---
feature: vmm-allocation
completed: 2026-05-09
status: completed
---

# Walkthrough: VMM Allocation Logic

## Summary
Successfully implemented the core Virtual Memory Manager (VMM) and dynamic allocation primitives. The system now supports up to 16MB of REU memory using a 4KB Byte-Map strategy. A major portion of this effort involved stabilizing the shell by isolating it from the C64's native BASIC and KERNAL environments.

## Files Changed
| File | Change | Notes |
|------|--------|-------|
| `include/vmm.inc` | Created/Modified | Defined VMM ABI, REU registers, and page state flags. |
| `include/command64.inc` | Modified | Remapped Zero Page pointers to safe areas and isolated buffers. |
| `src/command64/vmm.asm` | Created | Implemented `vmmInit`, `vmmAlloc`, `vmmFree`, and byte-level I/O. |
| `src/command64/shell.asm` | Modified | Added VMM initialization and version tracking banner. |
| `build/command64.asm` | Modified | Adjusted memory map to resolve segment overlaps. |
| `docs/vmm-api.md` | Modified | Synchronized documentation with the implemented 16MB Byte-Map design. |

## Testing Results
- **Assembly**: Build passes with 0 errors/warnings.
- **Stability**: Verified that `EXIT` to BASIC works without corrupting `LIST`.
- **Isolation**: Verified that `CommandBuffer` at `$033C` no longer stomps on code at `$1600`.
- **Verification**: Internal commands (`CLS`, `VER`, `ECHO`) are fully functional.

## Lessons Learned & Gotchas
- **BASIC Sensitivity**: Zero Page range `$2B-$32` is critical for BASIC. Any use of this range by the shell or VMM causes immediate instability and corrupted `LIST` artifacts.
- **Segment Overlaps**: As the shell code grows, fixed segment addresses in `build/command64.asm` must be proactively adjusted. Using the Cassette Buffer (`$033C`) for the command buffer is a safer alternative than mid-RAM locations.
- **External Compatibility**: External programs pre-compiled for `$2000` must be loaded at that exact address; shifting `UserProgStart` to `$4000` caused immediate crashes upon execution.
