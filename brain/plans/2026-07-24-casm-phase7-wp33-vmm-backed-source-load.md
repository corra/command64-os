---
feature: casm-phase7-wp33-vmm-backed-source-load
created: 2026-07-24
status: planned
---

# Plan: CASM Phase 7 WP33 - VMM-Backed Source Load and Traversal Equivalence

## Objective

Implement Contract items 1-3 of the Phase 0C.10 freeze
(`brain/plans/2026-07-23-casm-phase7-wp32-prerequisite-reconciliation.md`):
a new pre-pass `sourceLoad` stage that streams the (still single) input file
into one VMM allocation, and a VMM-backed `sourceRefill` that fills
`CasmIoBuffer` from that allocation instead of the OS file directly. Prove
byte-identical/diagnostic-identical equivalence against every existing
single-file fixture before the old OS-direct refill path is deleted --
matching the master plan's Phase 7 gate wording exactly ("small inputs
remain byte-identical ... before retiring any redundant backend").

**Scope boundary, per the user's confirmed decision (2026-07-24): WP33 is
single-file only.** No `CasmSourceNames` array, no `CasmSourceFileTable`, no
loop over multiple inputs -- `cli.s` still populates exactly one
`CasmSourceName` until WP34. Building the N-file loop now, when no fixture
WP33 can write would ever exercise it with more than one file, would be
exactly the kind of untested speculative complexity this project's own
precedent has repeatedly avoided (WP26 deferred "emission events" the same
way, for the same reason). WP34 extends `sourceLoad` into a real loop and
adds the file table once `CasmSourceNames` actually holds more than one
entry.

Taskwarrior: to be created after this plan's approval, mirroring WP27's
child-task creation under the CASM Phase 7 milestone
(`1a0d0dc8-3267-4885-aa83-adf923d56422`).

Prerequisite: CASM Phase 7 WP32 is complete and approved (CASM `0.1.34`
build 1132, Phase 0C.10 contract frozen in `brain/KNOWLEDGE.md`). Approval
of this plan is required before activation or source edits, per the CASM
`AGENTS.md` gate. Active on `feature/casm-phase7-wp33` from `main`'s tip
(commit `ab7445b`).

## Baseline

- CASM `0.1.34` build 1132. `MAIN: start = $3400, size = $3000` (12288
  bytes), 97 bytes headroom (unchanged since WP31/WP32 -- no production
  source has moved).
- Zero page `$70-$8F` fully allocated; WP33 needs no new zero-page cell
  (Dependency Review item 5 below).
- `source.s`'s traversal core (`sourceFetchPhysical`, `sourceNextResult`,
  `sourceAdvanceNewline`, `sourceComputeBase`, `sourceNextLine`) is
  unchanged by this WP (Dependency Review item 1) -- only the four routines
  that touch the OS/VMM boundary (`sourceOpen`, `sourceRewind`,
  `sourceClose`, `sourceRefill`) and one new routine (`sourceLoad`) change.

## Dependency Review and Discrepancies Reconciled

Direct tracing of the current `source.s`/`fileio.s`/`vmm_store.s`/`casm.s`
against the Phase 0C.10 contract found the following:

1. **`sourceFetchPhysical` needs zero changes.** It only ever inspects
   `CasmSourceBlockLenLo/Hi` and `CasmSourceBlockIndexLo/Hi` ("how much of
   `CasmIoBuffer` is currently valid, and where the cursor is within it")
   and `CasmSourceOffsetLo/Hi` ("how many bytes have been delivered to the
   classifier so far, checked against `$FFFF` overflow") -- both meanings
   are identical regardless of whether the block was filled from disk or
   from VMM. Confirmed by direct inspection (`source.s:654-721`): the only
   routine that actually calls an I/O primitive is the private
   `sourceRefill`. This substantially narrows WP33's real blast radius from
   "rewrite source.s's traversal" to "rewrite one private refill routine
   plus three small public state-transition routines."
2. **A single-file combined-size cap is already enforced for free, with no
   new check needed.** `inputStreamReadInto`/`inputStreamRead`
   (`fileio.s:394-461`, unchanged) already advance a checked 16-bit
   `CasmInputTotalLo/Hi` and raise `CASM_DIAG_SOURCE_OFFSET_OVERFLOW` at
   exactly 65535 bytes. `sourceLoad` (Contract item 1 below) calls these
   same wrappers unchanged to read each 256-byte OS block before writing it
   into VMM, so it inherits this exact cap for free. Since WP33 is
   single-file, this pre-existing per-file cap *is* the Phase 0C.10
   combined 65535-byte cap for N=1 -- no duplicate overflow check is
   written in this WP. (WP34 will need a distinct combined-across-files
   check, since `CasmInputTotalLo/Hi` resets per file.)
3. **Two independent 16-bit counters are needed on the VMM side, not one**,
   confirmed by tracing exactly what each existing counter means:
   `CasmSourceOffsetLo/Hi` already counts *bytes delivered to the
   classifier* (incremented once per `sourceFetchPhysical` data return,
   `source.s:695-699`) -- it says nothing about how far a refill has read
   from the underlying source. A fresh pair is needed for **how far
   `sourceRefill` has read out of the VMM allocation** (its next
   `vmmWindowRead` offset), separate from **how many bytes the allocation
   actually holds** (fixed once `sourceLoad` finishes). Reusing one pair for
   both purposes at different times is safe because loading always
   completes fully before any refill begins -- see Contract item 2.
4. **New Phase 7 state does not belong in `state.s`'s frozen Phase 3
   subrecords.** `state.s`'s 16-byte source subrecord and 47-byte
   lexer subrecord are both size-asserted (`CasmSourceStateEnd -
   CasmSourceStateStart = 16`, `CasmPhase3StateEnd - CasmPhase3StateStart =
   63`) and `AGENTS.md` documents them as a closed Phase 3 contract that
   `source.s`/`lexer.s` "must not redefine." This is exactly the situation
   WP28 already resolved once for `CasmLabelName`/`CasmLabelNameLen`
   (`parser.s`'s own BSS segment, "kept separate rather than grown into
   `CasmParserStmt`, whose size is an asserted shared ABI"). **Resolved
   (Contract item 4 below): the three new persistent cells live in a new
   `.segment "BSS"` block declared directly in `source.s`**, not in
   `state.s`, mirroring the `CasmLabelName` precedent exactly.
5. **No new zero-page cell is needed.** `sourceLoad`'s per-chunk staging
   (chunk length, source/dest offsets within `CasmIoBuffer`) reuses the
   already-generic `CasmIoLenLo/Hi`, `CasmIoPtrLo/Hi`, and
   `CasmVmmOffLo/Hi` cells `fileio.s`/`vmm_store.s` already stage every
   call through, plus `CasmSourceScratch0/1` ($80/$81, already aliased for
   `source.s`'s own transient use) within `sourceLoad`'s own call boundary.
   Confirms the "no zero-page growth" line of WP32's freeze holds for this
   WP specifically, not just in principle.
6. **`sourceOpen`, `sourceRewind`, and `sourceClose` all lose failure paths
   they have today, not just change what they call.** With no OS call left
   in any of the three (Contract item 4), each can now only fail on a bad
   precondition state -- their existing `CASM_DIAG_STREAM_STATE_FAILED`
   path is untouched, but `sourceOpen`'s open-failure path, `sourceRewind`'s
   `CASM_DIAG_INPUT_CLOSE_FAILED`/`CASM_DIAG_SOURCE_REWIND_FAILED` paths,
   and `sourceClose`'s `CASM_DIAG_INPUT_CLOSE_FAILED` path all become
   dead code at their current call sites. **`CASM_DIAG_INPUT_CLOSE_FAILED`
   stays reachable** (it moves to `sourceLoad`'s own `inputStreamClose`
   call, arguably a more sensible place for a "closing this file failed"
   diagnostic than at the very end of a successful Pass 2).
   **`CASM_DIAG_SOURCE_REWIND_FAILED` ($14) becomes entirely unreachable
   through any code path.** Not removed or renumbered -- `common.inc`'s
   diagnostic identifiers are a stable, sequentially-asserted-contiguous
   contract (`CASM_DIAG_PHASE3_LAST` and every later phase's range depend
   on it), so an unreachable-but-declared diagnostic is treated the same
   way Phase 5's WP17 reservations were: declared and message-tabled, just
   not currently raised by anything. Recorded here as an as-built
   correction for the eventual Phase 0C.11 close-out, not resolved by
   deleting or repurposing the identifier.
7. **Existing single-file fixtures split into two groups with different
   equivalence proofs, not one uniform re-run.** The 12 `CASM_REF_NAMES`
   fixtures (`casmemit1`, `casmhello`, `casmmodes`, `casmnum2`, `casmexprn`,
   `p1fwd1`, `p1back1`, `p1size1`, `brfwd1`, `brback1`, `casmcase1`,
   `casmmaxid1`) are real programs with trusted-reference PRGs -- their
   equivalence proof is "still byte-identical to the same trusted
   reference." The seven Phase 3 traversal fixtures in
   `CASM_TEST_FIXTURES` but not `CASM_REF_NAMES` (`casmempty`, `casmshort`,
   `casm256`, `casmmulti`, `casmcr`, `casmcrlf`, `casmsplit`) contain no
   valid mnemonics/directives at all (confirmed by direct inspection of
   `cmake/GenerateCasmTestFixtures.cmake:11-46` -- e.g. `casmcr.seq` is
   literally `"LINE1<CR>LINE2<CR>"`) and exist specifically to exercise
   newline normalization and OS-block-boundary behavior; run through real
   `casm.s` they fail immediately with a predictable `CASM_DIAG_SYNTAX_ERROR`
   at a predictable line/column. Their equivalence proof is "the same
   diagnostic at the same line and column," not byte-identical PRG output.
   Both proofs are meaningful and neither subsumes the other -- both are
   required (Verification Plan below).
8. **No existing fixture was designed with the new 64-byte internal VMM
   chunk boundary in mind, because that boundary didn't exist before.**
   `sourceRefill`'s outer 256-byte OS-block boundary is already covered
   (`casm256`), but `sourceRefill`'s new internal loop (Contract item 3)
   transfers in up to four 64-byte `vmmWindowRead` chunks per refill, and
   no existing fixture's content length was chosen with 64/128/192-byte
   granularity in mind. **Resolved (Verification Plan below): two new,
   small fixtures are added**, sized so a refill needs a partial final
   chunk at a 64-byte-multiple-plus-remainder boundary, proving the
   chunking loop's arithmetic rather than only its outer shape.

## Contract to Freeze/Amend (Phase 0C.11)

Amends Phase 0C.10 with the as-built detail WP33 needs to actually write
code, per the WP28/29/30-over-WP26 precedent of each implementing package
refining the prior freeze:

1. **New routine `sourceLoad` (public, new export), single-file only.**
   Inserted into `casm.s`'s `start` routine immediately before the existing
   `jsr sourceOpen` call (after `symbolsInit`, per the current call order).
   Requires `CasmSourceState == CASM_SOURCE_STATE_CLOSED` (same precondition
   `sourceOpen` checks today). Steps: `vmmStoreAlloc` for
   `CASM_SOURCE_VMM_MAX_BYTES` (65535, new `common.inc` constant -- see
   Contract item 2) bytes, storing the granted slot in the new
   `CasmSourceVmmSlot`; `inputStreamOpen` (unchanged, opens
   `CasmSourceName`, resets `CasmInputTotalLo/Hi`); a loop of
   `inputStreamRead` (unchanged, 256-byte `CasmIoBuffer` blocks) until
   `CASM_STREAM_EOF`, writing each returned block into the VMM allocation
   through up to four 64-byte `vmmWindowWrite` chunks at the running
   `CasmSourceVmmCursorLo/Hi` offset (advancing it by each chunk's actual
   length); `inputStreamClose` (unchanged). On success,
   `CasmSourceLoadedLenLo/Hi` is set to the final `CasmSourceVmmCursorLo/Hi`
   value (the total bytes loaded) and `CasmSourceVmmCursorLo/Hi` is reset to
   `0` for reuse as the read-side cursor (Contract item 3). Any
   `vmmStoreAlloc`/`inputStreamOpen`/`inputStreamRead`/`vmmWindowWrite`/
   `inputStreamClose` failure propagates its existing diagnostic unchanged
   (Dependency Review item 6's `CASM_DIAG_INPUT_CLOSE_FAILED` relocation is
   this call site). `sourceLoad` does not touch `CasmSourceState` -- it
   stays `CLOSED` until the following `sourceOpen` call commits `READY`.
2. **`CASM_SOURCE_VMM_MAX_BYTES = 65535`, a new `common.inc` constant**,
   documented as the true single-`vmmStoreAlloc`-request ceiling (WP32's
   Dependency Review item 4: 65536 cannot be represented in a 16-bit `X/Y`
   count). This is the byte count `sourceLoad` requests; the allocation
   internally rounds up to a full 16-page/65536-byte grant, matching every
   other VMM consumer's existing rounding behavior.
3. **`sourceRefill`'s data source changes from `inputStreamReadInto` to
   chunked `vmmWindowRead`; every surrounding invariant is preserved.**
   `sourceComputeBase`'s BYTE/LINE base computation is unchanged.
   `remaining = CasmSourceLoadedLenLo/Hi - CasmSourceVmmCursorLo/Hi`
   (checked 16-bit subtract) replaces the OS's own EOF signal:
   `remaining == 0` commits EOF exactly as today's `srEof` does (same
   `CASM_SOURCE_STATE_EOF` commit, same `CasmSourceResultByte` clear),
   cross-checked against `CasmSourceBlockIndexLo/Hi ==
   CasmSourceBlockLenLo/Hi` exactly as today (the drained-block invariant
   is caller-guaranteed by `sourceFetchPhysical`, unchanged). Otherwise,
   `transferLen = min(256 - base, remaining)`, executed as up to four
   `vmmWindowRead` calls of up to 64 bytes each (slot =
   `CasmSourceVmmSlot`, offset = `CasmSourceVmmCursorLo/Hi`, advancing it
   by each chunk's length) targeting successive positions within
   `CasmIoBuffer + base`; the installed block index/length
   (`CasmSourceBlockIndexLo/Hi = base`,
   `CasmSourceBlockLenLo/Hi = base + transferLen`) is computed exactly as
   today. No `srInvalidBlock`-style external-input validation is needed
   (the chunk lengths are locally computed, not OS-reported), but an
   internal consistency check (`transferLen` never exceeds `256 - base`)
   is kept as a defensive assert against a cursor-math bug, not an
   external-input rejection.
4. **New persistent state lives in `source.s`'s own new `.segment "BSS"`**,
   not `state.s` (Dependency Review item 4): `CasmSourceVmmSlot: .res 1`,
   `CasmSourceLoadedLenLo/Hi: .res 2`, `CasmSourceVmmCursorLo/Hi: .res 2` --
   5 new bytes total. `sourceInit` gains their zero-initialization
   (`CasmSourceVmmSlot` has no "unallocated" sentinel need since
   `sourceLoad` always assigns it before any refill can run; zeroing it at
   `sourceInit` is defensive only).
5. **`sourceOpen` becomes a pure cursor reset, no OS call.** Precondition
   unchanged (`CasmSourceState == CLOSED`); on success it sets
   `CasmSourceState = READY`, `CasmSourceApiMode = BYTE`, resets
   `CasmSourceVmmCursorLo/Hi` to `0` (the new read-side cursor start),
   and calls the existing `sourceResetTraversal` unchanged. Its
   `CASM_DIAG_STREAM_STATE_FAILED` bad-state path is the only remaining
   failure outcome (Dependency Review item 6).
6. **`sourceRewind` becomes textually the same reset `sourceOpen` performs**
   (precondition `READY` or `EOF`, same three field resets, same
   `sourceResetTraversal` call) -- no `inputStreamClose`/`inputStreamOpen`
   pair, no failure path beyond bad-state. The two routines may share a
   private body if that reads more clearly once written; not mandated
   here.
7. **`sourceClose` drops its `inputStreamClose` call entirely** -- the OS
   file was already closed by `sourceLoad`. It keeps its existing
   `CasmSourceState == CLOSED` no-op short-circuit and its existing tail
   (commit `CLOSED`/`NONE`, clear block/result state), with no remaining
   failure path (Dependency Review item 6). Whether `sourceClose` also
   calls `vmmStoreFree` on `CasmSourceVmmSlot` explicitly, or leaves the
   allocation for `resourcesCleanup`'s existing generic VMM sweep (the
   symbol table's own established precedent -- WP27's symbol allocation is
   never freed explicitly, only by the generic sweep at `exitSuccess`/
   `exitFatal`), is decided in favor of the **generic sweep**, for
   consistency with that existing precedent and because CASM's file-handle
   scarcity rationale (explicit prompt release) does not apply to VMM
   allocations, which already have their own dedicated 8-slot registry
   independent of file handles.
8. **`casm.s` gains one new call and one new import.** `jsr sourceLoad`
   inserted immediately before the existing `jsr sourceOpen`, both still
   under the existing `bcs startInitFatal` pattern; `.import sourceLoad`
   added alongside the existing `sourceInit`/`sourceOpen`/`sourceClose`
   imports.

## Scope

Included in WP33:

- `source.s`: new `sourceLoad`; rewritten `sourceOpen`, `sourceRewind`,
  `sourceClose`, `sourceRefill`; new `.segment "BSS"` block (Contract item
  4); `sourceInit` extended to zero the new cells.
- `common.inc`: `CASM_SOURCE_VMM_MAX_BYTES = 65535`.
- `casm.s`: one new call site and import (Contract item 8).
- New fixtures for the 64-byte internal chunk boundary (Dependency Review
  item 8).
- Full re-run of every existing single-file fixture (Dependency Review item
  7) for equivalence, and removal of the old OS-direct refill code path
  once equivalence is confirmed (not kept as dead code, per WP32's gate
  wording).

Excluded from WP33 (each is a later, separately-gated package):

- `CasmSourceNames` array, `cli.s` multi-file parsing (WP34).
- `CasmSourceFileTable`, file-boundary `CasmSourceFileId`/line-number resets
  (WP34).
- `CasmStmtLocFileId`/`CasmDiagLocFileId`, diagnostic filename printing
  (WP35).
- Any MAIN envelope size change beyond what this WP's own measurement
  justifies.

## Expected Files

| File | Action |
| --- | --- |
| `brain/plans/2026-07-24-casm-phase7-wp33-vmm-backed-source-load.md` | this document |
| `src/external/casm/source.s` | Modify: `sourceLoad`, rewritten `sourceOpen`/`sourceRewind`/`sourceClose`/`sourceRefill`, new BSS block |
| `src/external/casm/common.inc` | Modify: `CASM_SOURCE_VMM_MAX_BYTES` |
| `src/external/casm/casm.s` | Modify: `sourceLoad` call site and import; version-only stage increment at completion |
| `src/external/casm/BUILD_CASM` | build-managed increment |
| `cmake/GenerateCasmTestFixtures.cmake` | Modify: two new 64-byte-boundary fixtures |
| `tests/fixtures/casm/` | new fixture(s) if a trusted-reference comparison is used rather than a diagnostic-only proof (decided when the fixtures are drafted, per Dependency Review item 8's chunking-boundary intent) |
| `wiki/tasks/casm.md`, `brain/task.md`, `brain/KNOWLEDGE.md`, `CHANGELOG.md` | Closeout updates |

## ABI, Storage, and Runtime Effects

- New exported routine: `sourceLoad` (`source.s`).
- New persistent BSS: `CasmSourceVmmSlot`, `CasmSourceLoadedLenLo/Hi`,
  `CasmSourceVmmCursorLo/Hi` (5 bytes, `source.s`'s own segment, not
  `state.s`).
- New constant: `CASM_SOURCE_VMM_MAX_BYTES = 65535` (`common.inc`).
- `sourceOpen`/`sourceRewind`/`sourceClose`'s public signatures (inputs,
  C/A outputs) are unchanged; only their reachable failure outcomes shrink
  (Dependency Review item 6). No caller outside `source.s`/`casm.s` needs
  to change.
- `CASM_DIAG_SOURCE_REWIND_FAILED` becomes declared-but-unreachable; not
  removed or renumbered (Dependency Review item 6).
- MAIN size: not pre-sized here. Measured once the code is written, against
  the 97-byte current headroom, per every prior WP's precedent.

## Verification and Fixture Strategy

**Correction to this plan's own earlier framing**: the seven Phase 3
traversal fixtures below were designed for the pre-WP15 temporary
token-dump mode and have never actually been run through the real two-pass
`casm.s` before (they are not part of any prior WP's regression sample --
WP31's targeted 7-fixture sample was a *different* set:  `casmwp11`,
`casmzp1`, `casmcma2`, `casmorg3`, `casmzpi2`, `casmpcovf`,
`casmnumerrh`). There is no "same as before" baseline to re-confirm for
most of them. This section instead hand-derives the expected outcome for
each, mirroring WP31's own per-fixture verification rigor, and the runtime
matrix confirms those derivations rather than a regression.

### Test Procedure

Prerequisite: `build/image.d64` (contains `casm.prg`, `comp.prg`) and
`build/test.d64` (contains every fixture `.seq`, every trusted `.ref` PRG,
and the standalone `TEST_CASM_*` harnesses) are current -- rebuild both if
any source changed since your last build. Mount both in the supported local
emulator per your usual CASM testing setup.

**1. Standalone harnesses (regression -- confirm still pass unmodified):**

Run `TEST_CASM_PASS1` and `TEST_CASM_PASSCHECK` from `test.d64`. Both now
exercise `sourceLoad` internally (`casm_pass1.s`'s two driver routines gained
their own `jsr sourceLoad` immediately before `jsr sourceOpen`, mirroring
`casm.s`'s own change) -- confirm each harness still reports its existing
all-pass result with no new failure.

**2. Byte-identical trusted references (12 total) -- `CASM <name>.S` then
`COMP <name>.PRG <name>.REF`, expect IDENTICAL for every one:**

`casmemit1`, `casmhello`, `casmmodes`, `casmnum2`, `casmexprn`, `p1fwd1`,
`p1back1`, `p1size1`, `brfwd1`, `brback1`, `casmcase1`, `casmmaxid1`.

**3. Phase 3 traversal fixtures -- first real run through two-pass `casm.s`,
hand-derived expected results (not a "same as before" check):**

| Fixture | Content | Expected result |
| --- | --- | --- |
| `casmempty` | 0 bytes | `CASM: CANNOT OPEN INPUT` -- `fileOpenInput`'s own `DOS_OPEN_FILE` call rejects a zero-size SEQ before `sourceLoad`'s read loop ever starts ([[project-casm-zero-size-seq-open]]); unaffected by WP33 since this is the same call site, just reached from `sourceLoad` instead of `sourceOpen` |
| `casmshort` | `.ORG`/`LDA`/`STA`/`LDA`/`JMP START_LABEL` | Assembles through `.ORG`, `LDA #10`, `STA $0400,X`, `LDA %10101010` (zero-page, value $AA) cleanly; `START_LABEL` is never defined anywhere in the file, so Pass 1 sizes `JMP START_LABEL` as absolute (3 bytes, tolerated unresolved) but Pass 2 raises `CASM: UNDEFINED SYMBOL` at the `JMP` statement -- no output PRG survives (`outputAbort` deletes the partial file) |
| `casm256` | 256 `A` bytes, no newline | Lexer's identifier scan hits its 31-byte cap on the 32nd `A` -- `CASM: TOKEN TOO LONG` at line 1, col 32 (offset 31) |
| `casmmulti` | 513 `B` bytes, no newline | Same token-length cap, same shape -- `CASM: TOKEN TOO LONG` at line 1, col 32 (offset 31) |
| `casmcr` | `LINE1<CR>LINE2<CR>` | `LINE1` (5-char identifier) is followed by a newline, not `:` -- a label statement requires the colon immediately (`parser.s`'s `ppsLabel`) -- `CASM: SYNTAX ERROR AT LINE 1, COL 6 (OFFSET 5)` |
| `casmcrlf` | `LINE1<CR><LF>LINE2<CR><LF>` | Same shape as `casmcr`; CRLF collapses to one newline at the same column as the CR-only case -- `CASM: SYNTAX ERROR AT LINE 1, COL 6 (OFFSET 5)`, **identical location to `casmcr`** (proves CRLF normalization doesn't shift the reported column) |
| `casmsplit` | 255 `A` bytes + CRLF + `END` | The identifier scan hits `TOKEN TOO LONG` at column 32 long before reaching the CRLF at byte 255 -- same `CASM: TOKEN TOO LONG` at line 1, col 32 (offset 31) as `casm256`; the CRLF-across-block-boundary behavior this fixture was originally built to exercise is masked by the unrelated, pre-existing lexer length cap, which is not a WP33 regression (unchanged lexer code) |

**4. New 64-byte VMM chunk-boundary fixtures -- same token-length-cap shape
as `casm256`, proving the new chunked refill delivers identical bytes at
the 64-byte-multiple boundary as it does elsewhere:**

| Fixture | Content | Expected result |
| --- | --- | --- |
| `casmvmm65` | 65 `A` bytes (one full 64-byte VMM chunk + 1-byte partial), no newline | `CASM: TOKEN TOO LONG` at line 1, col 32 (offset 31) -- identical shape to `casm256`; a wrong byte anywhere in bytes 1-31 (spanning the chunk 0/1 boundary at byte 64 is not even reached before the 32nd-byte cutoff, but the chunk arithmetic itself is exercised during `sourceLoad`'s write and every `sourceRefill` read regardless of where the diagnostic fires) |
| `casmvmm128` | 128 `A` bytes (exactly two full 64-byte VMM chunks, no partial), no newline | Same: `CASM: TOKEN TOO LONG` at line 1, col 32 (offset 31) |

If either new fixture instead hangs, crashes, or reports a different
diagnostic (e.g. a VMM transfer failure), that is a direct signal of a
chunk-loop defect, since nothing else about these two differs from
`casm256`'s already-understood shape.

**5. Static/manual confirmation** that the old direct-disk refill code path
is fully removed from `source.s`, not left compiled-but-unreachable (visual
check, already done during implementation: `inputStreamReadInto` is no
longer imported or referenced anywhere in the file).

**6. Build verification** (already done, recorded here for the walkthrough):
both relocation bases and `test_image_d64` build clean; a no-change rebuild
holds `BUILD_CASM` stable at 1135; MAIN headroom is 276 of 12800 bytes
(`$3200`, up from `$3000` -- a 236-byte overflow at the old size made the
bump necessary). `casm_pass1`/`casm_passcheck`'s own MAIN envelope grew
`$3200` -> `$3300` for the same reason (both link `source.s` whole).

Every failing case is investigated before completion is requested. A
newly-discovered defect is presented to the user with its root cause and a
proposed fix before any source is touched, matching WP30's precedent.

## Atomic Implementation Increments

1. Add `CASM_SOURCE_VMM_MAX_BYTES` to `common.inc`.
2. Implement `sourceLoad` and the new BSS block in `source.s`; wire the new
   call site and import in `casm.s`.
3. Rewrite `sourceRefill`'s data-source path; rewrite `sourceOpen`/
   `sourceRewind`/`sourceClose`.
4. Add the two new 64-byte-boundary fixtures to
   `cmake/GenerateCasmTestFixtures.cmake` (and a trusted reference if
   applicable); wire into `CMakeLists.txt`.
5. Build `casm` and `test_image_d64`; run the full verification matrix in
   VICE (ask the user); investigate and resolve any failure per the Stop
   Conditions below before proceeding.
6. Measure MAIN headroom via `ld65 -m`; propose a size bump only if the
   current `$3000` envelope is insufficient.
7. Apply the version-only completion increment; confirm no-change rebuild
   stability; update `wiki/tasks/casm.md`, `brain/task.md`,
   `brain/KNOWLEDGE.md` (Phase 0C.11 as-built record), `CHANGELOG.md`,
   Taskwarrior; draft the walkthrough and request completion approval.

## Failure and Cleanup

A newly-discovered defect during verification is handled exactly as WP30's
`eiRelative` fix: presented to the user with root cause and a proposed fix
before any change, applied only with explicit approval, scoped as narrowly
as the defect allows -- matching every prior phase's precedent. No new
runtime cleanup path is introduced: `sourceLoad`'s VMM allocation is freed
generically by the existing `resourcesCleanup` sweep (Contract item 7); its
file handle follows the existing `fileOpenInput`/`inputStreamClose`
registration/release contract unchanged.

## Documentation and DOX Closeout

Update this plan, `brain/KNOWLEDGE.md` (new Phase 0C.11 as-built section
amending Phase 0C.10 with the exact routine/state shape implemented, per
this document's Contract section), `brain/task.md`, `wiki/tasks/casm.md`,
`CHANGELOG.md`, Taskwarrior, and a new walkthrough. `AGENTS.md` needs no
change (WP33 does not touch the multi-file CLI grammar `AGENTS.md`
currently documents as single-file-only; that is WP34's concern).

## Stop Conditions

Stop if CASM Phase 7 WP32 is not complete and approved. Stop if any
fixture reveals a defect whose scope or fix is not small and
well-understood enough for the user to approve fixing in place. Stop if a
further material discrepancy against this freeze is found during
implementation, requiring this document to be amended and re-approved.

## Completion Gate

WP33 is complete when: the full verification matrix above passes; the old
direct-disk refill code path is fully removed (not left dead); MAIN
headroom is measured and any needed size bump is applied and justified; a
no-change rebuild holds `BUILD_CASM` stable; both `image_d64` and
`test_image_d64` build clean; and the user explicitly approves the
walkthrough. This closes WP33 but does not activate WP34, which remains
separately gated per `AGENTS.md`.

## Progress

- 2026-07-24: Drafted after confirming CASM Phase 7 WP32's completion gate
  (`0.1.34` build 1132, Phase 0C.10 frozen). Traced the current
  `source.s`/`fileio.s`/`vmm_store.s`/`casm.s` in detail rather than
  re-describing WP32's freeze at a summary level, and found `sourceFetchPhysical`
  needs zero changes (only the private `sourceRefill` and three small
  public state-transition routines touch the OS/VMM boundary), that the
  existing per-file 65535-byte overflow check is inherited for free by
  `sourceLoad` simply by reusing `inputStreamRead` unchanged, that two
  independent 16-bit counters (not one) are needed on the VMM side since
  `CasmSourceOffsetLo/Hi` already means something else, and that the new
  state belongs in `source.s`'s own BSS segment rather than `state.s`'s
  frozen Phase 3 subrecords -- mirroring WP28's `CasmLabelName` precedent
  exactly. Asked the user whether WP33's `sourceLoad` should already be a
  general N-file loop or strictly single-file; the user confirmed the
  recommended single-file-only scope, deferring the loop and file table to
  WP34. Created `feature/casm-phase7-wp33` from `main` at `ab7445b`.
  Awaiting user approval before Taskwarrior child-task creation or any
  source edit.
