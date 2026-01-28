{
  components: {
    schemas: {
      GetFsSyncRequest: {
        type: 'object',
        required: ['projectId', 'entries'],
        properties: {
          projectId: { type: 'string', description: 'The id of the project.' },
          entries: {
            type: 'array',
            description: 'List of all file system entries present on client.',
            items: { "$ref": '#/components/schemas/FsEntry' },
          },
        },
      },

      GetFsSyncResponse: {
        type: 'object',
        required: ['projectId', 'updates'],
        properties: {
          projectId: { type: 'string', description: 'The unique project UUID-V4.' },
          updates: {
          	type: 'array',
          	description: 'List of changed or new file system entries in comparison to the client-provided entries.',
		  	items: { "$ref": '#/components/schemas/FsEntry' },
		  },
        },
      },

      FsEntry: {
		type: 'object',
		required: ['docId', 'path', 'stamp', 'status'],
		properties: {
		  docId: { type: 'string', description: 'The document ID associated with the fs-entry.' },
		  path: { type: 'string', description: 'The path of the fs-entry, relative to the project root.' },
		  stamp: { type: 'integer', description: 'The unix timestamp when the fs-entry was updated.' },
		  status: { type: 'string', description: 'The status of the fs-entry within the project. E.g., "active", "archived", "deleted".' },
		},
	  },
    },
  },

  paths: {
    '/fs/getSync': {
      post: {
        tags: ['File System'],
        summary: 'Get file system sync updates.',
        description: 'Compares client entries against the server state and returns the fs-entry updates needed to sync.',
        requestBody: {
          required: true,
          content: { 'application/json': { schema: { "$ref": '#/components/schemas/GetFsSyncRequest' } } },
        },
        responses: {
          '200': { description: 'Sync updates returned successfully.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/GetFsSyncResponse' } } } },
          '400': { description: 'Invalid input.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
        },
      },
    },
  },
}
