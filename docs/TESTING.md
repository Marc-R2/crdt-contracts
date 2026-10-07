# Testing & gates — `crdt-contracts`

Requires Node.js >= 22. `npm ci` compiles the `@hanazuki/node-jsonnet` native binding via
`cmake-js`, so a **CMake + C toolchain is required on the install machine** (CI sets up CMake
explicitly).

```bash
npm ci                  # needs CMake + a C toolchain (native jsonnet binding via cmake-js)
npm run build           # tsc -p tsconfig.json -> dist/ (CommonJS + .d.ts)
npm run build:openapi   # renders openapi/src/** -> openapi/openapi.yaml (pinned jsonnet devDep)
npm run check:openapi   # drift gate (rebuild + bytes + openapiSha256 pin) THEN Redocly conformance lint
npm test                # builds, then runs the contract tests (vitest)
npm run compat:gate     # builds, then verifies the compat-manifest pins vs the exports + the yaml hash
npm run check:agents    # AGENTS.md size gate (cap 24000 bytes)
```

The package declares `main: dist/index.js` + `types: dist/index.d.ts`, so **every consumer must
build it (CJS + declarations) before using it** — a source-only package breaks the compiled CJS
server (`ERR_MODULE_NOT_FOUND`). This is a hard requirement of the distribution, not a convenience.

## Gates

- **Contract tests** (`tests/unit/contracts/`, vitest): wire surface, implementation-free guard,
  `compat:gate` green + drift proof.
- **`check:openapi`** is two-part: (1) DRIFT — the render must be byte-identical to the committed
  yaml and the `openapiSha256` pin must match; (2) CONFORMANCE — `@redocly/cli` lints the contract
  (`.redocly.yaml`) so a faithfully rendered but WRONG contract (e.g. an optional path parameter
  that makes the generator drop the route) fails too. Drift alone would not have caught that class.
- **`compat:gate`** (`scripts/compat-gate.mjs`) compares the declared pins against the actual
  exported `PROTOCOL_VERSION` and the committed yaml hash. Together with `check:openapi` it proves
  pin == committed file == render.
- **`check:suite`** (`scripts/check-suite-coherence.mjs`, `--dry-run` available) is the cross-consumer
  OpenAPI bridge gate: it reads each consumer's `package.json` dependency spec + `package-lock.json`
  `resolved`/`integrity` and requires both `crdt_plugin` and `crdt_server` to reference the SAME
  contracts release tag. It needs sibling consumer checkouts and runs in `coherence.yml`.

## CI

`.github/workflows/test.yml`: build → **AGENTS.md size cap** (`npm run check:agents`) → OpenAPI gate
(drift + conformance lint) → contract tests → compatibility gate.

`.github/workflows/coherence.yml`: the cross-consumer suite coherence gate over sibling checkouts
(`check:suite:dry`/`check:suite`).

`.github/workflows/release.yml`: packs and publishes the release tarball (see `docs/RELEASE.md`).
