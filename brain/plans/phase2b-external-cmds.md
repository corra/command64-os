---
feature: phase2b-external-cmds
created: 2026-05-03
status: planned
---

# Plan: Phase 2B - External Command Support & PATH Search

## Goal & Rationale
Enable the shell to execute commands not built into the kernel. This requires the shell to search for a matching filename in a specified directory (the PATH), load the binary from disk into memory, and transfer execution control to it. 

To align with C64 conventions while maintaining the DOS paradigm, the shell will search for `.PRG` files. The search must be case-insensitive to ensure user friendliness in the C64's PETSCII environment.

## Scope
- **Command Search Logic**: Implement `PATH_SEARCH` mechanism targeting `.PRG` files.
- **Case-Insensitivity**: Ensure `DIR` and `PATH_SEARCH` handle case-insensitive matches.
- **Binary Loader**: Create a loader using KERNAL `LOAD` ($FFD5).
    - **Default**: Load to `$2000`.
    - **Optional**: Support user-specified load address (e.g., `run program 3000`).
- **Hex Parser**: Implement a string-to-hex utility (`parseHex`) to support address arguments.
- **Execution Handover**: Implement the jump to the loaded binary and the return-to-shell mechanism.

## Files to Create/Modify
| File | Action | Notes |
|------|--------|-------|
| `src/command64/shell.asm` | Modify | Update `shellDispatch` to support optional address arguments. |
| `src/command64/loader.asm` | Create | Implementation of the binary loader. |
| `src/command64/utils.asm` | Create | Hex parsing and string utility routines. |
| `src/command64/path.asm` | Create | Logic for searching directories for `.PRG` files. |
| `include/command64.inc` | Modify | Add equates for search buffers and utility scratch space. |

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
