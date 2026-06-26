# Task Spec: VOL / LABEL Command Implementation

## Description
Implement the internal shell commands `VOL` and `LABEL` for reading and writing the C64 disk directory header volume label.

## Scope
- `VOL`: Retrieve and display the current disk name and disk ID from the directory header.
- `LABEL`: Modify the disk name/label dynamically by executing the disk BAM header edit command on the drive command channel.
- Limit inputs to standard C64 filename lengths (up to 16 characters for label).

## Sub-tasks
- [x] Implement `cmdVol` routine in `shell.asm` to read and print the disk header name/ID.
- [x] Implement `cmdLabel` routine in `shell.asm` to write a new name to the disk header using the floppy disk command channel.
- [x] Register `VOL` and `LABEL` in the command table and the `HELP` output.
- [x] Verify functionality on standard D64 disk images.
