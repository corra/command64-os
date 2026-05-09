# Session Memory

## Project Documentation
- `GEMINI.md`: Core directives and protocols
- `brain/KNOWLEDGE.md`: Architectural decisions and technical findings
- `brain/MEMORY.md`: Session state and task tracking (this file)
- `brain/COMMANDS.md`: Internal command status and priority
- `brain/EXTERNAL.md`: External program status and priority
- `brain/task.md`: Granular task list

## Current State (2026-05-09)
- Phase 2A and 2B complete; external command support verified via `tests/image.d64`.
- Input: `shellReadLine` migrated to raw `GETIN` polling loop (fixes quote mode).
- Memory: `CommandBuffer` moved to `$1600` for increased shell headroom.
- Zero Page variables moved to `$22–$2D` (Kernal-safe range).
- Ready for Phase 2C (VMM).

## Memory Map (current)
| Region | Purpose |
|--------|---------|
| `$0801` | BASIC SYS launcher (BasicUpstart2 → `$1200`) |
| `$1100` | Command table (fixed-width entries) |
| `$1200` | CommandShell code |
| `$1450` | Utils (parseHex, normalizeName) |
| `$14C0` | Loader (shellLoadPrg) |
| `$1510` | Path (findFile, checkExistence) |
| `$1600` | CommandBuffer (79 data bytes + null) |
| `$2000+` | UserProgStart (External command execution area) |
| `$22–$2F` | Zero-page pointers & scratch |

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
