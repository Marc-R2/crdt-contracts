{
  components: {
    schemas: {
      ListSnapshotsRequest: {
        type: 'object',
        required: [],
        properties: {
          includeDeleted: {
            type: 'boolean',
            description: 'If true, include deleted snapshots; defaults to false (active only).',
          },
        },
      },

      ListSnapshotsResponse: {
        type: 'object',
        required: ['snapshotInfos'],
        properties: {
          snapshotInfos: {
            type: 'array',
            description: 'List of all active snapshots-infos within the project.',
            items: { "$ref": '#/components/schemas/SnapshotInfo' },
          },
        },
      },

      SnapshotInfo: {
        type: 'object',
        required: ['globalId', 'hashPart'],
        properties: {
          globalId: { "$ref": '#/components/schemas/GlobalId' },
          hashPart: { type: 'string', description: 'The first 8 Bytes of the hash.' },
        },
      },
    },
  },

  paths: {
    '/snapshot/list': {
      post: {
        tags: ['Snapshot'],
        summary: 'Get list of snapshots.',
        description: 'Get a list of snapshot-infos within a project. Snapshot-info is a minimal representation containing only the docId and the first 8 bytes of the hash. Deleted snapshots are excluded unless includeDeleted is true.',
        requestBody: {
          required: true,
          content: { 'application/json': { schema: { "$ref": '#/components/schemas/ListSnapshotsRequest' } } },
        },
        responses: {
          '200': { description: 'Snapshot list returned successfully.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/ListSnapshotsResponse' } } } },
          '400': { description: 'Invalid input.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
        },
      },
    },
  },
}
