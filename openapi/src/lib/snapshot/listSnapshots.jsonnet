{
  components: {
    schemas: {
      ListSnapshotsRequest: {
        type: 'object',
        required: ['projectId'],
        properties: {
          projectId: { type: 'string', description: 'The id of the project.' },
        },
      },

      ListSnapshotsResponse: {
        type: 'object',
        required: ['projectId', 'snapshotInfos'],
        properties: {
          projectId: { type: 'string', description: 'The unique project UUID-V4.' },
          snapshotInfos: {
         	type: 'array',
            description: 'List of all active snapshots-infos within the project.',
      	    items: { "$ref": '#/components/schemas/SnapshotInfo' },
      	  },
        },
      },

      SnapshotInfo: {
		type: 'object',
		required: ['docId', 'hashPart'],
		properties: {
		  docId: { type: 'string', description: 'The document ID of the snapshot.' },
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
        description: 'Get a list of all snapshot-infos within a project. Snapshot-info is a minimal representation of a snapshot containing only the docId and the first 8 bytes of the hash.',
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
