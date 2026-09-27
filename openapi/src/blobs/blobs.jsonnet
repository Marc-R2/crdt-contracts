local rateLimited = {
  description: 'Rate limited (blob limiter RATE_LIMIT_BLOBS_PER_WINDOW, default 6000 per window per IP, 0 = disabled). The response carries the CORS header block but NO Retry-After header, so the client must apply its own backoff.',
  content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } },
};

{
  components: {
    schemas: {
      BatchCheckRequest: {
        type: 'object',
        required: ['hashes'],
        properties: {
          hashes: {
            type: 'array',
            // The SERVER cap is BLOB_MAX_BATCH_HASHES (env-tunable, default
            // 5000) and a longer list is rejected with 400. `maxItems` is the
            // client-side validation bound, so it must state the server cap —
            // the 500 that used to sit here is the reference CLIENT's
            // MAX_BATCH_SIZE (how IT chunks a larger set), not a server limit.
            maxItems: 5000,
            items: { type: 'string', description: '64-hex SHA-256 blob hash.' },
            description: 'Blob hashes to probe. Server cap: BLOB_MAX_BATCH_HASHES (env-tunable, default 5000); a longer list is rejected with 400. The reference client chunks larger sets into requests of 500 (its own MAX_BATCH_SIZE, not a server limit).',
          },
        },
      },
      BatchCheckResult: {
        type: 'object',
        required: ['existing', 'missing'],
        properties: {
          existing: {
            type: 'array',
            items: { type: 'string' },
            description: 'Hashes that exist as complete blobs on the server.',
          },
          missing: {
            type: 'array',
            items: { type: 'string' },
            description: 'Hashes that are missing from the server.',
          },
          chunked: {
            type: 'array',
            items: { type: 'string' },
            description: 'Hashes with an in-progress chunked upload (can be resumed).',
          },
        },
      },
      BlobManifestEntry: {
        type: 'object',
        required: ['hash', 'size', 'createdAt'],
        properties: {
          hash: { type: 'string', description: '64-hex SHA-256 blob hash.' },
          size: { type: 'integer', description: 'Blob size in bytes.' },
          createdAt: { "$ref": '#/components/schemas/UnixTimestamp' },
        },
      },
      BlobManifest: {
        type: 'object',
        required: ['blobs', 'totalSize', 'count', 'total'],
        properties: {
          blobs: {
            type: 'array',
            items: { "$ref": '#/components/schemas/BlobManifestEntry' },
          },
          totalSize: { type: 'integer', description: 'Summed size of the returned page entries (bounded work per request).' },
          count: { type: 'integer', description: 'Number of entries in THIS page (blobs.length).' },
          total: { type: 'integer', description: 'Full blob count of the store.' },
        },
      },
      ChunkUploadStatus: {
        type: 'object',
        required: ['complete', 'totalChunks', 'presentChunks', 'chunkSize', 'totalSize'],
        properties: {
          complete: { type: 'boolean', description: 'True when the blob is already committed and visible as a COMPLETE object (not merely assembled from chunks).' },
          totalChunks: {
            type: 'integer',
            description: 'Total number of chunks the upload consists of — the count the client passes in the commit request. Must NOT repeat presentChunks.length (the resume set, which is a lower bound until the commit declares the real total).',
          },
          presentChunks: {
            type: 'array',
            items: { type: 'integer' },
            description: 'Indexes of already-uploaded chunks (resume support).',
          },
          chunkSize: { type: 'integer', description: 'Chunk size in bytes the server is CONFIGURED to accept (BLOB_MAX_CHUNK_SIZE; env-tunable, default 4 MiB) — a hardcoded default that ignores the configured cap is non-conformant.' },
          totalSize: { type: 'integer', description: 'Expected total blob size in bytes. Advisory before the commit: the client declares the authoritative totalSize in the commit body.' },
        },
      },
    },
  },

  paths: {
    '/blobs/manifest': {
      get: {
        tags: ['Blobs'],
        summary: 'List the blob manifest.',
        description: 'Lists stored blobs (content-addressed by SHA-256). Serves the structure-sync reconciliation of the plugin BlobClient. Raw transfer routes sit behind the blob rate limiter (the shared JSON limiter is bypassed) — see the 429 response.',
        parameters: [
          { name: 'limit', 'in': 'query', required: false, description: 'Max entries (server default caps the page).', schema: { type: 'integer' } },
          { name: 'offset', 'in': 'query', required: false, description: 'Page offset into the full (hash-sorted) manifest.', schema: { type: 'integer' } },
          { name: 'X-Project-ID', 'in': 'header', required: true, description: 'Project scoping (shared with the other project routes).', schema: { type: 'string' } },
        ],
        responses: {
          '200': {
            description: 'A page of the manifest (bounded work per request — the full-store sum would cost one statSync per blob).',
            content: { 'application/json': { schema: { "$ref": '#/components/schemas/BlobManifest' } } },
          },
          '401': { description: 'Unauthorized.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '429': rateLimited,
        },
      },
    },
    '/blobs/batch-check': {
      post: {
        tags: ['Blobs'],
        summary: 'Batch blob existence check.',
        description: 'Checks which of the submitted hashes exist on the server (probes run concurrently) — replaces N individual HEAD checks. The server accepts up to BLOB_MAX_BATCH_HASHES hashes per request (env-tunable, default 5000) and answers 400 above that; the reference client chunks larger sets into requests of 500 (its own MAX_BATCH_SIZE, not a server limit).',
        parameters: [
          { name: 'X-Project-ID', 'in': 'header', required: true, description: 'Project key for the blob store.', schema: { type: 'string' } },
        ],
        requestBody: {
          required: true,
          content: { 'application/json': { schema: { "$ref": '#/components/schemas/BatchCheckRequest' } } },
        },
        responses: {
          '200': {
            description: 'Existing / missing / resumable-chunked hashes.',
            content: { 'application/json': { schema: { "$ref": '#/components/schemas/BatchCheckResult' } } },
          },
          '400': { description: 'Invalid or oversized hash list.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '401': { description: 'Unauthorized.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '429': rateLimited,
        },
      },
    },
    '/blobs/{hash}': {
      put: {
        tags: ['Blobs'],
        summary: 'Upload a blob (raw binary).',
        description: 'Streams the request body (application/octet-stream) into the content-addressed store; the server verifies sha256(body) === {hash} before persisting (F3: missing/invalid Content-Length is rejected). Single-blob size cap applies (BLOB_MAX_SINGLE_SIZE).',
        parameters: [
          { name: 'hash', 'in': 'path', required: true, description: '64-hex SHA-256 of the content (the blob id).', schema: { type: 'string', pattern: '^[a-fA-F0-9]{64}$' } },
          { name: 'X-Project-ID', 'in': 'header', required: true, description: 'Project key.', schema: { type: 'string' } },
        ],
        requestBody: {
          required: true,
          content: { 'application/octet-stream': { schema: { type: 'string', format: 'binary' } } },
        },
        responses: {
          '201': { description: 'Blob stored (hash verified on the server side). 201 Created is the success code — the client keys on it.' },
          '400': { description: 'Hash mismatch / invalid hash / size limit.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '401': { description: 'Unauthorized.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '411': { description: 'Length Required — the Content-Length header is missing or unparseable, so the body is refused before it is streamed (chunked transfer-encoding is not accepted on uploads).', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '413': { description: 'Payload Too Large — Content-Length exceeds BLOB_MAX_SINGLE_SIZE (env-tunable, default 16 MiB); use the chunked upload routes.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '429': rateLimited,
        },
      },
      get: {
        tags: ['Blobs'],
        summary: 'Download a blob (raw binary, Range-capable).',
        description: 'Streams the raw blob bytes. Supports HTTP Range requests (partial download). The client verifies sha256(response) === {hash}. Empty-blob rule: exactly one usability predicate (size>0 || hash===EMPTY_SHA256) gates 404 vs serve.',
        parameters: [
          { name: 'hash', 'in': 'path', required: true, description: '64-hex SHA-256.', schema: { type: 'string', pattern: '^[a-fA-F0-9]{64}$' } },
          { name: 'Range', 'in': 'header', required: false, description: 'Byte range for partial download.', schema: { type: 'string' } },
          { name: 'X-Project-ID', 'in': 'header', required: true, description: 'Project key.', schema: { type: 'string' } },
        ],
        responses: {
          '200': {
            description: 'Blob bytes.',
            content: { 'application/octet-stream': { schema: { type: 'string', format: 'binary' } } },
          },
          '206': {
            description: 'Partial content (Range request served).',
            content: { 'application/octet-stream': { schema: { type: 'string', format: 'binary' } } },
          },
          '404': { description: 'Blob not found (or unusable).', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '401': { description: 'Unauthorized.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '416': { description: 'Range Not Satisfiable — a Range header was sent but cannot be served (malformed, start >= size, or an inverted end < start). The body is EMPTY; the blob size is carried by the `Content-Range: bytes */<size>` header together with `Accept-Ranges: bytes`.' },
          '429': rateLimited,
        },
      },
      delete: {
        tags: ['Blobs'],
        summary: 'Delete a blob (GC) — DESTRUCTIVE.',
        description: 'Removes an unreferenced blob (client-driven GC). Protected referenced hashes must not be deleted; tombstoned hashes still keep a 1h grace before the vacuum can reclaim them. Exposed to every project member — a known production-hardening gap (no per-project upload quota either).',
        parameters: [
          { name: 'hash', 'in': 'path', required: true, description: '64-hex SHA-256.', schema: { type: 'string', pattern: '^[a-fA-F0-9]{64}$' } },
          { name: 'X-Project-ID', 'in': 'header', required: true, description: 'Project key.', schema: { type: 'string' } },
        ],
        responses: {
          // NO 404: the delete is idempotent. The repository swallows every
          // unlink error (`catch { /* Already gone — fine. */ }`), so a hash
          // that is absent answers 200 exactly like one that was removed — a
          // GC retry must never fail. A future server that wants to
          // distinguish "gone" must answer 404 on BOTH paths (i.e. before
          // deleting) and add it here.
          '200': { description: 'Blob deleted — also returned when the hash was already absent (idempotent).' },
          '401': { description: 'Unauthorized.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '429': rateLimited,
        },
      },
    },
    '/blobs/{hash}/chunks/{n}': {
      put: {
        tags: ['Blobs'],
        summary: 'Upload one chunk of a chunked blob.',
        description: 'Uploads chunk {n} of a large blob (>= 16 MB uses chunked upload with resume). 0-based chunk index; each chunk is hashed/verified server side; per-chunk and total caps apply (BLOB_MAX_CHUNK_SIZE / BLOB_MAX_TOTAL_BYTES).',
        parameters: [
          { name: 'hash', 'in': 'path', required: true, description: '64-hex SHA-256 of the WHOLE blob.', schema: { type: 'string', pattern: '^[a-fA-F0-9]{64}$' } },
          { name: 'n', 'in': 'path', required: true, description: 'Zero-based chunk index.', schema: { type: 'integer', minimum: 0 } },
          { name: 'X-Project-ID', 'in': 'header', required: true, description: 'Project key.', schema: { type: 'string' } },
        ],
        requestBody: {
          required: true,
          content: { 'application/octet-stream': { schema: { type: 'string', format: 'binary' } } },
        },
        responses: {
          '201': { description: 'Chunk stored. 201 Created is the success code — the client keys on it.' },
          '401': { description: 'Unauthorized.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '411': { description: 'Length Required — the Content-Length header is missing or unparseable, so the chunk body is refused before it is streamed (chunked transfer-encoding is not accepted on uploads).', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          // Oversized chunks and out-of-range indexes are 413, NOT 400 (the
          // contract used to promise a 400 this route cannot write).
          '413': { description: 'Payload Too Large — Content-Length exceeds BLOB_MAX_CHUNK_SIZE (env-tunable, default 4 MiB, plus a 1 KiB tolerance), or the chunk INDEX is beyond the chunk count BLOB_MAX_TOTAL_BYTES / BLOB_MAX_CHUNK_SIZE allows.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '429': rateLimited,
        },
      },
    },
    '/blobs/{hash}/status': {
      get: {
        tags: ['Blobs'],
        summary: 'Query chunked-upload status (resume).',
        description: 'Returns which chunks of an in-progress chunked upload are present so the client can resume exactly where it stopped (ChunkUploadStatus contract from blobTypes.ts).',
        parameters: [
          { name: 'hash', 'in': 'path', required: true, description: '64-hex SHA-256.', schema: { type: 'string', pattern: '^[a-fA-F0-9]{64}$' } },
          { name: 'X-Project-ID', 'in': 'header', required: true, description: 'Project key.', schema: { type: 'string' } },
        ],
        responses: {
          '200': {
            description: 'Upload status.',
            content: { 'application/json': { schema: { "$ref": '#/components/schemas/ChunkUploadStatus' } } },
          },
          '401': { description: 'Unauthorized.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '429': rateLimited,
        },
      },
    },
    '/blobs/{hash}/commit': {
      post: {
        tags: ['Blobs'],
        summary: 'Finalize a chunked upload.',
        description: 'Completes a chunked upload: the server concatenates every present chunk, verifies the final sha256 === {hash}, and makes the blob visible (atomically; empty body).',
        parameters: [
          { name: 'hash', 'in': 'path', required: true, description: '64-hex SHA-256.', schema: { type: 'string', pattern: '^[a-fA-F0-9]{64}$' } },
          { name: 'X-Project-ID', 'in': 'header', required: true, description: 'Project key.', schema: { type: 'string' } },
        ],
        requestBody: {
          required: false,
          content: { 'application/json': { schema: { type: 'object' } } },
        },
        responses: {
          '201': { description: 'Blob finalized and hash-verified (empty body). 201 Created is the success code — the client keys on it.' },
          '400': { description: 'Invalid JSON body / `totalChunks` missing or not a number, a missing chunk, or a hash mismatch of the assembled blob. NOTE: the missing-chunk case is a client error that the server currently answers 500 — the mapping is tracked as a server-side fix.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '401': { description: 'Unauthorized.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '413': { description: 'Payload Too Large — the declared `totalSize` or the implied chunk count exceeds BLOB_MAX_TOTAL_BYTES (env-tunable, default 1 GiB); the assembly is refused before any work starts.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '429': rateLimited,
        },
      },
    },
  },
}
