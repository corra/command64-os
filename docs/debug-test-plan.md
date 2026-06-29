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

## Test Suite 9 (Future): Interactive Inline 6502 Assembler (`A`)

*(Note: The `A` command is planned for implementation in Phase 2)*

### Test 9.1: Command Activation & Address Prompt

- **Proposed Input**: `A 2000` or `A`

- **Expected Flow**: Starts an assembler loop, prompting the user with `2000:` or the active address. An empty line exits back to the `-` prompt.

### Test 9.2: Mnemonic Parsing & Addressing Modes

- **Proposed Inputs**:
  - `LDA #10` (Immediate)
  - `STA $70` (Zero Page)
  - `LDA ($70),Y` (Indirect Indexed)
  - `JMP $C000` (Absolute)

- **Expected Flow**: Instruction is parsed, matched, translated to hex opcodes/operands, and written to memory. The prompt address increments by the byte size of the instruction.

### Test 9.3: Relative Branch Offset Generation

- **Proposed Inputs**: `BNE $2000` (when assembling at `$2005`)

- **Expected Flow**: Calculates offset (`$F9` or `-7` relative) and writes relative instruction `D0 F9`. Out-of-range offsets (>+127 or <-128 bytes) output `error`.

---

## Test Suite 10 (Future): Breakpoint Tracing (`T`, `P`)

- **Note**: *Tracing is planned for implementation in Phase 3*

### Test 10.1: Single-Step Tracing (`T`)

- **Proposed Input**: `T` or `T 2000`

- **Expected Flow**: Hijacks instruction execution at target address. Replaces the next instruction with a software breakpoint (`BRK`). Restores CPU registers, executes the single instruction, catches the break, restores original code, prints updated registers and next disassembled instruction, and returns to the `-` prompt.

### Test 10.2: Step-Over Proceed Tracing (`P`)

- **Proposed Input**: `P`

- **Expected Flow**: Similar to `T`, but if the next instruction is a subroutine call (`JSR`), it places the breakpoint at the instruction *after* the `JSR` and executes without stopping, step-over proceeding the subroutine and breaking only on return.
