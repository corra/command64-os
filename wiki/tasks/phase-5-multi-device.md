# Task Spec: Phase 5 Multi-Device Support

## Description
Provide support in the command64 OS to dynamically switch between and interact with multiple disk devices connected to the C64 (devices 8, 9, 10, and 11).

## Scope
- Implement `DRIVE [8-11]` command in the shell to change the current active device.
- Integrate the active device selection with the file system operations (loading, saving, deleting, renaming).
- Update the shell prompt or status to display the active device number.
- Gracefully fail with "Invalid device" if a user specifies an address outside the range 8-11.

## Sub-tasks
- [x] Implement basic `DRIVE` command (with `DEVICE`/`DEV` aliases) and saving device in `CurrentDevice` ($039E).
- [ ] Add support for dynamically changing file open routines to use `CurrentDevice`.
- [ ] Update `path.asm` and `loader.asm` to target the active device.
- [ ] Verify functionality using multiple active drive attachments in VICE.
