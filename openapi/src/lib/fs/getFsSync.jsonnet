{
  components: {
    schemas: {
      GetFsSyncRequest: {
        type: 'object',
        required: ['projectId', 'entries'],
        properties: {
          projectId: { "$ref": '#/components/schemas/ProjectId' },
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
          projectId: { "$ref": '#/components/schemas/ProjectId' },
          updates: {
            type: 'array',
            description: 'List of server-side fs entry updates compared to the client entries.',
            items: { "$ref": '#/components/schemas/FsEntry' },
          },
        },
      },
    },
  },

  paths: {
    '/fs/getSync': {
      post: {
        tags: ['File System'],
        summary: 'Get file system sync updates.',
        description: 'Compares client entries against the server state and returns the fs-entry updates needed to sync. LWW uses client stamp with server validation; ties are resolved by server write time.',
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
