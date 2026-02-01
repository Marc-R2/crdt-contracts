{
  components: {
    schemas: {
      PutFsUpdateRequest: {
        type: 'object',
        required: ['update'],
        properties: {
          update: { "$ref": '#/components/schemas/FsEntry' },
        },
      },
      
      PutFsUpdateResponse: {
        type: 'object',
        required: ['newest'],
        properties: {
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
        description: 'Stores a single fs entry update for a project and returns the newest entry for that document. Client stamp is validated; LWW uses stamp and server write time to break ties.',
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
