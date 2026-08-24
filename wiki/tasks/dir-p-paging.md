# `dir /p` Paged Directory Listing

## Goal

Add a `/p` command-line option to the shell's `dir` command that pauses
output after each screenful and waits for a keypress, matching the
DOS-family `dir /p` convention. Plain `dir` (no `/p`) is unaffected.

Plan: `brain/plans/2026-08-21-dir-p-paging.md`. Taskwarrior task 44
(`5ae09831-1204-4204-a962-0cbf0a228197`, project `command64.shell`).

## Status

- [x] Plan drafted and approved (2026-08-21), including three scoping
  decisions: lowercase-only `/p`, position-independent relative to the
  device prefix, no abort key (matches `more`'s existing behavior).
- [x] Increment 1: baseline build succeeded; `CommandShell` occupies
  `$10D1-$1EFD`, leaving 162 bytes free before the `$1FA0` `VmmData`
  boundary (2026-08-21).
- [x] Increment 2: added `dirPagingEnabled`/`dirPageRow` state bytes to
  `ShellExt`; rebuild succeeded and `CommandShell` remained unchanged
  (2026-08-21).
- [x] Increment 3: implemented standalone lowercase `/p` token scanning
  and in-place excision before `parsePointerDevice`; live VICE confirmed
  plain `dir` clears paging and both flag/device orderings preserve device
  8 while enabling paging (2026-08-21).
- [x] Increment 4: implemented `dirPause`, row initialization, and the
  `cdLineDone` counting hook. The user-approved channel handoff uses
  `KernalCLRCHN` for keyboard input and reselects open LFN 13 afterward;
  rebuild succeeded with 36 bytes of `CommandShell` headroom
  (2026-08-21).
- [x] Increment 5: user manually verified build 2675 on a multi-screen
  directory: pause after 23 lines, any-key resume without stream
  corruption, plain `dir` unpaged, `dir 8: /p`, and `dir /p 8:` all pass
  (2026-08-22). Agent VICE verification was blocked by persistent MCP disk
  attachment failure and is recorded in the walkthrough.
- [x] Completion-gate walkthrough recorded and user-approved (2026-08-22).

## Current Behavior

`dir` (`cmdDir`, `src/command64/shell.asm:785`) remains unpaged by default.
Standalone lowercase `/p`, before or after an optional `N:` device prefix,
pauses after each 23-line screenful and resumes on any key.
