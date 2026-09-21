import {describe, it, expect} from 'vitest';
import {execFileSync} from 'node:child_process';
import path from 'node:path';

const gateScript = path.resolve(import.meta.dirname, '../../../scripts/compat-gate.mjs');

describe('compat:gate', () => {
	it('exits 0 and reports GREEN when the declared pin matches the consumed package', () => {
		const out = execFileSync('node', [gateScript], {encoding: 'utf8'});
		expect(out).toContain('GREEN');
	});
});
