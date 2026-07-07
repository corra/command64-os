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
- **External Utilities:** Support for external applications (e.g., `DEBUG`, `LABEL`, `CONWAY`).
- **App Manager:** Resident registry of loaded programs (`APPS`/`PS`, `FREE`) with memory-safe pre-flight validation and dynamic auto-slotting on `LOAD`.
- **Binary Relocator:** Load relocatable binaries at arbitrary memory addresses.

## Getting Started

### Requirements

- Commodore 64 (or VICE emulator)
- RAM Expansion Unit (REU) - 512KB or larger recommended.
- Java Runtime Environment (for KickAssembler)
- CMake (version 3.20 or newer)
- GNU Make (optional wrapper)

### Building

The project is built using **CMake**. A `Makefile` wrapper is also provided at the root for convenience.

1. **Configure CMake**:

   ```bash
   cmake -B build
   ```

2. **Build the OS and all utilities**:

   ```bash
   cmake --build build
   # OR using the Makefile wrapper:
   make all
   ```

3. **Build the OS disk image only**:

   ```bash
   cmake --build build --target image_d64
   # OR using the Makefile wrapper:
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
| `LOAD`  | Load a program by name, optionally at an address; auto-picks a free memory region if omitted. |
| `RUN`   | Execute a program by name or address; with no argument, runs the program already loaded at the base of user program space. Alias: `GO`. |
| `APPS`  | List currently loaded/registered programs (name, address, size). Alias: `PS`. |
| `FREE`  | Deregister a named program, or all loaded programs if no name is given. |
| `VOL`   | Display the disk name/ID. |
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
