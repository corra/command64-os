# Test Plan: DEBUG Full Feature Verification

This document outlines the comprehensive test plan for the `DEBUG` utility of the `command64` OS. It covers all interactive commands, input parsing, memory management, register inspection, execution, and file I/O.

---

## 1. Introduction & Environment Setup

### Purpose

Ensure the technical integrity, stability, and MS-DOS parity of the `DEBUG` utility.

### Setup Procedure

1. Boot the `command64` OS emulator or hardware.
2. Ensure the compiled `debug.prg` is present on the active disk image (Device 8).
3. Execute `debug` from the shell prompt:

   ```bash
   C64:> debug
   ```

4. Verify the startup message displays (e.g., `DEBUG v0.1.8.1027`) followed by the prompt:

   ```bash
   -
   ```

### General Pass/Fail Criteria

- The utility must never crash or cause kernel lockups.
- Output text must be cleanly aligned to the 40-column display.
- Control must be returned cleanly to the shell when using `Q`.

---

## Test Suite 1: UI & Basic Input Handling

### Test 1.1: Basic Start-up and Empty Input

- **Input**: `[Enter]` on an empty prompt line.

- **Procedure**: Press `[Enter]` without typing any characters.
- **Pass Criteria**: A new prompt `-` is displayed. No error message is shown.

### Test 1.2: Destructive Backspace (INST/DEL)

- **Input**: Type `ABC`, press `[DEL]`, type `D`, press `[Enter]`.

- **Procedure**:
  1. Type `ABC`.
  2. Press the `INST/DEL` key to delete the `C`.
  3. Type `D`.
  4. Press `[Enter]`.
- **Pass Criteria**:
  - The character `C` is erased from the screen when `[DEL]` is pressed.
  - The command executed is `ABD` (resulting in `error` as it is an unknown command, proving `C` was not processed).

### Test 1.3: Spacing and Case Insensitivity

- **Input**: `d  1000   100f` and `D  1000   100F`

- **Procedure**:
  1. Start `DEBUG`.
  2. Type the first input with multiple spaces and lowercase command. Press `[Enter]`.
  3. Type the second input with uppercase command. Press `[Enter]`.
- **Pass Criteria**: Both inputs successfully parse and dump memory from `$1000` to `$100F`. Spaces are skipped, and lowercase characters are normalized.

### Test 1.4: Command Line Buffer Limit

- **Input**: Type a command of exactly 63 characters, and attempt a 64th.

- **Procedure**:
  1. Type `D` followed by 61 characters (e.g. `1`).
  2. Attempt to type a 64th character.
- **Pass Criteria**: The 64th character is ignored/not echoed on screen. Pressing `[Enter]` processes the 63-character command.

---

## Test Suite 2: Hexadecimal Arithmetic (`H`)

### Test 2.1: Standard Hex Addition and Subtraction

- **Input**: `H 1000 0050`

- **Procedure**: Type `H 1000 0050` and press `[Enter]`.
- **Pass Criteria**: Displays:

  ```hex
  1050  0FB0
  ```

  (representing Sum `$1050` and Difference `$0FB0`).

### Test 2.2: 16-bit Overflow and Underflow Wrap-around

- **Input**: `H FFFF 0001`

- **Procedure**: Type `H FFFF 0001` and press `[Enter]`.
- **Pass Criteria**: Displays:

  ```hex
  0000  FFFE
  ```

  (representing Sum `$0000` and Difference `$FFFE`).

### Test 2.3: Input Parameter Validation

- **Input**: `H 12G4 1000` or `H 1000` or `H 1000 2000 3000`

- **Procedure**: Enter each malformed arithmetic command.
- **Pass Criteria**: The utility prints `error` immediately for each input.

---

## Test Suite 3: Memory Manipulation (`D`, `E`, `F`, `M`, `C`, `S`)

### Test 3.1: Memory Dump (`D`)

- **Procedures & Inputs**:
  - `D` (No args): Displays 128 bytes (16 rows of 8 bytes) starting from the last set `currentAddr`.
  - `D 2000`: Sets `currentAddr` to `$2000` and displays 128 bytes.
  - `D 2000 201F` (Range): Displays memory from `$2000` to `$201F` inclusive.
  - `D 2000 L 10` (Length): Displays exactly 16 bytes starting at `$2000`.
  - `D` (Continuous): Pressing `D` sequentially advances `currentAddr` by 128 bytes each time.

- **Pass Criteria**:
  - Dump layout matches C64 screen: `ADDR: XX XX XX XX XX XX XX XX  ASCII`
  - Start addresses greater than end addresses (e.g. `D 2010 2000`) print `error`.

### Test 3.2: Memory Enter (`E`)

- **Input**: `E 2500 11 22 33 "C64" 44`

- **Procedure**:
  1. Enter the list command.
  2. Verify with `D 2500 L 08`.
- **Pass Criteria**:
  - Dump shows bytes at `$2500` as: `11 22 33 43 36 34 44` (ASCII `"C"`, `"6"`, `"4"` mapped to hex `$43`, `$36`, `$34`).
  - `currentAddr` is updated to the byte after the last entered item (`$2507`).

### Test 3.3: Memory Fill (`F`)

- **Input**: `F 3000 300F AA BB`

- **Procedure**:
  1. Fill the range with the alternating pattern.
  2. Dump range using `D 3000 300F`.
- **Pass Criteria**: Memory contains alternating `AA BB AA BB...`.

### Test 3.4: Memory Move (`M`)

- **Procedures & Inputs**:
  - **Forward Copy (No Overlap)**: `M 3000 3007 3100` (copies `$3000-$3007` to `$3100`).
  - **Backward Copy (Overlap, Dest > Src)**: Fill `$3000-$3007` with `01 02 03 04 05 06 07 08`. Move with `M 3000 3006 3001`.

- **Pass Criteria**:
  - Dump `$3100` shows identical bytes to `$3000`.
  - Overlap move results in memory `$3000-$3007` containing `01 01 02 03 04 05 06 07` (verifies overlap protection prevents source bytes from being corrupted before read).

### Test 3.5: Memory Compare (`C`)

- **Input**:
  - Identical blocks: `C 3000 3007 3100` (when blocks match).
  - Non-identical: Modify `$3102` to `EE` and compare again.

- **Pass Criteria**:
  - Matching blocks return no output.
  - Non-matching blocks output: `3002 XX EE 3102` (displays address 1, value 1, value 2, address 2).

### Test 3.6: Memory Search (`S`)

- **Input**:
  - `S 3000 3100 "C64"`
  - `S 3000 3100 AA BB`

- **Pass Criteria**: Displays the starting hex address(es) of all matching sequences in range. If no matches exist, returns directly to the prompt.

---

## Test Suite 4: Register Display & Editing (`R`)

### Test 4.1: Display Captured Register Context

- **Input**: `R`

- **Procedure**: Execute `R` on the prompt.
- **Pass Criteria**: Displays the current captured CPU register state:

  ```hex
  A=xx X=xx Y=xx P=xx S=xx
  ```

  (where `xx` represents hex numbers).

### Test 4.2: Modify Register (Valid Inputs)

- **Input**: `R A` -> `: FF`, `R X` -> `: 00`

- **Procedure**:
  1. Type `R A` and press `[Enter]`.
  2. At the `:` prompt, type `FF` and press `[Enter]`.
  3. Type `R` to display all registers.
- **Pass Criteria**:
  - Register `A` displays as `FF`.
  - Pressing `[Enter]` on `:` without typing a value leaves the register unmodified.

### Test 4.3: Modify Register (Invalid Inputs)

- **Inputs & Procedures**:
  - Type `R A` -> `: G0` (invalid hex).
  - Type `R A` -> `: 123` (out-of-bounds > 8-bit).
  - Type `R A` -> `: FF 00` (extra parameters).

- **Pass Criteria**: The utility prints `error` immediately and leaves register unmodified.

---

## Test Suite 5: Code Execution (`G`)

### Test 5.1: Execution of Subroutines

- **Input**: `E 4000 60` (6502 `RTS` instruction), followed by `G 4000`

- **Procedure**:
  1. Enter `RTS` at `$4000`.
  2. Run the routine using `G 4000`.
- **Pass Criteria**: Control returns cleanly to the `DEBUG` `-` prompt.

### Test 5.2: Default Address Execution

- **Input**: `G`

- **Procedure**:
  1. Dump or Enter at address `$4000` (setting `currentAddr` to `$4000`).
  2. Type `G` and press `[Enter]`.
- **Pass Criteria**: Executes starting at `$4000` and returns cleanly.

---

## Test Suite 6: Version and Help (`V`, `?`)

### Test 6.1: Help Command

- **Input**: `?`

- **Pass Criteria**: Displays a complete, cleanly aligned list of available command characters and descriptions.

### Test 6.2: Version Command

- **Input**: `V`

- **Pass Criteria**: Prints the `DEBUG` version and build number.

---

## Test Suite 7: Filename and Disk I/O (`N`, `L`, `W`)

### Test 7.1: Filename Management (`N`)

#### Test 7.1.1: Setting a Valid Filename

- **Input**: `N TEST1.PRG`

- **Procedure**:
  1. Launch the `debug` utility from the command64 shell.
  2. Type `N TEST1.PRG` and press `[Enter]`.
  3. Type `N` and press `[Enter]` to read back the active name.
- **Pass Criteria**: The screen displays `TEST1.PRG`.

#### Test 7.1.2: Case Insensitivity of Command

- **Input**: `n test2.prg`

- **Procedure**:
  1. Type `n test2.prg` (lowercase `n` and lowercase filename) and press `[Enter]`.
  2. Type `N` and press `[Enter]`.
- **Pass Criteria**: The screen displays `test2.prg`.

#### Test 7.1.3: Trailing Space and Parameter Isolation

- **Input**: `N TEST3.PRG` (trailing spaces)

- **Procedure**:
  1. Type `N TEST3.PRG` and press `[Enter]`.
  2. Type `N` and press `[Enter]`.
- **Pass Criteria**: The screen displays `TEST3.PRG` (trailing spaces are trimmed/ignored).

- **Input**: `N TEST4.PRG 2000` (trailing parameters)
- **Procedure**:
  1. Type `N TEST4.PRG 2000` and press `[Enter]`.
  2. Type `N` and press `[Enter]`.
- **Pass Criteria**: The screen displays `TEST4.PRG` (the trailing parameter `2000` is isolated and ignored).

#### Test 7.1.4: Filename Length Enforcement & Corruption Prevention

- **Input**: `N 123456789012345678901234567890123.prg` (33 characters)

- **Procedure**:
  1. Set filename to a valid 9-char name first: `N TEST4.PRG`.
  2. Type the 33-character name command and press `[Enter]`.
  3. Type `N` and press `[Enter]` to read back the active name.
- **Pass Criteria**:
  - The utility prints `error` upon the long input.
  - The second readback displays `TEST4.PRG` intact, proving that too-long filenames are rejected before modifying the active buffer.

---

### Test 7.2: File Writing (`W`)

#### Test 7.2.1: Write with Empty Filename

- **Procedure**:
  1. Start a fresh `debug` session.
  2. Type `W 2000 2010` and press `[Enter]`.

- **Pass Criteria**: The utility prints `error` immediately.

#### Test 7.2.2: Save as Standard Program (`PRG` - Default)

- **Input**: `N TMP.PRG` followed by `W 2000 200F`

- **Procedure**:
  1. Set the name to `TMP.PRG`.
  2. Fill a test pattern in memory: `F 2000 200F AA` (fills `$2000`–`$200F` with `$AA`).
  3. Type `W 2000 200F` and press `[Enter]`.
- **Pass Criteria**:
  - The drive active light flashes and control returns cleanly.
  - Quit debug (`Q`), run `dir` $\rightarrow$ verify `TMP.PRG` exists on the disk.
  - *Note*: `type TMP.PRG` in the shell will print the 2-byte starting address header first (often displaying as graphics/control codes) followed by the data.

#### Test 7.2.3: Save as Alternative Formats (`SEQ` and `USR`)

- **Input**: `W S 2000 200F` (Sequential) and `W U 2000 200F` (User)

- **Procedure**:
  1. Set the name to `TMP.SEQ`. Type `W S 2000 200F` (using either shifted or unshifted `S`) and press `[Enter]`.
  2. Set the name to `TMP.USR`. Type `W U 2000 200F` (using either shifted or unshifted `U`) and press `[Enter]`.
- **Pass Criteria**: Both writes return cleanly. Verify their existence on disk via `dir`. Typing `type TMP.SEQ` should show raw characters with no address header.

#### Test 7.2.4: Range Bounds Enforcement

- **Input**: `W 2010 2000`

- **Procedure**:
  1. Type `W 2010 2000` (start address greater than end address) and press `[Enter]`.
- **Pass Criteria**: The utility prints `error` immediately instead of writing indefinitely.

---

### Test 7.3: File Loading (`L`)

#### Test 7.3.1: Load with Empty Filename

- **Procedure**:
  1. Start a fresh `debug` session.
  2. Type `L` or `L 2000` and press `[Enter]`.

- **Pass Criteria**: Prints `error` immediately.

#### Test 7.3.2: Malformed Address Syntax Checks

- **Input**: `L G000` or `L 200G`

- **Procedure**:
  1. Set the name to `TMP.PRG`.
  2. Type `L G000` and press `[Enter]`.
- **Pass Criteria**: Prints `error` immediately (ignores single-address fallback).

#### Test 7.3.3: Relocated Loading & Address Tracking (`PRG`)

- **Input**: `L 4000`

- **Procedure**:
  1. Set the name to `TMP.PRG` (the file written in Test 7.2.2).
  2. Clear target memory: `F 4000 400F 00`.
  3. Type `L 4000` and press `[Enter]`.
  4. Type `D` (with no arguments) and press `[Enter]`.
- **Pass Criteria**:
  - The load returns cleanly.
  - The memory dump defaults to starting at `$4000` and shows the loaded `$AA` bytes, proving `currentAddr` was updated.

#### Test 7.3.4: Absolute Header Loading & Address Tracking (`PRG`)

- **Input**: `L`

- **Procedure**:
  1. Set the name to `TMP.PRG`.
  2. Clear target memory: `F 2000 200F 00`.
  3. Type `L` (no address argument) and press `[Enter]`.
  4. Type `D` (with no arguments) and press `[Enter]`.
- **Pass Criteria**:
  - The file loads back to its header start address (`$2000`).
  - The memory dump defaults to starting at `$2000` and shows the loaded `$AA` bytes, proving `currentAddr` was successfully read from KERNAL `$C1/$C2`.
  - *Troubleshooting Note*: If emulator fastloaders (like Virtual FS / True Drive Emulation settings) are active, KERNAL `$C1/$C2` (`MEMUSS`) may not be updated correctly and default to `$A000`. If this occurs, dump the memory at the file's original address manually (`D 2000`) to confirm the load succeeded.

#### Test 7.3.5: Relocated Loading (`SEQ` and `USR`)

- **Input**: `L S 4000` with `TMP.SEQ` (or `TMP.USR`)

- **Procedure**:
  1. Set the name to `TMP.SEQ` (the file written in Test 7.2.3).
  2. Clear target memory: `F 4000 400F 00`.
  3. Type `L S 4000` and press `[Enter]`.
  4. Type `D` (with no arguments) and press `[Enter]`.
- **Pass Criteria**:
  - The custom byte loader runs and control returns cleanly.
  - Dumping memory at `$4000` shows the `$AA` bytes (proves custom read loop loaded the raw bytes).

#### Test 7.3.6: Default Address Loading (`SEQ` and `USR`)

- **Input**: `L S` with `TMP.SEQ`

- **Procedure**:
  1. Set the name to `TMP.SEQ`.
  2. Clear target memory: `F 4000 400F 00`.
  3. Set `currentAddr` by running `D 4000`.
  4. Type `L S` (no address argument) and press `[Enter]`.
  5. Type `D` and press `[Enter]`.
- **Pass Criteria**:
  - The file loads successfully.
  - The dump starting at `currentAddr` (`$4000`) displays the loaded `$AA` bytes.

---

### Test 7.4: End-to-End Session Integration

- **Procedure**:
  1. Launch `debug`.
  2. Type `n testdata.bin` and press `[Enter]`.
  3. Fill memory: `f 4000 40ff 55` (places pattern `$55` at `$4000`–`$40FF`).
  4. Write range: `w 4000 40ff`
  5. Clear memory: `f 4000 40ff 00`
  6. Verify memory is empty: `d 4000 l 10` (should show all `$00` bytes).
  7. Load file back: `l` (relies on header `$4000` saved in the file).
  8. Verify memory is restored: `d` (should default dump starting at `$4000` and show the `$55` pattern).

- **Pass Criteria**: Memory dump shows `$55` successfully restored across the `$4000-$40FF` range.

---

## Test Suite 8: Instruction Disassembly (`U`)

### Test 8.1: Default Unassemble

- **Input**: `U`

- **Procedure**: Type `U` on the prompt.
- **Pass Criteria**: Displays 16 disassembled 6502 instructions starting at `currentAddr`, updating `currentAddr` to the byte following the last disassembled instruction.

### Test 8.2: Unassemble Address Fallback

- **Input**: `U 2200`

- **Procedure**: Type `U 2200` and press `[Enter]`.
- **Pass Criteria**: Sets `currentAddr` to `$2200` and disassembles 16 instructions.

### Test 8.3: Unassemble Range

- **Input**: `U 2200 220A`

- **Procedure**: Type `U 2200 220A` and press `[Enter]`.
- **Pass Criteria**: Disassembles all instructions that fall within the range `$2200` to `$220A` inclusive.

### Test 8.4: Relative Branch Target Calculations

- **Input**: Unassemble a range containing branch instructions (e.g. `BNE`, `BEQ`, `BCC`, `BCS`).

- **Procedure**: Verify the disassembled instruction printout.
- **Pass Criteria**: The branch destination address is printed correctly in hex alongside the branch mnemonic (e.g. `BNE $203B` instead of just the relative offset byte value).

### Test 8.5: Invalid Opcode Handling

- **Input**: Unassemble a memory region containing unimplemented opcodes (e.g. `$02`, `$12`).

- **Pass Criteria**: Invalid opcodes print `???` as the mnemonic, and the disassembler safely advances by 1 byte.

---

## Test Suite 9: Interactive Inline 6502 Assembler (`A`)

This suite verifies that the interactive assembler correctly prompts, reads, parses mnemonics/operands, handles case insensitivity and optional prefixes, performs addressing mode fallback, calculates signed branch offsets, and writes correct opcodes/operands to memory.

### Test 9.1: Command Activation & Address Prompt

- **Input**:
  1. `A` at the `-` prompt.
  2. `A 4000` at the `-` prompt.
  3. `A G000` at the `-` prompt.
  4. Press `[Enter]` on an empty prompt (e.g. `4000:`).
- **Procedure**:
  1. Launch `debug` and type `A` with no address, press `[Enter]`.
  2. Exit the loop, type `A 4000`, press `[Enter]`.
  3. Exit, type `A G000`, press `[Enter]`.
  4. At prompt `4000:`, press `[Enter]` without typing any characters.
- **Pass Criteria**:
  - Typing `A` starts the assembler at `currentAddr` (normally `0000:` on startup or last used memory address) with prompt.
  - Typing `A 4000` starts the assembler at `$4000` with prompt `4000:`.
  - Typing `A G000` displays `error` and returns to `-` prompt.
  - Pressing `[Enter]` on an empty prompt line exits the assembler loop and returns to the `-` prompt.

### Test 9.2: Mnemonic Parsing & Case Normalization

- **Input**: Assemble `LDA #$01` using different cases and invalid mnemonics:
  1. `lda #$01`
  2. `LDA #$01`
  3. `Lda #$01`
  4. `XYZ #$01`
- **Procedure**:
  1. Start assembler via `A 4000`.
  2. Type each input and press `[Enter]`.
- **Pass Criteria**:
  - Inputs 1, 2, and 3 parse successfully and advance the prompt to `4002:`.
  - Input 4 outputs `error` on the next line and repeats prompt `4002:` (does not advance).

### Test 9.3: Syntax Parsing for all 13 Addressing Modes

- **Input**: Type the following instructions consecutively at `A 4000`:
  1. `NOP` (Implied)
  2. `LSR` (Accumulator - empty operand fallback)
  3. `ASL A` (Accumulator)
  4. `LDA #$01` (Immediate with `$`)
  5. `LDX #10` (Immediate without `$`)
  6. `STA $10` (Zero Page with `$`)
  7. `STX 20` (Zero Page without `$`)
  8. `LDY $10,X` (Zero Page,X)
  9. `LDX $10,Y` (Zero Page,Y)
  10. `JMP ($1234)` (Indirect)
  11. `LDA ($12,X)` (Indirect,X)
  12. `LDA ($12),Y` (Indirect,Y)
  13. `STA $1234` (Absolute)
  14. `LDA $1234,X` (Absolute,X)
  15. `LDX $1234,Y` (Absolute,Y)
- **Procedure**:
  1. Enter the above instructions in order starting at `$4000`.
  2. Exit the assembler and type `U 4000` to check the disassembly output.
- **Pass Criteria**:
  - All 15 instructions compile successfully and advance the prompt.
  - The unassemble (`U`) command shows the identical mnemonics and operands matching the compiled byte sequences:
    1. `NOP` $\rightarrow$ `EA`
    2. `LSR A` $\rightarrow$ `4A`
    3. `ASL A` $\rightarrow$ `0A`
    4. `LDA #$01` $\rightarrow$ `A9 01`
    5. `LDX #$10` $\rightarrow$ `A2 10`
    6. `STA $10` $\rightarrow$ `85 10`
    7. `STX $20` $\rightarrow$ `86 20`
    8. `LDY $10,X` $\rightarrow$ `B4 10`
    9. `LDX $10,Y` $\rightarrow$ `B6 10`
    10. `JMP ($1234)` $\rightarrow$ `6C 34 12`
    11. `LDA ($12,X)` $\rightarrow$ `A1 12`
    12. `LDA ($12),Y` $\rightarrow$ `B1 12`
    13. `STA $1234` $\rightarrow$ `8D 34 12`
    14. `LDA $1234,X` $\rightarrow$ `BD 34 12`
    15. `LDX $1234,Y` $\rightarrow$ `BE 34 12`

### Test 9.4: Addressing Mode Fallback / Promotion

- **Input**: Assemble absolute targets specified with 2-digit zero-page numbers:
  1. `JMP $0020` (deduced as ZP, fallback/promoted to Absolute)
  2. `JSR $0050` (deduced as ZP, fallback/promoted to Absolute)
  3. `LDA $0010,Y` (deduced as ZP,Y, fallback/promoted to Absolute,Y)
- **Procedure**:
  1. Start assembler via `A 4000`.
  2. Enter each of the three instructions, then exit.
  3. Disassemble using `U 4000`.
- **Pass Criteria**:
  - Instructions parse successfully and compile as absolute length-3 instructions:
    1. `JMP $0020` $\rightarrow$ `4C 20 00`
    2. `JSR $0050` $\rightarrow$ `20 50 00`
    3. `LDA $0010,Y` $\rightarrow$ `B9 10 00`

### Test 9.5: Relative Branch Offset Generation & Range Checks

- **Input**: Assemble relative branch instructions:
  1. `BNE $4000` (at assembly prompt address `$4004`)
  2. `BEQ $400A` (at assembly prompt address `$4000`)
  3. `BPL $4100` (at assembly prompt address `$4000` - out of range)
  4. `BMI $4000` (at assembly prompt address `$4100` - out of range)
- **Procedure**:
  1. Start assembler at `$4004` via `A 4004`. Type `BNE $4000`, press `[Enter]`.
  2. Exit and start assembler at `$4000` via `A 4000`. Type `BEQ $400A`, press `[Enter]`.
  3. Exit, start assembler at `$4000` via `A 4000`. Type `BPL $4100`, press `[Enter]`.
  4. Exit, start assembler at `$4100` via `A 4100`. Type `BMI $4000`, press `[Enter]`.
- **Pass Criteria**:
  - `BNE $4000` at `$4004` compiles to `D0 FA` (offset is `-6` relative to `$4006`).
  - `BEQ $400A` at `$4000` compiles to `F0 08` (offset is `+8` relative to `$4002`).
  - `BPL $4100` at `$4000` outputs `error` and prompt remains at `4000:` (offset `+254` is out of signed 8-bit range).
  - `BMI $4000` at `$4100` outputs `error` and prompt remains at `4100:` (offset `-258` is out of signed 8-bit range).

### Test 9.6: Syntax Whitespace Tolerance

- **Input**:
  1. `LDA   #  $01`
  2. `STA   $D020  ,  X`
  3. `LDA   (  $12  )  ,  Y`
- **Procedure**:
  1. Start assembler via `A 4000`.
  2. Type each instruction containing multiple spaces between arguments and symbols.
  3. Exit and disassembled using `U 4000`.
- **Pass Criteria**:
  - All three instructions are successfully parsed and compiled:
    1. `LDA #$01` $\rightarrow$ `A9 01`
    2. `STA $D020,X` $\rightarrow$ `9D 20 D0`
    3. `LDA ($12),Y` $\rightarrow$ `B1 12`

---

---

## Test Suite 10: Single-Step Instruction Tracing (`T`)

> [!IMPORTANT]
> **Safety Constraint**: All manual tracing/proceed tests must use target addresses (e.g. `$4000+`) that are safe from memory collisions with the resident `debug` program itself (located at `$2000-$376B`), unless they are explicitly intended to test boundary conditions or destructive behavior.

### Test 10.1: Default Trace (Current PC)

- **Input**: `T`
- **Procedure**:
  1. Assemble at `$4000` via `A 4000`:

     ```asm
     4000: LDA #$05
     4002: INX
     ```

  2. Set `PC` to `$4000` and `X` to `$00` (`R PC` -> `4000`, `R X` -> `00`).
  3. Execute `T`.
- **Pass Criteria**:
  - The CPU executes `LDA #$05`.
  - The printed register line displays: `A=05 X=00 Y=00 P=xx S=xx PC=4002` (validating virtual registers and PC update).
  - The next instruction is disassembled: `4002: INX`.
  - Returns control to the `-` prompt.

### Test 10.2: Relocated Trace (Address Argument)

- **Input**: `T 4002`
- **Procedure**:
  1. Verify the setup from Test 10.1 is still active.
  2. Execute `T 4002`.
- **Pass Criteria**:
  - The CPU executes the `INX` instruction at `$4002`.
  - Registers printed show: `A=05 X=01 Y=00 P=xx S=xx PC=4003` (verifying `X` is incremented and `PC` is advanced).

### Test 10.3: Conditional Branching (Taken & Not Taken Paths)

- **Input**: `T`
- **Procedure**:
  1. Assemble a branch sequence at `$4000`:

     ```asm
     4000: CPX #$01
     4002: BEQ $4006
     4004: NOP
     4005: RTS
     4006: SEC
     4007: RTS
     ```

  2. Test Case A (Branch Taken): Set `PC` to `$4000`, `X` to `$01`.
     - Execute `T` (executes `CPX #$01`).
     - Execute `T` (reaches `BEQ $4006` with Zero flag set).
     - Execute `T`.
     - **Pass Criteria**: `PC` lands at `$4006` (`SEC`). Breakpoints were successfully handled on both relative branch paths, and the taken path was followed.
  3. Test Case B (Branch Not Taken): Set `PC` to `$4000`, `X` to `$00`.
     - Execute `T` (executes `CPX #$01`).
     - Execute `T` (reaches `BEQ $4006` with Zero flag clear).
     - Execute `T`.
     - **Pass Criteria**: `PC` lands at `$4004` (`NOP`). The not-taken path was followed.

---

## Test Suite 11: Proceed Step-Over (`P`)

### Test 11.1: Proceed Over Subroutine Call (`JSR`)

- **Input**: `P`
- **Procedure**:
  1. Assemble at `$4000`:

     ```asm
     4000: JSR $4500
     4003: NOP
     ```

  2. Assemble a subroutine at `$4500`:

     ```asm
     4500: LDY #$aa
     4502: RTS
     ```

  3. Set `PC` to `$4000`, `Y` to `$00`.
  4. Execute `P` on the JSR instruction.
- **Pass Criteria**:
  - The debugger steps over the subroutine call.
  - Registers print shows: `A=xx X=xx Y=AA P=xx S=xx PC=4003`.
  - Next instruction disassembled: `4003: NOP`.
  - This confirms that the subroutine ran to completion, modified `Y`, and execution safely broke on return.

### Test 11.2: Proceed Over Branch Loop

- **Input**: `P`
- **Procedure**:
  1. Assemble at `$4000`:

     ```asm
     4000: LDX #$02
     4002: DEX
     4003: BNE $4002
     4005: NOP
     ```

  2. Set `PC` to `$4000`.
  3. Execute `T` (executes `LDX #$02`).
  4. Execute `T` (executes `DEX`, `X` becomes `01`).
  5. Execute `P` on the `BNE $4002` loop branch.
- **Pass Criteria**:
  - The program executes the remaining loop iterations without stopping on each one.
  - Breaks cleanly on the `NOP` at `$4005` with register state `X=00`.

---

## Test Suite 12: ROM Safety Protection & Guards

### Test 12.1: JSR to ROM Target (Step-Over Fallback)

- **Input**: `T`
- **Procedure**:
  1. Assemble a JSR to KERNAL `CHROUT` at `$4000`:

     ```asm
     4000: JSR $FFD2
     4003: RTS
     ```

  2. Set `PC` to `$4000`, `A` to `$41` (character 'A').
  3. Execute `T` on the JSR.
- **Pass Criteria**:
  - The character `'A'` is printed to the screen.
  - The tracer detects that the target `$FFD2` is inside ROM ($\ge \$D000$) and automatically steps over it.
  - Breaks cleanly at `$4003` (`RTS`) without crashing.

### Test 12.2: JMP to ROM Target (Execution Guard)

- **Input**: `T`
- **Procedure**:
  1. Assemble `JMP $FFD2` at `$4000`.
  2. Set `PC` to `$4000`.
  3. Execute `T`.
- **Pass Criteria**:
  - The trace is safely blocked.
  - The debugger prints: `error: cannot trace target in ROM`
  - Returns immediately to the `-` command prompt.

---

## Test Suite 13: Exit Banking Restoration

### Test 13.1: BASIC ROM Restore on Quit

- **Input**: `Q` followed by `EXIT`
- **Procedure**:
  1. Start `DEBUG`.
  2. Verify BASIC ROM is banked out (e.g., run `D A000` to dump, write bytes using `E A000`, and confirm memory is writable RAM).
  3. Type `Q` to quit `DEBUG` and return to the `command64` shell.
  4. Type `EXIT` in the shell prompt.
- **Pass Criteria**:
  - The system returns to the Commodore BASIC prompt:

    ```petscii
    READY.
    ```

  - The warm start displays cleanly, and typing BASIC commands (like `PRINT 1+1`) works and prints outputs (confirming the BASIC ROM mapping was fully restored before jumping to KERNAL warm start).
