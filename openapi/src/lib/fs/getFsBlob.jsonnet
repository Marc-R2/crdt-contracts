{
  components: {
    schemas: {
      GetFsBlobRequest: {
        type: 'object',
        required: ['hash'],
        properties: {
          hash: {
            type: 'string',
            description: 'Hash of the file content to retrieve.'
          }
        }
      },
      GetFsBlobResponse: {
        type: 'object',
        required: ['blob'],
        properties: {
          blob: {
            type: 'string',
            description: 'Base64-encoded file content.'
          }
        }
      }
    }
  },
  paths: {
    '/fs/getBlob': {
      post: {
        tags: ['File System'],
        summary: 'Get the blob for a file hash.',
        description: 'Retrieves the blob (base64-encoded) for the given file hash.',
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: { '$ref': '#/components/schemas/GetFsBlobRequest' }
            }
          }
        },
        responses: {
          '200': {
            description: 'Newest fs entry and blob retrieved successfully.',
            content: {
              'application/json': {
                schema: { '$ref': '#/components/schemas/GetFsBlobResponse' }
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
          },
          '404': {
            description: 'Blob not found for the given hash.',
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
