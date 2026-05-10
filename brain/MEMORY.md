# Session Memory

## Project Documentation
- `GEMINI.md`: Core directives and protocols
- `brain/KNOWLEDGE.md`: Architectural decisions and technical findings
- `brain/MEMORY.md`: Session state and task tracking (this file)
- `brain/COMMANDS.md`: Internal command status and priority
- `brain/EXTERNAL.md`: External program status and priority
- `brain/task.md`: Granular task list

## Current State (2026-05-09)
- Phase 2A, 2B, and 2C complete.
- **Version**: 0.2.3 (Build 2300).
- **VMM**: 16MB supported via 4KB Page Byte-Map at `$C000`. `vmmInit`, `vmmAlloc`, `vmmFree` implemented.
- **Stability**: Fixed inverted `LOAD` secondary address mapping.
- **Stability**: Shell isolated via Cassette Buffer (`$033C`) and safe Zero Page remapping (`$FB-$FE`, `$61-$6C`).
- **Input**: Migrated to raw `GETIN` loop; quote-mode issues resolved.
- **Verification**: Internal commands (`CLS`, `VER`, `HELP`, `ECHO`, `EXIT`) and memory stability verified.

## Memory Map (current)
| Region | Purpose |
|--------|---------|
| `$033C` | CommandBuffer (192 bytes, Cassette Buffer) |
| `$0801` | BASIC SYS launcher |
| `$1100` | Command table |
| `$1200` | CommandShell code |
| `$1500` | Utils (parseHex, normalizeName) |
| `$1580` | Loader (shellLoadPrg) |
| `$1600` | Path (findFile, checkExistence) |
| `$1700` | VMM Core Primitives |
| `$1A00` | VmmData (Temporary storage) |
| `$2000+` | UserProgStart (External commands) |
| `$C000` | VMM MCT (4KB Byte-Map) |
| `$FB–$FE` | Zero-page: PrintPtrLo/Hi, NamePtrLo/Hi (User Safe) |
| `$61–$6C` | Zero-page: HandlerVec, ParsePos, Temp, HexVal, Vmm pointers (FAC1) |
| `$02` | Zero-page: CmpBase (User Safe) |

## C64 Hardware Gotchas (hard-won)
- **Page 3 ($0300–$033B) is KERNAL/BASIC vector table** — NEVER place buffers here.
- **BASIC warm start = `jmp $E37B`** — not `jmp ($0338)`.
- **CHRIN ($FFCF) = screen editor (BASIN)** — echoes chars itself; avoid for raw shells.
- **GETIN ($FFE4)** — non-blocking raw input; use polling loop for shell input.
- **KA `.text` maps lowercase ASCII → PETSCII control codes** — send `$0E` at startup for mixed-case.

## Pending Tasks
- [x] VMM API specification (`include/vmm.inc`)
- [ ] Implement VMM bank switching / segment management (`vmm.asm`)
- [ ] Plan Phase 2C scope

## Next Steps
1. Implement `vmmInit` and `vmmReadByte` / `vmmWriteByte` in `src/command64/vmm.asm`.
2. Implement basic VMM memory control table.
