# COMP Command Implementation Plan

**Date:** 2026-07-14
**Branch:** `compfc`
**Taskwarrior:** #24
**Scope:** Plan first; implement only after explicit approval.

## 1. Goal

Implement `COMP` as a normal external utility shipped in the standard disk
image from the start. Phase 1 compares two files as raw byte streams and
reports byte offsets/values for mismatches.

`COMP` must stay out of the shell command table. It is an external app, not an
internal command, to avoid OS bloat and keep MS-DOS parity accurate.

## 2. Confirmed Product Decisions

- Implement `COMP` only in this phase; do not implement `FC`.
- Syntax is strict utility behavior:
  - `COMP FILE1 FILE2`
  - Missing arguments print usage.
  - Extra arguments print usage.
  - Slash options, including `/B`, are rejected in v1.
- Compare raw bytes regardless of file type.
  - PRG load-address bytes are compared exactly as stored.
  - No file-type interpretation or PRG payload special case.
- Report offsets and bytes in hex only.
- Maintain a 24-bit logical byte offset.
- Stop printing after 10 mismatches.
- Detect differing file sizes by streaming reads, not by precomputing size.
- `COMP` v1 is screen-output-only; external-app return codes are out of
  scope because the OS does not currently expose meaningful app exit status.

## 3. Non-Goals

- No `FC` implementation.
- No text-mode file compare.
- No DOS-style prompts for missing file names.
- No "Compare more files (Y/N)" loop.
- No file-size preflight through directory/BAM parsing.
- No kernel API changes for return codes.
- No broad DEBUG refactor unless a helper is already cleanly separable.

## 4. Return-Code Finding

Current `DOS_EXIT ($4C)` only resets the stack and jumps back to `mainLoop`.
It has no status-code input, no shell-visible output, and no documented
`ERRORLEVEL`/last-status variable. `COMP` can internally know whether files
matched, differed, or errored, but v1 cannot publish that result as a process
status without new OS design.

Follow-up task: Taskwarrior #25 / `wiki/tasks/external-app-return-codes.md`.

## 5. File Size Strategy

CBM DOS BAM data tracks free/used blocks, not exact per-file byte length.
Directory data is not a DOS-like exact byte-size source for `COMP`, and exact
size would still require following file data or block-chain details. Therefore
`COMP` should stream both files and discover size mismatch at EOF:

1. Read a chunk from file 1.
2. Read a chunk from file 2.
3. Compare the overlapping byte count.
4. If one chunk is shorter than the other, report `FILES ARE DIFFERENT SIZES`.
5. If both reach EOF together, report OK only if no mismatches were found.

This matches the existing `DOS_READ_FILE` API and avoids expensive drive-format
logic.

## 6. Recon Before Code

Perform these read-only checks before implementation edits:

1. Re-read root `AGENTS.md` and `src/external/AGENTS.md`.
2. Inspect `src/external/format/`, `src/external/label/`, and `src/external/edlin/`
   for current ca65 app startup, argument parsing, build numbering, and API
   usage patterns.
3. Inspect `MORE` implementation in `src/command64/shell.asm`.
   - `MORE` is currently internal, so parser extraction may not be appropriate.
   - Use it for behavior expectations, not as an automatic shared-code source.
4. Inspect `src/external/debug/debug.s` for reusable patterns:
   - byte comparison logic,
   - hex byte/address printing,
   - bounded mismatch/report output,
   - file-read helper patterns, if any.
5. Confirm Taskwarrior #22 (`fileRead` READST/CHRIN sequencing) status before
   final verification, because `COMP` depends directly on trustworthy streaming
   reads.

## 7. Modularization Plan

Design the argument parser as a small, separable utility even if it initially
lives in `src/external/comp/`.

Phase 1 parser contract:

- Input: shell argument tail at `CommandBuffer + ParsePos`.
- Output:
  - `File1Buf` null-terminated.
  - `File2Buf` null-terminated.
  - Carry clear on success.
  - Carry set with a small parser status code on usage/option errors.
- Behavior:
  - skip leading spaces,
  - parse exactly two non-space positional tokens,
  - preserve device prefixes such as `9:FILE`,
  - reject slash options,
  - reject extra non-space tokens,
  - cap each filename buffer to avoid overflow.

Extraction decision:

- Extract into a shared external-app parser module only if the build and symbol
  boundaries are obvious and low-risk.
- Otherwise keep it app-local but documented and shaped for later reuse by
  `FIND`, `SORT`, `ATTRIB`, `XCOPY`, or a future external `MORE`.

## 8. Proposed Source Layout

Use ca65/ld65 unless recon finds a compelling reason to use KickAssembler.
The current external app direction favors ca65.

Expected files:

- `src/external/comp/BUILD_COMP`
- `src/external/comp/comp.s`
- `src/external/comp/common.inc` if the app grows beyond one file

Expected CMake work:

- Add `COMP_SRCS` and `COMP_ENTRY`.
- Add `add_ca65_app(comp "${COMP_ENTRY}" COMP_SRCS 1000 "<size>")`.
- Add `COMP_TARGET` to `IMAGE_PRG_TARGETS` so `COMP` ships from the start.

Initial `PRG_SIZE_HEX` should be selected after the source skeleton exists.
Likely range: `0700` to `0A00`, depending on parser/printing helpers.

## 9. Runtime Design

### Startup

1. Print a short version banner only if existing external utilities do so
   consistently for direct invocation.
2. Parse arguments.
3. On usage/option error, print usage and exit via `DOS_EXIT`.

### Open

1. Open file 1 read-only via `DOS_OPEN_FILE`.
2. Open file 2 read-only via `DOS_OPEN_FILE`.
3. If either open fails, print an error and close any already-open handle.

### Compare Loop

Use two fixed-size buffers. Preferred chunk size: 64 bytes per file.

For each iteration:

1. Read up to 64 bytes from file 1.
2. Read up to 64 bytes from file 2.
3. Compare `min(read1, read2)` bytes.
4. For each mismatch:
   - print `COMPARE ERROR AT $HHMMLL: $AA $BB`,
   - increment mismatch count,
   - stop printing after 10 mismatches and exit compare early.
5. Increment 24-bit offset by the number of overlapping bytes compared.
6. If `read1 != read2`, report differing sizes and finish.
7. If both reads are zero, finish.
8. Otherwise continue.

### EOF and Error Handling

The final byte at EOI must be preserved by `DOS_READ_FILE`; if Taskwarrior #22
is not fixed in the current source, implementation may build but manual compare
verification is blocked until the shared file-read bug is resolved.

Every path must close both handles that were successfully opened.

## 10. Output Text

Keep messages short for 40-column display:

```text
USAGE: COMP FILE1 FILE2
UNKNOWN OPTION
TOO MANY ARGUMENTS
FILE OPEN ERROR
READ ERROR
COMPARE ERROR AT $000123: $41 $42
10 MISMATCHES - STOPPING
FILES ARE DIFFERENT SIZES
FILES COMPARE OK
```

Exact wording can be adjusted during implementation to fit PETSCII/layout
constraints.

## 11. Verification Plan

Build verification:

- `cmake --build build --target image_d64`
- `cmake --build build --target test_image_d64` if test fixtures are added.

Do not use `c64-testing`; project instructions mark it broken. Do not use a web
emulator. Ask the user for C64/VICE/manual verification when needed.

Manual cases:

1. `COMP SAME1 SAME2` with identical files: prints `FILES COMPARE OK`.
2. One-byte difference: prints one compare error at the expected hex offset.
3. More than 10 differences: prints 10 mismatches and the stopping message.
4. File 1 longer: compares overlap, then reports different sizes.
5. File 2 longer: compares overlap, then reports different sizes.
6. Missing first file: clean error, no leaked handle.
7. Missing second file: clean error, first handle is closed.
8. Missing args / extra args: usage.
9. `/B` or any slash option: rejected in v1.
10. PRG-vs-PRG compare: raw bytes including load address are compared.

## 12. Documentation Updates During Implementation

After code approval and implementation:

- Update `wiki/tasks/comp-command.md`.
- Update `brain/task.md`.
- Update `docs/codebase-reference.md` only if CMake/external-app inventory or
  reusable parser structure is added.
- Update `brain/analysis/2026-07-12-ms-dos-4.0-parity-comparison.md` only if
  implementation decisions differ from the current feasibility notes.
- Perform the DOX closeout pass for every touched path.

## 13. Approval Gate

Do not implement code until the user approves this plan.
