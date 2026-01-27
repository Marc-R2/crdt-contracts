{
  components: {
    schemas: {
      // Define any shared schemas here if needed in the future
    },
  },

  paths: {
    '/': {
      get: {
        tags: ['System'],
        summary: 'Returns basic server information.',
        description: 'Provides basic information about the CRDT Sync Server. This endpoint can be used to check server availability.',
        responses: {
          '200': {
            description: 'Success',
            content: {
              'application/json': {
                schema: {
                  type: 'object',
                  properties: {
                    ok: { type: 'string', description: "'OK'" },
                    service: { type: 'string', description: "'Obsidian CRDT Sync Server'" },
                    versions: {
                      type: 'object',
                      properties: {
                        hocuspocus: { type: 'string', description: 'Hocuspocus server version' },
                        yjs: { type: 'string', description: 'Yjs version' },
                        'self': { type: 'string', description: 'Server version' },
                      },
                    },
                  },
                },
              },
            },
          },
        },
      },
    },
    '/openapi.yaml': {
      get: {
        tags: ['System'],
        summary: 'Returns OpenAPI YAML document describing the capabilities of this API.',
        responses: { '200': { description: 'Success' } },
      },
    },
  },
}
