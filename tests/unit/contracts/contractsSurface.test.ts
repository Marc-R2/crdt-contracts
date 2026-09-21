import {describe, it, expect} from 'vitest';
import {readFileSync} from 'node:fs';
import path from 'node:path';
import {
	PROTOCOL_VERSION,
	DocType,
	DOCID_PREFIXES,
	BLOB_DOCID_PREFIX,
	EMPTY_SHA256,
	SHA256_HEX_REGEX,
	CRDT_DOCID_PREFIXES,
} from '@marc-r2/crdt-contracts';

// The package sits at the repository ROOT after the extraction (it was
// `packages/crdt-contracts/` in the monorepo), so `../../..` is the repo root.
const contractsDir = path.resolve(import.meta.dirname, '../../..');

describe('@marc-r2/crdt-contracts wire surface', () => {
	it('keeps the compat-manifest protocol pin in lockstep with PROTOCOL_VERSION', () => {
		const manifest = JSON.parse(readFileSync(path.join(contractsDir, 'compat-manifest.json'), 'utf8')) as {
			protocolVersion: number;
			contracts: string;
		};
		expect(manifest.protocolVersion).toBe(PROTOCOL_VERSION);
	});

	it('keeps the compat-manifest contracts version in lockstep with package.json', () => {
		const manifest = JSON.parse(readFileSync(path.join(contractsDir, 'compat-manifest.json'), 'utf8')) as {
			contracts: string;
		};
		const pkg = JSON.parse(readFileSync(path.join(contractsDir, 'package.json'), 'utf8')) as {version: string};
		expect(manifest.contracts).toBe(pkg.version);
	});

	it('exposes the unified docId prefix scheme unchanged', () => {
		expect(DOCID_PREFIXES[DocType.Text]).toBe('text:');
		expect(DOCID_PREFIXES[DocType.Map]).toBe('map:');
		expect(DOCID_PREFIXES[DocType.Json]).toBe('json:');
		expect(DOCID_PREFIXES[DocType.List]).toBe('list:');
		expect(DOCID_PREFIXES[DocType.Xml]).toBe('xml:');
		expect(DOCID_PREFIXES[DocType.Frag]).toBe('frag:');
		expect(DOCID_PREFIXES[DocType.Blob]).toBe('sha256:');
		expect(BLOB_DOCID_PREFIX).toBe('sha256:');
	});

	it('exposes the blob constants unchanged', () => {
		expect(EMPTY_SHA256).toBe('e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
		expect(SHA256_HEX_REGEX.test(EMPTY_SHA256)).toBe(true);
		expect(CRDT_DOCID_PREFIXES).toEqual(['text:', 'map:', 'json:', 'list:', 'xml:', 'frag:']);
	});
});
