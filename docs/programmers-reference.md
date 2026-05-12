# command64 Programmer's Reference

This document provides technical details for developing applications for the command64 operating system.

## 1. Memory Map

| Region | Description |
|--------|-------------|
| `$033C - $03FB` | **OS Workspace** (Cassette Buffer). Includes Handle Table and command buffer. |
| **`$1000`** | **OS Entry Point** (Stable Jump Table). |
| `$1200 - $1FFF` | **command64 OS Kernel**. Includes shell, API dispatcher, and VMM. |
| **`$2000 - $9FFF`** | **User Program Space**. Applications should be loaded and run here. |
| `$C000 - $CFFF` | **VMM Memory Control Table (MCT)**. Reserved for OS. |

## 2. Zero Page Usage

Applications should respect the following zero-page allocations to avoid system corruption.

### Safe Areas for User Programs
- `$02 - $60`: Generally safe (OS uses `$02` as `CmpBase`).
- `$6D - $8F`: Safe for temporary application use.

### OS Reserved Zero Page
- **`$FB - $FE`**: OS Pointer Workspace (PrintPtr, NamePtr).
- **`$61 - $6C`**: OS Dispatcher Workspace (HandlerVec, ParsePos, Temp, HexVal, VMM Seg/Off/Bank).

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
The project uses **Kick Assembler v5.25**.
- **Main Project:** `build/command64.asm`
- **Output:** `build/command64.prg`
