{
  components: {
    schemas: {
      # Registration of the flow schemas that reference the shared Error
      # envelope; the bodies stay intentionally small/inline because the
      # paste-token protocol is one field deep on both sides.
    },
  },

  paths: {
    '/auth/device-tokens': {
      post: {
        tags: ['Auth'],
        summary: 'Mint a single-use device token.',
        description: "Mints a single-use paste/device token (5 min TTL). Only the SHA-256 hash is persisted; the plaintext code is returned exactly once. Authenticated via bearer token OR the httpOnly portal session cookie. The Obsidian plugin uses the returned code with POST /auth/exchange to obtain a full session.",
        requestBody: {
          required: false,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                properties: {
                  label: { type: 'string', description: 'Optional human-readable label for the device token.' },
                },
              },
            },
          },
        },
        responses: {
          '200': {
            description: 'Token minted.',
            content: {
              'application/json': {
                schema: {
                  type: 'object',
                  properties: {
                    code: { type: 'string', description: 'One-time plaintext code (shown only here).' },
                  },
                },
              },
            },
          },
          '401': { description: 'Missing or invalid session.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
        },
      },
    },
    '/auth/exchange': {
      post: {
        tags: ['Auth'],
        summary: 'Exchange a device code for a session.',
        description: "Exchanges a paste/device code for a full session token. Validates existence, single-use and 5-minute TTL, marks the token used, and creates a session row carrying the device label. Rate-limited to 5 attempts per minute per IP (brute-force bound).",
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['code'],
                properties: {
                  code: { type: 'string' },
                  deviceLabel: { type: 'string', description: 'Label recorded on the created session (shown in the account sessions list).' },
                },
              },
            },
          },
        },
        responses: {
          '200': {
            description: 'Session created.',
            content: {
              'application/json': {
                schema: {
                  type: 'object',
                  properties: {
                    token: { type: 'string', description: 'New session_ token.' },
                  },
                },
              },
            },
          },
          '400': { description: 'Missing code / invalid JSON.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '401': { description: 'Invalid, used, or expired code.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '429': { description: 'Too many exchange attempts.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
        },
      },
    },
    '/auth/logout': {
      post: {
        tags: ['Auth'],
        summary: 'Revoke the calling session (logout).',
        description: "Revokes the caller's session (if authenticated) and clears the httpOnly portal session cookie. Alias: POST /account/logout. Idempotent: answering with {ok:true} and a cleared cookie even without a valid session.",
        responses: {
          '200': {
            description: 'Logout processed.',
            content: {
              'application/json': {
                schema: {
                  type: 'object',
                  properties: {
                    ok: { type: 'boolean', description: 'Always true.' },
                  },
                },
              },
            },
          },
        },
      },
    },
  },
}
