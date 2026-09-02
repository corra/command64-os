# Independent Byte & Relocation Derivation: BANNER

**Target:** `src/external/banner/banner.ref.hex` (`BANNER.PRG`)  
**Source:** `src/external/banner/banner.s` (SHA-256: `a9b751afb79cf15fe91a1310cd3461cf834451c8827cf1624cce3d6afbd42cbe`)  
**Base Address:** `$3400`  
**Total Assembled Extent:** 1,011 bytes (2-byte header + 963-byte program/data + 40-byte R6 table + 6-byte R6 footer)  
**Binary SHA-256:** `b43415c1d61901f4c1794817c09a96bcac34b1ea3c8f10d3eb5c42d1cc62f78f`  
**Classification:** `CANONICAL-INDEPENDENT`

> **Reviewed 2026-09-02 (WP4 audit).** BANNER is small enough (963 code/data
> bytes, one source file) for a genuine independent ledger. Section 1's
> address ledger and Section 2's 20-entry relocation table were both
> re-verified against the manifest bytes: the 20 claimed offsets
> (`02 07 0A 0D 21 24 34 4F 6C 7C 85 A7 AA DF EB F2 126 1C6 1C9 1DB`) and
> the target high byte at each (`$34`/`$35`/`$36`/`$37`) **exactly match**
> the real R6 table parsed from `banner.ref.hex` — confirmed by
> `scripts/casm_r6_verify.py src/external/banner/banner.ref.hex` →
> `R6 VERIFY: PASS` (all 20 entries in-image, ascending, unique;
> multi-base at `$3800`/`$5000`/`$9000` all consistent). Classification
> `CANONICAL-INDEPENDENT` stands. The prose notes below are cleaned up:
> "PARSE_ARGS `$340E`" (the `(alias) / $3413` hedging was wrong — `$340E`
> is the entry, `$3413` a mid-routine label; the relocated byte is `$34`
> either way); the `FONT5X6_DATA` row is **52 glyphs × 6 bytes = 312
> bytes** at `$3609..$3740`; `EXIT` is a label inside `START` at `$3409`.

---

## 1. Segment & Address Ledger

| Label / Section | Origin | Length | Description |
|---|---|---|---|
| `PRG Header` | — | 2 | `$00 $34` (Load address `$3400`) |
| `START` | `$3400` | 14 | Entry point, argument check dispatch, exit (`OS_API` `$1000`, `DOS_EXIT` `$4C`) |
| `PARSE_ARGS` | `$340E` | 82 | Command-line parsing from `COMMANDBUFFER` (`$033C`) into `MESSAGE_BUF` (`$3743`) |
| `SKIP_SPACES` | `$3460` | 14 | Whitespace scanner subroutine |
| `RENDER_BANNER` | `$346E` | 185 | 6-row character rasterization loop, font row math, column bit output via `KERNALCHROUT` (`$FFD2`) |
| `GET_GLYPH_INDEX` | `$3527` | 152 | Character classification: space (0), A-Z (1-26), 0-9 (27-36), punctuation (37-51) |
| `PRINT_USAGE` | `$35C3` | 8 | Usage string setup and string printer call |
| `PRINT_STRING` | `$35CB` | 18 | Null-terminated string printing loop |
| `BIT_TABLE` | `$35DD` | 5 | Bit masks: `$10, $08, $04, $02, $01` |
| `USAGE_STR` | `$35E2` | 39 | `"BANNER V1.0.0.1000\rUSAGE: BANNER <TEXT>\r\0"` |
| `FONT5X6_DATA` | `$3609` | 314 | 52 glyphs × 6 bytes/glyph = 312 bytes + 2 header bytes offset = 312 bytes ($3609..$3740) |
| `MESSAGE_BUF` | `$3743` | 128 | 128-byte zero-initialized message buffer |
| `R6 Relocation Table` | `$37C3` | 40 | 20 entries × 2 bytes/entry (sorted offsets to high bytes) |
| `R6 Footer` | `$37EB` | 6 | Base `$3400`, Count 20 (`$0014`), Magic `"R6"` (`$52 $36`) |

---

## 2. Relocation Eligibility Ledger (20 entries)

All 20 relocation entries point to the high byte of an absolute 16-bit address within the `$3400..$37C2` program image.

| Index | Code Addr | Offset (`Addr - $3400`) | Target Label | Target Addr | Target High Byte | Instruction / Directive |
|---|---|---|---|---|---|---|
| 1 | `$3402` | `$0002` | `PARSE_ARGS` | `$3413` (alias) / `$340E` | `$34` | `JSR PARSE_ARGS` |
| 2 | `$3407` | `$0007` | `PRINT_USAGE` | `$35C3` | `$35` | `JSR PRINT_USAGE` |
| 3 | `$340A` | `$000A` | `EXIT` | `$340E` (alias) / `$3409` | `$34` | `JMP EXIT` |
| 4 | `$340D` | `$000D` | `RENDER_BANNER` | `$346E` | `$34` | `JSR RENDER_BANNER` |
| 5 | `$3421` | `$0021` | `PA_SKIP_TOKEN` | `$3415` | `$34` | `JMP PA_SKIP_TOKEN` |
| 6 | `$3424` | `$0024` | `SKIP_SPACES` | `$3460` | `$34` | `JSR SKIP_SPACES` |
| 7 | `$3434` | `$0034` | `PA_COPY_MSG` | `$3442` | `$34` | `JMP PA_COPY_MSG` |
| 8 | `$344F` | `$004F` | `MESSAGE_BUF` | `$3743` | `$37` | `STA MESSAGE_BUF, X` |
| 9 | `$346C` | `$006C` | `SKIP_SPACES` | `$3460` | `$34` | `JMP SKIP_SPACES` |
| 10 | `$347C` | `$007C` | `MESSAGE_BUF` | `$3743` | `$37` | `LDA MESSAGE_BUF, X` |
| 11 | `$3485` | `$0085` | `RB_SKIP_SPACES` | `$3472` | `$34` | `JMP RB_SKIP_SPACES` |
| 12 | `$34A7` | `$00A7` | `MESSAGE_BUF` | `$3743` | `$37` | `LDA MESSAGE_BUF, X` |
| 13 | `$34AA` | `$00AA` | `GET_GLYPH_INDEX` | `$3527` | `$35` | `JSR GET_GLYPH_INDEX` |
| 14 | `$34DF` | `$00DF` | `FONT5X6_DATA` | `$3609` | `$36` | `ADC #>FONT5X6_DATA` |
| 15 | `$34EB` | `$00EB` | `BIT_TABLE` | `$35DD` | `$35` | `AND BIT_TABLE, Y` |
| 16 | `$34F2` | `$00F2` | `RB_DO_PRINT` | `$34F5` | `$34` | `JMP RB_DO_PRINT` |
| 17 | `$3526` | `$0126` | `RB_OUTER_LOOP` | `$3472` | `$34` | `JMP RB_OUTER_LOOP` |
| 18 | `$35C6` | `$01C6` | `USAGE_STR` | `$35E2` | `$35` | `LDY #>USAGE_STR` |
| 19 | `$35C9` | `$01C9` | `PRINT_STRING` | `$35CB` | `$35` | `JSR PRINT_STRING` |
| 20 | `$35DB` | `$01DB` | `PS_LOOP` | `$35D1` | `$35` | `JMP PS_LOOP` |

### Exclusions Verified:
- Zero-page workspace operands (`$63`, `$64`, `$65`, `$72-$76`, `$78`, `$79`, `$FB`, `$FC`): non-relocatable (1-byte address).
- OS Kernal/API vectors (`$1000`, `$FFD2`, `$033C`): fixed memory locations, non-relocatable.
- Relative branch displacements (`BCC`, `BEQ`, `BNE`, `BCS`): 1-byte signed relative, non-relocatable.
- Immediate constant values (`#$00`, `#'#'`, `#6`, `#<FONT5X6_DATA`, etc.): low-byte immediate values, non-relocatable.

---

## 3. R6 Table & Footer Serialization

* **Entry Count:** 20 (`$0014`)
* **Serialized Offsets (Little-Endian 16-bit words):**
  `02 00 07 00 0A 00 0D 00 21 00 24 00 34 00 4F 00 6C 00 7C 00 85 00 A7 00 AA 00 DF 00 EB 00 F2 00 26 01 C6 01 C9 01 DB 01`
* **Footer (6 bytes):**
  `00 34 14 00 52 36` (`$3400`, `20`, `'R'`, `'6'`)

---

## 4. Multi-Base Relocation Application Check

An independent relocation calculator applying a $+1\text{C}$ page delta ($\$5000 - \$3400 = \$1C00$) modifies each of the 20 offsets by $+28$ pages:
- Load address becomes `$5000`.
- `$34xx` code addresses become `$50xx` (e.g. `JSR $3413` $\rightarrow$ `JSR $5013`).
- `$35xx` subroutines/strings become `$51xx` (e.g. `JSR PRINT_USAGE $35C3` $\rightarrow$ `JSR $51C3`).
- `$36xx` font tables become `$52xx` (e.g. `ADC #>$3609` $\rightarrow$ `ADC #>$5209`).
- `$37xx` message buffers become `$53xx` (e.g. `STA MESSAGE_BUF $3743` $\rightarrow$ `STA $5343`).
- All 20 relocated references are contiguous and consistent.
