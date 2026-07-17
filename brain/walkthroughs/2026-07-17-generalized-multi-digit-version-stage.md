---
feature: generalized-multi-digit-version-stage
completed: 2026-07-17
status: completed
---

# Walkthrough: Generalized Multi-Digit Version Stage

## Summary

Migrated all `ca65` external applications and test suites in the repository from single-byte character constant equates to preprocessor `.define` string macros for their version components (`VERSION_MAJOR`, `VERSION_MINOR`, `VERSION_STAGE`). This resolves the single-digit limit on the version stage position, enabling `casm` to advance past version `0.1.8` to `0.1.9` and later double-digit stages (e.g. `0.1.10`) cleanly, and ensures other utilities and tests benefit from the same robust representation.

## Files Changed

| File | Change | Notes |
|------|--------|-------|
| [src/external/AGENTS.md](file:///home/morgan/development/c64/command64-os/src/external/AGENTS.md) | Modified | Guidelines updated to require `.define` syntax |
| [include/ca65/macros.inc](file:///home/morgan/development/c64/command64-os/include/ca65/macros.inc) | Modified | Version banner documentation updated |
| [src/external/casm/casm.s](file:///home/morgan/development/c64/command64-os/src/external/casm/casm.s) | Modified | Swapped version equates to macros, updated banner, bumped to version 0.1.9 |
| [src/external/comp/comp.s](file:///home/morgan/development/c64/command64-os/src/external/comp/comp.s) | Modified | Swapped version equates to macros |
| [src/external/conway/conway_main.s](file:///home/morgan/development/c64/command64-os/src/external/conway/conway_main.s) | Modified | Swapped version equates to macros |
| [src/external/debug/debug.s](file:///home/morgan/development/c64/command64-os/src/external/debug/debug.s) | Modified | Swapped version equates to macros |
| [src/external/edlin/edlin.s](file:///home/morgan/development/c64/command64-os/src/external/edlin/edlin.s) | Modified | Swapped version equates to macros, simplified banner |
| [src/external/format/format.s](file:///home/morgan/development/c64/command64-os/src/external/format/format.s) | Modified | Swapped version equates to macros |
| [src/external/label/label.s](file:///home/morgan/development/c64/command64-os/src/external/label/label.s) | Modified | Swapped version equates to macros, simplified banner |
| [src/external/pacman/pacman_main.s](file:///home/morgan/development/c64/command64-os/src/external/pacman/pacman_main.s) | Modified | Swapped version equates to macros |
| [tests/smoke/ca65_app_smoketest.s](file:///home/morgan/development/c64/command64-os/tests/smoke/ca65_app_smoketest.s) | Modified | Swapped version equates to macros |
| Integration tests (`tests/src/**/*.s`) | Modified | Swapped version equates to macros |

## Testing Results

- Run `make all` to compile all utilities into relocatable PRG files. Build succeeds with zero errors/warnings.
- Compiles successfully onto test disk image.
- Program entry point displays the correct version string (`0.1.9` for `casm`).

## Lessons Learned & Gotchas

- Standardizing on preprocessor `.define` string macros is highly effective in `ca65` since there is no native string concatenation operator for `=` equates.
- String arguments in `.byte` directives are automatically translated to PETSCII at compile time by the `-t c64` flag, meaning this preprocessor-only change yields zero runtime overhead.
