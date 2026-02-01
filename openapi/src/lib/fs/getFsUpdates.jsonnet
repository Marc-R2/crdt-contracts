{
  components: {
    schemas: {
      GetFsUpdatesRequest: {
        type: 'object',
        required: ['timestamp'],
        properties: {
          projectId: { "$ref": '#/components/schemas/ProjectId' },
          timestamp: { "$ref": '#/components/schemas/UnixTimestamp' },
        },
      },

      GetFsUpdatesResponse: {
        type: 'object',
        required: ['updates'],
        properties: {
          updates: {
            type: 'array',
            description: 'List of file system updates since the given timestamp.',
            items: { "$ref": '#/components/schemas/FsEntry' },
          },
        },
      },
    },
  },

  paths: {
    '/fs/getUpdates': {
      post: {
        tags: ['File System'],
        summary: 'Get file system updates.',
        description: 'Returns all file system updates after a specific timestamp within a project. Uses LWW by client stamp with server validation.',
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
