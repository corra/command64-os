# Walkthrough: DIR Reporting Accuracy Fix

## Summary
Resolved a major discrepancy in blocks-free reporting and hardened the 16-bit decimal utility.

## Files Changed
| File | Change |
|------|--------|
| `src/command64/utils.asm` | Rewrote `printDecimal16` to use full 16-bit subtractions for all digits. |
| `src/command64/shell.asm` | Hardened `cmdDir` to use stack-based register preservation for 16-bit counts. |

## Verification Results
- `DIR` now correctly reports large block counts (e.g. 664) instead of truncated 8-bit values (e.g. 144).

## Lessons Learned
- Don't assume 8-bit math is sufficient for secondary digits in 16-bit conversion routines.
- `GETIN` is destructive to registers; use the stack for data persistence across KERNAL polling loops.
