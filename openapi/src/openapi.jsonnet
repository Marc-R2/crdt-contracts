local Index = import 'index.jsonnet';

local getSnapshot = import 'snapshot/getSnapshot.jsonnet';
local getSnapshotUpdates = import 'snapshot/getSnapshotUpdates.jsonnet';
local listSnapshots = import 'snapshot/listSnapshots.jsonnet';
local docStatus = import 'snapshot/docStatus.jsonnet';

local blobs = import 'blobs/blobs.jsonnet';
local history = import 'history/history.jsonnet';
local vcs = import 'vcs/vcs.jsonnet';
local oidcAuth = import 'oidc/auth.jsonnet';
local oidcAccount = import 'oidc/account.jsonnet';
local oidcProjects = import 'oidc/projects.jsonnet';
local diagnostics = import 'diagnostics/diagnostics.jsonnet';

std.manifestYamlDoc(
  {
    openapi: '3.0.2',
    info: {
      title: 'Obsidian CRDT Sync Server API',
      description: "REST API for the Obsidian CRDT Sync Server.\n\nThis server enables real-time collaboration using Yjs as a CRDT. Documents are synchronized over WebSocket and persisted with SQLite.\nThe REST API covers the generated JSON controllers (snapshot/doc-status/system), the paste-token + account routes, the raw binary blob transfer (/blobs/*, blobRouteHandler.ts, not the generated NestJS controllers), the history capture API (raw binary chunks) and the experimental Git VCS routes.\n\n**Features:**\n- WebSocket-based real-time synchronization\n- SQLite persistence with Hocuspocus\n- Awareness support (cursor, users, selection)\n- Yjs CRDT for conflict-free collaboration\n- Register and manage projects\n- Raw binary blob sync with hash verification and chunked upload\n\nThe WebSocket server runs on port 1234 by default.\n",
      version: '0.1.0',
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
        + blobs.components.schemas
        + history.components.schemas
        + vcs.components.schemas
        + oidcAuth.components.schemas
        + oidcAccount.components.schemas
        + oidcProjects.components.schemas
        + diagnostics.components.schemas
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

      # /blob paths (raw binary streaming, handled by blobRouteHandler.ts, not
      # the generated NestJS controllers) and the /projects/... history (raw
      # binary chunks) and Git-VCS subpaths are documented in their own lib
      # files so this contract stays the single source of truth for every
      # served REST route (the /oidc/mock-login corner notes its deploy-gating).
      + blobs.paths
      + history.paths
      + vcs.paths
      + oidcAuth.paths
      + oidcAccount.paths
      + oidcProjects.paths
      + diagnostics.paths
    ),
  },
  quote_keys=false,
  indent_array_in_object=true,
)
