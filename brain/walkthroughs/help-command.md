---
feature: help-command
completed: 2026-05-09
status: completed
---

# Walkthrough: HELP Command

## Summary
Implemented the internal `HELP` command to provide users with a list of available shell commands and brief descriptions. This involved updating the command dispatch table, implementing the printing routine, and defining description strings (all kept under 40 characters for C64 screen compatibility).

## Files Changed
| File | Change | Notes |
|------|--------|-------|
| `src/command64/shell.asm` | Modified | Added `help` to table, implemented `cmdHelp`, added `helpMsg`. |
| `build/command64.asm` | Modified | Adjusted memory map to accommodate growing shell code. |
| `src/command64/utils.asm` | Modified | Segment address update. |
| `src/command64/loader.asm` | Modified | Segment address update. |
| `src/command64/path.asm` | Modified | Segment address update. |
| `src/command64/vmm.asm` | Modified | Segment address update. |

## Testing Results
- **Build**: Successfully compiled to `command64.prg`.
- **Functionality**: `HELP` command prints the command list correctly.
- **UI**: All descriptions are within the 40-character C64 screen limit.

## Lessons Learned & Gotchas
- **Code Growth**: The shell code is expanding rapidly as internal commands are added. Fixed memory segment boundaries must be monitored and adjusted frequently to avoid overlaps.
