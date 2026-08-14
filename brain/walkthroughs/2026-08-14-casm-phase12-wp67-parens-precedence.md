# Walkthrough: CASM Phase 12 WP67 — Parentheses and Explicit Precedence

Plan: `brain/plans/2026-08-14-casm-phase12-wp67-parens-precedence.md`
(approved 2026-08-14, including all three confirmed Scoping Decisions).
Prerequisite: WP64 (contract freeze), complete. Branch:
`feature/casm-phase12-wp65` (WP67 implemented on the same branch as
WP65/66; not yet merged to `casm-phase12`/`main`).

## What Shipped

- A precedence-climbing evaluator architecture (`expr.s`), replacing the
  flat single-addend parser: `exprEvaluate` (extraction prefix, then hands
  off), `parsePrimary` (`NUMBER`/`IDENTIFIER`/`*`/`(group)`), and
  `parseOperatorTail` (the `+`/`-` loop, recursing into `parsePrimary` for
  each RHS — including a parenthesized group, which itself recurses into
  the same pair for its own content).
- Parenthesized sub-expressions, bounded to 8 nesting levels
  (`CASM_EXPR_PAREN_MAX_DEPTH`), each level costing a `JSR` against the
  6502's hardware stack — `CASM_DIAG_EXPR_PAREN_TOO_DEEP` beyond that.
- WP64's relocation representability rule enforced per operator
  application for the first time: combining two relocatable values is
  `CASM_DIAG_EXPR_RELOC_UNSUPPORTED`.
- The pre-existing restriction that only `IDENTIFIER`/`*` primaries could
  take a trailing addend is lifted (user-confirmed 2026-08-14) — `NUMBER`
  now reaches the same operator loop, so `1+1` succeeds.
- `ppsConstant` (named-constant RHS) stays on its own separate, unchanged
  grammar (user-confirmed scoping decision, matching WP65/66's precedent).

## Real Findings, Not Assumed Correct

The plan's own Atomic Increments structure (baseline first, architecture
change proven byte-identical before adding parens, audit before shipping)
existed specifically to catch problems before they compound. It worked:

1. **Increment 3 surfaced a real, previously-unflagged design fork
   mid-implementation.** The plan's own `1+(2+3)` example assumed NUMBER
   would support operators, but the existing restriction (predating
   WP67) had two fixtures (`sNumAdd`/`sNumSub`) asserting the opposite
   diagnostic. Asked and user-confirmed rather than silently picked
   either way: lift the restriction, updating those two fixtures'
   expected outcome deliberately.
2. **A real bug caught by the plan's own byte-for-byte reproduction
   requirement.** An early draft of `parseOperatorTail` called `lexerNext`
   an extra time after combining each operator's RHS — a leftover from
   copying the old `exprParseAddend`-based tail's own convention, which
   didn't apply once `parsePrimary` (unlike `exprParseAddend`) already
   advances past its own token internally. Caught immediately by
   Increment 3's own live test run before it could compound into the
   parenthesization work.
3. **A real integration gap Increment 7's live VICE run caught that no
   amount of static reading had surfaced.** `parser.s`'s `posImmediate`
   gate — checked *before* `parserParseExpressionValue` (and therefore
   `exprEvaluate`) ever runs — whitelisted only `NUMBER`/`IDENTIFIER`/
   `LESS`/`GREATER` after `#`. The very first live run of
   `casmparen1.s` (`lda #<(screenw+2)`) produced `CASM: SYNTAX ERROR`,
   not because `exprEvaluate`'s own primary dispatch was wrong, but
   because it was never reached. Fixed with one new whitelist entry.
4. **Two new diagnostics silently had no message text.** Live use of
   `CASM_DIAG_EXPR_RELOC_UNSUPPORTED` and `CASM_DIAG_EXPR_PAREN_TOO_DEEP`
   revealed neither had an entry in `diagnostics.s`'s message dispatch —
   both would have fallen through to the generic "unknown diagnostic"
   fallback. Fixed with two new message-table entries, confirmed live.
5. **A live "regression" that bisection proved was not a code defect.**
   Immediately after implementation, `test_casm_listcap` started failing
   5 of 7 fixtures live under VICE. Rather than guessing, this was
   bisected properly: the pre-WP67 `expr.s`/`parser.s`/`common.inc` was
   checked out via `git show`, built and linked in complete isolation
   (`/tmp`, never touching the working tree), and tested against every
   source/binary combination (old+old, new+old, old+new, new+new) — all
   passed in isolation. The real production PRG, tested on a freshly
   hand-built disk with the same fixtures, also passed. Only the *real*
   `casm_listing_test.d64`, freshly rebuilt via `cmake --build`, failed —
   and its own directory listing showed **0 free blocks**. WP67's
   cumulative envelope growth across `test_casm_pass1`/`frame`/`listcap`/
   `passcheck` had consumed all build-time headroom, leaving nothing for
   `test_casm_listcap`'s own 10 runtime output-file writes
   (`CASMLO01`-`10`) during live execution. Not a source defect at all —
   resolved by relocating `test_casm_bounds`/`test_casm_cliderive`/
   `test_casm_lexer` (26 blocks, genuinely self-contained, unlike
   `test_casm_spanread`/`spancommit` which need companion `.seq` fixtures
   on whichever disk they live on) to `casm_include_test_d64` (208 free
   blocks), restoring 30 free blocks of headroom.

## Live VICE Evidence

Both new fixtures run against the real `casm.prg` (build 1296) via
`casm_include_test.d64`, Command64 shell dispatch (`casm <name>.s`), per
`.agents/workflows/vice-mcp-testing.md`:

- **`casmparen1.s`** (`.ORG $C000`; `screenw = 40`; `lda #<(screenw+2)`;
  `lda #(1+2)`; `jmp start`): `CASM: INPUT VALIDATED`. Extracted
  `casmparen1.prg` directly from the disk image (after a clean VICE
  detach to flush the write-behind cache) and confirmed its bytes
  exactly: `A9 2A 8D 20 D0 A9 03 8D 21 D0 4C 00 C0` — `LDA #$2A`
  (`<(42)`, correct), `STA $D020`, `LDA #$03` (`(1+2)`, correct),
  `STA $D021`, `JMP $C000` (`start`, correct).
- **`casmparen2.s`** (no `.ORG` — default relocatable output; `lbl1:`;
  `nop`; `lbl2:`; `nop`; `lda #<(lbl1+lbl2)` — two relocatable labels
  combined): `CASM: EXPRESSION RELOCATION UNSUPPORTED AT LINE 5, COL 17
  (OFFSET 16)` with the source-context caret pointing exactly at the
  second label reference (`lbl2`). Confirms both the diagnostic and its
  new message text/location context.

Regression evidence (every harness this WP's shared-module growth or
disk relocations could plausibly affect, re-run live after the fix):
`test_casm_expr` (extended to 55 cases, 10 new) → `CASM EXPR: PASS`;
`test_casm_symbols` → `CASM SYMBOLS: PASS`; `test_casm_pass1` → `CASM
PASS1: PASS`; `test_casm_include` → `CASM INCLUDE: ALL PASS`;
`test_casm_frame` → `CASM FRAME: PASS`; `test_casm_listcap` → `CASM
LISTCAP: PASS`; `test_casm_passcheck` → `CASM PASSCHECK: PASS`;
`test_casm_bounds` → `CASM BOUNDS: PASS`; `test_casm_cliderive` → `CASM
CLIDERIVE: PASS`; `test_casm_lexer` → `CASM LEXER: PASS`. All returned
cleanly to the Command64 shell prompt.

Full disk-image tree (`image_d64`, `test_image_d64`,
`command64_casm_utils_d64`, `casm_overflow_test_d64`,
`casm_include_test_d64`, `casm_listing_test_d64`, `casm_phase10_test_d64`,
`casm_opcode_test_d64`) rebuilds with zero errors and zero envelope
overflows as of the final commit.

## Harness/Workflow Notes

Diagnosing the disk-capacity "regression" required building and testing
the pre-WP67 source in complete isolation from the working tree — done
entirely under `/tmp`, using `git show <commit>:<path>` to extract old
file versions, direct `ca65`/`ld65` invocations (each wrapped in a manual
overlay build event per this project's own convention for direct tool
calls that bypass `cmake --build`), and hand-built diagnostic disk images
via `cc1541`/`c1541`. No working-tree file was touched or reverted during
this process. The scratch directory was removed once the diagnosis
completed.

## Stop Conditions Checked

- Increment 2 reproduced Increment 1's baseline exactly before parens
  were added (verified live, not assumed).
- The nesting-depth bound (8) was not re-derived against a measured stack
  budget beyond the design-time estimate — no live stack-exhaustion
  symptom was observed at 8 levels in testing; revisit if WP68's own
  operators materially increase per-level stack cost.
- The `$6000` production envelope held without a bump.
- No no-change rebuild changed any artifact.
- The apparent regression (disk capacity) was fully bisected before
  concluding root cause, not assumed to be either "code bug" or
  "unrelated flake" — disclosed as found.

## Documentation and Tracker Sync

- `brain/KNOWLEDGE.md`: new WP67 as-built section recorded, immediately
  after WP66's own section.
- `brain/task.md`, `wiki/tasks/casm.md`: completion entries recorded.
- `docs/casm-utility.md`/`wiki/casm-utility.md` (kept byte-identical):
  expression grammar section updated for chained operators and
  parentheses; named-constant section clarified that its own RHS grammar
  is unchanged and narrower.
- `wiki/casm-programmers-reference.md`: §11 (Expression Evaluator)
  rewritten to describe the new three-proc architecture, the hardware-
  stack save/restore convention, and the relocation-representability
  enforcement — superseding WP66's own update, which still described the
  flat evaluator.
- `CHANGELOG.md`: entry added under `[Unreleased]` → `Added`.
- Taskwarrior task (`8d988ac6-730a-440a-bc6e-a12e0c36888d`) marked done.

## Outcome

**WP67 complete, pending final user approval.** All 7 Atomic Increments
implemented and verified. Two real integration gaps and one live "false
regression" were found and resolved during implementation, each disclosed
as found rather than assumed away — the disk-capacity issue in particular
required a full bisection against the pre-WP67 source before concluding
root cause, exactly the kind of verification this project's own testing
convention exists to enforce. WP68 (arithmetic and bitwise operators) is
next and requires its own detailed plan and separate approval before any
source edit, per `.agents/workflows/phased-implementation-planning.md`.
