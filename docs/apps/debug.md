# DEBUG Utility User Guide

**Version:** 0.1.8 (C64 Command64 OS Port: Build 1049)
**Origin:** MS-DOS 4.0 / C64 Port
**Target Address:** $2000

## Overview

`DEBUG` is a low-level machine-language monitor, memory editor, and debugger for the `command64` OS. It provides parity with MS-DOS `DEBUG` commands, enabling interactive memory inspection, disassembly, assembly, file loading/saving, and execution control for the MOS 6502 processor.

## Command Syntax

DEBUG uses a single-character command structure. All numerical values are in **hexadecimal** (case-insensitive). Command arguments are separated by spaces or commas.

### Help & Utilities

* **`?`**: Displays a summary of all available commands.
* **`V`**: Shows the utility's version and build information.
* **`Q`**: Exits `DEBUG` and returns to the `command64` shell prompt.

### Memory Manipulation

* **`D [range]`**: **Dump** memory. Displays 128 bytes (16 rows of 8 bytes) in Hex and PETSCII.
  * *Default:* If no arguments are provided, it dumps 128 bytes starting from the last accessed address.
  * *Syntax:* `D [address]` (dumps 128 bytes starting at `address`), `D [start] [end]` (dumps inclusive range), or `D [start] L [length]` (dumps `length` bytes).
* **`E address [list]`**: **Enter** data into memory starting at `address`.
  * *Interactive:* If no list is provided, prompts with `address xx :` where `xx` is the current value, allowing you to type a new hex byte or press `[Enter]` to skip to the next address. Press `[Enter]` on an empty prompt to exit.
  * *Direct:* `E address byte1 byte2 "string"` writes hex bytes and ASCII/PETSCII strings directly.
* **`F range list`**: **Fill** a memory range with a repeating pattern or list.
  * *Syntax:* `F start end list` or `F start L length list`.
  * *Example:* `F 0400 L 03E8 20` clears the 1000-byte screen memory with spaces (hex `$20`).
* **`M range address`**: **Move** (copy) a memory block to a new destination address.
  * *Safety:* Automatically handles overlapping regions by using backward-copy logic when `destination > source`.
* **`C range address`**: **Compare** two memory blocks. Prints the addresses and values of any mismatched bytes.
* **`S range list`**: **Search** a memory range for a specific byte sequence or string. Prints the starting hex address of each match.

### Assembly & Disassembly

* **`A [address]`**: **Assemble** 6502 instructions interactively.
  * *Default:* If no address is specified, starts at the last accessed address.
  * *Behavior:* Displays the target address as a prompt (e.g. `2000:`). Enter a standard 6502 instruction. Press `[Enter]` on an empty line to exit the assembly loop.
  * *Syntax:* Case-insensitive, supports all 13 standard addressing modes (e.g., `LDA #$01`, `STA $D020,X`, `LDA ($12),Y`).
* **`U [range]`**: **Unassemble** (disassemble) memory. Translates machine code into 6502 assembly mnemonics.
  * *Default:* If no range is specified, disassembles 16 instructions starting at the last accessed address.
  * *Syntax:* `U [address]`, `U [start] [end]`, or `U [start] L [length]`.

### System Inspection & Math

* **`R [register]`**: **Register** display and modification.
  * *R (no arguments):* Displays the virtual CPU state: `A=xx X=xx Y=xx P=xx S=xx PC=xxxx`.
  * *R [reg]:* Edit a register interactively (e.g. `R A`, `R PC`). Prompts with the current value and allows entering a new hex byte (or 16-bit word for `PC`).
  * *Editable registers:* `A`, `X`, `Y`, `P`, `S` (8-bit), `PC` (16-bit).
  * *Note:* The `P` register is entered and displayed as a raw hex byte. See [Processor Status Register Bits](#processor-status-register-bits) for flag layout.
* **`H val1 val2`**: **Hex** math helper. Displays the 16-bit sum and difference of the two values.

### File & Disk I/O

* **`N [filename]`**: **Name** file. Sets the active filename for subsequent Load (`L`) and Write (`W`) commands.
  * *Syntax:* `N filename.prg` (stores up to 32 characters in the filename buffer).
  * *Readback:* `N` with no arguments displays the currently stored filename.
* **`L [type] [address]`**: **Load** the named file into memory.
  * *Type Prefix:* Optional type prefix `P` (PRG, default), `S` (SEQ), or `U` (USR).
  * *Address Override:* If no address is specified, files of type `P` load back to the 2-byte starting address header saved in the file; `SEQ`/`USR` files default to the last accessed address. If `address` is specified, the file is relocated to that address.
* **`W [type] range`**: **Write** memory range to the named file.
  * *Type Prefix:* Optional type prefix `P` (PRG, default), `S` (SEQ), or `U` (USR).
  * *Syntax:* `W [type] start end` or `W [type] start L length`.
  * *Example:* `W P 2000 207F` writes range `$2000-$207F` as a program file.

### Execution Control

* **`G [address]`**: **Go**. Executes code starting at `address` via a subroutine call (`JSR`). If no address is specified, starts at the last accessed address. Target routines must end in an `RTS` to return control to the debugger.
* **`T [address]`**: **Trace**. Single-steps exactly one instruction, restoring registers, executing, trapping via `BRK`, and printing the updated register context and next disassembled instruction.
* **`P [address]`**: **Proceed**. Steps *over* subroutine calls (`JSR`), loops, or interrupts, executing the entire subroutine/loop without stopping and breaking on the instruction immediately following it.

---

## Examples in Action

This section provides exhaustive examples demonstrating every command and syntax variation.

### 1. Help & Version Utility Commands

* **Show Command Help (`?`)**:

    ```text
    -?
    DEBUG COMMANDS:
    A [ADDR]    - ASSEMBLE
    D [RANGE]   - DUMP MEMORY
    ...
    Q           - QUIT TO SHELL
    ```

* **Show Version Info (`V`)**:

    ```text
    -V
    DEBUG v0.1.8.1027
    ```

* **Quit Utility (`Q`)**:

    ```text
    -Q
    C64:> 
    ```

### 2. Memory Dump Variations (`D`)

* **Default 128-byte Dump (`D`)** (dumps starting from `currentAddr`, advances pointer by 128):

    ```text
    -D
    0000: 00 11 22 33 44 55 66 77  .!"#$%&'
    ...
    ```

* **Dump from Address (`D address`)**:

    ```text
    -D 2000
    2000: A9 01 8D 20 D0 60 00 00  ... .`..
    ...
    ```

* **Dump Inclusive Range (`D start end`)**:

    ```text
    -D 2000 200F
    2000: A9 01 8D 20 D0 60 00 00  ... .`..
    2008: 11 22 33 44 55 66 77 88  ."3DUfww
    ```

* **Dump Explicit Length (`D start L length`)**:

    ```text
    -D 2000 L 0A
    2000: A9 01 8D 20 D0 60 00 00  ... .`..
    2008: 11 22                    ."
    ```

### 3. Memory Enter Variations (`E`)

* **Interactive Byte Editing (`E address`)** (Press `[Enter]` on empty prompt to skip or exit):

    ```text
    -E 2500
    2500: A9 : 4C     ; Overwrites value at $2500 with $4C
    2501: 20 :        ; Empty input, leaves $20 at $2501 unmodified
    2502: D0 : 08     ; Overwrites value at $2502 with $08
    2503: 60 :        ; Empty input, exits interactive mode
    ```

* **Direct List Entry (`E address byte1 byte2...`)**:

    ```text
    -E 2000 A9 01 8D 20 D0 60
    ```

* **Direct String & Byte Entry (`E address "string" bytes...`)**:

    ```text
    -E 3000 "C64 OS" 0D 00
    ```

### 4. Memory Fill Variations (`F`)

* **Fill Range with Single Byte (`F start end byte`)**:

    ```text
    -F C000 C0FF 00   ; Zero-fill memory from $C000 to $C0FF
    ```

* **Fill Range with Alternating List (`F start end byte1 byte2...`)**:

    ```text
    -F 0400 07E7 20 01 ; Fills screen memory with spaces colored white (alternating $20 $01)
    ```

* **Fill Length with Pattern (`F start L length pattern...`)**:

    ```text
    -F 1000 L 100 AA 55 ; Fills 256 bytes starting at $1000 with alternating AA 55 AA 55
    ```

### 5. Memory Move Variations (`M`)

* **Move Range to Destination (`M start end dest`)**:

    ```text
    -M 1000 1FFF 2000 ; Copies 4KB block from $1000-$1FFF to $2000-$2FFF
    ```

* **Move Length to Destination (`M start L length dest`)**:

    ```text
    -M 1000 L 0100 2000 ; Copies 256 bytes from $1000-$10FF to $2000-$20FF
    ```

* **Overlapping Move Safety**:
    If source and destination overlap (e.g. copying 16 bytes from `$1000` to `$1001`):

    ```text
    -M 1000 100F 1001
    ```

    *Note: DEBUG detects that `dest > source` and performs a backward copy from the tail end, ensuring that bytes are not overwritten before they are copied.*

### 6. Memory Compare Variations (`C`)

* **Compare Range to Address (`C start end dest`)**:

    ```text
    -C 1000 1007 2000
    ```

    If mismatched, outputs differences in format `[addr1] [val1] [val2] [addr2]`:

    ```text
    1002 A9 8D 2002   ; Mismatch at offset $02: source has $A9, dest has $8D
    1005 60 RTS 2005  ; Mismatch at offset $05: source has $60, dest has $FF
    ```

    *If blocks are identical, returns immediately with no output.*
* **Compare Length to Address (`C start L length dest`)**:

    ```text
    -C 1000 L 10 3000 ; Compares 16 bytes starting at $1000 with the 16 bytes at $3000
    ```

### 7. Memory Search Variations (`S`)

* **Search Range for Byte Pattern (`S start end bytes`)**:

    ```text
    -S 1000 2000 A9 00 8D
    10A4              ; Found sequence starting at $10A4
    1F82              ; Found sequence starting at $1F82
    ```

* **Search Length for String (`S start L length "string"`)**:

    ```text
    -S 1000 L 1000 "KERNAL"
    13C0              ; Found string "KERNAL" starting at $13C0
    ```

### 8. Inline Assembler Variations (`A`)

* **Assemble at Last Accessed Address (`A`)**:

    ```text
    -A
    1000: LDA #$01
    1002: RTS
    1003: 
    ```

* **Assemble at Specific Address (`A address`)** (Pressing `[Enter]` on empty prompt exits):

    ```text
    -A 2000
    2000: LDX #$00       ; Immediate Mode (without '$' prefix is decimal/hex-deduced)
    2002: LDA $12,X      ; Zero Page,X Indexed
    2004: STA $D020,X    ; Absolute,X Indexed
    2007: JMP ($1234)    ; Indirect
    200A: BNE $2002      ; Relative Branch (automatically calculates relative offset)
    200C: RTS            ; Implied Mode
    200D: 
    ```

### 9. Unassembler / Disassembler Variations (`U`)

* **Unassemble Default Count (`U`)** (disassembles 16 instructions starting from last accessed address):

    ```text
    -U
    1000  A9 01      LDA #$01
    1002  E8         INX
    ...
    ```

* **Unassemble from Address (`U address`)**:

    ```text
    -U 2000
    2000  A2 00      LDX #$00
    2002  B5 12      LDA $12,X
    ...
    ```

* **Unassemble Inclusive Range (`U start end`)**:

    ```text
    -U 2000 2007
    2000  A2 00      LDX #$00
    2002  B5 12      LDA $12,X
    2004  9D 20 D0   STA $D020,X
    2007  6C 34 12   JMP ($1234)
    ```

* **Unassemble Explicit Length (`U start L length`)**:

    ```text
    -U 2000 L 04
    2000  A2 00      LDX #$00
    2002  B5 12      LDA $12,X
    ```

### 10. Register View & Modification Variations (`R`)

* **Display Registers (`R`)**:

    ```text
    -R
    A=00 X=12 Y=FF P=30 S=FD PC=2000
    ```

* **Edit 8-bit Register (`R reg`)**:

    ```text
    -R A
    A 00
    : 85              ; Set Accumulator to $85
    ```

* **Edit 16-bit Program Counter (`R PC`)**:

    ```text
    -R PC
    PC 2000
    : C000            ; Set Program Counter to $C000
    ```

### 11. Hexadecimal Arithmetic (`H`)

* **Hex Math (`H val1 val2`)** (prints 16-bit sum and difference):

    ```text
    -H 1000 0050
    1050 0FB0         ; Sum is $1050, Difference is $0FB0
    ```

* **Hex Math with Underflow/Overflow Wrap**:

    ```text
    -H FFFF 0001
    0000 FFFE         ; FFFF + 1 = 0000 (wrap), FFFF - 1 = FFFE
    ```

### 12. Filename Configuration (`N`)

* **Read Current Filename (`N`)**:

    ```text
    -N
    MYAPP.PRG         ; Displays active filename (or returns immediately if empty)
    ```

* **Set New Filename (`N filename`)**:

    ```text
    -N NEWDATA.SEQ
    ```

### 13. File Load Variations (`L`)

* **Load Default Program (`L`)** (reads filename from name buffer, loads to header address):

    ```text
    -N MYAPP.PRG
    -L
    ```

* **Load Relocated Program (`L address`)** (ignores the file's starting address header, relocates to `address`):

    ```text
    -N MYAPP.PRG
    -L 4000           ; Loads MYAPP.PRG starting at $4000
    ```

* **Load Sequential File (`L S address`)** (uses byte-by-byte file stream loading):

    ```text
    -N TEST.SEQ
    -L S 5000         ; Loads sequential stream to $5000
    ```

* **Load User File (`L U address`)**:

    ```text
    -N USER.USR
    -L U 6000         ; Loads user stream to $6000
    ```

### 14. File Write Variations (`W`)

* **Write Range as Default Program (`W start end`)** (prepends the 2-byte header with `start` address):

    ```text
    -N OUT.PRG
    -W 2000 207F      ; Saves range $2000-$207F into OUT.PRG
    ```

* **Write Range Explicitly (`W type start end`)**:

    ```text
    -N OUT.SEQ
    -W S 4000 40FF    ; Saves range $4000-$40FF into OUT.SEQ as a Sequential file
    ```

* **Write Length Syntax (`W [type] start L length`)**:

    ```text
    -N OUT.USR
    -W U 5000 L 80    ; Saves 128 bytes starting at $5000 into OUT.USR as a User file
    ```

### 15. Execution Control Variations (`G`, `T`, `P`)

* **Go at Default PC (`G`)** (executes starting at last accessed memory address):

    ```text
    -G
    ```

* **Go at Specific Address (`G address`)**:

    ```text
    -G C000           ; Subroutine executes and returns to DEBUG prompt on RTS
    ```

* **Trace One Step (`T`)** (executes instruction at current `PC`, displays next instruction):

    ```text
    -T
    A=01 X=12 Y=FF P=30 S=FD PC=2002
    2002  E8         INX
    ```

* **Trace One Step from Address (`T address`)**:

    ```text
    -T 2000           ; Sets virtual PC to $2000 and single-steps
    A=01 X=12 Y=FF P=30 S=FD PC=2002
    2002  E8         INX
    ```

* **Proceed Step-Over (`P`)** (steps over subroutines, loops, and interrupts):

    ```text
    -U 2000 L 03
    2000  20 00 C0   JSR $C000   ; Subroutine call
    2003  E8         INX
    -R PC
    PC 2000
    : 2000
    -P                ; Step OVER the JSR call
    A=10 X=12 Y=FF P=30 S=FD PC=2003
    2003  E8         INX
    ```

* **Proceed from Address (`P address`)**:

    ```text
    -P 2000           ; Set virtual PC to $2000 and step-over
    ```

---

## Processor Status Register Bits

The `P` register (Processor Status) is a single byte displayed and edited as a hexadecimal value by the `R` command. Each bit is a CPU status flag. The layout for the MOS 6510 is:

```text
Bit:  7   6   5   4   3   2   1   0
Flag: N   V   1   B   D   I   Z   C
```

| Bit | Flag | Name | Description |
| :-: | :--: | :--- | :--- |
| 7 | **N** | Negative | Set if the result of the last operation had bit 7 set (was negative in signed arithmetic). |
| 6 | **V** | Overflow | Set if a signed arithmetic operation produced a result out of the –128 to +127 range. |
| 5 | **—** | *(Always 1)* | This bit is always read as `1`. Writing `0` has no effect. |
| 4 | **B** | Break | Set when a `BRK` instruction caused the last interrupt. Clear for hardware `IRQ`. Only meaningful when read off the stack after an interrupt. |
| 3 | **D** | Decimal | When set, `ADC` and `SBC` operate in BCD (Binary Coded Decimal) mode. The C64 KERNAL clears this on entry. |
| 2 | **I** | Interrupt Disable | When set, maskable `IRQ` interrupts are ignored. Does not affect `NMI` or `BRK`. |
| 1 | **Z** | Zero | Set if the result of the last operation was zero. |
| 0 | **C** | Carry | Set by arithmetic operations on overflow out of bit 7, or by compare/rotate instructions. |

### Common P Values

| Hex | Binary | Meaning |
| :-: | :----- | :------ |
| `$30` | `0011 0000` | Power-on default. B and reserved bit set, all flags clear. |
| `$32` | `0011 0010` | B set, Zero flag set (result was zero). |
| `$31` | `0011 0001` | B set, Carry flag set. |
| `$B0` | `1011 0000` | Negative, B set (result was negative). |
| `$F0` | `1111 0000` | Negative, Overflow, B, Decimal all set. |

> **Tip:** To force the `N` flag before a trace, set `P` to `$B0`. To force `Z`, set `P` to `$32`.

---

## Error Messages

DEBUG reports errors with a brief message followed by a return to the `-` prompt. No error codes are used; all messages are descriptive English.

| Message | Command | Cause |
| :------ | :------ | :---- |
| `syntax error` | Any | Unrecognized command character, or argument format is invalid (e.g. non-hex digit in an address). |
| `bad address` | `D`, `E`, `F`, `M`, `C`, `S`, `G`, `T`, `P`, `U`, `W` | Start address is greater than end address, or a required address argument is missing. |
| `bad range` | `F`, `M`, `C`, `S`, `W` | The specified range or length is zero or malformed. |
| `file not found` | `L` | The filename stored by `N` does not exist on the active drive. |
| `disk error xx` | `L`, `W` | The C64 drive returned error code `xx` from the command channel (e.g. `62` = file not found, `63` = file exists). |
| `no filename` | `L`, `W` | A `L` or `W` was issued without first setting a filename with `N`. |
| `error: cannot trace target in ROM` | `T`, `P` | The decoded next-instruction target falls entirely within ROM (`$A000–$BFFF` or `$D000–$FFFF`), so no software breakpoint can be written. |
| `unknown register` | `R` | The register name provided is not one of `A`, `X`, `Y`, `P`, `S`, or `PC`. |
| `value out of range` | `R` | A 16-bit entry was expected but a value larger than `$FFFF` was entered, or a byte entry received a value larger than `$FF`. |

---

## MS-DOS Parity & Platform Notes

This section documents intentional deviations from MS-DOS `DEBUG` (v4.0) and summarizes which commands are architecture-specific or have adapted behavior on the 6502/C64 platform.

### Register Name Mapping

MS-DOS `DEBUG` targets the 8086/8088 and uses 16-bit segment/offset register names that have no 6502 equivalent. The mapping below shows the closest C64 `DEBUG` analogues:

| MS-DOS Register | MS-DOS Meaning | C64 DEBUG Equivalent | Notes |
| :--- | :--- | :--- | :--- |
| `AX` | Accumulator (16-bit) | `A` | 8-bit only on 6502. |
| `BX`, `CX`, `DX` | General purpose | — | No equivalent; 6502 is accumulator-based. |
| `SI`, `DI` | Index registers | `X`, `Y` | 8-bit only. |
| `IP` | Instruction Pointer | `PC` | 16-bit; same role. |
| `F` | Flags register | `P` | Bit layout differs; see [Processor Status Register Bits](#processor-status-register-bits). |
| `SP` | Stack Pointer | `S` | 8-bit page-1 offset on 6502 (stack is fixed at `$0100–$01FF`). |
| `CS`, `DS`, `ES`, `SS` | Segment registers | — | No memory segmentation on 6502; addressing is flat 16-bit. |

### Address Argument Syntax

MS-DOS `DEBUG` requires an `=` prefix for the entry address in `G`, `T`, and `P` to distinguish it from breakpoint addresses:

```text
MS-DOS:  G =C000 2000   (run from $C000, break at $2000)
C64:     G C000         (no = prefix; breakpoints not yet supported)
```

C64 `DEBUG` omits the `=` prefix. The entry address is always the first bare hex argument.

### Commands Not Applicable to 6502/C64

| MS-DOS Command | Reason Not Implemented |
| :---: | :--- |
| **`I port`** | MS-DOS input-from-port instruction. The 6502 has no `IN` opcode; all I/O is memory-mapped. Use `D` or `E` on the relevant SID/VIC/CIA address instead. |
| **`O port byte`** | MS-DOS output-to-port instruction. Same reason as `I`; write to the memory-mapped register directly. |
| **`XA`**, **`XD`**, **`XM`**, **`XS`** | EMS (Expanded Memory Specification) commands. Not applicable; C64 extended memory (REU) is managed by the OS VMM, not DEBUG. |

### Behavioral Differences from MS-DOS DEBUG

| Feature | MS-DOS DEBUG | C64 DEBUG |
| :--- | :--- | :--- |
| **`R F` flag display** | Shows symbolic flag names: `OV DN EI NG ZR AC PE CY` / `NV UP DI PL NZ NA PO NC`. Allows toggling individual flags by name. | `P` is shown and edited as a raw hex byte. Symbolic flag display is not implemented. |
| **`G` breakpoints** | `G [=address] [bp1 bp2 ...]` accepts up to 10 software breakpoint addresses. | `G [address]` accepts only the entry address. Inline breakpoints are not yet supported. |
| **`T count`** | `T [=address] [count]` traces up to `count` instructions in one command. | `T [address]` always executes exactly one instruction. Repeat count is not supported. |
| **`P count`** | `P [=address] [count]` proceeds over up to `count` instructions. | `P [address]` always proceeds over a single instruction or subroutine call. |
| **Error format** | `^ Error` with a caret pointing to the offending character. | Full English message on its own line; no caret position indicator. |
| **Numeric output radix** | Always hexadecimal; prefix `0x` not used. | Same — all values are hexadecimal, no prefix. |
| **`D` row width** | 16 bytes per row. | 8 bytes per row (optimized for the 40-column C64 display). |
| **PETSCII character column** | ASCII character column beside hex bytes. | PETSCII character column beside hex bytes (printable PETSCII `$20–$7E`). |

---

## UI Behavior & Quirks

* **Prompt:** `-`
* **Line Editing:** Supports the **INST/DEL** key for destructive backspace.
* **Case Normalization:** Normalizes all letters (shifted or unshifted) to unshifted lowercase command characters and unshifted uppercase hex digits/mnemonics.
* **ROM Safeguards:** The `T` and `P` commands cannot set breakpoints in ROM (`$A000-$BFFF`, `$D000-$FFFF`). Attempting to step into ROM will automatically step over subroutine calls (`JSR`) or report an error to prevent the monitor from locking up.
