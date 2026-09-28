/**
 * blobTypes — the `/blobs/*` REST wire contract.
 *
 * Implementation-free: interfaces ONLY. Shared by the plugin client
 * (`BlobClient`/`ChunkedUploader`) and the server blob service/route
 * handler so a contract change cannot drift between the two sides.
 *
 * Response codes are pinned by the OpenAPI contract
 * (`openapi/src/blobs/blobs.jsonnet`) and its regression test — notably the
 * three blob WRITE operations answer **201**, not 200, and a declared code
 * that the server cannot write is a defect, not documentation.
 */

/** Result of a batch existence check. */
export interface BatchCheckResult {
	/** Hashes that exist as complete blobs on the server. */
	existing: string[];
	/** Hashes that are missing from the server. */
	missing: string[];
	/** Hashes with an in-progress chunked upload (can be resumed). */
	chunked: string[];
}

/** Entry in the blob manifest. */
export interface BlobManifestEntry {
	hash: string;
	size: number;
	createdAt: number;
}

/**
 * One page of the blob manifest. `count` is the number of entries in THIS
 * page (`blobs.length`), `total` the full blob count of the store, and
 * `totalSize` the summed size of the returned page entries (bounded work
 * per request — the full-store sum would cost one statSync per blob).
 */
export interface BlobManifest {
	blobs: BlobManifestEntry[];
	totalSize: number;
	count: number;
	total: number;
}

/** Result of a chunked-upload status query (`GET /blobs/{hash}/status`). */
export interface ChunkUploadStatus {
	/** True when the blob is already committed and visible as a COMPLETE object. */
	complete: boolean;
	/**
	 * Total number of chunks the upload consists of — the count the client
	 * passes in the commit request. It must NOT be a copy of
	 * `presentChunks.length` (the resume set, a lower bound until the commit
	 * declares the real total).
	 */
	totalChunks: number;
	/** Indexes of already-uploaded chunks (resume support). */
	presentChunks: number[];
	/**
	 * Chunk size in bytes the server is CONFIGURED to accept
	 * (`BLOB_MAX_CHUNK_SIZE`; env-tunable, default 4 MiB). A server that
	 * publishes a hardcoded default instead is non-conformant.
	 */
	chunkSize: number;
	/**
	 * Expected total blob size in bytes. Advisory before the commit — the
	 * client declares the authoritative `totalSize` in the commit body.
	 */
	totalSize: number;
}

/** Result of a garbage-collection pass. */
export interface GCStats {
	scanned: number;
	deleted: number;
	freedBytes: number;
}
