---
feature: command64-remediation-round3
created: 2026-05-11
status: completed
---

# Plan: command64 Remediation Round 3 (VMM Safety Hardening)

## Goal & Rationale
With the resolution of the Phase 2C Round 1 bugs (A, B, E, F, J) by Claude, the Service Bus and VMM are structurally sound. However, a residual safety gap remains: `vmmFree`, `vmmReadByte`, and `vmmWriteByte` do not check the `vmmInitialized` flag. If called on a system without an REU, these routines will silently corrupt the C64's memory or write to invalid hardware registers. This plan secures these remaining functions.

## Scope
- Bug I2-Extended: Secure `vmmFree`, `vmmReadByte`, and `vmmWriteByte` with the `vmmInitialized` flag.
- Update tracking artifacts (`brain/reviews/`, `brain/task.md`).

## Files to Create/Modify
| File | Action | Notes |
|------|--------|-------|
| `src/command64/vmm.asm` | Modify | Add `vmmInitialized` checks to `vmmFree`, `vmmReadByte`, and `vmmWriteByte`. |
| `brain/reviews/2026-05-11_command64-round3-gemini-review.md` | Create | Log the final safety review findings. |
| `brain/plans/2026-05-11_command64-remediation-round3.md` | Create | Copy this plan to the canonical brain directory. |

## Implementation Steps

### Task 1: Secure `vmmFree`
- Add a check at the start of `vmmFree` to return `VMM_ERR_INVALID` if `vmmInitialized` is zero.
  ```asm
  vmmFree:
      lda vmmInitialized
      bne vfInitOk
      lda #VMM_ERR_INVALID
      rts
  vfInitOk:
      // Convert Segment to MCT pointer...
  ```

### Task 2: Secure `vmmReadByte`
- Add a check at the start of `vmmReadByte` to return `0` if `vmmInitialized` is zero.
  ```asm
  vmmReadByte:
      lda vmmInitialized
      bne vrbInitOk
      lda #0                  // Return 0 if not initialized
      rts
  vrbInitOk:
      jsr vmmComputeAddress...
  ```

### Task 3: Secure `vmmWriteByte`
- Add a check at the start of `vmmWriteByte` to return silently if `vmmInitialized` is zero.
  ```asm
  vmmWriteByte:
      sta vmmTempByte         // Save data to write
      lda vmmInitialized
      bne vwbInitOk
      rts                     // Silently ignore write if not initialized
  vwbInitOk:
      jsr vmmComputeAddress...
  ```

## Verification Plan
1. Rebuild the main binary: `java -jar tools/KickAss.jar build/command64.asm -odir build/`
2. Verify no build errors occur and the PRG size remains within segment limits.
