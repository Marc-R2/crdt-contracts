{
  components: {
    schemas: {
      // Project payloads reuse the shared ProjectData schema; the member
      // shape is kept inline because only this handler exposes it.
      ProjectMember: {
        type: 'object',
        properties: {
          projectId: { type: 'string' },
          userId: { type: 'string' },
          role: { type: 'string', description: "Member role: 'owner' | 'editor' | 'viewer'." },
          createdAt: { type: 'integer', description: 'Unix ms.' },
          addedBy: { type: 'string', nullable: true },
          email: { type: 'string', nullable: true },
          name: { type: 'string', nullable: true },
          avatarUrl: { type: 'string', nullable: true },
        },
      },
      ProjectUserSearchResult: {
        type: 'object',
        properties: {
          userId: { type: 'string' },
          email: { type: 'string', nullable: true },
          name: { type: 'string', nullable: true },
          avatarUrl: { type: 'string', nullable: true },
        },
      },
    },
  },

  paths: {
    '/projects': {
      get: {
        tags: ['Projects'],
        summary: "List the authenticated user's projects.",
        description: 'Returns the project memberships (raw array) of the authenticated user. Auth: bearer token OR httpOnly portal session cookie.',
        responses: {
          '200': {
            description: 'Project list returned (a bare JSON array).',
            content: {
              'application/json': {
                schema: {
                  type: 'array',
                  items: { type: 'object' },
                },
              },
            },
          },
          '401': { description: 'Missing or invalid session.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
        },
      },
      post: {
        tags: ['Projects'],
        summary: 'Create a new project.',
        description: 'Creates a project owned by the authenticated user; the user becomes the primary owner. Name is required (non-empty after trim). The created project entity is returned.',
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['name'],
                properties: {
                  name: { type: 'string', description: 'Project name (non-empty after trim).' },
                },
              },
            },
          },
        },
        responses: {
          '200': {
            description: 'Project created.',
            content: { 'application/json': { schema: { "$ref": '#/components/schemas/ProjectData' } } },
          },
          '400': { description: 'Invalid JSON or missing name.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '401': { description: 'Missing or invalid session.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '413': { description: 'Payload Too Large.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
        },
      },
    },
    '/account/projects': {
      get: {
        tags: ['Account'],
        summary: "List the user's projects.",
        description: "Lists the authenticated user's project memberships with owner/editor/viewer role and member count (portal view).",
        responses: {
          '200': {
            description: 'Project list returned.',
            content: {
              'application/json': {
                schema: {
                  type: 'object',
                  properties: {
                    projects: {
                      type: 'array',
                      items: {
                        type: 'object',
                        properties: {
                          id: { type: 'string' },
                          projectId: { type: 'string' },
                          name: { type: 'string' },
                          role: { type: 'string' },
                          memberCount: { type: 'integer' },
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
    '/account/users/search': {
      get: {
        tags: ['Account'],
        summary: 'Search users for member invitations.',
        description: "Searches users by email/name/userId for the members-management UI. PRIVILEGE-GATED + rate-limited: only project owners/editors may search; the `projectId` query param is REQUIRED so plain account holders and viewers get 403 (no global user enumeration, F5).",
        parameters: [
          { name: 'projectId', 'in': 'query', required: true, description: 'Project whose owner/editor is searching.', schema: { type: 'string' } },
          { name: 'q', 'in': 'query', required: false, description: 'Case-insensitive substring over email/name or exact userId; max 10 results.', schema: { type: 'string' } },
        ],
        responses: {
          '200': {
            description: 'Matching users (at most 10).',
            content: {
              'application/json': {
                schema: {
                  type: 'object',
                  properties: {
                    users: {
                      type: 'array',
                      items: { "$ref": '#/components/schemas/ProjectUserSearchResult' },
                    },
                  },
                },
              },
            },
          },
          '400': { description: 'projectId is required.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '401': { description: 'Missing or invalid session.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '403': { description: 'Only project owners and editors can search users.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '404': { description: 'Project not found.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '429': { description: 'Too Many Requests.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
        },
      },
    },
    '/account/projects/{projectId}/members': {
      get: {
        tags: ['Members'],
        summary: 'List the project members.',
        description: "Lists all members of the given project (role + profile details). Requires project access; non-members get 403.",
        parameters: [
          { name: 'projectId', 'in': 'path', required: true, schema: { type: 'string' } },
        ],
        responses: {
          '200': {
            description: 'Members returned.',
            content: {
              'application/json': {
                schema: {
                  type: 'object',
                  properties: {
                    members: {
                      type: 'array',
                      items: { "$ref": '#/components/schemas/ProjectMember' },
                    },
                  },
                },
              },
            },
          },
          '401': { description: 'Missing or invalid session.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '403': { description: 'Forbidden (no project access).', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '404': { description: 'Project not found.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
        },
      },
      post: {
        tags: ['Members'],
        summary: 'Invite a project member.',
        description: "Adds a member with role owner/editor/viewer (default editor). Only project owners and editors may invite; only owners may grant the owner role. Either `userId` or `email` must be provided — an unknown email registers a stub user. Returns the created member.",
        parameters: [
          { name: 'projectId', 'in': 'path', required: true, schema: { type: 'string' } },
        ],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                properties: {
                  userId: { type: 'string' },
                  email: { type: 'string' },
                  role: { type: 'string', description: "Default 'editor'." },
                },
              },
            },
          },
        },
        responses: {
          '201': {
            description: 'Member added.',
            content: {
              'application/json': {
                schema: {
                  type: 'object',
                  properties: {
                    success: { type: 'boolean' },
                    member: { "$ref": '#/components/schemas/ProjectMember' },
                  },
                },
              },
            },
          },
          '400': { description: 'Invalid JSON or missing userId/email.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '401': { description: 'Missing or invalid session.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '403': { description: 'Only owners/editors may invite (owner role for owners only).', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '404': { description: 'Project not found.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '405': { description: 'Method Not Allowed.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
        },
      },
    },
    '/account/projects/{projectId}/members/me': {
      get: {
        tags: ['Members'],
        summary: "Get the caller's own project role.",
        description: "Returns `{role}` for an authenticated PROJECT MEMBER (the portal UI self-role lookup); non-members get 403. Kept before the generic member branches so 'me' is never mistaken for a userId.",
        parameters: [
          { name: 'projectId', 'in': 'path', required: true, schema: { type: 'string' } },
        ],
        responses: {
          '200': {
            description: 'Role returned.',
            content: {
              'application/json': {
                schema: {
                  type: 'object',
                  required: ['role'],
                  properties: {
                    role: { type: 'string', description: "'owner' | 'editor' | 'viewer'." },
                  },
                },
              },
            },
          },
          '401': { description: 'Missing or invalid session.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '403': { description: 'Forbidden (not a member).', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '404': { description: 'Project not found.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
        },
      },
    },
    '/account/projects/{projectId}/members/{userId}': {
      delete: {
        tags: ['Members'],
        summary: 'Remove a project member.',
        description: "Removes a member. Only an owner (or the member removing themselves) may do this; the primary project owner cannot be removed. Returns {success:true} on 200 (chosen over 204 for symmetry with the POST).",
        parameters: [
          { name: 'projectId', 'in': 'path', required: true, schema: { type: 'string' } },
          { name: 'userId', 'in': 'path', required: true, description: 'Member userId to remove.', schema: { type: 'string' } },
        ],
        responses: {
          '200': {
            description: 'Member removed.',
            content: {
              'application/json': {
                schema: {
                  type: 'object',
                  properties: {
                    success: { type: 'boolean' },
                  },
                },
              },
            },
          },
          '400': { description: 'Cannot remove primary project owner.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '401': { description: 'Missing or invalid session.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '403': { description: 'Forbidden (not owner and not self).', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
          '404': { description: 'Project not found.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/Error' } } } },
        },
      },
    },
  },
}
