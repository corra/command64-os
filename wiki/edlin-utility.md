# command64 OS EDLIN Utility Manual

**File Name:** `edlin.prg`
**Target Address:** `UserProgStart` (Standard User Program Space)
**Origin:** MS-DOS 4.0 `EDLIN`, ported to COMMAND64OS

## Overview

`EDLIN` is a line-oriented text editor, ported from MS-DOS 4.00's `EDLIN`.
Unlike a cursor-addressed screen editor, every interaction is "prompt with
`*`, read a line, act on it" — no screen positioning is required, which
maps cheaply onto a 40-column shell. The edit buffer is backed by the VMM
(REU) heap rather than fixed conventional memory, so file size is not
bounded by the ~40KB of base RAM available to user programs (a REU is
required for this; see [Memory Safety](#memory-safety) below).

This port implements MS-DOS EDLIN's core line-editing model: Insert,
Delete, List, Page, edit-line, Quit, and Write, with simplified line-number
syntax. See [Deviations from MS-DOS EDLIN](#deviations-from-ms-dos-edlin)
for what was deliberately left out.

## Command Syntax

```
EDLIN <filename>
```

`<filename>` is required — running `EDLIN` with no argument prints
`USAGE: EDLIN <FILENAME>` and exits. If the named file doesn't exist,
EDLIN prints `NEW FILE.` and starts with an empty buffer (matching stock
EDLIN's `edlin newfile.txt` create-on-open behavior). A genuine device
error (drive not present/not ready) or a file too large for the available
buffer space is fatal and exits back to the shell.

Once running, EDLIN prompts with `*` and reads one line at a time. Each
line is an optional line range followed by a single command letter (or no
letter at all, to edit a line in place):

```
[line1][,line2]<command-letter>
```

### Line Number Syntax

A line token is one of:

- A decimal number (e.g. `5`).
- `.` — the current line.
- `#` — one past the last line in the buffer (computed via a full-buffer
  scan).

Spaces are allowed around numbers and the comma.

---

## Commands

| Command | Syntax | Action |
| --- | --- | --- |
| `L` | `[line1][,line2]L` | List lines. Read-only; never moves the current line. |
| `P` | `[line1][,line2]P` | Page through lines, screen at a time. Moves the current line to `line2` after display. |
| `I` | `[line]I` | Insert new lines before `line` (defaults to current line). |
| `D` | `[line1][,line2]D` | Delete lines (defaults to current line). Current line becomes `line1` afterward. |
| *(none)* | `[line]` | Edit a single line in place (no command letter). |
| `W` | `W` | Write the buffer back to the file it was opened from. |
| `Q` | `Q` | Quit, with a confirmation prompt. |

An unrecognized command letter prints `?` and returns to the `*` prompt.

### `L` — List

`[line1][,line2]L`. If `line1` is omitted, defaults to `max(1, current -
11)`. If `line2` is omitted, defaults to one screen's worth of lines from
`line1`. Does not change the current line.

### `P` — Page

`[line1][,line2]P`. If `line1` is omitted, defaults to `current + 1` (or
`1` if current is `1`). If `line2` is omitted, defaults to `line1 +
(screen height - 2)`. Unlike stock EDLIN's `PAGER`, an explicit `line2`
past the end of the buffer is rejected rather than silently clamped.
Repositions the current line to `line2` after display.

### `I` — Insert

`[line]I` (no `line2`). Prompts `N:` for each new line (where `N` is the
line number being entered) and reads text until you enter a **blank
line**, which terminates insertion and returns to the `*` prompt. This is
a deliberate simplification of stock EDLIN, which terminates insertion on
Ctrl-Z/EOF instead.

### `D` — Delete

`[line1][,line2]D`, defaulting to the current line if omitted.

### Edit-line (no command letter)

`[line]` with nothing after it edits one line: EDLIN echoes the existing
text, then reads a replacement line. Press `RETURN` on an empty line to
leave the line unchanged; typing new text replaces it. No `line2` is
accepted.

### `W` — Write

`W` takes **no arguments** — a deliberate deviation from stock EDLIN's
`WRT`/`EWRITE`, which accept a partial line count for streaming large
files in chunks. That mechanism exists because DOS EDLIN's buffer may not
hold an entire large file at once; this port's buffer is REU-backed and
always holds the whole file, so a partial write has no purpose here. `W`
streams the entire buffer to the file it was opened from, using the 1541
`@0:` save-replace convention so a failed write leaves the original file
intact.

### `Q` — Quit

Prompts `ABORT EDIT (Y/N)? `. This is simplified from stock EDLIN, which
re-prompts indefinitely until it gets a valid answer; this port accepts a
single Y/N response.

---

## Deviations from MS-DOS EDLIN

The following stock EDLIN features are intentionally **not** implemented
in this port:

- **Search/Replace (`S`/`R`)** — not yet implemented (planned; will ship
  without `^V`-style quote-character escaping for control characters).
- **Copy/Move (`C`/`M`)** — DOS EDLIN's block-move routine (`BLKMOVE`) is
  flagged in its own revision history as the historically buggiest part of
  the program; cut for this port unless there's real demand for it.
- **Transfer/merge** (inserting another file's contents at a line) — not
  core to the editing workflow, skipped.
- **`^V`-quoted control-character literals** in search patterns — depends
  on Search/Replace, which isn't implemented yet.
- **DBCS/Kanji handling** — no target-hardware relevance.
- **Dynamic screen geometry** — COMMAND64OS is always a fixed 40x25
  screen, so `List`/`Page` use a hardcoded page size instead of querying
  terminal geometry.
- **Ctrl-Break/INT 23h mid-command abort** — no KERNAL equivalent signal.

## Memory Safety

The edit buffer lives in REU-backed VMM heap space (`DOS_ALLOC_MEM`), not
base RAM, so file size isn't bounded by the ~40KB user program area. This
requires a REU to be present. Without one, there is no VMM heap and EDLIN
cannot hold a buffer larger than base RAM allows — the same ceiling stock
DOS EDLIN had in its original 64KB segment.

## Source

[src/external/edlin/edlin.s](../src/external/edlin/edlin.s),
[src/external/edlin/cmds.s](../src/external/edlin/cmds.s),
[src/external/edlin/buffer.s](../src/external/edlin/buffer.s)
