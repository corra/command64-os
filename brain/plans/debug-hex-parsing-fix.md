---
feature: debug-hex-parsing-fix
created: 2026-06-27
status: planned
---

# Plan: DEBUG Hex Letter Parsing Fix

## Goal & Rationale
Fix the hex letter parsing bug in `parseHexArg` (`debug.asm`) where lowercase hex letters `a`–`f` (PETSCII `$41`–`$46`) are incorrectly rejected as invalid characters due to assembler encoding side effects. This fixes failures in all range and fill commands that contain hex letters.

## Scope
- Modify `src/external/debug/debug.asm` to fix `parseHexArg`.
- Update `CHANGELOG.md` to document the fix.

## Files to Create/Modify
| File | Action | Notes |
|------|--------|-------|
| `src/external/debug/debug.asm` | Modify | Fix hex parsing case-sensitivity and range checks. |
| `CHANGELOG.md` | Modify | Add build notes. |

## Key Design Decisions
Centralize character masking and hex digit conversion in `parseHexArg`:
```asm
    and #$7F
    cmp #$41            // 'a'
    bcc phInvalid
    cmp #$47            // 'g'
    bcs phInvalid
    sec
    sbc #$37            // Convert to 10-15
    jmp phAdd
```

## Verification Plan
- Compile successfully via `make`.
- Manual verification: test `-F 4000 l 10 aa` and `-D 4000 401f` in the debugger.
