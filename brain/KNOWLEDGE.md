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
| 2026-06-25 | Code Wiki & Project Tooling | Created structured code wiki under wiki/, corrected child DOX index paths, and initialized Taskwarrior + Codebase Memory. | Active |

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

## Current Status — Build 2436 / Stage 15 (2026-06-25)

| Task | Status |
| :--- | :--- |
| Phase 2A: Core Dispatcher | ✅ Done |
| Phase 2B: External Commands | ✅ Done |
| Phase 2C: Virtual Memory Manager (VMM) | ✅ Done |
| Phase 2D: Service Bus & VMM Stabilizing | ✅ Done |
| Phase 3: File System Integration (Handles) | ✅ Done |
| Phase 4: External System Utilities (DEBUG) | ✅ Done |
| Phase 5: Env & Multi-Device Support | ⏳ In-Progress (Taskwarrior & Wiki setup done) |
| Phase 6A: App Manager (Phase A) | ✅ Done |
| Phase 6B: Binary Relocator | ✅ Done |

## Architectural Decisions & Constraints

### Absolute vs. Relocatable Binaries
- **Constraint**: External programs are compiled for `$2600` (UserProgStart) by default.
- **Relocation**: In Phase 6B, a **Binary Relocator** (`aptRelocate` in `loader.asm`) is implemented. Relocatable apps are compiled twice at a 1-page offset, and post-processed by `tools/reloc.py` to append a relocation table and a 6-byte footer (`BaseAddr`, `TableSize`, `'R'`,`'6'`).
- **Execution**: The OS loader automatically detects this footer, patches all absolute high-bytes in-place to run at the target load page (e.g. `LOAD debug $4000`), and truncates the registered size to exclude the table. Non-relocatable binaries fall back to being registered as-is with original bounds preserved.

### App Table (Phase 6A — Completed)
- **Segment**: `AppTable` at `$2000`–`$235C`. Consecutively followed by `ShellExt` segment at `$235D`–`$24ED` (storing help/version string blocks).
- **UserProgStart**: Shifted from `$2000` → `$2600` to leave memory headroom for OS expansion.
- **Storage**: VMM-allocated 4 KB page (one `vmmAlloc` call at shell startup). Segment number saved in `AptSegLo/Hi` at `$03F2`–`$03F3` (cassette buffer free area).
- **Layout**: 4-byte header (MaxSlots=16, UsedSlots, reserved×2) + 16 entries × 40 bytes = 644 bytes total.
- **Entry offsets**: Flags=0, Name=1 (16 bytes PETSCII null-padded), LoadAddr=17 (lo/hi), Size=19 (lo/hi). Offsets 21–39 reserved for Phase B/C (ReuAddr, saved CPU state).
- **Protected ranges for LOAD**: Reject if address < `UserProgStart` or >= `$C000`.
- **API**: Internal 6502 labels (`aptInit`, `aptFind`, `aptRegister`, `aptRemove`, `aptList`, `aptPrintHex8`).
- **Phase progression**: A = fixed `$2600` entry; B = Binary Relocator patches binary at arbitrary address; C = REU-resident with DMA swap on RUN.
- **Design spec**: `docs/superpowers/specs/2026-05-13-app-manager-design.md`.

### Master Environment Block
- **Storage**: Allocated in the REU via `vmmAlloc` (4KB / 1 page) during shell initialization.
- **Format**: MS-DOS standard double-null terminated strings (`VAR1=VAL1\0VAR2=VAL2\0\0`).
- **Access**: Managed via the `SET` and `PATH` internal commands. External programs can access it via the VMM API.

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
