# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.11] - 2026-05-12

### Added
- **Internal Commands**: Added `DEL` and `ERASE` commands for file deletion.
- **Service Bus API**: Added `DOS_DELETE_FILE` ($41) for external program file management.

### Changed
- **Memory Map**: Realigned `VmmData` and `FileScratch` to `$1FA0` to accommodate growing file module.

## [0.2.10] - 2026-05-12

### Fixed
- **Critical — KERNAL API Register Mismatches**: Resolved multiple bugs in `file.asm` where LFN and Device Number registers were swapped or incorrect for `SETLFS`, `CHKIN`, and `CHKOUT` calls.
- **Filename Normalization**: Enhanced `normalizeName` to handle lowercase PETSCII conversion, ensuring shell input matches standard uppercase disk filenames.
- **Memory Map**: Realigned segments (`Loader`, `Path`, `Vmm`, `File`, `VmmData`) to resolve overlaps caused by expanded utility code.

## [0.2.9] - 2026-05-12

### Fixed
- **Handle/Channel Conflict**: `fileOpen` now uses the Logical File Number (LFN) as the Secondary Address, ensuring unique channels for simultaneous files (fixing `COPY`).
- **Case Sensitivity**: Added `normalizeName` call to `fileOpen` to ensure filenames match the unshifted PETSCII expected by the disk drive (fixing `TYPE` and `COPY` "Load error").

## [0.2.8] - 2026-05-12

### Fixed
- **Critical — cmdCopy Handle Corruption**: `cmdCopy` was using `TempLo/Hi` for handles, which were clobbered by `fileRead/Write`. Added dedicated ZP registers `SrcHandle` ($6E) and `DstHandle` ($6F).
- **Documentation**: Corrected outdated Zero Page addresses in `utils.asm` comments ($F7/$F8 -> $66/$67).

### Changed
- **Performance — Buffered I/O**: `TYPE` and `COPY` commands now use 64-byte buffered I/O instead of 1-byte-at-a-time, significantly improving disk performance.

## [0.2.7] - 2026-05-12

### Fixed
- **C1 — FileScratch address** (`include/command64.inc`): `FileScratch` was `$1D80` (= File segment start), causing `fileOpen` to overwrite its own code when building filenames. Corrected to `$1F02` where `fileScratch` actually lives in VmmData.
- **C2 — Handle lost in API dispatch** (`api.asm`, `shell.asm`): `ahRead`/`ahWrite`/`ahClose` were entered with A = function code, not the handle; `fileRead`/`fileWrite`/`fileClose` received garbage. Added ZP register `FileHandle = $6D` (vmm.inc). `ahRead`/`ahWrite`/`ahClose` now load A from FileHandle before delegating. Callers in `cmdType`/`cmdCopy` now `sta FileHandle` after open and before each read/write/close API call. TYPE and COPY are now functional.
- **C3 — fileClose X clobber** (`file.asm`): `KernalCLOSE` does not preserve X; `sta HandleTable, x` after the call wrote to the wrong slot. Fixed by saving X to TempLo around the KERNAL call.
- **N8 — Spurious `asl` in fileClose** (`file.asm`): Dead code after `jsr KernalCLOSE` removed.
- **Dead `lda` lines in cmdType/cmdCopy** (`shell.asm`): Removed no-op handle loads that were immediately overwritten.

### Changed
- **Version**: 0.2.7 (Build 2400), Phase 2F (File I/O).
- **HELP text**: Added TYPE and COPY to the HELP command output.
- **ABI comments** (`api.asm`): Updated ahRead/ahWrite/ahClose comments to reflect FileHandle ZP convention.
- **Removed `KernalCBINV`** (`include/command64.inc`): Vestigial BRK vector label from pre-v0.2.6 removed.

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
