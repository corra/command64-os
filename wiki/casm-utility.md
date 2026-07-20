# command64 OS CASM Utility Manual

**File Name:** `casm.prg`
**Version:** `0.1.15.1053`
**Target Address:** `UserProgStart` (currently `$3400`, Standard User Program Space)
**Toolchain:** ca65/ld65 (see [CASM Programmer's Reference](casm-programmers-reference.md) for internals)

## Overview

`CASM` is a native 6502/6510 assembler that runs *on the C64 itself* — you
write source on the machine (with `EDLIN`, for example), assemble it with
`CASM`, and `LOAD`/`RUN` the resulting PRG, all without leaving the shell.

> **CASM is under active development (Phase 4).** Everything documented
> below as "supported" is real and has been verified end-to-end against the
> shipped build. Features not yet implemented are called out explicitly in
> [Not Yet Supported](#not-yet-supported) rather than silently omitted —
> assume anything not mentioned here doesn't work yet.

## Command Syntax

```text
CASM <source> [/O:<output>] [/S] [/M] [/L]
```

### Parameters

- **`<source>`** (required): the file to assemble. Exactly one source file
  is accepted; a second bare filename is an error.
- **`/O:<output>`** (optional): explicit output filename, up to 63
  characters. Without it, the output name is derived from `<source>`: its
  extension (the part after the last `.` that comes after any device-prefix
  `:`) is replaced with `.PRG`, or `.PRG` is appended if it has none. For
  example, `CASM GAME.CSM` writes `GAME.PRG`; `CASM 9:UTIL` writes
  `9:UTIL.PRG`.
- **`/S`**: static output. Currently accepted but has no additional effect
  — CASM always writes a PRG by default once assembly succeeds.
- **`/M`** and **`/L`**: map file and listing file. **Not yet implemented.**
  CASM recognizes these switches but exits immediately with `FEATURE NOT
  IMPLEMENTED` if either is present — don't use them yet.

Options may appear before or after the source filename, in any order, and
are matched case-insensitively (`/o:out.prg` works the same as `/O:OUT.PRG`).

### What Happens

1. CASM opens `<source>` for reading. If it can't be opened, you get
   `CASM: CANNOT OPEN INPUT` and nothing else happens.
2. It assembles the whole file in one pass, creating the output file as
   soon as parsing starts.
3. On success, it prints `CASM: INPUT VALIDATED` and returns to the shell.
   The output PRG is on disk and ready to `LOAD`.
4. On any error, it prints one specific diagnostic (see
   [Example 3: Error Messages](#example-3-error-messages)), deletes the
   partial output file if one was created, and returns to the shell — no
   half-written PRG is left behind.

## Language Reference

### Statements

One statement per line: an optional leading whitespace, then either a
directive (`.ORG`, `.BYTE`, `.WORD`), a mnemonic and its operand, or nothing
(a blank line is valid). A semicolon starts a comment that runs to end of
line:

```asm
    LDA #$01        ; load the value
```

**Labels and symbols are not yet supported.** Every address and offset in
your source must currently be written as a literal number — see
[casmhello.seq](#example-2-a-complete-runnable-program) below for what that
looks like in practice.

### Numeric Literals

| Format | Example | Notes |
| --- | --- | --- |
| Decimal | `10`, `65535` | No prefix |
| Hexadecimal | `$FF`, `$1234` | `$` prefix, at least one hex digit required |
| Binary | `%10101010` | `%` prefix, at least one `0`/`1` required |

All three accept up to a 16-bit value (0-65535); anything larger is
`CASM: OPERAND OUT OF RANGE`, even if later digits would have brought it
back in range (e.g. `$1FFFF` is rejected the moment it exceeds 65535, not
after the whole token is read).

### Addressing Modes

Every documented 6502 addressing mode that the target mnemonic supports is
available. This single program exercises one instruction in each mode —
it's a real, build-verified fixture (`casmwp11.seq`) used in CASM's own test
suite:

```asm
INX                 ; implied
LDA #10              ; immediate, decimal
LDA #$FF             ; immediate, hex
LDX #%10101010        ; immediate, binary
LDA $10              ; zero page (absolute promotes automatically — see below)
STA $0400,X           ; absolute,X
STA $0500,Y           ; absolute,Y
ASL A                ; accumulator
LDA ($10),Y           ; indirect indexed  -- (zp),Y
LDA ($10,X)           ; indexed indirect  -- (zp,X)
JMP ($1234)           ; indirect
```

You never have to choose zero-page vs. absolute yourself: write the operand
as a plain number, and CASM picks zero page automatically whenever the
value fits in a byte and the mnemonic supports it in that mode, falling
back to absolute otherwise. `LDA $10` assembles as zero-page `LDA` (2
bytes); `LDA $1000` assembles as absolute `LDA` (3 bytes) — same source
syntax either way.

Branch mnemonics (`BCC`, `BCS`, `BEQ`, `BMI`, `BNE`, `BPL`, `BVC`, `BVS`)
take a plain 16-bit target address, not a signed offset — CASM computes the
relative displacement for you and rejects the instruction with `CASM:
BRANCH OUT OF RANGE` if the target is more than 127 bytes behind or 128
bytes ahead of the next instruction.

### Directives

| Directive | Syntax | Effect |
| --- | --- | --- |
| `.ORG` | `.ORG $C000` | Sets the assembly address. Required exactly once, before any instruction or `.BYTE`/`.WORD`; a second `.ORG` is an error. |
| `.BYTE` | `.BYTE $01, $02, $FF` | Emits one or more comma-separated byte values (each must fit 8 bits) at the current address. |
| `.WORD` | `.WORD $1234, $ABCD` | Emits one or more comma-separated 16-bit values, little-endian, at the current address. |

`.STATIC`, `.RELOC`, and `.INCLUDE` are recognized by name but not yet
implemented — using one exits with `CASM: FEATURE NOT IMPLEMENTED`.

## Practical Examples

### Example 1: A Minimal Valid Program

```asm
.ORG $C000
LDA #$01
STA $D020
LDX #$10
INX
BNE $C007
RTS
.BYTE $01, $02, $FF
.WORD $1234, $ABCD
```

Assemble it:

```text
CASM DEMO.CSM
```

*Output:* `CASM: INPUT VALIDATED`. This produces a 20-byte PRG loading at
`$C000`:

```text
00 C0                      ; PRG header (load address $C000)
A9 01                      ; LDA #$01
8D 20 D0                   ; STA $D020
A2 10                      ; LDX #$10
E8                         ; INX
D0 FD                      ; BNE $C007   (displacement -3, branches to itself minus one)
60                         ; RTS
01 02 FF                   ; .BYTE $01,$02,$FF
34 12 CD AB                ; .WORD $1234,$ABCD
```

### Example 2: A Complete, Runnable Program

Because labels aren't implemented yet, a runnable program has to spell out
every address by hand — including the OS service-bus entry point (`$1000`)
and its own message's load address. Here's `CASMHELLO.CSM`, one of CASM's
own verified test fixtures. It prints a message via `DOS_PRINT_STR` and
exits cleanly via `DOS_EXIT`:

```asm
.ORG $3400
LDX #$0E
LDY #$34
LDA #$09
JSR $1000
LDA #$4C
JSR $1000
.BYTE $59, $45, $53, $20, $49, $54, $20
.BYTE $42, $55, $49, $4C, $44, $53, $21, $20
.BYTE $2D, $2D, $20, $43, $41, $53, $4D
.BYTE $0D, $00
```

Walking through it: the program loads at `$3400` (`UserProgStart`), so its
message text starts at `$340E` (14 bytes after the load address — 2 bytes
of `LDX`/`LDY` opcode+operand, twice, plus `LDA`/`JSR` pairs). The `LDX
#$0E` / `LDY #$34` pair loads that address into X/Y, `LDA #$09` selects
`DOS_PRINT_STR` and `JSR $1000` calls the OS service bus (see
[api-reference.md](api-reference.md)) to print it; `LDA #$4C`/`JSR $1000`
then calls `DOS_EXIT`. The `.BYTE` lines spell out `"YES IT BUILDS! --
CASM"` followed by a carriage return and a null terminator.

To try it:

```text
CASM CASMHELLO.CSM
LOAD CASMHELLO
GO 3400
```

(`LOAD CASMHELLO` loads the assembled PRG at its header-specified address —
`$3400` — and registers it in the App Table; `GO 3400` then looks it up by
address and runs it. `GO` with no argument would also work here, since
`$3400` is `UserProgStart`, the default `GO` searches when given nothing.)

*Output:* `YES IT BUILDS! -- CASM`, then a clean return to the shell.

### Example 3: Error Messages

CASM stops at the first error and reports a specific diagnostic rather than
a generic failure. A few representative cases (see the [Programmer's
Reference diagnostic table](casm-programmers-reference.md#13-diagnostic-reference)
for the complete list of all 36 codes):

| Source | Result |
| --- | --- |
| `LDA #` *(no value)* | `CASM: SYNTAX ERROR` |
| `STA $0400,` *(no register after comma)* | `CASM: SYNTAX ERROR` |
| `LDA ($10,Y)` *(indexed-indirect requires X)* | `CASM: SYNTAX ERROR` |
| `LDA #10 20` *(trailing token after a complete operand)* | `CASM: EXPECTED NEWLINE` |
| `LDA #70000` *(exceeds 16 bits)* | `CASM: OPERAND OUT OF RANGE` |
| `LDA A` *(accumulator mode on an instruction that has none)* | `CASM: INVALID ADDRESSING MODE` |
| `INX #5` *(immediate mode on an implied-only instruction)* | `CASM: INVALID ADDRESSING MODE` |
| `LDA #$1234` *(immediate operand exceeds 8 bits)* | `CASM: OPERAND OUT OF RANGE` |
| Any code before the first `.ORG` | `CASM: ORG REQUIRED` |
| A second `.ORG` | `CASM: DUPLICATE ORG` |
| `.ORG $C000` / `BNE $D000` *(target far out of branch range)* | `CASM: BRANCH OUT OF RANGE` |
| A word CASM doesn't recognize where a statement should start | `CASM: SYNTAX ERROR` |

## Not Yet Supported

These will produce a specific error rather than silently doing the wrong
thing — see the [Programmer's Reference §12](casm-programmers-reference.md#12-coverage-what-works-today)
for status and rationale:

- **Labels and symbols.** Every address must be a literal number today.
- **`.STATIC`, `.RELOC`, `.INCLUDE` directives.**
- **`/M` (map file) and `/L` (listing file) output.**
- **Source files larger than 64KB.**

## Source

[src/external/casm/](../src/external/casm/) — see
[CASM Programmer's Reference](casm-programmers-reference.md) for the full
module-by-module internals.
