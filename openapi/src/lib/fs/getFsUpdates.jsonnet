{
  components: {
    schemas: {
      GetFsUpdatesRequest: {
        type: 'object',
        required: ['projectId', 'timestamp'],
        properties: {
          projectId: { type: 'string', description: 'The id of the project.' },
          timestamp: { type: 'integer', description: 'The unix timestamp after which to retrieve file system updates.' },
        },
      },

      GetFsUpdatesResponse: {
        type: 'object',
        required: ['projectId', 'updates'],
        properties: {
          projectId: { type: 'string', description: 'The unique project UUID-V4.' },
          updates: {
          	type: 'array',
          	description: 'List of file system updates since the given timestamp.',
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
    '/fs/getUpdates': {
      post: {
        tags: ['File System'],
        summary: 'Get file system updates.',
        description: 'Get all file system updates after a specific timestamp within a project.',
        requestBody: {
          required: true,
          content: { 'application/json': { schema: { "$ref": '#/components/schemas/GetFsUpdatesRequest' } } },
        },
        responses: {
          '200': { description: 'File System updates provided.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/GetFsUpdatesResponse' } } } },
          '400': { description: 'Invalid input.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
        },
      },
    },
  },
}
