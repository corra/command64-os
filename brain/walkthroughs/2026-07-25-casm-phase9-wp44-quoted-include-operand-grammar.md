# Walkthrough: CASM Phase 9 WP44 - Quoted Include Operand Grammar

## Implemented Behavior

- `.INCLUDE` accepts one quoted 1-63-byte raw PETSCII filename.
- Accepted payload ranges are `$20-$7E` and `$A0-$FE`, excluding quote `$22`.
- Space/tab may surround the operand and a semicolon comment may follow it.
- The original filename bytes and length are retained in a dedicated 65-byte
  parser-owned record; the frozen 31-byte token payload is unchanged.
- Valid syntax currently reports `CASM_DIAG_NOT_IMPLEMENTED` before emitter,
  PC, output, file, or VMM effects. WP45 will add semantic file loading.
- Grammar failures use `$31` filename expected, `$32` invalid filename, and
  `$33` filename too long with opening-quote/offending-byte provenance.

## Automated Evidence

- CASM build 1165 passes and a no-change build holds 1165.
- `build/casm.prg` is 15,800 bytes, loads at `$3400`, and ends with R6 footer
  `00 34 ba 06 52 36` (1722 relocation entries).
- `test_casm_include` build 1003 links the real lexer/parser/state modules and
  contains 14 embedded boundary/error cases.
- `test_casm_pass1` and `test_casm_passcheck` link successfully after their
  user-approved whole-object envelopes matched production's `$3A00`.
- `image_d64`, `test_image_d64`, and `casm_overflow_test_d64` build clean.
- The include harness is intentionally excluded from directory-full `test.d64`
  and stored on `casm_overflow_test.d64` as `test_casm_includ`.

## Runtime Evidence

The user's first run produced `.fffffffffffff`. RCA showed the harness retained
its case cursor in production-clobbered zero page. After moving persistent test
pointers to BSS, the user reran `test_casm_includ` and reported all 14 cases
passing.

Expected successful display:

```text
..............
CASM INCLUDE: ALL PASS
```

## Manual Confirmation

1. Attach `build/casm_overflow_test.d64` in the supported local emulator or use
   the generated disk on hardware.
2. Run `test_casm_includ`.
3. Confirm fourteen dots and `CASM INCLUDE: ALL PASS`.
4. Optionally assemble a source containing `.INCLUDE "A"`; confirm CASM reports
   `FEATURE NOT IMPLEMENTED`, proving grammar acceptance without claiming WP45
   file-loading behavior.

## Completion Gate

The user explicitly approved WP44 completion. CASM advanced once to `0.1.46`
build 1166, a no-change build held 1166, and all three disk images passed. The
final artifact remains 15,800 bytes with load address `$3400` and R6 footer
`00 34 ba 06 52 36` (1722 entries). WP45 was not activated.
