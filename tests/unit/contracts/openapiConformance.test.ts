import {describe, it, expect} from 'vitest';
import {mkdtempSync, readFileSync, rmSync, writeFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {tmpdir} from 'node:os';
import path from 'node:path';

const repoRoot = path.resolve(import.meta.dirname, '../../..');
const yamlPath = path.join(repoRoot, 'openapi', 'openapi.yaml');
const configPath = path.join(repoRoot, '.redocly.yaml');
const redoclyBin = path.join(repoRoot, 'node_modules', '.bin', 'redocly');

/** Runs redocly lint on a yaml file and returns {status, output}. */
function lint(file: string): {status: number; output: string} {
	try {
		const stdout = execFileSync(redoclyBin, ['lint', file, '--config', configPath], {
			encoding: 'utf8',
			stdio: ['ignore', 'pipe', 'pipe'],
		});
		return {status: 0, output: stdout};
	} catch (err) {
		const failure = err as {status?: number; stdout?: string; stderr?: string};
		return {status: failure.status ?? -1, output: `${failure.stdout ?? ''}${failure.stderr ?? ''}`};
	}
}

/**
 * Conformance red proof (the review's key lesson): the DRIFT gate proves the
 * committed yaml equals the jsonnet render, but says nothing about whether the
 * contract is CORRECT. These tests reintroduce real defects on THROWAWAY copies
 * (the repo is never mutated) and assert the conformance lint FAILS naming them.
 */
describe('openapi conformance lint', () => {
	it('is green on the committed contract', () => {
		const {status, output} = lint(yamlPath);
		expect(output).toContain('valid');
		expect(status).toBe(0);
	});

	it('fails naming path-parameters-defined when the B1 defect (optional id on the collection path) is reintroduced', () => {
		const dir = mkdtempSync(path.join(tmpdir(), 'crdt-contracts-b1-'));
		try {
			const defective = path.join(dir, 'openapi.yaml');
			const original = readFileSync(yamlPath, 'utf8');
			const anchor = '  /api/bug-reports:\n    delete:\n';
			expect(original).toContain(anchor);
			const reintroduced = original.replace(
				anchor,
				anchor +
					'      parameters:\n' +
					'        - name: id\n' +
					'          in: path\n' +
					'          required: false\n' +
					'          schema:\n' +
					'            type: string\n',
			);
			writeFileSync(defective, reintroduced, 'utf8');

			const {status, output} = lint(defective);
			expect(status).not.toBe(0);
			expect(output).toContain('path-parameters-defined');
			expect(output).toContain('not used in the path');
		} finally {
			rmSync(dir, {recursive: true, force: true});
		}
	});

	it('fails naming nullable-type-sibling when the M2 defect (nullable logs with no type) is reintroduced', () => {
		const dir = mkdtempSync(path.join(tmpdir(), 'crdt-contracts-m2-'));
		try {
			const defective = path.join(dir, 'openapi.yaml');
			const original = readFileSync(yamlPath, 'utf8');
			// Revert the M2 fix: drop the oneOf union, keep a bare nullable.
			const fixedBlock =
				'        logs:\n' +
				'          description: "String or string array (validator: string OR array of strings; null is rejected)."\n' +
				'          oneOf:\n' +
				'            - type: "string"\n' +
				'            - items:\n' +
				'                type: "string"\n' +
				'              type: "array"\n';
			expect(original).toContain(fixedBlock);
			const reintroduced = original.replace(
				fixedBlock,
				'        logs:\n          description: "String or string array."\n          nullable: true\n',
			);
			writeFileSync(defective, reintroduced, 'utf8');

			const {status, output} = lint(defective);
			expect(status).not.toBe(0);
			expect(output).toContain('nullable-type-sibling');
		} finally {
			rmSync(dir, {recursive: true, force: true});
		}
	});
});
