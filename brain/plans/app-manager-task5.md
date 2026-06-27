---
feature: app-manager-task5
created: 2026-06-27
status: planned
---

# Plan: App Manager Task 5 — Implement aptRemove

## Goal & Rationale

Implement the deregistration routine to release slots in the App Table. This frees the entry in VMM space and decrements the active program count.

## Scope

* **In-scope**: Writing `aptRemove` to clear flags and decrement the table header's `UsedSlots` byte.
* **Out-of-scope**: Zeroing RAM (not necessary, as eviction only requires clearing the OS registry entry) or freeing REU backing store (Phase C).

## Files to Create/Modify

| File                                             | Action | Notes            |
|--------------------------------------------------|--------|------------------|
| [apptable.asm](../../src/command64/apptable.asm) | Modify | Append aptRemove |

## Key Design Decisions

* **`aptRemove`**:
  * Input: `X` = slot index (0..15).
  * Clears the `Flags` byte (offset 0) of the entry to `$00`, which clears `APT_FLAG_USED` and releases the slot.
  * Reads `UsedSlots` from VMM header offset 1, decrements it by 1, and writes it back.
  * Preserves `X` so callers can chain operations on the target slot if needed.

## Verification Plan

* Compile: `cmake --build build`.
