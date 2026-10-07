/**
 * @marc-r2/crdt-contracts — implementation-free wire contracts shared by
 * the Obsidian plugin and the sync server.
 *
 * This package contains TYPES and CONSTANTS only: no functions, no UUID or
 * crypto sources, no filesystem or DOM access, no Yjs, no NestJS runtime.
 * Behavior (minting, predicates, validators, room-name helpers) stays in
 * the consuming repos.
 */

export * from './docType';
export * from './blob';
export * from './blobTypes';
export * from './history';
export * from './vcs';
export * from './protocol';
export * from './capabilities';
export * from './serverInfo';
