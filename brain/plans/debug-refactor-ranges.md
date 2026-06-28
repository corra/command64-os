---
feature: debug-refactor-ranges
created: 2026-06-27
status: planned
---

# Plan: DEBUG Range Refactoring and Duplication Clean-up

## Goal & Rationale
Refactor the range-checking code in `debug.asm` to eliminate redundant inline 16-bit comparisons across commands, simplify case-insensitive character comparisons, and shrink the code footprint of the debugger.

## Scope
- Refactor `src/external/debug/debug.asm` to:
  - Centralize unshifted/shifted 'L' key checks in `parseRange`.
  - Introduce `checkRangeLimit` subroutine for single-byte loop boundaries.
  - Simplify multi-byte inclusive range bounds check using reversed comparison and `bcs`.
- Update `CHANGELOG.md` to reflect the refactoring.

## Files to Create/Modify
| File | Action | Notes |
|------|--------|-------|
| `src/external/debug/debug.asm` | Modify | Implement range checking refactoring. |
| `CHANGELOG.md` | Modify | Add build notes. |

## Key Design Decisions
1. **Simplified Case Masking:** Instead of double-compare for lowercase and uppercase, use `and #$7F` directly and compare only against `'l'`.
2. **Helper Subroutine `checkRangeLimit`:** Shared by `cmdFill`, `cmdMove`, `cmdCompare`, and `cmdSearch`. Compares `rangeStart` to `rangeEnd` (sets Z=1 on equal).
3. **Reversed inclusive boundary comparison:** Compares `rangeEnd` to `currentAddr`, allowing a single direct `bcs` branch (currentAddr <= rangeEnd).

## Verification Plan
- Compile successfully via `make`.
- Manual verification: test all range-based commands (D, F, M, C, S, U) with both 'l' and 'L' syntax.
