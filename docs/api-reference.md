# command64 OS API Reference

The command64 operating system provides services to external programs via a stable jump table entry point.

## Stable Entry Point: **`$1000`**

External programs MUST use **`JSR $1000`** to access OS services.

### Calling Convention (6502)

- **Input:**
  - `A`: Function Number
  - `X`: Argument 1 (Low byte)
  - `Y`: Argument 2 (High byte)
- **Output:**
  - `Carry Flag`: 0 = Success, 1 = Error
  - `A, X, Y`: Return values as defined by the function.

---

## Function List

### DOS_PRINT_CHAR ($02)

Prints a single PETSCII character to the screen.

- **Input:** `X` = Character to print.
- **Output:** `Carry` = 0.

### DOS_PRINT_STR ($09)

Prints a null-terminated PETSCII string to the screen.

- **Input:** `X/Y` = Pointer to string (Lo/Hi).
- **Output:** `Carry` = 0.

### DOS_OPEN_FILE ($3D)

Opens a file on disk (CurrentDevice).

- **Input:**
  - `X/Y`: Pointer to null-terminated filename (Lo/Hi).
  - `HexValLo` ($66): Access Mode (0 = Read, 1 = Write).
  - `HexValHi` ($67): File Type for Write Mode (optional, e.g., 'S', 'P', 'U', 'R'). Omitted or invalid values default to 'S' (SEQ).
- **Output:**
  - **A**: File Handle (0-7).
  - `Carry`: 0 (Success).
- **Error:** `Carry` = 1, `A` = $FF.

### DOS_CLOSE_FILE ($3E)

Closes an open file handle.

- **Input:** `FileHandle` ($6D): File Handle.
- **Output:** `Carry`: 0.
- **Error:** `Carry` = 1.

### DOS_READ_FILE ($3F)

Reads bytes from an open file handle.

- **Input:**
  - `FileHandle` ($6D): File Handle.
  - `X/Y`: Pointer to destination buffer (Lo/Hi).
  - `HexValLo/Hi` ($66-$67): Number of bytes to read.
- **Output:**
  - `HexValLo/Hi`: Number of bytes actually read.
  - `Carry`: 0.
- **Error:** `Carry` = 1.

### DOS_WRITE_FILE ($40)

Writes bytes to an open file handle.

- **Input:**
  - `FileHandle` ($6D): File Handle.
  - `X/Y`: Pointer to source buffer (Lo/Hi).
  - `HexValLo/Hi` ($66-$67): Number of bytes to write.
- **Output:**
  - `HexValLo/Hi`: Number of bytes actually written.
  - `Carry`: 0.
- **Error:** `Carry` = 1.

### DOS_DELETE_FILE ($41)

Deletes a file from disk.

- **Input:** `X/Y` = Pointer to null-terminated filename (Lo/Hi).
- **Output:** `Carry` = 0.
- **Error:** `Carry` = 1.

### DOS_RENAME_FILE ($56)

Renames a file on disk.

- **Input:**
  - `X/Y`: Pointer to old filename (Lo/Hi).
  - `PrintPtrLo/Hi` ($FB-$FC): Pointer to new filename (Lo/Hi).
- **Output:** `Carry` = 0.
- **Error:** `Carry` = 1.

### DOS_PARSE_PREFIX ($57)

Parses an optional `<dev>:` device prefix off the front of a zero-page
pointer's target string (e.g. `9:FILENAME`), resolving it to a device
number without modifying the underlying string. Used internally by
`fileOpen`/`fileDelete`/`fileRename` and available to callers that need the
same prefix convention (see `DOS_SEND_COMMAND`).

- **Input:** `X` = zero-page offset of the pointer to the string to parse
  (not an X/Y pointer pair like most other calls — `X` alone is the ZP
  address holding the Lo/Hi pointer).
- **Output:**
  - `A` = resolved device number (8-11), or `CurrentDevice` if no prefix
    was present.
  - `Carry` = 1 if a prefix was found and parsed, 0 if absent. **Note:**
    this is inverted relative to every other `DOS_*` function, where
    `Carry` = 0 means success — `Carry` here only reports whether a prefix
    existed, not whether the call succeeded (it cannot fail).

### DOS_SEND_COMMAND ($58)

Sends an arbitrary command-channel string to a drive unmodified (no
`,<type>,W` wrapping like `DOS_OPEN_FILE` does) and returns the drive's
actual response text. Generalizes the open-SA15/write/read-result pattern
`DOS_DELETE_FILE`/`DOS_RENAME_FILE` use internally, for callers (e.g.
`format`'s `N:name,id`) that need the raw drive response.

- **Input:**
  - `X/Y`: Pointer to null-terminated command string (Lo/Hi), optionally
    prefixed with `<dev>:` per the `DOS_PARSE_PREFIX` convention (defaults
    to the current device if absent).
  - `PrintPtrLo/Hi` ($FB-$FC): Pointer to caller-supplied output buffer
    (at least 40 bytes).
- **Output:** Caller's buffer = null-terminated drive response string;
  `Carry` = 0.
- **Error:** `Carry` = 1. Transport-level failure only (IEC/OPEN/CHKIN) —
  a drive-reported error in the response text still returns `Carry` = 0.

### DOS_ALLOC_MEM ($48)

Allocates memory in the REU.

- **Input:** `X/Y` = Requested paragraphs (16-byte units).
- **Output:**
  - `X` = Starting Page Index (SegHi).
  - `Y` = Starting Bank (VmmBank).
  - `Carry` = 0.
- **Error:** `Carry` = 1.

### DOS_FREE_MEM ($49)

Frees previously allocated REU memory.

- **Input:**
  - `X` = Page Index (SegHi).
  - `Y` = Bank (VmmBank).
- **Output:** `Carry` = 0.
- **Error:** `Carry` = 1.

### DOS_VMM_READ ($59)

Reads a caller-specified byte range out of a previously `DOS_ALLOC_MEM`'d
REU segment into C64 RAM, in a single REU DMA burst. `DOS_ALLOC_MEM`/
`DOS_FREE_MEM` alone give no way to actually move data into/out of
allocated REU memory — this and `DOS_VMM_WRITE` are the primitives that
close that gap. Reuses the same `VmmSegLo/Hi`/`VmmOffLo/Hi`/`VmmBank` ZP
convention the kernel's internal `vmmReadByte` uses, but transfers the
whole requested range in one DMA call rather than one byte at a time.

- **Input:**
  - `VmmSegLo/Hi`, `VmmOffLo/Hi`, `VmmBank` ($68-$6C): Source Seg:Off:Bank.
  - `X/Y`: Destination C64 buffer pointer (Lo/Hi).
  - `HexValLo/Hi` ($66-$67): Byte count.
- **Output:** Destination buffer filled; `Carry` = 0.
- **Error:** `Carry` = 1 (REU/VMM not initialized).

### DOS_VMM_WRITE ($5A)

Writes a caller-specified byte range from C64 RAM into a previously
`DOS_ALLOC_MEM`'d REU segment, in a single REU DMA burst. See
`DOS_VMM_READ` above for rationale.

- **Input:**
  - `VmmSegLo/Hi`, `VmmOffLo/Hi`, `VmmBank` ($68-$6C): Destination Seg:Off:Bank.
  - `X/Y`: Source C64 buffer pointer (Lo/Hi).
  - `HexValLo/Hi` ($66-$67): Byte count.
- **Output:** `Carry` = 0.
- **Error:** `Carry` = 1 (REU/VMM not initialized).

### DOS_RELEASE_L15 ($5B)

Closes KERNAL logical file 15 (the command channel) and clears the OS's
persistent-open cache for it (`ensureL15Open`/`L15Device` in `file.asm`).
This releases a channel left open by an earlier OS disk operation before a
program claims LFN 15 directly, and prevents a stale cache after that program
closes the channel itself. Call it before directly opening LFN 15 and again
after finishing direct use.

- **Input:** None.
- **Output:** `Carry` = 0 (always succeeds).
- **Behavior:** Calls `KernalCLOSE` for LFN 15, then sets `L15Device` to the
  closed sentinel (`0`).
- **Note:** Safe to call even if LFN 15 was never open or was already closed;
  closing an unopened KERNAL logical file is a harmless no-op.

### DOS_GET_SYSTEM_INFO ($5C)

Populates a caller-supplied 24-byte buffer with current system metrics, including OS version, video mode, user RAM boundaries, VMM page counts, active application counts, and device numbers.

- **Input:**
  - `X/Y`: Pointer to caller-supplied 24-byte buffer (Lo/Hi).
- **Output:**
  - `Carry` = 0: Success, `A` = `$00` (`DOS_ERR_OK`), buffer populated.
  - `Carry` = 1: Failure, `A` = `$04` (`DOS_ERR_INVALID_ARG`), buffer unchanged.
- **Record Structure (24 Bytes):**
  - Offset 0: `StructVersion` (1 byte = `$01`)
  - Offset 1: `StructSize` (1 byte = `24`)
  - Offset 2: `OsMajor` (1 byte = `4`)
  - Offset 3: `OsMinor` (1 byte = `0`)
  - Offset 4: `OsStage` (1 byte = `0` Release)
  - Offset 5: `CurrentDevice` (1 byte)
  - Offset 6: `VideoStandard` (1 byte: `0`=NTSC, `1`=PAL)
  - Offsets 7-8: `UserProgStart` (2 bytes, little-endian = `$0800`)
  - Offsets 9-10: `UserProgEnd` (2 bytes, little-endian = `$BFFF`)
  - Offset 11: `VmmFlags` (1 byte bitmask: bit 0 = VMM Active)
  - Offsets 12-13: `VmmPageSize` (2 bytes, little-endian = `4096`)
  - Offsets 14-15: `VmmTotalPages` (2 bytes, little-endian = `4096`)
  - Offsets 16-17: `VmmAllocPages` (2 bytes, little-endian)
  - Offsets 18-19: `VmmFreePages` (2 bytes, little-endian)
  - Offset 20: `AppMaxSlots` (1 byte = `16`)
  - Offset 21: `AppUsedSlots` (1 byte count of active slots)
  - Offsets 22-23: `Reserved` (2 bytes = `$0000`)

### DOS_EXIT ($4C)

Termates the program and returns to the command64 shell.

- **Input:** None.
- **Action:** Does not return to the caller.
