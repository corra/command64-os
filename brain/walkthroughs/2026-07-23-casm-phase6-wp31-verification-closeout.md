---
feature: casm-phase6-wp31-verification-closeout
created: 2026-07-23
status: complete
---

# Walkthrough: CASM Phase 6B WP31 Verification, Walkthrough, and Completion Gate

Plan: `brain/plans/2026-07-23-casm-phase6-wp31-verification-closeout.md`

Taskwarrior: `86d8ac7e-0725-44b8-81ae-dcef143a20ad` (WP31); closes parent CASM
Phase 6B milestone `166e5352-5aa0-45bd-8bee-5baf0e878798`.

## Outcome

WP31 closed the last unchecked item in `wiki/tasks/casm.md`'s Phase 6B
Acceptance list — "duplicate, undefined, case-sensitive, and max-length
behavior match the frozen contract" — with real end-to-end proof through
production `casm.s`, then ran the full consolidated verification matrix
across every CASM Phase 6A/6B standalone test harness and trusted reference
accumulated since Phase 4. Unlike WP30, this run found no new defects: all
five standalone harnesses, all twelve byte-identical trusted references, all
three diagnostic fixtures, and the seven-fixture targeted Phase 3/4
regression sample passed cleanly on the first try. Required no production
source changes at all — purely new fixtures plus a final regression pass.

A real, non-obvious pitfall was caught and avoided at planning time, before
any fixture was written: a case-sensitivity `.seq` fixture built with
ordinary mixed-case ASCII text would have silently tested nothing, since
CASM's lexer only accepts unshifted (`$41-$5A`) or shifted (`$C1-$DA`)
PETSCII as identifier bytes, and raw `.seq` fixture files (unlike a
ca65-assembled `.s` test harness) receive no charmap conversion. Confirmed
the correct shifted-byte values empirically by compiling both quoted strings
directly with ca65 before writing the fixture.

## Baseline

| Item | Value |
| --- | --- |
| Branch | `feature/casm-phase6-wp31` |
| Branch point | `feature/casm-phase6-wp30` at `6f415e7` |
| Baseline version | `0.1.32` build 1130 |
| Plan approval | Approved as drafted, including both confirmed decisions (skip a new end-to-end symbol-table-full fixture; use a 7-fixture targeted regression sample rather than a full 60-fixture historical re-run) |

## Dependency Review Findings, Reconciled Before Implementation

1. **A naive case-sensitivity fixture would have tested nothing.**
   `isIdFirst`/`isIdCont` (`lexer.s`) accept only unshifted or shifted
   PETSCII A-Z as identifier bytes; plain ASCII lowercase is rejected as
   `CASM_DIAG_INVALID_SOURCE_BYTE`. WP27's own `symcase1` fixture relies on
   ca65's `-t c64` charmap (confirmed empirically: uppercase source letters
   in a quoted string shift to `$C1-$DA`, lowercase source letters map to
   unshifted `$41-$5A`) — but `.seq` fixtures are raw text files with no
   charmap applied at all. Resolved by constructing the shifted-byte
   variant directly via `string(ASCII <code> ...)` in the CMake generator.
2. **Symbol-table-full is out of scope**, per the user's confirmed decision:
   neither the master plan's fixture list nor the acceptance checklist names
   it, and the same `casmRunPass` -> `startFatalNear` propagation path a
   table-full failure would take is already proven by the duplicate-symbol
   fixture.
3. **Regression scope against the 60 pre-existing Phase 3/4 fixtures is
   targeted, not exhaustive**, per the user's confirmed decision: `eiRelative`'s
   WP30 defect was narrowly specific to a live-counter *difference* check,
   which no other Phase 4 diagnostic shares (`.BYTE`/`.WORD`'s range check
   tests the placeholder directly and can only under-, never over-report).
   A 7-fixture representative sample stood in for the full historical
   matrix.
4. **`casmcma2`'s "partial output" framing no longer applies literally**
   under the two-pass model (Pass 1 now catches the same syntax error before
   any output file is ever created) — a documented behavioral nuance, not a
   regression.

## Implementation

- `cmake/GenerateCasmTestFixtures.cmake`: new `casmcase1.seq` (two labels,
  same letters, unshifted vs. shifted PETSCII bytes — the shifted variant
  built via `string(ASCII 204/207/207/208 ...)`, confirmed by direct byte
  inspection: `LOOP: NOP` / `\xCC\xCF\xCF\xD0: RTS` / `LDA LOOP` / `LDA
  \xCC\xCF\xCF\xD0`) and `casmmaxid1.seq` (a 31-character label via
  `string(REPEAT "A" 31 ...)`, confirmed by direct length inspection).
- `tests/fixtures/casm/casmcase1.ref.hex`, `casmmaxid1.ref.hex`: new
  trusted-reference manifests, self-validated against
  `hex_manifest_to_bin.py`.
- `CMakeLists.txt`: `casmcase1`/`casmmaxid1` appended to `CASM_REF_NAMES` and
  `CASM_TEST_FIXTURES`. No other change — the reused (`p1dup1`, `p1undef1`,
  `brrng1`) and regression-sample fixtures (`casmwp11`, `casmzp1`,
  `casmcma2`, `casmorg3`, `casmzpi2`, `casmpcovf`, `casmnumerrh`) were
  already wired from prior WPs.
- No production `casm.s`/`emit.s`/`parser.s`/etc. changes at all — this WP
  found no defect requiring one.

## Static Verification

- No production source changed; `casm`'s build held stable at build 1130
  through the fixture-wiring changes (confirmed via a no-change rebuild)
  before the version-only completion increment was applied.
- Both new `.ref.hex` manifests self-validated against
  `hex_manifest_to_bin.py` before use.
- Both `image_d64` and `test_image_d64` build clean with `casmcase1.s`/
  `casmmaxid1.s` packaged alongside every prior CASM fixture; `test.d64`
  reports 137 blocks free.
- MAIN unchanged at 12191 of 12288 bytes (97 bytes headroom) — no
  production code was touched.

## Runtime Verification

The user ran the complete consolidated matrix from `build/test.d64` and
`build/image.d64` in VICE in one pass:

**Standalone test harnesses** (regression):

| Harness | Result |
| --- | --- |
| `TEST_CASM_VMM` | pass, all 7 fixtures |
| `TEST_CASM_SYMBOL` | pass, all 10 fixtures |
| `TEST_CASM_PASS1` | pass, all 7 fixtures |
| `TEST_CASM_PASSCHECK` | pass, both fixtures |
| `TEST_CASM_EXPR` | pass |

**Byte-identical trusted references** (`CASM` + `COMP` each):

| Reference | Result |
| --- | --- |
| `casmemit1` / `casmhello` / `casmmodes` / `casmnum2` / `casmexprn` (Phase 4/5) | identical |
| `p1fwd1` / `p1back1` / `p1size1` (WP29) | identical |
| `brfwd1` / `brback1` (WP30) | identical |
| `casmcase1` / `casmmaxid1` (WP31, new) | identical |

**Diagnostic fixtures through real `casm.s`**:

| Fixture | Result |
| --- | --- |
| `p1undef1` (`CASM_DIAG_UNDEFINED_SYMBOL`) | pass |
| `p1dup1` (`CASM_DIAG_DUPLICATE_SYMBOL`, new use through production `casm.s`) | pass |
| `brrng1` (`CASM_DIAG_BRANCH_OUT_OF_RANGE`) | pass |

**Targeted Phase 3/4 regression sample** (first re-run since the WP29
two-pass rewrite):

| Fixture | Result |
| --- | --- |
| `casmwp11` (assembles cleanly) | pass |
| `casmzp1` (assembles cleanly) | pass |
| `casmcma2` (`SYNTAX ERROR`) | pass |
| `casmorg3` (`SYNTAX ERROR`) | pass |
| `casmzpi2` (established diagnostic) | pass |
| `casmpcovf` (`ADDRESS OVERFLOW`) | pass |
| `casmnumerrh` (established diagnostic) | pass |

The user confirmed: "All tests pass."

## Phase 6B Acceptance — Complete

Closed out in full in `wiki/tasks/casm.md`:

- [x] Symbol table duplicate, undefined, case-sensitive, and max-length
      behavior match the frozen contract.
- [x] Pass 1 assigns addresses and definitions without emitting output.
- [x] Pass 2 resolves symbols and emits final output.
- [x] Relative branches are computed from resolved symbols.
- [x] A Pass 1/Pass 2 disagreement is treated as fatal.
- [x] Static programs with forward and backward references match trusted
      reference binaries byte-for-byte.

**All six items are now checked. CASM Phase 6B is complete.**

## DOX Closeout

Root, `src`, `src/external`, `src/external/casm`, `tests` contracts
rechecked. `brain/KNOWLEDGE.md` records the final consolidated verification
result. `AGENTS.md` needed no change (no durable local contract changed;
this WP added no new ABI). Closes the CASM Phase 6B Taskwarrior milestone
(`166e5352-5aa0-45bd-8bee-5baf0e878798`) alongside WP31 itself.

## Completion Dry-Run and Final Increment (`0.1.32` -> `0.1.33`)

| Measurement | Value |
| --- | --- |
| Baseline | `0.1.32` build 1130 |
| Applied version | `0.1.33` |
| Build number | 1131 (incremented exactly once) |
| No-change rebuild | pass, held at 1131 |
| `image_d64` | pass |
| `test_image_d64` | pass |

## Approval

The user confirmed the full consolidated VICE verification matrix ("All
tests pass").

WP31 is complete, and with it the CASM Phase 6B milestone closes. Taskwarrior
(`86d8ac7e`) and the parent CASM Phase 6B milestone (`166e5352`) are both
marked done. `wiki/tasks/casm.md` and `brain/task.md` reflect the closed
milestone. CASM Phase 7 (VMM-backed source and multiple top-level inputs)
and Phase 8 (R6 relocation consumption) remain separately gated and
unstarted, per the master plan's own sequencing.
