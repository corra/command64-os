# Walkthrough: CASM Phase 12 WP69 — Character Literals

Plan: `brain/plans/2026-08-15-casm-phase12-wp69-character-literals.md`
(approved 2026-08-15, including both confirmed Scoping Decisions).
Prerequisite: WP64 (contract freeze), complete; WP68 (arithmetic/bitwise
operators, the last dependency-spine WP before WP69), complete and
user-approved 2026-08-15. Branch: `feature/casm-phase12-wp65` (WP69
implemented on the same branch as WP65-68; not yet merged to
`casm-phase12`/`main`).

## What Shipped

- A new token, `CASM_TOKEN_CHAR` (`'x'`), the last token WP64's contract
  freeze reserved but never implemented (`brain/plans/2026-08-13-casm-
  phase12-wp64-contract-freeze.md` line 91).
- A single literal PETSCII byte between quotes, taken verbatim (no
  escapes, no case folding) — `'''` (a literal quote as content) works
  without any special-casing, since the lexer's rule is mechanically
  "one content byte, then a closing quote," regardless of what that byte
  is. An empty `''` literal reports the same `CASM_DIAG_CHAR_
  UNTERMINATED` as a genuinely unterminated one, deliberately not
  special-cased.
- Two new diagnostics, `$47`/`$48` (`CASM_DIAG_CHAR_UNTERMINATED`/
  `CHAR_INVALID_BYTE`), the last two of WP64's reserved Phase 12
  diagnostic range.
- Usable **only** as a whole immediate operand or a whole `.BYTE` list
  entry — a deliberate, narrower restriction than every other Phase 12
  primitive (WP66's `*`, WP68's operators): never combinable with an
  operator, never in `.WORD`, never as a bare (non-immediate) instruction
  operand, never on a named constant's own RHS.
- Because of that restriction, `expr.s` needed **zero changes** —
  `CASM_TOKEN_CHAR` never reaches `exprEvaluate`/`parsePrimary`.
  `posImmediate` (`parser.s`) and `emitByteList` (`emit.s`) each gained a
  direct short-circuit reading `CasmTokenText[0]`.
- Production `casm` cap `$6100` → `$6200`; three test-harness caps bumped
  the same round-page step. CASM promoted `0.2.3` → `0.2.4`.

## Real Findings, Not Assumed Correct

1. **A genuine 6502 branch-range overflow, not a design defect**
   (Atomic Step 2). Adding `lnChar`'s dispatch check pushed `lnAngle`'s
   two `beq` sites out of short-branch range — the dispatch region was
   already tight from WP68's own additions. Fixed with an `lnAngleJmp`
   trampoline, the same indirection `lnHexJmp`/`lnBinJmp` already use.
   Caught immediately by the compiler (`Range error (132 not in
   [-128..127])`), not discovered live.
2. **The design assumption that `ppsConstant`/`emitWordList` need no
   change was verified, not assumed** (Atomic Step 1, before writing any
   code): traced `ppsConstant`'s `@primary` dispatch (`parser.s`) and
   confirmed it only recognizes `NUMBER`/`IDENTIFIER`/`STAR` — anything
   else, including `CASM_TOKEN_CHAR`, falls to `CASM_DIAG_EXPR_MALFORMED`
   with zero code change required. Same confirmation for `emitWordList`.
3. **`casmcharinvalid.s` (17 characters) silently truncated** on the
   first disk-packaging build, losing its `.s` suffix — the identical
   mistake WP68 Increment 7 already found once for `casmarithreloc1`/`2`.
   Caught before any live testing (comparing the packaged directory
   listing against the intended fixture set), not discovered live under
   VICE. Renamed to `casmcharinval.s` (15 characters).
4. **A stale doc claim corrected by live evidence, not by inspection
   alone**: `wiki/casm-programmers-reference.md` previously stated
   `BYTE` is emitted only for `CASM_DIAG_INVALID_SOURCE_BYTE`. Live
   testing of `casmcharunterm.s` printed `AT LINE 1, COL 8 (OFFSET 7)
   BYTE $00` — confirming `BYTE` is emitted for *any*
   `diagSetLocFromLookahead`-raised diagnostic, not just that one. Doc
   corrected.
5. **Two production envelope overflows, disclosed and approved before
   raising either cap** (not silently absorbed): `casm` overflowed
   `$6100` by 235 measured bytes once the full feature (lexer + parser +
   emitter integration) was complete; three test harnesses
   (`test_casm_pass1`/`frame`/`listcap`) overflowed their own caps by
   150/69/249 bytes respectively from the same shared-module growth.
   Both rounds of cap increases were measured, disclosed, and
   user-approved separately, matching this project's established
   practice — not requested piecemeal per source-file edit.

## Live Evidence (VICE 3.10)

- **`casmchar1.s`** (`.ORG $C000; LDA #'A'; .BYTE 'H','I'`) →
  `CASM: INPUT VALIDATED`; `comp cchar1.prg casmchar1.ref` → `FILES
  COMPARE OK` — the `posImmediateChar`/`emitByteList` short-circuit path
  is byte-exact correct.
- **`casmcharbare.s`** (`LDA 'A'`) → `CASM: SYNTAX ERROR AT LINE 1, COL 5
  (OFFSET 4)`, echoed `lda 'a` with caret — confirms the excluded
  bare-operand context is rejected by `parseOperandSequence`'s own
  whitelist (which deliberately never gained `CASM_TOKEN_CHAR`), not
  just by design.
- **`casmcharunterm.s`** (`LDA #'A`, no closing quote) → `CASM:
  CHARACTER LITERAL UNTERMINATED AT LINE 1, COL 8 (OFFSET 7) BYTE $00`.
- **`casmcharinval.s`** (`LDA #'` + a raw `$01` control byte + `'`) →
  `CASM: CHARACTER LITERAL INVALID BYTE AT LINE 1, COL 7 (OFFSET 6) BYTE
  $01`.
- **`test_casm_lexer`** re-run (4 new character-literal cases plus every
  pre-existing case) → `CASM LEXER: PASS`.
- **`test_casm_expr`** re-run (unaffected — confirms `expr.s` truly
  untouched) → `CASM EXPR: PASS` (all 97 dots).
- **Version bump verification**: after promoting CASM to `0.2.4`, a
  fresh boot of the rebuilt `casm_phase12_test.d64` showed `CASM
  V0.2.4.1311` on the real banner, `casm.prg` unchanged in size (21,776
  bytes — the digit change didn't alter code size), and every other
  artifact byte-identical to the pre-bump build in a no-change rebuild.

A recurring VICE MCP keyboard-queue quirk (spurious `BAD COMMAND OR FILE
NAME` with a garbled command echo for `test_casm_lexer`/`test_casm_expr`,
both containing underscores) recurred during this WP too — resolved each
time with a `flush\n` immediately before retyping the command via the
segmented `vice_keyboard_petscii` underscore technique already documented
in `.agents/workflows/vice-mcp-testing.md`. Not a product defect; not
investigated further.

## Envelope

Production `casm`: `$6100` → `$6200` (235 measured bytes over $6100).
`test_casm_pass1`/`test_casm_frame`: `$5900` → `$5A00` (150/69 bytes).
`test_casm_listcap`: `$5D00` → `$5E00` (249 bytes). `test_casm_passcheck`
($5B00) absorbed the growth without needing a bump. All four the
smallest round-page (+256) step, user-approved 2026-08-15.

`casm_phase12_test_d64` ended WP69 at 441 free blocks (comfortably above
its `>=40` gate). `image_d64`/`test_image_d64`/`casm_listing_test_d64`
all shrank slightly (317/18/7 free, down from 318/21/11) from the larger
`casm.prg`/`test_casm_lexer.prg` consuming more disk blocks when
packaged — none hit zero and every build succeeded, but
`casm_listing_test_d64` at 7 free blocks is now tight enough to flag as a
watch item: the next WP touching these shared modules should consider
relocating a harness off it before it runs out, the same capacity crunch
WP67 already resolved once for this exact disk. Not itself a defect or a
Stop Condition trigger this WP (nothing failed), just a disclosed
observation for whoever picks up WP70.

## Stop Conditions Checked

- Atomic Step 1's audit confirmed every design assumption (token/
  diagnostic numbering, `ppsConstant`/`emitWordList` needing no change,
  the `posImmediate`/`.BYTE` dispatch shapes) before any code was
  written — no correction needed.
- Every forbidden-form fixture raised the correct diagnostic at the
  correct location; the success fixture byte-exact-matched its
  hand-derived reference.
- Both envelope overflows were measured, disclosed, and user-approved
  before either cap was raised — not silently absorbed.
- No no-change rebuild changed any artifact or build counter, at any
  point in this WP including after the final version bump.
- The one genuinely new defect encountered (the branch-range overflow)
  was root-caused and fixed inline as a mechanical consequence of this
  WP's own change, not a pre-existing latent gap requiring separate
  disclosure/approval — matching the same class of fix WP68 made for
  `lnHexJmp`/`lnBinJmp`-style trampolines.

## Documentation and Tracker Sync

- `brain/KNOWLEDGE.md`: new WP69 as-built section recorded, immediately
  after WP68's own section.
- `brain/task.md`, `wiki/tasks/casm.md`: completion entries recorded
  alongside this walkthrough.
- `docs/casm-utility.md`/`wiki/casm-utility.md` (kept byte-identical): new
  "Character Literals" section with lowercase examples, showing both the
  valid forms and every excluded context.
- `wiki/casm-programmers-reference.md`: §9 (Lexer) token table and
  scanning-rules table extended for `CASM_TOKEN_CHAR`/`lnChar`; §10
  (Parser) gained a note on the `posImmediate`/`.BYTE` short-circuit and
  why `ppsConstant`/`emitWordList` are untouched; §19 (Diagnostic
  Reference) table extended with `$47`/`$48`; the stale `BYTE`-suffix
  claim in §18.1 corrected per the live finding above.
- `CHANGELOG.md`: entry added under `[Unreleased]` → `Added`.
- CASM version promoted `0.2.3` → `0.2.4`, live-verified on the real
  banner (`CASM V0.2.4.1311`).
- Taskwarrior task 44 to be marked done alongside this walkthrough's
  approval.

## Outcome

**WP69 complete, pending final user approval.** All five Atomic Steps
implemented and verified. Both confirmed Scoping Decisions (no escapes;
restricted to immediate/`.BYTE` contexts, not a general expression
primary) held throughout implementation with no need to revisit either.
One genuinely new defect (a branch-range overflow) was found and fixed as
a direct, disclosed consequence of this WP's own change. `expr.s` was
confirmed unchanged, exactly as designed. This is the last of Phase 12's
dependency-spine-adjacent syntax WPs (WP65/66/67/68/69 all now complete);
WP70 (relocation algebra closure — consolidated verification that every
operator/operand combination WP65-69 actually shipped matches WP64's
representability contract) is next and requires its own detailed plan
and separate approval before any implementation.
