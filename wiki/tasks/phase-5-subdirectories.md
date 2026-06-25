# Task Spec: Phase 5 Subdirectory Support

## Description
Add support for navigating and reading subdirectories on devices that support them (such as the 1581 disk drive or modern SD2IEC devices).

## Scope
- Parse directory path separators (e.g., `/` or `\`) in filename parameters.
- Handle partition/directory commands for 1581 (using command channel parameters).
- Enable the shell `DIR` command to list contents of a subdirectory.
- Support relative and absolute paths for external program execution.

## Sub-tasks
- [ ] Implement path parsing routine to isolate directories from filenames.
- [ ] Implement SD2IEC partition/directory changing commands (CD command to drive command channel).
- [ ] Verify subdirectory switching on simulated SD2IEC or 1581 images in VICE.
