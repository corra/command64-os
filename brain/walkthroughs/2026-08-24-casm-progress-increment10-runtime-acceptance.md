# CASM Progress Increment 10 - Runtime Acceptance Walkthrough

Status: **ACCEPTED - user-approved 2026-08-31.** All planned live cases
have evidence; no findings. Only Increment 11 (completion gate) remains
for the feature.

Plan: `brain/plans/2026-08-24-casm-progress-increment10-runtime-acceptance.md`

## Setup

- VICE 3.10 PAL C64SC, `WarpMode: 0` (normal speed).
- Fresh `vice_autostart` of `build/casm_progress_test.d64` on unit 8;
  screen row 0 decodes `Command 64-DOS Version 0.4.1.2680`; prompt
  `C64[8]:>`.
- Binary under test: `CASM V0.4.0.1379` banner confirmed on the first run
  (the Increment 9 remediation build; `casm.prg` sha256 `72549659...`).
- Disk rebuilt with the new `casmpgbad.s` failure fixture (433 blocks free).

Representative subset re-driven live (user-approved scope); the exhaustive
10/10 fixture + 5/5 option-identity matrix stands on Increment 4's own
evidence against the byte-identical-output invariant.

## Cases

### Case 1 - short assemble (`CASM CASMPG64.S`)

Screen (screenshots `inc10_case1_casmpg64.png`, `inc10_case1_done.png`):

```
CASM V0.4.0.1379
P1: START
P1: DONE 00064 STATEMENTS
P2: START
P2: DONE 00064 STATEMENTS
WRITE: casmpg64.prg
DONE: P1 00064, P2 00064, 00065 BYTES
CASM: INPUT VALIDATED
C64[8]:>
```

Persistent lines legible and in order; `DONE:` byte count matches the
Increment 4 reference (65). Clean shell return.

### Case 2 - nested include + re-inclusion (`CASM CASMPGINCA`)

`casmpginca` -> `.INCLUDE "CASMPGINCB"` (twice) -> `casmpgincb` ->
`.INCLUDE "CASMPGINCC"`. Screen:

```
P1: DONE 00012 STATEMENTS
P2: DONE 00012 STATEMENTS
WRITE: casmpginca.prg
DONE: P1 00012, P2 00012, 00009 BYTES
CASM: INPUT VALIDATED
```

`00012` = every frame push/pop (nested and the sequential re-inclusion)
was traversed - matches Increment 4. The transient line's child/parent
filename swap flashes during the (12-statement) traversal; too brief to
freeze a single mid-frame screenshot reliably, but the count and the
byte total (`00009`, = 2 header + `EA` x 7) confirm correct traversal.

### Case 3 - `/M` + `/L` screen ownership (`CASM CASMPG128.S /O:AL.PRG /M /L`)

Screen (screenshot `inc10_case3_ml.png`):

```
CASM V0.4.0.1379
P1: START
P1: DONE 00128 STATEMENTS
P2: START
P2: DONE 00128 STATEMENTS
WRITE: al.prg
SYMBOL MAP
000 SYMBOLS
DONE: P1 00128, P2 00128, 00129 BYTES
CASM: INPUT VALIDATED
C64[8]:>
```

The `SYMBOL MAP` / `000 SYMBOLS` block and the `DONE:` summary print in
clean order with **no transient-line residue** before, inside, or after
the map. `al.lst` written. `progressSuspend` (now with the real
Increment-9 `SUSPENDED` guard) did not perturb `/M`/`/L` output.

### Case 4 - relocatable output + WRITE line (`CASM CASMPGR6.S`)

Screen (screenshot `inc10_case4_r6.png`):

```
P1: DONE 00044 STATEMENTS
P2: DONE 00044 STATEMENTS
WRITE: casmpgr6.prg
DONE: P1 00044, P2 00044, 00054 BYTES
CASM: INPUT VALIDATED
```

`00054` = 44 program + 2-byte R6 table + 6-byte R6 footer + 2 header -
the relocation table and footer are correctly in the `WRITE`-line byte
accounting, matching Increment 4.

### Case 5 - mid-assembly failure (`CASM CASMPGBAD.S`) -- NEW

`casmpgbad.s` = `.ORG $C000` + 70 `NOP` + `BNE $D000`. Screen
(screenshot `inc10_case5_fail.png`):

```
CASM V0.4.0.1379
P1: START
P1: DONE 00072 STATEMENTS
P2: START
P2:
CASM: BRANCH OUT OF RANGE
AT LINE 72, COL 1 (OFFSET 0)
 bne $d000
 ^
C64[8]:>
```

- **Transient line cleared before the diagnostic.** Pass 2 rendered the
  throttled transient status line at statement 64; when the `BNE`
  (statement 72) failed, `diagPrintFatal`'s universal
  `progressClearTransient` wiped it. The screen shows `P2: START` then a
  blank row then the clean diagnostic - **no garbled overlap** of stale
  transient text with the diagnostic, its source context, or the caret.
- **Diagnostic fully readable** - identifier, line/column/offset, the
  offending source line, and a column-1 caret.
- **No orphan partial PRG.** `DIR` after the failure lists `casmpgbad.s`
  (the source, 508 bytes) but **not** `casmpgbad.prg` - `outputAbort`
  deleted the 72-byte partial output (2-byte header + 70 `NOP`).
- Clean shell return to `C64[8]:>`.
- Note (not a finding): `P1: DONE 00072` counts the `BNE` statement too
  (the count hook runs before the instruction is emitted); Pass 1 measures
  it, Pass 2 rejects it. This is inherent two-pass behavior - Pass 1
  measures, Pass 2 validates+emits - the same as every `casmerr*` fixture.

### Case 6 - repeated invocation (`CASM CASMPG65.S /O:R1.PRG` then `/O:R2.PRG`)

Two consecutive assemblies of the same source to different output names.
Both:

```
P1: DONE 00065 STATEMENTS
P2: DONE 00065 STATEMENTS
WRITE: r1.prg   (then r2.prg)
DONE: P1 00065, P2 00065, 00066 BYTES
CASM: INPUT VALIDATED
```

`comp r1.prg r2.prg` -> `FILES COMPARE OK` (screenshot
`inc10_case6_repeat.png`). Identical progress output and clean shell
return on both runs - no leaked file handle or VMM allocation between
invocations (a leak would have failed the second run against CASM's
capped registries).

## Findings

None. Behavior matches the Increment 4 evidence and the Increment 9
reviewed candidate; the new failure fixture confirms the transient-clear
and partial-output-cleanup paths.

The known existing-output-file hang
([[project-casm-filecreateoutput-no-replace]]) was deliberately not
exercised - it is a separately tracked defect and would wedge the
emulator. Case 6 uses distinct `/O:` names to prove repeat-invocation
resource hygiene without hitting it.

## Completion Gate

- [x] Command64 boot prerequisite proven (banner + prompt).
- [x] Success matrix (representative subset + Increment 4 exhaustive
      matrix): persistent lines legible, ordered, byte counts exact.
- [x] `/M`, `/L`, `/M /L`: status never overwrites map/listing rows;
      native `COMP` confirms artifacts.
- [x] Failure matrix: transient clear over a real diagnostic, diagnostic
      readable, no orphan partial PRG, clean shell return.
- [x] Repeated invocation: identical output, clean return, no resource
      leak.
- [x] Live evidence recorded (this walkthrough + screenshots).
- [x] User explicitly accepted the runtime behavior (2026-08-31).
