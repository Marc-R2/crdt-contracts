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
| [`crdt_plugin`](https://github.com/Marc-R2/crdt_plugin) | Consumer — depends on `@marc-r2/crdt-contracts` (git submodule at `packages/crdt-contracts`). |
| [`crdt_server`](https://github.com/Marc-R2/crdt_server) | Consumer — depends on `@marc-r2/crdt-contracts` (git submodule at `packages/crdt-contracts`). |
| [`web_vault`](https://github.com/Marc-R2/web_vault) | **Not** a consumer — the portal/WebVault keep portal-local copies and must not import this package. |
| [`crdt-e2e-catalog`](https://github.com/Marc-R2/crdt-e2e-catalog) | Not a consumer. |
| [`obsidian-crdt-sync`](https://github.com/Marc-R2/obsidian-crdt-sync) | Parent/umbrella — hosts this package in-tree as `packages/crdt-contracts` while the monorepo is still the integration branch; the parent `compat.yml` verifies the pins. |

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
| `openapi/` | OpenAPI 3 source (`*.jsonnet`) and the generated `openapi.yaml` + Swagger UI assets. |
| `compat-manifest.json` | `{ "contracts": "<version>", "protocolVersion": <n> }` — the consumer-facing compatibility pin. |
| `tests/unit/contracts/` | Contract tests (vitest): wire surface, implementation-free guard, `compat:gate` green + drift proof. |

## Build & test

```bash
npm install          # installs the vitest/typescript toolchain
npm run build        # tsc -p tsconfig.json -> dist/ (CommonJS + .d.ts)
npm test             # builds, then runs the contract tests (vitest)
npm run compat:gate  # builds, then verifies the compat-manifest pin vs the export
```

Requires Node.js >= 22. The package is type-checked and emitted successfully with TypeScript 5.8.

### Version bumping contract

`compat-manifest.json` must stay in lockstep with the code:

- `protocolVersion` must equal `PROTOCOL_VERSION` in `src/protocol.ts` (bump it on **any** breaking
  room-name or structure-entry-schema change).
- `contracts` must equal `version` in `package.json`.

Both pins are enforced in this repository by `tests/unit/contracts/` and the repo-local `compat:gate`
(`scripts/compat-gate.mjs`), which compares the manifest against what the package actually exports.

## How consumers obtain this package

- **In the monorepo (current integration path):** declared as `file:packages/crdt-contracts` on the
  plugin and `file:../packages/crdt-contracts` on the server — zero cross-repo auth.
- **Cross-repo (split path):** a git dependency over HTTPS pinned to a release tag
  (`git+https://github.com/Marc-R2/crdt-contracts.git#vX.Y.Z`, decision D-1 in the split plan),
  authenticated in CI with the `SUBMODULES_TOKEN` secret and locally via the keychain/SSH.

## Cross-repo credential caveat

`SUBMODULES_TOKEN` is **not yet configured** (blocker HB-2 in the split plan). Cross-repo reads from
CI therefore fail closed; until the secret exists, the in-tree `file:` dependency + parity
typecheck (`check:parity` in the server) is the supported path. Do not enable a cross-repo consumer
CI job before the Phase-0.5 red/green auth proof has passed.

## Status

- **Verified:** `npm run build` emits `dist/index.js` + `dist/index.d.ts`, the package loads
  (`node -e "require('./dist/index.js')"`), and `npm test` runs the re-rooted contract tests
  (vitest) green against the repo-local `compat:gate`. See [`docs/STATUS.md`](docs/STATUS.md).
- **Open follow-ups:** release tag + consumer pin (split-plan D-1, blocked on `SUBMODULES_TOKEN`)
  and wiring the `openapi/` generation/lint command.

## Sibling repositories

- [`crdt_plugin`](https://github.com/Marc-R2/crdt_plugin) — Obsidian plugin (desktop client)
- [`crdt_server`](https://github.com/Marc-R2/crdt_server) — Hocuspocus/Yjs sync server
- [`web_vault`](https://github.com/Marc-R2/web_vault) — account portal + standalone WebVault sources
- [`crdt-e2e-catalog`](https://github.com/Marc-R2/crdt-e2e-catalog) — host-agnostic e2e scenarios
- [`obsidian-crdt-sync`](https://github.com/Marc-R2/obsidian-crdt-sync) — parent/umbrella
