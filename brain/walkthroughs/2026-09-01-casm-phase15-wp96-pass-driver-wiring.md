# Walkthrough: CASM Phase 15 WP96 — Conditional Pass-Driver Wiring

Plan: `brain/plans/2026-09-01-casm-phase15-wp96-pass-driver-wiring.md`
Taskwarrior: WP96 `e841c04b`
Branch: `feature/casm-phase15`

`.if` / `.elseif` / `.else` / `.endif` working end to end. `.ifdef` /
`.ifndef` are WP97 (the WP96/97 boundary was reshaped by mechanism —
truthiness family here, symbol-existence family next; user-approved).

## Changes

- `parser.s`:
  - The six conditional `CASM_DIRECTIVE_*` subtypes route to
    `ppsDeferOperands` — classify, leave operand tokens in the stream.
  - New exported `parserEvalConditionExpr` — `lexerNext` +
    `parserParseExpressionValue` + `CASM_EXPR_FLAG_RESOLVED` check (else
    `CASM_DIAG_CONDITIONAL_OPERAND_UNRESOLVED`) → truthiness (nonzero ⇒
    1) in `A`. The `ppsFillDirective` / `ppsAssert` template.

- `casm.s`:
  - `casmRunPass` top: `condCurrentlyEmitting` → emitting path unchanged;
    suppressed → `crpScanSuppressed`.
  - `crpScanSuppressed` — one physical line, `lexerNext` only, NEVER the
    full parser. Recognises only the six conditional keywords as a line's
    first token: `.IF`/`.IFDEF`/`.IFNDEF` → `condOpenIf(0)` (nested in a
    suppressed level, no eval); `.ELSEIF` → `crpCondApplyElseif` (evaluate
    only if it can re-enable); `.ELSE`/`.ENDIF` → structurally; everything
    else drained and discarded.
  - `crpDir` dispatches `crpCondIf` / `crpCondElseif` / `crpCondElse` /
    `crpCondEndif` for an emitting branch. `.IFDEF`/`.IFNDEF` emitting →
    `CASM_DIAG_NOT_IMPLEMENTED` (WP97).
  - Shared helpers: `crpCondApplyElseif` (the "eval only when parent
    emitting and no branch taken yet" rule, used by handler + scanner),
    `crpCondSiteDecision` (pass number from `CasmPassMode` → the WP95
    record/replay bitmap), `crpCondRequireTerminator`,
    `crpCondStageOpenLoc` / `crpCondStampOpenLoc`.
  - `crpDone` runs `condAtEof` first — an open `.IF` at EOF is
    `CASM: UNTERMINATED .IF` pointing at the `.IF`'s own line.

- `CMakeLists.txt` / `GenerateCasmTestFixtures.cmake`: new
  `casm_phase15_test_d64` image; `test_casm_cond` moved onto it from
  `casm_include_test_d64`; 10 fixtures (6 accepted + hand-derived
  `.ref.hex`, 4 rejected). `test_casm_include` `TEST_PRG_SIZE` `$1900` →
  `$1A00` (53 B parser growth, unused by that harness). `CASM_REF_NAMES`
  test.d64 loop excludes `^casmif` / `^casmel` (phase15 disk only).

Two build fixes en route: `beq crpDone` went out of branch range (764 B)
→ `bne`+`jmp`; `test_casm_include` MAIN overflow → the envelope bump.

## Live verification (VICE 3.10, `CASM V0.6.0.1413`)

`casm_phase15_test.d64`:

| Fixture | Result |
| --- | --- |
| `test_casm_cond` | `CASM COND: PASS` (moved-disk regression) |
| `casmif1` | `00 C0 EA EA` → `FILES COMPARE OK` (`.IF 1` body assembled) |
| `casmif0` | `00 C0 EA` → `FILES COMPARE OK` (`.IF 0` body omitted, 3 statements counted) |
| **`casmifskip`** | `00 C0 EA` → `FILES COMPARE OK` — a `.IF 0` body holding `LDA UNDEFINEDXYZ` + `.WORD NOTASYMBOL` assembled clean. **The structural scanner never evaluated it** (WP93 D2). |
| `casmifelse` | `00 C0 EA EA` → `FILES COMPARE OK` (`.ELSE` of a false `.IF`) |
| `casmelif` | `00 C0 EA EA EA` → `FILES COMPARE OK` (`.ELSEIF` ladder, third arm taken) |
| `casmifnest` | `00 C0 EA EA` → `FILES COMPARE OK` (nested `.IF`) |
| `casmiffwd` | `CASM: .IF CONDITION NOT RESOLVED` AT LINE 2, COL 1 (caret at `.if later`) |
| `casmifnoend` | `CASM: UNTERMINATED .IF` AT LINE 2, COL 1 |
| `casmendnoif` | `CASM: .ELSE/.ELSEIF/.ENDIF WITHOUT .IF` AT LINE 3, COL 1 |
| `casmelseelse` | `CASM: .ELSEIF/.ELSE AFTER .ELSE` AT LINE 4, COL 1 |

Regression witness: `casm_phase13_test.d64` → `casm casmassert1.s` +
`comp casmassert1.prg casmassert1.ref` → **`FILES COMPARE OK`** — a
program with no `.if` token assembles byte-identically; the `casm.s`
gate is neutral.

Overlay `test/pass` event fired.

## Build + envelope

- Full `cmake --build build` clean; all 32 `test_casm_*` targets build.
- `ld65 -m`: casm CODE `$55C9` → `$57BE` (+505 B — scanner + handlers +
  `parserEvalConditionExpr`), RODATA unchanged, BSS unchanged.
  **MAIN headroom under `$7400`: 1,000 → 499 bytes.**
- **Watch item:** WP97 (`.ifdef`/`.ifndef`) adds the `symbolsLookup` +
  `DEFINED_AT_OFFSET` handler code. 499 B may not absorb it plus WP98/99;
  an envelope decision (raise `$7400`, or trim) may be needed before
  WP99. Flag at WP97 start.
- `BUILD_CASM` → 1413.

## Deferred from the sub-plan's 12 fixtures

`casmifsym` (label in a skipped branch → later `UNDEFINED SYMBOL`) and
`casmifp1p2` (Pass 1/Pass 2 byte-count agreement) — deferred to WP98's
consolidated verification, where the no-conditionals regression and
`/M` `/L` interaction fixtures also live.

## Status

WP96 source-complete, build- and live-VICE-verified (10/10 fixtures +
regression). Nothing committed at time of writing. Requesting sign-off
to close WP96 and start WP97 (`.ifdef` / `.ifndef` — and confirm the
envelope decision if the headroom won't hold).
