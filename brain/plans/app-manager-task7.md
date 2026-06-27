---
feature: app-manager-task7
created: 2026-06-27
status: planned
---

# Plan: App Manager Task 7 — Integrate Shell Commands (LOAD, RUN, APPS, FREE)

## Goal & Rationale

Integrate the App Table manager with the Command 64 shell, enforcing protected-address checks, registry table membership before executing programs, and introducing the `APPS`/`PS` and `FREE` commands.

## Scope

* **In-scope**:
  * Replacing `cmdLoad` and `cmdRun` in `shell.asm`.
  * Implementing `cmdApps` and `cmdFree`.
  * Registering `APPS`, `PS`, and `FREE` in the command table and `HELP` string.
* **Out-of-scope**: Implementing Binary Relocator execution (Phase B) or REU task swapping (Phase C).

## Files to Create/Modify

| File                                       | Action | Notes                                                          |
|--------------------------------------------|--------|----------------------------------------------------------------|
| [shell.asm](../../src/command64/shell.asm) | Modify | Replace handlers; register commands; add shell message strings |

## Key Design Decisions

* **`cmdLoad`**:
  1. Checks if relocated load. If so, calls `aptProtectedCheck` to reject overlaps with low-RAM/ROM.
  2. If the table is full (UsedSlots = 16), aborts with `app table full`.
  3. Executes standard file-find and load.
  4. If successful, calls `aptRegister` (passing name pointer, length in `SrcHandle`, load address, and returned end address).
* **`cmdRun`**:
  1. Parses the argument. If hex address, does `aptFind` in address mode. If alpha name, does `aptFind` in name mode.
  2. If not found in table, prints `not loaded` and returns.
  3. If found, jumps to the resolved address (`HandlerVecLo/Hi`).
* **`cmdApps`**: Simple router calling `aptList`.
* **`cmdFree`**:
  1. Parses the app name.
  2. Calls `aptFind` to resolve the slot. If not found, prints `not found`.
  3. Checks `Flags` for `APT_FLAG_RUNNING` (Phase C compatibility; refuses if set).
  4. Calls `aptRemove` to deregister the slot.

## Verification Plan

* Compile: `cmake --build build`.
