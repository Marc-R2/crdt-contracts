# Status — `crdt-contracts`

Snapshot of the extracted repository (extracted from the `obsidian-crdt-sync` monorepo,
`packages/crdt-contracts/**` → repository root). Update this file as work items close.

## Verification performed

| Check | Command | Result |
|---|---|---|
| Install | `npm ci` | ✅ lockfile committed; jsonnet binding builds via `cmake-js` at install time — **CMake + a C toolchain are required on the install machine** (CI sets up CMake explicitly) |
| Build | `npm run build` (`tsc -p tsconfig.json`) | ✅ emits `dist/index.js` + `dist/index.d.ts` |
| OpenAPI render | `npm run build:openapi` | ✅ renders 56 paths from `openapi/src/**`; byte-identical re-runs, byte-identical across `@hanazuki/node-jsonnet` 3.0.1/3.3.1, AND byte-identical to the old homebrew jsonnet CLI v0.22.0 render |
| OpenAPI gate | `npm run check:openapi` | ✅ GREEN — render == committed yaml, `openapiSha256` pin matches, all `$ref`s resolve, Redocly conformance lint valid (0 errors, 76 pre-existing operationId warnings) |
| Contract tests | `npm test` (`vitest run`, build first via `pretest`) | ✅ 6 files / 15 tests pass (incl. drift + conformance red proofs) |
| Compat gate | `npm run compat:gate` | ✅ GREEN — contracts 0.1.0, protocolVersion 1, openapiSha256 matches the committed yaml hash |
| Generator proof | `openapi-generator 7.25.0 -g typescript-nestjs-server` | ✅ emits `@Delete('/api/bug-reports/:id')` with a required `@Param('id') id: string` and `logs?: Array<string> \| string` (was `@Delete('/api/bug-reports')` with `id: string \| undefined` and `logs?: any \| null` before the B1/M2 fixes) |

## Open follow-ups

1. **Phase B (crdt_server).** Regenerate `src/generated-api-module` from this package's rendered
   contract with `openapi-generator -g typescript-nestjs-server` (the pre-split root
   `openapi:generate` command); the yaml now covers the full served REST surface.
3. **Phase C (crdt_plugin).** Regenerate the plugin's TS client from the same rendered contract
   (the pre-split `typescript-fetch -o src/api/generated` generator; that client was deleted at
   monorepo commit `3a4d6317` and is the Phase-C target).
4. **operationIds (n2).** The contract carries no `operationId`s (76 Redocly warnings), so
   generators derive method names from path+method heuristics. Adding them would improve Phase-B
   naming; deliberately deferred so the regenerated NestJS module keeps its current method names.

## Closed

1. **OpenAPI pipeline restored (DONE, Phase A).** `build:openapi` renders `openapi/src/**` →
   `openapi/openapi.yaml` with the pinned npm devDependency `@hanazuki/node-jsonnet` (declared +
   exact-pinned; no brew/global binary). The CJS binding's output is byte-identical to the old
   jsonnet CLI render, so the committed artifact stays comparable. `check:openapi` gates the drift
   (render vs committed bytes + `openapiSha256` manifest pin — decision C-6). CI runs it right
   after build (`.github/workflows/test.yml`).
2. **Jsonnet sources reconciled with the real API (DONE).** The dead `/fs/*` endpoint definitions
   (`openapi/src/lib/fs/` + the never-imported `FsEntry` schema) were REMOVED; new lib files
   (`blobs/`, `history/`, `oidc/`, `vcs/`, `diagnostics/`) document every currently served REST
   route at path+method level. `info.version` aligned to the package version (`0.1.0`).
3. **Re-rooted the carried-over contract tests (DONE).** The `tests/unit/contracts/*.test.ts`
   resolve `src/`, `compat-manifest.json` and `package.json` at the repository root instead of
   `packages/crdt-contracts/...`; the drift copy skips `node_modules/` and `.git/`.
4. **Wired a test runner (DONE).** `vitest` + `typescript` (+ `@types/node`, `vite`) devDeps,
   `vitest.config.mts` (package-name alias to `src/index.ts`), and `test` / `pretest` /
   `compat:gate` scripts. The parent's monorepo-only `compat-gate.mjs` consumer checks were replaced
   by a repo-local equivalent (`scripts/compat-gate.mjs`) that keeps the package-local semantics:
   `compat-manifest.json` vs the package's actual export and `package.json` version. No new contract
   semantics were invented.
5. **Strict-review fixes (DONE).** B1: the spec now has a real `DELETE /api/bug-reports/{id}` path
   with a REQUIRED `{id}` and the invalid optional `id` path param was removed from the collection
   path (the generator now emits the `:id` route). M2: `BugReportRequest.logs` is a typed
   `oneOf: [string, string[]]` (no `nullable` without `type`). M1: `@hanazuki/node-jsonnet` bumped
   3.0.1 → 3.3.1 (byte-identical render, re-verified) and CI sets up CMake explicitly. NEW:
   conformance lint (`@redocly/cli` + `.redocly.yaml`, wired into `check:openapi` and CI) with
   throwaway-copy red proofs for B1 and M2. m1: `compat:gate` now checks `openapiSha256` EQUALITY
   against the committed yaml, not just presence/format. m2: unused `ProjectId` schema dropped.

## Consumers

`crdt_plugin`, `crdt_server` — both install the public GitHub Release tarball
`@marc-r2/crdt-contracts` (currently `v0.1.0`) via `package.json`; no submodule.
`web_vault` intentionally does **not** import this package.

## Distribution migration (2026-10-06)

Consumers no longer pin a `packages/crdt-contracts` git submodule. `crdt-contracts` is **public** and
consumed as the release tarball
`https://github.com/Marc-R2/crdt-contracts/releases/download/v0.1.0/marc-r2-crdt-contracts-0.1.0.tgz`,
installed anonymously by `npm ci`. The cross-consumer release identity is checked by
`npm run check:suite` (`scripts/check-suite-coherence.mjs`).
