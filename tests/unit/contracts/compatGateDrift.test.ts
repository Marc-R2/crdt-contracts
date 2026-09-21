import {describe, it, expect, afterEach} from 'vitest';
import {cpSync, mkdtempSync, readFileSync, rmSync, writeFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {tmpdir} from 'node:os';
import path from 'node:path';

const repoRoot = path.resolve(import.meta.dirname, '../../..');
const gateScript = path.join(repoRoot, 'scripts', 'compat-gate.mjs');
const contractsSource = path.join(repoRoot, 'packages', 'crdt-contracts');

let tempDir: string | undefined;

afterEach(() => {
	if (tempDir) rmSync(tempDir, {recursive: true, force: true});
	tempDir = undefined;
});

/**
 * The gate must be refutable by an INDEPENDENT declaration, not by bumping the
 * shared constant (both consumers would move together). This test mutates only
 * a throwaway COPY of the package, so the repo is never touched, and asserts
 * the gate exits non-zero naming the mismatch.
 */
describe('compat:gate drift regression', () => {
	it('exits non-zero and names the mismatch when the declared pin disagrees with the exported PROTOCOL_VERSION', () => {
		tempDir = mkdtempSync(path.join(tmpdir(), 'crdt-contracts-drift-'));
		cpSync(contractsSource, tempDir, {recursive: true});

		const manifestPath = path.join(tempDir, 'compat-manifest.json');
		const manifest = JSON.parse(readFileSync(manifestPath, 'utf8')) as {protocolVersion: number};
		manifest.protocolVersion = manifest.protocolVersion + 1;
		writeFileSync(manifestPath, `${JSON.stringify(manifest, null, '\t')}\n`);

		let status = 0;
		let output = '';
		try {
			execFileSync('node', [gateScript, '--contracts-dir', tempDir], {encoding: 'utf8'});
		} catch (err) {
			const failure = err as {status?: number; stdout?: string; stderr?: string};
			status = failure.status ?? -1;
			output = `${failure.stdout ?? ''}${failure.stderr ?? ''}`;
		}

		expect(status).not.toBe(0);
		expect(output).toContain('RED');
		expect(output).toContain('protocolVersion mismatch');
	});
});
