# command64 User Manual

Welcome to the **command64** User Manual. command64 is an MS-DOS style operating system port for the Commodore 64, designed to provide a familiar command-line environment and a robust set of system services.

---

## Table of Contents

1. [Hardware Requirements](#hardware-requirements)
2. [Getting Started](#getting-started)
3. [The Command Shell](#the-command-shell)
4. [Internal Command Reference](#internal-command-reference)
5. [Multi-Device Navigation](#multi-device-navigation)
6. [Environment Variables](#environment-variables)
7. [External Utilities](#external-utilities)
8. [Technical Specifications & Limits](#technical-limits)
9. [Troubleshooting](#troubleshooting)

---

<a name="hardware-requirements"></a>

## 1. Hardware Requirements

To run command64 effectively, you will need:

- **Commodore 64** or **Commodore 128** (in C64 mode).
- **RAM Expansion Unit (REU):** A minimum of 512KB is recommended. command64 uses the REU for its Virtual Memory Manager (VMM) and environment storage.
- **Disk Drive:** 1541, 1571, 1581, or SD2IEC compatible device.
- **Display:** Standard 40-column monitor or TV.

---

<a name="getting-started"></a>

## 2. Getting Started

### Booting the OS

1. Insert the command64 disk into your primary drive (usually Device 8).
2. Load the OS: `LOAD "COMMAND64",8`
3. Run the OS: `RUN`

Upon success, you will see the command64 banner and the prompt:
`C64:>`

---

<a name="the-command-shell"></a>

## 3. The Command Shell

The command64 shell is the primary interface for the OS.

- **Case Insensitivity:** You can type commands in lowercase or uppercase. `DIR`, `dir`, and `Dir` are all valid.
- **Line Editing:** Use the **INST/DEL** key to correct typing errors.
- **Prompt:** The prompt displays the current environment. (Standard is `C64:>`).

---

<a name="internal-command-reference"></a>

## 4. Internal Command Reference

### CLS

**Description:** Clears the screen and resets the cursor to the top-left.
**Syntax:** `CLS`

### DIR

**Description:** Lists the files on the currently active disk, including each file's size in bytes.
**Syntax:** `DIR`
**Example output:** `"MYPROG" (2032 bytes)`

### PS

**Description:** Lists currently loaded/registered programs, showing each one's name, load address, and size.
**Syntax:** `PS`

> **Note:** the built-in `HELP` text advertises `APPS` with `PS` as its alias,
> but only `PS` is present in the shell's command table and dispatches. Typing
> `APPS` falls through to the external-program search and fails.

### FREE

**Description:** Deregisters a loaded program, freeing its App Table slot so its memory can be reused by a future `LOAD`. With no name given, deregisters every loaded program that isn't currently running.
**Syntax:** `FREE [name]`
**Examples:** `FREE MYPROG` (frees just `MYPROG`), `FREE` (frees everything loaded).

### ECHO

**Description:** Echoes the typed text back to the screen.
**Syntax:** `ECHO [text]`
**Example:** `ECHO HELLO WORLD`

### TYPE

**Description:** Displays the contents of a sequential or program file to the screen. Line-feed bytes (`$0A`) are displayed as CR/LF newlines.
**Syntax:** `TYPE [filename]`
**Example:** `TYPE README`

### MORE

**Description:** Displays the contents of a sequential or program file one screen at a time. When the screen fills, `MORE` displays `-- More --` and waits for a key before continuing.
**Syntax:** `MORE [filename]`
**Example:** `MORE README`

### COPY

**Description:** Copies a file from one name/device to another.
**Syntax:** `COPY [source] [destination]`
**Example:** `COPY FILE1 FILE2`

### DEL

**Description:** Deletes a file from the disk.
**Syntax:** `DEL [filename]`

> **Note:** `HELP` advertises `ERASE` as an alias for `DEL`, but `ERASE` is not
> in the shell's command table and does not dispatch.

### REN

**Description:** Renames an existing file on the disk.
**Syntax:** `REN [oldname] [newname]`

> **Note:** `HELP` advertises `RENAME` as an alias for `REN`, but `RENAME` is
> not in the shell's command table and does not dispatch.

### VER

**Description:** Displays the current OS version and build number.
**Syntax:** `VER`

### VOL

**Description:** Displays the disk volume label and ID of the active drive.
**Syntax:** `VOL`

### DATE

**Description:** Displays or sets the system date. Phase 1 stores the date in resident kernel RAM and resets to `1980-01-01` on cold boot or `RUN`; hardware RTC persistence is planned for a later phase. Date rollover is detected when `DATE` or `TIME` is queried.
**Syntax:** `DATE [YYYY-MM-DD]`
**Examples:** `DATE` (display current date and prompt for a new one), `DATE 2026-07-12` (set directly).

### TIME

**Description:** Displays or sets the system time using the CIA #1 Time-of-Day clock. Time is shown and entered in 24-hour format.
**Syntax:** `TIME [HH:MM:SS]`
**Examples:** `TIME` (display current time and prompt for a new one), `TIME 15:30:00` (set directly).

### HELP

**Description:** Displays a list of available internal commands and brief descriptions.
**Syntax:** `HELP`

### EXIT

**Description:** Terminates the OS and returns control to C64 BASIC.
**Syntax:** `EXIT`

---

<a name="multi-device-navigation"></a>

## 5. Multi-Device Navigation

command64 supports up to four disk devices simultaneously (8, 9, 10, and 11).

### DRIVE / DEV

**Description:** Switches the active device or displays the current one.
`DEV` is a true alias — both names are present in the shell's command table.
`DEVICE` is **not** a recognized command.
**Syntax:** `DRIVE [number]`
**Examples:**

- `DRIVE 9` — Switches all future operations (DIR, LOAD, etc.) to device 9.
- `9:` — Shortcut equivalent to `DRIVE 9` to permanently switch to device 9.
- `DRIVE` — Displays the currently active device.

### FLUSH

**Description:** Manually reads and clears a drive's command/error channel (LFN 15) and prints its current status string. Most commands already drain this channel themselves right after an error, so `FLUSH` is mainly a diagnostic escape hatch — e.g. to inspect or clear a stale status if it's ever suspected of blocking an otherwise-healthy command.
**Syntax:** `FLUSH [device:]`
**Examples:**

- `FLUSH` — Reads and clears the error channel of the active device.
- `FLUSH 9:` — Reads and clears the error channel of device 9 without changing the active device.

### Target Device Routing

**Description:** Temporarily redirects a single disk operation to a specific drive (8, 9, 10, or 11) using the drive number followed by a colon (`:`).
This routing applies only to the duration of that specific command, leaving the active device (set by `DRIVE`) unchanged.

**Supported Commands:** `DIR`, `TYPE`, `MORE`, `COPY`, `DEL`, `REN`, `VOL`, `LABEL`, and `FLUSH`.

**Examples:**

- `DIR 9:` — Lists the directory of the disk in device 9.
- `VOL 9:` — Displays the volume label of the disk in device 9.
- `TYPE 9:README` — Displays the file `README` from device 9.
- `MORE 9:README` — Displays the file `README` from device 9 one screen at a time.
- `LABEL 9:NEWLABEL` — Sets the volume label of device 9 to `NEWLABEL`.
- `DEL 9:OLDDATA` — Deletes `OLDDATA` on device 9.
- `REN 9:OLD NEW` — Renames `OLD` to `NEW` on device 9.
- `COPY 9:FILE1 8:FILE2` — Copies `FILE1` from device 9 to device 8 as `FILE2`.
- `COPY FILE 9:FILE` — Copies `FILE` from the active drive (e.g., 8) to device 9.
- `COPY 9:FILE FILE` — Copies `FILE` from device 9 to the active drive.

---

<a name="environment-variables"></a>

## 6. Environment Variables

command64 supports persistent environment variables stored in the REU.

### SET

**Description:** Displays all currently set environment variables.
**Syntax:** `SET`
*(Note: SET VAR=VAL support is planned for a future build).*

### PATH

**Description:** Displays the current executable search path.
**Syntax:** `PATH`

---

<a name="external-utilities"></a>

## 7. External Utilities

External utilities are programs (typically `.PRG` files) that reside on disk and are loaded into memory when needed.

### Running a Utility

If you type a command that the shell doesn't recognize as internal, it automatically searches the disk for a matching filename and attempts to run it.
**Example:** Typing `DEBUG` will load and run `DEBUG.PRG`.

### LOAD

**Description:** Loads a program from disk into memory without running it. Before any data is transferred, the OS validates that the destination memory range doesn't collide with protected system memory or another loaded program, rejecting the load with `protected address` or `address overlap` if it would. If no address is given, the OS automatically picks the first free memory region large enough for the file (reporting `out of memory` if none fits). On success, it prints the program's name, load address, and size.
**Syntax:** `LOAD [filename] [address]`
**Example:** `LOAD MYPROG 4000` (Loads `MYPROG` to address `$4000`). `LOAD MYPROG` (Loads `MYPROG` at an automatically chosen free address).

### RUN / GO

**Description:** Executes a program by name or address. With no argument, it runs whatever program is currently loaded at the base of User Program Space.
**Syntax:** `RUN [name|address]` or `GO [name|address]`

### COMP

**Description:** Compares two files as raw byte streams. Differences are reported as hex byte offsets and byte values. Version 1 rejects options and compares file bytes exactly as stored, including PRG load-address bytes.
**Syntax:** `COMP file1 file2`
**Example:** `COMP OLD.PRG NEW.PRG`

### LABEL

**Description:** Sets a new volume label (up to 16 characters) on the disk in the active drive.
**Syntax:** `LABEL [new-label]`
**Example:** `LABEL NEWDISK`

### FORMAT

**Description:** Low-level-formats a floppy disk by sending the drive's
native `N:` (New) command over its command channel; the drive firmware
performs the actual format. **This destroys all data on the target disk.**
FORMAT guards the operation behind a two-step confirmation: a `(Y/N)`
prompt naming the target device, then a re-typed disk name that must match
exactly before the format is sent. Any mismatch cancels with `FORMAT
CANCELLED.` and touches nothing.
**Syntax:** `FORMAT <dev>:<name>,<id>`
**Example:** `FORMAT 8:MYDISK,01`

Arguments can be given on the command line or left out; FORMAT prompts
interactively for device (8-11), name (1-16 characters, no `,` or `:`), and
ID (exactly 2 characters) in turn, reprompting on invalid input. If a
CLI argument is present but fails validation, FORMAT reports the specific
error and stops rather than falling back to interactive prompts.

### CONWAY

**Description:** A 40×24 toroidal Life-like cellular automaton with nine presets, custom Birth/Survival rules, and a five-digit generation counter. CONWAY opens on a menu; preset 1 is classic B3/S23 Life.
**Syntax:** `CONWAY`

**Controls (during simulation):**

| Key | Action |
| --- | --- |
| `SPACE` | Pause / resume |
| `R` | Re-randomize grid |
| `C` | Clear grid, reset the counter, and pause |
| `Q` | Return to the CONWAY menu |
| RUN/STOP | Quit and return to shell |

While paused, the status word `pause` is cyan; it returns to green when the
simulation resumes. The menu accepts `1`–`9` for presets, `B` or `S` followed
by `0`–`8` for custom rule toggles, RETURN to run the retained field, `R` to
randomize and run, and `Q` or RUN/STOP to exit.

### PACMAN

**Description:** Pac64 — an in-progress character-grid Pac-Man clone with a
centered 28×24 maze and a status row. Pac-Man movement and Phase 3.1 Blinky
scatter/chase behavior are active. The other ghosts and frightened/eaten,
fruit, and tunnel systems are planned. Contact with Blinky costs one life,
resets the maze and actors while lives remain, and stops play at zero lives.
**Syntax:** `PACMAN`

**Controls (during play):**

| Key | Action |
| --- | --- |
| `W`/`A`/`S`/`D` | Move up / left / down / right (buffered) |
| `P` or `SPACE` | Pause / resume |
| `Q` | Quit and return to shell |

### CASM

**Description:** A native 6502/6510 assembler that runs *on the C64
itself* — write source with `EDLIN`, assemble it with `CASM`, then
`LOAD`/`RUN` the resulting PRG, all without leaving the shell. CASM reads
its whole source file, assembles it, and on success prints `INPUT
VALIDATED` and writes a runnable PRG to disk. On any error it prints one
specific diagnostic, deletes the partial output, and returns to the shell.
`.INCLUDE` is supported for splitting source across multiple files.
**Syntax:** `CASM <source> [/O:<output>] [/S] [/M] [/L]`
**Example:** `CASM GAME.CSM` (writes `GAME.PRG`). `CASM GAME.CSM
/O:OUT.PRG` (explicit output name).

- **`/O:<output>`**: explicit output filename. Without it, the output name
  is derived from `<source>` by replacing its extension with `.PRG`.
- **`/S`**: static output at a fixed address (requires an explicit `.ORG`
  in the source). Without it, CASM's default is **relocatable** output
  that runs correctly at whatever address the OS loads it.
- **`/M`** and **`/L`**: print a deterministic symbol map and write a
  `.LST` source listing alongside the PRG, respectively. Both may be
  combined with each other or used alone.

CASM's language also supports named constants, the current-address symbol
`*`, parenthesized expressions, a full arithmetic/bitwise operator set,
and character/string literals — see the full manual for the complete
grammar.

See the **[CASM Utility Manual](casm-utility.md)** for the full language
reference (addressing modes, directives, expressions, and limits).

### DASH

**Description:** A three-page system dashboard — System information, a
live Applications registry, and a VMM/REU hardware self-test. It ships
as a relocatable PRG assembled by the *native* CASM assembler itself
(not any host tool), so it runs correctly wherever the OS loads it.
**Syntax:** `LOAD DASH` then `RUN`

Once running, function keys switch pages (**F1** System, **F3**
Applications, **F5** VMM Test); **R** redraws the current page, **T**
runs the VMM hardware test (VMM Test page only), and **Q** exits cleanly
back to the shell.

See the **[DASH Utility Manual](dash-utility.md)** for the full page
reference and explicit-relocation examples.

### EDLIN

**Description:** A line-oriented text editor ported from MS-DOS 4.00's
`EDLIN` — the tool for writing CASM source or any other text file
directly on the C64. Every interaction is "prompt with `*`, read a line,
act on it," so no screen positioning is required. The edit buffer lives in
the VMM (REU) heap, so file size isn't bounded by the ~40KB of base RAM
available to user programs (a REU is required).
**Syntax:** `EDLIN <filename>`

Running `EDLIN` with no argument prints usage and exits. If the named file
doesn't exist, EDLIN prints `NEW FILE.` and starts with an empty buffer.
Once running, EDLIN prompts with `*` and reads one line at a time: an
optional line range followed by a single command letter for Insert,
Delete, List, Page, edit-line, Quit, or Write.

See the **[EDLIN Utility Manual](edlin-utility.md)** for the full command
reference and deviations from MS-DOS EDLIN.

### DEBUG

**Description:** A low-level machine-language monitor, memory editor, and
debugger with parity to MS-DOS `DEBUG` commands — interactive memory
inspection, disassembly, assembly, file loading/saving, and 6502 execution
control.
**Syntax:** `DEBUG`

Once running, DEBUG uses single-character commands with hexadecimal
arguments: `D` (dump memory), `E` (enter data), `F` (fill), `M` (move),
`C` (compare), `S` (search), `A` (assemble), `?` (help), `V` (version),
and `Q` (quit back to the shell).

See the **[DEBUG Utility Manual](debug-utility.md)** for the complete
command reference.

### BANNER

**Description:** Renders a text message in large 5×6 block characters built from
the `#` character (`$23`). Output wraps after 6 characters per block line to fit
the 40-column screen. BANNER ships on the OS disk as **source only**
(`BANNER.S`) — assembling it with `CASM` is the intended first thing to try:

```text
CASM BANNER.S
BANNER HELLO
```

**Syntax:** `BANNER <text>`
**Example:** `BANNER HELLO`

Running `BANNER` with no text — or with `/?`, `-?`, `/H`, or `-H` — prints the
usage banner instead of rendering.

**Text handling:**

- Lowercase letters are folded to uppercase; `A`–`Z`, `0`–`9`, and the
  punctuation `! ? . , - + = : ; / \ * ( ) #` have glyphs. Any other character
  renders as a blank glyph.
- Messages are capped at 120 characters; anything beyond that is discarded.
- Spaces at the start of a block line are skipped, so wrapped lines stay
  left-aligned and a trailing run of spaces does not emit an empty final line.
- A blank line separates consecutive block lines.

See the **[BANNER Utility Manual](banner-utility.md)** for the full glyph table
and worked examples.

---

<a name="technical-limits"></a>

## 8. Technical Specifications & Limits

### Memory Map

- **$0801:** OS Entry Point (BASIC Launcher).
- **$1000:** OS Service Bus (External API Hook).
- **$1180 - $1900:** Command Shell and built-in handlers.
- **User Program Space (`UserProgStart` - $CFFF):** currently `$3800` (expanded by banking out BASIC ROM). `UserProgStart` has grown over successive OS releases as resident segments expand — always compile external utilities against the current build's constant rather than a hardcoded address. Relocatable binaries (see the Programmer's Reference) can run at any address regardless of their compile-time origin; CASM continues to emit relocatable output at `$3400` by default.
- **$C000:** VMM Memory Control Table (REU Management).

### VMM Capacity

- command64 supports up to **16MB of REU memory**.
- Memory is managed in **4KB pages**.

### File Limitations

- Filenames follow C64 standards (up to 16 characters recommended).
- The OS normalizes filenames to unshifted PETSCII for compatibility.

---

<a name="troubleshooting"></a>

## 9. Troubleshooting

### "Bad command or file name"

- The command you typed is not built-in, and no matching file was found on the current disk. Use `DIR` to check available files.

### "Invalid device"

- You attempted to switch to a device number outside the supported range (8-11).

### "Warning: No REU detected"

- command64 could not find a RAM Expansion Unit. VMM-dependent features (like environment variables and high-memory allocation) will be disabled.

### Program Crashes after `RUN`

- Ensure the program was compiled for the address you are running it from (the current `UserProgStart`, by default). Running a program from a non-native address will cause a crash unless it was built as a relocatable binary (see the Programmer's Reference).
