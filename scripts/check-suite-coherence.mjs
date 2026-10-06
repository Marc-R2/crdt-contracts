#!/usr/bin/env node
/**
 * check-suite-coherence.mjs — cross-consumer OpenAPI bridge gate.
 *
 * WHY THIS FILE EXISTS
 * --------------------
 * The OpenAPI contract is a THREE-repo bridge: this repository owns the
 * rendered `openapi/openapi.yaml` (+ its `compat-manifest.json.openapiSha256`
 * pin), and `crdt_server` / `crdt_plugin` each consume it through a release
 * tarball and regenerate their own client/module with a drift gate
 * (`check:openapi`). Each consumer already proves "my artifact matches the
 * contract I pin" — but nothing proves the two consumers reference the SAME
 * crdt-contracts release, that the declared `openapiSha256` matches the yaml it
 * actually ships, or that the DELIBERATE generator-JAR divergence (server
 * 7.25.0 / plugin 7.21.0) has not silently changed. One consumer could bump its
 * contract release alone and both repo-local gates would stay green while the
 * two halves of the bridge drift apart. This gate closes that hole.
 *
 * MIGRATION: NESTED SUBMODULE -> RELEASE TARBALL
 * ----------------------------------------------
 * Consumers used to pin a `packages/crdt-contracts` gitlink and depend on it
 * via `"@marc-r2/crdt-contracts": "file:packages/crdt-contracts"`. They now
 * install a prebuilt tarball over plain HTTPS:
 *
 *   https://github.com/Marc-R2/crdt-contracts/releases/download/vX.Y.Z/marc-r2-crdt-contracts-X.Y.Z.tgz
 *
 * so there is no gitlink to read. This gate instead reads each consumer's
 * `package.json` dependency spec AND its `package-lock.json` `resolved` URL +
 * `integrity`, parses the `vX.Y.Z` release tag from either, and requires both
 * consumers to reference the SAME tag.
 *
 * WHAT IT ASSERTS (over sibling checkouts of the two consumers)
 * -------------------------------------------------------------
 *   1. RELEASE DEP: each consumer declares `@marc-r2/crdt-contracts` as a
 *      release-tarball URL (or a declared version) — never the legacy
 *      `file:`/`link:`/git form — and its `package-lock.json` records a
 *      `resolved` URL plus an `integrity` hash.
 *   2. SHARED RELEASE: both consumers reference the SAME `vX.Y.Z` release/tag
 *      (the spec and lockfile must agree within each consumer too). An optional
 *      `--expected-version` lets a release step pin an exact version.
 *   3. RELEASE REACHABLE: the shared tag exists in THIS repository — the
 *      adapted reachability check that replaces the old gitlink "commit exists"
 *      assertion.
 *   4. MANIFEST HASH: `compat-manifest.json.openapiSha256` equals the actual
 *      `sha256(openapi/openapi.yaml)` of this checkout.
 *   5. GENERATOR JAR: each consumer's `openapitools.json` generator version
 *      equals the documented expected-value map (7.25.0 / 7.21.0 — the
 *      divergence is intentional and documented in the consumer READMEs).
 *   6. CONSUMER GATE: both consumers declare a `check:openapi` script.
 *
 * DELIBERATELY DROPPED
 * --------------------
 *   - Reading the `packages/crdt-contracts` gitlink (`git ls-tree`), and the
 *     `parseGitlink` / `readNestedPin` / `pinExists` helpers plus the old
 *     `--expected-pin` flag: the nested submodule no longer exists.
 *   - The umbrella remote-reachability tier (`verifyRemotePin`,
 *     `SUBMODULES_TOKEN` inside the script): the local tag check above plus the
 *     CI checkout already prove reachability. The workflow still needs
 *     `SUBMODULES_TOKEN` to check out the PRIVATE consumers themselves.
 *
 * USAGE
 *   node scripts/check-suite-coherence.mjs [--dry-run] [--quiet]
 *       [--contracts <dir>] [--plugin <dir>] [--server <dir>]
 *       [--expected-version <X.Y.Z>]
 *
 *   Consumer checkouts default to `../crdt_plugin` and `../crdt_server`
 *   (siblings of this repository — both the CI layout and the umbrella layout).
 *   Override with the flags or the env vars `CRDT_PLUGIN_DIR` /
 *   `CRDT_SERVER_DIR`; `CRDT_CONTRACTS_DIR` overrides the contract root and
 *   `CRDT_EXPECTED_VERSION` the optional expected version.
 *
 *   `--dry-run` reports missing consumer checkouts instead of failing, so the
 *   gate can be rehearsed before the private siblings are cloned.
 *
 * Zero network, zero credentials, no data leaves the machine. The release tag,
 * integrity hash and generator versions it prints are public build inputs,
 * never secrets.
 */
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {existsSync, readFileSync, realpathSync} from 'node:fs';
import {dirname, join, resolve} from 'node:path';
import {fileURLToPath, pathToFileURL} from 'node:url';

/** The repository root (the directory holding `scripts/`). */
export const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');

/** The package name both consumers depend on. */
export const CONTRACTS_NAME = '@marc-r2/crdt-contracts';

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

/** `vX.Y.Z` (optionally suffixed) captured from a release-download URL. */
const RELEASE_TAG = /releases\/download\/(v\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?)\/([^/?#]+)/u;

/** A bare or declared `vX.Y.Z` version spec (range operators stripped by caller). */
const SEMVER = /^v?(\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?)$/u;

/** sha256 (hex) of a file on disk. */
export function sha256File(file) {
	return createHash('sha256').update(readFileSync(file)).digest('hex');
}

/** True when `url` is a release-download URL of THIS repository. */
export function isReleaseUrlForRepo(url) {
	return /^https?:\/\/github\.com\/marc-r2\/crdt-contracts\/releases\/download\//iu.test(url ?? '');
}

/**
 * Extracts the release `{tag, version, asset}` from a GitHub release-download
 * URL; `null` when the URL carries no `releases/download/vX.Y.Z/<asset>` path.
 */
export function parseReleaseUrl(url) {
	const match = RELEASE_TAG.exec(url ?? '');
	if (!match) return null;
	return {tag: match[1], version: match[1].replace(/^v/u, ''), asset: match[2]};
}

/**
 * Parses a declared dependency version (`0.1.0`, `^0.1.0`, `~0.1.0`, `v0.1.0`)
 * into `{tag, version, ranged}`; `null` when it is not a version at all.
 */
export function parseDeclaredVersion(spec) {
	const trimmed = (spec ?? '').trim();
	const bare = trimmed.replace(/^[\^~>=<\s]+/u, '');
	const match = SEMVER.exec(bare);
	if (!match) return null;
	return {tag: `v${match[1]}`, version: match[1], ranged: trimmed !== bare};
}

/**
 * Broadens {@link parseVersionSpec} over either dependency form:
 * `{version, tag, kind: 'release-url' | 'exact' | 'range'}` or `null`.
 */
export function parseVersionSpec(spec) {
	if (!spec) return null;
	if (isReleaseUrlForRepo(spec)) {
		const release = parseReleaseUrl(spec);
		return release ? {...release, kind: 'release-url'} : null;
	}
	const declared = parseDeclaredVersion(spec);
	return declared ? {...declared, kind: declared.ranged ? 'range' : 'exact'} : null;
}

/** True for the migrated-away nested-submodule / link / git dependency forms. */
export function isLegacyRef(spec) {
	return /^(file|link|workspace|portal):/u.test(spec) ||
		/^git\+/u.test(spec) ||
		/^github:/u.test(spec) ||
		(spec ?? '').includes('.git');
}

/** Returns the consumer's declared spec for the contracts package, '' when absent. */
export function findDependency(pkg) {
	for (const field of ['dependencies', 'devDependencies', 'peerDependencies', 'optionalDependencies']) {
		const value = pkg?.[field]?.[CONTRACTS_NAME];
		if (value) return value;
	}
	return '';
}

/** Returns the lockfile entry for the contracts package (npm v7+ then v6), or null. */
export function findLockEntry(lock) {
	if (!lock) return null;
	return lock.packages?.[`node_modules/${CONTRACTS_NAME}`] ?? lock.dependencies?.[CONTRACTS_NAME] ?? null;
}

/**
 * Pure bridge evaluation over already-gathered data. `consumers` maps a repo
 * name to `{depSpec, lockPresent, lockResolved, lockIntegrity, lockVersion,
 * jarVersion, hasCheckScript}`; `skipped` names consumers whose checkout is
 * absent (dry-run only). Returns `{errors, rows, sharedVersion, sharedTag}`,
 * where `sharedVersion`/`sharedTag` are the agreed release when both present
 * consumers reference one.
 */
export function evaluateSuiteCoherence({
	contractsManifest = {},
	contractsYamlSha256 = '',
	consumers = {},
	skipped = [],
	expectedVersion = '',
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

	const versions = {};
	for (const name of CONSUMERS) {
		if (skipped.includes(name)) {
			rows.push({name, version: '', tag: '', jarVersion: '', status: 'skipped'});
			continue;
		}
		if (!(name in consumers)) {
			errors.push(`MISSING CHECKOUT: no checkout supplied for ${name}.`);
			rows.push({name, version: '', tag: '', jarVersion: '', status: 'missing'});
			continue;
		}

		const consumer = consumers[name] ?? {};
		const problems = [];
		const dep = (consumer.depSpec ?? '').trim();
		const legacy = Boolean(dep) && isLegacyRef(dep);
		const spec = legacy ? null : parseVersionSpec(dep);

		if (!dep) {
			problems.push(`MISSING DEPENDENCY: ${name} package.json does not declare ${CONTRACTS_NAME}.`);
		} else if (legacy) {
			problems.push(
				`LEGACY DEPENDENCY FORM: ${name} still declares ${CONTRACTS_NAME} as "${dep}" ` +
				'(nested gitlink/link). Migrate to the release-tarball URL.',
			);
		} else if (!spec) {
			problems.push(
				`UNSUPPORTED DEPENDENCY: ${name} ${CONTRACTS_NAME} spec "${dep}" is neither a ` +
				'crdt-contracts release-tarball URL nor a declared version.',
			);
		}

		if (!consumer.lockPresent) {
			problems.push(
				`MISSING LOCKFILE: ${name} has no package-lock.json; the gate needs the ` +
				'resolved URL + integrity to prove the pinned release.',
			);
		} else {
			if (!consumer.lockResolved) {
				problems.push(`MISSING LOCK RESOLVED URL: ${name} package-lock.json has no resolved URL for ${CONTRACTS_NAME}.`);
			}
			if (!consumer.lockIntegrity) {
				problems.push(`MISSING LOCK INTEGRITY: ${name} package-lock.json has no integrity hash for ${CONTRACTS_NAME}.`);
			}
		}
		if (spec?.kind === 'release-url' && consumer.lockResolved && !isReleaseUrlForRepo(consumer.lockResolved)) {
			problems.push(
				`LOCK NOT A RELEASE URL: ${name} package-lock resolves "${consumer.lockResolved}", ` +
				'expected a crdt-contracts releases/download URL.',
			);
		}

		const lockSpec = parseVersionSpec(consumer.lockResolved);
		const specVersion = spec?.version ?? '';
		const lockVersion = lockSpec?.version ?? (consumer.lockVersion ?? '');
		if (specVersion && lockVersion && specVersion !== lockVersion) {
			problems.push(
				`DEP/LOCK MISMATCH: ${name} declares ${specVersion} but package-lock resolves ${lockVersion}.`,
			);
		}
		const version = specVersion || lockVersion || '';
		const tag = spec?.tag || (version ? `v${version}` : '');
		if (!version) {
			problems.push(`UNKNOWN VERSION: ${name} does not pin a resolvable ${CONTRACTS_NAME} version.`);
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

		versions[name] = version;
		errors.push(...problems);
		rows.push({
			name,
			version,
			tag,
			jarVersion: consumer.jarVersion ?? '',
			status: problems.length ? 'error' : 'ok',
		});
	}

	const present = CONSUMERS.filter((name) => versions[name] !== undefined);
	const distinct = [...new Set(present.map((name) => versions[name]).filter(Boolean))];
	if (distinct.length > 1) {
		const detail = present.map((name) => `${name}=${versions[name] || '(none)'}`).join(', ');
		errors.push(
			`CONSUMER VERSION DRIFT: the consumers reference different ${CONTRACTS_NAME} ` +
			`releases (${detail}); they must use the SAME release tag.`,
		);
		for (const row of rows) if (row.status === 'ok') row.status = 'error';
	}
	const sharedVersion = distinct.length === 1 ? distinct[0] : '';
	const sharedTag = sharedVersion ? `v${sharedVersion}` : '';
	const normalizedExpected = expectedVersion.replace(/^v/u, '');
	if (normalizedExpected && sharedVersion && sharedVersion !== normalizedExpected) {
		errors.push(`EXPECTED VERSION MISMATCH: consumers reference ${sharedVersion}, expected ${expectedVersion}.`);
	}

	return {errors, rows, sharedVersion, sharedTag};
}

/** Runs git in `cwd`, capturing stderr so callers can report a sanitized reason. */
function git(cwd, args) {
	return execFileSync('git', ['-C', cwd, ...args], {encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe']}).trim();
}

/** True when `tag` is a tag object in the repository at `cwd`. */
export function tagExists(cwd, tag) {
	try {
		git(cwd, ['rev-parse', '--verify', '--quiet', `refs/tags/${tag}`]);
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
		const lock = readJsonOrNull(join(dir, 'package-lock.json'));
		const lockEntry = findLockEntry(lock) ?? {};
		const tools = readJsonOrNull(join(dir, 'openapitools.json')) ?? {};
		consumers[name] = {
			depSpec: findDependency(pkg),
			lockPresent: lock !== null,
			lockResolved: lockEntry.resolved ?? '',
			lockIntegrity: lockEntry.integrity ?? '',
			lockVersion: lockEntry.version ?? '',
			jarVersion: tools?.['generator-cli']?.version ?? '',
			hasCheckScript: Boolean(pkg.scripts?.['check:openapi']),
		};
	}

	return {contractsHead, contractsManifest, contractsYamlSha256, consumers, skipped};
}

/** Parses CLI flags; unknown flags throw so a typo cannot silently widen the gate. */
export function parseArgs(argv) {
	const args = {dryRun: false, quiet: false};
	const valued = new Set(['--contracts', '--plugin', '--server', '--expected-version']);
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
		const flag = name.replace(/^crdt_/u, '');
		const override = args[flag] ?? env[CONSUMER_ENV[name]];
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
	const expectedVersion = args['expected-version'] ?? process.env.CRDT_EXPECTED_VERSION ?? '';

	let data;
	try {
		data = gatherSuiteCoherence({contractsDir, consumerDirs});
	} catch (error) {
		console.error('[check:suite] cannot read the coherence inputs');
		console.error(`  ${error.message}`);
		console.error(
			'  The contract checkout must be intact and each consumer checkout must contain ' +
			'package.json + package-lock.json (siblings are PRIVATE: clone them or provide ' +
			'SUBMODULES_TOKEN in CI).',
		);
		process.exit(1);
	}

	const {errors, rows, sharedVersion, sharedTag} = evaluateSuiteCoherence({
		contractsManifest: data.contractsManifest,
		contractsYamlSha256: data.contractsYamlSha256,
		consumers: data.consumers,
		skipped: data.skipped,
		expectedVersion,
	});
	const failures = [...errors];

	if (sharedTag && !tagExists(contractsDir, sharedTag)) {
		failures.push(
			`UNKNOWN RELEASE TAG: ${sharedTag} is not a tag in this crdt-contracts checkout ` +
			'(the consumers must pin a release of THIS repository; a shallow clone needs full tags).',
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
				`  ${row.status.padEnd(7)}  ${row.name.padEnd(12)}  version=${row.version || '(none)'}  ` +
				`tag=${row.tag || '(none)'}  jar=${row.jarVersion || '(none)'}`,
			);
		}
	}

	const mode = args.dryRun ? 'dry-run' : 'enforce';
	console.log(
		`[check:suite] mode=${mode} consumers=${CONSUMERS.length} sharedVersion=${sharedVersion || '(none)'} ` +
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
