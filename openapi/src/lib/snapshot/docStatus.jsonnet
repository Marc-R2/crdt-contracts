{
  components: {
    schemas: {
      DocStatusEntry: {
        type: 'object',
        required: ['bytes'],
        properties: {
          bytes: {
            type: 'integer',
            description: 'Byte length of the stored Yjs update blob (computed via SQL LENGTH, never materialized).',
          },
          updatedAt: {
            "$ref": '#/components/schemas/UnixTimestamp',
            description: 'Timestamp (ms) of the snapshot row (the stamp column).',
          },
        },
      },

      DocStatusResponse: {
        type: 'object',
        required: ['docs'],
        properties: {
          docs: {
            type: 'object',
            description: 'Per-document status keyed by globalId.',
            additionalProperties: { "$ref": '#/components/schemas/DocStatusEntry' },
          },
        },
      },
    },
  },

  paths: {
    '/projects/doc-status': {
      get: {
        tags: ['Projects'],
        summary: 'Get per-document sync status for a project.',
        description: 'Returns one entry per snapshot row of the project (globalId → byte length + row timestamp) so ANY client — including a lone client with no peers — can compare its per-CRDT state against the server (the exchange source for smart-sync). The project is taken from the X-Project-ID header (same authenticated-worker flow as the other project endpoints).',
        responses: {
          '200': { description: 'Per-document status returned successfully.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/DocStatusResponse' } } } },
          '401': { description: 'Missing or invalid bearer token / project ownership.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '404': { description: 'Unknown project.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
        },
      },
    },
  },
}
