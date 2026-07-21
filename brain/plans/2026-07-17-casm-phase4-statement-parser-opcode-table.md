# Implementation Plan: CASM Phase 4 — Statement Parser, Opcode Table, and Numeric Static Assembly

## Objective

Phase 4 implements a restricted numeric-only vertical slice of the assembler. It introduces statement-level parsing, instruction classification, operand sizing, addressing-mode matching against the official 6502 opcode table, and binary generation. It accepts a single, initial `.org`, data definition directives `.byte` and `.word` with numeric operands, and outputs a native relocatable or absolute PRG file.

Labels, symbols, forward references, expressions, macros, listings, and maps are excluded.

---

## Proposed Work Package Breakdown

To maintain state-gated execution and atomic commits, Phase 4 is partitioned
into five distinct work packages. The original plan folded final phase
verification into WP14; Taskwarrior created separate WP14 and WP15 records, so
the corrected split reserves WP14 for orchestration/binary validation and WP15
for independent phase verification and closeout.

### 1. Work Package 11: Statement Parser and Syntax Validation
- **Goal**: Parse individual source statements from the lexer stream.
- **Scope**:
  - Implement statement loop in `parser.s` (scans statement structure: optional label/identifier, mnemonic/directive, operands, comment, newline/EOF).
  - Parse comma-separated numeric operands and arguments.
  - Reject statements with malformed syntax (e.g. consecutive commas, missing arguments).
- **Diagnostics added**:
  - `CASM_DIAG_SYNTAX_ERROR` ($1C) -> `"CASM: SYNTAX ERROR"`
  - `CASM_DIAG_EXPECTED_NEWLINE` ($1D) -> `"CASM: EXPECTED NEWLINE"`
  - `CASM_DIAG_OPERAND_OUT_OF_RANGE` ($1E) -> `"CASM: OPERAND OUT OF RANGE"`
    (amended 2026-07-17: moved up from WP12 because the WP11 numeric-literal
    converter's >65535 bounds check needs it; keeping it contiguous at $1E
    avoids a hole in the dense `diagPrintFatal` message table)

### 2. Work Package 12: Opcode Table and Addressing Mode Matcher
- **Goal**: Define the 6502 opcode lookup tables and match mnemonics with operands.
- **Scope**:
  - Define compressed opcode table in `opcodes.s` RODATA (mapping 56 mnemonics, supported addressing modes, and byte opcodes).
  - Implement addressing-mode matcher that inspects operand tokens (e.g. `#` for immediate, `(...,X)` for indexed-indirect, `,X` or `,Y` for indexed, etc.) and determines the target mode:
    - Implied, Accumulator, Immediate, Zero-Page, Zero-Page X/Y, Absolute, Absolute X/Y, Indirect, Indexed-Indirect (X), Indirect-Indexed (Y), and Relative.
  - Determine numeric sizes (8-bit vs 16-bit) and select the correct opcode.
  - For branch mnemonics, select the Relative mode and branch opcode only. The
    displacement computation and `-128..+127` range check move to WP13 (see the
    amendment note below).
  - Reuse `CASM_DIAG_OPERAND_OUT_OF_RANGE` ($1E, added in WP11) to reject
    immediate/zero-page-indirect operands that exceed 8 bits.
  - Detailed plan: `brain/plans/2026-07-17-casm-phase4-wp12-opcode-table-matcher.md`.
- **Diagnostics added**:
  - `CASM_DIAG_INVALID_ADDR_MODE` ($1F) -> `"CASM: INVALID ADDRESSING MODE"`
    (amended 2026-07-17: was $1E; shifted to $1F because WP11 now owns $1E for
    `CASM_DIAG_OPERAND_OUT_OF_RANGE`. Net slot usage through WP12 is unchanged,
    so WP13's existing $20-$22 numbering is unaffected.)
  - **Amendment 2026-07-17 (dependency fix)**: the original WP12 scope listed a
    "relative branch range check from current program counter." The program
    counter (`CasmPc`) is not introduced until WP13, so WP12 cannot range-check
    branches. WP12 now resolves the Relative *mode* and opcode only; the
    PC-relative displacement and range check are WP13 work.

### 3. Work Package 13: Directives and Emission Engine
- **Goal**: Process numeric directives and emit machine bytes to a native output file.
- Detailed plan: `brain/plans/2026-07-17-casm-phase4-wp13-directives-emission.md`.
- **Scope**:
  - Parse `.ORG` (must be single, initial; records start address).
  - Parse `.BYTE` and `.WORD` containing comma-separated numeric literals. This
    requires refining the WP11 parser: its single-operand addressing-mode
    grammar cannot express a comma-separated list, so `parserParseStatement`
    leaves `.BYTE`/`.WORD` operands for the WP13 directive handler to read from
    the lexer.
  - Emit a plain absolute PRG (2-byte load-address header = the `.ORG` value,
    then raw bytes) via `fileIo` write APIs. No R6 relocation trailer.
  - Track Program Counter (`CasmPc`) and check segment limits (max `$FFFF`).
  - Compute relative branch displacements against `CasmPc` and enforce the
    `-128..+127` range (moved here from WP12, which now only selects the
    Relative mode and branch opcode; see the WP12 amendment note above).
  - Single forward pass is sufficient (Phase 4 has no symbols/forward
    references); this is a strict, forward-compatible subset of the two-pass
    architecture, which arrives with symbol support in a later phase.
  - **Decision (amendment 2026-07-17)**: WP13 is where output becomes
    operational (per the Phase 0B note that output begins in the numeric
    static-output phase). Confirmed: emit by default on a successful assembly,
    accept `/S` as the now-default static mode, and keep only `/M`/`/L`
    rejected.
- **Diagnostics added**:
  - `CASM_DIAG_DUPLICATE_ORG` ($20) -> `"CASM: DUPLICATE ORG"`
  - `CASM_DIAG_ORG_REQUIRED` ($21) -> `"CASM: ORG REQUIRED"`
  - `CASM_DIAG_ADDRESS_OVERFLOW` ($22) -> `"CASM: ADDRESS OVERFLOW"`
  - `CASM_DIAG_BRANCH_OUT_OF_RANGE` ($23) -> `"CASM: BRANCH OUT OF RANGE"`
    (added 2026-07-17: the relative range check moved here from WP12 with the
    program counter it depends on)

### 4. Work Package 14: Phase 4 Orchestration and Verification
- **Goal**: Integrate components into the main assembler execution path and verify against reference binaries.
- Detailed plan: `brain/plans/2026-07-20-casm-phase4-wp14-orchestration-binary-validation.md`.
- **Scope**:
  - Replace the temporary token dump loop in [casm.s](src/external/casm/casm.s) with the parser/compiler loop.
  - Handle central fatal cleanup on compile errors (closing source and deleting partial/incomplete output files).
  - Write test assembly fixtures in [GenerateCasmTestFixtures.cmake](cmake/GenerateCasmTestFixtures.cmake) containing valid numeric instructions.
  - Verify generated binaries match expected machine code bytes exactly.
  - Advanced version stage to `16` (`0.1.16`).

### 5. Work Package 15: Phase 4 Verification and Closeout
- **Goal**: Independently reproduce the Phase 4 acceptance evidence, obtain
  final user runtime confirmation, synchronize all milestone records, and ask
  the user whether Phase 4 is done.
- Detailed plan:
  `brain/plans/2026-07-20-casm-phase4-wp15-phase-verification-closeout.md`.
- Depends on completed and user-approved WP14.
- Advances the version stage to `17` (`0.1.17`) only through its separately
  approved completion gate.
- The diagnostic source-context feature historically called `WP15` is renamed
  DSC1 in current planning and is not this Phase 4 work package.

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
- Extend the existing `casmemit1` and `casmhello` fixtures and add independently
  generated `casmemit1.ref` and `casmhello.ref` files for binary verification.

---

## Verification Plan

### Automated Tests
- Run `cmake --build build --target casm` to verify error-free compilation and table size bounds check.
- Verify trusted reference manifests during the host build and compare CASM
  output byte-for-byte with the native `comp` utility on Command 64.

### Manual Verification
- Deploy to local VICE emulator and run:
  ```text
  casm casmemit1 /o:casmemit1.prg
  comp casmemit1.prg casmemit1.ref
  ```
  Verify that the `comp` command reports the files match exactly and returns success.
- Test error paths (e.g. invalid instruction syntax, out-of-bounds relative branches) and confirm correct descriptive fatal messages are displayed.
