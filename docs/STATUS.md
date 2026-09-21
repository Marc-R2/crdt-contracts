# Status — `crdt-contracts`

Snapshot of the extracted repository (extracted from the `obsidian-crdt-sync` monorepo,
`packages/crdt-contracts/**` → repository root). Update this file as work items close.

## Verification performed

| Check | Command | Result |
|---|---|---|
| Install | `npm ci` | ✅ 41 packages, 0 vulnerabilities (lockfile committed) |
| Build | `npm run build` (`tsc -p tsconfig.json`) | ✅ emits `dist/index.js` + `dist/index.d.ts` |
| Load | `node -e "require('./dist/index.js')"` | ✅ exports `PROTOCOL_VERSION`, `DocType`, `DOCID_PREFIXES`, `BLOB_DOCID_PREFIX`, `EMPTY_SHA256`, `SHA256_HEX_REGEX`, `CRDT_DOCID_PREFIXES` |
| Contract tests | `npm test` (`vitest run`, build first via `pretest`) | ✅ 4 files / 8 tests pass |
| Compat gate | `npm run compat:gate` | ✅ GREEN — pin matches the exported `PROTOCOL_VERSION` |

## Open follow-ups

1. **Release tag + pin.** Publish `v0.1.0` and have consumers pin the git dependency (D-1), gated
   on the `SUBMODULES_TOKEN` proof (HB-2).
2. **OpenAPI generation.** `openapi/` carries the jsonnet sources and a committed `openapi.yaml` +
   Swagger UI bundle; the build/lint command for it is not wired here yet.

## Closed

1. **Re-rooted the carried-over contract tests (DONE).** The four `tests/unit/contracts/*.test.ts`
   now resolve `src/`, `compat-manifest.json` and `package.json` at the repository root instead of
   `packages/crdt-contracts/...`; the drift copy skips `node_modules/` and `.git/`.
2. **Wired a test runner (DONE).** `vitest` + `typescript` (+ `@types/node`, `vite`) devDeps,
   `vitest.config.mts` (package-name alias to `src/index.ts`), and `test` / `pretest` /
   `compat:gate` scripts. The parent's monorepo-only `compat-gate.mjs` consumer checks were replaced
   by a repo-local equivalent (`scripts/compat-gate.mjs`) that keeps the package-local semantics:
   `compat-manifest.json` vs the package's actual export and `package.json` version. No new contract
   semantics were invented.

## Consumers

`crdt_plugin`, `crdt_server` (both via submodule at `packages/crdt-contracts`).
`web_vault` intentionally does **not** import this package.
