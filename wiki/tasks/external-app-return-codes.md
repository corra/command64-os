# External App Return Codes

Status: [ ]
Taskwarrior: 25

## Goal

Design and implement meaningful external application return status, analogous
in purpose to MS-DOS `ERRORLEVEL`, so shell automation can observe whether an
external utility succeeded, failed, or found a domain-specific condition.

## Current Finding

`DOS_EXIT ($4C)` currently resets the stack and jumps back to the shell main
loop. It has no documented input status byte and no shell-visible last-status
storage. Utilities such as `COMP` must therefore be screen-output-only until a
separate OS-level return-code design exists.

## Subtasks

- [ ] Define where last external-app status is stored.
- [ ] Define `DOS_EXIT` or a new API's status-passing convention.
- [ ] Define shell visibility (`ERRORLEVEL`, env var, or batch-only primitive).
- [ ] Update API docs and programmer reference.
- [ ] Update external app examples.
- [ ] Add tests/manual verification.

## Manual Verification

1. Run a utility that exits success.
2. Confirm shell-visible status reports success.
3. Run a utility that exits failure.
4. Confirm shell-visible status reports failure without corrupting shell state.

