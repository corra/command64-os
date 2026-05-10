---
feature: load-investigation
completed: 2026-05-09
status: completed
---

# Walkthrough: LOAD Command & Dispatcher Hardening

## Summary
Investigated and resolved a critical bug in the `LOAD` command and stabilized the external command dispatcher. The system now correctly handles both internal and external commands without memory corruption or unexpected exits to BASIC.

## Files Changed
| File | Change | Notes |
|------|--------|-------|
| `src/command64/shell.asm` | Modified | Fixed `pla` bug in `cmdLoad`, added length-0 check in `sdBadCmd`. |

## Testing Results
- **Stability**: Verified that blank lines and non-existent commands no longer crash the system.
- **LOAD**: Verified that `LOAD` now correctly passes the filename pointer to the KERNAL routines.
- **LIST**: Verified that `EXIT` to BASIC remains clean even after failed command attempts.

## Lessons Learned & Gotchas
- **Stack Discipline**: Pulling the wrong register from the stack (`pla` vs `plx` equivalent) can have catastrophic consequences, especially when the target register holds a pointer used near critical KERNAL vectors.
- **Input Sanitization**: Even with explicit empty-line checks, hardening subsequent dispatcher stages (like length-0 checks in `sdBadCmd`) is essential for robust operation.
