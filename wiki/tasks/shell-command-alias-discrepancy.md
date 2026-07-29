# Shell HELP Advertises Commands That Cannot Dispatch

Status: [ ]
Type: Bug
Taskwarrior: 36
Found: 2026-07-28 (OS build 2658), during a documentation audit.

## Summary

The shell's `HELP` output lists `RENAME`, `ERASE`, and `APPS` as usable
commands, but none of them exist in the dispatch table. Typing any of them
falls through to the external-program search and fails with
`Bad command or file name`.

## Root Cause

`cmdCompare` (`src/command64/shell.asm:367`) matches the typed token against
fixed-width, space-padded `TABLE_NAME_LEN` (6) byte names in `tableCmd`
(`src/command64/shell.asm:25`), character for character. There is no prefix
matching and no separate alias mechanism — **a name only dispatches if it is
its own `tableCmd` entry.**

`tableCmd` contains: `exit`, `cls`, `echo`, `load`, `dir`, `ver`, `help`,
`type`, `more`, `copy`, `del`, `ren`, `drive`, `dev`, `run`, `set`, `vol`,
`path`, `ps`, `free`, `flush`, `date`, `time`.

`helpMsg` (`src/command64/shell.asm:3118`) advertises three names absent from
that list:

| HELP line | Reality |
| --- | --- |
| `RENAME - ALIAS FOR REN` | not in `tableCmd`; only `ren` dispatches |
| `ERASE  - ALIAS FOR DEL` | not in `tableCmd`; only `del` dispatches |
| `APPS   - LIST LOADED APPS` | not in `tableCmd`; only `ps` dispatches |
| `PS     - ALIAS FOR APPS` | correct command, but described as an alias of a name that does not exist |

`HELP` is also incomplete in the other direction: `DEV` (a genuine alias for
`DRIVE`, present in `tableCmd`) and `FLUSH` are never listed.

## Decision

**Remove the phantom aliases from `HELP` rather than adding them to
`tableCmd`.** `HELP` becomes an accurate description of what the shell
actually accepts, and no table space is consumed by aliases nobody asked for.

## Scope

- `src/command64/shell.asm` `helpMsg` text only. No change to `tableCmd`,
  `cmdCompare`, or any command handler.

## Subtasks

- [ ] Remove the `RENAME - ALIAS FOR REN` line from `helpMsg`.
- [ ] Remove the `ERASE  - ALIAS FOR DEL` line from `helpMsg`.
- [ ] Replace the `APPS   - LIST LOADED APPS` and `PS     - ALIAS FOR APPS`
      pair with a single `PS     - LIST LOADED APPS` line.
- [ ] Add the missing `FLUSH` entry to `helpMsg`.
- [ ] Note `DEV` as the alias on the `DRIVE` line.
- [ ] Confirm `helpMsg` still fits its segment and the OS builds with zero
      warnings and errors.
- [ ] Remove the "does not dispatch" notes from `wiki/user-manual.md`
      (`PS`, `DEL`, `REN`, `DRIVE / DEV` sections) once HELP is accurate, and
      re-sync `docs/`.
- [ ] Remove the "Known Discrepancies" section from `brain/COMMANDS.md`.
- [ ] Add a `CHANGELOG.md` entry under `[Unreleased]` / `### Fixed`.
- [ ] Verify in VICE per `.agents/workflows/vice-mcp-testing.md`.
- [ ] Obtain user confirmation before marking this task complete.

## Manual Verification

1. Boot Command64 OS in VICE and confirm the `Command 64-DOS Version` banner.
2. Run `HELP`. Confirm `RENAME`, `ERASE`, and `APPS` no longer appear, that
   `PS` is described as listing loaded apps, and that `FLUSH` and the `DEV`
   alias are shown.
3. Confirm every name printed by `HELP` dispatches — in particular `PS`,
   `FLUSH`, `DEV`, `REN`, and `DEL` return their own output, not
   `Bad command or file name`.
4. Confirm the removed names now fail cleanly: `RENAME`, `ERASE`, and `APPS`
   each report `Bad command or file name` and return to the `c64[<device>]:>`
   prompt.

## Related

- `brain/COMMANDS.md` — internal command registry and dispatch notes.
- `wiki/user-manual.md` — currently carries temporary notes describing this
  discrepancy for users.
