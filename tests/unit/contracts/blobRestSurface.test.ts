import {describe, it, expect, beforeAll, afterAll} from 'vitest';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {mkdtempSync, readFileSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import path from 'node:path';

const repoRoot = path.resolve(import.meta.dirname, '../../..');
const yamlPath = path.join(repoRoot, 'openapi', 'openapi.yaml');
const manifestPath = path.join(repoRoot, 'compat-manifest.json');
const redoclyBin = path.join(repoRoot, 'node_modules', '.bin', 'redocly');

/** Minimal OpenAPI shape this suite reads (paths + the blob schemas). */
interface Spec {
	paths: Record<string, Record<string, {responses: Record<string, {description: string}>}>>;
	components: {schemas: Record<string, Record<string, unknown>>};
}

let spec: Spec;
let bundleDir: string;

beforeAll(() => {
	// `redocly bundle` is the same pinned tool the conformance gate uses; it
	// turns the committed yaml into JSON so these assertions are structural
	// (a response KEY) instead of indentation-sensitive text matching.
	bundleDir = mkdtempSync(path.join(tmpdir(), 'crdt-contracts-blobs-'));
	const bundled = path.join(bundleDir, 'openapi.json');
	execFileSync(redoclyBin, ['bundle', yamlPath, '-o', bundled, '--ext', 'json'], {
		encoding: 'utf8',
		stdio: ['ignore', 'pipe', 'pipe'],
	});
	spec = JSON.parse(readFileSync(bundled, 'utf8')) as Spec;
});

afterAll(() => {
	if (bundleDir) rmSync(bundleDir, {recursive: true, force: true});
});

/** Response codes declared for one operation (e.g. `put` of `/blobs/{hash}`). */
const codes = (route: string, method: string): string[] =>
	Object.keys(spec.paths[route]?.[method]?.responses ?? {}).sort();

/** Description of one declared response code. */
const described = (route: string, method: string, code: string): string =>
	spec.paths[route][method].responses[code].description;

/**
 * Blob REST surface regression tests.
 *
 * WHY: the jsonnet contract mis-transcribed the served surface. The three blob
 * WRITE operations declared `'200'` while the server answers `201`
 * (`writeJson(res, 201, …)`) and the only first-party client treats
 * `response.status === 201` as success — a generated client built from the
 * contract would reject every successful upload. The reverse errors were there
 * too: a `DELETE` `404` the handler can never write, and real `411`/`413`/
 * `416`/`429` responses that were never declared. The DRIFT gate cannot see
 * any of it (a faithfully rendered wrong contract is still faithful), so the
 * invariants are pinned here.
 */
describe('blob REST surface matches the served contract', () => {
	it('declares 201 — not 200 — as the success response of the three blob WRITE operations', () => {
		for (const [route, method] of [
			['/blobs/{hash}', 'put'],
			['/blobs/{hash}/chunks/{n}', 'put'],
			['/blobs/{hash}/commit', 'post'],
		] as const) {
			expect(codes(route, method), `${method.toUpperCase()} ${route}`).toContain('201');
			expect(codes(route, method), `${method.toUpperCase()} ${route}`).not.toContain('200');
		}
	});

	it('re-pins the manifest hash in the same commit as the 201 correction', () => {
		// The hash assertion is deliberately coupled to the 201 assertion
		// above: re-pinning `openapiSha256` is what makes a wrong contract look
		// green, so a reverted `'200'` must fail even after a fresh re-pin.
		const manifest = JSON.parse(readFileSync(manifestPath, 'utf8')) as {openapiSha256: string};
		const actual = createHash('sha256').update(readFileSync(yamlPath)).digest('hex');
		expect(manifest.openapiSha256).toBe(actual);
		expect(codes('/blobs/{hash}', 'put')).toContain('201');
	});

	it('declares the 411 / 413 rejections the upload routes actually emit', () => {
		expect(codes('/blobs/{hash}', 'put')).toEqual(expect.arrayContaining(['411', '413']));
		expect(codes('/blobs/{hash}/chunks/{n}', 'put')).toEqual(expect.arrayContaining(['411', '413']));
		// Content-Length is required before the body is streamed (F3).
		expect(described('/blobs/{hash}', 'put', '411')).toMatch(/Content-Length/);
		expect(described('/blobs/{hash}/chunks/{n}', 'put', '411')).toMatch(/Content-Length/);
		// 413 covers BLOB_MAX_SINGLE_SIZE and (chunk) BLOB_MAX_CHUNK_SIZE.
		expect(described('/blobs/{hash}', 'put', '413')).toMatch(/BLOB_MAX_SINGLE_SIZE/);
		expect(described('/blobs/{hash}/chunks/{n}', 'put', '413')).toMatch(/BLOB_MAX_CHUNK_SIZE/);
		expect(described('/blobs/{hash}/chunks/{n}', 'put', '413')).toMatch(/chunk index/i);
	});

	it('declares the 413 an oversized chunked assembly is rejected with', () => {
		expect(codes('/blobs/{hash}/commit', 'post')).toContain('413');
		expect(described('/blobs/{hash}/commit', 'post', '413')).toMatch(/BLOB_MAX_TOTAL_BYTES/);
	});

	it('declares the 416 an unsatisfiable Range is answered with', () => {
		expect(codes('/blobs/{hash}', 'get')).toContain('416');
		expect(described('/blobs/{hash}', 'get', '416')).toMatch(/Content-Range/);
	});

	it('declares 429 on every blob route behind the blob rate limiter', () => {
		for (const [route, method] of [
			['/blobs/manifest', 'get'],
			['/blobs/batch-check', 'post'],
			['/blobs/{hash}', 'put'],
			['/blobs/{hash}', 'get'],
			['/blobs/{hash}', 'delete'],
			['/blobs/{hash}/chunks/{n}', 'put'],
			['/blobs/{hash}/status', 'get'],
			['/blobs/{hash}/commit', 'post'],
		] as const) {
			expect(codes(route, method), `${method.toUpperCase()} ${route}`).toContain('429');
		}
		expect(described('/blobs/{hash}', 'put', '429')).toMatch(/Retry-After|back off/);
	});

	it('declares the limiter and server-error responses of the info route GET /', () => {
		expect(codes('/', 'get')).toEqual(expect.arrayContaining(['200', '429', '500']));
	});

	it('does not declare the unreachable DELETE 404 and documents the idempotent 200 instead', () => {
		// `FileBlobRepository.delete` swallows every unlink error, so the
		// handler can only ever write 200 — a declared 404 is unreachable.
		expect(codes('/blobs/{hash}', 'delete')).toEqual(['200', '401', '429']);
		expect(described('/blobs/{hash}', 'delete', '200')).toMatch(/idempotent/i);
	});

	it('names BOTH hash-list caps on the batch check (server cap vs. client chunking)', () => {
		// 500 is the CLIENT's MAX_BATCH_SIZE; the server cap is
		// BLOB_MAX_BATCH_HASHES (env-tunable, default 5000) and answers 400
		// above it — `maxItems: 500` would make a generated client reject a
		// request the server accepts.
		const hashes = spec.components.schemas.BatchCheckRequest.properties as Record<
			string,
			{maxItems?: number; description: string}
		>;
		expect(hashes.hashes.maxItems).not.toBe(500);
		expect(hashes.hashes.maxItems).toBe(5000);
		expect(hashes.hashes.description).toMatch(/BLOB_MAX_BATCH_HASHES/);
		expect(hashes.hashes.description).toMatch(/500/);
		const op = spec.paths['/blobs/batch-check'].post;
		expect(op.description ?? '').toMatch(/BLOB_MAX_BATCH_HASHES/);
	});

	it('states the INTENDED ChunkUploadStatus semantics, not a claim about the server', () => {
		const status = spec.components.schemas.ChunkUploadStatus.properties as Record<
			string,
			{description?: string}
		>;
		// chunkSize names the CONFIGURED cap — the MEANING of the field. The
		// server already publishes the configured BLOB_MAX_CHUNK_SIZE
		// (BlobService.getChunkStatus), so no claim about a live deviation may
		// survive here: a pinned test that asserts a non-conformance which is
		// not there teaches the next engineer to "fix" a correct server, or to
		// weaken the contract back to the stale premise.
		expect(status.chunkSize.description).toMatch(/BLOB_MAX_CHUNK_SIZE/);
		expect(status.chunkSize.description).not.toMatch(/hardcoded|non-conformant/i);
		// totalChunks names the TOTAL, and says which value is only the resume
		// set. The server's presentChunks.length fallback (no ?totalSize
		// declared) is its own DOCUMENTED behaviour, not a defect to chase.
		expect(status.totalChunks.description).toMatch(/total/i);
		expect(status.totalChunks.description).toMatch(/presentChunks/);
	});
});
