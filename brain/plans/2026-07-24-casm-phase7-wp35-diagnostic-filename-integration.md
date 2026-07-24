---
feature: casm-phase7-wp35-diagnostic-filename-integration
created: 2026-07-24
status: planned
---

# Plan: CASM Phase 7 WP35 - Diagnostic Filename Integration

## Objective

Implement Contract item 5 of the Phase 0C.10 freeze
(`brain/plans/2026-07-23-casm-phase7-wp32-prerequisite-reconciliation.md`):
when a diagnostic fires during a multi-file assembly, print which
top-level source file it came from. WP34 already made
`CasmSourceFileId`/line/column *correct* across file boundaries; WP35 makes
that identity *visible* in a fatal diagnostic's location trailer. This
closes the last unchecked item in `wiki/tasks/casm.md`'s Phase 7
Acceptance list.

Taskwarrior: to be created after this plan's approval, mirroring WP34's
child-task creation under the CASM Phase 7 milestone
(`1a0d0dc8-3267-4885-aa83-adf923d56422`).

Prerequisite: CASM Phase 7 WP34 is complete and approved (CASM `0.1.36`
build 1139, multi-file CLI and file-boundary provenance shipped).
Approval of this plan is required before activation or source edits, per
the CASM `AGENTS.md` gate. Active on `feature/casm-phase7-wp35` from
`feature/casm-phase7-wp34`'s tip (`20b0b98`).

## Baseline

- CASM `0.1.36` build 1139. `MAIN: start = $3400, size = $3500` (13568
  bytes). Measured via `ld65 -m`: CODE `$2311` (8977) + RODATA `$091C`
  (2332) + BSS `$7CE` (1998) = 13307 of 13568 bytes -- **261 bytes
  headroom**.
- Zero page `$70-$8F` fully allocated; WP35 needs no new zero-page cell
  (Dependency Review item 5 below).
- `CasmSourceFileId` (state.s) is already driven correctly across file
  boundaries by WP34's `srCheckFileBoundary`. `CasmLookaheadFileId`
  (state.s) and `CasmTokenRecord + CASM_TOKEN_REC_FILE_ID` (common.inc)
  already carry file identity alongside line/column, unchanged since
  Phase 3. None of this is yet read by `diagnostics.s`.
- `diagnostics.s`'s three location-recording routines
  (`diagSetLocFromLookahead`, `diagSetLocFromToken`, `diagSetLocFromStmt`)
  and `diagStampStmtLoc` currently copy line/column only, confirmed by
  direct re-inspection unchanged since WP15.

## Dependency Review and Discrepancies Reconciled

Direct tracing of the current `diagnostics.s`/`state.s`/`cli.s` against the
Phase 0C.10 contract found the following, beyond what WP32's own review
already covered:

1. **WP32's "the 40-column diagnostic window is already full" rationale
   for gating filename printing does not actually describe the
   constraint it was invoked for.** `CASM_DIAG_WINDOW_WIDTH`/
   `CASM_DIAG_INDENT` (`common.inc`) bound the *rendered source line and
   caret* -- a different print statement (`diagPrintLineAndCaret`) from
   the "AT LINE n, COL c (OFFSET o)" trailer (`diagPrintSourceContext`)
   this WP touches. Confirmed by direct inspection that the trailer
   already has no such budget today: `"AT LINE "` (8) + up to 5 line
   digits + `", COL "` (6) + up to 3 column digits + `" (OFFSET "` (10) +
   up to 3 offset digits + `")"` (1) + optional `" BYTE $XX"` (9) reaches
   ~45 characters in the worst case already, silently wrapping to a second
   physical screen row -- a pre-existing, accepted behavior, not something
   WP35 introduces. **The real, still-valid reason to gate filename
   printing on `CasmSourceCount > 1` is keeping every single-file
   diagnostic's exact printed text byte-identical to every prior phase's**,
   not a hard column budget. Recorded here as a correction to WP32's
   stated rationale, not a reason to change the gating decision itself
   (still correct, just for a different reason) -- the same class of
   correction WP26/WP33 each made to a stale prior-WP rationale.
2. **The filename to print is exactly what the user typed on the command
   line, not a canonicalized on-disk name.** `cliCopySource`
   (`cli.s`) copies `CommandBuffer` bytes verbatim into
   `CasmSourceNames`, case and all -- confirmed by direct inspection, no
   normalization step exists anywhere in the CLI path. This matches user
   expectation (the diagnostic echoes what they actually invoked) and
   requires no new formatting logic.
3. **The filename pointer lookup already exists and is already exported:
   WP34's `cliSourceSlotLo`/`cliSourceSlotHi` compile-time table**
   (`cli.s`, exported specifically so `source.s`'s `sourceLoad` could reuse
   it) indexes directly by a file identifier 0..7 to a ready-to-print
   null-terminated pointer -- exactly the shape `diagPrintSourceContext`
   needs for `CasmDiagLocFileId`. No new lookup mechanism is required,
   only a new import of the same table `source.s` already established.
4. **Both standalone harnesses that link the real `diagnostics.s`
   (`test_casm_pass1`, `test_casm_passcheck`) already carry the exact
   stand-in symbols this WP's new imports need, as a direct consequence of
   WP34's own fix.** Neither links `cli.s`; WP34 already gave both their
   own `CasmSourceNames`/`CasmSourceCount`/`cliSourceSlotLo`/`Hi`
   stand-ins so `sourceLoad` would link. `diagPrintSourceContext` importing
   the same three names resolves against those same stand-ins with zero
   further harness changes -- confirmed by cross-checking exactly which
   symbols WP34 added against exactly which symbols this WP needs; they
   are identical. `casm_symbols.s`/`casm_vmm.s`/`casm_expr.s` are
   unaffected: each stubs `diagPrintFatal` itself and never links the real
   `diagnostics.s` translation unit at all.
5. **No new zero-page cell is needed.** The filename-pointer lookup uses
   ordinary `A`/`X`/`Y` register work (`ldx CasmDiagLocFileId`, index the
   table, stage into `X`/`Y` for `diagPrintString`), mirroring the exact
   pattern already used for the same table in `sourceLoad`. No indirect
   `(zp),Y` addressing is needed here at all, since `diagPrintString`
   already takes its pointer in `X`/`Y` directly.
6. **`CasmDiagStateEnd`'s size assert (`state.s`) is a hygiene check on
   this module's own bookkeeping, not a cross-module ABI other files size
   against -- unlike `CASM_TOKEN_REC_SIZE`, which `parser.s`/`lexer.s`
   both depend on.** Growing it in place (two new isolated fields, each
   with exactly one clear write site) is lower-risk than WP28's
   `CasmParserStmt` case, where three separate *wholesale*-record writes
   would each have needed updating for an in-place grow -- the precedent
   that motivated keeping `CasmLabelName` external. **Resolved (Contract
   item 1 below): `CasmDiagLocFileId`/`CasmStmtLocFileId` grow the existing
   `CasmDiagState` block in place**, next to their respective sibling
   groups, rather than opening a new external block the way `CasmLabelName`
   and WP33/34's VMM state did.

## Contract to Freeze (Phase 0C.13)

Per the user's confirmed decision (2026-07-24: filename on its own line,
before the location trailer):

1. **`state.s`'s `CasmDiagState` block grows by 2 bytes in place**
   (Dependency Review item 6): `CasmDiagLocFileId: .res 1` immediately
   after `CasmDiagLocByte`; `CasmStmtLocFileId: .res 1` immediately after
   `CasmStmtLocColumn`. `CasmDiagStateEnd - CasmDiagStateStart`'s assert
   updates from 530 to 532.
2. **All three location-recording routines (`diagnostics.s`) gain one more
   field copy each**, sourcing file identity from whatever they already
   read line/column from: `diagSetLocFromLookahead` copies
   `CasmLookaheadFileId` -> `CasmDiagLocFileId`; `diagSetLocFromToken`
   copies `CasmTokenRecord + CASM_TOKEN_REC_FILE_ID` -> `CasmDiagLocFileId`;
   `diagSetLocFromStmt` copies `CasmStmtLocFileId` -> `CasmDiagLocFileId`.
   `diagStampStmtLoc` gains the matching fourth copy:
   `CasmTokenRecord + CASM_TOKEN_REC_FILE_ID` -> `CasmStmtLocFileId`.
3. **`diagPrintSourceContext` gains a new filename-printing prefix**,
   inserted immediately after the existing `CasmDiagLocValid` gate and
   before the existing `"AT LINE "` print: if `CasmSourceCount > 1`
   (`.import CasmSourceCount`, `cli.s`), print a new message (`"IN FILE "`
   or equivalent short label) followed by the filename looked up via
   `CasmDiagLocFileId` indexing the existing exported
   `cliSourceSlotLo`/`cliSourceSlotHi` table (`.import` both from
   `cli.s`, reusing WP34's table unchanged -- Dependency Review item 3),
   then a newline, before falling through to the unchanged existing
   trailer. When `CasmSourceCount <= 1`, this entire block is skipped and
   the existing trailer is byte-for-byte unchanged from every prior
   phase's output (Dependency Review item 1's real justification). No
   truncation logic for a long filename: consistent with the existing
   trailer's own established behavior, it simply wraps to a second
   physical screen row in the worst case.
4. **No new `CASM_DIAG_*` identifier and no new failure mode.** This WP
   only changes what a diagnostic *prints*, never whether one fires or
   what value it carries.
5. **No `test_casm_pass1`/`test_casm_passcheck` source change is expected**
   (Dependency Review item 4) -- both already carry the exact stand-in
   symbols this WP's new imports resolve against, as a direct consequence
   of WP34's own fix. Confirmed by build, not assumed (Verification Plan
   below).

## Scope

Included in WP35:

- `state.s`: `CasmDiagLocFileId`/`CasmStmtLocFileId`, in-place growth of
  the existing `CasmDiagState` block.
- `diagnostics.s`: `diagSetLocFromLookahead`/`diagSetLocFromToken`/
  `diagSetLocFromStmt`/`diagStampStmtLoc` each gain one field copy;
  `diagPrintSourceContext` gains the conditional filename prefix and its
  two new imports (`CasmSourceCount`, reusing `cliSourceSlotLo`/`Hi`
  already imported by `source.s` elsewhere in the link set).
- New multi-file diagnostic fixtures proving both a first-file and a
  non-first-file diagnostic report the correct filename (Verification
  Plan below).

Excluded from WP35:

- Any change to when or why a diagnostic fires (WP34's behavior is
  otherwise untouched).
- Any change to `sourceLoad`/`sourceRefill`/the CLI grammar.
- Any MAIN envelope size change beyond what this WP's own measurement
  justifies (not expected to be needed, per the small scope, but not
  pre-ruled-out).

## Expected Files

| File | Action |
| --- | --- |
| `brain/plans/2026-07-24-casm-phase7-wp35-diagnostic-filename-integration.md` | this document |
| `src/external/casm/state.s` | Modify: `CasmDiagLocFileId`/`CasmStmtLocFileId`, updated size assert |
| `src/external/casm/diagnostics.s` | Modify: four routines gain a file-identity copy; `diagPrintSourceContext` gains the filename prefix and two new imports |
| `src/external/casm/casm.s` | Modify: version-only stage increment at completion |
| `src/external/casm/BUILD_CASM` | build-managed increment |
| `cmake/GenerateCasmTestFixtures.cmake` | Modify: new fixture(s) for a first-file diagnostic (non-first-file case reuses `casmmfcr1`/`casmmfcr2`) |
| `CMakeLists.txt` | Modify: new fixture wiring if a new `.seq` pair is added |
| `wiki/tasks/casm.md`, `brain/task.md`, `brain/KNOWLEDGE.md`, `CHANGELOG.md` | Closeout updates |

## ABI, Storage, and Runtime Effects

- New `state.s` fields: `CasmDiagLocFileId`, `CasmStmtLocFileId` (1 byte
  each, `CasmDiagState` block).
- `diagnostics.s` gains two new imports (`CasmSourceCount`,
  `cliSourceSlotLo`/`cliSourceSlotHi` -- three names total) from `cli.s`.
- No diagnostic identifier, raise condition, or PRG byte output changes.
  Only printed diagnostic *text* for multi-file assemblies changes;
  single-file diagnostic text is provably unchanged (gated on
  `CasmSourceCount > 1`).
- MAIN size: not pre-sized; expected to fit within the existing 261-byte
  headroom given the small scope, measured once written per precedent.

## Verification Plan

1. **Single-file diagnostic text unchanged (regression)**: re-run a
   representative sample of existing single-file diagnostic fixtures
   (`casmbadb`, `casmcol1`, `casmshort`-equivalent path) and confirm the
   printed text is byte-for-byte identical to before this WP -- no `"IN
   FILE"` line appears.
2. **Byte-identical trusted references unaffected (regression)**: all 15
   existing `CASM_REF_NAMES` entries (12 pre-WP34 plus `casmmf1`/
   `casmmf2`/`casmmf3`) still produce identical PRG bytes -- this WP never
   touches emission.
3. **Non-first-file diagnostic reports the correct filename**: reuse
   `casmmfcr1.seq`/`casmmfcr2.seq` unmodified (already raises
   `CASM_DIAG_INVALID_SOURCE_BYTE` in the second file) -- confirm the
   output now reads `IN FILE CASMMFCR2.S` (or whatever exact case the
   fixture is invoked with) immediately before `AT LINE 2, COL 1 (OFFSET
   0)`.
4. **First-file diagnostic reports the correct filename**: new fixture
   pair with the invalid byte in the *first* file instead, proving
   `CasmDiagLocFileId == 0` prints correctly too, not just non-zero
   values.
5. **Standalone harnesses still link and pass**: `TEST_CASM_PASS1` (all 7)
   and `TEST_CASM_PASSCHECK`, confirming Dependency Review item 4's
   "no harness source change expected" by build outcome, not assumption.
6. Build both relocation bases and `test_image_d64`; confirm a no-change
   rebuild holds `BUILD_CASM` stable before any source edit and increments
   exactly once after.
7. Every failing case is investigated before completion is requested,
   matching every prior WP's precedent.

## Atomic Implementation Increments

1. Grow `state.s`'s `CasmDiagState` block by 2 bytes; update the size
   assert.
2. Update `diagSetLocFromLookahead`/`diagSetLocFromToken`/
   `diagSetLocFromStmt`/`diagStampStmtLoc` in `diagnostics.s`.
3. Add the conditional filename prefix to `diagPrintSourceContext`; add
   the two new imports.
4. Add the new first-file-diagnostic fixture pair; wire into
   `CMakeLists.txt` if a new `.seq` pair is needed.
5. Build `casm`, `test_casm_pass1`, `test_casm_passcheck`, and
   `test_image_d64`; run the full verification matrix in VICE (ask the
   user); investigate and resolve any failure per the Stop Conditions
   below before proceeding.
6. Measure MAIN headroom via `ld65 -m`; propose a size bump only if
   needed.
7. Apply the version-only completion increment; confirm no-change rebuild
   stability; update `wiki/tasks/casm.md` (checking the final Phase 7
   Acceptance item), `brain/task.md`, `brain/KNOWLEDGE.md` (Phase 0C.13
   as-built record), `CHANGELOG.md`, Taskwarrior; draft the walkthrough
   and request completion approval.

## Failure and Cleanup

No new runtime failure mode or cleanup path: this WP only changes what a
diagnostic prints, never resource lifecycle. A newly-discovered defect
during verification is handled exactly as every prior WP's precedent:
presented to the user with root cause and a proposed fix before any
change, applied only with explicit approval.

## Documentation and DOX Closeout

Update this plan, `brain/KNOWLEDGE.md` (new Phase 0C.13 as-built section
amending Phase 0C.10 with the exact implemented shape),
`wiki/tasks/casm.md` (checks the final Phase 7 Acceptance item: this
closes that checklist entirely, pending WP36's own consolidated
verification), `brain/task.md`, `CHANGELOG.md`, Taskwarrior, and a new
walkthrough. `AGENTS.md` needs no change (it does not currently document
diagnostic text format as a durable contract).

## Stop Conditions

Stop if CASM Phase 7 WP34 is not complete and approved. Stop if any
fixture reveals a defect whose scope or fix is not small and
well-understood enough for the user to approve fixing in place. Stop if a
further material discrepancy against this freeze is found during
implementation, requiring this document to be amended and re-approved.

## Completion Gate

WP35 is complete when: the full verification matrix above passes; single-
file diagnostic text is confirmed byte-identical to before this WP; MAIN
headroom is measured and any needed size bump is applied and justified; a
no-change rebuild holds `BUILD_CASM` stable; both `image_d64` and
`test_image_d64` build clean; and the user explicitly approves the
walkthrough. This closes WP35 but does not activate WP36, which remains
separately gated per `AGENTS.md`.

## Progress

- 2026-07-24: Drafted after confirming CASM Phase 7 WP34's completion gate
  (`0.1.36` build 1139). Traced the current `diagnostics.s`/`state.s`/
  `cli.s` in detail rather than re-describing WP32's freeze at a summary
  level, and found WP32's own stated rationale for gating filename
  printing ("the 40-column diagnostic window is already full") describes
  a different print statement than the one this WP touches -- the
  trailer this WP extends already silently wraps past 40 columns in its
  own worst case today, so the real and still-valid reason to gate on
  `CasmSourceCount > 1` is single-file text stability, not a hard column
  budget. Found the filename-pointer lookup mechanism (WP34's
  `cliSourceSlotLo`/`cliSourceSlotHi` table) already exists and is already
  exported for exactly this kind of reuse, and that both standalone
  harnesses needing new imports from `cli.s` already carry the exact
  stand-in symbols WP34's own fix gave them -- no harness source change
  expected, confirmed by build rather than assumed. Asked the user how
  the filename should be presented (own line before the location vs.
  appended to the existing trailer); the recommended option (own line,
  file first) was confirmed. Created `feature/casm-phase7-wp35` from
  `feature/casm-phase7-wp34`'s tip (`20b0b98`). Awaiting user approval
  before Taskwarrior child-task creation or any source edit.
- 2026-07-24: Approved and implemented exactly as planned, with no
  material deviations. `test_casm_pass1`/`test_casm_passcheck` needed
  zero source changes, confirmed by a successful build/link rather than
  assumed, exactly as predicted. User ran the full verification matrix
  (single-file diagnostic text regression, byte-identical trusted
  references, both new filename fixtures, both standalone harnesses) and
  confirmed: "all test pass." Applied the version-only completion
  increment: final CASM `0.1.37` build 1141, no-change rebuild stable, all
  three disk images build clean, MAIN headroom 189 of 13568 bytes (no
  bump needed). While updating closeout docs, found and fixed a
  documentation-only bookkeeping error dating back to WP32: the
  Taskwarrior UUID citations for WP32-WP35 in `brain/task.md`,
  `wiki/tasks/casm.md`, and two prior walkthroughs had been
  cross-assigned to the wrong work packages since a bulk `task ... uuids`
  query's output order was assumed (incorrectly) to match input order.
  The actual Taskwarrior task data itself was never affected -- every
  task's own annotations always matched its real description correctly;
  only the UUID strings quoted in prose were wrong. Corrected all five
  citations to the verified mapping (WP32=`25e69c58`, WP33=`ac152eb9`,
  WP34=`035c0295`, WP35=`7fedccb3`, WP36=`c69b675f`, unchanged). Recorded
  the Phase 0C.13 as-built amendment in `brain/KNOWLEDGE.md`, updated
  `wiki/tasks/casm.md` (checking the final Phase 7 Acceptance item --
  all four are now checked), `brain/task.md`, `CHANGELOG.md`, Taskwarrior,
  and drafted the walkthrough. **WP35 is complete.** WP36 (verification,
  walkthrough, and Phase 7 completion gate) remains separately gated and
  unstarted.
