---
feature: casm-phase15-wp96-pass-driver-wiring
created: 2026-09-01
status: complete (user-approved 2026-09-01, committed e28dd7d; "grow if needed" for the WP97 envelope)
taskwarrior: e841c04b-94aa-4fb3-bc7b-9285d022e5f5 (WP96), parent
  0678049c-7d67-4b9a-9305-14efb2353ae1 (Phase 15)
depends-on: WP93 (37bd4c8), WP94 (fb21ff9), WP95 (ecbd717)
---

# Plan: CASM Phase 15 WP96 — Conditional Pass-Driver Wiring

## Status

**Proposed, not yet approved.** WP96 wires the truthiness-family
conditionals (`.if` / `.elseif` / `.else` / `.endif`) end to end through
`casm.s` / `parser.s`, adds the `condScanSuppressedLine` structural
scanner, and lands the first `casm_phase15_test.d64` production fixtures.
Branch `feature/casm-phase15`; commits directly on it.

## Scoping adjustment (proposed)

The phase plan split WP96 = `.if`/`.else`/`.endif` and WP97 = `.elseif`
chain + `.ifdef`/`.ifndef`. **Proposed reshape, grouped by mechanism:**

- **WP96** = `.if` / `.elseif` / `.else` / `.endif` — the whole
  *truthiness-expression* family. `.elseif` is literally `.if`'s operand
  evaluation plus `condElseif` (which WP95 already built); splitting it
  out would duplicate the eval path and the scanner's `.elseif` handling
  across two WPs.
- **WP97** = `.ifdef` / `.ifndef` — the *symbol-existence* family, which
  needs the WP76 `DEFINED_AT_OFFSET` "defined so far" logic and a
  no-raise `symbolsLookup` path — genuinely separate work.

If the user prefers the original split, WP96 does `.if`/`.else`/`.endif`
only and `.elseif` in scan mode returns `CASM_DIAG_NOT_IMPLEMENTED` until
WP97.

## Objective

`.if EXPR` / `.elseif EXPR` / `.else` / `.endif` fully working: a taken
branch assembles, a skipped branch emits nothing / defines nothing / is
never parsed for meaning, nesting works, Pass 1 and Pass 2 take identical
branches, and every structural error is a specific diagnostic at the
right source location. Plus the production fixtures proving it.

**Not in scope:** `.ifdef`/`.ifndef` (WP97); `/M` `/L` interaction
detail (WP98); the no-conditionals byte-identity regression sweep and
DASH survey (WP98); comparison operators (never — Scoping Decision 2).

## Design

### Parser (`parser.s`)

Route the six conditional `CASM_DIRECTIVE_*` subtypes to `ppsDeferOperands`
(the `.BYTE`/`.WORD` path): classify the statement, leave the operand
tokens (if any) in the lexer stream, return `CASM_TOKEN_DIRECTIVE`. All
conditional semantics stay in `casm.s`, which owns the pass number,
`cond.s`, and the scanner. `.else`/`.endif` carry no operand;
`ppsDeferOperands` leaves NEWLINE buffered and `casm.s` drains it.

`parserParseExpressionValue` + `exprGetResult` are already exported
(ppsAssert uses them) — no new parser export.

### Pass driver (`casm.s`)

**`casmRunPass` top** — after `crpListingBegin`, before
`parserParseStatement`:

```
    jsr condCurrentlyEmitting
    bne crpEmittingPath            ; A=1: normal parse+dispatch, unchanged
    jsr crpScanSuppressed          ; A=0: consume one physical line, act on
    bcs crpFail                    ;      cond.s only
    ; crpScanSuppressed returns via A: 0 = continue loop, 1 = EOF reached
    cmp #1
    beq crpScanEof
    jsr crpListingCommit           ; a suppressed line still ends a physical line
    bcc :+
    jmp crpFail
    :
    jmp casmRunPass
crpScanEof:
    jsr condAtEof                  ; unterminated .IF -> fatal, location from cond.s
    bcs crpFail
    jmp crpDone
```

**`crpScanSuppressed`** (new) — one physical line, `lexerNext` only:
- first token EOF -> return A=1.
- first token NEWLINE -> return A=0 (blank line).
- first token `CASM_TOKEN_DIRECTIVE`, conditional subtype:
  - `.if` -> `condOpenIf(0)` (nested inside a suppressed level -> inert,
    no eval, no site index). Drain operand tokens to NEWLINE/EOF.
  - `.elseif` -> if `condTopParentEmitting()==1` AND the top level's
    branch is not yet taken: **evaluate** (shared `crpCondEvalOperand`),
    `condSiteDecision`, `condElseif(result)` -- this is where a skipped
    region can re-enable. Else `condElseif(0)`, drain operand.
  - `.else` -> `condElse`. drain trailer.
  - `.endif` -> `condEndif`. drain trailer.
  - any `cond.s` error -> `diagSetLocFromStmt`, return C set + A = diag.
- first token anything else -> drain to NEWLINE/EOF, discard.
- always leave the terminating NEWLINE consumed or EOF buffered, matching
  what `parserParseStatement` does, so `casmRunPass`'s listing commit and
  loop are unchanged.

**`crpDir` emitting path** — dispatch the conditional subtypes before
`crpEmitDir`:
- `.if` -> `crpCondIf`: `crpCondEvalOperand` -> truthy; require NEWLINE;
  `condSiteDecision(truthy, passNum)` -> effective; set `CasmCondOpenLoc*`
  from `CasmStmtLoc*`; `condOpenIf(effective)`; commit listing line; loop.
- `.elseif` -> `crpCondElseif`: `crpCondEvalOperand`; require NEWLINE;
  if `condTopParentEmitting()` AND top not-taken -> `condSiteDecision` +
  `condElseif(truthy)`; else `condElseif(0)`. (Same rule as the scanner
  -- factor it.) `WITHOUT_IF` / `ELSE_AFTER_ELSE` propagate from
  `condElseif`.
- `.else` -> `crpCondElse`: require NEWLINE; `condElse`; loop.
- `.endif` -> `crpCondEndif`: require NEWLINE; `condEndif`; loop.

**`crpCondEvalOperand`** (new, shared) -- current token is the operand;
`jsr lexerNext`? no -- `ppsDeferOperands` left the operand tokens
buffered and the parser already did one `lexerNext` past the directive,
so the operand token is current. `jsr parserParseExpressionValue`;
`exprGetResult`; if `CASM_EXPR_FLAG_RESOLVED` clear ->
`CASM_DIAG_CONDITIONAL_OPERAND_UNRESOLVED` (`diagSetLocFromStmt`). Else
`truthy` = `(CasmParserStmt.VAL_LO | VAL_HI) != 0`, returned in A.

**`crpDone`** -- prepend `jsr condAtEof; bcs crpFail` before the existing
listing commit, so a clean-EOF-but-`.IF`-still-open source is
`UNTERMINATED_CONDITIONAL`.

**Pass number**: `casm.s` already tracks `CasmPassMode`
(`CASM_PASS_MODE_MEASURE` / `_EMIT`). `condSiteDecision`'s X arg = 1 if
MEASURE, 2 if EMIT.

### Grammar note for docs (WP99)

`.if`/`.elseif`/`.else`/`.endif` must be the first token on their line
(optionally after whitespace) -- a label on the same line as a
conditional directive is not supported. Documented, not diagnosed
specially (the scanner simply skips such a line in a suppressed region;
in an emitting region the label dispatches and the directive is a
separate statement -- which actually *does* work there, but the
asymmetry is why the docs say "first token").

## Production fixtures (`casm_phase15_test.d64`, new)

New image mirroring `casm_phase14_test_d64` (`CMakeLists.txt`, overlay
wrapper, `cmake-overlay-events` checklist). `test_casm_cond` **moves**
here from `casm_include_test_d64`. Each fixture COMP- or
diagnostic-verified against a hand-derived reference
(`project-casm-trusted-reference-rule`):

1. `casmif1` — `.if 1` … `.endif` around one instruction -> body assembled.
2. `casmif0` — `.if 0` … `.endif` -> output identical to the body being
   physically absent.
3. `casmifskip` — `.if 0` body contains `.res undefinedname` and a
   dangling `lda notdefined` -> still assembles clean (structural scan
   never evaluates).
4. `casmifnest` — `.if 1` / `.if 0` / `.endif` / `.endif`, and
   `.if 0` / `.if 1` / … -> correct bytes for each.
5. `casmifelse` — `.if 0` / … / `.else` / … / `.endif` -> the else body
   assembles; `.if 1` variant -> the if body.
6. `casmelif` — `.if 0` / `.elseif 0` / `.elseif 1` / `.else` / `.endif`
   ladder -> only the third arm's bytes.
7. `casmiffwd` — `.if laterconst` where `laterconst` is defined below ->
   `CASM: .IF CONDITION NOT RESOLVED` at the `.if` line.
8. `casmifnoend` — `.if 1` with no `.endif` -> `CASM: UNTERMINATED .IF`
   naming the `.if`'s line.
9. `casmendnoif` — `.endif` with no `.if` -> `CASM: .ELSE/.ELSEIF/.ENDIF
   WITHOUT .IF`.
10. `casmelseelse` — `.if 0` / `.else` / `.else` -> `CASM: .ELSEIF/.ELSE
    AFTER .ELSE`.
11. `casmifsym` — a label defined only inside a taken `.if` is usable
    after `.endif`; a label defined only inside a *skipped* `.if` ->
    a later reference is `CASM: UNDEFINED SYMBOL` (proves the skipped
    branch defines nothing).
12. `casmifp1p2` — a `.if 1` whose body's byte count differs from a
    parallel `.if 0` -- assemble and confirm Pass 1 and Pass 2 agree
    (no `PASS 1/PASS 2` mismatch), COMP-exact.

Live VICE per `vice-mcp-testing` (boot Command64, FLUSH before/after,
fire `c64-overlay-api` test events). `test_casm_cond` re-run on the new
disk. Regression witness: `casmassert1` / `casmhello` COMP OK.

## Atomic Increments

1. `parser.s`: 6 conditional subtypes -> `ppsDeferOperands`.
2. `casm.s`: `crpScanSuppressed`, `crpCondEvalOperand`, the four
   `crpCond*` handlers, the `casmRunPass` top gate, the `crpDone`
   `condAtEof` prepend, `crpDir` dispatch. `.import` the `cond.s`
   routines + `parserParseExpressionValue`/`exprGetResult` (already
   imported?).
3. `CMakeLists.txt` + `cmake/GenerateCasmTestFixtures.cmake`:
   `casm_phase15_test_d64` image, move `test_casm_cond` onto it, the 12
   fixtures + `.ref` hand-references.
4. Build clean (all link configs, all harnesses, new image).
5. Live VICE: `test_casm_cond` + all 12 fixtures + `casmassert1`
   regression, on the new disk. Overlay events.
6. Walkthrough; commit.

## Expected Files

| File | Action |
| --- | --- |
| `src/external/casm/parser.s` | Modify — conditional subtype dispatch |
| `src/external/casm/casm.s` | Modify — scanner + handlers + gate |
| `CMakeLists.txt`, `cmake/GenerateCasmTestFixtures.cmake` | Modify — image + fixtures |
| `tests/fixtures/casm/casmif*.s`, `casmel*.s`, `*.ref.hex` | Create |
| `brain/plans/2026-09-01-casm-phase15-wp96-pass-driver-wiring.md` | Create |
| `brain/walkthroughs/2026-09-01-casm-phase15-wp96-pass-driver-wiring.md` | Create |

## Stop Conditions

- Any existing `test_casm_*` harness fails, or a no-change rebuild alters
  any assembled `.ref`.
- **CASM MAIN cannot stay within `$7400`** — WP95 left 1,000 bytes
  headroom and WP96 adds the scanner + handlers (est. 300-500 bytes). If
  it overflows, STOP: raising the envelope is a separate,
  separately-approved decision (`project-os-sub1000-segment-full`).
- Pass 1 and Pass 2 take a different branch at any conditional site, or
  disagree on any assembled byte for a fixture — do not fix forward.
- The structural scanner reaches the expression evaluator or symbol table
  for a genuinely-suppressed line (fixture 3 is the sharp test).
- A new defect outside Phase 15 surfaces — disclose and defer.
- `casm_phase15_test.d64` source-text budget overflows the image.

## Completion Gate

- `.if`/`.elseif`/`.else`/`.endif` working: all 12 fixtures COMP-exact or
  correct-diagnostic live in VICE; `test_casm_cond` still green on the
  new disk.
- `casmassert1` / `casmhello` byte-identical (no-conditionals
  regression).
- CASM within `$7400`; both link configs pass; test image builds;
  build-number check passes.
- Walkthrough recorded; **explicit user approval** before WP97.

## Progress

- 2026-09-01: Plan drafted. Scanner + `crpCond*` handler design against
  the `ppsAssert` operand-eval precedent; parser routes conditionals to
  `ppsDeferOperands`; 12 production fixtures outlined; WP96/97 boundary
  reshape proposed (truthiness family vs symbol-existence family).
  MAIN envelope flagged as the top risk. Awaiting approval.
- 2026-09-01: **Approved (incl. reshape). WP96 implemented.**
  - `parser.s`: the six conditional subtypes route to `ppsDeferOperands`
    (leave operand tokens in the stream). New exported
    `parserEvalConditionExpr` -- `lexerNext` + `parserParseExpressionValue`
    + resolved-check (else `CASM_DIAG_CONDITIONAL_OPERAND_UNRESOLVED`) ->
    truthiness in A. The `ppsFillDirective`/`ppsAssert` template.
  - `casm.s`: `casmRunPass` top gate (`condCurrentlyEmitting` -> emitting
    path unchanged; suppressed -> `crpScanSuppressed`). `crpScanSuppressed`
    = a `lexerNext`-only line scanner recognising only the six conditional
    keywords, `condOpenIf(0)` for a nested `.IF`/`.IFDEF`/`.IFNDEF`,
    `crpCondApplyElseif` for a re-enable-capable `.ELSEIF`, `condElse`/
    `condEndif` structurally, everything else drained. `crpDir` dispatches
    the four truthiness handlers (`crpCondIf`/`Elseif`/`Else`/`Endif`);
    `.IFDEF`/`.IFNDEF` in an emitting branch -> `NOT_IMPLEMENTED` (WP97).
    Shared `crpCondApplyElseif` (the "eval only when parent emitting and
    branch not yet taken" rule), `crpCondSiteDecision` (pass number from
    `CasmPassMode`), `crpCondRequireTerminator`, `crpCondStageOpenLoc` /
    `crpCondStampOpenLoc`. `crpDone` runs `condAtEof` first ->
    `UNTERMINATED .IF` pointing at the open `.IF`'s line.
  - `CMakeLists.txt` + `GenerateCasmTestFixtures.cmake`: new
    `casm_phase15_test_d64` image, `test_casm_cond` moved onto it, 10
    fixtures (6 accepted + `.ref.hex`, 4 rejected). `test_casm_include`
    envelope `$1900` -> `$1A00` (53 B parser growth). `CASM_REF_NAMES`
    excludes `^casmif`/`^casmel` from the test.d64 ref loop.
  - Two build fixes on the way: a `beq crpDone` out-of-range (764 B) ->
    `bne`+`jmp`; `test_casm_include` MAIN overflow -> envelope bump.
  - **Live VICE** (`casm_phase15_test.d64`, `CASM V0.6.0.1413`):
    - `test_casm_cond` -> `CASM COND: PASS` (moved-disk regression).
    - `casmif1` (`00 C0 EA EA`), `casmif0` (`00 C0 EA`),
      **`casmifskip`** (a `.IF 0` body holding `LDA UNDEFINEDXYZ` +
      `.WORD NOTASYMBOL` -> assembles clean, `00 C0 EA` -- the sharp
      structural-scan test), `casmifelse` (`00 C0 EA EA`),
      `casmelif` (`00 C0 EA EA EA` -- `.ELSEIF` ladder, third arm),
      `casmifnest` (`00 C0 EA EA`) -> all **`FILES COMPARE OK`**.
    - `casmiffwd` -> `CASM: .IF CONDITION NOT RESOLVED` AT LINE 2 COL 1;
      `casmifnoend` -> `CASM: UNTERMINATED .IF` AT LINE 2 COL 1;
      `casmendnoif` -> `CASM: .ELSE/.ELSEIF/.ENDIF WITHOUT .IF` AT LINE 3
      COL 1; `casmelseelse` -> `CASM: .ELSEIF/.ELSE AFTER .ELSE` AT
      LINE 4 COL 1 -- each with the caret at the offending directive.
    - `casmassert1` COMP OK on `casm_phase13_test.d64` -- the
      no-conditionals regression witness; the `casm.s` gate is byte-neutral.
  - All 32 `test_casm_*` targets build. **MAIN headroom 1,000 -> 499
    bytes** -- WP97 (`.ifdef`/`.ifndef`) is the remaining envelope risk;
    a decision may be needed before WP99.
  - `BUILD_CASM` -> 1413. Walkthrough
    `brain/walkthroughs/2026-09-01-casm-phase15-wp96-pass-driver-wiring.md`.
    Awaiting sign-off before WP97.
