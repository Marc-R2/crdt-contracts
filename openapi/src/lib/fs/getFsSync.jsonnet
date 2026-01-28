{
  components: {
    schemas: {
      GetFsSyncRequest: {
        type: 'object',
        required: ['projectId', 'entries'],
        properties: {
          projectId: { type: 'string', description: 'Project ID (UUID v4).' },
          entries: {
            type: 'array',
            description: 'All file system entries present on the client.',
            items: { "$ref": '#/components/schemas/FsEntry' },
          },
        },
      },

      GetFsSyncResponse: {
        type: 'object',
        required: ['projectId', 'updates'],
        properties: {
          projectId: { type: 'string', format: 'uuid', description: 'Project ID (UUID v4).' },
          updates: {
            type: 'array',
            description: 'List of server-side fs entry updates compared to the client entries.',
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
