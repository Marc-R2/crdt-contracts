{
  components: {
    schemas: {
      HistoryUser: {
        type: 'object',
        required: ['clientId', 'userId', 'userName', 'color'],
        properties: {
          clientId: { type: 'integer', description: 'Yjs client id.' },
          userId: { type: 'string' },
          userName: { type: 'string' },
          color: { type: 'string', description: 'Attribution color (derived per user).' },
        },
      },
      TimelineCheckpoint: {
        type: 'object',
        required: ['checkpointSeq', 'seq', 'createdAt'],
        properties: {
          checkpointSeq: { type: 'integer', description: 'Checkpoint sequence (every CHECKPOINT_INTERVAL=100 stored seqs).' },
          seq: { type: 'integer', description: 'Last captured seq covered by this checkpoint.' },
          createdAt: { "$ref": '#/components/schemas/UnixTimestamp' },
        },
      },
      TimelineCommit: {
        type: 'object',
        properties: {
          commitId: { type: 'string' },
          scope: { type: 'string', description: "'note' | 'vault'." },
          docId: { type: 'string', nullable: true, description: 'Only for note-scoped commits.' },
          seq: { type: 'integer', nullable: true },
          name: { type: 'string' },
          createdAt: { "$ref": '#/components/schemas/UnixTimestamp' },
          createdBy: { type: 'string' },
        },
      },
      TimelineIndex: {
        type: 'object',
        required: ['docId', 'seqCount', 'firstTs', 'lastTs', 'checkpoints', 'commits', 'users'],
        properties: {
          docId: { "$ref": '#/components/schemas/DocId' },
          seqCount: { type: 'integer', description: 'Number of captured updates.' },
          firstTs: { "$ref": '#/components/schemas/UnixTimestamp' },
          lastTs: { "$ref": '#/components/schemas/UnixTimestamp' },
          checkpoints: {
            type: 'array',
            items: { "$ref": '#/components/schemas/TimelineCheckpoint' },
          },
          commits: {
            type: 'array',
            items: { "$ref": '#/components/schemas/TimelineCommit' },
          },
          users: {
            type: 'array',
            items: { "$ref": '#/components/schemas/HistoryUser' },
            description: 'PRIVACY: only users with an edit on THIS document are exposed (vault commit authors who never touched the note are omitted).',
          },
        },
      },
      CommitInfo: {
        type: 'object',
        properties: {
          commitId: { type: 'string' },
          scope: { type: 'string', description: "'note' | 'vault'." },
          docId: { type: 'string', nullable: true },
          seq: { type: 'integer', nullable: true },
          name: { type: 'string' },
          createdAt: { "$ref": '#/components/schemas/UnixTimestamp' },
          createdBy: { type: 'string' },
        },
      },
    },
  },

  paths: {
    '/projects/{projectId}/docs/{docId}/timeline': {
      get: {
        tags: ['History'],
        summary: 'History timeline index for one document.',
        description: 'Returns the update timeline index (seq range, checkpoints, commits, attributed users) for a document. URL-param route served by the history handler (regex-direct; auth bearer + X-Project-ID is NOT bypassed, URL project must match the header).',
        parameters: [
          { name: 'projectId', 'in': 'path', required: true, schema: { type: 'string' } },
          { name: 'docId', 'in': 'path', required: true, schema: { type: 'string' } },
        ],
        responses: {
          '200': {
            description: 'Timeline index.',
            content: { 'application/json': { schema: { "$ref": '#/components/schemas/TimelineIndex' } } },
          },
          '400': { description: 'Bad request.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '401': { description: 'Unauthorized.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '404': { description: 'Unknown doc.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
        },
      },
    },
    '/projects/{projectId}/docs/{docId}/chunks': {
      get: {
        tags: ['History'],
        summary: 'Raw Yjs update deltas (chunked binary contract).',
        description: 'Reads the update range [fromSeq, toSeq] clamped to the doc actual [minSeq, maxSeq] and returns the encoded binary chunk payload (GET returns application/octet-stream; no history / empty range counts 0; FAIL-OPEN on seq gaps on the client side).',
        parameters: [
          { name: 'projectId', 'in': 'path', required: true, schema: { type: 'string' } },
          { name: 'docId', 'in': 'path', required: true, schema: { type: 'string' } },
          { name: 'fromSeq', 'in': 'query', required: false, description: 'Inclusive lower bound (defaults to the doc min seq).', schema: { type: 'integer', minimum: 0 } },
          { name: 'toSeq', 'in': 'query', required: false, description: 'Inclusive upper bound (defaults to the doc max seq).', schema: { type: 'integer', minimum: 0 } },
        ],
        responses: {
          '200': {
            description: 'Encoded binary chunk payload.',
            content: { 'application/octet-stream': { schema: { type: 'string', format: 'binary' } } },
          },
          '400': { description: 'Bad request.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '401': { description: 'Unauthorized.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
        },
      },
    },
    '/projects/{projectId}/docs/{docId}/checkpoints/{checkpointSeq}': {
      get: {
        tags: ['History'],
        summary: 'Checkpoint snapshot blob.',
        description: 'Returns the raw checkpoint snapshot blob (404 → the replay window expands to seq 0 client-side). Binary route (application/octet-stream).',
        parameters: [
          { name: 'projectId', 'in': 'path', required: true, schema: { type: 'string' } },
          { name: 'docId', 'in': 'path', required: true, schema: { type: 'string' } },
          { name: 'checkpointSeq', 'in': 'path', required: true, description: 'Checkpoint sequence (must be a non-negative integer).', schema: { type: 'integer', minimum: 0 } },
        ],
        responses: {
          '200': {
            description: 'Checkpoint blob.',
            content: { 'application/octet-stream': { schema: { type: 'string', format: 'binary' } } },
          },
          '400': { description: 'Invalid checkpointSeq.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '401': { description: 'Unauthorized.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '404': { description: 'Checkpoint not found.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
        },
      },
    },
    '/projects/{projectId}/commits': {
      post: {
        tags: ['History'],
        summary: 'Create a note or vault commit.',
        description: "Records a commit (scope 'note' = one doc with optional seq; scope 'vault' = whole-vault manifest built from the structure Y.Doc). The note ownership gate (docId must exist in the project structure) runs inside CommitService in ONE transaction (TOCTOU-closed).",
        parameters: [
          { name: 'projectId', 'in': 'path', required: true, schema: { type: 'string' } },
        ],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['scope', 'name'],
                properties: {
                  scope: { type: 'string', description: "'note' | 'vault'." },
                  docId: { type: 'string', description: "Note-scope only: docId that must exist in the project structure." },
                  seq: { type: 'integer', description: 'Note-scope only: defaults to the doc max seq.' },
                  name: { type: 'string' },
                },
              },
            },
          },
        },
        responses: {
          '201': {
            description: 'Commit recorded (note scope returns the CommitInfo; vault scope also returns the built manifest).',
            content: { 'application/json': { schema: { type: 'object' } } },
          },
          '400': { description: "commit scope must be 'note' or 'vault' (or ownership/seq validation failure).", content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '401': { description: 'Unauthorized.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
        },
      },
      get: {
        tags: ['History'],
        summary: 'List commits (optional scope/docId filter).',
        description: 'Lists commits (projection never includes manifest_json). Optional query filters: scope=note|vault and docId.',
        parameters: [
          { name: 'projectId', 'in': 'path', required: true, schema: { type: 'string' } },
          { name: 'scope', 'in': 'query', required: false, description: "'note' | 'vault'.", schema: { type: 'string' } },
          { name: 'docId', 'in': 'query', required: false, description: 'Filter to one document.', schema: { type: 'string' } },
        ],
        responses: {
          '200': {
            description: 'Filtered commit list.',
            content: {
              'application/json': {
                schema: {
                  type: 'array',
                  items: { "$ref": '#/components/schemas/CommitInfo' },
                },
              },
            },
          },
          '401': { description: 'Unauthorized.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
        },
      },
    },
    '/projects/{projectId}/commits/{commitId}/manifest': {
      get: {
        tags: ['History'],
        summary: 'Commit manifest.',
        description: 'Returns the manifest of a vault commit (notes = markdown/UUID docIds, blobs = sha256: docIds / contentHashes) — the restore window on the client side.',
        parameters: [
          { name: 'projectId', 'in': 'path', required: true, schema: { type: 'string' } },
          { name: 'commitId', 'in': 'path', required: true, schema: { type: 'string' } },
        ],
        responses: {
          '200': {
            description: 'Manifest returned.',
            content: { 'application/json': { schema: { type: 'object' } } },
          },
          '401': { description: 'Unauthorized.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '404': { description: 'Commit not found.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
        },
      },
    },
    '/projects/{projectId}/commits/{commitId}': {
      patch: {
        tags: ['History'],
        summary: 'Rename a commit.',
        description: 'Renames a commit (non-empty string name required; OPTIONS is accepted as CORS preflight).',
        parameters: [
          { name: 'projectId', 'in': 'path', required: true, schema: { type: 'string' } },
          { name: 'commitId', 'in': 'path', required: true, schema: { type: 'string' } },
        ],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['name'],
                properties: {
                  name: { type: 'string', description: 'Non-empty commit name.' },
                },
              },
            },
          },
        },
        responses: {
          '200': {
            description: 'Renamed commit returned.',
            content: { 'application/json': { schema: { "$ref": '#/components/schemas/CommitInfo' } } },
          },
          '400': { description: 'commit requires a non-empty name.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '401': { description: 'Unauthorized.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
        },
      },
    },
  },
}
