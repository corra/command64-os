# DEBUG Utility User Guide

**Version:** 0.1.4 (Build 1015)
**Origin:** MS-DOS 4.0
**Target Address:** $2200 (shifted from $2000 in Phase 6A)

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

## Examples

Here are some common scenarios for using the DEBUG utility:

### 1. Inspecting Memory
To view 128 bytes of memory starting at the standard OS entry point (`$1000`):
`-D 1000`

To view exactly 32 bytes (hex `$20`) starting at `$0C00` using the length parameter:
`-D 0C00 L 20`

To view a specific range from `$0400` to `$04FF`:
`-D 0400 04FF`

### 2. Entering Data and Text
To write a machine code instruction (`RTS`, which is `$60`) at address `$2500`:
`-E 2500 60`

To enter a mixed sequence of text and hex bytes (e.g., a "HELLO" string followed by a null terminator `$00`) at `$3000`:
`-E 3000 "HELLO" 00`

### 3. Filling Memory (e.g., Clearing Screen Memory)
The C64's default screen memory starts at `$0400` and is 1000 bytes long (hex `$03E8`). To fill it with space characters (PETSCII `$20`):
`-F 0400 L 03E8 20`

To fill a smaller range with an alternating pattern (e.g., `$AA` and `$55`):
`-F 1000 10FF AA 55`

### 4. Searching for Strings or Bytes
To search for the string "DOS" anywhere between `$1000` and `$1FFF`:
`-S 1000 1FFF "DOS"`

To search for a specific byte sequence (e.g., `A9 00 8D` which is `LDA #$00, STA ...`):
`-S 1000 L 1000 A9 00 8D`

### 5. Moving (Copying) Memory
To copy 256 bytes (hex `$0100`) from `$1000` to `$2000`:
`-M 1000 L 0100 2000`

### 6. Executing Code
To execute a subroutine located at `$C000`:
`-G C000`
*(Note: Ensure the routine at the target address ends with an `RTS` instruction to return control safely to DEBUG).*

### 7. Hex Arithmetic
To calculate the sum and difference of `$A500` and `$0250`:
`-H A500 0250`
*(Output will be `A750 A2B0`, representing the sum and difference respectively).*

## UI Behavior
- **Prompt:** `-`
- **Line Editing:** Supports the **INST/DEL** key for destructive backspace.
- **Display:** Optimized for the C64's 40-column screen (8-byte rows with grouping separators).
