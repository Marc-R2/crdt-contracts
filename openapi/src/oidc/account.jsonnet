{
  components: {
    schemas: {
      // NOTE: schemas stay minimal/inline (the account payloads are flat
      // portal shapes; the committed contract documents them the same way).
    },
  },

  paths: {
    '/account': {
      get: {
        tags: ['Account'],
        summary: "Get the authenticated user's profile.",
        description: "Returns the authenticated user's profile. Auth: bearer token OR httpOnly portal session cookie.",
        responses: {
          '200': {
            description: 'Profile returned.',
            content: {
              'application/json': {
                schema: {
                  type: 'object',
                  properties: {
                    id: { type: 'string' },
                    email: { type: 'string', nullable: true },
                    name: { type: 'string', nullable: true },
                    avatarUrl: { type: 'string', nullable: true },
                    googlePicture: { type: 'string', nullable: true },
                  },
                },
              },
            },
          },
          '401': { description: 'Missing or invalid session.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
        },
      },
    },
    '/account/profile': {
      patch: {
        tags: ['Account'],
        summary: "Update the user's profile.",
        description: "Updates the authenticated user's display name / avatar URL. Both fields optional; name must be 1-100 chars, avatarUrl a valid http(s) URL (max 512 chars).",
        requestBody: {
          required: false,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                properties: {
                  name: { type: 'string' },
                  avatarUrl: { type: 'string' },
                },
              },
            },
          },
        },
        responses: {
          '200': {
            description: 'Updated profile returned.',
            content: {
              'application/json': {
                schema: {
                  type: 'object',
                  properties: {
                    id: { type: 'string' },
                    email: { type: 'string', nullable: true },
                    name: { type: 'string', nullable: true },
                    avatarUrl: { type: 'string', nullable: true },
                    googlePicture: { type: 'string', nullable: true },
                  },
                },
              },
            },
          },
          '400': { description: 'Validation failure.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '401': { description: 'Missing or invalid session.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
        },
      },
    },
    '/account/sessions': {
      get: {
        tags: ['Account'],
        summary: "List the user's active sessions.",
        description: "Lists the authenticated user's active sessions (revoked ones are excluded). The calling session is marked isCurrent=true. Own-session revocation is not allowed.",
        responses: {
          '200': {
            description: 'Session list returned.',
            content: {
              'application/json': {
                schema: {
                  type: 'object',
                  properties: {
                    sessions: {
                      type: 'array',
                      items: {
                        type: 'object',
                        properties: {
                          id: { type: 'string', description: 'Opaque sid (never the raw token).' },
                          deviceLabel: { type: 'string', nullable: true },
                          lastSeenAt: { type: 'integer', nullable: true, description: 'Unix ms.' },
                          createdAt: { type: 'integer', nullable: true, description: 'Unix ms.' },
                          isCurrent: { type: 'boolean' },
                        },
                      },
                    },
                  },
                },
              },
            },
          },
          '401': { description: 'Missing or invalid session.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
        },
      },
    },
    '/account/sessions/current': {
      patch: {
        tags: ['Account'],
        summary: 'Rename the calling session.',
        description: "Renames the CALLING session's device label (device transfers a new name). The target session is resolved from bearer-or-cookie auth, never from the body. Returns 200 {deviceLabel} (chosen over 204 so the client gets the normalized/trimmed value back).",
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                properties: {
                  deviceLabel: { type: 'string', description: 'New label, 1-100 characters after trimming.' },
                },
              },
            },
          },
        },
        responses: {
          '200': {
            description: 'Renamed; the normalized label is returned.',
            content: {
              'application/json': {
                schema: {
                  type: 'object',
                  properties: {
                    deviceLabel: { type: 'string' },
                  },
                },
              },
            },
          },
          '400': { description: 'deviceLabel must be a string of 1-100 characters.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '401': { description: 'Missing or invalid session.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '404': { description: 'Current session not found.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
        },
      },
    },
    '/account/sessions/{id}': {
      delete: {
        tags: ['Account'],
        summary: 'Revoke another session.',
        description: "Revokes another active session of the authenticated user (never the current one). Revocation invalidates the session cache immediately.",
        parameters: [
          {
            name: 'id',
            'in': 'path',
            required: true,
            description: 'Opaque sid of the target session (the raw token is never accepted).',
            schema: { type: 'string' },
          },
        ],
        responses: {
          '204': { description: 'Session revoked.' },
          '400': { description: 'Tried to revoke the current session.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '401': { description: 'Missing or invalid session.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '404': { description: 'Session not found / not owned by the user.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
        },
      },
    },
  },
}
