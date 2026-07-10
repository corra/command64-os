# Task Spec: External `FORMAT` Utility

## Description

Develop an external user-space `format` application (`format.asm`) for
Command 64 OS that formats a floppy disk by sending the CBM DOS native
`N:name,id` (NEW) command to the target drive's command channel. `format`
is a thin wrapper around the drive's own firmware format routine — the C64
does not perform host-side low-level formatting the way MS-DOS's
`FORMAT.COM` does against a BIOS-addressed FAT volume; the 1541/1571/1581
drives own the actual format logic and are the correct place for it to
live.

### Reference material (read-only, non-portable)

`ms-dos/v4.0/src/CMD/FORMAT/FORMAT.ASM` is retained in this repository as
**reference only**. It targets FAT12 over BIOS INT 13h on physically
addressed sectors — a completely different disk model from CBM DOS's
track/sector/GCR layout on the IEC bus. Nothing in that source is portable
to this application. Concepts worth borrowing (not code): overall command
flow (prompt → confirm → invoke → verify → report) and confirmation/UX
conventions for a destructive operation.

## Scope

- **Drive support**: 1541 (single-sided, 35 track) only for v1. 1571
  (double-sided) and 1581 (3.5", different NEW syntax) are explicitly out
  of scope — see Non-Goals.
- **Operation**: Send `N:<name>,<id>` to the target device's command
  channel via the new `DOS_SEND_COMMAND` primitive (see
  `dos-send-command.md`), then read back and report the drive's status
  response.
- **Invocation syntax**: `FORMAT <dev>:<name>,<id>`, e.g.
  `FORMAT 8:MYDISK,01`. Device prefix matches the existing `<dev>:`
  filename convention used elsewhere in the OS (`fileOpen` /
  `parsePointerDevice`).
- **Interactive fallback**: if invoked with no arguments (or incomplete
  arguments), prompt interactively for device number, disk name, and ID in
  turn.
- **Client-side validation** (before ever contacting the drive):
  - Assembled command string (the full `N:name,id` sent to the drive):
    trim leading and trailing spaces before length/charset checks and
    before transmission.
  - Disk name: rtrim only (strip trailing spaces; leading spaces are
    significant/preserved, since CBM DOS disk names may legitimately start
    with a space). 1-16 characters after rtrim, PETSCII, no `,` or `:`.
  - ID: exactly 2 characters.
  - Device number: numeric, in a sane device range (8-11).
  - Reject and re-prompt (interactive mode) or exit with an error message
    (CLI mode) on validation failure — no drive I/O attempted.
- **Confirmation (destructive-action safety)**:
  1. Print `Format drive <dev> - ALL DATA WILL BE LOST. Continue? (Y/N)`.
     Abort on anything but `Y`.
  2. Prompt `Re-enter disk name to confirm:` and require an exact match
     against the name already supplied. Abort (no drive I/O) on mismatch.
- **Progress indication**: a simple busy indicator (e.g. animated dots)
  while waiting on the drive's command-channel response. Not cancellable —
  the 1541 firmware doesn't support aborting a NEW once started, so there's
  no clean abort path to offer.
- **Result reporting**: print the drive's actual status-channel response
  (e.g. `73,COMMODORE DOS V2.6,00,00` / error text) rather than a generic
  pass/fail, using `DOS_SEND_COMMAND`'s response buffer.

## Non-Goals

- 1571 double-sided native mode and 1581 support (future task).
- Any low-level/manual track-by-track formatting logic — the drive
  firmware owns this entirely.
- Quick-format / verify-only modes.
- Any BIOS-style sector addressing, FAT structures, or other MS-DOS
  FORMAT.COM concepts.

## Prerequisites

- `DOS_SEND_COMMAND` kernel primitive must land first — see
  `dos-send-command.md`. `format` cannot send a raw command-channel string
  through the existing stable API (`DOS_OPEN_FILE` only reaches secondary
  addresses 2-9, never 15).

## Sub-tasks

- [ ] Create persistent build counter `BUILD_FORMAT` at
      `src/external/format/BUILD_FORMAT`.
- [ ] Add `format` ca65/ld65 application target via `add_ca65_app` in
      `CMakeLists.txt`, wired into the disk image targets.
- [ ] Create entry assembly file `src/external/format/format.asm` with
      version constants and `command64.inc` include per
      `src/external/AGENTS.md`'s ca65 workflow.
- [ ] Implement CLI argument parsing (`<dev>:<name>,<id>`).
- [ ] Implement interactive prompt fallback for missing/incomplete
      arguments.
- [ ] Implement client-side validation (name length/charset, ID length,
      device range), including full-command space trim and disk-name
      rtrim-only (no ltrim) prior to any checks.
- [ ] Implement the two-step destructive-action confirmation (Y/N + re-type
      disk name).
- [ ] Implement the busy indicator while awaiting the drive response.
- [ ] Wire the `N:name,id` command through `DOS_SEND_COMMAND` and print the
      drive's real status response.
- [ ] Verify in VICE: format a real (virtual) 1541 disk image end-to-end,
      confirm the resulting disk mounts cleanly with the given name/ID and
      an empty directory.
