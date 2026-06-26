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
- [ ] Add interactive input branch to `cmdLabel` when no argument is present.
- [ ] Reuse existing BAM-write logic for the actual rename.
- [ ] Handle empty input as a cancel/no-op.
