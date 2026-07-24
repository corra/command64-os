---
feature: casm-phase7-wp34-multi-file-cli-and-provenance
created: 2026-07-24
status: planned
---

# Plan: CASM Phase 7 WP34 - Multi-File CLI and File-Boundary Provenance

## Objective

Implement Contract items 4, 6, and 7 of the Phase 0C.10 freeze
(`brain/plans/2026-07-23-casm-phase7-wp32-prerequisite-reconciliation.md`):
accept an ordered list of up to 8 top-level source filenames on the CLI,
load them all into one combined VMM stream (extending WP33's single-file
`sourceLoad`), and correctly reset file identity and per-file line
numbering at each file boundary during traversal. Diagnostic filename
printing (Contract item 5) remains WP35's job -- WP34 only needs
`CasmSourceFileId`/line/column to be *correct* across boundaries, not yet
*visible* in a diagnostic.

Taskwarrior: to be created after this plan's approval, mirroring WP33's
child-task creation under the CASM Phase 7 milestone
(`1a0d0dc8-3267-4885-aa83-adf923d56422`).

Prerequisite: CASM Phase 7 WP33 is complete and approved (CASM `0.1.35`
build 1137, single-file `sourceLoad`/VMM-backed `sourceRefill` shipped).
Approval of this plan is required before activation or source edits, per
the CASM `AGENTS.md` gate. Active on `feature/casm-phase7-wp34` from
`feature/casm-phase7-wp33`'s tip (`73af6e8`).

## Baseline

- CASM `0.1.35` build 1137. `MAIN: start = $3400, size = $3200` (12800
  bytes). Measured via `ld65 -m`: CODE `$21EF` (8687) + RODATA `$090C`
  (2316) + BSS `$5F4` (1524) = 12527 of 12800 bytes -- **273 bytes
  headroom**.
- Zero page `$70-$8F` fully allocated; WP34 needs no new zero-page cell
  (Dependency Review item 6 below).
- `cli.s`'s `CasmSourceName`/`CasmSourceLen` are still the single-buffer
  pair `cliCopySource`'s `ccsExtra` path hard-rejects a second token
  against, unchanged since Phase 2 -- confirmed still true by direct
  re-inspection, not assumed from WP32's earlier research.
- `source.s`'s `sourceLoad` (WP33) opens exactly `CasmSourceName`, single
  file, no loop, no file table. `sourceFetchPhysical`,
  `sourceAdvanceNewline`, and every other traversal routine are unchanged
  from Phase 3/5 and remain untouched by this WP too, except where this
  plan explicitly says otherwise (Contract items 3-4 below).

## Dependency Review and Discrepancies Reconciled

Direct tracing of the current `cli.s`/`source.s` against the Phase 0C.10
contract found the following, beyond what WP32's own review already
covered:

1. **`CasmSourceLen`'s only remaining purpose after WP34 is the
   "already have N" capacity gate; every other use is replaceable.**
   Confirmed by direct inspection (`cli.s`): it is read at
   `cliCopySource`'s entry (`ccsExtra` gate), written once at the end of a
   successful copy, and read again by `cliDeriveOutputName`'s
   character-copy loop bound and by `cliParse`'s `cpFinish` "was a source
   given" check. All four uses translate directly to a per-slot analog
   (`CasmSourceCount` for the first and last, a per-slot length array for
   the middle two) with no structural rework of any of the three routines'
   surrounding logic.
2. **A minimal-diff choice: keep a per-slot length array
   (`CasmSourceLens`) rather than rewriting `cliDeriveOutputName` to
   rescan for a null terminator.** Both are correct (every name is already
   null-terminated); the array costs 8 more BSS bytes but leaves
   `cliDeriveOutputName`'s existing column-scanning algorithm (which
   already tracks the last extension-dot index and device-prefix colon
   while copying) completely unchanged in shape -- only its two operand
   names change (`CasmSourceName` -> `CasmSourceNames`, `CasmSourceLen` ->
   `CasmSourceLens + 0`, always slot 0). Given WP34 already touches a lot
   of code in `source.s`, minimizing incidental rework in `cli.s` is
   worth 8 bytes.
3. **`CasmSourceFileTable` only needs to record each file's *start*
   offset, not its length.** A file's end is implicitly the next file's
   start (or, for the last file, `CasmSourceLoadedLenLo/Hi`, the grand
   total WP33 already produces) -- confirmed by tracing exactly what the
   boundary check in `sourceRefill` actually needs (Contract item 4).
   This halves the table from the 4-bytes/entry the earlier informal
   sketch assumed to **2 bytes/entry, 16 bytes total** for 8 entries.
4. **A single-file assembly (`CasmSourceCount == 1`) must take an
   identical code path through `sourceRefill` to WP33's, not merely
   produce identical output.** The boundary check Contract item 4 adds is
   gated on `CasmSourceFileId + 1 < CasmSourceCount`; when `CasmSourceCount
   == 1` this condition is false on every call, so the new comparison
   executes but the boundary-handling code it guards never runs -- the
   3-way `min` in `srComputeRemaining` degrades exactly to WP33's existing
   2-way `min` (the added `untilBoundary` term is simply never computed).
   This is not a new equivalence proof WP34 needs to run standalone
   fixtures for: it falls out of the gating condition rather than being a
   separate code path, so WP33's own regression fixtures re-passing (part
   of this WP's own verification matrix) already cover it.
5. **A real, non-obvious correctness hazard: the pending-CR latch must not
   survive a file boundary.** `CasmSourcePendingCr` exists specifically so
   a CR/LF pair split across a *block* refill still collapses into one
   newline. Left unguarded, the same latch would incorrectly collapse a
   file N trailing bare CR with a file N+1 leading LF into one phantom
   newline spanning two unrelated files, silently swallowing file N+1's
   first byte. **Resolved (user-confirmed, Contract item 4 below): clear
   `CasmSourcePendingCr` unconditionally at every file-boundary
   transition**, guaranteeing file N+1 always starts completely fresh
   regardless of how file N's content ended.
6. **No new zero-page cell is needed.** The file-boundary comparison
   indexes `CasmSourceFileTable` by `CasmSourceFileId` (a runtime 0..7
   value) using ordinary `A`/`X` register indexing
   (`CasmSourceFileTable, x` with `x = CasmSourceFileId * 2`); the 3-way
   `min` in `srComputeRemaining` reuses `CasmValue0Lo/Hi`, already used
   transiently for the same purpose in WP33's 2-way `min`. The synthetic
   inter-file newline write reuses the same `CasmVmmBuffer`/
   `CasmVmmOffLo/Hi` staging cells every other VMM transfer already uses.
7. **The combined 65535-byte cap is genuinely *not* inherited for free
   once more than one file exists**, correcting the scope of WP32's own
   finding. WP33's Dependency Review item 2 found the cap came free from
   `inputStreamReadInto`'s `CasmInputTotalLo/Hi` check -- true only because
   that counter is per-file (`inputStreamOpen` resets it for every file
   `sourceLoad` opens). Once `sourceLoad` loops over more than one file,
   each file's own bytes pass that per-file check independently even
   though their *combined* total could exceed 65535. **A new explicit
   check against `CasmSourceVmmCursorLo/Hi` (the combined write cursor,
   never reset between files) is required**, reusing
   `CASM_DIAG_SOURCE_OFFSET_OVERFLOW` per WP32's Contract item 8 (same
   diagnostic identifier, but a genuinely new call site, not a free
   inheritance the way WP33's single-file case was).
8. **`test_casm_pass1`/`test_casm_passcheck` are unaffected.** Both open
   fixtures directly by name via their own local `CasmSourceName` buffer
   (declared in `casm_pass1.s` itself, not linking `cli.s` at all, per
   that harness's own header comment) and call `sourceLoad` once per
   fixture -- `sourceLoad`'s post-WP34 signature (looping over
   `CasmSourceNames`/`CasmSourceCount` from `cli.s`) would break this,
   since the harness never populates those cli.s-owned globals at all.
   **This is a real, confirmed integration point WP34 must not overlook**:
   either the harness gains its own `CasmSourceNames`/`CasmSourceCount`
   population (setting `CasmSourceCount = 1` and copying into slot 0
   instead of the old single buffer), or `sourceLoad` needs a
   single-file-compatible calling convention preserved for exactly this
   caller. Resolved below (Contract item 7).

## Contract to Freeze/Amend (Phase 0C.12)

Per the user's confirmed decision (2026-07-24: clear the pending-CR latch
at file boundaries):

1. **`CASM_SOURCE_COUNT_MAX = 8`, a new `common.inc` constant.**
   `CasmSourceNames` (`cli.s`) grows from one `CASM_FILENAME_BUFFER_SIZE`
   (64-byte) buffer to `CASM_SOURCE_COUNT_MAX * CASM_FILENAME_BUFFER_SIZE`
   (512 bytes); `CasmSourceLens: .res CASM_SOURCE_COUNT_MAX` (8 bytes,
   Dependency Review item 2) replaces `CasmSourceLen`; `CasmSourceCount:
   .res 1` (0..8) replaces its role as the "how many so far" counter.
   `cliInit` zeroes all 512 + 8 + 1 bytes.
2. **`cliCopySource`'s capacity gate becomes `CasmSourceCount ==
   CASM_SOURCE_COUNT_MAX`** (was: `CasmSourceLen != 0`), reusing
   `CASM_DIAG_EXTRA_SOURCE` unchanged -- its existing message text ("CASM:
   TOO MANY SOURCE FILES") is already plural and correct for this case,
   confirmed by WP32's Dependency Review item 8. On a successful copy, the
   destination becomes `CasmSourceNames + (CasmSourceCount *
   CASM_FILENAME_BUFFER_SIZE)`; the final length is stored into
   `CasmSourceLens + CasmSourceCount`; `CasmSourceCount` increments.
   `cliParse`'s `cpFinish` "was a source given" check becomes `lda
   CasmSourceCount / beq cpSourceRequired` (was `CasmSourceLen`).
3. **`cliDeriveOutputName` derives from slot 0 only**
   (`CasmSourceNames + 0`, `CasmSourceLens + 0`), matching the master
   plan's "otherwise CASM derives the name from the first source file"
   CLI-grammar text; its "was a source given" check becomes `lda
   CasmSourceCount / beq cdonSourceRequired`. No other change to its
   existing column-scanning algorithm (Dependency Review item 2).
4. **`sourceLoad` becomes an outer loop over `CasmSourceLoadIndex = 0 ..
   CasmSourceCount - 1`, wrapping WP33's existing per-file inner logic
   unchanged.** A new private `CasmSourceLoadIndex: .res 1` (source.s's
   own BSS, alongside the WP33 block) is sourceLoad's own loop counter --
   deliberately *not* reusing `CasmSourceFileId` (which is
   traversal-owned and already correctly reset to 0 by every
   `sourceResetTraversal` call), to avoid any ambiguity between "which
   file is being loaded" and "which file is being traversed" even though
   their reset timing would technically make aliasing safe. For each file
   index `i`:
   - Record `CasmSourceFileTable[i] = CasmSourceVmmCursorLo/Hi` (this
     file's start offset in the combined stream) *before* opening it.
   - `inputStreamOpen` on `CasmSourceNames + (i * CASM_FILENAME_BUFFER_SIZE)`
     (generalizing WP33's hardcoded `CasmSourceName`).
   - Stream the file exactly as WP33's existing inner read/write-chunk
     loop already does, with two additions to that loop's per-chunk
     tail: (a) before advancing `CasmSourceVmmCursorLo/Hi`, verify the
     advance would not exceed `CASM_SOURCE_VMM_MAX_BYTES` (65535) --
     fail with `CASM_DIAG_SOURCE_OFFSET_OVERFLOW` if it would (Dependency
     Review item 7); (b) record the chunk's last byte into a new private
     `CasmSourceLoadLastByte: .res 1` (source.s BSS).
   - `inputStreamClose`.
   - **If `i < CasmSourceCount - 1`** (not the last file) **and
     `CasmSourceLoadLastByte` is neither CR nor LF**, write one synthetic
     LF byte at the current combined cursor via a new private helper
     `slWriteByte` (factors out the existing "stage one chunk into
     `CasmVmmBuffer`, `vmmWindowWrite`, advance cursor" sequence so the
     main chunk loop and this single-byte case share it rather than
     duplicating the staging logic), itself subject to the same
     65535-byte cap check.
   - `CasmSourceLoadedLenLo/Hi` is set to the final combined cursor value
     after the last file, exactly as WP33's existing tail already does.
5. **`sourceRefill` gains a file-boundary check at its very top, before
   any other computation.** If `CasmSourceFileId + 1 < CasmSourceCount`
   and `CasmSourceVmmCursorLo/Hi == CasmSourceFileTable[CasmSourceFileId +
   1]` (indexed via `A`/`X`, Dependency Review item 6): increment
   `CasmSourceFileId`, reset `CasmSourceLineLo/Hi` to
   `CASM_SOURCE_LINE_INITIAL` (1), reset `CasmSourceColumn` to
   `CASM_SOURCE_COLUMN_INITIAL` (1), and clear `CasmSourcePendingCr`
   (Dependency Review item 5) -- *before* proceeding with the normal
   `requestLen`/`transferLen` computation, which now correctly pulls from
   the new file's content. `srComputeRemaining`'s existing 2-way `min`
   (`requestLen` vs. `remaining`-in-total) becomes a 3-way `min` that also
   caps `transferLen` at `CasmSourceFileTable[CasmSourceFileId + 1] -
   CasmSourceVmmCursorLo/Hi` whenever a next file exists, so no single
   installed block ever spans two files -- this is what makes the
   top-of-routine check sufficient: a boundary is always crossed exactly
   at the start of some future `sourceRefill` call, never mid-block.
   Gated correctly for the single-file case (Dependency Review item 4).
6. **`test_casm_pass1`/`test_casm_passcheck` are updated to populate
   `CasmSourceNames`/`CasmSourceCount` instead of the retired single
   buffer**, since `sourceLoad`'s signature changes underneath them
   (Dependency Review item 8). `casm_pass1.s`'s two driver routines
   (`runMeasurePass`, the `p1dup1` custom driver) copy their fixture name
   into `CasmSourceNames + 0` and set `CasmSourceCount = 1` instead of
   copying into the old `CasmSourceName`. `casm_passcheck.s` needs no
   change (confirmed in WP33: it never calls `sourceOpen`/`sourceLoad` at
   all).
7. **No new `CASM_DIAG_*` identifier.** The combined-overflow case reuses
   `CASM_DIAG_SOURCE_OFFSET_OVERFLOW`; the 9th-source case reuses
   `CASM_DIAG_EXTRA_SOURCE`. Matches WP32's own finding that Phase 7 needs
   no new diagnostic identifiers, now confirmed true for WP34 specifically
   too (WP33 already confirmed it for the single-file load itself).
8. **MAIN growth is not pre-sized**, per every prior WP's precedent, but
   is flagged here as a near-certainty *larger* than WP33's 512-byte bump:
   `CasmSourceNames` alone grows by 448 bytes, plus `CasmSourceLens` (8),
   `CasmSourceFileTable` (16), `CasmSourceLoadIndex`/`CasmSourceLoadLastByte`
   (2) -- roughly 474 bytes of new BSS before any new CODE for the
   loop/boundary-check/overflow-check/synthetic-newline logic is counted.
   Measured once written, against the current 273-byte headroom.

## Scope

Included in WP34:

- `common.inc`: `CASM_SOURCE_COUNT_MAX = 8`.
- `cli.s`: `CasmSourceNames`/`CasmSourceLens`/`CasmSourceCount` replacing
  `CasmSourceName`/`CasmSourceLen`; `cliCopySource`, `cliDeriveOutputName`,
  `cliParse`'s `cpFinish`, and `cliInit` updated accordingly.
- `source.s`: `sourceLoad` restructured into a multi-file loop;
  `sourceRefill` gains the file-boundary check and 3-way `min`; new
  private `slWriteByte` helper; new BSS (`CasmSourceFileTable`,
  `CasmSourceLoadIndex`, `CasmSourceLoadLastByte`); `sourceInit` extended
  to zero the new cells.
- `tests/src/casm_pass1/casm_pass1.s`: both driver routines updated to
  populate `CasmSourceNames`/`CasmSourceCount` instead of the retired
  single buffer.
- New multi-file fixtures and trusted references through real `casm.s`
  (Verification Plan below).

Excluded from WP34 (each is a later, separately-gated package):

- `CasmStmtLocFileId`/`CasmDiagLocFileId`, diagnostic filename printing
  (WP35).
- Any MAIN envelope size change beyond what this WP's own measurement
  justifies.

## Expected Files

| File | Action |
| --- | --- |
| `brain/plans/2026-07-24-casm-phase7-wp34-multi-file-cli-and-provenance.md` | this document |
| `src/external/casm/common.inc` | Modify: `CASM_SOURCE_COUNT_MAX` |
| `src/external/casm/cli.s` | Modify: multi-slot source name storage and parsing |
| `src/external/casm/source.s` | Modify: multi-file `sourceLoad`, boundary-aware `sourceRefill`, new BSS |
| `src/external/casm/casm.s` | Modify: version-only stage increment at completion |
| `src/external/casm/BUILD_CASM` | build-managed increment |
| `tests/src/casm_pass1/casm_pass1.s` | Modify: populate `CasmSourceNames`/`CasmSourceCount` |
| `cmake/GenerateCasmTestFixtures.cmake` | Modify: new multi-file fixtures |
| `tests/fixtures/casm/*.ref.hex` | Create: trusted references for the new byte-identical multi-file fixtures |
| `CMakeLists.txt` | Modify: `CASM_REF_NAMES`/`CASM_TEST_FIXTURES`, MAIN size |
| `wiki/tasks/casm.md`, `brain/task.md`, `brain/KNOWLEDGE.md`, `CHANGELOG.md` | Closeout updates |

## ABI, Storage, and Runtime Effects

- `cli.s` exports `CasmSourceNames`/`CasmSourceLens`/`CasmSourceCount`
  replacing `CasmSourceName`/`CasmSourceLen`. Any importer of the retired
  names (currently only `source.s` and `fileio.s`'s `outputAbort`
  reference via `CasmOutputName`, which is unaffected -- `CasmSourceName`
  itself is imported only by `source.s`) must update.
- New private `source.s` state: `CasmSourceFileTable` (16 bytes),
  `CasmSourceLoadIndex`, `CasmSourceLoadLastByte` (1 byte each).
- `CasmSourceFileId`'s write site changes: previously only ever `0` (via
  `sourceResetTraversal`), now also incremented by `sourceRefill`'s new
  boundary check during traversal of a multi-file source.
- MAIN size: not pre-sized here; a larger bump than WP33's is expected
  (Contract item 8).

## Verification Plan

1. **Two-file happy path, no synthetic newline needed**: file A's content
   already ends in a real newline; a label defined in file A is
   referenced in file B (and vice versa in a second variant), proving
   cross-file symbol resolution and correct combined addressing through
   real `casm.s`. Byte-identical trusted reference.
2. **Two-file happy path, synthetic newline required**: file A's last
   line has no trailing newline; confirm the synthetic LF is inserted
   (file B's first statement is not silently concatenated onto file A's
   last line) and the output still matches a trusted reference computed
   with that synthetic newline accounted for.
3. **Three-file case**: proves the loop generalizes past exactly two
   files, not just `N=1 -> N=2`.
4. **Cross-file pending-CR edge case** (Dependency Review item 5): file A
   ends in a bare CR, file B starts with LF; confirm file B's first byte
   survives (is not swallowed by a phantom cross-file CRLF collapse).
5. **9th source file rejected**: `CASM A.S B.S C.S D.S E.S F.S G.S H.S
   I.S` -> `CASM_DIAG_EXTRA_SOURCE` (reused, unchanged message).
6. **Combined-overflow boundary**: two large filler files (cheap
   `string(REPEAT ...)` content, matching `casm256`/`casmmulti`'s
   precedent) whose combined size exceeds 65535 bytes ->
   `CASM_DIAG_SOURCE_OFFSET_OVERFLOW`, firing during the load phase
   itself (before any lexing), confirmed to fire before any
   lexer-level diagnostic would even be reached.
7. **Regression**: `test_casm_pass1` (all 7 sub-fixtures, now driven
   through the updated `CasmSourceNames`/`CasmSourceCount` population) and
   `test_casm_passcheck`; every existing single-file `CASM_REF_NAMES`
   trusted reference (12 total, unaffected single-file path via the
   `CasmSourceCount == 1` gating, Dependency Review item 4).
8. Build both relocation bases and `test_image_d64`; confirm a no-change
   rebuild holds `BUILD_CASM` stable before any source edit and increments
   exactly once after.
9. Every failing case is investigated before completion is requested. A
   newly-discovered defect is presented to the user with its root cause
   and a proposed fix before any source is touched, matching WP30/WP33's
   precedent.

## Atomic Implementation Increments

1. Add `CASM_SOURCE_COUNT_MAX` to `common.inc`.
2. Rework `cli.s`: `CasmSourceNames`/`CasmSourceLens`/`CasmSourceCount`,
   `cliInit`, `cliCopySource`, `cliDeriveOutputName`, `cliParse`'s
   `cpFinish`.
3. Update `tests/src/casm_pass1/casm_pass1.s`'s two driver routines to
   populate the new `cli.s`-owned globals.
4. Rework `source.s`: multi-file `sourceLoad` loop, `slWriteByte` helper,
   combined-overflow check, synthetic-newline insertion, new BSS.
5. Add the file-boundary check and 3-way `min` to `sourceRefill`.
6. Add the new multi-file fixtures and trusted references; wire into
   `CMakeLists.txt`.
7. Build `casm`, `test_casm_pass1`, `test_casm_passcheck`, and
   `test_image_d64`; run the full verification matrix in VICE (ask the
   user); investigate and resolve any failure per the Stop Conditions
   below before proceeding.
8. Measure MAIN headroom via `ld65 -m`; propose a justified size bump.
9. Apply the version-only completion increment; confirm no-change rebuild
   stability; update `wiki/tasks/casm.md`, `brain/task.md`,
   `brain/KNOWLEDGE.md` (Phase 0C.12 as-built record), `CHANGELOG.md`,
   Taskwarrior; draft the walkthrough and request completion approval.

## Failure and Cleanup

A newly-discovered defect during verification is handled exactly as
WP30/WP33's precedent: presented to the user with root cause and a
proposed fix before any change, applied only with explicit approval,
scoped as narrowly as the defect allows. No new runtime cleanup path is
introduced: every VMM allocation and file handle this WP touches already
flows through the existing generic `resourcesCleanup` sweep and
`fileOpenInput`/`inputStreamClose` registration/release contract,
unchanged.

## Documentation and DOX Closeout

Update this plan, `brain/KNOWLEDGE.md` (new Phase 0C.12 as-built section
amending Phase 0C.10/0C.11 with the exact implemented shape),
`brain/task.md`, `wiki/tasks/casm.md`, `CHANGELOG.md`, Taskwarrior, and a
new walkthrough. `AGENTS.md` needs a real update this time: it currently
documents "Phase 2 accepts one unquoted source filename" as a durable
local contract, which WP34 directly supersedes.

## Stop Conditions

Stop if CASM Phase 7 WP33 is not complete and approved. Stop if any
fixture reveals a defect whose scope or fix is not small and
well-understood enough for the user to approve fixing in place. Stop if a
further material discrepancy against this freeze is found during
implementation, requiring this document to be amended and re-approved.

## Completion Gate

WP34 is complete when: the full verification matrix above passes; MAIN
headroom is measured and any needed size bump is applied and justified; a
no-change rebuild holds `BUILD_CASM` stable; both `image_d64` and
`test_image_d64` build clean; `AGENTS.md`'s single-source-filename
contract is corrected; and the user explicitly approves the walkthrough.
This closes WP34 but does not activate WP35, which remains separately
gated per `AGENTS.md`.

## Progress

- 2026-07-24: Drafted after confirming CASM Phase 7 WP33's completion gate
  (`0.1.35` build 1137). Traced the current `cli.s`/`source.s` in detail
  rather than re-describing WP32's freeze at a summary level, and found:
  `CasmSourceFileTable` only needs each file's start offset, not a
  separate length, halving its size from the informal 4-bytes/entry
  sketch to 2; the combined 65535-byte overflow cap is genuinely not
  inherited for free once more than one file exists (correcting the scope
  of WP33's own "free" finding, which was specific to `N=1`);
  `test_casm_pass1` will break under `sourceLoad`'s new signature unless
  its own driver routines are updated to populate
  `CasmSourceNames`/`CasmSourceCount`, since it never links `cli.s` at
  all; and a single-file assembly's `sourceRefill` path degrades exactly
  to WP33's existing 2-way `min` under the new gating condition, so no
  separate single-file equivalence fixture is needed beyond WP33's own
  regression set re-passing. Found a real, non-obvious correctness hazard
  before writing any code: the pending-CR latch could carry across a file
  boundary and silently swallow a neighboring file's first byte in a rare
  bare-CR-then-LF case. Asked the user whether to guard against it; the
  recommended fix (clear the latch at every file-boundary transition) was
  confirmed. Created `feature/casm-phase7-wp34` from
  `feature/casm-phase7-wp33`'s tip (`73af6e8`). Awaiting user approval
  before Taskwarrior child-task creation or any source edit.
- 2026-07-24: Approved and implemented. `cli.s`'s indirect-write
  requirement (writing to a runtime-selected slot while `Y` is the
  established `CommandBuffer` cursor throughout its call chain) needed
  more care than planned: `(zp),Y` addressing requires `Y` as the index,
  so the destination pointer itself advances one byte at a time (`Y`
  fixed at 0 per store) rather than being indexed, with the real `Y`
  stashed around each store. A mid-implementation disk-space discrepancy
  surfaced: the combined-overflow fixtures (40000/30000 bytes) do not fit
  on the already-full shared `test.d64`. Presented the constraint to the
  user with two options; the user chose a dedicated
  `casm_overflow_test_d64` disk image (`casm.prg` plus the two oversized
  fixtures only) over dropping the fixture. Implementation otherwise
  matched the plan closely. User ran the full verification matrix across
  two sessions and confirmed: "all test pass." Applied the version-only
  completion increment: final CASM `0.1.36` build 1139, no-change rebuild
  stable, all three disk images build clean, MAIN headroom 261 of 13568
  bytes. Recorded the Phase 0C.12 as-built amendment in
  `brain/KNOWLEDGE.md`, corrected `AGENTS.md`'s stale single-source-filename
  contract, updated `wiki/tasks/casm.md`/`brain/task.md`/`CHANGELOG.md`/
  Taskwarrior, and drafted the walkthrough. **WP34 is complete.** WP35
  (diagnostic filename integration) remains separately gated and
  unstarted.
