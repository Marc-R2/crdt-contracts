#!/usr/bin/env node
/**
 * THE `AGENTS.md` SIZE GATE.
 *
 * WHY THIS FILE EXISTS. The cap was a MANUAL check for several waves in the
 * umbrella and sibling repositories, and it was breached twice while a workflow
 * claimed to enforce it. That workflow was a DEAD gate: `continue-on-error:
 * true`, an unconditional `exit 0`, and it measured only one file. **A gate
 * nobody invokes is the same defect as no gate.** This repository ports the
 * working gate from the umbrella so the contract file cannot quietly grow: the
 * cap is measured on every `npm test`-adjacent CI run and on demand via
 * `npm run check:agents`.
 *
 * THE CAP. 24,000 bytes — a suite-wide directive, lowered from the umbrella's
 * 100,000 (user directive, 2026-09-21). The number is a DIRECTIVE, not a budget
 * to negotiate: when the file is over it, the answer is a MOVE to the note that
 * owns the topic, never a bigger number.
 *
 * WHAT IT DOES. Measures the byte length of every `AGENTS.md` in scope, compares
 * it against the cap, and exits non-zero naming the file, its size, the cap and
 * the overage.
 *
 * USAGE
 *   node scripts/check-agents-size.mjs [--cap <bytes>] [file...]
 *
 *   With no file arguments it checks this repository's own `AGENTS.md`.
 *
 *   PATH SEMANTICS — ONE RULE: RELATIVE PATHS ARE REPO-ANCHORED. A relative
 *   argument resolves against THIS repository (the directory holding
 *   `scripts/`), never against the shell's working directory; an absolute
 *   argument is used exactly as given. So the same invocation means the same
 *   file from any directory.
 *
 *   A SYMLINK IS REFUSED, not followed: see `measure` below.
 *
 *   `--cap` overrides the default of 24,000.
 *
 * Privacy: reads file lengths only. It does not read, print, copy or transmit
 * the CONTENT of any file it measures, and it performs no network access and no
 * writes.
 */
import {readFileSync, lstatSync} from 'node:fs';
import {dirname, isAbsolute, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');

/** The umbrella directive's number (user directive, 2026-09-21). Do not quietly raise it. */
export const DEFAULT_CAP = 24000;

/** Parse argv. Exported so a test can drive the real parser rather than a copy. */
export function parseArgs(argv) {
	let cap = DEFAULT_CAP;
	const files = [];
	for (let i = 0; i < argv.length; i++) {
		const arg = argv[i];
		if (arg === '--cap') {
			const raw = argv[++i];
			const n = Number(raw);
			if (raw === undefined || !Number.isFinite(n) || !Number.isInteger(n) || n <= 0) {
				throw new Error(`--cap needs a positive integer, got ${JSON.stringify(raw)}`);
			}
			cap = n;
		} else if (arg.startsWith('--cap=')) {
			const n = Number(arg.slice('--cap='.length));
			if (!Number.isInteger(n) || n <= 0) {
				throw new Error(`--cap needs a positive integer, got ${JSON.stringify(arg.slice(6))}`);
			}
			cap = n;
		} else if (arg.startsWith('--')) {
			throw new Error(`unknown flag ${arg}`);
		} else {
			// REPO-ANCHORED, not CWD-anchored: the default file resolves against
			// ROOT, so explicit relative paths follow the same rule. An absolute
			// path is left verbatim.
			files.push(isAbsolute(arg) ? arg : resolve(ROOT, arg));
		}
	}
	return {cap, files: files.length ? files : [resolve(ROOT, 'AGENTS.md')]};
}

/** Byte size of one file, or a reason it cannot be measured. */
export function measure(file) {
	const full = resolve(file);
	let st;
	// `lstatSync`, NOT `statSync`: `stat` follows symlinks and would measure the
	// TARGET, so a symlinked AGENTS.md measuring a tiny file would pass the gate
	// on the one thing it measures.
	try {
		st = lstatSync(full);
	} catch {
		return {ok: false, file: full, reason: 'no such file'};
	}
	// A SYMLINK IS REFUSED, NOT FOLLOWED: a link means the document a reader
	// opens is not the document the cap governs. Failing CLOSED with a reason
	// beats printing a number for a file the directive never named.
	if (st.isSymbolicLink()) return {ok: false, file: full, reason: 'is a symbolic link'};
	if (!st.isFile()) return {ok: false, file: full, reason: 'not a regular file'};
	// `wc -c` counts BYTES, and that is the measurement the directive names.
	// Reading as a buffer matters: a UTF-8 character is more than one byte.
	return {ok: true, file: full, bytes: readFileSync(full).length};
}

/** Run the whole check. Returns the process exit code; prints its own report. */
export function check(argv, {log = console.log, error = console.error} = {}) {
	let parsed;
	try {
		parsed = parseArgs(argv);
	} catch (e) {
		error(`check-agents-size: ${e.message}`);
		return 2;
	}
	const {cap, files} = parsed;
	const failures = [];
	for (const file of files) {
		const m = measure(file);
		if (!m.ok) {
			failures.push({file: m.file, reason: m.reason});
			continue;
		}
		const over = m.bytes - cap;
		if (over > 0) failures.push({file: m.file, bytes: m.bytes, over});
	}
	if (failures.length === 0) {
		for (const file of files) {
			const m = measure(file);
			log(`check-agents-size: ${m.file} ${m.bytes} bytes (cap ${cap}) — ok`);
		}
		return 0;
	}
	error('');
	// The header names the count of OVER-CAP files, not the count of problems: a
	// missing file or a symlink is a failure, but calling it "over the cap" would
	// be a second, smaller lie in the same output.
	const over = failures.filter((f) => !f.reason).length;
	const unmeasurable = failures.length - over;
	error(`check-agents-size: FAILED — ${over} file(s) over the ${cap}-byte cap, ${unmeasurable} unmeasurable.`);
	for (const f of failures) {
		if (f.reason) {
			error(`  ${f.file}: ${f.reason}`);
			if (f.reason === 'is a symbolic link') {
				error(
					'    This gate measures the file it is NAMED. A symlink resolves to a file the\n' +
						'    directive never named, so the cap is not applied through a link. Commit the\n' +
						'    real file, or point the invocation at it explicitly.',
				);
			}
			continue;
		}
		error(`  ${f.file}: ${f.bytes} bytes, over by ${f.over} (cap ${cap}).`);
		error(`    Measured the way the directive names it: \`wc -c ${f.file}\`.`);
		error(
			'    A BREACH IS ANSWERED BY A MOVE, NOT BY A BIGGER NUMBER. Reference material\n' +
				'    does not belong in AGENTS.md: a table, an enumeration or a script list goes to\n' +
				'    the note that owns the topic, and the contract keeps a NAMED POINTER to it.\n' +
				'    A MOVED INVARIANT IS A DELETED INVARIANT: keep the one-line clause and its gate\n' +
				'    name, move the incident story, and keep both homes from drifting apart.',
		);
	}
	error('');
	return 1;
}

// Only run when invoked directly, so a test can import this module safely.
if (process.argv[1] && resolve(process.argv[1]) === resolve(fileURLToPath(import.meta.url))) {
	process.exit(check(process.argv.slice(2)));
}
