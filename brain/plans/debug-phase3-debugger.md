---
feature: debug-phase3-debugger
created: 2026-06-27
status: planned
---

# Plan: DEBUG Phase 3 - Software Breakpoint Debugger (`T`, `P`)

## Goal & Rationale
Implement single-step CPU instruction tracing (`T` for Trace step-into, `P` for Proceed step-over) for the C64 `DEBUG` utility. Since the MOS 6502 does not support hardware single-step trap flags, this must be implemented using a software breakpoint subsystem using the `BRK` instruction.

## Scope
- Redirect and handle the C64 Kernal `BRK` interrupt vector (CBINV at `$0316/$0317`).
- Decode instruction length and target execution addresses at the Program Counter.
- Insert software breakpoints (`BRK` / `$00`) at potential execution targets.
- Restore registers, execute instructions, intercept breakpoints, restore original code, and print states.

## Files to Create/Modify
| File | Action | Notes |
|------|--------|-------|
| [src/external/debug/debug.asm](file:///home/morgan/development/c64/command64-os/src/external/debug/debug.asm) | Modify | Implement CBINV interrupt redirection, target instruction decoding, breakpoint injection, register loading, and state printout. |

## Detailed Design & Key Decisions

### 1. Intercepting the C64 BRK Interrupt (CBINV)
* **Design**:
  * The C64 Kernal routes software `BRK` and hardware `IRQ` through the vector at `$0314/$0315` (CINV). If a `BRK` instruction is identified, the Kernal jumps to the address in `$0316/$0317` (CBINV).
  * We will hijack CBINV:
    1. During trace execution setup, copy the original contents of `$0316/$0317` to a backup location.
    2. Write the address of our custom handler `brkHandler` to `$0316/$0317`.
    3. At the end of breakpoint handling, restore the original CBINV vector.

### 2. Instruction Decoding and Next Target Analysis
* **Workflow**:
  * Determine instruction targets starting at the virtual PC (`regPC`):
    * **JMP absolute (`$4C`)**: target address is read from `regPC + 1` (Lo) and `regPC + 2` (Hi). Next breakpoint goes at target.
    * **JMP indirect (`$6C`)**: read indirect address from `regPC + 1` (Lo) and `regPC + 2` (Hi). Read final target from the indirect address pointer. Next breakpoint goes at final target.
    * **JSR subroutine (`$20`)**:
      * **Trace (`T`)**: target is read from `regPC + 1`/`2`. Place breakpoint at subroutine start.
      * **Proceed (`P`)**: target is `regPC + 3` (the instruction immediately following JSR, stepping *over* subroutine). Place breakpoint at `regPC + 3`.
    * **RTS return (`$60`)**:
      * Read stack pointer `regS` to retrieve return address from page 1.
      * Target address is at `$0100 + regS + 1` (Lo) and `$0100 + regS + 2` (Hi), plus 1.
    * **RTI return (`$40`)**:
      * Read status register and return PC from stack using `regS`.
      * Target address is at `$0100 + regS + 2` (Lo) and `$0100 + regS + 3` (Hi).
    * **Branch instructions** (`BCC`, `BCS`, `BNE`, `BEQ`, `BPL`, `BMI`, `BVC`, `BVS`):
      * Since branch decisions depend on the status register `regP` which might change during execution, place breakpoints at **both** execution paths:
        * Path A (Branch Not Taken): `regPC + 2`
        * Path B (Branch Taken): `regPC + 2 + signed_offset` (where `signed_offset` is read from `regPC + 1`).
    * **All other instructions**: Next target is `regPC + length` (where `length` is obtained from `modeLength` lookup table using addressing mode of the instruction).

### 3. Breakpoint Insertion and Removal
* **Strategy**:
  * We can have up to 2 active breakpoints simultaneously (needed for branches).
  * Structure to hold breakpoints:
    ```asm
    bpAddr1: .word 0
    bpByte1: .byte 0
    bpAddr2: .word 0
    bpByte2: .byte 0
    ```
  * **Insertion**:
    * Save target memory byte to `bpByte1`/`2`.
    * Overwrite target memory byte with `$00` (`BRK`).
  * **Removal**:
    * Write `bpByte1`/`2` back to `bpAddr1`/`2` memory locations.

### 4. CPU Context Restoration and Execution Launch
* **Design**:
  * To run the target instruction, we must restore the registers to C64 CPU registers.
  * Since our handler is running under an interrupt context, we can push our desired registers and target PC onto the stack and run `RTI`.
  * **Context Switch to target**:
    1. Set up the stack at page 1 to contain:
       * Return address High (`regPC >> 8`)
       * Return address Low (`regPC & $FF`)
       * Status byte (`regP`)
    2. Load CPU registers from `regA`, `regX`, `regY`.
    3. Load CPU stack pointer using `ldx regS; txs`.
    4. Run `RTI` to restore status and jump to target PC.

### 5. Breakpoint Intercept (Interrupt Handler)
* **Design**:
  * When `BRK` triggers, C64 redirects control to our custom CBINV handler:
    1. Immediately save the CPU registers `A`, `X`, `Y` into scratch variables.
    2. Retrieve the interrupted PC and Status register from the stack frame:
       * The CPU pushes PC + 2 and Status when `BRK` executes.
       * Retrieve these values from page 1 (`$0100 + StackPointer`) and save to `regPC` (subtracting 2 to get the actual `BRK` instruction address) and `regP`.
       * Save stack pointer to `regS`.
    3. Restore the original instruction bytes at the breakpoint addresses.
    4. Print the register block (identical to `R` command output).
    5. Disassemble the next instruction at the new `regPC` (identical to `U` command output).
    6. Restore the CBINV vector and jump back to the main `DEBUG` input loop.

---

## Detailed Implementation Checklist
- [ ] Implement CBINV interrupt redirection handler.
- [ ] Implement instruction decoder at `regPC` to compute instruction length and targets.
- [ ] Implement breakpoint insertion / deletion logic supporting up to 2 targets.
- [ ] Implement context restoration stack pushing and execution launch via `RTI`.
- [ ] Implement intercept handler saving state, removing breakpoints, disassembling next PC, and returning to prompt.

---

## Verification Plan

### Manual Verification
1. Place a simple program at `$2000`:
   ```text
   2000: LDA #$01
   2002: INX
   2003: CPX #$03
   2005: BNE $2002
   2007: RTS
   ```
2. Set virtual PC to `$2000` (`R PC 2000` or equivalent).
3. Run `T` (Trace) and verify:
   * It executes `LDA #$01`. Registers display updates `A=01`. Next instruction shown is `INX`.
4. Run `T` (Trace) again:
   * It executes `INX`. Registers display updates `X=01`. Next instruction is `CPX #$03`.
5. Run `P` (Proceed) when on `BNE $2002` to see if execution runs and stops on `RTS` at `$2007` once loop terminates.
