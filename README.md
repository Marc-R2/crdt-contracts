# CRDT Sync Contracts (`@marc-r2/crdt-contracts`)

Implementation-free **wire contracts** (types + constants only) shared by the Obsidian plugin
(`crdt_plugin`) and the sync server (`crdt_server`).

This package defines what travels **between** the two sides of the suite — docId prefix shapes,
blob identity constants, the `/blobs/*` REST payloads, history timeline types, VCS domain types and
the client/server protocol pin. It contains **no behavior**: no functions, no UUID/crypto sources,
no filesystem or DOM access, no Yjs, no NestJS runtime. Minting, predicates, validators and
room-name helpers stay in the consuming repos.

> Part of the five-repository split of the former `obsidian-crdt-sync` monorepo. The canonical
> architecture (decisions, extraction map, phase ordering, credential blockers) is
> [`docs/REPO_SPLIT_PLAN.md`](https://github.com/Marc-R2/obsidian-crdt-sync/blob/main/docs/REPO_SPLIT_PLAN.md)
> in the parent repository.

## Role in the suite

| Repository | Relation to this package |
|---|---|
| [`crdt_plugin`](https://github.com/Marc-R2/crdt_plugin) | Consumer — installs the public release tarball `@marc-r2/crdt-contracts` (no submodule, no build step). |
| [`crdt_server`](https://github.com/Marc-R2/crdt_server) | Consumer — installs the public release tarball `@marc-r2/crdt-contracts` (no submodule, no build step). |
| [`web_vault`](https://github.com/Marc-R2/web_vault) | **Not** a consumer — the portal/WebVault keep portal-local copies and must not import this package. |
| [`crdt-e2e-catalog`](https://github.com/Marc-R2/crdt-e2e-catalog) | Not a consumer. |
| [`obsidian-crdt-sync`](https://github.com/Marc-R2/obsidian-crdt-sync) | Parent/umbrella — split architecture, decisions and phase ordering. |

This repository consumes **no** sibling repository and has no submodules.

## Layout

| Path | Contents |
|---|---|
| `src/docType.ts` | `DocType` enum, `DocumentId`, `DOCID_PREFIXES`, `BLOB_DOCID_PREFIX`. |
| `src/blob.ts` | `EMPTY_SHA256`, `SHA256_HEX_REGEX`, `BlobDocId`, `CRDT_DOCID_PREFIXES`. |
| `src/blobTypes.ts` | `/blobs/*` REST payload interfaces (batch-check, manifest, chunk status). |
| `src/history.ts` | History timeline wire types (index, checkpoints, commits, chunk updates). |
| `src/vcs.ts` | Git/VCS domain types shared by plugin and server. |
| `src/protocol.ts` | `PROTOCOL_VERSION` — the single integer pinning room-name/entry-schema compatibility. |
| `src/index.ts` | The public surface (re-exports all of the above). |
| `openapi/` | OpenAPI 3 pipeline: jsonnet sources (`src/**`, the edit targets) and the GENERATED `openapi.yaml` (never hand-edit; `build:openapi` re-renders, `check:openapi` gates drift + Redocly conformance) + Swagger UI assets. |
| `compat-manifest.json` | `{ "contracts": "<version>", "protocolVersion": <n>, "openapiSha256": "<64-hex>" }` — the consumer-facing compatibility pin. |
| `tests/unit/contracts/` | Contract tests (vitest): wire surface, implementation-free guard, `compat:gate` green + drift proof. |

## Build & test

```bash
npm install          # installs the vitest/typescript toolchain + the native jsonnet binding
npm run build        # tsc -p tsconfig.json -> dist/ (CommonJS + .d.ts)
npm run build:openapi  # renders openapi/src/** -> openapi/openapi.yaml
npm run check:openapi  # drift gate + Redocly conformance lint for the REST contract
npm test             # builds, then runs the contract tests (vitest)
npm run compat:gate  # builds, then verifies the compat-manifest pins vs the exports
```

Requires Node.js >= 22. `npm install`/`npm ci` compiles the `@hanazuki/node-jsonnet` native
binding via `cmake-js`, so a **CMake + C toolchain is required on the install machine** (CI sets up
CMake explicitly). The package is type-checked and emitted successfully with TypeScript 5.8.

### Version bumping contract

`compat-manifest.json` must stay in lockstep with the code:

- `protocolVersion` must equal `PROTOCOL_VERSION` in `src/protocol.ts` (bump it on **any** breaking
  room-name or structure-entry-schema change).
- `contracts` must equal `version` in `package.json`.

Both pins are enforced in this repository by `tests/unit/contracts/` and the repo-local `compat:gate`
(`scripts/compat-gate.mjs`), which compares the manifest against what the package actually exports.

## How consumers obtain this package

`crdt_plugin` and `crdt_server` declare the package as a **public** GitHub Release tarball URL in
`package.json`:

```
"@marc-r2/crdt-contracts":
  "https://github.com/Marc-R2/crdt-contracts/releases/download/v0.1.0/marc-r2-crdt-contracts-0.1.0.tgz"
```

`package-lock.json` records the `resolved` URL + `integrity`, so `npm ci` installs it anonymously —
no token, no SSH key, no submodule, no contracts build step. The tarball ships its own prebuilt
`dist/`, `src/`, `compat-manifest.json` and `openapi/openapi.yaml`. To pick up a new contracts
change, publish a release here and bump the tarball URL in each consumer. The cross-consumer
identity of the pinned release is checked by `npm run check:suite`
(`scripts/check-suite-coherence.mjs`).

## Status

- **Verified:** `npm run build` emits `dist/index.js` + `dist/index.d.ts`, the package loads
  (`node -e "require('./dist/index.js')"`), and `npm test` runs the re-rooted contract tests
  (vitest) green against the repo-local `compat:gate`. See [`docs/STATUS.md`](docs/STATUS.md).
- **Open follow-up:** the Phase-B/C consumer generation (server module / plugin client) from the
  rendered contract.

## Sibling repositories

- [`crdt_plugin`](https://github.com/Marc-R2/crdt_plugin) — Obsidian plugin (desktop client)
- [`crdt_server`](https://github.com/Marc-R2/crdt_server) — Hocuspocus/Yjs sync server
- [`web_vault`](https://github.com/Marc-R2/web_vault) — account portal + standalone WebVault sources
- [`crdt-e2e-catalog`](https://github.com/Marc-R2/crdt-e2e-catalog) — host-agnostic e2e scenarios
- [`obsidian-crdt-sync`](https://github.com/Marc-R2/obsidian-crdt-sync) — parent/umbrella
