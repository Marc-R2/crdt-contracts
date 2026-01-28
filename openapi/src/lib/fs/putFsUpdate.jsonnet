{
  components: {
    schemas: {
      PutFsUpdateRequest: {
        type: 'object',
        required: ['projectId', 'update'],
        properties: {
          projectId: { "$ref": '#/components/schemas/ProjectId' },
          update: { "$ref": '#/components/schemas/FsEntry' },
        },
      },
      
      PutFsUpdateResponse: {
        type: 'object',
        required: ['projectId', 'newest'],
        properties: {
          projectId: { "$ref": '#/components/schemas/ProjectId' },
          newest: { "$ref": '#/components/schemas/FsEntry' }
        },
      },
    },
  },

  paths: {
    '/fs/putUpdate': {
      put: {
        tags: ['File System'],
        summary: 'Submit a file system update.',
        description: 'Stores a single fs entry update for a project and returns the newest entry for that document.',
        requestBody: {
          required: true,
          content: { 'application/json': { schema: { "$ref": '#/components/schemas/PutFsUpdateRequest' } } },
        },
        responses: {
          '200': { description: 'Update stored successfully.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/PutFsUpdateResponse' } } } },
          '400': { description: 'Invalid input.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
        },
      },
    },
  },
}
