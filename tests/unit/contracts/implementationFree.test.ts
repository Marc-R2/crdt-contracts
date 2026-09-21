import {describe, it, expect} from 'vitest';
import {readdirSync, readFileSync} from 'node:fs';
import path from 'node:path';

const srcDir = path.resolve(import.meta.dirname, '../../../packages/crdt-contracts/src');

function collectTsFiles(dir: string): string[] {
	const out: string[] = [];
	for (const entry of readdirSync(dir, {withFileTypes: true})) {
		const full = path.join(dir, entry.name);
		if (entry.isDirectory()) out.push(...collectTsFiles(full));
		else if (entry.name.endsWith('.ts')) out.push(full);
	}
	return out;
}

/**
 * Guards the Phase-0 design rule: the contracts package contains TYPES and
 * CONSTANTS only. A function/class/arrow body or an implementation import
 * (uuid mint, crypto, fs, NestJS) must never enter it — that is what caused
 * the reviewed plan to be unexecutable.
 */
describe('contracts package is implementation-free', () => {
	it('has no function/class/arrow runtime bodies and no implementation imports', () => {
		const files = collectTsFiles(srcDir);
		expect(files.length).toBeGreaterThan(0);

		for (const file of files) {
			const text = readFileSync(file, 'utf8');
			expect(text, `${file} declares a function`).not.toMatch(/\bfunction\b/);
			expect(text, `${file} declares an arrow function`).not.toMatch(/=>/);
			expect(text, `${file} declares a class`).not.toMatch(/\bclass\b/);
			expect(text, `${file} references the uuid mint`).not.toMatch(/uuidUtils|generateUuid/);
			expect(text, `${file} imports a Node/implementation module`).not.toMatch(
				/from ['"](?:node:)?(?:fs|crypto|path|http|os|child_process)['"]/,
			);
			expect(text, `${file} imports NestJS`).not.toMatch(/@nestjs/);
		}
	});
});
