---
feature: app-manager-task3
created: 2026-06-27
status: planned
---

# Plan: App Manager Task 3 — Implement aptFind and aptNameMatch

## Goal & Rationale

Implement the search engine for the loaded program registry. The shell and API layer must be able to scan the VMM page to find registered applications either by matching their filename strings (for command execution) or their RAM load addresses (for address execution checks).

## Scope

* **In-scope**:
  * Implementing `aptNameMatch` to compare search strings against name buffers stored inside VMM entries.
  * Implementing `aptFind` to scan all 16 slots.
* **Out-of-scope**: Writing code for editing entries (Task 4/5) or displaying listings (Task 6).

## Files to Create/Modify

| File                                             | Action | Notes                                             |
|--------------------------------------------------|--------|---------------------------------------------------|
| [apptable.asm](../../src/command64/apptable.asm) | Modify | Append aptNameMatch, aptFind, and state variables |

## Key Design Decisions

* **`aptNameMatch`**: Inputs search pointer at `NamePtrLo/Hi` and length in `SrcHandle`. Compares up to `SrcHandle` bytes. To prevent partial prefix matching (e.g., search `"hel"` matching entry `"hello"`), it reads the `SrcHandle + 1` byte from the entry name field and ensures it is `$00` (null-terminator).
* **`aptFind`**: Supports two modes via the Carry flag on input:
  * `Carry = 0` (Name Search): Uses `NamePtrLo/Hi` and `SrcHandle` (length).
  * `Carry = 1` (Address Search): Matches `HexValLo/Hi` with entry `LoadAddr`.
  * Walks slots `X = 0..15`. Skips entries where the `SLOT_USED` flag bit is clear.
  * If matched, it reads the entry's `LoadAddr` field, stores it in `HandlerVecLo/Hi`, and returns `Carry = 0` and slot index in `X`. On miss, returns `Carry = 1`.

## Verification Plan

* Compile: `cmake --build build`.
* Verify that code compiles and the segment fits within the 512-byte limit.
