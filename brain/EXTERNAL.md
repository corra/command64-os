# MS-DOS Port: External Program Registry

This document tracks the status and priority of external programs (.COM / .EXE) planned for the `command64` environment. These utilities are loaded into the User Program Space at `UserProgStart` (currently `$3800`, relocation partner `$3900`); R6-relocatable external commands are relocated before name-based execution.

## 1. High Priority (Phase 2B / 2C / 4)
These programs are essential for system maintenance and early verification of the binary loader.

| Program | Description | Status | Priority | Origin |
|:---|:---|:---|:---|:---|
| `CHKDSK` | Check disk status and memory usage | 📅 Planned | High | DOS 4.0 |
| `DEBUG` | Hex editor and assembly debugger | ✅ v0.4.0 (Build 1109) | High | DOS 4.0 |
| `FORMAT` | Format C64 disks (via KERNAL wrappers) | ✅ v0.1.0 (Build 1011) | High | DOS 4.0 |
| `SYS` | Transfer system files to a disk | 📅 Planned | Medium | DOS 4.0 |

### DEBUG Roadmap

- **Phase 1 (Done)**: Core memory manipulation (D, E, F, M, C, S), Hex math, and Execution (G).
- **Phase 2 (Done)**: I/O port commands (I, O), Length syntax (L), and Register modification (R).
- **Phase 3 (Mid-term)**: VMM/EMS integration (XA, XM, XS) and Banked addressing (BANK:OFF).
- **Phase 4 (Done)**: Disk management (N, L, W) and Disassembler (U).
- **ca65 migration (Done)**: builds from `src/external/debug/debug.s` via ca65/ld65.

## 2. Essential System Utilities
| Program | Description | Status | Priority | Origin |
|:---|:---|:---|:---|:---|
| `EDLIN` | Line-based text editor | ✅ v0.1.4 (Build 1033) | Medium | DOS 4.0 |
| `MEM` | Display memory allocation details | 💤 Backlog | Medium | DOS 4.0 |
| `MODE` | Configure system devices (Screen/Printer) | 💤 Backlog | Low | DOS 4.0 |
| `TREE` | Display directory structure | 💤 Backlog | Low | DOS 4.0 |
| `MORE` | Display output one screen at a time | ✅ Shipped as an **internal** shell command, not an external program — see `brain/COMMANDS.md` | Medium | DOS 4.0 |

## 3. File & Data Tools
| Program | Description | Status | Priority | Origin |
|:---|:---|:---|:---|:---|
| `XCOPY` | Extended file and directory copy | 💤 Backlog | Medium | DOS 4.0 |
| `FIND` | Search for a string in a file | 💤 Backlog | Low | DOS 4.0 |
| `SORT` | Sort input data | 💤 Backlog | Low | DOS 4.0 |
| `COMP` | Compare files as raw byte streams | ✅ v0.1.0 (Build 1004) — cross-device false size mismatch open, see `wiki/tasks/comp-cross-device-regression.md` | Low | DOS 4.0 |
| `FC` | File compare with binary/text options | 💤 Backlog | Low | DOS 4.0 |
| `ATTRIB` | Change file attributes | 💤 Backlog | Medium | DOS 4.0 |

## 4. Development & Advanced Tools
| Program | Description | Status | Priority | Origin |
|:---|:---|:---|:---|:---|
| `CASM` | Native 6502 assembler — assembles source to a runnable PRG on the C64 | ✅ v0.1.48 (Build 1191) — Phases 1-8 complete, Phase 9 (`.INCLUDE`) in progress | High | C64 |
| `EXE2BIN` | Convert .EXE to .BIN/.COM format | 💤 Backlog | Low | DOS 4.0 |
| `LINK` | MS-DOS Linker (Concept only for now) | 💤 Backlog | Low | DOS 4.0 |
| `PRINT` | Background printing service | 💤 Backlog | Low | DOS 4.0 |

## 5. C64-Specific External Utilities
| Program | Description | Status | Priority | Origin |
|:---|:---|:---|:---|:---|
| `LABEL` | Rename a disk volume label via BAM direct access | ✅ v0.4.0 (Build 1043) | High | C64 |
| `BANNER` | Render text in 5x6 block characters; native CASM source-compatibility reference | ✅ Build 1005 | Medium | C64 |
| `CONWAY` | Conway's Game of Life demo with presets and custom rules | ✅ v0.4.1 (Build 1061) | Low | C64 |
| `PACMAN` | Pac64 character-grid Pac-Man clone | 🚧 v0.1.9 (Build 1090) — in progress | Low | C64 |
| `SIDPLAY` | Play SID music files from DOS | 💡 Idea | Low | C64 |
| `REUCHECK`| Utility to verify REU/VMM status | 📅 Planned | High | C64 |
| `DISKMON` | Raw disk sector editor | 💡 Idea | Medium | C64 |
| `DVORAK` | Dvorak keyboard remap | ⛔ Parked (Build 1001) — known fundamental problems; deliberately not wired into the build | Low | C64 |
| `VI` | vi-like visual editor (Phase 6C) | 📅 Future — earlier implementation withdrawn after code review; source removed and target commented out at `CMakeLists.txt:269`. `BUILD_VI` (1015) is retained for the rework. `EDLIN` covers editing in the meantime. | Low | C64 |

## Disk Images

- **`image.d64`**: the standard OS image — OS plus the unconditionally shipped utilities.
- **`command64_casm_utils.d64`** (label `CASM UTILS`): carries `banner.prg` and its `banner.s` source as a SEQ file, for on-target reassembly with `CASM`.
- **`test.d64`** / **`casm_overflow_test.d64`**: test harnesses and CASM fixtures.

## Technical Implementation Notes

- **Loader Target**: Programs load at `UserProgStart` (currently `$3800`) but can be loaded anywhere using the `LOAD` command. R6-relocatable external commands are relocated before name-based execution.
- **Toolchain**: New external applications are built with ca65/ld65 via `add_ca65_app`; see `src/external/AGENTS.md`.
- **Auto-Search**: The shell automatically appends `.prg` and searches device 8 if an internal command is not found.
- **Case-Insensitive**: All external command searches are case-insensitive.
- **Termination**: External programs terminate by calling `DOS_EXIT` (`$4C`) through the OS Service Bus (`JSR $1000`) to return control to the `command64` shell.
- **I/O Redirection**: Standard Input/Output for these programs must route through the PETSCII API in `src/command64/petsci.asm`.

### DEBUG.PRG — Known Bugs & Remediation (Build 1011, 2026-05-13)

1. **Hex Parsing & Case Sensitivity** (Fixed):
   - **Remediation**: Correctly handle both uppercase/shifted and lowercase letters in hex parsing.

2. **Enter (E) Command Failure** (Fixed):
   - **Remediation**: Preserved Y register during memory writes.

3. **Dump (D) Width** (Fixed):
   - **Remediation**: Refactored to 8 bytes per line for 40-column display.

4. **Return Key UI** (Fixed):
   - **Remediation**: Advanced cursor correctly after RETURN.

5. **Register Preservation** (Fixed):
   - **Remediation**: KernalGetIn clobbering Y handled.

6. **Range Loop Logic** (Fixed):
   - **Remediation**: Restructured as do-while.

7. **Overlap Corruption** (Fixed):
   - **Remediation**: Backward-copy logic implemented.
