---
feature: debug-feature-completeness
created: 2026-06-27
status: planned
---

# Plan: DEBUG Utility Feature Completeness Roadmap

This plan provides a roadmap and detailed design for bringing the Command 64 OS `DEBUG` utility closer to feature parity with the MS-DOS 4.0 `DEBUG.COM` version. It outlines which commands are feasible to port, which are not applicable to the C64/6502 architecture, and provides technical designs for each target feature.

---

## 1. Feasibility Analysis of MS-DOS DEBUG Commands

The table below catalogs all MS-DOS `DEBUG` commands, their current implementation status in Command 64 OS, and feasibility evaluations for porting.

| Command | MS-DOS Function | C64 Status | Feasibility / Action Plan |
| :---: | :--- | :---: | :--- |
| **`A`** | Assemble x86 instructions | **Missing** | **Feasible (Phase 2)**. Implement a line-by-line 6502 assembler. |
| **`C`** | Compare memory | Implemented | Complete. |
| **`D`** | Dump memory | Implemented | Complete (optimized for 40 columns). |
| **`E`** | Enter memory data | Implemented | Complete. |
| **`F`** | Fill memory | Implemented | Complete. |
| **`G`** | Go (execute) | Implemented | Complete (uses 6502 `JSR`). |
| **`H`** | Hex arithmetic | Implemented | Complete (performs 16-bit sum/diff). |
| **`I`** | Input from port | **Missing** | **Not Feasible/Redundant**. 6502 uses memory-mapped I/O. Reading ports is identical to standard memory reads (`D` or `E`). |
| **`L`** | Load file/sectors | **Missing** | **Feasible (Phase 1)**. Interface with C64 Kernal / DOS API to load programs. |
| **`M`** | Move memory | Implemented | Complete (handles overlapping buffers). |
| **`N`** | Name target file | **Missing** | **Feasible (Phase 1)**. Store filename in a buffer for `L`/`W`. |
| **`O`** | Output to port | **Missing** | **Not Feasible/Redundant**. 6502 uses memory-mapped I/O. Writing ports is identical to memory writes (`E`). |
| **`P`** | Proceed (step over) | **Missing** | **Feasible (Phase 3)**. Implement step-over via dynamic `BRK` breakpoint placement. |
| **`Q`** | Quit to shell | Implemented | Complete. |
| **`R`** | Register edit/view | Partial | **Feasible (Phase 1)**. Add register modification support (`R [reg]`). |
| **`S`** | Search memory | Implemented | Complete. |
| **`T`** | Trace (step into) | **Missing** | **Feasible (Phase 3)**. Implement step-into via dynamic `BRK` placement. |
| **`U`** | Unassemble (disassemble)| Implemented | Complete (6502 disassembly table-driven parser). |
| **`W`** | Write memory to file | **Missing** | **Feasible (Phase 1)**. Interface with C64 Kernal / DOS API to save memory ranges. |
| **`V`** | Version info | Custom | Added custom command (non-DOS standard). |
| **`X...`**| Expanded Memory (EMS) | **Missing** | **Not Applicable**. C64 lacks EMS bank switching; REU access is handled via memory-mapped DMA registers (`$DF00`). |

---

## 2. Phase 1: Interactive Registers and File I/O (`R`, `N`, `L`, `W`)

These features represent highly feasible additions that align perfectly with C64 OS capabilities.

### A. Register Modification (`R [register]`)

* **Design**: Expand the current `cmdRegs` handler in [debug.asm](file:///home/morgan/development/c64/command64-os/src/external/debug/debug.asm) to inspect trailing arguments:
  * If no argument is provided, print the standard register block (`A=xx X=xx Y=xx P=xx S=xx`).
  * If a valid register argument is supplied (case-insensitive: `A`, `X`, `Y`, `P`, or `S`):
    1. Print the register name and current value.
    2. Display a colon prompt `:` and wait for a 2-digit hex input.
    3. If input is valid, overwrite the corresponding internal variable (`regA`, `regX`, `regY`, `regP`, or `regS`). If invalid, print `error`.

### B. Filename Setup (`N [filename]`)

* **Design**: Add an `inputFileName` buffer (up to 32 bytes) inside [debug.asm](file:///home/morgan/development/c64/command64-os/src/external/debug/debug.asm) variables:

  ```asm
  fileNameLen: .byte 0
  fileNameBuf: .fill 32, 0
  ```

  * **Command `N`**: Parse the filename argument, verify it fits in 32 bytes, copy it to `fileNameBuf`, and set `fileNameLen`.

### C. Loading Files (`L [address]`)

* **Design**: Integrate with the C64 Kernal load routines (`SETNAM`, `SETLFS`, `LOAD`):
  * Validate that `fileNameLen > 0`; if not, print `error`.
  * If an `address` argument is provided, load the file into that target address (overriding the file's start address header).
  * If no address is specified, load the file using the address specified in the program's two-byte load header.
  * Update `currentAddr` to point to the load address.

### D. Writing Files (`W range` / `W address length`)

* **Design**: Integrate with C64 Kernal save routines (`SETNAM`, `SETLFS`, `SAVE`):
  * Validate that `fileNameLen > 0`.
  * Parse a range argument (either `start end` or `start L length`) using the existing `parseRange` logic.
  * Invoke Kernal `SAVE` to write the memory range to disk under the active name in `fileNameBuf`.

---

## 3. Phase 2: Interactive 6502 Assembler (`A [address]`)

Implementing a line-by-line 6502 assembler within `DEBUG` requires inverting the table-driven decoding structures used in the `U` (Unassemble) command.

### Design Principles

1. **Interactive Loop**:
   * If an address is provided, start assembly at `address`. Otherwise, default to the last accessed address (`currentAddr`).
   * For each line:
     * Display the current memory address prompt: `2000:`
     * Wait for a line of input. A blank line exits the assembly mode.
     * Parse the line into a 3-letter mnemonic and an operand expression.
     * Identify the addressing mode based on syntax features:
       * `#$xx` $\rightarrow$ Immediate (`MODE_IMM`)
       * `($xx,X)` $\rightarrow$ Indirect X (`MODE_IZX`)
       * `($xx),Y` $\rightarrow$ Indirect Y (`MODE_IZY`)
       * `($xxxx)` $\rightarrow$ Indirect (`MODE_IND`)
       * `$xx,X` $\rightarrow$ Zero Page X (`MODE_ZPX`)
       * `$xxxx,X` $\rightarrow$ Absolute X (`MODE_ABX`)
       * `$xx,Y` $\rightarrow$ Zero Page Y (`MODE_ZPY`)
       * `$xxxx,Y` $\rightarrow$ Absolute Y (`MODE_ABY`)
       * `$xx` $\rightarrow$ Zero Page (`MODE_ZP`)
       * `$xxxx` $\rightarrow$ Absolute (`MODE_ABS`)
       * (None) $\rightarrow$ Implied/Accumulator (`MODE_IMP`/`MODE_ACC`)
       * For branches (e.g. `BNE target`), compute the relative offset: `target - currentAddr - 2`. If outside the range `[-128, 127]`, report `error`.
     * Look up the mnemonic and mode in the opcode database to retrieve the matching hex opcode.
     * Write the opcode byte and operands to memory.
     * Advance `currentAddr` by the instruction length.

---

## 4. Phase 3: Software Breakpoint debugger (`T` and `P`)

Single-stepping (`T` for Trace, `P` for Proceed) requires intercepting CPU execution using the 6502 `BRK` instruction.

### Debugger Context Variables

To track the debugger's virtual execution state, we define:

```asm
regPC: .word 0 // Virtual Program Counter
```

### Operation Design

1. **Interrupt Vector Hijack**:
   * During initialization of `T` or `P`, redirect the C64 Kernal `BRK` vector (`$0316/$0317` - CBINV) to our custom interrupt handler.
2. **Instruction Decoding**:
   * Read the opcode at `regPC`.
   * Decode the instruction length and possible execution targets (leveraging logic in `cmdUnassemble`):
     * **Standard Instructions**: Next PC is `regPC + length`.
     * **JMP**: Next PC is the target of the jump.
     * **JSR**:
       * For `T` (Trace): Next PC is the subroutine entry target.
       * For `P` (Proceed): Treat subroutine as atomic; place the breakpoint at `regPC + 3` (the return address).
     * **Branches**: Place breakpoints at **both** targets (taken branch `regPC + 2 + offset` and not-taken branch `regPC + 2`).
     * **RTS/RTI**: Read return address from stack frame in page 1 (`$0100 + regS`).
3. **Breakpoint Insertion**:
   * Save the original bytes at the calculated next target addresses.
   * Write a `BRK` instruction (`$00`) to those addresses.
4. **Context Restore & Run**:
   * Restore the CPU registers from our saved state (`regA`, `regX`, `regY`, `regP`, `regS`).
   * Push the virtual `regPC` to the stack.
   * Execute an `RTI` or jump to run the instruction.
5. **Breakpoint Capture**:
   * When `BRK` fires, our hijacked interrupt handler runs first:
     * Save the active CPU registers back into `regA`, `regX`, `regY`, `regP`, `regS`.
     * Restore the original instruction bytes at the breakpoint addresses.
     * Set `regPC` to the breakpoint address that was triggered.
     * Print the register state (`R` command output) and disassemble the next instruction (`U` command output).
     * Restore the CBINV vector and return to the `DEBUG` main loop.

---

## 5. Verification Plan

### Automated/Manual Tests

* **Phase 1 (Registers/File I/O)**:
  * Run `R A` and input `FF`. Run `R` and verify `A=FF`.
  * Run `N TEST.PRG` then `W 2000 2100`. Verify file exists on disk.
  * Run `L 2000` and verify the file is correctly loaded.
* **Phase 2 (Assembler)**:
  * Run `A 2000` and input:

    ```text
    LDA #$20
    STA $D020
    RTS
    ```

  * Disassemble via `U 2000` to verify correct instruction generation.
* **Phase 3 (Trace/Proceed)**:
  * Set `regPC` to `$2000`. Run `T` to step through the program, verifying screen border color changes on `STA $D020` and execution returns to `DEBUG` on `RTS`.
