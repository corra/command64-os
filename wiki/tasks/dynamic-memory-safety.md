# Task Spec: Dynamic Memory safety & Allocation

## Description
Develop dynamic memory allocation on `LOAD` (finding next available slot of memory without overwriting existing registered programs), explicit address loading safety validation (blocking loads that overlap with existing programs or protected regions), and global `free` command execution (unloading all loaded programs).

## Scope
- Implement file size pre-resolution (`getFileSize` using directory check `"$:filename"` and `calcFileSize`).
- Implement memory range validation (`aptCheckRange`) protecting `$0000–$29FF` and `$C000–$FFFF` and checking for overlaps against all other registered apps.
- Implement sliding-window allocator (`aptFindFreeRegion`) to dynamically locate the first free page-aligned address.
- Support bare `free` command to call `aptRemoveAll` and deregister all active apps.
- Harden `cmdLoad` to check address bounds, enforce relocation checks for dynamic loads, and prevent program memory clobbering.

## Sub-tasks
- [ ] Define Cassette Buffer registers in `include/command64.inc`
- [ ] Write `aptCheckRange` range overlap routine in `apptable.asm`
- [ ] Write `aptFindFreeRegion` allocator in `apptable.asm`
- [ ] Write `aptRemoveAll` global free routine in `apptable.asm`
- [ ] Implement LFN 13 directory read `getFileSize` in `shell.asm`
- [ ] Integrate safety check and allocator into `cmdLoad` in `shell.asm`
- [ ] Integrate bare `free` command handler in `shell.asm`
- [ ] Compile and verify safety boundaries and dynamic allocation under VICE
