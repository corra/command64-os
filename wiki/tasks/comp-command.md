# COMP Command

Status: [/]
Taskwarrior: 24

## Goal

Implement `COMP` as an external command that compares two files as raw byte
streams and reports byte-level differences.

## Scope

- External app, not an internal shell command.
- Built into the normal disk image from the start.
- Strict syntax: `COMP FILE1 FILE2`.
- Raw byte comparison regardless of file type.
- Hex-only offsets and byte values.
- 24-bit logical byte offset.
- 10 mismatch display cap.
- Streaming size-mismatch detection; no BAM/directory pre-size pass.
- Reject slash options in v1.

## Subtasks

- [x] Create active Taskwarrior task.
- [x] Write implementation plan for approval.
- [x] Review external app build/startup patterns.
- [x] Review `MORE` behavior for parser expectations.
- [x] Review `DEBUG` compare/hex helpers for possible reuse.
- [x] Confirm shared `fileRead` bug status before manual verification.
- [x] Implement `src/external/comp/` source and build file.
- [x] Wire `COMP` into `CMakeLists.txt` and `IMAGE_PRG_TARGETS`.
- [x] Implement strict two-argument parser.
- [x] Implement raw streaming compare backend.
- [x] Implement hex offset/byte output.
- [x] Build `image_d64` successfully.
- [x] Build `test_image_d64` successfully.
- [ ] Complete manual C64/VICE verification.
- [x] Update docs and task status.

## Manual Verification

1. Boot command64 with a disk image containing `COMP`.
2. Run `COMP SAME1 SAME2` and confirm identical files report OK.
3. Run `COMP DIFF1 DIFF2` with one known byte difference and confirm the
   reported hex offset and byte values.
4. Run against files with more than 10 differences and confirm output stops at
   the cap.
5. Run file1-longer and file2-longer cases and confirm size mismatch reporting.
6. Run missing-file and bad-argument cases and confirm clean return to prompt.
7. Run against PRG files and confirm raw bytes, including load-address bytes,
   are compared.
