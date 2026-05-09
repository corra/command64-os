# Session Memory

## Project Documentation
- `GEMINI.md`: Core directives and protocols
- `brain/KNOWLEDGE.md`: Architectural decisions and technical findings
- `brain/MEMORY.md`: Session state and task tracking (this file)
- `brain/COMMANDS.md`: Internal command status and priority
- `brain/EXTERNAL.md`: External program status and priority
- `brain/task.md`: Granular task list

## Current State (2026-05-08)
- Phase 2A complete; build verified on hardware.
- `brain/COMMANDS.md` and `brain/EXTERNAL.md` created to track system evolution.
- Stability fixes: Y-register clobbering and GETIN polling resolved.
- Build command: `java -jar tools/KickAss.jar build/command64.asm` (outputs to `build/`)
- Ready for Phase 2B (External Commands & Loader).

## Memory Map (current)
| Region | Purpose |
|--------|---------|
| `$0801` | BASIC SYS launcher (BasicUpstart2 → `$1200`) |
| `$1000` | Petsci segment (empty — macros inline into CommandShell) |
| `$1100` | Command table (fixed-width: 3 entries × 8 bytes) |
| `$1200` | CommandShell code (~$130 bytes, ends ~$1330) |
| `$1400` | CommandBuffer (79 data bytes + null at `$144F`) |
| `$1450` | CommandLen (1 byte) |
| `$FB–$FE` | Zero-page scratch: PrintPtrLo/Hi, HandlerVecLo/Hi |
| `$F9–$FA` | Zero-page scratch: ParsePos, CmpBase |

## C64 Hardware Gotchas (hard-won)
- **Page 3 ($0300–$033B) is KERNAL/BASIC vector table** — NEVER place buffers here
  - `$0302/$0303` = IMAIN (BASIC warm start)
  - `$0314/$0315` = IRQ handler — overwrite this → crash on next timer tick
  - `$0326/$0327` = BSOUT (CHROUT indirect) — overwrite → output breaks
- **BASIC warm start = `jmp $E37B`** — not `jmp ($0338)`, not any Page 3 vector
- **CHRIN ($FFCF) = screen editor (BASIN)** — echoes chars itself; never manually CHROUT them again
- **KA `.text` maps lowercase ASCII ($61-$7A) → PETSCII $01–$1A** — send `$0E` at startup to enter lowercase display mode so these render as letters
- **KA syntax**: `.label name = value` (bare `name = value` is invalid); macros need `()` in definition
- **cmdCompare pattern**: X = immutable entry base; read table as `tableCmd[CmpBase+Y]`; restore X=CmpBase on fail; set X=CmpBase+TABLE_NAME_LEN on match — do not walk X during comparison
- **C64 screen editor quote mode**: `"` puts editor in mode where cursor keys insert PETSCII control codes instead of moving cursor; only fixable by switching from CHRIN to raw GETIN polling

## Pending Tasks
- [ ] Raw GETIN input loop (replaces CHRIN) — fixes quote mode, gives full input control
- [ ] VMM API specification (`include/vmm.inc`)
- [ ] Phase 2B planning: external command support, PATH search

## Next Steps
1. Decide: accept CHRIN limitations or rewrite shellReadLine with GETIN polling loop
2. Define VMM ABI headers in `include/vmm.inc`
3. Plan Phase 2B scope
