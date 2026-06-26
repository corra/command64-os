# Task Spec: DATE Command Implementation

## Description
Implement the internal shell command `DATE` to display and modify the system date.

## Scope
- Since the C64 CIA TOD clock does not track calendar years/months, establish a software-based calendar epoch or simple date memory block.
- Support displaying date in standard MM-DD-YYYY or DD-MM-YYYY formats.
- Support setting date via `DATE MM-DD-YYYY` command syntax.
- Store the system date persistently in the REU memory block.

## Sub-tasks
- [ ] Define system date storage structures in kernel RAM and REU space.
- [ ] Implement `cmdDate` handler in `shell.asm` to print and parse date inputs.
- [ ] Register `DATE` in the command table and the `HELP` output.
- [ ] Verify date persistence across warm starts.
