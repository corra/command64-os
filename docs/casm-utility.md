# command64 OS CASM Utility Manual

**File Name:** `casm.prg`
**Version:** `0.2.0` (build 1260)
**Target Address:** `UserProgStart` (currently `$3800`, Standard User Program Space)
**Toolchain:** ca65/ld65 (see [CASM Programmer's Reference](casm-programmers-reference.md) for internals)

## Overview

`CASM` is a native 6502/6510 assembler that runs *on the C64 itself* — you
write source on the machine (with `EDLIN`, for example), assemble it with
`CASM`, and `LOAD`/`RUN` the resulting PRG, all without leaving the shell.
It performs a real two-pass assembly with labels and forward references, a
bounded expression evaluator, source-file inclusion via `.INCLUDE`, and
produces relocatable output by default so the same PRG can run at any load
address the OS chooses.

> **CASM Phase 10 is complete (labels/expressions/multi-file/relocation/
> include processing/symbol map/listing output all shipped).** `/M` and
> `/L` are fully implemented — see [Map and Listing
> Output](#map-and-listing-output-m-l) below. Everything documented below as
> supported is real and has been verified end-to-end, including in
> production via [DASH](dash-utility.md), which assembles through a
> seven-file `.INCLUDE` chain. See [Not Yet
> Supported](#not-yet-supported) for the remaining gaps.

## Command Syntax

```text
CASM <source>... [/O:<output>] [/S] [/M] [/L]
```

### Parameters

- **`<source>...`** (required): one or more top-level source files to
  assemble, up to 8, concatenated in the order given on the command line
  (each keeps its own line numbers for diagnostics). A 9th source name is
  `CASM: TOO MANY SOURCE FILES`.
- **`/O:<output>`** (optional): explicit output filename, up to 63
  characters. Without it, the output name is derived from the *first*
  source file: its extension (the part after the last `.` that comes after
  any device-prefix `:`) is replaced with `.PRG`, or `.PRG` is appended if
  it has none. For example, `CASM GAME.CSM` writes `GAME.PRG`; `CASM
  9:UTIL` writes `9:UTIL.PRG`.
- **`/S`**: static output. The assembly must supply its own `.ORG`, and the
  resulting PRG carries no relocation trailer — use this for a program that
  will only ever run at one fixed address.
- **`/M`**: print a deterministic symbol map after a successful assembly —
  one `$HHHH LABEL` row per symbol, in definition order, plus a final
  `NNN SYMBOLS` total.
- **`/L`**: write a `.LST` source listing alongside the PRG. The name is
  derived from the output name the same way the PRG name is derived from the
  source name (extension swapped for `.LST`), unless overridden — see
  [Map and Listing Output](#map-and-listing-output-m-l).

`/M` and `/L` may be combined, and either may be used alone. Both run only
after the PRG itself is successfully committed to disk, so a listing or map
failure never costs an already-valid PRG (see
[Map and Listing Output](#map-and-listing-output-m-l)).

Options may appear before or after the source filenames, in any order, and
are matched case-insensitively (`/o:out.prg` works the same as `/O:OUT.PRG`).

### What Happens

1. CASM opens every listed source in order and streams them into one
   combined 65,535-byte source buffer (a synthetic linefeed is inserted
   between files that don't already end in one). If a source can't be
   opened, you get `CASM: CANNOT OPEN INPUT` and nothing else happens.
2. **Pass 1** measures the whole assembly without writing any output,
   defining every label's address as it goes — this is what makes forward
   references (using a label before its definition) work.
3. **Pass 2** re-walks the same source from the start, now that every label
   resolves, and actually emits the PRG.
4. On success, it prints `CASM: INPUT VALIDATED` and returns to the shell.
   The output PRG is on disk and ready to `LOAD`.
5. On any error, it prints one specific diagnostic (see
   [Example 4: Error Messages](#example-4-error-messages)), deletes the
   partial output file if one was created, and returns to the shell — no
   half-written PRG is left behind.

## Language Reference

### Statements

One statement per line: an optional leading whitespace, then either a
label definition, a directive (`.ORG`, `.BYTE`, `.WORD`, `.INCLUDE`), a
mnemonic and its operand, or nothing (a blank line is valid). A semicolon
starts a comment that runs to end of line:

```asm
START:  LDA #$01        ; load the value
        STA $D020
```

### Labels and Symbols

A line consisting of an identifier followed by `:` defines a label at the
current address:

```asm
LOOP:   INX
        BNE LOOP
```

Labels can be used before their definition (a forward reference) — CASM's
first pass resolves every label's address before the second pass emits any
code, so it doesn't matter whether `LOOP` appears above or below where it's
used. Identifiers are up to 31 characters, **case-sensitive** (in PETSCII
terms, unshifted and shifted spellings of the same letter are different
symbols), and stored in a 512-entry symbol table shared across the whole
assembly. Redefining the same name is `CASM: DUPLICATE SYMBOL`; using a name
that's never defined is `CASM: UNDEFINED SYMBOL`; exceeding 512 distinct
labels is `CASM: SYMBOL TABLE FULL`.

An expression is one symbol or literal number, with an optional `<` (low
byte) or `>` (high byte) prefix, and an optional `+`/`-` numeric addend:

```asm
LDA #<MESSAGE      ; low byte of MESSAGE's address
LDA #>MESSAGE      ; high byte of MESSAGE's address
LDA MESSAGE+3      ; the 4th byte of MESSAGE
```

Parenthesized or multiplicative arithmetic (`(A+B)*2`) is not supported —
`CASM: EXPRESSION UNSUPPORTED`.

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
available:

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
as a plain number or label, and CASM picks zero page automatically whenever
the value fits in a byte and the mnemonic supports it in that mode, falling
back to absolute otherwise. `LDA $10` assembles as zero-page `LDA` (2
bytes); `LDA $1000` assembles as absolute `LDA` (3 bytes) — same source
syntax either way. A label's address always forces the *absolute* form of
the instruction, even if the resolved value happens to fit in a byte — this
keeps instruction sizes identical between passes regardless of where the
label is defined.

Branch mnemonics (`BCC`, `BCS`, `BEQ`, `BMI`, `BNE`, `BPL`, `BVC`, `BVS`)
take a plain target address or label, not a signed offset — CASM computes
the relative displacement for you and rejects the instruction with `CASM:
BRANCH OUT OF RANGE` if the target is more than 127 bytes behind or 128
bytes ahead of the next instruction.

### Directives

| Directive | Syntax | Effect |
| --- | --- | --- |
| `.ORG` | `.ORG $C000` | Sets the assembly's fixed address and switches it to static output (see [Relocation](#relocation) below). Optional — omit it entirely for the default relocatable behavior. A second `.ORG`, or one after output has already started, is an error. |
| `.BYTE` | `.BYTE $01, $02, $FF` | Emits one or more comma-separated byte values (each must fit 8 bits) at the current address. |
| `.WORD` | `.WORD $1234, $ABCD` | Emits one or more comma-separated 16-bit values, little-endian, at the current address. |
| `.INCLUDE` | `.INCLUDE "SUBS.S"` | Splices another source file in at this point, as if its text appeared here. See [Splitting Source Across Files](#splitting-source-across-files). |

`.STATIC` and `.RELOC` are recognized by name but not yet implemented —
using either exits with `CASM: FEATURE NOT IMPLEMENTED`. Use `/S` with an
explicit `.ORG` for static output instead (see below).

### Relocation

By default — with no `.ORG` and no `/S` — CASM produces **relocatable**
output: the PRG assembles against an implicit base address (`$3400`) but
carries a relocation table and footer (format `R6`) that lets the OS loader
patch every address-dependent byte to run correctly at whatever address it's
actually loaded at. This is what lets a single assembled PRG run unmodified
from `LOAD`/`RUN` at the default user program address, or explicitly
relocated elsewhere.

Giving an explicit `.ORG`, or passing `/S` (which requires an explicit
`.ORG`), switches to **static** output instead: the PRG is fixed at that one
address, with no relocation table. Use static output for a program that
must live at a specific fixed address and will never move — `/S` with no
`.ORG` is `CASM: ORG REQUIRED`.

### Splitting Source Across Files

`.INCLUDE "NAME.S"` loads another source file's text in place at that point,
as if it had been pasted there — the included file's own labels and code
become part of the same single assembly (same symbol table, same two
passes). This is how a large program is organized as multiple files without
needing them all named on the `CASM` command line:

```asm
.INCLUDE "SUBS.S"
```

Rules:

- The filename must be a quoted string, 1-63 printable characters, right
  after `.INCLUDE`. A missing opening quote is `CASM: INCLUDE FILENAME
  EXPECTED`; an empty or unprintable name is `CASM: INVALID INCLUDE
  FILENAME`; over 63 characters is `CASM: INCLUDE FILENAME TOO LONG`.
- A file with no explicit device prefix (`8:`, `9:`, `10:`, `11:`) is read
  from the *including* file's own device — so a chain of includes stays on
  whichever disk the top-level source came from unless a child explicitly
  names another one.
- The same physical file may be `.INCLUDE`d more than once (from different
  places) without being read from disk twice — up to 32 distinct files
  total (`CASM: INCLUDE CATALOG FULL` beyond that).
- Includes may nest up to 16 levels deep (`CASM: INCLUDE DEPTH EXCEEDED`
  beyond that); a file that (directly or indirectly) includes itself is
  `CASM: INCLUDE CYCLE DETECTED`.
- The combined size of every source file involved — top-level and included
  — is still capped at 65,535 bytes total.

See [DASH](dash-utility.md) for a real, shipping seven-file program built
entirely through one `.INCLUDE` chain from a single entry file.

## Map and Listing Output (`/M`, `/L`)

Both options run only after a successful assembly, in a fixed order: PRG
first, then `/L`'s listing, then `/M`'s map. Each stage's output is
committed before the next one starts, so a failure at any stage retains
everything already committed and only suppresses what would have come
after — a listing failure still leaves a complete, valid PRG; a map failure
still leaves a complete, valid PRG and listing. Nothing about the PRG
itself changes — its bytes are identical whether or not `/M`/`/L` are given
(see [Programmer's Reference §17](casm-programmers-reference.md#17-symbol-map--listing-output-phase-10-complete)
for the underlying guarantee).

### `/M`: Symbol Map

Prints one row per symbol, in the order each was first defined (not
alphabetical, not hash-table order), followed by a total:

```text
$3400 START
$340E MSG
002 SYMBOLS
```

### `/L`: Source Listing

Writes a `.LST` file alongside the PRG: a 40-column listing with a file
header (source filename, chunked across continuation lines if it doesn't
fit one), then one detail row per source line showing that line's starting
address, the bytes it emitted, and its exact verbatim source text —
including lines inside an `.INCLUDE`d file, each attributed to its own
file and line number. Without `/O:`, the `.LST` name is derived from the
*output* name the same way the output name itself is derived from the
source name (extension replaced with `.LST`); rerunning `CASM` against a
`.LST` name that already exists on disk is subject to the same
replace-on-open behavior as the PRG itself.

### Combining Both

```text
CASM DEMO.CSM /M /L
```

Produces `DEMO.PRG`, `DEMO.LST`, and the symbol map printed to the screen,
in that order — PRG first (so it's safe the moment it appears), listing
second, map last.

## Practical Examples

### Example 1: A Minimal Static Program

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

*Output:* `CASM: INPUT VALIDATED`. This produces a 20-byte static PRG
loading at `$C000` (no relocation trailer, since `.ORG` was given):

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

### Example 2: Labels and Forward References

```asm
        LDX #$00
LOOP:   LDA MESSAGE,X
        BEQ DONE
        JSR $1000
        INX
        BNE LOOP
DONE:   LDA #$4C
        JSR $1000
MESSAGE:
        .BYTE $48, $49, $00     ; "HI" + null terminator
```

This assembles with no `.ORG`, so it produces the default relocatable
output at implicit base `$3400`, complete with a relocation table covering
`MESSAGE`'s address wherever the loader ultimately places it. `LOOP` is used
before its own definition is reached in the source (a genuine forward
reference within the same file) and resolves correctly because Pass 1
records every label's address before Pass 2 emits any code.

### Example 3: Splitting Source with `.INCLUDE`

`MAIN.S`:

```asm
        LDA #$09
        LDX #<MESSAGE
        LDY #>MESSAGE
        JSR $1000
        LDA #$4C
        JSR $1000
        .INCLUDE "DATA.S"
```

`DATA.S`:

```asm
MESSAGE:
        .BYTE $59, $45, $53, $20, $49, $54, $20
        .BYTE $42, $55, $49, $4C, $44, $53, $21, $00
```

Assemble and run it:

```text
CASM MAIN.S /O:HELLO.PRG
LOAD HELLO
RUN
```

`.INCLUDE "DATA.S"` splices `DATA.S`'s text in at that point, so `MESSAGE`
is defined as part of the same assembly `MAIN.S` started — no separate
symbol table, no separate passes. `#<MESSAGE`/`#>MESSAGE` load the low/high
bytes of the label's relocated address into X/Y before calling
`DOS_PRINT_STR` (see [api-reference.md](api-reference.md)); `LDA #$4C` then
`JSR $1000` calls `DOS_EXIT`.

*Output:* `YES IT BUILDS!`, then a clean return to the shell.

### Example 4: Error Messages

CASM stops at the first error and reports a specific diagnostic rather than
a generic failure. A few representative cases (see the [Programmer's
Reference diagnostic table](casm-programmers-reference.md#19-diagnostic-reference)
for the complete list):

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
| A second `.ORG` | `CASM: DUPLICATE ORG` |
| `/S` with no `.ORG` anywhere | `CASM: ORG REQUIRED` |
| `.ORG $C000` / `BNE $D000` *(target far out of branch range)* | `CASM: BRANCH OUT OF RANGE` |
| Using `UNDEFINEDLABEL` that's never defined | `CASM: UNDEFINED SYMBOL` |
| Defining the same label twice | `CASM: DUPLICATE SYMBOL` |
| `.INCLUDE FOO.S` *(missing quotes)* | `CASM: INCLUDE FILENAME EXPECTED` |
| A word CASM doesn't recognize where a statement should start | `CASM: SYNTAX ERROR` |

### Reading a diagnostic

A diagnostic that concerns a specific place in the source prints two extra
lines under the message: a location and the offending line with a caret
(preceded by an `IN FILE` line whenever more than one top-level source file
was given, so an error inside an `.INCLUDE`d file names it):

```text
CASM: INVALID SOURCE BYTE
AT LINE 2, COL 9 (OFFSET 8) BYTE $40
  LDA #$0A@,X
          ^
```

- **LINE** and **COL** are 1-based and counted **per file**; **OFFSET** is
  the 0-based byte index into the line (always `COL - 1`), which some
  editors report instead of a column.
- **BYTE** appears only for `INVALID SOURCE BYTE`, giving the rejected
  byte's value. That byte is shown as `.` in the line above, because it is
  by definition not a normal printable character, so its value is stated in
  hex rather than left ambiguous.
- Lines wider than the screen scroll a window to keep the caret visible,
  with `<.` or `.>` marking a clipped edge.

Diagnostics with no source position — a missing file, an option error, an
internal failure — print the message line alone.

## Not Yet Supported

These will produce a specific error rather than silently doing the wrong
thing — see the [Programmer's Reference §18](casm-programmers-reference.md#18-coverage-what-works-today)
for status and rationale:

- **`.STATIC` / `.RELOC` directives** — use `/S` plus `.ORG` instead.
- **Multiplicative or parenthesized expression arithmetic** — `(A+B)*2` and
  similar are not supported; only one symbol/literal plus an optional
  `±NUMBER` addend.
- **More than 8 top-level source files, 32 distinct included files, 16
  include-nesting levels, 512 distinct labels, 4096 relocation entries,
  4096 listing records (`/L`), or 65,535 bytes of combined source.**
- **Rerunning `CASM` against an output (or `/L`) name that already exists
  on disk** hangs rather than replacing or failing fast (a pre-existing
  gap, not specific to `/M`/`/L`) — use a distinct `/O:` name per run, or
  delete the stale file first.

## Source

[src/external/casm/](../src/external/casm/) — see
[CASM Programmer's Reference](casm-programmers-reference.md) for the full
module-by-module internals.
