# Knowledge Base

This file serves as the shared repository for architectural decisions, technical findings, and project-specific "gotchas" discovered during the porting of MS-DOS 4.0 to the Commodore 64.

## Architectural Decisions

| Date | Decision | Rationale | Status |
| :--- | :--- | :--- | :--- |
| 2026-05-01 | C64 Ultimate with REU | Target upgraded from stock C64 to C64 Ultimate specifically because it provides an REU (1MB–16MB) to adequately support the 1MB logical address space model of MS-DOS. | Active |
| 2026-05-01 | Service Bus Model | Adopted over a monolithic kernel. The C64 KERNAL operates as a collection of system routines, and GEOS-era OSes were essentially shells rather than full kernel replacements. DOS components (`IO.SYS`, `MSDOS.SYS`, `COMMAND.COM`) are modularized as coordinated services. | Active |
| 2026-05-01 | PETSCII as Character Standard | C64 uses PETSCII (Hex 00–FF), not ASCII. All character I/O, filenames, and messaging route through a PETSCII abstraction layer. | Active |
| 2026-05-01 | VMM and RAL as Constitutional Pillars | Virtual Memory Manager (VMM) and Register Abstraction Layer (RAL) are mandatory because the 8086's segmented memory architecture and rich register set do not exist on the 6502. The port treats the entire OS as an emulation layer, not a direct translation. | Active |
| 2026-05-01 | Kick Assembler | Selected for 6502 assembly support. | Active |
| 2026-05-01 | Oscar64 | Selected as the C compiler for C64 target. | Active |

## Technical Findings

- **[2026-05-01] Workspace Initialization**: Successfully established the PRAR-compliant state management structure.
- **[2026-05-01] Boot Architecture Divergence**: PC boot is modular/sequential (MBR → IO.SYS → MSDOS.SYS → COMMAND.COM). C64 boot is minimalist/direct from fixed ROM (`*$0801`). Ported system must *emulate the effect* of structured handoffs through explicit initialization in the Service Bus, not actually take over boot ROM.
- **[2026-05-01] Component Analogy Mapping**:
  - `IO.SYS` → **File System Service API** (raw disk I/O, memory allocation, device routing)
  - `MSDOS.SYS` → **VMM + PETSCII Service Layer** (system calls, memory mapping, character encoding, process control)
  - `COMMAND.COM` → **System Shell Emulator** (command parsing, command registry, execution handover, prompt management)
- **[2026-05-01] Port Scope Definition**: "Mostly functional port," not a 1:1 replica. Features may be omitted with explicit justification documented here.
- **[2026-05-01] Source Code Structure**: Core modules in `v4.0/src/MAPPER/` (file I/O primitives) and `v4.0/src/DOS/` (system services). Internal commands are embedded in `v4.0/src/CMD/COMMAND/TCMD*.ASM`.
- **[2026-05-01] MAPPER Disassembly Findings**: `EXIT.ASM` (58 lines), `DELETE.ASM` (70 lines), and `MKDIR.ASM` (53 lines) are the simplest modules. They follow a strict 8-15 instruction wrapper pattern around INT 21h calls with only `MACROS.INC` as a dependency.
- **[2026-05-01] COMMAND.COM Core Logic**: The core dispatcher logic resides in `TCODE.ASM` (400+ lines). It reads input via `STD_CON_STRING_INPUT`, preprocesses it (`PRESCAN`), parses it (`PARSERINE`), and dispatches it to internal commands or initiates a file search (`PATH_SEARCH` for external commands).
- **[2026-05-01] C64 KERNAL Integration**: C64 KERNAL routines (e.g., `CHROUT`, `CHRIN`, `LOAD`, `SAVE`, `VERIFY`) will serve as the foundational building blocks for our PETSCII and I/O abstractions.

## Phase 2 Status — Phase 2B COMPLETE (2026-05-09)

| Task | Status |
| :--- | :--- |
| Phase 2A: Core Dispatcher | ✅ Done |
| Raw GETIN input loop | ✅ Done (Fixes quote mode) |
| Phase 2B: External Commands | ✅ Done |
| Path search & auto-.prg | ✅ Done |
| Binary loader ($2000+) | ✅ Done |
| Phase 2B Verification | ✅ Done (Pre-verified image.d64) |
| VMM API (`include/vmm.inc`) | ⏳ Pending (Phase 2C) |

## C64 Platform Constraints Discovered

| Finding | Impact | Resolution |
| :--- | :--- | :--- |
| `$0300–$033B` = KERNAL/BASIC vector table | CommandBuffer at $0300 corrupts IRQ ($0314) and CHROUT ($0326) on any input | Relocated CommandBuffer to `$1400` |
| CHRIN ($FFCF) goes through screen editor (BASIN) | Screen editor already echoes typed chars; manual re-echo garbles display | Removed echo CHROUT from shellReadLine |
| KA `.text` maps lowercase ASCII → PETSCII control codes $01–$1A | Strings like "Bad command" render as garbage in default C64 char mode | Added `lda #$0E` at startup to enter lowercase/uppercase display mode |
| KA bare `name = value` is invalid syntax | Build fails; all equates require `.label name = value` | Converted all equates to `.label` |
| KA macros require `()` in definition | Build fails without `()`: `.macro Foo() {` | Fixed macro definitions |
| cmdCompare X-register walk bug | All 3 commands dispatched to wrong addresses; crash on every command | Redesigned cmdCompare: X = immutable entry base via `CmpBase` ZP var |
| `jmp ($0338)` for EXIT | $0338 is not a BASIC warm start vector; hangs or crashes | Changed to `jmp $E37B` (BASIC ROM warm start) |
| C64 screen editor "quote mode" | `"` in input causes cursor keys to insert control codes | Known limitation; requires GETIN polling loop to fix |
| `KernalGetIn ($FFE4)` may clobber Y | Any input loop using Y as a buffer index will silently corrupt it across `GETIN` calls, causing characters stored at wrong offsets | Always push/pop Y around `jsr KernalGetIn`: `tya/pha … jsr KernalGetIn … pla/tay`. See `shellReadLine` in `shell.asm` for the canonical pattern. |
