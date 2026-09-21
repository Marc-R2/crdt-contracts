import {defineConfig} from 'vitest/config';
import path from 'node:path';

/**
 * Test runner for the extracted `@marc-r2/crdt-contracts` package.
 *
 * The contract tests import the package by name (`@marc-r2/crdt-contracts`),
 * which resolved through the monorepo's `node_modules` link. After the
 * extraction the package IS this repository, so a vitest alias points the name
 * at the source entry — the tests pin the actual contract source, and no
 * self-referential `exports` field has to change consumer resolution.
 */
export default defineConfig({
	resolve: {
		alias: {
			'@marc-r2/crdt-contracts': path.resolve(import.meta.dirname, 'src/index.ts'),
		},
	},
	test: {
		environment: 'node',
		include: ['tests/**/*.test.ts'],
	},
});
