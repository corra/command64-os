# Implementation Plan: CASM Phase 4 — Statement Parser, Opcode Table, and Numeric Static Assembly

## Objective

Phase 4 implements a restricted numeric-only vertical slice of the assembler. It introduces statement-level parsing, instruction classification, operand sizing, addressing-mode matching against the official 6502 opcode table, and binary generation. It accepts a single, initial `.org`, data definition directives `.byte` and `.word` with numeric operands, and outputs a native relocatable or absolute PRG file.

Labels, symbols, forward references, expressions, macros, listings, and maps are excluded.

---

## Proposed Work Package Breakdown

To maintain state-gated execution and atomic commits, Phase 4 is partitioned into four distinct work packages:

### 1. Work Package 11: Statement Parser and Syntax Validation
- **Goal**: Parse individual source statements from the lexer stream.
- **Scope**:
  - Implement statement loop in `parser.s` (scans statement structure: optional label/identifier, mnemonic/directive, operands, comment, newline/EOF).
  - Parse comma-separated numeric operands and arguments.
  - Reject statements with malformed syntax (e.g. consecutive commas, missing arguments).
- **Diagnostics added**:
  - `CASM_DIAG_SYNTAX_ERROR` ($1C) -> `"CASM: SYNTAX ERROR"`
  - `CASM_DIAG_EXPECTED_NEWLINE` ($1D) -> `"CASM: EXPECTED NEWLINE"`

### 2. Work Package 12: Opcode Table and Addressing Mode Matcher
- **Goal**: Define the 6502 opcode lookup tables and match mnemonics with operands.
- **Scope**:
  - Define compressed opcode table in `opcodes.s` RODATA (mapping 56 mnemonics, supported addressing modes, and byte opcodes).
  - Implement addressing-mode matcher that inspects operand tokens (e.g. `#` for immediate, `(...,X)` for indexed-indirect, `,X` or `,Y` for indexed, etc.) and determines the target mode:
    - Implied, Accumulator, Immediate, Zero-Page, Zero-Page X/Y, Absolute, Absolute X/Y, Indirect, Indexed-Indirect (X), Indirect-Indexed (Y), and Relative.
  - Determine numeric sizes (8-bit vs 16-bit) and select the correct opcode.
  - Relative branch range check (`-128` to `127`) from current program counter.
- **Diagnostics added**:
  - `CASM_DIAG_INVALID_ADDR_MODE` ($1E) -> `"CASM: INVALID ADDRESSING MODE"`
  - `CASM_DIAG_OPERAND_OUT_OF_RANGE` ($1F) -> `"CASM: OPERAND OUT OF RANGE"`

### 3. Work Package 13: Directives and Emission Engine
- **Goal**: Process numeric directives and emit machine bytes to a native output file.
- **Scope**:
  - Parse `.ORG` (must be single, initial; records start address).
  - Parse `.BYTE` and `.WORD` containing comma-separated numeric literals.
  - Write output stream buffers to the derived output file using `fileIo` write APIs.
  - Generate the standard 2-byte PRG load address header.
  - Track Program Counter (`CasmPc`) and check segment limits (max `$FFFF`).
- **Diagnostics added**:
  - `CASM_DIAG_DUPLICATE_ORG` ($20) -> `"CASM: DUPLICATE ORG"`
  - `CASM_DIAG_ORG_REQUIRED` ($21) -> `"CASM: ORG REQUIRED"`
  - `CASM_DIAG_ADDRESS_OVERFLOW` ($22) -> `"CASM: ADDRESS OVERFLOW"`

### 4. Work Package 14: Phase 4 Orchestration and Verification
- **Goal**: Integrate components into the main assembler execution path and verify against reference binaries.
- **Scope**:
  - Replace the temporary token dump loop in [casm.s](src/external/casm/casm.s) with the parser/compiler loop.
  - Handle central fatal cleanup on compile errors (closing source and deleting partial/incomplete output files).
  - Write test assembly fixtures in [GenerateCasmTestFixtures.cmake](cmake/GenerateCasmTestFixtures.cmake) containing valid numeric instructions.
  - Verify generated binaries match expected machine code bytes exactly.
  - Advanced version stage to `16` (`0.1.16`).

---

## Proposed Changes

### Build System & Configuration
- **Modify** [CMakeLists.txt](CMakeLists.txt): Add new files `parser.s` and `opcodes.s` to the `casm` executable target.

### CASM Codebase

#### [NEW] [parser.s](src/external/casm/parser.s)
- Implements statement-level parsing, syntax extraction, and argument collection.
- Exports `parserParseStatement`.

#### [NEW] [opcodes.s](src/external/casm/opcodes.s)
- Stores the 6502 opcode matrix and exports matching utilities.
- Exports `opcodesFindOpcode`.

#### [MODIFY] [diagnostics.s](src/external/casm/diagnostics.s)
- Register diagnostic messages `$1C` to `$22` and update compilation checks.

#### [MODIFY] [common.inc](src/external/casm/common.inc)
- Add parser/opcode structures, addressing mode enum constants, and diagnostic IDs.

#### [MODIFY] [casm.s](src/external/casm/casm.s)
- Wire parser and emitter loop.

#### [MODIFY] [GenerateCasmTestFixtures.cmake](cmake/GenerateCasmTestFixtures.cmake)
- Append test fixtures `casmnum1.asm`, `casmnum2.asm` and compile expected outputs `casmnum1.ref`, `casmnum2.ref` for binary verification.

---

## Verification Plan

### Automated Tests
- Run `cmake --build build --target casm` to verify error-free compilation and table size bounds check.
- Compare output byte-for-byte using a validation script or comparison targets (e.g. `comp` utility on Command 64) against trusted expected binaries.

### Manual Verification
- Deploy to local VICE emulator and run:
  ```text
  casm casmnum1.asm /o:casmnum1.prg
  comp casmnum1.prg casmnum1.ref
  ```
  Verify that the `comp` command reports the files match exactly and returns success.
- Test error paths (e.g. invalid instruction syntax, out-of-bounds relative branches) and confirm correct descriptive fatal messages are displayed.
