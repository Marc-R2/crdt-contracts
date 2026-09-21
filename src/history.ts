/**
 * history — shared history timeline wire types for the desktop plugin and
 * the web portal.
 *
 * Implementation-free: interfaces/type aliases ONLY.
 */

export interface HistoryUser {
	clientId: number;
	userId: string;
	userName: string;
	color: string;
}

export interface TimelineCheckpoint {
	checkpointSeq: number;
	seq: number;
	createdAt: number;
}

export type TimelineCommitScope = 'note' | 'vault';

export interface TimelineCommit {
	commitId: string;
	scope: TimelineCommitScope;
	docId?: string;
	seq?: number;
	name: string;
	createdAt: number;
	createdBy: string;
}

export interface TimelineIndex {
	docId: string;
	seqCount: number;
	firstTs: number;
	lastTs: number;
	checkpoints: TimelineCheckpoint[];
	commits: TimelineCommit[];
	users: HistoryUser[];
}

export interface ChunkUpdate {
	seq: number;
	ts: number;
	blob: Uint8Array;
}

export interface BlameRun {
	from: number;
	to: number;
	userId: string;
	userName: string;
	color: string;
	ts: number;
}

export interface Frame {
	seq: number;
	text: string;
	runs: BlameRun[];
}
