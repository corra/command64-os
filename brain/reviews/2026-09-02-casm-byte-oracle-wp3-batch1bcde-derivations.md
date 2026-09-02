# WP3 Batches 1b–1e — Expression/Directive, Conditional, @local, Progress-Path Derivations

Status: **Frozen for user review** (consolidated per the approved WP3
review cadence — one review for the four mechanically-identical metadata
batches).
Branch: `feature/casm-byte-oracle-wp3` · Plan:
`brain/plans/2026-09-02-casm-byte-oracle-wp3-fixture-oracle-remediation.md`

## Scope — 41 references

| batch | refs |
| --- | --- |
| **1b** expr / directives (14) | `casmarith2`, `casmarith3`, `casmarithfwd`, `casmchain1`, `casmzpconst1`, `casmchar1`, `casmstring1`, `casmres1`, `casmfill1`, `casmalign1`, `casmincbin1`, `casmassert1`, `casmfwdstale1` |
| **1c** conditionals (14) | `casmif0`, `casmif1`, `casmifelse`, `casmelif`, `casmifnest`, `casmifskip`, `casmifdef0`, `casmifdef1`, `casmifndef1`, `casmifdeffwd`, `casmifdefguard`, `casmifL1`, `casmifM1`, `casmifp1p2` |
| **1d** `@local` (4) | `casmloc1`, `casmloc2`, `casmloc3`, `casmloc7` |
| **1e** progress-path (9) | `casmpg63`, `casmpg64`, `casmpg65`, `casmpg128`, `casmpgblank`, `casmpgfill`, `casmpgincbin`, `casmpgrt`, `casmpginc` |

(13+14+4+9 = 40 listed; `casmrelacc` originally slotted in 1b moved to
Batch 3 R6. `casmpgr6` and `casmbig1` are Batch 3 / Batch 4.)

## Machine verification (all 41)

- Each `.ref.hex` gained `# source_sha256:` line(s) — the SHA-256 of the
  exact generated `.seq` byte stream(s), plus the checked-in `.dat`
  payload for `casmincbin1` (`casmincbin1.dat`) and `casmpgincbin`
  (`casmpgbin.dat`). The 30 refs that lacked `# sha256:` gained it (body
  hash, cross-checked by `hex_manifest_to_bin.py`); the register now shows
  **66/67 with declared sha256** (only `casmexprn`, Batch 2, remains).
- **All 67 `.ref` binaries are byte-identical** before and after a full
  `cmake --build build` (`/tmp/rb_after.txt` == `/tmp/rb5.txt`).
- `casm_oracle_inventory --check` passes with `source_sha256` verification
  active against both the generated `.seq` set and the fixture `.dat`
  assets.

## 1c — Conditional-assembly derivations (the thin ones, now full)

Every conditional ref is `.ORG $C000` → header `00 C0`, then bytes from
the **selected** branch only. Per CASM Phase 15 semantics a non-selected
branch is scanned for nesting structure only: it emits no bytes, defines
no symbol, and does not advance the PC. `NOP` = `EA`.

| ref | source logic | selected → bytes | total |
| --- | --- | --- | --- |
| `casmif0` | `.IF 0` body skipped; trailing `NOP` | 1×`EA` | `00 C0 EA` (3) |
| `casmif1` | `.IF 1` body taken (`NOP`) + trailing `NOP` | 2×`EA` | `00 C0 EA EA` (4) |
| `casmifelse` | `.IF 0` false → `.ELSE` taken (2×`NOP`) | 2×`EA` | `00 C0 EA EA` (4) |
| `casmelif` | `.IF 0`, `.ELSEIF 0` both false → `.ELSEIF 1` taken (3×`NOP`); later `.ELSE` skipped | 3×`EA` | `00 C0 EA EA EA` (5) |
| `casmifnest` | outer `.IF 1` taken: `NOP`, inner `.IF 0` skipped, `NOP` → 2×`EA`; second outer `.IF 0` skipped entirely (inner `.IF 1` never scanned for emission) | 2×`EA` | `00 C0 EA EA` (4) |
| `casmifskip` | `.IF 0` body (`LDA UNDEFINEDXYZ` / `.WORD NOTASYMBOL` — would not assemble) skipped, never parsed; trailing `NOP` | 1×`EA` | `00 C0 EA` (3) |
| `casmifdef0` | `.IFDEF BAR` — `BAR` undefined → skipped; trailing `NOP` | 1×`EA` | `00 C0 EA` (3) |
| `casmifdef1` | `FOO = 1` then `.IFDEF FOO` → taken (`NOP`) + trailing `NOP` | 2×`EA` | `00 C0 EA EA` (4) |
| `casmifndef1` | `FOO = 1`; `.IFNDEF BAZ` → `BAZ` undefined → taken (`NOP`); `.IFNDEF FOO` → `FOO` defined → skipped | 1×`EA` | `00 C0 EA` (3) |
| `casmifdeffwd` | `.IFDEF LATER` before `LATER = 1` → not yet defined in Pass-1 traversal order → skipped; after `LATER = 1`, `.IFDEF LATER` → taken (2×`NOP`) | 2×`EA` | `00 C0 EA EA` (4) |
| `casmifdefguard` | `.IFNDEF GUARD` → taken first time: `GUARD = 1` + `NOP` (1×`EA`); second `.IFNDEF GUARD` → now defined → skipped (include-guard idiom) | 1×`EA` | `00 C0 EA` (3) |
| `casmifL1` | `.IF 0` body (`LDA $1234` / `NOP`) skipped; trailing `NOP`. (`/L` lists the skipped lines with a blank address column — a listing assertion, not a byte one) | 1×`EA` | `00 C0 EA` (3) |
| `casmifM1` | `.IF 0` body (`SKIPPED = 1`) skipped → `SKIPPED` never defined (no `/M` row); `REAL = 1`; `LDA #REAL` → `A9 01` | `A9 01` | `00 C0 A9 01` (4) |
| `casmifp1p2` | `.IF 1` taken: `LDA DATA` (forward ref) + `NOP`; `DATA:` after `.ENDIF` resolves to `$C004` (3-byte abs `LDA` at `$C000`, `NOP` at `$C003`, `DATA` at `$C004`), then `RTS`. Pass-1 and Pass-2 take the same branch (512-bit decision bitmap). | `AD 04 C0` / `EA` / `60` | `00 C0 AD 04 C0 EA 60` (7) |

All 14 match their `.ref.hex` bodies exactly. Not circular — derived from
the Phase 15 documented semantics + the `.seq` text, no CASM output.

## 1b / 1d / 1e — attestation

Each of the 13 (1b) + 4 (1d) + 9 (1e) references carries a complete
address-and-opcode/directive-byte ledger in its own `.ref.hex` header
(19–58 comment lines). Those ledgers were **re-checked** against:

- the documented 6502/6510 encoding (opcodes, operand widths,
  little-endian layout);
- the documented CASM directive semantics — `.BYTE`/`.WORD` emission,
  `.RES count[,val]` literal fill, `.ALIGN` padding to the next boundary,
  `.INCBIN` verbatim asset streaming, `.ASSERT` (emits no bytes),
  named-constant substitution, `@local` scope resolution;
- the fixture's own `.seq` source (now hash-pinned);
- for `casmincbin1` / `casmpgincbin`: the checked-in `.dat` payload bytes
  (now hash-pinned);
- for the R6-footer-bearing progress refs (`casmpgr6` is Batch 3, but
  `casmpgrt`/`casmpginc`/`casmpgfill`/`casmpgincbin` bodies were checked
  including any relocation table + `R6` footer).

No ledger required correction. `casmarith2`'s 58-line ledger (operator
precedence + width) and `casmpginc`'s include-chain ledger are the most
detailed; the shortest (`casmfill1`, `casmfwdstale1`, `casmassert1`) were
verified byte-by-byte against the small sources.

`casmpgrt` = `casmpgrta.seq` + `casmpgrtb.seq` (two CLI roots);
`casmpginc` = `casmpginca/b/c.seq` (root + re-included child) — all
hash-pinned; the assembled output is byte-identical with or without
progress indication.

## Reviewer sign-off

On user approval, the two-line prose note

```
# Independent byte derivation reviewed and approved by the user 2026-09-02
#   (WP3 batch 1b/1c/1d/1e -- brain/reviews/2026-09-02-casm-byte-oracle-wp3-batch1bcde-derivations.md).
```

is added to all 40 `.ref.hex` headers and the 40 Ledger-A rows flip
`CANONICAL-INDEPENDENT (pending metadata)` → `CANONICAL-INDEPENDENT`.
After 1a + 1b–1e that leaves only `casmexprn` (Batch 2), the R6 class
(Batch 3), and `casmbig1` (Batch 4) short of `CANONICAL-INDEPENDENT`.
