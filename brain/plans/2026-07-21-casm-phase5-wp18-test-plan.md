# Test Plan: CASM Phase 5 WP18 Numeric and Checked Arithmetic Core

## Purpose

Certify that relocating the numeric converter does not change Phase 4 output,
that decimal carry propagation remains correct, and that every radix rejects
values above `$FFFF`. Checked addend helpers have no production caller until
WP19, so their WP18 evidence is static/object-level; WP19/WP21 own end-to-end
expression execution.

## Generated Fixtures

### `casmnum2.seq` - valid trusted-output case

```asm
.ORG $C000
.WORD 25, 26, 255, 256, 6553, 6554, 65535
.WORD $00FF, $FFFF, %11111111, %1111111111111111
```

Expected PRG bytes:

```text
00 C0
19 00 1A 00 FF 00 00 01 99 19 9A 19 FF FF
FF 00 FF FF FF 00 FF FF
```

The reference is hand-derived and stored as `casmnum2.ref.hex`; it must not be
generated from CASM output.

### Error fixtures

| Fixture | Source operand | Expected diagnostic |
|---|---|---|
| `casmnumerrd.seq` | decimal `65536` | `$1E OPERAND OUT OF RANGE` |
| `casmnumerrh.seq` | hexadecimal `$10000` | `$1E OPERAND OUT OF RANGE` |
| `casmnumerrb.seq` | binary 17 ones | `$1E OPERAND OUT OF RANGE` |

Each begins with `.ORG $C000` and emits the operand through `.WORD`, exercising
the exported parser compatibility wrapper from the existing emitter path.

## Static Arithmetic Matrix

Instruction-by-instruction review covers:

- add: `$0000+0`, `$0000+1`, `$FFFE+1`, `$FFFF+0`, `$FFFF+1`;
- subtract: `$0000-0`, `$0001-1`, `$FFFF-$FFFF`, `$0000-1`;
- positive/negative zero magnitude;
- carry propagation low to high byte;
- overflow/underflow returns `$26` and carry set;
- success returns carry clear and adjusted X/Y;
- failure location is stamped while the magnitude NUMBER remains current.

All arithmetic tests inherit CASM's application invariant that D is clear;
public routine comments state this precondition explicitly.

## Automated Verification

- configure and build `casm`, `casm_test_fixtures`, and `test_image_d64`;
- verify all four SEQ files and `casmnum2.ref` appear on the test disk;
- inspect trusted manifest byte count and SHA-256 conversion;
- confirm existing `casmemit1`, `casmhello`, and `casmmodes` references are
  unchanged;
- inspect `expr.o`, `parser.o`, and `diagnostics.o` segments/exports/imports;
- verify no-change build-number stability and `git diff --check`.

## Manual Verification

On supported local C64 emulation or hardware:

1. Assemble `casmnum2` and compare its PRG with `casmnum2.ref` using `COMP`.
2. Assemble each error fixture and confirm `OPERAND OUT OF RANGE` at the numeric
   token.
3. Run one existing Phase 4 trusted fixture to confirm no parser/emitter
   regression.

Do not use the broken C64-testing MCP or a web emulator.
