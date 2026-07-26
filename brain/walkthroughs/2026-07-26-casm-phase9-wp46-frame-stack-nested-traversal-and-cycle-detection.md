# Walkthrough: CASM Phase 9 WP46 - Frame Stack, Nested Traversal, and Cycle Detection

## Implemented Behavior

- `source.s` gained a 16-slot nested-include frame stack (parallel BSS
  arrays, 0-based, indexed by depth-1): `CasmFrameDepth`,
  `CasmFrameCatalogIndex`, `CasmFrameEndOffsetLo/Hi`,
  `CasmFrameResumeOffsetLo/Hi`, `CasmFrameResumeLineLo/Hi`,
  `CasmFrameResumeColumn`, `CasmFrameResumePendingCr`.
- New export `sourceFramePush`: checks depth (`<16`) and active-chain
  cycles before any state change, then saves the parent's live traversal
  state, switches to the child's start, invalidates the installed block
  and the lexer lookahead, and resets the diagnostic echo/offset-guard
  state.
- Frame **pop is fully automatic**, not a separate exported call: rewired
  `sourceRefill` now branches its boundary cap on `CasmFrameDepth` (root
  file-table cap at depth 0, the active frame's own end offset at depth
  `>0`), and reaching a nested frame's own end triggers
  `sourceFramePopInternal` (private) followed by a retry of the entire
  refill computation -- which can cascade through multiple pops if a
  shallower parent is *also* exactly at its own end.
- Fixed a pre-existing latent bug: `srCheckFileBoundary` (WP34's
  top-level multi-file transition) now also resets the diagnostic
  echo-buffer bookkeeping (`sourceResetBoundaryEcho`, new), not just
  line/column/pending-CR. Before this fix, two different top-level files
  sharing a line number could show one file's cached echo text under the
  other's diagnostic -- nothing had ever invalidated that bookkeeping at
  a file boundary.
- `CasmSourceOffsetLo/Hi` (the per-span byte-delivered overflow guard, no
  consumer outside `source.s` itself) is now reset to 0 at every boundary
  (root transition, push, pop) instead of accumulating as a global total
  -- avoiding a false rejection once the same physical bytes can be
  delivered many times over through repeated inclusion.
- Two new diagnostics: `$35` `CASM_DIAG_INCLUDE_DEPTH_EXCEEDED`, `$36`
  `CASM_DIAG_INCLUDE_CYCLE_DETECTED`.
- `casmRunPass`'s `.INCLUDE` dispatch is **unchanged from WP45**: still
  `CASM_DIAG_NOT_IMPLEMENTED`. `sourceFramePush` has no production call
  site; only the new `test_casm_frame` harness calls it. WP47 wires real
  dispatch once the include-event log exists to satisfy Pass 2's
  replay-only requirement.

## User-Confirmed Scope Decisions (recap)

1. Standalone module + harness only; no `casmRunPass` wiring (WP47's job).
2. Fixed the pre-existing WP34 echo-identity gap alongside the new
   nested-frame case, via one shared `sourceResetBoundaryEcho` helper.
3. Echo/offset-guard state is reset, not saved/restored, at every frame
   boundary -- **user asked this be revisited later**; not a closed
   decision.

## Automated Evidence

- `casm` build 1173 passes; MAIN grown `$3E00` -> `$4000` (221-byte
  measured overflow, user chose the tighter "exactly what's needed"
  amendment over a more generous one). Measured directly via `ld65 -m`:
  MAIN uses 16,092 of 16,384 bytes (292 bytes headroom). `build/casm.prg`
  is 17,483 bytes, loads at `$3400`, R6 footer `00 34 92 07 52 36` (1938
  relocation entries).
- `test_casm_pass1` (build 1035) and `test_casm_passcheck` (build 1017) --
  both link `source.s` whole -- needed the same `$3A00` -> `$4000`
  amendment (176-byte measured overflow) and now build/hold stable.
- New `test_casm_frame` (build 1001) passes and holds stable on a
  no-change rebuild.
- `test_casm_catalog` needed a small bump (`$1A00` -> `$1B00`, 51-byte
  overflow) from the shared `source.s` growth.
- `test_casm_include`, `test_casm_expr`, `test_casm_vmm`,
  `test_casm_symbols`, `test_casm_reloc` all rebuild successfully with no
  behavior change.
- `image_d64`, `test_image_d64`, and `casm_overflow_test_d64` all build
  clean. `casm_overflow_test_d64` carries the new harness as
  `test_casm_frame` (14 characters, no truncation needed) plus ten new
  real-CASM-syntax fixtures (`casmfrp1`-`casmfrp4`, `casmfrc1`-`casmfrc3`,
  `casmfrcr1`, `casmfrr1`-`casmfrr2`, bare lowercase disk names matching
  the established cc1541/ca65 case-pairing convention), 59 blocks free.
- `git diff --check` passes.

## Runtime-Discovered Defects (four, all production code)

The first runtime run displayed `fffff...`: every case driving real
lexer/parser traversal failed, while the three synthetic depth/cycle cases
passed. Root-causing took four distinct fixes, found by temporary
on-screen instrumentation in the harness (since removed) driving real
fixtures on real hardware/emulator -- none of them were reachable by
static review, and the first three each masked the next.

1. **`lexerFill` captured stale provenance** (`lexer.s`). It snapshotted
   `CasmSourceFileId`/`LineLo`/`Hi`/`Column` *before* calling
   `sourceNextByte`. Correct for an ordinary byte, but stale whenever that
   same call is the one that resolves a child frame's EOF and triggers the
   automatic pop: the delivered byte belongs to the *restored parent*, yet
   was stamped with the abandoned child's position. Fixed by capturing
   provenance *after* the fetch, from new `CasmSourceResultFileId`/
   `LineLo`/`Hi`/`Column` fields (`state.s`) written by
   `sourceFetchPhysical` itself at `sfpHaveByte`/`sfpEof` -- the one layer
   that already knows which span the delivered byte truly came from.
   `tests/src/casm_include/casm_include.s`'s stand-in `sourceNextByte`
   (which links no `source.s` at all) honors the same contract via its own
   `stampResultLoc` helper.
2. **`sfpEof` clobbered `A`** (`source.s`). The provenance capture added by
   fix 1 destroyed the `CASM_SOURCE_EOF` value the routine must still
   return, so stale garbage was misread as a real byte -- surfacing as a
   spurious `CASM_DIAG_INVALID_SOURCE_BYTE`. `A` is now reloaded after the
   capture rather than trusted to survive it.
3. **Depth-0 traversal had no end cap of its own** (`source.s`). Nested
   frames get `CasmFrameEndOffsetLo/Hi`, but depth 0 was capped only by
   `CasmSourceLoadedLenLo/Hi` -- which *grows* every time
   `sourceAppendFile` appends an `.INCLUDE` child mid-traversal. A
   top-level file with real content after its own `.INCLUDE` therefore
   overran straight into an appended child's bytes on reaching its own
   true end, instead of hitting EOF. Fixed with
   `CasmSourceTopLevelEndLo/Hi`: a fixed snapshot of the combined
   top-level content's true end, taken at `sourceLoad`'s own completion
   (before any child can ever be appended) and applied as depth-0's cap in
   `srComputeRemaining`.
4. **`sourceFramePush` saved the wrong resume offset** (`source.s`) -- the
   deepest of the four. It saved `CasmSourceVmmCursorLo/Hi`, which is the
   **bulk-refill read head**, not the logical parse position. `sourceRefill`
   installs up to 256 bytes per call, so for any fixture smaller than the
   buffer the cursor has already run to the file's very end by the time the
   lexer parses the `.INCLUDE` line. Resuming the parent from there skipped
   every byte still sitting unconsumed in the installed block. Fixed by
   saving `cursor - (blockLen - blockIndex)` instead.

### The false pass this exposed

Fix 4 also revealed that `frSinglePushPop` had been *passing for the wrong
reason* before fix 3 landed. With the resume offset wrong (cursor at 36,
the parent's own end) and no depth-0 cap, the pop re-read the **child's**
8 bytes a second time -- but with the parent's line counter correctly
restored to 4, those re-read `C1`/`C2` labels were stamped lines **4 and
5**, which is exactly what the expected `P3=4, P4=5` assertion wanted.
Only after fix 3 stopped the overrun did it become visible that `P3`/`P4`
were never actually being read at all. A green test was concealing two
independent bugs whose errors happened to cancel.

## Runtime Evidence

Confirmed by the user on the supported local emulator, twice: once on the
instrumented binary and again on the final clean (instrumentation-removed)
`test_casm_frame` build 1023, which is what actually ships.

All 8 cases (`frSinglePushPop`, `frNestedPushPop`,
`frSequentialReinclusion`, `frPendingCrBoundary`,
`frRootBoundaryEchoReset`, `frDepthExceeded`, `frDirectCycle`,
`frIndirectCycle`) pass:

```text
........
CASM FRAME: PASS
```

Booted through Command64 on `test.d64` (device 8) with
`casm_overflow_test.d64` on device 9, switching to device 9 via the `9:`
shortcut before launching -- matching the two-drive setup this project's
harnesses require.

## Manual Confirmation

1. Attach `build/casm_overflow_test.d64` in the supported local emulator
   (or use the generated disk on hardware) -- never the broken
   `c64-testing` MCP or a web emulator.
2. Run `test_casm_frame`.
3. Confirm eight dots and `CASM FRAME: PASS`. Any `F` indicates a failing
   case; report which position failed.
4. Optionally re-run `test_casm_catalo` (WP45's harness, unaffected by
   this work) and `casm` against any existing trusted-reference `.seq`
   fixture from `test_image_d64`, confirming `.INCLUDE` statements still
   report `FEATURE NOT IMPLEMENTED` unchanged -- proving this WP added no
   observable production behavior.

## Post-Fix Verification

- `test_casm_frame` build 1023 (clean, all temporary instrumentation
  removed) fits the original `$4000` envelope again at 13,837 code bytes
  -- the `$4200` bump needed while instrumented was reverted, so no
  envelope amendment ships.
- `casm` build 1190 builds and holds stable across two consecutive
  rebuilds.
- `test_casm_pass1`, `test_casm_passcheck`, `test_casm_catalog`,
  `test_casm_include`, `test_casm_expr`, `test_casm_vmm`,
  `test_casm_symbols`, `test_casm_reloc` all rebuild clean.
- `image_d64` (438 blocks free), `test_image_d64` (57), and
  `casm_overflow_test_d64` (56) all build clean.
- `git diff --check` passes; no `CasmDbg*`/`dbgDump*`/`dbgPrint*` symbol
  or `TEMPORARY WP46` marker remains anywhere in `src/` or `tests/`.
- One incidental linker fix: the CODE growth from fixes 1-4 shifted BSS
  enough to push `CasmExprResolverAddrLo` onto a `$xxFF` low byte,
  tripping `expr.s`'s own long-standing NMOS 6502 JMP-indirect page-wrap
  `.assert`. Resolved with a single pad byte in `expr.s` itself (the only
  file whose own BSS layout controls that symbol's offset, since `expr.o`
  links before `source.o`/`state.o`).

## Completion Gate

Runtime confirmation received (twice, including on the final clean
binary). Awaiting explicit completion approval. Once approved, CASM will
advance its version-only stage once, a no-change rebuild will be verified,
and all durable records will be synchronized. WP47 will not be activated
by this closure.
