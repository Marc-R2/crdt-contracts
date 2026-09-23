#!/usr/bin/env node
/**
 * compat:gate — in-repo protocol-compatibility gate for `crdt-contracts`.
 *
 * WHY this exists
 * ---------------
 * After the repo split this package, the plugin and the server live in separate
 * repositories. The wire protocol (`PROTOCOL_VERSION`, room names, structure
 * entry schema) is the ONE thing that must stay in lockstep: a peer speaking a
 * different protocol can silently corrupt mixed-version self-hosted data.
 * "Both repos import the same package" is NOT a proof — a `file:` dependency
 * makes both consumers move together, so a naive bump always stays green.
 *
 * WHAT this gate checks (the package-local half of the pre-split monorepo gate;
 * the consumer-side checks stay in the parent `obsidian-crdt-sync` repo)
 * --------------------------------------------------------------------------
 * It compares the INDEPENDENT declaration (`compat-manifest.json`, the
 * consumer-facing pin) against what the package ACTUALLY exports
 * (`PROTOCOL_VERSION` in `src/protocol.ts`), plus the `contracts` pin against
 * the package version. Any drift exits non-zero with a named mismatch.
 *
 * DELIBERATE RED PROOF: bump `src/protocol.ts` to 2 without touching the pin
 * -> gate fails naming `protocolVersion`. Restore -> gate passes.
 *
 * Zero network, zero credentials, no data leaves the machine.
 */
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {createRequire} from 'node:module';
import {fileURLToPath, pathToFileURL} from 'node:url';
import path from 'node:path';

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

/**
 * Optional `--contracts-dir <dir>` override. The drift regression test points
 * this at a throwaway copy of the package (mutated pin) to prove the gate
 * fails WITHOUT mutating the real repo.
 *
 * The package lives at the repository ROOT after the extraction (it used to be
 * `packages/crdt-contracts/` in the monorepo), so the default is `repoRoot`.
 */
function readArg(name) {
	const idx = process.argv.indexOf(name);
	return idx >= 0 && idx + 1 < process.argv.length ? process.argv[idx + 1] : undefined;
}
const contractsDir = path.resolve(readArg('--contracts-dir') ?? repoRoot);
const require = createRequire(import.meta.url);

const readJson = (p) => JSON.parse(readFileSync(p, 'utf8'));

/** Reads the version the consumed package actually exports. */
async function readExportedProtocolVersion() {
	const pkgMain = path.join(contractsDir, readJson(path.join(contractsDir, 'package.json')).main);
	try {
		// Primary: the exact artifact consumers load (compiled `main`).
		const mod = require(pkgMain);
		if (typeof mod.PROTOCOL_VERSION !== 'number') {
			throw new Error(`exported PROTOCOL_VERSION is not a number: ${String(mod.PROTOCOL_VERSION)}`);
		}
		return {value: mod.PROTOCOL_VERSION, via: 'require(dist)'};
	} catch (requireErr) {
		try {
			// Fallback: TypeScript source (Node >=22.18 type stripping).
			const mod = await import(pathToFileURL(path.join(contractsDir, 'src', 'protocol.ts')).href);
			return {value: mod.PROTOCOL_VERSION, via: 'import(src)'};
		} catch (importErr) {
			// Last resort: strict source parse.
			const text = readFileSync(path.join(contractsDir, 'src', 'protocol.ts'), 'utf8');
			const match = /export\s+const\s+PROTOCOL_VERSION\s*=\s*(\d+)\s*;/u.exec(text);
			if (!match) {
				throw new Error(
					`could not read PROTOCOL_VERSION (${String(requireErr)} / ${String(importErr)})`,
				);
			}
			return {value: Number(match[1]), via: 'source-parse'};
		}
	}
}

const errors = [];
const manifest = readJson(path.join(contractsDir, 'compat-manifest.json'));
const contractsPkg = readJson(path.join(contractsDir, 'package.json'));

let exported;
try {
	exported = await readExportedProtocolVersion();
} catch (err) {
	console.error(`[compat-gate] FATAL: ${err instanceof Error ? err.message : String(err)}`);
	process.exit(1);
}

if (manifest.protocolVersion !== exported.value) {
	errors.push(
		`protocolVersion mismatch: compat-manifest.json pin=${manifest.protocolVersion} ` +
		`but the package exports ${exported.value}`,
	);
}
if (manifest.contracts !== contractsPkg.version) {
	errors.push(
		`contracts version mismatch: compat-manifest.json=${manifest.contracts} ` +
		`but package.json=${contractsPkg.version}`,
	);
}

// OpenAPI contract pin (decision C-6): the manifest carries the sha256 of the
// committed openapi.yaml so consumers can pin the REST contract. This gate
// verifies the pin against the ACTUAL committed file (cheap, no jsonnet
// render) — a wrong 64-hex pin FAILS here. The complementary half (committed
// file == jsonnet render) lives in `check:openapi`; together they prove
// pin == render without duplicating the expensive render.
if (!manifest.openapiSha256) {
	errors.push('compat-manifest.json is missing the "openapiSha256" pin (C-6)');
} else if (!/^[0-9a-f]{64}$/.test(manifest.openapiSha256)) {
	errors.push(`compat-manifest.json openapiSha256 is not a 64-hex sha256: ${manifest.openapiSha256}`);
} else {
	const yamlPath = path.join(contractsDir, 'openapi', 'openapi.yaml');
	try {
		const actual = createHash('sha256').update(readFileSync(yamlPath)).digest('hex');
		if (actual !== manifest.openapiSha256) {
			errors.push(
				`openapiSha256 mismatch: compat-manifest.json pin=${manifest.openapiSha256} ` +
				`but the committed openapi/openapi.yaml hashes to ${actual} — re-pin it ` +
				`(and re-render) in the same commit as the contract change`,
			);
		}
	} catch {
		errors.push(`openapiSha256 pin set but openapi/openapi.yaml is missing/unreadable at ${yamlPath}`);
	}
}

if (errors.length > 0) {
	console.error('[compat-gate] RED — protocol contract drift detected:');
	for (const e of errors) console.error(`  - ${e}`);
	process.exit(1);
}

console.log(
	`[compat-gate] GREEN — contracts ${manifest.contracts}, protocolVersion ${exported.value} ` +
	`(read via ${exported.via}), openapiSha256 pinned ` +
	`(${String(manifest.openapiSha256).slice(0, 12)}…); the compat pin matches the exported contract.`,
);
