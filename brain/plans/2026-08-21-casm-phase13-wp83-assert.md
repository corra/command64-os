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

**Approved 2026-08-21.** All four Scoping Decisions confirmed (see below).
Implementation authorized on `feature/casm-phase13-wp83`.

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

Proposed: `.ASSERT`'s expression is treated as **false only when it
resolves to exactly `0`**, true for any other resolved value (matches
ca65's own `.assert` semantics and is the obvious reading of "expression
check"). No separate boolean/comparison-operator requirement — `.ASSERT
symbol = value` already works today because `=` is an existing expression
operator producing `0`/`1`, not new grammar. **Confirmed.**

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

New (if Decision 2 = (b) or the message operand is accepted at all,
which every option requires syntactically) `lexerScanAssertMessage`,
covering only the quoted-string half of `lexerScanIncludeOperand`'s
structure (leading whitespace after the comma, opening quote, printable-
PETSCII payload, closing quote, trailing whitespace/comment, terminator)
— no filename-specific semantics to inherit, so this is a narrower
routine than `lexerScanIncludeOperand`/`lexerScanIncbinOperand`, not a
copy of either.

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
3. **Message scanner**: `lexerScanAssertMessage` (quoted-string half
   only, per Technical Design above).
4. **Parser dispatch**: `ppsAssert`, expr + strict-resolution check +
   optional message staging.
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
