# VOL / LABEL Command Implementation

Implement the internal shell commands `VOL` and `LABEL` for reading and writing the C64 disk directory header volume label.

## Background

On the C64, the disk directory header (track 18, sector 0 — the BAM sector) contains the 16-character disk name and 2-character disk ID. The `$` directory listing exposes this as the first line of output:

```text
0 "DISK NAME       " ID 2A
```

The existing `cmdDir` at [shell.asm:536](file:///home/morgan/development/c64/command64-os/src/command64/shell.asm#L536) already reads and displays the full directory listing (including this header line). The `fileRename` at [file.asm:378](file:///home/morgan/development/c64/command64-os/src/command64/file.asm#L378) demonstrates the command channel pattern (LFN 15, secondary 15) needed for `LABEL`.

---

## Decisions (Resolved)

- **No confirmation prompt** for `LABEL` — keep it simple, match MS-DOS behavior.
- **MS-DOS two-line output format** for `VOL` — approved as proposed.
- **Require label argument** — `LABEL` with no argument prints an error. Interactive prompt deferred to a follow-up task.
- **Disk name only** — `LABEL` does not modify the disk ID. Disk ID modification deferred to a future disk-utility.

---

## Proposed Changes

### Shell Command Table & HELP Text

#### [MODIFY] [shell.asm](file:///home/morgan/development/c64/command64-os/src/command64/shell.asm)

**Command Table** (lines 21–64):

- Add two new 8-byte entries before `tableEnd`:

  ```asm
      .text "vol   "
      .word cmdVol
      .text "label "
      .word cmdLabel
  tableEnd:
  ```

**HELP Message** (lines 1545–1579):

- Add two new lines to the `helpMsg` string block:

  ```asm
      .text "VOL    - SHOW DISK LABEL"
      .byte $0D
      .text "LABEL  - SET DISK LABEL"
      .byte $0D
  ```

---

### cmdVol — Read & Display Disk Label

#### [MODIFY] [shell.asm](file:///home/morgan/development/c64/command64-os/src/command64/shell.asm)

New routine `cmdVol` inserted before the string literals section (~line 1519, after `cmdPath` and before `cmdVer`).

**Algorithm:**

1. Open the directory channel (`$`, LFN 13, secondary 0) — same as `cmdDir`.
2. Skip 2-byte load address.
3. Skip 2-byte link pointer.
4. Skip 2-byte block count (always 0 for header line).
5. Read characters until null byte — this is the raw header line: `"DISK NAME       " ID 2A`.
6. Parse the header line:
   - The disk name is between the first and second `"` (PETSCII `$22`).
   - The disk ID follows the second `"`, after a space.
7. Print in MS-DOS style format:

   ```text
   Volume in drive X is DISK NAME
   Volume ID is AB
   ```

   Where `X` is `CurrentDevice`.
8. Close channel, return.

**Estimated size:** ~80–100 bytes of code + ~40 bytes of string data.

**Key implementation detail:** Reuses the same directory-open pattern from `cmdDir` (LFN 13, `CurrentDevice`, secondary 0). The parsing loop reads the first directory line only, extracts the quoted disk name and trailing ID, then closes the channel immediately.

---

### cmdLabel — Write New Disk Label

#### [MODIFY] [shell.asm](file:///home/morgan/development/c64/command64-os/src/command64/shell.asm)

New routine `cmdLabel` inserted adjacent to `cmdVol`.

**Algorithm:**

1. Parse the argument from `CommandBuffer` at `ParsePos` (using `shellSkipSpaces`, same as `cmdRen`, `cmdType`, etc.).
2. If no argument → print error message, return.
3. Validate label length ≤ 16 characters. If too long → print error, return.
4. Build the command channel string in `FileScratch`:

   ```text
   R0:NEW NAME=0:OLD NAME
   ```

   **Wait — this is the Rename command.** For changing the disk header name, the correct CBM DOS command is:
   - **Method: Block-Write via command channel.** The standard approach on the C64 1541 is:
     1. Open the command channel (LFN 15, secondary 15).
     2. Send: `I` (initialize disk) — ensures BAM is current.
     3. Read the BAM sector via `U1` (or `B-R`): `U1 2 0 18 0` — read track 18 sector 0 into drive buffer 2.
     4. Modify the disk name bytes at offset 144–159 ($90–$9F) in the drive buffer using `B-P` and `M-W`.
     5. Write the buffer back: `U2 2 0 18 0`.
     6. Close the command channel.

   **However**, there is a simpler and widely-used trick:
   - The CBM DOS `R` (rename) command format is `R0:NEWNAME=0:OLDNAME`.
   - This renames a file, but **it can also rename the disk header** if we use a special approach.

   **Simplest correct approach — direct Memory-Write (`M-W`):**
   1. Open command channel (LFN 15, secondary 15).
   2. Send `I` to initialize.
   3. Read current BAM into drive memory via `U1 2 0 18 0`.
   4. Use `B-P 2 144` to position the buffer pointer to the disk name offset.
   5. Write new name bytes via channel output (up to 16 chars, pad with shifted-space `$A0`).
   6. Write back with `U2 2 0 18 0`.
   7. Close channel.

   **This is the standard, safe, well-documented approach for relabeling C64 disks.**

**Implementation steps:**

1. Parse argument (new label name).
2. Open command channel: `SETLFS(15, CurrentDevice, 15)`, `SETNAM(0, ...)`, `OPEN`.
3. Send `I` command (initialize): `CHKOUT(15)`, write "I", `CLRCHN`.
4. Send `U1 2 0 18 0`: read BAM sector to drive buffer.
5. Send `B-P 2 144`: position pointer to disk name.
6. Write new name bytes (up to 16 chars) to the channel, padding with `$A0`.
7. Send `U2 2 0 18 0`: write buffer back to disk.
8. Close command channel.
9. Print confirmation or error.

**Estimated size:** ~120–150 bytes of code + ~60 bytes of string constants.

---

### String Literals

#### [MODIFY] [shell.asm](file:///home/morgan/development/c64/command64-os/src/command64/shell.asm)

New string constants added to the string literals section (after line 1611):

```asm
volDriveMsg:
    .text "Volume in drive "
    .byte 0
volIsMsg:
    .text " is "
    .byte 0
volIdMsg:
    .text "Volume ID is "
    .byte 0
labelOkMsg:
    .text "Label updated"
    .byte $0D, 0
labelLenMsg:
    .text "Label too long (max 16)"
    .byte $0D, 0
volInitCmd:
    .text "I"
    .byte 0
volReadCmd:
    .text "U1 2 0 18 0"
    .byte $0D
volWriteCmd:
    .text "U2 2 0 18 0"
    .byte $0D
volSeekCmd:
    .text "B-P 2 144"
    .byte $0D
```

---

### Task & Wiki Updates

#### [MODIFY] [vol-label.md](file:///home/morgan/development/c64/command64-os/wiki/tasks/vol-label.md)

Update sub-tasks to reflect the refined plan with measurable acceptance criteria.

#### [MODIFY] [ms-dos-comparison.md](file:///home/morgan/development/c64/command64-os/wiki/ms-dos-comparison.md)

Update the **VOL / LABEL** row status from `Missing` to `In Progress` once implementation begins.

---

## Verification Plan

### Automated Tests

No automated test framework exists yet. Verification is manual.

### Manual Verification

1. **VOL — read label from a known D64 image:**
   - Load a D64 with a known disk name (e.g., `"TEST DISK       "` ID `AB`).
   - Run `VOL`.
   - Confirm output: `Volume in drive 8 is TEST DISK` / `Volume ID is AB`.
2. **VOL — empty/fresh disk:**
   - Format a new disk image.
   - Run `VOL`, confirm default label is displayed.
3. **LABEL — set new name:**
   - Run `LABEL NEWNAME`.
   - Run `VOL` to confirm the name changed.
   - Run `DIR` to confirm the header line shows the new name.
4. **LABEL — max length (16 chars):**
   - Run `LABEL ABCDEFGHIJKLMNOP` (16 chars).
   - Confirm it succeeds and is displayed correctly.
5. **LABEL — too long (17+ chars):**
   - Run `LABEL ABCDEFGHIJKLMNOPQ`.
   - Confirm error message is shown.
6. **LABEL — no argument:**
   - Run `LABEL` with no argument.
   - Confirm error message is shown.
7. **LABEL — pad short name:**
   - Run `LABEL HI`.
   - Run `DIR` to confirm name is `"HI              "` (padded with shifted spaces).
