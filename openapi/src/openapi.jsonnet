local Get = import 'get.jsonnet';
local ProjectRegister = import 'project/register.jsonnet';

std.manifestYamlDoc(
  {
    openapi: '3.0.2',
    info: {
      title: 'Obsidian CRDT Sync Server API',
      description: "REST API for the Obsidian CRDT Sync Server.\n\nThis server enables real-time collaboration using Yjs as a CRDT. Documents are synchronized over WebSocket and persisted with SQLite.\nThe REST API provides endpoints for authentication, project management, filetree synchronization, and more.\nPlanned is also support for larger files using chunking and binary data transfer.\n\n**Features:**\n- WebSocket-based real-time synchronization\n- SQLite persistence with Hocuspocus\n- Awareness support (cursor, users, selection)\n- Yjs CRDT for conflict-free collaboration\n- Register and manage projects\n- Update and retrieve filetrees of projects\n- Startup synchronization of projects\n\nThe WebSocket server runs on port 1234 by default.\n",
      version: '0.0.1',
    },

    servers: [
      {
        url: 'http://{host}:{port}',
        description: 'HTTP REST API',
        variables: {
          host: { default: 'localhost', description: 'Server host' },
          port: { default: '1234', description: 'HTTP port' },
        },
      },
      {
        url: 'ws://{host}:{port}',
        description: 'WebSocket Server (for Yjs synchronization)',
        variables: {
          host: { default: 'localhost', description: 'Server host' },
          port: { default: '1234', description: 'WebSocket port' },
        },
      },
    ],

    components: {
      schemas: (
        {
          Error: {
            type: 'object',
            properties: {
              message: { type: 'string', description: 'Message describing the error.', example: 'A brief description of the error.' },
              errorCode: { type: 'number', description: 'A 5-digit error code uniquely identifying this particular type of error.', example: 40149 },
            },
          },
        }
        + ProjectRegister.components.schemas
      ),
    },

    paths: (
      {
        '/': {
          get: {
            tags: ['System'],
            summary: 'Returns basic server information.',
            description: 'Provides basic information about the CRDT Sync Server. This endpoint can be used to check server availability.',
            responses: {
              '200': {
                description: 'Success',
                content: {
                  'application/json': {
                    schema: {
                      type: 'object',
                      properties: {
                        ok: { type: 'string', description: "'OK'" },
                        service: { type: 'string', description: "'Obsidian CRDT Sync Server'" },
                        versions: {
                          type: 'object',
                          properties: {
                            hocuspocus: { type: 'string', description: 'Hocuspocus server version' },
                            yjs: { type: 'string', description: 'Yjs version' },
                            'self': { type: 'string', description: 'Server version' },
                          },
                        },
                      },
                    },
                  },
                },
              },
            },
          },
        },

        '/openapi.yaml': {
          get: {
            tags: ['System'],
            summary: 'Returns OpenAPI YAML document describing the capabilities of this API.',
            responses: { '200': { description: 'Success' } },
          },
        },
      }
      + ProjectRegister.paths # /project/register
    ),
  },
  quote_keys=false,
  indent_array_in_object=true,
)
