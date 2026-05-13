# DEBUG Utility User Guide

**Version:** 0.1.2 (Build 1010)
**Origin:** MS-DOS 4.0
**Target Address:** $2000

## Overview
`DEBUG` is a low-level memory editor, monitor, and debugger for the `command64` OS. It allows direct manipulation of C64 memory, execution of code, and hexadecimal arithmetic.

## Command Syntax
DEBUG uses a single-character command structure. All numerical values are in **hexadecimal**.

### Help
- **`?`**: Displays a summary of all available commands.

### Memory Manipulation
- **`D [range]`**: **Dump** memory. Displays 128 bytes (16 rows of 8) in Hex and PETSCII.
  - *Range Syntax:* `START END` (e.g., `D 1000 1020`) or `START L LENGTH` (e.g., `D 1000 L 40`).
- **`E address [list]`**: **Enter** data into memory starting at `address`.
  - *List:* Can be hex bytes or quoted strings (e.g., `E 1000 "HELLO" 00`).
- **`F range list`**: **Fill** a memory range with a repeating pattern.
  - Example: `F 1000 L 100 AA BB` (fills with alternating AA BB).
- **`M range address`**: **Move** (copy) a memory block to a new destination.
  - *Safety:* Automatically handles overlapping regions by switching to backward-copy logic when `dest > src`.
- **`C range address`**: **Compare** two memory blocks. Reports addresses and values that do not match.
- **`S range list`**: **Search** a memory range for a specific byte sequence or string.

### System Inspection
- **`R`**: **Register** display. Shows the captured state of `A`, `X`, `Y`, `P` (status), and `S` (stack pointer).
- **`H val1 val2`**: **Hex** math. Displays the 16-bit sum and difference of two hex values.

### Execution & Control
- **`G [address]`**: **Go**. Executes code starting at the specified address via a `JSR`. If no address is provided, it uses the last accessed address.
- **`V`**: **Version**. Shows the utility's version and build information.
- **`Q`**: **Quit**. Exits `DEBUG` and returns to the `command64` shell prompt.

## UI Behavior
- **Prompt:** `-`
- **Line Editing:** Supports the **INST/DEL** key for destructive backspace.
- **Display:** Optimized for the C64's 40-column screen (8-byte rows with grouping separators).
