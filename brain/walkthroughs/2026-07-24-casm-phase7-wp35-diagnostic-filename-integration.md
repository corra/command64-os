---
feature: casm-phase7-wp35-diagnostic-filename-integration
created: 2026-07-24
status: complete
---

# Walkthrough: CASM Phase 7 WP35 Diagnostic Filename Integration

Plan: `brain/plans/2026-07-24-casm-phase7-wp35-diagnostic-filename-integration.md`

Taskwarrior: `7fedccb3-8464-4b4d-a49e-2ac200e99dd4` (WP35); part of the CASM
Phase 7 milestone `1a0d0dc8-3267-4885-aa83-adf923d56422`.

## Outcome

WP35 implemented Contract item 5 of the Phase 0C.10 freeze: a fatal
diagnostic raised during a multi-file assembly now prints which top-level
source file it came from, closing the last unchecked item in
`wiki/tasks/casm.md`'s Phase 7 Acceptance list. WP34 already made
`CasmSourceFileId`/line/column *correct* across file boundaries; this WP
makes that identity *visible* in the diagnostic's location trailer,
gated on `CasmSourceCount > 1` so single-file diagnostic text stays
byte-identical to every prior release.

Implementation matched the plan closely, with no material deviations.

## Baseline

| Item | Value |
| --- | --- |
| Branch | `feature/casm-phase7-wp35` |
| Branch point | `feature/casm-phase7-wp34` at `20b0b98` |
| Baseline version | `0.1.36` build 1139 |
| Plan approval | Approved as drafted, including the confirmed "own line, file first" presentation decision |

## Implementation

- `state.s`: `CasmDiagState` block grew in place by 2 bytes
  (`CasmDiagLocFileId` after `CasmDiagLocByte`, `CasmStmtLocFileId` after
  `CasmStmtLocColumn`), size assert updated 530 -> 532. Grown in place
  rather than kept external (unlike `CasmLabelName`/the WP33-34 VMM
  state): every field in this block, old and new, has exactly one clear
  write site, unlike `CasmParserStmt`'s three wholesale-record writers
  that motivated keeping state external in that earlier case.
- `diagnostics.s`: `diagSetLocFromLookahead` (from `CasmLookaheadFileId`),
  `diagSetLocFromToken` and `diagStampStmtLoc` (from
  `CasmTokenRecord + CASM_TOKEN_REC_FILE_ID`), and `diagSetLocFromStmt`
  (from `CasmStmtLocFileId`) each gained one more field copy.
  `diagPrintSourceContext` gained a new prefix: when `CasmSourceCount >
  1`, prints `"IN FILE "` followed by the filename (looked up by indexing
  WP34's exported `cliSourceSlotLo`/`cliSourceSlotHi` table with
  `CasmDiagLocFileId`, using the same register-staging pattern already
  established in `sourceLoad`) and a newline, before falling through to
  the existing, unchanged `"AT LINE..."` trailer.
- `cmake/GenerateCasmTestFixtures.cmake` / `CMakeLists.txt`: new fixture
  pair `casmmfdiag1.seq`/`casmmfdiag2.seq` (invalid byte in the first
  file), complementing the existing `casmmfcr1`/`casmmfcr2` non-first-file
  case.

## A Correction to the Prior Phase's Stated Rationale

WP32's original justification for gating filename printing on
`CasmSourceCount > 1` ("the 40-column diagnostic window is already full")
described `CASM_DIAG_WINDOW_WIDTH`/`CASM_DIAG_INDENT`, which bound the
*rendered source line and caret* -- a different print statement
(`diagPrintLineAndCaret`) from the `"AT LINE n, COL c (OFFSET o)"` trailer
this WP actually extends (`diagPrintSourceContext`). Direct inspection
found that trailer already has no such budget and already silently wraps
past 40 columns in its own worst case today (~45 characters: 5 line
digits + `", COL "` + 3 column digits + `" (OFFSET "` + 3 offset digits +
`")"` + an optional 9-character byte suffix). The real, still-valid reason
to gate on `CasmSourceCount > 1` is keeping every single-file
diagnostic's exact printed text byte-identical to every prior phase's,
not a column budget -- the gating *decision* was unchanged, only its
stated *justification* was corrected, matching the class of correction
WP26/WP33 each made to a stale prior-WP rationale.

## A Documentation Bookkeeping Error Found and Fixed

While updating this WP's closeout documentation, discovered that the
Taskwarrior UUID citations for WP32 through WP35 recorded in
`brain/task.md`, `wiki/tasks/casm.md`, and the WP33/WP34 walkthroughs had
been cross-assigned to the wrong work packages since WP32's own closeout.
The root cause: a single bulk `task 29 30 31 32 33 uuids` query issued
when the five WP32-WP36 tasks were first created returned five UUIDs, and
their *output order* was incorrectly assumed to match the *input ID
order* used in the query. Taskwarrior does not guarantee this.

Critically, **the actual Taskwarrior task data was never affected or
corrupted** -- every task's own `start`/`annotate`/`done` calls throughout
WP32-WP35 always operated on a task ID that was internally consistent at
the time (confirmed by cross-checking every task's `description` field,
set once at creation and immutable, against its own annotation history:
every task's annotations describe exactly the work its description says
it is). Only the UUID *strings quoted in prose* were wrong. Corrected all
five citations to the verified mapping: WP32 = `25e69c58-b1cf-4c43-8aa9-5ae79b015375`,
WP33 = `ac152eb9-f202-41e3-bdf5-8ce5af9a8a88`,
WP34 = `035c0295-ae69-4795-b85d-a0c113e80cb8`,
WP35 = `7fedccb3-8464-4b4d-a49e-2ac200e99dd4` (this WP),
WP36 = `c69b675f-def4-4fbb-a767-e32794e77af5` (unchanged, never cited incorrectly).

## Static Verification

- `casm` build 1140 (implementation) -> 1141 (version-only completion
  increment), no-change rebuild stable at each step.
- `image_d64`, `test_image_d64`, and `casm_overflow_test_d64` all build
  clean.
- MAIN measured via `ld65 -m`: CODE `$234E` (9038) + RODATA `$925` (2341)
  + BSS `$7D0` (2000) = 13379 of 13568 bytes -- 189 bytes headroom, no
  size bump needed.
- `test_casm_pass1`/`test_casm_passcheck` linked successfully with **zero
  source changes** -- confirmed by build outcome, not assumed: WP34's own
  harness fix already gave both the exact stand-in symbols
  (`CasmSourceNames`/`CasmSourceCount`/`cliSourceSlotLo`/`Hi`) this WP's
  new `diagnostics.s` imports needed.

## Runtime Verification

The user ran the full verification matrix and confirmed: "all test pass."

| Check | Result |
| --- | --- |
| Single-file diagnostic text (regression, e.g. `casmbadb`/`casmcol1`) | byte-identical to before this WP |
| Byte-identical trusted references (spot-checked) | still identical |
| `CASM CASMMFCR1.S CASMMFCR2.S` (non-first-file case) | `IN FILE CASMMFCR2.S` then `AT LINE 2, COL 1 (OFFSET 0)` |
| `CASM CASMMFDIAG1.S CASMMFDIAG2.S` (first-file case, `FileId == 0`) | `IN FILE CASMMFDIAG1.S` then `AT LINE 2, COL 1 (OFFSET 0)` |
| `TEST_CASM_PASS1` / `TEST_CASM_PASSCHECK` | both pass |

## Documentation and DOX Closeout

- `brain/KNOWLEDGE.md`: Phase 0C.13 as-built section added, amending
  Phase 0C.10 with the exact implemented shape and the rationale
  correction.
- `wiki/tasks/casm.md`: WP35 checked complete; all four Phase 7 Acceptance
  items now checked.
- `brain/task.md`: WP35 entry added and closed.
- `CHANGELOG.md`: Unreleased entry added.
- Taskwarrior: WP35 (`7fedccb3-8464-4b4d-a49e-2ac200e99dd4`) completed.
- Five stale Taskwarrior UUID citations (WP32-WP35, across `brain/task.md`,
  `wiki/tasks/casm.md`, and two walkthroughs) corrected -- see above.

## Completion

**CASM Phase 7 WP35 is complete**, per the completion gate in
`brain/plans/2026-07-24-casm-phase7-wp35-diagnostic-filename-integration.md`:
the full verification matrix passed, single-file diagnostic text is
confirmed byte-identical, MAIN headroom is measured (no bump needed), a
no-change rebuild holds `BUILD_CASM` stable, all three disk images build
clean, and the user confirmed the runtime results. All four Phase 7
Acceptance items are now checked. WP36 (verification, walkthrough, and
Phase 7 completion gate) remains separately gated and unstarted per
`AGENTS.md`.
