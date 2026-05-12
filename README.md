# command64

An MS-DOS style operating system for the Commodore 64.

## Overview
command64 provides a familiar command-line interface and DOS-compatible API for the C64. It leverages the RAM Expansion Unit (REU) to provide up to 16MB of virtual memory and implements modern handle-based file I/O.

## Features
- **MS-DOS Shell:** Commands like `DIR`, `TYPE`, `CLS`, and `VER`.
- **Service Bus API:** Stable INT 21h-style entry point for external programs.
- **Virtual Memory:** 4KB page-based allocation in the REU.
- **Handle-based I/O:** Simplified file management over KERNAL channels.

## Getting Started

### Requirements
- Commodore 64 (or VICE emulator)
- RAM Expansion Unit (REU) - 512KB or larger recommended.
- Kick Assembler v5.25 (for building)

### Building
Run the following command from the project root:
```bash
java -jar tools/KickAss.jar build/command64.asm -odir build/
```

### Running
1. Load the compiled `command64.prg` into your C64 or emulator.
2. Run with `SYS 4608` (if loaded via BASIC stub).

## Internal Commands

| Command | Description |
|---------|-------------|
| `CLS`   | Clear the screen. |
| `DIR`   | List files on the current disk. |
| `TYPE`  | Display the contents of a file (e.g., `TYPE README.TXT`). |
| `VER`   | Show OS version and build information. |
| `HELP`  | Display available commands. |
| `EXIT`  | Return to BASIC. |

## For Developers
See the following documents in the `docs/` directory:
- [API Reference](docs/api-reference.md)
- [Programmer's Reference](docs/programmers-reference.md)
- [VMM Specification](docs/vmm-api.md)
