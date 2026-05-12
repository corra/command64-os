# Session Memory

## Project Documentation
- `GEMINI.md`: Core directives and protocols
- `brain/KNOWLEDGE.md`: Architectural decisions and technical findings
- `brain/MEMORY.md`: Session state and task tracking (this file)
- `brain/COMMANDS.md`: Internal command status and priority
- `brain/EXTERNAL.md`: External program status and priority
- `brain/task.md`: Granular task list

## Current State (2026-05-11)
- Phase 2A, 2B, 2C, and 2D complete (2D = INT 21h BRK service bus).
- Phase 3 complete (File System Integration).
- **Handle-based I/O**: Implemented modern MS-DOS style handle system. Maps handles 0-7 to C64 LFNs 2-9.
- **Service Bus**: Extended Jump Table to support `DOS_OPEN_FILE` ($3D), `DOS_CLOSE_FILE` ($3E), `DOS_READ_FILE` ($3F), and `DOS_WRITE_FILE` ($40).
- **Internal Commands**: Added `TYPE` and `COPY` commands.
- **Version**: 0.2.10 (Build 2403), Stage 4.
- **Verification**: `build/command64.prg` and all test binaries assemble cleanly. `COPY` and `TYPE` fully functional with correct KERNAL API register usage.

## Memory Map (current — as of Build 2403)
| Region | Purpose |
|--------|---------|
| `$033C` | CommandBuffer (80 bytes, Cassette Buffer) |
| `$038C` | CommandLen (1 byte) |
| `$038D` | SpecificLoad flag (1 byte) |
| `$038E-$039D` | HandleTable (16 bytes, 8 entries) |
| `$03A0-$03CF` | SourceBuf (48 bytes, COPY command) |
| `$03D0-$03FF` | DestBuf (48 bytes, COPY command) |
| `$0801` | BASIC SYS launcher (Main segment) |
| `$1000` | ApiStub (Stable OS Entry Point — `JMP apiHandler`) |
| `$1040` | Petsci (petPrintString, petPrintChar macro) |
| `$1100` | CommandTable (8-byte fixed-width entries) |
| `$1200` | CommandShell (main loop, dispatcher, built-ins) |
| `$1800` | Api (INT 21h Jump Table service bus — `api.asm`) |
| `$1900` | Utils (parseHex, normalizeName, printDecimal16) |
| `$1A80` | Loader (shellLoadPrg) |
| `$1B00` | Path (findFile, checkExistence) |
| `$1C00` | Vmm (vmmInit, vmmAlloc, vmmFree, vmmRead/WriteByte) |
| `$1E00` | File (Handle-based I/O — `file.asm`) |
| `$1F80` | VmmData (vmmInitialized, vmmTempByte, fileScratch) |
| `$2000+` | UserProgStart (External commands loaded here) |
| `$C000–$CFFF` | VMM MCT (4KB Page Byte-Map, 16MB support) |
| `$FB–$FE` | Zero-page: PrintPtrLo/Hi, NamePtrLo/Hi (User Safe) |
| `$61–$6C` | Zero-page: HandlerVec, ParsePos, Temp, HexVal, VmmSeg/Off/Bank (FAC1) |
| `$6D` | Zero-page: FileHandle (Active API Handle) |
| `$6E-$6F` | Zero-page: SrcHandle, DstHandle (Shell Scratch) |
| `$02` | Zero-page: CmpBase (User Safe) |

## C64 Hardware Gotchas (hard-won)
- **Segment Overlaps**: Proactive realignment of segments (64-byte padding) required as shell code grows.
- **BRK Trap Model is non-viable** for high-level OS calls on C64 due to KERNAL non-reentrancy.
- **Handle LFNs**: Use LFN 2-9 for handles to avoid conflict with LFN 1 used by program loader.
- **BASIC warm start = `jmp $E37B`** — not `jmp ($0338)`.
- **KA `.text` maps lowercase ASCII → PETSCII control codes** — send `$0E` at startup for mixed-case.

## Pending Tasks
- [ ] Environment variable support
- [ ] Implement `COPY` command (Shell integration complete, but needs verification)
