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

### APPS / PS

**Description:** Lists currently loaded/registered programs, showing each one's name, load address, and size.
**Syntax:** `APPS` or `PS`

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

### DEL / ERASE

**Description:** Deletes a file from the disk.
**Syntax:** `DEL [filename]` or `ERASE [filename]`

### REN / RENAME

**Description:** Renames an existing file on the disk.
**Syntax:** `REN [oldname] [newname]`

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

### DRIVE / DEVICE / DEV

**Description:** Switches the active device or displays the current one.
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

**Supported Commands:** `DIR`, `TYPE`, `MORE`, `COPY`, `DEL`/`ERASE`, `REN`/`RENAME`, `VOL`, `LABEL`, and `FLUSH`.

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

---

<a name="technical-limits"></a>

## 8. Technical Specifications & Limits

### Memory Map

- **$0801:** OS Entry Point (BASIC Launcher).
- **$1000:** OS Service Bus (External API Hook).
- **$1180 - $1900:** Command Shell and built-in handlers.
- **User Program Space (`UserProgStart` - $CFFF):** currently `$3400` (expanded by banking out BASIC ROM). `UserProgStart` has grown over successive OS releases as resident segments expand — always compile external utilities against the current build's constant rather than a hardcoded address. Relocatable binaries (see the Programmer's Reference) can run at any address regardless of their compile-time origin.
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
