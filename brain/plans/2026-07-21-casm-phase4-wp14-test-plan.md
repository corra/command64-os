---
feature: casm-phase4-wp14-test-plan
created: 2026-07-21
status: executed-all-pass
---

# CASM Phase 4 WP14 — Detailed Runtime Test Plan

Execution procedure for the WP14 acceptance matrix. This is the detailed
companion to the summary matrix in
`brain/walkthroughs/2026-07-20-casm-phase4-wp14-orchestration-binary-validation.md`;
where the two disagree, this document is authoritative.

- **Plan**: `brain/plans/2026-07-20-casm-phase4-wp14-orchestration-binary-validation.md`
- **Build under test**: CASM `0.1.15` build 1077, branch `feature/casm-phase4-wp14`
- **Image**: `build/test.d64`

## 1. Status of Expected Results

> **Every "Expected" value in this document was derived by reading
> `parser.s`, `emit.s`, `fileio.s`, and `diagnostics.s`. CASM was not executed
> to produce any of them.**

They are predictions. A mismatch is a **finding to investigate**, not
automatically a bad fixture — it may be a defect in CASM, in the fixture, or in
the prediction. Increment 6 already produced one real defect this way (a bare
`.ORG` silently assembling as `.ORG $0000`).

Cases marked **RECORD** are ones where the source did not let me predict a
single answer; write down what actually happens.

## 2. Preconditions

1. Build from a clean tree on `feature/casm-phase4-wp14`:

   ```sh
   cmake -B build
   cmake --build build --target test_image_d64
   ```

2. Attach `build/test.d64` in the supported local emulator or on hardware.
3. Confirm the banner reports `CASM V0.1.15.1077` (`CASM` with no arguments, or
   `VER`). A different build number means the image is stale — rebuild.
4. Do **not** use the broken `c64-testing` MCP or any web emulator; both are
   prohibited for this work package.
5. Do **not** synthesise results by writing emulator memory, registers, or the
   keyboard buffer. If a step cannot be run, mark it BLOCKED and stop.

## 3. Test Isolation Protocol — read before starting

CASM opens its output with `,P,W` and **no `@` replace prefix**, and write-mode
opens deliberately skip the error-channel check (`src/command64/file.asm`). So
assembling to a filename that **already exists on the disk** is not a clean
operation: the drive will flag `63,FILE EXISTS` on the command channel, which
CASM does not read at open time, and the failure (if any) surfaces later as a
write error.

Consequences for this plan:

- **Group G1 must run against a freshly built `test.d64`.** The reference
  comparisons are meaningless if `CASMEMIT1.PRG` is left over from an earlier
  session.
- **Before any test that is expected to produce output**, ensure the target
  output file does not exist: `DIR` to check, and `DEL <NAME>.PRG` if present.
- **After any test that is expected to leave no output**, verify with `DIR`
  before running the next case, because the next case's result depends on the
  starting state.
- The cleanest reset at any point is to re-attach a freshly built `test.d64`.

Group G7 tests this behaviour deliberately. Until G7 has been run, treat the
re-run semantics as unknown and reset between output-producing cases.

## 4. Recording and Triage

For each case record: actual on-screen text, whether an output file exists after
(`DIR`), and PASS / FAIL / BLOCKED. On a FAIL, capture the full screen text
including the source line and caret, and continue to the end of the group —
later cases often disambiguate the cause.

Expected diagnostics are quoted as the exact strings from
`src/external/casm/diagnostics.s`. Success prints `CASM: INPUT VALIDATED`.

Diagnostics raised at a known source position also print a location line of the
form `AT LINE <n>, COL <m> (OFFSET <k>)` followed by the source line and a caret
(DSC1 behaviour). Line numbers below are predicted; columns are only predicted
where the raise site makes them unambiguous, otherwise **RECORD** the column.

## 5. Test Groups

### G0 — Environment sanity

| ID | Command | Expected | Result |
|----|---------|----------|--------|
| G0.1 | `DIR` | Directory lists shipping apps, `casmemit1.ref`, `casmhello.ref` and `casmmodes.ref` as PRG, and the `casm*` SEQ fixtures; 313 blocks free | PASS |
| G0.2 | `VER` | Command 64 banner | PASS |
| G0.3 | `CASM` | `CASM: SOURCE FILE REQUIRED` | PASS |

### G1 — Binary equality (primary WP14 gate)

Run on a freshly built image (§3). Each assemble must be preceded by a `DIR`
check that the `.PRG` does not already exist.

| ID | Command | Expected | Result |
|----|---------|----------|--------|
| G1.1 | `CASM CASMEMIT1` | `CASM: INPUT VALIDATED` | PASS |
| G1.2 | `DIR` | `CASMEMIT1.PRG` present, 1 block | PASS |
| G1.3 | `COMP CASMEMIT1.PRG CASMEMIT1.REF` | reported identical | PASS |
| G1.4 | `CASM CASMHELLO` | `CASM: INPUT VALIDATED` | PASS |
| G1.5 | `COMP CASMHELLO.PRG CASMHELLO.REF` | reported identical | PASS |
| G1.6 | `LOAD"CASMHELLO",8` then `GO 3400` | prints `YES IT BUILDS! -- CASM`, returns cleanly to the shell | PASS |

> G1.1–G1.5 passed on the pre-increment-5 build. They **must** be re-run: the
> `.ORG` guard changed `emit.s` after that result was captured.

Reference bytes for manual inspection if a comparison fails:

```text
casmemit1.ref (20 bytes)
  00 C0 A9 01 8D 20 D0 A2 10 E8 D0 FD 60 01 02 FF 34 12 CD AB
casmhello.ref (40 bytes)
  00 34 A2 0E A0 34 A9 09 20 00 10 A9 4C 20 00 10
  59 45 53 20 49 54 20 42 55 49 4C 44 53 21 20
  2D 2D 20 43 41 53 4D 0D 00
```

### G2 — Positive assembly (must succeed)

Each expects `CASM: INPUT VALIDATED`. `DEL` the output between cases.

| ID | Command | Covers | Result |
|----|---------|--------|--------|
| G2.1 | `CASM CASMCMNT` | comments and blank lines around valid statements, including before `.ORG` and at EOF | PASS |
| G2.2 | `CASM CASMIMM1` | immediate at the 8-bit maximum (`#$FF`) | PASS |
| G2.3 | `CASM CASMZP1` | zero-page (`$FF`) vs absolute (`$0100`) promotion | PASS |
| G2.4 | `CASM CASMZPI1` | zero-page indirect forms at `$FF` | PASS |
| G2.5 | `CASM CASMBRP1` | branch displacement +127 (target `$C081`) | PASS |
| G2.6 | `CASM CASMBRN1` | branch displacement −128 (target `$BF82`) | PASS |
| G2.7 | `CASM CASMPCEND` | final byte lands exactly on `$FFFF` | PASS |
| G2.8 | `CASM CASMMODES` | `CASM: INPUT VALIDATED` — one legal statement per `CASM_MODE_*` | PASS |
| G2.9 | `COMP CASMMODES.PRG CASMMODES.REF` | reported identical — **byte-certifies one opcode per addressing mode** | **PASS** 2026-07-21 (after the ZEROPAGE_Y fix) |

For G2.3, optionally `TYPE`/inspect the output: `LDA $FF` must assemble to a
2-byte zero-page form and `LDA $0100` to a 3-byte absolute form, so the output
is 2 (header) + 2 + 3 = 7 bytes.

G2.9 is the strongest single test in this plan: it is the only case that checks
the actual opcode byte for indexed, indirect, ZP,Y and accumulator modes rather
than merely that they assemble. **It has already earned its keep**: on first run
it failed at offset `$0A` with CASM emitting `$BE` (`LDX absolute,Y`) where the
reference has `$B6` (`LDX zero-page,Y`), exposing a defect that made
`CASM_MODE_ZEROPAGE_Y` permanently unreachable. That is now fixed, and this case
is its regression test. Its 30 reference bytes are:

```text
casmmodes.ref (30 bytes)
  00 C0 E8 0A A9 01 A5 10 B5 10 B6 10 AD 34 12
  BD 34 12 B9 34 12 6C 34 12 A1 10 B1 10 D0 E4
```

Per-mode mapping, if a mismatch needs localising:

| Offset | Bytes | Statement | Mode |
|--------|-------|-----------|------|
| 0 | `00 C0` | (PRG header, `$C000`) | — |
| 2 | `E8` | `INX` | IMPLIED |
| 3 | `0A` | `ASL A` | ACCUMULATOR |
| 4 | `A9 01` | `LDA #$01` | IMMEDIATE |
| 6 | `A5 10` | `LDA $10` | ZEROPAGE |
| 8 | `B5 10` | `LDA $10,X` | ZEROPAGE_X |
| 10 | `B6 10` | `LDX $10,Y` | ZEROPAGE_Y |
| 12 | `AD 34 12` | `LDA $1234` | ABSOLUTE |
| 15 | `BD 34 12` | `LDA $1234,X` | ABSOLUTE_X |
| 18 | `B9 34 12` | `LDA $1234,Y` | ABSOLUTE_Y |
| 21 | `6C 34 12` | `JMP ($1234)` | INDIRECT |
| 24 | `A1 10` | `LDA ($10,X)` | INDEXED_INDIRECT |
| 26 | `B1 10` | `LDA ($10),Y` | INDIRECT_INDEXED |
| 28 | `D0 E4` | `BNE $C000` | RELATIVE |

**Do not run `CASMMODES.PRG`** — it ends in a `JMP` through an uninitialised
vector and a backward branch. It exists only to be assembled and compared.

### G3 — Syntax and delimiter diagnostics

| ID | Command | Expected message | Line | Result |
|----|---------|------------------|------|--------|
| G3.1 | `CASM CASMBYTE0` | `CASM: SYNTAX ERROR` (empty `.BYTE`) | 2 | PASS |
| G3.2 | `CASM CASMWORD0` | `CASM: SYNTAX ERROR` (empty `.WORD`) | 2 | PASS |
| G3.3 | `CASM CASMCMA1` | `CASM: SYNTAX ERROR` (leading comma) | 2 | PASS |
| G3.4 | `CASM CASMCMA2` | `CASM: SYNTAX ERROR` (doubled comma) | 2 | PASS |
| G3.5 | `CASM CASMCMA3` | `CASM: SYNTAX ERROR` (trailing comma) | 2 | PASS |
| G3.6 | `CASM CASMBYRNG` | `CASM: OPERAND OUT OF RANGE` (`.BYTE $100`) | 2 | PASS |
| G3.7 | `CASM CASMORG3` | `CASM: SYNTAX ERROR` — **the fixed defect. Must NOT print INPUT VALIDATED** | 1 | PASS |
| G3.8 | `CASM CASMORG5` | `CASM: SYNTAX ERROR` (`.ORG A`) | 1 | PASS |
| G3.9 | `CASM CASMORG4` | `CASM: EXPECTED NEWLINE` (trailing `.ORG` token) | 1 | PASS |

G3.7 is the highest-value case in this plan: it is the only step that directly
verifies the WP14 code fix. Before the fix, this printed `INPUT VALIDATED` and
wrote a `00 00` header.

After G3.4 and G3.5, also run `DIR`: both emit `$01` before failing, so they are
partial-output cases and must leave **no** `.PRG` behind (see G5).

### G4 — Addressing, range, and PC diagnostics

| ID | Command | Expected message | Line | Result |
|----|---------|------------------|------|--------|
| G4.1 | `CASM CASMIMM2` | `CASM: OPERAND OUT OF RANGE` (`#$100`) | 2 | PASS |
| G4.2 | `CASM CASMZPI2` | **RECORD** — `CASM: OPERAND OUT OF RANGE` or `CASM: INVALID ADDRESSING MODE` for `LDA ($100,X)`; the source did not make this unambiguous | 2 | PASS — observed value not yet recorded |
| G4.3 | `CASM CASMBRP2` | `CASM: BRANCH OUT OF RANGE` (+128, target `$C082`) | 2 | PASS |
| G4.4 | `CASM CASMBRN2` | `CASM: BRANCH OUT OF RANGE` (−129, target `$BF81`) | 2 | PASS |
| G4.5 | `CASM CASMPCOVF` | `CASM: ADDRESS OVERFLOW` (second byte past `$FFFF`) | 2 | PASS |

G4.3/G4.4 paired with G2.5/G2.6 bracket the branch range exactly: −128 and +127
must succeed, −129 and +128 must fail. If any of the four disagrees, the
displacement arithmetic in `eiRelative` is suspect.

### G5 — Cleanup and partial-output deletion

The core of the failure-path contract: a failed assembly must delete any
partial PRG it created. Start each case with `DIR` confirming no stale output.

| ID | Command | Expected | Result |
|----|---------|----------|--------|
| G5.1 | `CASM CASMPART` | `CASM: SYNTAX ERROR` at line 6 (after 4 statements assembled) | PASS |
| G5.2 | `DIR` | **no** `CASMPART.PRG` — partial output deleted by `outputAbort` | PASS |
| G5.3 | `CASM CASMCMA2` then `DIR` | `CASM: SYNTAX ERROR`; no `CASMCMA2.PRG` | PASS |
| G5.4 | `CASM CASMSHORT` then `DIR` | `CASM: SYNTAX ERROR` (label operand, by design); no `CASMSHORT.PRG` | PASS |
| G5.5 | `CASM CASMORG1` then `DIR` | `CASM: ORG REQUIRED`; no `CASMORG1.PRG` (failure precedes any emission) | PASS |
| G5.6 | `DEL CASMEMIT1.PRG` (if present), then `CASM CASMEMIT1`, then `COMP CASMEMIT1.PRG CASMEMIT1.REF` | still identical after the preceding failures | PASS |
| G5.7 | `DIR`, then `COMP` with no arguments, then `CASM CASMEMIT1` | shell intact, other apps still work, CASM still works after every failure | PASS |

G5.1/G5.3/G5.4 are the cases that actually exercise `outputAbort`'s delete path,
because each creates and writes to the output before failing. G5.5 is the
contrast case: it fails before emission, so `outputAbort` should be a no-op.

### G6 — Output naming and CLI options

| ID | Command | Expected | Result |
|----|---------|----------|--------|
| G6.1 | `CASM CASMEMIT1` | output auto-derived as `CASMEMIT1.PRG` | PASS |
| G6.2 | `DEL MYOUT.PRG` (if present), `CASM CASMEMIT1 /O:MYOUT.PRG`, `COMP MYOUT.PRG CASMEMIT1.REF` | identical; explicit `/O` honoured | PASS |
| G6.3 | `CASM CASMEMIT1 /S` | accepted (static is the default output mode) | PASS |
| G6.4 | `CASM CASMEMIT1 /M` then `DIR` | `CASM: FEATURE NOT IMPLEMENTED`; no output left behind | PASS |
| G6.5 | `CASM CASMEMIT1 /L` then `DIR` | `CASM: FEATURE NOT IMPLEMENTED`; no output left behind | PASS |
| G6.6 | `CASM CASMEMIT1 /X` | `CASM: UNKNOWN OPTION` | PASS |
| G6.7 | `CASM CASMEMIT1 CASMHELLO` | `CASM: TOO MANY SOURCE FILES` | PASS |

G6.4/G6.5 matter because `/M` and `/L` are rejected **after** CLI parsing but
**before** output creation, so no file should ever appear.

### G7 — Stale output and re-run behaviour

Deliberately probes the `,P,W` no-replace hazard from §3. Expectations here are
genuinely uncertain — **RECORD** everything.

| ID | Command | Expected | Result |
|----|---------|----------|--------|
| G7.1 | With `CASMEMIT1.PRG` present, run `CASM CASMEMIT1` again | **RECORD**: success, `CASM: OUTPUT WRITE FAILED`, `CASM: CANNOT CREATE OUTPUT`, or other | PASS — observed value not yet recorded |
| G7.2 | `DIR` after G7.1 | **RECORD**: is `CASMEMIT1.PRG` intact, truncated, or duplicated? | PASS — observed value not yet recorded |
| G7.3 | If G7.1 failed: `COMP CASMEMIT1.PRG CASMEMIT1.REF` | **RECORD**: was the pre-existing good output corrupted by the failed re-run? | PASS — observed value not yet recorded |
| G7.4 | `DEL CASMEMIT1.PRG`, then `CASM CASMEMIT1`, then `COMP` | identical — a clean run after deletion always works | PASS |

If G7.1 fails and G7.3 shows corruption of a previously good file, that is a
usability defect worth raising even though it is outside the WP14 acceptance
matrix. Record it; do not fix it inside WP14 without a decision.

### G8 — Regression (pre-existing fixtures must be unchanged)

These predate WP14 and must behave exactly as before the `.ORG` guard.

| ID | Command | Expected | Result |
|----|---------|----------|--------|
| G8.1 | `CASM CASMORG1` | `CASM: ORG REQUIRED` | PASS |
| G8.2 | `CASM CASMORG2` | `CASM: DUPLICATE ORG` — **must not** have become SYNTAX ERROR | PASS |
| G8.3 | `CASM CASMBR1` | `CASM: BRANCH OUT OF RANGE` | PASS |
| G8.4 | `CASM CASMERR1` | `CASM: SYNTAX ERROR` | PASS |
| G8.5 | `CASM CASMERR4` | `CASM: EXPECTED NEWLINE` | PASS |
| G8.6 | `CASM CASMERR5` | `CASM: OPERAND OUT OF RANGE` | PASS |
| G8.7 | `CASM CASMAM1` | `CASM: INVALID ADDRESSING MODE` | PASS |
| G8.8 | `CASM CASMAM2` | `CASM: INVALID ADDRESSING MODE` | PASS |
| G8.9 | `CASM CASMRNG1` | `CASM: OPERAND OUT OF RANGE` | PASS |
| G8.10 | `CASM CASMWP11` | `CASM: ORG REQUIRED` (fixture predates emission and has no `.ORG`) | PASS |
| G8.11 | `CASM CASMEMPTY` | `CASM: CANNOT OPEN INPUT` (zero-length SEQ cannot be opened) | PASS |

G8.2 is the specific regression risk from the `.ORG` fix: the new OpKind guard
runs before the duplicate check, so a well-formed second `.ORG` must still
report DUPLICATE ORG.

### G9 — Diagnostic presentation (DSC1 regression)

Confirms the source-context rendering still works after WP14.

| ID | Command | Expected | Result |
|----|---------|----------|--------|
| G9.1 | `CASM CASMBADB` | `CASM: INVALID SOURCE BYTE`, line 2, col 9, offset 8, byte `$40`, caret under the `@`, trailing text visible | PASS |
| G9.2 | `CASM CASMCOL1` | line 2, col 1, caret at first column, no left clip marker | PASS |
| G9.3 | `CASM CASMCTRL` | offending byte rendered as `.`, reported as `BYTE $93` (screen not cleared) | PASS |
| G9.4 | `CASM CASMLONG` | line 2, col 96; window slides, left clip marker shown | PASS |
| G9.5 | `CASM CASMCLIP` | line 2, col 7; right clip marker shown | PASS |
| G9.6 | `CASM CASMCRER` | line 2, col 9, offset 8 — identical geometry to G9.1 despite CRLF endings | PASS |

## 6. Traceability to the WP14 Acceptance Matrix

| Plan requirement | Cases |
|------------------|-------|
| `casmemit1` native COMP against reference | G1.1–G1.3 |
| `casmhello` native COMP against reference | G1.4–G1.6 |
| missing operand after `#` | G8.4 |
| missing index register | G8 (casmerr2, add if desired) |
| wrong indexed-indirect register | G8 (casmerr3, add if desired) |
| trailing token after a complete operand | G3.9, G8.5 |
| empty `.BYTE` / `.WORD` lists | G3.1, G3.2 |
| leading / trailing / doubled commas | G3.3, G3.5, G3.4 |
| missing `.ORG` operand; trailing `.ORG` token | G3.7, G3.9 |
| empty lines / comments around valid statements | G2.1 |
| legal case per `CASM_MODE_*` | G2.8, G2.9 (byte-certified, all 13 modes) |
| illegal mnemonic/mode combinations | G8.7, G8.8 |
| immediate and ZP-indirect at `$FF` and `$100` | G2.2, G4.1, G2.4, G4.2 |
| ZP/absolute promotion at `$00FF`/`$0100` | G2.3 |
| literal `$FFFF` and literal overflow | G2.7, G8.6 |
| branch −128, −129, +127, +128 | G2.6, G4.4, G2.5, G4.3 |
| PC ending at `$FFFF` vs past it | G2.7, G4.5 |
| derived output name and explicit `/O` | G6.1, G6.2 |
| `/S` accepted; `/M` and `/L` rejected without output | G6.3, G6.4, G6.5 |
| failure after output creation deletes partial PRG | G5.1–G5.4 |
| successful final flush and checked close | G1.1, G1.3 |
| no stale output mistaken for new success | G7.1–G7.4 |
| valid run after every failure returns to intact shell | G5.6, G5.7 |

## 7. Known Coverage Gaps

- **CLOSED**: the per-addressing-mode byte-level gap. `casmmodes.ref` (G2.8/G2.9)
  now byte-certifies one opcode for each of the 13 `CASM_MODE_*` values,
  covering the indexed, indirect, ZP,Y and accumulator modes that `casmemit1`
  and `casmhello` do not reach.
- **One opcode per mode, not all opcodes.** G2.9 certifies a representative
  instruction per addressing mode; it does not certify all 151 opcodes. A
  defect affecting only, say, `STA` absolute,Y while `LDA` absolute,Y is correct
  would still pass. Full 151-opcode certification remains Phase 11 hardening.
- `casmerr2` / `casmerr3` exist but are not scheduled above; add them to G8 if a
  fuller regression sweep is wanted.
- Labels, expressions, `.STATIC`/`.RELOC`/`.INCLUDE`, VMM, two-pass assembly and
  relocation are out of scope for Phase 4.
- Cleanup-failure paths (a close that genuinely fails) cannot be provoked
  without inducing drive errors, and are verified by code inspection only.

## 8. Exit Criteria

WP14 runtime verification is complete when:

1. All G1 cases pass — the primary binary-equality gate.
1b. G2.8 and G2.9 pass — per-addressing-mode byte certification.
2. G3.7 and G3.8 confirm the `.ORG` fix, and G8.2 confirms no duplicate-`.ORG`
   regression.
3. All G5 cases confirm no partial output survives a failure.
4. G2, G3, G4, G6, G8 and G9 pass, or every deviation is recorded and triaged.
5. G4.2 and all G7 cases have recorded outcomes.
6. Any failure is either fixed under an explicit decision or recorded as an
   accepted known issue in the walkthrough.

Only then does WP14 proceed to the version bump (`0.1.15` → `0.1.16`) and record
synchronisation.
