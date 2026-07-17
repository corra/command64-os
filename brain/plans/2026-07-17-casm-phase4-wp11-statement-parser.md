# Implementation Plan: CASM Phase 4 WP11 — Statement Parser and Syntax Validation

## Objective

WP11 implements statement-level parsing and syntax validation in a new module, `parser.s`. It consumes the token stream from the lexer, identifies statement structures, validates the operand grammar, parses and converts numeric literal values (decimal, hexadecimal, binary) to 16-bit integers, and reports syntax errors.

---

## Technical Specifications

### 1. Statement AST Record
To transfer parsed statement data to the downstream addressing-mode matcher and emission engine, we define a structured, BSS-allocated statement record `CasmParserStmt`:

```assembly
; Statement record layout in BSS
.struct CasmParserStmt
    Type        .byte ; CASM_TOKEN_MNEMONIC, CASM_TOKEN_DIRECTIVE, or CASM_TOKEN_EOF/NEWLINE
    Subtype     .byte ; Mnemonic index (0-55) or Directive index (1-6)
    OpKind      .byte ; Operand category (implied, immediate, absolute, indirect, etc.)
    ValLo       .byte ; 16-bit numeric value low byte (if operand present)
    ValHi       .byte ; 16-bit numeric value high byte
    RegSubtype  .byte ; Register subtype index (CASM_REGISTER_X, CASM_REGISTER_Y, or CASM_REGISTER_A)
.endstruct
```

### 2. LL(1) Statement Grammar
The parser reads tokens from the lexer and validates the following restricted grammar:

- **Empty / Line Terminator**: `NEWLINE` or `EOF` -> Sets statement `Type` to `NEWLINE` or `EOF`.
- **Labels / Symbols**: If a statement starts with `IDENTIFIER` or has a trailing colon, it is rejected with `CASM_DIAG_SYNTAX_ERROR` in this phase (as symbols/labels are deferred to Phase 6B).
- **Mnemonic / Directive**: Must begin with `MNEMONIC` or `DIRECTIVE` token.
  - Read operand sequence:
    - **No operands**: Expect `NEWLINE` or `EOF` immediately.
    - **Immediate**: `#` followed by `NUMBER`.
    - **Absolute / Zero Page**: `NUMBER` optionally followed by `,` and then `REGISTER` (must be `X` or `Y`).
    - **Accumulator**: `REGISTER` (must be `A`).
    - **Indirect / Indexed-Indirect**: `(` followed by `NUMBER`, then:
      - `)` -> Optionally followed by `,` and then `REGISTER` `Y`.
      - `,` -> Must be followed by `REGISTER` `X` and then `)`.

### 3. Numeric Value Converter
Implement `parseNumericValue` in `parser.s` to convert the scanned text in `CasmTokenText` into a 16-bit value in `ValLo/Hi`.
- **Hexadecimal (`$`)**: Parse trailing characters as base-16 digits.
- **Binary (`%`)**: Parse trailing characters as base-2 digits (`0` or `1`).
- **Decimal**: Parse characters as base-10 digits.
- Bounds check: If the computed value exceeds 65535, report `CASM_DIAG_OPERAND_OUT_OF_RANGE`.

### 4. Diagnostics Added
- `CASM_DIAG_SYNTAX_ERROR` ($1C) -> `"CASM: SYNTAX ERROR"`
- `CASM_DIAG_EXPECTED_NEWLINE` ($1D) -> `"CASM: EXPECTED NEWLINE"`

---

## Proposed Changes

### Build System & Configuration
#### [MODIFY] [CMakeLists.txt](CMakeLists.txt)
- Add `src/external/casm/parser.s` to the `casm` executable source list.

### CASM Codebase

#### [MODIFY] [common.inc](src/external/casm/common.inc)
- Define `CasmParserStmt` struct offsets.
- Add parser error diagnostics `$1C` and `$1D`.
- Add operand kind equates:
  ```assembly
  CASM_OPKIND_IMPLIED          = 0
  CASM_OPKIND_ACCUMULATOR      = 1
  CASM_OPKIND_IMMEDIATE        = 2
  CASM_OPKIND_ABSOLUTE         = 3  ; Covers ZP, Absolute
  CASM_OPKIND_ABSOLUTE_X       = 4  ; ZP,X / Abs,X
  CASM_OPKIND_ABSOLUTE_Y       = 5  ; ZP,Y / Abs,Y
  CASM_OPKIND_INDIRECT         = 6
  CASM_OPKIND_INDEXED_INDIRECT = 7  ; (ZP,X)
  CASM_OPKIND_INDIRECT_INDEXED = 8  ; (ZP),Y
  ```

#### [NEW] [parser.s](src/external/casm/parser.s)
- Implement `parserParseStatement` executing the LL(1) parser.
- Implement `parseNumericValue` helper.
- Allocates BSS space for `CasmParserStmt` and exports it.

#### [MODIFY] [diagnostics.s](src/external/casm/diagnostics.s)
- Append `msgSyntaxError` and `msgExpectedNewline` strings to RODATA.
- Extend `diagMessageLo/Hi` tables and bounds assertions.

---

## Verification Plan

### Automated Tests
- Build CASM using `cmake --build build --target casm` to verify successful assembly and linking.
- Ensure all compile-time size assertions pass.

### Manual Verification
- Rebuild test image and run in local VICE emulator.
- Test parsing of various valid statements against `casm` to confirm correct internal state:
  - `INX` -> `Type = MNEMONIC`, `OpKind = IMPLIED`
  - `LDA #10` -> `Type = MNEMONIC`, `OpKind = IMMEDIATE`, `ValLo = 10`, `ValHi = 0`
  - `STA $0400,X` -> `Type = MNEMONIC`, `OpKind = ABSOLUTE_X`, `ValLo = $00`, `ValHi = $04`
  - `LDA ($10),Y` -> `Type = MNEMONIC`, `OpKind = INDIRECT_INDEXED`, `ValLo = $10`, `ValHi = $00`
- Confirm that syntax errors (e.g. `LDA #`, `STA $0400,`, `LDA ($10,Y)`) correctly print `CASM: SYNTAX ERROR` and exit cleanly.
