{
  components: {
    schemas: {
      GetSnapshotUpdatesRequest: {
        type: 'object',
        required: ['projectId', 'timestamp'],
        properties: {
          projectId: { type: 'string', description: 'The id of the project.' },
          timestamp: { type: 'integer', description: 'The unix timestamp after which to retrieve snapshot updates.' },
        },
      },

      GetSnapshotUpdatesResponse: {
        type: 'object',
        required: ['projectId', 'updates'],
        properties: {
          projectId: { type: 'string', description: 'The unique project UUID-V4.' },
          updates: {
            type: 'array',
            description: 'List of updated snapshots since the given timestamp.',
            items: { "$ref": '#/components/schemas/Snapshot' },
          },
        },
      },

      Snapshot: {
        type: 'object',
        required: ['docId', 'snapshotData', 'stamp', 'hash', 'status'],
        properties: {
          docId: { type: 'string', description: 'The document ID of the snapshot.' },
          snapshotData: { type: 'string', description: 'The data of the snapshot, encoded in base64.' },
          stamp: { type: 'integer', description: 'The unix timestamp when the snapshot was updated.' },
          hash: { type: 'string', description: 'The hash of the snapshot data.' },
          status: { type: 'string', description: 'The status of the snapshot within the project. E.g., "active", "archived", "deleted".' },
        },
      },
    },
  },

  paths: {
    '/snapshot/getUpdates': {
      post: {
        tags: ['Snapshot'],
        summary: 'Get snapshot updates.',
        description: 'Get all updated snapshots after a specific timestamp within a project.',
        requestBody: {
          required: true,
          content: { 'application/json': { schema: { "$ref": '#/components/schemas/GetSnapshotUpdatesRequest' } } },
        },
        responses: {
          '200': { description: 'Snapshots provided.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/GetSnapshotUpdatesResponse' } } } },
          '400': { description: 'Invalid input.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
        },
      },
    },
  },
}
