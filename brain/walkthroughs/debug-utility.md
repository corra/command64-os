# Walkthrough: DEBUG External Utility

## Summary
Developed a functional port of MS-DOS `DEBUG.COM` for memory inspection and modification.

## Files Changed
| File | Change |
|------|--------|
| `src/external/debug/debug.asm` | Full utility source (input loop, dispatcher, hex parser). |
| `bin/debug.prg` | Compiled executable. |
| `CHANGELOG.md` | Logged versioning and bug remediation milestones. |

## Verification Results
- All TC cases in `debug-test-plan.md` passed in Build 1007.
- Inclusive range logic verified.
- Backward-move (overlap safe) verified.
- 40-col UI verified (16 rows of 8 bytes).

## Lessons Learned
- External utilities must use a private Zero Page block to avoid clobbering shell state.
- `and #$7F` is the preferred PETSCII case-insensitive strategy for mixed-mode character codes.
- Inclusive ranges (do-while) are more robust for user-facing memory tools.
