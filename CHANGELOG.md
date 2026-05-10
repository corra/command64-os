# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
