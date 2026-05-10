---
feature: vmm-allocation
created: 2026-05-09
status: completed
---

# Plan: Phase 2C - VMM Allocation Logic

## Goal & Rationale
Implement the dynamic memory allocation primitives (`vmmAlloc` and `vmmFree`) for the Virtual Memory Manager. To support up to 16MB of REU space efficiently on a 1MHz 6502, we are using an **Out-of-Band Byte-Map** strategy. 

Instead of traditional DOS 16-byte paragraph granularity with in-band Memory Control Blocks (MCBs), we will use **4KB Pages**. A 16MB space requires exactly 4096 pages, which can be tracked perfectly in a 4096-byte (4KB) Byte-Map located in base RAM.

## Scope
- Move `VmmMctBase` from `$1700` to `$C000` (final relocation) and expand to 4096 bytes (4KB).
- Relocate `UserProgStart` to `$2000` to maintain compatibility with existing test programs.
- Implement `vmmAlloc`: 
  - Takes requested size in 16-byte paragraphs.
  - Rounds up to nearest 4KB page count.
  - Scans the byte-map for contiguous `$00` (Free) bytes.
  - Marks them: `$01` for the head, `$02` for the tail blocks.
  - Returns the starting logical Segment and Bank.
- Implement `vmmFree`: 
  - Takes a DOS segment pointer.
  - Walks forward from the start pointer in the byte-map.
  - Frees the `$01` block and any subsequent `$02` blocks until it hits `$00` or another `$01`.

## Files to Create/Modify
| File | Action | Notes |
|------|--------|-------|
| `include/vmm.inc` | Modify | Update MCT constants and add page state flags. |
| `include/command64.inc` | Modify | Synchronize headers and update ZP safe areas. |
| `src/command64/vmm.asm` | Modify | Implement `vmmAlloc` and `vmmFree`. Update `vmmInit` to clear the 4KB table. |
| `docs/vmm-api.md` | Modify | Update allocation documentation to reflect 4KB page granularity. |

## Key Design Decisions
- **Byte-Map vs Bit-Map**: A raw bit-map cannot easily track the length of an allocation. By dedicating 4KB of base RAM to a Byte-Map, we can use Head ($01) and Tail ($02) markers, completely eliminating the need for separate size tracking or MCB headers.
- **ZP Isolation**: Remapped all pointers to `$FB-$FE` and `$61-$6C` to prevent corruption of BASIC and KERNAL state.
- **Buffer Isolation**: Moved `CommandBuffer` to `$033C` to avoid code collisions.

## Verification Plan
- **Assembly Verification**: Build the project to ensure no segment overlaps.
- **Stability Check**: Verify shell re-entry and BASIC stability after exit.
- **Functionality**: Verify external command loading and internal command dispatch.

## Progress
- [x] Update documentation and headers
- [x] Implement `vmmAlloc`
- [x] Implement `vmmFree`
- [x] Resolve memory and ZP collisions
