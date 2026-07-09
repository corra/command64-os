# Command 64 OS — Complete Codebase Reference

> **Audience**: Developers working on or extending Command 64 OS.  
> **Scope**: Every module, every public routine, every constant, the build system, and the complete call graph.
> **Mainenance**: This is a living document. *It must be maintained as part of task completions.*
---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Repository Structure](#2-repository-structure)
3. [Build System](#3-build-system)
4. [Memory Map](#4-memory-map)
5. [Zero Page Allocation](#5-zero-page-allocation)
6. [KERNAL Jump Table References](#6-kernal-jump-table-references)
7. [API Constants (DOS Function Numbers)](#7-api-constants-dos-function-numbers)
8. [Module Reference — OS Core](#8-module-reference--os-core)
   - 8.1 [command64.asm — Root Assembly Unit](#81-command64asm--root-assembly-unit)
   - 8.2 [petsci.asm — PETSCII Output Layer](#82-petsciasm--petscii-output-layer)
   - 8.3 [api.asm — INT 21h Service Bus](#83-apiasm--int-21h-service-bus)
   - 8.4 [utils.asm — Utility Routines](#84-utilsasm--utility-routines)
   - 8.5 [loader.asm — Binary Loader](#85-loaderasm--binary-loader)
   - 8.6 [path.asm — File Discovery](#86-pathasm--file-discovery)
   - 8.7 [vmm.asm — Virtual Memory Manager](#87-vmmasm--virtual-memory-manager)
   - 8.8 [file.asm — Handle-Based File I/O](#88-fileasm--handle-based-file-io)
   - 8.9 [shell.asm — Command Shell and Built-in Commands](#89-shellasm--command-shell-and-built-in-commands)
9. [Module Reference — External Commands](#9-module-reference--external-commands)
   - 9.1 [debug.s — Interactive Memory Monitor](#91debugs--interactive-memory-monitor)
   - 9.2 [label.asm — Disk Volume Label Writer](#92-labelasm--disk-volume-label-writer)
   - 9.3 [conway.asm — Conway's Game of Life](#93-conwayasm--conways-game-of-life)
   - 9.4 [pacman.asm — Pac64](#94-pacmanasm--pac64)
10. [API Call Stacks](#10-api-call-stacks)
11. [Code Graph and Interrelations](#11-code-graph-and-interrelations)
12. [Shell Command Reference](#12-shell-command-reference)
13. [Writing External Programs](#13-writing-external-programs)
14. [Hardware Notes](#14-hardware-notes)

---

## 1. Project Overview

Command 64 OS is a CP/M-and-MS-DOS–inspired operating system shell for the Commodore 64.  It runs natively on real hardware and provides:

- A command-line shell with a fixed command table and external-program dispatch.
- An INT 21h–style API at the stable jump table address `$1000` for use by external programs.
- A Virtual Memory Manager (VMM) that maps a 1 MB logical address space into the C64's RAM Expansion Unit (REU), enabling a persistent environment-variable store and general heap allocation.
- A handle-based file I/O subsystem over the C64 KERNAL.
- Two shipped external programs: `debug.prg` (memory monitor / assembler) and `label.prg` (disk volume label editor).

The core OS still builds with **KickAssembler v5.25**. New external applications are built with **ca65/ld65**, while existing KickAssembler external apps may remain on their current toolchain until migrated. The project is built with **CMake ≥ 3.20** and targets a standard NTSC/PAL C64 with an attached 1541/1571/1581 disk drive (device 8–11) and optionally a 1750/1764 REU.

---

## 2. Repository Structure

```
command64-os/
├── CMakeLists.txt              Root CMake build definition
├── Makefile                    Convenience proxy to cmake --build build
├── VERSION                     Semantic version string (e.g. "0.2.21")
├── BUILD_OS                    Persistent OS build counter (auto-incremented)
├── BUILD_DEBUG                 Persistent DEBUG build counter
├── BUILD_LABEL                 Persistent LABEL build counter
│
├── include/
│   ├── command64.inc           Core constants, ZP labels, KERNAL addresses, I/O buffers
│   └── vmm.inc                 VMM constants, REU registers, MCT/page constants
│
├── src/
│   ├── command64.asm           Root assembly file — segment layout and imports
│   └── command64/
│       ├── petsci.asm          PETSCII string and character output
│       ├── api.asm             INT 21h dispatcher (apiHandler) + stable stub ($1000)
│       ├── utils.asm           parseHex, hexDigitToVal, normalizeName,
│       │                       printDecimal16, parsePointerDevice
│       ├── loader.asm          shellLoadPrg — KERNAL LOAD wrapper
│       ├── path.asm            findFile, checkExistence
│       ├── vmm.asm             vmmInit, vmmAlloc, vmmFree, vmmReadByte,
│       │                       vmmWriteByte, vmmComputeAddress
│       ├── file.asm            fileInit, fileOpen, fileClose, fileRead,
│       │                       fileWrite, fileDelete, fileRename
│       └── shell.asm           Command table, shell entry, main loop,
│                               all built-in command handlers,
│                               environment variable subroutines
│
├── src/external/
│   ├── debug/
│   │   └── debug.s             DEBUG utility (memory monitor, assembler; ca65/ld65)
│   └── label/
│       └── label.asm           LABEL disk volume-name writer
│
├── tests/
│   ├── src/
│       ├── hello.s             Minimal "hello world" test program (ca65/ld65)
│       ├── color.s             Colour attribute test (ca65/ld65)
│       ├── extcls.s            External CLS test (ca65/ld65)
│       ├── apitest.s           API function exerciser (ca65/ld65)
│       ├── filetest.s          File open/read/write/close exerciser (ca65/ld65)
│       ├── vmmtest.s           VMM alloc/free/read/write exerciser (ca65/ld65)
│       └── reloc.asm           Kick-specific relocation pipeline test
│   └── smoke/
│       └── ca65_app_smoketest.s  Minimal add_ca65_app pipeline smoke source
│
├── cmake/
│   ├── FindKickAss.cmake       Locates KickAss.jar
│   ├── FindOscar64.cmake       Locates oscar64 C compiler (optional)
│   ├── Findcc1541.cmake        Locates cc1541 disk-image tool
│   ├── KickAssembler.cmake     add_kickass_target() helper
│   ├── Oscar64.cmake           add_oscar64_target() helper
│   ├── cc1541.cmake            add_c64_disk_image() helper
│   ├── IncrementBuildNumber.cmake  Auto-increments BUILD_* files
│   └── PackRelease.cmake       Produces release archives
│
├── docs/                       Authoritative docs (synced from wiki/ by build)
│   ├── api-reference.md
│   ├── vmm-api.md
│   ├── programmers-reference.md
│   ├── user-manual.md
│   └── apps/debug.md
│
├── wiki/                       Wiki source (edit here; build copies to docs/)
├── brain/                      AI planning documents, reviews, and research notes
└── tools/
    ├── KickAss.jar             KickAssembler v5.25
    ├── cc1541                  CBM disk image builder
    └── command64.reu.reu       Test REU image
```

---

## 3. Build System

### 3.1 Targets

| Make target       | CMake target        | Description |
|-------------------|---------------------|-------------|
| `make` / `make all` | (default)          | Builds all PRGs and syncs docs |
| `make image`      | `image_d64`         | Assembles `build/image.d64` containing `command64.prg`, `debug.prg`, `label.prg` |
| `make testimage`  | `test_image_d64`    | Same as above plus all test PRGs and `testseq` SEQ file |
| `make release`    | `release`           | Packages `release/command64-os-<version>.tar.gz/.zip` |
| `make clean`      | —                   | Removes `build/` directory |

### 3.2 Build Flow

```bash
cmake -B build                     # Configure
cmake --build build                # Full build
cmake --build build --target image_d64
```

**What happens during a build:**

1. `IncrementBuildNumber.cmake` checks if any tracked target source files changed; if so, it increments the target's colocated `BUILD_<NAME>` file and writes a generated `build_<name>.inc`. KickAssembler targets receive `.const BUILD_NUMBER = "NNNN"` syntax; ca65/ld65 targets receive `.define BUILD_NUMBER "NNNN"` syntax.
2. `KickAssembler.cmake` invokes `java -jar tools/KickAss.jar` with `-includeDir build/` so the generated `build_os.inc` is found by `#import "build_os.inc"`.
3. `cc1541.cmake` invokes `tools/cc1541` to create a `.d64` CBM disk image.
4. `sync_docs` target copies changed markdown files from `wiki/` → `docs/`.

### 3.3 External Application Versioning

Each program in `src/external/<name>/` must have:

- `BUILD_<NAME_UPPER>` in the app's own source directory — initial value typically `1000`.
- The generated build include imported by the app source (`#import` for KickAssembler, `.include` for ca65).
- A CMake app-helper call in `CMakeLists.txt`: `add_external_app(<name> ...)` for KickAssembler or `add_ca65_app(<name> ...)` for ca65/ld65.

Both helpers schedule `IncrementBuildNumber.cmake` with the correct counter file and produce relocatable PRGs through the base/next-page diff pipeline.

### 3.4 Test Program Versioning

Ported tests in `tests/src/<name>/<name>.s` build with ca65/ld65 as the
primary `test_<name>` targets and use `BUILD_TEST_<NAME>` counters in the
same directory. KickAssembler remains available for tests without a ca65
port; currently `tests/src/reloc/reloc.asm` stays on that path because it
exercises the Kick/reloc.py relocation pipeline directly.

---

## 4. Memory Map

This is the compiled segment layout for `command64.prg` plus the surrounding RAM regions.

```
Address     Segment / Region         Contents
─────────── ──────────────────────── ─────────────────────────────────────────────
$0801       Main                     BASIC SYS $1130 launcher (BasicUpstart2)
$0820       Utils                    parseHex, normalizeName, printDecimal16,
                                     parsePointerDevice, hexDigitToVal
$09C0       Api                      apiHandler (INT 21h dispatcher)
$0A50       Loader                   shellLoadPrg
$0AA0       Path                     findFile, checkExistence
$0B30       Vmm                      vmmInit, vmmAlloc, vmmFree,
                                     vmmReadByte, vmmWriteByte,
                                     vmmComputeAddress
$0CE0       File                     fileInit, fileOpen, fileClose,
                                     fileRead, fileWrite,
                                     fileDelete, fileRename
──────────── ──────────────────────── ────────────────────────────────────────────
$033C–$038B  CommandBuffer            80-byte typed command input buffer
$038C        CommandLen               Length of last typed command (1 byte)
$038D        SpecificLoad             0 = relocated (uses HexVal), 1 = absolute
$038E–$039D  HandleTable              8 × 2-byte entries (Status, LFN)
$039E        CurrentDevice            Active CBM device number (8–11)
$039F–$03A0  EnvSegmentLo/Hi         Segment address of Master Environment Block
$03A2–$03C9  SourceBuf                40-byte scratch buffer (copy src / env var name)
$03CA–$03F1  DestBuf                  40-byte scratch buffer (copy dest)
──────────── ──────────────────────── ────────────────────────────────────────────
$1000        ApiStub                  Stable JMP to apiHandler — never moves
$1040        Petsci                   petPrintString, petPrintChar macro
$1080        CommandTable             Fixed-width 8-byte command dispatch table
$1130        CommandShell             start (OS entry), mainLoop, shellReadLine,
                                     shellDispatch, cmdCompare, all built-ins,
                                     environment subroutines, string literals
──────────── ──────────────────────── ────────────────────────────────────────────
$1F90        VmmData                  vmmInitialized (1), vmmTempByte (1),
                                     fileScratch (96 bytes)
──────────── ──────────────────────── ────────────────────────────────────────────
UserProgStart–$CFFF  User Program Space   External programs load and execute here (BASIC ROM banked out); currently `$2C00`
$C000–$CFFF  VMM MCT                  Memory Control Table (4096 bytes for 16MB REU)
```

> **Note**: The addresses shown for OS segments (`$0820`–`$0CE0`) are compile-time constants in `src/command64.asm`; they may drift slightly between builds as code grows. The *stable* entry point for external programs is always exactly `$1000`. `UserProgStart` (the `AppTable`/`ShellExt` boundary that follows it) has shifted upward several times as OS-resident segments grew — from `$2000` to `$2200` to `$2600` to the current `$2C00` — and is configured via the CMake cache variable `USER_PROG_START_HEX`. Never hardcode a prior value; always compile external programs against the current build's constant.

---

## 5. Zero Page Allocation

The 6510 zero page is a scarce resource. The OS carves it as follows:

| ZP Address | Label         | Owner            | Purpose |
|-----------|---------------|------------------|---------|
| `$02`     | `CmpBase`     | Shell/Dispatcher | Saved table-entry base offset in `cmdCompare` |
| `$22`–`$23` | *(implicit)* | KERNAL           | KERNAL uses these internally; OS avoids them |
| `$61`     | `HandlerVecLo` | Shell            | Indirect jump target low byte |
| `$62`     | `HandlerVecHi` | Shell            | Indirect jump target high byte |
| `$63`     | `ParsePos`    | Shell            | Buffer index of first argument after command name |
| `$64`     | `TempLo`      | OS-wide scratch  | General low-byte scratch (clobbered freely) |
| `$65`     | `TempHi`      | OS-wide scratch  | General high-byte scratch |
| `$66`     | `HexValLo`    | Utils / API      | `parseHex` result low byte; file I/O byte counts |
| `$67`     | `HexValHi`    | Utils / API      | `parseHex` result high byte; file I/O byte counts |
| `$68`     | `VmmSegLo`    | VMM              | Logical segment low byte |
| `$69`     | `VmmSegHi`    | VMM              | Logical segment high byte |
| `$6A`     | `VmmOffLo`    | VMM              | Offset within segment, low byte |
| `$6B`     | `VmmOffHi`    | VMM              | Offset within segment, high byte |
| `$6C`     | `VmmBank`     | VMM              | REU bank (64 KB unit index) |
| `$6D`     | `FileHandle`  | File / API       | Active file handle for read/write/close calls |
| `$6E`     | `SrcHandle`   | Shell (COPY)     | Source file handle scratch |
| `$6F`     | `DstHandle`   | Shell (COPY)     | Destination file handle scratch |
| `$70`–`$7F` | *(external)* | DEBUG.PRG       | Used by the debug utility (safe for other external programs when debug is not running) |
| `$FB`     | `PrintPtrLo`  | petPrintString   | String pointer low byte |
| `$FC`     | `PrintPtrHi`  | petPrintString   | String pointer high byte |
| `$FD`     | `NamePtrLo`   | Loader/File      | Filename pointer low byte |
| `$FE`     | `NamePtrHi`   | Loader/File      | Filename pointer high byte |

**Safe zones for external programs:**

- `$03`–`$60`: Generally unused by the OS.
- `$70`–`$8F`: Safe unless running alongside DEBUG.

---

## 6. KERNAL Jump Table References

All KERNAL calls go through the official `$FF00+` jump table, never raw ROM body addresses.

| Label             | Address  | Function |
|-------------------|----------|---------|
| `KernalChROUT`    | `$FFD2`  | Output one character to the current output channel |
| `KernalGetIn`     | `$FFE4`  | Non-blocking raw keyboard read (returns 0 if no key) |
| `KernalChRIN`     | `$FFCF`  | Blocking read from current input channel |
| `KernalCLALL`     | `$FFE7`  | Close all I/O channels |
| `KernalSETMSG`    | `$FF90`  | Enable/disable KERNAL messages (0 = off) |
| `KernalSETLFS`    | `$FFBA`  | Set logical file number (A), device (X), secondary address (Y) |
| `KernalSETNAM`    | `$FFBD`  | Set filename (A = length, X/Y = pointer) |
| `KernalLOAD`      | `$FFD5`  | Load or verify file (A=0 load, X/Y = target address) |
| `KernalSAVE`      | `$FFD8`  | Save memory range to file |
| `KernalOPEN`      | `$FFC0`  | Open a logical file (uses SETLFS / SETNAM params) |
| `KernalCLOSE`     | `$FFC3`  | Close a logical file (A = LFN) |
| `KernalREADST`    | `$FFB7`  | Read I/O status byte (0 = ok, non-zero = error/EOF) |
| `KernalCHKIN`     | `$FFC6`  | Redirect input to logical file (X = LFN) |
| `KernalCHKOUT`    | `$FFC9`  | Redirect output to logical file (X = LFN) |
| `KernalCLRCHN`    | `$FFCC`  | Restore I/O to keyboard/screen |

The BASIC warm-start (`$E37B`) is used by `cmdExit` to return to BASIC.

---

## 7. API Constants (DOS Function Numbers)

These are modeled after PC MS-DOS INT 21h function numbers. External programs invoke them via `JSR $1000` with `A` = function number.

| Constant         | Value | Description |
|-----------------|-------|-------------|
| `DOS_PRINT_CHAR` | `$02` | Print PETSCII character. Input: `X` = character. |
| `DOS_PRINT_STR`  | `$09` | Print null-terminated string. Input: `X`/`Y` = pointer lo/hi. |
| `DOS_OPEN_FILE`  | `$3D` | Open file. Input: `X`/`Y` = filename pointer, `HexValLo` = mode (0=read, 1=write). Output: `A` = handle, `C` = status. |
| `DOS_CLOSE_FILE` | `$3E` | Close file. Input: `FileHandle` ($6D) = handle. |
| `DOS_READ_FILE`  | `$3F` | Read bytes. Input: `FileHandle`, `X`/`Y` = buffer, `HexValLo/Hi` = byte count. Output: `HexValLo/Hi` = actual bytes read. |
| `DOS_WRITE_FILE` | `$40` | Write bytes. Same inputs/outputs as read. |
| `DOS_DELETE_FILE`| `$41` | Delete file. Input: `X`/`Y` = filename pointer. |
| `DOS_RENAME_FILE`| `$56` | Rename file. Input: `X`/`Y` = old name, `PrintPtrLo/Hi` = new name. |
| `DOS_ALLOC_MEM`  | `$48` | Allocate REU memory. Input: `X`/`Y` = paragraphs requested. Output: `X` = segment hi, `Y` = bank. |
| `DOS_FREE_MEM`   | `$49` | Free REU memory. Input: `X` = segment hi, `Y` = bank. |
| `DOS_EXIT`       | `$4C` | Terminate program, return to shell. Resets stack pointer. |
| `DOS_PARSE_PREFIX`| `$57` | Parse device prefix from a ZP pointer. Input: `X` = ZP address of pointer. Output: `A` = device number, `C` = 1 if prefix found. |

**ABI summary:**

```text
Before call:
  A  = function number
  X  = argument 1 (lo byte) or ZP offset
  Y  = argument 2 (hi byte)
  (additional params in ZP as documented per function)

After call:
  C  = 0 success, 1 error
  A  = return value or error code
  X, Y = secondary return values
```

---

## 8. Module Reference — OS Core

### 8.1 `command64.asm` — Root Assembly Unit

**File**: [src/command64.asm](src/command64.asm)  
**Segment**: `Main` @ `$0801`

This is the KickAssembler "project root" — it does nothing except:

1. Define all segment start addresses.
2. Declare the output file name and segment list.
3. `#import` all sub-modules in dependency order.
4. Emit a `BasicUpstart2(start)` macro at `$0801` that generates a one-line BASIC program `10 SYS 4400` (where 4400 = `$1130`, the `start` label in `shell.asm`).

**Segment layout declared here:**

```asm
.segmentdef Main         [start=$0801]
.segmentdef Utils        [start=$0820]
.segmentdef Api          [start=$09C0]
.segmentdef Loader       [start=$0A50]
.segmentdef Path         [start=$0AA0]
.segmentdef Vmm          [start=$0B30]
.segmentdef File         [start=$0CE0]
.segmentdef VmmData      [start=$1F90]
```

The `Petsci`, `CommandTable`, `CommandShell`, and `ApiStub` segments are defined inside their respective imported files.

**Import order matters** because KickAssembler resolves forward references at link time, but the `#import` chain establishes what constants and labels are visible during parse:

```asm
#import "../include/command64.inc"   ← must come first (defines all labels)
#import "command64/petsci.asm"
#import "command64/api.asm"
#import "command64/utils.asm"
#import "command64/loader.asm"
#import "command64/path.asm"
#import "command64/vmm.asm"
#import "command64/file.asm"
#import "command64/shell.asm"        ← must come last (references all others)
```

---

### 8.2 `petsci.asm` — PETSCII Output Layer

**File**: [src/command64/petsci.asm](src/command64/petsci.asm)  
**Segment**: `Petsci` @ `$1040`

#### `petPrintString`

```text
Input:  A = string pointer low byte
        Y = string pointer high byte
Effect: Prints null-terminated PETSCII string character-by-character via KernalChROUT.
        Advances across page boundaries (inc PrintPtrHi).
Preserves: X, Y (KERNAL ChROUT contract)
Clobbers: A, PrintPtrLo ($FB), PrintPtrHi ($FC)
```

**How it works**: Stores `A`→`PrintPtrLo`, `Y`→`PrintPtrHi`, then loops with `LDA (PrintPtrLo),Y` using `Y` as the byte index (0-based within the page). On `Y` overflow (page wrap), increments `PrintPtrHi`. Stops on null byte (`$00`).

#### `petPrintChar` macro

Inlines a `JSR KernalChROUT`. Exists for documentation consistency; callers can also call `KernalChROUT` directly.

---

### 8.3 `api.asm` — INT 21h Service Bus

**File**: [src/command64/api.asm](src/command64/api.asm)  
**Segments**: `ApiStub` @ `$1000`, `Api` @ `$09C0`

#### `$1000` — Stable Jump Table (ApiStub)

A permanent `JMP apiHandler` at exactly `$1000`. This address is documented and must never be moved. External programs call `JSR $1000`.

#### `apiHandler`

The central dispatcher. Entry sequence:

1. `CLD` — always clears decimal mode (defensive: programs may leave BCD set).
2. Chains of `CMP #<constant>` / `BEQ <handler>` for each function number.
3. Falls through to `SEC; RTS` (error) if no function matches.

**Dispatch table (in code order):**

| A value | Branch target | Calls |
|---------|--------------|-------|
| `$02` `DOS_PRINT_CHAR` | `ahPrintChar` | `KernalChROUT` |
| `$09` `DOS_PRINT_STR`  | `ahPrintStr`  | `petPrintString` |
| `$3D` `DOS_OPEN_FILE`  | `ahOpen`      | `fileOpen` |
| `$3E` `DOS_CLOSE_FILE` | `ahClose`     | `fileClose` |
| `$3F` `DOS_READ_FILE`  | `ahRead`      | `fileRead` |
| `$40` `DOS_WRITE_FILE` | `ahWrite`     | `fileWrite` |
| `$41` `DOS_DELETE_FILE`| `ahDelete`    | `fileDelete` |
| `$56` `DOS_RENAME_FILE`| `ahRename`    | `fileRename` |
| `$48` `DOS_ALLOC_MEM`  | `ahAllocMem`  | `vmmAlloc` |
| `$49` `DOS_FREE_MEM`   | `ahFreeMem`   | `vmmFree` |
| `$4C` `DOS_EXIT`       | `ahExit`      | resets SP, `JMP mainLoop` |
| `$57` `DOS_PARSE_PREFIX`| `ahParsePrefix` | `parsePointerDevice` |

#### `ahExit` — Stack Reset

This is the only handler that does not `RTS`. Instead:

```asm
ldx #$FF
txs          ; reset stack pointer to $01FF
jmp mainLoop ; return to shell without using the stack
```

This is necessary because each `JSR $1000` from `UserProgStart` pushes two bytes. Without the stack reset, 63 program launches would overflow the 256-byte stack.

---

### 8.4 `utils.asm` — Utility Routines

**File**: [src/command64/utils.asm](src/command64/utils.asm)  
**Segment**: `Utils` @ `$0820`

#### `parseHex`

```text
Input:  Y = starting index in CommandBuffer
Output: HexValLo/Hi = 16-bit parsed value
        C = 0 success, C = 1 invalid character or overflow
Clobbers: A, X, Y
```

Reads hex digits from `CommandBuffer[Y]` until space or null. For each digit:

1. Calls `hexDigitToVal` to convert ASCII → nibble value (0–15).
2. Left-shifts `HexValHi:HexValLo` by 4 bits (using a `ldx #4` / `asl HexValLo` / `rol HexValHi` loop).
3. ORs the new nibble into `HexValLo`.

Supports only 4 hex digits (16-bit result). Longer strings cause the upper nibbles to shift out silently (this is expected behavior — callers do not pass more than 4 digits).

#### `hexDigitToVal`

```text
Input:  A = PETSCII character
Output: A = nibble value 0–15, C = 0
        C = 1 on invalid character
```

Accepts `'0'`–`'9'` and `'a'`–`'f'` (unshifted PETSCII lowercase `$61`–`$66`). Does **not** accept uppercase `A`–`F` — the OS normalizes to lowercase before calling `parseHex`.

#### `normalizeName`

```text
Input:  A = string pointer lo
        Y = string pointer hi
        X = string length
Output: Y = string length (same as input X)
        String modified in-place: shifted PETSCII A–Z ($C1–$DA) → unshifted ($41–$5A)
Clobbers: A, TempLo, PrintPtrLo/Hi
Preserves: X (callers rely on this)
```

The CBM DOS stores filenames in **unshifted PETSCII** (what .encoding "petscii_mixed" calls "lowercase"). When the user types in the C64's mixed-mode charset, uppercase keystrokes produce **shifted** PETSCII (`$C1`–`$DA`). `normalizeName` strips the shift bit with `AND #$7F` to make comparisons case-insensitive against disk directory entries.

#### `printDecimal16`

```text
Input:  X = value low byte
        Y = value high byte
Effect: Prints the decimal representation of X/Y to current output channel.
        Leading zeros are suppressed. Value 0 prints as "0".
Clobbers: A, X, Y, HexValLo/Hi, TempHi
```

Uses repeated 16-bit subtraction for each power of 10 (10000, 1000, 100, 10, 1). `TempHi` is the leading-zero suppression flag: becomes `1` after the first non-zero digit is printed, allowing subsequent zero digits to print.

#### `parsePointerDevice`

```text
Input:  X = ZP address of a 2-byte pointer (e.g. $FD for NamePtrLo)
Output: A = resolved device number (8, 9, 10, or 11; or CurrentDevice if no prefix)
        C = 1 if a prefix was found and stripped
        Pointer at ZP[X]/ZP[X+1] advanced past the prefix if found
Clobbers: A, Y, TempLo, TempHi
```

Checks if the string pointed to by the ZP pointer starts with a device prefix: `8:`, `9:`, `10:`, `11:`. If found, the pointer is advanced by 2 (single-digit) or 3 (two-digit) bytes and the device number is returned. This allows any filename argument to be prefixed with a device number: e.g. `LOAD 9:MYPROG`.

---

### 8.5 `loader.asm` — Binary Loader

**File**: [src/command64/loader.asm](src/command64/loader.asm)  
**Segment**: `Loader` @ `$0A50`

#### `shellLoadPrg`

```text
Input:  A  = filename pointer low byte
        Y  = filename pointer high byte
        X  = filename length
        SpecificLoad ($038D) = 0 (use HexVal address) | 1 (use file header address)
        HexValLo/Hi ($66/$67) = load address if SpecificLoad=0
Output: C = 0 success, C = 1 error (A = KERNAL error code)
Clobbers: A, X, Y
```

Wraps the three KERNAL calls needed to load a CBM binary:

1. `KernalSETNAM` (A=length, X/Y=pointer)
2. `KernalSETLFS` (A=1, X=`CurrentDevice`, Y=`SpecificLoad`)
   - Secondary address `0` = relocated (KERNAL places file at the address in `HexValLo/Hi`)
   - Secondary address `1` = absolute (KERNAL places file at the address in its 2-byte header)
3. `KernalSETMSG #0` — silences the "LOADING" / "FOUND" messages from KERNAL ROM (the OS prints its own `"loading..."` message via `petPrintString`)
4. `KernalLOAD` (A=0 = load, not verify; X=`HexValLo`, Y=`HexValHi`)

The KERNAL `LOAD` routine sets carry on error and returns a KERNAL error code in `A`.

---

### 8.6 `path.asm` — File Discovery

**File**: [src/command64/path.asm](src/command64/path.asm)  
**Segment**: `Path` @ `$0AA0`

#### `findFile`

```text
Input:  A = filename pointer lo
        Y = filename pointer hi
        X = filename length
Output: C = 0 found, C = 1 not found
        NamePtrLo/Hi updated to point to (possibly normalized) name
        X = updated length
Clobbers: A, X, Y
```

1. Stores pointer in `NamePtrLo/Hi`, length in `TempLo`.
2. Calls `normalizeName` (converts to unshifted PETSCII in-place).
3. Calls `checkExistence` to probe the disk.
4. Returns carry to caller.

> **Historical note**: An earlier version also tried appending `.prg` if the bare name was not found. That logic was removed when it was determined that disk directory entries on the standard image do not include extensions.

#### `checkExistence`

```text
Input:  NamePtrLo/Hi = filename pointer
        TempLo       = filename length
        CurrentDevice = target drive
Output: C = 0 file exists, C = 1 not found / error
```

Silently probes for the file by:

1. `KernalSETMSG #0` — suppress KERNAL error messages.
2. `KernalSETLFS` LFN=14, device=`CurrentDevice`, SA=0 (read).
3. `KernalSETNAM` with the filename.
4. `KernalOPEN` — if carry is clear, file exists.
5. `KernalCLOSE #14` — always, to release the channel.
6. `PLP` — restore carry from after OPEN (this is a PHP/PLP sandwich around the close).

LFN 14 is chosen because it is outside the handle table range (2–9), directory range (13), and command channel (15), so it never collides with anything else the OS has open.

---

### 8.7 `vmm.asm` — Virtual Memory Manager

**File**: [src/command64/vmm.asm](src/command64/vmm.asm)  
**Segment**: `Vmm` @ `$0B30`

The VMM maps a 1 MB logical address space (`Segment:Offset`, 20-bit) into the REU's expansion RAM. It maintains a Memory Control Table (MCT) in C64 RAM at `$C000`–`$CFFF` (4096 bytes = 4096 4 KB pages = 16 MB addressable, though the actual REU is 512 KB–2 MB).

#### Address Encoding

| Concept | Description |
|---------|-------------|
| **Segment** (`VmmSegHi:VmmSegLo`) | 16-bit segment number, 16-byte units (paragraph units, DOS convention). Each paragraph = 16 bytes. |
| **Offset** (`VmmOffHi:VmmOffLo`) | 16-bit byte offset within the segment. |
| **Physical address** = `(Segment × 16) + Offset` | 20-bit result. REU holds it as a 3-byte address (24-bit, bank in `REU_REU_BANK`). |
| **Bank** (`VmmBank`) | REU bank (each bank = 64 KB). Bank 0 = bytes `$000000`–`$00FFFF`. |

#### MCT Layout

Each byte at `VmmMctBase + N` describes 4 KB page N:

| Value | Constant | Meaning |
|-------|----------|---------|
| `$00` | `PAGE_FREE` | Page is free |
| `$01` | `PAGE_HEAD` | First page of an allocated block |
| `$02` | `PAGE_TAIL` | Continuation page of an allocated block |

#### `vmmInit`

```text
Output: A = VMM_SUCCESS ($00) or VMM_ERR_INVALID ($02) if no REU detected
        vmmInitialized (at $1F90) = 1 (ok) or 0 (no REU)
```

1. Reads `REU_STATUS` (`$DF00`) and checks bit 4 (size bit). If clear, no REU → error.
2. Clears 4096 bytes of MCT at `$C000`–`$CFFF` (16 pages × 256 bytes) with `PAGE_FREE`.
3. Sets `vmmInitialized = 1`.

#### `vmmAlloc`

```text
Input:  VmmSegLo/Hi = number of paragraphs to allocate
Output: A = VMM_SUCCESS, VMM_ERR_NOMEM, or VMM_ERR_INVALID
        VmmSegLo/Hi = starting segment of allocation (on success)
        VmmBank      = REU bank of allocation (on success)
```

Algorithm:

1. Guard: zero-paragraph request → `VMM_ERR_INVALID`.
2. Convert paragraphs → page count: `PageCount = (Paragraphs + 255) >> 8`.  Each page = 4 KB = 256 paragraphs.
3. Scan MCT linearly for `PageCount` contiguous free bytes.  Tracks search across 256-byte MCT blocks using `TempLo` (block index) and `PrintPtrHi` (MCT page pointer).
4. On finding a contiguous run: write `PAGE_HEAD` to the first page, `PAGE_TAIL` to all remaining.
5. Compute returned segment: `VmmSegHi = VmmOffLo` (page index within its 256-page MCT block), `VmmBank = VmmOffHi` (which 256-page block).

#### `vmmFree`

```text
Input:  VmmSegHi = page index (low), VmmBank = page index (high)
Output: A = VMM_SUCCESS or VMM_ERR_INVALID
```

Locates the MCT entry for the given block head. Validates it is `PAGE_HEAD`. Walks forward writing `PAGE_FREE` until it hits a non-`PAGE_TAIL` entry or the end of the MCT.

#### `vmmReadByte`

```text
Input:  VmmSegLo/Hi, VmmOffLo/Hi
Output: A = byte read from REU
```

1. Guards on `vmmInitialized`.
2. Calls `vmmComputeAddress` to set REU address registers.
3. Sets `REU_C64_ADDR_L/H` to `vmmTempByte` (a 1-byte scratchpad in VmmData).
4. Sets transfer length to 1 byte.
5. Writes `REU_CMD_FETCH` (`$91`) to `REU_COMMAND` — triggers DMA REU→C64.
6. Loads and returns `vmmTempByte`.

#### `vmmWriteByte`

```text
Input:  A = byte to write, VmmSegLo/Hi, VmmOffLo/Hi
```

1. Saves byte to `vmmTempByte`.
2. Guards on `vmmInitialized` (silently returns if not initialized).
3. Calls `vmmComputeAddress`.
4. Sets REU registers pointing to `vmmTempByte`.
5. Writes `REU_CMD_STASH` (`$90`) — triggers DMA C64→REU.

#### `vmmComputeAddress` (private)

```text
Input:  VmmSegLo/Hi, VmmOffLo/Hi
Effect: Sets REU_REU_ADDR_L, REU_REU_ADDR_H, REU_REU_BANK
Clobbers: A, Y, TempLo, TempHi (saves/restores via stack)
```

Computes the 20-bit physical address:

```asm
Address = (Segment << 4) + Offset

Addr_L   = (SegLo << 4)              [low 8 bits]
Addr_H   = (SegLo >> 4) | (SegHi << 4) [middle 8 bits]
Addr_B   = (SegHi >> 4)              [upper 4 bits = bank]
```

Then adds `VmmOffLo/Hi` to `Addr_L/H/B` with carry propagation to set the final REU address registers.

**Preservation contract**: `vmmComputeAddress` preserves `Y` (and `TempLo/Hi`) via stack push/pop. This matters because the environment variable loops (`siZeroEnvByte`, `eaValLoop`, etc.) use `Y` as an offset and call `vmmWriteByte` inside the loop.

#### REU Hardware Registers

| Register | Address | Direction | Purpose |
|----------|---------|-----------|---------|
| `REU_STATUS` | `$DF00` | R | Status / interrupt flags |
| `REU_COMMAND` | `$DF01` | W | DMA trigger + mode |
| `REU_C64_ADDR_L` | `$DF02` | W | C64 base address lo |
| `REU_C64_ADDR_H` | `$DF03` | W | C64 base address hi |
| `REU_REU_ADDR_L` | `$DF04` | W | REU address lo |
| `REU_REU_ADDR_H` | `$DF05` | W | REU address hi |
| `REU_REU_BANK` | `$DF06` | W | REU bank (64 KB units) |
| `REU_LEN_L` | `$DF07` | W | Transfer length lo |
| `REU_LEN_H` | `$DF08` | W | Transfer length hi |

---

### 8.8 `file.asm` — Handle-Based File I/O

**File**: [src/command64/file.asm](src/command64/file.asm)  
**Segment**: `File` @ `$0CE0`

The file system presents an 8-handle table that wraps the C64's KERNAL logical file numbers (LFNs). The OS pre-assigns LFNs 2–9 to handles 0–7 to avoid channel conflicts with the directory (LFN 13), existence probe (LFN 14), and command channel (LFN 15).

#### Handle Table Layout (`$038E`)

```text
Byte 0: Status (0 = free, 1 = open)
Byte 1: LFN (pre-assigned: handle 0 → LFN 2, handle 1 → LFN 3, ..., handle 7 → LFN 9)
```

The table is a flat array of 16 bytes (8 handles × 2 bytes). Entry for handle N starts at offset `N*2`.

#### `fileInit`

Clears `HandleTable` (16 bytes) and pre-assigns LFNs:

```asm
for h = 0..7:
  HandleTable[h*2]   = 0       (free)
  HandleTable[h*2+1] = h + 2   (LFN)
```

#### `fileOpen`

```text
Input:  X/Y = pointer to null-terminated filename
        HexValLo = mode (0 = read, 1 = write)
        HexValHi = file type character for write ('P'=$50, 'S'=$53, or 0 for default 'P')
Output: A = handle (0–7) on success, or $FF on error
        C = 0 success, C = 1 error
```

1. Parses device prefix from filename via `parsePointerDevice`.
2. Scans `HandleTable` for a free slot.
3. Copies filename to `fileScratch` (`$1F92`).
4. Calls `normalizeName` on the copy.
5. If write mode: appends `,<type>,W` to `fileScratch` (e.g. `,P,W` for a PRG write).
6. Calls `KernalSETNAM` (length, `fileScratch` pointer), `KernalSETLFS` (LFN from table, `TargetDevice`, SA=LFN for uniqueness), `KernalOPEN`.
7. On KERNAL error: closes the LFN (to release the channel) and returns error.
8. On success: marks handle as open, returns handle index.

> **Why SA = LFN?** Using the LFN as the secondary address ensures each open file gets a unique secondary address on the device, which is required by the 1541 for concurrent file access.

#### `fileClose`

```text
Input:  A = handle
Output: C = 0 success, C = 1 error (handle not open)
```

Converts handle to table offset (`ASL`), checks status, calls `KernalCLOSE` with the LFN, clears the status byte.

#### `fileRead`

```text
Input:  A = handle
        X/Y = destination buffer pointer
        HexValLo/Hi = requested byte count
Output: HexValLo/Hi = actual bytes read
        C = 0 success, C = 1 error
```

1. Validates handle is open.
2. `KernalCHKIN` with the LFN to redirect input to the file.
3. Loop: checks `KernalREADST` (non-zero = EOF/error → stop), calls `KernalChRIN`, stores byte via `(PrintPtrLo),Y`, increments `PrintPtrLo/Hi` and byte count.
4. `KernalCLRCHN` to restore keyboard input.
5. Writes actual count back to `HexValLo/Hi`.

#### `fileWrite`

```
Input:  A = handle
        X/Y = source buffer pointer
        HexValLo/Hi = byte count to write
Output: HexValLo/Hi = actual bytes written
        C = 0 success, C = 1 error
```

Mirror of `fileRead` but uses `KernalCHKOUT` + `KernalChROUT`.

#### `fileDelete`

```text
Input:  X/Y = pointer to null-terminated filename
Output: C = 0 success, C = 1 error
```

Constructs a CBM DOS "scratch" command in `fileScratch`: `S0:<filename>`.  

- `$53` = unshifted `S`  
- `'0'` = drive number  
- `':'` = separator  
- Then appends the filename.  
Calls `normalizeName`, then opens LFN 15 (command channel, SA 15) which causes the drive to execute the command, then closes it.

> **Encoding note**: The command prefix bytes (`$53`, `$52`, `$55`, `$42`, `$50`) are written as explicit hex literals, **not** as `'S'` or `'R'` character literals. Under `.encoding "petscii_mixed"`, uppercase character literals assemble to shifted PETSCII (`$C3`–`$DA`), which the 1541 command parser rejects with error 31 (syntax error). Explicit bytes bypass this.

#### `fileRename`

```text
Input:  X/Y = pointer to old name
        PrintPtrLo/Hi = pointer to new name
Output: C = 0 success, C = 1 error
```

Constructs a CBM DOS rename command in `fileScratch`: `R0:<newname>=<oldname>`.  
The separator `=` is required by CBM DOS rename syntax.  
Opens LFN 15 / SA 15 (command channel) to execute.

---

### 8.9 `shell.asm` — Command Shell and Built-in Commands

**File**: [src/command64/shell.asm](src/command64/shell.asm)  
**Segments**: `CommandTable` @ `$1080`, `CommandShell` @ `$1130`

This is the largest and most complex module. It contains:

- The command dispatch table.
- The OS entry point (`start`) and main loop.
- `shellReadLine` — input handler.
- `shellDispatch` and `cmdCompare` — command routing.
- All 20 built-in command handlers.
- Environment variable subroutines.

#### 8.9.1 Command Table

Format: 8 bytes per entry = 6-byte space-padded ASCII name + 2-byte handler address (little-endian). The table is terminated by the label `tableEnd`. The loop in `shellDispatch` uses `tableEnd - tableCmd` as the upper bound.

```text
Offset  Name      Handler
0       "exit  "  cmdExit
8       "cls   "  cmdCls
16      "echo  "  cmdEcho
24      "load  "  cmdLoad
32      "dir   "  cmdDir
40      "ver   "  cmdVer
48      "help  "  cmdHelp
56      "type  "  cmdType
64      "copy  "  cmdCopy
72      "del   "  cmdDel
80      "erase "  cmdDel
88      "ren   "  cmdRen
96      "rename"  cmdRen
104     "drive "  cmdDrive
112     "device"  cmdDrive
120     "dev   "  cmdDrive
128     "run   "  cmdRun
136     "go    "  cmdRun
144     "set   "  cmdSet
152     "vol   "  cmdVol
160     "path  "  cmdPath
```

#### 8.9.2 OS Startup (`start`)

The entry point after the BASIC `SYS`:

```asm
start:
  STA CurrentDevice = 8        ← default drive
  JSR vmmInit                  ← probe REU; set vmmInitialized
  JSR fileInit                 ← clear handle table
  [if no REU: print warning, proceed degraded]
  [if REU: allocate 4KB env segment (256 paragraphs)]
    JSR vmmAlloc  VmmSeg=0:1
    [on success: zero all 4096 env bytes via vmmWriteByte loop]
  CLS ($93), lowercase mode ($0E)
  JSR cmdVer                   ← print banner
mainLoop:
  JSR printPrompt              ← print "C64[N]:> "
  JSR shellReadLine            ← block for user input
  JSR shellDispatch            ← parse and execute
  JMP mainLoop
```

**Environment initialization detail**: After `vmmAlloc` returns, the shell zeros the entire 4 KB environment segment. This is necessary because REU RAM contains garbage on power-up. The zero loop uses `X` as a page counter (16 pages) and `VmmOffLo` as the byte counter (wraps at 256 naturally), calling `vmmWriteByte` for each byte. `vmmWriteByte` preserves `Y` (via the stack save in `vmmComputeAddress`), but clobbers `A`, so the design uses `X` as the outer page counter and `VmmOffLo` wrap behavior for the inner loop.

#### 8.9.3 `shellReadLine`

```
Input:  (none) — reads from keyboard
Output: CommandBuffer contains null-terminated input
        CommandLen = number of characters read
Clobbers: A, Y
```

Raw input loop using `KernalGetIn` (non-blocking, `$FFE4`). The loop is:

```
Y = 0
loop:
  push Y; poll KernalGetIn until non-zero; pop Y; restore A
  if A == CR ($0D): done
  if A == DEL ($14):
    if Y == 0: ignore (buffer empty)
    else: Y--; echo destructive backspace
  else:
    echo char (KernalChROUT)
    CommandBuffer[Y++] = char
    if Y == 79: done (preserve one byte for null)
write CommandBuffer[Y] = 0
CommandLen = Y
echo CR
```

**Key design point**: `KernalGetIn` clobbers `Y`. The `TYA; PHA; ... PLA; TAY` sandwich preserves `Y` across each poll. `X` is used to temporarily hold the character because `KernalChROUT` preserves `X`.

#### 8.9.4 `shellDispatch`

```
Input:  CommandBuffer (null-terminated), CommandLen
Clobbers: A, X, Y, HandlerVecLo/Hi, ParsePos
```

1. Skip leading spaces. If result is null → return (empty line).
2. Save `Y` to `ParsePos` (start of command name).
3. Walk command table: `X` = current entry offset (0, 8, 16, ...).
4. For each entry, call `cmdCompare`. If Z=1: found → load handler address, `JMP (HandlerVecLo)`.
5. If table exhausted: attempt external command search.

**External command path:**

1. Extract the command name token (scan to space or null).
2. Reject names starting with `$` (prevents loading the directory listing as a program).
3. Call `parsePointerDevice` to resolve optional device prefix.
4. Call `findFile` to probe the disk for the program.
5. If found: set `SpecificLoad = 0` (relocated), `HexValLo/Hi = UserProgStart` (currently `$2C00`).
6. Call `shellLoadPrg`.
7. On success: `JSR UserProgStart`. The external program runs; when it returns (via `RTS` or `DOS_EXIT`), control returns here.

#### 8.9.5 `cmdCompare`

The table-walk comparison subroutine. Critical invariant: **X always holds the entry base offset**; it is never incremented inside `cmdCompare`.

```
Input:  X = entry base offset in tableCmd
        ParsePos = first non-space char index in CommandBuffer
Output: Z=1 (match): ParsePos updated to first arg char; X = entry_base + TABLE_NAME_LEN
        Z=0 (mismatch): X restored to entry_base
```

Algorithm:

1. Save X to `CmpBase`.
2. Loop from `Y = ParsePos`, comparing `CommandBuffer[Y]` vs `tableCmd[CmpBase + (Y - ParsePos)]`.
3. If input hits space before 6 chars: check that table is padded with space there (partial match).
4. If input hits null: same check (command with no argument).
5. If both exhausted after 6 chars: `ccSetMatch` — update `ParsePos` to first arg, set `X = CmpBase + 6`, load `A=0` (sets Z=1).
6. On mismatch: restore `X = CmpBase`, load `A=1` (sets Z=0).

The returned `ParsePos` skips any remaining spaces between the command name and its first argument, so built-in handlers can immediately start parsing at `ParsePos`.

#### 8.9.6 Built-in Command Handlers

**`cmdExit`**  
`JMP $E37B` — the BASIC warm-start vector. Prints `READY.` and enters BASIC.

**`cmdCls`**  
Outputs `$93` (PETSCII clear screen) then `$0E` (switch to mixed-case charset). The charset switch is required because the clear-screen resets the C64 to uppercase-only mode.

**`cmdEcho`**  
Prints `CommandBuffer[ParsePos..]` then CR. Trivially echoes the argument text.

**`cmdLoad`** — Load PRG from disk  

1. Parse filename token.
2. Check for optional hex address argument → `SpecificLoad = 0` (relocated) or `1` (header).
3. Parse device prefix via `parsePointerDevice`.
4. Count filename length.
5. **Address given, explicitly protected**: `aptProtectedCheck` rejects the request immediately (`protected address`) before touching the disk (fast path, added alongside the pre-flight validation below).
6. **No address given**: `aptFindFreeRegion` (a page-aligned sliding-window scan starting at `UserProgStart`, skipping past protected regions and any registered app's range) picks the first free region large enough for the file, using the size resolved by `getFileSize` (see below).
7. **Relocated loads (`SpecificLoad = 0`)**: `getFileSize` resolves the file's byte size ahead of time via a directory-only read (`"$0:filename"`, secondary address 0 — skips the header line, parses the next line's block count, converts to bytes with `calcFileSize`). `aptCheckRange` then validates `[address, address + size)` against protected ranges (`< UserProgStart` or `>= $C000`, including 16-bit wraparound) and every other registered app's range. Any collision aborts the load before the KERNAL `LOAD` call runs (`protected address` / `address overlap`) — memory is never partially transferred.
8. `findFile` → `shellLoadPrg` → `aptRelocate` (patches a relocatable binary's absolute high bytes if the file has the `'R','6'` magic footer; otherwise treated as a plain non-relocatable PRG) → `aptRegister`.
9. On success: `aptPrintLoadInfo` prints a `name / addr / size` hex report (same layout as `APPS`/`PS`).
10. Restore `CurrentDevice` on both success and error.

**`cmdRun`** — Execute program in memory  
Without argument: searches the App Table for a program registered at `UserProgStart` (`aptFind`, address mode) and jumps to it if found; otherwise reports not loaded.  
With a name argument: `aptFind` (name mode) resolves the registered load address.  
With a hex address argument: parse via `parseHex`, either resolved directly via `aptFind` (address mode) or, if not registered, treated as a raw jump target.  
The inner `crJump`/`crExecute` path using `JMP (HandlerVecLo)` allows the `JSR` to be a normal subroutine call; the program's `RTS` returns here, and then a final `RTS` returns to `mainLoop`.

**`cmdDir`** — Directory listing  
Opens LFN 13 with filename `$` (directory) and secondary address 0 (read). The C64 CBM DOS responds to opening `$` with a BASIC-tokenized directory stream. The shell:

1. Skips the 2-byte load address.
2. For each "BASIC line": reads 2-byte link pointer, 2-byte block count, then the name until null.
3. Prints block count (decimal via `printDecimal16`), the name, and — for real file entries (lines containing a quoted name, as opposed to the header or the trailing `BLOCKS FREE` line) — the byte size in parentheses, e.g. `"FILENAME" (508 bytes)`. The byte size is computed by `calcFileSize` (`Size = Blocks*254 = Blocks*256 - Blocks*2`, avoiding a multiply loop) and printed via `printDecimal24` (24-bit decimal with leading-zero suppression).
4. Stops when the link pointer is `$0000` (EOF).

**`cmdType`** — Display file contents  
Uses the API layer (`DOS_OPEN_FILE`, `DOS_READ_FILE` 64 bytes at a time into `CommandBuffer`, `DOS_CLOSE_FILE`). Prints raw bytes to screen — no translation.

**`cmdDel` / `cmdErase`** — Delete file  
Calls `DOS_DELETE_FILE` via `apiHandler`.

**`cmdRen` / `cmdRename`** — Rename file  
Parses two name tokens (null-terminates each in `CommandBuffer`). Calls `DOS_RENAME_FILE` with old-name in `X/Y` and new-name in `PrintPtrLo/Hi`.

**`cmdCopy`** — Copy file  
Full source→destination copy:

1. Parse source and destination filenames; resolve device prefixes.
2. Call `getSourceFileType` to determine the file type (`P`, `S`, or `U`).
3. Open source for read (`DOS_OPEN_FILE`, mode 0).
4. Open destination for write (`DOS_OPEN_FILE`, mode 1, `HexValHi` = file type char).
5. 64-byte read/write loop until EOF.
6. Close both handles.

`getSourceFileType` reads the directory listing for the source file's device and parses the filename and type field from the directory stream. Returns `'P'`, `'S'`, or `'U'` (PRG, SEQ, USR). Case-insensitive comparison via `petsciiToLower`. Defaults to `'P'` if directory read fails or file not found.

**`cmdDrive` / `cmdDevice` / `cmdDev`** — Switch active device  
Without argument: prints `"Current device: N"`.  
With argument `8`, `9`, `10`, or `11`: stores in `CurrentDevice`.

**`cmdSet`** — Environment variables  

- `SET` alone: print all variables (scan env segment from VmmOff=0).
- `SET VAR`: query; print value after `=` if found.
- `SET VAR=VAL`: set variable.
  - Parse VAR into `SourceBuf` (normalizing to unshifted PETSCII).
  - `envSearch` — scan env segment for existing `VAR=...` entry.
  - If found: `envDelete` (shift remainder down).
  - If VAL is non-empty: `envFindEnd` + `envAppend`.

Environment segment format: a sequence of null-terminated `VAR=VALUE` strings followed by a double-null terminator (`\0\0`). The 4 KB segment was zeroed at startup, so the initial state is all `$00` — a valid empty environment (double-null at offset 0).

**`cmdPath`** — Set/query PATH environment variable  
Sugar over `cmdSet`: hard-codes `SourceBuf = "path"` and calls `envSearch` / `envDelete` / `envAppend`.

**`cmdVol`** — Show disk volume label  
Opens directory (`$`) on `CurrentDevice` and parses the CBM DOS header line format: `0 "DISKNAME       " ID 2A`. Extracts disk name (between quotes) and disk ID (next two non-space chars after the closing quote). Prints: `Volume in drive N is DISKNAME` and `Volume ID is AB`.

**`cmdVer`**  
Prints the `verMsg` string: `"Command 64-DOS Version M.m.s.NNNN\r\r"`.

**`cmdHelp`**  
Prints the `helpMsg` string — a fixed multi-line help listing.

#### 8.9.7 Environment Variable Subroutines

All operate on the Master Environment Block at `EnvSegmentLo/Hi` via `vmmReadByte` / `vmmWriteByte`.

| Subroutine | Description |
|-----------|-------------|
| `envSearch` | Scans for `SourceBuf=...` entry. Returns `C=0` + `VmmOff` at start of match, or `C=1` + `VmmOff` at end of block. |
| `envDelete` | Removes the string at `VmmOff` by byte-shifting the remaining data left. Writes the new double-null at the end. |
| `envFindEnd` | Positions `VmmOff` at the correct write offset for appending (the byte before the trailing double-null). |
| `envAppend` | Writes `SourceBuf + '=' + CommandBuffer[ParsePos]` + double-null at `VmmOff`. Checks for 4 KB segment overflow. |
| `envPrintVal` | Scans forward to `=` then prints all bytes until null. |

**`envSearch` algorithm:**  

```
VmmOff = 0; VmmSeg = EnvSegment
loop:
  save VmmOff as "start of current string"
  read byte; if zero → block end (C=1, not found)
  compare bytes of SourceBuf[0..] against env bytes until VAR chars exhausted
  if next byte = '=' → match (C=0, restore VmmOff to saved start)
  else → scan to next null; advance past it; repeat
```

**`envDelete` algorithm:**  

```asm
dest = VmmOff (start of string to delete)
src  = VmmOff + strlen(string) + 1 (first byte after the null)
loop:
  read byte at src; write to dest; advance both
  if byte just moved was null: check next src byte
    if that is also null: write extra null at dest; done
```

---

## 9. Module Reference — External Commands

External commands are standalone PRG files that live at `UserProgStart` (currently `$2C00`). They use the OS API via `JSR $1000` and terminate with `DOS_EXIT`. They share `CommandBuffer`, `ParsePos`, and `CurrentDevice` with the shell (these are at fixed RAM addresses). Non-relocatable binaries compiled for a prior `UserProgStart` value can still run via the Binary Relocator (§13.1).

### 9.1 `debug.s` — Interactive Memory Monitor

**File**: [src/external/debug/debug.s](src/external/debug/debug.s)  
**Toolchain**: ca65/ld65 via `add_ca65_app`  
**Load address**: `UserProgStart` (currently `$2C00`)  
**Version**: 0.1.x (auto-incremented build number from `BUILD_DEBUG`)

DEBUG is a port of the MS-DOS `DEBUG.COM` interactive memory/register tool.

#### Zero Page Usage (private to DEBUG)

| ZP | Label | Purpose |
| ---- | ------- | --------- |
| `$70`–`$71` | `currentAddr` | 16-bit current address pointer |
| `$72`–`$73` | `rangeStart` | Range start address |
| `$74`–`$75` | `rangeEnd` | Range end address |
| `$76`–`$77` | `val1` | First hex argument |
| `$78`–`$79` | `val2` | Second hex argument / diff scratch |
| `$7A` | `DebugTemp` | Dump row counter / misc scratch |
| `$7B` | `disasmTemp` | Disassembler row/count scratch |
| `$7C` | `mnemIndex` | Matched mnemonic index (0–56) |
| `$7D` | `deducedMode` | Deduced addressing mode |
| `$7E`–`$7F` | `operandValLo/Hi` | Assembler parsed operand |

#### Entry Point (`start`)

Captures the CPU register state at the moment DEBUG is called (A, X, Y, P, S → `regA`, `regX`, `regY`, `regP`, `regS`), initializes `currentAddr = $0000`, prints the startup banner, then enters `mainLoop`.

#### `mainLoop`

```asm
print '-' prompt
JSR readLine       ← read into inputBuf (64-byte buffer), handles DEL
JSR dispatch       ← parse first char and jump to handler
JMP mainLoop
```

#### `dispatch`

Single-character command lookup. Normalizes shifted to unshifted (`AND #$7F`). Chain of `CMP / BNE`:

| Char | Command | Description |
|------|---------|-------------|
| `a` | `cmdAssemble` | Interactive 6502 assembler |
| `?` | `cmdHelp` | Show help |
| `q` | `cmdQuit` | Exit (calls `DOS_EXIT`) |
| `d` | `cmdDump` | Hex+ASCII memory dump |
| `e` | `cmdEnter` | Edit memory bytes interactively |
| `f` | `cmdFill` | Fill range with byte value |
| `m` | `cmdMove` | Copy memory block |
| `c` | `cmdCompare` | Compare two memory blocks |
| `s` | `cmdSearch` | Search for byte pattern |
| `u` | `cmdUnassemble` | Disassemble to 6502 mnemonics |
| `h` | `cmdHexMath` | Add and subtract two hex values |
| `g` | `cmdGo` | Execute (`JSR`) at address |
| `r` | `cmdRegs` | Show or modify registers |
| `v` | `cmdVer` | Show version |
| `n` | `cmdName` | Set filename for load/write |
| `l` | `cmdLoad` | Load binary from disk |
| `w` | `cmdWrite` | Write binary to disk |

**`cmdDump`**: Dumps 8 bytes per row with address, hex (with `:` separator at 4 bytes), and PETSCII printable view. Supports range syntax (`D L H`) and single address (`D ADDR`). Uses `DebugTemp` as a row counter (16 rows = 128 bytes by default).

**`cmdHexMath`**: Parses two hex arguments, prints their sum and difference as 4-digit hex values separated by two spaces.

**`cmdRegs`**: Without argument: prints all saved registers (A, X, Y, P, S) and a disassembly of `currentAddr`. With single-register argument (`r a`, `r x`, etc.): prompts for new hex value and updates the register save buffer.

**`cmdAssemble`**: The Phase 2 interactive assembler. Accepts a starting address, then loops prompting for mnemonics and operands (in MS-DOS DEBUG syntax). Parses mnemonics against a 57-entry mnemonic table, deduces addressing mode from operand syntax (14 modes), and emits the correct opcode byte(s) directly to RAM.

**`cmdUnassemble`**: Disassembles memory from `currentAddr` (or a specified range) using the same mnemonic and mode tables as the assembler.

#### API Wrappers (in debug.s)

```asm
API_PRINT_STR:
    tax           // Move X=lo into correct position
    lda #DOS_PRINT_STR
    jsr OS_API
    rts

API_EXIT:
    lda #DOS_EXIT
    jsr OS_API
    rts
```

---

### 9.2 `label.asm` — Disk Volume Label Writer

**File**: [src/external/label/label.s](src/external/label/label.s) (built with ca65/ld65, not KickAssembler — see `brain/plans/2026-07-08-ca65-adoption-and-spike-migration.md` Phase 4)  
**Load address**: `UserProgStart` (currently `$2C00`)

LABEL directly edits the CBM DOS directory structure on disk (Track 18, Sector 0, byte offset 144) to set the 16-byte volume name field.

#### Protocol (CBM DOS Direct Access)

```
1. Open command channel (LFN 15, SA 15, no filename)
2. Send "I\r" — Initialize drive (clear stuck buffers)
3. Open data buffer channel (LFN 2, SA 2, filename "#")
4. Send "U1:2 0 18 0\r" — Block Read T18/S0 into drive buffer
5. Send "B-P:2 144\r" — Position buffer pointer to volume name offset
6. Write 16 bytes via data channel (label padded with $A0)
7. Send "U2:2 0 18 0\r" — Block Write drive buffer back to T18/S0
8. Close data channel
9. Read drive status from command channel (check "00" = success)
10. If success: send "I\r" again (force drive to re-read BAM cache)
11. Close command channel
```

#### Encoding Note

All CBM DOS command string bytes are written as explicit hex literals:

- `$49` = `I`, `$55` = `U`, `$42` = `B`, `$50` = `P`, `$52` = `R` (not `'I'`, `'U'`, etc.)

Uppercase character literals under either assembler's default PETSCII translation (Kick's `.encoding "petscii_mixed"`, or ca65's `-t c64` target) assemble to shifted PETSCII (`$C9`, `$D5`, etc.), which the 1541 command parser rejects with error code 31 (syntax error). Explicit bytes bypass any such translation entirely — this isn't an assembler-specific workaround, it's a genuine 1541 protocol constraint, so `label.s`'s ca65 port keeps every one of these tables byte-for-byte identical to the original.

#### Key Labels / Buffers

| Label | Purpose |
|-------|---------|
| `ArgIdx` ($70) | CommandBuffer index of label text start |
| `SavedDevice` ($71) | Saved `CurrentDevice` (restored on exit) |
| `labelBuf` (in PRG) | 16-byte volume name buffer, pre-padded with `$A0` |
| `statusBuf` (in PRG) | 40-byte drive status response buffer |
| `cmdInit/U1/BP/U2` | Null-terminated CBM DOS command strings (explicit byte literals) |

#### Volume Name Rules

- 1–16 characters; longer than 16 → error `"Label too long (max 16)"`.
- Padded with `$A0` (PETSCII shifted space, the standard CBM name-field fill byte).
- Device prefix (`8:`, `9:`, etc.) is parsed via `DOS_PARSE_PREFIX` and stripped before writing.

---

### 9.3 `conway.asm` — Conway's Game of Life

**Files**: [src/external/conway/conway_main.s](src/external/conway/conway_main.s), [conway_grid.s](src/external/conway/conway_grid.s) (built with ca65/ld65, not KickAssembler — see `brain/plans/2026-07-08-ca65-adoption-and-spike-migration.md` Phase 4)  
**Load address**: `UserProgStart` (currently `$2C00`)

Full-screen cellular automaton. The 40×25 text screen is used 1:1 as the simulation grid (1000 cells). Rules: B3/S23 with toroidal wrapping on all four edges.

#### Double-Buffer Design

Two 960-byte page-aligned buffers (`grid0`/`grid1`, embedded in-binary via a source-level `.align 256`, not fixed addresses) alternate roles each generation. `computeNext` reads from the active buffer via `zpPrev/Curr/Next` row pointers and writes results to the inactive buffer via `zpDst`. `swapBufs` toggles `zpBufSel` (0↔1) to exchange roles. Page-alignment allows multi-page iteration with a plain `INC zpHi` rather than a full 16-bit pointer increment. (Buffers were relocatable-address embedded, not hardcoded to `$3000`/`$3400`, after a relocation-crash fix — see `getCurrBase`/`getNextBase` below.)

#### Row Pointer Setup (`setThreeRowPtrs`)

A 25-entry precomputed table (`rowOffLo` / `rowOffHi`) stores `N × 40` for rows 0–24, avoiding a runtime multiply. For each row, three 16-bit base+offset additions set `zpPrev`, `zpCurr`, and `zpNext` to their row start addresses. Carry from the lo-byte `ADC` propagates naturally into the hi-byte add, making the arithmetic correct for offsets that cross a page boundary (rows 7+).

#### Neighbour Accumulation

For each cell, the column loop resolves left/right column indices with compare-and-substitute for the toroidal wrap at columns 0 and 39. Six `(ptr),Y` reads (three rows × left column), two center-column reads, and six more right-column reads accumulate the 8-cell Moore count into `zpCount`. Conway B3/S23 rules are applied with a simple branch tree; result is written to `(zpDstLo),Y`.

#### Branch Distance

The column loop body is ~140 bytes — beyond the 6502 ±127-byte relative-branch limit. The back-edge uses `BEQ cnColDone / JMP cnColLoop`.

#### Key Labels

| Label | ZP / Address | Purpose |
| --- | --- | --- |
| `zpPrevLo/Hi` | `$70–$71` | Previous-row pointer in active buffer |
| `zpCurrLo/Hi` | `$72–$73` | Current-row pointer in active buffer |
| `zpNextLo/Hi` | `$74–$75` | Next-row pointer in active buffer |
| `zpDstLo/Hi` | `$76–$77` | Destination-row pointer in inactive buffer |
| `zpRow` | `$78` | Row loop index (0–24) |
| `zpCol` | `$79` | Column loop index (0–39) |
| `zpCount` | `$7A` | Accumulated neighbour count |
| `zpLfsr` | `$7B` | 8-bit Galois LFSR state (RNG) |
| `zpPaused` | `$7C` | Pause flag: 0 = running, $FF = paused |
| `zpBufSel` | `$7D` | Active buffer: 0 = `grid0`, 1 = `grid1` (relocatable page-aligned labels) |
| `rowOffLo/Hi` | in PRG | 25-entry row-offset table (N×40, lo and hi bytes) |
| `cellCharTbl` | in PRG | 2-byte display map: `[0]=$20` (space), `[1]=$A0` (solid block) |
| `stpBLo/Hi` | in PRG | Scratch: buffer base address saved across `setThreeRowPtrs` calls |
| `dgPageCnt` | in PRG | Outer page counter for `drawGrid` (X clobbered by `TAX` inside loop) |

#### Subroutine Summary

| Routine | Description |
| --- | --- |
| `start` | Entry point: seed LFSR, set colors, call `randomizeGrid` + `drawGrid`, enter `mainLoop` |
| `mainLoop` | Poll keys, wait delay, `computeNext`, `swapBufs`, `drawGrid`, repeat |
| `handleKeys` | Non-blocking `KernalGetIn` poll; dispatches Q/STOP/SPACE/R/C |
| `waitDelay` | Busy-waits `GEN_DELAY` jiffy ticks (default 3, ≈50 ms per generation) |
| `computeNext` | Outer row loop → `setThreeRowPtrs` + `setDstRowPtr` → inner column loop with neighbour count and rule application |
| `setThreeRowPtrs` | Sets `zpPrev/Curr/Next` from active buffer base + `rowOffLo/Hi[zpRow±1]` |
| `setDstRowPtr` | Sets `zpDst` from inactive buffer base + `rowOffLo/Hi[zpRow]` |
| `getCurrBase` | Returns active buffer base (A=lo, X=hi) based on `zpBufSel` |
| `getNextBase` | Returns inactive buffer base (A=lo, X=hi) based on `zpBufSel` |
| `swapBufs` | `zpBufSel ^= 1` |
| `randomizeGrid` | Fills active buffer with ~25% live cells via LFSR; alive when `(LFSR & $0A) == 0` |
| `clearGrid` | Zeros all 1000 cells in active buffer |
| `drawGrid` | Copies active buffer to screen RAM (`$0400`), converting via `cellCharTbl` |
| `clearScreen` | Fills screen RAM with `$20` (space) |
| `lfsrStep` | Advances `zpLfsr` one step; result in A. Galois right-shift, mask `$B8` |

---

### 9.4 `pacman.asm` — Pac64

**File**: [src/external/pacman/pacman.asm](src/external/pacman/pacman.asm)  
**Load address**: `UserProgStart` (currently `$2C00`)

Character-grid Pac-Man clone. The 40×24 playfield (row 24 is a dynamic status
line) is rendered directly to screen/colour RAM, following the same
direct-write, jiffy-polled, `KernalGetIn`-driven conventions as `conway.asm`.
Unlike conway's whole-grid-per-generation update, movement here is
grid-locked and per-actor: Pac-Man and each of the four ghosts carry their
own jiffy-driven move timer, so speeds are independently tunable without a
raster IRQ.

#### Maze Tables

`mazeWalls` (read-only: 0=open, 1=wall, 2=ghost-only door) and `mazeItems`
(mutable: 0=empty, 1=dot, 2=power pellet) are both ordinary labelled data —
unlike conway's buffers, they are **not** pinned to fixed addresses. Conway's
own code fits under 1KB, leaving headroom below its hardcoded `$3000`/`$3400`
buffers, but a full ghost-AI game does not reliably fit in the ~1KB gap
between `UserProgStart` ($2C00) and `$3000`; the assembler places both
tables wherever they naturally fall instead, removing the collision risk.
`mazeItems` is reserved via `.fill 960,0` and regenerated at runtime by
`resetItems`.

#### Ghost AI

Each ghost (`GHOST_BLINKY/PINKY/INKY/CLYDE`) is a parallel-array entry
(`ghostRow/Col/Dir/Mode/MoveTimer/ReleaseTimerLo/Hi/TargetRow/Col`), not a
copy-pasted variable set. `ghostMoveTick` runs a two-pass structure each
elapsed tick: pass 1 (`computeGhostTarget`) computes every pending ghost's
target tile from positions as they stand at the start of the tick — so
Inky's target reads Blinky's pre-move position regardless of update order —
then pass 2 (`moveOneGhost`) resolves and applies each pending ghost's move.
Legal directions are narrowed by minimum squared distance to the target
(`calcDistSq`, via the precomputed `sqrTbl`), tie-broken in fixed order
up > left > down > right, excluding the reverse of the current heading
(except while `MODE_EATEN`). Scatter/chase phase flips
(`phaseTimerTick`) and the frightened-mode pellet timer
(`frightTimerTick`) each force a reversal on the ghosts they affect.
Ghost-house release (`houseReleaseTick`) is a v1 simplification: a
housed ghost pops directly to the door-exit tile when its own release timer
expires, rather than authentic dot-count-based release.

#### Score Rendering

The 3-byte binary score is expanded to 6 decimal digits via repeated
subtraction against a table of 24-bit powers of ten (`cmp24GE`/`sub24`),
the same technique needed because a 16-bit counter would overflow well
before a real game ends.

#### Key Labels

| Label | ZP / Address | Purpose |
| --- | --- | --- |
| `zpCellLo/Hi` | `$70–$71` | Generic maze-cell pointer (wall/item lookup) |
| `zpDrawLo/Hi` | `$72–$73` | Screen/colour RAM draw pointer |
| `zpTmpA` | `$74` | Scratch for squared-distance/address math |
| `zpLfsr` | `$75` | 8-bit Galois LFSR state (frightened-ghost RNG) |
| `mazeWalls` | in PRG | 960-byte hand-authored maze (0=open, 1=wall, 2=door) |
| `mazeItems` | in PRG | 960-byte mutable dot/pellet state, regenerated by `resetItems` |
| `rowOffLo/Hi` | in PRG | 24-entry row-offset table, shared by every single-cell pointer helper |
| `sqrTblLo/Hi` | in PRG | Squared-distance table (index 0-39), avoids a runtime multiply |

#### Subroutine Summary

| Routine | Description |
| --- | --- |
| `start` | Entry point: seed LFSR, init state, `resetItems` + `resetPositions`, draw everything, enter `mainLoop` |
| `mainLoop` | Poll keys; while playing, run `checkTick`/`tickUpdate`; while paused-for-life-lost/level-clear, run `pauseStateTick`; game-over waits for any key |
| `handleKeys` | Non-blocking `KernalGetIn` poll; WASD buffers `pacNextDir`, P/SPACE pause, Q/STOP quit |
| `tickUpdate` | Per-elapsed-tick dispatch: house release, Pac-Man move, ghost move, phase/frightened timers, collision check |
| `updatePacman` | Resolves the buffered turn or current heading via `canMovePac`, moves one tile, consumes items |
| `canMovePac` / `canMoveGhost` | Shared target-tile + legality check; Pac-Man is blocked by walls and doors, ghosts only by walls |
| `ghostMoveTick` | Two-pass per-tick ghost update (see Ghost AI above) |
| `computeGhostTarget` | Per-personality target-tile computation (Blinky/Pinky/Inky/Clyde) |
| `moveOneGhost` | Resolves and applies one ghost's tile move (distance-scored or random-frightened) |
| `houseReleaseTick` / `phaseTimerTick` / `frightTimerTick` | Independent timers for ghost-house release, scatter/chase phase, and frightened duration |
| `collisionCheck` / `eatGhost` / `loseLife` | Tile-equality collision resolution and its two outcomes |
| `resetItems` | Regenerates `mazeItems` from `mazeWalls`, carves out the ghost house, places the four pellets |
| `resetPositions` | Resets Pac-Man/ghost tiles, directions, modes, and timers (never touches `mazeItems`) |
| `drawMaze` / `drawActors` | Full-screen redraw of the maze, then Pac-Man and all four ghosts on top |
| `renderScoreLivesLevel` | Updates the score/lives/level digit fields on the status row |

---

## 10. API Call Stacks

### External Program → Print String

```asm
EXTERNAL PROGRAM
  lda #DOS_PRINT_STR   ; $09
  ldx #<myString
  ldy #>myString
  jsr $1000            ; stable stub
    → jmp apiHandler
        → ahPrintStr
            txa              ; A = string lo
            jsr petPrintString
                sta PrintPtrLo
                sty PrintPtrHi
                ldy #0
                loop: lda (PrintPtrLo),y → jsr KernalChROUT → iny → bne loop
            clc
            rts          ; back to apiHandler
        rts              ; back to external program
```

### External Program → Open File

```asm
EXTERNAL PROGRAM
  lda #0               ; read mode
  sta HexValLo
  ldx #<"myfile"
  ldy #>"myfile"
  lda #DOS_OPEN_FILE   ; $3D
  jsr $1000
    → apiHandler → ahOpen → fileOpen
        stx NamePtrLo ; sty NamePtrHi
        ldx #NamePtrLo
        jsr parsePointerDevice  ; strip device prefix if any
        scan HandleTable for free slot
        copy filename to FileScratch
        jsr normalizeName       ; shift→unshifted conversion
        if write mode: append ",P,W"
        jsr KernalSETNAM
        jsr KernalSETLFS  (LFN from table, device, SA=LFN)
        jsr KernalOPEN
        [on error: jsr KernalCLOSE; sec; lda #$FF; rts]
        mark handle open
        txa; lsr       ; A = handle index
        clc; rts
    rts  ; C=0, A=handle
```

### Shell → Load External Command

```
shellDispatch (table miss)
  → sdExtScan: find token end
  → parsePointerDevice: resolve device
  → findFile
      → normalizeName (in-place on CommandBuffer slice)
      → checkExistence
          KernalSETMSG #0
          KernalSETLFS (LFN=14, device, SA=0)
          KernalSETNAM
          KernalOPEN
          KernalCLOSE #14
          PLP → return carry
  bcs sdExtError (not found)
  → shellLoadPrg
      KernalSETNAM
      KernalSETLFS (LFN=1, device, SA=SpecificLoad)
      KernalSETMSG #0
      petPrintString "loading..."
      KernalLOAD (A=0, X/Y=target)
  bcs sdExtError (load error)
  → JSR UserProgStart (currently $2C00)
      [program executes; may call DOS_EXIT → resets SP → JMP mainLoop]
      [or: program RTS → return here]
  rts → mainLoop
```

### VMM Allocate + Read/Write Cycle

```
CALLER
  lda #<paragraphs_lo
  sta VmmSegLo
  lda #<paragraphs_hi
  sta VmmSegHi
  jsr vmmAlloc
    check vmmInitialized
    guard zero-paragraphs
    compute page count: (paragraphs + 255) >> 8 → TempHi
    scan MCT at $C000 for TempHi contiguous PAGE_FREE bytes
    mark PAGE_HEAD + PAGE_TAIL
    return: VmmSegHi=pageIndex, VmmBank=blockIndex, A=VMM_SUCCESS

  lda VmmSegHi → sta VmmSegHi ; already set by vmmAlloc
  lda VmmBank  → sta VmmBank

  lda #0 ; sta VmmOffLo / VmmOffHi  (byte offset within allocation)
  lda #42 ; byte to write
  jsr vmmWriteByte
    sta vmmTempByte
    jsr vmmComputeAddress
        compute (Seg<<4)+Off → REU_ADDR_L/H/BANK
        [preserves Y via stack]
    REU_C64_ADDR = vmmTempByte
    REU_LEN = 1
    REU_COMMAND = REU_CMD_STASH ($90)  ← DMA C64→REU
    rts

  jsr vmmReadByte
    jsr vmmComputeAddress
    REU_C64_ADDR = vmmTempByte
    REU_LEN = 1
    REU_COMMAND = REU_CMD_FETCH ($91)  ← DMA REU→C64
    lda vmmTempByte
    rts    ; A = $2A (42)
```

### Environment Variable Set

```
cmdSet ("SET PATH=/programs")
  → envSearch (SourceBuf="path")
      VmmSeg = EnvSegment; VmmOff = 0
      loop: read env bytes, compare against "path"
      → match: check next byte = '='
      → return C=0, VmmOff = start of "PATH=..."
  → envDelete
      scan to null at end of this string
      byte-shift all subsequent bytes left, overwriting the deleted string
      write double-null at new end
  → envFindEnd
      scan to find correct append offset (before trailing double-null)
  → envAppend
      check VmmOffHi < $10 (4KB limit)
      write "path" bytes → vmmWriteByte each
      write '='
      write value bytes from CommandBuffer[ParsePos..]
      write null; write null (double-null terminator)
```

---

## 11. Code Graph and Interrelations

### Module Dependency Graph

```
command64.asm (root)
├── command64.inc  ←── imported by all modules (constants, ZP labels)
│   └── vmm.inc   ←── imported transitively
│
├── petsci.asm     (no dependencies on other OS modules)
│
├── api.asm        → petPrintString, vmmAlloc, vmmFree, fileOpen, fileClose,
│                    fileRead, fileWrite, fileDelete, fileRename,
│                    parsePointerDevice, mainLoop (DOS_EXIT)
│
├── utils.asm      (no calls to OS modules; uses KERNAL only)
│
├── loader.asm     → petPrintString, KernalSETNAM/SETLFS/SETMSG/LOAD
│
├── path.asm       → normalizeName, KernalSETMSG/SETLFS/SETNAM/OPEN/CLOSE
│
├── vmm.asm        (no calls to other OS modules; accesses REU registers directly)
│
├── file.asm       → parsePointerDevice, normalizeName,
│                    KernalSETNAM/SETLFS/OPEN/CLOSE/CHKIN/CHKOUT/CLRCHN/ChRIN/ChROUT/READST
│
└── shell.asm      → ALL modules
    (printPrompt → petPrintString → KernalChROUT)
    (shellReadLine → KernalGetIn, KernalChROUT)
    (shellDispatch → cmdCompare, shellLoadPrg, findFile, parsePointerDevice)
    (cmdLoad → findFile, shellLoadPrg, parsePointerDevice)
    (cmdRun → parseHex)
    (cmdDir → KernalSETNAM/SETLFS/OPEN/CHKIN/GetIn/ChROUT/READST/CLRCHN/CLOSE,
              printDecimal16)
    (cmdType → apiHandler)
    (cmdCopy → getSourceFileType, apiHandler)
    (cmdDel → apiHandler)
    (cmdRen → apiHandler)
    (cmdSet → vmmReadByte, vmmWriteByte, envSearch, envDelete, envFindEnd, envAppend)
    (cmdPath → envSearch, envDelete, envFindEnd, envAppend)
    (cmdVol → KernalSETNAM/SETLFS/OPEN/CHKIN/ChRIN/READST/CLRCHN/CLOSE,
              parsePointerDevice, printDecimal16, petPrintString)
    (cmdDrive → printDecimal16, petPrintString)
```

### External Program → OS Interaction

```
debug.prg / label.prg / user.prg
    ↓  JSR $1000  (stable stub)
    ↓  JMP apiHandler
    ↓
    ├── DOS_PRINT_STR  → petPrintString → KernalChROUT
    ├── DOS_OPEN_FILE  → fileOpen → parsePointerDevice, normalizeName,
    │                              KernalSETNAM/SETLFS/OPEN
    ├── DOS_READ_FILE  → fileRead → KernalCHKIN, KernalChRIN, KernalREADST, KernalCLRCHN
    ├── DOS_WRITE_FILE → fileWrite → KernalCHKOUT, KernalChROUT, KernalREADST, KernalCLRCHN
    ├── DOS_CLOSE_FILE → fileClose → KernalCLOSE
    ├── DOS_DELETE_FILE→ fileDelete → parsePointerDevice, normalizeName,
    │                                KernalSETNAM/SETLFS/OPEN/CLOSE
    ├── DOS_RENAME_FILE→ fileRename → parsePointerDevice, normalizeName,
    │                                KernalSETNAM/SETLFS/OPEN/CLOSE
    ├── DOS_ALLOC_MEM  → vmmAlloc → scans MCT at $C000
    ├── DOS_FREE_MEM   → vmmFree → clears MCT entries
    ├── DOS_EXIT       → resets stack → JMP mainLoop
    └── DOS_PARSE_PREFIX → parsePointerDevice
```

### LFN Allocation Strategy

| LFN | User | Purpose |
|-----|------|---------|
| 1 | Loader | KERNAL LOAD (always closed after load) |
| 2 | File handle 0 / label.asm | File I/O handle 0 / label direct-access channel |
| 3–9 | File handles 1–7 | File I/O |
| 13 | DIR / VOL / getSourceFileType | Directory listing (opened/closed per command) |
| 14 | checkExistence | File probe (opened/closed immediately) |
| 15 | fileDelete / fileRename / label.asm | CBM DOS command channel |

---

## 12. Shell Command Reference

| Command | Aliases | Syntax | Description |
|---------|---------|--------|-------------|
| `CLS` | — | `cls` | Clear screen, restore lowercase charset |
| `DIR` | — | `dir [device:]` | List directory; optional device prefix |
| `DRIVE` | `DEVICE`, `DEV` | `drive [8-11]` | Show or set active device |
| `ECHO` | — | `echo [text]` | Print text to screen |
| `EXIT` | — | `exit` | Return to BASIC warm start |
| `HELP` | — | `help` | Display command list |
| `LOAD` | — | `load <file> [addr]` | Load PRG; optional hex address overrides header. Without an address, `aptFindFreeRegion` auto-picks a free page-aligned region. Pre-flight-validates the destination range before touching disk and prints a name/addr/size report on success. |
| `TYPE` | — | `type <file>` | Display file contents |
| `COPY` | — | `copy <src> <dst>` | Copy file (cross-device supported) |
| `DEL` | `ERASE` | `del <file>` | Delete file |
| `REN` | `RENAME` | `ren <old> <new>` | Rename file |
| `RUN` | `GO` | `run [name\|addr]` | Execute a registered program by name or address; with no argument, runs whatever is registered at `UserProgStart` |
| `APPS` | `PS` | `apps` | List registered programs (name, address, size) |
| `FREE` | — | `free [name]` | Deregister a named program, or all non-running registered programs if no name is given |
| `SET` | — | `set [VAR[=VAL]]` | Show all / query / set environment variable |
| `PATH` | — | `path [value]` | Show or set `PATH` environment variable |
| `VOL` | — | `vol [device:]` | Show disk volume label and ID |
| `VER` | — | `ver` | Show OS version string |
| `<program>` | — | `[device:]<name> [args...]` | Load and execute external PRG from disk |

**Device prefix** (`8:`, `9:`, `10:`, `11:`) can be applied to filenames in `LOAD`, `DIR`, `COPY`, `DEL`, `REN`, `VOL`, and external command names.

---

## 13. Writing External Programs

New external applications should use the ca65/ld65 workflow documented in `src/external/AGENTS.md`. The KickAssembler template below remains useful for existing Kick-built apps and for the OS API calling convention; the relocation mechanism in §13.1 applies to both KickAssembler and ca65/ld65 PRG output.

### Minimal Program Template

```asm
#import "../../../include/command64.inc"

.encoding "petscii_mixed"

* = UserProgStart   ; currently $2C00 — never hardcode; always compile against the current build's constant

start:
    cld             ; always clear decimal mode
    
    ; Your program here.
    ; Use JSR $1000 for all OS services.
    
    ; Print a string:
    lda #DOS_PRINT_STR
    ldx #<myMsg
    ldy #>myMsg
    jsr $1000

    ; Exit cleanly:
    lda #DOS_EXIT
    jsr $1000       ; does not return

myMsg:
    .text "Hello from my program"
    .byte $0D, 0
```

### Receiving Shell Context

When your program is launched from the shell, these OS RAM locations are valid:

| Address | Label | Content |
|---------|-------|---------|
| `$033C` | `CommandBuffer` | The complete typed command line (null-terminated) |
| `$038C` | `CommandLen` | Number of characters in the command |
| `$063` | `ParsePos` | Index in `CommandBuffer` of first character after the command name |
| `$039E` | `CurrentDevice` | Active device number (8–11) |

Example: if the user typed `MYPROG foo bar`, then `ParsePos` points past `"myprog"` to `"foo bar\0"` in `CommandBuffer`.

### Exit Strategies

| Method | When to use |
|--------|------------|
| `lda #DOS_EXIT; jsr $1000` | Normal program exit — recommended. Resets stack, returns to shell. |
| `RTS` | Simple programs. The shell called you via `JSR UserProgStart`, so `RTS` returns to the shell's dispatch code. However, the stack has the return address from the calling shell on it, so this is safe for programs that don't corrupt the stack. |
| `JMP $E37B` | Return to BASIC (bypasses shell entirely). |

### 13.1 Making a Program Relocatable

By default, an external program is compiled for a fixed `UserProgStart` and can only be `LOAD`ed at that address (or explicitly relocated by editing high bytes yourself). To support loading at an arbitrary address (auto-slotting, or an explicit user-chosen address), build a relocatable binary:

1. Compile the same source twice, once at the normal `UserProgStart` origin and once at `UserProgStart + $0100` (one page later) — this is exactly the diff that `USER_PROG_START_HEX_NEXT` in `CMakeLists.txt` exists to produce.
2. Run `tools/reloc.py` on the two resulting `.prg` files. It diffs them to find every absolute high-byte reference that shifted by exactly one page, and appends a footer to the PRG: `BaseAddrLo/Hi` (the first build's origin), `TableSizeLo/Hi`, a table of 16-bit code offsets (one per patch site), and the 2-byte magic marker `'R','6'`.
3. At load time, `aptRelocate` (`src/command64/loader.asm`) detects the magic footer, computes `PageOffset = (actual load page) - BaseAddrHi`, and patches the high byte at each recorded offset by that amount. The registered program size excludes the appended table/footer. If the magic footer is absent, the loader falls back to registering the file as an ordinary non-relocatable PRG at its full loaded size.

### File I/O Example

```asm
    ; Open a file for reading
    lda #0               ; mode = read
    sta HexValLo
    ldx #<filename
    ldy #>filename
    lda #DOS_OPEN_FILE
    jsr $1000
    bcs openFailed
    sta FileHandle       ; save handle

    ; Read 64 bytes
    ldx #<buffer
    ldy #>buffer
    lda #64
    sta HexValLo
    lda #0
    sta HexValHi
    lda #DOS_READ_FILE
    jsr $1000
    ; HexValLo/Hi = bytes actually read

    ; Close
    lda #DOS_CLOSE_FILE
    jsr $1000
```

### VMM Memory Allocation Example

```asm
    ; Allocate 1 KB (64 paragraphs)
    lda #64
    sta VmmSegLo
    lda #0
    sta VmmSegHi
    lda #DOS_ALLOC_MEM
    jsr $1000
    bcs allocFailed
    ; X = segment hi, Y = bank
    stx VmmSegHi
    sty VmmBank

    ; Write byte at offset 0
    lda #0
    sta VmmOffLo
    sta VmmOffHi
    lda #$42
    jsr vmmWriteByte

    ; Read it back
    jsr vmmReadByte   ; A = $42

    ; Free
    lda #DOS_FREE_MEM
    jsr $1000
```

> **Note**: You can also call `vmmReadByte` / `vmmWriteByte` directly — they are in the OS binary. However, the API path (`DOS_ALLOC_MEM` / `DOS_FREE_MEM`) via `$1000` is the stable ABI; internal OS addresses may shift between builds.

---

## 14. Hardware Notes

### REU Detection

The OS checks `REU_STATUS` bit 4 at startup. If clear, the REU is absent or too small. When the REU is absent:

- `vmmInitialized` stays `0`.
- The warning `"Warning: No REU detected. VMM disabled."` is printed.
- The shell continues without environment variables or VMM allocation.
- External programs calling `DOS_ALLOC_MEM` will receive `VMM_ERR_INVALID`.

### PETSCII Encoding

The OS uses `.encoding "petscii_mixed"` throughout. In this mode:

- Lowercase source text (`a`–`z`) → unshifted PETSCII (`$41`–`$5A`).
- Uppercase source text (`A`–`Z`) → shifted PETSCII (`$C1`–`$DA`).
- **Disk filenames** must use unshifted PETSCII to match CBM DOS directory entries.
- **CBM DOS commands** (scratch, rename, block-read/write) must use unshifted ASCII bytes.
- `normalizeName` converts user-typed shifted characters to unshifted for filename matching.

### C64 Character Mode

The C64 powers on in uppercase-only mode (charset `$D000`). The OS switches to mixed-case mode at startup with `LDA #$0E; JSR KernalChROUT`. `cmdCls` re-issues this because `$93` (clear screen) resets the charset back to uppercase-only.

### Stack Discipline

The 6502 has a 256-byte hardware stack at `$0100`–`$01FF`. Each `JSR` pushes 2 bytes. `DOS_EXIT` resets `SP = $FF` before jumping to `mainLoop` to prevent stack overflow from accumulating return addresses from external programs. Without this, approximately 63 successive launches without `RTS` would overflow the stack.

### CBM DOS Channel Rules

The 1541/1571 supports multiple simultaneous open files (logical files), but each open file on the drive consumes a drive RAM buffer. The 1541 has 5 buffers total; one is used for the command channel. The OS handle table supports 8 handles (LFNs 2–9), but in practice the drive limits simultaneous open files to 4 (buffers: 1 command + 4 data = 5 total). Callers should not hold more than 4 files open simultaneously.
