{
  components: {
    schemas: {
      GetSnapshotUpdatesRequest: {
        type: 'object',
        required: ['timestamp'],
        properties: {
          timestamp: { "$ref": '#/components/schemas/UnixTimestamp' },
          includeDeleted: {
            type: 'boolean',
            description: 'If true, include deleted snapshots; defaults to false (active only).',
          },
        },
      },

      GetSnapshotUpdatesResponse: {
        type: 'object',
        required: ['updates'],
        properties: {
          updates: {
            type: 'array',
            description: 'List of updated snapshots since the given timestamp.',
            items: { "$ref": '#/components/schemas/Snapshot' },
          },
        },
      },

      Snapshot: {
        type: 'object',
        required: ['globalId', 'snapshotData', 'stamp', 'hash', 'status'],
        properties: {
          globalId: { "$ref": '#/components/schemas/GlobalId' },
          snapshotData: { type: 'string', description: 'The data of the snapshot, encoded in base64.' },
          stamp: { "$ref": '#/components/schemas/UnixTimestamp' },
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
        description: 'Get all updated snapshots after a specific timestamp within a project. Deleted snapshots are excluded unless includeDeleted is true.',
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
