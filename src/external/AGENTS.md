# Purpose

The purpose of the `src/external` directory is to contain external user space applications and utilities for the command64 operating system (e.g., `debug`, `label`).

# Ownership

- Primary Owner: Companion Agent (Gemini)
- Peer Owner: Primary Architect (Claude)

# Local Contracts

- All external applications must run in user space (starts at `$2200` to `$9FFF`).
- Every external application target must enforce build-time versioning through the unified `add_external_app` CMake function.
- A persistent build number file `BUILD_<APPNAME_UPPER>` containing the current build number must be maintained in the repository root.

# Work Guidance

## Workflow for Adding New External Applications

1. **Directory Setup**: Create a subdirectory `src/external/<appname>/`. Place all source assembly files inside it (e.g., `<appname>.asm`).
2. **Build File**: Create a persistent file `BUILD_<APPNAME_UPPER>` at the repository root. Initialize it with a starting build number (typically `1000\n`).
3. **Assembly Versioning Integration**:
   - Define version constants (`VERSION_MAJOR`, `VERSION_MINOR`, `VERSION_STAGE`) in the entry assembly file.
   - Import the generated build file: `#import "build_<appname>.inc"`.
   - Incorporate the `BUILD_NUMBER` constant in the printed version header (e.g., `.text "NAME v" + VERSION_MAJOR + "." + VERSION_MINOR + "." + VERSION_STAGE + "." + BUILD_NUMBER`).
4. **CMake Target**:
   - Discover source files and entry point in `CMakeLists.txt`.
   - Add the target using: `add_external_app(<appname> "${<APPNAME_UPPER>_ENTRY}" <APPNAME_UPPER>_SRCS <DEFAULT_BUILD>)`.
   - Add the target to the disk image list `IMAGE_PRG_TARGETS`.

# Verification

- CMake configuration must succeed with no warnings/errors.
- The build number in `BUILD_<APPNAME_UPPER>` must increment upon source modification and compile.
- The compiled `.prg` output must print the correct version major.minor.stage.build during execution.

# Child DOX Index

- (none)
