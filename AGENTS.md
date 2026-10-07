# AGENTS.md — crdt-contracts

**Language contract (user directive, 2026-09-01): ALWAYS work in English** — code, commit
messages, reports, thinking, agent briefs, git notes, AGENTS.md edits. The user usually writes
German; that NEVER changes the output language. Only an EXPLICIT user request for another language
overrides this. Subagents must receive this rule in their briefs.

Implementation-free **wire contracts** (types + constants only) shared by the Obsidian plugin
(`crdt_plugin`) and the sync server (`crdt_server`). Former monorepo `packages/crdt-contracts/**`
promoted to the repository root. Consumers install the **public** GitHub Release tarball
`@marc-r2/crdt-contracts` (currently `v0.1.0`) via `package.json`; no submodule, no sibling checkout.

- This repository consumes **no** sibling repository and has no submodules.
- `web_vault` and `crdt-e2e-catalog` are intentionally NOT consumers.
- Umbrella: `Marc-R2/obsidian-crdt-sync`; split plan `docs/REPO_SPLIT_PLAN.md` (parent repo).

## Commands

```bash
npm ci                  # needs CMake + a C toolchain (native jsonnet binding via cmake-js)
npm run build           # tsc -p tsconfig.json -> dist/ (CommonJS + .d.ts)
npm run build:openapi   # renders openapi/src/** -> openapi/openapi.yaml (pinned jsonnet devDep)
npm run check:openapi   # drift gate (rebuild + bytes + openapiSha256 pin) THEN Redocly lint
npm test                # builds, then runs the contract tests (vitest)
npm run compat:gate     # builds, then verifies the compat-manifest pins vs the exports + yaml hash
npm run check:agents    # AGENTS.md size gate (cap 24000 bytes)
npm run check:suite     # cross-consumer OpenAPI bridge gate (needs sibling checkouts)
```

Requires Node.js >= 22. The package emits CommonJS + `.d.ts`; **every consumer needs the built
`dist/`** (a source-only package breaks the compiled CJS server with `ERR_MODULE_NOT_FOUND`).

## Critical invariants

- **Implementation-free.** Types and constants ONLY — no functions/classes/UUID/crypto/fs/DOM/Yjs/
  NestJS runtime. Minting, predicates, validators, room-name helpers live in the consumers. Guard:
  `tests/unit/contracts/implementationFree.test.ts`. Never add behavior "for convenience".
- **`openapi/openapi.yaml` is a BUILD PRODUCT.** Never hand-edit it; edit the jsonnet under
  `openapi/src/**` and re-run `npm run build:openapi`.
- **`compat-manifest.json` stays in lockstep** with the code (enforced by tests + `compat:gate` +
  `check:openapi`): `protocolVersion` == `PROTOCOL_VERSION` in `src/protocol.ts`;
  `contracts` == `package.json` `version`; `openapiSha256` == sha256 of the rendered yaml. Edit the
  code, the yaml and the manifest in the SAME commit. A protocol/type bump is a breaking change.
- **docId ≠ globalId.** The type prefix (`text:`, `map:`, …) lives ONLY on the docId; rooms, server
  data and history use the unprefixed globalId. The prefix constants here are canonical; the strict
  predicates and the rehome contract are consumer-side. NO legacy bare-UUID fallback.
- **Commit discipline.** Small, self-contained, atomic commits; never mix unrelated changes. Strict
  TDD (failing contract/drift test first, then the minimal change). Every commit carries a
  `git notes add` with (1) context & rationale and (2) privacy & security guarantees (zero data
  egress, credential hygiene, local-only processing).
- **AGENTS.md size cap: 24000 bytes** (`npm run check:agents`). Keep this file lean; put detail in
  `docs/`.

## Key pointers

- `src/` — the contract surface (`docType.ts`, `blob.ts`, `blobTypes.ts`, `history.ts`, `vcs.ts`,
  `protocol.ts`, `capabilities.ts`, `serverInfo.ts`, `index.ts`).
- `src/capabilities.ts` + `src/serverInfo.ts` — additive feature negotiation: `CAPABILITIES`/
  `Capability` and the `GET /` wire shape (`versions.protocol` hard gate + optional `capabilities`).
  A capability absent from the list means the feature is OFF, never an error; the plugin never
  branches on a server version number. Adding a flag is a MINOR change (never a protocol bump).
- `openapi/src/**` — jsonnet edit targets; `openapi/openapi.yaml` — generated artifact.
- `compat-manifest.json` — the consumer-facing compatibility pin.
- `tests/unit/contracts/` — contract tests; `scripts/` — the build/gate scripts.
- Conventions: indentation tabs, tab width 4 (`.editorconfig`); files > ~300 lines should be split.

## Deeper docs

- `docs/ARCHITECTURE.md` — implementation-free boundary, contract surface, docId schema, OpenAPI pipeline.
- `docs/TESTING.md` — exact gates and CI jobs.
- `docs/RELEASE.md` — compat manifest, tarball acquisition, release process.
- `docs/STATUS.md` — verified state and open follow-ups.
- `README.md` — package overview and layout.
