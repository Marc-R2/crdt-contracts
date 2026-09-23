{
  components: {
    schemas: {
      // Diagnostics payloads are free-form enough that only the validated
      // top-level fields are documented here (validator in bugReport /
      // telemetryHandler; everything else is stored as opaque payload_json).
      BugReportRequest: {
        type: 'object',
        required: ['title'],
        properties: {
          id: {
            type: 'string',
            description: 'Optional client-supplied id (bug-<1..64 id-chars>); generated when missing.',
            pattern: '^bug-[a-zA-Z0-9_-]{1,64}$',
          },
          title: { type: 'string', maxLength: 200 },
          description: { type: 'string', nullable: true },
          clientVersion: { type: 'string', nullable: true },
          platform: { type: 'string', nullable: true },
          logs: {
            description: 'String or string array.',
            nullable: true,
          },
          systemInfo: { type: 'object', nullable: true },
        },
      },
      OkAckResponse: {
        type: 'object',
        required: ['ok'],
        properties: {
          ok: { type: 'boolean' },
          id: { type: 'string', nullable: true },
          deleted: { type: 'integer', nullable: true, description: 'Row count (GDPR delete routes).' },
        },
      },
    },
  },

  paths: {
    '/api/bug-reports': {
      post: {
        tags: ['Diagnostics'],
        summary: 'Submit a bug report.',
        description: 'Stores an authenticated bug report (512 KB body cap). Only the validated top-level fields are stored structured; the full payload is kept as payload_json.',
        requestBody: {
          required: true,
          content: { 'application/json': { schema: { "$ref": '#/components/schemas/BugReportRequest' } } },
        },
        responses: {
          '201': {
            description: 'Report stored.',
            content: {
              'application/json': {
                schema: {
                  type: 'object',
                  required: ['ok', 'id'],
                  properties: {
                    ok: { type: 'boolean' },
                    id: { type: 'string' },
                  },
                },
              },
            },
          },
          '400': { description: 'Validation failure.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '401': { description: 'Authentication required.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '413': { description: 'Report payload exceeds 512 KB.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
        },
      },
      delete: {
        tags: ['Diagnostics'],
        summary: 'Delete bug reports (GDPR).',
        description: 'User-owned deletion: without an id path component every report of the calling user is removed; with `/api/bug-reports/{id}` only that one (user-owned).',
        parameters: [
          { name: 'id', 'in': 'path', required: false, description: 'Optional report id (user-owned delete); omitted = delete all own reports.', schema: { type: 'string' } },
        ],
        responses: {
          '200': {
            description: 'Deletion result.',
            content: { 'application/json': { schema: { "$ref": '#/components/schemas/OkAckResponse' } } },
          },
          '401': { description: 'Authentication required.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
        },
      },
    },
    '/api/telemetry': {
      post: {
        tags: ['Diagnostics'],
        summary: 'Ingest a telemetry record.',
        description: 'Stores an authenticated telemetry record (bucketDate must be YYYY-MM-DD, K1). Optional feature/scale/health counters are validated as numeric objects; the full payload is kept as payload_json.',
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['bucketDate'],
                properties: {
                  bucketDate: { type: 'string', description: 'ISO date (YYYY-MM-DD) bucket key.', pattern: '^\\d{4}-\\d{2}-\\d{2}$' },
                  clientVersion: { type: 'string', nullable: true },
                  platform: { type: 'string', nullable: true },
                },
              },
            },
          },
        },
        responses: {
          '200': {
            description: 'Record stored.',
            content: {
              'application/json': {
                schema: {
                  type: 'object',
                  required: ['ok', 'id'],
                  properties: {
                    ok: { type: 'boolean' },
                    id: { type: 'string' },
                  },
                },
              },
            },
          },
          '400': { description: 'Validation failure.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '401': { description: 'Authentication required / invalid session.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
        },
      },
      delete: {
        tags: ['Diagnostics'],
        summary: 'Delete telemetry records (GDPR).',
        description: 'Removes every telemetry record of the calling user and returns the row count.',
        responses: {
          '200': {
            description: 'Deletion result.',
            content: { 'application/json': { schema: { "$ref": '#/components/schemas/OkAckResponse' } } },
          },
          '401': { description: 'Authentication required.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
        },
      },
    },
    '/oidc/login': {
      get: {
        tags: ['Auth'],
        summary: 'OIDC sign-in (mock form or provider redirect).',
        description: 'With a real provider configured: redirects to the IdP authorization endpoint. Without one and with OIDC_DISABLE_MOCK_LOGIN set: fails closed with 503. Otherwise serves the mock login form HTML (dev deployments only). `redirect_uri` must be in the allow list (F1); `state` is echoed through.',
        parameters: [
          { name: 'state', 'in': 'query', required: false, description: 'Opaque OIDC state echoed by the chosen flow.', schema: { type: 'string' } },
          { name: 'redirect_uri', 'in': 'query', required: false, description: 'Portal redirect target (allow-listed, F1).', schema: { type: 'string' } },
        ],
        responses: {
          '200': { description: 'Mock login form (HTML, dev-only).', content: { 'text/html': { schema: { type: 'string' } } } },
          '302': { description: 'Redirect to the real OIDC provider (or back to the portal after mock login POST).' },
          '400': { description: 'redirect_uri is not allowed.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '503': { description: 'No OIDC provider configured and mock disabled (fail closed, F2/P0).', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
        },
      },
      post: {
        tags: ['Auth'],
        summary: 'Mock OIDC login submit (dev-only).',
        description: 'Form/URL-encoded submit of the mock login. Creates/updates the user, issues a session_ token (30 d), seeds a Default Project when needed, sets the httpOnly session cookie (the token never travels in the URL) and 302-redirects to redirect_uri. With a real provider configured this endpoint answers 405; with OIDC_DISABLE_MOCK_LOGIN it fails closed with 503.',
        requestBody: {
          required: true,
          content: {
            'application/x-www-form-urlencoded': {
              schema: {
                type: 'object',
                properties: {
                  userId: { type: 'string', description: 'Defaults to a generated user_ id.' },
                  name: { type: 'string', description: 'Defaults to "Mock User".' },
                  email: { type: 'string', description: 'Defaults to user@example.com.' },
                  redirect_uri: { type: 'string', description: 'Must be allow-listed (F1).' },
                },
              },
            },
          },
        },
        responses: {
          '302': { description: 'Redirect to the portal with the session cookie set.' },
          '400': { description: 'redirect_uri is not allowed.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '405': { description: 'Real provider configured — use it instead of the mock (FR-AUTH-003).', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '503': { description: 'Mock disabled (fail closed).', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
        },
      },
    },
    '/oidc/callback': {
      get: {
        tags: ['Auth'],
        summary: 'Real-OIDC authorization-code callback.',
        description: 'The IdP redirects here with the authorization code; the server exchanges it, provisions the user (profile picture claim initializes avatarUrl) and redirects/authenticates to the portal. Answers 404 when no real provider is configured.',
        parameters: [
          { name: 'code', 'in': 'query', required: false, description: 'Authorization code from the IdP.', schema: { type: 'string' } },
          { name: 'state', 'in': 'query', required: false, schema: { type: 'string' } },
        ],
        responses: {
          '302': { description: 'Redirect to the portal with the session cookie set.' },
          '404': { description: 'No real OIDC provider configured.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
        },
      },
    },
  },
}
