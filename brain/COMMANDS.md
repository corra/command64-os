# MS-DOS Port: Internal Command Registry

This document tracks the status and priority of internal commands planned for the `command64` shell. Commands are derived from the original MS-DOS 4.0 `COMTAB` specification and C64-specific requirements.

## 1. Implemented
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
| `DEL` | Delete files from disk | ✅ Done | Medium | DOS 4.0 |
| `COPY` | Copy files between devices | ✅ Done | High | DOS 4.0 |
| `REN` | Rename files | ✅ Done | Medium | DOS 4.0 |
| `RUN` | Execute program at [address] or by name | ✅ Done | High | DOS 4.0 |
| `MORE` | Display a file one screen at a time | ✅ Done | Medium | DOS 4.0 |
| `SET` | Set environment variables | ✅ Done | Medium | DOS 4.0 |
| `PATH` | Set executable search path | ✅ Done | High | DOS 4.0 |
| `VOL` | Display volume label | ✅ Done | Low | DOS 4.0 |
| `DRIVE` / `DEV` | Switch active device (8, 9, 10, 11) | ✅ Done | High | C64 |
| `PS` | List loaded/registered programs | ✅ Done | Medium | C64 |
| `FREE` | Deregister a named program, or all if no name given | ✅ Done | Medium | C64 |
| `FLUSH` | Flush pending file/channel state | ✅ Done | Low | C64 |
| `DATE` | Display or set system date (`YYYY-MM-DD`) | ✅ Done | Low | DOS 4.0 |
| `TIME` | Display or set system time (`HH:MM:SS`) | ✅ Done | Low | DOS 4.0 |

> **Dispatch note:** `cmdCompare` in `src/command64/shell.asm` does a strict
> match against fixed-width, space-padded 6-byte names in `tableCmd`. Only the
> names literally present in `tableCmd` dispatch. The HELP text currently
> advertises `RENAME`, `ERASE`, and `APPS`, none of which are table entries —
> see the open discrepancy noted below.

## 2. High Priority (Phase 5)
| Command | Description | Status | Priority | Origin |
|:---|:---|:---|:---|:---|
| `CD` / `CHDIR` | Change current directory/device | 📅 Planned | High | DOS 4.0 |
| `MD` / `MKDIR` | Create new directory | 📅 Planned | Medium | DOS 4.0 |


## 3. Backlog (MS-DOS 4.0 Standards)
| Command | Description | Status | Priority | Origin |
|:---|:---|:---|:---|:---|
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

- **Internal vs External**: Internal commands reside within the `CommandShell` segment in `shell.asm`. External commands are loaded at `UserProgStart` (currently `$3800`).
- **Dispatch**: All commands listed here must be added to the `tableCmd` registry in `src/command64/shell.asm`. Names are fixed-width `TABLE_NAME_LEN` (6) bytes, space-padded, and matched character-for-character by `cmdCompare` — an alias only works if it is its own table entry.
- **Arguments**: Commands requiring arguments must use the `ParsePos` ZP index to locate parameters in the `CommandBuffer`.

## 6. Known Discrepancies

- **Advertised aliases that do not dispatch**: the HELP text in `shell.asm`
  lists `RENAME - ALIAS FOR REN`, `ERASE - ALIAS FOR DEL`, and
  `APPS - LIST LOADED APPS` / `PS - ALIAS FOR APPS`, but `tableCmd` contains
  only `ren`, `del`, and `ps`. Because `cmdCompare` requires an exact
  fixed-width match, typing `RENAME`, `ERASE`, or `APPS` falls through to the
  external-program search and fails. HELP also omits `FLUSH` and the genuine
  `DEV` alias. Resolution is to correct the HELP text, not to add table
  entries — tracked in `wiki/tasks/shell-command-alias-discrepancy.md`.
  Open as of OS build 2658.
