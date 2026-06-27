---
feature: app-manager-task4
created: 2026-06-27
status: planned
---

# Plan: App Manager Task 4 — Implement aptRegister with Overlap Eviction

## Goal & Rationale

Implement the registration routine to add or overwrite program entries in the registry, and enforce address-overlap eviction to prevent memory corruption when loading multiple programs at conflicting addresses (such as `$2200` in Phase A).

## Scope

* **In-scope**:
  * Writing `aptRegister` (checks existing entries, copies name, address, and size).
  * Implementing the 16-bit address-overlap checker and evictor.
* **Out-of-scope**: Paging binary code to REU backing store (deferred to Phase C).

## Files to Create/Modify

| File                                             | Action | Notes                                                          |
|--------------------------------------------------|--------|----------------------------------------------------------------|
| [apptable.asm](../../src/command64/apptable.asm) | Modify | Append aptRegister and memory range overlap verification logic |

## Key Design Decisions

* **Overlap Eviction**: Before allocating a slot, `aptRegister` will walk all 16 slots. If a slot is active, it compares its address range `[LoadAddr, LoadAddr + Size]` with the new program's range `[NewLoadAddr, NewEndAddr]`:
  * If `LoadAddr >= NewEndAddr` -> no overlap.
  * If `(LoadAddr + Size) <= NewLoadAddr` -> no overlap.
  * Otherwise, they overlap! The existing slot is cleared by calling `aptRemove`. This ensures that overwriting memory evicts the old program registration from the table automatically.
* **Search / Overwrite**: Searches by name first using `aptFind`. If an entry exists, its slot index is reused to overwrite the metadata (no change to `UsedSlots`).
* **Slot Allocation**: If it is a new program, it finds the first unused slot (Flags bit 0 = 0), writes the metadata, and increments `UsedSlots` in the VMM page header (offset 1).
* **Metadata Write**:
  * Sets `Flags` = `APT_FLAG_USED` ($01).
  * Copies up to 16 characters of the name from `NamePtrLo/Hi`, null-padding the rest of the 16-byte field.
  * Writes `LoadAddr` (`HexValLo/Hi`).
  * Computes and writes `Size` = `(end_addr+1) - LoadAddr`.

## Verification Plan

* Compile: `cmake --build build`.
