# Test Plan: DEBUG Phase 1 File I/O (`N`, `L`, `W`)

This document outlines the detailed manual test plan for verifying the `N` (Name), `L` (Load), and `W` (Write) commands of the `DEBUG` utility.

---

## Test Suite 1: Filename Management (`N`)

### Test 1.1: Setting a Valid Filename
* **Input**: `N TEST1.PRG`
* **Procedure**:
  1. Launch the `debug` utility from the command64 shell.
  2. Type `N TEST1.PRG` and press `[Enter]`.
  3. Type `N` and press `[Enter]` to read back the active name.
* **Pass Criteria**: The screen displays `TEST1.PRG`.

### Test 1.2: Case Insensitivity of Command
* **Input**: `n test2.prg`
* **Procedure**:
  1. Type `n test2.prg` (lowercase `n` and lowercase filename) and press `[Enter]`.
  2. Type `N` and press `[Enter]`.
* **Pass Criteria**: The screen displays `test2.prg`.

### Test 1.3: Trailing Space and Parameter Isolation
* **Input**: `N TEST3.PRG   ` (trailing spaces)
* **Procedure**:
  1. Type `N TEST3.PRG   ` and press `[Enter]`.
  2. Type `N` and press `[Enter]`.
* **Pass Criteria**: The screen displays `TEST3.PRG` (trailing spaces are trimmed/ignored).

* **Input**: `N TEST4.PRG 2000` (trailing parameters)
* **Procedure**:
  1. Type `N TEST4.PRG 2000` and press `[Enter]`.
  2. Type `N` and press `[Enter]`.
* **Pass Criteria**: The screen displays `TEST4.PRG` (the trailing parameter `2000` is isolated and ignored).

### Test 1.4: Filename Length Enforcement & Corruption Prevention
* **Input**: `N 123456789012345678901234567890123.prg` (33 characters)
* **Procedure**:
  1. Set filename to a valid 9-char name first: `N TEST4.PRG`.
  2. Type the 33-character name command and press `[Enter]`.
  3. Type `N` and press `[Enter]` to read back the active name.
* **Pass Criteria**: 
  - The utility prints `error` upon the long input.
  - The second readback displays `TEST4.PRG` intact, proving that too-long filenames are rejected before modifying the active buffer.

---

## Test Suite 2: File Writing (`W`)

### Test 2.1: Write with Empty Filename
* **Procedure**:
  1. Start a fresh `debug` session.
  2. Type `W 2000 2010` and press `[Enter]`.
* **Pass Criteria**: The utility prints `error` immediately.

### Test 2.2: Save as Standard Program (`PRG` - Default)
* **Input**: `N TMP.PRG` followed by `W 2000 200F`
* **Procedure**:
  1. Set the name to `TMP.PRG`.
  2. Fill a test pattern in memory: `F 2000 200F AA` (fills `$2000`–`$200F` with `$AA`).
  3. Type `W 2000 200F` and press `[Enter]`.
* **Pass Criteria**: 
  - The drive active light flashes and control returns cleanly.
  - Quit debug (`Q`), run `dir` $\rightarrow$ verify `TMP.PRG` exists on the disk.
  - *Note*: `type TMP.PRG` in the shell will print the 2-byte starting address header first (often displaying as graphics/control codes) followed by the data.

### Test 2.3: Save as Alternative Formats (`SEQ` and `USR`)
* **Input**: `W S 2000 200F` (Sequential) and `W U 2000 200F` (User)
* **Procedure**:
  1. Set the name to `TMP.SEQ`. Type `W S 2000 200F` (using either shifted or unshifted `S`) and press `[Enter]`.
  2. Set the name to `TMP.USR`. Type `W U 2000 200F` (using either shifted or unshifted `U`) and press `[Enter]`.
* **Pass Criteria**: Both writes return cleanly. Verify their existence on disk via `dir`. Typing `type TMP.SEQ` should show raw characters with no address header.

### Test 2.4: Range Bounds Enforcement
* **Input**: `W 2010 2000`
* **Procedure**:
  1. Type `W 2010 2000` (start address greater than end address) and press `[Enter]`.
* **Pass Criteria**: The utility prints `error` immediately instead of writing indefinitely.

---

## Test Suite 3: File Loading (`L`)

### Test 3.1: Load with Empty Filename
* **Procedure**:
  1. Start a fresh `debug` session.
  2. Type `L` or `L 2000` and press `[Enter]`.
* **Pass Criteria**: Prints `error` immediately.

### Test 3.2: Malformed Address Syntax Checks
* **Input**: `L G000` or `L 200G`
* **Procedure**:
  1. Set the name to `TMP.PRG`.
  2. Type `L G000` and press `[Enter]`.
* **Pass Criteria**: Prints `error` immediately (ignores single-address fallback).

### Test 3.3: Relocated Loading & Address Tracking (`PRG`)
* **Input**: `L 4000`
* **Procedure**:
  1. Set the name to `TMP.PRG` (the file written in Test 2.2).
  2. Clear target memory: `F 4000 400F 00`.
  3. Type `L 4000` and press `[Enter]`.
  4. Type `D` (with no arguments) and press `[Enter]`.
* **Pass Criteria**:
  - The load returns cleanly.
  - The memory dump defaults to starting at `$4000` and shows the loaded `$AA` bytes, proving `currentAddr` was updated.

### Test 3.4: Absolute Header Loading & Address Tracking (`PRG`)
* **Input**: `L`
* **Procedure**:
  1. Set the name to `TMP.PRG`.
  2. Clear target memory: `F 2000 200F 00`.
  3. Type `L` (no address argument) and press `[Enter]`.
  4. Type `D` (with no arguments) and press `[Enter]`.
* **Pass Criteria**:
  - The file loads back to its header start address (`$2000`).
  - The memory dump defaults to starting at `$2000` and shows the loaded `$AA` bytes, proving `currentAddr` was successfully read from KERNAL `$C1/$C2`.
  - *Troubleshooting Note*: If emulator fastloaders (like Virtual FS / True Drive Emulation settings) are active, KERNAL `$C1/$C2` (`MEMUSS`) may not be updated correctly and default to `$A000`. If this occurs, dump the memory at the file's original address manually (`D 2000`) to confirm the load succeeded.

### Test 3.5: Relocated Loading (`SEQ` and `USR`)
* **Input**: `L S 4000` with `TMP.SEQ` (or `TMP.USR`)
* **Procedure**:
  1. Set the name to `TMP.SEQ` (the file written in Test 2.3).
  2. Clear target memory: `F 4000 400F 00`.
  3. Type `L S 4000` and press `[Enter]`.
  4. Type `D` (with no arguments) and press `[Enter]`.
* **Pass Criteria**:
  - The custom byte loader runs and control returns cleanly.
  - Dumping memory at `$4000` shows the `$AA` bytes (proves custom read loop loaded the raw bytes).

### Test 3.6: Default Address Loading (`SEQ` and `USR`)
* **Input**: `L S` with `TMP.SEQ`
* **Procedure**:
  1. Set the name to `TMP.SEQ`.
  2. Clear target memory: `F 4000 400F 00`.
  3. Set `currentAddr` by running `D 4000`.
  4. Type `L S` (no address argument) and press `[Enter]`.
  5. Type `D` and press `[Enter]`.
* **Pass Criteria**:
  - The file loads successfully.
  - The dump starting at `currentAddr` (`$4000`) displays the loaded `$AA` bytes.

---

## Test Suite 4: End-to-End Session Integration

This test verifies the entire file read/write pipeline in a single session.

1. Launch `debug`.
2. Type `n testdata.bin` and press `[Enter]`.
3. Fill memory: `f 4000 40ff 55` (places pattern `$55` at `$4000`–`$40FF`).
4. Write range: `w 4000 40ff`
5. Clear memory: `f 4000 40ff 00`
6. Verify memory is empty: `d 4000 l 10` (should show all `$00` bytes).
7. Load file back: `l` (relies on header `$4000` saved in the file).
8. Verify memory is restored: `d` (should default dump starting at `$4000` and show the `$55` pattern).
