---
feature: phase3-filesystem
created: 2026-05-11
status: in-progress
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
  - `DOS_WRITE_FILE`
  - `DOS_CLOSE_FILE`
- Implement a new internal command: `TYPE` (displays file contents) as a proof-of-concept for the new API.

## Files to Create/Modify
| File | Action | Notes |
|------|--------|-------|
| `include/command64.inc` | Modify | Add new DOS API constants and Handle Table memory definitions. |
| `src/command64/api.asm` | Modify | Implement the new file I/O dispatch routines. |
| `src/command64/file.asm` | Create | New module for FCB and Handle Table management logic. |
| `src/command64/shell.asm` | Modify | Add the `TYPE` internal command to the registry. |
| `build/command64.asm` | Modify | Integrate the new `file.asm` segment. |

## Key Design Decisions
- **Handle Limits**: We will likely limit the maximum number of simultaneously open files (e.g., to 5 or 10) to conserve base memory for the Handle Table.
- **FCB vs. Handles**: While early DOS used FCBs explicitly in the API, later versions (and our target API) use integer handles that reference internal FCBs. We will use the modern Handle approach for the API to simplify external program development.
- **C64 Mapping**: A DOS "Handle" will map internally to a C64 "Logical File Number" (LFN). The OS will track which LFNs are active and map them to physical device 8 (or the current active device).

## Verification Plan
- Build the modified shell.
- Create a test text file on the disk image.
- Use the new `TYPE` command to read and display the text file.
- Verify that opening a non-existent file gracefully returns an error.
- Create an integration test program (`tests/src/filetest.asm`) that opens, reads, and closes a file using the Service Bus.

## Progress
- [x] Initialize Phase 3 plan
- [ ] Define FCB structure and Handle Table memory layout
- [ ] Implement `DOS_OPEN_FILE`
- [ ] Implement `DOS_READ_FILE`
- [ ] Implement `DOS_CLOSE_FILE`
- [ ] Implement `TYPE` internal command
