# DEBUG Utility User Guide

**Version:** 0.4.0 (C64 Command64 OS Port: Build 1101)
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

---

## MS-DOS Parity Status

The Command 64 OS `DEBUG` utility targets functional parity with MS-DOS `DEBUG` v4.0, adapted for the MOS 6502/6510 processor. The table below reflects the current implementation status.

| Command | Status | Notes |
| :---: | :---: | :--- |
| **`A`** | **Implemented** | Interactive 6502 assembler. All 13 addressing modes; auto branch-offset calculation. |
| **`C`** | **Implemented** | Memory compare; reports mismatched addresses and values. |
| **`D`** | **Implemented** | Memory dump (8-byte rows with PETSCII column). |
| **`E`** | **Implemented** | Enter memory — interactive byte editing or direct hex/string list. |
| **`F`** | **Implemented** | Fill memory range with a repeating byte pattern. |
| **`G`** | **Implemented** | Go (execute subroutine via JSR; returns to DEBUG on RTS). Inline breakpoints not yet supported (MS-DOS `G =addr bp1 bp2...`). |
| **`H`** | **Implemented** | Hex arithmetic — 16-bit sum and difference. |
| **`I`** | **N/A** | MS-DOS port-input opcode. 6502 has no `IN` instruction; all I/O is memory-mapped. |
| **`L`** | **Implemented** | Load named file from disk; supports PRG header address or explicit relocation address. |
| **`M`** | **Implemented** | Move (copy) memory block; overlap-safe backward-copy logic. |
| **`N`** | **Implemented** | Set/read active filename for `L` and `W` operations. |
| **`O`** | **N/A** | MS-DOS port-output opcode. Same reason as `I`. |
| **`P`** | *Planned (Phase 3)* | Proceed — step over subroutines/loops via software `BRK` breakpoints. |
| **`Q`** | **Implemented** | Quit to shell. |
| **`R`** | **Implemented** | Display and interactively edit registers `A`, `X`, `Y`, `P`, `S` (8-bit) and `PC` (16-bit). |
| **`S`** | **Implemented** | Search memory range for byte sequence or string. |
| **`T`** | *Planned (Phase 3)* | Trace — single-step via software `BRK` breakpoints. |
| **`U`** | **Implemented** | Unassemble (disassemble 6502 machine code). |
| **`V`** | **Implemented** | Show version — C64 extension, no MS-DOS equivalent. |
| **`W`** | **Implemented** | Write memory range to named file; supports PRG/SEQ/USR type prefixes. |
| **`XA`/`XD`/`XM`/`XS`** | **N/A** | MS-DOS EMS (Expanded Memory) commands. C64 extended memory (REU) is managed by the OS VMM, not DEBUG. |

### Key Deviations from MS-DOS DEBUG

| Feature | MS-DOS | C64 DEBUG |
| :--- | :--- | :--- |
| **`D` row width** | 16 bytes | 8 bytes (fits 40-column display) |
| **Address prefix** | `G =C000` (equals sign before entry address) | `G C000` (no equals sign) |
| **`R F` flag display** | Symbolic flag names (`NV UP DI PL NZ NA PO NC`) with individual toggle | `P` shown/edited as a raw hex byte; see flag table in [full docs](../docs/apps/debug.md) |
| **`T`/`P` count** | `T 5` traces 5 instructions | Single instruction only; count not supported |
| **`G` breakpoints** | Up to 10 inline breakpoint addresses | Not yet supported |
| **`I`/`O`** | x86 port I/O | Not implemented; use `D`/`E` on memory-mapped I/O addresses |
