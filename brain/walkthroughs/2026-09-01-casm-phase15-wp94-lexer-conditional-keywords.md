# Walkthrough: CASM Phase 15 WP94 — Lexer Conditional Directive Keywords

Plan: `brain/plans/2026-09-01-casm-phase15-conditional-assembly.md` (WP94)
Taskwarrior: WP94 `43d508a0`
Branch: `feature/casm-phase15`

WP94 wires the six conditional keywords into the lexer only — no parser
or pass-driver behaviour.

## Changes

- `src/external/casm/lexer.s`:
  - Six new keyword strings after `dirAssertStr`: `dirIfStr` (`.IF`),
    `dirElseifStr`, `dirElseStr`, `dirEndifStr`, `dirIfdefStr`,
    `dirIfndefStr`.
  - Six `compareTokenText` blocks appended to `lnDirective`'s linear
    recognition chain, inserted between `@notAssert` and the
    `CASM_DIRECTIVE_UNKNOWN` fall-through, each emitting
    `CASM_TOKEN_DIRECTIVE` with its D1 subtype (`$0C`-`$11`).
  - Recognition order is irrelevant: `compareTokenText` is exact-length
    and case-folded (via `normalizeChar`), so `.IF` never matches
    `.IFDEF`/`.IFNDEF` and `.ELSE` never matches `.ELSEIF`.

- `tests/src/casm_lexer/casm_lexer.s`:
  - Shared `dirCaseCheck` helper (`A` = string mode, `X` = expected
    subtype): feeds `.KEYWORD` + EOF, asserts `lexerNext` -> DIRECTIVE
    with the expected subtype, then EOF.
  - Eight cases: `caseDirIf/Elseif/Else/Endif/Ifdef/Ifndef` (accepted ->
    correct subtype) and `caseDirIfBad` (`.IFF`) / `caseDirEndBad`
    (`.ENDI`) -> `CASM_DIRECTIVE_UNKNOWN`.
  - Source rows 13-20 (`dirIfSrc`..`dirEndBadSrc`) appended to
    `stringSourceLo/Hi/Size` (string modes 19-26).
  - 21 -> 26 cases run.

- `CMakeLists.txt`: `test_casm_lexer` `TEST_PRG_SIZE` `1100` -> `1200`.
  The eight new cases + helper + source rows overflowed `$1100` by a
  measured 228 bytes; `$1200` (+256) is the next round-page fit, the
  same convention WP87 used for the `$1000`->`$1100` bump.

## Verification

- **Build**: `cmake -B build && cmake --build build` clean. All 31
  `test_casm_*` targets build. `BUILD_CASM` 1409 -> 1410.
- **Live VICE** (3.10, `Command 64-DOS Version 0.4.1.2680`): booted
  `casm_include_test.d64`, `flush`, dispatched `test_casm_lexer` ->
  **`CASM LEXER: PASS`** (26 cases), clean shell return. Overlay
  `test/pass` event fired.
- **Envelope** (`ld65 -m`): casm CODE `$53FB` -> `$545B` (+96 B, the six
  compare blocks), RODATA `$C81` -> `$CA9` (+40 B, the six keyword
  strings), BSS unchanged. BSS ends `$A6A3`; MAIN headroom under `$7400`:
  1,509 -> **1,373 bytes**.

## Status

WP94 source-complete, build- and live-VICE-verified. Nothing committed
yet at time of writing. Requesting sign-off to close WP94 and start WP95
(conditional-nesting stack + suppression scanner in `cond.s` +
`test_casm_cond` harness).
