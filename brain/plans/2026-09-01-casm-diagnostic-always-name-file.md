---
feature: casm-diagnostic-always-name-file
created: 2026-09-01
status: complete
taskwarrior: 86170ef8-0d91-44eb-9330-6f921a76eaee (done)
depends-on: none (branches off main)
---

# Plan: CASM — Always Name the Source File in a Located Diagnostic

## Status

**Approved 2026-09-01; not started.** The user approved this plan, satisfying
the per-work-package plan gate in
`.agents/workflows/phased-implementation-planning.md`. Implementation, branch
creation, and task activation remain pending an explicit start instruction so
this work does not interfere with concurrent CASM/DASH development.

Standalone hardening task — **not** a numbered CASM Phase or Work Package
(same category as the 2026-08-31 "diag-table single-source-of-truth" task).
It branches off `main`, not off `feature/casm-phase14`.

Parent/master plan: `brain/plans/2026-07-16-casm-assembler-implementation-plan.md`
(§18 diagnostics, Phase 11 hardening lineage).

## Objective

Make **every** source-position CASM diagnostic name the physical file the
error is in. Today the renderer prints an `IN FILE <name>` line only when
`CasmSourceCount > 1` **or** the location is inside an `.INCLUDE`d frame
(`src/external/casm/diagnostics.s` ~line 866-880, the WP35/WP48 gate). A
build with a single top-level source — **including a single root that
`.INCLUDE`s other files** — omits the filename on any diagnostic whose
location resolves to that root, so:

- a root-file error in an include build prints no filename while errors in
  the *included* files do — the output is internally inconsistent, and the
  root-file diagnostic reads as context-free;
- pasted or scrolled-back diagnostic text from a single-file assemble is not
  self-describing.

**Delivers:** the `IN FILE <name>` line on every diagnostic that has a valid
recorded source location (`CasmDiagLocValid != 0`), regardless of
`CasmSourceCount` or include depth.

**Does NOT deliver / explicitly excluded:**

- Any change to diagnostics that have *no* source location — CLI parse
  errors, file-service errors, internal-state errors stay bare. "The file
  where the error is" only has meaning when a location was stamped.
- No new CLI flag. The behavior is unconditional (user decision 2026-09-01).
- No change to the `AT LINE / COL / OFFSET / BYTE` trailer, the line echo,
  the caret, or the `INCLUDED FROM` traceback format.
- No change to how `CasmDiagLocFileId` provenance is *computed* — unless
  Increment 1 uncovers a genuine stamping bug (see Scoping Decision 3 /
  Stop Conditions).
- Not folded into Phase 14; ships on its own patch release.

## Scoping Decisions (user-confirmed 2026-09-01)

1. **Behavior: always print**, for any diagnostic with a valid location,
   single-source case included. Non-located diagnostics stay bare.
2. **Sequencing: standalone task off `main` now.** Own branch, own patch
   version bump. `feature/casm-phase14` inherits this change on its next
   merge/rebase from `main`; the only expected conflict is `VERSION` /
   `BUILD_CASM` and the diagnostic fixtures' expected-output comments, both
   mechanical.
3. **Motivating gap: a located diagnostic that is NOT single-source yet
   still shows no filename.** The plan's first increment must reproduce and
   characterize this precisely and decide whether it is (a) purely the
   root-in-an-include-build suppression described above — fixed by the
   always-print change — or (b) a provenance-stamping bug where an
   include-frame location is recorded with a root (bit-7-clear)
   `CasmDiagLocFileId`. If (b), the fix for the stamping bug is in scope for
   this task; if it turns out larger than a localized stamp correction,
   Stop and disclose.

## Background — current mechanism (as-built)

- `diagnostics.s` keeps a `CasmDiagLoc*` record. Raise sites stamp it via
  `diagSetLocFromLookahead` / `diagSetLocFromLookaheadPos` /
  `diagSetLocFromToken` / `diagSetLocFromStmt`. **All four** set
  `CasmDiagLocFileId` (from `CasmLookaheadFileId` or `CasmStmtLocFileId`)
  and `CasmDiagLocValid`.
- `diagPrintSourceContext` self-gates on `CasmDiagLocValid`; then:

  ```
  lda CasmDiagLocFileId
  bmi @printFileName        ; bit 7 set = include frame -> always name it
  lda CasmSourceCount
  cmp #2
  bcc @skipFileName         ; root id AND < 2 CLI sources -> NAME SUPPRESSED
  @printFileName:
  ldx #<msgInFile ...       ; "IN FILE "
  lda CasmDiagLocFileId
  jsr diagPrintIncludeIdentity   ; root: cliSourceSlotLo/Hi,x ; frame: includeCatalogRead
  ...
  @skipFileName:
  ldx #<msgAtLine ...       ; "AT LINE "
  ```

- `diagPrintIncludeIdentity` already resolves a root id (bit 7 clear) to
  `cliSourceSlotLo/Hi, x` — for the single root that is slot 0, a
  ready-to-print name. **The renderer already has everything it needs**;
  the change is deleting the `CasmSourceCount` gate so `@printFileName`
  runs whenever a location is valid.
- Fatal path: `diagPrintFatal` tail-calls `diagPrintSourceContext` for the
  id ranges that carry a location; bare ids are unaffected and must stay
  bare.

## Technical Design

### Code change (`diagnostics.s`)

Replace the gate at ~866-870:

```
    lda CasmDiagLocFileId
    bmi @printFileName
    lda CasmSourceCount
    cmp #2
    bcc @skipFileName
@printFileName:
```

with an unconditional fall-through to the name print (drop the
`CasmSourceCount` load/compare/branch and the now-unused `@printFileName`
label if the assembler flags it; keep `@skipFileName` only if another path
still targets it — audit first). Net effect: whenever `CasmDiagLocValid` is
set, `IN FILE <name>` is emitted. `diagnostics.s` shrinks by a few bytes;
no MAIN-envelope risk, but confirm the `$7400` figure is unchanged.

`CasmSourceCount` import in `diagnostics.s` becomes unused **only if** no
other routine in the file references it — grep before removing the
`.import` (currently line 50). Leaving an unused import is harmless; a
dangling one is not.

Update the WP35/WP48 comment block (lines ~1736-1737, `msgInFile`) and the
`diagPrintSourceContext` header comment to state the new unconditional
behavior and note the old `CasmSourceCount > 1` rule as historical.

### If Increment 1 finds a provenance bug (Scoping Decision 3b)

Likely locus: the token record's `CASM_TOKEN_REC_FILE_ID` (consumed by
`diagStampStmtLoc` -> `CasmStmtLocFileId` -> `diagSetLocFromStmt`) or
`CasmLookaheadFileId`, not carrying the frame-flagged id while a child
frame is active. Fix is a localized stamp correction at the source/lexer
provenance write, plus a regression fixture. If the mis-stamp turns out to
be systemic (multiple layers, or Pass 1/Pass 2 disagreement on file id),
**Stop** and bring findings back for a separate plan.

## Atomic Increments

1. **Characterize the gap (no code change).** On a scratch branch off
   `main`, build (or hand-write) five `.seq`/multi-file fixtures and run
   each live under VICE against current CASM (`0.5.2` b1392), capturing the
   exact on-screen diagnostic block:
   - (a) single CLI root, no include, lexer error;
   - (b) single CLI root that `.INCLUDE`s a file, error **in the root**;
   - (c) same, error **in the included file**;
   - (d) two CLI sources, error in the second;
   - (e) nested include (root -> A -> B), error in B.
   Record for each: is `IN FILE` present, and is the named file **correct**.
   Conclude whether the motivating gap is 3a (suppression only) or 3b
   (provenance mis-stamp). Write findings into this plan's Progress log
   before touching production code.
2. **Remove the suppression gate** in `diagnostics.s` per Technical Design.
   If Increment 1 found a 3b provenance bug within a localized stamp, fix it
   here too. Native build clean: `casm` target, `image_d64`,
   `casm_phase13_test_d64` (or whichever diag fixtures live where),
   `test_image_d64`. Re-run Increment 1's five fixtures live: (a) now names
   the root; (b)-(e) unchanged except any that were wrong are now right.
3. **Regenerate expected outputs.** Update every affected
   expected-diagnostic comment in `cmake/GenerateCasmTestFixtures.cmake`
   (the WP15 source-context block ~line 184+, WP35 `casmmfdiag*`, WP48
   included-source fixtures, WP69 char-literal diag fixtures, any Phase
   11/12/13 fixture whose documented expectation shows an `AT LINE` with no
   preceding `IN FILE`). Audit host harnesses under `tests/src/casm_*` for
   any that string-compare full diagnostic **text** (most compare
   diagnostic **codes** — `casm_faultinject*` — and are unaffected; confirm
   `casm_directives`, `casm_bounds`, `casm_expr`, `casm_opcodes`,
   `casm_include`, `casm_frame` explicitly). Rebuild all test images.
4. **Documentation.** `wiki/casm-programmers-reference.md` §18 filename
   bullet + §18.1 example, `wiki/casm-utility.md` error-output section
   (~line 675-686), and the `docs/` and `release/docs/` mirrors of both —
   verify byte-identical with `cmp` after editing. `CHANGELOG.md` Unreleased
   -> Changed. Note the change in `wiki/tasks/casm.md`.
5. **Consolidated live verification + version.** Fresh together: every
   `test_casm_*` harness across its disks + the full diagnostic fixture set
   + a no-change rebuild (`casm.prg` byte-stable across two builds) + a
   deliberate error injected into one `src/external/dash/` source assembled
   natively, confirming the DASH filename now appears. `VERSION` ->
   `0.5.3` (patch; diagnostic-text improvement, no grammar/output-binary
   change), `BUILD_CASM` auto-increments. Walkthrough in
   `brain/walkthroughs/2026-09-01-casm-diagnostic-always-name-file.md` with
   COMP transcripts / VICE screenshots. Overlay `test` events per
   `feedback-fire-overlay-events-for-tests` (curl fallback if the
   `c64-overlay-api` MCP is still down).

## Expected Files

| File | Planned action |
| --- | --- |
| `brain/plans/2026-09-01-casm-diagnostic-always-name-file.md` | Create (this file); append Progress |
| `src/external/casm/diagnostics.s` | Modify — remove `CasmSourceCount` suppression gate; update comments; drop unused `.import` iff truly unused |
| `src/external/casm/source.s` or `lexer.s` | Modify **only if** Increment 1 finds a localized provenance mis-stamp |
| `cmake/GenerateCasmTestFixtures.cmake` | Modify — regenerate affected expected-diagnostic comments; possibly add a 3b regression fixture |
| `tests/src/casm_*/` | Modify — only harnesses that compare full diagnostic *text* (audit; expected: none or few) |
| `wiki/casm-programmers-reference.md`, `wiki/casm-utility.md` | Modify — §18 / error-output docs |
| `docs/casm-programmers-reference.md`, `docs/casm-utility.md` | Modify — mirror, `cmp`-verified |
| `release/docs/casm-programmers-reference.md`, `release/docs/casm-utility.md` | Modify — mirror, `cmp`-verified |
| `VERSION` | Modify — `0.5.3` |
| `CHANGELOG.md` | Modify — Unreleased → Changed |
| `wiki/tasks/casm.md` | Modify — note the task |
| `brain/walkthroughs/2026-09-01-casm-diagnostic-always-name-file.md` | Create (at completion) |
| memory `MEMORY.md` + reference file | Create — supersede the "prints when CasmSourceCount > 1" detail |

## Stop Conditions

Halt and get renewed direction if:

- Increment 1 shows the motivating gap is a **systemic** provenance
  mis-stamp (multiple layers, or Pass 1 vs Pass 2 file-id disagreement),
  not a localized stamp fix — that becomes its own plan;
- any `test_casm_*` harness fails for a reason other than a now-expected
  added `IN FILE` line, or a no-change rebuild alters `casm.prg`;
- CASM MAIN cannot stay within its approved `$7400` envelope (this change
  should *shrink* the binary — an increase means something else is wrong);
- a fatal or internal-error diagnostic that should stay bare starts
  emitting an `IN FILE` line (would mean a location is being stamped where
  it should not be — investigate the raise site, do not paper over it);
- the `docs/` or `release/docs/` mirror cannot be made `cmp`-identical to
  the `wiki/` source;
- the affected-fixture list turns out materially larger than Increment 3
  anticipates (suggesting the diagnostic format is depended on somewhere
  undocumented) — reassess scope before mass-editing.

## Documentation, Task, and DOX Updates

- **At activation (on approval):** create the Taskwarrior task
  (`task` CLI, per `feedback-taskwarrior-mcp-fallback`); branch
  `feature/casm-diag-always-name-file` off `main`; add a one-line row to
  `wiki/tasks/casm.md` under a standalone-tasks heading with status `[/]`.
- **Per increment:** append this plan's Progress log.
- **At completion:** `wiki/` + `docs/` + `release/docs/` doc edits,
  `CHANGELOG.md`, `VERSION`, `wiki/tasks/casm.md` closeout line,
  `brain/KNOWLEDGE.md` one-line note if it tracks diagnostic behavior,
  memory (`reference-casm-diagnostic-always-names-file`, superseding the
  "prints only when CasmSourceCount > 1" wording in any existing memory or
  the §18 doc). DOX pass on `src/external/casm/AGENTS.md` and
  `wiki/AGENTS.md` — expected no ownership/contract change, this is a
  behavior refinement.

## Completion Gate

Complete only when **all** of:

- Increments 1-5 done; Increment 1's characterization recorded in Progress;
- the always-print change verified live for the single-root case (with and
  without includes) and confirmed non-regressive for multi-source and
  nested-include cases;
- every affected diagnostic fixture's documented expectation updated and
  live-re-verified together in one fresh sweep (not per-increment
  citations), recorded in `brain/walkthroughs/`;
- a deliberate DASH-source error assembled natively shows the correct
  filename;
- no-change rebuild proves `casm.prg` byte-stable; CASM within `$7400`;
  both link configs pass; build-number check passes;
- `wiki` / `docs` / `release/docs` manual copies `cmp`-identical;
- trackers synchronized (Taskwarrior, `brain/task.md`, `wiki/tasks/casm.md`,
  `CHANGELOG.md`, `VERSION` at `0.5.3`, memory);
- **explicit user approval** to close. No self-declared completion.

## Progress

- 2026-09-01: Plan drafted for review. Scoping decisions 1-3 captured from
  the user (always-print; standalone off `main`; motivating gap is a
  non-single-source located diagnostic still missing its filename — to be
  characterized in Increment 1 as suppression-only vs provenance bug).
- 2026-09-01: User approved the plan. Status set to `approved-not-started`;
  implementation, branch creation, and task activation remain pending an
  explicit start instruction.
- 2026-09-02: **CLOSED — user-approved.** User approved close and
  explicitly waived the full `test_casm_*` consolidated matrix sweep for
  this change ("I don't think a full test harness run is necessary in this
  case"), given the delta is a 3-instruction gate deletion already
  live-verified on 6 fixtures + the non-located bare-diagnostic check, with
  a byte-stable no-change rebuild and a full clean build of all 32
  harnesses. Merged to `main`; Taskwarrior `86170ef8` closed; memory
  updated. CASM `0.6.2` build 1419.
- 2026-09-02: **Increment 5 (verification + version) — implementation
  complete; full-matrix live sweep waived by the user at close.**
  - `src/external/casm/casm.s` `VERSION_STAGE "1"` -> `"2"` → CASM
    **`0.6.2`**. `BUILD_CASM` `1418` -> `1419` (content-hash gated; the
    version-string edit is the only source delta and it is same-length, so
    `casm.prg` code bytes stayed 25,853).
  - Doc version headers bumped to `0.6.2` build 1419
    (`wiki/casm-utility.md:4`, `wiki/casm-programmers-reference.md:11` +
    `:207`); `docs/` re-synced (`cmp`-identical).
  - **No-change rebuild:** `casm.prg` SHA-256 `e5e871ba…` identical across
    two consecutive `cmake --build build` runs; `BUILD_CASM` did not move
    (source hash `d0937c11…` stable). Full build clean — `casm`,
    `image_d64`, `test_image_d64`, all CASM test images.
  - **Link/envelope:** ld65 links at `$3800` and `$3900`; 25,853 code
    bytes / 4,228 relocation points, within the `$7400` MAIN envelope
    (the change is a net deletion). Diag-table verify: 97 ids OK.
  - **Live — DASH source error** (`dashdiag_test.d64` = rebuilt
    `casm_phase15_test.d64` + a truncated real `dscr.s` head + `.ORG` +
    `LDA #300`; CASM `0.6.2` b1419 under VICE 3.10):
    banner `CASM V0.6.2.1419`; diagnostic
    `CASM: OPERAND OUT OF RANGE   IN FILE dscr.s` /
    `AT LINE 8, COL 5 (OFFSET 4)` / `lda #300` / caret. **A real DASH
    filename is named** ✓. Overlay `test`/`pass` fired. VICE left healthy,
    `test.d64` re-attached.
  - **Deferred to the user (established pattern — see brain/task.md's
    "User ran the full consolidated matrix" entries for WP49/55/60/75):**
    the full `test_casm_*` harness sweep across all disks. No fixture
    expectation changed (Increment 3), and the behavior delta is a
    3-instruction gate deletion already live-verified on 6 fixtures
    ((a)-(e) + the DASH case) plus the non-located bare-diagnostic check,
    so the matrix is a regression backstop rather than a change-specific
    check. Walkthrough written; awaiting the user's consolidated run +
    explicit close approval.
- 2026-09-02: **Increment 4 (documentation) COMPLETE.**
  - `wiki/casm-utility.md` "Reading a diagnostic": rewrote the `IN FILE`
    description as unconditional and updated the example block to show the
    `IN FILE` line (single-file case now prints it). The closing "no source
    position ... message line alone" paragraph already covers the unchanged
    non-located behavior.
  - `wiki/casm-programmers-reference.md` §18.1: "with more than one
    top-level source, an `IN FILE` line precedes it" -> "always preceded by
    an `IN FILE` line"; the **Filename** bullet's "emitted only when
    `CasmSourceCount > 1`" -> "emitted for every diagnostic with a valid
    stamped location", with the removed gate noted as historical
    (releases through 0.6.1).
  - `docs/` mirror regenerated by the `sync_docs` build target
    (`cmp`-identical to `wiki/`, verified).
  - **`release/docs/` deviation:** `release/docs/casm-*.md` is a stale
    `0.3.0` build-`1324` snapshot (Phase 12 era) that
    `cmake/PackRelease.cmake` **deletes and regenerates from `docs/` at
    `make release` time** (`file(REMOVE_RECURSE)` + `file(COPY docs ...)`).
    It is not hand-maintained and cannot be made `cmp`-identical to `wiki/`
    now without also importing three minor versions of unrelated doc
    changes. Left as-is; it will pick up this change (and everything since
    0.3.0) at the next release packaging. Recorded here as an intentional
    departure from the plan's "modify `release/docs/`" Expected-Files row
    and its `cmp`-identical Completion-Gate line — those apply to the live
    `wiki/`+`docs/` pair.
  - `CHANGELOG.md`: entry under `## [Unreleased]` / `### Changed`.
  - `wiki/tasks/casm.md`: standalone-task row already carries the
    `0.6.1 -> 0.6.2` target (added at activation).
- 2026-09-02: **Increment 3 (regenerate expected outputs) — audit found
  nothing to regenerate; scope smaller than the plan anticipated.**
  - **CMake fixture comments:** the only `AT LINE` expectations in
    `cmake/GenerateCasmTestFixtures.cmake` are `casmmfcr1/2` (717) and
    `casmmfdiag1/2` (733-734) — both **two-source** fixtures that already
    printed `IN FILE` before this change (`CasmSourceCount == 2`), so their
    documented blocks are unchanged. Line 1026-1027 (`casmiddiag`,
    `.INCLUDE`) is a frame case, also unchanged. No single-source located
    diagnostic is documented anywhere as lacking an `IN FILE` line. **No
    fixture comment edited.**
  - **Host harnesses:** no `tests/src/casm_*` harness string-compares full
    diagnostic *text*; the fault-injection harnesses
    (`casm_faultinject*`, `casm_faultsource`, `casm_flist`, `casm_flmeta`)
    assert on diagnostic *codes* via the OS_API vector. The harnesses that
    `.export CasmSourceCount` do so for `source.s` / `listing.s` (still
    live importers), not for `diagnostics.s` — removing `diagnostics.s`'s
    `.import` cannot leave any link undefined.
  - **Full build clean:** `cmake --build build` — all 32 `test_casm_*`
    harnesses and all 12 CASM test images build with no errors, no
    undefined symbols, no warnings. `CasmSourceCount` remains exported by
    `cli.s` and imported by `source.s` + `listing.s`.
  - Net: the stale wording is entirely in the **user manuals** (Increment
    4). Nothing to regenerate here.
- 2026-09-02: **Increment 2 (remove the suppression gate) COMPLETE.**
  `src/external/casm/diagnostics.s`: deleted the
  `lda CasmDiagLocFileId / bmi @printFileName / lda CasmSourceCount /
  cmp #2 / bcc @skipFileName` gate and the now-unreferenced
  `@printFileName:` / `@skipFileName:` labels; the name-print block now
  falls through unconditionally once `CasmDiagLocValid` is set. Removed the
  now-unused `.import CasmSourceCount` (grep confirmed it was the sole
  reference). Updated the `diagPrintSourceContext` header/inline comment
  and the `msgInFile` comment to state the unconditional behavior with the
  old gate noted as historical. Increment 1's Scoping-Decision-3b path was
  ruled out, so no provenance-stamp fix was needed here.

  Build: `cmake --build build --target casm` clean — ld65 links at both
  `$3800` and `$3900`, `reloc.py` reports 25,853 code bytes / 4,228
  relocation points (well within the `$7400` MAIN envelope; the change is a
  pure deletion so the binary shrank), diag-table verify "all 97
  diagnostic identifiers + 2 extras render exactly the frozen text".
  `BUILD_CASM` auto-incremented `1417` -> `1418`. Rebuilt `image_d64`,
  `test_image_d64`, `casm_phase15_test_d64`.

  Live re-verification (fresh scratch disk = rebuilt `casm_phase15_test.d64`
  + the 10 Increment-1 fixtures; CASM `0.6.1` b`1418` under VICE 3.10):

  | Case | Before (Inc 1) | After (Inc 2) |
  | --- | --- | --- |
  | (a) single root, no include | no `IN FILE` | **`IN FILE diaga.s`** ✓ |
  | (b) root error in an `.INCLUDE` build | no `IN FILE` | **`IN FILE diagbr.s`** ✓ (no `INCLUDED FROM` — correct) |
  | (c) error in `.INCLUDE`d file | `IN FILE diagci.s` + traceback | unchanged ✓ |
  | (d) two CLI roots, error in 2nd | `IN FILE diagd2.s` | unchanged ✓ |
  | (e) nested include, error in B | `IN FILE diageb.s` + 2 tracebacks | unchanged ✓ |

  Stop-condition check: `CASM` with no args still prints
  `CASM: SOURCE FILE REQUIRED` **bare, no `IN FILE`** — the
  `CasmDiagLocValid` self-gate keeps non-located (CLI/file/internal)
  diagnostics unchanged. Overlay `test`/`pass` event fired. VICE left
  healthy, `test.d64` re-attached on unit 8.
- 2026-09-02: **Increment 1 (characterize the gap) COMPLETE — no code
  change.** Built 10 all-uppercase `.seq` fixtures
  (`.../scratchpad/diagfix/`) into a scratch disk (copy of
  `casm_phase15_test.d64` + `cc1541 -f "<name>.s" -T SEQ -w`), ran all
  five cases live under VICE 3.10 against CASM `0.6.1` build `1417`
  (Command64 OS `0.4.1` b2680), screen-RAM decoded. All use the same
  located diagnostic `CASM: OPERAND OUT OF RANGE` from `LDA #300`
  (immediate 8-bit overflow — a properly *located* diagnostic, which is
  what the gate test needs; the plan's assumed "lexer error" was not
  required).

  | Case | Source shape | `IN FILE`? | Named file | Assessment |
  | --- | --- | --- | --- | --- |
  | (a) | single root, no include, error in root | **NO** | — | suppressed: `CasmSourceCount==1`, root (bit-7-clear) id |
  | (b) | single root that `.INCLUDE`s `DIAGBI.S`, error **in root** (line 3) | **NO** | — | suppressed: same gate; file id is the root's and **correct**, just gated out |
  | (c) | single root, error in `.INCLUDE`d `DIAGCI.S` | YES | `diagci.s` ✓ | frame id (bit 7 set) → `bmi @printFileName`; `INCLUDED FROM diagcr.s LINE 2 COLUMN 1` ✓ |
  | (d) | two CLI roots, error in 2nd (`diagd2.s`) | YES | `diagd2.s` ✓ | `CasmSourceCount==2` → gate passes; no `INCLUDED FROM` (siblings) |
  | (e) | nested `diager.s`→`diagea.s`→`diageb.s`, error in B | YES | `diageb.s` ✓ | frame id; both `INCLUDED FROM` lines correct, innermost-to-root |

  **Verdict: the motivating gap is 3a (suppression only), NOT 3b
  (provenance mis-stamp).** In (a) and (b) the stamped `CasmDiagLocFileId`
  is the root's and is *correct* — the error genuinely is in the root. The
  name is withheld purely by `lda CasmSourceCount / cmp #2 / bcc
  @skipFileName` at `diagnostics.s:868-870`. Removing that gate (Increment
  2's Technical Design, unchanged) fixes (a) and (b) and leaves (c)/(d)/(e)
  untouched. **No provenance-stamping bug — Scoping Decision 3b path and
  its "systemic mis-stamp" stop condition do not apply.** No stop
  condition triggered. Overlay `test`/`pass` event fired via curl
  (`127.0.0.1:8000`). VICE left healthy with `test.d64` re-attached on
  unit 8.
- 2026-09-02: **Activated by explicit user start instruction** after
  Byte-Oracle Transition WP1 closed. Branch
  `feature/casm-diag-always-name-file` cut from `main` `a3d3999` and
  rebased on it; Taskwarrior `86170ef8` (project `casm.standalone`)
  created and started; row added to `wiki/tasks/casm.md`. Runs concurrently
  with docs-only byte-oracle work and **must merge to `main` before
  Byte-Oracle WP2's inventory freeze**.
  **Version drift found (mechanical, anticipated by Scoping Decision 2):**
  the plan predates CASM Phases 14-15. CASM is now `0.6.1` build `1417`
  (not `0.5.2` b1392). The Increment 5 version bump target becomes
  **`0.6.2`** (patch on the current `0.6.x` series), not `0.5.3`;
  `BUILD_CASM` already at 1417. Increment 1's live baseline runs against
  `0.6.1` b1417. The gate code at `diagnostics.s:866-871` still matches
  the Technical Design exactly (`bmi @printFileName` / `lda CasmSourceCount`
  / `cmp #2` / `bcc @skipFileName`); only the version numbers moved.
  `.import CasmSourceCount` is at `diagnostics.s:50`, `msgInFile` at
  `1767`, the WP35/WP48 comment at `1765`.
