import {describe, it, expect} from 'vitest';
import {readdirSync, readFileSync} from 'node:fs';
import path from 'node:path';

const srcDir = path.resolve(import.meta.dirname, '../../../packages/crdt-contracts/src');

/**
 * Strips `//` and `/* *\/` comments so documentation prose (which legitimately
 * says "no functions") cannot false-positive the code guard. The package
 * source contains no regex/string literals with comment-like sequences, so a
 * plain comment strip is sufficient.
 */
function stripComments(source: string): string {
	return source
		.replace(/\/\*[\s\S]*?\*\//gu, '')
		.replace(/(^|[^:])\/\/[^\n]*/gmu, '$1');
}

function collectTsFiles(dir: string): string[] {
	const out: string[] = [];
	for (const entry of readdirSync(dir, {withFileTypes: true})) {
		const full = path.join(dir, entry.name);
		if (entry.isDirectory()) out.push(...collectTsFiles(full));
		else if (entry.name.endsWith('.ts')) out.push(full);
	}
	return out;
}

const FORBIDDEN: Array<{pattern: RegExp; what: string}> = [
	{pattern: /\bfunction\b/u, what: 'a function declaration'},
	{pattern: /=>/u, what: 'an arrow function'},
	{pattern: /\bclass\b/u, what: 'a class'},
	{pattern: /uuidUtils|generateUuid/u, what: 'the uuid mint'},
	{
		pattern: /from\s+['"](?:node:)?(?:fs|crypto|path|http|os|child_process)['"]/u,
		what: 'a Node implementation import',
	},
	{pattern: /@nestjs/u, what: 'a NestJS import'},
];

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
			const code = stripComments(readFileSync(file, 'utf8'));
			for (const {pattern, what} of FORBIDDEN) {
				expect(code, `${file} declares ${what}`).not.toMatch(pattern);
			}
		}
	});

	it('ignores forbidden tokens that appear only inside comments', () => {
		const commented =
			'// function foo => class Bar uuidUtils\n/* fs crypto @nestjs */\nexport type T = string;\n';
		const code = stripComments(commented);
		for (const {pattern} of FORBIDDEN) {
			expect(code).not.toMatch(pattern);
		}
		expect(code).toContain('export type T');
	});
});
