# Task Spec: Dynamic Memory safety & Allocation

> **Split notice:** The safety-check/validation portion of this spec
> (`aptCheckRange`, `getFileSize`, aborting unsafe `cmdLoad`s) is now tracked
> in detail in [`memory-safe-loading.md`](memory-safe-loading.md), which is
> in scope now. The `aptFindFreeRegion` sliding-window allocator (auto-slotting
> on `LOAD`) remains deferred and stays tracked here only.

## Description
Develop dynamic memory allocation on `LOAD` (finding next available slot of memory without overwriting existing registered programs), explicit address loading safety validation (blocking loads that overlap with existing programs or protected regions), and global `free` command execution (unloading all loaded programs).

## Scope
- Implement file size pre-resolution (`getFileSize` using directory check `"$:filename"` and `calcFileSize`).
- Implement memory range validation (`aptCheckRange`) protecting `$0000–$29FF` and `$C000–$FFFF` and checking for overlaps against all other registered apps.
- Implement sliding-window allocator (`aptFindFreeRegion`) to dynamically locate the first free page-aligned address.
- Support bare `free` command to call `aptRemoveAll` and deregister all active apps.
- Harden `cmdLoad` to check address bounds, enforce relocation checks for dynamic loads, and prevent program memory clobbering.

## Sub-tasks
- [x] Define Cassette Buffer registers in `include/command64.inc`
- [x] Write `aptCheckRange` range overlap routine in `apptable.asm`
- [x] Write `aptFindFreeRegion` allocator in `apptable.asm`
- [x] Write `aptRemoveAll` global free routine in `apptable.asm`
- [x] Implement LFN 13 directory read `getFileSize` in `shell.asm`
- [x] Integrate safety check and allocator into `cmdLoad` in `shell.asm`
- [x] Integrate bare `free` command handler in `shell.asm`
- [x] Compile and verify safety boundaries and dynamic allocation under VICE

> **Status: Shipped.** All sub-tasks complete — see `CHANGELOG.md`
> "Dynamic Memory Allocation (Auto-Slotting)" and
> [`memory-safe-loading.md`](memory-safe-loading.md) for the validation half.
