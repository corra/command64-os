---
feature: debug-phase2-assembler
created: 2026-06-27
status: active
---

# Plan: DEBUG Phase 2 - Interactive Inline 6502 Assembler (`A`)

## Goal & Rationale

Implement an interactive line-by-line assembler (`A [address]`) allowing direct compilation of 6502 assembly mnemonics and operands into memory. This provides parity with MS-DOS `DEBUG`'s `A` command, making on-the-fly binary patching and program writing highly productive.

## Scope

- Interactive assembly loop at a specified or default memory address.
- Mnemonic parser supporting 56 standard 6502 instructions.
- Operand parsing matching standard MOS 6502 syntax to resolve the 13 addressing modes.
- Offset calculation and range verification for relative branch instructions.
- Opcode dictionary lookup and writing compiled bytes directly to memory.

## Files to Create/Modify

| File | Action | Notes |
|------|--------|-------|
| [src/external/debug/debug.asm](src/external/debug/debug.asm) | Modify | Implement line-by-line prompt, tokenization, mode matching, dictionary matching, and byte writing. |

## Detailed Design & Key Decisions

### 1. Interactive Assembly Prompt Loop

- **Workflow**:
  - Execute command `A [address]`. If no address is specified, default to the last accessed memory address (`currentAddr`).
  - In a loop:
    1. Print the current address as a prompt, followed by a space: e.g. `2000:`
    2. Read line of input into `inputBuf` (reusing `readLine`).
    3. If the input line is empty (length 0), exit the assembly loop.
    4. Process the line. If a compilation error occurs, print `error` and repeat the prompt at the *same* address.
    5. If compilation is successful, write bytes to memory, advance `currentAddr` by the instruction length, and repeat the prompt at the new address.

### 2. Zero Page & Memory Management

The assembler will utilize the safe Zero Page range `$7C-$7F` to track assembler state during compilation:
```asm
.label mnemIndex    = $7C  // Index of matched mnemonic (0-56)
.label deducedMode  = $7D  // Deduced addressing mode
.label operandValLo = $7E  // Parsed operand value low byte
.label operandValHi = $7F  // Parsed operand value high byte
```

### 3. Mnemonic Parsing & Lexer

- **Lexer logic**:
  - Skip leading spaces in `inputBuf`.
  - Read the first 3 characters and convert them to uppercase to ensure case insensitivity.
  - Search for this 3-character string in `opStringTable` (which stores mnemonics grouped by 3 letters).
  - If found, record the index (0–56) into `mnemIndex`. If not found, report `error`.
  - Skip trailing spaces after the mnemonic. The remainder of the line is the operand string.

### 4. Operand Addressing Mode Deduction

- Deduce the addressing mode by scanning the operand string structure:
  - **No Operand**:
    - If string length is 0, set `deducedMode` to `MODE_IMP`. If no match is found in the dictionary, fallback/retry with `MODE_ACC`.
    - If the operand is exactly `'A'` or `'a'`, set `deducedMode` to `MODE_ACC`.
  - **Immediate Mode (`MODE_IMM`)**:
    - Operand starts with character `#`. The remaining characters must contain a hex value (skipping optional `$` prefix, e.g. `#$12` or `#12`). Set `deducedMode` to `MODE_IMM`.
  - **Indirect Modes**:
    - Operand starts with `(`:
      - If it ends with `,X)` or `,x)` $\rightarrow$ Indirect X (`MODE_IZX`) (e.g., `($12,X)`).
      - If it ends with `),Y` or `),y` $\rightarrow$ Indirect Y (`MODE_IZY`) (e.g., `($12),Y`).
      - If it ends with `)` $\rightarrow$ Indirect (`MODE_IND`) (e.g., `($1234)`).
  - **Indexed and Direct Modes**:
    - If operand contains `,X` or `,x`:
      - If value is 1 byte ($00–$FF) $\rightarrow$ Zero Page X (`MODE_ZPX`).
      - If value is 2 bytes ($0100–$FFFF) $\rightarrow$ Absolute X (`MODE_ABX`).
    - If operand contains `,Y` or `,y`:
      - If value is 1 byte ($00–$FF) $\rightarrow$ Zero Page Y (`MODE_ZPY`).
      - If value is 2 bytes ($0100–$FFFF) $\rightarrow$ Absolute Y (`MODE_ABY`).
    - If operand has no comma:
      - If value is 1 byte ($00–$FF) $\rightarrow$ Zero Page (`MODE_ZP`).
      - If value is 2 bytes ($0100–$FFFF) $\rightarrow$ Absolute (`MODE_ABS`).
  - **Branch Relative Mode (`MODE_REL`)**:
    - If the mnemonic is a branch instruction (`BCC`, `BCS`, `BEQ`, `BNE`, `BPL`, `BMI`, `BVC`, `BVS`), override `deducedMode` to `MODE_REL`.
    - Parse target address (skipping `$`), calculate relative offset: `offset = target - (currentAddr + 2)`.
    - Verify offset fits in a signed 8-bit byte (`-128` to `127`). If not, report `error`.
    - Store the calculated offset in `operandValLo`.

### 5. Opcode Selection & Fallback/Promotion

- **Dictionary Matching**:
  - Scan all opcodes (0 to 255):
    1. Read the mnemonic index for that opcode from `opMnemonicIndex`.
    2. Read the addressing mode for that opcode from `opAddrMode`.
    3. If both the mnemonic index and addressing mode match our parsed results, this is the target opcode!
    4. If no opcode matches the combination, check for Zero Page fallback/promotion:
       - If `deducedMode == MODE_ZP` $\rightarrow$ promote to `MODE_ABS` and retry search.
       - If `deducedMode == MODE_ZPX` $\rightarrow$ promote to `MODE_ABX` and retry search.
       - If `deducedMode == MODE_ZPY` $\rightarrow$ promote to `MODE_ABY` and retry search.
       - Otherwise, or if retry still fails, report `error`.

### 6. Write to Memory & Advance PC

- Write the resolved opcode byte to `(currentAddr)`.
- If length is 2 or 3, write `operandValLo` to `(currentAddr) + 1`.
- If length is 3, write `operandValHi` to `(currentAddr) + 2`.
- Advance `currentAddr` by instruction length (looked up from `modeLength` index `deducedMode`).

---

## Detailed Implementation Checklist

- [ ] Implement `A` command parser and interactive prompt loop.
- [ ] Implement mnemonic lexer scanning `opStringTable` with case insensitivity.
- [ ] Implement operand string pattern detector for all 13 addressing modes, supporting optional `$` prefix.
- [ ] Implement relative offset calculations for branch instructions with range checking.
- [ ] Implement dictionary lookup scanning `opMnemonicIndex` and `opAddrMode` with automatic zero-page promotion fallback.
- [ ] Implement memory writing and program counter advancement.

---

## Verification Plan

### Manual Verification

1. Assemble a simple program at `$2000`:
   ```text
   LDA #$01      ; Imm
   LDX #$00      ; Imm
   STA $D020,X   ; Abx
   INX           ; Imp
   CPX #$0A      ; Imm
   BNE $2004     ; Rel
   RTS           ; Imp
   ```

2. Run `U 2000` to verify that disassembly output matches the input instructions.
3. Run `G 2000` to execute and verify that it turns the screen border color white.
