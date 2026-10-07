# Release & versioning — `crdt-contracts`

## Compat manifest (the pin)

`compat-manifest.json` must stay in lockstep with the code:

```json
{ "contracts": "0.2.0", "protocolVersion": 1, "openapiSha256": "<64-hex sha256 of openapi/openapi.yaml>" }
```

- `protocolVersion` must equal `PROTOCOL_VERSION` in `src/protocol.ts` (bump it on **any** breaking
  room-name or structure-entry-schema change).
- `contracts` must equal `version` in `package.json`.
- `openapiSha256` must equal the sha256 of the RENDERED `openapi/openapi.yaml` (decision C-6).
  After a deliberate contract change: edit `openapi/src/**`, re-run `npm run build:openapi`,
  re-compute the pin, update `compat-manifest.json` in the SAME commit.
- Enforced here by `tests/unit/contracts/`, the repo-local `compat:gate`
  (`scripts/compat-gate.mjs`: all pins vs the actual export AND `openapiSha256` vs the committed
  yaml hash) and `check:openapi` (render-vs-file byte equality + the Redocly conformance lint).
  Wired into CI right after build.

A protocol/type bump is a **breaking change**: update `compat-manifest.json` + `protocol.ts` together
and note the migration in the commit/PR.

## How consumers obtain this package

Consumers (crdt_plugin, crdt_server) install the **public** GitHub Release tarball via a `package.json`
URL — no submodule, no token, no sibling checkout:

```
"@marc-r2/crdt-contracts":
  "https://github.com/Marc-R2/crdt-contracts/releases/download/v0.2.0/marc-r2-crdt-contracts-0.2.0.tgz"
```

`package-lock.json` records the tarball's `resolved` URL + `integrity`, so `npm ci` installs it
anonymously. The tarball ships prebuilt `dist/`, `src/`, `compat-manifest.json` and
`openapi/openapi.yaml`, so consumers need no contracts build step.

To pick up a new contracts change: publish a new release here, then bump the tarball URL in each
consumer's `package.json` and refresh its lockfile (`npm install`) and generated artifacts.

The consumer `compat:gate` compares the declared pin against the actual exported
`PROTOCOL_VERSION`; the cross-repo `compat`/coherence job additionally boots the pinned SERVER and
asserts `compat-manifest.protocolVersion === server.versions.protocol`.

## Release process

Release = an **unprefixed** git tag `vX.Y.Z` (npm publish route rejected). `release.yml`:

1. verifies the tag matches `package.json` `version`;
2. runs `release:pack` (`build:openapi && build && compat:gate && npm pack`);
3. locates/inspects the tarball;
4. publishes the GitHub Release with the tarball;
5. re-reads the release to verify it and its assets.

`npm run release:pack` builds the tarball locally without publishing.
