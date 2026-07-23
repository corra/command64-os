---
feature: casm-phase6-wp29-pass2-resolution-emission
created: 2026-07-23
status: complete
---

# Plan: CASM Phase 6B WP29 - Pass 2 Resolution and Emission

## Objective

WP29 replaces `casm.s`'s single-pass `startParseLoop` with a real two-pass
orchestration: Pass 1 drives the already-built-and-fixture-tested "measure
engine" (WP28) to completion over the whole source, then Pass 2 rewinds the
same source and re-drives an *identical* per-statement dispatch in
`CASM_PASS_MODE_EMIT` to produce the real output PRG, now that every label
resolves against the WP27 symbol table WP28 already wired in. This is the
first work package to exercise `CASM_PASS_MODE_EMIT` at all outside
`emit.s`'s own default -- WP28's harness only ever drove `MEASURE` mode.

Taskwarrior: `8e989bdf-7aed-4bfe-ae9c-3771edb7caf5`.

Prerequisite: WP28 is complete and approved (CASM `0.1.30` build 1123).
Approval of this plan is required before activation or source edits, per the
CASM `AGENTS.md` gate.

## Baseline

- CASM `0.1.30` build 1123. `casm.s`'s `start`/`startParseLoop` is unchanged
  since Phase 4 WP14: a single `sourceOpen` -> `lexerInit` -> `fileCreateOutput`
  -> `emitInit` -> one parse-dispatch-emit loop to `CASM_TOKEN_EOF`. It never
  sets `CasmPassMode` explicitly, imports nothing from `symbols.s`, and does
  not recognize `CASM_TOKEN_IDENTIFIER` (label) statements at all -- every
  production assembly today would hard-fail on any label with
  `CASM_DIAG_SYNTAX_ERROR` if one somehow reached `startParseLoop` (it cannot
  today, since WP28's label grammar exists in `parser.s` but has no
  production call site).
- `emitInit` defaults `CasmPassMode = CASM_PASS_MODE_EMIT`
  (`emit.s:64-72`), matching casm.s's current single-caller assumption
  exactly. `emitRawByte`'s single gate gets its byte in `X` and its
  pass-mode check runs first, in `A` (`emit.s:380-398`, fixed during WP28
  after an initial clobber defect).
- `parser.s`'s `parserParseExpressionValue` already binds `symbolsLookup` as
  the production resolver and is fully pass-mode-aware: `CASM_PASS_MODE_EMIT`
  turns an unresolved identifier into a hard `CASM_DIAG_UNDEFINED_SYMBOL`
  failure (`parser.s:519-525`), already wired to real printable message text
  in `diagnostics.s` (confirmed: `msgUndefinedSymbol`/`msgPassMismatch` both
  already have real strings in the message table, not `UNKNOWN` placeholders
  -- WP27 wired all four Phase 6B messages despite its own plan text saying
  it would wire only two).
- `symbols.s` exports `symbolsInit`/`symbolsInsert`/`symbolsLookup`; nothing
  in `casm.s` calls any of them yet.
- `sourceRewind` (`source.s:537+`) closes and reopens the source and resets
  every source-owned field; it deliberately does not touch lexer lookahead
  (lexer-owned), and `lexerInit`'s own doc comment already anticipates being
  called again after a rewind (WP7 design, unexercised until now).
- `outputAbort` (`fileio.s:513+`) already handles "no output file was ever
  created" cleanly via `CasmOutputState`/`CasmOutputCreated`, which stay at
  their `sourceInit`-time defaults if `fileCreateOutput` is never reached --
  this is exactly Pass 1's failure case once `fileCreateOutput` moves past
  it (Contract item 2).
- Production MAIN currently `$3000`, 233 bytes free (WP28's own measurement).
- `tests/src/casm_pass1/casm_pass1.s` (WP28) proves the measure engine
  correct via its own private driver loop (`runMeasurePass`) -- it does not
  touch `casm.s` and is not reused as production code; WP29 writes `casm.s`'s
  own driver from scratch, informed by (not sharing code with) that harness.
- Five trusted-reference fixtures already exist and pass against the
  current single-pass `casm.s`: `casmemit1`, `casmhello`, `casmmodes`,
  `casmnum2`, `casmexprn` (`tests/fixtures/casm/*.ref.hex`, `CASM_REF_NAMES`
  in `CMakeLists.txt`). None uses a label; all five are the two-pass
  rewrite's regression floor -- non-symbol programs must still assemble
  byte-identically once `casm.s`'s control flow is rewritten.
- Three label-bearing source fixtures already exist from WP28, already
  hand-verified and cross-checked for Pass 1 sizing:
  `tests/fixtures/casm/p1fwd1.seq`, `p1back1.seq`, `p1size1.seq`
  (`cmake/GenerateCasmTestFixtures.cmake`), already packaged onto `test.d64`
  as `p1fwd1.s`/`p1back1.s`/`p1size1.s`/`p1undef1.s` (SEQ, `.s`-suffixed).
  Production `casm.prg` is already on `test.d64` (`TEST_IMAGE_PRG_TARGETS`
  includes `IMAGE_PRG_TARGETS`, which includes `CASM_TARGET`) -- so these
  four files can be assembled by the real `casm` binary today with zero new
  fixture-generation work, per the user's confirmed decision to reuse them
  as WP29's own trusted-reference and undefined-symbol fixtures rather than
  authoring parallel copies under new names.

## Dependency Review and Discrepancies Reconciled

1. **The master plan's own "Core Decisions" list, and `AGENTS.md`'s Local
   Contracts, both still describe an event-based Pass 2 design WP26 already
   overrode -- confirmed by direct inspection, not merely suspected.**
   `brain/plans/2026-07-16-casm-assembler-implementation-plan.md:111-113`
   ("Pass 2 emits structured emission events. The PRG writer consumes them
   first; the future listing writer consumes the same events without
   duplicating code generation.") and
   `src/external/casm/AGENTS.md`'s Local Contracts ("Emit structured events
   in Pass 2 so PRG, listing, and map consumers do not duplicate instruction
   generation.") both date to 2026-07-16 (`git blame` confirms the AGENTS.md
   line has never been touched since). WP26's Phase 0C.5 contract, approved
   2026-07-22, explicitly rejected this in favor of a single `CasmPassMode`
   flag consulted at exactly one gate in `emitRawByte`, deferring any
   structured "emission event" concept to Phase 10 when its real consumer
   (the listing writer) exists to design against. Neither document was
   updated when WP26 was approved, so both currently contradict the
   architecture WP28 already implemented and WP29 completes. **Resolved per
   the user's confirmed decision: WP29 corrects both documents as part of its
   own DOX closeout** -- the master plan's Core Decisions bullet and the
   AGENTS.md Local Contracts line are each rewritten to state the frozen
   single-flag design, cross-referencing WP26's plan
   (`brain/plans/2026-07-22-casm-phase6-wp26-prerequisite-reconciliation.md`)
   as the decision record. This is corrective, not a new architectural
   decision -- WP29 does not re-open pass-mode threading, it only makes the
   documentation match what WP26 already approved and WP28 already built.
2. **`fileCreateOutput` must move from before Pass 1 to between Pass 1 and
   Pass 2 -- a real control-flow change, not an incidental one.** Today's
   `start` calls `fileCreateOutput` immediately after the single `lexerInit`,
   before any parsing begins. WP26's frozen contract is explicit that "no
   output file exists yet" before Pass 1 (`emitOrg`'s header write
   automatically no-ops under `MEASURE` mode specifically because of this).
   **Resolved:** the rewritten `start` calls `sourceOpen`/`lexerInit`/
   `symbolsInit` once, runs Pass 1 with `CasmPassMode = MEASURE` and no
   output file, then on Pass 1 success calls `sourceRewind`/`lexerInit` again,
   *then* `fileCreateOutput`, *then* `emitInit` with `CasmPassMode = EMIT`,
   then runs Pass 2 for real. A Pass 1 failure now hits `outputAbort` before
   any file was ever created -- confirmed safe by inspection (Dependency
   Review baseline note on `outputAbort`), so no new failure-path code is
   needed there.
3. **One shared per-statement dispatch drives both passes, exactly as WP26
   froze it -- and it turns out to need no pass-mode branching of its own
   beyond the label case.** Tracing what actually differs between a
   `MEASURE` statement and an `EMIT` statement for each `CasmParserStmt.Type`:
   `MNEMONIC` -> `opcodesFindOpcode`/`emitInstruction` and `DIRECTIVE` ->
   `emitDirective` are *already* fully pass-transparent (WP26/28: the single
   `emitRawByte` gate is the only place `CasmPassMode` matters, and
   `opcodesFindOpcode`'s `FORCE_ABS` consultation and
   `parserParseExpressionValue`'s resolver binding are unconditional in both
   passes). The *only* statement type whose handling differs by pass is
   `CASM_TOKEN_IDENTIFIER` (a label): `MEASURE` calls `symbolsInsert`, `EMIT`
   does nothing at all (WP26 Contract item 2, WP28 Dependency Review item 3:
   "Pass 2 has nothing to do for a label statement"). **Resolved:** a single
   private `casmRunPass` routine in `casm.s` implements the complete
   dispatch loop once; its label-statement branch itself reads
   `CasmPassMode` to decide `symbolsInsert`-or-nothing. `start` calls
   `casmRunPass` twice (once per pass), around the different
   open/rewind/file-creation/mode-set sequencing each pass needs. No
   duplicated dispatch code exists anywhere in `casm.s`.
4. **A duplicate-symbol failure during Pass 1 must still route through
   `startFatal`, and nothing new is needed for that.** `symbolsInsert`'s
   `CASM_DIAG_DUPLICATE_SYMBOL`/`CASM_DIAG_SYMBOL_TABLE_FULL` failures are
   already stable `CASM_DIAG_*` values with real message text (WP27); the
   existing `bcs startFatal` convention after every dispatch call handles
   them identically to any other diagnostic with zero new code. Confirmed:
   no CASM Phase 6B diagnostic needs special handling different from a
   Phase 4/5 one at the `casm.s` orchestration level -- they all funnel
   through the same `A = CASM_DIAG_*`, `C` set, `jmp startFatal` shape.
5. **Pass 1/Pass 2 final-`CasmPc` disagreement detection is explicitly out of
   WP29's scope, confirmed against both the parent Phase 6 plan and WP26's own
   division of labor.** The parent plan assigns "Pass 1/Pass 2 disagreement
   detection" to WP30 by name, and WP26's Verification and Fixture Strategy
   section lists it under "WP30 fixtures," not WP29's. **Resolved:** WP29
   introduces no `CasmPass1FinalPc`-style storage and no comparison logic --
   `CASM_DIAG_PASS_MISMATCH` stays reserved (already has message text, per
   the baseline note) and unraised until WP30 designs its own storage and
   comparison point. This is a deliberate scope boundary, not an oversight:
   folding it into WP29 would silently pre-empt WP30's own dedicated plan.
6. **Relative-branch computation from resolved symbol values needs no change
   in WP29 -- confirmed by inspection, not assumed.** `emitInstruction`'s
   `eiRelative` path (`emit.s:121-157`) already computes displacement purely
   from `CasmParserStmt.VAL_LO/VAL_HI` against `CasmPc`, with no knowledge of
   whether that value came from a literal number or a resolved symbol
   expression -- `parserParseExpressionValue` already normalizes both into
   the same `VAL_LO/VAL_HI` fields before `emitInstruction` ever runs. Once
   Pass 2 resolves a real label through `symbolsLookup`, a relative branch to
   it "just works" through already-existing, unmodified code. The parent
   plan's dependency item 5 ("Relative branches move from immediate to
   symbol-resolved computation... WP30 owns this migration explicitly") is
   therefore mechanically already satisfied by WP28's resolver binding; what
   remains for WP30 is solely the range-check *verification* against real
   forward/backward branch fixtures and the disagreement-detection work
   (item 5 above), not any further branch-displacement code change. Flagged
   here so WP30's own plan does not re-discover this from scratch, but no
   source changes for it belong in WP29.
7. **Three already-hand-verified WP28 fixtures are reused as WP29's own
   trusted-reference source, per the user's confirmed decision -- no new
   `.seq` fixture files are authored.** `p1fwd1.seq`/`p1back1.seq`/
   `p1size1.seq` already exist, are already packaged onto `test.d64` as
   `p1fwd1.s`/`p1back1.s`/`p1size1.s`, and their Pass 1 sizing was already
   independently hand-verified and cross-referenced in WP28's plan and
   walkthrough. Deriving the *emitted-byte* trusted reference for each is a
   mechanical extension of that same hand verification (Contract item 3
   below shows the full derivation for all three) -- reusing them avoids a
   second, parallel fixture-authoring effort that could drift from WP28's
   already-reviewed numbers. `p1undef1.seq` (also already on `test.d64` as
   `p1undef1.s`) is similarly reused, per the user's confirmed decision, as
   WP29's one end-to-end "real casm.s fails cleanly on Pass 2 undefined
   symbol" regression fixture -- no new fixture file for it either.
8. **`p1dup1.seq` is deliberately NOT reused for an end-to-end production
   fixture in WP29.** It already exists and is already packaged, but the
   full duplicate/case-sensitivity/table-full *error-fixture matrix* through
   the real `casm.s` driver is WP31's explicit scope per WP26's own
   Verification and Fixture Strategy section ("WP31 bundles the full
   matrix"). Running `p1dup1.s` through production `casm` now would be easy
   to add but would silently expand WP29 beyond the "resolution and
   emission" byte-matching scope the user confirmed; WP31 owns it.

## Contract / Implementation Details

1. **`casm.s`'s `start` routine is rewritten as a two-pass orchestrator**
   sharing one private dispatch routine, `casmRunPass`:

   ```text
   start:
       ; unchanged: diagClearLoc, resourcesInit, cliInit, fileIoInit,
       ; sourceInit, version banner, cliParse, /M and /L rejection,
       ; cliDeriveOutputName -- all exactly as today, through the existing
       ; startInitFatal trampoline.

       jsr symbolsInit                  ; NEW: once, before either pass
       bcs startInitFatal
       jsr sourceOpen                   ; unchanged call, moved earlier
       bcs startInitFatal
       jsr lexerInit
       bcs startInitFatal

       ; Pass 1: measure. No output file exists yet.
       jsr emitInit
       bcs startInitFatal
       lda #CASM_PASS_MODE_MEASURE
       sta CasmPassMode
       jsr casmRunPass
       bcs startFatal                   ; outputAbort is a safe no-op: no
                                         ; file was ever created this pass

       ; Pass 2: rewind, recreate the output, emit for real.
       jsr sourceRewind
       bcs startFatal
       jsr lexerInit
       bcs startFatal
       ldx #<CasmOutputName
       ldy #>CasmOutputName
       jsr fileCreateOutput
       bcs startFatal
       jsr emitInit
       bcs startFatal
       lda #CASM_PASS_MODE_EMIT
       sta CasmPassMode
       jsr casmRunPass
       bcs startFatal

       jsr emitFinalize
       bcs startFatal
       jsr diagPrintPhase2Ready
       jsr sourceClose
       bcs startFatal
       jmp exitSuccess
   ```

   `startInitFatal` (pre-Pass-1 failures, before any pass-shaped state exists)
   and `startFatal` (mid-orchestration failures) keep their existing
   `outputAbort`-then-`exitFatal` shape unchanged; `startInitFatal` already
   trampolines into `startFatal` today and continues to.
2. **`casmRunPass` (new, private): the single shared per-statement dispatch,
   driven to `CASM_TOKEN_EOF`.**

   ```text
   casmRunPass:
       jsr parserParseStatement
       bcs crpFail
       lda CasmParserStmt + CASM_PARSER_STMT_TYPE
       cmp #CASM_TOKEN_IDENTIFIER
       beq crpLabel
       cmp #CASM_TOKEN_MNEMONIC
       beq crpInsn
       cmp #CASM_TOKEN_DIRECTIVE
       beq crpDir
       cmp #CASM_TOKEN_EOF
       beq crpDone
       jmp casmRunPass                  ; NEWLINE: nothing to do
   crpLabel:
       lda CasmPassMode
       cmp #CASM_PASS_MODE_MEASURE
       bne casmRunPass                  ; EMIT: nothing to do for a label
       lda CasmLabelNameLen
       ldx #<CasmLabelName
       ldy #>CasmLabelName
       stx CasmPtr0Lo
       sty CasmPtr0Hi
       ldx CasmPc
       ldy CasmPc + 1
       jsr symbolsInsert
       bcs crpFail
       jmp casmRunPass
   crpInsn:
       jsr opcodesFindOpcode
       bcs crpFail
       jsr emitInstruction
       bcs crpFail
       jmp casmRunPass
   crpDir:
       jsr emitDirective
       bcs crpFail
       jmp casmRunPass
   crpDone:
       clc
       rts
   crpFail:
       rts                              ; C already set, A = CASM_DIAG_*
   ```

   This is a line-for-line match of `tests/src/casm_pass1/casm_pass1.s`'s
   `runMeasurePass`/label-dispatch logic (Dependency Review item 3), with the
   label branch's pass-mode check added and the loop reused for both passes
   rather than being `MEASURE`-only. `parser.s`/`opcodes.s`/`emit.s`/
   `symbols.s` need zero changes for this: every routine `casmRunPass` calls
   is already pass-mode-correct on its own.
3. **New trusted-reference manifests, reusing WP28's already-hand-verified
   fixture sources verbatim (no new `.seq` files):**

   `tests/fixtures/casm/p1fwd1.ref.hex` -- source `.ORG $0010` / `LDA LOOP` /
   `LOOP: NOP`. `LDA LOOP` is an unresolved forward reference in Pass 1,
   forced absolute by `CASM_PARSER_STMT_FORCE_ABS`; by Pass 2, `LOOP` is
   defined and resolves to `$0013` (`$0010` + 3-byte `LDA` absolute), still
   emitted as absolute (`$AD` not `$A5`) since Pass 2 reuses the identical
   `FORCE_ABS`-derived width Pass 1 already committed to:

   ```text
   10 00           PRG load-address header ($0010, little-endian)
   AD 13 00        LDA $0013  (absolute, NOT zero-page $A5 13)
   EA              NOP        (at $0013)
   ```

   `tests/fixtures/casm/p1back1.ref.hex` -- source `.ORG $0010` /
   `LOOP: NOP` / `LDA LOOP`. `LOOP` resolves to `$0010` (deliberately a small,
   zero-page-eligible value) before `LDA LOOP` is even parsed -- this is the
   fixture that would fail if `CASM_PARSER_STMT_FORCE_ABS` were ever derived
   from `CASM_EXPR_FLAG_FORCE_ABS` (unresolved-only) instead of
   `CASM_EXPR_FLAG_SYMBOL_DERIVED` (any resolver success): a resolved,
   small-valued backward reference must still emit absolute.

   ```text
   10 00           PRG load-address header ($0010, little-endian)
   EA              NOP        (at $0010, defines LOOP)
   AD 10 00        LDA $0010  (absolute, NOT zero-page $A5 10)
   ```

   `tests/fixtures/casm/p1size1.ref.hex` -- source `.ORG $C000` / `JMP LOOP`
   / `LOOP: LDA #$01` / `STA $D020` / `RTS` / `DATA: .BYTE $01, $02, $03` /
   `VALS: .WORD $ABCD, $1234`. Combines a forward reference (`JMP LOOP`,
   always 3 bytes regardless of width rules), two more backward-referenceable
   labels (`DATA`, `VALS`), and both list directives, matching WP28's own
   "comprehensive Pass 1 sanity check" -- this is its real-emission
   counterpart:

   ```text
   00 C0           PRG load-address header ($C000, little-endian)
   4C 03 C0        JMP $C003        (LOOP, forward reference)
   A9 01           LDA #$01         (at $C003, defines LOOP)
   8D 20 D0        STA $D020
   60               RTS             (at $C008; DATA defined at $C009)
   01 02 03        .BYTE $01,$02,$03
   CD AB 34 12     .WORD $ABCD,$1234 (little-endian; VALS defined at $C00C)
   ```

   All three amend `CASM_REF_NAMES` in `CMakeLists.txt` (append `p1fwd1`,
   `p1back1`, `p1size1`); the existing `foreach` loop over `CASM_REF_NAMES`
   needs no structural change, only the three new list entries.
4. **No new diagnostics, no `common.inc` changes, no `symbols.s`/`parser.s`/
   `opcodes.s`/`emit.s` changes.** Every ABI and constant WP29 needs
   (`CASM_PASS_MODE_*`, `CasmPassMode`, `symbolsInit`/`Insert`/`Lookup`,
   `CasmLabelName`/`CasmLabelNameLen`, `CASM_TOKEN_IDENTIFIER`) already exists
   from WP27/WP28. WP29 is exclusively a `casm.s` orchestration change plus
   test-fixture manifests.
5. **`.import` additions to `casm.s` only:** `symbolsInit`, `symbolsInsert`,
   `CasmLabelName`, `CasmLabelNameLen`, `CasmPassMode`, `sourceRewind`. All
   already `.export`ed by their owning modules (`symbols.s`, `parser.s`,
   `emit.s`, `source.s` respectively) -- no new `.export` anywhere.

## Scope

Included:

- `src/external/casm/casm.s`: `start` rewritten as the two-pass orchestrator
  (Contract item 1); new private `casmRunPass` shared dispatch (Contract
  item 2); new imports (Contract item 5).
- `tests/fixtures/casm/p1fwd1.ref.hex`, `p1back1.ref.hex`, `p1size1.ref.hex`:
  new trusted-reference manifests (Contract item 3).
- `CMakeLists.txt`: append `p1fwd1`, `p1back1`, `p1size1` to `CASM_REF_NAMES`;
  MAIN envelope size if the measured overflow requires it.
- `brain/plans/2026-07-16-casm-assembler-implementation-plan.md`: correct the
  stale "Pass 2 emits structured emission events" Core Decisions bullet
  (Dependency Review item 1).
- `src/external/casm/AGENTS.md`: correct the matching stale Local Contracts
  line (Dependency Review item 1).

Excluded (each requires its own dedicated plan per `AGENTS.md`):

- relative-branch range-check fixtures and Pass 1/Pass 2 disagreement
  detection (`CASM_DIAG_PASS_MISMATCH` raise path) -- WP30;
- the full duplicate/case-sensitivity/table-full error-fixture matrix through
  production `casm.s` (`p1dup1.s` and siblings) -- WP31;
- any `symbols.s`, `parser.s`, `opcodes.s`, or `emit.s` change -- none is
  needed (Contract item 4);
- `.include` processing, listings, maps, macros -- unrelated, later phases.

## Expected Files

| File | Action |
| --- | --- |
| `brain/plans/2026-07-23-casm-phase6-wp29-pass2-resolution-emission.md` | this document |
| `src/external/casm/casm.s` | Modify: two-pass orchestration, `casmRunPass` |
| `tests/fixtures/casm/p1fwd1.ref.hex` | Create |
| `tests/fixtures/casm/p1back1.ref.hex` | Create |
| `tests/fixtures/casm/p1size1.ref.hex` | Create |
| `CMakeLists.txt` | Modify: `CASM_REF_NAMES` append; MAIN size if needed |
| `brain/plans/2026-07-16-casm-assembler-implementation-plan.md` | Modify: correct stale Core Decisions bullet |
| `src/external/casm/AGENTS.md` | Modify: correct stale Local Contracts line |
| `wiki/tasks/casm.md`, `brain/task.md`, `brain/KNOWLEDGE.md`, `CHANGELOG.md` | Closeout updates |

## ABI, Storage, and Runtime Effects

- No new or changed record layout, diagnostic, or exported constant. This WP
  consumes WP27/WP28's already-frozen ABI exactly as designed.
- `casm.s` gains one new private routine (`casmRunPass`) and no new BSS --
  every cell it touches (`CasmParserStmt`, `CasmLabelName`/`Len`, `CasmPc`,
  `CasmPassMode`) already exists.
- Production behavior changes materially for the first time since Phase 4:
  `casm` now performs two full source passes per assembly (one extra
  `sourceOpen`-equivalent I/O cost via `sourceRewind`, and a second full
  reparse), and labels are now a legal statement. Every non-label program's
  *output* must remain byte-identical (regression, Verification item 1
  below); only programs using labels newly assemble at all (they would have
  hit `CASM_DIAG_SYNTAX_ERROR` on any bare identifier before WP28/WP29).

## Verification Plan

1. **Regression: the five existing Phase 4/5 trusted references still match
   byte-for-byte** (`casmemit1`, `casmhello`, `casmmodes`, `casmnum2`,
   `casmexprn`) -- proving the two-pass rewrite changes no observable output
   for any program that uses no labels. Run each through the rebuilt `casm`
   in VICE and `COMP` against its existing `.ref` on `test.d64`, exactly as
   WP14/15 established.
2. **New: `p1fwd1`, `p1back1`, `p1size1` match their new trusted references
   byte-for-byte** (Contract item 3) -- proving real Pass 2 emission for
   forward references, backward references (including the
   resolved-but-still-absolute regression case), and a comprehensive
   multi-label/directive mix. Same `casm` + `COMP` procedure, against the
   three new `.ref` files this WP adds to `test.d64`.
3. **New: `p1undef1` fails cleanly through the real `casm.s` Pass 2 path.**
   `.ORG $0010` / `LDA GHOST` (`GHOST` is never defined). Pass 1 tolerates it
   (measure mode, per WP28); Pass 2's `parserParseExpressionValue` returns
   `CASM_DIAG_UNDEFINED_SYMBOL` with `C` set, which must propagate through
   `casmRunPass` -> `startFatal` -> `outputAbort` (deleting whatever partial
   output Pass 2 had begun) -> `exitFatal`, printing the UNDEFINED SYMBOL
   diagnostic and leaving no output file on disk. Run `casm p1undef1.s` in
   VICE, confirm the diagnostic text and the absence of a `P1UNDEF1.PRG` (or
   equivalent derived name) on `test.d64` afterward.
4. Build both relocation bases and `test_image_d64`; confirm a no-change
   rebuild holds `BUILD_CASM` stable before any source edit, and increments
   exactly once after.
5. Every failing case is investigated before completion is requested,
   matching every prior work package's discipline.

## Atomic Implementation Increments

1. Rewrite `casm.s`: extract `casmRunPass`, reorder `start` per Contract
   item 1 (move `fileCreateOutput` between the passes), add the new
   imports. Build production `casm` alone first; confirm it still assembles
   the five existing non-label fixtures correctly before touching any label
   fixture (an early regression gate on the control-flow rewrite itself,
   independent of the new trusted references).
2. Hand-derive and write `p1fwd1.ref.hex`, `p1back1.ref.hex`, `p1size1.ref.hex`
   (Contract item 3); append the three names to `CASM_REF_NAMES` in
   `CMakeLists.txt`.
3. Build both relocation bases and `test_image_d64`; measure MAIN overflow
   (expected modest: no new module, only `casm.s` control-flow and three
   `.ref` files); propose and get approval for any needed size increase.
4. Run the full verification matrix in VICE (ask the user): the five
   regression references, the three new label references, and the
   `p1undef1` failure case. Record the full result in a walkthrough.
5. Correct the stale "Pass 2 emits structured emission events" text in both
   the master plan and `AGENTS.md` (Dependency Review item 1), cross-
   referencing WP26's plan as the decision record.
6. Apply the version-only completion increment, rebuild, confirm no-change
   rebuild stability, both images pass.
7. Update `wiki/tasks/casm.md`, `brain/task.md`, `brain/KNOWLEDGE.md`,
   `CHANGELOG.md`, Taskwarrior.

## Failure and Cleanup

No new failure mode. Every diagnostic `casmRunPass`/`start` can surface is
already stable and already has real message text (Phase 4/5/WP27/WP28).
Pass 1 failures hit `outputAbort` before any output file exists (confirmed
safe no-op, Dependency Review item 2); Pass 2 failures hit it after
`fileCreateOutput`, exercising the existing partial-output-delete path exactly
as every prior phase's fatal exit already does. `resourcesCleanup` requires no
change: `symbolsInit`'s one VMM allocation is registered exactly as WP27/28's
own harnesses already proved, and is freed on every exit path regardless of
which pass failed.

## Documentation and DOX Closeout

Update this plan, `brain/KNOWLEDGE.md` (record that Pass 2 orchestration is
live -- likely as a completion note under the existing Phase 0C.5 section
rather than a new section, since no new contract is being frozen), the master
plan and `AGENTS.md` corrections (Dependency Review item 1), `brain/task.md`,
`wiki/tasks/casm.md`, `CHANGELOG.md`, Taskwarrior, and a new walkthrough with
the full verification matrix (five regression references, three new
references, one undefined-symbol failure case). Re-read the `src`/`external`/
`casm`/`tests` DOX chain after source edits.

## Stop Conditions

Stop if the control-flow rewrite (Atomic Increment 1) breaks any of the five
existing non-label trusted-reference fixtures before any new fixture is even
added -- that would mean the two-pass restructuring itself has a defect
unrelated to symbols, and must be fixed and re-verified before proceeding.
Stop if any of the three new label fixtures or the undefined-symbol fixture
fails and its cause is not small and well-understood enough for the user to
approve fixing in place. Stop if a further material discrepancy is found
during implementation, requiring this plan to be amended and re-approved.

## Completion Gate

WP29 is complete when: the two-pass `casm.s` rewrite passes all five
regression references and all three new label references byte-for-byte, the
`p1undef1` fixture fails cleanly through the real production path with no
partial output left on disk, any measured MAIN size increase is approved and
applied, the master-plan/AGENTS.md documentation correction is made, the
version-only completion increment is verified, and the user explicitly
approves. This does not activate WP30 (relative branches and Pass 1/Pass 2
disagreement detection) or WP31 (full verification and closeout), which
remain separately gated per `AGENTS.md`.

## Progress

- 2026-07-23: Drafted after WP28 closed (CASM `0.1.30` build 1123). Direct
  research against the current source (not the parent Phase 6 plan's
  pre-WP28 description) found WP29's real remaining scope is narrower than
  the parent plan's prose suggested: WP28 already bound the production
  resolver and made `parserParseExpressionValue` pass-mode-aware, so WP29 is
  purely a `casm.s` orchestration rewrite (two passes sharing one dispatch
  routine) plus real-emission trusted-reference proof, with zero changes
  needed to `symbols.s`, `parser.s`, `opcodes.s`, or `emit.s`. Found and, per
  the user's confirmed decision, will correct a real discrepancy: both the
  master plan's Core Decisions list and `AGENTS.md`'s Local Contracts still
  describe a structured-emission-event Pass 2 design from 2026-07-16 that
  WP26 explicitly overrode on 2026-07-22 in favor of the single
  `CasmPassMode` flag WP28 already built -- neither document was updated
  when WP26 was approved. Also confirmed, by tracing `eiRelative` directly,
  that relative-branch displacement computation needs no code change at all
  to consume resolved symbol values (it already consumes whatever
  `parserParseExpressionValue` normalizes into `CasmParserStmt.VAL_LO/HI`,
  regardless of numeric-literal or symbol origin) -- WP30's real remaining
  work is range-check verification and disagreement detection, not further
  branch-displacement plumbing. Per the user's confirmed decisions: reusing
  WP28's already-hand-verified `p1fwd1`/`p1back1`/`p1size1`/`p1undef1`
  fixtures directly as WP29's trusted-reference and undefined-symbol
  regression fixtures (no new `.seq` files), and including exactly one
  undefined-symbol end-to-end fixture now rather than deferring all error-path
  testing to WP31. Awaiting user approval before implementation begins.
- 2026-07-23: Approved and implemented on `feature/casm-phase6-wp29`.
  Rewrote `casm.s` as a two-pass orchestrator sharing one new private
  dispatch, `casmRunPass`; needed zero changes to `symbols.s`/`parser.s`/
  `opcodes.s`/`emit.s`, confirming the narrower scope found during planning.
  Building surfaced a real ca65 branch-range error (three `bcs` branches
  pushed past ±127 bytes), fixed with two near trampolines
  (`startInitFatal`, `startFatalNear`). Added the three new trusted-reference
  manifests, self-validated against `hex_manifest_to_bin.py` before use.
  Corrected the stale "Pass 2 emits structured emission events" text in both
  the master plan and `AGENTS.md`. MAIN measured at 12137 of 12288 bytes
  (151 bytes headroom), no size increase needed. User ran the full VICE
  matrix (5 regression references, 3 new label references, 1
  undefined-symbol failure case) and confirmed "All tests pass." Version-only
  completion increment applied: final CASM `0.1.31` build 1126, no-change
  rebuild stable, both `image_d64` and `test_image_d64` build clean.
  Walkthrough:
  `brain/walkthroughs/2026-07-23-casm-phase6-wp29-pass2-resolution-emission.md`.
  **WP29 is complete.** WP30 is unblocked in Taskwarrior but requires its own
  dedicated plan and approval before any relative-branch or
  disagreement-detection source is written.
