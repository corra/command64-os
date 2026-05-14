# MS-DOS Port: Internal Command Registry

This document tracks the status and priority of internal commands planned for the `command64` shell. Commands are derived from the original MS-DOS 4.0 `COMTAB` specification and C64-specific requirements.

## 1. Implemented (Phase 2A - 3)
| Command | Description | Status | Priority | Origin |
|:---|:---|:---|:---|:---|
| `CLS` | Clear screen using PETSCII $93 | ✅ Done | High | DOS 4.0 |
| `ECHO` | Print strings to standard output | ✅ Done | High | DOS 4.0 |
| `EXIT` | Return to BASIC (Warm Start $E37B) | ✅ Done | High | DOS 4.0 |
| `LOAD` | Load a .PRG from disk [address] | ✅ Done | Medium | C64 |
| `HELP` | Display help information | ✅ Done | High | DOS 4.0 |
| `DIR` | List directory contents | ✅ Done | High | DOS 4.0 |
| `VER` | Display MS-DOS / command64 version | ✅ Done | Low | DOS 4.0 |
| `TYPE` | Display file contents | ✅ Done | Medium | DOS 4.0 |
| `DEL` / `ERASE`| Delete files from disk | ✅ Done | Medium | DOS 4.0 |
| `COPY` | Copy files between devices | ✅ Done | High | DOS 4.0 |
| `REN` / `RENAME`| Rename files | ✅ Done | Medium | DOS 4.0 |
| `RUN` / `G` | Execute program at [address] | ✅ Done | High | DOS 4.0 |
| `SET` | Set environment variables | ✅ Done | Medium | DOS 4.0 |
| `PATH` | Set executable search path | ✅ Done | High | DOS 4.0 |

## 2. High Priority (Phase 5)
| Command | Description | Status | Priority | Origin |
|:---|:---|:---|:---|:---|
| `DRIVE` | Switch active device (8, 9, 10, 11) | 💡 Idea | High | C64 |
| `CD` / `CHDIR` | Change current directory/device | 📅 Planned | High | DOS 4.0 |
| `MD` / `MKDIR` | Create new directory | 📅 Planned | Medium | DOS 4.0 |


## 3. Backlog (MS-DOS 4.0 Standards)
| Command | Description | Status | Priority | Origin |
|:---|:---|:---|:---|:---|
| `VOL` | Display volume label | 💤 Backlog | Low | DOS 4.0 |
| `DATE` | Display or set system date | 💤 Backlog | Low | DOS 4.0 |
| `TIME` | Display or set system time | 💤 Backlog | Low | DOS 4.0 |
| `PROMPT` | Change the command prompt | 💤 Backlog | Low | DOS 4.0 |
| `BREAK` | Enable/Disable CTRL-C checking | 💤 Backlog | Low | DOS 4.0 |
| `VERIFY` | Enable/Disable disk write verification | 💤 Backlog | Low | DOS 4.0 |
| `REM` | Batch file comment | 💤 Backlog | Low | DOS 4.0 |
| `PAUSE` | Suspend batch processing | 💤 Backlog | Low | DOS 4.0 |

## 4. Proposed C64-Specific Commands
| Command | Description | Status | Priority | Origin |
|:---|:---|:---|:---|:---|
| `SAVE` | Direct KERNAL SAVE wrapper | 💡 Idea | Medium | C64 |
| `PEEK` | Read from memory address | 💡 Idea | Low | C64 |
| `POKE` | Write to memory address | 💡 Idea | Low | C64 |
| `CURSOR` | Toggle flashing vertical bar [ON/OFF] | 💤 Backlog | Low | C64 |

## 5. Technical Notes
- **Internal vs External**: Internal commands reside within the `CommandShell` segment in `shell.asm`. External commands (.COM) will be loaded to `$2000` via the Phase 2B loader.
- **Dispatch**: All commands listed here must be added to the `tableCmd` registry in `src/command64/shell.asm`.
- **Arguments**: Commands requiring arguments must use the `ParsePos` ZP index to locate parameters in the `CommandBuffer`.
