---
feature: casm-phase7-wp36-verification-closeout
created: 2026-07-24
status: complete
---

# Walkthrough: CASM Phase 7 WP36 Verification, Walkthrough, and Completion Gate

Plan: `brain/plans/2026-07-24-casm-phase7-wp36-verification-closeout.md`

Taskwarrior: `c69b675f-def4-4fbb-a767-e32794e77af5` (WP36, completed);
closes the CASM Phase 7 milestone `1a0d0dc8-3267-4885-aa83-adf923d56422`
(also completed). `command64.casm` project reports 100% complete.

## Outcome

WP36 closed CASM Phase 7 ("VMM-backed source and multiple top-level
inputs") by bundling the full accumulated WP32-35 fixture/harness matrix
into one consolidated verification run, closing two real gaps found by
tracing the master plan's own Phase 7 gate text before implementation, and
closing the CASM Phase 7 milestone. No production source changed; this WP
is verification-only, mirroring WP25 (Phase 6A) and WP31 (Phase 6B).

One real implementation-time discrepancy against the plan surfaced (a disk-
space limit the plan's fixture sizing hadn't accounted for) and was
corrected with the user's explicit approval before proceeding, per the
plan's own Stop Conditions.

## Baseline

| Item | Value |
| --- | --- |
| Branch | `feature/casm-phase7-wp36` |
| Branch point | `feature/casm-phase7-wp35` at `caa2e3e` |
| Baseline version | `0.1.37` build 1141, re-measured (not merely recalled) at 189/13568 bytes MAIN headroom via `ld65 -m` |
| Plan approval | Approved as drafted, including all three confirmed scope decisions below |

## Two Gaps Found Before Implementation

1. **No fixture had ever proven a large, under-cap input actually
   assembles successfully.** The master plan's Phase 7 gate text ("small
   inputs remain byte-identical, while large and multiple inputs assemble
   successfully with correct diagnostics") was only half-covered by the
   four Phase 7 Acceptance items WP32 derived from it. Every existing
   "large" fixture was either invalid syntax (`casm256`/`casmmulti`/
   `casmvmm65`/`casmvmm128`, pure `sourceRefill` traversal proof, never
   reaching a successful assembly) or deliberately over the 65535-byte cap
   (`casmmfovf1`/`casmmfovf2`, the failure path). The largest fixture to
   ever produce a real, byte-verified successful PRG was `casmmodes`/
   `casmmf3`, both well under a few hundred bytes.
2. **WP31's targeted 7-fixture Phase 3/4 diagnostic regression sample had
   never been re-run since Phase 7 replaced the entire source-loading
   layer those fixtures depend on to reach the lexer/parser at all.**
   WP33's own plan explicitly used a *different* fixture set and noted
   there was no "same as before" baseline to re-confirm at that point;
   WP34's and WP35's verification sections each used their own different,
   narrower samples. Between WP31 and WP36, `source.s`'s physical-read path
   was fully replaced by a VMM-cached load/refill (WP33), then extended for
   multi-file boundaries (WP34) and diagnostic file identity (WP35) -- a
   substantial rewrite of exactly the layer every one of WP31's 7 fixtures
   depends on, never re-confirmed since.

The user confirmed three scope decisions given these findings: add a new
large fixture to close gap 1 (rather than treat existing evidence as
sufficient); verify it via a reviewed single-opcode repetition rule for
both the source and the reference (rather than a hand-typed manifest or a
size-only check); and split it across two files (rather than one), so it
proves both the "large" and "multiple" halves of the gate text together.

## Implementation

- `cmake/GenerateCasmTestFixtures.cmake`: new `casmbiga.seq` (`.ORG $C000`
  + 3000 `NOP` statements via `string(REPEAT "NOP\n" 3000 ...)`) and
  `casmbigb.seq` (3000 more `NOP` statements, no `.ORG` -- continues the
  combined PC from file A, matching `casmmf1`-`casmmf3`'s convention).
- `tests/fixtures/casm/casmbig1.ref.hex`: new trusted reference. Body is
  `00 C0` (load-address header) followed by `EA` repeated 6000 times, with
  `# bytes: 6002` and `# sha256: ...` self-check metadata. Self-validated
  against `scripts/hex_manifest_to_bin.py` before wiring in (6002 bytes,
  matching sha256 `7288e489...`). Generated from one reviewed repetition
  rule documented inline in the file, not hand-typed token by token.
- `CMakeLists.txt`: `casmbig1` appended to `CASM_REF_NAMES` (so the shared
  `hex_manifest_to_bin.py`/`casm_reference_fixtures` machinery builds it
  unchanged).
- WP31's 7-fixture Phase 3/4 regression sample (`casmwp11`/`casmzp1`/
  `casmcma2`/`casmorg3`/`casmzpi2`/`casmpcovf`/`casmnumerrh`) re-run
  unmodified, no new files.

## A Real Discrepancy Found During Implementation, Fixed With Approval

`casmbiga.seq`/`casmbigb.seq`'s raw source text (12011/12000 bytes) is far
larger than its assembled 1-byte-per-`NOP` output -- a distinction the
plan's own sizing reasoning hadn't weighed against disk capacity. Building
`test_image_d64` after wiring the fixtures into `CASM_TEST_FIXTURES`
failed with "Disk full": only 110 blocks were free beforehand (confirmed by
temporarily stashing the change and rebuilding), 96 were consumed by the
new pair, leaving 14 -- not enough for the trailing `edlinfull` fixture (64
blocks).

This is exactly the same problem `casmmfovf1`/`casmmfovf2` (WP34) already
hit for the same underlying reason, which is why they already have their
own dedicated `casm_overflow_test_d64` disk image. Presented to the user
with the exact block-count numbers and a proposed fix before making any
further change; approved as proposed:

- Removed `casmbiga.seq`/`casmbigb.seq` from `CASM_TEST_FIXTURES` (they
  remain unconditionally generated by the script regardless, matching
  `casmmfovf1`/`casmmfovf2`'s identical existing exclusion for the same
  reason -- confirmed this only affects CMake's incremental-build
  dependency tracking, not whether the files get written).
- Added `casmbiga.s`/`casmbigb.s` to `casm_overflow_test_d64` via the same
  `CC1541`-append pattern already used for `casmmfovf1`/`casmmfovf2`.
- Added `comp.prg` and the `casmbig1.ref` trusted-reference PRG to
  `casm_overflow_test_d64` too -- that disk previously carried only
  `casm.prg`, since the overflow fixtures only ever needed a diagnostic to
  fire, never a `COMP` byte-identity check. `casmbig1` is excluded from the
  generic `CASM_REF_NAMES` -> `test.d64` append loop (via an explicit
  `if(NOT REF_NAME STREQUAL "casmbig1")` guard) since its matching `.seq`
  inputs live only on `casm_overflow_test_d64`, not `test.d64`.

Result after the fix: `test.d64` rebuilds at exactly 110 blocks free again
(unchanged from before WP36), and `casm_overflow_test_d64` builds clean
with 204 blocks free (`casm` 58, `comp` 5, `casmmfovf1.s` 158,
`casmmfovf2.s` 119, `casmbiga.s` 48, `casmbigb.s` 48, `casmbig1.ref` 24).

## Static Verification

- `casm` build 1141 (baseline) -> 1142 (version-only completion increment,
  `VERSION_STAGE` `"37"` -> `"38"`), no-change rebuild stable at each step.
- `image_d64`, `test_image_d64`, and `casm_overflow_test_d64` all build
  clean.
- MAIN measured via `ld65 -m`: CODE `$234E` (9038) + RODATA `$925` (2341) +
  BSS `$7D0` (2000) = 13379 of 13568 bytes -- 189 bytes headroom, identical
  to WP35's close (WP36 added no production code, only test fixtures).

## Runtime Verification

The user ran the full consolidated matrix and confirmed: "all tests pass."

| Check | Result |
| --- | --- |
| 5 standalone harnesses (`TEST_CASM_VMM`/`SYMBOL`/`PASS1`/`PASSCHECK`/`EXPR`) | all pass |
| 15 pre-existing byte-identical trusted references | all identical |
| New: `casmbig1` (`CASM CASMBIGA.S CASMBIGB.S` -> `COMP CASMBIG1.PRG CASMBIG1.REF`, from `casm_overflow_test.d64`) | identical |
| `p1undef1` / `p1dup1` / `brrng1` | established diagnostics reproduced |
| `casmmfcr1`/`casmmfcr2` (non-first-file filename) | `IN FILE CASMMFCR2.S` |
| `casmmfdiag1`/`casmmfdiag2` (first-file filename) | `IN FILE CASMMFDIAG1.S` |
| 9th source file (`CASM A B C D E F G H I`) | `CASM: TOO MANY SOURCE FILES` |
| `casmmfovf1`/`casmmfovf2` (combined overflow, `casm_overflow_test.d64`) | `CASM: SOURCE OFFSET OVERFLOW` |
| WP31 7-fixture Phase 3/4 regression sample (`casmwp11`/`casmzp1`/`casmcma2`/`casmorg3`/`casmzpi2`/`casmpcovf`/`casmnumerrh`) | all reproduced their established WP31 outcomes |

No production source defect was found -- unlike WP25/WP30, every case
passed on the first VICE run.

## Documentation and DOX Closeout

- `brain/KNOWLEDGE.md`: closing note added under the Phase 7 arc (0C.10
  through 0C.13), recording the final consolidated verification and both
  gaps this WP closed.
- `wiki/tasks/casm.md`: WP36 checked complete; a fifth Phase 7 Acceptance
  item added and checked ("a large, under-cap input assembles
  successfully"); Phase 7 milestone closing text added.
- `brain/task.md`: WP36 entry added and closed.
- `CHANGELOG.md`: Unreleased entry added.
- Taskwarrior: WP36 (`c69b675f-def4-4fbb-a767-e32794e77af5`) completed,
  which unblocked and allowed completion of the CASM Phase 7 milestone
  (`1a0d0dc8-3267-4885-aa83-adf923d56422`). `command64.casm` project now
  100% complete (0 of 62 tasks remaining).

## Completion

**CASM Phase 7 WP36 is complete, and with it the CASM Phase 7 milestone
closes**, per the completion gate in
`brain/plans/2026-07-24-casm-phase7-wp36-verification-closeout.md`: the
full consolidated matrix passed, the one implementation-time discrepancy
found was fixed with explicit approval and re-verified, `wiki/tasks/casm.md`'s
Phase 7 Acceptance is fully checked (five of five items), the version-only
completion increment is verified, all three images build clean with a
stable no-change rebuild, and the user explicitly confirmed the runtime
results. All five Phase 7 Acceptance items are now checked. CASM Phase 8
(native R6 relocation consumption) remains separately gated and unstarted
per `AGENTS.md`.
