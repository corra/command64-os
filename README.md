# command64

An MS-DOS style operating system for the Commodore 64.

## Overview
command64 provides a familiar command-line interface and DOS-compatible API for the C64. It leverages the RAM Expansion Unit (REU) to provide up to 16MB of virtual memory and a robust handle-based file system.

## Features
- **MS-DOS Shell:** Commands like `DIR`, `TYPE`, `CLS`, and `VER`.
- **Environment Variables:** Persistent configuration (`SET`, `PATH`) stored in the REU.
- **Service Bus API:** Stable INT 21h-style entry point for external programs (JSR $1000).
- **Virtual Memory:** 4KB page-based allocation in the REU (up to 16MB).
- **Handle-based I/O:** Modern file management system mapping handles to C64 channels.
- **Multi-Device Support:** Seamlessly switch between C64 devices 8-11.
- **External Utilities:** Support for external applications (e.g., `DEBUG`).

## Getting Started

### Requirements
- Commodore 64 (or VICE emulator)
- RAM Expansion Unit (REU) - 512KB or larger recommended.
- Kick Assembler v5.25 (for building)
- GNU Make

### Building
The project uses a unified **Makefile**.
1. To build the OS and all utilities:
   ```bash
   make all
   ```
2. Build the OS disk image only:
   ```bash
   make image
   ```

### Running
1. Load the compiled `command64.prg` into your C64 or emulator.
2. Run with `SYS 4608` (or simply `RUN` if loaded via BASIC).
3. To load external utilities, ensure they are present on the same disk as the OS.

## Internal Commands

| Command | Description |
|---------|-------------|
| `CLS`   | Clear the screen. |
| `DIR`   | List files on the current disk. |
| `TYPE`  | Display the contents of a file (e.g., `TYPE README.TXT`). |
| `COPY`  | Copy a file to another location. |
| `DEL`   | Delete a file from disk. |
| `REN`   | Rename a file on disk. |
| `DRIVE` | Switch active device (8, 9, 10, 11). Aliases: `DEVICE`, `DEV`. |
| `SET`   | Display or set environment variables. |
| `PATH`  | Display or set the executable search path. |
| `RUN`   | Execute a program at a memory address (defaults to $2000). Alias: `GO`. |
| `VER`   | Show OS version and build information. |
| `HELP`  | Display available commands. |
| `EXIT`  | Return to BASIC. |

## For Users
See the **[User Manual](docs/user-manual.md)** for a comprehensive guide to using command64.
Details on external utilities like `DEBUG` can be found in the **[Applications Guide](docs/apps/debug.md)**.

## For Developers
See the following documents in the `docs/` directory:
- [API Reference](docs/api-reference.md)
- [Programmer's Reference](docs/programmers-reference.md)
- [VMM Specification](docs/vmm-api.md)
- [PETSCII API](docs/pet-sci-api.md)
