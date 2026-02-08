{
  components: {
    schemas: {
      PutFsBlobRequest: {
        type: 'object',
        required: ['hash', 'blob'],
        properties: {
          hash: {
			type: 'string',
			description: 'Hash of the file content for this update.',
		  },
		  blob: {
			type: 'string',
			description: 'Base64-encoded file content for this update. Optional if the server already has the blob from a previous update with the same hash.',
		  }
        },
      },
    },
  },

  paths: {
    '/fs/putBlob': {
      put: {
        tags: ['File System'],
        summary: 'Store a file blob and get the newest fs entry.',
        description: 'Stores a file blob on the server and returns the newest fs entry for the corresponding hash. Rejects if the hash is invalid or if the blob already exists.',
        requestBody: {
          required: true,
          content: { 'application/json': { schema: { "$ref": '#/components/schemas/PutFsBlobRequest' } } },
        },
        responses: {
          '200': { description: 'Blob stored successfully.' },
          '400': { description: 'Invalid input.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '409': { description: 'Conflict - blob already exists with the same hash.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } }}
        }
      }
    }
  }
}
