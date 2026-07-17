# Purpose

The purpose of the `src/external` directory is to contain external user space applications and utilities for the command64 operating system (e.g., `debug`, `label`).

# Ownership

- Primary Owner: Companion Agent (Gemini)
- Peer Owner: Primary Architect (Claude)

# Local Contracts

- All external applications must run in user space (starts at `$2200` to `$9FFF`).
- Every external application target must enforce build-time versioning through the unified CMake app helpers: `add_external_app` for KickAssembler apps or `add_ca65_app` for ca65/ld65 apps.
- A persistent build number file `BUILD_<APPNAME_UPPER>` containing the current build number must be maintained in the application's own `src/external/<appname>/` directory.
- App-private zero-page scratch allocations may use `$70-$8F`. Collisions between separately loaded apps are acceptable only because external apps are not concurrently resident; document any new allocation in the app source and avoid clobbering OS-owned zero-page locations.
- ca65 multi-file apps that share zero-page symbols across object-file boundaries must use `.exportzp` and `.importzp`; plain `.export`/`.import` treats the symbol as absolute and can emit incorrect three-byte absolute instructions.

# Work Guidance

## Workflow for Adding New KickAssembler External Applications

1. **Directory Setup**: Create a subdirectory `src/external/<appname>/`. Place all source assembly files inside it (e.g., `<appname>.asm`).
2. **Build File**: Create a persistent file `BUILD_<APPNAME_UPPER>` in the app directory. Initialize it with a starting build number (typically `1000\n`).
3. **Assembly Versioning Integration**:
   - Define version constants (`VERSION_MAJOR`, `VERSION_MINOR`, `VERSION_STAGE`) in the entry assembly file.
   - Import the generated build file: `#import "build_<appname>.inc"`.
   - Incorporate the `BUILD_NUMBER` constant in the printed version header (e.g., `.text "NAME v" + VERSION_MAJOR + "." + VERSION_MINOR + "." + VERSION_STAGE + "." + BUILD_NUMBER`).
4. **CMake Target**:
   - Discover source files and entry point in `CMakeLists.txt`.
   - Add the target using: `add_external_app(<appname> "${<APPNAME_UPPER>_ENTRY}" <APPNAME_UPPER>_SRCS <DEFAULT_BUILD>)`.
   - Add the target to the disk image list `IMAGE_PRG_TARGETS`.

## Workflow for Adding New ca65/ld65 External Applications

1. **Directory Setup**: Create a subdirectory `src/external/<appname>/`. Place the entry source and any app-local `.s`/`.inc` files inside it.
2. **Build File**: Create a persistent file `BUILD_<APPNAME_UPPER>` in the app directory. Initialize it with a starting build number (typically `1000\n`).
3. **Assembly Versioning Integration**:
   - Define version constants (`VERSION_MAJOR`, `VERSION_MINOR`, `VERSION_STAGE`) using preprocessor text macros (`.define`) in the entry assembly file (e.g. `.define VERSION_STAGE "0"`).
   - Include the shared app API with `.include "command64.inc"`; `add_ca65_app` already passes `-I include/ca65`.
   - Include the generated build file when a printed version banner needs `BUILD_NUMBER`; `add_ca65_app` emits ca65 syntax (`.define BUILD_NUMBER "<n>"`).
4. **CMake Target**:
   - Discover the app entry file and glob the app's `.s`/`.inc` files along with shared `include/ca65/*.inc` dependencies.
   - Add the target using: `add_ca65_app(<target> "${ENTRY}" <SOURCES_VAR> <DEFAULT_VERSION> <PRG_SIZE_HEX> [CODE_ALIGN])`.
   - Use `PRG_SIZE_HEX` for the link-time `MAIN` memory size and optional `CODE_ALIGN` only when the app embeds data that must stay page-aligned.
   - Add the target to the disk image list `IMAGE_PRG_TARGETS`.

# Verification

- CMake configuration must succeed with no warnings/errors.
- The build number in `BUILD_<APPNAME_UPPER>` must increment upon source modification and compile.
- The compiled `.prg` output must print the correct version major.minor.stage.build during execution.
- ca65/ld65 apps must build through `add_ca65_app` as part of `cmake --build build --target image_d64` or `cmake --build build --target test_image_d64`, depending on whether the app ships or is test-only.

# Child DOX Index

- [casm/AGENTS.md](casm/AGENTS.md)
- [pacman/AGENTS.md](pacman/AGENTS.md)
