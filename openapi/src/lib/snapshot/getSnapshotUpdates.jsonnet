{
  components: {
    schemas: {
      GetSnapshotUpdatesRequest: {
        type: 'object',
        required: ['projectId', 'timestamp'],
        properties: {
          projectId: { "$ref": '#/components/schemas/ProjectId' },
          timestamp: { "$ref": '#/components/schemas/UnixTimestamp' },
        },
      },

      GetSnapshotUpdatesResponse: {
        type: 'object',
        required: ['projectId', 'updates'],
        properties: {
          projectId: { "$ref": '#/components/schemas/ProjectId' },
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
          docId: { "$ref": '#/components/schemas/DocId' },
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
