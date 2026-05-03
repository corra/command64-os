---
feature: phase2a-input-vmm
created: 2026-05-03
status: completed
---

# Walkthrough: Phase 2A Follow-on (Input & VMM)

## Summary
Implemented a raw keyboard input loop to replace the KERNAL's screened-editor-based input, effectively removing the "quote mode" bug where entering a double-quote character would cause cursor keys to insert control codes. Additionally, established the Virtual Memory Manager (VMM) ABI header to support the transition to Phase 2B.

## Files Changed
| File | Change | Notes |
|------|--------|-------|
| `src/command64/shell.asm` | Modified `shellReadLine` | Replaced `CHRIN` with `GETIN` + manual echo. |
| `include/command64.inc` | Modified | Added `KernalGetIn` label and VMM ZP equates. |
| `include/vmm.inc` | Created | Formalized VMM ABI constants and hardware ports. |

## Verification Results
- **Functional Test**: Verified that `GETIN` provides raw input. By manually echoing characters via `CHROUT`, the visual behavior matches the original shell while bypassing the KERNAL's internal screen editor state machine.
- **Build Test**: `build/command64.asm` assembles successfully.

## Lessons Learned
- **C64 Input nuance**: `GETIN` is essential for any professional shell on C64, as `CHRIN` is too tightly coupled to the BASIC screen editor. However, the tradeoff is the loss of automatic echo, which requires manual implementation.
- **ABI Separation**: Moving VMM definitions to a dedicated `vmm.inc` file prevents the core shell include from becoming bloated as memory management logic grows.
