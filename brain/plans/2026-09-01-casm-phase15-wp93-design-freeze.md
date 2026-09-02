---
feature: casm-phase15-wp93-design-freeze
created: 2026-09-01
status: implemented, awaiting user sign-off
taskwarrior: ef34f19f-a0a5-4b3f-872c-6ac1ee842f3e (WP93), parent
  0678049c-7d67-4b9a-9305-14efb2353ae1 (Phase 15)
depends-on: CASM Phase 15 plan approved
  (brain/plans/2026-09-01-casm-phase15-conditional-assembly.md)
---

# Plan: CASM Phase 15 WP93 — Design Freeze + Prerequisite Reconciliation

## Status

**Proposed, not yet approved.** Drafted 2026-09-01 for user review.
Mirrors Phase 14 WP86 (design-freeze WP): no behaviour change, assigns
constants, records the decisions the phase plan's Technical Design left
open. No implementation of conditional-assembly behaviour is authorized
by this WP — only the constants, storage declarations (no readers /
writers), and `.assert`s.

Parent plan:
`brain/plans/2026-09-01-casm-phase15-conditional-assembly.md`.
Branch: `feature/casm-phase15` (already cut from `main` `1b3597b`);
WP93 commits directly on it.

## Objective

Freeze the six open design questions from the phase plan's Technical
Design so WP94-99 have no architecture left to invent, and land the
`common.inc` constants + storage skeleton + `.assert`s for them. Full
build stays clean and every assembled artifact byte-identical (zero new
instructions this WP).

## Design Decisions to Freeze (proposed — this plan IS the freeze once
approved)

### D1 — `CASM_DIRECTIVE_*` subtype values

Six new subtypes, contiguous after `CASM_DIRECTIVE_ASSERT` (`$0B`):

```
CASM_DIRECTIVE_IF      = $0C
CASM_DIRECTIVE_ELSEIF  = $0D
CASM_DIRECTIVE_ELSE    = $0E
CASM_DIRECTIVE_ENDIF   = $0F
CASM_DIRECTIVE_IFDEF   = $10
CASM_DIRECTIVE_IFNDEF  = $11
CASM_DIRECTIVE_COUNT   = $12   ; was $0C
```

`.assert CASM_DIRECTIVE_COUNT = CASM_DIRECTIVE_IFNDEF + 1` (replaces the
current `= CASM_DIRECTIVE_ASSERT + 1`).

### D2 — Suppression mechanism: **structural scan mode** (phase-plan
approach A)

`casmRunPass` gains a check: when the conditional stack's top level is
**not emitting**, the loop calls a new `condScanSuppressedLine` (WP95)
instead of `parserParseStatement`. `condScanSuppressedLine`:

- drives `lexerNext` to the end of the physical line;
- recognises **only** a leading `CASM_TOKEN_DIRECTIVE` whose subtype is
  one of the six conditional subtypes, and acts on the stack
  (`.if`/`.ifdef`/`.ifndef` push a nested "skip" level; `.endif` pops;
  `.elseif`/`.else` at the *current* level may flip emit state per the
  ladder rules);
- discards everything else — **no operand evaluation, no `symbolsInsert`,
  no `emit*`, no `.if`-expression parse** for a suppressed nested `.if`
  (its condition is not evaluated at all until/unless its level becomes
  reachable — which, because an outer level is skipped, it never does; a
  skipped nested `.if` is recorded as taken=false without evaluation).

Rationale: only this lets a suppressed branch hold source that would not
assemble standalone (a normal use of conditional assembly). Approach B
(parse-and-gate) is rejected — the parser evaluates operands inline, so a
suppressed `bne @undef` would still raise.

### D3 — Pass 1 / Pass 2 branch determinism: **`.if`/`.elseif` resolve
in-pass; a Pass-1 decision bitmap backs every conditional site**

- **`.if EXPR` / `.elseif EXPR`**: `EXPR` must **fully resolve in the
  pass that parses it** — a forward / unresolved reference →
  `CASM_DIAG_CONDITIONAL_OPERAND_UNRESOLVED` (the WP81 `.RES`/`.ALIGN`
  strict-operand convention). Pass 1 and Pass 2 evaluate the identical
  value from identical top-to-bottom source order, so they take the
  identical branch.
- **`.ifdef NAME` / `.ifndef NAME`**: "defined **at this point in the
  source**". `symbolsLookup` (no ABI change — it already reports
  found/not-found through the view, and populates
  `CASM_RESOLVE_DEFINED_AT_OFFSET_LO/HI` on a match). NAME counts as
  *defined* iff the lookup matches **and** the matched record's
  `DEFINED_AT_OFFSET` is strictly less than the `.ifdef` statement's own
  `CasmTokenStartOffsetLo/Hi`. This is the exact WP76 forward-reference
  mechanism: a symbol defined later in the concatenated source was
  necessarily absent when Pass 1 reached the `.ifdef`, so Pass 2 (full
  table) must reach the same verdict via the offset compare.
- **Belt-and-braces for both**: Pass 1 writes a 1-bit decision
  (taken / not-taken) for **every conditional evaluation site visited**,
  indexed by a per-pass monotonic counter (`CasmCondSiteCounter`, reset
  per pass, bumped once per `.if`/`.elseif`/`.ifdef`/`.ifndef` *reached
  while its enclosing level is emitting*). Pass 2 **replays** decision N
  for the Nth reached site rather than re-evaluating — the `.INCLUDE`
  `catalogLoad`→`catalogLookup` pattern. This removes every residual
  Pass1/Pass2 divergence risk (`.ifdef` + `.INCLUDE` source-offset
  ordering, in particular) and is cheap.
  - Storage: a bitmap. Cap `CASM_COND_MAX_SITES` (proposal **512** →
    **64 bytes**). Overflow → `CASM_DIAG_CONDITIONAL_SITE_OVERFLOW`.
    WP93 decides MAIN array vs a small VMM region; proposal **MAIN**
    (64 bytes is below the noise floor and avoids a VMM round-trip on
    the hot path).
  - A skipped nested `.if`/`.ifdef` does **not** consume a site index
    (its condition is never evaluated) — so the counter is
    deterministic across passes as long as the *outer* decisions match,
    which the same replay guarantees inductively.

### D4 — Conditional-nesting stack

- Depth `CASM_COND_MAX_DEPTH` = **16** (matches `CASM_INCLUDE_MAX_DEPTH`;
  same `.assert` style).
- Per level, parallel `.res CASM_COND_MAX_DEPTH` arrays in the new
  `cond.s` (module pattern like `source.s`'s frame stack):
  - `CasmCondEmitting` — 1 = this level currently emits, 0 = suppressed.
  - `CasmCondBranchTaken` — 1 = some branch at this level has already
    been taken (so a later `.elseif`/`.else` here stays suppressed).
  - `CasmCondSeenElse` — 1 = `.else` already seen at this level
    (`.elseif`/`.else` after it → diagnostic).
  - `CasmCondOpenLineLo/Hi` + `CasmCondOpenCol` — the opening `.if`'s
    location, for the unterminated-conditional diagnostic.
  - `CasmCondParentEmitting` — snapshot of the enclosing level's emit
    state, so a nested level that is entirely inside a suppressed outer
    level never emits regardless of its own condition.
- `CasmCondDepth` (0 = no open conditional). Reset to 0 at the start of
  **each pass** (alongside `CasmCurrentScope`).
- Overflow → `CASM_DIAG_CONDITIONAL_NESTING_OVERFLOW`.

### D5 — Diagnostics `$5B`-`$60` (contiguous, extend the flat
`diagMsgLo/Hi` table; bump `CASM_DIAG_LAST` `$5A`→`$60`)

| Code | Name | Message (final wording WP93) |
| --- | --- | --- |
| `$5B` | `CASM_DIAG_CONDITIONAL_WITHOUT_IF` | `.ELSE/.ELSEIF/.ENDIF WITHOUT .IF` |
| `$5C` | `CASM_DIAG_UNTERMINATED_CONDITIONAL` | `UNTERMINATED .IF` |
| `$5D` | `CASM_DIAG_CONDITIONAL_ELSE_AFTER_ELSE` | `.ELSEIF/.ELSE AFTER .ELSE` |
| `$5E` | `CASM_DIAG_CONDITIONAL_NESTING_OVERFLOW` | `CONDITIONAL NESTING TOO DEEP` |
| `$5F` | `CASM_DIAG_CONDITIONAL_OPERAND_UNRESOLVED` | `.IF CONDITION NOT RESOLVED` |
| `$60` | `CASM_DIAG_IFDEF_EXPECTS_NAME` | `.IFDEF/.IFNDEF EXPECTS A NAME` |

(`CASM_DIAG_CONDITIONAL_SITE_OVERFLOW` from D3 — decide in WP93 whether
it is a 7th code `$61` or folded into `NESTING_OVERFLOW`; proposal:
**7th code `$61`**, `CONDITIONAL COUNT LIMIT` — a distinct limit worth a
distinct message. That makes `CASM_DIAG_LAST = $61`.)

Contiguity `.assert`s in the WP89/Phase-14 style; `CASM_DIAG_LAST`
updated (the single source of truth pinning `diagPrintFatal`'s range
check + `verify_casm_diag_table.py`).

### D6 — `.ifdef`/`.ifndef` operand grammar

A single **bare identifier** — no expression, no `@local` prefix
(a `.ifdef @x` → `CASM_DIAG_IFDEF_EXPECTS_NAME`; scoped-local existence
testing is out of Phase 15 scope). Parsed the way `.INCBIN`'s filename
is: recognise exactly one token of the right kind after the directive,
then require end-of-line.

## Atomic Increments

1. **`common.inc`**: add D1 subtypes + updated `CASM_DIRECTIVE_COUNT`
   assert; D5 diag codes `$5B`-`$61` + contiguity asserts + bump
   `CASM_DIAG_LAST`; D3 `CASM_COND_MAX_SITES` (512) and D4
   `CASM_COND_MAX_DEPTH` (16) + their asserts. Doc comments citing this
   plan. No other file changed yet.
2. **`cond.s`** (new, added to the ca65 source list + all link configs +
   `verify`/build wiring): the D4 parallel arrays + `CasmCondDepth` +
   D3 `CasmCondDecisionBitmap` (64 B) + `CasmCondSiteCounter`, as BSS
   with a one-line `condResetForPass` stub (`lda #0` stores) exported but
   **not yet called** by `casm.s`. No logic.
3. **`diagnostics.s`**: seven new message-string `.byte` literals wired
   into `diagMsgLo/Hi` in identifier order; `verify_casm_diag_table.py`
   expected-count bumped. Deliberate-break check that the table-length
   `.assert` fires if a string is omitted.
4. **Build**: `rm -rf build && cmake -B build && cmake --build build` —
   clean, all link configs, `image_d64`, a test image. `casm.prg`
   unchanged in code size / relocation count (BSS-only + constants +
   message strings; message strings do grow RODATA — record the exact
   delta, it is data not code and does not touch MAIN's code budget, but
   note remaining MAIN headroom).
5. **Record**: append the frozen decisions (with any wording finalised)
   to the phase plan's Progress and this plan's Progress. Per-WP
   walkthrough `brain/walkthroughs/2026-09-01-casm-phase15-wp93-design-freeze.md`.

## Expected Files

| File | Action |
| --- | --- |
| `brain/plans/2026-09-01-casm-phase15-wp93-design-freeze.md` | Create (this file) |
| `src/external/casm/common.inc` | Modify — D1/D3/D4/D5 constants + `.assert`s |
| `src/external/casm/cond.s` | Create — BSS skeleton + `condResetForPass` stub |
| `src/external/casm/diagnostics.s` | Modify — 7 new message strings |
| `cmake/*.cmake` / `CMakeLists.txt` | Modify — add `cond.s` to the casm source list + every casm/test link |
| `scripts/verify_casm_diag_table.py` | Modify — expected id count |
| `brain/plans/2026-09-01-casm-phase15-conditional-assembly.md` | Modify — Progress |
| `brain/walkthroughs/2026-09-01-casm-phase15-wp93-design-freeze.md` | Create |

## Stop Conditions

- Any existing `test_casm_*` harness fails, or a no-change rebuild alters
  any assembled `.ref` artifact.
- Adding `cond.s` to the link cannot be done without disturbing an
  existing segment's placement / an existing `.assert` (a real risk —
  every `test_casm_*` link config lists the casm object set explicitly).
- The RODATA growth from seven message strings pushes any link past its
  envelope.
- The `CASM_DIRECTIVE_COUNT` or `CASM_DIAG_LAST` bump breaks a
  `.assert` elsewhere that this plan did not anticipate.
- A design decision above turns out to be unimplementable as stated when
  WP94/95 start — return here and re-freeze, do not improvise.

## Completion Gate

- All D1-D6 decisions final and recorded (this plan + phase-plan
  Progress).
- `common.inc` / `cond.s` / `diagnostics.s` / build wiring landed; full
  `cmake --build build` clean; `casm.prg` **code** size + relocation
  count unchanged; MAIN headroom recorded.
- `verify_casm_diag_table.py` green at the new count; deliberate-break
  check confirmed.
- Every `test_casm_*` harness still builds (a link-level regression is
  the main risk this WP).
- Per-WP walkthrough recorded; **explicit user approval** before WP94.

## Progress

- 2026-09-01: Plan drafted. D1-D6 proposed (subtype values `$0C`-`$11`;
  structural scan-mode suppression; `.if` resolve-in-pass + a 64-byte
  Pass-1 decision bitmap replayed in Pass 2; 16-deep conditional stack in
  a new `cond.s`; diag codes `$5B`-`$61`; `.ifdef` bare-identifier
  operand). Awaiting approval.
- 2026-09-01: **Approved. WP93 implemented.**
  - `common.inc`: D1 subtypes `CASM_DIRECTIVE_IF/ELSEIF/ELSE/ENDIF/IFDEF/
    IFNDEF` = `$0C`-`$11`, `CASM_DIRECTIVE_COUNT` `$0C`->`$12` + six
    contiguity `.assert`s. D5 diag codes `CASM_DIAG_CONDITIONAL_*` /
    `..._IFDEF_EXPECTS_NAME` = `$5B`-`$61`, `CASM_DIAG_LAST` `$5A`->`$61`
    (via a new `CASM_DIAG_PHASE15_WP93_LAST` alias) + seven contiguity
    `.assert`s. D3/D4: `CASM_COND_MAX_DEPTH` = 16, `CASM_COND_MAX_SITES`
    = 512, `CASM_COND_BITMAP_BYTES` = 64 + `.assert`s.
  - `cond.s` (new, storage-only like `state.s`): `CasmCondDepth`, the
    eight per-level `.res CASM_COND_MAX_DEPTH` arrays
    (Emitting/BranchTaken/SeenElse/ParentEmitting/OpenLineLo/Hi/OpenColumn/
    OpenFileId), `CasmCondSiteCounterLo/Hi`, `CasmCondDecisionBitmap`
    (64 B). Four internal layout `.assert`s. **No code** -- `condResetForPass`
    and all logic deferred to WP95 (matches the WP86 "zero new
    instructions this WP" precedent; the sub-plan's "one-line stub"
    wording dropped in favour of the cleaner storage-only module).
  - `diagnostics.s`: seven new `.byte` message strings + 14 `diagMsgLo/Hi`
    table entries (`$5B`-`$61`), RODATA.
  - `scripts/verify_casm_diag_table.py`: `EXPECTED` extended with the
    seven `$5B`-`$61` frozen strings.
  - `cond.s` is picked up automatically by `CASM_SRCS`'s
    `GLOB_RECURSE src/external/casm/*.s`; no `test_casm_*` link config
    needed a change (WP93 adds no symbol any harness references).
  - **Build**: full `cmake --build build` clean; all 31 `test_casm_*`
    targets build; `verify_casm_diag_table` -> `OK: all 97 diagnostic
    identifiers + 2 extras`. Deliberate-break check: dropping one
    `diagMsgLo` entry -> `Error: CASM diagnostic message table (lo)
    length must equal CASM_DIAG_LAST` (build-breaking, as designed).
  - **Envelope** (`ld65 -m`): CODE `$3800`-`$8BFA` size `$53FB` --
    **byte-identical to the WP92 baseline** (zero new instructions).
    RODATA +198 B (message strings + table). BSS +195 B (exactly the
    `cond.s` state: 1 + 8*16 + 2 + 64). MAIN headroom under `$7400`:
    1,902 -> **1,509 bytes**. No-change rebuild: zero further
    compile/link work.
  - `BUILD_CASM` 1405 -> 1409 (deliberate-break iterations).
  Walkthrough:
  `brain/walkthroughs/2026-09-01-casm-phase15-wp93-design-freeze.md`.
  Awaiting user sign-off before WP94.
