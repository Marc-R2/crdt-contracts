# Architecture — `crdt-contracts`

Deeper detail behind the lean `AGENTS.md`: the implementation-free boundary, the contract surface,
the docId schema and the OpenAPI pipeline.

## Implementation-free boundary

The package is **types and constants ONLY** — no functions, no classes, no arrow functions, no
UUID/crypto sources, no filesystem or DOM access, no Yjs, no NestJS runtime. Minting, predicates,
validators and room-name helpers stay in the consuming repos. Enforced by
`tests/unit/contracts/implementationFree.test.ts`.

Where the behavior lives instead:

- `freshTypedDocId` and the read predicates (`isBlobDocId`/`isLiveEditDocId`/`isCrdtDocId`/
  `docIdPrefixOf`) are PLUGIN code (`crdt_plugin/src/sync/docType.ts`).
- Blob validators (`assertSafeBlobHash`, `isUsableBlob`) and their behavior tests live in SERVER.
- `server/src/generated-api-module/**` is a SERVER runtime stub, not a contract.

Do NOT add behavior "for convenience" — it breaks the implementation-free guard and the consumer
parity model.

## Contract surface (`src/`)

| File | Contents |
|---|---|
| `docType.ts` | `DocType` enum (`text\|map\|json\|list\|xml\|frag\|blob`), `DocumentId`, `DOCID_PREFIXES` (`text:`/`map:`/`json:`/`list:`/`xml:`/`frag:`/`sha256:`), `BLOB_DOCID_PREFIX`. |
| `blob.ts` | `EMPTY_SHA256`, `SHA256_HEX_REGEX`, `BlobDocId`, `CRDT_DOCID_PREFIXES`. |
| `blobTypes.ts` | `/blobs/*` REST payload interfaces (batch-check, manifest, chunk status). |
| `history.ts` | History timeline wire types (index, checkpoints, commits, chunk updates). |
| `vcs.ts` | Git/VCS domain types shared by plugin and server. |
| `protocol.ts` | `PROTOCOL_VERSION` — the single integer pinning room-name/entry-schema compatibility. |
| `capabilities.ts` | `CAPABILITIES` (canonical additive feature flags: `snapshots.v1`, `blobs.chunked.v1`, `doc-status.v1`, `history.v1`, `vcs.v1`), `Capability`, `CAPABILITY_VALUES`. |
| `serverInfo.ts` | `ServerInfoResponse` / `ServerInfoVersions` — the `GET /` wire shape: `versions.protocol` (hard gate) + optional `capabilities`. |
| `index.ts` | The public surface (re-exports all of the above). |

Keep the public surface grouped by domain (blob/protocol/history/vcs) and re-export from `index.ts`.

## Capability negotiation (additive feature flags)

`capabilities` is the suite-wide mechanism that lets a plugin run against MULTIPLE server versions
**by feature, not by version number**:

- **`protocol` is the ONLY hard gate.** The plugin fails visible on a `versions.protocol` mismatch;
  it never branches on a server version number.
- **Capabilities are additive booleans.** `GET /` carries `capabilities: string[]`; a flag absent
  from the list means the feature is simply **off** (no error). An older server that omits the field
  entirely is handled tolerantly — every feature resolves to off.
- Flags are namespaced `<feature>.<revision>` so a future breaking change can advertise
  `snapshots.v2` next to `snapshots.v1` without renaming. Adding/removing a flag is a MINOR contracts
  change; it never touches `PROTOCOL_VERSION`.


## docId prefix schema (the contract)

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

## OpenAPI pipeline

`openapi/` carries the OpenAPI 3 contract as a **jsonnet → yaml pipeline**:

- `openapi/src/**` — the jsonnet **sources** (the edit targets).
- `openapi/openapi.yaml` — the **generated artifact**. It is committed but is a BUILD PRODUCT:
  never hand-edit it; edit the jsonnet sources and re-run `build:openapi`.
- Swagger UI assets live here too (moved from the former `server/docs/`).

The REST contract is rendered with the **pinned npm devDependency** `@hanazuki/node-jsonnet@3.3.1`
(exact pin) — no brew/global binary dependency. The binding builds natively via `cmake-js` at
`npm ci` time, so the install machine needs CMake + a C toolchain (CI sets up CMake explicitly);
consumers of the contracts only need the build output, never a jsonnet render.

The render is byte-stable (keys sorted by the renderer) and was verified byte-identical across the
CJS binding and the old CLI binary. `openapi-generator` is NOT needed here — it stays a Phase-B/C
concern of the CONSUMERS (server module / plugin client generation), which read this package's
rendered contract.

`openapiSha256` (in `compat-manifest.json`) is the sha256 of the rendered `openapi/openapi.yaml`
(decision C-6). `versionsUiSha256` is deliberately NOT in the manifest (the shared-CSS invariant is
repo-local + cross-checked — see `web_vault/AGENTS.md`).
