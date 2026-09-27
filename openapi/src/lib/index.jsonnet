{
  components: {
    schemas: {
      // Define any shared schemas here if needed in the future
      GlobalId: { type: 'string', format: 'uuid', description: 'Server-assigned globally unique identifier (UUID).' },
      DocId: { type: 'string', description: 'Document ID.' },
      UnixTimestamp: { type: 'integer', description: 'Unix timestamp in milliseconds.' },

      # Health payload (GET /health, no auth; FR-SERVER-011): process stats
      # for load balancers / monitoring, mirrors the `InfoResponse` contract.
      HealthResponse: {
        type: 'object',
        required: ['ok'],
        properties: {
          ok: { type: 'boolean', description: "Always `true` when the process answers." },
          uptime: { type: 'number', description: 'Process uptime in seconds.' },
          activeRooms: { type: 'integer', description: 'Currently active WebSocket rooms (projects).' },
          blobCount: { type: 'integer', description: 'Number of stored blobs (lazy probe).' },
          dbSize: { type: 'integer', description: 'Size of the per-project SQLite storage in bytes.' },
        },
      },

      ProjectData: {
        type: 'object',
        properties: {
          projectId: { type: 'string', description: 'Unique project identifier.' },
          name: { type: 'string', description: 'Human-readable project name.' },
          createdAt: { type: 'integer', description: 'Creation timestamp (unix ms).' },
          userId: { type: 'string', description: 'Primary owner userId.' },
        },
      },

      InfoResponse: {
        type: 'object',
        properties: {
          ok: { type: 'string', description: "Literal 'OK'." },
          service: { type: 'string', description: 'Service name.' },
          versions: {
            type: 'object',
            properties: {
              hocuspocus: { type: 'string', description: 'Hocuspocus server version.' },
              yjs: { type: 'string', description: 'Yjs version.' },
              'self': { type: 'string', description: 'Server version.' },
              server: { type: 'string', description: 'Server package version.' },
              protocol: { type: 'integer', description: 'Wire-protocol version (integer). Bump on any breaking room-name / entry-schema change.' },
            },
          },
        },
      },
    },
  },

  paths: {
    '/': {
      get: {
        tags: ['System'],
        summary: 'Return basic server information.',
        description: 'Returns basic information about the CRDT Sync Server for health checks. The route sits behind the SHARED REST rate limiter and the REST dispatcher, so a probe can also be answered with 429 or 5xx — a client MUST treat any non-2xx answer as "server unreachable" and retry with backoff, never as a protocol mismatch.',
        responses: {
          '200': {
            description: 'Server info returned successfully.',
            content: { 'application/json': { schema: { "$ref": '#/components/schemas/InfoResponse' } } }
          },
          '429': {
            description: 'Too Many Requests (shared REST limiter RATE_LIMIT_MAX_PER_WINDOW, default 300 per window per IP and per project when X-Project-ID is sent, 0 = disabled). The response carries the CORS header block but NO Retry-After header, so the client must apply its own backoff.',
            content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } }
          },
          '500': {
            description: 'Internal Server Error — generic body, no internals leaked (the REST dispatcher maps every unmapped error to 500).',
            content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } }
          },
        },
      },
    },
    '/health': {
      get: {
        tags: ['System'],
        summary: 'Liveness health probe.',
        description: 'Returns basic process stats (uptime, active WebSocket rooms, blob count, DB size) with no authentication required; used by load balancers/monitoring (FR-SERVER-011).',
        responses: {
          '200': {
            description: 'Health stats returned successfully.',
            content: { 'application/json': { schema: { "$ref": '#/components/schemas/HealthResponse' } } },
          },
        },
      },
    },
    '/api-docs': {
      get: {
        tags: ['System'],
        summary: 'Return the human-readable API documentation page.',
        description: 'Serves a minimal HTML page listing the main endpoints and the locations of the machine-readable contract (`/openapi.yaml`) and the health probe.',
        responses: {
          '200': {
            description: 'API documentation page (HTML).',
            content: { 'text/html': { schema: { type: 'string' } } },
          },
        },
      },
    },
    '/openapi.yaml': {
      get: {
        tags: ['System'],
        summary: 'Return the OpenAPI YAML document for this API.',
        responses: { '200': { description: 'OpenAPI YAML document.' } },
      },
    },
  },
}
