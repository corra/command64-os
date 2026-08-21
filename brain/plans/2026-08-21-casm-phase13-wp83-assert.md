---
feature: casm-phase13-wp83-assert
created: 2026-08-21
status: proposed
taskwarrior: 4611cf63-b963-4463-822d-42b68b9b571d (task "WP83: .ASSERT directive", project casm.phase13)
depends-on: CASM Phase 13 WP82 (.INCBIN), complete on feature/casm-phase13-wp82
  (brain/walkthroughs/2026-08-21-casm-phase13-wp82-incbin.md), pending merge
  into feature/casm-phase13
---

# Plan: CASM Phase 13 WP83 - .ASSERT

## Status

**Complete.** Approved 2026-08-21 on `feature/casm-phase13-wp83`. See the
completion walkthrough:
`brain/walkthroughs/2026-08-21-casm-phase13-wp83-assert.md`.

Parent plan: `brain/plans/2026-08-21-casm-phase13-data-construction-
directives.md`. Branch: `feature/casm-phase13-wp83`, to be cut from
`feature/casm-phase13` once WP82 is merged into it.

## Objective

Add `.ASSERT expr[, "message"]`: a compile-time expression check with no
byte emission. If `expr` resolves to zero (false) in either pass, assembly
fails with a new diagnostic — printing the optional user-supplied message
if present, otherwise a generic "ASSERTION FAILED" diagnostic. Does
**not** deliver DASH adoption (WP84) or `.STATIC`/`.RELOC` (out of Phase 13
scope).

**Risk gate**, mirroring WP81/WP82's own: `.ASSERT` touches no
emission/relocation machinery at all (Research Summary point 7 in the
master plan) — genuinely the lowest-risk WP of the three directive WPs.
The real risk is narrower: getting the "expr, optional comma, quoted
string" hybrid grammar right (a shape with no existing precedent in CASM,
per research below) and deciding how much new diagnostics-module work a
user-supplied message string actually needs.

## Research Summary

A pre-planning research pass (this session, 2026-08-21) traced the
current directive/diagnostic/expression infrastructure as it stands after
WP81/WP82:

1. **Current directive constants** (`common.inc`): `CASM_DIRECTIVE_RES` =
   `$07`, `FILL` = `$08`, `ALIGN` = `$09`, `INCBIN` = `$0A`,
   `CASM_DIRECTIVE_COUNT` = `$0B`, validated by `.assert
   CASM_DIRECTIVE_COUNT = CASM_DIRECTIVE_INCBIN + 1`. `.ASSERT` becomes
   `$0B`; `CASM_DIRECTIVE_COUNT` bumps to `$0C`.
2. **Lexer dispatch** (`lexer.s:865-975`, string table `~1541-1544`):
   `lnDirective` is a linear `compareTokenText`/`bcs @notX`/fallthrough
   chain. `.ASSERT` gets the same shape as every prior entry: a new
   `dirAssertStr` constant and a `@notIncbin`→`@notAssert` block inserted
   before the final `CASM_DIRECTIVE_UNKNOWN` fallback.
3. **No existing directive parses "expr, optional comma, quoted string."**
   The two existing shapes are disjoint and neither fits directly:
   - `ppsFillDirective` (`parser.s:309-425`, WP81) parses `expr [',' expr]`
     where *both* operands are numeric expressions via
     `parserParseExpressionValue`, gated by checking
     `CasmTokenRecord+CASM_TOKEN_REC_TYPE == CASM_TOKEN_COMMA`.
   - `ppsInclude`/`ppsIncbin` (`parser.s:268-303`, `lexer.s:373/551`) each
     just hand the *entire* operand to a dedicated lexer scanner
     (`lexerScanIncludeOperand`/`lexerScanIncbinOperand`) that consumes a
     quoted filename and its trailer in one shot — no expression parsing
     at all.
   `.ASSERT` needs a genuine hybrid: `parserParseExpressionValue` for
   `expr` (reusing WP81's exact resolved-check pattern, point 4 below),
   then a comma check, then — only if a comma is present — a *new* scanner
   for the quoted message half (mirroring the quoted-string half of
   `lexerScanIncludeOperand`, not the whole thing, since there's no
   filename-specific validation to inherit).
4. **`parserParseExpressionValue` resolution check** (`parser.s:1138`,
   used at `348`/`384` by WP81): `jsr exprGetResult` → read
   `CASM_EXPR_FLAGS` → `and #CASM_EXPR_FLAG_RESOLVED` (`common.inc:1068`,
   `%00000001`) → diagnose if unset. `.ASSERT`'s own strict-resolution
   requirement (Scoping Decision 1 below) follows this exact pattern
   verbatim, with its own diagnostic instead of reusing WP81's
   `CASM_DIAG_RES_FILL_ALIGN_UNRESOLVED`.
5. **Diagnostics**: current last sentinel `CASM_DIAG_PHASE13_WP82_LAST`
   = `CASM_DIAG_INCBIN_FILENAME_TOO_LONG` = `$51` (`common.inc:819`,
   asserted `891`). WP83's block starts at `$52`. **No existing CASM
   diagnostic prints a user-supplied string** — every `.INCLUDE`/`.INCBIN`
   filename diagnostic is a fixed message; the filename itself is never
   echoed back. Printing `.ASSERT`'s optional message on failure is
   genuinely new diagnostics-module capability, not a reuse of an existing
   path (Scoping Decision 2 below).
6. **`emitDirective` dispatch** (`emit.s:343-399`): a `cmp`/`beq` chain,
   each real case a `jmp emitX`, ending in `.STATIC`/`.RELOC` returning
   `CASM_DIAG_NOT_IMPLEMENTED`. **No existing directive emits zero
   bytes** — even `.ORG` writes the PRG load-address header on first use;
   `.STATIC`/`.RELOC` aren't real no-op handlers, just immediate
   not-implemented stubs. `emitAssert` is the first genuine
   "runs full logic, emits nothing" handler. Its success path (`clc; rts`
   with no `emitByte` calls at all) needs an explicit check against
   `crpListingCommit` (`casm.s ~655-665`) confirming a zero-byte statement
   commits cleanly — flagged as an implementation-time check, not assumed.
7. **Pass-agnostic check-and-fail precedent**: `emitCheckPassAgreement`
   (`emit.s:192`) is a *whole-assembly*, once-at-Pass-2-end check
   (`CasmPc` vs `CasmPass1FinalPc`), not a per-statement pattern —
   doesn't directly apply. The real precedent is structural instead:
   every non-`.INCLUDE` directive (via `casmRunPass`'s `crpDir`/
   `crpEmitDir` path, `casm.s:645-665`) already executes `emitDirective`
   identically in both passes, unconditionally, with no pass-number
   branching inside the handler itself. `.ASSERT`'s "fail if false in
   either pass" requirement is therefore **free** — it just needs to
   require full resolution (Scoping Decision 1, same as WP81) rather than
   tolerate a Pass-1 placeholder; the existing two-pass re-execution loop
   does the rest. No new `emitCheckPassAgreement`-style plumbing needed.

## Scoping Decisions (user-confirmed 2026-08-21)

### Decision 1: strict resolution, same as WP81's `.RES`/`.FILL`/`.ALIGN`?

`.ASSERT`'s expression must be evaluable to a real true/false answer in
both passes — a `.ASSERT` that only resolves in Pass 2 (e.g. checks a
forward-referenced symbol) would silently pass Pass 1 with a placeholder
value, defeating the point of a compile-time check. Proposed: **same
strict rule as WP81** — `CASM_EXPR_FLAG_RESOLVED` required in *both*
passes; an unresolved operand is a new diagnostic
(`CASM_DIAG_ASSERT_UNRESOLVED`), not tolerated. **Confirmed.**

### Decision 2: how much custom-message printing is actually delivered?

No existing diagnostic path echoes a user-supplied string. Three options,
increasing in cost:

- **(a) No message printing at all.** `.ASSERT expr, "message"` parses
  and stores the message, but a failure always prints a fixed generic
  diagnostic (`CASM: ASSERTION FAILED`) regardless of whether a message
  was given. Cheapest — the message operand exists syntactically (so
  DASH's own real use case, `DISPATCHRETURN`'s one-byte invariant, reads
  naturally) but its text is inert. Diverges from the master plan's own
  wording ("optional message") in that the message is accepted but never
  shown.
- **(b) Minimal message echo.** A new diagnostic-printing primitive that
  copies the message's raw bytes (already PETSCII, no translation needed)
  into the diagnostic output stream verbatim after a fixed prefix (e.g.
  `CASM: ASSERTION FAILED: <message>`), reusing whatever low-level
  "print string from a buffer" routine `diagnostics.s` already has for
  fixed messages, just pointed at the staged message buffer instead of a
  literal. Genuinely new wiring, but small — no new formatting, truncation
  handling matches the existing fixed-length message-buffer convention
  (mirrors `CasmIncludeFilename`/`CASM_INCLUDE_FILENAME_BUFFER_SIZE`'s own
  65-byte precedent).
- **(c) Something richer** (e.g. distinguishing message-present vs.
  message-absent diagnostic IDs, multi-line formatting) — not proposed;
  flagged only in case the user wants it.

**Confirmed: (b)** — matches the master plan's literal wording
("optional message") and DASH's real WP84 use case
(`DISPATCHRETURNMINUSONE`/`DISPATCHRETURN` invariant) benefits from an
actual echoed message, not a generic one. This is the single largest
new-capability item in this WP.

### Decision 3: truthiness rule for the expression

`.ASSERT`'s expression is treated as **false only when it resolves to
exactly `0`**, true for any other resolved value (matches ca65's own
`.assert` semantics and is the obvious reading of "expression check").
**Confirmed.**

**Correction (found during Increment 5 implementation, 2026-08-21):** this
plan originally claimed `.ASSERT symbol = value` "already works today
because `=` is an existing expression operator producing `0`/`1`" — that
claim was wrong, not verified against `expr.s` before writing it.
`parseOperatorTail` (`expr.s:509-560`) only classifies
`+ - | ^ & << >> * /` as binary operators; `CASM_TOKEN_EQUALS` is used
exclusively at the *statement* level for named-constant definitions
(`identifier = expr`, WP65), never inside an expression. `CASM_TOKEN_LESS`/
`GREATER` are the `<`/`>` byte-extraction prefixes (low/high byte of a
label), not comparison operators either (confirmed via their only other
call sites, `parser.s`'s addend-extraction grammar).

**Consequence, confirmed with the user 2026-08-21:** CASM's expression
grammar has no equality/comparison operator at all, so `.ASSERT` can only
usefully express **nonzero-arithmetic** truthiness checks (a pointer/
size/flag is nonzero) — it cannot express an equality or alignment
invariant (`a = b`, `(addr & $FF) = 0`) the way ca65's own `.assert`
commonly is used, including the master plan's own cited DASH target
(`DISPATCHRETURN` must be exactly one byte past
`DISPATCHRETURNMINUSONE`). **Decision: ship `.ASSERT` with nonzero-only
truthiness as originally scoped (no new expression syntax); a real
comparison operator is deferred as a separate, separately-planned
follow-up** (it would expand Phase 12's frozen expression grammar
project-wide, not just for `.ASSERT`), not fixed inline in this WP. WP84
(DASH adoption) will need to find genuinely nonzero-truthy target sites,
restate its planned equality checks some other way, or skip sites that
need true equality — to be resolved when WP84 itself is planned, not
here.

### Decision 4: message buffer size

Proposed: reuse `CASM_INCLUDE_FILENAME_BUFFER_SIZE`'s exact precedent (65
bytes: 64-byte payload + null/length byte) for the new
`CasmAssertMessage`/`CasmAssertMessageLen` staging fields, with a new
`CASM_DIAG_ASSERT_MESSAGE_TOO_LONG` diagnostic on overflow — consistent
sizing across all of Phase 13's quoted-string operands rather than
picking a new number. **Confirmed.**

## Language Contract

```
directive-stmt ::= '.ASSERT' expr [',' STRING]
```

- `expr` is the existing bounded expression grammar (Phase 12's named
  constants, `*`, parens, operators) — no new expression syntax.
- `expr` must fully resolve (`CASM_EXPR_FLAG_RESOLVED`) in **both**
  passes (Decision 1) — an unresolved operand is a diagnostic error, not
  a Pass-1-tolerated placeholder.
- The optional message is a quoted string, same printable-PETSCII-byte
  restriction as `.INCLUDE`/`.INCBIN`'s filename scanner.
- `.ASSERT` emits **zero bytes** in both passes, on both success and
  failure (failure aborts assembly via the normal diagnostic-error path,
  same as any other diagnosed statement).
- `.ASSERT` never calls `emitMarkStarted` — unlike `.RES`/`.BYTE`/an
  instruction, it has no byte-emission side effect, so it cannot be "the
  first statement" of a relocatable assembly in any meaningful sense.
  (Confirm at implementation time whether `emitMarkStarted`'s absence
  needs an explicit carve-out anywhere, or is simply a non-issue since
  `.ASSERT` just never calls it.)
- No relocation interaction whatsoever (no bytes emitted, so no
  `relocRecord` call is even possible).

## Technical Design

### Directive constant (`common.inc`)

```
CASM_DIRECTIVE_ASSERT = $0B
CASM_DIRECTIVE_COUNT  = $0C
```
Update `.assert CASM_DIRECTIVE_COUNT = CASM_DIRECTIVE_INCBIN + 1` to
`= CASM_DIRECTIVE_ASSERT + 1`.

### Lexer (`lexer.s`)

New `dirAssertStr` constant (`.byte ".ASSERT", 0`) and a
`compareTokenText`/`lexerEmitWithSubtype` block appended to
`lnDirective`'s chain, before the final `CASM_DIRECTIVE_UNKNOWN`
fallback (same shape as every prior directive there).

**Decision 5 (added during implementation, user-confirmed 2026-08-21): no
new scanner.** The lexer already has a general quoted-string token type,
`lnString`/`CASM_TOKEN_STRING` (WP74, added for `.BYTE "string"` literals)
— dispatched automatically by the main `lexerNext` byte-dispatch table
whenever the next raw byte is a quote, in any normal token-scanning
position (`lexer.s:189-190`, `lnStringJmp`). Since `ppsAssert`'s message
operand is scanned via an ordinary `lexerNext` call after the comma (not
a directive-adjacent raw-byte scan like `.INCLUDE`/`.INCBIN`'s filename,
which must run *before* normal tokenization resumes), it gets `lnString`
for free: same printable-PETSCII payload rule, same
`CASM_DIAG_STRING_UNTERMINATED`/`CASM_DIAG_STRING_INVALID_BYTE`
diagnostics, into the existing `CasmStringBuffer`/`CasmStringLength`
(255-byte capacity, `CASM_STRING_BUFFER_SIZE`). No `lexerScanAssertMessage`
routine, no new filename-style diagnostics for the message grammar.
`ppsAssert` (Parser section below) copies `CasmStringBuffer`'s bytes into
its own `CasmAssertMessage` buffer immediately after recognizing
`CASM_TOKEN_STRING`, rather than relying on the shared scratch surviving
until `emitAssert` runs later — same reasoning as WP81's own
dedicated-scratch precedent (`CasmFillCountLo/Hi`/`CasmFillValue`, not a
reused `CasmParserStmt.Val*`).

### Parser (`parser.s`)

New `ppsAssert`, dispatched from `ppsMnemonic` for the new subtype:

1. `parserParseExpressionValue` for `expr`.
2. Check `CASM_EXPR_FLAG_RESOLVED` explicitly (Decision 1); diagnose
   `CASM_DIAG_ASSERT_UNRESOLVED` if unset in either pass.
3. Stage the resolved value into a new scratch field (or reuse
   `CasmConstantValueLo/Hi`-style scratch, TBD at implementation,
   mirroring WP81's own "TBD at implementation" note for its count/value
   staging).
4. If next token is `COMMA`: consume it, call the new message scanner,
   stage into `CasmAssertMessage`/`CasmAssertMessageLen` (Decision 4).
   If next token is not `COMMA`: no message, `CasmAssertMessageLen = 0`
   sentinel for "no message given."
5. Require `NEWLINE`/`EOF` terminator via an explicit `jmp` to the
   terminator check at every exit path (no fall-through — WP77's own
   incident, cited in WP81's plan, is the reason for this convention).

### Emission (`emit.s`)

New `emitAssert`, dispatched from `emitDirective`:

1. No `emitMarkStarted` call (Language Contract above).
2. Compare the staged resolved value against `0`.
3. If nonzero: `clc; rts` (success, zero bytes emitted, statement
   completes normally).
4. If zero: diagnose. If `CasmAssertMessageLen == 0`: generic
   `CASM_DIAG_ASSERTION_FAILED`. Else (Decision 2 = (b)): a message-
   printing diagnostic path that echoes `CasmAssertMessage`'s bytes —
   exact new diagnostics.s primitive TBD at implementation, this is the
   single largest open item in this WP per Decision 2's own framing.

### Diagnostics (`common.inc`)

New contiguous block starting at `CASM_DIAG_PHASE13_WP82_LAST + 1`
(`$52`):

- `CASM_DIAG_ASSERT_UNRESOLVED` — expression didn't resolve in this pass
  (Decision 1).
- `CASM_DIAG_ASSERT_MESSAGE_TOO_LONG` — message exceeds the buffer bound
  (Decision 4, only if a message operand is present at all).
- `CASM_DIAG_ASSERTION_FAILED` — expression resolved to `0`, no message
  given.
- (Decision 2 = (b) only) whatever new identifier the message-echo path
  needs — TBD whether this reuses `CASM_DIAG_ASSERTION_FAILED`'s ID with
  a different print routine, or needs its own ID. Decide at
  implementation time once the diagnostics.s primitive shape is clear.
- `CASM_DIAG_PHASE13_WP83_LAST` sentinel, plus the matching `.assert`
  chain entries.

## Atomic Increments

1. **Contract freeze**: `CASM_DIRECTIVE_ASSERT` constant, the new
   diagnostic block, `.assert` chain updates. No behavior change yet.
2. **Lexer recognition**: `.ASSERT` token recognition in `lnDirective`.
3. **Message scanner**: none needed (Decision 5) — reuses the existing
   `lnString`/`CASM_TOKEN_STRING` tokenizer. This increment becomes a
   no-op on `lexer.s`; folded into Increment 4's parser work.
4. **Parser dispatch**: `ppsAssert`, expr + strict-resolution check +
   optional message staging (calls `lexerNext` after the comma, checks
   for `CASM_TOKEN_STRING`, copies `CasmStringBuffer` into
   `CasmAssertMessage`/`Len`).
5. **Emission — no-message path**: `emitAssert`'s zero/nonzero check and
   `CASM_DIAG_ASSERTION_FAILED` path first (simplest end-to-end slice).
   First fixtures here: a passing `.ASSERT 1 = 1` (or similar
   always-true) and a failing `.ASSERT 0` fixture, both without a message
   operand.
6. **Emission — message path** (Decision 2 = (b)): the new
   diagnostics.s message-echo primitive, wired into `emitAssert`'s
   failure branch. Fixture: a failing `.ASSERT 0, "custom message"`,
   live-verified that the custom text actually appears in VICE's error
   output.
7. **Unresolved-operand diagnostic fixture**: `.ASSERT` against a
   forward-referenced symbol that can't resolve in Pass 1, confirming
   `CASM_DIAG_ASSERT_UNRESOLVED` fires (not a silent Pass-1 pass-through).
8. **Regression**: existing CASM test suite re-run clean
   (`test_casm_expr`, `test_casm_pass1`, `test_casm_frame`, matching
   WP81/WP82's own regression witnesses).
9. **Envelope check**: measure CASM's actual size; negotiate a bump if
   the current ceiling (post-WP82) is exceeded — expected, per every
   prior WP this Phase.
10. **Consolidated live-VICE verification + walkthrough**: every new
    fixture plus a clean regression run, recorded in
    `brain/walkthroughs/`, submitted for user sign-off.

## Expected Files

| File | Planned action |
| --- | --- |
| `src/external/casm/common.inc` | Modify (directive constant, diagnostics) |
| `src/external/casm/lexer.s` | Modify (token recognition, new message scanner) |
| `src/external/casm/parser.s` | Modify (new `ppsAssert`) |
| `src/external/casm/emit.s` | Modify (new `emitAssert`) |
| `src/external/casm/diagnostics.s` (or equivalent) | Modify (new message-echo printing primitive, Decision 2 = (b) only) |
| `cmake/GenerateCasmTestFixtures.cmake` | Modify (new fixtures) |
| `tests/fixtures/casm/*.ref.hex` | Create (hand-derived trusted references for the passing-assert cases; failing cases verify diagnostics, not byte output) |
| `CMakeLists.txt` | Modify (fixture/reference registration, likely reusing `casm_phase13_test_d64`) |
| `tests/src/casm_assert/casm_assert.s` (if an isolation harness is warranted — TBD at increment-planning time, mirroring WP81's `test_casm_directives` precedent more than WP82's "skipped as unnecessary" outcome, since `.ASSERT`'s diagnostics-path is new enough to want direct proof independent of the lexer/parser) | Create |

## Stop Conditions

- Any harness/test fails unexpectedly, including a currently-passing
  fixture regressing after this WP's changes.
- The envelope bump needs approval before proceeding past it.
- A no-change rebuild changes any artifact.
- A genuinely new defect is discovered outside this WP's own scope:
  disclose and defer as a separate follow-up (default), do not fix inline
  unless explicitly directed in the moment.
- Any of Decisions 1-4 above turns out to need revisiting once real
  implementation work starts: pause and confirm before deviating.

## Documentation, Task, and DOX Updates

- Taskwarrior: WP83 task created under the Phase 13 parent on approval of
  this plan.
- `wiki/tasks/casm.md`/`brain/task.md`: WP83 entry, updated at completion.
- No `CHANGELOG.md`/`KNOWLEDGE.md` update yet — those land with WP85.

## Completion Gate

- `.ASSERT` live-verified in VICE: correct pass-through for a true
  expression, correct diagnostic (generic and message-bearing, per
  Decision 2) for a false expression, correct diagnostic for an
  unresolved operand.
- Native/COMP production fixtures (the passing cases) byte-exact against
  hand-derived references (zero bytes emitted, so this mainly confirms
  no accidental byte leakage).
- Full existing CASM regression suite clean, no regressions.
- No-change rebuild confirmed stable.
- Envelope bump (if any) explicitly approved, not silently absorbed.
- Walkthrough recorded in `brain/walkthroughs/`.
- User explicitly approves closing WP83.

## Progress

- 2026-08-21: Plan drafted after researching current directive/diagnostic/
  expression infrastructure post-WP82 (directive constants, lexer dispatch
  shape, the two existing-but-disjoint parser grammars neither of which
  fits `.ASSERT`'s "expr, optional comma, quoted string" hybrid shape,
  `parserParseExpressionValue`'s resolution-check pattern, current
  diagnostic sentinel `$51`, and confirmation that the two-pass structural
  loop already gives `.ASSERT` "fail in either pass" for free). Four
  Scoping Decisions drafted for confirmation.
- 2026-08-21: All four Scoping Decisions confirmed by the user: (1) strict
  both-pass resolution mirroring WP81, (2) minimal message echo (option
  b), (3) zero-is-false truthiness, (4) 65-byte message buffer mirroring
  the `.INCLUDE`/`.INCBIN` filename precedent. Plan approved. Branch
  `feature/casm-phase13-wp83` cut from `feature/casm-phase13` (WP82 merged
  in first). Taskwarrior task created (project `casm.phase13`, `+wp83`).
- 2026-08-21: Increment 1 (contract freeze) complete: `CASM_DIRECTIVE_ASSERT`
  = `$0B` added, `CASM_DIRECTIVE_COUNT` bumped to `$0C`; new diagnostic
  block `CASM_DIAG_ASSERT_UNRESOLVED`/`_MESSAGE_TOO_LONG`/
  `CASM_DIAG_ASSERTION_FAILED` ($52-$54) added with matching `.assert`
  chain entries; `CASM_DIAG_PHASE13_WP83_LAST` sentinel added. No behavior
  change — build is clean, all `.assert` range checks pass, no-change
  rebuild confirmed stable (second build produced no work). Message-buffer
  BSS staging (`CasmAssertMessage`/`Len`) deferred to Increment 4
  (parser dispatch), per the plan's own increment split.
- 2026-08-21: Increment 2 (lexer recognition) complete: new `dirAssertStr`
  constant and a `@notIncbin`→`@notAssert` block appended to
  `lnDirective`'s chain (`lexer.s`), same shape as every prior directive
  there. Build clean, no-change rebuild stable. No standalone lexer-only
  live check performed — `test_casm_lexer` is narrowly scoped to
  identifier-length boundary testing, not general directive tokenization,
  and no isolation harness for directive-token classification exists
  (checked). Following WP81's own precedent (its Progress log records
  Increments 1-3 together), live verification that `.ASSERT` classifies
  correctly is deferred to Increment 5's first end-to-end fixture, where a
  wrong subtype would surface immediately as a parser dispatch failure.
- 2026-08-21: Increment 3 (message scanner) revised mid-implementation:
  discovered the lexer already has a general quoted-string token type
  (`lnString`/`CASM_TOKEN_STRING`, WP74's `.BYTE "string"` support)
  dispatched automatically by the main `lexerNext` table on any leading
  quote in normal token position. Confirmed with the user (Decision 5) to
  reuse it rather than write a new `lexerScanAssertMessage` — no
  `lexer.s` change needed for this increment; the buffer-copy work moves
  into Increment 4. No code changed in this increment.
- 2026-08-21: Increment 4 (parser dispatch) complete: new
  `CASM_ASSERT_MESSAGE_MAX`/`_BUFFER_SIZE` constants (`common.inc`,
  mirroring `CASM_INCLUDE_FILENAME_MAX`/`_BUFFER_SIZE` exactly);
  `CasmAssertValueLo/Hi`/`CasmAssertMessage`/`CasmAssertMessageLen` staging
  fields and `ppsAssert` added to `parser.s`, dispatched from
  `ppsMnemonic`. `ppsAssert` parses the expression via
  `parserParseExpressionValue`, requires `CASM_EXPR_FLAG_RESOLVED` (Decision
  1), and — if a comma follows — calls `lexerNext` again to land on the
  existing `lnString`/`CASM_TOKEN_STRING` tokenizer (Decision 5), copying
  `CasmStringBuffer` into `CasmAssertMessage` with its own
  `CASM_DIAG_ASSERT_MESSAGE_TOO_LONG` cap check. Envelope overflowed
  `$6A00` by 59 measured bytes (the new BSS staging fields); bumped to
  `$6B00` (+256, smallest round-page fit, 197 bytes headroom),
  user-approved 2026-08-21. Build clean, no-change rebuild stable.
  `emitDirective` has no `CASM_DIRECTIVE_ASSERT` case yet (Increment 5), so
  `.ASSERT` currently falls through cleanly to the existing
  `.STATIC`/`.RELOC` `CASM_DIAG_NOT_IMPLEMENTED` catch-all — confirmed safe,
  no crash risk. No fixtures added this increment (none planned until
  Increment 5's first end-to-end slice).
- 2026-08-21: Increment 5 (no-message emission path) complete. `emitAssert`
  (`emit.s`) dispatched from `emitDirective`: compares `CasmAssertValueLo/
  Hi` against zero, `clc; rts` on nonzero (no `emitMarkStarted`, no bytes),
  diagnoses `CASM_DIAG_ASSERTION_FAILED` on zero. `diagnostics.s` gained the
  WP83 dispatch range-check block and `diagWp83MessageLo/Hi` message table
  for all three WP83 diagnostics (`ASSERT_UNRESOLVED`/`_MESSAGE_TOO_LONG`/
  `ASSERTION_FAILED`) — while wiring this in, `diagPrintFatal`'s very first
  branch (`bcc dpfMainRange`) fell out of 6502 branch range from the new
  block's own size, the same class of hazard WP81's own comment already
  flags for this function; fixed with a `bcs`/`jmp` inversion, no logic
  change.
  Two production fixtures added (`casmassert1.seq`/`.ref.hex`,
  `casmassertfail.seq`), packaged on `casm_phase13_test_d64`:
  `casmassert1` (`.ASSERT 1` then `.BYTE $AA`) is COMP-verified byte-exact,
  proving zero-byte emission on success; `casmassertfail` (`.ASSERT 0`, no
  message) is live-diagnosed for the generic failure text.
  **Real defect found and corrected while drafting these fixtures**: the
  original plan's Decision 3 claimed `.ASSERT symbol = value` already
  worked because `=` was "an existing expression operator producing 0/1" —
  false, not verified before writing it. `expr.s`'s `parseOperatorTail`
  only classifies `+ - | ^ & << >> * /`; `CASM_TOKEN_EQUALS` is exclusively
  the *statement*-level named-constant assignment (`identifier = expr`,
  WP65), and `CASM_TOKEN_LESS`/`GREATER` are the `<`/`>` byte-extraction
  prefixes, not comparisons. CASM's expression grammar has **no
  equality/comparison operator at all**, so `.ASSERT` can only usefully
  test nonzero-arithmetic truthiness — it cannot express an equality or
  alignment invariant (the master plan's own cited DASH
  `DISPATCHRETURN`/`DISPATCHRETURNMINUSONE` use case included). Confirmed
  with the user: ship `.ASSERT` nonzero-only as originally scoped (no new
  expression syntax this WP); a real comparison operator is deferred as a
  separate, separately-planned follow-up, to be resolved when WP84 (DASH
  adoption) is itself planned. Fixtures were rewritten to use plain
  nonzero/zero literals instead of the originally-drafted (invalid)
  equality form.
  Five envelope bumps, all user-approved: `casm` `$6A00`→`$6B00` (already
  recorded, Increment 4); `test_casm_pass1` `$6200`→`$6300` (+256, 166-byte
  overflow); `test_casm_frame` `$6100`→`$6300` (+512, 286-byte overflow,
  exceeded a single page); `test_casm_listcap` `$6600`→`$6700` (+256,
  210-byte overflow); `test_casm_passcheck` `$5E00`→`$5F00` (+256,
  180-byte overflow); `test_casm_include` `$1800`→`$1900` (+256, 54-byte
  overflow, this WP's own lexer recognition from Increment 2).
  `test_casm_passcheck` also retripped the recurring `expr.s`
  `jmp (CasmExprResolverAddrLo)` page-boundary hazard (WP46/WP54/WP82's own
  prior occurrences); `CasmExprResolverAddrPad` widened 3→4 bytes,
  user-approved, same mechanical fix as every prior occurrence.
  `test_casm_bounds` and `test_casm_directives` (WP81's isolation harness)
  each needed a one-byte `CasmAssertValueLo`/`CasmAssertValueHi` stand-in
  pair, same precedent as their existing `CasmFillCountLo/Hi`/
  `CasmIncbinFilename` stand-ins — `emit.s` links whole in both, so the new
  `emitAssert` import pulled these in even though neither harness
  dispatches `.ASSERT`.
  **Disk-full blocker, resolved with the user**: `test_casm_frame`'s own
  envelope bump grew its PRG enough that `casm_listing_test.d64` (which it
  shared with several other harnesses) hit 0 free blocks, live-confirmed
  (`casmfrr2.seq` failed to write). Relocated `test_casm_frame` and its own
  `casmfrp1-4`/`casmfrc1-3`/`casmfrcr1`/`casmfrr1-2` fixtures to
  `casm_phase13_test_d64` (469 free blocks before the move, 345 after) —
  same "move the largest occupant off a full disk" precedent this project
  has used before (WP52, WP67, WP53 increment 4's original move of
  `test_casm_frame` onto that disk in the first place).
  A full clean rebuild from scratch (`rm -rf build && cmake -B build &&
  cmake --build build`) completed with zero errors, zero overflows, zero
  unresolved externals; a subsequent no-op `cmake --build build` re-ran
  only disk-packaging POST_BUILD steps (this project's existing, known
  non-idempotent packaging behavior — not a regression) with no
  compile/link work and no errors.
  Live-VICE evidence: `casmassert1.s` → `comp casmassert1.prg
  casmassert1.ref` → `FILES COMPARE OK`. `casmassertfail.s` → `CASM:
  ASSERTION FAILED` at line 1, col 1 (offset 0), correct caret context.
  Regression witnesses re-run fresh on the rebuilt binaries:
  `test_casm_frame` → `CASM FRAME: PASS`; `test_casm_expr` → `CASM EXPR:
  PASS`; `test_casm_pass1` → `CASM PASS1: PASS`. (VICE crashed once,
  unprompted, mid-session during a disk-attach call between the frame and
  expr/pass1 runs — a fresh instance was started per the workflow's
  one-clean-restart allowance, Command64 reboot and regression re-run from
  scratch confirmed identical results.)
- 2026-08-21: Increment 6 (message-echo diagnostic path) complete.
  `diagnostics.s`'s `dpfWp83Check` gained a carve-out: `CASM_DIAG_
  ASSERTION_FAILED` with `CasmAssertMessageLen != 0` prints a new
  `msgAssertionFailedPrefix` ("CASM: ASSERTION FAILED: ", no trailing CR)
  followed by `CasmAssertMessage` itself (now null-terminated by
  `ppsAssert`'s copy loop) and a one-byte `msgCrOnly` line terminator,
  before falling into the normal `diagPrintSourceContext` call — the
  no-message case is unchanged, reusing the existing table-driven
  generic path. No new "print a runtime buffer" primitive was needed:
  `diagPrintString`/`DOS_PRINT_STR` already prints whatever null-terminated
  buffer X/Y point at, whether a ROM literal or `CasmAssertMessage`'s RAM
  contents.
  Wiring this in tripped the *same* branch-range hazard as Increment 5's
  own `dpfNotMain` fix (WP81's own comment already flags `diagPrintFatal`
  as prone to this): `dpfNotMain`'s `bcc dpfListingRange` fell out of
  range from the new carve-out's size; fixed with the same `bcs`/`jmp`
  inversion, no logic change.
  New fixture: `casmassertmsg.seq` (`.ASSERT 0, "CUSTOM MESSAGE"`),
  packaged on `casm_phase13_test_d64`. Live-VICE confirmed the full output
  line-by-line: `CASM: ASSERTION FAILED: custom message` (the echoed text
  renders lowercase per this project's usual raw-PETSCII-source display
  convention, matching every other runtime-read string in this codebase —
  not a defect), then `AT LINE 1, COL 1 (OFFSET 0)`, then the caret-context
  line `.assert 0, "custom message"` with the caret under column 1, then a
  clean `c64[8]:>` return.
  Two envelope bumps, user-approved: `casm` `$6B00`→`$6C00` (+256, 25-byte
  overflow); `test_casm_listcap` `$6700`→`$6800` (+256, 25-byte overflow).
  `test_casm_faultsource` and `test_casm_spanread` each needed a new
  one-byte `CasmAssertMessage`/`CasmAssertMessageLen` stand-in pair (same
  precedent as Increment 5's `test_casm_bounds`/`test_casm_directives`
  stand-ins) — `diagnostics.s` links whole in both and its new import
  pulled these in even though neither harness raises `.ASSERT`
  diagnostics.
  A full clean rebuild from scratch completed with zero errors, zero
  overflows, zero unresolved externals; a subsequent no-op build re-ran
  only the known non-idempotent disk-packaging steps. Regression witnesses
  (`test_casm_frame`/`test_casm_expr`/`test_casm_pass1`) re-run live in
  VICE against this final build, all PASS.
- 2026-08-21: Increment 7 (unresolved-operand diagnostic fixture)
  complete. New `casmassertfwd.seq` (`.ASSERT COUNT` / `COUNT = 5`,
  mirroring WP81's `casmresfwd.seq` precedent exactly) packaged on
  `casm_phase13_test_d64`. No code change was needed — `ppsAssert`'s
  strict `CASM_EXPR_FLAG_RESOLVED` check (Increment 4) already covers
  this case. Live-VICE confirmed: `CASM: ASSERT OPERAND NOT RESOLVED` at
  `AT LINE 1, COL 9 (OFFSET 8)` (exactly where `COUNT` begins, after
  `.ASSERT ` — 8 characters), correct caret-context line (`.assert
  count`), clean `c64[8]:>` return. Confirms Scoping Decision 1: a
  forward reference is rejected outright in Pass 1, not silently
  tolerated as a placeholder the way an ordinary instruction operand
  would be.
- 2026-08-21: Increments 8 (regression) and 9 (envelope check) confirmed
  already satisfied by the incremental work above — Increment 7 made no
  code change, so Increment 6's fresh live-VICE regression pass
  (`test_casm_expr`/`test_casm_pass1`/`test_casm_frame`, all PASS) still
  holds against the current build; a follow-up `cmake --build build`
  confirmed zero errors/overflows/unresolved externals. Every envelope
  bump this WP needed was measured and user-approved at the point it
  occurred (Increments 4, 5, 6), not deferred to a single end-of-WP
  negotiation. Proceeding to Increment 10 (consolidated verification +
  walkthrough).
- 2026-08-21: Increment 10 complete. Completion-gate walkthrough drafted
  at `brain/walkthroughs/2026-08-21-casm-phase13-wp83-assert.md`.
  `wiki/tasks/casm.md` and `brain/task.md` updated with WP83's summary.
  Awaiting explicit user sign-off to close WP83.
