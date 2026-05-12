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
- **Stable API Entry**: Implemented a fixed Jump Table Stub at `$1000`. All external programs should now `JSR $1000`.
- **Handle-based I/O**: Implemented modern MS-DOS style handle system. Maps handles 0-7 to C64 LFNs 2-9.
- **Service Bus**: Extended Jump Table to support `DOS_OPEN_FILE` ($3D), `DOS_CLOSE_FILE` ($3E), and `DOS_READ_FILE` ($3F).
- **Internal Commands**: Added `TYPE` command to display file contents using the new DOS API.
- **Version**: 0.2.6 (Build 2311), Stage 4.
- **Verification**: `build/command64.prg` and all test binaries assemble cleanly. Segment overlaps resolved.

## Memory Map (current — as of Build 2311)
| Region | Purpose |
|--------|---------|
| `$033C` | CommandBuffer (80 bytes, Cassette Buffer) |
| `$038C` | CommandLen (1 byte) |
| `$038D` | SpecificLoad flag (1 byte) |
| `$038E-$039D` | HandleTable (16 bytes, 8 entries) |
| `$0801` | BASIC SYS launcher (Main segment) |
| `$1000` | ApiStub (Stable OS Entry Point — `JMP apiHandler`) |
| `$1040` | Petsci (petPrintString, petPrintChar macro) |
| `$1100` | CommandTable (8-byte fixed-width entries) |
| `$1200` | CommandShell (main loop, dispatcher, built-ins) |
| `$1680` | Api (INT 21h Jump Table service bus — `api.asm`) |
| `$1780` | Utils (parseHex, normalizeName, printDecimal16) |
| `$1880` | Loader (shellLoadPrg) |
| `$1900` | Path (findFile, checkExistence) |
| `$1A00` | Vmm (vmmInit, vmmAlloc, vmmFree, vmmRead/WriteByte) |
| `$1C00` | File (Handle-based I/O — `file.asm`) |
| `$1D80` | VmmData (vmmInitialized, vmmTempByte) |
| `$2000+` | UserProgStart (External commands loaded here) |
| `$C000–$CFFF` | VMM MCT (4KB Page Byte-Map, 16MB support) |
| `$FB–$FE` | Zero-page: PrintPtrLo/Hi, NamePtrLo/Hi (User Safe) |
| `$61–$6C` | Zero-page: HandlerVec, ParsePos, Temp, HexVal, VmmSeg/Off/Bank (FAC1) |
| `$02` | Zero-page: CmpBase (User Safe) |

## C64 Hardware Gotchas (hard-won)
- **Segment Overlaps**: Proactive realignment of segments (64-byte padding) required as shell code grows.
- **BRK Trap Model is non-viable** for high-level OS calls on C64 due to KERNAL non-reentrancy.
- **Handle LFNs**: Use LFN 2-9 for handles to avoid conflict with LFN 1 used by program loader.
- **BASIC warm start = `jmp $E37B`** — not `jmp ($0338)`.
- **KA `.text` maps lowercase ASCII → PETSCII control codes** — send `$0E` at startup for mixed-case.

## Pending Tasks
- [ ] Environment variable support
- [ ] Implement `DOS_WRITE_FILE` ($40)
- [ ] Implement `COPY` command
