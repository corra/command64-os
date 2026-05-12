---
feature: phase3-filesystem
created: 2026-05-11
status: completed
---

# Plan: Phase 3 - File System Integration

## Goal & Rationale
Now that the Service Bus (INT 21h equivalent) and VMM are stable, the next major capability is file I/O. We need to implement MS-DOS style handle-based file I/O over the C64's channel-based KERNAL routines. This will allow external programs to read and write files without dealing with Commodore-specific device numbers or secondary addresses.

## Scope
- Define the File Control Block (FCB) structure.
- Implement a Handle Table to map integer handles to open files.
- Extend the `api.asm` Jump Table to support new INT 21h file primitives:
  - `DOS_OPEN_FILE`
  - `DOS_READ_FILE`
  - `DOS_WRITE_FILE` ($40)
  - `DOS_CLOSE_FILE`
- Implement a new internal command: `TYPE` (displays file contents) as a proof-of-concept for the new API.
- Implement `COPY` internal command as a proof-of-concept for `DOS_WRITE_FILE`.

## Files to Create/Modify
| File | Action | Notes |
|------|--------|-------|
| `include/command64.inc` | Modify | Add new DOS API constants and Handle Table memory definitions. |
| `src/command64/api.asm` | Modify | Implement the new file I/O dispatch routines (`ahWrite`). |
| `src/command64/file.asm` | Modify | Add `fileWrite` routine using KERNAL `CHKOUT` and `BSOUT`. |
| `src/command64/shell.asm` | Modify | Add `COPY` internal command. |
| `tests/src/filetest.asm` | Create | Integration test for File I/O API. |

## Key Design Decisions
- **Write Mode**: `fileOpen` accepts mode in `HexValLo` (0=Read, 1=Write). For Write mode, it appends `,S,W` to the filename copy in `FileScratch`.
- **C64 Mapping**: A DOS "Handle" will map internally to a C64 "Logical File Number" (LFN). The OS will track which LFNs are active and map them to physical device 8 (or the current active device).
- **Stable Entry Point**: External programs call `JSR $1000` (ApiStub).

## Verification Plan
- Build the modified shell.
- Create an integration test program (`tests/src/filetest.asm`) that opens a file for writing, writes data, closes it, reopens for reading, and verifies the data.
- Verify `COPY` command.

## Progress
- [x] Initialize Phase 3 plan
- [x] Define FCB structure and Handle Table memory layout
- [x] Implement `DOS_OPEN_FILE`
- [x] Implement `DOS_READ_FILE`
- [x] Implement `DOS_CLOSE_FILE`
- [x] Implement `TYPE` internal command
- [x] Implement `DOS_WRITE_FILE` ($40)
- [x] Update `DOS_OPEN_FILE` to support Write mode
- [x] Create `filetest.asm`
- [x] Implement `COPY` command
