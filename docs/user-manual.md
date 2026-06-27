# command64 User Manual

Welcome to the **command64** User Manual. command64 is an MS-DOS style operating system port for the Commodore 64, designed to provide a familiar command-line environment and a robust set of system services.

---

## Table of Contents
1.  [Hardware Requirements](#hardware-requirements)
2.  [Getting Started](#getting-started)
3.  [The Command Shell](#the-command-shell)
4.  [Internal Command Reference](#internal-command-reference)
5.  [Multi-Device Navigation](#multi-device-navigation)
6.  [Environment Variables](#environment-variables)
7.  [External Utilities](#external-utilities)
8.  [Technical Specifications & Limits](#technical-limits)
9.  [Troubleshooting](#troubleshooting)

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
1.  Insert the command64 disk into your primary drive (usually Device 8).
2.  Load the OS: `LOAD "COMMAND64",8`
3.  Run the OS: `RUN`

Upon success, you will see the command64 banner and the prompt:
`C64:> `

---

<a name="the-command-shell"></a>
## 3. The Command Shell

The command64 shell is the primary interface for the OS.
- **Case Insensitivity:** You can type commands in lowercase or uppercase. `DIR`, `dir`, and `Dir` are all valid.
- **Line Editing:** Use the **INST/DEL** key to correct typing errors.
- **Prompt:** The prompt displays the current environment. (Standard is `C64:> `).

---

<a name="internal-command-reference"></a>
## 4. Internal Command Reference

### CLS
**Description:** Clears the screen and resets the cursor to the top-left.
**Syntax:** `CLS`

### DIR
**Description:** Lists the files on the currently active disk.
**Syntax:** `DIR`

### TYPE
**Description:** Displays the contents of a sequential or program file to the screen.
**Syntax:** `TYPE [filename]`
**Example:** `TYPE README`

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
- `DRIVE` — Displays the currently active device.

### Target Device Routing
**Description:** Temporarily redirects a single disk operation to a specific drive (8, 9, 10, or 11) using the drive number followed by a colon (`:`).
This routing applies only to the duration of that specific command, leaving the active device (set by `DRIVE`) unchanged.

**Supported Commands:** `DIR`, `TYPE`, `COPY`, `DEL`/`ERASE`, `REN`/`RENAME`, `VOL`, and `LABEL`.

**Examples:**
- `DIR 9:` — Lists the directory of the disk in device 9.
- `VOL 9:` — Displays the volume label of the disk in device 9.
- `TYPE 9:README` — Displays the file `README` from device 9.
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
**Description:** Loads a program from disk into memory without running it.
**Syntax:** `LOAD [filename] [address]`
**Example:** `LOAD MYPROG 4000` (Loads `MYPROG` to address `$4000`).

### RUN / GO
**Description:** Executes a program already resident in memory.
**Syntax:** `RUN [address]` or `GO [address]`
**Default:** If no address is provided, it defaults to `$2000` (Standard User Program Space).

---

<a name="technical-limits"></a>
## 8. Technical Specifications & Limits

### Memory Map
- **$0801:** OS Entry Point (BASIC Launcher).
- **$1000:** OS Service Bus (External API Hook).
- **$1180 - $1900:** Command Shell and built-in handlers.
- **$2000 - $9FFF:** **User Program Space.** Most external utilities should be compiled for `$2000`.
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
- Ensure the program was compiled for the address you are running it from. Most programs are designed for `$2000`. Running a program from a non-native address will cause a crash unless it is specifically designed to be position-independent.
