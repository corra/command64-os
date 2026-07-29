---
feature: casm-phase10-wp55-verification-walkthrough-completion-gate
created: 2026-07-29
status: approved-blocked
taskwarrior: 94d98a2b-7ad4-49f0-bf33-38702690eca9
depends-on: f4b598fd-bab1-4394-9415-c71e3ea1cfa5
---

# Plan: CASM Phase 10 WP55 - Verification, Walkthrough, and Completion Gate

## Status

Approved but blocked by WP54 completion. WP55 adds no production behavior of its own; its only eventual
production change is the separate completion-only `0.1.56` version increment
and, after explicit Phase 10 approval, the completion-only `0.2.0` promotion
described by the parent plan. A discovered defect stops WP55 until its root
cause, exact remediation, tests, and resource impact receive an amended plan
and explicit approval.

Parent plan: `brain/plans/2026-07-29-casm-phase10-symbol-map-listing.md`.
Prerequisite plans: WP50-WP54, required complete and user-approved before this
plan's verification work begins. WP54's target completion is CASM `0.1.55`.

Fixture ownership assigned by WP50: WP55 owns full regression/bounds coverage,
the memory/ABI/stack/carry/resource/artifact audit, the implementation review,
the native walkthrough, and the `0.2.0` gate.

## Objective

Consolidate and independently verify the complete Phase 10 `/M` and `/L`
implementation delivered by WP50-WP54. Prove the frozen contract holds exactly:
deterministic symbol-map output, native listing generation, unchanged PRG/R6
bytes, unchanged source traversal and include replay, unchanged diagnostics
provenance, and unchanged cleanup guarantees. Produce the consolidated user
walkthrough and, only after explicit approval, close Phase 10 and promote
`0.2.0`.

## Scope

Included:

- Reconcile WP50-WP54 requirements and frozen ABI against the final
  implementation in `listing.s`, `map.s`, and every modified module.
- Review the complete capture, metadata, byte-mirror, serialization, naming,
  cleanup, and CLI-integration paths, including carry/error propagation at
  every module boundary identified by WP50.
- Run all Phase 10 standalone harnesses and affected Phase 1-9 regressions.
- Verify PRG and R6 relocation-table identity across every `/M`/`/L`/`/S`/`/O`
  combination against pre-Phase-10 baselines.
- Verify the 4,096/4,097 listed-line-occurrence bound and the 65,536-byte
  emitted-byte endpoint, including the explicit full/exhausted state.
- Verify malformed/colliding listing names, VMM/allocation/transfer failures,
  disk-full and create/write/short-write/close/delete failures, valid-PRG
  retention, map suppression, and repeated cleanup with no leaked handles or
  VMM allocations.
- Verify measured production and harness envelopes, the content-driven build
  counter, and all affected disk images.
- Produce the consolidated user walkthrough and synchronize closeout records.
- After explicit Phase 10 completion approval, apply the separate
  completion-only `0.1.56` to `0.2.0` promotion and verify stability.

Excluded:

- New directives, syntax, diagnostics, map/listing behavior, refactoring, or
  optimization.
- Unapproved memory-envelope, zero-page, ABI, or Phase 10 contract changes.
- The optional progress feature or activation of master-plan work beyond
  Phase 10.

## Frozen Acceptance Contract

Restated from the parent plan and WP50-WP54 for direct verification:

- `/M` prints `SYMBOL MAP`, `$HHHH LABEL` rows in strict definition order
  (never hash-bucket order), and a decimal total supporting 0-512 symbols; an
  empty map prints the title and `000 SYMBOLS`.
- `/M` allocates no map-specific VMM store and performs no sorting.
- `/L` derives a `.LST` name from the final PRG output name, preserving any
  device prefix, and rejects an empty filename portion, an over-length derived
  name, a name byte-identical to the PRG output name, or malformed derivation
  state before source loading or output creation.
- The listing contains every physical source line in actual traversal order,
  including zero-byte lines, `.INCLUDE` lines before child traversal, blank and
  comment-only lines, repeated include traversals, and a final unterminated
  line; synthetic top-level separator newlines produce no row.
- Listing text and preserved source bytes are raw PETSCII; every row terminates
  with PETSCII CR; original CR/LF/CRLF terminators are excluded; no tab or byte
  expansion occurs; an empty source produces an empty listing file.
- File-identity transitions serialize the exact `FILE 00: ROOT.S` header and
  filename continuation rows with the complete authoritative filename, never
  truncated.
- Every detail row is at most 40 bytes before CR and matches the frozen
  column layout; the first row carries up to four emitted bytes and 14 source
  bytes; byte and source continuations advance independently; a zero-byte line
  uses spaces, not placeholder values, in the byte columns.
- `/L` conditionally allocates exactly two additional VMM stores (4,096
  fixed 16-byte metadata records; up to 65,536 mirrored emitted bytes); `/M`
  without `/L` acquires neither.
- `emitByte` is the only source-generated-byte capture boundary; `emitRawByte`
  PRG/R6 format bytes are never mirrored; Pass 2 performs no source filesystem
  I/O and no reparsing or re-evaluation during listing serialization.
- With `/M /L`, listing success precedes all map output; a listing failure
  suppresses the map.
- A pre-finalization listing, bound, source-span, or VMM failure is fatal and
  removes partial PRG output; a post-finalization listing create/write/
  short-write/close failure preserves the primary diagnostic, closes the
  listing handle when possible, deletes only the incomplete listing, retains
  the valid finalized PRG, suppresses `/M`, and exits with failure.
- Listing cleanup never deletes a file CASM did not create or safely replace.
- `/M` and `/L`, singly or combined, with `/S` and `/O` in every combination,
  never change generated static or R6 PRG bytes, relocation records, source
  traversal, include replay, or diagnostics provenance.

## Baseline Reconciliation

Before substantive verification:

1. Confirm WP50-WP54 are complete in Taskwarrior, `wiki/tasks/casm.md`,
   `wiki/tasks/casm-phase10-symbol-map-listing.md`, and `brain/task.md`.
2. Confirm the CASM version/build WP54 completed at (target `0.1.55`) and a
   stable WP54 no-change rebuild.
3. Re-measure every approved envelope frozen by WP51-WP54 (production, and
   each of `test_casm_listing`, `test_casm_listcap`, `test_casm_map`,
   `test_casm_listwrite`, and `test_casm_phase10`).
4. Confirm the diagnostic range `$39`-`$41` matches WP50's reservation with no
   unapproved renumbering.
5. Confirm expected harnesses and fixtures are present on their documented
   images.
6. Record the starting revision, version, build number, artifact size,
   relocation count, and image checksums.

Any unexplained discrepancy blocks further verification.

## Full-Path Review

Trace the implementation rather than inferring behavior from names:

1. CLI gate removal and listing-name derivation/validation before source
   loading.
2. `listingStateInit`, conditional `/L` allocation and registration order
   relative to `sourceRewind`/`includeReplayReset`.
3. Per-statement capture transaction: snapshot, dispatch, `sourceTakeCompletedLine`
   consumption, metadata append, and mirrored-byte delta assignment.
4. `.INCLUDE` parent-before-child commit ordering and parent-resume traversal.
5. Metadata and byte-mirror bounds checks, including the 65,536-byte full/
   exhausted state and carry-safe cursor arithmetic.
6. Pass agreement, PRG finalization, and the required commit order: PRG commit
   before listing serialization before map printing before the success line.
7. Listing serialization: file-header transitions, detail-row and independent
   byte/source continuation formatting, source-span reads from the source VMM
   store, and byte-mirror reads.
8. Symbol map iteration by definition-order index, exact row/title/count
   formatting, and confirmation that no sort or hash-chain traversal occurs.
9. Unified fatal routing (`artifactsAbort`) across pre-finalization,
   post-finalization listing, and map failure cases, including central cleanup
   of every registered handle and VMM allocation.

The review explicitly checks carry, zero, register, and error contracts at
cross-module calls and rejects continuation with partially initialized state.

## Verification Matrix

### Symbol Map

- Verify 0, 1, maximum-length-name, case-sensitive, and 512-symbol maps in
  definition order for both static and relocatable output.
- Verify the empty-map `000 SYMBOLS` line and the unsigned decimal count
  across the full 0-512 range.
- Verify `/M` alone acquires no listing VMM store.

### Listing Content and Format

- Verify empty, one-line, blank/comment-only, and final-unterminated sources.
- Verify every currently supported emitting instruction and directive,
  including long data directives requiring byte continuations.
- Verify source lengths spanning the 14-byte continuation boundary and the
  255-byte payload cap.
- Verify multiple top-level roots with and without synthetic boundary
  newlines, and confirm no row is emitted for a synthetic-only separator.
- Verify nested includes, sequential reinclusion, maximum depth, and correct
  parent-resume file-header re-transition.
- Verify PETSCII byte fidelity, CR row termination, and exact 40-byte row
  bounds, including zero-byte rows using spaces rather than placeholders.

### Bounds

- Verify exactly 4,096 listed physical-line occurrences succeed and 4,097
  fails deterministically before wraparound.
- Verify the mirrored-byte stream at its final valid byte (65,535) and one
  byte beyond capacity (65,536th), confirming the explicit full/exhausted
  state is never confused with 16-bit wraparound.
- Verify per-line emitted-byte count overflow detection.

### Naming, Serialization Failures, and Cleanup

- Verify `.LST` derivation for device-prefixed, dot-suffixed, and
  no-dot-suffix filenames.
- Verify rejection of an empty filename portion, an over-length derived name,
  and a derived name byte-identical to the PRG output name, each before source
  loading or output creation.
- Inject listing create, write, short-write, close, and delete failures both
  before and after PRG finalization; confirm pre-finalization failures remove
  partial PRG output and post-finalization failures retain the valid PRG,
  suppress `/M`, and exit with failure.
- Verify internal metadata/source/byte replay disagreement is detected and
  reported distinctly.
- Verify VMM unavailable/allocation/transfer failures for each of the two
  listing stores independently.
- After each representative failure, run a known-good assembly in the same OS
  session to prove no stale handle, channel, frame, cursor, or VMM ownership
  remains.

### PRG and R6 Identity

- Compare PRG bytes and R6 relocation tables for representative static and
  relocatable programs across the full `/M`, `/L`, `/M /L`, no-option, `/S`,
  and `/O` matrix; every combination must be byte-identical to the equivalent
  Phase 9 baseline assembly.
- Confirm forward and backward symbol references, cross-boundary branches, and
  included/flattened equivalents remain unaffected.

## Harness and Build Verification

Build and run the complete Phase 10 harness set:

- `test_casm_listing`
- `test_casm_listcap`
- `test_casm_map`
- `test_casm_listwrite`
- `test_casm_phase10`

Also run existing lexer, parser, source, include, emission, symbol, relocation,
overflow, and diagnostic regressions affected by shared Phase 10 modules.

Use only CMake targets. Build narrow targets and `casm`, record size/envelope/
relocation measurements, then build `casm` again without changes and require
`BUILD_CASM` to remain stable. Build these images independently, not in
parallel:

- `image_d64`
- `test_image_d64`
- `casm_overflow_test_d64`
- `casm_include_test_d64`
- any Phase 10-specific fixture/image target introduced by WP51-WP54

Verify image contents, run `git diff --check`, and investigate every
unexpected artifact or generated-file change.

## VICE and User Walkthrough

All automated emulator work follows
`.agents/workflows/vice-mcp-testing.md`: boot Command64 first, prove its
banner, launch applications only from its shell, use bounded observations and
one clean recovery, require shell return, and classify product/harness/setup/
inconclusive failures from evidence. If the MCP is unavailable, the user
performs the same workflow in supported local VICE; no web emulator is
permitted.

The final walkthrough has four sessions:

1. Run all five Phase 10 harnesses and require complete pass text and shell
   return.
2. Assemble representative static and relocatable programs with no options,
   `/M`, `/L`, and `/M /L`; inspect native map/listing output on-device; load
   and run each generated PRG to confirm behavior is unaffected.
3. Exercise included sources under `/L`, confirming file-header transitions,
   parent-resume rows, and full filenames render correctly; confirm `/M /L`
   ordering (listing before map) and map suppression on listing failure.
4. Run representative naming, bound, and failure-injection cases (listing-name
   collision, records-full, bytes-full, create/write/close/delete failure),
   verifying valid-PRG retention and shell return after each, followed by a
   successful assembly without an OS reboot.

Record image, application, start evidence, assertions, shell-return evidence,
VICE information, checkpoints, recovery, and classification for each runtime
group.

## Atomic Increments

1. Persist this approved plan and activate WP55 in Taskwarrior,
   `wiki/tasks/casm.md`, `wiki/tasks/casm-phase10-symbol-map-listing.md`, and
   `brain/task.md`.
2. Reconcile the frozen baseline and produce the full-path review evidence.
3. Run static, narrow harness, regression, envelope, and artifact
   verification.
4. Run PRG/R6 identity, bounds, failure-injection, resource-reuse, image, and
   no-change-build verification.
5. Create
   `brain/walkthroughs/2026-07-29-casm-phase10-wp55-verification-walkthrough-completion-gate.md`
   and present the bounded runtime walkthrough.
6. After the user performs the walkthrough and explicitly approves WP55
   completion, apply the version-only `0.1.56` increment and verify stability.
7. After the user separately and explicitly approves Phase 10 completion,
   apply the completion-only `0.2.0` promotion, rebuild, and synchronize
   Taskwarrior, task/acceptance records, knowledge, memory, changelog,
   walkthrough, and applicable DOX files.

## Expected Files

| File | Planned action |
| --- | --- |
| This plan | Approved WP55 verification contract and progress |
| `brain/walkthroughs/2026-07-29-casm-phase10-wp55-verification-walkthrough-completion-gate.md` | Consolidated evidence and manual steps |
| `wiki/tasks/casm.md`, `wiki/tasks/casm-phase10-symbol-map-listing.md`, `brain/task.md` | Synchronized activation, acceptance, and closeout state |
| `brain/KNOWLEDGE.md`, `brain/MEMORY.md`, `CHANGELOG.md` | Durable verified result at closeout |
| Applicable `AGENTS.md`/DOX files | Only if the DOX pass identifies a changed durable contract |

No production, harness, fixture, or build-system change is expected beyond the
two completion-only version increments (`0.1.56`, then `0.2.0`).

## Stop Conditions

Stop, preserve evidence, perform root-cause analysis, amend this plan, and seek
renewed approval if any acceptance case fails; PRG bytes or relocation data
differ from baseline; Pass 2 performs source I/O or listing serialization
reparses/re-evaluates source; cleanup leaks a handle, channel, or VMM
allocation; a no-change build increments; an approved envelope is exceeded; an
artifact changes unexpectedly; an expected harness or fixture is absent;
documentation materially disagrees with behavior; the 4,096-line or
65,536-byte bounds cannot be checked before wraparound; safe listing cleanup
could delete a file CASM did not create; or verification requires any
production, harness, fixture, or build edit.

Leave WP55 active and Phase 10 incomplete while remediation is pending. Add
measurable subtasks and repeat affected checks plus regressions after an
approved fix.

## Documentation, Task, and DOX Updates

- Keep Taskwarrior, `wiki/tasks/casm.md`, `wiki/tasks/casm-phase10-symbol-map-listing.md`,
  and `brain/task.md` synchronized at activation, verification, and closeout.
- Record stable findings in `brain/KNOWLEDGE.md`, session state in
  `brain/MEMORY.md`, and reproducible evidence in the walkthrough.
- Update `CHANGELOG.md` only at user-approved Phase 10 closeout.
- Re-read every applicable DOX chain before edits and perform the required
  closeout pass. Change an `AGENTS.md` only when verification changes a
  durable contract; otherwise record that it was intentionally unchanged.

## Completion Gate

WP55 completes only after this approved plan's full static, build, artifact,
PRG/R6 identity, bounds, failure, resource, and runtime matrix passes; the
no-change build and all images are stable; the walkthrough contains
reproducible evidence; and the user completes the walkthrough and explicitly
approves marking WP55 complete at `0.1.56`.

Phase 10 completes only after WP55 completion and a separate, explicit user
approval of the `0.2.0` completion promotion, applied exactly as the parent
plan describes with no assembly-behavior change beyond CASM's own version/
build artifact effects.

## Progress

- 2026-07-29: User requested a detailed WP55 plan. Drafted and recorded this
  plan; WP55 remains blocked by WP54 pending approval.
- 2026-07-29: User approved this plan. WP55 remains blocked by WP54; no
  verification work is authorized until WP54 completes.
