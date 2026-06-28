---
feature: debug-prlength-y-preservation
created: 2026-06-27
status: planned
---

# Plan: DEBUG Y-Register Preservation in prLength

## Goal & Rationale
Fix the parser corruption bug in `prLength` where the `Y` register (acting as the parser index `y`) is clobbered during 16-bit range calculations. This fixes syntax errors when using the length (`L`) parameter with trailing command arguments.

## Scope
- Modify `src/external/debug/debug.asm` to push `Y` to the stack before 16-bit calculations in `prLength` and restore it before return.
- Update `CHANGELOG.md` to document the fix.

## Files to Create/Modify
| File | Action | Notes |
|------|--------|-------|
| `src/external/debug/debug.asm` | Modify | Preserve Y register around range calculation math. |
| `CHANGELOG.md` | Modify | Add build notes. |

## Key Design Decisions
Save `Y` to stack after parsing is finished, then restore before returning success (`clc; rts`):
```asm
prLength:
    iny                     // skip 'L'
    jsr skipSpaces
    jsr parseHexArg
    bcs prErr
    
    tya
    pha                     // Save parser index Y
    
    // 16-bit range math (clobbers Y)
    lda HexValLo
    sec
    sbc #1
    tax
    lda HexValHi
    sbc #0
    tay
    
    txa
    clc
    adc rangeStart
    sta rangeEnd
    tya
    adc rangeStart + 1
    sta rangeEnd + 1
    
    pla
    tay                     // Restore parser index Y
    clc
    rts
```

## Verification Plan
- Compile successfully via `make`.
- Manual verification: test `f 0400 l 80 20` and `m 4000 l 10 5000` to verify preservation of Y.
