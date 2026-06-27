# command64 Programmer's Reference

This document provides technical details for developing applications for the command64 operating system.

## 1. Memory Map

| Region | Description |
|--------|-------------|
| `$033C - $03FB` | **OS Workspace** (Cassette Buffer). Includes Handle Table, Env pointers, and command buffer. |
| `$0C00 - $0CFF` | **OS Utils** (Hex parsing, decimal printer). |
| `$0D00 - $0FFF` | **OS Core** (API, Loader, Path). |
| **`$1000`** | **OS Entry Point** (Stable Jump Table). |
| `$1040 - $107F` | **PETSCII Library**. |
| `$1080 - $10FF` | **Command Table**. |
| `$1180 - $19FF` | **Command Shell**. |
| `$1B80 - $1D7F` | **VMM Module**. |
| `$1D80 - $1F8F` | **File System Module**. |
| **`$2200 - $9FFF`** | **User Program Space**. Applications should be loaded and run here (note: shifted from $2000 to accommodate App Table in Phase 6A). |
| `$C000 - $CFFF` | **VMM Memory Control Table (MCT)**. Reserved for OS. |

## 2. Zero Page Usage

Applications should respect the following zero-page allocations to avoid system corruption.

### Safe Areas for User Programs

- `$03 - $60`: Generally safe (OS uses `$02` as `CmpBase`).
- `$70 - $8F`: Safe for temporary application use. **Note:** DEBUG.PRG uses `$70-$7F`.

### OS Reserved Zero Page

- **`$FB - $FE`**: OS Pointer Workspace (PrintPtr, NamePtr).
- **`$61 - $6D`**: OS Dispatcher Workspace (HandlerVec, ParsePos, Temp, HexVal, VMM, FileHandle).
- **`$6E - $6F`**: Shell Scratch (SrcHandle, DstHandle).

## 3. Development Guidelines

### 3.1 OS Integration

Always use the stable entry point at **`$1000`** for OS services. Never jump directly into the OS kernel ($1200+) as these addresses may change between builds.

### 3.2 Compatibility

- **Binary Mode:** Always start your program with `CLD` to ensure binary arithmetic mode.
- **Character Set:** The OS starts in lowercase/mixed mode. Use PETSCII mixed-case encoding for strings.
- **Exit Strategy:** Always terminate your program via `DOS_EXIT ($4C)` to ensure the shell state is correctly reset.

### 3.3 Memory Management

Use the VMM API (`DOS_ALLOC_MEM`, `DOS_FREE_MEM`) to manage memory in the REU. Do not write directly to REU registers unless you are managing your own banked memory and are certain it does not conflict with the OS MCT.

## 4. Build System

The project is built using a cross-platform **CMake** build system (minimum version 3.20) and **Kick Assembler v5.25**.

- **Main Entry Point**: `src/command64.asm`
- **CMake Configuration**: Run `cmake -B build` followed by `cmake --build build` to compile the operating system, utilities, and test suites.
- **GNU Make Wrapper**: A `Makefile` proxy is provided at the repository root for convenience. You can run standard targets like `make all`, `make image`, or `make clean` which are forwarded directly to CMake.
- **Output**: Output binaries (`command64.prg`, `debug.prg`, etc.) are placed under the `build/` directory.
