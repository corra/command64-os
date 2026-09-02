# Walkthrough: CASM Phase 15 WP93 — Design Freeze

Plan: `brain/plans/2026-09-01-casm-phase15-wp93-design-freeze.md`
Phase plan: `brain/plans/2026-09-01-casm-phase15-conditional-assembly.md`
Taskwarrior: WP93 `ef34f19f`, Phase 15 parent `0678049c`
Branch: `feature/casm-phase15`

WP93 is a design-freeze WP (Phase 14 WP86 pattern): no conditional-assembly
behaviour, only the frozen decisions + the `common.inc` constants + the
`cond.s` storage skeleton + the `diagnostics.s` message strings.

## Decisions frozen (D1–D6)

| | Frozen as |
| --- | --- |
| **D1** — directive subtypes | `CASM_DIRECTIVE_IF`=`$0C`, `ELSEIF`=`$0D`, `ELSE`=`$0E`, `ENDIF`=`$0F`, `IFDEF`=`$10`, `IFNDEF`=`$11`; `CASM_DIRECTIVE_COUNT` `$0C`→`$12` |
| **D2** — suppression | **structural scan mode** — a suppressed branch is scanned line-by-line for the six conditional keywords only; no operand evaluation, no `symbolsInsert`, no `emit*`. WP95 builds `condScanSuppressedLine`. |
| **D3** — Pass 1/Pass 2 determinism | `.if`/`.elseif` **must resolve in-pass** (`CASM_DIAG_CONDITIONAL_OPERAND_UNRESOLVED` otherwise, the `.RES` precedent). Plus a **64-byte Pass-1 decision bitmap** (`CasmCondDecisionBitmap`) — every conditional site reached while emitting records one bit; Pass 2 replays by index. `.ifdef` also uses the WP76 `DEFINED_AT_OFFSET` compare as the in-pass definition test. |
| **D4** — nesting stack | `CASM_COND_MAX_DEPTH`=16, in a new `cond.s`; per-level parallel arrays; reset per pass (WP95). |
| **D5** — diagnostics | `$5B` `CONDITIONAL_WITHOUT_IF`, `$5C` `UNTERMINATED_CONDITIONAL`, `$5D` `CONDITIONAL_ELSE_AFTER_ELSE`, `$5E` `CONDITIONAL_NESTING_OVERFLOW`, `$5F` `CONDITIONAL_OPERAND_UNRESOLVED`, `$60` `IFDEF_EXPECTS_NAME`, `$61` `CONDITIONAL_SITE_OVERFLOW`; `CASM_DIAG_LAST` `$5A`→`$61`. |
| **D6** — `.ifdef` operand | a single bare identifier, no expression, no `@local` prefix. |

## Changes landed

- `src/external/casm/common.inc`: D1 subtypes + `CASM_DIRECTIVE_COUNT`
  bump + 6 contiguity `.assert`s; D5 diag identifiers `$5B`–`$61` +
  `CASM_DIAG_PHASE15_WP93_LAST` alias + `CASM_DIAG_LAST` retarget +
  7 contiguity `.assert`s; D3/D4 `CASM_COND_MAX_DEPTH` (16),
  `CASM_COND_MAX_SITES` (512), `CASM_COND_BITMAP_BYTES` (64) + `.assert`s.
- `src/external/casm/cond.s` (**new**, storage-only, `state.s` pattern):
  `CasmCondDepth`; eight `.res CASM_COND_MAX_DEPTH` per-level arrays
  (`Emitting`, `BranchTaken`, `SeenElse`, `ParentEmitting`, `OpenLineLo`,
  `OpenLineHi`, `OpenColumn`, `OpenFileId`); `CasmCondSiteCounterLo/Hi`;
  `CasmCondDecisionBitmap` (64 B). Four internal layout `.assert`s.
  **No executable code** — `condResetForPass` and the push/pop/scan
  logic are WP95 (matches WP86's "zero new instructions this WP"; the
  sub-plan's "one-line stub" idea was dropped for the cleaner
  storage-only module).
- `src/external/casm/diagnostics.s`: 7 message strings
  (`.ELSE/.ELSEIF/.ENDIF WITHOUT .IF`, `UNTERMINATED .IF`,
  `.ELSEIF/.ELSE AFTER .ELSE`, `CONDITIONAL NESTING TOO DEEP`,
  `.IF CONDITION NOT RESOLVED`, `.IFDEF/.IFNDEF EXPECTS A NAME`,
  `TOO MANY CONDITIONALS`) + 14 `diagMsgLo`/`diagMsgHi` entries
  (`$5B`–`$61`), all RODATA.
- `scripts/verify_casm_diag_table.py`: `EXPECTED` extended with the seven
  `$5B`–`$61` frozen strings.
- No build-wiring change needed: `cond.s` is picked up by
  `CASM_SRCS`'s `GLOB_RECURSE src/external/casm/*.s`, and no `test_casm_*`
  link config references any WP93 symbol.

## Verification

- **Build**: `cmake -B build && cmake --build build` — clean. All 31
  `test_casm_*` targets build.
- **Diagnostic table**: `verify_casm_diag_table` (`POST_BUILD`) →
  `OK: all 97 diagnostic identifiers + 2 extras render exactly the frozen
  text` (was 90 at Phase 14).
- **Deliberate-break check**: deleting one `diagMsgLo` entry →
  `Error: CASM diagnostic message table (lo) length must equal
  CASM_DIAG_LAST` (build-breaking, as designed — the runtime range check
  and the verify script cannot drift behind the table). Reverted.
- **Envelope** (`ld65 -m` against the `casm_3800` config):

  | Segment | WP92 baseline | WP93 | Δ |
  | --- | --- | --- | --- |
  | CODE | `$3800`–`$8BFA` (`$53FB`) | `$3800`–`$8BFA` (`$53FB`) | **0** — byte-identical |
  | RODATA | `$0BBB` | `$0C81` | +198 (7 strings + 14 table bytes) |
  | BSS | `$0CDD` | `$0DA0` | +195 (exactly `cond.s`: 1 + 8·16 + 2 + 64) |

  BSS ends `$A61B`; MAIN `$3800`+`$7400` ends `$AC00` → **1,509 bytes
  headroom** (was 1,902). Within the approved `$7400` envelope.
- **No-change rebuild**: a second `cmake --build build` triggered zero
  casm compile/link work.
- `BUILD_CASM` 1405 → 1409 (four builds, three of them
  deliberate-break iterations).

## Status

WP93 source-complete, build-verified, byte-identical CODE. Nothing
committed. Requesting sign-off to close WP93 and proceed to WP94 (lexer:
recognise the six conditional directive keywords).
