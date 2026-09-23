import {describe, it, expect} from 'vitest';
import {readFileSync, writeFileSync, mkdirSync, rmSync, cpSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import path from 'node:path';

// The package sits at the repository ROOT after the extraction
// (this file is tests/unit/contracts/ — three levels up).
const repoRoot = path.resolve(import.meta.dirname, '../../..');
const yamlPath = path.join(repoRoot, 'openapi', 'openapi.yaml');
const manifestPath = path.join(repoRoot, 'compat-manifest.json');
const fiveMinMs = 300_000; // the jsonnet render costs ~100 s; stay far below CI limits

/**
 * Red-proof regression tests for the OpenAPI pipeline (build:openapi /
 * check:openapi — Phase A of the jsonnet→yaml restore).
 *
 * The render itself is ~100 s, so these assertions run against the
 * COMMITTED artifact and the manifest pin; the full re-render + gate is
 * exercised by `npm run check:openapi` (wired in CI right after build).
 */
describe('openapi contract pipeline', () => {
	it('keeps compat-manifest.json openapiSha256 pin === sha256(openapi/openapi.yaml)', () => {
		const manifest = JSON.parse(readFileSync(manifestPath, 'utf8')) as {openapiSha256?: string};
		expect(manifest.openapiSha256, 'manifest must carry an openapiSha256 pin (C-6)').toBeTruthy();
		const actual = createHash('sha256').update(readFileSync(yamlPath)).digest('hex');
		expect(manifest.openapiSha256).toBe(actual);
	});

	it('documents the current API surface (no dead /fs/*, key routes present)', () => {
		const yaml = readFileSync(yamlPath, 'utf8');
		expect(yaml).toContain('openapi: "3.0.2"');
		// The dead /fs/* endpoints stay gone.
		expect(yaml).not.toMatch(/^  \/fs\//m);
		expect(yaml).not.toContain('FsEntry');
		// Key surface spot checks (snapshot trio, doc-status, health).
		for (const p of ['/snapshot/get', '/snapshot/getUpdates', '/snapshot/list', '/projects/doc-status', '/health']) {
			expect(yaml).toContain(`  ${p}:`);
		}
	});

	it('fails the drift gate when openapi.yaml is hand-edited (red proof on a copy)', {timeout: fiveMinMs}, () => {
		// Prove the gate RED on a THROWAWAY copy of the package (the real repo
		// is never mutated): hand-edit the committed yaml -> byte-drift error.
		const tmp = path.join(repoRoot, 'tests', 'unit', 'contracts', '.drift-tmp');
		rmSync(tmp, {recursive: true, force: true});
		mkdirSync(tmp, {recursive: true});
		cpSync(path.join(repoRoot, 'src'), path.join(tmp, 'src'), {recursive: true});
		cpSync(path.join(repoRoot, 'openapi'), path.join(tmp, 'openapi'), {recursive: true});
		cpSync(path.join(repoRoot, 'scripts'), path.join(tmp, 'scripts'), {recursive: true});
		cpSync(path.join(repoRoot, 'compat-manifest.json'), path.join(tmp, 'compat-manifest.json'));
		cpSync(path.join(repoRoot, 'package.json'), path.join(tmp, 'package.json'));
		try {
			const driftyaml = path.join(tmp, 'openapi', 'openapi.yaml');
			const original = readFileSync(driftyaml, 'utf8');
			// Hand-edit ONE character of the committed contract.
			const edited = original.replace('openapi: "3.0.2"', 'openapi: "3.0.3"');
			expect(edited).not.toBe(original);
			writeFileSync(driftyaml, edited, 'utf8');

			try {
				execFileSync('node', [path.join(tmp, 'scripts', 'check-openapi.mjs')], {
					cwd: tmp,
					timeout: fiveMinMs,
					encoding: 'utf8',
					// The copy has no node_modules; the gate must resolve the
					// jsonnet binding from the REAL repo (see check-openapi.mjs).
					env: {...process.env, CONTRACTS_REPO_ROOT: repoRoot},
					stdio: ['ignore', 'pipe', 'pipe'],
				});
				// Passing the gate with a hand-edited yaml is the failure mode.
				expect.unreachable('check:openapi unexpectedly stayed GREEN after a hand-edit');
			} catch (err) {
				const status = (err as {status?: number}).status;
				expect(status).toBe(1);
				const stderr = String((err as {stderr?: Buffer}).stderr ?? '');
				expect(stderr).toContain('byte-identical');
			}
		} finally {
			rmSync(tmp, {recursive: true, force: true});
		}
	});
});
