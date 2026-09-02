---
feature: casm-phase15-wp99-completion-gate
created: 2026-09-02
status: proposed, not yet approved
taskwarrior: 43 (project casm.phase15), parent 41 (Phase 15)
depends-on: WP93 (37bd4c8), WP94 (fb21ff9), WP95 (ecbd717),
  WP96 (e28dd7d, 6eb2815), WP97 (59c1066), WP98 (37a12c5)
---

# Plan: CASM Phase 15 WP99 — Consolidated Completion Gate

## Status

**Proposed, not yet approved.** WP99 closes Phase 15 (Conditional
Assembly). No new language behaviour — a fresh *together* re-verification
of everything WP93-98 built, the two fixtures deferred from WP96, the
documentation reconciliation, the version promotion to **CASM 0.6.1**, a
consolidated walkthrough, and explicit phase sign-off.

Branch `feature/casm-phase15`; commits directly on it. After sign-off the
branch merges to `main` (separate "Merge it" step, as with Phase 14).

## Objective

1. Every `test_casm_*` harness green in one fresh run (not per-WP
   citation).
2. Every Phase 15 production fixture re-verified together on
   `casm_phase15_test.d64`.
3. The two WP96-deferred fixtures added and verified: `casmifsym`
   (a label defined only inside a *skipped* branch → later reference is
   `UNDEFINED SYMBOL`), `casmifp1p2` (a `.if 1` body whose size differs
   from the `.if 0` case → Pass 1 == Pass 2, COMP-exact).
4. Docs: new "Conditional Assembly" section in `docs/casm-utility.md`
   + programmer's-reference note + wiki mirrors + `wiki/tasks/casm.md`
   + `brain/KNOWLEDGE.md` Phase 15 closing section + `CHANGELOG.md`.
5. Version bump `casm.s` → CASM **0.6.1** (build auto-increments).
6. Walkthrough; memory; explicit user sign-off for the whole phase.

**Not in scope:** anonymous labels (deferred); comparison operators in
`.if` / `.assert` (never); any new directive.

## Consolidated re-verification (the gate)

### Host build

- Clean `cmake -B build` + `cmake --build build` from scratch (or at
  least `rm -rf build && cmake -B build && cmake --build build`), all
  targets, zero warnings/errors.
- `scripts/verify_casm_diag_table.py` passes (the `$5B`-`$61` conditional
  diag rows).
- `ld65 -m` envelope check: CASM MAIN within `$7400`. Record the final
  headroom. (327 B at WP98; the 0.6.1 string is the same length as
  0.6.0 — no code delta expected.)
- Every `CASM_REF_NAMES` entry transcribes from its `.ref.hex` unchanged
  (`git status` clean on generated artifacts after a build).

### Live VICE (`casm_phase15_test.d64`, per `vice-mcp-testing`)

Boot Command64, FLUSH before/after, fire `c64-overlay-api` test events.
Run **all** Phase 15 fixtures in one session:

| Fixture | Assertion |
| --- | --- |
| `casmif1` / `casmif0` / `casmifskip` | `.IF 1`/`.IF 0` body in/out; skipped body never evaluated. COMP. |
| `casmifelse` / `casmelif` | `.ELSE` / `.ELSEIF` ladder landings. COMP. |
| `casmifnest` | nested `.IF`. COMP. |
| `casmiffwd` | forward `.IF LATER` → `CONDITIONAL_OPERAND_UNRESOLVED`. |
| `casmifnoend` / `casmendnoif` / `casmelseelse` | the three structural diagnostics. |
| `casmifdef1` / `casmifdef0` / `casmifndef1` | `.IFDEF`/`.IFNDEF` true/false. COMP. |
| `casmifdeffwd` / `casmifdefguard` | forward `.IFDEF` + define-once guard; **P1 == P2**. COMP. |
| `casmifdefname` | `.IFDEF 5` → `IFDEF_EXPECTS_NAME`. |
| `casmifL1` / `casmifM1` | WP98 `/L` blank-address + `/M` non-leak. COMP. |
| `casmifsym` (new) | skipped-branch label → later `UNDEFINED SYMBOL`; taken-branch label usable after `.ENDIF`. |
| `casmifp1p2` (new) | size-divergent `.IF 1` vs `.IF 0` → no `PASS 1/PASS 2` mismatch. COMP. |
| `test_casm_cond` | `CASM COND: PASS`. |

Regression witnesses (no `.if`): `casmhello`, `casmassert1`, `casmchain1`
COMP-exact (from a disk that carries them — `casm_phase10_test.d64` or
`test.d64`; pick per what's bootable).

## Documentation

### `docs/casm-utility.md` — new `### Conditional Assembly` under `## Language Reference`

Placed after `### Splitting Source Across Files` (before `## Map and
Listing Output`). Content:

- The six directives: `.IF expr` / `.ELSEIF expr` / `.ELSE` / `.ENDIF`,
  `.IFDEF name` / `.IFNDEF name`.
- **Truthiness only** — `.IF` takes an expression; non-zero = true, zero
  = false. No comparison operators (`=`, `<`, `>` …) — a documented
  divergence from ca65. Show the workaround (compute a 0/1 constant).
- `.IFDEF` / `.IFNDEF` test whether a name is defined **at that point in
  Pass 1's traversal** — a name defined later in the file reads as *not
  defined*, consistently in both passes (matches ca65's traversal-order
  `.ifdef`). The define-once include-guard idiom.
- Nesting depth limit (`CASM_COND_MAX_DEPTH` = 16); total conditional
  sites limit (`CASM_COND_MAX_SITES` = 512).
- A skipped branch is **not assembled and not parsed** — it may contain
  text that would not assemble on its own; it defines no labels and no
  constants; a later reference to a skipped-branch label is `UNDEFINED
  SYMBOL`.
- `.IF` conditions must fully resolve in-pass — a forward reference in an
  `.IF` / `.ELSEIF` expression is `.IF CONDITION NOT RESOLVED`.
- `/L`: a line inside a skipped branch is listed with its source text
  and a **blank address column**; the `.IF`/`.ENDIF` directive lines
  render normally. `/M`: a skipped branch contributes no symbols.
- The five structural diagnostics (`WITHOUT .IF`, `UNTERMINATED .IF`,
  `AFTER .ELSE`, `NESTING TOO DEEP`, `TOO MANY CONDITIONALS`) +
  `IFDEF/IFNDEF EXPECTS A NAME`.
- A worked example (Practical Examples → new "Example 5: Conditional
  Assembly").

### Other docs

- `docs/casm-programmers-reference.md`: a `§` bullet for the conditional
  directives + the truthiness/no-operator note; update the directive
  table / "implemented" status.
- `docs/casm-utility.md` "## Not Yet Supported": move conditional
  assembly out (it is now supported); keep anonymous labels + `.if`
  comparison operators listed.
- `wiki/casm-utility.md`, `wiki/casm-programmers-reference.md`: re-mirror
  (`cp` from `docs/`, matching the WP92 process).
- `wiki/Home.md`, `wiki/tasks/casm.md`: Phase 15 → complete at 0.6.1.
- `CHANGELOG.md`: a `## CASM 0.6.1` entry — the six directives,
  truthiness-only, `/L` blank-address rule, the ca65 divergences.
- `brain/KNOWLEDGE.md`: a new "## CASM Phase 15 Complete" section.

## Version bump

`src/external/casm/casm.s`: `.define VERSION_STAGE "1"` (0.6.0 → 0.6.1).
`VERSION_MINOR` stays `"6"`. Build number auto-increments.

## Atomic Increments

1. `casmifsym` + `casmifp1p2` fixtures + `.ref.hex` (accepted cases) in
   `GenerateCasmTestFixtures.cmake` / `CMakeLists.txt`; append to
   `casm_phase15_test_d64`; `casmifsym` is a diagnostic case (partial —
   the taken-branch half COMPs), `casmifp1p2` COMPs.
2. Version bump `casm.s` → 0.6.1. Build. Envelope check.
3. Fresh full `cmake --build build`; `verify_casm_diag_table.py`; ref
   transcription check.
4. Live VICE: the full Phase 15 fixture matrix + `test_casm_cond` + the
   no-`.if` regression witnesses, one session.
5. Docs: all of the above.
6. Walkthrough (`brain/walkthroughs/2026-09-01-casm-phase15-wp99-completion-gate.md`),
   memory (`project-casm-phase15-complete`, indexed in `MEMORY.md`;
   supersede the WP-snapshot memories), Taskwarrior / `brain/task.md` /
   `wiki/tasks/casm.md` sync.
7. Commit. Request sign-off. (Merge to `main` is a separate step after
   sign-off.)

## Expected Files

| File | Action |
| --- | --- |
| `cmake/GenerateCasmTestFixtures.cmake`, `CMakeLists.txt` | Modify — `casmifsym` / `casmifp1p2` |
| `tests/fixtures/casm/casmifsym.ref.hex`, `casmifp1p2.ref.hex` | Create |
| `src/external/casm/casm.s` | Modify — `VERSION_STAGE "1"` |
| `docs/casm-utility.md`, `docs/casm-programmers-reference.md` | Modify — Conditional Assembly section + notes |
| `wiki/casm-utility.md`, `wiki/casm-programmers-reference.md`, `wiki/Home.md`, `wiki/tasks/casm.md` | Modify — re-mirror + status |
| `CHANGELOG.md`, `brain/KNOWLEDGE.md` | Modify |
| `brain/plans/2026-09-01-casm-phase15-*.md` | Append Progress |
| `brain/walkthroughs/2026-09-01-casm-phase15-wp99-completion-gate.md` | Create |
| `MEMORY.md` + `memory/project_casm_phase15_complete.md` | Create/Modify |

## Stop Conditions

- Any `test_casm_*` harness fails in the fresh sweep, or a no-change
  rebuild alters any assembled `.ref` / `.LST` / `.MAP`.
- Any Phase 15 fixture: Pass 1 and Pass 2 disagree on a branch or an
  assembled byte.
- `casmifsym` shows a skipped-branch label resolving (would mean the
  scanner leaked a definition — a WP95/96 defect; disclose and defer,
  do not fix in the gate).
- CASM MAIN overflows `$7400` after the version bump (should be
  impossible — same string length; if it happens, STOP).
- A new defect outside Phase 15 surfaces — disclose and defer.

## Completion Gate

- Fresh full `test_casm_*` sweep green; full Phase 15 fixture matrix
  correct live; `casmifsym` / `casmifp1p2` verified; no-`.if` regression
  witnesses byte-identical.
- `verify_casm_diag_table.py` green; CASM within `$7400`; both link
  configs pass; test images build; build-number check passes.
- All docs updated + wiki mirrored; `CHANGELOG.md` + `KNOWLEDGE.md`
  Phase 15 closing sections written; memory written.
- Walkthrough recorded; **explicit user approval to close Phase 15**.

## Progress

- 2026-09-02: Plan drafted. WP98 closed (user-approved, 37a12c5).
  Awaiting approval to run the gate.
