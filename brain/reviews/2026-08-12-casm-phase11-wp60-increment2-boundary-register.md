# CASM Phase 11 WP60 Increment 2 Boundary Evidence Register

Status: Frozen for user review
Branch: `feature/casm-phase11-wp60`
Baseline: CASM `0.2.1` build `1264`
Plan: `brain/plans/2026-08-11-casm-phase11-wp60-opcode-addressing-boundary-hardening.md`
Taskwarrior: `bd441121-dffa-4d69-8f3a-8572e0643322`

## Scope and Method

This is the Increment 2 gate artifact. It inventories existing test evidence
for all eight required boundary domains, records the exact current
valid/invalid endpoints, diagnostics, and assertion strength found, and
assigns a reuse/strengthen/add disposition to every required row per the
plan's bar: *"Existing exact evidence may satisfy a row only when it verifies
the production routine, expected diagnostic/flags, state commit point, and
repeat cleanup. A comment or incidental successful assembly is not
sufficient."*

No production or fixture source changed while producing this register.

Notation:

- **Evidence** cites file:line for the strongest existing case, or "none" for
  zero coverage.
- **Strength**: `commit` = a real state-commit-point/byte/diagnostic
  assertion; `incidental` = only "it assembled"/"carry clear" with no value
  check; `unwired` = a fixture exists but no harness asserts on it at all
  (CLI/manual-VICE exercise only).
- **Disposition**: `reuse` = row is satisfied as-is; `strengthen` = evidence
  exists but falls short of the bar above; `add` = zero qualifying evidence.

## Cross-Cutting Finding

A large fraction of gaps below share one root cause: an older generation of
CMake-generated `.seq` fixtures (branch/PC/addressing-width boundary cases)
were authored with correct boundary values and header comments describing the
expected diagnostic, but were never wired into an automated `tests/src`
harness with an in-code assertion. They are packaged onto test disks and were
historically exercised only through manual VICE walkthroughs recorded as
pass/fail table rows in `brain/walkthroughs/*.md` -- not repeatable,
diagnostic-code-checked evidence. `brrng1` (relative-branch +128 rejection)
is a documented case of this pattern producing a **wrong-reason pass** that
was only caught by a later bug fix (`brain/walkthroughs/2026-07-23-casm-phase6-wp30-branches-and-disagreement-detection.md:109/158`).
No `add_test`/ctest exists in `CMakeLists.txt` for any CASM fixture; every
fixture runs manually inside VICE. The newer generation of harnesses
(`casm_symbols.s`, `casm_vmm.s`, `casm_reloc.s`, `casm_spanread.s`,
`casm_faultinject_*`) establishes the pattern later increments should follow:
a self-contained `.s` harness with explicit in-code diagnostic/byte/state
assertions and a PASS/FAIL banner, not a bare `.seq` fixture relying on
external comparison.

One plan-text correction found during inventory: the plan's Boundary
Evidence Register table states the VMM domain's transfer-split boundary as
"255/256-byte window split." Production's actual VMM window-transfer chunk
size is `CASM_VMM_BUFFER_SIZE = 64` bytes (`common.inc:160`), not 256 --
256 is `source.s`'s *own* read-chunk size (`CasmIoBuffer`), a different
layer, and that domain's row is correctly 255/256 as written. The VMM row
below uses the real 64/65-byte boundary instead of the plan's literal text;
flagged for your confirmation rather than silently substituted.

## Domain: Numeric Literal

| Required boundary | Evidence | Strength | Disposition |
| --- | --- | --- | --- |
| `$0000` | `casm_expr.s:401,428` (`sN0`/`sAbsNegZero`) | commit (byte-compare) | reuse |
| `$00FF` | none | -- | **add** |
| `$0100` | `casm_expr.s:432` (`sRelAdd`), only as an addend, not isolated | incidental | **strengthen** |
| `$FFFF` | `casm_expr.s:403` (`sNMAX`), full-extraction asserted | commit | reuse |
| First lexical/eval overflow (>16-bit literal) | none anywhere in `tests/` (`OPERAND_OUT_OF_RANGE` zero hits) | -- | **add** |
| Decimal/hex/binary format parity | none (`casm_expr.s` never uses `CASM_NUMBER_BINARY`) | -- | **add** |

## Domain: Addressing Width

| Required boundary | Evidence | Strength | Disposition |
| --- | --- | --- | --- |
| ZP/Absolute crossover at `$FF`/`$0100` | `casmzp1.seq` exists, generated, zero consuming harness | unwired | **add** |
| 8-bit-mode rejection at `$0100`+ (immediate/(zp,X)/(zp),Y) | `casmimm2.seq`/`casmzpi2.seq` exist; `casmzpi2`'s own generator comment says the expected diagnostic is unconfirmed | unwired | **add** |
| `FORCE_ABS` stability for a symbol-derived operand | `casm_pass1.s:470-517` (`p1back1`), real `CasmPc` state-commit check, but at `$0010` (not a `$FF`/`$0100` boundary) and only within one measure pass, never re-resolved across a genuine second pass | commit but off-boundary/single-pass | **strengthen** |

## Domain: Relative Branch

| Required boundary | Evidence | Strength | Disposition |
| --- | --- | --- | --- |
| `-128` (accept) | `casmbrn1.seq`, manual-VICE only | unwired | **add** |
| `-127` (accept) | none | -- | **add** |
| `0` (accept) | none | -- | **add** |
| `+127` (accept) | `casmbrp1.seq`, manual-VICE only | unwired | **add** |
| reject `-129` | `casmbrn2.seq`, manual-VICE only, no diagnostic-code assertion | unwired | **add** |
| reject `+128` | `casmbrp2.seq`/`brrng1.seq`, manual-VICE only; `brrng1` has a documented historical wrong-reason pass | unwired, unreliable | **add** |
| wrap-sensitive PC endpoints (branch near `$0000`/`$FFFF`) | none | -- | **add** |

## Domain: Program Counter

| Required boundary | Evidence | Strength | Disposition |
| --- | --- | --- | --- |
| `.ORG $0000` | none (`casmorg1` is implicit-default-origin, not a literal `.ORG $0000`) | -- | **add** |
| `.ORG $FFFE` | none | -- | **add** |
| `.ORG $FFFF` | only reached combined with the two rows below | -- | (covered by rows below) |
| Emission ending exactly at `$FFFF` | `casmpcend.seq`, manual-VICE only, no PRG-byte verification | unwired | **add** |
| Reject first byte past `$FFFF` overflow | `casmpcovf.seq`, manual-VICE only, no diagnostic-code assertion | unwired | **add** |
| Repeat reset (no leaked `CasmPc` across runs without `.ORG`) | `emitInit` structurally re-primes state (`emit.s:107-128`, WP38 fix comment); every existing multi-fixture harness (`casm_pass1.s`) happens to open each fixture with its own `.ORG`, so the no-`.ORG` leak path is never exercised | incidental (structural claim, untested) | **add** |

## Domain: Source

| Required boundary | Evidence | Strength | Disposition |
| --- | --- | --- | --- |
| Empty source file | none | -- | **add** |
| One-byte source file | none isolated | -- | **add** |
| 255/256-byte transfer-chunk split | `casm256.seq`/`casmsplit.seq` exist with well-placed CR/LF straddling the boundary, but no located `tests/src` harness asserts on them in-code (CLI-path only per header comments) | unwired/unclear | **strengthen** |
| 65,535-byte accepted extent | none at the exact cap (`casmmfovf1/2` overshoot by 4,465 bytes; `casmbiga/b` sit at 6,000, far under) | -- | **add** |
| First byte beyond cap (65,536, reject) | none at the exact boundary | -- | **add** |
| Exact EOF/line-ending behavior | `casmcr`/`casmcrlf`/`casmblank`/`casmfincr`/`casmln255`/`casmln256` fixtures exist with correct shapes, same unwired-harness caveat as the chunk-split row | unwired/unclear | **strengthen** |

## Domain: Symbol

| Required boundary | Evidence | Strength | Disposition |
| --- | --- | --- | --- |
| Empty table | `casm_symbols.s:142-166` (`syminit1`), real post-init lookup-miss check | commit | reuse |
| One symbol | `casm_symbols.s:174` (`symins1`), record index asserted | commit | reuse |
| Name length 1 | none | -- | **add** |
| Name length 31 (accept) | `casm_symbols.s:434` (`symlen1`), round-trip verified | commit | reuse |
| Name length 0 (reject) | `symbols.s` treats length as an unenforced precondition (`1..31`); a length-0 identifier may be structurally impossible from the lexer rather than a runtime-rejected case -- needs root-cause determination, not just a test | -- | **add** (with a design note, see below) |
| Name length 32 (reject) | Owned by `lexer.s`'s `CASM_DIAG_TOKEN_TOO_LONG` (`lexer.s:526-537`), zero test hits anywhere in `tests/` | -- | **add** |
| Values `$0000`/`$FFFF` | none (existing cases use `$1234`, `$5678`, small counters) | -- | **add** |
| 511 symbols (accept, capacity-edge minus one) | `casm_symbols.s:518-595` (`symfull1`) reaches 512 cumulative but never isolates 511 as its own checkpoint | commit but not isolated | **strengthen** |
| 512 symbols (accept, at capacity) | `symfull1`, all inserts through 512 must succeed | commit | reuse |
| 513th symbol (reject) | `symfull1:583-589`, exact `CASM_DIAG_SYMBOL_TABLE_FULL` assertion | commit | reuse |
| Duplicate-symbol behavior | `casm_symbols.s:278` (`symdup1`) + `:311` (`symcase1`, case-sensitivity) | commit | reuse |

Design note for the length-0 row: before adding a test, Increment 7 must
first determine via source trace whether the lexer can ever hand `symbols.s`
a zero-length identifier at all (if not, this is a structural invariant to
document, not a runtime path to test) -- consistent with the plan's stop
condition against inventing coverage for an unreachable path.

## Domain: VMM Store/Window

| Required boundary | Evidence | Strength | Disposition |
| --- | --- | --- | --- |
| First byte (offset 0) | `casm_vmm.s:301-341` (`vmmreplay1`), real byte-pattern compare | commit | reuse |
| Last byte (offset size-1) | `casm_vmm.s:402-412` (`vmmoffset1`), offset 65504+len32 ends at 65535, but only carry-clear checked, no content verification | incidental | **strengthen** |
| Window-transfer chunk split (real boundary: 64/65 bytes, `CASM_VMM_BUFFER_SIZE`, not the plan's literal 255/256 -- see Cross-Cutting Finding) | none; largest transfer tested is 32 bytes | -- | **add** |
| 4,095/4,096-byte page edge | `casm_vmm.s:444-475` (`vmmbounds1`) tests an in-page overrun (4090+32) crossing the page, but never isolates the literal 4095/4096 values, and only checks carry-set (no diagnostic compare) | incidental | **strengthen** |
| 65,535-byte max request/grant endpoint | `casm_vmm.s:393-394` (`vmmoffset1`) allocates via X=$FF,Y=$FF (clamps to 65536/16 pages) but never asserts `REC_PAGES==16` (unlike the 32-byte case, which does check `REC_PAGES`) | incidental | **strengthen** |
| One-past-window rejection | `casm_vmm.s:414-425` (`vmmoffset1`), offset 65505+len32=65537, carry-set only, no diagnostic-code compare | incidental | **strengthen** |

## Domain: Relocation

| Required boundary | Evidence | Strength | Disposition |
| --- | --- | --- | --- |
| Empty table | `relocinit1` checks alloc success only, no `count==0`/empty-footer assertion; `relocFinalize` is never called on an empty table | incidental | **add** |
| One entry | `casmreloc1.seq`, byte-for-byte `COMP` against `casmreloc1.ref.hex` (full R6 footer) **and** the patch is live-loaded and executed via `aptRelocate` | commit (strongest evidence in the whole audit) | reuse |
| Offset `$0000` | `casm_reloc.s:156-181` (`relocrecord1`) | commit | reuse |
| Offset `$FFFF` | none (existing offsets top out at `$00FF`) | -- | **add** |
| 4,095/4,096-entry capacity | `casm_reloc.s:285-329` (`relocfull1`), all 4096 sequential inserts must succeed | commit | reuse |
| 4,097th entry (reject) | `relocfull1:315-323`, exact `CASM_DIAG_RELOC_TABLE_FULL` assertion | commit | reuse |
| R6 footer count field/terminator at capacity extremes (0, 4096) | Only verified for `count=1` (`casmreloc1.ref.hex`); `relocfull1` never calls `relocFinalize` | -- | **add** |
| Replay/re-read bounds near the table's full 8,192-byte extent | `relocrecord1`/`relocmeasure1` only re-read at offsets 0/6; fault-injection (`casm_freloc.s:224-250`) covers only the first 64-byte read chunk of a 128-chunk full-table copy | incidental | **add** |

## Disposition Summary

52 required boundary rows total (the ".ORG `$FFFF`" PC row is a merge note,
not counted separately -- it's satisfied by the two rows beneath it).

| Domain | Rows | reuse | strengthen | add |
| --- | --- | --- | --- | --- |
| Numeric literal | 6 | 2 | 1 | 3 |
| Addressing width | 3 | 0 | 1 | 2 |
| Relative branch | 7 | 0 | 0 | 7 |
| Program counter | 5 | 0 | 0 | 5 |
| Source | 6 | 0 | 2 | 4 |
| Symbol | 11 | 6 | 1 | 4 |
| VMM store/window | 6 | 1 | 4 | 1 |
| Relocation | 8 | 4 | 0 | 4 |
| **Total** | **52** | **13** | **9** | **30** |

## Frozen Target/File Changes for Increments 6-7

No production or fixture file changes are authorized by this increment. Based
on this register, later increments are expected to touch:

- **Increment 6** (numeric/addressing/branch/PC): `tests/src/casm_expr/`,
  a new or extended branch/PC boundary harness (likely
  `tests/src/casm_branch/` or an extension of an existing emit-adjacent
  harness -- exact target named at Increment 6 activation), and wiring the
  five already-generated-but-unwired `.seq` fixtures
  (`casmzp1`, `casmimm2`, `casmzpi2`, `casmbrn1/2`, `casmbrp1/2`,
  `casmpcend`, `casmpcovf`) into real asserting harnesses or superseding them
  with in-code equivalents.
- **Increment 7** (source/symbol/VMM/relocation): `tests/src/casm_symbols/`,
  `tests/src/casm_vmm/`, `tests/src/casm_reloc/`, and a source-boundary
  harness (likely extending `casm_spanread`/`casm_pass1` or a new dedicated
  target).
- No production source change is authorized by either increment unless a
  confirmed defect is found and separately approved, per the plan.

## Sign-off

Inventory complete across all eight required domains. 52 required boundary
rows recorded; 13 already satisfy the plan's evidentiary bar and are marked
`reuse`, 9 have partial/incidental evidence needing strengthening, and 30
have zero qualifying coverage today (several because generated fixtures were
never wired to an automated assertion). One plan-text correction is flagged
above (VMM chunk boundary: 64/65 bytes, not 255/256) for your confirmation.

Requesting user approval of this frozen register, and of the VMM boundary
correction, before Increment 3 (structural `CLD` hardening) activates.
