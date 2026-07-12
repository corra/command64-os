# Task Spec: LABEL Interactive Prompt

## Description

Implement interactive prompt mode for the `LABEL` command when invoked with no arguments, matching MS-DOS behavior where `LABEL` alone prompts the user to type a new label.

## Scope

- When `LABEL` is invoked with no argument, prompt: `Volume label (16 chars max)?`
- Read user input via KERNAL input routines.
- Validate length (≤ 16 characters).
- Write the new label using the existing `cmdLabel` BAM-write logic.
- Empty input (just RETURN) should cancel without modifying the disk.

## Prerequisites

- `LABEL` command with argument support must be implemented first (see `vol-label.md`).

## Sub-tasks

- [x] Add interactive input branch to `cmdLabel` when no argument is present.
- [x] Reuse existing BAM-write logic for the actual rename.
- [x] Handle empty input as a cancel/no-op.

## Status

Done. Implemented in `src/external/label/label.s` (`labelNoArg`/`readLoop`,
prompt/backspace/cancel-on-empty behavior) since the first LABEL spike
commit — this tracker just hadn't been checked off. Documented in
[wiki/label-utility.md](../label-utility.md#interactive-prompt-mode).
