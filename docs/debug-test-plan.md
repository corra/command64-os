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

4. Verify the startup message displays (e.g., `DEBUG v0.5.0.1128`) followed by the prompt:

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

> [!IMPORTANT]
> **Safety Constraint**: Current relocatable DEBUG builds load at `$3800` and
> build 1124 occupies through approximately `$5761`. DEBUG's linker envelope
> (`MAIN`) was expanded from `$2000` to `$2400` bytes for WP6, giving a ceiling
> of `$5C00` with a 1024-byte margin below the `$6000+` test-fixture
> convention. Use `$6000+` for every writable fixture. Legacy examples below
> that use a `$4000` or `$5000` base must be translated to `$6000` while
> preserving relative offsets; translate `$4500` or `$5500` to `$6500`. Never
> write inside `$3800-$5C00`.

### Test 3.1: Memory Dump (`D`)

- **Procedures & Inputs**:
  - `D` (No args): Displays 128 bytes (16 rows of 8 bytes) starting from the last set `currentAddr`.
  - `D 5000`: Sets `currentAddr` to `$5000` and displays 128 bytes.
  - `D 5000 501F` (Range): Displays memory from `$5000` to `$501F` inclusive.
  - `D 5000 L 10` (Length): Displays exactly 16 bytes starting at `$5000`.
  - `D` (Continuous): Pressing `D` sequentially advances `currentAddr` by 128 bytes each time.

- **Pass Criteria**:
  - Dump layout matches C64 screen: `ADDR: XX XX XX XX XX XX XX XX  ASCII`
  - Start addresses greater than end addresses (e.g. `D 5010 5000`) print `error`.

### Test 3.2: Memory Enter (`E`)

- **Input**: `E 5500 11 22 33 "C64" 44`

- **Procedure**:
  1. Enter the list command.
  2. Verify with `D 5500 L 08`.
- **Pass Criteria**:
  - Dump shows bytes at `$5500` as: `11 22 33 43 36 34 44` (ASCII `"C"`, `"6"`, `"4"` mapped to hex `$43`, `$36`, `$34`).
  - `currentAddr` is updated to the byte after the last entered item (`$5507`).

### Test 3.3: Memory Fill (`F`)

- **Input**: `F 5000 500F AA BB`

- **Procedure**:
  1. Fill the range with the alternating pattern.
  2. Dump range using `D 5000 500F`.
- **Pass Criteria**: Memory contains alternating `AA BB AA BB...`.

### Test 3.4: Memory Move (`M`)

- **Procedures & Inputs**:
  - **Forward Copy (No Overlap)**: `M 5000 5007 5100` (copies `$5000-$5007` to `$5100`).
  - **Backward Copy (Overlap, Dest > Src)**: Fill `$5000-$5007` with `01 02 03 04 05 06 07 08`. Move with `M 5000 5006 5001`.

- **Pass Criteria**:
  - Dump `$5100` shows identical bytes to `$5000`.
  - Overlap move results in memory `$5000-$5007` containing `01 01 02 03 04 05 06 07` (verifies overlap protection prevents source bytes from being corrupted before read).

### Test 3.5: Memory Compare (`C`)

- **Input**:
  - Identical blocks: `C 5000 5007 5100` (when blocks match).
  - Non-identical: Modify `$5102` to `EE` and compare again.

- **Pass Criteria**:
  - Matching blocks return no output.
  - Non-matching blocks output: `5002 XX EE 5102` (displays address 1, value 1, value 2, address 2).

### Test 3.6: Memory Search (`S`)

- **Input**:
  - `S 5000 5100 "C64"`
  - `S 5000 5100 AA BB`

- **Pass Criteria**: Displays the starting hex address(es) of all matching sequences in range. If no matches exist, returns directly to the prompt.

---

## Test Suite 4: Register Display & Editing (`R`)

### Test 4.1: Display Captured Register Context

- **Input**: `R`

- **Procedure**: Execute `R` on the prompt.
- **Pass Criteria**: Displays the current captured CPU register state on two lines:

  ```hex
  A=xx X=xx Y=xx P=xx S=xx PC=xxxx
  P=xx: N=x V=x * B=x D=x I=x Z=x C=x
  ```

  (where `xx`/`xxxx` represents hex numbers, and `x` represents flag bit values `0` or `1`).

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

### Test 4.4: Display and Edit Register P (Whole Byte)

- **Input & Procedure**:
  1. Type `R P` and press `[Enter]`. Verify it displays the current value of P, e.g. `P 30` followed by the status flags line `P=30: N=0 V=0 * B=1 D=0 I=0 Z=0 C=0`, and prompts with `:`.
  2. Input `81` and press `[Enter]`.
  3. Type `R` to display all registers.
- **Pass Criteria**:
  - The second line under all registers displays `P=81: N=1 V=0 * B=0 D=0 I=0 Z=0 C=1`.
  - Pressing `[Enter]` on `:` without typing a value leaves P unmodified.

### Test 4.5: Edit Register P via Flag Assignments

- **Input & Procedure**:
  1. Type `R P` and press `[Enter]`.
  2. Input `N=1 V=1 Z=0 C=0` and press `[Enter]`.
  3. Type `R` to display all registers.
- **Pass Criteria**:
  - Register P flags are correctly updated: N=1, V=1, Z=0, C=0.
  - The output displays `P=E0: N=1 V=1 * B=0 D=0 I=0 Z=0 C=0`.
  - Inputs with spaces around `=` (e.g. `n = 0`) are successfully parsed.
  - Inputs with invalid flags (e.g. `X=1` or `*=1`) or invalid values (e.g. `N=2`) return `error`.


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
  2. Type `W 5000 5010` and press `[Enter]`.

- **Pass Criteria**: The utility prints `error` immediately.

#### Test 7.2.2: Save as Standard Program (`PRG` - Default)

- **Input**: `N TMP.PRG` followed by `W 5000 500F`

- **Procedure**:
  1. Set the name to `TMP.PRG`.
  2. Fill a test pattern in memory: `F 5000 500F AA` (fills `$5000`–`$500F` with `$AA`).
  3. Type `W 5000 500F` and press `[Enter]`.
- **Pass Criteria**:
  - The drive active light flashes and control returns cleanly.
  - Quit debug (`Q`), run `dir` $\rightarrow$ verify `TMP.PRG` exists on the disk.
  - *Note*: `type TMP.PRG` in the shell will print the 2-byte starting address header first (often displaying as graphics/control codes) followed by the data.

#### Test 7.2.3: Save as Alternative Formats (`SEQ` and `USR`)

- **Input**: `W S 5000 500F` (Sequential) and `W U 5000 500F` (User)

- **Procedure**:
  1. Set the name to `TMP.SEQ`. Type `W S 5000 500F` (using either shifted or unshifted `S`) and press `[Enter]`.
  2. Set the name to `TMP.USR`. Type `W U 5000 500F` (using either shifted or unshifted `U`) and press `[Enter]`.
- **Pass Criteria**: Both writes return cleanly. Verify their existence on disk via `dir`. Typing `type TMP.SEQ` should show raw characters with no address header.

#### Test 7.2.4: Range Bounds Enforcement

- **Input**: `W 5010 5000`

- **Procedure**:
  1. Type `W 5010 5000` (start address greater than end address) and press `[Enter]`.
- **Pass Criteria**: The utility prints `error` immediately instead of writing indefinitely.

---

### Test 7.3: File Loading (`L`)

#### Test 7.3.1: Load with Empty Filename

> [!IMPORTANT]
> **Safety Constraint**: Apply Suite 3's address-translation rule. Files saved
> from a legacy `$5000` header example must instead use `$6000`; relocated-load
> cases must use `$7000+` so source and destination remain distinct and both
> stay clear of resident DEBUG through approximately `$51C2`.

- **Procedure**:
  1. Start a fresh `debug` session.
  2. Type `L` or `L 5000` and press `[Enter]`.

- **Pass Criteria**: Prints `error` immediately.

#### Test 7.3.2: Malformed Address Syntax Checks

- **Input**: `L G000` or `L 500G`

- **Procedure**:
  1. Set the name to `TMP.PRG`.
  2. Type `L G000` and press `[Enter]`.
- **Pass Criteria**: Prints `error` immediately (ignores single-address fallback).

#### Test 7.3.3: Relocated Loading & Address Tracking (`PRG`)

- **Input**: `L 6000`

- **Procedure**:
  1. Set the name to `TMP.PRG` (the file written in Test 7.2.2).
  2. Clear target memory: `F 6000 600F 00`.
  3. Type `L 6000` and press `[Enter]`.
  4. Type `D` (with no arguments) and press `[Enter]`.
- **Pass Criteria**:
  - The load returns cleanly.
  - The memory dump defaults to starting at `$6000` and shows the loaded `$AA` bytes, proving `currentAddr` was updated.

#### Test 7.3.4: Absolute Header Loading & Address Tracking (`PRG`)

- **Input**: `L`

- **Procedure**:
  1. Set the name to `TMP.PRG`.
  2. Clear target memory: `F 5000 500F 00`.
  3. Type `L` (no address argument) and press `[Enter]`.
  4. Type `D` (with no arguments) and press `[Enter]`.
- **Pass Criteria**:
  - The file loads back to its header start address (`$5000`).
  - The memory dump defaults to starting at `$5000` and shows the loaded `$AA` bytes, proving `currentAddr` was successfully read from KERNAL `$C1/$C2`.
  - *Troubleshooting Note*: If emulator fastloaders (like Virtual FS / True Drive Emulation settings) are active, KERNAL `$C1/$C2` (`MEMUSS`) may not be updated correctly and default to `$A000`. If this occurs, dump the memory at the file's original address manually (`D 5000`) to confirm the load succeeded.

#### Test 7.3.5: Relocated Loading (`SEQ` and `USR`)

- **Input**: `L S 6000` with `TMP.SEQ` (or `TMP.USR`)

- **Procedure**:
  1. Set the name to `TMP.SEQ` (the file written in Test 7.2.3).
  2. Clear target memory: `F 6000 600F 00`.
  3. Type `L S 6000` and press `[Enter]`.
  4. Type `D` (with no arguments) and press `[Enter]`.
- **Pass Criteria**:
  - The custom byte loader runs and control returns cleanly.
  - Dumping memory at `$6000` shows the `$AA` bytes (proves custom read loop loaded the raw bytes).

#### Test 7.3.6: Default Address Loading (`SEQ` and `USR`)

- **Input**: `L S` with `TMP.SEQ`

- **Procedure**:
  1. Set the name to `TMP.SEQ`.
  2. Clear target memory: `F 6000 600F 00`.
  3. Set `currentAddr` by running `D 6000`.
  4. Type `L S` (no address argument) and press `[Enter]`.
  5. Type `D` and press `[Enter]`.
- **Pass Criteria**:
  - The file loads successfully.
  - The dump starting at `currentAddr` (`$6000`) displays the loaded `$AA` bytes.

---

### Test 7.4: End-to-End Session Integration

- **Procedure**:
  1. Launch `debug`.
  2. Type `n testdata.bin` and press `[Enter]`.
  3. Fill memory: `f 6000 60ff 55` (places pattern `$55` at `$6000`–`$60FF`).
  4. Write range: `w 6000 60ff`
  5. Clear memory: `f 6000 60ff 00`
  6. Verify memory is empty: `d 6000 l 10` (should show all `$00` bytes).
  7. Load file back: `l` (relies on header `$6000` saved in the file).
  8. Verify memory is restored: `d` (should default dump starting at `$6000` and show the `$55` pattern).

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
> **Safety Constraint**: Apply Suite 3's address-translation rule to all
> assembler, trace, and proceed examples: use `$6000` instead of `$4000` and
> `$6500` instead of `$4500`. Current DEBUG occupies approximately
> `$3800-$51C2`; tracing or assembling there corrupts the debugger.

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

---

## Test Suite 14: Permissive Execution Address Syntax (`G`, `T`, `P`)

### Test 14.1: Equivalent Bare and `=` Forms

- **Input**: `G 4000`, `G=4000`, `G =4000`, `G= 4000`, `G = 4000`
- **Procedure**:
  1. Assemble `RTS` at `$4000`.
  2. Execute each of the five forms above in turn, confirming a clean return
     to the `-` prompt after each (a bare `RTS` target is safe to `G` to
     directly).
  3. Repeat the same five address forms for `T` and `P`, using `R` after
     each to confirm `regPC` was set to `$4000` before the trace/proceed
     executed.
- **Pass Criteria**:
  - All five forms of each command reach identical target state (`$4000`).
  - Whitespace around `=` (`G=4000`, `G =4000`, `G= 4000`, `G = 4000`) does
    not change the result.

### Test 14.2: No-Argument Behavior Unchanged

- **Input**: `G`, `T`, `P` (no address)
- **Procedure**:
  1. Set `currentAddr` via a prior `D`/`G` and `regPC` via a prior `T`/`P`.
  2. Execute bare `G`, `T`, `P` and confirm each still targets the
     pre-existing state exactly as Test Suites 5, 10, and 11 already
     establish.
- **Pass Criteria**: no-argument behavior is identical to pre-WP1 DEBUG; `=`
  syntax is never required.

### Test 14.3: Negative Grammar

- **Input**: `G =`, `G ==`, `G =G000`, `G =10000`, `G =4000 EXTRA`,
  `T =4000 02`, `P =4000 02`, `G =0001:0000`
- **Procedure**: Execute each form in turn, recording `regPC`/`currentAddr`
  before and after.
- **Pass Criteria**:
  - Every form prints `error`.
  - No form executes, traces, proceeds, or changes `regPC`/`currentAddr`
    from its pre-command value.

---

## Test Suite 15: REU Command Family (`XA`, `XD`, `XM`, `XS`)

> [!IMPORTANT]
> Requires REU emulation enabled (`-reu -reusize 512` or the equivalent
> persisted VICE setting) except Test 15.5, which requires it disabled.

### Test 15.1: Allocation Lifecycle

- **Input**: `XA 0001`, `XA 0100`, `XA 1000`, `XA 0000`, `XA 1001`, `XD`, `Q`
- **Procedure**:
  1. `XA 0001` (minimum, 16 bytes), `XA 0100` (4KB), `XA 1000` (64KB
     boundary) — verify each prints `<handle>: SEG=xx BANK=xx PARA=xxxx
     PAGES=xx SIZE=xxxx` with `SIZE=0010`, `SIZE=1000`, `SIZE=10000`
     respectively.
  2. `XA 0000` and `XA 1001` — verify both are rejected with `ERROR`.
  3. From an empty registry, issue four successive valid `XA`s to fill all
     four handles, then a fifth — verify the fifth is rejected even though
     REU pages remain free (registry-full, not out-of-memory).
  4. `XD` on a valid handle — verify it is silent on success; repeat `XD` on
     the same handle — verify it is rejected.
  5. Allocate at least one handle, then `Q` — verify DEBUG returns cleanly
     to the `command64` shell with no `ERROR`.
- **Pass Criteria**: capacities and rejections match exactly; the registry
  enforces a four-handle ceiling independent of OS free-page count; `Q`
  releases every active allocation before exiting.

### Test 15.2: Status Reporting

- **Input**: `XS`, `XS handle`
- **Procedure**:
  1. Bare `XS` with an empty registry — verify `NONE`.
  2. Allocate one or more handles; bare `XS` — verify `VMM ACTIVE`,
     `PAGES TOTAL=`/`ALLOC=`/`FREE=`, and one row per active allocation.
  3. `XS handle` for a valid handle — verify one matching row; for an
     invalid, out-of-range, or inactive handle — verify `ERROR` with no OS
     call side effect.
- **Pass Criteria**: reported fields match the registry exactly; invalid
  handles are rejected before any OS call.

### Test 15.3: Page-Offset Parsing

- **Input**: equivalence pairs `0000`/`0000:0000`, `0FFF`/`0000:0FFF`,
  `1000`/`0001:0000`, `1020`/`0001:0020`, `FFFF`/`000F:0FFF`; malformed
  forms `:`, `0001:`, `:0020`, `0001::0020`, `0001:1000`, `0010:0000`,
  `000G:0000`, `0001:000G`, `0001:0020X`
- **Procedure**: Against a 64KB allocation (`XA 1000`), issue each
  equivalence pair as the offset operand of an otherwise-identical `XM`
  command and confirm both forms of a pair select the same REU location
  (verify via a small `R`/`W` round-trip); issue each malformed form and
  confirm rejection.
- **Pass Criteria**: every equivalence pair addresses identical REU bytes;
  every malformed form prints `ERROR` before any OS call.

### Test 15.4: Transfer Round-Trips and Boundaries

- **Input**: see `wiki/debug-utility.md`'s round-trip and boundary examples
  (Section "Complete Session", "Boundary Examples")
- **Procedure**:
  1. Single-byte transfer at offset `$0000` and at the final valid byte of a
     4KB allocation (`$0FFF`); verify both round-trip byte-exact via `D`/`C`.
  2. A transfer ending exactly at allocation capacity; a transfer one byte
     beyond capacity (verify rejection, no DMA).
  3. A transfer crossing a 256-byte chunk boundary (multi-chunk, e.g. 768
     bytes) and one crossing a 4KB page boundary (`0000:0FFF` to
     `0001:0000`); verify byte-exact via direct memory comparison, not just
     absence of `ERROR`.
  4. Flat and page-relative operands addressing the same location (e.g.
     `1000` and `0001:0000`); verify identical data.
  5. Zero length, invalid direction, missing operands, trailing garbage, and
     a C64-side address wrap (`address + length > $10000` without landing
     exactly on it); verify all rejected before any DMA.
- **Pass Criteria**: every successful transfer prints the exact `XM
  XFER=xxxx OK` byte count and is independently verified byte-exact; every
  rejected case produces `ERROR` with no data movement.

### Test 15.5: REU-Disabled Environment

- **Input**: `XS`, `XA 0100`, `XM 0 0000 6000 0010 R`, `XD 0`, `G`, `Q`
- **Procedure**:
  1. Boot Command64 with REU emulation disabled.
  2. `XS` — verify `VMM INACTIVE` with zero counters and `NONE`.
  3. `XA 0100` — verify a clean `ERROR`, VMM-unavailable selector, no
     registry mutation.
  4. `XM 0 0000 6000 0010 R` (no active handle possible) — verify `ERROR`.
  5. `XD 0` — verify `ERROR` (no active handle) without an OS call.
  6. Confirm ordinary commands (`G`, `D`, `E`, etc.) still function normally.
  7. `Q` — verify a clean exit with nothing to clean up.
- **Pass Criteria**: every REU command fails cleanly and immediately; no
  crash, hang, or corruption; non-REU DEBUG functionality is unaffected.
