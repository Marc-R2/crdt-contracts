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
        summary: 'Return basic server information.',
        description: 'Returns basic information about the CRDT Sync Server for health checks.',
        responses: {
          '200': {
            description: 'Server info returned successfully.',
            content: {
              'application/json': {
                schema: {
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
