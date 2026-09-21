/**
 * protocol — the client/server wire-protocol pin (P0 release blocker).
 *
 * Room names (`project-{id}@structure`, `project-{id}@{globalId}`) and the
 * structure Y.Map entry schema are IMPLICIT wire contracts — a client with
 * a different protocol could silently corrupt mixed-version self-hosted
 * rooms. `PROTOCOL_VERSION` is the single integer that pins these; bump it
 * (with a matching `compat-manifest.json` pin) on ANY breaking room-name or
 * entry-schema change so mismatched peers fail visibly instead of
 * corrupting data.
 *
 * Implementation-free: one numeric constant. The room-name helpers are
 * deliberately NOT here (they would be runtime implementation); call sites
 * keep the inline templates until the extraction phase introduces them.
 */

/** Wire-protocol version (integer). Start at 1. */
export const PROTOCOL_VERSION = 1;
