---
feature: casm-phase9-include-processing
created: 2026-07-25
status: approved
---

# Plan: CASM Phase 9 - Include Processing

## Objective

Implement native `.INCLUDE "filename"` processing over CASM's existing
VMM-backed, deterministic two-pass source pipeline. Nested includes must retain
physical source provenance, detect bounded-depth and cycle failures, close every
transient input handle, and replay the exact Pass 1 include graph in Pass 2
without any source filesystem I/O.

This parent plan authorizes the Phase 9 architecture and WP43 prerequisite
reconciliation. WP44-WP49 remain separately gated: each requires its own
detailed plan and explicit user approval before implementation.

## Baseline and Prerequisites

- CASM Phase 8 is complete and approved at `0.1.44` build 1157. The subsequent
  merged LABEL/API work changed the shared ca65 include and legitimately
  advanced CASM's content-hash counter to 1159 without changing its stage;
  WP43 therefore starts at `0.1.44` build 1159 on `b279365`.
- MAIN starts at `$3400`, has size `$3700`, and has 153 bytes free.
- CASM's private zero-page range `$70-$8F` is fully allocated; Phase 9 adds no
  persistent zero-page cells.
- Phase 7 loads up to eight ordered top-level sources into one 65,535-byte VMM
  allocation before Pass 1 and closes every input handle before parsing.
- Phase 6B runs one shared statement dispatcher twice and requires stable final
  PC and instruction widths.
- Phase 8 may additionally own the symbol-table and relocation-table VMM
  allocations. Phase 9 metadata consumes one more registry slot, leaving four
  of eight slots free in a relocatable build.
- `.INCLUDE` is already classified by `lexer.s`, but `emitDirective` rejects it
  with `CASM_DIAG_NOT_IMPLEMENTED` and no filename operand grammar exists.

## Dependency Review and Reconciled Discrepancies

1. The master plan's source-frame wording predates Phase 7 and suggests live
   include handles. Current CASM deliberately preloads and closes inputs.
   Phase 9 frames therefore hold immutable VMM spans and traversal state, not
   handles. One include handle is opened transiently, copied, and closed.
2. The Phase 7 source is a flat combined stream. Nested includes require a
   bounded active frame stack and resumable parent cursors; this cannot be a
   thin `emitDirective` addition.
3. The lexer token payload is frozen at 31 bytes while filenames allow 63
   bytes. `.INCLUDE` uses a dedicated 64-byte operand buffer and a specialized
   quoted scanner; the stable token record does not grow.
4. `CasmSourceVmmCursor` is reused for loading and traversal because loading
   currently finishes before parsing. Pass 1 include discovery invalidates
   that assumption. Phase 9 separates the immutable append cursor from each
   active frame's read cursor.
5. `CasmSourceFileId` currently indexes the eight CLI source slots directly.
   Included files require a separate physical-file catalog and diagnostic name
   lookup.
6. Diagnostic echo selection currently distinguishes buffered lines by line
   number but not physical file/frame identity. Nested files commonly share
   line numbers, so Phase 9 must include identity in echo-buffer matching.
7. Existing top-level source boundaries are start offsets only. Include
   traversal needs explicit physical start/length records and source-instance
   frames.
8. The plan's "include-path resolution" is underspecified for Command 64.
   Phase 9 implements explicit device prefixes and parent-device inheritance,
   not host-style directories or a fallback search list.
9. Reopening files in Pass 2 would weaken Phase 7's deterministic load-once
   contract and permit content changes between passes. Pass 2 remains entirely
   filesystem-free for source input.
10. `test.d64` is already at the 1541 directory-track entry ceiling. New large
    or numerous fixtures should use `casm_overflow_test_d64` unless a later WP
    proves a smaller packaging arrangement fits without displacing coverage.

## Frozen Observable Contract

### Grammar

- Syntax is `.INCLUDE "filename"` only; unquoted operands are rejected.
- Filename payload is 1-63 raw printable PETSCII bytes.
- No escape syntax exists. Quote, null, CR/LF, and control bytes are invalid.
- Horizontal whitespace may surround the quoted operand; a trailing comment is
  allowed; any other trailing token is a syntax error.
- `.INCLUDE` occupies one complete statement.

### Device and Identity

- An explicit `8:` through `11:` child prefix wins.
- An unprefixed child inherits its including physical file's resolved device.
- An unprefixed top-level file captures `CurrentDevice` during initial load.
- Phase 9 has no include search list and no fallback-device probing.
- Physical identity is resolved device plus a case-folded unshifted/shifted
  PETSCII filename with the prefix removed.
- The original spelling remains available for diagnostics.

### Capacities

- Maximum include nesting depth is 16 beyond a depth-zero top-level root.
- Maximum distinct physical files is 32, including top-level roots.
- Maximum include occurrences/events is 128.
- All distinct top-level and included source bytes share the existing 65,535
  byte source-store cap.
- Repeated includes expand every time but share one immutable physical byte
  copy. There is no implicit include-once behavior.
- One 8KB VMM metadata allocation stores the physical catalog and event log.

### Traversal and Boundaries

- The eight existing top-level inputs remain independent depth-zero roots that
  share one symbol scope, output stream, and program counter.
- Frame entry, child EOF, parent resume, and root transition are logical
  statement boundaries regardless of physical trailing newlines.
- Pending CR never crosses a frame boundary.
- The shared 256-byte `CasmIoBuffer` is invalidated and refilled on frame
  push/pop; no frame stores a copy of that buffer.

### Cycles and Repetition

- Cycle detection scans the active frame chain only.
- Direct and indirect cycles fail at the parent include site.
- Sequential reinclusion after a prior frame returns is legal.
- Same folded name on different devices identifies different physical files.

### Deterministic Replay

- Pass 1 discovers, loads, catalogs, and records include events in encounter
  order.
- Pass 2 opens no source files and consumes the event log in order.
- Parent identity, include-site location, child identity, and event ordinal
  must match; missing, extra, or reordered events are fatal replay mismatch.
- Included bytes are immutable between passes even if disk contents change.

### Diagnostics

- Failures inside an included file print its physical filename, line, column,
  and source line/caret where available.
- Include load failures point at the parent `.INCLUDE` site.
- A bounded traceback prints parent include sites from innermost to root.
- Root-only diagnostics print no traceback.
- Diagnostic rendering performs no filesystem I/O and must not mask the
  primary failure.

## Storage Architecture

### Physical Source Store

Keep one source VMM allocation. Each distinct file owns a start offset and byte
length. Source bytes are appended once and remain immutable. Synthetic
statement boundaries are traversal metadata, not bytes included in a physical
file's span.

### Metadata Store

Use one 8KB VMM allocation:

- 32 fixed physical-file records, likely 128 bytes each so a full 63-byte
  printable/canonical filename and span metadata fit without changing the
  64-byte VMM staging buffer. Each record transfers in two windows.
- 128 fixed include-event records, sized by WP43's final ABI freeze.
- Power-of-two record sizes and compile-time capacity assertions are required.

### Frame Stack

Keep compact hot traversal state in bounded BSS. A frame records physical file
ID, start/end/current offsets, line, column, pending-CR state, and parent event
identity. Exact offsets and total bytes are frozen by WP43 before source work.

## Pass 1 Algorithm

1. Catalog and load each top-level root.
2. Parse until an `.INCLUDE` statement is returned.
3. Resolve device and folded canonical identity.
4. Scan active frames for a cycle and check depth.
5. Find or create a physical record.
6. If new, transiently open, read, append, close, and finalize the record.
7. Append one ordered include event.
8. Save the parent frame's consumed position and normalization state.
9. Invalidate lexer lookahead and the refill window.
10. Push and traverse the child frame.
11. At child EOF, pop, restore, invalidate/refill, and resume the parent after
    the include statement.

## Pass 2 Algorithm

1. Reset root/frame traversal and the event-read cursor.
2. Parse the source normally.
3. At `.INCLUDE`, consume and validate the next Pass 1 event.
4. Push the recorded immutable child span without opening a file.
5. At final EOF, require exact consumption of all recorded events.
6. Preserve existing final-PC agreement and relocation behavior.

## Work Packages

### WP43 - Prerequisite Reconciliation and Phase 0C.19 Freeze

Record the contract, task hierarchy, exact metadata/frame ABI proposal,
baseline measurements, expected diagnostics, and verification matrix. No
functional include code. Dedicated plan:
`brain/plans/2026-07-25-casm-phase9-wp43-prerequisite-reconciliation.md`.

### WP44 - Quoted Include Operand Grammar

Add the dedicated 64-byte operand buffer, quoted scanner, parser path, and
grammar diagnostics. Remove `.INCLUDE` from `emitDirective`'s generic
not-implemented ownership. Do not load or traverse a child yet.

### WP45 - Physical File Catalog and Dynamic Source Loading

Add the metadata VMM store, device/name canonicalization, catalog lookup,
deduplicated immutable source append, and transient child load/close behavior.

### WP46 - Frame Stack, Nested Traversal, and Cycle Detection

Add frame-aware refill/push/pop/root transitions, active-chain cycle checks,
depth enforcement, statement-boundary semantics, and file-aware echo identity.

### WP47 - Ordered Include Graph and Pass 2 Replay

Add event recording, replay cursor, correspondence checks, final event-count
agreement, and production two-pass integration with zero Pass 2 source I/O.

### WP48 - Included-Source Diagnostics and Tracebacks

Replace CLI-only filename lookup with catalog lookup, add include-specific
messages, and render bounded include-site traceback without masking failures.

### WP49 - Verification, Walkthrough, and Completion Gate

Perform consolidated static, build, artifact, trusted-reference, failure,
resource, and user runtime verification. Add no production behavior unless a
discovered defect receives an amended plan and approval.

## Expected Files

- New production module: `src/external/casm/include.s`.
- Production changes: `common.inc`, `casm.s`, `source.s`, `lexer.s`,
  `parser.s`, `emit.s`, `diagnostics.s`, `state.s`, and possibly `fileio.s`.
- Build/test changes: `CMakeLists.txt`, fixture generator, trusted references,
  and likely a `tests/src/casm_include/` harness.
- Records: per-WP plans/walkthroughs, `wiki/tasks/casm.md`, `brain/task.md`,
  `brain/KNOWLEDGE.md`, `brain/MEMORY.md`, `CHANGELOG.md`, CASM manuals, and
  CASM-local `AGENTS.md`.

## Verification Matrix

- Quoted grammar, 1/63/64-byte boundaries, empty/unterminated/control/trailing
  cases.
- One-level, multi-level, depth-16, and depth-17 nesting.
- Direct, indirect, and alternate-case cycle spellings.
- Sequential repeat and deduplicated physical storage.
- Same name on different devices; inherited and explicit prefixes.
- Missing/open/read/close/VMM/catalog/event-capacity failures.
- Exact 65,535-byte distinct-source boundary and one-byte overflow.
- Parent/child CR, LF, CRLF, and missing-final-newline combinations.
- Cross-include forward/backward labels and branches.
- Static and relocatable trusted-reference equivalence to flattened source.
- Zero Pass 2 source opens and explicit replay-mismatch harness cases.
- Included diagnostic location, line echo, and full traceback.
- Existing standalone harnesses and targeted Phase 3-8 regressions.
- `casm`, no-change rebuild, `image_d64`, `test_image_d64`, and
  `casm_overflow_test_d64`.

## Stop Conditions

Stop and amend the active WP plan if source append requires another 256-byte
buffer, folded identity disagrees with Command 64 DOS behavior, production VMM
ownership exceeds four simultaneous slots, metadata cannot use the 64-byte
transfer window safely, Pass 2 performs source I/O, equivalent flattened output
differs, or MAIN growth approaches the external-app ceiling without a reviewed
layout.

## Completion Gate

Phase 9 completes only after WP43-WP49 are individually planned, approved,
implemented, and verified; the user completes the runtime walkthrough and
explicitly approves completion. Approval of this parent plan activates only
WP43.
