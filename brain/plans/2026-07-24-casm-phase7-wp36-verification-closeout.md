---
feature: casm-phase7-wp36-verification-closeout
created: 2026-07-24
status: complete
---

# Plan: CASM Phase 7 WP36 - Verification, Walkthrough, and Completion Gate

## Objective

WP36 closes CASM Phase 7 ("VMM-backed source and multiple top-level
inputs") by bundling the full accumulated WP32-WP35 fixture/harness matrix
into one consolidated verification run, closing two real gaps a fresh trace
found (Dependency Review below), and closing the CASM Phase 7 milestone.
This is structurally the same kind of work package as WP25 (Phase 6A's
closeout) and WP31 (Phase 6B's closeout): it implements no new production
source-loading, CLI, or diagnostic behavior, only exercises and proves what
WP32-35 already built, plus one small new fixture pair the gap review below
justifies.

Taskwarrior: `c69b675f-def4-4fbb-a767-e32794e77af5` (WP36, verified live via
`task c69b675f... information`: Description "CASM Phase 7 WP36:
verification, walkthrough, and completion gate", Status Pending, blocking
the milestone). Parent CASM Phase 7 milestone
`1a0d0dc8-3267-4885-aa83-adf923d56422` (verified live: Description "CASM
Phase 7: VMM-backed source and multiple top-level inputs", blocked by
WP36) closes when WP36 does. Both UUIDs match [[project-casm-phase7-wp35-complete]]'s
recorded map exactly -- no further correction needed.

Prerequisite: CASM Phase 7 WP35 is complete and approved (CASM `0.1.37`
build 1141, commit `caa2e3e`). Approval of this plan is required before
activation or source edits, per the CASM `AGENTS.md` gate. Active on
`feature/casm-phase7-wp36` from `feature/casm-phase7-wp35`'s tip (`caa2e3e`).

## Baseline

- CASM `0.1.37` build 1141. `MAIN: start = $3400, size = $3500` (13568
  bytes). Re-measured directly via `ld65 -m` against the current
  `build/out_casm/*.o` set (not merely recalled from WP35's closeout note):
  CODE `$234E` (9038) + RODATA `$925` (2341) + BSS `$7D0` (2000) = 13379 of
  13568 bytes -- **189 bytes headroom**, exactly matching WP35's own closing
  figure, confirming no source has moved since Phase 7 WP35 closed.
- `wiki/tasks/casm.md`'s Phase 7 Acceptance section already shows all four
  items checked (WP33, WP34, WP34, WP35). Unlike WP31 (which closed the one
  remaining unchecked Phase 6B item), **WP36 has no unchecked acceptance
  item to close directly** -- its job is the consolidated matrix, the two
  gaps below, and the milestone close itself.
- 16 standing `CASM_REF_NAMES` byte-identical trusted references exist: 12
  pre-Phase-7 plus `casmmf1`/`casmmf2`/`casmmf3` (WP34). 5 standalone test
  harnesses exist (`TEST_CASM_VMM`, `TEST_CASM_SYMBOL`, `TEST_CASM_PASS1`,
  `TEST_CASM_PASSCHECK`, `TEST_CASM_EXPR`). A full inventory of Phase-7-era
  diagnostic fixtures already exists: `casmmfcr1`/`casmmfcr2` (non-first-file
  filename), `casmmfdiag1`/`casmmfdiag2` (first-file filename), the 9th-
  source-file rejection case, and `casmmfovf1`/`casmmfovf2` (combined-
  overflow, on its own dedicated `casm_overflow_test.d64`).

## Dependency Review and Discrepancies Reconciled

Direct tracing of the master plan's Phase 7 gate text against the current
`wiki/tasks/casm.md` Acceptance list and every WP32-35 plan's own
verification section found two real gaps, beyond what WP32's own review
already covered:

1. **No fixture proves a large, under-cap input actually assembles
   successfully -- the master plan's own gate wording is only half-covered.**
   The master plan's Phase 7 gate text
   (`brain/plans/2026-07-16-casm-assembler-implementation-plan.md:339-340`)
   reads: *"small inputs remain byte-identical, while large and multiple
   inputs assemble successfully with correct diagnostics."* The four Phase 7
   Acceptance items WP32 derived from it cover: small-input byte-identity
   (WP33), multi-file combined-scope correctness (WP34), multi-file
   diagnostic filename correctness (WP35), and the combined-overflow
   *failure* case (WP34) -- but **none of the four is a large, under-cap
   input that assembles *successfully***. Every existing "large" fixture is
   either not valid CASM syntax at all (`casm256`/`casmmulti`/`casmvmm65`/
   `casmvmm128`, which exist purely to exercise `sourceRefill`'s block/chunk
   traversal, never reach a successful assembly) or is deliberately *over*
   the 65535-byte cap to prove the failure path (`casmmfovf1`/`casmmfovf2`,
   40000/30000 bytes). The largest fixture that has ever produced a real,
   byte-verified successful PRG is `casmmodes`/`casmmf3`, both well under a
   few hundred bytes. **Confirmed with the user (2026-07-24): resolved by
   adding one new large, multi-file, successful-assembly fixture pair**
   (Contract item 1 below), which closes both halves of the gate text
   ("large" and "multiple") in one fixture rather than two.
2. **Verifying a multi-KB successful-assembly fixture by hand-typed hex
   manifest, the way every other `CASM_REF_NAMES` entry is verified, is
   impractical, and the manifest format has no repeat directive.**
   `hex_manifest_to_bin.py`'s manifest grammar (`scripts/hex_manifest_to_bin.py`)
   is whitespace-separated two-digit hex tokens plus two optional `#
   bytes:`/`# sha256:` metadata checks -- no repetition syntax exists, and
   hand-typing thousands of tokens would not actually make the manifest more
   trustworthy, only more tedious to review. **Confirmed with the user
   (2026-07-24): resolved by a repeated-single-opcode fixture** (Contract
   items 1-2 below) -- both the `.seq` source and the `.ref.hex` manifest are
   generated from one reviewed repetition rule (`NOP` = `$EA` implied, 1
   byte, per the 6502 spec -- already independently used and proven correct
   by WP31's `casmcase1` fixture, though not relied on here as the source of
   truth; the spec fact is elementary and re-confirmed directly), keeping the
   human-reviewable claim to "one 2-byte header plus N copies of one
   hand-verified byte" rather than N individually-typed tokens. This needs no
   change to `hex_manifest_to_bin.py` or to `CASM_REF_NAMES`'s existing
   per-entry CMake machinery -- the new manifest is a committed file like
   every other one, just generated once rather than hand-typed once.
3. **WP31's targeted 7-fixture Phase 3/4 diagnostic-category regression
   sample has never been re-run since Phase 7 replaced the entire source
   layer it was designed to protect.** WP31 built `casmwp11`/`casmzp1`/
   `casmcma2`/`casmorg3`/`casmzpi2`/`casmpcovf`/`casmnumerrh` specifically to
   catch a regression in Phase 3/4 diagnostic categories the WP29/30
   regression set never touched. WP33's own plan explicitly notes (line
   315-324) that its Phase 3 traversal fixtures are a *different* set from
   WP31's sample and that there was "no 'same as before' baseline to
   re-confirm" at that point -- WP33 did not re-run WP31's sample. Tracing
   WP34's and WP35's verification sections confirms neither re-ran it either
   (WP34's matrix is multi-file-specific; WP35's "representative sample" of
   `casmbadb`/`casmcol1`/`casmshort`-equivalent fixtures is a different,
   3-item set). **Between WP31 and today, `source.s`'s physical-read path
   was fully replaced by a VMM-cached load/refill (WP33), then extended for
   multi-file boundaries (WP34) and diagnostic file identity (WP35) -- a
   substantial rewrite of exactly the layer every one of WP31's 7 fixtures
   depends on to reach the lexer/parser at all, never re-confirmed since.**
   Resolved: WP36 re-runs the same 7 fixtures, unmodified, no new files,
   closing this gap as part of its consolidated matrix.
4. **Taskwarrior UUID bookkeeping is already correct for WP36 and the
   milestone**, reconfirmed live via `task <uuid> information` for both
   (Description fields checked against expectation), not merely recalled
   from [[project-casm-phase7-wp35-complete]] -- no further correction
   needed, unlike the WP32-35 citation error that memory already fixed.

## Contract / Implementation Details

1. **New fixture pair `casmbiga.seq`/`casmbigb.seq`**
   (`cmake/GenerateCasmTestFixtures.cmake`, via `string(REPEAT "NOP\n" 3000
   ...)` for each): file A opens `.ORG $C000` followed by 3000 `NOP`
   statements; file B is 3000 more `NOP` statements with **no** `.ORG`,
   continuing the combined program counter from file A's end -- the same
   "later files don't re-`.ORG`" convention `casmmf1`-`casmmf3` already
   established. Combined output: the 2-byte `$C000` load-address header
   followed by 6000 `$EA` bytes (6002 total), spanning `$C000`..`$D747` --
   comfortably under both the `$FFFF` PC ceiling and the 65535-byte combined
   multi-file cap (6000 is roughly 9% of it), and roughly 12x larger than
   the largest fixture that has ever produced a byte-verified successful
   assembly to date.
2. **New trusted reference `tests/fixtures/casm/casmbig1.ref.hex`**: a
   committed manifest whose body is `00 C0` (the load-address header) followed
   by `EA` repeated 6000 times, with a `# bytes: 6002` self-check directive
   (the existing `hex_manifest_to_bin.py` metadata convention, so a
   miscount is a hard build error, not a silent pass) and an inline comment
   at the top of the file documenting the repetition rule and citing this
   plan -- so a reviewer confirms the *rule*, not 6000 individually-typed
   tokens. No change to `hex_manifest_to_bin.py` or to `CASM_REF_NAMES`'s
   existing per-entry `add_custom_command` loop -- `casmbig1` is appended to
   `CASM_REF_NAMES` exactly like every other entry.
3. **`casmbiga`/`casmbigb` are appended to `CASM_TEST_FIXTURES`** so both
   `.seq` inputs are packaged on `test.d64`, matching every other multi-file
   fixture's packaging (no new dedicated disk image needed -- unlike
   `casmmfovf1`/`casmmfovf2`, 6002 bytes is small enough for the shared
   `test.d64`).
4. **WP31's 7-fixture Phase 3/4 regression sample is re-run once more,
   unmodified, no new files** (Dependency Review item 3): `casmwp11`,
   `casmzp1`, `casmcma2`, `casmorg3`, `casmzpi2`, `casmpcovf`,
   `casmnumerrh`.
5. **No production source change is planned.** Any defect the consolidated
   matrix surfaces is handled exactly as WP25/WP30/WP31's precedent:
   presented to the user with root cause and a proposed fix before any
   change, applied only with explicit approval, scoped as narrowly as the
   defect allows.

## Scope

Included:

- `cmake/GenerateCasmTestFixtures.cmake`: new `casmbiga.seq`/`casmbigb.seq`
  (`string(REPEAT "NOP\n" 3000 ...)` each).
- `tests/fixtures/casm/casmbig1.ref.hex`: new trusted-reference manifest
  (Contract item 2).
- `CMakeLists.txt`: `casmbig1` appended to `CASM_REF_NAMES`; `casmbiga.seq`/
  `casmbigb.seq` appended to `CASM_TEST_FIXTURES`.
- The full consolidated verification matrix (Verification Plan below):
  every standalone harness (5), every byte-identical trusted reference (15
  existing + `casmbig1` = 16), every Phase-7-era diagnostic fixture through
  real `casm.s`, the WP31 7-fixture Phase 3/4 regression sample, and this
  WP's own `casmbig1` pair.
- Closing the CASM Phase 7 milestone (Taskwarrior, `wiki/tasks/casm.md`,
  `brain/task.md`, `brain/KNOWLEDGE.md`) upon explicit user approval.
- Any production source fix a newly-discovered defect requires, handled
  exactly as WP25/WP30/WP31's precedent.

Excluded:

- CASM Phase 8 (R6 relocation consumption) activation -- a separate,
  later gate, per the master plan's own sequencing.
- Any change to the frozen Phase 0C.10-0C.13 ABI/storage/CLI contract.
- A full historical re-run of every pre-Phase-6B fixture -- WP31 already
  scoped this down to its own targeted 7-fixture sample (per the user's
  confirmed decision at the time); WP36 reuses that same sample rather than
  re-litigating its size.

## Expected Files

| File | Action |
| --- | --- |
| `brain/plans/2026-07-24-casm-phase7-wp36-verification-closeout.md` | this document |
| `cmake/GenerateCasmTestFixtures.cmake` | Modify: new `casmbiga.seq`, `casmbigb.seq` |
| `tests/fixtures/casm/casmbig1.ref.hex` | Create |
| `CMakeLists.txt` | Modify: `CASM_REF_NAMES`, `CASM_TEST_FIXTURES` |
| `src/external/casm/*.s` | Unplanned: only if a newly-discovered defect requires a fix, per explicit user approval (WP25/30/31 precedent) |
| `src/external/casm/casm.s` | version-only stage increment at completion |
| `src/external/casm/BUILD_CASM` | build-managed increment |
| `wiki/tasks/casm.md`, `brain/task.md`, `brain/KNOWLEDGE.md`, `CHANGELOG.md` | Closeout updates; closes the CASM Phase 7 milestone |

## ABI, Storage, and Runtime Effects

None planned. No new record layout, diagnostic, or exported routine -- WP36
is verification-only. If a defect surfaces during the consolidated matrix,
any resulting change is scoped, presented, and approved exactly as
WP25/WP30/WP31's precedent, and this section is amended in the walkthrough
to record it.

## Verification Plan

The full consolidated matrix, run once at the end after the new fixture and
CMake wiring are in place:

1. **Standalone test harnesses** (unchanged since their own WPs; re-run
   here only to confirm nothing regressed): `TEST_CASM_VMM` (7 fixtures),
   `TEST_CASM_SYMBOL` (10 fixtures), `TEST_CASM_PASS1` (7 fixtures),
   `TEST_CASM_PASSCHECK` (2 fixtures), `TEST_CASM_EXPR`.
2. **Byte-identical trusted references (16 total)** -- `CASM <name>.S` then
   `COMP <name>.PRG <name>.REF`, expect IDENTICAL for every one:
   `casmemit1`, `casmhello`, `casmmodes`, `casmnum2`, `casmexprn`, `p1fwd1`,
   `p1back1`, `p1size1`, `brfwd1`, `brback1`, `casmcase1`, `casmmaxid1`,
   `casmmf1`, `casmmf2`, `casmmf3`, and **new: `casmbig1`** (`CASM
   CASMBIGA.S CASMBIGB.S`, then `COMP` against `casmbig1.ref`).
3. **Diagnostic fixtures through real `casm.s`:** `p1undef1`
   (`CASM_DIAG_UNDEFINED_SYMBOL`), `p1dup1` (`CASM_DIAG_DUPLICATE_SYMBOL`),
   `brrng1` (`CASM_DIAG_BRANCH_OUT_OF_RANGE`), `casmmfcr1`/`casmmfcr2`
   (non-first-file filename in the diagnostic trailer), `casmmfdiag1`/
   `casmmfdiag2` (first-file filename in the diagnostic trailer), the 9th
   top-level source token (`CASM_DIAG_EXTRA_SOURCE`), and `casmmfovf1`/
   `casmmfovf2` (`CASM_DIAG_SOURCE_OFFSET_OVERFLOW`, on
   `casm_overflow_test.d64`).
4. **WP31's targeted 7-fixture Phase 3/4 regression sample** (Contract item
   4, Dependency Review item 3): `casmwp11` (assembles cleanly), `casmzp1`
   (assembles cleanly), `casmcma2` (`SYNTAX ERROR`), `casmorg3` (`SYNTAX
   ERROR`), `casmzpi2` (its established range/addressing-mode diagnostic),
   `casmpcovf` (`ADDRESS OVERFLOW`), `casmnumerrh` (its established
   numeric-overflow diagnostic) -- each expected to reproduce exactly the
   same outcome WP31 established, now through the fully VMM-backed,
   multi-file-capable source layer.
5. Build both relocation bases, `test_image_d64`, and
   `casm_overflow_test_d64`; confirm a no-change rebuild holds `BUILD_CASM`
   stable before any source edit and increments exactly once after (or not
   at all, if no production source changes are needed).
6. Every failing case is investigated before completion is requested. A
   newly-discovered defect is presented to the user with its root cause and
   a proposed fix before any source is touched, matching WP25/WP30/WP31's
   precedent exactly -- this is the Phase 7 completion gate itself, so
   nothing is waved through.

## Atomic Implementation Increments

1. Add `casmbiga.seq`/`casmbigb.seq` to
   `cmake/GenerateCasmTestFixtures.cmake`; generate and self-validate
   `casmbig1.ref.hex` (`00 C0` + 6000x `EA`, `# bytes: 6002`) against
   `hex_manifest_to_bin.py` before wiring it in.
2. Append `casmbig1` to `CASM_REF_NAMES` and `casmbiga`/`casmbigb` to
   `CASM_TEST_FIXTURES` in `CMakeLists.txt`; build both relocation bases,
   `test_image_d64`, and `casm_overflow_test_d64`; confirm clean build.
3. Run the full consolidated matrix in VICE (ask the user): 5 standalone
   harnesses, 16 byte-identical references (including the new `casmbig1`),
   8 diagnostic-fixture scenarios, and the 7-fixture Phase 3/4 regression
   sample. Record every result.
4. If any case fails: stop, root-cause it, present the finding and a
   proposed fix to the user (per Dependency Review and the Stop Conditions
   below), apply only with explicit approval, then re-run the full matrix
   again before proceeding.
5. Update `wiki/tasks/casm.md`: record the `casmbig1` large/multi-file
   successful-assembly proof against the master plan's gate text
   (Dependency Review item 1), and close the CASM Phase 7 milestone section.
6. Apply the version-only completion increment, rebuild, confirm no-change
   rebuild stability, all three images pass.
7. Update `brain/task.md`, `brain/KNOWLEDGE.md` (a closing note on the
   Phase 7 arc -- 0C.10 through 0C.13 -- recording the final consolidated
   verification and the two gaps this WP closed), `CHANGELOG.md`,
   Taskwarrior (complete WP36 *and* the CASM Phase 7 parent milestone).
8. Draft the walkthrough with the complete matrix result and request
   explicit completion approval -- this closes the CASM Phase 7 milestone,
   per this plan's own definition (mirroring WP25/WP31's role for Phase
   6A/6B).

## Failure and Cleanup

No new failure mode expected. If verification surfaces a genuine defect, it
is handled exactly as WP25/WP30/WP31's precedent: presented to the user with
root cause and proposed fix before any source change, applied only with
explicit approval, scoped as narrowly as the defect allows. The standalone
test harnesses have no new cleanup requirements (unchanged since their own
WPs).

## Documentation and DOX Closeout

Update this plan, `brain/KNOWLEDGE.md` (a closing note under the Phase 7 arc
-- 0C.10 through 0C.13 -- recording the final consolidated verification
result and the two Dependency Review gaps this WP closed, or a new Phase
0C.14 section if a defect fix requires recording new as-built detail,
matching WP25/WP30/WP31's own precedent for when a closeout WP finds
something worth freezing), `brain/task.md`, `wiki/tasks/casm.md` (close the
Phase 7 milestone section), `CHANGELOG.md`, Taskwarrior (WP36 and the CASM
Phase 7 parent milestone), and a new walkthrough. `AGENTS.md` is not
expected to change (no new durable local contract -- `casmbig1` proves an
already-documented behavior at a larger scale, it doesn't establish a new
one) unless a defect fix touches one; re-check during implementation.

## Stop Conditions

Stop if WP35 is not complete and approved. Stop if any fixture reveals a
defect whose scope or fix is not small and well-understood enough for the
user to approve fixing in place -- matching WP25/WP30/WP31's precedent, a
defect requiring an ABI change or non-obvious redesign gets its own
remediation plan rather than being folded into WP36 silently. Stop if a
further material discrepancy is found during implementation, requiring this
plan to be amended and re-approved.

## Completion Gate

WP36 is complete -- and with it, the CASM Phase 7 milestone closes -- when:
the full consolidated matrix (5 standalone harnesses, 16 byte-identical
references, 8 diagnostic-fixture scenarios, 7-fixture Phase 3/4 regression
sample) passes in VICE; any defect found along the way has been fixed with
explicit user approval and re-verified; `wiki/tasks/casm.md`'s Phase 7
Acceptance remains fully checked and records the `casmbig1` gate-text
closure; the version-only completion increment is verified; all three
images (`image_d64`, `test_image_d64`, `casm_overflow_test_d64`) build clean
with a stable no-change rebuild; and the user explicitly approves the
walkthrough. This closes CASM Phase 7 but does not activate CASM Phase 8
(native R6 relocation), which remains separately gated per the master plan.

## Progress

- 2026-07-24: Drafted after confirming CASM Phase 7 WP35's completion gate
  (`0.1.37` build 1141, 189 bytes MAIN headroom, re-measured directly via
  `ld65 -m` and confirmed to match WP35's own closing figure exactly rather
  than merely recalled). Verified both relevant Taskwarrior UUIDs live
  (`task <uuid> information`) against [[project-casm-phase7-wp35-complete]]'s
  recorded map -- both correct, no further citation fix needed. Traced the
  master plan's literal Phase 7 gate text against the current Acceptance
  checklist and found a real, previously unnoticed gap: none of the four
  checked Acceptance items is actually a large, under-cap input that
  assembles *successfully* -- every existing "large" fixture is either
  invalid syntax (pure traversal-boundary proof) or deliberately over the
  cap (the failure-path proof). Also found, by reading WP33's own plan text
  and re-checking WP34/35's verification sections, that WP31's 7-fixture
  Phase 3/4 diagnostic regression sample has never been re-run since Phase 7
  replaced the entire source-loading layer those fixtures depend on to
  reach the lexer/parser at all. Asked the user three scope questions given
  these findings: whether to close the large-input gap with a new fixture
  (confirmed: yes), how to verify a multi-KB fixture given the manifest
  format's lack of a repeat directive (confirmed: generate both the source
  and the reference from one reviewed single-opcode repetition rule, not a
  hand-typed manifest or a size-only check), and whether the new fixture
  should be single- or multi-file (confirmed: split across two files, so it
  proves both the "large" and "multiple" halves of the gate text together).
  Designed the `casmbiga`/`casmbigb`/`casmbig1` fixture accordingly (3000 +
  3000 `NOP` statements, 6002-byte PRG). Awaiting user approval before
  implementation begins.
- 2026-07-24 (later): Approved as drafted. Activated on
  `feature/casm-phase7-wp36` from `feature/casm-phase7-wp35`'s tip
  (`caa2e3e`). Implemented `casmbiga.seq`/`casmbigb.seq` and
  `casmbig1.ref.hex` exactly as planned, self-validated via
  `hex_manifest_to_bin.py` (6002 bytes, sha256 confirmed) before wiring in.
  Building `test_image_d64` then found a real discrepancy the plan's
  fixture sizing hadn't accounted for: `casmbiga.seq`/`casmbigb.seq`'s raw
  source text (12011/12000 bytes, since source text is far larger than its
  1-byte-per-`NOP` assembled output) did not fit on `test.d64` (110 blocks
  free beforehand, 96 needed, no room left for the trailing `edlinfull`
  fixture) -- the identical problem `casmmfovf1`/`casmmfovf2` already
  solved. Presented the exact numbers and a proposed fix (move
  `casmbiga.s`/`casmbigb.s` plus `casmbig1`'s `COMP` verification onto the
  existing `casm_overflow_test_d64` disk image, adding `comp.prg` to it)
  to the user before proceeding; approved as proposed. `test.d64` rebuilt
  clean at exactly 110 blocks free again; `casm_overflow_test_d64` built
  clean with 204 blocks free. User ran the full consolidated matrix (5
  standalone harnesses, 16 byte-identical references including the new
  `casmbig1`, 7 diagnostic-fixture scenarios, the 7-fixture Phase 3/4
  regression sample) and confirmed: "all tests pass" -- no production
  source defect found. Applied the version-only completion increment: final
  CASM `0.1.38` build 1142, no-change rebuild stable, all three images
  build clean, MAIN headroom 189 of 13568 bytes (unchanged). Updated
  `wiki/tasks/casm.md` (WP36 checked, a fifth Phase 7 Acceptance item
  added and checked, Phase 7 milestone closing text), `brain/task.md`,
  `brain/KNOWLEDGE.md` (Phase 7 arc closing note), `CHANGELOG.md`, and
  Taskwarrior (WP36 and the CASM Phase 7 milestone both completed --
  `command64.casm` project now 100% complete). Drafted the walkthrough:
  `brain/walkthroughs/2026-07-24-casm-phase7-wp36-verification-closeout.md`.
  **WP36 is complete, and with it the CASM Phase 7 milestone closes.** CASM
  Phase 8 remains separately gated and unstarted.
