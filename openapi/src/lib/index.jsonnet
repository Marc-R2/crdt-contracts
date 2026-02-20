{
  components: {
    schemas: {
      // Define any shared schemas here if needed in the future
      ProjectId: { type: 'string', format: 'uuid', description: 'Project ID (UUID v4).' },
      GlobalId: { type: 'string', format: 'uuid', description: 'Server-assigned globally unique identifier (UUID).' },
      DocId: { type: 'string', description: 'Document ID.' },
      UnixTimestamp: { type: 'integer', description: 'Unix timestamp in milliseconds.' },
      FsEntry: {
        type: 'object',
        required: ['globalId', 'docId', 'path', 'stamp', 'status'],
        properties: {
          globalId: { "$ref": '#/components/schemas/GlobalId' },
          docId: { "$ref": '#/components/schemas/DocId' },
          path: {
            type: 'string',
            description: 'Path of the fs entry relative to the project root. Use forward slashes, no leading slash, case-sensitive.',
          },
          stamp: {
            "$ref": '#/components/schemas/UnixTimestamp',
            description: 'Client-provided modification time (offline-first). Server validates plausibility and uses LWW by stamp.',
          },
          status: {
            type: 'string',
            description: 'Entry status within the project. Example: "active", "archived", "deleted".',
          },
          updated: {
            "$ref": '#/components/schemas/UnixTimestamp',
            description: 'Server write timestamp for this entry. Used as a tie-breaker when stamps are equal.',
          },
          isPresent: {
			type: 'boolean',
			description: 'Indicates if the file or snapshot is present on the server. If false, the file of snapshot is missing - needs to be uploaded by the client.',
		  },
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
        description: 'Returns basic information about the CRDT Sync Server for health checks.',
        responses: {
          '200': {
            description: 'Server info returned successfully.',
            content: { 'application/json': { schema: { "$ref": '#/components/schemas/InfoResponse' } } }
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
