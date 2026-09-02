# command64 OS CASM Utility Manual

**File Name:** `casm.prg`
**Version:** `0.6.1` (build 1417)
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

> **CASM Phase 15 is complete** (CASM `0.6.1`). Through Phase 12:
> labels/expressions/multi-file/relocation/include processing/symbol
> map/listing output/named constants/the current-address
> symbol/parenthesized precedence/arithmetic and bitwise
> operators/character literals/string literals. Phase 13 added the
> data directives (`.RES`/`.FILL`/`.ALIGN`/`.INCBIN`/`.ASSERT` — see
> [Data Directives](#data-directives)); Phase 14 added `@name` local labels
> (see [Local Labels](#local-labels-name)); Phase 15 added conditional
> assembly (`.IF`/`.ELSEIF`/`.ELSE`/`.ENDIF`/`.IFDEF`/`.IFNDEF` — see
> [Conditional Assembly](#conditional-assembly)). Everything
> documented below as supported is real and has been verified end-to-end,
> including in production via [DASH](dash-utility.md), which assembles
> through a seven-file `.INCLUDE` chain and uses named constants, operator
> expressions, string literals, `.RES` buffers, and `@local` labels
> throughout its own source. A consolidated hardening pass has also
> exhaustively re-verified the base behavior — every opcode/addressing-mode
> combination, every Phase 12 syntax form together in one session, boundary
> conditions, and re-assembly determinism. See
> [Not Yet Supported](#not-yet-supported) for the remaining gaps.

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

### Local Labels (`@name`)

An identifier prefixed with `@` is a **local label** — the ca65 "cheap
local" spelling. It is defined with `@name:` and referenced as `@name`
anywhere an ordinary label is valid (a branch or absolute operand, a
`.BYTE`/`.WORD` operand, a `.ASSERT` expression):

```asm
delay:  ldx #$00
@loop:  dex
        bne @loop        ; @loop is the one just above
        rts
draw:   ldy #$28
@loop:  dey              ; a *different* @loop -- new scope
        bne @loop
        rts
```

A local label's **scope** opens at the nearest preceding ordinary
(non-`@`) label and closes at the next ordinary label, or end of file.
Within one scope a local name must be unique; across scopes the same
`@name` is free to reuse, and a local may shadow an ordinary label of
the same spelling (the `@`-prefixed reference always resolves to the
local). Forward references work exactly as for ordinary labels — `bne
@done` before `@done:` is fine — because both passes re-establish the
same scope in lockstep.

Diagnostics:

| Condition | Message |
| --- | --- |
| `@name:` before any ordinary label | `CASM: LOCAL LABEL BEFORE ANY GLOBAL LABEL` |
| the same `@name:` twice in one scope | `CASM: DUPLICATE LOCAL LABEL IN SCOPE` |
| `@name` referenced but never defined in its scope | `CASM: UNDEFINED LOCAL LABEL` |
| `@` on either side of a named constant's `=` | `CASM: LOCAL LABEL NOT ALLOWED IN CONSTANT` |

The undefined/duplicate messages name the owning ordinary label. In the
`/M` symbol map a local prints qualified as `<owner>@<local>` (e.g.
`DELAY@LOOP`), in definition order, truncated to fit the row.

> **Divergence from ca65 / Turbo Macro Pro.** The `@name` *spelling* is
> ca65-compatible, but CASM forbids a local label on either side of a
> named constant's `=` (`@x = 1` and `y = @x` are both rejected).
> ca65 and Turbo Macro Pro (and ACME, 64tass, KickAssembler, DASM) all
> allow it. This is a deliberate implementation-simplicity choice in CASM
> 0.6; a TMP/ca65 source that assigns a local label into a constant will
> not port cleanly. Anonymous labels (`:` / `:+` / `:-`) are not
> supported at all — they are planned as a later, separate feature.

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
| `.RES` | `.RES 16` / `.RES 16, $FF` | Emits *count* filler bytes (`$00` unless a second value is given). See [Data Directives](#data-directives). |
| `.FILL` | `.FILL 40, $20` | Emits *count* bytes of *value* — the value is required. See [Data Directives](#data-directives). |
| `.ALIGN` | `.ALIGN 256` / `.ALIGN 256, $EA` | Pads with filler bytes until the address is a multiple of *boundary*. See [Data Directives](#data-directives). |
| `.INCBIN` | `.INCBIN "DATA.BIN"` | Emits the raw bytes of another file verbatim at the current address. See [Data Directives](#data-directives). |
| `.ASSERT` | `.ASSERT END - START, "empty region"` | Compile-time check — fails assembly if the expression resolves to 0. Emits nothing. See [Data Directives](#data-directives). |

The six conditional-assembly directives — `.IF`, `.ELSEIF`, `.ELSE`,
`.ENDIF`, `.IFDEF`, `.IFNDEF` — are covered in
[Conditional Assembly](#conditional-assembly).

`.STATIC` and `.RELOC` are recognized by name but not yet implemented —
using either exits with `CASM: FEATURE NOT IMPLEMENTED`. Use `/S` with an
explicit `.ORG` for static output instead (see below).

### Data Directives

Five directives construct or check data rather than encoding instructions.

#### `.RES count[, value]` — reserve filler

Emits *count* bytes. Each byte is *value* if given, otherwise `$00`:

```asm
BUFFER: .RES 256          ; 256 zero bytes
PADDING: .RES 4, $EA       ; 4 bytes of $EA (NOP)
```

Unlike ca65's `.res`, CASM has no zero-cost "advance the program counter
without emitting" mode — a CASM PRG is one contiguous stream, so `.RES`
writes real filler bytes into the output. *count* may be any 16-bit value;
*value* must be 0-255.

#### `.FILL count, value` — repeated byte

Emits *count* copies of *value*. Both operands are required — `.FILL` has no
default fill byte (that is the one grammatical difference from `.RES`):

```asm
SCREENROW: .FILL 40, $20   ; a blank 40-column screen-code row
```

#### `.ALIGN boundary[, value]` — pad to a boundary

Emits just enough filler bytes (again `$00`, or *value*) to make the current
address a multiple of *boundary*:

```asm
        .ALIGN 256          ; next byte starts on a page boundary
TABLE:  .WORD ENTRY0, ENTRY1
```

*boundary* must be non-zero. When the address is already aligned, `.ALIGN`
emits nothing.

#### `.INCBIN "file"` — include a binary file

Splices the raw bytes of *file* into the output at the current address, with
no interpretation. The filename follows the same rules as `.INCLUDE`
(quoted, up to 32 bytes, inherits the current device unless prefixed):

```asm
SPRITES: .INCBIN "SPRITEDATA"
```

A missing file is `CASM: CANNOT OPEN INPUT`; the file's identity and length
are checked to be the same in both passes.

#### `.ASSERT expr[, [action,] "message"]` — compile-time check

Evaluates *expr* and, if it resolves to **0**, aborts the assembly with a
fatal diagnostic. Any non-zero result passes silently. It emits no bytes.

```asm
        .ASSERT ENABLE_SOUND               ; fail the build if the flag is 0
        .ASSERT TABLE_END - TABLE_START    ; fail if the table came out empty
```

`.ASSERT` tests **truthiness only** — there are no comparison operators, so
it cannot express `expr <= limit` or `a = b` directly (a documented ca65
divergence — see [Not Yet Supported](#not-yet-supported)). It is useful for
"this must be non-zero" and, via subtraction, "these two must differ"
invariants. Compute a 0/1 value with the supported arithmetic/bitwise
operators for anything more.

Like `.RES`/`.FILL`/`.ALIGN` counts and `.IF` conditions, an `.ASSERT`
expression **must fully resolve in the pass that reads it** — a forward
reference is `CASM: ASSERT OPERAND NOT RESOLVED`, not a deferred check.

Without a message, a failure prints `CASM: ASSERTION FAILED`; with one, it
prints `CASM: ASSERTION FAILED: <message>` (message up to 63 bytes). For
source shared with ca65, an optional ca65 action keyword (`ERROR`,
`WARNING`, `LDERROR`, `LDWARNING`) is accepted between the expression and
the message and then ignored — CASM treats every `.ASSERT` as a pass-time
hard failure regardless:

```asm
        .ASSERT READY, ERROR, "not ready"   ; keyword parsed and discarded by CASM
```

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

### Conditional Assembly

Six directives include or exclude a block of source depending on a
condition evaluated at assembly time (Phase 15):

```asm
.IF expr          ; assemble the following block iff expr is non-zero
.ELSEIF expr      ; ...otherwise try this block iff its expr is non-zero
.ELSE             ; ...otherwise assemble this block
.ENDIF            ; end of the conditional

.IFDEF name       ; assemble the block iff `name` is a defined symbol
.IFNDEF name      ; assemble the block iff `name` is NOT defined
```

`.IF` / `.ELSEIF` take an **expression**, and the test is pure
truthiness: any non-zero value is true, zero is false. There are **no
comparison operators** — `.IF A = B`, `.IF X < 4` and the like are *not*
supported (a deliberate divergence from ca65). When you need a
comparison, compute a 0/1 constant with the operators that
[expressions](#expressions-and-operators) do have and test that:

```asm
BIG = (SIZE - 1) >> 7      ; 1 when SIZE > 128, else 0
.IF BIG
    ; ... large-buffer path
.ENDIF
```

`.IFDEF` / `.IFNDEF` take a **bare name** (`.IFDEF 5` or `.IFDEF @local`
is `CASM: .IFDEF/.IFNDEF EXPECTS A NAME`). The name is tested against
every symbol defined *up to that point in the first pass* — a symbol
defined later in the file reads as **not defined**, consistently in both
passes (this matches ca65's traversal-order `.ifdef`). The classic use
is a define-once guard:

```asm
.IFNDEF DID_CONSTANTS
DID_CONSTANTS = 1
SCREEN = $0400
COLOR  = $D800
.ENDIF
```

Rules:

- A block that is **not** selected is skipped entirely — its text is not
  even parsed. It may contain source that would not assemble on its own;
  it defines **no labels and no constants**. A later reference to a
  label that appears only inside a skipped block is `CASM: UNDEFINED
  SYMBOL`.
- `.IF` / `.ELSEIF` conditions must resolve within the pass that reads
  them — a **forward reference** in the condition (a symbol defined later
  in the file) is `CASM: .IF CONDITION NOT RESOLVED`. (`.IFDEF` has no
  such restriction; an undefined name simply reads as "not defined".)
- Conditionals nest up to **16** levels deep (`CASM: CONDITIONAL NESTING
  TOO DEEP` beyond that) and a single assembly may contain up to **512**
  of them in total (`CASM: TOO MANY CONDITIONALS`).
- Structural errors: `.ELSE` / `.ELSEIF` / `.ENDIF` with no open `.IF` is
  `CASM: .ELSE/.ELSEIF/.ENDIF WITHOUT .IF`; a second `.ELSE` (or an
  `.ELSEIF` after `.ELSE`) is `CASM: .ELSEIF/.ELSE AFTER .ELSE`; reaching
  end of source with an `.IF` still open is `CASM: UNTERMINATED .IF`.
- With `/L`, a source line inside a skipped block is listed with its
  text but a **blank address column** and no object bytes; the
  `.IF`/`.ENDIF` directive lines themselves list normally. With `/M`, a
  skipped block contributes no symbols to the map.

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

### Example 5: Conditional Assembly

```asm
.ORG $C000

DEBUG = 1

        LDA #$00
        STA $D020
.IF DEBUG
        LDA #$02          ; only assembled when DEBUG is non-zero
        STA $D020
.ENDIF
        RTS

.IFNDEF PALETTE_DONE
PALETTE_DONE = 1
BLACK  = $00
RED    = $02
.ENDIF
```

With `DEBUG = 1` the `.IF DEBUG` block is assembled (five extra bytes);
change it to `DEBUG = 0` and those two instructions vanish from the
output with no other edit. The `.IFNDEF PALETTE_DONE` guard assembles its
body the first time and would skip it on any later repeat (e.g. if this
file were `.INCLUDE`d twice). Assemble with `/L` to see the skipped
lines listed with a blank address column.

### Reading a diagnostic

A diagnostic that concerns a specific place in the source prints extra
lines under the message: an `IN FILE` line naming the file the error is
in, a location line, and the offending line with a caret. An error inside
an `.INCLUDE`d file also lists the `INCLUDED FROM` chain back to the root.

```text
CASM: INVALID SOURCE BYTE
IN FILE MAIN.S
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
- **Comparison operators in `.IF` / `.ASSERT`** (`=`, `<>`, `<`, `>`,
  `<=`, `>=`) — `.IF` tests truthiness only; `.ASSERT` takes a single
  expression. Compute a 0/1 value with the supported operators instead.
  A divergence from ca65.
- **Anonymous labels** (`:` definition, `:+` / `:-` / `:++` references) —
  not supported; planned as a later, separate feature.
  [Named local labels](#local-labels-name) (`@name`) *are* supported as of
  Phase 14, but must not appear on either side of a named constant's `=`.
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
