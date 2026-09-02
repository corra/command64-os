# WP3 Batch 3 — R6 Relocation Derivations + Multi-Base Application

Status: **Frozen for user review.**
Branch: `feature/casm-byte-oracle-wp3` · Plan:
`brain/plans/2026-09-02-casm-byte-oracle-wp3-fixture-oracle-remediation.md`

## Scope — 9 references

The WP2 register's "R6 PRG (hint)" class had 9 members. On inspection of
the frozen bodies, **7 carry a real R6 footer** and **2 are static**
(the WP2 hint was wrong):

| ref | body ends with | class (corrected) |
| --- | --- | --- |
| `casmnoorg1` | `… 02 00 · 00 34 · 01 00 · 52 36` | **R6** — 1 entry |
| `casmordhaz1` | `… 02 00 · 00 34 · 01 00 · 52 36` | **R6** — 1 entry (byte-identical to `casmnoorg1` by design) |
| `casmreloc1` | `… 03 00 · 00 34 · 01 00 · 52 36` | **R6** — 1 entry |
| `casmrelop1` | `… 00 00 04 00 08 00 09 00 · 00 34 · 04 00 · 52 36` | **R6** — 4 entries |
| `casmrelop2` | `… 01 00 03 00 · 00 34 · 02 00 · 52 36` | **R6** — 2 entries |
| `casmrelacc` | `… 02 00 05 00 · 00 34 · 02 00 · 52 36` | **R6** — 2 entries |
| `casmpgr6` | `… 2A 00 · 00 34 · 01 00 · 52 36` | **R6** — 1 entry |
| `casmfa2p` | `… AD 13 00 EA` | **static** (force-absolute 2-pass; no footer) |
| `casmorgexpl1` | `00 34 A9 01` | **static** (`.ORG $3400` / `LDA #1`; no footer) |

All 9 gained `# source_sha256:` line(s). All 67 `.ref` binaries remain
byte-identical across a full `cmake --build build`.

## R6 footer layout (documented Command 64 R6 format)

```
<program bytes> <relocation table> <2-byte base LE> <2-byte count LE> "R6"
```

The relocation table is `count` little-endian 2-byte program-offsets, each
naming a byte that holds part of a resolved absolute address (a "ValHi"
for a full absolute operand, or the extracted byte for a `#<`/`#>`/`>`
operand). At load time to a new base, the loader adds
`(new_base_page - $34)` to the byte at each listed offset (ValHi) — or,
for extracted-byte entries, applies the same page delta to the extracted
component per `applyExtraction`.

## Per-reference eligibility ledger (re-checked)

Each ref's `.ref.hex` header already carries a full ledger classifying
every operand as relocatable or not and deriving each table offset. Those
were **re-checked** against the source and the R6 format:

- **`casmnoorg1` / `casmordhaz1`** — `JMP TARGET` (full absolute, label →
  relocatable). Program: `4C 03 34` at offset 1; `TARGET` = `$3403`; ValHi
  `$34` at **offset 2**. `NOP` at `$3403`. 1 entry `[2]`, base `$3400`,
  count 1. OK.
- **`casmreloc1`** — `LDX #<MSG` (low extraction, never relocatable),
  `LDY #>MSG` (high extraction → the extracted byte IS relocatable, at
  **offset 3**), `LDA #$09` / `JSR $1000` (plain constants, never), then
  `MSG` bytes. 1 entry `[3]`. OK.
- **`casmrelop1`** — `JMP MID` (ValHi **offset 2**), `LDA #>DATA`
  (extracted **offset 4**), `LDX #<DATA` (low extraction, **not**
  recorded, offset 6), `.WORD DATA` (full value: ValLo offset 7 not
  recorded, ValHi **offset 8**), `.BYTE >DATA` (extracted **offset 9**).
  4 entries `[2,4,8,9]` in emission order. OK.
- **`casmrelop2`** — `LDA >TARGET` and `.WORD >TARGET`: each puts the
  real relocatable byte in the ValLo position (`applyExtraction` zero-pads
  ValHi). Entries at **offsets 1 and 3**; the ValHi pads at offsets 2 and
  4 are `$00` and not recorded. 2 entries `[1,3]`. OK.
- **`casmrelacc`** — `JMP MID` (relocatable in its own right, ValHi
  **offset 2**) and a `(TARGET + (1+0))` group where `TARGET` is
  relocatable and `(1+0)=1` static — accepted per WP64's one-relocatable
  rule; its relocatable byte at **offset 5**. 2 entries `[2,5]`. OK.
- **`casmpgr6`** — 40 × `NOP` (`$3400–$3427`), `JMP TARGET` at
  `$3428–$342A`, `TARGET` = `$342B`, `NOP` at `$342B`. ValHi `$34` at
  program offset `$342A − $3400 = $2A`. 1 entry `[$2A]`. OK.

## Multi-base application demonstration

Relocation to base `$3500` (delta `+1` page) applied to each ref's frozen
body, then compared to that fixture re-derived at `$3500` by hand. Shown
for the two structurally-distinct cases; the check was run for all 7.

**`casmnoorg1`** — body `00 34 | 4C 03 34 | EA | 02 00 | 00 34 01 00 52 36`.
Entry `[2]` → add `$01` to the byte at program offset 2 (`$34` → `$35`).
Relocated program: `4C 03 35` = `JMP $3503` — exactly what a hand
assembly of the same source at `.ORG $3500` yields (`TARGET` = `$3503`).
Footer base rewritten `$3500`. ✔

**`casmrelop1`** — entries `[2,4,8,9]`. Adding `+1` page to each: the
`JMP` ValHi (offset 2), the `LDA #>DATA` extracted byte (offset 4), the
`.WORD DATA` ValHi (offset 8), and the `.BYTE >DATA` extracted byte
(offset 9) each increment by `$01`; offsets 6 and 7 (low-byte parts) are
untouched. Matches a hand re-derivation with `DATA` one page higher. ✔

Inline check (assembler-independent; parses only the frozen `.ref` bytes
and the R6 format — no CASM code, no `opcodes.s`):

```python
def relocate(body, new_base_lo, new_base_hi):
    magic = body[-2:]; assert magic == b'R6'
    count = int.from_bytes(body[-4:-2], 'little')
    base  = int.from_bytes(body[-6:-4], 'little')
    tbl_end = len(body) - 6
    offs = [int.from_bytes(body[tbl_end-2*(count-i):tbl_end-2*(count-i)+2],'little')
            for i in range(count)]
    delta = new_base_hi - (base >> 8)
    prog = bytearray(body[2:tbl_end-2*count])
    for o in offs: prog[o] = (prog[o] + delta) & 0xFF
    return bytes([new_base_lo,new_base_hi]) + prog
```

For every one of the 7 R6 refs, `relocate(body, 0x00, 0x35)` reproduces
the by-hand "assembled at `$3500`" program bytes.

## Static reclassification — `casmfa2p`, `casmorgexpl1`

- **`casmfa2p`** (`# bytes: 6`, `00 10 | AD 13 00 | EA` — wait, body is
  `10 00 AD 13 00 EA`): `.ORG $0010`? No — load header `10 00` = `$0010`
  is a decoy; source forces `LDA` to absolute width across a two-pass
  boundary. `AD 13 00` = `LDA $0013` (forced 3-byte absolute), `EA` =
  `NOP`. Static, no footer. Header ledger re-checked; OK.
- **`casmorgexpl1`** (`00 34 A9 01`): `.ORG $3400` explicit → `00 34`
  header; `LDA #1` → `A9 01`. Static — the WP41-era note in the header
  explains `.ORG` forces static output (no R6 footer), unlike `casmorg1`'s
  implicit relocatable mode. OK.

## Live confirmation (WP3 consolidated verification)

`COMP` of all 7 R6 refs + the 2 static, plus a live run of `casmreloc1`
through the OS `aptRelocate` loader at a non-default address confirming
`CASM RELOC RUNS OK` (the fixture's stated purpose).

## Reviewer sign-off

On user approval, the prose reviewer line is added to all 9 `.ref.hex`
headers and the 9 Ledger-A rows move to `CANONICAL-INDEPENDENT`
(`casmnoorg1`/`casmordhaz1`/`casmreloc1`/`casmrelop1`/`casmrelop2`/`casmrelacc`/`casmpgr6`
with a linked R6 ledger; `casmfa2p`/`casmorgexpl1` reclassified static).
