# CASM Phase 13 WP85 Consolidated Completion Gate

## Status

**Approved by the user on 2026-08-21.** WP85 is complete. CASM Phase 13
(WP81-85) is fully closed at `0.4.0` build `1349`.

## Result

CASM Phase 13 (WP81-84: `.RES`/`.FILL`/`.ALIGN`, `.INCBIN`, `.ASSERT`,
DASH adoption of `.RES`) is closed. A fresh consolidated regression
sweep — the full 29-harness live-VICE pass this project's own WP75/WP76
precedent calls for, not a narrower "just Phase 13's own new material"
pass — found the phase already clean: no regressions, no new defects.
CASM is promoted from `0.3.0` to `0.4.0`.

## Scoping Decision (confirmed before implementation)

**Full sweep**: all 29 `test_casm_*` harnesses, matching WP75's own
Phase-12-closing precedent, over a narrower Phase-13-only alternative (3
regression witnesses + Phase 13's own fixtures + DASH only). Chosen
explicitly because WP75's own full sweep is what caught WP76's real
cross-harness defect — a narrower pass would have missed it.

## Consolidated Sweep Evidence

All 29 harnesses mapped to their six disk images by direct
`CMakeLists.txt` inspection (not assumed), then re-run fresh in one
continuous set of live-VICE sessions:

| Disk | Harnesses | Result |
| --- | --- | --- |
| `test.d64` | `test_casm_reloc`, `test_casm_symbols`, `test_casm_vmm`, `test_casm_faultinject` | All PASS |
| `casm_overflow_test.d64` (companion-disk pattern, unit 9 + `DRIVE 9`) | `test_casm_include`, `test_casm_catalog`, `test_casm_faultsource` | All PASS |
| `casm_include_test.d64` | `test_casm_freloc`, `test_casm_bounds`, `test_casm_cliderive`, `test_casm_lexer`, `test_casm_fsym`, `test_casm_finc`, `test_casm_opcodes`, `test_casm_event`, `test_casm_directives` | All PASS |
| `casm_phase12_test.d64` | `test_casm_expr`, `test_casm_pass1` | All PASS |
| `casm_phase13_test.d64` | `test_casm_frame` + all 14 Phase 13 production fixtures | All PASS/correct |
| `casm_listing_test.d64` | `test_casm_listing`, `test_casm_listcap`, `test_casm_map`, `test_casm_passcheck`, `test_casm_spanread`, `test_casm_spancommit`, `test_casm_listwrite`, `test_casm_flist`, `test_casm_flmeta`, `test_casm_faultvmm` | All PASS |

**29/29 harnesses PASS. 14/14 Phase 13 production fixtures correct**
(5 COMP-exact against hand-derived references, 9 correct rejected
diagnostics, each matching its own WP's original recorded result
exactly):

- `.RES`/`.FILL`/`.ALIGN`: `casmres1`/`casmfill1`/`casmalign1` all
  `FILES COMPARE OK`; `casmresfwd` → `CASM: OPERAND NOT RESOLVED`;
  `casmfillnoval` → `CASM: FILL REQUIRES A VALUE`; `casmalignzero` →
  `CASM: ALIGN BOUNDARY ZERO`; `casmresrange` → `CASM: VALUE OUT OF
  RANGE`.
- `.INCBIN`: `casmincbin1` → `FILES COMPARE OK`; `casmincbinmiss` →
  `CASM: CANNOT OPEN INPUT`; `casmincbinbadname` → `CASM: INCBIN
  FILENAME EXPECTED`.
- `.ASSERT`: `casmassert1` → `FILES COMPARE OK`; `casmassertfail` →
  `CASM: ASSERTION FAILED`; `casmassertmsg` → `CASM: ASSERTION FAILED:
  custom message`; `casmassertfwd` → `CASM: ASSERT OPERAND NOT
  RESOLVED`.

Every diagnostic fired at its documented line/column with correct caret
context; every dispatch ended with a clean shell return.

## DASH Re-verification

A fresh `dash_ref` (ca65) build's SHA-256 matches WP84's own recorded
`dash.ref.hex` hash exactly (`3238b7863cc9b7ba7b07202c94dccb8dcbd1fd0fe4c
578362f311b79757b814b`) — a cheap host-side confirmation; no second full
hardware run was needed since WP84 already did that this same phase.

## Version Promotion

`src/external/casm/casm.s`'s `VERSION_MINOR` bumped `"3"` → `"4"`
(`0.3.0` → `0.4.0`), completion-only, no behavior change in the same
commit — mirrors the `0.2.8`→`0.3.0` WP75 precedent. Live-verified in
VICE: `CASM V0.4.0.1349` banner; `casm casmassert1.s` still assembles
cleanly; `comp casmassert1.prg casmassert1.ref` → `FILES COMPARE OK`.

## Regression Evidence

- Full clean rebuild from scratch (`rm -rf build && cmake -B build &&
  cmake --build build`), performed twice (once as the sweep's own
  baseline, once after the version bump): both exit 0, zero errors, zero
  overflows, zero unresolved externals.
- A subsequent no-change `cmake --build build` after the version bump
  triggered zero compile/link work.

## Documentation Reconciliation

- `CHANGELOG.md`: new `### Added` entries for Phase 13's directives and
  DASH's `.RES` adoption; new `### Fixed` entry for the `0.4.0`
  completion promotion, mirroring the `0.3.0` WP75 entry's shape.
- `brain/KNOWLEDGE.md`: new "CASM Phase 13 Complete" closing section,
  mirroring the existing "CASM Phase 12 Complete" section — records both
  scoping-narrowing findings (deferred `.ASSERT` DASH adoption, dropped
  `.FILL` DASH adoption for `.RES`) and how each was verified directly
  against the toolchain rather than assumed.
- `wiki/tasks/casm.md`/`brain/task.md`: WP85 entry recorded, Phase 13
  marked fully closed.

## Manual Confirmation

1. Boot any of the six disks listed above; dispatch each harness by
   name; expect the PASS banner shown in the table.
2. Boot `build/casm_phase13_test.d64`; run each of the 14 fixtures
   (`casm <name>.s`, `comp <name>.prg <name>.ref` for the accepted
   cases); expect the results listed above.
3. Confirm CASM's version banner reads `CASM V0.4.0`.

## Completion Gate

- [x] All 29 `test_casm_*` harnesses re-run live in VICE in one
      continuous set of sessions, all PASS.
- [x] All 14 Phase 13 production fixtures re-verified together, each
      matching its own WP's original recorded result.
- [x] DASH manifest hash re-confirmed against WP84's own recorded value.
- [x] CASM promoted to `0.4.0`; version banner confirmed live.
- [x] Full clean rebuild and no-change rebuild both stable.
- [x] `CHANGELOG.md`/`brain/KNOWLEDGE.md`/`wiki/tasks/casm.md`/
      `brain/task.md` all synchronized.
- [x] Consolidated walkthrough recorded here.
- [x] **User explicitly approves closing WP85 and the whole of Phase
      13.** Approved 2026-08-21.

**Phase 13 (WP81-85) is fully closed**, at CASM `0.4.0` build `1349`.
