{
  components: {
    schemas: {
      GetFsBlobInfoRequest: {
        type: 'object',
        required: ['hash'],
        properties: {
          hash: {
            type: 'string',
            description: 'Hash of the file content to check.'
          }
        }
      },
      GetFsBlobInfoResponse: {
        type: 'object',
        required: ['exists'],
        properties: {
          exists: {
            type: 'boolean',
            description: 'True if the blob exists on the server.'
          },
          newest: {
            '$ref': '#/components/schemas/FsEntry',
            description: 'The newest fs entry for the blob, if available.'
          }
        }
      }
    }
  },
  paths: {
    '/fs/getBlobInfo': {
      post: {
        tags: ['File System'],
        summary: 'Get blob info and check availability by hash.',
        description: 'Checks if a blob exists on the server for the given hash (provided in the request body) and returns info about the newest fs entry. Use this endpoint before uploading a blob.',
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: { '$ref': '#/components/schemas/GetFsBlobInfoRequest' }
            }
          }
        },
        responses: {
          '200': {
            description: 'Blob info retrieved successfully.',
            content: {
              'application/json': {
                schema: { '$ref': '#/components/schemas/GetFsBlobInfoResponse' }
              }
            }
          },
          '400': {
            description: 'Invalid input.',
            content: {
              'application/json': {
                schema: { '$ref': '#/components/schemas/Error' }
              }
            }
          }
        }
      }
    }
  }
}
