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

## Current State (2026-06-25)
- Phase 2A, 2B, 2C, and 2D complete (2D = INT 21h BRK service bus).
- Phase 3 complete (File System Integration).
- Phase 4 complete (DEBUG external utility, code review + remediation done Build 1016).
- Phase 5: DRIVE/multi-device, Environment (`SET`/`PATH`) complete.
- Project Infrastructure: Taskwarrior tasks initialized, Codebase Memory indexed, Code Wiki created.
- **CMake Migration**: Build system migrated to CMake with clean source imports, cross-platform build counters, and a root Makefile proxy wrapper.
- **Version**: 0.2.22 (command64 Build 2442, Stage 15) / DEBUG 0.1.4 (Build 1021).
- **Verification**: Both `build/command64.prg` and `build/debug.prg` assemble cleanly via CMake and match Makefile output byte-for-byte.

## Phase 6A — App Manager (next up)

### Superpowers Artifacts
| Artifact | Path |
|----------|------|
| Design spec | `docs/superpowers/specs/2026-05-13-app-manager-design.md` |
| Phase A plan | `docs/superpowers/plans/2026-05-13-app-manager-phase-a.md` |

### What Phase A delivers (11 tasks, ~$350 bytes of new code)
- New segment `AppTable` at `$2000`; `UserProgStart` shifts from `$2000` → `$2200`.
- `apptable.asm`: `aptInit`, `aptProtectedCheck`, `aptSlotBase`, `aptNameMatch`, `aptFind`, `aptRegister`, `aptRemove`, `aptList`, `aptPrintHex8`.
- `LOAD` gated: protected-address check ($0000–$21FF, $C000–$FFFF) + table-full check before disk I/O; registers entry on success.
- `RUN`/`GO` gated: requires app table membership; supports `RUN <name>` and `RUN <addr>`.
- New commands: `APPS`/`PS` (list loaded programs), `FREE` (remove entry, guards APP_RUNNING).
- `debug.asm` and all `tests/src/*.asm` compile address moved from `$2000` → `$2200`.

### Key implementation details
- App table stored in VMM: 1 page (4 KB), segment saved in `AptSegLo/Hi` ($03F2–$03F3).
- Entry stride 40 bytes × 16 slots + 4-byte header = 644 bytes total (fits in 1 VMM page).
- `vmmReadByte`/`vmmWriteByte` clobbers `TempLo/Hi` and `Y`; preserves `X` and `VmmOffLo/Hi`.
- `aptRegister` calling convention: `NamePtrLo/Hi` + `SrcHandle` = name, `HexValLo/Hi` = load addr, `TempLo/Hi` = KernalLOAD end+1 return.
- `aptFind` calling convention: carry clear = name mode (`NamePtrLo/Hi`, `SrcHandle`); carry set = address mode (`HexValLo/Hi`). Returns X = slot index, `HandlerVecLo/Hi` = LoadAddr on found.
- Phases B and C extend `apptable.asm` without changing the API surface.

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
| `$03F2-$03F3` | AptSegLo/Hi (App Table VMM segment, allocated by aptInit at startup) |
| `$2000-$21FF` | AppTable segment (apptable.asm — 512 bytes reserved) |
| `$2200+` | UserProgStart (External commands loaded here — shifted from $2000 by Phase 6A) |
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
- [x] DEBUG code review + remediation (Build 1012 — cuOpRel ZP alias, parseList overflow)
- [ ] **Execute App Manager Phase A** — plan at `docs/superpowers/plans/2026-05-13-app-manager-phase-a.md`
- [ ] Binary Relocator (Phase 6B prerequisite)
- [ ] Implement `DRIVE` command
- [ ] Add support for multiple devices (8, 9, 10, 11)
- [ ] Support subdirectories (1581 / SD2IEC)
- [ ] Environment variable storage (`SET`, `PATH`) in REU

## Superpowers Docs Index
| Document | Path |
|----------|------|
| App Manager design | `docs/superpowers/specs/2026-05-13-app-manager-design.md` |
| App Manager Phase A plan | `docs/superpowers/plans/2026-05-13-app-manager-phase-a.md` |
| DEBUG remediation plan | `docs/superpowers/plans/2026-05-13-debug-asm-zp-alias-and-listbuf-overflow.md` |
| Unified build system design | `docs/superpowers/specs/2026-05-13-unified-build-system-design.md` |
| Unified build system plan | `docs/superpowers/plans/2026-05-13-unified-build-system.md` |
