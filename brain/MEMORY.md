# Session Memory

## Project Documentation
- `GEMINI.md`: Core directives and protocols
- `README.md`: Project overview and quick start
- `docs/user-manual.md`: Comprehensive usage guide (the "whole shebang")
- `brain/KNOWLEDGE.md`: Architectural decisions and technical findings
- `brain/MEMORY.md`: Session state and task tracking (this file)
- `brain/COMMANDS.md`: Internal command status and priority
- `brain/EXTERNAL.md`: External program status and priority
- `brain/task.md`: Granular task list

## Current State (2026-05-13)
- Phase 2A, 2B, 2C, and 2D complete (2D = INT 21h BRK service bus).
- Phase 3 complete (File System Integration).
- **Phase 4 Code Review Remediation**: Full multi-agent review completed; all fixes implemented in Build 2414/1011.
- **Handle-based I/O**: Implemented modern MS-DOS style handle system. Maps handles 0-7 to C64 LFNs 2-9.
- **Service Bus**: Extended Jump Table to support `DOS_OPEN_FILE` ($3D), `DOS_CLOSE_FILE` ($3E), `DOS_READ_FILE` ($3F), `DOS_WRITE_FILE` ($40), `DOS_DELETE_FILE` ($41), and `DOS_RENAME_FILE` ($56).
- **Internal Commands**: Added `TYPE`, `COPY`, `DEL`, `ERASE`, `REN`, and `RENAME`.
- **Version**: 0.2.21 (command64 Build 2414, Stage 15) / DEBUG 0.1.4 (Build 1012, Stage 4).
- **Verification**: Both `build/command64.prg` and `build/debug.prg` assemble cleanly. Unified build system (`Makefile`) implemented and verified.
- **Documentation**: Synchronized `COMMANDS.md`, `EXTERNAL.md`, and `KNOWLEDGE.md` with current codebase state.
- **External Programs**: `DEBUG.PRG` (v0.1.4 Build 1012) — dispatch case-sensitivity fixed, hex parsing handles SHIFT+letter A-F, verMsg deduplicated, cuOpRel ZP alias fixed (U command now correct for relative branches), parseList buffer overflow fixed (65+ byte lists now return error).

## Memory Map (current — as of Build 2410)
| Region | Purpose |
|--------|---------|
| `$033C` | CommandBuffer (80 bytes, Cassette Buffer) |
| `$038C` | CommandLen (1 byte) |
| `$038D` | SpecificLoad flag (1 byte) |
| `$038E-$039D` | HandleTable (16 bytes, 8 entries) |
| `$039E` | CurrentDevice (1 byte) |
| `$039F-$03A0` | EnvSegmentLo/Hi (2 bytes) |
| `$03A1` | EnvBank (1 byte) |
| `$03A2-$03C9` | SourceBuf (40 bytes, COPY command) |
| `$03CA-$03F1` | DestBuf (40 bytes, COPY command) |
| `$0801` | BASIC SYS launcher (Main segment) |
| `$0C00` | Utils (parseHex, normalizeName, printDecimal16) |
| `$1000` | ApiStub (Stable OS Entry Point — `JMP apiHandler`) |
| `$1040` | Petsci (petPrintString, petPrintChar macro) |
| `$1080` | CommandTable (8-byte fixed-width entries) |
| `$1180` | CommandShell (main loop, dispatcher, built-ins) |
| `$1900` | Api (INT 21h Jump Table service bus — `api.asm`) |
| `$1A00` | Loader (shellLoadPrg) |
| `$1A80` | Path (findFile, checkExistence) |
| `$1B80` | Vmm (vmmInit, vmmAlloc, vmmFree, vmmRead/WriteByte) |
| `$1D80` | File (Handle-based I/O — `file.asm`) |
| `$1F90` | VmmData (vmmInitialized, vmmTempByte, fileScratch) |
| `$2000+` | UserProgStart (External commands loaded here) |
| `$C000–$CFFF` | VMM MCT (4KB Page Byte-Map, 16MB support) |
| `$FB–$FE` | Zero-page: PrintPtrLo/Hi, NamePtrLo/Hi (User Safe) |
| `$61–$6C` | Zero-page: HandlerVec, ParsePos, Temp, HexVal, VmmSeg/Off/Bank (FAC1) |
| `$6D` | Zero-page: FileHandle (Active API Handle) |
| `$6E-$6F` | Zero-page: SrcHandle, DstHandle (Shell Scratch) |
| `$70-$7F` | Zero-page: DEBUG Pointers (External Utility) |
| `$02` | Zero-page: CmpBase (User Safe) |

## C64 Hardware Gotchas (hard-won)
- **Segment Overlaps**: Proactive realignment of segments (64-byte padding) required as shell code grows.
- **BRK Trap Model is non-viable** for high-level OS calls on C64 due to KERNAL non-reentrancy.
- **Handle LFNs**: Use LFN 2-9 for handles. LFN 13=cmdDir, LFN 14=checkExistence, LFN 15=command channel. Never use LFN 2 for built-in commands.
- **BASIC warm start = `jmp $E37B`** — not `jmp ($0338)`.
- **KA `.text` maps lowercase ASCII → PETSCII control codes** — send `$0E` at startup for mixed-case.
- **KernalGetIn ($FFE4) clobbers Y**: Always preserve Y across keyboard polling loops.
- **PETSCII lowercase mode dispatch**: Use `ora #$20` (not `and #$7F`) to normalize unshifted keys ($41-$5A) to lowercase ($61-$7A). `and #$7F` produces $01-$1A which matches nothing.
- **ahExit stack discipline**: Each program run orphans 4 bytes (jsr UserProgStart + jsr $1000). Always reset SP=`#$FF` in `ahExit` before `jmp mainLoop`.

## Pending Tasks
- [x] Implement `DEBUG` Unassemble (U) command (Disassembler)
- [ ] Implement `DRIVE` command
- [ ] Add support for multiple devices (8, 9, 10, 11)
- [ ] Support subdirectories (1581 / SD2IEC)
- [ ] Environment variable storage (`SET`, `PATH`) in REU
