/**
 * vcs — unified VCS (Git) domain types shared by the desktop plugin and
 * the sync server.
 *
 * Implementation-free: pure domain interfaces/type aliases ONLY — no
 * dependency on 'obsidian' or server internals.
 */

/** Status of a file relative to Git HEAD. */
export type VcsFileStatusType = 'modified' | 'added' | 'deleted' | 'untracked' | 'renamed';

/** A single changed file entry in status or commit details. */
export interface VcsFileChange {
	path: string;
	status: VcsFileStatusType;
	oldPath?: string;
	staged?: boolean;
	additions?: number;
	deletions?: number;
}

/** Git branch reference. */
export interface VcsBranch {
	name: string;
	isCurrent: boolean;
	headCommit: string;
	upstream?: string;
}

/** Git tag reference. */
export interface VcsTag {
	name: string;
	commit: string;
	message?: string;
}

/** Git remote repository configuration. */
export interface VcsRemote {
	name: string;
	url: string;
	fetchUrl?: string;
	pushUrl?: string;
}

/** Full working tree and repository status. */
export interface VcsStatus {
	branch: string;
	headCommit: string | null;
	headMessage?: string;
	ahead: number;
	behind: number;
	uncommitted: VcsFileChange[];
	branches: VcsBranch[];
	tags: VcsTag[];
	remotes: VcsRemote[];
}

/** Single commit in a commit log or tree. */
export interface VcsCommit {
	sha: string;
	shortSha: string;
	parents: string[];
	author: string;
	authorEmail: string;
	date: number; // Unix timestamp in milliseconds
	message: string;
	branches?: string[];
	tags?: string[];
}

/** Detailed commit info including file list. */
export interface VcsCommitDetails extends VcsCommit {
	files: VcsFileChange[];
	manifest?: Record<string, unknown>;
}

/** Single line inside a diff hunk. */
export interface VcsDiffLine {
	type: 'add' | 'delete' | 'context';
	content: string;
	oldLineNumber?: number;
	newLineNumber?: number;
}

/** A hunk within a file diff. */
export interface VcsDiffHunk {
	oldStart: number;
	oldLines: number;
	newStart: number;
	newLines: number;
	header: string;
	lines: VcsDiffLine[];
}

/** Structured diff representation for one file. */
export interface VcsFileDiff {
	oldPath: string;
	newPath: string;
	status: VcsFileStatusType;
	additions: number;
	deletions: number;
	isBinary?: boolean;
	hunks: VcsDiffHunk[];
}

/** Overall diff result across one or more files. */
export interface VcsDiffResult {
	files: VcsFileDiff[];
	totalAdditions: number;
	totalDeletions: number;
}

/** Request payload for creating a commit. */
export interface VcsCommitRequest {
	message: string;
	filePaths?: string[];
}

/** Request payload for restoring a historical state. */
export interface VcsRestoreRequest {
	commitSha: string;
	path?: string; // Optional: single file restore
}

/** An entry in a virtual repository tree at a commit. */
export interface VcsTreeEntry {
	path: string;
	type: 'blob' | 'tree';
	sha: string;
	size?: number;
}

/** Ephemeral awareness payload broadcast when a Git commit is created. */
export interface VcsCommitAwarenessPayload {
	sha: string;
	message: string;
	author: string;
	timestamp: number;
}
