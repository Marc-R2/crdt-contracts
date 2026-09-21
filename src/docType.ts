/**
 * docType — wire contract for the unified docId prefix scheme.
 *
 * A **docId** is the Y.Map key inside the structure Y.Doc and the key of
 * every local store (local-tracked.json, content-exported.json,
 * conflicts.json, AbandonedPathStore). Every docId carries exactly one of
 * the prefixes in {@link DOCID_PREFIXES}. The **globalId** is a SEPARATE,
 * unprefixed UUID namespace (room key `project-{id}@{globalId}`, `.bin`
 * filename, server snapshot) and lives outside this module — the prefixes
 * here never touch rooms/server/history.
 *
 * IMPLEMENTATION-FREE: this module declares the `DocType` enum, the
 * `DocumentId` branded string and the prefix constants ONLY. The strict
 * mint (`freshTypedDocId`) and the read predicates (`docIdPrefixOf`,
 * `isBlobDocId`, `isLiveEditDocId`, `isCrdtDocId`) stay in the consumers
 * because they are behavior, not wire contract — `freshTypedDocId` in
 * particular needs a UUID source and must never enter this package.
 */

/** The CRDT content formats a docId can identify (wire contract). */
export enum DocType {
	Text = 'text',
	Map = 'map',
	Json = 'json',
	List = 'list',
	Xml = 'xml',
	Frag = 'frag',
	Blob = 'blob',
}

/** A docId that carries a known prefix: `<prefix>:<payload>`. */
export type DocumentId = `${string}:${string}`;

/**
 * Prefix of content-addressed binary docIds (`sha256:<hash>#<index>`).
 * The single location of the literal — never hardcode `'sha256:'`
 * elsewhere (DUP-CODE-002).
 */
export const BLOB_DOCID_PREFIX = 'sha256:';

/** Prefix per DocType, in declaration order (first match wins when reading). */
export const DOCID_PREFIXES: Record<DocType, string> = {
	[DocType.Text]: 'text:',
	[DocType.Map]: 'map:',
	[DocType.Json]: 'json:',
	[DocType.List]: 'list:',
	[DocType.Xml]: 'xml:',
	[DocType.Frag]: 'frag:',
	[DocType.Blob]: BLOB_DOCID_PREFIX,
};
