# MORE Command

Status: [x]
Taskwarrior: 24

## Goal

Implement an internal `MORE [filename]` command based on MS-DOS `MORE`, adapted to command64's current file API and 40x25 C64 text display.

## Subtasks

- [x] Add `MORE` to the internal command table and help text.
- [x] Read files through the existing DOS open/read/close API.
- [x] Support temporary target-device prefixes (`8:`, `9:`, `10:`, `11:`).
- [x] Track rows/columns and pause with `-- More --` before the screen fills.
- [x] Document the command in the user manual and mirrored docs.
- [x] Verify with a clean build.
- [x] Manually verify on C64/VICE workflow.

## Manual Verification

1. Boot command64.
2. Run `MORE README` against a file longer than one screen.
3. Confirm output pauses with `-- More --`, resumes after one keypress, and returns to the prompt at EOF.
4. Run `MORE 9:README` with a readable file on device 9 and confirm the active drive is restored afterward.
5. Run `MORE` and confirm it prints `File name required`.
6. Run `MORE MISSING` and confirm it reports the drive/file status and returns to the prompt.
