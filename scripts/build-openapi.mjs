#!/usr/bin/env node
/**
 * build:openapi — render `openapi/openapi.yaml` from the jsonnet sources
 * (`openapi/src/**`) with the pinned npm jsonnet binding
 * (`@hanazuki/node-jsonnet`, pinned EXACT — no homebrew/binary dependency).
 *
 * Deterministic: the renderer emits object keys sorted (jsonnet-based
 * manifest) and the lexicographically consistent filename imports are
 * explicit, so the same sources always produce byte-identical YAML
 * (verified by `check:openapi` and an `openapiSha256` pin in
 * `compat-manifest.json`).
 *
 * Zero network, zero credentials, no data leaves the machine.
 */
import {mkdirSync, writeFileSync} from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const outPath = path.join(repoRoot, 'openapi', 'openapi.yaml');

// The binding needs createRequire (ESM `import` would load the ESM wrapper,
// which is fine too, but CJS keep it aligned with the types).
const {createRequire} = await import('node:module');
const require = createRequire(import.meta.url);
const {Jsonnet} = require('@hanazuki/node-jsonnet');

const rendered = await new Jsonnet()
	.setMaxStack(6000)
	.addJpath(path.join(repoRoot, 'openapi', 'src', 'lib'))
	.stringOutput(true)
	.evaluateFile(path.join(repoRoot, 'openapi', 'src', 'openapi.jsonnet'));

mkdirSync(path.dirname(outPath), {recursive: true});
writeFileSync(outPath, rendered, 'utf8');
console.log(`[build:openapi] rendered ${path.relative(repoRoot, outPath)} from openapi/src/**`);
