---
feature: dir-command
completed: 2026-05-09
status: completed
---

# Walkthrough: Non-Destructive DIR Command

## Summary
Implemented the internal `DIR` command using a non-destructive KERNAL streaming strategy. Instead of loading the directory into RAM and clobbering the shell, the code opens the logical file `"$"` and reads it byte-by-byte via `GETIN`. It parses the C64's BASIC-token-style directory format and displays block counts (via a new 16-bit decimal utility) and filenames to the screen. Graceful error handling was added to catch missing or non-functioning devices.

## Files Changed
| File | Change | Notes |
|------|--------|-------|
| `src/command64/shell.asm` | Modified | Replaced `DIR` stub with implementation; added `noDeviceMsg` and `dirFname`. |
| `src/command64/utils.asm` | Modified | Added `printDecimal16` for 16-bit to decimal conversion. |
| `include/command64.inc` | Modified | Added KERNAL equates for `CHKIN` and `CLRCHN`. |
| `build/command64.asm` | Modified | Adjusted memory map to resolve segment overlaps caused by new code. |
| `src/command64/loader.asm` | Modified | Segment address update. |
| `src/command64/path.asm` | Modified | Segment address update. |
| `src/command64/vmm.asm` | Modified | Segment address update. |

## Testing Results
- **Assembly**: Build passes with 0 errors/warnings.
- **Functionality**: `DIR` command streams correctly from disk.
- **Error Handling**: Missing device 8 correctly displays "Device not present".
- **Formatting**: Block counts are printed in decimal with leading zero suppression.

## Lessons Learned & Gotchas
- **KERNAL Status**: `READST` ($FFB7) is essential for detecting the end of a directory stream (EOF).
- **Secondary Address**: Secondary address `0` is mandatory for directory streaming; `1` will trigger an absolute load of the directory file.
- **Leading Zeros**: A 16-bit decimal printer requires a "first digit printed" flag to suppress leading zeros for readability.
