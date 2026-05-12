# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.6] - 2026-05-11

### Changed
- **Service Bus Architecture Pivot**: Transitioned from a `BRK`-based trap model to a **Jump Table** model (`JSR $1600`). This resolves infinite recursion crashes and stack corruption caused by conflicts between custom `BRK` handlers and the non-reentrant C64 KERNAL interrupt routines.
- **ABI Update**: The Service Bus now follows standard subroutine conventions:
  - Entry point: `$1600`
  - Calling convention: `JSR $1600`
  - Input: `A`=Function, `X/Y`=Args
  - Output: `A, X, Y` as per function, `Carry`=Status (0=Success, 1=Error)

### Fixed
- **Stability**: Removed all hardcoded `BRK` vector hooks (`$0316`), making the system 100% stable under emulator and real-hardware conditions.
- **Infinite Recursion**: Fixed the "stack drain" issue where nested interrupts caused the stack pointer to wrap around.

## [0.2.5] - 2026-05-11

## [0.2.4] - 2026-05-11

### Added
- **Phase 2D (Service Bus)**: Implemented INT 21h-style BRK service bus (`api.asm`, segment `$1600`). Handles DOS_PRINT_CHAR ($02), DOS_PRINT_STR ($09), DOS_ALLOC_MEM ($48), DOS_FREE_MEM ($49), DOS_EXIT ($4C).
- **BRK Vector Install**: Shell startup installs `apiHandler` to `KernalCBINV` ($0316/$0317) at boot.
- **VMM Safety Guard**: Added `vmmInitialized` flag; `vmmAlloc` returns `VMM_ERR_INVALID` if REU detection failed, preventing MCT corruption.
- **Test Scaffolding**: Added `tests/src/apitest.asm` and `tests/src/vmmtest.asm` integration test stubs.

### Fixed
- **printDecimal16**: Initialized `TempHi` to 0 at entry to prevent garbage leading zeros from prior callers.

### Changed
- **Segment Layout Cascade**: Inserted `Api` at $1600; relocated `Utils`→$1700, `Loader`→$1800, `Path`→$1880, `Vmm`→$1980, `VmmData`→$1C80.
- **Version**: 0.2.4 (Build 2303), Stage 4.

## [0.2.3] - 2026-05-09

### Added
- **Phase 2C (VMM) Core**: Implemented Virtual Memory Manager primitives (`vmmInit`, `vmmReadByte`, `vmmWriteByte`) mapping 1MB-16MB REU space.
- **Dynamic Allocation**: Implemented `vmmAlloc` and `vmmFree` using a 4KB Page Byte-Map strategy ($01 Head, $02 Tail).
- **Version Tracking**: Added startup version banner and internal `VER` command.
- **HELP Command**: Added internal `HELP` command with brief descriptions.
- **DIR Command**: Implemented non-destructive directory listing via KERNAL streaming.
- **LOAD Command Fix**: Resolved a critical register corruption bug and inverted secondary address mapping.
- **Dispatcher Hardening**: Added length-0 safety checks to external command searches.
- **Stability**: Relocated Command Buffer to Cassette Buffer ($033C) and isolated Memory Control Table (MCT) to $C000.
- **Zero Page Remapping**: Migrated all pointers to safe/FAC1 workspace ($FB-$FE, $61-$6C) to prevent BASIC/KERNAL corruption.

### Changed
- Reverted `UserProgStart` to $2000 for compatibility with existing pre-compiled programs.
- Refined versioning scheme to 0.x.x (Pre-Alpha) to better track project sub-stages.

## [0.1.4] - 2026-05-08
