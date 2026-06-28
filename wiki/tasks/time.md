# Task Spec: TIME Command Implementation

## Description

Implement the internal shell command `TIME` to display and modify the system time by interfacing with the C64 CIA Real Time Clock (CIA 1 TOD registers).

## Scope

- Read Time of Day (TOD) clock registers from CIA 1 (`$DC08`–`$DC0B`) to retrieve hours, minutes, seconds, and tenths of a second.
- Support displaying time in standard HH:MM:SS format.
- Support setting time via `TIME HH:MM:SS` command syntax.
- Handle AM/PM bit conversion or standard 24-hour mode.

## Sub-tasks

- [ ] Implement TOD clock initialization routine at system boot.
- [ ] Implement `cmdTime` handler in `shell.asm` to format and print time.
- [ ] Implement CIA 1 TOD register write routines to allow user clock adjustments.
- [ ] Register `TIME` in the command table and the `HELP` output.
