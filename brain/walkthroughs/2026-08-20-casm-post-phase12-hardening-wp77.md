---
feature: casm-post-phase12-hardening-wp77
plan: brain/plans/2026-08-20-casm-post-phase12-hardening.md
date: 2026-08-20
---

# Walkthrough: WP77 — Named-Constant Chaining Parse Failure

## Scope

Taskwarrior task 42. `IDENTIFIER = IDENTIFIER` (a named constant whose
right-hand side is another identifier, e.g. `DEFCONST = BASECONST`), with
no arithmetic operator involved, failed to parse the *following* statement
with `CASM: EXPECTED NEWLINE`. Disclosed as a deferred follow-up during
WP76.

## Root Cause

`ppsConstant`'s `@identifierStore` label (`src/external/casm/parser.s:512`)
carried a comment claiming to "fall through to `@requireTerminator`", but
the code immediately following it was actually `@curAddr`'s body — the
`*`-RHS (current-address) handler, which unconditionally calls `jsr
lexerNext` to consume the `*` token. For an `IDENTIFIER` RHS there is no
`*` to consume, so that call ate the real NEWLINE terminator instead,
leaving the lexer's current token pointing at the *next* line's first
token. `@requireTerminator` then rejected that token as "not a NEWLINE" —
which is why the diagnostic located the failure on the following line, not
the constant-chain line itself. Also silently corrupted the constant's own
flags (`CasmConstantIsCurAddr` was wrongly set to 1 for a plain identifier
RHS), though no test happened to exercise that downstream effect.

Live reproduction (build 1324, pre-fix) with a minimal fixture:
```
.ORG $C000
BASECONST = $05
DEFCONST = BASECONST
LDA #DEFCONST
RTS
```
produced `CASM: EXPECTED NEWLINE AT LINE 3, COL 1 (OFFSET 0)`, pointing at
line 3's `LDA`, confirming the desync.

## Fix

`src/external/casm/parser.s`: one-line change. Replaced the fall-through
comment with an explicit `jmp @requireTerminator` at the end of
`@identifierStore`, matching every other RHS arm's own explicit jump
(`@numericTerminator`, `@curAddrStore`).

## Verification (live VICE 3.10, C64SC)

1. Same fixture re-run against the fixed build (1325): `CASM: INPUT
   VALIDATED`, output PRG created.
2. Regression: `test_casm_expr` (the full expression/constant unit suite,
   unaffected by this change per its own design) re-run on
   `casm_phase12_test.d64` — `CASM EXPR: PASS` (100 dots, no failures).
3. Permanent fixture added: `casmchain1.s`/`casmchain1.ref`
   (`cmake/GenerateCasmTestFixtures.cmake`,
   `tests/fixtures/casm/casmchain1.ref.hex`, registered in
   `CMakeLists.txt`'s `CASM_REF_NAMES` and `casm_phase12_test_d64`'s
   fixture set). Hand-derived reference (`A9 05 60` — `LDA #$05` / `RTS`,
   `DEFCONST` resolving through `BASECONST` to `$05`), never produced by
   CASM itself. Live COMP: `casm casmchain1.s /o:casmchainout.prg` →
   `CASM: INPUT VALIDATED`; `comp casmchainout.prg casmchain1.ref` →
   `FILES COMPARE OK`.
4. `FLUSH` run before/after each command per this project's live-test
   convention.
5. Build: `cmake --build build --target casm` clean at build 1325; a
   repeat build left `BUILD_CASM` unchanged (true no-change rebuild).
   `cmake --build build --target image_d64` and
   `casm_phase12_test_d64` both build clean.

Naming note: the fixture was first named `casmconstchain1` (16 characters),
which collides with its own `.s`/`.ref` suffixes at CBM DOS's 16-character
directory-name truncation boundary (a documented hazard in this project —
see `project-casm-testd64-source-vs-output-size`). Renamed to `casmchain1`
(10 characters) before either file was actually needed to disambiguate on
disk.

## Outcome

Fix confirmed working live, byte-exact against a hand-derived trusted
reference, zero regression in the existing expression/constant suite.
Taskwarrior task 42 marked complete. User approved closing WP77 on
2026-08-20.
