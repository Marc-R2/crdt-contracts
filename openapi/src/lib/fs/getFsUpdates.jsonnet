{
  components: {
    schemas: {
      GetFsUpdatesRequest: {
        type: 'object',
        required: ['projectId', 'timestamp'],
        properties: {
          projectId: { type: 'string', description: 'Project ID (UUID v4).' },
          timestamp: { type: 'integer', description: 'Unix timestamp after which to retrieve file system updates.' },
        },
      },

      GetFsUpdatesResponse: {
        type: 'object',
        required: ['projectId', 'updates'],
        properties: {
          projectId: { type: 'string', description: 'Project ID (UUID v4).' },
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
          docId: { type: 'string', description: 'Document ID associated with the fs entry.' },
          path: { type: 'string', description: 'Path of the fs entry relative to the project root.' },
          stamp: { type: 'integer', description: 'Unix timestamp of the last update.' },
          status: { type: 'string', description: 'Entry status within the project. Example: "active", "archived", "deleted".' },
        },
      },
    },
  },

  paths: {
    '/fs/getUpdates': {
      post: {
        tags: ['File System'],
        summary: 'Get file system updates.',
        description: 'Returns all file system updates after a specific timestamp within a project.',
        requestBody: {
          required: true,
          content: { 'application/json': { schema: { "$ref": '#/components/schemas/GetFsUpdatesRequest' } } },
        },
        responses: {
          '200': { description: 'File system updates returned successfully.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/GetFsUpdatesResponse' } } } },
          '400': { description: 'Invalid input.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
        },
      },
    },
  },
}
