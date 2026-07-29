# BANNER Command

Status: [x]
Taskwarrior: 33

## Goal

Implement `BANNER` as a UNIX-style external command for Command64 OS that renders text messages in 5x6 block characters. Implemented using `#` (`$23`) for block cells — the originally specified inverted space (`$A0`) was replaced during implementation because it rendered incorrectly.

## Scope

- External application built with ca65/ld65 toolchain in `src/external/banner/`.
- Integrated into `CMakeLists.txt` and shipped in a new CASM utilities disk image.
- Command line parsing for message string argument.
- 5x6 monospace character rendering engine using `#` (`$23`) for block cells and regular space (`$20`) for empty cells.
- Horizontal (left-to-right) output layout with 1-character spacing (6 columns total per character, 6 characters max per 40-column screen row).
- Clean line-wrapping when text exceeds the 40-column screen width.
- Clean exit to OS shell via `DOS_EXIT` (`$4C` via `OS_API`).

## Subtasks

- [x] Create feature branch `feature/banner-command`.
- [x] Create Taskwarrior task #33.
- [x] Create task tracking doc at `wiki/tasks/banner-command.md`.
- [x] Draft initial implementation plan artifact for user approval.
- [x] Update implementation plan based on user feedback (5x6 monospace, inverted space $A0, LTR layout, line wrap).
- [x] Implement `src/external/banner/BUILD_BANNER` initialized to `1000`.
- [x] Inline zero-page equations and font data in `src/external/banner/banner.s` for native `casm` compatibility.
- [x] Create `src/external/banner/header.s` to hold ca65/ld65 build segments.
- [x] Wire `BANNER` into `CMakeLists.txt` as a target on `command64_casm_utils.d64` (PRG and source SEQ).
- [x] Verify clean build of the CASM utilities disk image.
- [x] Verify manual runtime execution in VICE emulator (user-confirmed 2026-07-28).
- [x] Implement line-leading space skipping so wrapped lines stay left-aligned.
- [x] Update documentation (`wiki/user-manual.md` -> synced to `docs/`, `wiki/banner-utility.md`, `CHANGELOG.md`).

## Manual Verification

1. Boot Command64 OS in VICE.
2. Execute `BANNER HELLO` and verify 5x6 PETSCII block rendering on the screen.
3. Execute `BANNER COMMAND64` and verify clean line wrapping after 6 characters on the 40-column screen.
4. Execute `BANNER` (no args) or `BANNER /?` and verify usage help.
5. Verify clean return to shell prompt without zero-page or memory corruption.
