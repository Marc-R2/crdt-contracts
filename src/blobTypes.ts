/**
 * blobTypes — the `/blobs/*` REST wire contract.
 *
 * Implementation-free: interfaces ONLY. Shared by the plugin client
 * (`BlobClient`/`ChunkedUploader`) and the server blob service/route
 * handler so a contract change cannot drift between the two sides.
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

/** Result of a chunked-upload status query. */
export interface ChunkUploadStatus {
	complete: boolean;
	totalChunks: number;
	presentChunks: number[];
	chunkSize: number;
	totalSize: number;
}

/** Result of a garbage-collection pass. */
export interface GCStats {
	scanned: number;
	deleted: number;
	freedBytes: number;
}
