# command64 OS CASM Utility Manual

**File Name:** `casm.prg`
**Version:** `0.3.0` (build 1324)
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

> **CASM Phase 12 is complete** (labels/expressions/multi-file/relocation/
> include processing/symbol map/listing output/named constants/the
> current-address symbol/parenthesized precedence/arithmetic and bitwise
> operators/character literals/string literals all shipped). Everything
> documented below as supported is real and has been verified end-to-end,
> including in production via [DASH](dash-utility.md), which assembles
> through a seven-file `.INCLUDE` chain and uses named constants, operator
> expressions, and string literals throughout its own source. A
> consolidated hardening pass has since exhaustively re-verified this
> behavior — every opcode/addressing-mode combination, every Phase 12
> syntax form together in one session, boundary conditions, and
> re-assembly determinism — rather than adding anything new for you to
> use. See [Not Yet Supported](#not-yet-supported) for the remaining gaps.

## Command Syntax

```text
CASM <source>... [/O:<output>] [/S] [/M] [/L]
```

### Parameters

- **`<source>...`** (required): one or more top-level source files to
  assemble, up to 8, concatenated in the order given on the command line
  (each keeps its own line numbers for diagnostics). A 9th source name is
  `CASM: TOO MANY SOURCE FILES`.
- **`/O:<output>`** (optional): explicit output filename, up to 32
  characters (reduced from 63 by the memory-optimization WP). Without it, the output name is derived from the *first*
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
4. On success, it prints a `DONE: P1 nnnnn, P2 nnnnn, nnnnn BYTES` summary
   (both passes' statement totals and the final PRG size), then
   `CASM: INPUT VALIDATED`, and returns to the shell. The output PRG is on
   disk and ready to `LOAD`.
5. On any error, it prints one specific diagnostic (see
   [Example 4: Error Messages](#example-4-error-messages)), deletes the
   partial output file if one was created, and returns to the shell — no
   half-written PRG is left behind.

### Progress Display

CASM's progress display is always enabled. It uses a 34-character transient
field within the C64's 40-column row. The field is rewritten in place without
a carriage return, so repeated updates do not scroll the screen. The remaining
six columns are unused.

During either assembly pass, the transient line has this exact layout:

```text
P1: D03 F07 FILENAME L00128 T00412
```

`P2:` replaces `P1:` during Pass 2. The fields are:

| Field | Meaning |
| --- | --- |
| `D03` | Include depth, zero-padded to two digits. Top-level source is depth `00`. |
| `F07` | Numeric top-level source identity, zero-padded to two digits. During included-file traversal this can remain the parent/root id; use `D` and the filename to identify the active include. |
| `FILENAME` | First eight filename characters, truncated or space-padded to exactly eight. |
| `L00128` | Physical line number within that file, zero-padded to five digits. |
| `T00412` | Statements dispatched so far in the active pass, zero-padded to five digits. |

The statement total includes labels, named constants, instructions, and every
directive, including `.ORG` and `.INCLUDE`. Blank lines, comment-only lines,
newlines, and end-of-file do not count. The ordinary pass display updates at
exact totals 64, 128, 192, and so on. A source-file or include-depth change
forces an update on the next dispatched statement, including include entry,
return, and top-level root changes.

Source loading and long byte-producing directives temporarily use the same
transient field:

```text
LOAD F00ROOT.S  00256
P1: RES    00256
P1: FILL   00256
P1: ALIGN  00256
P2: INCBIN 00256
```

The `LOAD` layout has no separators between its two-digit file id, eight-byte
filename field, and five-digit cumulative byte count. Loading updates after
each successfully committed input block, normally every 256 bytes, and after
a final short block. The directive line reports cumulative successfully
accepted bytes after each complete block and after a final short block where
applicable; a zero-byte operation produces no directive update.

Major transitions are persistent lines ending in a carriage return:

```text
P1: START
P1: DONE 00412 STATEMENTS
P2: START
P2: DONE 00412 STATEMENTS
WRITE: PROGRAM.PRG
DONE: P1 00412, P2 00412, 16384 BYTES
CASM: INPUT VALIDATED
```

`WRITE:` prints the full output filename. Each pass starts with its statement
counter reset. Pass 1's final total is retained and compared with Pass 2; a
counter that would exceed 65535 reports `CASM: STATEMENT COUNT OVERFLOW`, and
unequal pass totals report `CASM: PASS 1/PASS 2 STATEMENT MISMATCH` before a
`P2: DONE` line can be printed.

The transient field is erased before pass-completion lines and every fatal
diagnostic. It is also cleared and suspended before `/L` listing serialization
or `/M` map output, so it cannot overwrite their output. Progress owns no file,
VMM, timer, keyboard, parser, or emitter resource, and the **assembled output
bytes are identical** regardless of the display.

All displayed counters are unsigned 16-bit values. The final `DONE:` byte
field therefore wraps modulo 65536 for an output PRG larger than 65,535 bytes;
this is a display limitation only and does not truncate or otherwise change the
written file. The included-file numeric `F` field is likewise not a unique
catalog id, although include depth and filename remain accurate. CASM currently
has no quiet option, percentage, ETA, elapsed-time display, keypress polling,
or cancellation.

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
assembly.

> **Convention:** most C64 platforms run in a single-case PETSCII mode and
> have no lowercase letters at all, so real-world C64 symbols are
> conventionally single-case, never a mix of shifted and unshifted
> spellings within one name. Command64's mixed-case charset (and CASM's
> resulting true case-sensitivity, distinct from ASCII-style case-folding)
> is an anomaly relative to that convention. Prefer **lowercase PETSCII
> identifiers** to match how real C64 software is written — CASM
> supporting case-sensitivity doesn't make mixed-case identifiers
> idiomatic.

Redefining the same name is `CASM: DUPLICATE SYMBOL`; using a name
that's never defined is `CASM: UNDEFINED SYMBOL`; exceeding 512 distinct
labels is `CASM: SYMBOL TABLE FULL`.

An expression is one or more terms — a symbol, literal number, the
current-address symbol `*` (see below), or a parenthesized sub-expression
— combined with `+`/`-`, with an optional `<` (low byte) or `>` (high
byte) prefix applying to the expression as a whole:

```asm
LDA #<MESSAGE        ; low byte of MESSAGE's address
LDA #>MESSAGE        ; high byte of MESSAGE's address
LDA MESSAGE+3        ; the 4th byte of MESSAGE
LDA #1+2+3           ; 6 -- chained operators, left to right
LDA #<(SCREENW+2)    ; a parenthesized sub-expression
LDA #((1+2)+3)       ; parentheses can nest, up to 8 levels deep
```

`+`/`-` are left-associative (`1-2-3` is `(1-2)-3`, not `1-(2-3)`) and a
relocatable value (a label, `*`, or a relocatable named constant) may only
appear once per expression — combining two of them (`label1+label2`, or
`label+(label2)`) is `CASM: EXPRESSION RELOCATION UNSUPPORTED`, since the
relocation table can only patch one such reference per location. A static
value plus one relocatable value, in either order and however deeply
parenthesized, is always fine. Nesting parentheses more than 8 levels deep
is `CASM: EXPRESSION TOO DEEPLY NESTED`. Multiplicative arithmetic (`*` as
an operator, `/`) is not yet supported — `CASM: EXPRESSION UNSUPPORTED`.

### Named Constants

`identifier = expression` defines a named constant — a value you can refer
to by name anywhere an expression is expected, without it occupying any
address of its own:

```asm
screenw = 40
border = screenw + 10
```

Constants share the same 512-entry symbol table as labels (a name can be
one or the other, never both — redefining a label as a constant, or vice
versa, is `CASM: DUPLICATE SYMBOL`) and can forward-reference other
constants or labels defined later in the source, exactly like an operand
can. A constant whose own definition is directly or transitively
self-referential (`a = b` / `b = a`, or the degenerate `a = a`) is `CASM:
CIRCULAR CONSTANT DEFINITION`.

A constant's own defining expression is narrower than an ordinary operand:
a single symbol, number, or `*`, with at most one `+`/`-` addend — it does
not support parenthesized sub-expressions or a second chained operator,
even though both are otherwise valid everywhere else. `screenw = (10+30)`
is `CASM: MALFORMED EXPRESSION`; `total = 1+2+3` is `CASM: EXPRESSION
UNSUPPORTED` at the second `+`.

> Prefer **lowercase** constant names, per the identifier convention above
> — `screenw`, not `SCREENW`.

### The Current-Address Symbol (`*`)

`*` evaluates to the address the *next* byte would be emitted at — the
same address a label defined at that exact point in the source would get.
It can appear anywhere an expression can, including as a named constant's
own value:

```asm
bufstart = *        ; bufstart == the address right here
        lda #<bufstart
        sta $fb
```

Like a label, `*` is relocation-aware: it participates in the same
relocatable/static output rules as any other address-valued expression
(see [Relocation](#relocation) below), and forces the absolute form of an
instruction operand, same as a label would. `*+N`/`*-N` and `<*`/`>*` all
work the same way they would for a label or numeric constant.

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

### Expressions and Operators

Any operand position (instruction operand, `.BYTE`/`.WORD` list, or a
named constant's own RHS) accepts a full expression, not just a bare
number or label. Operators combine any mix of numbers, labels, named
constants, and `*`, and may be grouped with parentheses:

```asm
LDA #(BASE+2)*3          ; grouping plus multiplication
LDA #~$FF00              ; bitwise complement, immediate
LDA TABLE+OFFSET*2         ; a label combined with arithmetic
.WORD $0F&$03, $8001>>1     ; bitwise AND and a logical right shift, in a directive
```

Operators, from tightest to loosest binding:

| Operator | Meaning |
| --- | --- |
| unary `-`, `~` | Negate / bitwise complement (prefix; chain freely, e.g. `~-1`) |
| `*`, `/` | Multiply, divide (unsigned 16-bit; division truncates toward zero) |
| `<<`, `>>` | Shift left/right (count must be 0-15; `>>` is logical — zero-filling, not sign-extending) |
| `&` | Bitwise AND |
| `^` | Bitwise XOR |
| `\|` | Bitwise OR |
| `+`, `-` | Add, subtract |

All arithmetic is unsigned 16-bit; a result or intermediate value outside
0-65535, a shift count outside 0-15, or a divisor of zero is `CASM:
EXPRESSION OVERFLOW` (or, for a zero divisor, `CASM: EXPRESSION DIVISION
BY ZERO`) rather than silently wrapping or crashing the assembler.
Parenthesized groups may nest up to 8 levels deep; a 9th level is `CASM:
EXPRESSION TOO DEEPLY NESTED`.

**Relocation**: an operator may combine at most one relocatable component
(a label, or a `*`-derived value) with any number of static (plain
number/constant) components. Combining two relocatable components —
`LABEL1+LABEL2`, or a label multiplied by anything — is `CASM: EXPRESSION
RELOCATION UNSUPPORTED`, because the output format can only represent one
symbol plus a static addend (see [Relocation](#relocation) below). This
applies uniformly regardless of which operator or how deeply parenthesized
the combination is.

Named constants' own definitions (`NAME = expr`, see [Named
Constants](#named-constants) above) use a narrower grammar and do not
accept these operators — only a single symbol/literal/`*` with an
optional `±NUMBER` addend.

### Character Literals

`'x'` — a single quote, exactly one byte, a closing quote — evaluates to
that byte's PETSCII value, exactly as if you had written its numeric
value directly:

```asm
lda #'a'            ; same as lda #$41
.byte 'h', 'i'       ; same as .byte $48, $49
```

The byte is taken **verbatim**: no escape sequences (`\n`, `\'`, and
similar are not supported — there is no backslash convention anywhere in
CASM), and no case folding. A literal quote character as content works
without any special syntax: `'''` reads as the quote character's own
value, since the rule is always "one byte, then the closing quote,"
regardless of what that one byte is.

Unlike a number, label, or the operators above, a character literal is
**not** a general expression primary — it's valid only as a whole
immediate operand or a whole `.BYTE` list entry:

```asm
lda #'a'             ; OK -- immediate operand
.byte 'h', 'i'        ; OK -- .BYTE list entries
lda 'a'              ; error -- not valid as a bare (non-immediate) operand
.word 'a'            ; error -- not valid in a .WORD list
lda #'a'+1            ; error -- can't combine with an operator
name = 'a'           ; error -- not valid on a named constant's own RHS
```

### String Literals

Double-quoted strings are valid as whole `.BYTE` list entries:

```asm
.byte "hello", 0
.byte $01, "", 'a', "ok", 1+1
```

Each content byte is emitted **verbatim** as PETSCII. CASM performs no case
folding, ASCII conversion, screen-code conversion, or ca65 charmap remapping.
An empty string is valid and emits zero bytes. No terminator or length byte is
added automatically; write an explicit `0` when the consumer needs a
null-terminated string.

Strings support no escapes, embedded quote spelling, interpolation, or implicit
concatenation. Content is limited to printable PETSCII (`$20-$7E` and
`$A0-$FE`, with `"` closing the string) and to the current 255-byte source-line
payload. A newline or EOF before the closing quote reports `CASM: STRING
UNTERMINATED`; a non-printable content byte reports `CASM: STRING INVALID
BYTE`.

Strings are not expression values. They are invalid in instruction operands,
`.WORD`, `.ORG`, and named-constant definitions, and adjacent strings require
the ordinary comma separator.

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
| `.BYTE` | `.BYTE $01, "OK", 0` | Emits one or more comma-separated byte expressions, character literals, or verbatim PETSCII strings at the current address. Numeric values must fit 8 bits; strings may be empty and add no implicit terminator. |
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

- The filename must be a quoted string, 1-32 printable characters, right
  after `.INCLUDE`. A missing opening quote is `CASM: INCLUDE FILENAME
  EXPECTED`; an empty or unprintable name is `CASM: INVALID INCLUDE
  FILENAME`; over 32 characters is `CASM: INCLUDE FILENAME TOO LONG`.
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
- **A named constant's own definition** (`NAME = expr`) does not accept the
  full expression grammar above — only a single symbol/literal/`*` with an
  optional `±NUMBER` addend.
- **More than 8 top-level source files, 32 distinct included files, 16
  include-nesting levels, 512 distinct labels, 4096 relocation entries,
  4096 listing records (`/L`), or 65,535 bytes of combined source.**
- **Rerunning `CASM` against an output (or `/L`) name that already exists
  on disk** hangs rather than replacing or failing fast (a pre-existing
  gap, not specific to `/M`/`/L`) — use a distinct `/O:` name per run, or
  delete the stale file first.
- **`/L` listing output shows a blank line between each row when printed to
  a real C64 screen.** This is a display artifact only — the `.LST` file
  written to disk is not affected. See the [Programmer's
  Reference §18](casm-programmers-reference.md#18-coverage-what-works-today)
  for the underlying mechanism.
- **A one-byte source file can trigger a phantom end-of-file byte** during
  assembly (a known, currently-unresolved defect in the source-loading
  path). See the [Programmer's
  Reference §18](casm-programmers-reference.md#18-coverage-what-works-today)
  for detail.

## Source

[src/external/casm/](../src/external/casm/) — see
[CASM Programmer's Reference](casm-programmers-reference.md) for the full
module-by-module internals.
