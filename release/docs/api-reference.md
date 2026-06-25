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
- **Output:** 
    - `A`: File Handle (0-7).
    - `Carry`: 0 (Success).
- **Error:** `Carry` = 1, `A` = $FF.

### DOS_CLOSE_FILE ($3E)
Closes an open file handle.
- **Input:** `A`: File Handle.
- **Output:** `Carry`: 0.
- **Error:** `Carry` = 1.

### DOS_READ_FILE ($3F)
Reads bytes from an open file handle.
- **Input:** 
    - `A`: File Handle.
    - `X/Y`: Pointer to destination buffer (Lo/Hi).
    - `HexValLo/Hi` ($66-$67): Number of bytes to read.
- **Output:**
    - `HexValLo/Hi`: Number of bytes actually read.
    - `Carry`: 0.
- **Error:** `Carry` = 1.

### DOS_WRITE_FILE ($40)
Writes bytes to an open file handle.
- **Input:** 
    - `A`: File Handle.
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

### DOS_EXIT ($4C)
Terminates the program and returns to the command64 shell.
- **Input:** None.
- **Action:** Does not return to the caller.
