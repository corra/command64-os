# WP3 Batch 4 — `casmbig1` Repetition Rule

Status: **Frozen for user review.**
Branch: `feature/casm-byte-oracle-wp3` · Plan:
`brain/plans/2026-09-02-casm-byte-oracle-wp3-fixture-oracle-remediation.md`

## Class

Repetitive/large output — the WP1 contract requires a **reviewed seed +
count/range formula with an assembler-independent expansion**, not a
hand-typed byte stream.

## Source

Two CLI roots (`source_sha256` pinned):

- `casmbiga.seq` = `.ORG $C000` followed by **3000** `NOP` lines
  (`ebbf46982761…`).
- `casmbigb.seq` = **3000** more `NOP` lines, no `.ORG`
  (`2dde170dedb8…`).

Assembled with `CASM CASMBIGA.S CASMBIGB.S /O:CASMBIG1.PRG`.

## Repetition rule

- `.ORG $C000` → PRG load-address header `00 C0`.
- Each `NOP` (implied addressing) → `$EA`, one byte, no operand.
- `3000 + 3000 = 6000` `NOP` statements → `6000 × $EA`.
- The synthetic inter-file newline (file A has a trailing LF; the loop
  concatenates cleanly) does not emit a byte.

Total length: `2 + 6000 = 6002` bytes.

## Assembler-independent expansion

```python
body = b'\x00\xC0' + b'\xEA' * 6000
assert len(body) == 6002
import hashlib
assert hashlib.sha256(body).hexdigest() == \
    '7288e48919ca646b4ddd242ad6dcc6a05cecccdd181a380d5d559a1682ae391d'
```

This reproduces `casmbig1.ref.hex`'s body exactly. The expansion uses no
6502 opcode table — `$EA` is the single documented NOP-implied encoding,
stated once here.

## Boundary spot-checks

| offset | expected | why |
| --- | --- | --- |
| `0`–`1` | `00 C0` | load-address header (`$C000`) |
| `2` | `EA` | first `NOP` (`$C000`) |
| `3001` | `EA` | last `NOP` from `casmbiga.seq` (3000th; `$C000 + 2999`) |
| `3002` | `EA` | first `NOP` from `casmbigb.seq` — proves the file join emits nothing between |
| `6001` | `EA` | last `NOP` (`$C000 + 5999` = `$D747`) |
| `6002` | — | EOF; no R6 footer (this fixture is `.ORG`-anchored static) |

All confirmed against the frozen body.

## Not circular

Derived from: the single documented `NOP` encoding, the `.WORD`-style
load-address framing, and the two source files' line counts. No CASM
output consulted; the `.ref` binary is byte-identical before/after (it was
never changed — only `# source_sha256:` lines added).

## Live confirmation (WP3 consolidated verification)

`CASM CASMBIGA.S CASMBIGB.S /O:CASMBIG1.PRG` on
`casm_overflow_test.d64`, then `COMP CASMBIG1.PRG,CASMBIG1.REF` →
`FILES COMPARE OK`.

## Reviewer sign-off

On user approval, the prose reviewer line is added to `casmbig1.ref.hex`
and the Ledger-A row moves to `CANONICAL-INDEPENDENT`.
