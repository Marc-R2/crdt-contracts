{
  components: {
    schemas: {
      BatchCheckRequest: {
        type: 'object',
        required: ['hashes'],
        properties: {
          hashes: {
            type: 'array',
            maxItems: 500,
            items: { type: 'string', description: '64-hex SHA-256 blob hash.' },
            description: 'Up to 500 blob hashes per request; larger sets are chunked by the client.',
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
          complete: { type: 'boolean', description: 'True once every chunk is uploaded and the upload is ready to commit.' },
          totalChunks: { type: 'integer' },
          presentChunks: {
            type: 'array',
            items: { type: 'integer' },
            description: 'Indexes of already-uploaded chunks (resume support).',
          },
          chunkSize: { type: 'integer', description: 'Chunk size in bytes.' },
          totalSize: { type: 'integer', description: 'Expected total blob size in bytes.' },
        },
      },
    },
  },

  paths: {
    '/blobs/manifest': {
      get: {
        tags: ['Blobs'],
        summary: 'List the blob manifest.',
        description: 'Lists stored blobs (content-addressed by SHA-256). Serves the structure-sync reconciliation of the plugin BlobClient. Raw transfer routes sit behind the blob rate limiter (the shared JSON limiter is bypassed).',
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
        },
      },
    },
    '/blobs/batch-check': {
      post: {
        tags: ['Blobs'],
        summary: 'Batch blob existence check.',
        description: 'Checks which of up to 500 hashes exist on the server (probes run concurrently) — replaces N individual HEAD checks. Chunked into requests of 500 by the client.',
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
          '200': { description: 'Blob stored (hash verified on the server side).' },
          '400': { description: 'Hash mismatch / invalid hash / size limit.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '401': { description: 'Unauthorized.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
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
          '200': { description: 'Blob deleted.' },
          '404': { description: 'Blob not found.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '401': { description: 'Unauthorized.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
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
          '200': { description: 'Chunk stored.' },
          '400': { description: 'Chunk too large / total-size overflow / invalid index.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '401': { description: 'Unauthorized.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
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
          '200': { description: 'Blob finalized and hash-verified.' },
          '400': { description: 'Missing chunks / hash mismatch.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '401': { description: 'Unauthorized.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
        },
      },
    },
  },
}
