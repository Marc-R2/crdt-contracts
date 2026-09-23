# Status — `crdt-contracts`

Snapshot of the extracted repository (extracted from the `obsidian-crdt-sync` monorepo,
`packages/crdt-contracts/**` → repository root). Update this file as work items close.

## Verification performed

| Check | Command | Result |
|---|---|---|
| Install | `npm ci` | ✅ lockfile committed; jsonnet binding builds via `cmake-js` at install time — **CMake + a C toolchain are required on the install machine**, then cached in the lockfile resolution |
| Build | `npm run build` (`tsc -p tsconfig.json`) | ✅ emits `dist/index.js` + `dist/index.d.ts` |
| OpenAPI render | `npm run build:openapi` | ✅ renders 55 paths from `openapi/src/**`; byte-identical re-runs AND byte-identical to the old homebrew jsonnet CLI v0.22.0 render |
| OpenAPI drift gate | `npm run check:openapi` | ✅ GREEN — render == committed yaml, `openapiSha256` pin matches, all `$ref`s resolve |
| Contract tests | `npm test` (`vitest run`, build first via `pretest`) | ✅ 5 files / 11 tests pass (incl. the OpenAPI pipeline red-proof) |
| Compat gate | `npm run compat:gate` | ✅ GREEN — contracts 0.1.0, protocolVersion 1, openapiSha256 pinned |

## Open follow-ups

1. **Release tag + pin.** Publish `v0.1.0` and have consumers pin the git dependency (D-1), gated
   on the `SUBMODULES_TOKEN` proof (HB-2).
2. **Phase B (crdt_server).** Regenerate `src/generated-api-module` from this package's rendered
   contract with `openapi-generator -g typescript-nestjs-server` (the pre-split root
   `openapi:generate` command); the yaml now covers the full served REST surface.
3. **Phase C (crdt_plugin).** Regenerate the plugin's TS client from the same rendered contract
   (replacing hand-written REST call sites where elected).

## Closed

1. **OpenAPI pipeline restored (DONE, Phase A).** `build:openapi` renders `openapi/src/**` →
   `openapi/openapi.yaml` with the pinned npm devDependency `@hanazuki/node-jsonnet@3.0.1`
   (declared + exact-pinned; no brew/global binary). The CJS binding's output is byte-identical
   to the old jsonnet CLI render, so the committed artifact stays comparable.
   `check:openapi` gates the drift (render vs committed bytes + `openapiSha256` manifest pin vs
   render — decision C-6). CI runs it right after build (`.github/workflows/test.yml`).
2. **Jsonnet sources reconciled with the real API (DONE).** The dead `/fs/*` endpoint definitions
   (`openapi/src/lib/fs/` + the never-imported `FsEntry` schema) were REMOVED; new lib files
   (`blobs/`, `history/`, `oidc/`, `vcs/`, `diagnostics/`) document every currently served REST
   route at path+method level (55 paths). `info.version` aligned to the package version
   (`0.1.0`, was stale `0.0.1`).
3. **Re-rooted the carried-over contract tests (DONE).** The `tests/unit/contracts/*.test.ts`
   resolve `src/`, `compat-manifest.json` and `package.json` at the repository root instead of
   `packages/crdt-contracts/...`; the drift copy skips `node_modules/` and `.git/`.
4. **Wired a test runner (DONE).** `vitest` + `typescript` (+ `@types/node`, `vite`) devDeps,
   `vitest.config.mts` (package-name alias to `src/index.ts`), and `test` / `pretest` /
   `compat:gate` scripts. The parent's monorepo-only `compat-gate.mjs` consumer checks were replaced
   by a repo-local equivalent (`scripts/compat-gate.mjs`) that keeps the package-local semantics:
   `compat-manifest.json` vs the package's actual export and `package.json` version. No new contract
   semantics were invented.

## Consumers

`crdt_plugin`, `crdt_server` (both via submodule at `packages/crdt-contracts`).
`web_vault` intentionally does **not** import this package.
