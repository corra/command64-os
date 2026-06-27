# Command 64 OS Build Tools

This directory contains the cross-development tools, compilers, utility scripts, and emulator assets used to build, test, and package Command 64 OS.

## Tool Suite

### 1. KickAssembler (`KickAss.jar`)

* **Purpose**: Java-based 6502/6510 assembler. It is used to assemble the `.asm` files (e.g., `src/command64.asm` and `src/external/debug/debug.asm`) into Commodore executable `.prg` binaries.
* **Version**: v5.25.
* **Installation**:
  1. Download `KickAss.jar` from [KickAssembler Releases](https://github.com/KickAssembler/KickAssembler/releases/download/v5.25/KickAss.jar).
  2. Place the JAR file in this directory as `tools/KickAss.jar`.
* **CMake Integration**: Discovered via the custom module `FindKickAss.cmake` and compiled using the `add_kickass_target` helper defined in `KickAssembler.cmake`.

### 2. cc1541 Disk Packaging Utility (`cc1541`)

* **Purpose**: A command-line tool for creating Commodore 1541/1571/1581 floppy disk images (`.d64`, `.d71`, `.d81`) and copying files to them.
* **Installation**:
  1. Download or build from the [cc1541 Repository](https://github.com/skoe/cc1541).
  2. Place the binary in this directory as `tools/cc1541` (or `tools/cc1541.exe` on Windows).
* **CMake Integration**: Discovered via the custom module `Findcc1541.cmake` and invoked via the `cc1541` CMake helper targets (e.g. `image_d64`, `test_image_d64`).

### 3. Oscar64 C Compiler (`oscar64/`)

* **Purpose**: An optimizing C compiler targeting the 6502/C64. It is used to build C source files into C64 executables.
* **Installation**:
  1. Download the compiler toolchain from [Oscar64 Repository](https://github.com/drwuro/oscar64).
  2. Unpack the compiler such that the executable is located at `tools/oscar64/bin/oscar64` (or `oscar64.exe` on Windows).
* **CMake Integration**: Optionally discovered via `FindOscar64.cmake` and registered via the `add_oscar64_target` helper defined in `Oscar64.cmake`.

### 4. REU Emulation Image (`command64.reu.reu`)

* **Purpose**: A pre-configured 256KB RAM Expansion Unit (REU) memory image.
* **Usage**: Configured in C64 emulators (such as VICE) to mock and test REU-enabled features like the Virtual Memory Manager (VMM), environment variables (`SET`, `PATH`), and CPU state preservation.
