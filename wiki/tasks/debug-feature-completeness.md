# Task Spec: DEBUG Utility Feature Completeness

## Description

Implement the remaining MS-DOS DEBUG parity features for the Command 64 OS `DEBUG` utility, including interactive registers, file loading/saving, an interactive inline assembler, and single-step software breakpoint tracing.

## Scope

- Modify [src/external/debug/debug.asm](file:///home/morgan/development/c64/command64-os/src/external/debug/debug.asm) to implement:
  - `R [register]`: Modify CPU registers (`A`, `X`, `Y`, `P`, `S`) interactively.
  - `N [filename]`: Store file names for I/O operations.
  - `L [address]`: Load named files into memory at default or overridden addresses.
  - `W [range]`: Write specified memory ranges to the named file.
  - `A [address]`: Interactively assemble 6502 instructions into memory.
  - `T [address]`: Single-step trace through instructions (using dynamic `BRK` trapping).
  - `P [address]`: Step-over proceed execution of subroutines/loops (using dynamic `BRK` trapping).

## Sub-tasks

### Phase 1: Interactive Register Editing and File I/O (`R`, `N`, `L`, `W`)

- [x] Implement register name parsing and interactive modification for `R` command (`R A`, `R X`, etc. prompting with `:`).
- [x] Implement `N` command to write input arguments to the filename buffer `fileNameBuf`.
- [x] Implement `L` command to load files from disk, supporting optional address override.
- [x] Implement `W` command to parse memory range and save data to disk using C64 Kernal.

### Phase 2: Interactive Inline 6502 Assembler (`A`)

- [ ] Implement command dispatching for `A` and prompt loop displaying `currentAddr:`.
- [ ] Implement assembler lexer/parser separating mnemonics from operand expressions.
- [ ] Implement syntax parser mapping operands to 6502 addressing modes (e.g. `#`, `(`, `,X`, `,Y`).
- [ ] Implement branch instruction relative offset calculation and out-of-range checks.
- [ ] Implement opcode lookup dictionary and memory write logic.

### Phase 3: Software Breakpoint Debugger (`T`, `P`)

- [ ] Implement C64 CBINV interrupt vector hijacking and restoration routines.
- [ ] Implement 6502 instruction decoder determining execution length and potential targets.
- [ ] Implement dynamic software breakpoint insertion and original code backup.
- [ ] Implement CPU register context recovery before jumping to target code.
- [ ] Implement breakpoint intercept logic (saving state, removing breakpoints, printing registers and next disassembly).

### Verification and Documentation

- [x] Verify Phase 1 register editing and load/save operations.
- [x] Create and document a full feature test plan for `debug` (maintained continuously).
- [ ] Verify Phase 2 assembly of simple loops and comparison with disassemble output.
- [ ] Verify Phase 3 step-into and step-over tracing operations.
- [ ] Update user documentation and `CHANGELOG.md` to reflect new commands.
