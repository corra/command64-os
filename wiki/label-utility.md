# command64 OS LABEL Utility Manual

**File Name:** `label.prg`
**Target Address:** `$2200` (Standard User Program Space)

## Overview

`LABEL` is an external disk management utility that allows you to change the volume name of a floppy disk without erasing its contents.

Standard Commodore DOS only permits setting a disk name when formatting a disk (using the `NEW` command), which destroys all existing files. `LABEL` bypasses the standard file system using CBM DOS Direct Access Commands, editing the BAM sector directly on Track 18, Sector 0.

## Command Syntax

```bash
LABEL [new-label]
```

### Parameters

* **`[new-label]`**: The new name for the disk. It can be up to 16 characters long.
  * If the label contains spaces, ensure they are typed directly.
  * Names shorter than 16 characters are automatically padded with PETSCII shifted space characters (`$A0`), which is the Commodore standard for directory headers.
  * Attempting to set a label longer than 16 characters will return an error without modifying the disk.

*(Note: Running `LABEL` with no arguments is reserved for a future interactive prompt mode. Currently, it displays an error).*

---

## Direct Access Protocol (How it Works)

Under the hood, `LABEL` operates directly on the disk controller of the active drive:

1. **Initialize Command Channel:** Opens logical file 15 to the drive's command channel.
2. **Drive Reset:** Sends the Initialize (`I`) command to clear any previous error states.
3. **Open Data Channel:** Opens logical file 2 configured as a raw data channel (`#`) to request a free drive memory buffer.
4. **Block Read (U1):** Instructs the drive to read Track 18, Sector 0 (the directory header/BAM block) into the allocated drive buffer.
5. **Seek Offset (B-P):** Moves the drive buffer pointer to offset **144** (the start of the 16-character diskette name).
6. **Modify Buffer:** Writes the 16 bytes of the new label (including `$A0` padding) directly into the drive buffer.
7. **Block Write (U2):** Instructs the drive to write the modified buffer back to Track 18, Sector 0 on the physical diskette.
8. **Flush BAM Cache:** Sends a second Initialize (`I`) command to the drive command channel. This forces the drive to re-read Track 18, Sector 0 into its internal memory, synchronizing its directory header RAM cache immediately.
9. **Clean Up:** Closes both the data and command channels.

---

## Practical Examples

### 1. Renaming the Disk

To rename the disk currently in Drive 8 to "GAMES 2026":
`LABEL GAMES 2026`
*Output:* `Label updated`

To verify the change took effect immediately:
`VOL`
*Output:*

```text
Volume in drive 8 is GAMES 2026
Volume ID is 2A
```

### 2. Error Handling

* **Write Protected Disk:** If you attempt to rename a write-protected floppy disk:
  `LABEL NEWNAME`
  *Output:* `26, WRITE PROTECT ON, 00, 00`
* **Label Too Long:**
  `LABEL THISLABELISEXCEEDINGSIXTEEN`
  *Output:* `Label too long (max 16)`
* **Device Not Present:** If the active device is switched to an empty drive number:
  `LABEL TEST`
  *Output:* `Device not present`
