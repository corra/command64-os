# Walkthrough: CASM Phase 14 WP87 - Lexer `@`-Prefixed Local Identifiers

Plan: `brain/plans/2026-09-01-casm-phase14-local-anonymous-labels.md`
Taskwarrior: WP87 `31728848-3018-4bd4-aae3-ac68f5d3eea0`
Branch: `feature/casm-phase14`

## What this WP delivers

`lexer.s`'s `lnId` identifier scanner now accepts a leading `@`
(`CASM_PETSCII_AT`), legal only when immediately followed by a real
identifier-first byte (`A-Z`, `a-z`, `_`):

- Top-level dispatch (`lnSkip`'s byte classifier): `@` now routes into
  `lnId` alongside every other `isIdFirst` byte, instead of falling
  through to the catch-all "invalid source byte" case.
- `lnId` special-cases a leading `@`: append it, consume it, then require
  the *next* byte to pass `isIdFirst` before falling into the normal
  `isIdCont` continuation loop unchanged. A malformed form (bare `@`,
  `@@`, `@1`, `@` immediately before a newline or EOF) is reported as
  `CASM_DIAG_INVALID_SOURCE_BYTE` at the offending byte — the same
  diagnostic a bare `@` already produced before this WP, no new
  diagnostic identifier spent (per WP86's open item).
- No parser, pass-driver, symbol-table, or diagnostic-message-table
  change. A `@`-led token is still just an ordinary
  `CASM_TOKEN_IDENTIFIER` as far as every downstream consumer is
  concerned; scoping semantics are WP88/89.

## Standalone harness: `test_casm_lexer`

Seven new cases added to `tests/src/casm_lexer/casm_lexer.s`, reusing the
existing generic "string mode" `sourceNextByte` stand-in (modes 12-18):

| Case | Source | Expects |
| --- | --- | --- |
| `caseLocalIdentBareAt` | `"@"` then EOF | `CASM_DIAG_INVALID_SOURCE_BYTE` |
| `caseLocalIdentDoubleAt` | `"@@"` | `CASM_DIAG_INVALID_SOURCE_BYTE` |
| `caseLocalIdentAtDigit` | `"@1"` | `CASM_DIAG_INVALID_SOURCE_BYTE` |
| `caseLocalIdentAtNewline` | `"@"` then newline | `CASM_DIAG_INVALID_SOURCE_BYTE` |
| `caseLocalIdentSimple` | `"@A"` | `IDENTIFIER`, length 2, text `"@A"`, then EOF |
| `caseLocalIdentLong` | `"@LOOP2"` | `IDENTIFIER`, length 6, full text match, then EOF |
| `caseLocalIdentUnderscoreDigit` | `"@X1_Y"` | `IDENTIFIER`, length 5, full text match (proves digit/underscore continuation), then EOF |

Placed after the shared `stringCaseInit`/`stringCaseFail` helpers (not
before, like the first attempt) with a per-case local `@fail` trampoline
for every internal check, keeping every branch within 6502 short-branch
range as the harness grows — two build-time `Range error` iterations
before landing this shape, recorded here rather than silently smoothed
over.

## Build evidence (this session, 2026-09-01)

```
$ cmake --build build --target casm
...
reloc.py: .../build/casm.prg: base=0x3800, 23803 code bytes, 3900 relocation points
Verifying CASM diagnostic id -> message table
OK: all 86 diagnostic identifiers + 2 extras render exactly the frozen text
[100%] Built target casm
```

`casm.prg` grew by 66 code bytes over the WP86 baseline (23737 -> 23803) —
entirely the new lexer branch; no diagnostic-table change since
`CASM_DIAG_LOCAL_*` still has no producer.

`test_casm_lexer` initially overflowed its own `MAIN` region by 140 bytes
at the pre-existing `$1000` size; bumped to `$1100` (+256, the project's
standard smallest-round-page-fit convention) in `CMakeLists.txt`. Rebuilt
clean: `3816 code bytes, 641 relocation points`.

`image_d64`, `test_image_d64`, and `casm_phase12_test_d64` (this harness's
disk home) all rebuilt clean, no errors.

## Live VICE evidence

- `tools/vice_mcp_start.sh status`: live instance already running
  (PID 1939, VICE 3.10, `C64SC`). It was displaying the user's live Conway
  demo (confirmed via screenshot) when this session started; **the user
  was asked and explicitly approved taking it over** for this test.
- Attached `build/casm_phase12_test.d64` on unit 8 (rebuilt fresh this
  session, so no stale-image risk).
- `vice_autostart` index 0 (`command64`); screen row 0 decoded to
  `Command 64-DOS Version 0.4.1.26880` — Command64 resident, confirmed via
  direct `$0400` screen-RAM read (not just visual).
- Dispatched via `tools/vice_type_command.py "test_casm_lexer"` ->
  `vice_keyboard_petscii` with the printed byte array (never hand-typed).
- Screenshot after load: `CASM LEXER: PASS` printed, followed by a
  `c64[8]:>` shell prompt — clean exit, all cases (26 total: 19
  pre-existing + 7 new) passed. `FailCount` gates the `PASS`/`FAIL` banner
  in the harness itself (`beq allPass`), so a `PASS` banner is definitive:
  zero fails, not just "printed something."
- No checkpoints were created; nothing to clean up. VICE left running,
  healthy, at the shell prompt (Command64 resident on the test disk —
  the user can reattach `image.d64` and restart Conway themselves if
  they want the stream display back).

## Real-source behavior note (not yet exercised by fixtures)

This WP makes `@name:`/`@name` lex successfully as an ordinary
`CASM_TOKEN_IDENTIFIER` through the *entire* existing pipeline — parser,
pass driver, symbol table all still treat it exactly like any other
identifier (no LOCAL flag ever set, no scope filter ever applied) until
WP88/89 wire that in. A real `.s` source file using `@foo:` today would
already assemble it as an ordinary **global** label named `@foo`. That is
expected and harmless (nothing in the existing test corpus uses `@`), but
it means WP87 alone does not yet deliver correct local-label semantics —
only correct tokenization. Recorded so it isn't mistaken for a regression
if WP88 fixtures show a `@`-named symbol behaving as global before that
WP lands.

## Sign-off requested

WP87 is source-complete, build-verified, and live-VICE-verified
(`CASM LEXER: PASS`, 26/26 cases). Requesting approval to close WP87 and
proceed to WP88 (symbol-layer scope support: `symbolsInsert` scope
stamping, `symbolsFindChain`/`symbolsLookup` scope filtering, new
standalone `test_casm_scope` harness).
