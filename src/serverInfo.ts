/**
 * serverInfo — wire shape of the server info response (`GET /`).
 *
 * The plugin reads this once at startup to negotiate with the server:
 *   - `versions.protocol` is the hard gate (must equal `PROTOCOL_VERSION`);
 *   - `capabilities` lists the additive feature flags the server implements.
 *
 * `capabilities` is OPTIONAL on the wire: an older server that predates the
 * field simply omits it, and the plugin treats every feature as OFF rather
 * than failing. Adding a field is backward-compatible; only a `protocol`
 * mismatch ever blocks.
 *
 * Implementation-free: interfaces only.
 */

/** Informational version block of the server info response. */
export interface ServerInfoVersions {
	/** Hocuspocus server version. */
	hocuspocus?: string;
	/** Yjs version. */
	yjs?: string;
	/** Server package version. */
	server?: string;
	/** Server version alias (legacy field). */
	self?: string;
	/** Wire-protocol version (integer). */
	protocol?: number;
}

/**
 * Server info response body (`GET /`). `capabilities` is additive: absent
 * means an older server, and each missing entry means that feature is off.
 */
export interface ServerInfoResponse {
	/** Literal 'OK'. */
	ok?: string;
	/** Service name. */
	service?: string;
	/** Informational versions. */
	versions?: ServerInfoVersions;
	/** Advertised feature capabilities (unknown strings must be ignored). */
	capabilities?: string[];
}
