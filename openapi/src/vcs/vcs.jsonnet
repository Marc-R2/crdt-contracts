{
  components: {
    schemas: {
      VcsFileChange: {
        type: 'object',
        properties: {
          path: { type: 'string' },
          status: { type: 'string', description: "'modified' | 'added' | 'deleted' | 'untracked' | 'renamed'." },
          oldPath: { type: 'string', nullable: true },
          staged: { type: 'boolean', nullable: true },
          additions: { type: 'integer', nullable: true },
          deletions: { type: 'integer', nullable: true },
        },
      },
      VcsBranch: {
        type: 'object',
        properties: {
          name: { type: 'string' },
          isCurrent: { type: 'boolean' },
          headCommit: { type: 'string' },
          upstream: { type: 'string', nullable: true },
        },
      },
      VcsTag: {
        type: 'object',
        properties: {
          name: { type: 'string' },
          commit: { type: 'string' },
          message: { type: 'string', nullable: true },
        },
      },
      VcsRemote: {
        type: 'object',
        properties: {
          name: { type: 'string' },
          url: { type: 'string' },
          fetchUrl: { type: 'string', nullable: true },
          pushUrl: { type: 'string', nullable: true },
        },
      },
      VcsStatus: {
        type: 'object',
        properties: {
          branch: { type: 'string' },
          headCommit: { type: 'string', nullable: true },
          headMessage: { type: 'string' },
          ahead: { type: 'integer' },
          behind: { type: 'integer' },
          uncommitted: { type: 'array', items: { "$ref": '#/components/schemas/VcsFileChange' } },
          branches: { type: 'array', items: { "$ref": '#/components/schemas/VcsBranch' } },
          tags: { type: 'array', items: { "$ref": '#/components/schemas/VcsTag' } },
          remotes: { type: 'array', items: { "$ref": '#/components/schemas/VcsRemote' } },
        },
      },
      VcsCommit: {
        type: 'object',
        properties: {
          sha: { type: 'string' },
          shortSha: { type: 'string' },
          parents: { type: 'array', items: { type: 'string' } },
          author: { type: 'string' },
          authorEmail: { type: 'string' },
          date: { type: 'integer', description: 'Unix timestamp (ms).' },
          message: { type: 'string' },
          branches: { type: 'array', items: { type: 'string' } },
          tags: { type: 'array', items: { type: 'string' } },
        },
      },
      VcsCommitDetails: {
        type: 'object',
        properties: {
          sha: { type: 'string' },
          shortSha: { type: 'string' },
          parents: { type: 'array', items: { type: 'string' } },
          author: { type: 'string' },
          authorEmail: { type: 'string' },
          date: { type: 'integer' },
          message: { type: 'string' },
          branches: { type: 'array', items: { type: 'string' } },
          tags: { type: 'array', items: { type: 'string' } },
          files: { type: 'array', items: { "$ref": '#/components/schemas/VcsFileChange' } },
          manifest: { type: 'object', nullable: true },
        },
      },
      VcsCommitRequest: {
        type: 'object',
        required: ['message'],
        properties: {
          message: { type: 'string' },
          filePaths: {
            type: 'array',
            items: { type: 'string' },
            description: 'Optional path filter for a partial commit.',
          },
        },
      },
      VcsBranchRequest: {
        type: 'object',
        required: ['name'],
        properties: {
          name: { type: 'string' },
          startPoint: { type: 'string', nullable: true },
        },
      },
      VcsCheckoutRequest: {
        type: 'object',
        required: ['name'],
        properties: {
          name: { type: 'string' },
        },
      },
      VcsMergeRequest: {
        type: 'object',
        required: ['name'],
        properties: {
          name: { type: 'string' },
          message: { type: 'string', nullable: true },
        },
      },
      VcsTagRequest: {
        type: 'object',
        required: ['name'],
        properties: {
          name: { type: 'string' },
          commitSha: { type: 'string', nullable: true },
          message: { type: 'string', nullable: true },
        },
      },
      VcsRemoteRequest: {
        type: 'object',
        required: ['name', 'url'],
        properties: {
          name: { type: 'string' },
          url: { type: 'string', description: 'http(s)/ssh remote URL - validated by assertSafeRemoteUrl.' },
        },
      },
      VcsPushFetchRequest: {
        type: 'object',
        properties: {
          remote: { type: 'string', description: "Remote name (default 'origin'; assertSafeRemoteName)." },
          branch: { type: 'string', nullable: true, description: 'push only: branch name (assertValidBranchName).' },
        },
      },
      VcsRestoreRequest: {
        type: 'object',
        required: ['commitSha'],
        properties: {
          commitSha: { type: 'string' },
          path: { type: 'string', nullable: true, description: 'Optional single-file restore.' },
        },
      },
      VcsTreeEntry: {
        type: 'object',
        properties: {
          path: { type: 'string' },
          type: { type: 'string', description: "'blob' | 'tree'." },
          sha: { type: 'string' },
          size: { type: 'integer', nullable: true },
        },
      },
      VcsOperationAck: {
        type: 'object',
        properties: {
          ok: { type: 'boolean' },
          status: { "$ref": '#/components/schemas/VcsStatus' },
        },
      },
      VcsError: {
        type: 'object',
        properties: {
          'error': { type: 'string' },
        },
      },
      // NOTE: every VCS subroute shares the same auth/permission/validation
      // error family: 401 Unauthorized, 400 project mismatch / validation,
      // 403 viewer-role (mutating verbs) and 404/409 (VcsNotFound /
      // VcsConflict). They are kept inline per route for readability.
    },
  },

  paths: {
    '/projects/{projectId}/vcs/status': {
      get: {
        tags: ['VCS'],
        summary: 'Working tree + repository status.',
        description: 'Git status (branch, head, ahead/behind, uncommitted files, branches, tags, remotes). Experimental one-way CRDT→Git projection surface.',
        parameters: [
          { name: 'projectId', 'in': 'path', required: true, schema: { type: 'string' } },
        ],
        responses: {
          '200': { description: 'Status.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsStatus' } } } },
          '400': { description: 'Project mismatch.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsError' } } } },
          '401': { description: 'Unauthorized.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsError' } } } },
        },
      },
    },
    '/projects/{projectId}/vcs/commit': {
      post: {
        tags: ['VCS'],
        summary: 'Create a git commit from the CRDT state.',
        description: 'Commits the current CRDT projection into the project repo. Viewer sessions get 403 (read-only role).',
        parameters: [
          { name: 'projectId', 'in': 'path', required: true, schema: { type: 'string' } },
        ],
        requestBody: {
          required: true,
          content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsCommitRequest' } } },
        },
        responses: {
          '200': { description: 'Commit created.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsCommitDetails' } } } },
          '400': { description: 'Project mismatch.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsError' } } } },
          '401': { description: 'Unauthorized.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsError' } } } },
          '403': { description: 'Viewer role cannot mutate.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsError' } } } },
        },
      },
    },
    '/projects/{projectId}/vcs/commits': {
      get: {
        tags: ['VCS'],
        summary: 'Commit log.',
        description: 'Commit history of the projection repo.',
        parameters: [
          { name: 'projectId', 'in': 'path', required: true, schema: { type: 'string' } },
          { name: 'maxCount', 'in': 'query', required: false, description: 'Maximum commits to return (default 50).', schema: { type: 'integer', default: 50 } },
          { name: 'branch', 'in': 'query', required: false, description: 'Restrict the log to a branch (assertSafeRev).', schema: { type: 'string' } },
        ],
        responses: {
          '200': {
            description: 'Commit list.',
            content: { 'application/json': { schema: { type: 'array', items: { "$ref": '#/components/schemas/VcsCommit' } } } },
          },
          '400': { description: 'Project mismatch.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsError' } } } },
          '401': { description: 'Unauthorized.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsError' } } } },
        },
      },
    },
    '/projects/{projectId}/vcs/commits/{commitSha}': {
      get: {
        tags: ['VCS'],
        summary: 'Commit details.',
        description: 'Detailed info of a single commit (files, optional manifest).',
        parameters: [
          { name: 'projectId', 'in': 'path', required: true, schema: { type: 'string' } },
          { name: 'commitSha', 'in': 'path', required: true, schema: { type: 'string' } },
        ],
        responses: {
          '200': { description: 'Commit details.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsCommitDetails' } } } },
          '400': { description: 'Project mismatch.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsError' } } } },
          '401': { description: 'Unauthorized.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsError' } } } },
          '404': { description: 'Unknown commit / revision.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsError' } } } },
        },
      },
    },
    '/projects/{projectId}/vcs/diff': {
      get: {
        tags: ['VCS'],
        summary: 'Diff between revisions (raw unified text).',
        description: 'Diff between two revisions. from/to validated by assertSafeRev; path filters to one repo path (assertSafeRepoPath). The worktree diff (no from/to) invokes syncLiveStateToGit which mutates disk - viewer sessions get 403 exactly for that case. Returns the DIFF as plain text (200, text/plain).',
        parameters: [
          { name: 'projectId', 'in': 'path', required: true, schema: { type: 'string' } },
          { name: 'from', 'in': 'query', required: false, schema: { type: 'string' } },
          { name: 'to', 'in': 'query', required: false, schema: { type: 'string' } },
          { name: 'path', 'in': 'query', required: false, schema: { type: 'string' } },
        ],
        responses: {
          '200': { description: 'Diff output.', content: { 'text/plain': { schema: { type: 'string' } } } },
          '403': { description: 'Viewer role cannot inspect the uncommitted live worktree.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsError' } } } },
          '400': { description: 'Project mismatch / invalid rev.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsError' } } } },
          '401': { description: 'Unauthorized.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsError' } } } },
        },
      },
    },
    '/projects/{projectId}/vcs/tree': {
      get: {
        tags: ['VCS'],
        summary: 'Tree listing at a revision.',
        description: 'Entries of the repository tree at commitSha (default HEAD), optionally filtered to one tree path.',
        parameters: [
          { name: 'projectId', 'in': 'path', required: true, schema: { type: 'string' } },
          { name: 'commitSha', 'in': 'query', required: false, description: "Revision (default 'HEAD'; assertSafeRev).", schema: { type: 'string' } },
          { name: 'path', 'in': 'query', required: false, description: 'Sub-tree path (assertSafeRepoPath).', schema: { type: 'string' } },
        ],
        responses: {
          '200': {
            description: 'Tree entries.',
            content: { 'application/json': { schema: { type: 'array', items: { "$ref": '#/components/schemas/VcsTreeEntry' } } } },
          },
          '400': { description: 'Project mismatch.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsError' } } } },
          '401': { description: 'Unauthorized.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsError' } } } },
        },
      },
    },
    '/projects/{projectId}/vcs/blob': {
      get: {
        tags: ['VCS'],
        summary: 'File content at a revision (raw text).',
        description: 'Returns the file content at commitSha (default HEAD). `path` is REQUIRED (400 otherwise; assertSafeRepoPath). Returns the content as plain text.',
        parameters: [
          { name: 'projectId', 'in': 'path', required: true, schema: { type: 'string' } },
          { name: 'commitSha', 'in': 'query', required: false, description: "Revision (default 'HEAD'; assertSafeRev).", schema: { type: 'string' } },
          { name: 'path', 'in': 'query', required: true, description: 'Repo-relative file path (assertSafeRepoPath).', schema: { type: 'string' } },
        ],
        responses: {
          '200': { description: 'File content.', content: { 'text/plain': { schema: { type: 'string' } } } },
          '400': { description: 'Project mismatch.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsError' } } } },
          '401': { description: 'Unauthorized.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsError' } } } },
        },
      },
    },
    '/projects/{projectId}/vcs/branches': {
      get: {
        tags: ['VCS'],
        summary: 'List branches.',
        parameters: [
          { name: 'projectId', 'in': 'path', required: true, schema: { type: 'string' } },
        ],
        responses: {
          '200': {
            description: 'Branch list.',
            content: { 'application/json': { schema: { type: 'array', items: { "$ref": '#/components/schemas/VcsBranch' } } } },
          },
          '400': { description: 'Project mismatch.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsError' } } } },
          '401': { description: 'Unauthorized.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsError' } } } },
        },
      },
      post: {
        tags: ['VCS'],
        summary: 'Create a branch.',
        description: 'Creates a branch. Name is required (assertValidBranchName); startPoint optional (assertSafeRev).',
        parameters: [
          { name: 'projectId', 'in': 'path', required: true, schema: { type: 'string' } },
        ],
        requestBody: {
          required: true,
          content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsBranchRequest' } } },
        },
        responses: {
          '201': { description: 'Branch created (returns {ok:true} + updated status).', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsOperationAck' } } } },
          '400': { description: 'Branch name is required / invalid.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsError' } } } },
          '401': { description: 'Unauthorized.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsError' } } } },
          '403': { description: 'Viewer role cannot mutate.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsError' } } } },
        },
      },
    },
    '/projects/{projectId}/vcs/branches/checkout': {
      post: {
        tags: ['VCS'],
        summary: 'Checkout a branch.',
        parameters: [
          { name: 'projectId', 'in': 'path', required: true, schema: { type: 'string' } },
        ],
        requestBody: {
          required: true,
          content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsCheckoutRequest' } } },
        },
        responses: {
          '200': { description: 'Checked out (returns {ok, status}).', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsOperationAck' } } } },
          '400': { description: 'Branch name is required / invalid.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsError' } } } },
          '401': { description: 'Unauthorized.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsError' } } } },
          '403': { description: 'Viewer role cannot mutate.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsError' } } } },
        },
      },
    },
    '/projects/{projectId}/vcs/branches/merge': {
      post: {
        tags: ['VCS'],
        summary: 'Merge a branch.',
        description: 'Dual-writer valve beyond the Reconciler/applier guards (marked experimental).',
        parameters: [
          { name: 'projectId', 'in': 'path', required: true, schema: { type: 'string' } },
        ],
        requestBody: {
          required: true,
          content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsMergeRequest' } } },
        },
        responses: {
          '200': { description: 'Merged (returns {ok, status}).', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsOperationAck' } } } },
          '400': { description: 'Branch name is required / invalid.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsError' } } } },
          '401': { description: 'Unauthorized.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsError' } } } },
          '403': { description: 'Viewer role cannot mutate.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsError' } } } },
          '409': { description: 'Merge conflict (VcsConflictError).', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsError' } } } },
        },
      },
    },
    '/projects/{projectId}/vcs/tags': {
      get: {
        tags: ['VCS'],
        summary: 'List tags.',
        parameters: [
          { name: 'projectId', 'in': 'path', required: true, schema: { type: 'string' } },
        ],
        responses: {
          '200': {
            description: 'Tag list.',
            content: { 'application/json': { schema: { type: 'array', items: { "$ref": '#/components/schemas/VcsTag' } } } },
          },
          '400': { description: 'Project mismatch.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsError' } } } },
          '401': { description: 'Unauthorized.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsError' } } } },
        },
      },
      post: {
        tags: ['VCS'],
        summary: 'Create a tag.',
        description: 'Tag an optional commitSha (assertSafeRev); name required (assertValidTagName).',
        parameters: [
          { name: 'projectId', 'in': 'path', required: true, schema: { type: 'string' } },
        ],
        requestBody: {
          required: true,
          content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsTagRequest' } } },
        },
        responses: {
          '201': { description: 'Tag created.', content: { 'application/json': { schema: { type: 'object', properties: { ok: { type: 'boolean' } } } } } },
          '400': { description: 'Tag name is required / invalid.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsError' } } } },
          '401': { description: 'Unauthorized.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsError' } } } },
          '403': { description: 'Viewer role cannot mutate.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsError' } } } },
        },
      },
    },
    '/projects/{projectId}/vcs/tags/{name}': {
      delete: {
        tags: ['VCS'],
        summary: 'Delete a tag.',
        parameters: [
          { name: 'projectId', 'in': 'path', required: true, schema: { type: 'string' } },
          { name: 'name', 'in': 'path', required: true, description: 'Tag name (assertValidTagName).', schema: { type: 'string' } },
        ],
        responses: {
          '200': { description: 'Tag deleted.', content: { 'application/json': { schema: { type: 'object', properties: { ok: { type: 'boolean' } } } } } },
          '400': { description: 'Invalid tag name.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsError' } } } },
          '401': { description: 'Unauthorized.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsError' } } } },
          '403': { description: 'Viewer role cannot mutate.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsError' } } } },
        },
      },
    },
    '/projects/{projectId}/vcs/remotes': {
      get: {
        tags: ['VCS'],
        summary: 'List remotes.',
        parameters: [
          { name: 'projectId', 'in': 'path', required: true, schema: { type: 'string' } },
        ],
        responses: {
          '200': {
            description: 'Remote list.',
            content: { 'application/json': { schema: { type: 'array', items: { "$ref": '#/components/schemas/VcsRemote' } } } },
          },
          '400': { description: 'Project mismatch.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsError' } } } },
          '401': { description: 'Unauthorized.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsError' } } } },
        },
      },
      post: {
        tags: ['VCS'],
        summary: 'Add a remote.',
        parameters: [
          { name: 'projectId', 'in': 'path', required: true, schema: { type: 'string' } },
        ],
        requestBody: {
          required: true,
          content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsRemoteRequest' } } },
        },
        responses: {
          '201': { description: 'Remote added.', content: { 'application/json': { schema: { type: 'object', properties: { ok: { type: 'boolean' } } } } } },
          '400': { description: 'name and url are required / validation failed.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsError' } } } },
          '401': { description: 'Unauthorized.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsError' } } } },
          '403': { description: 'Viewer role cannot mutate.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsError' } } } },
        },
      },
    },
    '/projects/{projectId}/vcs/remotes/{name}': {
      delete: {
        tags: ['VCS'],
        summary: 'Remove a remote.',
        parameters: [
          { name: 'projectId', 'in': 'path', required: true, schema: { type: 'string' } },
          { name: 'name', 'in': 'path', required: true, description: 'Remote name (assertSafeRemoteName).', schema: { type: 'string' } },
        ],
        responses: {
          '200': { description: 'Remote removed.', content: { 'application/json': { schema: { type: 'object', properties: { ok: { type: 'boolean' } } } } } },
          '400': { description: 'Invalid remote name.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsError' } } } },
          '401': { description: 'Unauthorized.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsError' } } } },
          '403': { description: 'Viewer role cannot mutate.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsError' } } } },
        },
      },
    },
    '/projects/{projectId}/vcs/remotes/push': {
      post: {
        tags: ['VCS'],
        summary: 'Push to a remote.',
        description: "Pushes `branch` (or the current HEAD) to `remote` (default 'origin'; assertSafeRemoteName + assertValidBranchName).",
        parameters: [
          { name: 'projectId', 'in': 'path', required: true, schema: { type: 'string' } },
        ],
        requestBody: {
          required: true,
          content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsPushFetchRequest' } } },
        },
        responses: {
          '200': { description: 'Push result.', content: { 'application/json': { schema: { type: 'object' } } } },
          '400': { description: 'Project mismatch / invalid remote.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsError' } } } },
          '401': { description: 'Unauthorized.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsError' } } } },
        },
      },
    },
    '/projects/{projectId}/vcs/remotes/fetch': {
      post: {
        tags: ['VCS'],
        summary: 'Fetch from a remote.',
        description: "Fetches `remote` (default 'origin'; assertSafeRemoteName).",
        parameters: [
          { name: 'projectId', 'in': 'path', required: true, schema: { type: 'string' } },
        ],
        requestBody: {
          required: true,
          content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsPushFetchRequest' } } },
        },
        responses: {
          '200': { description: 'Fetch result.', content: { 'application/json': { schema: { type: 'object' } } } },
          '400': { description: 'Project mismatch / invalid remote.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsError' } } } },
          '401': { description: 'Unauthorized.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsError' } } } },
        },
      },
    },
    '/projects/{projectId}/vcs/restore': {
      post: {
        tags: ['VCS'],
        summary: 'Restore a historical state.',
        description: "Restores a commit (or a single file with `path`). RESTART-gated follow-up: restore must clear tombstoneExpiresAt/deletedAt on the active flip and stop raw snapshotRepo.upsert — documented as OPEN before merge.",
        parameters: [
          { name: 'projectId', 'in': 'path', required: true, schema: { type: 'string' } },
        ],
        requestBody: {
          required: true,
          content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsRestoreRequest' } } },
        },
        responses: {
          '200': { description: 'Restored.', content: { 'application/json': { schema: { type: 'object' } } } },
          '400': { description: 'Invalid revision (assertSafeRev rejects `-`-prefixed/whitespace revs).', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsError' } } } },
          '401': { description: 'Unauthorized.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsError' } } } },
          '403': { description: 'Viewer role cannot mutate.', content: { 'application/json': { schema: { "$ref": '#/components/schemas/VcsError' } } } },
        },
      },
    },
  },
}
