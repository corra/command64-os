---
feature: casm-phase13-wp85-consolidated-completion
created: 2026-08-21
status: proposed
taskwarrior: 47fbe529-c710-473c-9eef-147c38592454 (task "WP85:
  consolidated completion gate, version promotion to 0.4.0", project
  casm.phase13)
depends-on: CASM Phase 13 WP81/82/83/84, all complete and merged into
  feature/casm-phase13
---

# Plan: CASM Phase 13 WP85 - Consolidated Completion Gate

## Status

**Approved 2026-08-21.** Sweep scope confirmed (full 29-harness sweep,
see Scoping Decision below). Implementation authorized on
`feature/casm-phase13-wp85`.

Parent plan: `brain/plans/2026-08-21-casm-phase13-data-construction-
directives.md`. Branch: `feature/casm-phase13-wp85`, cut from
`feature/casm-phase13` (WP81-84 all merged in).

## Objective

Close the whole of CASM Phase 13 (WP81-84: `.RES`/`.FILL`/`.ALIGN`,
`.INCBIN`, `.ASSERT`, DASH adoption of `.RES`) per the parent plan's own
completion gate: a fresh consolidated regression sweep (not just citing
each WP's own individual pass — the project's own WP46/WP63/WP76
precedent for catching cross-harness defects that only a full re-run
together reveals), version promotion to `0.4.0`, documentation
reconciliation, and a closing walkthrough with user sign-off for the
whole phase.

## Scoping Decision (user-confirmed 2026-08-21)

**Full sweep**: re-run all 29 `test_casm_*` harnesses live in VICE (not
a narrower "just Phase 13's own new material" pass), matching WP75's own
precedent for Phase 12's closing WP — chosen explicitly over a targeted
alternative (3 regression witnesses + Phase 13's own 14 fixtures + DASH
only) because that precedent's own session found a real cross-harness
defect (WP76) a narrower sweep would have missed.

## Research Summary: harness-to-disk map

A pre-planning pass mapped all 29 harnesses to their disk images (direct
`grep` against `CMakeLists.txt`'s `add_c64_disk_image`/`PRGS` lines, not
assumed) to sequence live-VICE sessions efficiently — each group below
shares one disk, so all harnesses in a group run in one boot/attach
without re-imaging:

| Disk (`OUTPUT_FILE`) | Self-bootable? | Harnesses |
| --- | --- | --- |
| `test.d64` (`test_image_d64`) | Yes (carries `command64`) | `test_casm_reloc`, `test_casm_symbols`, `test_casm_vmm`, `test_casm_faultinject` |
| `casm_overflow_test.d64` | **No** (no `command64` — needs a companion disk on a second unit + `DRIVE` switch, same pattern WP84's native DASH run used) | `test_casm_include`, `test_casm_catalog`, `test_casm_faultsource` |
| `casm_include_test.d64` | Yes | `test_casm_freloc`, `test_casm_bounds`, `test_casm_cliderive`, `test_casm_lexer`, `test_casm_fsym`, `test_casm_finc`, `test_casm_opcodes`, `test_casm_event`, `test_casm_directives` |
| `casm_phase12_test.d64` | Yes | `test_casm_expr`, `test_casm_pass1` (`test_casm_lexer` also here, a duplicate build already covered above) |
| `casm_phase13_test.d64` | Yes | `test_casm_frame`, plus all 14 Phase 13 production fixtures (`casmres1`/`casmfill1`/`casmalign1`/`casmincbin1`/`casmassert1` and their rejected-case siblings) |
| `casm_listing_test.d64` | Yes | `test_casm_listing`, `test_casm_listcap`, `test_casm_map`, `test_casm_passcheck`, `test_casm_spanread`, `test_casm_spancommit`, `test_casm_listwrite`, `test_casm_flist`, `test_casm_flmeta`, `test_casm_faultvmm` |

Six disk-session legs total (the seventh disk, `casm_opcode_test.d64`,
carries only a duplicate `test_casm_opcodes` build already exercised via
`casm_include_test.d64` — not re-tested separately, same "duplicate
build, test once" judgment already applied to `test_casm_lexer`).

Note on shortened dispatch names (CBM DOS's 16-character directory-entry
limit forced these; confirmed against each harness's own `BUILD_TEST_*`
naming, not guessed): `casm_faultinject_include` dispatches as
`test_casm_finc`; `casm_faultinject_listing` as `test_casm_flist`;
`casm_faultinject_listing_meta` as `test_casm_flmeta`;
`casm_faultinject_reloc` as `test_casm_freloc`; `casm_faultinject_source`
as `test_casm_faultsource`; `casm_faultinject_symbols` as
`test_casm_fsym`; `casm_faultinject_vmm` as `test_casm_faultvmm`.

## Atomic Increments

1. **Full clean rebuild from scratch**: `rm -rf build && cmake -B build
   && cmake --build build`, confirm zero errors/overflows/unresolved
   externals — the starting baseline every subsequent live check runs
   against.
2. **Disk-session leg 1 (`test.d64`)**: `test_casm_reloc`/
   `test_casm_symbols`/`test_casm_vmm`/`test_casm_faultinject`, each
   dispatched and confirmed PASS with a clean shell return.
3. **Disk-session leg 2 (`casm_overflow_test.d64`, companion-disk
   pattern)**: attach a `command64`-carrying disk on unit 8 and
   `casm_overflow_test.d64` on unit 9, `DRIVE 9`, dispatch
   `test_casm_include`/`test_casm_catalog`/`test_casm_faultsource`.
4. **Disk-session leg 3 (`casm_include_test.d64`)**: `test_casm_freloc`/
   `test_casm_bounds`/`test_casm_cliderive`/`test_casm_lexer`/
   `test_casm_fsym`/`test_casm_finc`/`test_casm_opcodes`/
   `test_casm_event`/`test_casm_directives`.
5. **Disk-session leg 4 (`casm_phase12_test.d64`)**: `test_casm_expr`/
   `test_casm_pass1`.
6. **Disk-session leg 5 (`casm_phase13_test.d64`)**: `test_casm_frame`,
   plus all 14 Phase 13 production fixtures re-run together in one
   session (the ones with a `.ref` re-`COMP`-verified; the rejected-case
   ones re-confirmed against their documented diagnostic).
7. **Disk-session leg 6 (`casm_listing_test.d64`)**: `test_casm_listing`/
   `test_casm_listcap`/`test_casm_map`/`test_casm_passcheck`/
   `test_casm_spanread`/`test_casm_spancommit`/`test_casm_listwrite`/
   `test_casm_flist`/`test_casm_flmeta`/`test_casm_faultvmm`.
8. **DASH re-verification**: re-confirm `dash.ref.hex`'s recorded hash
   still matches a fresh `build/dash_ref.prg` (ca65) build — a cheap
   host-side sanity check, not a full hardware re-run (WP84 already did
   that hardware run this same phase; re-doing it here would be
   redundant, not a fresh cross-check).
9. **Version promotion**: bump `VERSION_MAJOR`/`MINOR`/`STAGE` in
   `casm.s` from `0.3.0` to `0.4.0` (completion-only bump, no behavior
   change in the same commit — mirrors the `0.2.8`→`0.3.0` WP75
   precedent). Rebuild `casm`, confirm the version banner reads
   `CASM V0.4.0`.
10. **No-change rebuild check**: a second `cmake --build build` after
    Increment 9 changes nothing further (only the version-bump commit
    itself should differ from Increment 1's baseline).
11. **Documentation reconciliation**: `CHANGELOG.md` (new entry, mirrors
    the `0.3.0` WP75 entry's shape), `brain/KNOWLEDGE.md` (new "CASM
    Phase 13 Complete" closing section, mirrors the existing "CASM Phase
    12 Complete" section's shape), `wiki/tasks/casm.md`/`brain/task.md`
    (Phase 13 closed, WP85 entry), Taskwarrior (WP85 task + Phase 13
    parent task, if one exists, marked complete).
12. **Consolidated walkthrough**: record every leg's live evidence in
    `brain/walkthroughs/`, submitted for user sign-off — for the whole
    phase, not just WP85 itself.

## Expected Files

| File | Planned action |
| --- | --- |
| `src/external/casm/casm.s` | Modify (version bump `0.3.0` → `0.4.0`) |
| `CHANGELOG.md` | Modify (new Phase 13 entry) |
| `brain/KNOWLEDGE.md` | Modify (new Phase 13 closing section) |
| `wiki/tasks/casm.md` | Modify (Phase 13 closed) |
| `brain/task.md` | Modify (WP85 entry, Phase 13 closed) |

No CASM source (other than the version bump) or DASH source changes
expected — this WP is verification and documentation, not new
implementation.

## Stop Conditions

- Any of the 29 harnesses fails unexpectedly, including a
  currently-passing one regressing.
- Any Phase 13 production fixture (COMP-verified or diagnostic-verified)
  disagrees with its own WP's original recorded result.
- The DASH manifest hash check disagrees with WP84's own recorded hash.
- A no-change rebuild (Increment 10) changes anything beyond the version
  bump itself.
- A genuinely new defect is discovered (the whole reason for a full
  sweep, per WP76's own precedent): disclose and defer as a separate,
  separately-approved follow-up — do not fix inline as part of closing
  the phase, unless explicitly directed in the moment.

## Documentation, Task, and DOX Updates

- Taskwarrior: WP85 task created under the Phase 13 parent on approval
  of this plan; Phase 13 parent task (if tracked) marked complete
  alongside WP85.
- `wiki/tasks/casm.md`/`brain/task.md`: WP85 entry, Phase 13 marked
  fully closed.
- `CHANGELOG.md`/`brain/KNOWLEDGE.md`: whole-phase closing entries, per
  this WP's own Atomic Increment 11.

## Completion Gate

- All 29 `test_casm_*` harnesses re-run live in VICE in one continuous
  set of sessions, all PASS.
- All 14 Phase 13 production fixtures re-verified together (COMP-exact
  or correct diagnostic, matching each WP's own original result).
- DASH manifest hash re-confirmed against WP84's own recorded value.
- CASM promoted to `0.4.0`; version banner confirmed live.
- Full clean rebuild and no-change rebuild both stable.
- `CHANGELOG.md`/`brain/KNOWLEDGE.md`/`wiki/tasks/casm.md`/
  `brain/task.md` all synchronized.
- Consolidated walkthrough recorded in `brain/walkthroughs/`.
- User explicitly approves closing WP85 **and the whole of Phase 13**.

## Progress

- 2026-08-21: Plan drafted after mapping all 29 harnesses to their six
  disk images (direct `grep` against `CMakeLists.txt`, not assumed) and
  confirming the sweep-scope Scoping Decision with the user (full
  29-harness sweep, matching WP75's own Phase-12-closing precedent, over
  a narrower Phase-13-only alternative). Awaiting nothing further --
  plan approved in the same exchange the scoping question was answered;
  implementation begins at Increment 1.
- 2026-08-21: Increment 1 (full clean rebuild) complete: `rm -rf build &&
  cmake -B build && cmake --build build` exit 0, zero errors/overflows/
  unresolved externals. CASM version banner confirmed still `0.3.0` build
  `1348` (unchanged baseline before Increment 9's promotion).
  Increment 2 (disk-session leg 1, `test.d64`) complete: fresh Command64
  boot, all four harnesses dispatched and PASS live in VICE --
  `test_casm_reloc` (`CASM RELOC: PASS`), `test_casm_symbols`
  (`CASM SYMBOLS: PASS`), `test_casm_vmm` (`CASM VMM: PASS`),
  `test_casm_faultinject` (`CASM FAULTINJECT: PASS`). Clean shell return
  after each.
  Increment 3 (disk-session leg 2, `casm_overflow_test.d64`, companion-disk
  pattern) complete: `casm_overflow_test.d64` attached at unit 9 alongside
  `test.d64`'s already-resident Command64 at unit 8, `DRIVE 9`, all three
  harnesses PASS live in VICE -- `test_casm_include` (`CASM INCLUDE: ALL
  PASS`), `test_casm_catalog` (`CASM CATALOG: PASS`),
  `test_casm_faultsource` (`CASM FAULT SOURCE: PASS`). Clean `c64[9]:>`
  shell return after each.
  Increment 4 (disk-session leg 3, `casm_include_test.d64`) complete: all
  nine harnesses PASS live in VICE -- `test_casm_freloc` (`CASM FAULT
  RELOC: PASS`), `test_casm_bounds` (`CASM BOUNDS: PASS`),
  `test_casm_cliderive` (`CASM CLIDERIVE: PASS`), `test_casm_lexer`
  (`CASM LEXER: PASS`), `test_casm_fsym` (`CASM FAULT SYMBOLS: PASS`),
  `test_casm_finc` (`CASM FAULT INCLUDE: PASS`), `test_casm_opcodes`
  (`CASM OPCODES: PASS`), `test_casm_event` (`CASM EVENT TESTS PASS`),
  `test_casm_directives` (`CASM DIRECTIVES: PASS`). Clean shell return
  after each.
  Increment 5 (disk-session leg 4, `casm_phase12_test.d64`) complete:
  fresh Command64 boot, `test_casm_expr` (`CASM EXPR: PASS`) and
  `test_casm_pass1` (`CASM PASS1: PASS`) both PASS live in VICE.
  Increment 6 (disk-session leg 5, `casm_phase13_test.d64`) complete:
  fresh Command64 boot, `test_casm_frame` → `CASM FRAME: PASS`. All 14
  Phase 13 production fixtures re-verified together in one continuous
  session, each matching its own WP's original recorded result exactly:
  `casmres1`/`casmfill1`/`casmalign1`/`casmincbin1`/`casmassert1` all
  `FILES COMPARE OK`; `casmresfwd` → `CASM: OPERAND NOT RESOLVED`;
  `casmfillnoval` → `CASM: FILL REQUIRES A VALUE`; `casmalignzero` →
  `CASM: ALIGN BOUNDARY ZERO`; `casmresrange` → `CASM: VALUE OUT OF
  RANGE`; `casmincbinmiss` → `CASM: CANNOT OPEN INPUT`;
  `casmincbinbadname` → `CASM: INCBIN FILENAME EXPECTED`;
  `casmassertfail` → `CASM: ASSERTION FAILED`; `casmassertmsg` →
  `CASM: ASSERTION FAILED: custom message`; `casmassertfwd` →
  `CASM: ASSERT OPERAND NOT RESOLVED` — every diagnostic at its
  documented line/column, clean shell return after each.
  Increment 7 (disk-session leg 6, `casm_listing_test.d64`) complete:
  fresh Command64 boot, all ten harnesses PASS live in VICE --
  `test_casm_listing` (`CASM LISTING: PASS`), `test_casm_listcap`
  (`CASM LISTCAP: PASS`), `test_casm_map` (`CASM MAP: PASS`),
  `test_casm_passcheck` (`CASM PASSCHECK: PASS`), `test_casm_spanread`
  (`CASM SPANREAD: PASS`), `test_casm_spancommit` (`CASM SPANCOMMIT:
  PASS`), `test_casm_listwrite` (`CASM LISTWRITE: PASS`), `test_casm_flist`
  (`CASM FAULT LIST: PASS`), `test_casm_flmeta` (`CASM FAULT META: PASS`),
  `test_casm_faultvmm` (`CASM FAULT VMM: PASS`). Clean shell return after
  each.

  **All 29 `test_casm_*` harnesses now confirmed clean in this
  session** (4 + 3 + 9 + 2 + 1 + 10 = 29 across the six disk-session legs),
  plus all 14 Phase 13 production fixtures -- the full consolidated sweep
  Scoping Decision called for. No regressions found; no new defect
  surfaced (unlike WP76's own precedent, this sweep found the phase
  already clean).
