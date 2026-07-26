---
feature: casm-phase9-wp46-frame-stack-nested-traversal-and-cycle-detection
created: 2026-07-26
status: complete
---

# Plan: CASM Phase 9 WP46 - Frame Stack, Nested Traversal, and Cycle Detection

## Objective

Add a real, standalone nested-include traversal engine to `source.s`: a
16-level frame stack, frame push (with depth and active-chain cycle
checks), and fully automatic frame pop/root-transition on child EOF,
wired into `sourceRefill`'s existing chunked-transfer loop rather than
replacing it. Fix a related, file-identity-blind diagnostic echo bug that
predates Phase 9. Proven entirely by a new dedicated test harness that
drives real lexer/parser traversal across simulated include boundaries.
`casmRunPass`'s `.INCLUDE` dispatch is **unchanged from WP45**: still
`CASM_DIAG_NOT_IMPLEMENTED`. Production wiring is WP47's job, once the
include-event log exists to satisfy Pass 2's replay-only requirement.

Parent plan: `brain/plans/2026-07-25-casm-phase9-include-processing.md`.
Prerequisite plans: WP43
(`brain/plans/2026-07-25-casm-phase9-wp43-prerequisite-reconciliation.md`),
WP44
(`brain/plans/2026-07-25-casm-phase9-wp44-quoted-include-operand-grammar.md`),
WP45
(`brain/plans/2026-07-25-casm-phase9-wp45-physical-file-catalog-and-dynamic-source-loading.md`).

Taskwarrior: `005a1819-eda6-4fa5-89e1-5848a5076a7d` (pending activation).

## User-Confirmed Scope Decisions

Three architectural forks were resolved with the user before this plan was
written:

1. **Wiring boundary**: WP46 stays standalone, exactly like WP44/45. No
   `casmRunPass` changes. The parent plan's own WP47 description
   ("production two-pass integration with zero Pass 2 source I/O") confirms
   real wiring cannot happen before WP47's event log exists -- Pass 2 must
   replay, not re-open files, and there is nothing to replay yet.
2. **Latent echo bug**: `diagResolveView` (diagnostics.s) matches a
   diagnostic's cached line purely by line number, with no file-identity
   check at all -- a pre-existing gap in the already-shipped WP34
   multi-top-level-file support (two different top-level files sharing a
   line number could show one file's cached text under the other's
   diagnostic), not something new to nested includes. WP46 fixes both the
   pre-existing top-level case and the new nested-frame case together,
   since both go through the same `srCheckFileBoundary` choke point.
3. **Echo/offset state at a frame boundary is reset, not saved/restored**:
   a diagnostic on the first statement immediately after any root
   transition, push, or pop shows no "previous line" text (absent, not
   wrong) rather than paying for full per-frame echo-buffer save/restore
   (256+ bytes x 16 frames). **User asked this be revisited later** --
   recorded as a stop/reconsider marker in Scope below, not closed
   permanently.

## Prerequisites and Baseline

- WP45 is complete and user-approved at CASM `0.1.47` build 1171. MAIN
  `$3400` + `$3E00` uses 15,563 of 15,872 bytes: 309 bytes free.
- `include.s` (WP45) is a standalone module: `includeCatalogInit`,
  `includeResolveDevice`, `includeCatalogFind`, `includeCatalogRead`,
  `includeCatalogLoad`. A successful `includeCatalogLoad` returns a record
  index in `X` and leaves the full 128-byte record in
  `CasmIncludeRecordStage` (`CASM_INCLUDE_PHYS_REC_START_LO/HI`,
  `..._LENGTH_LO/HI`). No production call site exists yet.
- `casmRunPass` (`casm.s`) intercepts a parsed `.INCLUDE` statement before
  `emitDirective` and returns `CASM_DIAG_NOT_IMPLEMENTED`, unchanged since
  WP44.
- The next free diagnostic number is `$35`
  (`CASM_DIAG_PHASE9_WP45_LAST = $34`).

## Dependency Review and Reconciled Discrepancies

1. **`sourceRefill`'s existing boundary logic is flat and top-level-only,
   and is not safe to reuse as-is for nested frames.** `srCheckFileBoundary`
   and `srComputeRemaining`'s next-boundary cap are keyed entirely off
   `CasmSourceFileId` vs. `CasmSourceCount`/`CasmSourceFileTable` -- a
   linear sequence of up to 8 top-level spans. A nested child's span (from
   `include.s`'s catalog) can be appended anywhere in the combined store,
   with no relationship to the top-level file table at all. Reusing the
   existing cap unmodified while a nested frame is active could either
   truncate a refill at an unrelated top-level boundary or let a child's
   traversal run past its own end into unrelated content. **Resolution**:
   `sourceRefill`'s cap computation must branch on whether a nested frame
   is active (frame depth `> 0`): at depth 0, the existing
   `CasmSourceFileTable`-based logic is unchanged; at depth `N > 0`, the
   cap is the active frame's own recorded end offset instead, and
   `srCheckFileBoundary`'s top-level-transition check is skipped entirely
   (a depth-0-only concern).
2. **Frame pop is not a separate operation the caller invokes -- it must
   be fully automatic, inside `sourceRefill`.** The frozen contract
   describes "frame entry, child EOF, parent resume, and root transition"
   as the same class of automatic, transparent boundary the lexer/parser
   never has to know about. This means reaching a nested frame's own end
   (`transferLen == 0` while depth `> 0`) must restore the suspended
   parent's state and retry the refill computation from scratch --
   possibly cascading through multiple pops if a shallower parent is
   *also* immediately at its own end -- rather than committing combined
   EOF (which today unconditionally means "the whole traversal is done").
   Only reaching depth 0 with the top-level content exhausted still means
   real combined EOF. `sourceRefill` needs a retry loop, not a single
   linear pass.
3. **`CasmSourceOffsetLo/Hi`'s existing "reject the 65535th+ byte"
   overflow guard would produce false positives under repeated inclusion.**
   It is a global monotonic "total bytes ever delivered" counter today,
   grep-confirmed to have no consumer outside `source.s` itself (only the
   overflow guard and one "has any byte been consumed yet" check). Once
   the same physical bytes can be delivered to the lexer many times over
   (an included file used repeatedly), this total could exceed 65535 even
   though the physical store never does. Resolution: reset it to 0 at
   every frame boundary (root transition, push, and pop alike) rather than
   treating it as a value needing to survive across frames -- it has no
   external reader, so a fresh reset at each transition preserves its only
   real purpose (protecting the 16-bit counters within whatever span is
   currently active) without any false rejection.
4. **Frame push/pop logic belongs in `source.s`, not a new module or
   `include.s`.** It requires deep, direct rewiring of `sourceRefill`/
   `srCheckFileBoundary`'s internals and the same traversal fields
   (`CasmSourceVmmCursorLo/Hi`, `CasmSourceLineLo/Hi`, `CasmSourceColumn`,
   `CasmSourcePendingCr`) those routines already own. `include.s` has
   never imported from `source.s`'s traversal internals (only
   `sourceAppendFile`, a public entry point) and should not start; the
   caller (the new test harness now, WP47's dispatch later) bridges
   `include.s`'s catalog lookup and `source.s`'s frame push, exactly as
   already established (a caller reads `CasmIncludeRecordStage` after
   `includeCatalogLoad` and acts on it, per WP45's own harness precedent).
5. **Both the WP34 root-transition path and the new push/pop path need
   the same echo/offset reset** (Scope Decision 2 above). Factored into
   one shared private helper in `source.s` rather than duplicated three
   times.
6. **Line/column/pending-CR reset vs. restore differ by transition
   type**: a root transition or a frame push always resets to line 1,
   column 1, pending-CR clear (a fresh file always starts there); a frame
   pop restores the exact saved values from the moment of the
   corresponding push (the parent resumes mid-line, not at its own start).
   The shared echo/offset reset helper (finding 5) applies uniformly to
   all three transition types; the line/column/pending-CR handling does
   not, and is not factored together with it.
7. **Cycle detection is correctly scoped by the frozen contract already**:
   "Cycle detection scans the active frame chain only" -- a top-level root
   is never itself a catalog entry (WP45 finding: top-level files are not
   cataloged; that unification is WP48's job), so an `.INCLUDE` that
   happens to reference the same physical file as a top-level root is not,
   and is not expected to be, caught as a cycle by WP46. This is not a new
   gap; it is the frozen contract's own stated scope.

## Frame Stack Design

Sixteen slots (`CASM_INCLUDE_MAX_DEPTH = 16`), indexed by depth 1-16 (depth
0 means "no nested frame active, traversing a top-level root exactly as
today"). Plain BSS parallel arrays, not a packed VMM-style record -- no
power-of-two/shift constraint applies here, and direct `X`-indexed byte
arrays need no per-record multiply:

- `CasmFrameCatalogIndex` (16 bytes): the physical catalog index active at
  this depth, for cycle detection.
- `CasmFrameEndOffsetLo/Hi` (16 bytes each): the active frame's own end
  offset in the combined store, used as `sourceRefill`'s cap while this
  depth is active.
- `CasmFrameResumeOffsetLo/Hi` (16 bytes each): the suspended parent's
  `CasmSourceVmmCursorLo/Hi` at the moment this depth was pushed.
- `CasmFrameResumeLineLo/Hi` (16 bytes each), `CasmFrameResumeColumn` (16
  bytes), `CasmFrameResumePendingCr` (16 bytes): the suspended parent's
  line/column/pending-CR at the same moment.
- `CasmFrameDepth` (1 byte): 0-16, the current active depth.

Total new BSS: `16 * 12 + 1 = 193` bytes.

Indexing convention: pushing from depth `D` to `D+1` saves the parent's
state at array index `D+1` (not `D`) and stores the new child's own
catalog index/end offset there too; popping from depth `D+1` back to `D`
restores from that same index `D+1`. The array index a frame occupies is
always its own (post-push) depth.

## ABI

### `sourceFramePush` (new export, `source.s`)

- Inputs: `A` = candidate catalog index (0-31); `CasmValue0Lo/Hi` = child
  start offset; `CasmValue1Lo/Hi` = child end offset (start + length),
  staged by the caller immediately before the call (the same safe
  stage-then-copy pattern `resourceRegisterVmm`/`vmmStoreAlloc` already
  use, not the "must survive a later call" pattern that caused WP45's
  `sourceAppendFile` defect).
- Checks, in order, before any state changes: depth `< 16` (else
  `CASM_DIAG_INCLUDE_DEPTH_EXCEEDED`); the candidate catalog index does not
  match `CasmFrameCatalogIndex[1..CasmFrameDepth]` (else
  `CASM_DIAG_INCLUDE_CYCLE_DETECTED`).
- On success: saves the current (parent's) `CasmSourceVmmCursorLo/Hi`/
  `CasmSourceLineLo/Hi`/`CasmSourceColumn`/`CasmSourcePendingCr` into the
  new depth's array slot; stores the candidate catalog index and end
  offset there too; sets the live cursor to the child's start offset, line
  1, column 1, pending-CR clear; calls the shared echo/offset reset helper
  (Dependency Review finding 5); increments `CasmFrameDepth`; invalidates
  the lexer lookahead (`CasmLookaheadValid = 0`, matching the existing
  `sourceRewind` precedent of the *caller* owning lookahead invalidation,
  not a private lexer call).
- Outputs: `C` clear, `A = CASM_DIAG_NONE` on success; `C` set with the
  diagnostic above on failure (no state changed).
- Clobbers: `A`, `X`, `Y`, `CasmValue0Lo/Hi`, `CasmValue1Lo/Hi`.

### Automatic pop (private, inside the rewired `sourceRefill`)

Not a separate exported entry point. When the active frame's cap
computation yields `transferLen == 0` while `CasmFrameDepth > 0`: restore
`CasmSourceVmmCursorLo/Hi`/`CasmSourceLineLo/Hi`/`CasmSourceColumn`/
`CasmSourcePendingCr` from the current depth's array slot; call the shared
echo/offset reset helper; decrement `CasmFrameDepth`; retry the refill
computation (which may cascade into another automatic pop if the
newly-resumed depth is *also* exactly at its own end). Reaching depth 0
with the top-level content also exhausted is unchanged combined EOF.

### `sourceResetBoundaryEcho` (private, new)

Resets `CasmDiagLineNoLo/Hi`, `CasmDiagPrevNoLo/Hi`, `CasmDiagLineLen`,
`CasmDiagLineClipped`, `CasmDiagPrevLen`, `CasmDiagPrevClipped` to their
sentinel/zero values (mirroring `sourceResetTraversal`'s own existing
reset), and `CasmSourceOffsetLo/Hi` to 0. Called from `srCheckFileBoundary`
(extending its existing top-level-transition reset, Dependency Review
finding 1/5 fix) and from both the push and automatic-pop paths above.

## Constants and Diagnostics

- `common.inc`: `CASM_INCLUDE_MAX_DEPTH = 16` and the frame array
  declarations' sizes derive from it (`.assert` against 16, matching this
  codebase's existing capacity-constant convention).
- Two new diagnostics, contiguous from `$35`:
  - `$35` `CASM_DIAG_INCLUDE_DEPTH_EXCEEDED`
  - `$36` `CASM_DIAG_INCLUDE_CYCLE_DETECTED`
  - `CASM_DIAG_PHASE9_WP46_LAST = $36`, with the matching contiguity assert.

## Scope

Included:

- `source.s`: frame stack storage; `sourceFramePush`; automatic pop inside
  a rewired `sourceRefill`; the shared echo/offset reset helper, applied to
  both the existing top-level-transition path and the new frame paths.
- `common.inc`: `CASM_INCLUDE_MAX_DEPTH`, diagnostics `$35-$36`.
- `diagnostics.s`: messages/table entries for the two new diagnostics.
- Dedicated `tests/src/casm_frame/` harness and `casm_overflow_test_d64`
  packaging.
- Task, plan, walkthrough, knowledge, changelog, and DOX synchronization.

Excluded:

- Any `casmRunPass`/`casm.s` production call site for `.INCLUDE` (WP47).
- Include-event recording, Pass 2 replay, or correspondence checks (WP47).
- Included-source diagnostic filename correctness (still CLI-index-based;
  unifying it with the catalog is WP48's job) or bounded traceback (WP48).
- Saving/restoring per-frame diagnostic echo state (Scope Decision 3) --
  **flagged by the user for later reconsideration**, not to be revisited
  silently inside this WP without a fresh conversation.
- Device/name canonicalization changes (WP45, unaffected).

## Expected Files

| File | Planned action |
| --- | --- |
| `src/external/casm/source.s` | frame stack, `sourceFramePush`, rewired `sourceRefill`/`srCheckFileBoundary`, shared echo/offset reset helper |
| `src/external/casm/common.inc` | `CASM_INCLUDE_MAX_DEPTH`, diagnostics `$35-$36` |
| `src/external/casm/diagnostics.s` | messages and table bounds for `$35-$36` |
| `tests/src/casm_frame/casm_frame.s` | new dedicated harness |
| `cmake/GenerateCasmTestFixtures.cmake`, `CMakeLists.txt` | new fixtures, target, `casm_overflow_test_d64` packaging |
| `wiki/tasks/casm.md`, `brain/task.md` | synchronized task state |
| `brain/KNOWLEDGE.md`, `CHANGELOG.md` | durable verified result at closeout |
| `brain/walkthroughs/2026-07-26-casm-phase9-wp46-frame-stack-nested-traversal-and-cycle-detection.md` | evidence and manual steps |
| `src/external/casm/AGENTS.md` | only if implementation changes a durable local contract |

## Harness Design and Test Matrix

`tests/src/casm_frame/casm_frame.s` links `include.s`, `fileio.s`,
`source.s`, `state.s`, `lexer.s`, `parser.s`, `opcodes.s`, `emit.s`,
`expr.s`, `diagnostics.s` (needed for real echo-buffer verification, unlike
`test_casm_catalog`'s stubbed `diagPrintFatal`), `resources.s`,
`vmm_store.s`, `symbols.s`, `reloc.s` -- the same whole-object surface as
`test_casm_pass1`, plus `include.s`. Its own driver loop calls
`parserParseStatement` directly and, on a parsed `.INCLUDE` statement,
manually performs what WP47's real dispatch will eventually do: resolve
the operand via `includeCatalogLoad`, read `CasmIncludeRecordStage`, and
call `sourceFramePush` -- proving the same sequence a real caller will use,
without needing `casmRunPass` itself.

Required cases:

- single push/pop: a parent fixture with statements before and after one
  `.INCLUDE`, a child fixture with its own statements; verify tokens,
  lines, and columns are correct throughout, including the parent's
  correct line/column resuming exactly where it left off after the
  child's automatic EOF-triggered pop;
- nested push/pop two and three levels deep;
- depth-17 rejection (`CASM_DIAG_INCLUDE_DEPTH_EXCEEDED`) with no state
  change;
- direct cycle (A includes A) and indirect cycle (A includes B includes
  A) both rejected (`CASM_DIAG_INCLUDE_CYCLE_DETECTED`);
- sequential reinclusion after a prior frame already returned is legal
  (not treated as a cycle, since it is no longer on the active chain);
- pending-CR never crosses a frame boundary (a parent ending in a bare CR
  immediately before an `.INCLUDE`, a child starting with LF, must not
  collapse into one CRLF -- and the same the other direction, into a
  child's own trailing CR and the parent's next byte);
- the shared `CasmIoBuffer` is correctly invalidated and refilled across a
  push and a pop (no frame stores or relies on a stale copy);
- diagnostic echo/offset reset: a fixture that fails immediately after a
  root transition, a push, and a pop each show no "previous line" text
  (absent, not any other file's text) -- proving Scope Decision 2/3
  together;
- the pre-existing WP34 latent case: two top-level files sharing a line
  number, a diagnostic on the second file's matching line shows that
  file's own text, not the first's;
- existing lexer/parser/source/catalog harnesses remain unchanged and
  pass.

## Atomic Increments

1. After explicit approval, mark WP46 active in Taskwarrior,
   `wiki/tasks/casm.md`, and `brain/task.md`.
2. Add `common.inc` constants and diagnostics `$35-$36` with compile-time
   assertions; add `diagnostics.s` messages/table entries.
3. Add the frame stack BSS arrays and `sourceResetBoundaryEcho`; extend
   `srCheckFileBoundary` to call it (closing the pre-existing WP34 gap in
   isolation, independently testable before any push/pop code exists).
4. Implement `sourceFramePush` (depth/cycle checks, state save, child
   entry).
5. Rewire `sourceRefill`'s cap computation and EOF path into the
   depth-aware retry loop (automatic pop), per Dependency Review findings
   1-2.
6. Add and build `tests/src/casm_frame/`; package it on
   `casm_overflow_test_d64`.
7. Run static, narrow, regression, image, artifact, and no-change-build
   checks; create the walkthrough and present runtime instructions to the
   user.
8. After user runtime verification and explicit completion approval only,
   increment CASM's version-only stage, rebuild, synchronize closeout
   records, and complete WP46. Do not activate WP47 automatically.

## Failure and Cleanup

- `sourceFramePush`'s depth/cycle checks run before any state mutation;
  a rejected push leaves every frame-stack field, the live cursor, and
  the echo buffers completely untouched.
- Automatic pop only ever restores previously-saved, known-good state; it
  cannot itself fail (no OS call, no allocation).
- No new resource (file handle, VMM allocation) is acquired by this WP:
  frame push/pop only manipulates already-loaded VMM-store offsets and
  BSS bookkeeping.

## Verification

- `git diff --check` and all relevant ca65 compile-time assertions pass.
- `tests/src/casm_frame` passes its complete matrix in the supported local
  emulator, as performed by the user (never the broken `c64-testing` MCP
  or a web emulator).
- Existing standalone lexer, parser, expression, symbol, VMM, relocation,
  include-grammar, and catalog regression targets build without behavior
  changes.
- `test_casm_pass1`/`test_casm_passcheck` (both link `source.s` whole)
  continue to fit their existing envelope, or a measured overflow is
  presented to the user before any amendment.
- Two consecutive `cmake --build build --target casm` builds hold the same
  `BUILD_CASM` value after the first content-driven increment.
- `image_d64`, `test_image_d64`, and `casm_overflow_test_d64` build clean.
- Confirm `casmRunPass`'s `.INCLUDE` behavior is byte-for-byte unchanged
  from WP45 (still `CASM_DIAG_NOT_IMPLEMENTED`, zero production call site
  for the new frame API).

## Documentation, Task, and DOX Updates

- Keep Taskwarrior, `wiki/tasks/casm.md`, and `brain/task.md` synchronized
  at activation, verification, and closeout.
- Record stable implementation findings in `brain/KNOWLEDGE.md`, including
  the fixed pre-existing WP34 echo gap and the explicit "revisit
  save/restore echo state" marker from Scope Decision 3.
- User-visible change in `CHANGELOG.md`; evidence/manual confirmation in
  the walkthrough.
- Re-read the root, `src`, `src/external`, `src/external/casm`, `tests`,
  `wiki`, and `wiki/tasks` DOX chain before implementation and perform a
  closeout DOX pass.
- Update `src/external/casm/AGENTS.md` only if implementation establishes
  or changes a durable local contract (the frame array layout, once
  frozen by real code rather than this plan alone).

## Stop Conditions

Stop, amend this plan, and request renewed approval if:

- the depth-aware retry loop cannot be expressed within `sourceRefill`
  without breaking its documented single-refill-per-call contract for
  every existing (non-nested) caller;
- cycle/depth checks cannot run before any state mutation;
- the shared echo/offset reset helper turns out to need per-frame
  save/restore after all (contradicts Scope Decision 3 -- stop and ask
  the user rather than silently switching approaches);
- code/BSS growth threatens the current `$3E00` MAIN envelope for
  `test_casm_pass1`/`test_casm_passcheck` beyond a small, presentable
  amendment;
- `tests/src/casm_frame` cannot exercise the real `source.s`/`include.s`
  ABI without duplicating production logic;
- any existing parser, lexer, source, catalog, or diagnostic-rendering
  behavior regresses.

## Completion Gate

WP46 is complete only after this plan is explicitly approved, implementation
and the full verification matrix pass, the user performs the runtime
walkthrough, the user explicitly approves completion, CASM advances its
version-only stage with a stable no-change build, and all durable records
agree. Completion does not activate WP47.

## Progress

- 2026-07-26: Drafted. User confirmed all three scope forks (standalone
  wiring, fixing the pre-existing WP34 echo gap alongside the new
  nested-frame case, and reset-not-save/restore echo/offset state with an
  explicit note to revisit that trade-off later) before this plan was
  written. Awaiting approval to activate.
- 2026-07-26: User approved. Activated WP46 in Taskwarrior, `wiki/tasks/casm.md`,
  and `brain/task.md`.
- 2026-07-26: Increment 2 added `common.inc`'s `CASM_INCLUDE_MAX_DEPTH` and
  diagnostics `$35-$36`, plus `diagnostics.s` messages/table entries.
- 2026-07-26: Increments 3-5 added the frame stack BSS arrays,
  `sourceResetBoundaryEcho` (called from both the extended
  `srCheckFileBoundary` and the new push/pop paths), `sourceFramePush`
  (depth/cycle checks before any mutation), and rewired `sourceRefill`'s
  cap computation and EOF path into the depth-aware retry loop
  (`srEofOrPop` / `sourceFramePopInternal`, private -- pop is never a
  separate exported call). `casm` measured a 221-byte overflow at the
  existing `$3E00` envelope; the user chose the tighter "exactly what's
  needed" amendment to `$4000` (292 bytes headroom) over a more generous
  one. `test_casm_pass1`/`test_casm_passcheck`/`test_casm_catalog` (all
  link `source.s` whole) needed matching envelope bumps.
- 2026-07-26: Increment 6 added the 8-case `tests/src/casm_frame/` harness
  (ten new real-CASM-syntax fixtures via
  `cmake/GenerateCasmTestFixtures.cmake`, bare lowercase disk names
  matching the established cc1541/ca65 case-pairing convention rather
  than the `.S`-suffixed convention `test_image_d64` uses for real CASM
  source, to avoid risking a second naming mismatch after WP45's own),
  wired into `CMakeLists.txt` and `casm_overflow_test_d64` packaging.
  Five cases drive real lexer/parser traversal across genuine push/pop
  boundaries (single, three-level nested, sequential reinclusion,
  pending-CR non-crossing, and the pre-existing root-boundary echo-reset
  fix); three exercise depth/cycle rejection synthetically (fabricated
  catalog indices, never traversed for real), mirroring
  `test_casm_catalog`'s own precedent of not requiring real fixture files
  for capacity-boundary cases.
- 2026-07-26: Increment 7 verification: `test_casm_frame` build 1001
  passes and holds stable on a no-change rebuild; `casm` build 1173 holds
  stable (MAIN 16,092/16,384 bytes, 292 bytes headroom); all other
  standalone CASM harnesses rebuild successfully; `image_d64`,
  `test_image_d64`, and `casm_overflow_test_d64` all build clean (59
  blocks free); `git diff --check` passes. Walkthrough drafted:
  `brain/walkthroughs/2026-07-26-casm-phase9-wp46-frame-stack-nested-traversal-and-cycle-detection.md`.
  Awaiting the user's runtime confirmation of `test_casm_frame` and
  explicit completion approval before the version-only increment.
- 2026-07-26: First runtime run failed `fffff...` -- every case driving
  real lexer/parser traversal failed while the three synthetic
  depth/cycle cases passed. Four distinct production defects were found
  and fixed, each masking the next (full detail in the walkthrough):
  (1) `lexerFill` snapshotted token provenance *before* `sourceNextByte`,
  going stale exactly when that call resolved a child's EOF and popped --
  fixed with new `CasmSourceResult*` fields captured inside
  `sourceFetchPhysical`; (2) that capture clobbered `A` at `sfpEof`,
  destroying the `CASM_SOURCE_EOF` return; (3) depth-0 traversal had no
  end cap of its own and overran into `.INCLUDE` children appended
  mid-traversal (`CasmSourceLoadedLen` grows) -- fixed with a fixed
  `CasmSourceTopLevelEndLo/Hi` snapshot; (4) `sourceFramePush` saved
  `CasmSourceVmmCursor` (the bulk-refill read head, already at the file's
  end for any sub-256-byte fixture) rather than the logical parse
  position -- fixed to `cursor - (blockLen - blockIndex)`.
  **Fix 4 exposed that `frSinglePushPop` had been passing for the wrong
  reason**: the pop re-read the child's bytes while the parent's line
  counter read 4, so the re-read `C1`/`C2` were stamped lines 4/5 --
  coincidentally matching the expected `P3=4, P4=5`. Two independent bugs
  were cancelling into a green test.
  All 8 cases now pass, confirmed by the user on the clean
  (instrumentation-removed) `test_casm_frame` build 1023, which fits the
  original `$4000` envelope -- the temporary `$4200` bump was reverted, so
  no envelope amendment ships. `casm` build 1190 holds stable; full suite,
  all three images, and `git diff --check` clean. Still awaiting explicit
  completion approval before the version-only increment.
- 2026-07-26: User approved completion. CASM advanced its version-only
  stage `0.1.47` -> `0.1.48` (build 1191), verified stable across a
  no-change rebuild. WP46 marked complete in Taskwarrior,
  `wiki/tasks/casm.md`, and `brain/task.md` (WP45's own stale `[ ]`
  checkbox in `wiki/tasks/casm.md` corrected to `[x]` in the same pass --
  it had been Completed in Taskwarrior since WP45's own closure).
  Durable findings recorded in `brain/KNOWLEDGE.md`; user-visible entry
  added to `CHANGELOG.md`, scoped to the one externally observable
  symptom (wrong diagnostic line numbers) since the other three fixes sit
  in code paths with no production call site yet. DOX closeout pass
  performed. **WP46 complete.** WP47 is unblocked in Taskwarrior by
  dependency resolution but deliberately not activated.
