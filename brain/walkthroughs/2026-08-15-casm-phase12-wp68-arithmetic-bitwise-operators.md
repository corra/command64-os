# Walkthrough: CASM Phase 12 WP68 — Arithmetic and Bitwise Operators

Plan: `brain/plans/2026-08-14-casm-phase12-wp68-arithmetic-bitwise-operators.md`
(nine Atomic Increments; Increments 6, 7, 8, and 9 each have their own
detailed, user-approved subordinate plan). Prerequisite: WP67
(parentheses and explicit precedence), complete. Branch:
`feature/casm-phase12-wp65` (WP68 implemented on the same branch as
WP65-67; not yet merged to `casm-phase12`/`main`).

## What Shipped

- The last operator group WP64's frozen contract reserved: `*`, `/`,
  `<<`, `>>`, `&`, `^`, `|`, unary `-`, unary `~` — nine new tokens
  (`common.inc`/`lexer.s`, `CASM_TOKEN_COUNT` now `$19`).
- WP67's flat `+`/`-` `parseOperatorTail` generalized to real 7-tier
  precedence climbing (tightest to loosest: unary `-`/`~`; `*`/`/`;
  `<<`/`>>`; `&`; `^`; `|`; `+`/`-`), reproducing every pre-WP68
  expression result byte/message/location-identical before any new
  operator was enabled.
- `&`/`^`/`|` as plain `AND`/`EOR`/`ORA`; `*`/`/` as bounded unsigned
  16-bit software routines (`mulUnsigned16`/`divUnsigned16`); `<<`/`>>`
  bounded to a 0-15 count, `>>` logical (zero-filling, not
  arithmetic/sign-extending); unary `-`/`~` always producing a full
  16-bit result. A new diagnostic, `CASM_DIAG_EXPR_DIV_ZERO` (`$44`,
  WP64's third and last reserved Phase 12 code) for a static divisor of
  zero, checked before any division arithmetic.
- WP64's relocation-representability rule (already enforced generically
  by WP67) verified to hold for every new operator, both for a real
  label and for a label-derived named constant.
- Six new production `.seq`/`.ref.hex` fixture pairs on
  `casm_phase12_test_d64` proving the real `parser.s`/`emit.s`/`casm.s`
  pipeline, not just the synthetic `test_casm_expr` harness: `casmarith2`/
  `casmarithfwd`/`casmareloc1`/`casmareloc2` (Increment 7),
  `casmarith3`/`casmdivzero` (Increment 9).
- CASM promoted `0.2.2` → `0.2.3`.

## Real Findings, Not Assumed Correct

The plan's own increment structure (baseline first, architecture change
proven byte-identical before adding operators, per-operand-context
integration only after the synthetic harness closed, consolidated
envelope verification before the final live pass) existed specifically to
catch problems before they compound. It worked:

1. **A real production-pipeline gap, found live, not by static reading**
   (Increment 7). `parser.s` has two operand-entry token whitelists
   gating which token may *start* a non-implied operand — the outer
   `parseOperandSequence` dispatcher and `posImmediate`'s own inner one —
   both checked *before* `parserParseExpressionValue` (and therefore
   `exprEvaluate`) ever runs. Neither had gained `CASM_TOKEN_MINUS`/
   `TILDE`, so `LDA #-1`-shaped operand forms failed `CASM_DIAG_
   SYNTAX_ERROR` before `exprEvaluate`'s own already-correct primary
   dispatch was ever reached — the identical bug class WP67 already fixed
   once for a leading `(`. The same audit found `CASM_TOKEN_STAR`
   (WP66's current-address symbol) had the identical gap since WP66, not
   introduced by WP68. Disclosed and user-approved before either fix
   landed; both whitelists fixed in the same pass.
2. **A fixture-design mistake correctly distinguished from a production
   defect** (Increment 7). After the parser fix above, `LDA #-1` then
   failed `CASM: OPERAND OUT OF RANGE`. Traced to `ofRequire8Bit`: unary
   `-` always yields a full 16-bit two's-complement result, and any
   nonzero result therefore carries a nonzero high byte — correctly
   rejected for an 8-bit immediate operand, the same rule any other
   `>255` literal already hits. Corrected the fixture (`LDA #~$FF00` for
   immediate context, `LDA -1` — absolute, no `#` — to exercise unary
   `-` as an instruction operand instead), not the source.
3. **`CASM_DIAG_EXPR_DIV_ZERO` had never been proven live through the
   real production pipeline** until Increment 9 — only through the
   synthetic `test_casm_expr` harness (Increment 6). `common.inc`'s own
   comment ("not yet raised anywhere") was stale as of Increment 6's
   wiring; Increment 9's `casmdivzero.seq` closed that gap, producing the
   exact expected message and source location on the real `casm.prg`.
4. **A VICE MCP harness-only quirk, not a product defect** (Increment 9).
   Several shell-dispatch attempts for `test_casm_expr`/`test_casm_lexer`
   returned spurious `BAD COMMAND OR FILE NAME` with a visibly garbled
   command echo. Resolved every time by a fresh `flush\n` immediately
   before retyping the command, per the existing recovery procedure in
   `.agents/workflows/vice-mcp-testing.md`. Not investigated further —
   out of this WP's scope, and the existing mitigation is sufficient.

## Live Evidence (VICE 3.10, consolidated across increments)

- **Increment 7**: `casmarith2.s` → `CASM: INPUT VALIDATED`; `comp
  carith2.prg casmarith2.ref` → `FILES COMPARE OK`. `casmarithfwd.s` →
  `CASM: INPUT VALIDATED`; `comp cfwd.prg casmarithfwd.ref` → `FILES
  COMPARE OK` — genuine two-pass Pass 1/Pass 2 `FORCE_ABS` width
  agreement for a forward-referenced named constant combined with a new
  operator, the same property `casmfa2p.ref.hex` established for a bare
  label (WP61 Increment 4). `casmareloc1.s` → `CASM: EXPRESSION
  RELOCATION UNSUPPORTED AT LINE 3, COL 12 (OFFSET 11)` (a real label).
  `casmareloc2.s` → the same diagnostic at `COL 16 (OFFSET 15)` (a
  label-derived `= *` named constant). `test_casm_expr` (97 dots, PASS)
  and `test_casm_lexer` (3 dots, PASS) both re-ran clean.
- **Increment 9**: `casmarith3.s` → `CASM: INPUT VALIDATED`; `comp
  carith3.prg casmarith3.ref` → `FILES COMPARE OK` — proves `/`, `^`,
  `|`, and a logical `>>` (`$8001>>1 = $4000`) through the real pipeline.
  `casmdivzero.s` → `CASM: EXPRESSION DIVISION BY ZERO AT LINE 1, COL 9
  (OFFSET 8)`, echoed source `lda #5/0` with caret — the first real
  end-to-end proof of `CASM_DIAG_EXPR_DIV_ZERO`. `test_casm_expr`
  (`CASM EXPR: PASS`) and `test_casm_lexer` (`CASM LEXER: PASS`) both
  re-ran clean after a `flush\n` recovery.
- **Version bump verification**: after promoting CASM to `0.2.3`
  (`casm.s`'s `VERSION_STAGE`), a fresh boot of the rebuilt
  `casm_phase12_test.d64` showed `CASM V0.2.3.1308` on the real banner —
  the version and build-counter bump landed as expected, with `casm.prg`
  unchanged in size (21,481 bytes — the digit change didn't alter code
  size) and every other artifact byte-identical to the pre-bump build in
  a no-change rebuild.

## Envelope

Production `casm` grew `$6000` → `$6100` (Increment 6, activating
`CASM_DIAG_EXPR_DIV_ZERO`'s message/dispatch plus the divisor-zero
check) — the only production cap change; held with 3,351 bytes of
headroom at Increment 8's consolidated final measurement, still true
after the version bump (`casm.prg` unchanged in size). Test harness caps:
`test_casm_expr` `$1600` → `$1700` (tightest surviving headroom, 158
bytes); `test_casm_lexer` unchanged at `$1000`; `test_casm_pass1`/`frame`
→ `$5900`; `test_casm_passcheck` → `$5B00`; `test_casm_listcap` →
`$5D00`. `casm_phase12_test_d64` (created in Increment 6 when
`test.d64`'s final free blocks ran out) ended WP68 at 449 free blocks,
comfortably above its own `>=40` gate. `image_d64` (318 free),
`test_image_d64` (21 free), and `casm_listing_test_d64` (11 free) all
confirmed unaffected across every increment's rebuild.

## Stop Conditions Checked

- Increment 3 reproduced Increment 1's baseline exactly before new
  operators were enabled (verified live, not assumed).
- The production `$6000` → `$6100` cap change was disclosed and
  user-approved, not silently raised.
- No no-change rebuild changed any artifact or build counter, at any
  increment boundary or after the final version bump.
- Every harness/test failure encountered (the parser dispatch gap, the
  `LDA #-1` fixture-design question) was root-caused and disclosed before
  any correction, not silently patched over.
- The two genuinely-new defects found (parser whitelist gaps for
  `MINUS`/`TILDE`/pre-existing `STAR`) were disclosed and user-approved
  before being fixed inline, per this plan's own Stop Conditions —
  neither was silently absorbed as "obviously in scope."

## Documentation and Tracker Sync

- `brain/KNOWLEDGE.md`: new WP68 as-built section recorded, immediately
  after WP67's own section.
- `brain/task.md`, `wiki/tasks/casm.md`: completion entries to be
  recorded alongside this walkthrough.
- `docs/casm-utility.md`/`wiki/casm-utility.md` (kept byte-identical): new
  "Expressions and Operators" section documenting the full operator
  table, precedence, unsigned-16-bit/shift-count/division-by-zero
  semantics, and the relocation-representability rule; removed the now-
  stale "multiplicative or parenthesized arithmetic not supported" bullet
  from "Not Yet Supported."
- `wiki/casm-programmers-reference.md`: §9 (Lexer) token table extended
  for all nine new tokens (plus the pre-existing but previously
  undocumented `EQUALS`/`STAR`); §10 (Parser) grammar and a new note on
  the operand-entry whitelist fix; §11 (Expression Evaluator) extended
  with the precedence table and each new operator's algorithm/diagnostic;
  §19 (Diagnostic Reference) table extended with `$43`-`$46` (previously
  entirely missing from this table since WP65).
- `CHANGELOG.md`: entry added under `[Unreleased]` → `Added`.
- CASM version promoted `0.2.2` → `0.2.3` (`VERSION_STAGE` in `casm.s`),
  live-verified on the real banner.
- Taskwarrior task 43 to be marked done alongside this walkthrough's
  approval.

## Outcome

**WP68 complete, pending final user approval.** All nine Atomic
Increments implemented and verified, four of them (6, 7, 8, 9) behind
their own detailed, user-approved subordinate plans. Every WP64-frozen
operator is now proven correct both algebraically (97-case synthetic
harness) and live through the real production pipeline. Two real,
in-scope defects were found and fixed (the parser operand-entry
whitelist gaps for `MINUS`/`TILDE`, plus the pre-existing WP66-era
`STAR` gap in the same code) — both disclosed and user-approved before
the fix, not silently absorbed. Phase 12 itself is **not** yet complete:
WP64's own contract freeze reserved a character-literal token (`'`) for a
separate WP69, still pending and out of this walkthrough's scope.
