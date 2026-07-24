---
feature: casm-phase7-wp32-prerequisite-reconciliation
created: 2026-07-23
status: planned
---

# Plan: CASM Phase 7 WP32 - Prerequisite Reconciliation and Phase 0C.10 Freeze

## Objective

WP32 is the first Phase 7 artifact, mirroring WP26's role for Phase 6B and
WP22's role for Phase 6A: it verifies the Phase 6B completion gate, reconciles
every dependency and discrepancy a fresh read of the current source turned up
against the master plan's Phase 7 text, and freezes the VMM-backed-source and
multi-file contract (Phase 0C.10) that WP33-WP36 implement against. It
implements no source, symbol, or CLI change; the only source change is the
version-only completion increment, exactly as WP22/WP26 did for their phases.

Taskwarrior: to be created by this WP. No Phase 7 Taskwarrior record exists
yet.

Prerequisite: CASM Phase 6B is complete and approved (CASM `0.1.33` build
1131, per `wiki/tasks/casm.md`'s Phase 6B Acceptance section and
`brain/plans/2026-07-23-casm-phase6-wp31-verification-closeout.md`).
Approval of this plan is required before activation or source edits, per the
CASM `AGENTS.md` gate.

## Baseline

- CASM `0.1.33` build 1131. `MAIN: start = $3400, size = $3000` (12288
  bytes). Measured directly via `ld65 -m` against the current
  `out_casm/*.o` set: CODE `$20A4` + RODATA `$090C` + BSS `$5EF` = 12191
  bytes used, **97 bytes headroom** -- unchanged since WP31's own
  measurement, confirming no source has moved since Phase 6B closed.
- Zero page `$70-$8F` is fully allocated (32/32 bytes); no bytes remain for
  any new persistent Phase 7 zero-page state. Any new transient scratch
  Phase 7 needs must reuse an existing aliased range (`CasmSourceScratch0/1`,
  `CasmPassScratch0-3`, etc.) within its own documented call-boundary
  discipline, exactly as every prior phase has.
- `CasmSourceFileId` (`state.s`) already exists as a persistent byte and
  already flows into `CasmLookaheadFileId` (`lexer.s:275-276`) and
  `CasmTokenRecord.FileId` (`CASM_TOKEN_REC_FILE_ID`, `common.inc`) -- but
  no code anywhere ever writes anything other than `$00` into it
  (`sourceResetTraversal`, `state.s`). This confirms the master plan's
  "every source location carries file identity ... from the start"
  foundational constraint was honored as a placeholder in Phase 3; Phase 7 is
  the first phase that needs to actually drive this field.
- `CasmDiagLoc*` (`state.s`) carries line, column, and byte, but no file
  identity. No diagnostic path prints a filename today; a fatal diagnostic's
  "AT LINE n COL c" trailer is unconditionally correct only because exactly
  one source file can exist per assembly today.

## Dependency Review and Discrepancies Reconciled

Direct research against the current source (not the master plan's
pre-Phase-3 description of it) found the following:

1. **The master plan's stated Phase 7 rationale is stale and does not
   describe a real problem in the current implementation.** Its bullets
   ("Extend the source backend to handle sources larger than the RAM
   window", "Use block VMM transfers rather than byte-at-a-time OS calls")
   describe a byte-at-a-time design that Phase 3 never built.
   `sourceFetchPhysical`/`sourceRefill` (`source.s:641-1021`) already stream
   the input in bounded 256-byte OS blocks (`inputStreamReadInto`) regardless
   of total file size, refilling `CasmIoBuffer` on demand; nothing about the
   traversal cursor depends on a file fitting in RAM. **A single file's
   effective size limit today is the 16-bit `CasmInputTotalLo/Hi` fetched-byte
   counter (`fileio.s`), which already overflows cleanly at 65535 bytes via
   `CASM_DIAG_SOURCE_OFFSET_OVERFLOW` -- there is no "larger than the RAM
   window" failure mode to fix.** This is the same class of correction WP26
   made to the master plan's "structured emission events" bullet: recorded
   here as a stale rationale, not implemented as written.
2. **The only confirmed, real gap is CLI-level: a second top-level source is
   hard-rejected today, not merely unsupported.** `cli.s`'s `cliCopySource`
   (`ccsExtra`, `cli.s:178-181`) raises `CASM_DIAG_EXTRA_SOURCE` the moment a
   second bare positional token appears. `CasmSourceName` (`cli.s:24`) is a
   single 64-byte buffer with no concept of an ordered list. This is Phase
   2's deliberate, documented scope ("Phase 2 accepts one unquoted source
   filename", `AGENTS.md`), not a bug -- but it is the actual, load-bearing
   blocker for "multiple top-level inputs", confirmed by direct inspection
   rather than assumed from the master plan's CLI grammar section.
3. **Given finding 1, the user was asked whether Phase 7 should still adopt a
   VMM-cached source model, since its originally stated rationale no longer
   applies.** The user confirmed **yes**, per the real remaining benefit: today
   `sourceRewind` (`source.s:556-596`) closes and reopens the file, forcing a
   second full physical read from the actual Command 64 storage device for
   every Pass 2 -- slow on real hardware/1541-equivalent emulation and, once
   multiple files exist, would require re-deriving multi-file traversal state
   twice per assembly. A VMM cache loaded once before Pass 1 makes Pass 2's
   rewind a pure VMM-offset reset with no OS calls at all, and gives multiple
   files one uniform, replayable stream. This is also the model Phase 9
   (include processing) will most naturally extend. **Resolved (Contract
   item 1 below): one pre-pass load stage populates a single VMM allocation
   from every input file in order; both passes read only from VMM.**
4. **A single `vmmStoreAlloc` request cannot actually reach the documented
   65536-byte cap.** `vmmStoreAlloc` (`vmm_store.s:54-62`) rejects a
   zero-size request before any OS call, and 65536 is not representable in a
   16-bit `X/Y` byte count (it wraps to `$0000`, indistinguishable from an
   explicit zero request). The largest requestable single allocation is
   therefore **65535** bytes, which internally rounds up to a full
   16-page/65536-byte grant (per `vmmStoreAlloc`'s own rounding comment) --
   the extra byte of granted-but-unrequestable space is not a defect, just
   unusable by this ABI. **Resolved (Contract item 2 below): combined
   multi-file source content is capped at 65535 bytes total**, which is not
   a new *tighter* constraint than today's single-file cap (`fileio.s`'s
   `CasmInputTotalLo/Hi` already overflows at the same 65535-byte boundary)
   -- it generalizes an existing limit to "combined across all files" rather
   than introducing a smaller one.
5. **`CASM_VMM_BUFFER_SIZE` (64 bytes) cannot grow to match `CasmIoBuffer`
   (256 bytes) without breaking an existing frozen invariant.**
   `CASM_VMM_BUFFER_SIZE` is asserted equal to `CASM_SYMBOL_REC_SIZE`
   (`common.inc:734`, WP27's frozen symbol-record contract) specifically so
   one symbol record fits one VMM transfer; growing it to 256 would either
   break that assert or force every symbol record to pad to 256 bytes,
   which would blow the existing "`CASM_SYMBOL_MAX * CASM_SYMBOL_REC_SIZE <=
   CASM_VMM_ALLOC_MAX_BYTES`" assert outright (512 * 256 = 131072 > 65536).
   **Resolved (Contract item 3 below): `sourceRefill`'s VMM-backed path
   fills the existing 256-byte `CasmIoBuffer` window with up to four
   sequential 64-byte `vmmWindowRead` calls, not a single larger transfer.**
   This keeps `CASM_VMM_BUFFER_SIZE`, the symbol-table contract, and every
   `CasmIoBuffer`-sized invariant in `sourceNextLine`'s LINE-mode payload
   logic (`CASM_SOURCE_LINE_PAYLOAD_MAX = 255`, the base-relative buffer
   partitioning) completely unchanged.
6. **Per the user's confirmed capacity decision, `CasmSourceNames` becomes
   an 8-slot array, not a dynamically sized list.** Matches this codebase's
   existing bounded-capacity convention (`CASM_FILE_CAPACITY = 8`,
   `CASM_VMM_CAPACITY = 8`) and keeps every filename slot the same
   `CASM_FILENAME_BUFFER_SIZE` (64 bytes) as today's single buffer, so
   `cliCopySource`'s per-character copy logic barely changes -- only its
   destination and its "already have one" rejection condition change. Cost:
   512 new BSS bytes (up from 64), on top of whatever the VMM-load rewrite
   itself costs, against 97 bytes of current headroom -- a MAIN size bump is
   a near-certainty, not sized here (matches the WP26/WP31 precedent of
   deferring exact sizing to the implementing WP).
7. **`fileOpenInput` already accepts an arbitrary filename pointer in `X/Y`;
   only `inputStreamOpen` hardcodes the single `CasmSourceName` buffer.**
   Confirmed by direct inspection (`fileio.s:108`, `:385-391`): `fileOpenInput`
   is already fully generic. The Phase 7 load loop can call it directly with
   `X/Y = &CasmSourceNames[i * CASM_FILENAME_BUFFER_SIZE]` for each file in
   turn, or `inputStreamOpen` can be generalized to take the same pointer
   parameter -- either is a small, contained change; no ABI redesign of the
   file layer is needed.
8. **No new diagnostic identifier is provably required.** Every failure mode
   Phase 7 introduces already has an existing, correctly-shaped diagnostic:
   a combined-source-size overflow reuses `CASM_DIAG_SOURCE_OFFSET_OVERFLOW`
   (already means "the 16-bit fetched-byte counter would overflow"; the
   combined VMM write offset is the same kind of checked 16-bit counter); a
   9th source token reuses `CASM_DIAG_EXTRA_SOURCE`, whose existing message
   text is **already plural and generic** -- `"CASM: TOO MANY SOURCE
   FILES"` (`diagnostics.s:1008`) -- confirmed by direct inspection, not
   assumed; and every VMM allocation/transfer/file-open/read/close failure
   during the load stage reuses the existing `CASM_DIAG_VMM_*` and
   `CASM_DIAG_INPUT_*` families unchanged. This is a genuine contrast with
   every prior phase (6A added 4, 6B added 4): **Phase 7 is not expected to
   need any new `CASM_DIAG_*` value**, only new call sites of existing ones.
   An implementing WP that finds a real gap during implementation amends
   this finding rather than inventing an ad hoc code silently.
9. **File-boundary provenance touches three separate write sites in
   `diagnostics.s`, and one of them has no file-identity source to copy
   from at all yet.** `diagSetLocFromLookahead` (`diagnostics.s:150-161`)
   and `diagSetLocFromToken` (`:174-183`) can copy `CasmLookaheadFileId` and
   `CasmTokenRecord + CASM_TOKEN_REC_FILE_ID` respectively -- both already
   exist. `diagSetLocFromStmt` (`:197-206`) copies from `CasmStmtLocLineLo/
   Hi/Column` (`state.s`), which has **no** file-identity field today;
   `parser.s`'s `diagStampStmtLoc` call site (`parser.s:81`) would need a
   new `CasmStmtLocFileId` cell to stamp, sourced from whatever the source
   layer's current file identity is at that point. Flagged for the
   implementing WP to trace precisely against the real call sequence rather
   than resolved here.
10. **Diagnostic screen width is already tight and was not designed with a
    filename in mind.** `CASM_DIAG_WINDOW_WIDTH = 38` plus
    `CASM_DIAG_INDENT = 2` already fills the 40-column screen exactly
    (`common.inc:589-590,630`). Printing a full 63-byte filename inline
    on every diagnostic is not viable. **Resolved (Contract item 5 below):**
    the filename trailer prints only when `CasmSourceCount > 1`; a
    single-file assembly's diagnostic text is therefore provably unchanged
    from today, which also directly serves the master plan's "small inputs
    remain byte-identical" gate wording (read as covering diagnostic text,
    not only PRG bytes, for the fixtures that exercise it).

## Contract to Freeze (Phase 0C.10)

Per the user's confirmed decisions (2026-07-23: VMM-cached whole-source load;
8-slot x 64-byte `CasmSourceNames`):

1. **One pre-pass load stage, run once after CLI parsing and before Pass 1,
   replaces today's single `sourceOpen` OS-level file open.** For each of
   `CasmSourceCount` (1..8) entries in `CasmSourceNames`, in order: open via
   `fileOpenInput` (Dependency Review item 7), stream the file in 256-byte
   `CasmIoBuffer` blocks via the existing `fileRead`, and `vmmWindowWrite`
   each block into one VMM allocation at the current running combined
   offset, checked against the 65535-byte combined cap
   (`CASM_DIAG_SOURCE_OFFSET_OVERFLOW`, reused per Dependency Review item 8).
   Close the file via `fileClose`/`inputStreamClose`'s existing pattern
   before opening the next. Exactly one file handle is ever open at a time
   during the load stage -- `CASM_FILE_CAPACITY = 8` is not stressed
   differently than today. Record each file's `{VmmOffsetLo/Hi,
   VmmLengthLo/Hi}` span (4 bytes/entry, new bounded base-RAM
   `CasmSourceFileTable`, 8 entries = 32 bytes) as it is written. If the
   just-finished file's last written byte was not already CR or LF, write
   one synthetic LF byte into the VMM stream before starting the next file
   (Dependency Review's "insert a logical newline between files" bullet) --
   this is an ordinary byte in the stream; no special-case detection is
   needed at *read* time, since `sourceFetchPhysical`'s existing CR/LF
   classification already treats it as a normal newline.
2. **The VMM allocation is sized to the combined cap up front, not grown
   incrementally.** One `vmmStoreAlloc` request for 65535 bytes (Dependency
   Review item 4) happens once, before the load loop begins iterating
   files; the load loop only ever writes within that single allocation and
   fails with the existing `CASM_DIAG_SOURCE_OFFSET_OVERFLOW` the moment a
   file's content would push the combined running offset past 65535. This
   mirrors the symbol table's existing "pre-allocate the full bound,
   regardless of actual usage" precedent (WP27) rather than inventing a
   grow-on-demand allocator.
3. **`sourceFetchPhysical`/`sourceRefill`'s OS-backed refill is replaced by
   a VMM-backed refill that fills the same 256-byte `CasmIoBuffer` window
   through up to four sequential 64-byte `vmmWindowRead` calls**
   (Dependency Review item 5), stopping early at the combined stream's
   recorded total length. `CasmSourceBlockLenLo/Hi`,
   `CasmSourceBlockIndexLo/Hi`, and every downstream byte-classification,
   newline-normalization, and LINE-mode payload-partitioning routine in
   `source.s` are **unchanged** -- only the refill's data source moves from
   `inputStreamReadInto` (OS call) to `vmmWindowRead` (REU transfer) against
   the one VMM allocation from Contract item 1. `sourceOpen` becomes "reset
   the traversal cursor and file-identity fields to the start of the loaded
   VMM stream" (no OS call); `sourceRewind` becomes textually the same
   operation (Contract item 4 makes them near-identical). Both retire their
   current `inputStreamOpen`/`inputStreamClose` calls entirely -- the
   loaded-source VMM allocation is opened once by the load stage and freed
   once at central cleanup (`resourcesCleanup` already frees every
   registered VMM slot generically; no new cleanup path is needed).
4. **File-identity and per-file line numbering reset at each recorded file
   boundary during refill, using `CasmSourceFileTable` from Contract item
   1.** When the VMM-backed refill's running combined read offset reaches
   `CasmSourceFileTable[fileId + 1].VmmOffset`, the traversal commits a file
   transition before classifying the next byte: `CasmSourceFileId`
   increments, `CasmSourceLineLo/Hi` resets to `CASM_SOURCE_LINE_INITIAL`
   (1), and `CasmSourceColumn` resets to `CASM_SOURCE_COLUMN_INITIAL` (1).
   The exact integration point against the existing pending-CR latch and
   16-bit line-overflow check in `sourceAdvanceNewline` (Dependency Review
   item 9's sibling concern) is left for the implementing WP to trace
   against the real call sequence, not resolved here.
5. **Diagnostic filename printing is confirmed-conditional on
   `CasmSourceCount > 1`** (Dependency Review item 10). A new
   `CasmStmtLocFileId` cell (parallel to `CasmStmtLocLineLo/Hi/Column`,
   `state.s`) is stamped by `diagStampStmtLoc` alongside its existing
   fields; `CasmDiagLoc*` gains a matching `CasmDiagLocFileId` byte,
   populated by all three of `diagSetLocFromLookahead`,
   `diagSetLocFromToken`, and `diagSetLocFromStmt` (Dependency Review item
   9). The fatal-diagnostic printer looks up the filename from
   `CasmSourceNames[CasmDiagLocFileId]` and prints it only when
   `CasmSourceCount > 1`; a single-file assembly's diagnostic output is
   therefore provably identical to today's, satisfying the master plan's
   gate wording literally for both PRG bytes and diagnostic text.
6. **`CASM_DIAG_EXTRA_SOURCE`'s existing message and diagnostic identity are
   reused unchanged for "9th source token rejected"** (Dependency Review
   item 8) -- no new diagnostic identifier, no message-table change.
7. **`CasmSourceNames` grows from one 64-byte buffer to an 8-slot array
   (`CasmSourceCount` tracks 1..8)**, per the user's confirmed capacity
   decision. `cliCopySource`'s rejection condition changes from "a source
   was already parsed" to "`CasmSourceCount` already equals 8"; its copy
   destination becomes `CasmSourceNames + (CasmSourceCount *
   CASM_FILENAME_BUFFER_SIZE)`. `cliDeriveOutputName` derives the default
   output name from `CasmSourceNames[0]` only, matching the master plan's
   "otherwise CASM derives the name from the first source file" CLI-grammar
   text, which Phase 2 already satisfies vacuously for the single-file case.
8. **No zero-page growth.** `$70-$8F` stays fully allocated; any new
   transient scratch the load stage needs during file-table bookkeeping
   reuses an existing aliased range within its own call-boundary discipline
   (most likely `CasmSourceScratch0/1` or `CasmPassScratch0-3`, whichever
   the implementing WP's actual register pressure favors -- not frozen
   further here).
9. **MAIN growth is not pre-sized.** Matches every prior phase's precedent
   (WP24, WP26 item 6, WP31): each implementing WP measures its own
   overflow against the 97-byte baseline headroom and proposes a justified
   `add_ca65_app` size bump.

## Scope

Included in WP32:

- verifying the Phase 6B gate (done above);
- creating the CASM Phase 7 Taskwarrior milestone and WP32-WP36 child tasks
  in `wiki/tasks/casm.md` and `brain/task.md`;
- recording the Phase 0C.10 contract above in `brain/KNOWLEDGE.md`;
- the version-only completion increment.

Excluded from WP32 (each requires its own dedicated plan per AGENTS.md):

- any `source.s`, `cli.s`, `state.s`, `diagnostics.s`, or `casm.s` change
  implementing the load stage, VMM-backed refill, multi-file CLI parsing, or
  file-identity provenance;
- any `common.inc` constant/record addition (`CASM_SOURCE_COUNT_MAX`,
  `CasmSourceFileTable` layout, `CasmStmtLocFileId`/`CasmDiagLocFileId`);
- any MAIN envelope size change;
- any fixture or test harness.

Proposed WP breakdown for the implementing packages (subject to each
package's own approval, not authorized by this document):

- **WP33**: VMM-backed single-file load and traversal equivalence --
  Contract items 1-3, proven byte-identical against every existing
  single-file trusted-reference fixture before the old OS-refill path is
  removed (matches the master plan's "demonstrate equivalent output ...
  before retiring any redundant backend" gate wording exactly).
- **WP34**: Multi-file CLI and file-boundary provenance -- Contract items 4,
  6, 7 (`CasmSourceNames` array, file-table boundary transitions, synthetic
  inter-file newline).
- **WP35**: Diagnostic filename integration -- Contract item 5
  (`CasmStmtLocFileId`/`CasmDiagLocFileId`, conditional filename printing).
- **WP36**: Verification, walkthrough, and Phase 7 completion gate (mirrors
  WP25/WP31's role).

## Expected Files

| File | Action |
| --- | --- |
| `brain/plans/2026-07-23-casm-phase7-wp32-prerequisite-reconciliation.md` | this document |
| `wiki/tasks/casm.md` | add CASM Phase 7 milestone and WP32-WP36 child tasks |
| `brain/task.md` | synchronize active work |
| `brain/KNOWLEDGE.md` | add "CASM Phase 7 VMM-Backed Source and Multi-File Contract (Phase 0C.10, frozen 2026-07-23)" section |
| `src/external/casm/casm.s` | version-only stage increment at completion |
| `src/external/casm/BUILD_CASM` | build-managed increment |

No source file implementing the load stage, multi-file CLI, or provenance
tracking is authorized by approval of this document alone; WP33-WP36 each
require their own dedicated plan and approval.

## ABI, Storage, and Runtime Effects

None from WP32 itself. This document freezes the ABI/storage effects that
WP33 (`CasmSourceFileTable`, VMM-backed refill, `sourceOpen`/`sourceRewind`
simplification), WP34 (`CasmSourceNames` array growth, `CasmSourceCount`),
and WP35 (`CasmStmtLocFileId`, `CasmDiagLocFileId`) will implement.

## Verification and Fixture Strategy (binding on WP33-WP36)

- WP33 fixtures: every existing single-file trusted-reference fixture
  (`casmemit1`, `casmhello`, `casmmodes`, `casmnum2`, `casmexprn`, `p1fwd1`,
  `p1back1`, `p1size1`, `brfwd1`, `brback1`, `casmcase1`, `casmmaxid1`, plus
  the targeted Phase 3/4 regression sample WP31 already established) re-run
  unmodified against the new VMM-backed source path and confirmed
  byte-identical to their existing trusted references, before the old
  OS-refill path is deleted -- not kept as dead code.
- WP34 fixtures: new multi-file fixtures (two and three ordered `.seq`
  inputs, including a case where an inter-file synthetic newline is
  required and a case where it is not) proving symbol references resolve
  correctly across a file boundary and combined line/file numbering is
  correct on both sides of the boundary.
- WP35 fixtures: a diagnostic deliberately raised in the second file of a
  multi-file assembly, confirming the printed filename and line/column
  match the failing file, not the first one; a single-file diagnostic
  fixture re-run to confirm its text is byte-identical to its pre-Phase-7
  form.
- WP36 bundles the full matrix into the CASM Phase 7 completion gate,
  matching the master plan's Phase 7 gate text exactly: "small inputs
  remain byte-identical, while large and multiple inputs assemble
  successfully with correct diagnostics."

## Atomic Implementation Increments

1. After this plan's approval, create the CASM Phase 7 Taskwarrior milestone
   and WP32-WP36 child tasks (via the `task` CLI directly if the Task
   Warrior MCP remains unavailable this session, recording the same
   information in `wiki/tasks/casm.md`/`brain/task.md` regardless).
2. Record the Phase 0C.10 contract in `brain/KNOWLEDGE.md`, cross-referencing
   this plan.
3. Update `wiki/tasks/casm.md`'s CASM Phase 7 section with the WP32-WP36
   breakdown and mark WP32 in progress, then complete.
4. Apply the version-only completion increment (stage bump only, matching
   every prior freeze WP), rebuild, confirm a no-change rebuild holds
   stable, and request completion approval.

## Failure and Cleanup

Not applicable: WP32 implements no runtime behavior. A material deviation
found after this plan's approval (e.g., a frozen decision proving
unworkable once WP33 starts writing real code) stops implementation until
this document is amended and re-approved, per every prior CASM phase's
precedent.

## Documentation and DOX Closeout

Update this plan, `brain/KNOWLEDGE.md`, `brain/task.md`, `wiki/tasks/casm.md`,
`CHANGELOG.md`, and Taskwarrior. `AGENTS.md` is not expected to change by
WP32 itself; it will need a real update once WP34 lands the multi-file CLI
grammar, since `AGENTS.md` currently documents "Phase 2 accepts one
unquoted source filename" as a durable local contract.

## Stop Conditions

Stop if CASM Phase 6B is not complete and approved. Stop if a further
material discrepancy against this freeze is found during WP33-WP36
implementation, requiring this document to be amended and re-approved.

## Completion Gate

WP32 is complete when the Phase 0C.10 contract above is recorded in
`brain/KNOWLEDGE.md`, the CASM Phase 7 Taskwarrior milestone and WP32-WP36
child tasks exist, the version-only increment is verified, and the user
explicitly approves. This does not activate WP33; each remains separately
gated per AGENTS.md.

## Progress

- 2026-07-23: Drafted after confirming CASM Phase 6B's completion gate
  (`0.1.33` build 1131, 97 bytes MAIN headroom, confirmed via direct `ld65
  -m` measurement matching WP31's own figure exactly) and performing fresh
  dependency research against the current `source.s`/`vmm_store.s`/`cli.s`/
  `casm.s`/`state.s`/`fileio.s`/`resources.s`/`common.inc`/`diagnostics.s`
  rather than the master plan's pre-Phase-3 description of Phase 7. Found
  that the master plan's stated Phase 7 rationale ("sources larger than the
  RAM window", "byte-at-a-time OS calls") no longer describes a real
  problem -- the existing 256-byte block-streaming refill already handles
  arbitrarily large single files -- and that the only confirmed hard gap is
  CLI-level (`cliCopySource` hard-rejects a second source token). Asked the
  user two architectural questions given that finding: whether to still
  build the VMM-cached source model despite its original rationale being
  stale (recommended yes, for the real remaining benefit of eliminating
  Pass 2's forced second physical disk read and giving multiple files one
  uniform replayable stream), and what capacity to freeze for
  `CasmSourceNames` (recommended 8 slots x 64 bytes, matching this
  codebase's existing `CASM_FILE_CAPACITY`/`CASM_VMM_CAPACITY = 8`
  convention). Both of the user's confirmed decisions matched the
  recommended options. Also found, by direct inspection rather than
  assumption: a single `vmmStoreAlloc` request cannot actually reach the
  documented 65536-byte cap (65535 is the true requestable maximum);
  `CASM_VMM_BUFFER_SIZE` cannot grow past 64 bytes without breaking the
  frozen symbol-record contract, so VMM-backed refill must fill
  `CasmIoBuffer` through up to four 64-byte transfers rather than one larger
  one; `CasmSourceFileId` and `CasmTokenRecord.FileId` already exist as
  unused placeholders from Phase 3, confirming the master plan's
  file-identity-from-the-start constraint was honored ahead of need; and
  `CASM_DIAG_EXTRA_SOURCE`'s existing message text is already plural and
  reusable verbatim, so Phase 7 is not expected to need any new diagnostic
  identifier at all -- a contrast with every prior phase. Awaiting user
  approval before Taskwarrior creation or `brain/KNOWLEDGE.md` updates -- no
  source has been touched.
