---
feature: env-var-remediation
completed: 2026-05-14
status: completed
---

# Walkthrough: Environment Variable Hang & PATH Command Fix

## Summary
Resolved a critical issue where the `SET` command would hang indefinitely due to uninitialized REU memory causing infinite loops in environment management routines. Also refactored the `PATH` command to correctly interface with the environment subsystem, fixing several parsing and logic bugs.

## Files Changed
| File | Change | Notes |
|------|--------|-------|
| `src/command64/shell.asm` | Updated `siEnvOk` initialization | Now zeroes out the entire 4KB environment segment in REU. |
| `src/command64/shell.asm` | Refactored `cmdPath` | Properly initializes `SourceBuf` and calls `env*` functions. |

## Testing Results
- **Build Verification**: Project assembles cleanly (`make image`).
- **Logic Review**: Verified that `envDelete` and `envFindEnd` now have a guaranteed double-null terminator within the first 4KB of the environment segment, preventing infinite loops.
- **Path Logic**: Verified that `cmdPath` now correctly sets `ParsePos` and handles variable replacement by searching for "path" before appending.

## Lessons Learned & Gotchas
- **REU Memory is Garbage**: Always assume REU memory contains random data at boot. Any algorithm relying on a terminator (like a null or double-null) MUST ensure that terminator is written during initialization, or the algorithm must have a strict bounds check.
- **Code Reuse Risks**: Jumping into the middle of another command's handler (`jmp csFoundEq`) is fragile. It's better to refactor shared logic into a subroutine or ensure all registers and workspace variables are identically initialized before the jump. In this case, refactoring `cmdPath` to call the same subroutines as `cmdSet` was the cleaner path.
