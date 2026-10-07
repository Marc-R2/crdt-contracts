/**
 * capabilities — additive server feature flags (post-P0 negotiation).
 *
 * The plugin must run against MULTIPLE server versions and degrade
 * gracefully instead of scattering `if (serverVersion >= x)` checks. A
 * `protocol` mismatch is the ONLY hard failure; every other server
 * difference is expressed as an ADDITIVE boolean feature flag advertised by
 * the server (`GET /` → `capabilities: string[]`). A missing flag means the
 * feature is simply OFF, never an error.
 *
 * Capability strings are namespaced `<feature>.<revision>` (`snapshots.v1`)
 * so a future breaking change can advertise `snapshots.v2` alongside `v1`
 * without renaming the flag. Implementation-free: constants + one type.
 *
 * Protocol note: adding or removing a capability is NOT a protocol bump —
 * only a breaking room-name / structure-entry-schema change is. The
 * consumers' `if (capability absent)` branches are the whole mechanism.
 */

/** Canonical capability strings advertised by the sync server (`GET /`). */
export const CAPABILITIES = {
	/** Snapshot list/get/getUpdates REST endpoints. */
	SNAPSHOTS_V1: 'snapshots.v1',
	/** Chunked blob upload/download (`/blobs/_*`). */
	BLOBS_CHUNKED_V1: 'blobs.chunked.v1',
	/** Per-document status endpoint (`/projects/doc-status`). */
	DOC_STATUS_V1: 'doc-status.v1',
	/** History capture + timeline endpoints (`/projects/{id}/...`). */
	HISTORY_V1: 'history.v1',
	/** Server-side Git VCS endpoints (`/projects/{id}/vcs/*`). */
	VCS_V1: 'vcs.v1',
} as const;

/** A known capability string; unknown future strings stay `string`. */
export type Capability = (typeof CAPABILITIES)[keyof typeof CAPABILITIES];

/** All canonical capability strings, for validation and iteration. */
export const CAPABILITY_VALUES: readonly Capability[] = [
	CAPABILITIES.SNAPSHOTS_V1,
	CAPABILITIES.BLOBS_CHUNKED_V1,
	CAPABILITIES.DOC_STATUS_V1,
	CAPABILITIES.HISTORY_V1,
	CAPABILITIES.VCS_V1,
];
