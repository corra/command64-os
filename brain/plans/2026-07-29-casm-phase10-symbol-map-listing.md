---
feature: casm-phase10-symbol-map-listing
created: 2026-07-29
status: complete
taskwarrior: 32e09eea-691d-40bc-aa7a-7d2299fe093b
---

# Plan: CASM Phase 10 - Symbol Map and Listing

## Status and Authorization

This governing plan is approved. It freezes the observable Phase 10 contract,
architecture, work-package sequence, bounds, failure behavior, and completion
gate. Approval creates the task hierarchy but does not activate WP50 or authorize
source edits. Each work package requires its own detailed plan and explicit user
approval before implementation.

Parent plan:
`brain/plans/2026-07-16-casm-assembler-implementation-plan.md`.

Baseline: CASM `0.1.50` build 1204 with Phases 1-9 complete and user-approved.

## Objective

Implement `/M` deterministic symbol-map output and `/L` native listing
generation without changing assembled PRG bytes, source traversal, include
replay, relocation behavior, diagnostics provenance, or cleanup guarantees.

The completed phase is the master plan's CASM 0.2 developer-usability release.

## Inherited Contracts

- CASM remains a native Command 64 application; map and listing processing run
  on the 6510 and use Command 64 file and VMM services.
- `/M` and `/L` are already parsed case-insensitively as duplicate-rejected
  flags. Phase 10 removes only their current `NOT IMPLEMENTED` runtime gate.
- Pass 1 and Pass 2 share `casmRunPass`; Pass 2 reparses the deterministic VMM
  source stream and performs no source filesystem I/O.
- Symbols are fixed 64-byte VMM records stored in definition order. Hash buckets
  accelerate lookup but do not define reporting order.
- Top-level and included source bytes remain in the source VMM store. Packed
  physical identity distinguishes top-level roots from include-catalog files.
- Includes retain their existing ordered event replay, frame-stack, provenance,
  depth, physical-file, and event-count bounds.
- `emitByte` is the source-generated-byte boundary. `emitRawByte` also carries
  the PRG header and final format bytes and is not a valid listing-byte hook.
- Every acquired handle and VMM allocation is registered immediately with the
  central resource owner. Fatal cleanup preserves the primary diagnostic.
- `/M` and `/L` must never change generated static or R6 PRG bytes.

## Command-Line Behavior

### Symbol Map

`/M` prints the map to the console after every requested output file has been
written and closed successfully.

Exact format:

```text
SYMBOL MAP
$3400 START
$3412 LOOP
002 SYMBOLS
```

- Symbols appear in deterministic definition order, never hash-bucket order.
- Addresses are uppercase four-digit hexadecimal values at the configured
  assembly origin. Relocatable output reports its assembled base values.
- Symbol names preserve their original case-sensitive definition spelling.
- The final count is unsigned decimal and supports the full 0-512 symbol range.
- An empty map prints the title followed by `000 SYMBOLS`.
- `/M` allocates no map-specific VMM store and performs no sorting.
- With `/M /L`, listing success precedes all map output. A listing failure
  suppresses the map.

### Listing Filename

`/L` derives the listing name from the final PRG output name after `/O` or
default output-name derivation:

1. Preserve any device prefix and inspect only the filename portion after it.
2. Replace the final dot-suffix with `.LST`.
3. Append `.LST` when the filename has no dot.
4. Preserve device-prefix and basename bytes exactly.

Before source loading or output creation, reject:

- an empty filename portion;
- a derived name longer than `CASM_FILENAME_MAX`;
- a listing name byte-identical to the PRG output name; or
- malformed derivation state.

No explicit listing-name option is added in Phase 10.

## Listing Content

### Source Coverage

The listing contains every physical source line encountered in actual traversal
order:

- emitting instructions and directives;
- zero-byte labels and mode directives;
- `.INCLUDE` lines before their included child traversal;
- blank lines and comment-only lines;
- repeated include traversals; and
- final unterminated physical lines.

Synthetic newlines inserted between top-level files are logical stream
separators and do not produce listing rows.

All zero-byte rows display the current PC at the start of the physical line.
Included files retain their own packed physical identity, filename, and line
number. Returning from an include emits a new file-transition header before the
next parent row.

### Encoding

- Generated text and preserved source bytes are raw PETSCII.
- Every generated listing row terminates with PETSCII CR.
- Original source payload bytes are copied exactly, excluding their original
  CR, LF, or CRLF terminator.
- Tabs and other accepted source bytes are not expanded or normalized.
- The listing has no global title or footer. An empty source produces an empty
  listing file.

### File Headers

Whenever packed physical file identity changes, serialize:

```text
FILE 00: ROOT.S
```

- The packed identity is two uppercase hexadecimal digits.
- The prefix occupies columns 1-9; up to 31 filename bytes follow.
- Additional filename bytes use continuation rows with columns 1-9 blank and
  up to 31 bytes in columns 10-40.
- The complete authoritative filename is preserved; it is never truncated.

### Detail Rows

Every detail row is at most 40 bytes before CR:

| Columns | Width | Content |
|---|---:|---|
| 1-2 | 2 | Packed physical file identity, uppercase hexadecimal |
| 3 | 1 | `:` |
| 4-8 | 5 | One-based physical line number, zero-padded decimal |
| 9 | 1 | Space |
| 10-13 | 4 | Starting PC, uppercase hexadecimal without `$` |
| 14 | 1 | Space |
| 15-25 | 11 | Up to four bytes as `HH HH HH HH`, space-padded |
| 26 | 1 | Space |
| 27-40 | 14 | Up to 14 exact source bytes |

Example:

```text
00:00001 3400 A9 01       lda #$01
```

### Continuations

- The first detail row carries the first four emitted bytes and first 14 source
  bytes.
- Byte continuations leave columns 1-8 blank, display the advanced address in
  columns 10-13, and carry the next four emitted bytes in columns 15-25.
- Source continuations leave columns 1-26 blank and carry the next 14 exact
  source bytes in columns 27-40.
- Byte and source continuations are independent: exhaust all required byte
  continuation rows and source continuation rows without coupling their counts.
- A zero-byte line uses spaces in columns 15-25 rather than placeholder values.

## Listing Architecture

### Conditional VMM Stores

`/L` conditionally allocates exactly two additional VMM stores:

1. Metadata: 4,096 fixed 16-byte records, exactly 65,536 bytes.
2. Emitted-byte mirror: up to 65,536 source-generated bytes.

Worst-case CASM VMM registry occupancy is six of eight slots:

1. source stream;
2. symbol records;
3. include catalog and events;
4. relocation records;
5. listing metadata; and
6. listing emitted bytes.

`/M` without `/L` acquires neither listing allocation.

### Proposed Metadata Record

WP50 freezes exact offsets after tracing the current source and pass state:

| Field | Bytes | Purpose |
|---|---:|---|
| Packed file identity | 1 | Top-level/include physical identity |
| Physical line | 2 | One-based line number |
| Source VMM offset | 2 | Absolute first source payload byte |
| Source length | 1 | 0-255 payload bytes |
| Starting PC | 2 | PC before processing the line |
| Byte-stream offset | 2 | First mirrored byte for the line |
| Emitted-byte count | 2 | Number of bytes attributed to the line |
| Flags | 1 | Final-line/boundary and future-safe state |
| Reserved | 3 | Zero-filled; no speculative semantics |

The record is written only after the corresponding line transaction completes.
The 65,536-byte emitted-stream endpoint requires an explicit full/exhausted
state so a valid endpoint is never confused with 16-bit wraparound.

### Capture Boundary

Phase 10 adds a listing transaction around the shared statement path rather
than a syntax tree or general instruction-event IR:

1. Before parsing, begin one transaction by capturing starting PC and the
   current mirrored-byte cursor.
2. Parse and dispatch through the existing parser/emitter path.
3. Mirror each successful Pass 2 source-generated byte at `emitByte` without
   changing PRG buffering or `CasmPc` advancement.
4. Source normalization publishes the WP50-frozen completed-line sidecar with
   authoritative VMM span and provenance. Consume it after dispatch and commit
   one metadata record with the emitted-byte delta.
5. For `.INCLUDE`, commit the parent directive line before pushing the child
   frame, preserving parent-before-child traversal order.
6. Commit parser-returned blank/comment lines with a zero byte count. EOF
   creates no row itself but may commit a pending final unterminated line.
7. Do not commit synthetic-only top-level separator newlines.

The source layer exposes the completed-line sidecar and
`sourceTakeCompletedLine` ABI frozen by WP50. Consumers must not infer parse
position from the bulk-refill cursor and must not grow the frozen token or lexer
records. Pass 2 must remain filesystem-free.

### Serialization

After Pass 2 agreement and successful PRG finalization:

1. Create the derived listing file.
2. Replay metadata records in append order.
3. Resolve authoritative filenames from top-level CLI records or include
   physical-catalog records.
4. Read exact source spans from the existing source VMM allocation.
5. Read emitted bytes from the listing byte mirror.
6. Format bounded 40-column rows into a fixed base-RAM staging buffer.
7. Write through Command 64 file services and close the listing.
8. Print `/M` output only after listing close succeeds.

The listing writer never reparses source or re-evaluates expressions.

## Bounds and Diagnostics

- Maximum listed physical-line occurrences: 4,096.
- Maximum mirrored source-generated bytes: 65,536.
- Maximum source payload per physical line remains 255 bytes.
- Maximum symbol-map records remains 512.
- Every append checks capacity before writing or incrementing.
- Cursor arithmetic must explicitly handle carry and the valid 65,536 endpoint.
- New diagnostics, if required, are contiguous and compile-time range asserted.

Required distinct failures include:

- listing-name overflow;
- listing-name collision;
- listing metadata full;
- listing byte mirror full/overflow;
- listing VMM transfer failure;
- listing create, write, short-write, close, and delete failure; and
- internal metadata/source/byte replay disagreement.

WP50 decides which existing generic diagnostics may be reused without losing a
stable user-visible distinction.

## Failure and Cleanup Behavior

### Before PRG Finalization

Any listing capture, bound, source-span, or VMM failure during Pass 2 is fatal.
The existing incomplete-PRG abort path closes and removes partial PRG output;
central cleanup releases both listing VMM stores.

### After PRG Finalization

If listing create, write, short-write, or close fails after the PRG is valid:

- preserve the listing failure as the primary diagnostic;
- close the listing handle when possible;
- delete only the incomplete listing;
- retain the valid finalized PRG;
- suppress `/M`; and
- exit with failure through central cleanup.

Listing ownership state is separate from PRG ownership/validity state. It must
not inherit the known ambiguity where a successful replace-mode open can be
mistaken for proof that CASM created a previously nonexistent file. WP50 must
freeze safe replacement and deletion semantics before WP53 edits file handling.

Map printing performs no file acquisition. Cleanup failures remain secondary to
an earlier assembly or listing diagnostic.

## ABI, Register, and Scratch Requirements

Every work-package plan must freeze each new public routine's:

- inputs and outputs;
- carry and zero flag meaning;
- preserved and clobbered registers;
- zero-page and base-RAM scratch ownership;
- allowed nested calls; and
- VMM/file ownership side effects.

No new zero-page byte is approved by this parent plan. MAIN/BSS growth requires
measurement and explicit approval in the implementing work package. Listing
formatting must use bounded base-RAM staging and must not overlap source, VMM,
expression, diagnostics, include, relocation, or output state across calls.

## Work Packages

### WP50: Contract Reconciliation and ABI Freeze

Taskwarrior: `ad82f04d-0d34-4902-9a2c-ae27292902cf`.

Dedicated plan:
`brain/plans/2026-07-29-casm-phase10-wp50-contract-reconciliation.md`.

- Reconcile this plan with the current Phase 9 source, include, parser, emitter,
  symbol, output, cleanup, test, memory, and DOX contracts.
- Trace exact statement, newline, include push/pop, source-offset, emitted-byte,
  finalization, and fatal-cleanup paths.
- Freeze metadata offsets, full-endpoint representation, public routines,
  diagnostics, register/flag contracts, scratch, and measured envelopes.
- Freeze safe existing-listing replacement/deletion behavior.
- Bind a measurable fixture matrix to WP51-WP55.
- Make no production behavior change.

Gate: the user approves the complete design/ABI freeze and dedicated WP51 plan.
Completion version: `0.1.51`.

### WP51: Listing Stores and Capture Events

Taskwarrior: `a64fa847-1b46-44fd-be3b-8ad7b1055c92`.

Dedicated plan:
`brain/plans/2026-07-29-casm-phase10-wp51-listing-stores-capture.md`.

- Add `listing.s` storage initialization, append, replay, and bounds primitives.
- Conditionally allocate/register the two listing VMM stores.
- Add the approved exact physical-line-span source query.
- Mirror Pass 2 bytes through `emitByte`, excluding raw PRG/R6 format bytes.
- Integrate blank, statement, directive, and pre-include-push commit points.
- Verify nested include and parent-resume traversal order.
- Add focused metadata, byte-capture, boundary, overflow, and replay harnesses.

Gate: listing records and mirrored bytes exactly describe Pass 2 without file
serialization or PRG changes. Completion version: `0.1.52`.

### WP52: Deterministic Symbol Map

Taskwarrior: `0bf2e86b-0bd0-443a-b84b-b2c258e98181`.

Dedicated plan:
`brain/plans/2026-07-29-casm-phase10-wp52-deterministic-symbol-map.md`.

- Add `map.s` and iterate symbol records from index zero through count minus one.
- Print the approved title, `$HHHH LABEL` rows, and decimal total.
- Do not sort, traverse hash chains, or allocate map-specific VMM.
- Verify empty, one-symbol, maximum-length, case-sensitive, 512-symbol, static,
  and relocatable maps.
- Keep production invocation gated until WP54 integration.

Gate: focused map fixtures match exact PETSCII output in definition order.
Completion version: `0.1.53`.

### WP53: Listing Naming, Serialization, and Cleanup

Taskwarrior: `aa57f461-36a9-455c-966f-ac484ec57b41`.

Dedicated plan:
`brain/plans/2026-07-29-casm-phase10-wp53-listing-serialization-cleanup.md`.

- Implement approved `.LST` derivation and early collision validation.
- Add dedicated listing file ownership and abort state.
- Serialize file headers, detail rows, and independent continuations.
- Resolve top-level and include filenames from authoritative records.
- Preserve source payload bytes exactly and write CR row terminators.
- Delete incomplete listings while retaining finalized PRGs.
- Verify output-name, empty-source, long-filename, 255-byte-line, many-byte
  directive, device-prefix, and file-failure fixtures.

Gate: golden listing files and cleanup harnesses match the frozen contract.
Completion version: `0.1.54`.

### WP54: Production Integration

Taskwarrior: `f4b598fd-bab1-4394-9415-c71e3ea1cfa5`.

Dedicated plan:
`brain/plans/2026-07-29-casm-phase10-wp54-production-integration.md`.

- Remove `/M` and `/L` from the production `NOT IMPLEMENTED` gate.
- Sequence name derivation, conditional allocation, two passes, agreement,
  PRG finalization, listing serialization, map printing, cleanup, and exit.
- Exercise `/M`, `/L`, `/M /L`, `/S`, `/O`, multiple roots, nested includes,
  static output, and R6 output.
- Compare PRG artifacts across all option combinations.
- Verify `/M`-only execution acquires no listing resources.

Gate: all supported combinations work end-to-end and generated PRGs remain
byte-identical. Completion version: `0.1.55`.

### WP55: Verification, Walkthrough, and Phase Gate

Taskwarrior: `94d98a2b-7ad4-49f0-bf33-38702690eca9`.

Dedicated plan:
`brain/plans/2026-07-29-casm-phase10-wp55-verification-walkthrough-completion-gate.md`.

- Run every existing CASM harness and all Phase 10-specific tests.
- Build CASM and each affected disk image independently through CMake.
- Inspect MAIN/BSS, zero-page, VMM slots, imports/exports, PRG headers, R6
  footer, relocation count, and no-change build-counter behavior.
- Verify 4,096/4,097 line occurrences and emitted-byte endpoint boundaries.
- Verify malformed/colliding names, no REU, disk full, create/write/close/delete
  failures, valid-PRG retention, repeated cleanup, and map suppression.
- Perform the mandatory complete implementation review before runtime testing.
- Produce and complete the native runtime walkthrough.
- Obtain explicit user approval before marking WP55 or Phase 10 complete.

Gate: all evidence passes and the user explicitly approves Phase 10 completion.
Completion version: `0.1.56`.

### CASM 0.2.0 Promotion

After WP55 and Phase 10 receive explicit completion approval, make a separate
completion-only version change from `0.1.56` to `0.2.0`. It must change no
assembly behavior, listing format, map format, or output bytes other than the
CASM application's own version/build artifact effects.

## Expected Files

New production modules:

- `src/external/casm/listing.s`
- `src/external/casm/map.s`

Likely production modifications:

- `src/external/casm/casm.s`
- `src/external/casm/common.inc`
- `src/external/casm/cli.s`
- `src/external/casm/source.s`
- `src/external/casm/state.s`
- `src/external/casm/emit.s`
- `src/external/casm/fileio.s`
- `src/external/casm/resources.s`
- `src/external/casm/diagnostics.s`

Likely build, test, and record modifications:

- `CMakeLists.txt`
- focused Phase 10 harnesses and fixtures under `tests/`
- `wiki/tasks/casm-phase10-symbol-map-listing.md`
- `wiki/tasks/casm.md`
- `brain/task.md`
- `brain/KNOWLEDGE.md`
- `brain/MEMORY.md`
- `CHANGELOG.md`
- applicable DOX files
- a Phase 10 runtime walkthrough

Exact files are frozen by each dedicated work-package plan before edits.

## Verification Strategy

### Static and Build

- Configure and build only through CMake.
- Build focused harnesses, CASM, and affected disk images independently.
- Require zero warnings/errors and `git diff --check` success.
- Confirm no-change rebuilds do not increment `BUILD_CASM`.
- Inspect linked envelopes and every new import/export and diagnostic range.

### Functional

- Empty, one-line, blank/comment-only, and final-unterminated sources.
- Instructions and every currently supported emitting directive.
- Long data directives requiring byte continuations.
- Source lengths around 14-byte continuation boundaries and the 255-byte cap.
- Multiple roots with and without synthetic boundary newlines.
- Nested includes, sequential reinclusion, maximum depth, and parent resumption.
- Static and relocatable programs with forward/backward symbols.
- Empty through 512-entry maps in definition order.
- `/M`, `/L`, `/M /L`, `/S`, and `/O` combinations.
- PRG byte and relocation-table identity with options disabled/enabled.

### Bounds, Failures, and Cleanup

- 4,096 and 4,097 listed physical-line occurrences.
- Mirrored-byte stream at its final valid byte and one byte beyond capacity.
- Listing-name overflow, malformed derivation, and output/listing collision.
- VMM unavailable/allocation/transfer failures for each listing store.
- Listing create, write, short-write, close, and delete failures.
- Valid PRG retention after post-finalization listing failure.
- Partial PRG deletion after capture failure before finalization.
- Map suppression after listing failure.
- Repeated success and failure with no leaked handles or VMM allocations.

### Runtime Walkthrough

The user launches CASM from Command 64, assembles representative static and R6
programs with `/M`, `/L`, and both options, inspects native listing/map output,
loads/runs generated PRGs, exercises included sources and representative
failures, and confirms shell/resource integrity. The phase is not done until the
user explicitly approves the walkthrough.

## Documentation and DOX

Each work package synchronizes its dedicated plan, `wiki/tasks/casm.md`, the
Phase 10 task, `brain/task.md`, Taskwarrior, and evidence records. Behavioral or
ABI changes update CASM DOX immediately. Completion updates user documentation,
programmer/internal references, knowledge, memory, changelog, and walkthrough.

## Stop Conditions

Stop and request an amended plan and renewed approval if:

- exact source-line offsets require growing the frozen token record;
- Pass 2 source filesystem I/O becomes necessary;
- listing capture changes parser, expression, include, emission, or relocation
  semantics;
- more than two additional VMM slots are required;
- the 4,096-line or 65,536-byte contracts cannot be checked before wraparound;
- safe listing cleanup could delete a file CASM did not create or replace;
- `/M` or `/L` changes PRG bytes, relocation records, include order, or
  diagnostics provenance;
- a new zero-page allocation is required;
- MAIN/BSS growth exceeds the active work package's approved envelope; or
- implementation materially deviates from the exact output contracts above.

## Completion Gate

Phase 10 is complete only when WP50-WP55 are individually planned, approved,
implemented, verified, reviewed, walked through, and explicitly approved; all
task/documentation records agree; `/M` and `/L` preserve PRG identity; and the
user explicitly authorizes the `0.2.0` completion promotion. Until then the
phase and all unapproved work packages remain pending.

## Progress

- 2026-08-08: **Phase 10 is complete.** WP50-WP55 all individually planned,
  approved, implemented, verified, reviewed, walked through, and
  user-approved (see each WP's own plan/walkthrough,
  `wiki/tasks/casm.md`, and `wiki/tasks/casm-phase10-symbol-map-listing.md`
  for the full per-WP record). `/M` and `/L` are both fully implemented in
  production `casm`, proven to preserve PRG/R6 identity across the full
  option matrix by both WP54's own fixture matrix and WP55's independent
  re-verification. The user explicitly authorized the `0.2.0` completion
  promotion the same day WP55's own completion was approved; applied per
  `brain/plans/2026-07-29-casm-phase10-wp55-verification-walkthrough-completion-gate.md`'s
  increment 7. CASM stands at `0.2.0` build `1260`, live-verified via VICE
  (`CASM V0.2.0.1260`), no assembly/listing/map behavior changed beyond
  the version/build artifact itself.
