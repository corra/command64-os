---
feature: phase2b-external-cmds
created: 2026-05-03
status: planned
---

# Plan: Phase 2B - External Command Support & PATH Search

## Goal & Rationale
Enable the shell to execute commands not built into the kernel. This requires the shell to search for a matching filename in a specified directory (the PATH), load the binary from disk into memory, and transfer execution control to it. This is the core of the DOS "file-as-command" paradigm.

## Scope
- **Command Search Logic**: Implement `PATH_SEARCH` mechanism.
- **Binary Loader**: Create a minimal loader that can read a `.COM` (or equivalent C64 binary) from disk to a specific memory location.
- **Execution Handover**: Implement the jump to the loaded binary and the return-to-shell mechanism (stack preservation).
- **Basic PATH implementation**: Support a simple path string (e.g., `A:\CMD\`).

## Files to Create/Modify
| File | Action | Notes |
|------|--------|-------|
| `src/command64/shell.asm` | Modify | Update `shellDispatch` to trigger `PATH_SEARCH` on internal match failure |
| `src/command64/loader.asm` | Create | Implementation of the binary loader |
| `src/command64/path.asm` | Create | Logic for searching directories for filenames |
| `include/command64.inc` | Modify | Add constants for loader memory regions and PATH buffers |

## Key Design Decisions
- **Loader Location**: External commands will be loaded into a dedicated "User Program Segment" (e.g., starting at $2000) to avoid overwriting the shell or VMM.
- **Execution Context**: The shell will push the current state to the stack, jump to the entry point, and the external command is expected to `RTS` back to the shell.
- **Disk I/O**: Use the C64 KERNAL `SETLFS` / `SETK` routines to navigate the disk, abstracting the raw disk access behind the PETSCII/IO layer.

## Verification Plan
- **Positive Test**: Create a tiny "Hello World" .prg, place it on disk, and call it from the shell.
- **Negative Test**: Attempt to call a non-existent command and verify "Bad command or file name" is still returned.
- **Stability Test**: Ensure the shell remains functional after an external command returns.

## Progress
- [ ] Define loader memory map
- [ ] Implement directory search (`path.asm`)
- [ ] Implement binary loader (`loader.asm`)
- [ ] Integrate with `shellDispatch`
