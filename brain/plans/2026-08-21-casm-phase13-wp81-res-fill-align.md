---
feature: casm-phase13-wp81-res-fill-align
created: 2026-08-21
status: proposed
taskwarrior: TBD (created on approval)
depends-on: CASM Phase 13 master plan approval (brain/plans/2026-08-21-casm-phase13-data-construction-directives.md)
---

# Plan: CASM Phase 13 WP81 - .RES / .FILL / .ALIGN

## Status

**Complete.** Approved 2026-08-21 on `feature/casm-phase13-wp81`. See the
completion walkthrough:
`brain/walkthroughs/2026-08-21-casm-phase13-wp81-res-fill-align.md`.

Parent plan: `brain/plans/2026-08-21-casm-phase13-data-construction-
directives.md`. WP81 is the first work package; nothing depends on it
being complete before WP82/WP83 could theoretically start, but the
proposed order runs them sequentially (see parent plan's dependency spine).

## Objective

Add three new directives that share one implementation shape — "emit N
bytes of a computed value, computed identically in Pass 1 and Pass 2" —
to native CASM:

- `.RES count[, value]` — reserve `count` bytes, each set to `value`
  (default `0`).
- `.FILL count, value` — emit `count` bytes of `value` (required, no
  default — this is `.RES`'s only grammar difference).
- `.ALIGN boundary[, fill]` — pad with `fill` bytes (default `0`) until
  `CasmPc` is a multiple of `boundary`.

Does **not** deliver `.INCBIN` or `.ASSERT` (WP82/WP83), DASH adoption
(WP84), or `.STATIC`/`.RELOC` (explicitly out of Phase 13's scope per the
master plan's Scoping Decisions).

## Scoping Decisions (user-confirmed 2026-08-21, inherited from the master plan)

1. **Forward-referenced counts/boundaries are a diagnostic error**, not
   tolerated as a Pass-1 placeholder. `.RES`/`.FILL`/`.ALIGN`'s numeric
   operands must resolve fully in *both* passes; an operand referencing a
   symbol not yet resolvable at parse time in either pass fails with a new
   diagnostic (not the existing `parserParseExpressionValue`
   tolerate-in-MEASURE convention instruction operands use). This is a
   deliberate divergence from that shared helper's default behavior — see
   Technical Design below for exactly how.
2. **`.ALIGN`'s DASH-adoption requirement is waived** (no genuine DASH use
   case exists) — inherited from the master plan, not re-litigated here.
   `.RES`/`.FILL` *do* have real DASH targets, but their adoption happens
   in WP84, not this WP.

## Language Contract

Informal grammar extension (mirrors the style of Phase 12's own WP65/WP74
contract sections):

```
directive-stmt ::= '.RES' expr [',' expr]
                  | '.FILL' expr ',' expr
                  | '.ALIGN' expr [',' expr]
```

- Every `expr` is the existing bounded expression grammar (Phase 12's
  named constants, `*`, parens, operators — whatever `parserParseExpressionValue`
  already accepts). No new expression syntax.
- `.RES`'s second operand (fill value) is optional; omitted means `0`.
- `.FILL`'s second operand is **required** — `.FILL count` alone (no
  value) is a syntax error, not a `0`-default. This mirrors ca65's own
  distinction between the two directives and avoids `.FILL` silently
  behaving like `.RES` with no visible difference.
- `.ALIGN`'s second operand (fill byte) is optional; omitted means `0`.
- All operands must be a byte value (`0`-`255`) for the *value*/*fill*
  position, and a 16-bit value (`0`-`65535`) for *count*/*boundary*.
  `.ALIGN`'s boundary must additionally be `>= 1` (a `0` boundary is a
  divide-by-zero-equivalent error, diagnosed, not silently treated as
  no-op).
- `.ALIGN`'s boundary is **not** required to be a power of 2 (matches
  ca65's own `.align`, which computes plain `boundary - (addr mod
  boundary)`, not a bitmask) — simpler to implement and no real DASH/CASM
  use case needs the power-of-2 restriction.
- No relocation interaction for any of the three (Research Summary point
  4 in the parent plan): padding/reserved/filled bytes never call
  `relocRecord`, identical to a `.BYTE $00` byte today.

## Technical Design

### Directive constants (`common.inc`)

```
CASM_DIRECTIVE_RES   = $07
CASM_DIRECTIVE_FILL  = $08
CASM_DIRECTIVE_ALIGN = $09
CASM_DIRECTIVE_COUNT = $0A
```
(`.STATIC`=$05/`.RELOC`=$06 stay reserved-but-unimplemented, unchanged.)
Update the existing `.assert CASM_DIRECTIVE_COUNT = CASM_DIRECTIVE_RELOC + 1`
to instead chain off `CASM_DIRECTIVE_ALIGN` — the assert's job (catching an
accidental gap/duplicate) is unchanged, just extended.

### Lexer (`lexer.s`)

Three new `dirResStr`/`dirFillStr`/`dirAlignStr` constants and three new
`compareTokenText`/`lexerEmitWithSubtype` blocks appended to `lnDirective`'s
existing chain (same shape as every prior directive there), before the
final `CASM_DIRECTIVE_UNKNOWN` fallback.

### Parser (`parser.s`)

None of the three fit `parseOperandSequence` (single addressing-mode
operand) or `ppsDeferOperands` (arbitrary-length list, operand tokens left
for the emitter to walk) cleanly — they need exactly one or two bounded
expressions. New shared routine `ppsFillDirective` (name TBD at
implementation time), dispatched from `ppsMnemonic` for all three
subtypes, structured like `ppsConstant`'s own bounded two-operand grammar
(`parser.s:322-594`, `.res`/`. fill`/`.align`'s own precedent for "parse
first expr, optionally consume comma + second expr, require terminator"):

1. Call `parserParseExpressionValue` for the first operand (count for
   `.RES`/`.FILL`, boundary for `.ALIGN`).
2. **Diverge from `parserParseExpressionValue`'s own tolerate-unresolved
   convention here**: after the call, check `CASM_EXPR_FLAG_RESOLVED` (or
   equivalent) explicitly; if unset in *either* pass, fail with the new
   `CASM_DIAG_RES_FILL_ALIGN_UNRESOLVED`-family diagnostic (Scoping
   Decision 1) rather than letting Pass 1 silently accept a `$0000`
   placeholder.
3. If next token is `COMMA`: consume it, parse the second expr (value for
   `.RES`/`.FILL`, fill byte for `.ALIGN`) the same way; range-check as a
   byte (`0`-`255`), diagnosed if out of range.
4. If next token is not `COMMA`: for `.RES`/`.ALIGN`, default the second
   value to `0`; for `.FILL`, this is `CASM_DIAG_FILL_VALUE_REQUIRED`
   (Language Contract's required-second-operand rule).
5. Require `NEWLINE`/`EOF` terminator (same `@requireTerminator` shape
   `ppsConstant` uses — WP77's own bug was exactly a fall-through into the
   wrong terminator path, so this routine gets an explicit `jmp` to its
   terminator check at every exit, no fall-through, learning directly from
   that incident).
6. Stage the resolved count/boundary and value/fill into new
   `CasmParserStmt`-adjacent fields (or reuse `CasmConstantValueLo/Hi`-
   style scratch, TBD at implementation) for `emitDirective`'s handler to
   read.

### Emission (`emit.s`)

Three new handlers dispatched from `emitDirective`'s existing `cmp`/`beq`
chain:

- `emitRes`: loop `count` times, `lda value / jsr emitByte`, both passes
  (per the parent plan's Research Summary point 2 — no separate
  measure-only path, `emitRawByte`'s existing `CasmPassMode` gate handles
  Pass 1 discarding the write while `CasmPc` still advances for real).
  Calls `emitMarkStarted` first (a bare `.RES` can be a relocatable
  assembly's first statement, same as `.BYTE`/`.WORD`/an instruction).
- `emitFill`: identical loop, `value` always present (no default-path
  branch needed, unlike `.RES`).
- `emitAlign`: compute `padding = (boundary - (CasmPc mod boundary)) mod
  boundary` first (16-bit mod via existing arithmetic helpers, or a
  straightforward subtract-loop given boundary is expected to be small in
  practice — exact implementation TBD), then the same `fill`-byte loop for
  `padding` iterations. `padding` is recomputed fresh in each pass from
  that pass's own (by-construction-identical, per Scoping Decision 1)
  `CasmPc` — never cached/carried between passes.

### Diagnostics (`common.inc`)

New contiguous block starting at `CASM_DIAG_PHASE12_WP74_LAST + 1`
(`$4B`), following the existing `CASM_DIAG_PHASEn_LAST` sentinel
convention:

- `CASM_DIAG_RES_FILL_ALIGN_UNRESOLVED` — count/boundary operand didn't
  resolve in this pass (Scoping Decision 1).
- `CASM_DIAG_FILL_VALUE_REQUIRED` — `.FILL` with no second operand.
- `CASM_DIAG_VALUE_OUT_OF_RANGE` — value/fill operand doesn't fit in a
  byte (reuse `CASM_DIAG_OPERAND_OUT_OF_RANGE` if its existing semantics
  fit exactly; mint a new one only if a distinct message is warranted —
  decide at implementation time).
- `CASM_DIAG_ALIGN_BOUNDARY_ZERO` — `.ALIGN 0` (or a boundary that
  resolves to `0`).
- `CASM_DIAG_PHASE13_WP81_LAST` sentinel, plus the matching `.assert`
  chain entries.

`emitByte`'s own existing `CASM_DIAG_ADDRESS_OVERFLOW` check (triggered on
`CasmPc` wraparound) is reused automatically by the loop — no new overflow
diagnostic needed for "reservation runs past `$FFFF`".

## Atomic Increments

1. **Contract freeze**: add the three `CASM_DIRECTIVE_*` constants, the
   diagnostic block, and update the `.assert` chains in `common.inc`. No
   behavior change yet (constants unused). Build clean, no-change rebuild
   of everything else unaffected.
2. **Lexer recognition**: add `.RES`/`.FILL`/`.ALIGN` token recognition to
   `lnDirective`. Verify via a minimal fixture that the token classifies
   correctly (temporary/throwaway check, not a permanent fixture yet).
3. **`.RES` end-to-end**: parser grammar + `emitRes`, single-operand and
   two-operand forms, unresolved-operand diagnostic, out-of-range value
   diagnostic. First fixture(s) added here.
4. **`.FILL` end-to-end**: parser grammar (reusing WP81's shared routine)
   + `emitFill`, required-second-operand diagnostic. Fixture(s) added.
5. **`.ALIGN` end-to-end**: parser grammar + `emitAlign`, zero-boundary
   diagnostic, padding computed fresh per pass. Fixture(s) added,
   including a case that exercises actual non-zero padding (not just a
   boundary already satisfied) and a case where `CasmPc` already sits on
   the boundary (padding = 0, zero-iteration loop).
6. **Regression**: existing CASM test suite (`test_casm_expr`,
   `test_casm_pass1`, etc. — exact list TBD, mirroring which suites WP74
   re-ran) confirmed clean, no fixture regressed.
7. **Native/COMP production fixtures**: mirroring WP74's pattern
   (`cmake/GenerateCasmTestFixtures.cmake` + `tests/fixtures/casm/*.ref.hex`
   + `CMakeLists.txt`'s `CASM_REF_NAMES`/disk registration) — hand-derived
   trusted references, live-VICE COMP-verified.
8. **Envelope check**: measure CASM's actual size after all of the above;
   negotiate a bump if `$6500` is exceeded (expected per the parent plan's
   Research Summary point 6 — not a surprise if it happens).
9. **Consolidated live-VICE verification + walkthrough**: every new
   fixture plus a clean regression run, recorded in
   `brain/walkthroughs/`, submitted for user sign-off.

## Expected Files

| File | Planned action |
| --- | --- |
| `src/external/casm/common.inc` | Modify (directive constants, diagnostics) |
| `src/external/casm/lexer.s` | Modify (token recognition) |
| `src/external/casm/parser.s` | Modify (new shared grammar routine) |
| `src/external/casm/emit.s` | Modify (three new handlers) |
| `cmake/GenerateCasmTestFixtures.cmake` | Modify (new fixtures) |
| `tests/fixtures/casm/*.ref.hex` | Create (hand-derived trusted references) |
| `CMakeLists.txt` | Modify (fixture/reference registration) |
| Relevant `tests/src/casm_*` unit harness | Modify or create (TBD which existing harness fits best, likely `casm_expr` or a new `casm_directives`) |

## Stop Conditions

- Any harness/test fails unexpectedly, including a currently-passing
  fixture regressing after this WP's changes.
- The envelope bump (Increment 8) needs approval before proceeding past
  it — do not silently absorb an unapproved ceiling change.
- A no-change rebuild changes any artifact.
- A genuinely new defect is discovered outside this WP's own scope:
  disclose and defer as a separate follow-up (default), do not fix inline
  unless explicitly directed in the moment.
- `.FILL`'s required-value grammar or `.ALIGN`'s zero-boundary handling
  turns out to need a design change once real fixtures are written:
  pause and confirm before deviating from this plan's Language Contract.

## Documentation, Task, and DOX Updates

- Taskwarrior: WP81 task created under the Phase 13 parent (created when
  the master plan is approved).
- `wiki/tasks/casm.md`/`brain/task.md`: WP81 entry, updated at completion.
- No `CHANGELOG.md`/`KNOWLEDGE.md` update yet — those land with WP85 (the
  master plan's own whole-phase completion gate), not per-WP.

## Completion Gate

- `.RES`/`.FILL`/`.ALIGN` all live-verified in VICE: correct byte output,
  correct diagnostics for every error case in the Language Contract.
- Native/COMP production fixtures byte-exact against hand-derived
  references.
- Full existing CASM regression suite clean, no regressions.
- No-change rebuild confirmed stable.
- Envelope bump (if any) explicitly approved, not silently absorbed.
- Walkthrough recorded in `brain/walkthroughs/`.
- User explicitly approves closing WP81.

## Progress

- 2026-08-21: Plan drafted alongside the Phase 13 master plan. Awaiting
  approval of both before implementation begins.
- 2026-08-21: Both plans approved. Increments 1-3 complete (contract
  freeze, lexer recognition, full parser/emitter implementation), including
  9 envelope bumps and one disk relocation (all recorded in the completion
  walkthrough). Found and fixed a real defect during fixture verification:
  `ppsFillDirective` was missing its initial `lexerNext`, producing a
  spurious `MALFORMED EXPRESSION` on every fixture. New
  `test_casm_directives` isolation harness (9/9 live-verified) plus 7
  production fixtures on the new `casm_phase13_test_d64` disk (3 accepted
  COMP-verified, 4 rejected diagnostics verified) all pass live in VICE.
  Regression witnesses (`test_casm_expr`/`test_casm_pass1`/
  `test_casm_frame`) confirmed clean. Completion walkthrough drafted
  (`brain/walkthroughs/2026-08-21-casm-phase13-wp81-res-fill-align.md`),
  awaiting user sign-off.
