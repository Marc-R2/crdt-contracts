#!/usr/bin/env node
/**
 * check:openapi — rendered-contract drift gate for `openapi/openapi.yaml`.
 *
 * WHAT it checks
 * --------------
 * 1. Re-render `openapi/openapi.yaml` from the jsonnet sources with the same
 *    pinned toolchain as `build:openapi` and require the committed file to be
 *    byte-identical (a hand-edit of the yaml exits non-zero — edit the
 *    `openapi/src/**` sources instead, that is the whole point of the
 *    source-of-truth rule).
 * 2. Verify the `openapiSha256` field of `compat-manifest.json` against the
 *    ACTUAL sha256 of the rendered document (completes decision C-6: the
 *    consumers pin the REST contract, not just `PROTOCOL_VERSION`).
 *
 * ROLLBACK / red-proof: hand-edit one character in `openapi/openapi.yaml`
 * (or bump a schema in `openapi/src/**` without re-rendering) -> the gate
 * exits 1 naming the mismatch. Restore -> green.
 *
 * Zero network, zero credentials, no data leaves the machine.
 */
import {readFileSync, statSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {createRequire} from 'node:module';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const yamlPath = path.join(repoRoot, 'openapi', 'openapi.yaml');
const srcPath = path.join(repoRoot, 'openapi', 'src', 'openapi.jsonnet');
const libDir = path.join(repoRoot, 'openapi', 'src', 'lib');
const manifestPath = path.join(repoRoot, 'compat-manifest.json');

const errors = [];
const sha256 = (file) => createHash('sha256').update(readFileSync(file)).digest('hex');

// 1. Render into a throwaway copy (never touching the working tree).
const require = createRequire(import.meta.url);
const {Jsonnet} = require('@hanazuki/node-jsonnet');
const rendered = await new Jsonnet()
	.setMaxStack(6000)
	.addJpath(libDir)
	.stringOutput(true)
	.evaluateFile(srcPath);

if (!statSync(yamlPath, {throwIfNoEntry: false})) {
	errors.push(`openapi/openapi.yaml is missing — run \`npm run build:openapi\` to (re)generate it.`);
} else {
	const committed = readFileSync(yamlPath, 'utf8');
	if (committed !== rendered) {
		errors.push(
			`openapi/openapi.yaml is NOT byte-identical to the jsonnet render of openapi/src/** — ` +
			`run \`npm run build:openapi\` (a hand-edit of the yaml must NOT be committed).`,
		);
	}
}

// 2. Manifest pin vs. the actual rendered document.
let manifest;
try {
	manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
} catch (err) {
	console.error(`[check:openapi] FATAL: cannot read compat-manifest.json: ${String(err)}`);
	process.exit(1);
}
const actualSha = createHash('sha256').update(rendered, 'utf8').digest('hex');
if (!manifest.openapiSha256) {
	errors.push('compat-manifest.json is missing the "openapiSha256" pin (decision C-6).');
} else if (manifest.openapiSha256 !== actualSha) {
	errors.push(
		`openapiSha256 mismatch: compat-manifest.json pin=${manifest.openapiSha256} ` +
		`but the RENDERED contract is ${actualSha} — re-pin it after a deliberate contract change.`,
	);
}

// 3. The contract itself must not reference undefined schemas (cheap local
//    check; catches lib files that re-export schemas the manifest never
//    carries). BearerAuth is a securitySchemes name, not a schema.
const defined = new Set(
	[...rendered.matchAll(/^    ([A-Za-z][A-Za-z0-9]+):$/gm)].map((m) => m[1]),
);
const referenced = new Set(
	[...rendered.matchAll(/"#{1}\/components\/schemas\/([A-Za-z0-9]+)"/g)].map((m) => m[1]),
);
const undefinedRefs = [...referenced].filter((name) => !defined.has(name));
if (undefinedRefs.length > 0) {
	errors.push(`openapi/openapi.yaml references UNDEFINED schemas: ${undefinedRefs.join(', ')}`);
}

if (errors.length > 0) {
	console.error('[check:openapi] RED — OpenAPI contract drift detected:');
	for (const e of errors) console.error(`  - ${e}`);
	process.exit(1);
}

console.log(
	`[check:openapi] GREEN — rendered yaml is byte-identical, openapiSha256 pin matches ` +
	`(${actualSha.slice(0, 12)}…), all $refs resolve.`,
);
