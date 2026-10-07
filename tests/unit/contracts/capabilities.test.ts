import {describe, it, expect} from 'vitest';
import type {Capability, ServerInfoResponse} from '@marc-r2/crdt-contracts';
import {CAPABILITIES, CAPABILITY_VALUES} from '@marc-r2/crdt-contracts';

/**
 * Capability negotiation surface: the canonical flag strings, the
 * `Capability` union, and the `ServerInfoResponse` wire shape (`protocol`
 * hard gate + additive `capabilities`). Adding a capability is a MINOR
 * change; it must never touch `PROTOCOL_VERSION`.
 */
describe('capabilities contract', () => {
	it('exposes the canonical namespaced feature flags', () => {
		expect(CAPABILITIES).toEqual({
			SNAPSHOTS_V1: 'snapshots.v1',
			BLOBS_CHUNKED_V1: 'blobs.chunked.v1',
			DOC_STATUS_V1: 'doc-status.v1',
			HISTORY_V1: 'history.v1',
			VCS_V1: 'vcs.v1',
		});
	});

	it('lists every capability exactly once', () => {
		const values = Object.values(CAPABILITIES);
		expect(CAPABILITY_VALUES).toEqual(values);
		expect(new Set(values).size).toBe(values.length);
	});

	it('namespaces every capability as <feature>.<revision>', () => {
		for (const value of CAPABILITY_VALUES) {
			expect(value).toMatch(/^[a-z][a-z0-9.-]*\.v\d+$/u);
		}
	});

	it('keeps the server info wire type additive (protocol + capabilities)', () => {
		const info: ServerInfoResponse = {
			ok: 'OK',
			service: 'Obsidian CRDT Sync Server',
			versions: {server: '1.0.0', protocol: 1},
			capabilities: [CAPABILITIES.SNAPSHOTS_V1],
		};
		const capability: Capability = CAPABILITIES.SNAPSHOTS_V1;
		expect(info.capabilities).toContain(capability);
		expect(info.versions?.protocol).toBe(1);
	});
});
