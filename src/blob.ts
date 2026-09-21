/**
 * blob — wire constants for content-addressed blob identity.
 *
 * IMPLEMENTATION-FREE: constants and a branded string type only. The
 * predicates/validators (`isUsableBlob`, `assertSafeBlobHash`,
 * `extractBlobHash`, `isBlobDocId`, `isCrdtDocId`) stay in the consumers
 * because they are behavior, not wire contract.
 */

/**
 * SHA-256 of the empty byte string, as 64 hex chars. Used to detect
 * 0-byte / placeholder files without hashing (DUP-CODE-008).
 */
export const EMPTY_SHA256 = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

/** A legitimate SHA-256 hash: exactly 64 hex chars (case-insensitive on read). */
export const SHA256_HEX_REGEX = /^[0-9a-f0-9]{64}$/i;

/** A string that carries the blob prefix (template-literal type guard). */
export type BlobDocId = `sha256:${string}`;

/**
 * Unified CRDT docId prefixes for the non-blob LiveEdit formats.
 * Deliberately EXCLUDES `sha256:` — the blob case is identified by
 * {@link BLOB_DOCID_PREFIX} / `isBlobDocId`.
 */
export const CRDT_DOCID_PREFIXES = ['text:', 'map:', 'json:', 'list:', 'xml:', 'frag:'] as const;
