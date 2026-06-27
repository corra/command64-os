---
feature: app-manager-task1
created: 2026-06-27
status: planned
---

# Plan: App Manager Task 1 — Add APT Constants and Shift UserProgStart

## Goal & Rationale

To make room for the resident App Table manager segment in main RAM, the start address of user executable programs (`UserProgStart`) must be shifted from `$2000` to `$2200`. We must also define all App Table constants (entry offsets, flags, and VMM pointer registers).

## Scope

* **In-scope**: Updating constants in `include/command64.inc` and relocating compile addresses (`* =`) for the debugger utility and all six test programs.
* **Out-of-scope**: Writing any App Table code or modifying loader routines (handled in later tasks).

## Files to Create/Modify

| File                                                 | Action | Notes                                                 |
|------------------------------------------------------|--------|-------------------------------------------------------|
| [include/command64.inc](../../include/command64.inc) | Modify | Define APT constants and update UserProgStart = $2200 |
| [debug.asm](../../src/external/debug/debug.asm)      | Modify | Shift entry address to $2200                          |
| [apitest.asm](../../tests/src/apitest.asm)           | Modify | Shift entry address to $2200                          |
| [color.asm](../../tests/src/color.asm)               | Modify | Shift entry address to $2200                          |
| [extcls.asm](../../tests/src/extcls.asm)             | Modify | Shift entry address to $2200                          |
| [filetest.asm](../../tests/src/filetest.asm)         | Modify | Shift entry address to $2200                          |
| [hello.asm](../../tests/src/hello.asm)               | Modify | Shift entry address to $2200                          |
| [vmmtest.asm](../../tests/src/vmmtest.asm)           | Modify | Shift entry address to $2200                          |

## Key Design Decisions

* The App Table registry page will occupy memory region `$2000-$21FF` (512 bytes), allowing up to 16 slots of 40-byte entries. Shifting `UserProgStart` to `$2200` ensures that absolute-loaded external commands never overwrite the App Table manager code.

## Verification Plan

* Run compilation: `cmake --build build`.
* Verify all relocated programs compile without errors or overlaps.
