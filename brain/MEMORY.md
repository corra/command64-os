# Session Memory

## Project Documentation
- `GEMINI.md`: Core directives and protocols
- `brain/KNOWLEDGE.md`: Architectural decisions and technical findings
- `brain/MEMORY.md`: Session state and task tracking (this file)
- `brain/COMMANDS.md`: Internal command status and priority
- `brain/EXTERNAL.md`: External program status and priority
- `brain/task.md`: Granular task list

## Current State (2026-05-11)
- Phase 2A, 2B, 2C, and 2D complete (2D = Service Bus).
- **Architecture Pivot**: Service Bus transitioned from `BRK` Trap to ** Jump Table** model (`JSR $1600`). This resolves critical stack corruption and re-entrancy issues with the KERNAL.
- **Remediation**: All code review remediation rounds (1, 2, and 3) are COMPLETE. Build 2308 is the current stable reference.
- **Version**: 0.2.6 (Build 2308), Stage 4.
- **VMM**: 16MB supported via 4KB Page Byte-Map at `$C000`. Full memory safety hardening complete (all entry points check `vmmInitialized`). Corrected 20-bit address math logic.
- **Service Bus**: `api.asm` Jump Table implemented at `$1600`. All confirmed bugs (A, B, E, J) resolved by the architectural pivot and logic fixes.
- **Tests**: `apitest.asm` and `vmmtest.asm` updated to use `JSR $1600` ABI. Explicit lowercase mode initialization added.
- **Verification**: `build/command64.prg` and all test binaries assemble cleanly.

## Memory Map (current — as of Build 2308)
| Region | Purpose |
|--------|---------|
| `$033C` | CommandBuffer (192 bytes, Cassette Buffer) |
| `$038C` | CommandLen (1 byte) |
| `$038D` | SpecificLoad flag (1 byte) |
| `$0801` | BASIC SYS launcher (Main segment) |
| `$1000` | Petsci (petPrintString, petPrintChar macro) |
| `$1100` | CommandTable (8-byte fixed-width entries) |
| `$1200` | CommandShell (main loop, dispatcher, built-ins) |
| `$1600` | Api (INT 21h Jump Table service bus — `api.asm`) |
| `$1700` | Utils (parseHex, normalizeName, printDecimal16) |
| `$1800` | Loader (shellLoadPrg) |
| `$1880` | Path (findFile, checkExistence) |
| `$1980` | Vmm (vmmInit, vmmAlloc, vmmFree, vmmRead/WriteByte) |
| `$1C80` | VmmData (vmmInitialized, vmmTempByte) |
| `$2000+` | UserProgStart (External commands loaded here) |
| `$C000–$CFFF` | VMM MCT (4KB Page Byte-Map, 16MB support) |
| `$FB–$FE` | Zero-page: PrintPtrLo/Hi, NamePtrLo/Hi (User Safe) |
| `$61–$6C` | Zero-page: HandlerVec, ParsePos, Temp, HexVal, VmmSeg/Off/Bank (FAC1) |
| `$02` | Zero-page: CmpBase (User Safe) |

## C64 Hardware Gotchas (hard-won)
- **BRK Trap Model is non-viable** for high-level OS calls on C64 due to KERNAL non-reentrancy.
- **Page 3 ($0300–$033B) is KERNAL/BASIC vector table** — NEVER place buffers here.
- **BASIC warm start = `jmp $E37B`** — not `jmp ($0338)`.
- **CHRIN ($FFCF) = screen editor (BASIN)** — echoes chars itself; avoid for raw shells.
- **GETIN ($FFE4)** — non-blocking raw input; use polling loop for shell input.
- **KA `.text` maps lowercase ASCII → PETSCII control codes** — send `$0E` at startup for mixed-case.

## Pending Tasks
- [ ] Phase 3: File System (INT 21h extensions)
- [ ] Environment variable support

## Next Steps
1. Verify Build 2308 stability in VICE.
2. Begin Phase 3 architecture: design the File Control Block (FCB) and Handle-based I/O mapping.
