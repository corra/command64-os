---
feature: debug-phase3-debugger
created: 2026-06-27
status: active
---

# Plan: DEBUG Phase 3 - Software Breakpoint Debugger (`T`, `P`)

## Goal & Rationale

Implement single-step instruction tracing (`T` for Trace step-into, `P` for Proceed step-over) for the Command 64 OS `DEBUG` utility. Since the MOS 6502 processor lacks a hardware single-step trap flag, single-stepping must be implemented using software breakpoints via the `BRK` instruction. When triggered, the debugger intercepts the break, updates the virtual registers, disassembles the next instruction, and returns control to the interactive command prompt.

## Scope

- Add virtual Program Counter (`regPC`) display and interactive editing to the `R` command.
- Redirect and restore the C64 KERNAL `BRK` interrupt vector (CBINV at `$0316/$0317`).
- Parse the instruction at `regPC` to compute its length and next potential execution targets.
- Install software breakpoints (`BRK` / `$00`) at target addresses in RAM.
- Construct the execution CPU context on the program stack and launch it via `RTI`.
- Intercept the `BRK` interrupt, retrieve registers from the stack, restore modified memory, print state, and return to the main loop.
- Implement ROM safety guards that prevent crashes when tracing into ROM routines.

## Files to Create/Modify

| File | Action | Notes |
|------|--------|-------|
| [src/external/debug/debug.asm](src/external/debug/debug.asm) | Modify | Implement target decoding, breakpoint injection, RTI stack framing, CBINV hijacking, and register capture. |

## Detailed Design & Key Decisions

### 1. Virtual PC Integration (`R` Command)

- **Tracking Virtual PC**:
  - We will define `regPC: .word 0` in the variables section of `debug.asm`.
  - When a file is successfully loaded via `cmdLoad`, `regPC` is updated to the starting address (`currentAddr`).
  - When `debug` starts, `regPC` defaults to `$0000`.
- **Modifying Registers**:
  - `cmdRegs` will be updated to accept `pc` (case-insensitive) as a register argument.
  - When editing `PC`, the debugger will prompt with `PC xxxx :` and parse a 16-bit hexadecimal value.
- **Register Display**:
  - `printAllRegs` will print the virtual PC alongside the existing registers, matching the format:
  
    ```text
    A=xx X=xx Y=xx P=xx S=xx PC=xxxx
    ```

### 2. Zero Page & RAM Variable Layout

We will add variables at the end of `debug.asm` to manage the debugger state and active breakpoints. We will store these in standard RAM variables (instead of Zero Page) to conserve ZP addresses:

```asm
// Debugger Execution Variables
regPC:        .word 0  // Virtual PC
traceMode:    .byte 0  // 0 = Trace (T), 1 = Proceed (P)
dbgS:         .byte 0  // Debugger stack pointer backup
origCBINV:    .word 0  // Original CBINV vector backup

// Breakpoint Storage (supports up to 2 active breakpoints for branches)
bpCount:      .byte 0  // Number of computed targets (1 or 2)
bpAddr1:      .word 0  // Target address A
bpByte1:      .byte 0  // Original byte at target A
bp1Active:    .byte 0  // Flag if breakpoint A is set in memory
bpAddr2:      .word 0  // Target address B
bpByte2:      .byte 0  // Original byte at target B
bp2Active:    .byte 0  // Flag if breakpoint B is set in memory
```

### 3. Next Execution Target Analysis (`decodeTargets`)

To place breakpoints at the next instruction, we must analyze the opcode at `regPC` and decode its execution target address(es). The instruction length is retrieved by looking up the opcode's addressing mode in `opAddrMode` and indexing `modeLength`.

1. **Default Target**:
   - For non-control-flow instructions, there is exactly 1 target at `regPC + instruction_length`.
2. **Subroutine Call (`JSR $20`)**:
   - **Trace (`T`)**: Subroutine entry address at `(regPC + 1)` (low) and `(regPC + 2)` (high).
   - **Proceed (`P`)**: Next instruction in the current routine: `regPC + 3`.
3. **Absolute Jump (`JMP $4C`)**:
   - Target is at `(regPC + 1)` (low) and `(regPC + 2)` (high).
4. **Indirect Jump (`JMP ($6C)`)**:
   - Read vector address `V` from `(regPC + 1)`/`2`.
   - Read target low byte from `(V)`.
   - Read target high byte from `(V + 1)`. Emulate 6502 page-wrap bug: if `V` low byte is `$FF`, read high byte from `V - $FF` (low byte `$00`) instead of `V + 1`.
5. **Subroutine Return (`RTS $60`)**:
   - Read program's stack pointer from `regS`.
   - Read low byte from `$0100 + regS + 1`, and high byte from `$0100 + regS + 2`.
   - Target is `(high << 8 | low) + 1`.
6. **Interrupt Return (`RTI $40`)**:
   - Read program's stack pointer from `regS`.
   - Read low byte from `$0100 + regS + 2`, and high byte from `$0100 + regS + 3`.
   - Target is `high << 8 | low`.
7. **Conditional Branches** (`BPL`, `BMI`, `BVC`, `BVS`, `BCC`, `BCS`, `BNE`, `BEQ`):
   - All branch opcodes fit the pattern `(opcode & $1F) == $10`.
   - Since branch decisions depend on CPU status flag values that are active at execution, we must set **two** breakpoints:
     - **Target A (Not Taken)**: `regPC + 2`.
     - **Target B (Taken)**: `regPC + 2 + signed_offset` (where `signed_offset` is the signed 8-bit byte at `regPC + 1`).

### 4. ROM Safety Guards

Because software breakpoints rewrite instruction bytes in memory, they only function in RAM. Under Command 64 OS, the **BASIC ROM** (`$A000-$BFFF`) is banked out on startup (exposing the underlying RAM) and restored only upon system `EXIT`. Therefore, `$A000-$BFFF` is fully writeable RAM during execution. 

The only remaining read-only areas are the mapped I/O space / Character ROM (`$D000-$DFFF`) and the KERNAL ROM (`$E000-$FFFF`). Trying to set a breakpoint in these regions has no effect and causes the debugger to lose control.

- **Check Safe Address**:
  - Target address `A` is safe if `A < $D000` (since everything below `$D000` is active RAM).
- **Subroutine Step-over**:
  - If the user uses step-into (`T`) on a `JSR` targeting ROM (e.g. `JSR $FFD2`), the debugger will automatically treat it as step-over (`P`), placing the breakpoint at `regPC + 3` in RAM.
- **ROM Target Abortion**:
  - If a target address for an instruction (such as a branch or `JMP` to ROM) is unsafe, the breakpoint will not be set.
  - Before launching execution, if `bp1Active == 0` and `bp2Active == 0`, the command is aborted with `error: cannot trace target in ROM`.

### 5. Interrupt Vector Hijacking (CBINV)

- **Vector Information**:
  - The C64 Kernal routes software breaks (`BRK`) and hardware interrupts (`IRQ`) through vector `CINV` (`$0314/$0315`). If a `BRK` instruction is identified (by checking the B flag in status), the Kernal jumps to `CBINV` (`$0316/$0317`).
- **Hijacking Protocol**:
  1. Read original `CBINV` vector and store it in `origCBINV`.
  2. Inside a `SEI`/`CLI` block, write the address of our handler `myBrkHandler` to `$0316/$0317`.
- **Restoration Protocol**:
  - In `myBrkHandler`, write `origCBINV` back to `$0316/$0317` within a `SEI`/`CLI` block.

### 6. CPU Context Restoration & Target Execution

To execute the single instruction under test, we must restore registers and jump to `regPC` within the program's stack context:

1. **RTI Stack Frame**:
   - The program's stack pointer is `regS`.
   - We will write the target execution context directly to the stack memory page 1 relative to `regS`:
     - `$0100 + regS`     = `regPC` high byte
     - `$0100 + regS - 1` = `regPC` low byte
     - `$0100 + regS - 2` = `regP` status flags
2. **Launcher Sequence**:
   - Write breakpoints to memory at active target locations (`bpAddr1`/`bpAddr2` replaced with `$00`).
   - Backup the current debugger stack pointer: `tsx; stx dbgS`.
   - Set the stack pointer to `regS - 3` (`ldx regS; dex; dex; dex; txs`).
   - Load registers: `lda regA; ldy regY; ldx regX`.
   - Execute `rti` to restore program status, pop `PC`, and jump to target.

### 7. Breakpoint Intercept Handler (`myBrkHandler`)

When the CPU hits the inserted `BRK` instruction, the C64 KERNAL pushes CPU registers and jumps to our hijacked handler:

1. **Register Extraction**:
   - Perform `tsx` immediately. At this point, the stack contains the Kernal interrupt frame.
   - Relative to the stack pointer `X`, retrieve program registers:
     - `regY` = `$0101, x` (pushed by Kernal)
     - `regX` = `$0102, x` (pushed by Kernal)
     - `regA` = `$0103, x` (pushed by Kernal)
     - `regP` = `$0104, x` (pushed by CPU status)
   - Retrieve program PC:
     - `regPC` low byte  = `$0105, x` minus 2 (to offset `BRK` execution advance)
     - `regPC` high byte = `$0106, x` minus carry
   - Calculate program stack pointer before interrupt occurred:
     - `regS` = `X + 6` (account for the 6 bytes pushed on the stack by CPU and Kernal).
2. **State Restoration**:
   - Remove all breakpoints: write original bytes (`bpByte1`/`bpByte2`) back to memory.
   - Restore original `CBINV` from `origCBINV`.
   - Restore the debugger's stack pointer: `ldx dbgS; txs`.
3. **Display Output**:
   - Print CPU registers (`printAllRegs`).
   - Disassemble and print the next instruction at the new `regPC` (call disassembler loop with count = 1).
   - Jump directly back to the debugger's command loop (`mainLoop`).

---

## Detailed Implementation Checklist

- [ ] Define variables for execution state, register capture (`regPC`), and breakpoints.
- [ ] Update `cmdLoad` to set `regPC` to program entry point.
- [ ] Add `pc` case-insensitive parsing to `cmdRegs`.
- [ ] Update `printAllRegs` to append `PC=xxxx` to the register line.
- [ ] Register `t` (`cmdTrace`) and `p` (`cmdProceed`) in command dispatcher and help message.
- [ ] Implement `cmdTrace`/`cmdProceed` parsing and argument check.
- [ ] Implement target address decoder `decodeTargets` resolving branches, calls, jumps, returns, and page wrap.
- [ ] Implement address safety checker `isAddressSafe`.
- [ ] Implement breakpoint insertion (`setBreakpoints`) and restoration (`removeBreakpoints`).
- [ ] Implement context restoration stack framing and execution launch via `RTI`.
- [ ] Implement intercept handler `myBrkHandler` extracting register context, restoring memory, printing status, and returning to prompt.

---

## Verification Plan

### Manual Verification

1. **Simple Loop Test**:
   - Write the following assembly loop starting at `$2000` via `A 2000`:

     ```asm
     2000: LDA #$01
     2002: INX
     2003: CPX #$03
     2005: BNE $2002
     2007: RTS
     ```

   - Initialize registers: `R X` -> `00`, `R PC` -> `2000`.
   - Run `T` (Trace) and verify `A=01` and PC advances to `2002`.
   - Run `T` again and verify `X=01` and PC advances to `2003`.
   - Run `P` (Proceed) on `BNE $2002` (at `2005`) and verify execution runs until the loop finishes and stops at `RTS` at `2007`.

2. **ROM Safety Verification**:
   - Write `JSR $FFD2` at `$2000`.
   - Set `PC` to `$2000`.
   - Run `T` and verify it steps *over* `$FFD2` and stops at `$2003` without hanging the system.
   - Write `JMP $FFD2` at `$2000`.
   - Set `PC` to `$2000`.
   - Run `T` and verify it aborts with `error: cannot trace target in ROM` and returns to prompt.
