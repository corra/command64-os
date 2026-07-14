# MS-DOS Port: External Program Registry

This document tracks the status and priority of external programs (.COM / .EXE) planned for the `command64` environment. These utilities will be loaded into the User Program Space ($2000+) via the Phase 2B loader.

## 1. High Priority (Phase 2B / 2C / 4)
These programs are essential for system maintenance and early verification of the binary loader.

| Program | Description | Status | Priority | Origin |
|:---|:---|:---|:---|:---|
| `CHKDSK` | Check disk status and memory usage | 📅 Planned | High | DOS 4.0 |
| `DEBUG` | Hex editor and assembly debugger | ✅ v0.1.3 (Build 1011) | High | DOS 4.0 |

### DEBUG Roadmap
- **Phase 1 (Done)**: Core memory manipulation (D, E, F, M, C, S), Hex math, and Execution (G).
- **Phase 2 (Done)**: I/O port commands (I, O), Length syntax (L), and Register modification (R).
- **Phase 3 (Mid-term)**: VMM/EMS integration (XA, XM, XS) and Banked addressing (BANK:OFF).
- **Phase 4 (Done)**: Disk management (N, L, W) and Disassembler (U).

| `FORMAT` | Format C64 disks (via KERNAL wrappers) | 📅 Planned | High | DOS 4.0 |
| `SYS` | Transfer system files to a disk | 📅 Planned | Medium | DOS 4.0 |

## 2. Essential System Utilities
| Program | Description | Status | Priority | Origin |
|:---|:---|:---|:---|:---|
| `EDLIN` | Line-based text editor | 💤 Backlog | Medium | DOS 4.0 |
| `MEM` | Display memory allocation details | 💤 Backlog | Medium | DOS 4.0 |
| `MODE` | Configure system devices (Screen/Printer) | 💤 Backlog | Low | DOS 4.0 |
| `TREE` | Display directory structure | 💤 Backlog | Low | DOS 4.0 |
| `MORE` | Display output one screen at a time | 💤 Backlog | Medium | DOS 4.0 |

## 3. File & Data Tools
| Program | Description | Status | Priority | Origin |
|:---|:---|:---|:---|:---|
| `XCOPY` | Extended file and directory copy | 💤 Backlog | Medium | DOS 4.0 |
| `FIND` | Search for a string in a file | 💤 Backlog | Low | DOS 4.0 |
| `SORT` | Sort input data | 💤 Backlog | Low | DOS 4.0 |
| `COMP` | Compare files as raw byte streams | ✅ v0.1.0 (Build 1001) | Low | DOS 4.0 |
| `FC` | File compare with binary/text options | 💤 Backlog | Low | DOS 4.0 |
| `ATTRIB` | Change file attributes | 💤 Backlog | Medium | DOS 4.0 |

## 4. Development & Advanced Tools
| Program | Description | Status | Priority | Origin |
|:---|:---|:---|:---|:---|
| `EXE2BIN` | Convert .EXE to .BIN/.COM format | 💤 Backlog | Low | DOS 4.0 |
| `LINK` | MS-DOS Linker (Concept only for now) | 💤 Backlog | Low | DOS 4.0 |
| `PRINT` | Background printing service | 💤 Backlog | Low | DOS 4.0 |

## 5. C64-Specific External Utilities
| Program | Description | Status | Priority | Origin |
|:---|:---|:---|:---|:---|
| `SIDPLAY` | Play SID music files from DOS | 💡 Idea | Low | C64 |
| `REUCHECK`| Utility to verify REU/VMM status | 📅 Planned | High | C64 |
| `DISKMON` | Raw disk sector editor | 💡 Idea | Medium | C64 |

## Technical Implementation Notes
- **Loader Target**: Programs default to `$2000` but can be loaded anywhere using the `LOAD` command.
- **Auto-Search**: The shell automatically appends `.prg` and searches device 8 if an internal command is not found.
- **Case-Insensitive**: All external command searches are case-insensitive.
- **Termination**: External programs should terminate with an `RTS` to return control to the `command64` shell.
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
