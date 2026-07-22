---
feature: casm-phase5-wp20-tests
created: 2026-07-21
status: complete
---

# Test Plan: CASM Phase 5 WP20 Expression Adapter

## Harness Contract

`test_casm_expr` links production `expr.s` with test-owned token, lexer-next,
diagnostic, and resolver implementations. Each case installs a bounded token
script, calls `exprEvaluate`, reads the nine-byte record through `exprGetResult`,
and prints one result character followed by a final pass/fail summary.

The test owns `$70-$75` as a result pointer, expected pointer, and counters. It
allocates one 39-byte current token, a bounded scripted-token table, expected
record, counters, and diagnostic snapshot in BSS. It performs no file I/O and
exits through `DOS_EXIT`.

## Deterministic Symbols

| Name | ID | State | Value | Class |
|---|---:|---|---:|---|
| `ABSVAL` | `$0001` | resolved | `$1234` | absolute |
| `RELVAL` | `$0002` | resolved | `$2000` | relocatable |
| `UNRES` | `$0003` | unresolved | invalid | relocatable |
| `UNABS` | `$0004` | unresolved | invalid | absolute |
| `BADFLAG` | n/a | invalid output | n/a | forbidden flag bit |
| all others | n/a | resolver failure | n/a | n/a |

Matching is exact and case-sensitive using token length and explicit PETSCII
bytes. The resolver never advances the token and increments one call counter.

## Required Cases

Success records list `value, flags, extraction, ID, sign, magnitude`.

| Case | Expression | Expected |
|---|---|---|
| N0 | `0` NEWLINE | `0000, R, full, 0000, +, 0000`; delimiter NEWLINE; 0 calls |
| NMAX | `$FFFF` EOF | `FFFF, R, full, 0000, +, 0000`; EOF; 0 calls |
| NLO | `<$1234` COMMA | `0034, R, low, 0000, +, 0000`; COMMA |
| NHI | `>$1234` RPAREN | `0012, R, high, 0000, +, 0000`; RPAREN |
| ABS | `ABSVAL` NEWLINE | `1234, R|S, full, 0001, +, 0000`; 1 call |
| ABSADD | `ABSVAL+1` EOF | `1235, R|S, full, 0001, +, 0001` |
| ABSSUB | `ABSVAL-$34` EOF | `1200, R|S, full, 0001, -, 0034` |
| RELADD | `RELVAL+$100` EOF | `2100, R|S|L, full, 0002, +, 0100` |
| RELLO | `<RELVAL` EOF | `0000, R|S, low, 0002, +, 0000` |
| RELHI | `>RELVAL` EOF | `0020, R|S|L, high, 0002, +, 0000` |
| UNRADD | `UNRES+$FFFF` EOF | unresolved `S|L|F`, full, 0003, +, FFFF |
| UNRSUB | `UNRES-$FFFF` EOF | unresolved `S|L|F`, full, 0003, -, FFFF |
| UNRLO | `<UNRES` EOF | unresolved `S|F`, low, 0003, +, 0000 |
| UNRHI | `>UNRES` EOF | unresolved `S|L|F`, high, 0003, +, 0000 |
| UNA | `UNABS+5` EOF | unresolved `S|F`, full, 0004, +, 0005 |

`R/S/L/F` mean resolved, symbol-derived, relocatable, and force-absolute.
Unresolved expected value bytes are `$0000` only as initialized storage and are
never treated as valid.

## Error Cases

| Case | Tokens | Diagnostic and location |
|---|---|---|
| NUMADD | `1 + 1` | `$25` at PLUS; resolver calls 0 |
| NUMSUB | `1 - 1` | `$25` at MINUS |
| NOPRIMARY | `<` NEWLINE | `$24` at NEWLINE |
| BADADD | `ABSVAL +` NEWLINE | `$24` at NEWLINE; one resolver call |
| SYMADD | `ABSVAL + RELVAL` | `$24` at second IDENTIFIER |
| CHAIN | `ABSVAL + 1 + 1` | `$25` at second PLUS |
| ADJNUM | `ABSVAL 1` | `$25` at NUMBER |
| ADJID | `ABSVAL RELVAL` | `$25` at second IDENTIFIER; resolver called once |
| OVER | `RELVAL+$FFFF` | `$26` at magnitude NUMBER |
| UNDER | `ABSVAL-$FFFF` | `$26` at magnitude NUMBER |
| UNKNOWN | `absval` | `$27` at IDENTIFIER; one resolver call |
| BADFLAG | `BADFLAG` | `$27` at IDENTIFIER; one resolver call |

Each diagnostic case verifies carry set, A, one diagnostic stamp, token type,
and scripted line/column values. Success verifies carry clear, no stamp, exact
record bytes, final token, and resolver count.

## Production Adapter Regression

- Existing valid numeric fixtures continue through parser/opcode/emitter.
- `casmemit1`, `casmhello`, `casmmodes`, and `casmnum2` outputs compare equal to
  trusted references using the established C64 workflow.
- Existing parser/emit errors retain diagnostics and caret locations.
- Add focused generated sources only if needed for delimiter regressions:
  extraction in immediate/absolute/indirect/`.BYTE`/`.WORD`, comma retention,
  and identifier resolver failure. Such sources remain SEQ fixtures and do not
  define symbols or expected production symbolic output.

## Build and Manual Procedure

1. Build `test_casm_expr`, inspect header/segments/imports, and confirm no
   unresolved production-only symbols.
2. Build CASM at both bases and inspect MAIN use.
3. Build `test_image_d64`; confirm `test_casm_expr` and existing CASM fixtures.
4. In VICE or hardware, run `test_casm_expr`; record zero failures and summary.
5. Run the existing numeric CASM reference comparisons.

The broken `c64-testing` MCP and web emulators are prohibited. WP20 cannot be
completed until the user confirms the local runtime matrix.
