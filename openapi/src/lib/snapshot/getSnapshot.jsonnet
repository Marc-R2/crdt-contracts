{
  components: {
    schemas: {
      GetSnapshotRequest: {
        type: 'object',
        required: ['projectId', 'docId'],
        properties: {
          projectId: { "$ref": '#/components/schemas/ProjectId' },
          docId: { "$ref": '#/components/schemas/DocId' },
        },
      },

      GetSnapshotResponse: {
        type: 'object',
        required: ['projectId', 'docId', 'snapshotData', 'stamp', 'hash', 'status'],
        properties: {
          projectId: { "$ref": '#/components/schemas/ProjectId' },
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
    '/snapshot/get': {
      post: {
        tags: ['Snapshot'],
        summary: 'Get a snapshot.',
        description: 'Get a specific snapshot by its ID in the project.',
        requestBody: {
          required: true,
          content: { 'application/json': { schema: { "$ref": '#/components/schemas/GetSnapshotRequest' } } },
        },
        responses: {
          '200': { description: 'Snapshot provided.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/GetSnapshotResponse' } } } },
          '400': { description: 'Invalid input.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
        },
      },
    },
  },
}
