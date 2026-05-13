# Plan: Implement DEBUG Unassemble (U) Command

## Objective
Implement a 6502 disassembler within the `DEBUG` utility via the `U` command. The command will translate machine code at a specified memory address or range into human-readable assembly language mnemonics and operands.

## Scope & Constraints
- **Target:** `src/external/debug/debug.asm`
- **Architecture:** 6502 (Standard, no undocumented opcodes required).
- **Display:** C64 40-column screen.
- **Memory:** `DEBUG.PRG` currently occupies ~1.9K. A lookup-table approach (~700 bytes) is preferred over complex bitwise decoding for speed and implementation simplicity, as there is plenty of room in the `$2000-$9FFF` application space.

## Command Syntax
- `U` : Disassemble starting at the last accessed address (defaulting to 16 instructions).
- `U [address]` : Disassemble starting at `address` for 16 instructions.
- `U [range]` : Disassemble the specified memory range. Note: The exact number of instructions disassembled might slightly exceed the range if an instruction overlaps the boundary.

## Display Format
The output will be formatted to fit neatly within 40 columns:
```text
ADDR  BYTES      MNEMONIC OPERAND
1000  A9 00      LDA #$00
1002  8D 20 D0   STA $D020
1005  E8         INX
1006  90 F8      BCC $1000
```
*   **ADDR**: 4 hex characters + 2 spaces.
*   **BYTES**: Up to 8 characters (e.g., `A9 00   `) + 1 space.
*   **MNEMONIC**: 3 characters + 1 space.
*   **OPERAND**: Up to 9 characters (e.g., `$1000,X`).

## Architecture & Data Structures

### 1. Mnemonic String Table (`opStringTable`)
A contiguous block of exactly 56 unique 3-letter 6502 mnemonics (plus `???` for invalid).
*   Size: ~171 bytes.

### 2. Opcode to Mnemonic Index (`opMnemonicIndex`)
A 256-byte lookup table mapping each opcode (`$00` to `$FF`) to an index (0-56) into the `opStringTable`.

### 3. Opcode Addressing Mode & Length (`opAddrMode`)
A 256-byte lookup table mapping each opcode to its addressing mode.
Modes (13 total):
- `MODE_IMP` (Implied, 1 byte)
- `MODE_ACC` (Accumulator, 1 byte)
- `MODE_IMM` (Immediate, 2 bytes)
- `MODE_ZP` (Zero Page, 2 bytes)
- `MODE_ZPX` (Zero Page,X, 2 bytes)
- `MODE_ZPY` (Zero Page,Y, 2 bytes)
- `MODE_REL` (Relative, 2 bytes) -> **Needs PC-relative math**.
- `MODE_ABS` (Absolute, 3 bytes)
- `MODE_ABX` (Absolute,X, 3 bytes)
- `MODE_ABY` (Absolute,Y, 3 bytes)
- `MODE_IND` (Indirect, 3 bytes)
- ... (Additional modes as needed)

*Note: The addressing mode inherently defines the instruction length (1, 2, or 3 bytes).*

## Implementation Steps

### Phase 1: Data Structures
1.  Define the addressing mode constants (`MODE_IMP`, etc.).
2.  Create the `opStringTable` (e.g., `ADC`, `AND`, `ASL`, ... `???`).
3.  Create the `opMnemonicIndex` table (256 bytes).
4.  Create the `opAddrMode` table (256 bytes).

### Phase 2: Command Logic (`cmdUnassemble`)
1.  Add `u` to the dispatcher in `debug.asm` and update `debugHelpMsg`.
2.  Implement `cmdUnassemble` argument parsing.
3.  Implement the disassembly loop:
    *   Read opcode at `currentAddr`.
    *   Look up mode in `opAddrMode`.
    *   Determine length from mode.
    *   **Print ADDR**: `printHex8` for Hi/Lo + spaces.
    *   **Print BYTES**: Loop 1, 2, or 3 times to print hex bytes.
    *   **Print MNEMONIC**: Look up index, calculate string offset, print 3 characters.
    *   **Print OPERAND**: Branch based on mode (e.g., print `($xx,X)` for `MODE_IZX`).
    *   Advance `currentAddr` by length.
    *   Check loop condition and repeat.

## Verification
1.  Assemble `debug.asm`.
2.  Run `U 1000 L 10` and verify the OS entry point mnemonics.
3.  Write a simple loop in memory and verify relative branch calculation.
