# CASM Phase 12 WP75 Verification, Walkthrough, Completion Gate

Plan: `brain/plans/2026-08-19-casm-phase12-wp75-verification-walkthrough-completion-gate.md`

## Result

WP75 is implemented and verified. CASM Phase 12 (WP64-76) is at `0.3.0`
build `1324`, with a fresh consolidated live-VICE re-run of every
`test_casm_*` harness and every Phase 12 production fixture in one
continuous session, a clean regression build, a byte-identical no-change
rebuild, DASH's full Phase 12 adoption complete and re-verified,
documentation reconciled, and trackers synchronized. Pending only the
user's own manual runtime walkthrough and explicit approval to close.

## Increment 1: DASH Full-Adoption Audit

Complete (recorded in this plan's own 2026-08-19 Progress entry).
`dapp.s`/`ddata.s`/`dscr.s`/`dsys.s` adopted WP68 arithmetic/shift
expressions and WP74 string literals; character literals excluded per
DASH's own `AGENTS.md` (banned in its dual-assembler subset). No genuine
site for `*` existed. Live-verified byte-identical to the pre-edit
shipped artifact.

## Increments 2-3: Clean Regression Build + Byte-Identity

Complete (2026-08-19). Full `cmake --build build` clean; immediate
no-change rebuild byte-for-byte identical (SHA-256 diff empty). Phase
1-11 fixtures confirmed unchanged by inspection: only DASH sources
touched, and the no-change rebuild's own determinism proves it.

## Increment 4: Consolidated Live-VICE Session — All 30 `test_casm_*` Harnesses

Complete (2026-08-20). All 30 harnesses PASS across all five test disks
(`casm_listing_test.d64` 12/12, `casm_include_test.d64` 7/7, `test.d64`
4/4, `casm_phase12_test.d64` 3/3, `casm_overflow_test.d64` 4/4). Two real
defects found and fixed along the way, both disclosed and tracked before
being resolved: `test_casm_pass1` failing on `test.d64` (a fixture
packaging gap, fixed by removing it from `TEST_IMAGE_PRG_TARGETS`
matching `test_casm_expr`'s own precedent) and `casm_listing_test.d64`
BAM exhaustion (fixed by relocating two harnesses to
`casm_include_test.d64`). Full detail in this plan's own Progress log.

## Increment 5: Phase 12 Production Fixtures — Found and Fixed a Real Regression

Complete. Ten fixtures first surveyed 2026-08-20 found `casmarithfwd.s`
regressed to `CASM: PASS 1/2 MISMATCH` — a genuine defect outside any
prior WP's own scope, correctly triggering this plan's disclose-and-defer
Stop Condition. Fixed under a dedicated corrective WP (WP76, plan and
walkthrough at `brain/plans/2026-08-20-casm-phase12-wp76-forward-
reference-pass-agreement-fix.md`), following the WP72/WP73 precedent of
inserting a numbered WP for a mid-phase corrective fix. Root cause
confirmed live via direct memory read (`CasmPass1FinalPc=$0013` vs
`CasmPc=$0012`): a named constant referenced inside an arithmetic
expression before its own defining statement disagreed on instruction
width between Pass 1 (forced absolute while unresolved) and Pass 2
(always resolved, took WP72's zero-page exemption). Fixed with a
per-constant `DEFINED_AT_OFFSET` bookmark gating WP72's exemption on
source-position order.

**Post-fix, all 11 fixtures re-verified together fresh** on one dedicated
disk (`wp76_consolidated.d64`), CASM `0.2.8` build `1323`:

| Fixture | Result |
| --- | --- |
| `casmarithfwd.s` | `CASM: INPUT VALIDATED`, `FILES COMPARE OK` |
| `casmzpconst1.s` (WP72) | `CASM: INPUT VALIDATED`, `FILES COMPARE OK` |
| `casmfwdstale1.s` (WP73) | `CASM: INPUT VALIDATED`, `FILES COMPARE OK` |
| `casmrelacc.s` (WP70) | `CASM: INPUT VALIDATED`, `FILES COMPARE OK` |
| `casmarelocb.s`/`casmareloc1.s`/`casmareloc2.s` (WP70) | exact documented `CASM: EXPRESSION RELOCATION UNSUPPORTED`, exact line/col/offset |
| `casmarith2.s`/`casmarith3.s` (WP68) | `CASM: INPUT VALIDATED`, `FILES COMPARE OK` |
| `casmchar1.s` (WP69) | `CASM: INPUT VALIDATED`, `FILES COMPARE OK` |
| `casmstring1.s` (WP74) | `CASM: INPUT VALIDATED`, `FILES COMPARE OK` |

All 11 match their documented WP68/WP70/WP72/WP73/WP74 outcomes exactly —
the WP70 relocation algebra closure matrix is confirmed unregressed.

## Increment 6: DASH Regen Re-Verify (Post-WP76)

Complete (2026-08-20). Re-assembled DASH live with the post-WP76
`casm.prg` (build 1323) on a dedicated CASM-only test disk
(`dash_casm_test2.d64`): `CASM: INPUT VALIDATED`. Extracted PRG confirmed
byte-identical to the current shipping `dash.ref.hex`
(`sha256 3238b7863cc9b7ba7b07202c94dccb8dcbd1fd0fe4c578362f311b79757b814b`)
— WP76's fix changed nothing for DASH, as expected (DASH never combines
a forward-referenced constant with an arithmetic operator).

## Increment 7: Documentation Reconciliation

Complete (2026-08-20). Corrected a mistaken earlier assessment (from a
grep-only pass, not a full read) that `wiki/casm-utility.md` and
`wiki/casm-programmers-reference.md` were missing Phase 12 entirely —
their actual content already comprehensively documented named constants,
`*`, parentheses, arithmetic/bitwise operators, and character/string
literals. The real gaps: stale version/status headers, and WP76's
brand-new symbol-record/resolver-view changes undocumented. Fixed:

- `wiki/casm-utility.md`: version `0.2.2`/`1266` -> `0.3.0`/`1324`;
  status callout updated from "Phase 10 complete" to "Phase 12 complete."
  Synced to `docs/casm-utility.md` and `release/docs/casm-utility.md`
  (the source of truth).
- `wiki/casm-programmers-reference.md`: version/status callout updated
  to `0.3.0`/`1324`/"Phase 12 complete" with a WP64-76 summary; §11
  (Expression Evaluator) gained WP72's zero-page-exemption mechanism and
  WP76's forward-reference guard; §12 (Symbol Table) gained the
  `DEFINED_AT_OFFSET` record field and WP73's resolver-state-guard note;
  the resolver-view byte count corrected from stale "5-byte" to current
  8-byte (`CASM_RESOLVE_*`, grew via WP65 then WP76).
- `brain/KNOWLEDGE.md`: new Phase 12 rollup section, deliberately titled
  "pending final closure" rather than "complete" — caught and corrected
  a premature-completion framing before it was committed, since
  Increment 10's approval hadn't happened yet at that point.
- `CHANGELOG.md`: `0.3.0` promotion entry, matching the
  `0.1.56`->`0.2.0`/`0.2.0`->`0.2.1` precedent (completion-only, no
  behavior change).

## Increment 8: Version Promotion

Complete (2026-08-20). `casm.s`'s `VERSION_MAJOR/MINOR/STAGE` promoted to
`0`/`3`/`0`. Full project build clean, build `1324`. Live-verified:
`CASM V0.3.0.1324` prints correctly, `casmarithfwd.s` still
`CASM: INPUT VALIDATED`. Full no-change rebuild byte-stable across every
`.d64` in `build/` (`sha256sum -c`, zero `FAILED` lines).

(Done before Increment 7 in execution order, to avoid writing a
not-yet-real version number into the documentation pass — the plan's own
increments are dependency-ordered guidance, not a strict sequence lock.)

## Increment 9: Tracker Sync

Complete (2026-08-20). `wiki/tasks/casm.md`'s "Current Milestone" summary
and WP list updated (WP76 marked complete with full detail, WP75 marked
in-progress with per-increment status). Taskwarrior task 42 (Phase 12
parent, UUID `c547c74f-5080-4f2e-b086-e4e2273b5336`) and task 43 (WP75,
UUID `d3440667-c9bd-49cc-9013-80d9bd96d035`) both annotated with current
progress — **neither closed**, since this Increment 10 walkthrough and
the user's own approval were still outstanding at annotation time.

## Build Evidence

- Full project build (`cmake --build build`, no target): clean, zero
  errors/warnings, both before and after the version promotion.
- Full no-change rebuild: every `.d64` in `build/` byte-stable
  (`sha256sum -c` against pre-rebuild snapshots, zero `FAILED` lines),
  captured twice (once after WP76's fix, once after the version bump).

## Manual Confirmation

1. Boot a CASM-capable disk into Command64, run `CASM CASMARITHFWD.S`;
   expect `CASM V0.3.0.1324` then `CASM: INPUT VALIDATED`.
2. Try a few of the practical examples in `docs/casm-utility.md`
   (named constants, `*`, character/string literals, arithmetic
   operators) directly; confirm they assemble and behave as documented.
3. Run `DASH` (from `command64_casm_utils.d64` or `image.d64`); confirm
   it boots and its System/Applications/VMM Test pages render correctly.

## Completion Gate

Pending the user's own manual runtime walkthrough and explicit approval.
Once approved: Taskwarrior tasks 42 and 43 close, and this walkthrough's
own heading and `brain/KNOWLEDGE.md`'s Phase 12 section update from
"pending" to "complete."
