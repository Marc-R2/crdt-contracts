# Status — `crdt-contracts`

Snapshot of the extracted repository (extracted from the `obsidian-crdt-sync` monorepo,
`packages/crdt-contracts/**` → repository root). Update this file as work items close.

## Verification performed

| Check | Command | Result |
|---|---|---|
| Build | `npm run build` (`tsc -p tsconfig.json`) | ✅ emits `dist/index.js` + `dist/index.d.ts` |
| Load | `node -e "require('./dist/index.js')"` | ✅ exports `PROTOCOL_VERSION`, `DocType`, `DOCID_PREFIXES`, `BLOB_DOCID_PREFIX`, `EMPTY_SHA256`, `SHA256_HEX_REGEX`, `CRDT_DOCID_PREFIXES` |
| Contract tests | `npx vitest run tests/unit/contracts` | ❌ not runnable — no runner configured and stale monorepo paths |

## Open follow-ups

1. **Re-root the carried-over contract tests.** `tests/unit/contracts/*.test.ts` still resolve
   `packages/crdt-contracts/...` and `../../../scripts/compat-gate.mjs` (monorepo layout); the
   extracted repository has neither. Rewrite the paths to `src/` / `compat-manifest.json` and
   re-add the `compat:gate` script.
2. **Wire a test runner.** `package.json` declares no `devDependencies`, no `test` script and no
   `vitest.config` / `eslint.config`. Add them (or delete the tests if the gate moves elsewhere).
3. **Release tag + pin.** Publish `v0.1.0` and have consumers pin the git dependency (D-1), gated
   on the `SUBMODULES_TOKEN` proof (HB-2).
4. **OpenAPI generation.** `openapi/` carries the jsonnet sources and a committed `openapi.yaml` +
   Swagger UI bundle; the build/lint command for it is not wired here yet.

## Consumers

`crdt_plugin`, `crdt_server` (both via submodule at `packages/crdt-contracts`).
`web_vault` intentionally does **not** import this package.
