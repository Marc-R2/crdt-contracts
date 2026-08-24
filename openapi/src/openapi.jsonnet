local Index = import 'index.jsonnet';

# The old /fs/* endpoints (getSync, getUpdates, putUpdate, getBlob,
# getBlobInfo, putBlob) have been removed. Structure sync is now via
# Yjs Hocuspocus; blob sync is via the new /blobs/* streaming endpoints
# (handled by blobRouteHandler.ts, not the generated API module).

local getSnapshot = import 'snapshot/getSnapshot.jsonnet';
local getSnapshotUpdates = import 'snapshot/getSnapshotUpdates.jsonnet';
local listSnapshots = import 'snapshot/listSnapshots.jsonnet';
local docStatus = import 'snapshot/docStatus.jsonnet';

std.manifestYamlDoc(
  {
    openapi: '3.0.2',
    info: {
      title: 'Obsidian CRDT Sync Server API',
      description: "REST API for the Obsidian CRDT Sync Server.\n\nThis server enables real-time collaboration using Yjs as a CRDT. Documents are synchronized over WebSocket and persisted with SQLite.\nThe REST API provides endpoints for project management, snapshot access, and blob transfer.\nBlob upload/download uses raw binary streaming on /blobs/* endpoints (not part of this generated API — see blobRouteHandler.ts).\n\n**Features:**\n- WebSocket-based real-time synchronization\n- SQLite persistence with Hocuspocus\n- Awareness support (cursor, users, selection)\n- Yjs CRDT for conflict-free collaboration\n- Register and manage projects\n- Raw binary blob sync with hash verification and chunked upload\n\nThe WebSocket server runs on port 1234 by default.\n",
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
              message: { type: 'string', description: 'Message describing the error.' },
              errorCode: { type: 'number', description: 'A 5-digit error code uniquely identifying this particular type of error.', example: 40149 },
            },
          },
        }
        + Index.components.schemas

        + getSnapshot.components.schemas
        + getSnapshotUpdates.components.schemas
        + listSnapshots.components.schemas
        + docStatus.components.schemas
      ),

      securitySchemes: {
        BearerAuth: {
            type: 'http',
            scheme: 'bearer',
            description: 'Opaque bearer token issued by the server (not a JWT).',
        },
      },
    },

    security: [ { BearerAuth: [] } ],

    paths: (
      {}
      + Index.paths

      # /snapshot/*
      + getSnapshot.paths
      + getSnapshotUpdates.paths
      + listSnapshots.paths

      # /projects/doc-status (doc-status API)
      + docStatus.paths

      # /blobs/* endpoints are NOT defined here — they use raw binary
      # streaming (application/octet-stream) and are handled by
      # blobRouteHandler.ts, not the generated NestJS controllers.
    ),
  },
  quote_keys=false,
  indent_array_in_object=true,
)
