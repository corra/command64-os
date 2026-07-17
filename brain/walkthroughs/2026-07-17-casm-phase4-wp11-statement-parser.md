# CASM Phase 4 WP11 — Statement Parser and Syntax Validation Walkthrough

- **Date**: 2026-07-17
- **Version**: CASM `0.1.13`, build 1042
- **Plan**: `brain/plans/2026-07-17-casm-phase4-wp11-statement-parser.md`
- **Parent plan**: `brain/plans/2026-07-17-casm-phase4-statement-parser-opcode-table.md`

## Scope Delivered

- `parser.s` (new): `parserParseStatement` runs the restricted LL(1) grammar
  over the lexer's single-token buffer and fills the exported `CasmParserStmt`
  record. `parseNumericValue` converts decimal/hex/binary literals to a 16-bit
  value using a 24-bit accumulator with a sticky overflow flag so values above
  65535 are rejected regardless of trailing digits.
- `common.inc`: `CasmParserStmt` offsets, `CASM_OPKIND_*` equates, and
  diagnostics `$1C`–`$1E`.
- `diagnostics.s`: `SYNTAX ERROR`, `EXPECTED NEWLINE`, and
  `OPERAND OUT OF RANGE` messages, with the fatal range and message tables
  extended to `CASM_DIAG_PHASE4_LAST`.
- `casm.s`: temporary WP11 parse driver replacing the WP10 token-dump loop.
  Syntax diagnostics surface through the existing central fatal path; a clean
  parse to EOF prints `CASM: INPUT VALIDATED`. WP14 replaces this driver.
- Fixtures: `casmwp11` (all addressing modes, valid) and `casmerr1`–`casmerr5`
  (one per WP11 diagnostic), generated in
  `cmake/GenerateCasmTestFixtures.cmake` and appended to `test.d64`.

## Plan Deviations (approved during implementation)

- **Verification brought forward.** The WP11 plan's manual verification assumes
  a running parser, but the parent plan defers parser wiring to WP14. A
  *temporary* driver was added to `casm.s` so WP11 could be exercised now,
  rather than closing with no runtime evidence.
- **Diagnostic renumber.** `CASM_DIAG_OPERAND_OUT_OF_RANGE` was placed at `$1E`
  (contiguous after `$1D`) because the WP11 numeric converter needs a bounds
  diagnostic and a hole would break the dense `diagPrintFatal` table. The
  parent Phase 4 plan was amended: WP12's `INVALID_ADDR_MODE` shifts `$1E`→`$1F`;
  net slot usage through WP12 is unchanged, so WP13's `$20`–`$22` are unaffected.

## Automated Verification

- `cmake --build build --target casm` assembles and links cleanly; all
  compile-time size/range asserts pass.
- A no-change rebuild does not increment `BUILD_CASM` (held at 1042).
- `cmake --build build --target test_image_d64` places `casmwp11` and
  `casmerr1`–`casmerr5` on `test.d64`.

## Runtime Verification (user-confirmed in local VICE)

| Command | Expected | Result |
|---------|----------|--------|
| `casm casmwp11` | banner, then `CASM: INPUT VALIDATED` | pass |
| `casm casmerr1` (`LDA #`) | `CASM: SYNTAX ERROR` | pass |
| `casm casmerr2` (`STA $0400,`) | `CASM: SYNTAX ERROR` | pass |
| `casm casmerr3` (`LDA ($10,Y)`) | `CASM: SYNTAX ERROR` | pass |
| `casm casmerr4` (`LDA #10 20`) | `CASM: EXPECTED NEWLINE` | pass |
| `casm casmerr5` (`LDA #70000`) | `CASM: OPERAND OUT OF RANGE` | pass |

- **`casmshort` observation**: reports `CASM: SYNTAX ERROR`. This is expected,
  not a regression — the fixture ends in `JMP START_LABEL`, and identifier
  (label/symbol) operands are deferred to a later phase, so the parser rejects
  the operand. The fixture was authored for the WP4–WP10 lexer stream layer,
  where an identifier tokenizes cleanly; it cannot fully parse until label
  support lands.

## Known Limitations / Follow-ups

- Valid-case internal state (`OpKind`/`ValLo`/`ValHi`) is not observable at
  runtime; there is no statement dump. Per the parent plan, per-instruction
  correctness is verified by WP14's byte-for-byte reference comparison once
  emission exists.
- The `casm.s` parse driver and these WP11 fixtures are temporary scaffolding;
  WP14 replaces the driver with the parser/emitter loop and adds the
  `.ref`-compared assembly fixtures.

## Completion

- User approved marking WP11 done on 2026-07-17.
- Version stage advanced `12` → `13` (CASM `0.1.13`), build 1042.
