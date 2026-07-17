---
feature: generalized-multi-digit-version-stage
created: 2026-07-17
status: planned
---

# Plan: Generalized Multi-Digit Version Stage Migration

## Goal & Rationale

Currently, external applications and test suites in this repository track their major, minor, and stage version components using single-byte character constant equates (e.g., `VERSION_STAGE = '0'`) in their main entry assembly files. This restricts the stage component to a single character/digit. Once the stage reaches `10` or higher, this mechanism breaks because multi-character equates are not supported or do not fit in a single byte representation.

To allow arbitrary multi-digit stage versions across the entire Command 64 workspace (e.g., enabling `casm` to advance past `0.1.9` to `0.1.10`, and `pacman` or `edlin` to scale similarly), this plan transitions `VERSION_MAJOR`, `VERSION_MINOR`, and `VERSION_STAGE` to preprocessor text macros (`.define`) in all `ca65` external applications and test suites.

## Scope

### Included

- Update the external application documentation guidelines in `src/external/AGENTS.md` to establish `.define` string versioning as the standard.
- Update the documentation comments in `include/ca65/macros.inc` to show the correct macro-based version banner layout.
- Modify the version constants and banner layout in all resident `ca65` external utilities:
  - `casm` (`src/external/casm/casm.s`)
  - `comp` (`src/external/comp/comp.s`)
  - `conway` (`src/external/conway/conway_main.s`)
  - `debug` (`src/external/debug/debug.s`)
  - `edlin` (`src/external/edlin/edlin.s`)
  - `format` (`src/external/format/format.s`)
  - `label` (`src/external/label/label.s`)
  - `pacman` (`src/external/pacman/pacman_main.s`)
- Modify the version constants and banner layout in `tests/smoke/ca65_app_smoketest.s` and all integration tests under `tests/src/`.
- Verify compilation and execution of the modified binaries.

### Explicitly Out of Scope

- Modifying version constants for KickAssembler applications (which are written in `.asm` files and already use `.const` string concatenation, which natively handles multi-digit versions).

## Files to Create/Modify

| File | Action | Notes |
|------|--------|-------|
| [AGENTS.md](file:///home/morgan/development/c64/command64-os/src/external/AGENTS.md) | Modify | Update version rules to specify `.define` syntax |
| [macros.inc](file:///home/morgan/development/c64/command64-os/include/ca65/macros.inc) | Modify | Update documentation comments to demonstrate macro-based versioning |
| [casm.s](file:///home/morgan/development/c64/command64-os/src/external/casm/casm.s) | Modify | Update version equates and banner |
| [comp.s](file:///home/morgan/development/c64/command64-os/src/external/comp/comp.s) | Modify | Update version equates |
| [conway_main.s](file:///home/morgan/development/c64/command64-os/src/external/conway/conway_main.s) | Modify | Update version equates, exitBanner, and menuVersion |
| [debug.s](file:///home/morgan/development/c64/command64-os/src/external/debug/debug.s) | Modify | Update version equates and startupMsg |
| [edlin.s](file:///home/morgan/development/c64/command64-os/src/external/edlin/edlin.s) | Modify | Update version equates and verMsg |
| [format.s](file:///home/morgan/development/c64/command64-os/src/external/format/format.s) | Modify | Update version equates and verMsg |
| [label.s](file:///home/morgan/development/c64/command64-os/src/external/label/label.s) | Modify | Update version equates and verMsg |
| [pacman_main.s](file:///home/morgan/development/c64/command64-os/src/external/pacman/pacman_main.s) | Modify | Update version equates and exitBanner |
| [ca65_app_smoketest.s](file:///home/morgan/development/c64/command64-os/tests/smoke/ca65_app_smoketest.s) | Modify | Update version equates and msg |
| Integration tests (`tests/src/**/*.s`) | Modify | Update version equates and banner lines in the test suites |

## Key Design Decisions

### Preprocessor Text Macros for Versions

Using `.define VERSION_STAGE "10"` creates a text-substitution macro instead of a numeric constant. When `ca65` processes a banner declaration like:

```assembly
.byte "NAME V", VERSION_MAJOR, ".", VERSION_MINOR, ".", VERSION_STAGE, "."
```

it expands directly to:

```assembly
.byte "NAME V", "0", ".", "1", ".", "10", "."
```

This is compiled to PETSCII character bytes at build time. Since `ca65` strings in `.byte` are translated to PETSCII by the `-t c64` compiler flag, this dynamically formats the version with any number of digits and requires zero runtime formatting code or CPU overhead.

## Verification Plan

### Automated Build Verification

1. Run `make all` to verify that all external applications build without any compilation warnings or errors.
2. Run `make test` or `cmake --build build --target test_image_d64` to verify all test suites compile successfully.

### Manual Verification

1. Boot the compiled `test_image.d64` in VICE and run:
   - `casm`
   - `conway`
   - `debug`
   - `edlin`
   - `format`
   - `label`
   - `pacman`
2. Verify that each utility runs correctly and prints its version banner with the correct major, minor, stage, and build numbers, and that formatting remains clean with double-digit stages (e.g. `0.1.10.XXXX`).

## Progress

- [ ] Plan defined and submitted for review.
