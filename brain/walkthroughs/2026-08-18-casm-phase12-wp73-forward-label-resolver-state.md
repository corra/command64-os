---
feature: casm-phase12-wp73-branch-range-false-positive
completed: 2026-08-18
status: completed
---

# Walkthrough: CASM Phase 12 WP73 Forward-Label Resolver State

## Summary

Fixed Pass 1/Pass 2 width disagreement when a resolved named-constant lookup
immediately precedes an unresolved forward-label lookup. The resolver contract
leaves symbol-kind flags unspecified on a miss; `expr.s` now checks RESOLVED
before reading them, preserving absolute width for unresolved labels.

## Files Changed

| File | Change |
| --- | --- |
| `src/external/casm/expr.s` | Guard symbol-kind classification by RESOLVED; use `JMP` for the number-primary tail after code growth |
| `tests/src/casm_expr/casm_expr.s` | Add ordering-sensitive stale-output case 100 |
| `cmake/GenerateCasmTestFixtures.cmake` | Generate the minimal `casmfwdstale1.s` reproduction |
| `tests/fixtures/casm/casmfwdstale1.ref.hex` | Add 54-byte hand-derived trusted reference |
| `CMakeLists.txt` | Register and package the fixture/reference on `casm_phase12_test.d64` |

## Verification

- `cmake -S . -B build`: pass.
- `cmake --build build --target test_casm_expr casm_phase12_test_d64`: pass.
- `test_casm_opcodes`, `test_casm_pass1`, `test_casm_reloc`,
  `test_casm_symbols`, and `dash_ref`: build pass.
- VICE 3.10, `build/casm_phase12_test.d64`, unit 8, Command64 banner and
  `c64[8]:>` prompt proven.
- Exact PETSCII `CASM CASMFWDSTALE1.S /O:@:X /S`: output `X` created and shell
  returned. Exact PETSCII `COMP X CASMFWDSTALE1.REF`: `FILES COMPARE OK`.
- After exact PETSCII `FLUSH`, `TEST$A4CASM$A4EXPR` ran all 100 cases and
  reported `CASM EXPR: PASS`, then returned to `c64[8]:>`.
- VICE remains running as required.

## Oracle Correction

The first reference draft encoded `CPY MAXLEN` as `$E4 $7E`; COMP rejected it
at file offset `$0024`. `$E4` is CPX zero-page. The independently corrected CPY
zero-page encoding is `$C4 $7E`; the rerun then compared byte-identically.

## Manual Confirmation

1. Boot `build/casm_phase12_test.d64` into Command64.
2. Enter `CASM CASMFWDSTALE1.S /O:@:X /S` using exact PETSCII.
3. Enter `COMP X CASMFWDSTALE1.REF`; require `FILES COMPARE OK`.
4. Enter `FLUSH`, then `TEST_CASM_EXPR` with PETSCII `$A4` for each underscore;
   require `CASM EXPR: PASS` and a `c64[<device>]:>` prompt.

The user approved this completion gate on 2026-08-18. WP73 is complete and
CASM is promoted from `0.2.5` to `0.2.6`.
