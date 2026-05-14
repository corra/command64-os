---
feature: command64-phase2a
created: 2026-05-02
status: in-progress
---

# Plan: command64 Phase 2A - Core Dispatcher Proof-of-Concept

## Goal & Rationale
Build the absolute core of `command64.com`: the main command dispatcher loop, prompt rendering, input reading, and the two simplest internal commands (`CLS` and `ECHO`). This proves the Service Bus Model by verifying that the shell loop, PETSCII output, and basic command routing can successfully compile and run.

## Scope
**Included:**
- Core command dispatcher main loop
- Prompt display
- Character reading from PETSCII API
- CLS (clear screen) internal command
- ECHO string print internal command
- Command matching/registry logic

**Out of Scope:**
- External command executing PATH search
- File system integration
- Batch file processing
- Piping and redirection
- Environment variable management

## Files to Create/Modify
| File | Action | Notes |
|------|--------|-------|
| `build/command64.asm` | Create | Main Kick Assembler project entry point |
| `src/command64/shell.asm` | Create | Main dispatcher loop, prompt, command routing |
| `src/command64/petsci.asm` | Create | PETSCII API implementation |
| `include/command64.inc` | Create | Shared constants, macros, and equates for command64 |
| `include/vmm.inc` | Create | VMM memory constants and REU mappings |

## Key Design Decisions
- Kick Assembler is our compiler, providing C64 binary generation
- The command loop will be iterative, reading strings until CR is detected, and passing them to `parse_command`
- PETSCII layer maps directly to KERNAL subroutines for the MVP to keep code small and fast
- Command registry will be a simple label comparison table: matching the input against hardcoded strings
- VMM will be abstracted for Phase 2A as it's memory management logic that we can fully realize Phase 2B/2C

## Verification Plan
- **Assembly Build:** Verify Kick Assembler can successfully assemble the code without errors
- **Functional Test:** Run the assembled PRG in VICE (the C64 emulator) and manually verify:
  1. The prompt is printed
  2. Input is accepted
  3. `CLS` clears the screen
  4. `ECHO Hello World` prints the message
  5. `EXIT` terminates the program
- **Manual Test:** Verify PETSCII output characters appear correctly on the C64 display

## Progress
- [x] Project directory structure created
- [x] Kick Assembler verified
- [x] PETSCII API specification written
- [x] Include files defined (`include/command64.inc`)
- [x] Kick Assembler project file (`build/command64.asm`)
- [x] PETSCII implementation written and corrected (`src/command64/petsci.asm`)
- [x] Core command loop logic written and corrected (`src/command64/shell.asm`)
- [x] CLS and ECHO internals written
- [x] `build/command64.prg` assembles with 0 errors (2026-05-02)
- [ ] VMM API specification written (`include/vmm.inc`)
- [ ] Verify in VICE emulator
