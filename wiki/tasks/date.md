# Task Spec: DATE Command Implementation

## Description
Implement the internal shell command `DATE` to display and modify the system date.

## Scope
- Since the C64 CIA TOD clock does not track calendar years/months, establish a software-based calendar epoch in resident kernel RAM.
- Support displaying date in standard `YYYY-MM-DD` format.
- Support setting date via `DATE YYYY-MM-DD` command syntax.
- Phase 1 does not persist date across cold boot or `RUN`; hardware RTC persistence is deferred to later phases.

## Sub-tasks
- [x] Define system date storage structures in resident kernel RAM.
- [x] Implement `cmdDate` handler in `shell.asm` to print and parse date inputs.
- [x] Register `DATE` in the command table and the `HELP` output.
- [x] Verify direct and interactive setting/display round-trips.
- [x] Verify leap-year validation.
- [x] Verify midnight and month rollover.
