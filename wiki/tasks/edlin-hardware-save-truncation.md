# EDLIN Hardware Save Truncation

Status: [x]
Taskwarrior: 25

## Goal

Fix EDLIN `W` saves truncating the final bytes on physical hardware while emulator saves appear complete.

## Root Cause

- `DOS_READ_FILE` stored the masked KERNAL status byte instead of the final EOI byte on the EOF path, corrupting the last byte returned by file reads.
- `DOS_WRITE_FILE` did not check KERNAL status immediately after `CHROUT`, so late IEC write errors could be missed until a later operation.
- EDLIN closed the output file and returned without reading the drive command-channel status, so physical-drive close/finalization errors could be missed after a save-replace write.

## Subtasks

- [x] Preserve and store the final EOI byte in `fileRead`.
- [x] Check KERNAL status after each `fileWrite` byte and return Carry set with the actual byte count on write errors.
- [x] Have EDLIN read the target drive's post-close status after `W`.
- [x] Preserve target-device prefixes (`8:`, `9:`, `10:`, `11:`) for EDLIN post-close status checks.
- [x] Verify with `make all`.
- [x] Manually verify on physical hardware.

## Manual Verification

1. Boot the updated `image.d64` on physical C64 hardware.
2. Run `EDLIN <file>` against an existing SEQ file whose final two bytes are easy to identify.
3. Use `L` to list the file, make a small edit, and save with `W`.
4. Quit and reload the same file with EDLIN, then confirm the final bytes are still present.
5. Repeat with a target-device prefix such as `EDLIN 9:<file>` if a second physical drive is available.
6. Fill or write-protect the target disk enough to force a close/finalization failure and confirm EDLIN reports `ERROR: WRITE FAILED - DISK FULL?`.
