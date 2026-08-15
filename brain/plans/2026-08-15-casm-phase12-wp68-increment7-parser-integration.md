---
feature: casm-phase12-wp68-increment7-parser-integration
created: 2026-08-15
status: approved
taskwarrior: c1b8e145-0a9c-4e15-aaab-4e82fc253363 (WP68, task 43)
depends-on: WP68 Increment 6, complete
---

# Plan: CASM Phase 12 WP68 Increment 7 - Relocation, Unresolved, and Parser Integration

## Status

**Approved 2026-08-15.** The user approved this plan as drafted, including
all three Scoping Decisions. Implementation of the Atomic Steps below is
authorized.

Parent plan (Atomic Increment 7 of 9):
`brain/plans/2026-08-14-casm-phase12-wp68-arithmetic-bitwise-operators.md`.
Prerequisite: Increment 6 (multiply, division-by-zero, division), complete,
user-approved, and closed 2026-08-15
(`brain/plans/2026-08-14-casm-phase12-wp68-increment6-multiply-divide.md`).

The parent plan describes this increment as:

> Relocation, unresolved, and parser integration: exercise every new
> unary/binary operator with labels, current address, label-derived
> constants, pure numeric constants, unresolved Pass 1 references, immediate
> operands, directives, and parenthesized RHS forms. Confirm forbidden forms
> fail at the operator with the reserved diagnostic and valid static forms
> preserve Pass 1/Pass 2 width agreement.

This is the first WP68 increment to exercise the new operators through the
*real* production pipeline (`parser.s`/`emit.s`/`casm.s`'s two-pass driver)
rather than only `tests/src/casm_expr/casm_expr.s`'s synthetic
`exprEvaluate`-only harness, which already gives exhaustive per-operator
correctness coverage (97 cases, WP68 Increments 1-7... [sic, Increment 6]).
This increment's job is integration, not re-proving arithmetic.

## Objective

Prove that the new operators behave correctly when reached through real CASM
source text in every operand context that exists in production: instruction
immediate operands, instruction absolute-family operands (where zero-page vs.
absolute width selection matters), and `.BYTE`/`.WORD` directive operands.
Prove the relocation-rejection rule holds for every kind of relocatable
operand a real program can construct (a label, and a label-derived named
constant — not just the synthetic `RELVAL` used in the expression harness).
Prove a forward-referenced (Pass-1-unresolved), non-relocatable named
constant combined with a new operator forces the same absolute-width
classification in Pass 1 that Pass 2 independently re-derives, using the
same two-pass end-to-end proof shape WP61 Increment 4 established for plain
forward-referenced labels (`casmfa2p.seq`/`.ref.hex`).

This increment does not re-verify per-operator numeric correctness (already
closed in Increment 6/7 of the expression harness), does not add new
operators or grammar, and does not touch `ppsConstant`'s own narrow
constant-definition RHS grammar (still frozen: `['<'|'>'] (NUMBER|IDENTIFIER)
[('+'|'-') NUMBER]` plus WP66's `*`, no parentheses, no WP68 operators --
confirmed by reading `parser.s:305-308,392-394,515-559`).

## Scoping Decisions (user-confirmed 2026-08-15)

1. **Representative operators, not the full cross-product.** Exercising
   literally all 9 new operators (`*`,`/`,`<<`,`>>`,`&`,`^`,`|`, unary
   `-`,`~`) against every operand context and every operand kind would be a
   9x8 combinatorial matrix already covered once at the expression level.
   Proposed: follow WP20's own `casmexprn.seq` precedent (one exemplar
   swept across every context) and use one operator per family --
   `*` (arithmetic), `&` (bitwise), `<<` (shift), unary `-` -- crossed
   against every required context/operand-kind. If approved, every operator
   still gets at least one production-pipeline exercise; none are
   completely unverified end-to-end.
2. **Fixture placement.** `test.d64` has only 21 free blocks (WP68's own
   growth already forced the harness move to `casm_phase12_test.d64` in
   Increment 6). Proposed: package every new fixture, plus `comp.prg` (for
   COMP-verified success cases) and `casm.prg` (already present), on
   `casm_phase12_test_d64` -- consistent with that disk's stated purpose as
   "the canonical growth image for Phase 12 expression/operator harnesses...
   and later Phase 12 increments" (Increment 6 plan, Atomic Step 1 note).
3. **No new `test_casm_pass1`-style unit fixture.** WP61 Increment 4 found
   one end-to-end two-pass COMP-verified fixture (`casmfa2p`) sufficient
   proof of forward-reference width agreement, without an additional
   harness-level unit case. Proposed: follow that precedent for this
   increment's own width-agreement fixture rather than duplicating the
   proof in `test_casm_pass1.s` as well.

## Inherited Contracts

- Every new WP68 operator rejects any relocatable operand
  (`CASM_DIAG_EXPR_RELOC_UNSUPPORTED`), enforced generically by
  `checkStaticReloc` in `expr.s`, independent of which specific operator
  triggered it.
- `CASM_PARSER_STMT_FORCE_ABS` is derived from `CASM_EXPR_FLAG_SYMBOL_DERIVED`
  unconditionally, before the resolved/unresolved branch, in both passes
  alike (`parser.s:928-940`, confirmed by `casmfa2p.ref.hex`'s own
  commentary). A new operator's `staticFlags` combine step (`expr.s`)
  already propagates `SYMBOL_DERIVED` from either operand into the result
  (verified in Increment 6 Atomic Step 7 for the synthetic harness); this
  increment proves that propagation reaches `CasmParserStmt` and drives
  addressing-mode width identically in Pass 1 (value unknown/placeholder)
  and Pass 2 (value resolved).
  `emitCheckPassAgreement` (`emit.s:156-169`) is the defensive
  `CasmPc == CasmPass1FinalPc` invariant this proof must not trip.
- `parserParseExpressionValue` (`parser.s:892`) is the single production
  adapter calling `exprEvaluate` (`parser.s:921-922`) for every operand
  context -- immediate (`parser.s:675`), absolute-family (`parser.s:684`),
  indirect (`parser.s:755`), and (via `emit.s:417,459`) `.BYTE`/`.WORD`
  directive operands. One adapter, one relocMode plumbing path
  (`CasmRelocatableMode` -> `A` -> `exprEvaluate`), confirmed single call
  site.
- Named constants (`ppsConstant`) defer their own RHS identifier to
  `casm.s`'s Pass1->Pass2 resolution sweep exactly like a forward-referenced
  label (`parser.s:311-316,460-513`); a constant name used *after* its own
  definition, or even before it (forward reference to the constant itself),
  reaches the same identifier-resolver path as a label. `BUFSTART = *`
  (WP66's `casmcuraddr1.seq` precedent, `parser.s:103-114`) is
  `CASM_SYMBOL_FLAG_LABEL_DERIVED`, i.e. relocatable; a plain-number
  constant (`SCREENW = 40`, `casmconst1.seq` precedent) is not.

## Technical Design

### Fixture Set

All new `.seq` fixtures follow `cmake/GenerateCasmTestFixtures.cmake`'s
existing `file(WRITE ...)` convention, placed near the WP20/WP61/WP65/WP66
precedents they extend.

1. **`casmarith2.seq` -- pure numeric constants and parenthesized RHS,
   every context, success.** One representative operator per family
   (`*`, `&`, `<<`, unary `-`) as immediate operands, plus `.BYTE`/`.WORD`
   directive operands, plus one parenthesized RHS combining WP67 grouping
   with a WP68 operator (`(2+3)*2`). COMP-verified against a new hand-derived
   `casmarith2.ref.hex`, registered in `CASM_REF_NAMES`.
2. **`casmarithfwd.seq` -- forward-referenced, non-relocatable named
   constant, real two-pass width agreement.** `LDA FWDCONST*2` (absolute
   addressing, no `#`) where `FWDCONST = 5` is defined *after* its use.
   `FWDCONST*2 = $000A` would fit zero page as a literal, but
   `SYMBOL_DERIVED` must force 3-byte absolute in both passes -- the same
   proof shape as `casmfa2p.ref.hex`, now through a WP68 operator instead of
   a bare identifier. COMP-verified against a new hand-derived
   `casmarithfwd.ref.hex`, registered in `CASM_REF_NAMES`.
3. **`casmareloc1.seq` -- forbidden form, a real label.** `LOOP: NOP`
   then `LDA #LOOP*2`. No `.ref` (failure case); live-verified for the exact
   `CASM_DIAG_EXPR_RELOC_UNSUPPORTED` message and source location.
4. **`casmareloc2.seq` -- forbidden form, a label-derived named
   constant.** `BUFSTART = *` then `LDA #BUFSTART*2`. Proves relocation
   rejection generalizes beyond bare labels to any relocatable-flagged
   symbol. No `.ref`; live-verified the same way as (3).

Atomic Step 1 (below) re-confirms fixtures (2)-(4)'s exact resolver-flag
predictions (SYMBOL_DERIVED/RELOCATABLE per constant kind) against the real
symbol-table/resolver code before any expected byte or diagnostic is
finalized -- the same "audit before asserting" discipline Increment 6's own
Atomic Step 1 used, since this is the first time WP68 operators reach real
named constants rather than the expression harness's synthetic resolver.

### Disk and COMP Wiring

`casm_phase12_test_d64` gains `comp.prg` (needed for the two `CASM_REF_NAMES`
comparisons) alongside its existing `command64`, `casm`, `test_casm_expr`,
`test_casm_lexer`. The two new `.ref.hex` trusted references are hand-derived
from the 6502 instruction spec, per this project's non-circularity rule
(`[[project-casm-trusted-reference-rule]]`) -- never from `opcodes.s` or from
running the not-yet-verified new operator code itself.

## Scope

**Included:**

- Four new production `.seq` fixtures (two success/COMP-verified, two
  forbidden/diagnostic-verified) per the Fixture Set above.
- Two new hand-derived `.ref.hex` trusted references.
- `casm_phase12_test_d64` gains `comp.prg` and the four new fixtures (plus
  two `.ref` binaries), still comfortably within its free-block gate.
- Live VICE verification of all four fixtures against the real `casm.prg`
  binary: two via `comp.prg` byte-exact comparison, two via exact
  diagnostic message/location.
- Full affected-harness regression and no-change rebuild proof, matching
  every prior WP68 increment's own bar.

**Excluded:**

- Modulo or any operator not in WP64's frozen inventory (unchanged).
- Any change to `ppsConstant`'s own narrow constant-RHS grammar (still frozen).
- Re-verifying per-operator numeric correctness already closed by the
  expression harness (Increment 6 Atomic Step 7).
- A new `test_casm_pass1`-style unit fixture for width agreement (Scoping
  Decision 3).
- WP68 Atomic Increment 8/9's own full affected-target build/envelope sweep
  and Phase-12-wide production fixture matrix (this increment's own
  Completion Gate only requires the narrower checks below; the parent plan's
  Increment 8/9 run the broader pass again over WP68's complete, final
  diff).

## Atomic Steps

1. **Audit resolver-flag predictions.** Before writing any expected byte or
   diagnostic, trace the real symbol-table resolver path for: a plain-number
   named constant referenced after definition, a plain-number named constant
   referenced *before* definition (forward reference), a label, and a
   `= *` label-derived constant. Confirm each one's exact
   `RESOLVED`/`RELOCATABLE`/`SYMBOL_DERIVED` bit pattern matches this plan's
   Inherited Contracts section and the fixture designs above before
   proceeding. If any prediction is wrong, stop and report before writing
   fixtures against it.
2. **`casmarith2.seq` + hand-derived `.ref.hex`.** Add the fixture and its
   trusted reference; wire into `CASM_REF_NAMES`/`casm_phase12_test_d64`;
   verify narrow build and COMP match.
3. **`casmarithfwd.seq` + hand-derived `.ref.hex`.** Same shape as Step 2,
   for the forward-reference width-agreement proof.
4. **`casmareloc1.seq` and `casmareloc2.seq`.** Add both forbidden-form
   fixtures; no `.ref` needed; wire onto `casm_phase12_test_d64`.
5. **Build verification.** Narrow builds, `casm_phase12_test_d64` packaging
   and free-block inspection, full affected-target rebuild, no-change
   rebuild proof (SHA-256 across every touched artifact).
6. **Live VICE verification.** Boot `casm_phase12_test.d64`; run
   `casmarith2.s`/`casmarithfwd.s` through real `casm.prg` with `comp.prg`
   confirming byte-exact output; run `casmareloc1.s`/`casmareloc2.s`
   confirming the exact `CASM_DIAG_EXPR_RELOC_UNSUPPORTED` message and
   location; re-run `test_casm_expr`/`test_casm_lexer` to confirm no
   regression from the shared disk rebuild. Record evidence in the parent
   WP68 plan's Progress log.

## Expected Files

| File | Planned action |
| --- | --- |
| `cmake/GenerateCasmTestFixtures.cmake` | Add four new `.seq` fixture blocks |
| `tests/fixtures/casm/casmarith2.ref.hex`, `casmarithfwd.ref.hex` | Add hand-derived trusted references |
| `CMakeLists.txt` | Register new fixtures in `CASM_REF_NAMES`; add `comp.prg`/new fixtures/refs to `casm_phase12_test_d64`; adjust caps only if measured overflow requires it |
| `brain/plans/2026-08-14-casm-phase12-wp68-arithmetic-bitwise-operators.md` | Append Atomic Increment 7 progress |
| `brain/task.md`, `wiki/tasks/casm.md` | Append progress at completion |

No `src/external/casm/*.s` production source change is anticipated -- this
increment proves existing Increment 4-7 behavior through a new pipeline
surface, not new behavior. An unexpected need to modify `parser.s`/`emit.s`/
`expr.s` requires stopping and reporting before proceeding (see Stop
Conditions).

## Stop Conditions

- Atomic Step 1's audit finds any resolver-flag prediction in this plan
  wrong -- stop and report before writing fixtures against a false
  assumption.
- A forbidden-form fixture fails to raise
  `CASM_DIAG_EXPR_RELOC_UNSUPPORTED`, or raises it at the wrong location.
- A success fixture's real assembled output does not byte-exact-match its
  hand-derived `.ref.hex`.
- The forward-reference fixture's Pass 1 and Pass 2 addressing-mode width
  choices disagree (`CASM_DIAG_PASS_MISMATCH`) -- this would mean a real,
  in-scope WP68 defect, not a pre-existing one, and must be root-caused
  before any workaround.
- `casm_phase12_test_d64`'s free-block gate (established at >=40 in
  Increment 6) is threatened, or any approved production/test envelope cap
  is exceeded -- report measured usage and request direction rather than
  silently raising a cap.
- A no-change rebuild changes any artifact or build counter.
- A genuinely new defect outside this plan's scope is discovered --
  disclose and defer unless the user explicitly approves an inline fix, per
  Increment 6's own precedent for the `test_casm_passcheck`/`test_casm_frame`/
  `test_casm_listcap` latent-gap discovery.

## Documentation, Task, and DOX Updates

- No new Taskwarrior task; this remains under WP68's existing task 43.
- At completion, append Increment 7 evidence to the parent WP68 plan's
  Progress log (append-only, matching Increment 6's own pattern) and
  synchronize `brain/task.md`/`wiki/tasks/casm.md`.
- Update `src/external/casm/AGENTS.md` only if this increment's audit
  (Atomic Step 1) reveals a durable contract not already recorded there;
  otherwise no DOX change is anticipated since no production source changes.

## Completion Gate

Increment 7 completes only when: all four fixtures behave exactly as
designed (two byte-exact via COMP, two with the correct forbidden-form
diagnostic); the forward-reference fixture proves genuine Pass 1/Pass 2
width agreement through a real two-pass run; no `src/external/casm/*.s`
production source needed to change; full affected-target build and envelope
inspection pass; no-change rebuild is stable; live VICE evidence is recorded
in the parent WP68 plan's Progress log; and the user explicitly approves
closing Increment 7 and proceeding to Atomic Increment 8.

## Progress

- 2026-08-15: Drafted this plan after Increment 6's closure, following
  research into `parser.s`'s operand-adapter, `emitCheckPassAgreement`, and
  WP65 named-constant forward-reference semantics. No source, test,
  tracker, or build-system edit has begun.
- 2026-08-15: User confirmed all three Scoping Decisions as drafted:
  representative operators per family, fixtures packaged on
  `casm_phase12_test_d64`, and an end-to-end-only width-agreement proof (no
  separate `test_casm_pass1` unit fixture). User approved the plan as a
  whole; implementation authorized.
- 2026-08-15: **Atomic Step 1 (resolver-flag audit) complete.** Traced the
  real `symbolsLookup`/`expr.s` identifier-resolver path (`expr.s:292-367`,
  `symbols.s:459-498`) for all four planned operand kinds. Two findings,
  both resolved without needing to change the fixture designs already
  drafted, but requiring an explicit understanding not previously written
  down:

  1. `CasmRelocatableMode` is a **whole-assembly** toggle (`expr.s:62-67`'s
     own header comment), not a per-symbol property: an explicit `.ORG`
     sets it to static/0 for the entire pass (`emit.s:393`); its absence
     sets it to relocatable/1 via the implicit-default path
     (`emit.s:536`). `checkStaticReloc`'s rejection is gated on the
     `RELOCATABLE` flag, which `evApplyMode` (`expr.s:349-354`) only ever
     ORs in when this whole-assembly mode is on. **Consequence: WP68's
     relocation-rejection forbidden-form fixtures (3 and 4) MUST NOT use
     `.ORG`** -- under a fixed-address build, nothing is relocatable
     (matching `casmreloc1.seq`'s own established no-`.ORG` precedent), so
     `LOOP*2`/`BUFSTART*2` would silently succeed instead of failing.
     Fixtures 3/4 in this plan's Technical Design section were already
     written without `.ORG`; no correction needed, but the reasoning is now
     recorded rather than assumed.
  2. A genuinely-not-yet-defined forward-referenced identifier (Fixture 2's
     `FWDCONST`) resolves via `symbolsLookup`'s `slNotFound` path
     (`symbols.s:493-498`), which leaves `CASM_RESOLVE_SYM_FLAGS`
     unspecified/stale (never written on a miss) -- `expr.s`'s
     CONSTANT/RESOLVED/LABEL_DERIVED branch (`expr.s:339-348`) reads this
     stale byte, so which branch it takes is technically data-dependent.
     This does not matter for Fixture 2 specifically: both branches funnel
     through `evApplyMode`'s own `CasmExprRelocatableModeIn` gate
     (`expr.s:350-351`), and Fixture 2's explicit `.ORG` (matching
     `casmfa2p.seq`'s own precedent) keeps that mode at 0 regardless, so
     `RELOCATABLE` never gets set either way. `FORCE_ABS` is still set
     unconditionally (`expr.s:364-367`, RESOLVED clear), giving the
     intended Pass 1 "unresolved, force-absolute, propagate without
     evaluating" classification, later independently re-derived as
     resolved+`SYMBOL_DERIVED` (still forcing absolute) in Pass 2 once
     `casmResolveConstants` has run. This is the same width-agreement
     mechanism `casmfa2p.ref.hex` established for a bare label, now
     confirmed to hold for a forward-referenced constant combined with a
     new WP68 operator. The stale-SYM_FLAGS behavior itself is pre-existing
     (WP65-era), out of this increment's scope, and not disclosed as a
     defect since no observable outcome depends on it once `.ORG` is fixed.

  Hand-derived expected bytes for the two COMP-verified fixtures, confirmed
  against this trace:
  - `casmarith2.seq` (`.ORG $C000`; `2*3`, `$0F&$03`, `1<<3`, `-1` as
    immediates; `2*3, 1<<3` as `.BYTE`; `$0F&$03, (2+3)*2` as `.WORD`):
    `00 C0` / `A9 06` / `A9 03` / `A9 08` / `A9 FF` / `06 08` /
    `03 00 0A 00` (16 bytes).
  - `casmarithfwd.seq` (`.ORG $0010`; `LDA FWDCONST*2` before
    `FWDCONST = 5`): `10 00` / `AD 0A 00` (5 bytes; `FWDCONST*2 = $000A`,
    forced 3-byte absolute despite fitting zero page).

  Proceeding to Atomic Step 2.
- 2026-08-15: **Atomic Steps 2-4 (fixtures) complete.** Added all four
  fixtures to `cmake/GenerateCasmTestFixtures.cmake`, two hand-derived
  `.ref.hex` trusted references, registered `casmarith2`/`casmarithfwd` in
  `CASM_REF_NAMES`, added `comp.prg` to `casm_phase12_test_d64`, appended
  all four fixtures plus the two `.ref` binaries via a dedicated
  `POST_BUILD` command (mirroring `casmfa2p`'s own precedent), and excluded
  the two new `CASM_REF_NAMES` entries from the generic `test.d64` loop
  (same exclusion `casmfa2p`/`casmbig1`/`casmopall` already use).
  `casmarithreloc1`/`casmarithreloc2` were renamed to `casmareloc1`/
  `casmareloc2` before any build: the original names are 17 characters,
  over cc1541's 16-character PETSCII limit, and were silently truncating to
  `casmarithreloc1.` (losing the `.s` suffix) on first build. All four
  fixtures build and package cleanly; `casm_phase12_test_d64` sits at 452
  free blocks (comfortably above the >=40 gate); `test.d64` unaffected (21
  free blocks, no new entries pulled in).

  Live VICE testing then surfaced two real findings, both requiring a stop
  before proceeding (per this plan's own Stop Conditions):

  1. **A genuine, in-scope WP68 gap**, disclosed and user-approved to fix
     inline: `LDA #-1` failed `CASM: SYNTAX ERROR` on the real `casm.prg`.
     Root cause: `parser.s`'s instruction-operand dispatch has two
     token-type whitelists gating which tokens may *start* an operand --
     the outer `parseOperandSequence` dispatcher (`parser.s:610-634`) and
     `posImmediate`'s own inner whitelist (`parser.s:650-673`, last
     extended by WP67 for a leading `(`) -- and WP68 never added
     `CASM_TOKEN_MINUS`/`CASM_TOKEN_TILDE` to either. `.BYTE`/`.WORD`
     directives were unaffected (no such gate; they call the expression
     parser directly). Also found, and user-approved to fix in the same
     pass since it's the identical bug class in the identical code:
     `CASM_TOKEN_STAR` (WP66's current-address) was missing from both
     whitelists too -- a pre-existing, WP66-era gap, not something WP68
     introduced. Fixed by adding all three tokens to both whitelists,
     routing to `posAbsoluteJmp`/`posImmediateNumber` respectively, exactly
     matching WP67's own precedent for the `(` gap. `casm` relinks at
     21,481 code bytes (build 1307, well within `$6100`); `test_casm_pass1`/
     `passcheck`/`frame`/`listcap` (all link `parser.s`) relink within their
     own caps with no overflow. No-change rebuild confirmed stable across
     `casm`, `comp`, all four parser-linking harnesses, and all four
     touched disk images.
  2. **A fixture design mistake**, not a production defect: after the
     parser fix, `LDA #-1` then failed `CASM: OPERAND OUT OF RANGE`. Traced
     to `opcodes.s`'s `ofRequire8Bit`: unary `-` always produces a full
     16-bit two's-complement result (any nonzero input carries a nonzero
     high byte), which correctly cannot fit an 8-bit immediate operand --
     the same rule any other `>255` literal already hits, not a bug.
     Corrected the fixture rather than the source: replaced the immediate
     `-1` case with `LDA #~$FF00` (unary `~`, chosen so the complement's
     high byte is zero) for immediate context, and added `LDA -1` (absolute,
     no `#`) to exercise unary `-` as an instruction operand instead --
     which also deliberately exercises the just-added outer-dispatcher fix
     specifically, not just the inner one. Recomputed and updated
     `casmarith2.ref.hex` (19 bytes, sha256
     `1cf95aeac017fa18ffbb7a44e59771298ac0bc56c7e153b8ab5b4d6d3c2d82cb`).
- 2026-08-15: **Atomic Step 5 (build verification) complete.** Full
  affected-target rebuild after the parser fix and fixture correction:
  `casm` (21,481 bytes), `comp`, `test_casm_pass1`/`passcheck`/`frame`/
  `listcap` all link within cap. `casm_phase12_test_d64` (452 free blocks),
  `test_image_d64` (21 free blocks, unaffected), `casm_listing_test_d64`
  (11 free blocks, carries the three parser.s-linking harnesses),
  `image_d64` (318 free blocks, the general OS release image, confirmed
  unaffected) all build cleanly. SHA-256 comparison across every touched
  PRG and disk image, before/after an immediate rebuild of all of them,
  showed no change -- no-change rebuild stability confirmed.
- 2026-08-15: **Atomic Step 6 (live VICE verification) complete.** Booted
  the rebuilt `casm_phase12_test.d64`, confirmed the banner, then ran all
  four fixtures through the real `casm.prg`/`comp.prg`:
  - `casm casmarith2.s /o:carith2.prg` -> `CASM: INPUT VALIDATED`; `comp
    carith2.prg casmarith2.ref` -> `FILES COMPARE OK`.
  - `casm casmarithfwd.s /o:cfwd.prg` -> `CASM: INPUT VALIDATED`; `comp
    cfwd.prg casmarithfwd.ref` -> `FILES COMPARE OK` -- the Pass 1/Pass 2
    FORCE_ABS width-agreement proof holds for a forward-referenced constant
    combined with a WP68 operator, through a genuine two-pass run.
  - `casm casmareloc1.s` -> `CASM: EXPRESSION RELOCATION UNSUPPORTED AT
    LINE 3, COL 12 (OFFSET 11)`, echoed source `lda #loop*2` with caret --
    exactly as designed for a real relocatable label.
  - `casm casmareloc2.s` -> `CASM: EXPRESSION RELOCATION UNSUPPORTED AT
    LINE 3, COL 16 (OFFSET 15)`, echoed source `lda #bufstart*2` with caret
    -- exactly as designed for a label-derived (`= *`) named constant.
  - `test_casm_expr` re-run: all 97 dots, `CASM EXPR: PASS`. `test_casm_lexer`
    re-run: 3 dots, `CASM LEXER: PASS`. Neither regressed from the parser
    fix or the shared disk rebuild.

  All eight live-VICE overlay test events (`testing`/`pass` pairs for each
  of the six programs above) fired via `c64-overlay-api`, per the project's
  overlay-build-events workflow. VICE left healthy and running.

  All six Atomic Steps of this plan are complete. This increment's
  Completion Gate is satisfied: all four fixtures behave exactly as
  designed; the forward-reference fixture proves genuine Pass 1/Pass 2
  width agreement through a real two-pass run; the one production-source
  change that *was* needed (the parser.s operand-dispatch gap) was
  disclosed and explicitly user-approved before being made, not silently
  absorbed; full affected-target build/envelope inspection and no-change
  rebuild both pass; live VICE evidence is recorded here and will be
  appended to the parent WP68 plan's Progress log next. Awaiting the user's
  explicit approval to close Increment 7 and proceed to Atomic Increment 8.
