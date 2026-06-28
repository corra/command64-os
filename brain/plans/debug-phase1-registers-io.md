---
feature: debug-phase1-registers-io
created: 2026-06-27
status: planned
---

# Plan: DEBUG Phase 1 - Interactive Registers and File I/O (`R`, `N`, `L`, `W`)

## Goal & Rationale
Implement interactive CPU register modification and standard disk load/save capabilities for the `DEBUG` utility, enabling parity with MS-DOS `DEBUG`'s register manipulation and file session management.

## Scope
- Extend `R` command: support `R [register]` to view and modify a specific register.
- Implement `N [filename]` command: name a file and save it in a 32-byte name buffer.
- Implement `L [address]` command: load the named file into memory.
- Implement `W [range]` command: save a range of memory to the named file.

## Files to Create/Modify
| File | Action | Notes |
|------|--------|-------|
| [src/external/debug/debug.asm](file:///home/morgan/development/c64/command64-os/src/external/debug/debug.asm) | Modify | Implement register selection/input, name storage, and Kernal LOAD/SAVE bindings. |
| [CHANGELOG.md](file:///home/morgan/development/c64/command64-os/CHANGELOG.md) | Modify | Document Phase 1 completion. |

## Detailed Design & Key Decisions

### 1. Interactive Register Modification (`R [register-name]`)
* **Interactive Prompt Loop**:
  * Parse optional register name argument: check character at `inputBuf, y` after skipping spaces.
  * Supported names: `A`, `X`, `Y`, `P`, `S` (case-insensitive).
  * If a valid register is selected:
    1. Print the register name and current value: e.g. `A xx` (using `printHex8`).
    2. Print a colon `:` prompt and wait for keyboard input using `readLine` or a custom 2-byte reader.
    3. If the user presses CR with no input, leave value unmodified.
    4. If the user enters a valid 2-digit hex byte, parse it (reusing `parseHexArg`) and update the respective storage variable: `regA`, `regX`, `regY`, `regP`, or `regS`.
    5. If input is invalid, print `error`.
  * If no register name is specified, print the entire register block as currently implemented.

### 2. Filename Storage (`N [filename]`)
* **State Variables**:
  ```asm
  fileNameLen: .byte 0
  fileNameBuf: .fill 32, 0
  ```
* **Command `N`**:
  * Skip spaces and locate filename string in `inputBuf`.
  * Check that filename length does not exceed 32 characters. If it does, print `error`.
  * Copy characters into `fileNameBuf` and store length in `fileNameLen`.

### 3. File Loading (`L [address]`)
* **System Integration**:
  * Check `fileNameLen`. If zero, print `error`.
  * Parse optional `address` argument (reusing `parseHexArg`).
  * Set up Kernal `SETNAM` ($FFBD):
    ```asm
    lda fileNameLen
    ldx #<fileNameBuf
    ldy #>fileNameBuf
    jsr KernalSETNAM
    ```
  * Set up Kernal `SETLFS` ($FFBA):
    ```asm
    lda #1          // Logical file number
    ldx CurrentDevice // Default C64 device (usually 8)
    ldy #0          // Secondary address (0 = load to specified address, 1 = header address)
    ```
    * If an address was specified, set secondary address `Y = 0` (or `Y = 2` depending on drive protocol, but `Y = 0` allows overriding start address).
    * If no address was specified, set secondary address `Y = 1` (load to address header).
    ```asm
    jsr KernalSETLFS
    ```
  * Execute Kernal `LOAD` ($FFD5):
    * If address override is specified:
      ```asm
      lda #0          // 0 = load, 1 = verify
      ldx HexValLo    // Load address low
      ldy HexValHi    // Load address high
      jsr KernalLOAD
      ```
    * If no address override:
      ```asm
      lda #0
      jsr KernalLOAD
      ```
  * Check carry flag (C=1 indicates load error). If error, print `error`.

### 4. File Writing (`W [range]`)
* **System Integration**:
  * Check `fileNameLen`. If zero, print `error`.
  * Parse memory range using `parseRange` (supporting standard `start end` or `start L length`).
  * Set up Kernal `SETNAM` ($FFBD) with `fileNameBuf`.
  * Set up Kernal `SETLFS` ($FFBA) with logical file 1, device `CurrentDevice`, secondary address 15 (command/write).
  * Save memory range using Kernal `SAVE` ($FFD8):
    ```asm
    // SAVE expects:
    // A = pointer to Zero Page address containing start address of save block
    // X = end address low
    // Y = end address high
    // The start address must be stored in a zero page pointer, e.g. rangeStart ($72)
    lda #rangeStart
    ldx rangeEnd
    ldy rangeEnd + 1
    jsr KernalSAVE
    ```
  * Check carry flag for error status.

---

## Detailed Implementation Checklist
- [ ] Implement `R` command argument parser matching `A`, `X`, `Y`, `P`, `S`.
- [ ] Implement register prompt `:` reading and updating internal register variables.
- [ ] Create `fileNameLen` and `fileNameBuf` variables.
- [ ] Implement `N` command copying arguments to filename buffer.
- [ ] Implement `L` command calling Kernal `SETNAM`, `SETLFS`, and `LOAD`.
- [ ] Implement `W` command parsing range and calling Kernal `SAVE`.

---

## Verification Plan

### Manual Verification
1. **Register modification**:
   * Type `R A` $\rightarrow$ verify it prints current accumulator and prompts. Input `FF`, press Enter.
   * Type `R` $\rightarrow$ verify register list now displays `A=FF`.
2. **Naming and Writing**:
   * Type `N TEST.PRG`.
   * Type `W 2000 2010` $\rightarrow$ verify drive active light flashes and writes successfully.
3. **Loading**:
   * Clear target memory `$2000`–`$2010` to `00`.
   * Type `L 2000` $\rightarrow$ verify the written data is reloaded.
