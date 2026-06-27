---
feature: app-manager-task2
created: 2026-06-27
status: planned
---

# Plan: App Manager Task 2 — Create apptable.asm Skeleton and Segment

## Goal & Rationale

Establish the core App Table assembly file, wire it into the segment layout in `src/command64.asm` at `$2000`, and initialize the VMM-backed table page on boot.

## Scope

* **In-scope**:
  * Creating `apptable.asm` with initial initialization, boundary checks, and helper functions.
  * Registering the `AppTable` segment in `src/command64.asm`.
  * Triggering initialization (`aptInit`) in the startup code of `shell.asm`.
* **Out-of-scope**: Writing search, registration, or print routines (deferred to Tasks 3-6).

## Files to Create/Modify

| File                                             | Action | Notes                                                               |
|--------------------------------------------------|--------|---------------------------------------------------------------------|
| [apptable.asm](../../src/command64/apptable.asm) | Create | Define segment, write aptInit, aptSlotBase, aptProtectedCheck       |
| [command64.asm](../../src/command64.asm)         | Modify | Define AppTable segmentdef at $2000; import apptable.asm            |
| [shell.asm](../../src/command64/shell.asm)       | Modify | Call aptInit immediately after double-null env block initialization |

## Key Design Decisions

* **`aptInit`**: Idempotent page allocator. Checks `AptSegLo/Hi` ($03F2-$03F3) first. If zero, requests 1 page (256 paragraphs) via `vmmAlloc`, sets the persistent pointer, and initializes the header: `MaxSlots` = 16, `UsedSlots` = 0.
* **`aptSlotBase`**: Stride calculation helper. Sets `VmmSeg/Off` to the base of entry index `X`. Stride is 40 bytes. Offset = `4 + X * 40`. Uses zero-page `DstHandle` ($6F) as loop counter to preserve `X`.
* **`aptProtectedCheck`**: Rejects load addresses if `HexValHi < $22` (overlap with OS memory `$0000-$21FF`) or `HexValHi >= $C0` (overlap with MCT `$C000-$CFFF`, I/O `$D000-$DFFF`, KERNAL `$E000-$FFFF`).

## Verification Plan

* Compile: `cmake --build build`.
* Verify that `AppTable` fits cleanly in the `$2000-$21FF` boundary.
