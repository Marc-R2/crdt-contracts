{
  components: {
    schemas: {
      PutFsUpdateRequest: {
        type: 'object',
        required: ['projectId', 'update'],
        properties: {
          projectId: { type: 'string', description: 'The id of the project.' },
          update: { "$ref": '#/components/schemas/FsEntry' },
        },
      },
      
      PutFsUpdateResponse: {
        type: 'object',
        required: ['projectId', 'newest'],
        properties: {
          projectId: { type: 'string', description: 'The unique project UUID-V4.' },
          newest: { "$ref": '#/components/schemas/FsEntry' }
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
    '/fs/putUpdate': {
      put: {
        tags: ['File System'],
        summary: 'Submit a file system update.',
        description: 'Stores a single fs-entry update for a project and returns the newest entry for that document.',
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
