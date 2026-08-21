# CASM Phase 13 WP81 .RES/.FILL/.ALIGN Completion Gate

## Status

**Approved by the user on 2026-08-21.** WP81 is complete.

## Result (proposed)

`.RES`, `.FILL`, and `.ALIGN` are implemented end-to-end in native CASM:

- `.RES count[, value]` reserves `count` bytes, each set to `value` (default
  `0`).
- `.FILL count, value` emits `count` bytes of `value` (value is required, no
  default).
- `.ALIGN boundary[, fill]` pads with `fill` bytes (default `0`) until
  `CasmPc` is a multiple of `boundary`.

Both operands of all three directives must fully resolve in the pass that
parses them; a forward reference is rejected with a new diagnostic rather
than tolerated as a Pass-1 placeholder (Scoping Decision 1 in the WP81 plan).
None of the three interact with the R6 relocation table -- their bytes are
inert filler, identical to a `.BYTE $00`/`.BYTE $AA` byte today.

## Implementation

- `common.inc`: `CASM_DIRECTIVE_RES/FILL/ALIGN` ($07-$09), and four new
  diagnostics `CASM_DIAG_RES_FILL_ALIGN_UNRESOLVED` / `_FILL_VALUE_REQUIRED`
  / `_VALUE_OUT_OF_RANGE` / `_ALIGN_BOUNDARY_ZERO` ($4B-$4E).
- `lexer.s`: token recognition for `.RES`/`.FILL`/`.ALIGN` appended to
  `lnDirective`'s existing chain.
- `parser.s`: new `ppsFillDirective`, dispatched from `ppsMnemonic` for all
  three subtypes. Parses the count/boundary expression via the existing
  `parserParseExpressionValue`, explicitly checks `CASM_EXPR_FLAG_RESOLVED`
  (diverging from that routine's own Pass-1-tolerant convention), then an
  optional comma-separated value/fill expression with the same resolved
  check and a byte-range check. Stages results into new
  `CasmFillCountLo/Hi`/`CasmFillValue` (not `CasmParserStmt.Val*`, which the
  second `parserParseExpressionValue` call would otherwise clobber).
- `emit.s`: new `emitRes`/`emitFill`/`emitAlign`, dispatched from
  `emitDirective`. `emitRes`/`emitFill` call `emitMarkStarted` then a shared
  `emitFillLoop` (16-bit down-counter, `emitByte` per iteration -- Pass 1
  discards the write while `CasmPc` still advances, via `emitByte`'s own
  existing `CasmPassMode` gate). `emitAlign` additionally computes padding
  via a new self-contained `emitAlignMod` (16-iteration restoring-division
  remainder, `CasmPc mod boundary`), rejecting a zero boundary before any
  padding is computed.
- `diagnostics.s`: message text and dispatch for the four new diagnostics.
  The dispatch check for this WP's diagnostic range is a `bcc`/`bcs`
  range-test into its own small parallel message table
  (`diagWp81MessageLo/Hi`), not folded into the main `cmp`/`beq` chain --
  adding four more `cmp`/`beq` pairs to that chain pushed its earliest
  branches out of 6502 relative-branch range (a real assembly error hit
  during this WP, not a hypothetical).

### Defect found and fixed during fixture verification

`ppsFillDirective`'s first revision called `parserParseExpressionValue`
directly against the still-current `.RES`/`.FILL`/`.ALIGN` token itself,
never consuming it first (`parseOperandSequence`'s own first move, missing
here). Every production fixture failed with a spurious
`CASM: MALFORMED EXPRESSION` at line 1, column 1. Fixed by adding the
missing `jsr lexerNext` at entry. The new `test_casm_directives` isolation
harness (below) does not exercise `ppsFillDirective` at all -- it drives
`emitDirective` directly with hand-built `CasmFillCountLo/Hi`/`CasmFillValue`
records -- so it could not have caught this; only the production
`.seq`/`.ref.hex` fixtures, run through the real parser, exposed it. This is
the exact reason the WP81 plan calls for both an isolation harness (proves
`emit.s`'s own PC/diagnostic mechanics) and end-to-end fixtures (proves the
whole pipeline), not one or the other.

## New Test Harness: `test_casm_directives`

`tests/src/casm_directives/casm_directives.s`, modeled directly on
`casm_bounds.s`'s own narrow-link precedent (Phase 11 WP60 Increment 6):
links only `emit.s`, supplies `CasmParserStmt`/`CasmFillCountLo/Hi`/
`CasmFillValue` directly, stubs everything else. Proves
`emitRes`/`emitFill`/`emitAlign`/`emitFillLoop`/`emitAlignMod`'s PC
arithmetic and diagnostic behavior in isolation from the lexer/parser. Nine
cases: `.RES` zero-count (no-op), `.RES` normal count with explicit value,
`.RES` default value, `.FILL` normal count, `.FILL` zero count, `.ALIGN`
already-aligned (zero padding), `.ALIGN` needing padding, `.ALIGN 0`
rejection, and an address-overflow case exercising `emitFillLoop`'s
propagation of `emitByte`'s own overflow diagnostic.

Ships on `casm_include_test_d64` (self-contained, no VMM/file ownership --
same disk `casm_bounds` already lives on).

## Production Fixtures (`casm_phase13_test_d64`)

A new, dedicated Phase 13 test disk, created proactively per
`.agents/workflows/per-phase-test-images.md` rather than reactively once a
generic disk filled up. Self-bootable (`command64` + `casm` + `comp`).

- `casmres1.seq` / `casmres1.ref.hex` -- `.RES 3,$AA` then `.RES 2` (default
  value). Accepted, COMP-verified.
- `casmfill1.seq` / `casmfill1.ref.hex` -- `.FILL 4,$40`. Accepted,
  COMP-verified.
- `casmalign1.seq` / `casmalign1.ref.hex` -- `.ORG $C003` then `.ALIGN $10`
  (13 bytes of padding) then `.BYTE 1` landing exactly on `$C010`. Accepted,
  COMP-verified.
- `casmresfwd.seq` -- `.RES COUNT` where `COUNT` is defined later in the
  same file (a genuine Pass-1 forward reference). Rejected:
  `CASM_DIAG_RES_FILL_ALIGN_UNRESOLVED`.
- `casmfillnoval.seq` -- `.FILL 5` with no value operand. Rejected:
  `CASM_DIAG_FILL_VALUE_REQUIRED`.
- `casmalignzero.seq` -- `.ALIGN 0`. Rejected:
  `CASM_DIAG_ALIGN_BOUNDARY_ZERO`.
- `casmresrange.seq` -- `.FILL 1,256` (value operand out of byte range).
  Rejected: `CASM_DIAG_VALUE_OUT_OF_RANGE`.

## Envelope Changes

All user-approved 2026-08-21, each the smallest round-page fit above its
measured overflow:

| Target | Before | After | Reason |
| --- | --- | --- | --- |
| `casm` (production) | `$6500` | `$6600` | Increment 1: directive constants + diagnostics |
| `casm` (production) | `$6600` | `$6700` | Increment 3: parser/emitter implementation |
| `test_casm_frame` | `$5C00` | `$5D00` | Increment 1 |
| `test_casm_frame` | `$5D00` | `$5F00` | Increment 3 |
| `test_casm_listcap` | `$6100` | `$6200` | Increment 1 |
| `test_casm_listcap` | `$6200` | `$6300` | Increment 3 |
| `test_casm_include` | `$1500` | `$1600` | Increment 2: lexer recognition |
| `test_casm_pass1` | `$5D00` | `$5E00` | Increment 2 |
| `test_casm_pass1` | `$5E00` | `$5F00` | Increment 3 |

Additionally, `casm_overflow_test_d64` ran 1 block short for `casmcat5.seq`
after `casm`'s own envelope growth (same recurring disk-capacity issue as
WP65/WP66's own precedent) -- fixed by relocating the self-contained,
fixture-free `test_casm_event` to `casm_include_test_d64` (~540 free blocks),
not by trimming fixture content.

`test_casm_bounds` needed local one-byte stand-ins for
`CasmInsn`/`CasmFillCountLo/Hi`/`CasmFillValue` (linked whole from `emit.s`,
unreachable by that harness's own cases) to keep linking clean.

## Regression Evidence

- Full clean rebuild from scratch (`rm -rf build && cmake -B build &&
  cmake --build build`): every target links and packs clean, no overflow,
  no unresolved externals.
- `test_casm_expr`: `CASM EXPR: PASS` (live VICE, `casm_phase12_test.d64`).
- `test_casm_pass1`: `CASM PASS1: PASS` (live VICE, same disk).
- `test_casm_frame`: `CASM FRAME: PASS` (live VICE, `casm_listing_test.d64`).

## Live VICE Evidence

- VICE 3.10 C64SC answered MCP ping throughout.
- `test_casm_directives` (`casm_include_test.d64`): `CASM DIRECTIVES: PASS`,
  all 9 cases, followed by `c64[8]:>`.
- `casmres1.s` assembled via `casm`, then `comp casmres1.prg casmres1.ref`:
  `FILES COMPARE OK`.
- `casmfill1.s` assembled via `casm`, then `comp casmfill1.prg
  casmfill1.ref`: `FILES COMPARE OK`.
- `casmalign1.s` assembled via `casm`, then `comp casmalign1.prg
  casmalign1.ref`: `FILES COMPARE OK`.
- `casmresfwd.s`: `CASM: OPERAND NOT RESOLVED` at line 1, col 6 (offset 5).
- `casmfillnoval.s`: `CASM: .FILL REQUIRES A VALUE` at line 1, col 8 (offset
  7).
- `casmalignzero.s`: `CASM: ALIGN BOUNDARY ZERO` at line 1, col 1 (offset
  0).
- `casmresrange.s`: `CASM: VALUE OUT OF RANGE` at line 1, col 9 (offset 8).
- Every dispatch above ended with a clean `c64[8]:>` shell return.

## Manual Confirmation

1. Boot `build/casm_include_test.d64` into Command64, run
   `test_casm_directives`, expect `CASM DIRECTIVES: PASS`.
2. Boot `build/casm_phase13_test.d64` into Command64.
3. Run `casm casmres1.s`, then `comp casmres1.prg casmres1.ref`; expect
   `FILES COMPARE OK`. Repeat for `casmfill1`/`casmalign1`.
4. Run `casm casmresfwd.s`, `casm casmfillnoval.s`, `casm casmalignzero.s`,
   `casm casmresrange.s` in turn; expect the four diagnostics listed above,
   each at its documented location.
5. Confirm CASM's own version banner still reads `CASM V0.3.0` (build
   incremented, no version bump this WP -- that lands at WP85, the whole
   Phase 13 completion gate).

## Completion Gate

- [x] `.RES`/`.FILL`/`.ALIGN` implemented and live-verified in VICE.
- [x] Production fixtures byte-exact against hand-derived references.
- [x] All four documented diagnostics live-verified for message and
      location.
- [x] Isolation harness (`test_casm_directives`) live-verified, 9/9.
- [x] Regression witnesses (`test_casm_expr`/`test_casm_pass1`/
      `test_casm_frame`) confirmed clean.
- [x] Full clean rebuild confirmed stable.
- [x] Envelope bumps explicitly approved, not silently absorbed.
- [x] **User explicitly approves closing WP81.** Approved 2026-08-21.

WP81 is complete. Phase 13 remains open for WP82 (`.INCBIN`), WP83
(`.ASSERT`), WP84 (DASH adoption), and WP85 (consolidated verification and
version promotion to `0.4.0`).
