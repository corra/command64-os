# WP3 Batch 2 — `casmexprn` Re-Derivation (`UNCLEAR` → `CANONICAL-INDEPENDENT`)

Status: **Frozen for user review.**
Branch: `feature/casm-byte-oracle-wp3` · Plan:
`brain/plans/2026-09-02-casm-byte-oracle-wp3-fixture-oracle-remediation.md`

## Why this ref was `UNCLEAR`

At WP2, `casmexprn.ref.hex` was the lone `UNCLEAR`: it carried `bytes:`
and `sha256:` but only a one-line note ("Hand-derived little-endian
words at .ORG $C000" — which was also **wrong**, describing a different
fixture) and no "NOT produced by CASM" statement. The bytes were
plausibly hand-writable but the provenance was not asserted or explained.

## Coverage — not a duplicate

`casmexprn.seq` exercises the `<` (low-byte) and `>` (high-byte) operand
operators in **every** operand position. This is not covered by
`casmnum2` (`.WORD` value ranges) or `casmarith2/3` (arithmetic operator
precedence / width). Disposition (Scoping Decision 3): **re-derive and
keep.**

## Source and full derivation

`casmexprn.seq`
(`source_sha256: 3ae1d05bd1022cc4bd266dbeaedd4838fbe33ef50fb6943dcbb81d4971ed6bd5`):

```
.ORG $C000
LDA #<$1234
LDA >$1234
LDA (<$1234),Y
.BYTE <$1234, >$1234
.WORD <$1234, >$1234
```

| statement | reasoning | bytes |
| --- | --- | --- |
| `.ORG $C000` | PRG load-address header, little-endian | `00 C0` |
| `LDA #<$1234` | `#` = immediate. `<$1234` = low byte of `$1234` = `$34`. Opcode `LDA #` = `A9`. | `A9 34` |
| `LDA >$1234` | `>$1234` = high byte = `$12`. No `#` → memory operand. `$12` < 256 → zero-page addressing selected. Opcode `LDA zp` = `A5`. | `A5 12` |
| `LDA (<$1234),Y` | `(<$1234),Y` = `($34),Y` → (indirect),Y. Opcode `LDA (ind),Y` = `B1`. Operand = `$34`. | `B1 34` |
| `.BYTE <$1234, >$1234` | one byte per list item: `$34`, `$12` | `34 12` |
| `.WORD <$1234, >$1234` | `.WORD $0034, $0012`, each little-endian | `34 00 12 00` |

Total `2 + 2 + 2 + 2 + 2 + 4 = 14` bytes:

```
00 C0 A9 34 A5 12 B1 34 34 12 34 00 12 00
```

SHA-256 `325b48c21115fa9ac006a6aabfeecee08171a5d93b6746e701007bbb97e612b9`.
Matches the existing frozen body **byte-for-byte** — the `.ref` binary is
unchanged (`build/casm_refs/casmexprn.ref` == a fresh
`hex_manifest_to_bin.py` transcription). Only the header was rewritten:
the wrong one-line note replaced with this derivation + the "NOT produced
by CASM" statement + `source_sha256`.

Not circular — derived from the NMOS 6502 encoding and the operator
definitions, no CASM output consulted.

## Live confirmation

Recorded in the WP3 consolidated verification: `CASM CASMEXPRN.S` under
Command64, `COMP CASMEXPRN.PRG,CASMEXPRN.REF` → `FILES COMPARE OK`.

## Reviewer sign-off

On user approval, the prose reviewer line is added to
`casmexprn.ref.hex` and the Ledger-A row moves `UNCLEAR` →
`CANONICAL-INDEPENDENT`. **Zero `UNCLEAR` then remain.**
