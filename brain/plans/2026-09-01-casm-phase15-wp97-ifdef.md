---
feature: casm-phase15-wp97-ifdef
created: 2026-09-02
status: COMPLETE — user-approved 2026-09-02 (commit 59c1066)
taskwarrior: 56f9cd17-0aae-4f53-819e-e8b6dd2ad47e (WP97), parent
  0678049c-7d67-4b9a-9305-14efb2353ae1 (Phase 15)
depends-on: WP93 (37bd4c8), WP94 (fb21ff9), WP95 (ecbd717), WP96 (e28dd7d)
---

# Plan: CASM Phase 15 WP97 — `.ifdef` / `.ifndef`

## Status

**Proposed, not yet approved.** WP97 wires the symbol-existence
conditionals. The lexer keywords (WP94), the parser routing (WP96), the
`cond.s` stack (WP95), and the suppressed-branch scanner's structural
handling of `.ifdef`/`.ifndef` (WP96, `condOpenIf(0)`) are all already in
place -- WP97 adds only the two emitting-branch handlers.

Branch `feature/casm-phase15`; commits directly on it. The user has
pre-authorised growing the MAIN envelope past `$7400` if the ~499 B
headroom will not hold WP97 + WP98/99.

## Objective

`.ifdef NAME` — branch taken iff `NAME` is a symbol (label or named
constant) **defined at this point in the source**; `.ifndef NAME` — the
inverse. Bounded, deterministic, Pass 1 == Pass 2.

**Not in scope:** `.ifdef @local` (a scoped-local existence test —
rejected with `CASM_DIAG_IFDEF_EXPECTS_NAME`, documented); comparison
operators (never); `/L` interaction + regression sweep (WP98).

## Design

### The `.ifdef` operand and the "defined so far" question

WP96 routed `.ifdef`/`.ifndef` to `ppsDeferOperands`, so the operand
tokens are left in the lexer stream and `crpCondIfdef` reads them.

The classic hazard: `.ifdef FOO` where `FOO` is defined **later** in the
source. Pass 1's `symbolsLookup(FOO)` misses (not inserted yet); Pass 2's
hits (table complete) -> the two passes would take different branches.

**WP95's `condSiteDecision` decision bitmap already solves this** — it is
why the bitmap exists. Pass 1 computes the decision from the live table
(FOO not found -> `.ifdef` decision 0), records the bit;
Pass 2 recomputes (FOO found -> decision 1) **but `condSiteDecision`
discards the recomputed value and returns Pass 1's recorded bit**. So
Pass 2 replays Pass 1's "not defined" verdict. **No `DEFINED_AT_OFFSET`
comparison is needed** — a deliberate simplification vs. the phase plan's
Research item 5 sketch (the offset compare was for a design without the
replay bitmap). Documented as WP97's As-Built note.

Consequence worth stating in the docs: `.ifdef FOO` sees only symbols
defined **textually before it in Pass 1's traversal order** — a forward
`FOO` reads as *not defined*, consistently in both passes. This matches
ca65's own `.ifdef` (which is also traversal-order).

### `crpCondIfdef` / `crpCondIfndef` (new, `casm.s`, emitting path)

Reached from `crpDir` (WP96 currently sends `.IFDEF`/`.IFNDEF` there to
`CASM_DIAG_NOT_IMPLEMENTED` — replace those two arms):

```
crpCondIfdef:   lda #0  ; "want defined"  -> falls into shared body
crpCondIfndef:  lda #1  ; "want NOT defined"
crpCondIfdefBody:
    sta condWantAbsent          ; small BSS flag
    jsr lexerNext               ; consume .IFDEF/.IFNDEF, fetch operand
    bcs crpCondFailNoLoc
    lda CasmTokenRecord + CASM_TOKEN_REC_TYPE
    cmp #CASM_TOKEN_IDENTIFIER
    beq +
    lda #CASM_DIAG_IFDEF_EXPECTS_NAME
    jmp crpCondFail
  + ; a leading '@' -> reject (scoped-local existence not supported)
    lda CasmTokenText
    cmp #CASM_PETSCII_AT
    bne +
    lda #CASM_DIAG_IFDEF_EXPECTS_NAME
    jmp crpCondFail
  + ; lookup (bare global name)
    lda CasmCurrentScopeLo : sta CasmSymbolLookupScopeLo   ; (Hi too)
    lda #<CasmTokenText : sta CasmPtr0Lo ; (Hi too)
    ldx #<condIfdefView : ldy #>condIfdefView
    lda CasmTokenRecord + CASM_TOKEN_REC_LENGTH
    jsr symbolsLookup
    bcs crpCondFailNoLoc        ; C set only on a real VMM failure
    lda condIfdefView + CASM_RESOLVE_FLAGS
    and #CASM_EXPR_FLAG_RESOLVED
    ; A != 0  => defined.   decision = defined XOR condWantAbsent
    beq @notFound
    lda #1
@notFound: ; A now 1 if found, 0 if not
    eor condWantAbsent          ; .ifndef inverts
    and #1
    pha
    jsr lexerNext               ; fetch the terminator
    bcs @popFail
    jsr crpCondRequireTerminator
    bcs @popFailLoc
    pla
    jsr crpCondSiteDecision     ; A -> effective decision
    bcs crpCondFail
    pha : jsr crpCondStageOpenLoc : pla
    jsr condOpenIf
    bcs crpCondFail
    jmp crpCondCommitLoop
```

(exact register juggling finalised in implementation; the `pha`/`pla`
around `crpCondRequireTerminator` mirrors `crpCondIf`.)

New BSS in `casm.s` (or `cond.s`): `condWantAbsent` (1 byte),
`condIfdefView` (`CASM_RESOLVE_SIZE` bytes). `.import symbolsLookup`,
`CasmTokenText`, `CasmSymbolLookupScopeLo/Hi`, `CasmCurrentScopeLo/Hi`
(some already imported), `CASM_PETSCII_AT`.

### Suppressed-branch `.ifdef`

Already handled by WP96's `crpScanSuppressed` (`condOpenIf(0)` for any
`.IF`/`.IFDEF`/`.IFNDEF` first token). No change.

## Fixtures (append to `casm_phase15_test.d64`)

1. `casmifdef1` — `FOO = 1` then `.ifdef FOO` / body / `.endif` -> body
   assembled. COMP.
2. `casmifdef0` — `.ifdef BAR` with `BAR` never defined -> body omitted.
   COMP (same bytes as body absent).
3. `casmifndef1` — `.ifndef BAZ` (undefined) -> body assembled;
   `.ifndef FOO` (defined above) -> omitted. COMP.
4. `casmifdeffwd` — `.ifdef LATER` with `LATER = 1` *below* it -> body
   **omitted** in both passes (forward = not defined), COMP-exact; a
   parallel `.ifdef LATER` *after* the definition -> assembled. The
   sharp Pass 1 == Pass 2 test.
5. `casmifdefname` — `.ifdef 5` (not an identifier) ->
   `CASM: .IFDEF/.IFNDEF EXPECTS A NAME`. No .ref.
6. `casmifdefguard` — the classic define-once guard:
   `.ifndef GUARD` / `GUARD = 1` / ...body... / `.endif`, included
   conceptually twice via two back-to-back copies in one file -> the
   second copy's body is skipped. COMP.

## Atomic Increments

1. `casm.s`: `crpCondIfdef`/`crpCondIfndef` + the shared body, replacing
   the two `NOT_IMPLEMENTED` arms in `crpDir`. New BSS.
2. `GenerateCasmTestFixtures.cmake` + `CMakeLists.txt`: the 6 fixtures +
   4 `.ref.hex`; append to `casm_phase15_test_d64`; add the accepted
   names to `CASM_REF_NAMES` (with the `^casmif` test.d64 exclusion
   already covering them).
3. Build. **If MAIN overflows `$7400`**: bump to `$7500` (the pre-
   authorised grow), record the measured overflow + new headroom in the
   `add_ca65_app` comment block, same format as every prior bump.
4. Live VICE: the 6 fixtures + `test_casm_cond` + a no-conditionals
   regression witness (`casmassert1`).
5. Walkthrough; commit.

## Stop Conditions

- Any existing `test_casm_*` harness fails, or a no-change rebuild alters
  an assembled `.ref`.
- Pass 1 and Pass 2 take a different branch for any `.ifdef` fixture
  (fixture 4 is the sharp test) -- do not fix forward.
- MAIN still overflows after one `$7500` bump -- STOP and reassess (a
  second bump, or a trim, is a fresh decision).
- The `.ifdef` lookup needs a `symbolsLookup` ABI change (it must be a
  pure call -- the resolver already reports found/not-found without
  raising).
- A new defect outside Phase 15 surfaces -- disclose and defer.

## Completion Gate

- `.ifdef`/`.ifndef` working: 6 fixtures COMP-exact or correct-diagnostic
  live; `test_casm_cond` still green; `casmassert1` byte-identical.
- Pass 1 == Pass 2 proven by fixture 4.
- CASM within its envelope (grown or not); both link configs pass; test
  image builds; build-number check passes.
- Walkthrough recorded; **explicit user approval** before WP98.

## Progress

- 2026-09-02: Plan drafted. Key simplification: WP95's `condSiteDecision`
  replay bitmap already guarantees Pass 1 == Pass 2 for `.ifdef`, so the
  `DEFINED_AT_OFFSET` "defined so far" comparison from the phase plan is
  **not needed** -- `.ifdef` computes a naive found/not-found decision
  and the bitmap makes Pass 2 replay Pass 1's. Awaiting approval.
- 2026-09-02: **Approved (with subagents). WP97 implemented.**
  `casm.s`: `crpCondIfdef`/`crpCondIfndef` (shared body: IDENTIFIER
  operand, `@`-reject, `symbolsLookup`, `decision = defined XOR
  wantAbsent`, `crpCondSiteDecision` -> `condOpenIf`), replacing the two
  `NOT_IMPLEMENTED` arms. One build fix (block relocated to keep near
  branches in range). New BSS (`condWantAbsent` + `condIfdefView`),
  `.import CasmTokenText`. 6 fixtures + 5 `.ref.hex` on
  `casm_phase15_test.d64` (scaffolded by a general-purpose subagent).
  **Live VICE (`CASM V0.6.0.1415`):** `casmifdef1`/`casmifndef1`/
  **`casmifdeffwd`** (forward `.ifdef` -- P1 DONE 7 == P2 DONE 7, no
  mismatch) / **`casmifdefguard`** (define-once, P1 == P2) all
  `FILES COMPARE OK`; `casmifdefname` -> `.IFDEF/.IFNDEF EXPECTS A NAME`
  AT LINE 2 COL 1; `test_casm_cond` PASS. `casmifdef0` trusted by
  construction. All 32 harnesses build. **MAIN headroom 499 -> 360 B --
  no envelope grow needed** (fits `$7400`). `BUILD_CASM` 1415.
  Walkthrough
  `brain/walkthroughs/2026-09-01-casm-phase15-wp97-ifdef.md`.
  Awaiting sign-off before WP98.
- 2026-09-02: **User-approved. WP97 CLOSED.** Taskwarrior WP97 done;
  `brain/task.md` synced. Proceeding to WP98 sub-plan.
