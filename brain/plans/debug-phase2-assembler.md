---
feature: debug-phase2-assembler
created: 2026-06-27
status: planned
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
| [src/external/debug/debug.asm](file:///home/morgan/development/c64/command64-os/src/external/debug/debug.asm) | Modify | Implement line-by-line prompt, tokenization, mode matching, dictionary matching, and byte writing. |

## Detailed Design & Key Decisions

### 1. Interactive Assembly Prompt Loop
* **Workflow**:
  * Execute command `A [address]`. If no address is specified, default to the last accessed memory address (`currentAddr`).
  * In a loop:
    1. Print the current address as a prompt, followed by a space: e.g. `2000:`
    2. Read line of input into `inputBuf` (reusing `readLine`).
    3. If the input line is empty (length 0), exit the assembly loop.
    4. Process the line. If a compilation error occurs, print `error` and repeat the prompt at the *same* address.
    5. If compilation is successful, write bytes to memory, advance `currentAddr` by the instruction length, and repeat the prompt at the new address.

### 2. Mnemonic Parsing & Lexer
* **Lexer logic**:
  * Skip leading spaces in `inputBuf`.
  * Read the first 3 characters and convert them to uppercase.
  * Search for this 3-character string in `opStringTable` (which stores mnemonics grouped by 3 letters).
  * If found, record the index (0–56). If not found, report `error`.
  * Skip trailing spaces after the mnemonic. The remainder of the line is the operand string.

### 3. Operand Addressing Mode Deduction
* Deduce the addressing mode by scanning the operand string structure:
  * **No Operand**:
    * If string length is 0, addressing mode is Implied (`MODE_IMP`) or Accumulator (`MODE_ACC`). 
    * If the mnemonic only supports Accumulator (e.g. `ASL`, `LSR`, `ROL`, `ROR`) and operand is `'A'` or empty, default to Accumulator.
  * **Immediate Mode (`MODE_IMM`)**:
    * Operand starts with character `#`. The remaining characters must contain a hex value (e.g., `#$12` or `#12`).
  * **Indirect Modes**:
    * Operand starts with `(`:
      * If it ends with `,X)` $\rightarrow$ Indirect X (`MODE_IZX`) (e.g., `($12,X)`).
      * If it ends with `),Y` $\rightarrow$ Indirect Y (`MODE_IZY`) (e.g., `($12),Y`).
      * If it ends with `)` $\rightarrow$ Indirect (`MODE_IND`) (e.g., `($1234)`).
  * **Indexed and Direct Modes**:
    * If operand contains `,X`:
      * If value is 1 byte ($00–$FF) $\rightarrow$ Zero Page X (`MODE_ZPX`).
      * If value is 2 bytes ($0100–$FFFF) $\rightarrow$ Absolute X (`MODE_ABX`).
    * If operand contains `,Y`:
      * If value is 1 byte ($00–$FF) $\rightarrow$ Zero Page Y (`MODE_ZPY`).
      * If value is 2 bytes ($0100–$FFFF) $\rightarrow$ Absolute Y (`MODE_ABY`).
    * If operand has no comma:
      * If value is 1 byte ($00–$FF) $\rightarrow$ Zero Page (`MODE_ZP`).
      * If value is 2 bytes ($0100–$FFFF) $\rightarrow$ Absolute (`MODE_ABS`).
  * **Branch Relative Mode (`MODE_REL`)**:
    * If the mnemonic is a branch instruction (`BCC`, `BCS`, `BNE`, `BEQ`, `BPL`, `BMI`, `BVC`, `BVS`), override mode detection to Relative.
    * Parse the target address from operand string (e.g., `$2050`).
    * Calculate the relative offset: `offset = target - currentAddr - 2`.
    * Verify that the offset fits in a signed 8-bit byte (`-128` to `127`). If not, report `error`.

### 4. Opcode Selection & Memory Write
* **Dictionary Matching**:
  * Scan all opcodes (0 to 255):
    1. Read the mnemonic index for that opcode from `opMnemonicIndex`.
    2. Read the addressing mode for that opcode from `opAddrMode`.
    3. If both the mnemonic index and addressing mode match our parsed results, this is the target opcode!
    4. If no opcode matches the combination, report `error` (invalid instruction/addressing mode combination).
* **Write to Memory**:
  * Write the resolved opcode byte to `(currentAddr)`.
  * Write operand byte(s) (determined by addressing mode length) to subsequent memory addresses.
  * Advance `currentAddr` by instruction length.

---

## Detailed Implementation Checklist
- [ ] Implement `A` command parser and interactive prompt loop.
- [ ] Implement mnemonic lexer scanning `opStringTable`.
- [ ] Implement operand string pattern detector for all 13 addressing modes.
- [ ] Implement relative offset calculations for branch instructions with range checking.
- [ ] Implement dictionary lookup scanning `opMnemonicIndex` and `opAddrMode`.
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
