# command64 OS BANNER Utility Manual

**File Name:** `banner.prg`
**Build Counter:** `1005` (`src/external/banner/BUILD_BANNER`)
**Target Address:** `UserProgStart` (currently `$3800`, Standard User Program Space)
**Disk Image:** `command64_casm_utils.d64` (label `CASM UTILS`)

## Overview

`BANNER` is a UNIX-style external utility that renders a short text message in
large 5×6 block characters, in the spirit of the classic `banner(1)` command.
Each glyph is drawn from the `#` character (`$23`) for set cells and a regular
space (`$20`) for clear cells, printed through `KERNAL CHROUT` (`$FFD2`).

`BANNER` is also the project's reference case for **native CASM source
compatibility**. Its source, `src/external/banner/banner.s`, is deliberately
self-contained and segment-free — all zero-page equates and font data are
inlined — so the same file assembles both on the host with ca65/ld65 and on the
C64 itself with `CASM`. The host build's PRG load-address header is isolated in
a separate `src/external/banner/header.s`, which CASM does not need. The
`command64_casm_utils.d64` image therefore ships both `banner.prg` and
`banner.s` (as a SEQ file) so the source can be reassembled on-target.

## Command Syntax

```bash
BANNER <text>
```

### Parameters

* **`<text>`**: The message to render. Everything after the command name, up to
  the end of the command line, is taken as the message — spaces included, no
  quoting required.
* **`/?`, `-?`, `/H`, `-H`**: Print the usage banner instead of rendering.

Running `BANNER` with no argument at all also prints the usage banner:

```text
BANNER V1.0.0.1000
USAGE: BANNER <TEXT>
```

> **Note:** the version string in the usage text is a hardcoded literal in
> `USAGE_STR` and does not track the `BUILD_BANNER` counter, so it still reads
> `1.0.0.1000` at build 1005.

---

## Text Handling

* **Case folding:** lowercase `a`–`z` (`$61`–`$7A`) is folded to uppercase
  before glyph lookup, so `BANNER hello` and `BANNER HELLO` render identically.
* **Message cap:** the message buffer holds **120 characters**. Input past that
  is silently discarded.
* **Unmapped characters:** any character without a glyph renders as a blank
  glyph (the same cell pattern as a space) rather than erroring.
* **Line-leading space skipping:** spaces at the start of each block line are
  consumed before the line is measured. Wrapped lines therefore stay
  left-aligned, and a message ending in spaces exits cleanly instead of emitting
  an empty trailing block line.

## Layout and Wrapping

Each glyph occupies 5 columns plus a 1-column gap, so **6 characters fill one
40-column block line**. Wrapping is strictly character-based — there is no word
wrapping; a 7-character message splits after the 6th character.

Each block line is 6 screen rows tall, followed by one blank separator row
before the next block line.

## Supported Glyphs

| Range | Characters |
|:---|:---|
| Space | ` ` |
| Letters | `A`–`Z` (lowercase folded to uppercase) |
| Digits | `0`–`9` |
| Punctuation | `!` `?` `.` `,` `-` `+` `=` `:` `;` `/` `\` `*` `(` `)` `#` |

The font is stored in `FONT5X6_DATA` as 6 bytes per glyph (one per row). Bits
4..0 of each byte are the 5 horizontal cells, bit 4 being the leftmost column.

---

## Practical Examples

### 1. A Short Message

`BANNER HI`

Renders `H` and `I` side by side as two 5×6 block glyphs on a single block line.

### 2. Wrapping

`BANNER 0123456`

The first six characters (`012345`) fill the first block line; `6` wraps to a
second block line below it, separated by one blank row.

### 3. Punctuation

`BANNER !?.`

Exercises the punctuation dispatch path — useful as a quick smoke test after
changes to `GET_GLYPH_INDEX`.

### 4. Usage Help

`BANNER` or `BANNER /?`

Prints the two-line usage banner and exits without rendering.

---

## Technical Notes

* **Exit path:** `BANNER` terminates via `DOS_EXIT` (`$4C`) through the OS
  Service Bus at `JSR $1000`, returning cleanly to the shell prompt.
* **Argument source:** the message is read from `CommandBuffer` (`$033C`)
  starting at the shell's `ParsePos` (`$63`), skipping the command name token
  and any spaces that follow it.
* **Zero page:** uses `$72`–`$76`, `$78`, `$79` for render state and `$FB`/`$FC`
  as the string print pointer — all within the external-application safe area
  described in the [Programmer's Reference](programmers-reference.md).
* **Size bound:** the ca65 target is built with a `$0800` (2 KB) PRG size limit.

## Related Documents

* [OS User Manual](user-manual.md) — the summary `BANNER` command entry.
* [CASM Utility Manual](casm-utility.md) — assembling `banner.s` on the C64.
* [BANNER task record](tasks/banner-command.md).
