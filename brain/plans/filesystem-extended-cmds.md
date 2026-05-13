# Implementation Plan: DEL and REN Commands

## Objective
Extend the shell with `DEL` (delete) and `REN` (rename) commands, matching MS-DOS 4.0 functionality.

## Key Files & Context
- `src/command64/file.asm`: Implement low-level `fileDelete` and `fileRename`.
- `src/command64/api.asm`: Add `DOS_DELETE_FILE` ($41) and `DOS_RENAME_FILE` ($56) APIs.
- `src/command64/shell.asm`: Implement `cmdDel` and `cmdRen` handlers.

## Design Decisions
1. **API Contract**:
   - `DEL`: `X/Y` = Pointer to filename.
   - `REN`: `X/Y` = Old name pointer, `PrintPtrLo/Hi` ($FB/$FC) = New name pointer.
2. **C64 Disk Protocol**:
   - Use command channel 15.
   - `DEL`: `S:filename`.
   - `REN`: `R:newname=oldname`.

## Implementation Steps
1. Add `DOS_DELETE_FILE` and `DOS_RENAME_FILE` to service bus.
2. Implement `fileDelete` using disk "Scratch" command.
3. Implement `fileRename` using disk "Rename" command.
4. Add shell handlers and update command table.

## Verification & Testing
1. Test `DEL file`.
2. Test `REN old new`.
3. Verify via `DIR`.
