#!/usr/bin/env node
/**
 * check-suite-coherence.mjs — cross-consumer OpenAPI bridge gate (re-homed).
 *
 * WHY THIS FILE EXISTS
 * --------------------
 * The OpenAPI contract is a THREE-repo bridge: this repository owns the
 * rendered `openapi/openapi.yaml` (+ its `compat-manifest.json.openapiSha256`
 * pin), and `crdt_server` / `crdt_plugin` each consume it through a pinned
 * `packages/crdt-contracts` gitlink and regenerate their own client/module with
 * a drift gate (`check:openapi`). Each consumer already proves "my artifact
 * matches the contract I pin" — but nothing proves the two consumers pin the
 * SAME contract commit, that the declared `openapiSha256` matches the yaml it
 * actually ships, or that the DELIBERATE generator-JAR divergence (server
 * 7.25.0 / plugin 7.21.0) has not silently changed. One consumer could bump its
 * nested contract pin alone and both repo-local gates would stay green while
 * the two halves of the bridge drift apart. This gate closes that hole.
 *
 * This is the re-homed `openapi-pins` job + `tools/check-openapi-pins.mjs` from
 * the umbrella `obsidian-crdt-sync` (`.github/workflows/compat.yml`), which is
 * archived. The shared dependency is the natural owner of the cross-consumer
 * coherence check, so the still-valuable invariants live here now.
 *
 * WHAT IT ASSERTS (over sibling checkouts of the two consumers)
 * -------------------------------------------------------------
 *   1. CONSUMER PIN: both consumers' `packages/crdt-contracts` gitlink is the
 *      SAME full, non-zero commit, and that commit exists in this repository.
 *      (The umbrella compared each consumer to the umbrella's own gitlink; with
 *      the umbrella gone, the meaningful cross-consumer invariant is that the
 *      two consumers AGREE, and that the agreed commit is really this repo's.
 *      An optional `--expected-pin` lets a release step pin an exact commit.)
 *   2. MANIFEST HASH: `compat-manifest.json.openapiSha256` equals the actual
 *      `sha256(openapi/openapi.yaml)` of this checkout.
 *   3. GENERATOR JAR: each consumer's `openapitools.json` generator version
 *      equals the documented expected-value map (7.25.0 / 7.21.0 — the
 *      divergence is intentional and documented in the consumer READMEs).
 *   4. CONSUMER GATE: both consumers declare a `check:openapi` script.
 *
 * DELIBERATELY DROPPED from the umbrella version
 * ----------------------------------------------
 *   - Comparing each consumer pin to the umbrella's own `crdt-contracts`
 *     gitlink. There is no umbrella pin now, and comparing to this repo's HEAD
 *     would false-fail every time `main` advances past a released commit; the
 *     cross-consumer equality + resolvability above is the durable invariant.
 *   - The remote-reachability tier (`--remote`, `SUBMODULES_TOKEN`,
 *     `verifyRemotePin` from `check-submodule-pins.mjs`): in CI the consumers
 *     are checked out with `actions/checkout` from their remotes, so
 *     reachability is already proven by the checkout itself, and the helper is
 *     archived with the umbrella.
 *
 * USAGE
 *   node scripts/check-suite-coherence.mjs [--dry-run] [--quiet]
 *       [--contracts <dir>] [--plugin <dir>] [--server <dir>]
 *       [--expected-pin <40-hex>]
 *
 *   Consumer checkouts default to `../crdt_plugin` and `../crdt_server`
 *   (siblings of this repository — both the CI layout and the umbrella layout).
 *   Override with the flags or the env vars `CRDT_PLUGIN_DIR` /
 *   `CRDT_SERVER_DIR`; `CRDT_CONTRACTS_DIR` overrides the contract root and
 *   `CRDT_EXPECTED_PIN` the optional expected pin.
 *
 *   `--dry-run` reports missing consumer checkouts instead of failing, so the
 *   gate can be rehearsed before the private siblings are cloned.
 *
 * Zero network, zero credentials, no data leaves the machine. The gitlink SHA
 * and package versions it prints are public build inputs, never secrets.
 */
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {existsSync, readFileSync, realpathSync} from 'node:fs';
import {dirname, join, resolve} from 'node:path';
import {fileURLToPath, pathToFileURL} from 'node:url';

/** The repository root (the directory holding `scripts/`). */
export const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');

/** Nested submodule path both consumers pin this repository at. */
export const CONSUMER_NESTED_PATH = 'packages/crdt-contracts';

/** Consumers of this package that the coherence gate spans. */
export const CONSUMERS = ['crdt_server', 'crdt_plugin'];

/** Env var per consumer that overrides its default checkout path. */
export const CONSUMER_ENV = {
	crdt_server: 'CRDT_SERVER_DIR',
	crdt_plugin: 'CRDT_PLUGIN_DIR',
};

/**
 * The DELIBERATE generator-JAR divergence, encoded so a silent change fails.
 *
 *  - `crdt_server` generates the scoped NestJS route module with JAR **7.25.0**
 *    (the 7.21.0 -> 7.25.0 bump fixes the omitted `VcsTreeEntry` schema).
 *  - `crdt_plugin` generates the `typescript-fetch` client with JAR **7.21.0**.
 *
 * Both consume the SAME `openapi/openapi.yaml`; the versions differ on purpose.
 */
export const EXPECTED_GENERATOR_JAR = {
	crdt_server: '7.25.0',
	crdt_plugin: '7.21.0',
};

/** sha256 (hex) of a file on disk. */
export function sha256File(file) {
	return createHash('sha256').update(readFileSync(file)).digest('hex');
}

/** Extracts the 40-hex gitlink for `path` from raw `git ls-tree` output; '' when absent. */
export function parseGitlink(output, path) {
	for (const line of output.split('\n')) {
		const match = /^160000 commit ([0-9a-f]{40})\t(.+)$/u.exec(line);
		if (match && match[2] === path) return match[1];
	}
	return '';
}

/** True for a full, non-zero 40-hex commit SHA. */
function isUsablePin(pin) {
	return /^[0-9a-f]{40}$/u.test(pin) && !/^0{40}$/u.test(pin);
}

/**
 * Pure bridge evaluation over already-gathered data. `consumers` maps a repo
 * name to `{nestedPin, jarVersion, hasCheckScript}`; `skipped` names consumers
 * whose checkout is absent (dry-run only). Returns `{errors, rows, sharedPin}`,
 * where `sharedPin` is the agreed commit when both present consumers pin one.
 */
export function evaluateSuiteCoherence({
	contractsManifest = {},
	contractsYamlSha256 = '',
	consumers = {},
	skipped = [],
	expectedPin = '',
	expectedJar = EXPECTED_GENERATOR_JAR,
}) {
	const errors = [];
	const rows = [];
	const manifestHash = contractsManifest.openapiSha256 ?? '';

	if (!manifestHash) {
		errors.push(
			'MANIFEST HASH MISSING: compat-manifest.json has no openapiSha256 — ' +
			'the contract predates the OpenAPI bridge (a verification-gated pin bump is required).',
		);
	} else if (manifestHash !== contractsYamlSha256) {
		errors.push(
			`MANIFEST HASH DRIFT: compat-manifest.json openapiSha256=${manifestHash} ` +
			`but sha256(openapi/openapi.yaml)=${contractsYamlSha256}.`,
		);
	}

	const pins = {};
	for (const name of CONSUMERS) {
		if (skipped.includes(name)) {
			rows.push({name, nestedPin: '', jarVersion: '', status: 'skipped'});
			continue;
		}
		if (!(name in consumers)) {
			errors.push(`MISSING CHECKOUT: no checkout supplied for ${name}.`);
			rows.push({name, nestedPin: '', jarVersion: '', status: 'missing'});
			continue;
		}
		const consumer = consumers[name] ?? {};
		const nestedPin = consumer.nestedPin ?? '';
		const problems = [];

		if (!nestedPin) {
			problems.push(
				`MISSING GITLINK: ${name} records no ${CONSUMER_NESTED_PATH} pin ` +
				'(submodule not initialized?).',
			);
		} else if (!isUsablePin(nestedPin)) {
			problems.push(`BAD PIN: ${name} ${CONSUMER_NESTED_PATH} is not a usable commit (${nestedPin}).`);
		}

		const expected = expectedJar[name];
		if (consumer.jarVersion !== expected) {
			problems.push(
				`GENERATOR JAR DRIFT: ${name} pins generator ${consumer.jarVersion || '<unset>'}, ` +
				`expected ${expected} (deliberate divergence, documented in the consumer README).`,
			);
		}

		if (!consumer.hasCheckScript) {
			problems.push(`MISSING GATE: ${name} package.json has no check:openapi script.`);
		}

		pins[name] = nestedPin;
		errors.push(...problems);
		rows.push({
			name,
			nestedPin,
			jarVersion: consumer.jarVersion ?? '',
			status: problems.length ? 'error' : 'ok',
		});
	}

	const present = CONSUMERS.filter((name) => pins[name] !== undefined);
	const usable = [...new Set(present.map((name) => pins[name]).filter(isUsablePin))];
	if (usable.length > 1) {
		const detail = present.map((name) => `${name}=${pins[name] || '(none)'}`).join(', ');
		errors.push(
			`CONSUMER PIN DRIFT: the consumers disagree on ${CONSUMER_NESTED_PATH} (${detail}); ` +
			'they must pin the SAME crdt-contracts commit.',
		);
		for (const row of rows) if (row.status === 'ok') row.status = 'error';
	}
	if (expectedPin && usable.length === 1 && usable[0] !== expectedPin) {
		errors.push(`EXPECTED PIN MISMATCH: consumers pin ${usable[0]}, expected ${expectedPin}.`);
	}

	return {errors, rows, sharedPin: usable.length === 1 ? usable[0] : ''};
}

/** Runs git in `cwd`, capturing stderr so callers can report a sanitized reason. */
function git(cwd, args) {
	return execFileSync('git', ['-C', cwd, ...args], {encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe']}).trim();
}

/** True when `sha` is a commit object in the repository at `cwd`. */
export function pinExists(cwd, sha) {
	try {
		git(cwd, ['cat-file', '-e', `${sha}^{commit}`]);
		return true;
	} catch {
		return false;
	}
}

/** Reads a JSON file, throwing a path-annotated error when it is missing. */
function readJson(file) {
	try {
		return JSON.parse(readFileSync(file, 'utf8'));
	} catch (error) {
		throw new Error(`cannot read ${file}: ${error.message}`, {cause: error});
	}
}

/** Reads a JSON file, returning `null` when it is absent (optional consumer files). */
function readJsonOrNull(file) {
	try {
		return JSON.parse(readFileSync(file, 'utf8'));
	} catch {
		return null;
	}
}

/** Reads the `packages/crdt-contracts` gitlink recorded at a consumer's HEAD. */
export function readNestedPin(dir) {
	return parseGitlink(git(dir, ['ls-tree', 'HEAD', CONSUMER_NESTED_PATH]), CONSUMER_NESTED_PATH);
}

/** Gathers the bridge inputs from this repository and the consumer checkouts. */
export function gatherSuiteCoherence({contractsDir, consumerDirs}) {
	const contractsHead = git(contractsDir, ['rev-parse', 'HEAD']);
	const contractsManifest = readJson(join(contractsDir, 'compat-manifest.json'));
	const contractsYamlSha256 = sha256File(join(contractsDir, 'openapi', 'openapi.yaml'));

	const consumers = {};
	const skipped = [];
	for (const name of CONSUMERS) {
		const dir = consumerDirs[name];
		if (!existsSync(dir)) {
			skipped.push(name);
			continue;
		}
		const pkg = readJsonOrNull(join(dir, 'package.json')) ?? {};
		const tools = readJsonOrNull(join(dir, 'openapitools.json')) ?? {};
		consumers[name] = {
			nestedPin: readNestedPin(dir),
			jarVersion: tools?.['generator-cli']?.version ?? '',
			hasCheckScript: Boolean(pkg.scripts?.['check:openapi']),
		};
	}

	return {contractsHead, contractsManifest, contractsYamlSha256, consumers, skipped};
}

/** Parses CLI flags; unknown flags throw so a typo cannot silently widen the gate. */
export function parseArgs(argv) {
	const args = {dryRun: false, quiet: false};
	const valued = new Set(['--contracts', '--plugin', '--server', '--expected-pin']);
	for (let i = 0; i < argv.length; i += 1) {
		const arg = argv[i];
		if (arg === '--dry-run') args.dryRun = true;
		else if (arg === '--quiet') args.quiet = true;
		else if (valued.has(arg)) args[arg.slice(2)] = argv[++i];
		else throw new Error(`unknown argument ${arg}`);
	}
	return args;
}

/** Resolves each consumer checkout dir from flags, env, then the sibling default. */
export function resolveConsumerDirs(args, env = process.env) {
	const dirs = {};
	for (const name of CONSUMERS) {
		const override = args[name.replace('_', '-')] ?? env[CONSUMER_ENV[name]];
		dirs[name] = resolve(override ?? join(ROOT, '..', name));
	}
	return dirs;
}

function main() {
	let args;
	try {
		args = parseArgs(process.argv.slice(2));
	} catch (error) {
		console.error(`[check:suite] ${error.message}`);
		process.exit(2);
	}

	const contractsDir = resolve(args.contracts ?? process.env.CRDT_CONTRACTS_DIR ?? ROOT);
	const consumerDirs = resolveConsumerDirs(args);
	const expectedPin = args['expected-pin'] ?? process.env.CRDT_EXPECTED_PIN ?? '';

	let data;
	try {
		data = gatherSuiteCoherence({contractsDir, consumerDirs});
	} catch (error) {
		console.error('[check:suite] cannot read the coherence inputs');
		console.error(`  ${error.message}`);
		console.error(
			'  The contract checkout must be intact and each consumer must be a git checkout ' +
			'(siblings are PRIVATE: clone them or provide SUBMODULES_TOKEN in CI).',
		);
		process.exit(1);
	}

	const {errors, rows, sharedPin} = evaluateSuiteCoherence({
		contractsManifest: data.contractsManifest,
		contractsYamlSha256: data.contractsYamlSha256,
		consumers: data.consumers,
		skipped: data.skipped,
		expectedPin,
	});
	const failures = [...errors];

	if (sharedPin && !pinExists(contractsDir, sharedPin)) {
		failures.push(
			`UNKNOWN CONTRACT PIN: ${sharedPin} is not a commit in this crdt-contracts checkout ` +
			'(the consumers must pin a commit of THIS repository; a shallow clone needs full history).',
		);
	}

	if (data.skipped.length) {
		const note = `checkout(s) absent at ${data.skipped.map((name) => consumerDirs[name]).join(', ')}`;
		if (args.dryRun) {
			if (!args.quiet) console.log(`[check:suite] dry-run: skipping ${data.skipped.join(', ')} (${note}).`);
		} else {
			failures.push(`MISSING CONSUMER CHECKOUT: ${data.skipped.join(', ')} — ${note}.`);
		}
	}

	if (!args.quiet) {
		console.log(`[check:suite] contracts HEAD=${data.contractsHead} yamlSha256=${data.contractsYamlSha256}`);
		for (const row of rows) {
			console.log(
				`  ${row.status.padEnd(7)}  ${row.name.padEnd(12)}  pin=${row.nestedPin || '(none)'}  ` +
				`jar=${row.jarVersion || '(none)'}`,
			);
		}
	}

	const mode = args.dryRun ? 'dry-run' : 'enforce';
	console.log(
		`[check:suite] mode=${mode} consumers=${CONSUMERS.length} sharedPin=${sharedPin || '(none)'} ` +
		`errors=${failures.length}`,
	);
	for (const failure of failures) console.log(`  ${failure}`);
	process.exit(failures.length ? 1 : 0);
}

/** True only when executed directly (macOS `/var` -> `/private/var` symlink safe). */
export function isCliEntry(metaUrl, argv1) {
	if (!argv1) return false;
	try {
		return realpathSync(fileURLToPath(metaUrl)) === realpathSync(argv1);
	} catch {
		return metaUrl === pathToFileURL(argv1).href;
	}
}

if (isCliEntry(import.meta.url, process.argv[1])) main();
