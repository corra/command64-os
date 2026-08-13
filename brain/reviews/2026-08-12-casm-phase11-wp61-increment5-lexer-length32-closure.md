# CASM Phase 11 WP61 Increment 5 Symbol/Token Length-32 Closure

Status: Frozen for user review
Plan: `brain/plans/2026-08-12-casm-phase11-wp61-determinism-and-boundary-spot-checks.md`
Taskwarrior: `f6845310-bcce-4448-b5f2-0aa19a73723b`

## Scope

Closes WP60 Increment 9's residual item 3: symbol/token name-length-32 rejection at `lexerTokenAppend` (`CASM_TOKEN_TEXT_MAX = 31`, `lexer.s:525-537`), previously uncovered by any harness anywhere in `tests/`.

## Harness

New `tests/src/casm_lexer/casm_lexer.s`, linking only `lexer.s` (no parser.s/source.s/state.s), with local BSS for `CasmLexerState`/`CasmLookahead*`/`CasmTokenRecord`/`CasmTokenText`/`CasmIncludeFilename*` and a stub `sourceNextByte` feeding a fixed-length run of `'A'` bytes, driving the real `lnId` identifier-scan loop through the public `lexerNext` entry point. Joined `casm_listing_test_d64` (test.d64's directory remains full).

- Case 1 (accept): 31 bytes fed, then EOF. Expect `C` clear, token length exactly 31.
- Case 2 (reject): 32 bytes fed. Expect `C` set, `A = CASM_DIAG_TOKEN_TOO_LONG`, token length still 31 (unmodified).

## Live VICE Result

`test_casm_lexer` → `CASM LEXER: PASS` (2/2 cases, no `F`s), clean shell return.

## Findings

No production defect found. No production source change; only new test-only harness/build-system additions. Symbol/token name-length-32 rejection: **closed**.

Requesting review before Increment 6 (source extent 65,535/65,536-byte closure) activates.
