# AGENTS.md — crdt-contracts

**Language contract (user directive, 2026-09-01): ALWAYS work in English** — code, commit
messages, reports, thinking, agent briefs, git notes, AGENTS.md edits. The user usually writes
German; that NEVER changes the output language. Only an EXPLICIT user request for another language
overrides this. Subagents must receive this rule in their briefs.

Implementation-free **wire contracts** (types + constants only) shared by the Obsidian plugin
(`crdt_plugin`) and the sync server (`crdt_server`). This is the former monorepo's
`packages/crdt-contracts/**` promoted to the repository root.

- Umbrella: `Marc-R2/obsidian-crdt-sync` — split plan `docs/REPO_SPLIT_PLAN.md` (§1, §4.1, §5).
- This repository consumes **no** sibling repository and has no submodules.
- `web_vault` and `crdt-e2e-catalog` are intentionally NOT consumers.

## Hard boundary: implementation-free

The package is **types and constants ONLY** — no functions, no classes, no arrow functions, no UUID/
crypto sources, no filesystem or DOM access, no Yjs, no NestJS runtime. Minting, predicates,
validators and room-name helpers stay in the consuming repos. Enforced by
`tests/unit/contracts/implementationFree.test.ts`.

- `freshTypedDocId` + the read predicates (`isBlobDocId`/`isLiveEditDocId`/`isCrdtDocId`/
  `docIdPrefixOf`) are PLUGIN code (`crdt_plugin/src/sync/docType.ts`).
- Blob validators (`assertSafeBlobHash`, `isUsableBlob`) and their behavior tests live in SERVER.
- `server/src/generated-api-module/**` is a SERVER runtime stub, not a contract.
- Do NOT add behavior "for convenience" — it breaks the implementation-free guard and the
  consumer parity model.

## Contract surface (`src/`)

| File | Contents |
|---|---|
| `docType.ts` | `DocType` enum (`text\|map\|json\|list\|xml\|frag\|blob`), `DocumentId`, `DOCID_PREFIXES` (`text:`/`map:`/`json:`/`list:`/`xml:`/`frag:`/`sha256:`), `BLOB_DOCID_PREFIX`. |
| `blob.ts` | `EMPTY_SHA256`, `SHA256_HEX_REGEX`, `BlobDocId`, `CRDT_DOCID_PREFIXES`. |
| `blobTypes.ts` | `/blobs/*` REST payload interfaces (batch-check, manifest, chunk status). |
| `history.ts` | History timeline wire types (index, checkpoints, commits, chunk updates). |
| `vcs.ts` | Git/VCS domain types shared by plugin and server. |
| `protocol.ts` | `PROTOCOL_VERSION` — the single integer pinning room-name/entry-schema compatibility. |
| `index.ts` | The public surface (re-exports all of the above). |

`openapi/` carries the OpenAPI 3 contract as a **jsonnet → yaml pipeline**: `openapi/src/**`
(requested output) renders to the **generated artifact** `openapi/openapi.yaml`, plus the Swagger
UI assets (moved here from the former `server/docs/`). The yaml is committed, but it is a BUILD
PRODUCT — never hand-edit it; edit the jsonnet sources and re-run `build:openapi`.

### docId prefix schema (the contract)

- **docId ≠ globalId.** docId is the Y.Map **key** in the structure entries map + persisted stores
  (`local-tracked.json`, `content-exported.json`, `conflicts.json`, `AbandonedPathStore`). globalId
  is a separate, **unprefixed** UUID = Hocuspocus room key (`project-{id}@{globalId}`),
  `state/content/{globalId}.bin` filename, server snapshot keys and history doc_id. The type prefix
  (`text:`, `map:`, …) lives ONLY on the docId — rooms, server data and history are untouched by
  prefix changes.
- The enum/prefix constants above are canonical here; the strict predicates and the rehome contract
  are consumer-side (PLUGIN), with the server mirror in `crdt_server/src/utils/blobIdUtils.ts`
  (`CRDT_DOCID_PREFIXES` + `isCrdtDocId`).
- **NO legacy bare-UUID fallback**: `docIdPrefixOf` is strict (`''`/unknown → `null`). Clean cut.

## Build & test

```bash
npm ci
npm run build           # tsc -p tsconfig.json -> dist/ (CommonJS + .d.ts)
npm run build:openapi   # renders openapi/src/** -> openapi/openapi.yaml (pinned jsonnet devDep)
npm run check:openapi   # drift gate: rebuilds + compares bytes + verifies the openapiSha256 pin
npm test                # builds, then runs the contract tests (vitest)
npm run compat:gate     # builds, then verifies the compat-manifest pins vs the exports
```

Requires Node.js >= 22. The package declares `main: dist/index.js` + `types: dist/index.d.ts`, so
**every consumer must build it (CJS + declarations) before using it** — a source-only package breaks
the compiled CJS server (`ERR_MODULE_NOT_FOUND`). This is a hard requirement of the distribution, not
a convenience.

## Compat manifest (the pin)

`compat-manifest.json` must stay in lockstep with the code:

```json
{ "contracts": "0.1.0", "protocolVersion": 1, "openapiSha256": "<64-hex sha256 of openapi/openapi.yaml>" }
```

- `protocolVersion` must equal `PROTOCOL_VERSION` in `src/protocol.ts` (bump it on **any** breaking
  room-name or structure-entry-schema change).
- `contracts` must equal `version` in `package.json`.
- `openapiSha256` must equal the sha256 of the RENDERED `openapi/openapi.yaml` (decision C-6).
  After a deliberate contract change: edit `openapi/src/**`, re-run `npm run build:openapi`,
  re-compute the pin, update `compat-manifest.json` in the SAME commit.
- Enforced here by `tests/unit/contracts/`, the repo-local `compat:gate`
  (`scripts/compat-gate.mjs`, presence/format of all pins) and `check:openapi`
  (render-vs-file byte equality + pin-vs-render equality; wired into CI right after build).
  `versionsUiSha256` is deliberately NOT in the manifest (the shared-CSS invariant is repo-local +
  cross-checked — see `web_vault/AGENTS.md`).
- The consumer `compat:gate` compares the declared pin against the actual exported
  `PROTOCOL_VERSION`; the cross-repo `compat` job additionally boots the pinned SERVER and asserts
  `compat-manifest.protocolVersion === server.versions.protocol`.

## How consumers obtain this package

- Declared as a git dependency over HTTPS pinned to a release tag (D-1):
  `"@marc-r2/crdt-contracts": "git+https://github.com/Marc-R2/crdt-contracts.git#vX.Y.Z"`.
- `crdt_plugin` and `crdt_server` consume it as a submodule at `packages/crdt-contracts` (in-tree
  `file:` dependency + `check:parity` for the zero-auth integration path).
- CI authenticates with the `SUBMODULES_TOKEN` secret (`contents:read`); the secret is **not yet
  configured** (blocker HB-2). Never echo the token; `set +x` around any credential step; pass it as
  a BuildKit secret, never an `ARG`/`ENV`.

## Development workflow & commit discipline

- **Commit granularity**: small, self-contained, atomic commits; never mix unrelated changes.
- **Strict TDD**: a failing contract/drift test first, then the minimal change; `npm test` +
  `npm run build` before committing; new tests in the SAME commit.
- **Git notes invariant**: every commit carries a `git notes add` with (1) context & rationale and
  (2) privacy & security guarantees (zero data egress, credential hygiene, local-only processing).
- **AGENTS.md size cap**: keep this file under **100,000** characters (`wc -c AGENTS.md`).
- A protocol/type bump is a **breaking change**: update `compat-manifest.json` + `protocol.ts`
  together and note the migration in the commit/PR. Release = git tag `vX.Y.Z` (npm route rejected).

## Conventions worth knowing

- Indentation: tabs, tab width 4 (`.editorconfig`).
- Files exceeding ~300 lines should be split.
- Keep the public surface grouped by domain (blob/protocol/history/vcs) and re-export from `index.ts`.
- The REST contract is built from jsonnet via the **pinned npm devDependency**
  `@hanazuki/node-jsonnet@3.0.1` (exact pin) — no brew/global binary dependency. NOTE: the binding
  builds natively via `cmake-js` at `npm ci` time, so the install machine needs CMake + a C
  toolchain (consumers of the contracts only need the build output, never a jsonnet render).
  The render is byte-stable (keys sorted by the renderer; the CJS binding and the old CLI binary
  produce byte-identical output). `build:openapi` regenerates `openapi/openapi.yaml` from
  `openapi/src/**`; `check:openapi` gates drift (render must be byte-identical, pin must match).
  `openapi-generator` is NOT needed here — it stays a Phase-B/C concern of the CONSUMERS
  (server module / plugin client generation), which will read this package's rendered contract.

## Useful references

- `README.md` — package overview, layout, version-bumping contract.
- `docs/STATUS.md` — verified state and open follow-ups.
- Umbrella plan: `Marc-R2/obsidian-crdt-sync` `docs/REPO_SPLIT_PLAN.md` (§1, §4.1, §5, §6.2).
