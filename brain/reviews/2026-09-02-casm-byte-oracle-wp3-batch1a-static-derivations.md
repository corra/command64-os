# WP3 Batch 1a — Static PRG Derivations

Status: **Frozen for user review** (the independent-reviewer sign-off, per
WP3 Scoping Decision 1 / the WP60 opcode-oracle precedent).
Branch: `feature/casm-byte-oracle-wp3` · baseline `6ae6ea5`
Plan: `brain/plans/2026-09-02-casm-byte-oracle-wp3-fixture-oracle-remediation.md`
Register: `brain/reviews/2026-09-01-casm-byte-oracle-audit.md` (Ledger A)

## Scope

16 static-PRG references. This batch adds a `# source_sha256:` line to each
`.ref.hex` (the SHA-256 of the exact generated `.seq` byte stream the
fixture consumes) and freezes the byte derivation for review. **No `.ref`
hex body was changed** — verified: all 67 `.ref` binaries are
byte-identical before and after `cmake --build build --target
casm_reference_fixtures` (`/tmp/rb_before.txt` == `/tmp/rb_after.txt`),
and `casm_oracle_inventory --check` passes with the new `source_sha256`
verification active.

`# sha256:` was already present on all 16, so none was added; the
30-refs-without-`sha256` work lands in Batches 1b–1e.

## Method (applies to every ref in this batch)

The byte derivation was worked from: the documented NMOS 6502/6510
opcode + addressing-mode encoding, the fixture's own `.seq` source
directives, and the Command 64 PRG framing (2-byte little-endian
load-address header). **Not** from CASM output, `opcodes.s`, or ca65.
`hex_manifest_to_bin.py` then transcribed the reviewed hex and confirmed
the declared `bytes:`/`sha256:` against the body; native `COMP` under
Command64 is the post-derivation confirmation recorded in each fixture's
own CMake/walkthrough history.

For 15 of the 16 the `.ref.hex` header already carries a complete,
non-circular address-and-opcode ledger; this record **attests that ledger
was re-checked** against the 6502 encoding and the `.seq` source and is
correct. `casmnum2` had only a one-line note and is fully derived below.

## Per-reference

| ref | load | source `.seq` (sha256 first 12) | derivation |
| --- | --- | --- | --- |
| `brback1` | `$3400` | `brback1.seq` `9a54f34c5d76`… | header ledger re-checked: backward branch displacement, `$FB`/`$FE`-class negative offsets computed from `target - (pc+2)`; OK |
| `brfwd1` | `$3400` | `brfwd1.seq` | header ledger re-checked: forward branch, positive displacement; OK |
| `casmhello` | `$3400` | `casmhello.seq` `fca7778037c6`… | header ledger re-checked: `LDX #<msg` / `LDY #>msg` / `LDA #$09` / `JSR $1000` ×2, then the `"YES IT BUILDS! -- CASM" CR NUL` bytes copied from the fixture's own `.BYTE` directives; 40 bytes; OK |
| `casmemit1` | `$3400` | `casmemit1.seq` | header ledger re-checked: `.BYTE`/`.WORD` emission ordering; OK |
| `casmmodes` | `$3400` | `casmmodes.seq` | header ledger re-checked: one legal statement per `CASM_MODE_*` value, each opcode+operand from the 6502 matrix; 30 bytes; OK |
| `casmnum2` | `$C000` | `casmnum2.seq` `4f4c102c12f9`… | **full derivation below** |
| `casmorg1` | `$C000` | `casmorg1.seq` | header ledger re-checked: `.ORG` sets PC, subsequent bytes emitted at `$C000`; OK |
| `casmcase1` | `$3400` | `casmcase1.seq` | header ledger re-checked: case-sensitive identifier resolution, byte output unaffected by case; OK |
| `casmmaxid1` | `$3400` | `casmmaxid1.seq` | header ledger re-checked: max-length identifier accepted, 3-byte body; OK |
| `casmopall` | `$C000` | `casmopall.seq` `e983f784cb18`… | 152-line header ledger, one row per the 151 legal NMOS tuples, cross-referenced to `brain/reviews/2026-08-12-casm-phase11-wp60-increment1-opcode-oracle.md`; re-checked against that frozen oracle; 323 bytes; OK |
| `casmmf1` | `$C000` | `casmmfa.seq`+`casmmfb.seq` | header ledger re-checked: `LDA VALB` forward ref across a file boundary forces absolute (`AD 03 C0`), `RTS` at `$C003` defines `VALB`; 6 bytes; OK |
| `casmmf2` | `$C000` | `casmmfc.seq`+`casmmfd.seq` | header ledger re-checked: identical body to `casmmf1` (`AD 03 C0 / 60`), proving the synthetic inter-file LF (file C has no trailing newline) yields the same result; OK |
| `casmmf3` | `$C000` | `casmmfe.seq`+`casmmff.seq`+`casmmfg.seq` | header ledger re-checked: two chained cross-file forward `JMP`s — `4C 03 C0` (E→F), `FILEF` = `$C003`, `4C 06 C0` (F→G), `FILEG` = `$C006`, `RTS`; 9 bytes; OK |
| `p1back1` | `$C000` | `p1back1.seq` | header ledger re-checked: Pass-1 backward label resolution; OK |
| `p1fwd1` | `$C000` | `p1fwd1.seq` | header ledger re-checked: Pass-1 forward label, absolute width; OK |
| `p1size1` | `$C000` | `p1size1.seq` | header ledger re-checked: Pass-1 size/PC accounting across mixed statements; OK |

### `casmnum2` — full byte derivation

Source (`casmnum2.seq`):
```
.ORG $C000
.WORD 25, 26, 255, 256, 6553, 6554, 65535
.WORD $00FF, $FFFF, %11111111, %1111111111111111
```

- `.ORG $C000` → PRG load-address header, little-endian: **`00 C0`**.
- `.WORD` emits each value as two bytes, low then high:
  - `25` = `$0019` → `19 00`
  - `26` = `$001A` → `1A 00`
  - `255` = `$00FF` → `FF 00`
  - `256` = `$0100` → `00 01`
  - `6553` = `$1999` → `99 19`
  - `6554` = `$199A` → `9A 19`
  - `65535` = `$FFFF` → `FF FF`
- Second `.WORD`:
  - `$00FF` → `FF 00`
  - `$FFFF` → `FF FF`
  - `%11111111` = `255` = `$00FF` → `FF 00`
  - `%1111111111111111` = `65535` = `$FFFF` → `FF FF`

Total: `2 + 14 + 8 = 24` bytes. Full body:
```
00 C0 19 00 1A 00 FF 00 00 01 99 19 9A 19 FF FF FF 00 FF FF FF 00 FF FF
```
Matches `casmnum2.ref.hex` exactly. SHA-256
`0849f714d73fa213b5ee72c623094ef866f759b259c4d2f45f96c1f14971259b`.
The derivation exercises decimal / hex / binary literal parsing and
little-endian `.WORD` emission; not circular (no CASM output consulted).

## Reviewer sign-off

**User-approved 2026-09-02.** Each of the 16 `.ref.hex` headers now
carries the two-line prose note

```
# Independent byte derivation reviewed and approved by the user 2026-09-02
#   (WP3 batch 1a -- brain/reviews/2026-09-02-casm-byte-oracle-wp3-batch1a-static-derivations.md).
```

(prose, not a `# key:` directive — verified `hex_manifest_to_bin.py`
accepts it and all 67 `.ref` binaries stay byte-identical). The 16
Ledger-A rows are updated `CANONICAL-INDEPENDENT (pending metadata)` →
`CANONICAL-INDEPENDENT`.
