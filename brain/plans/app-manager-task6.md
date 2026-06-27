---
feature: app-manager-task6
created: 2026-06-27
status: planned
---

# Plan: App Manager Task 6 — Implement aptList and aptPrintHex8

## Goal & Rationale

Implement the formatted display logic for listing loaded programs, equivalent to the MS-DOS `mem` or Unix `ps`/`apps` commands.

## Scope

* **In-scope**:
  * Writing `aptPrintHex8` (prints accumulator as two uppercase hex digits).
  * Writing `aptList` (reads VMM entries, prints names, load addresses, and sizes, with headers and summaries).
* **Out-of-scope**: Displaying REU backing addresses or register states (Phase C).

## Files to Create/Modify

| File                                             | Action | Notes                                              |
|--------------------------------------------------|--------|----------------------------------------------------|
| [apptable.asm](../../src/command64/apptable.asm) | Modify | Append aptPrintHex8, aptList, and string constants |

## Key Design Decisions

* **`aptPrintHex8`**: Standard 8-bit hex formatting. Displays high nibble and low nibble using lookup table `"0123456789abcdef"`. Clobbers `A`, `X`. Preserves `Y` (crucial for walking filename loops).
* **`aptList`**:
  * Reads `UsedSlots` from VMM header. If 0, prints `no apps loaded` and returns.
  * Otherwise, prints table header: `name             addr  size`.
  * Walks slots 0..15. If a slot is used:
    * Prints 16 characters of the name field. If it encounters `$00` (null-padding), it prints a space character (`' '`) to align columns.
    * Prints a space separator.
    * Prints `LoadAddr` (4 hex digits: high byte then low byte).
    * Prints a space separator.
    * Prints `Size` (4 hex digits: high byte then low byte).
    * Prints carriage return.
  * Prints summary footer: `"<N> app(s) loaded"`.

## Verification Plan

* Compile: `cmake --build build`.
