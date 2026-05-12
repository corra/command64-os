---
feature: command64-remediation-round2
created: 2026-05-11
status: completed
---

# Plan: command64 Remediation Round 2

## Goal & Rationale
To fix the residual bugs and documentation inaccuracies identified during the code review of the command64 Phase 2A implementation. This ensures the integrity of the virtual memory manager, proper documentation for load operations, and correct formatting for decimal string outputs.

## Scope
- Correct documentation around `SpecificLoad`.
- Fix the uninitialized `TempHi` state in `printDecimal16`.
- Add a safety check to `vmmAlloc` for uninitialized VMM states.
- Perform artifact tracking (create review document, copy plan to brain, update task.md).

## Files to Create/Modify
| File | Action | Notes |
|------|--------|-------|
| `include/command64.inc` | Modify | Update comment for `SpecificLoad` to correctly state `0=use HexVal address, 1=use file header`. |
| `src/command64/loader.asm` | Modify | Update comment for `SpecificLoad` to reflect the correct value mapping. |
| `src/command64/utils.asm` | Modify | Add `lda #0` and `sta TempHi` at the start of `printDecimal16`. |
| `src/command64/vmm.asm` | Modify | Add `vmmInitialized` flag. Set to 1 in `vmmInit` on success. Check in `vmmAlloc`, return `VMM_ERR_INVALID` if 0. |
| `brain/reviews/2026-05-11_command64-bug-verification.md` | Create | Log the findings from this review session. |
| `brain/plans/2026-05-11_command64-remediation-round2.md` | Create | Copy this plan to the canonical brain directory. |
| `brain/task.md` | Modify | Add and check off the review task; add this remediation as an in-progress task. |

## Key Design Decisions
- `SpecificLoad` code logic is functionally correct, so we only need to fix misleading comments to prevent future developer confusion.
- `printDecimal16` will be made self-contained regarding leading-zero state so callers do not have to manually clear `TempHi`.
- `vmmAlloc` should "fail safely" if REU initialization failed, rather than proceeding and corrupting the C64's base memory at `$C000`.

## Verification Plan
- Build the project using Kick Assembler to ensure no syntax errors were introduced.
- Review output to ensure `printDecimal16` still functions correctly and no zero-padding regressions occur.
- Verify through code inspection that `vmmAlloc` checks the initialization flag.
