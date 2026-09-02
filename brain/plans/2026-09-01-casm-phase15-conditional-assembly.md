---
feature: casm-phase15-conditional-assembly
created: 2026-09-01
status: approved
taskwarrior: Phase 15 parent + WP93 (see Progress)
depends-on: CASM Phase 14 complete and user-approved 2026-09-01
  (brain/walkthroughs/2026-09-01-casm-phase14-wp92-consolidated-completion.md),
  merged to main at 1b3597b; CASM 0.6.0 build 1405
---

# Plan: CASM Phase 15 — Conditional Assembly (CASM 0.6.1)

## Status

**Proposed, not yet approved.** Drafted 2026-09-01 for user review, per
this project's per-work-package-plan-approval requirement
(`.agents/workflows/phased-implementation-planning.md`). No implementation
is authorized until this plan is approved, and each WP additionally
requires its own detailed sub-plan on file before that WP's
implementation begins (`feedback-phased-plans-detail-first`).

Parent plan: `brain/plans/2026-07-16-casm-assembler-implementation-plan.md`
— see its **Phase 15: Conditional Assembly (CASM 0.6)** section (as
corrected by that plan's 2026-08-31 Version Target Reconciliation) for the
frozen scope this plan expands into work packages.

Baseline: CASM `0.6.0` build `1405` (`src/external/casm/BUILD_CASM`),
Phase 14 (`@name` local labels) complete. `CASM_DIAG_LAST = $5A`.
WP numbering continues the running counter — Phase 14 used WP86-92, so
**Phase 15's work packages start at WP93.**

## Objective

Deliver **conditional assembly** — source regions the assembler includes
or omits based on a compile-time condition:

- `.if EXPR` / `.elseif EXPR` / `.else` / `.endif` — `EXPR` is **truthy**
  (any nonzero resolved value → the branch is taken; zero → skipped);
- `.ifdef NAME` / `.ifndef NAME` — taken/skipped on whether `NAME` is a
  symbol already defined at that point in the source;
- bounded nesting; **deterministic Pass 1 evaluation** — a `.if`/`.elseif`
  expression must fully resolve in the pass that parses it (a forward
  reference is a diagnostic error, not a tolerated Pass-1 placeholder —
  the WP81 `.RES`/`.ALIGN` strict-operand convention, reused);
- a **suppressed branch allocates no symbols and emits no bytes** — it is
  not parsed for meaning, only scanned structurally for the conditional
  directive that ends it;
- Pass 1 and Pass 2 take **identical** branches for every conditional
  site, so assembled layout is pass-invariant.

**Explicitly excluded from Phase 15** (per Scoping Decisions below):

- **Comparison / equality operators** (`=`, `<>`, `<`, `>`, `<=`, `>=`).
  CASM's expression grammar has none (WP83 established `.ASSERT` can only
  test truthiness for exactly this reason). Adding them touches the
  frozen `exprEvaluate` grammar and relocation algebra and is its own
  future scope. Phase 15 conditions are truthiness + symbol-existence
  only. `.if FOO` and `.ifdef FOO` are the vocabulary; `.if FOO = 3` is
  not expressible.
- **Anonymous labels** (`:` / `:+` / `:-`) — the deferred "optional" half
  of Phase 14. They remain a later, still-unnumbered phase; Phase 15 does
  not touch them.
- **Macros, `.repeat`, generated label scopes** — Phase 16.
- **`.define` / textual substitution / `.set` reassignable symbols** — not
  in this phase; `.ifdef` tests only real symbol-table entries (labels
  and named constants).
- Any change to how existing directives, labels, constants, or the
  expression grammar behave. Conditionals are purely additive: a source
  file containing no `.if`/`.ifdef` token must assemble to byte-identical
  output.

## Scoping Decisions (user-confirmed 2026-09-01)

1. **Phase 15 is Conditional Assembly**, per the master plan's numbered
   roadmap. The anonymous-label work deferred by Phase 14 stays deferred
   as a separate, still-unnumbered later phase — it is *not* Phase 15.
2. **Condition capability: truthiness + `.ifdef`/`.ifndef`.** `.if EXPR`
   is taken when `EXPR` resolves to any nonzero value; `.ifdef NAME` /
   `.ifndef NAME` test symbol existence. **No comparison operators** are
   added this phase (rejected — materially larger, touches the frozen
   expression grammar; truthiness + "is it defined" covers the dominant
   real use, feature flags).
3. **Directive set: `.if` / `.elseif` / `.else` / `.endif` + `.ifdef` /
   `.ifndef`.** The full chain including `.elseif` (not just
   `.if`/`.else`/`.endif`).
4. **Version target: CASM `0.6.1`** at the completion gate — staying
   within the `0.6` line the Version Target Reconciliation assigned to
   Phase 14/15, a patch bump (rejected `0.7.0` — that would shift Phase
   16 and force another reconciliation).

## Research Summary

Pre-planning survey of the current tree (this session, 2026-09-01):

1. **Directive recognition** (`lexer.s` `lnDirective`): a linear
   `compareTokenText` chain over `.ORG`/`.BYTE`/`.WORD`/`.INCLUDE`/
   `.STATIC`/`.RELOC`/`.RES`/`.FILL`/`.ALIGN`/`.INCBIN`/`.ASSERT`,
   emitting `CASM_TOKEN_DIRECTIVE` (`$04`) with a `CASM_DIRECTIVE_*`
   subtype (`$00` UNKNOWN .. `$0B` ASSERT; `CASM_DIRECTIVE_COUNT` asserted
   = ASSERT+1). Adding six conditional subtypes extends this chain in the
   same way `.RES`/`.INCBIN`/`.ASSERT` did.
2. **Statement dispatch** (`parser.s` `parserParseStatement`): parses one
   statement into `CasmParserStmt`, classifies a `CASM_TOKEN_DIRECTIVE`,
   and for the operand-bearing directives (`.RES`/`.FILL`/`.ALIGN`/
   `.INCBIN`/`.ASSERT`) evaluates the operand **inline in the parser**
   via `parserParseExpressionValue`. A forward/unresolved operand there
   is already a hard diagnostic for `.RES`/`.ALIGN`/`.ASSERT` (WP81/83).
   `.if EXPR` reuses that exact "resolve now or diagnose" path.
3. **Pass driver** (`casm.s` `casmRunPass`): a per-statement recursive
   loop (`jmp casmRunPass` to continue). Parses a statement, dispatches by
   `CasmParserStmt.Type` (IDENTIFIER→`crpLabel`, EQUALS→`crpConstant`,
   MNEMONIC→`crpCountInsn`, DIRECTIVE→`crpCountDir`, EOF→`crpDone`,
   NEWLINE→commit+loop). `CasmCurrentScope` (Phase 14) is a per-pass
   ordinal bumped identically in both passes and published to
   `CasmSymbolLookupScope` before each statement. **Conditional
   suppression is a new state layered on this loop** — see Technical
   Design.
4. **Two-pass model**: Pass 1 assigns addresses; Pass 2 re-parses
   identically and re-evaluates against the complete table. The
   `.INCLUDE` mechanism is the precedent for "Pass 1 does real work,
   Pass 2 replays it deterministically" (`includeCatalogLoad` →
   `includeCatalogLookup`). Whether conditionals need a similar
   Pass-1-decision record, or whether the "condition must resolve
   in-pass" rule makes re-evaluation naturally identical, is the central
   WP93 design question (Technical Design below).
5. **Symbol record** (`common.inc`): 64 bytes, live fields end at offset
   45; `DEFINED_AT_OFFSET` is at **44-45** (surfaced by the Phase 14 WP90
   map fix). Offsets 46-63 are reserved padding, of which Phase 14 took
   46-47 (scope ordinal). A `.ifdef` "defined *so far*" test can compare
   a symbol's `DEFINED_AT_OFFSET` against the `.ifdef`'s own source
   offset so Pass 1 ("not in the table yet") and Pass 2 ("in the table,
   but defined later") reach the **same** verdict — WP93 confirms whether
   the offset space is global or per-physical-file under `.INCLUDE` and
   picks the comparison key accordingly.
6. **Diagnostics** (`common.inc`, `diagnostics.s`): `CASM_DIAG_LAST = $5A`
   (Phase 14 `$57-$5A`). The message table is a `bcc`/`bcs`-gated
   parallel table (WP81 pattern) with a single `CASM_DIAG_LAST` source of
   truth pinning the runtime range check and `verify_casm_diag_table.py`
   (the post-WP89 hardening). Phase 15 codes start at `$5B` and extend
   the same table.
7. **Expression evaluator** (`expr.s`): frozen resolver ABI
   (`exprEvaluate` + the `symbolsLookup` callback). Truthiness is just
   "resolved value != 0" — no ABI change. `.ifdef` needs a *lookup that
   does not raise on absence* — `symbolsLookup` already returns a
   found/not-found status to its caller (it is `pevUnresolved` that
   escalates); `.ifdef` calls the lookup and branches on the status
   without escalating.
8. **`/L` listing** (`listing.s`): 40-column rows locked by `.assert`
   invariants, consumes resolved values. A suppressed source line
   produces no emitted bytes — WP98 decides whether `/L` shows it (as a
   no-address "skipped" row) or omits it, and pins that with a fixture.
   `/M` is symbol-identity only and is unaffected (a suppressed branch
   defines no symbols).
9. **MAIN envelope**: CASM MAIN is `$7400`, **1,902 bytes headroom** at
   the Phase 14 close. The conditional stack, the suppression scanner,
   and six new directive handlers all add code. Envelope pressure is a
   real risk and a Stop Condition.
10. **Phase test image**: per `.agents/workflows/per-phase-test-images.md`,
    Phase 15 gets its own `casm_phase15_test.d64` (WP96), self-bootable
    (`command64`+`casm`+`comp`).
11. **DASH**: no known conditional-assembly need in `src/external/dash/`
    (single-target, single-configuration). WP98 surveys and most likely
    documents "no adoption" rather than forcing one — but the survey is
    still done, mirroring Phase 12 WP71 / Phase 13 WP84 / Phase 14 WP91.

## Technical Design (to be finalized in WP93)

### Directives and lexing

- Six new `CASM_DIRECTIVE_*` subtypes (`$0C`-`$11`), `CASM_DIRECTIVE_COUNT`
  assert updated. `lnDirective`'s compare chain extended.
- `.if` / `.elseif` carry a truthiness expression operand (parsed inline,
  same path as `.ASSERT`). `.ifdef` / `.ifndef` carry a single bare
  identifier (no expression — a name only, like `.INCBIN`'s filename is a
  bare string). `.else` / `.endif` take no operand.

### Conditional-nesting stack

- A fixed-size stack (WP93 picks the depth — proposal **16**, matching
  the `.INCLUDE` nesting limit) of per-level state:
  `{ this level's branch-taken-yet flag, currently-emitting flag,
     the opening directive's source location }`.
- Overflow → `CASM_DIAG_CONDITIONAL_NESTING_OVERFLOW`.
- BSS only, in `casm.s` or a small `cond.s` module; reset at the start of
  **each pass** (like `CasmCurrentScope`).
- At EOF with the stack non-empty → `CASM_DIAG_UNTERMINATED_CONDITIONAL`
  (names the unclosed `.if`'s line). `.else`/`.elseif`/`.endif` with an
  empty stack → `CASM_DIAG_CONDITIONAL_WITHOUT_IF`. `.elseif`/`.else`
  after `.else` at the same level → `CASM_DIAG_CONDITIONAL_ELSE_AFTER_ELSE`.

### Suppression — the core mechanism

Two candidate approaches; **WP93 picks one and freezes it**:

- **(A) Structural scan mode.** When the top of the conditional stack is
  "not emitting", `casmRunPass` calls a new lightweight
  `parserScanConditionalLine` instead of the full
  `parserParseStatement` — it tokenises to end-of-line via `lexerNext`
  only far enough to recognise a leading `.if`/`.elseif`/`.else`/
  `.endif`/`.ifdef`/`.ifndef` (nested `.if` pushes a "skip" level;
  `.endif` pops; `.else`/`.elseif` at the target level may re-enable
  emitting) and otherwise discards the line. No operand evaluation, no
  symbol insertion, no emission. *Pro:* a suppressed `bne @undef` or
  half-written line never reaches the evaluator. *Con:* a second,
  simpler statement scanner to keep correct.
- **(B) Parse-and-gate.** `parserParseStatement` runs normally but a
  suppression flag makes `crpLabel`/`crpConstant`/`crpCountInsn`/
  `crpCountDir` no-ops and suppresses `emit*`. *Con:* the parser still
  evaluates operands — a suppressed reference to an undefined symbol
  still raises. Rejected unless WP93 finds a clean way to make operand
  evaluation lazy.

Leaning strongly to **(A)** — it is the only approach that lets a
suppressed branch contain source that would not assemble on its own,
which is a normal and expected use of conditional assembly.

### Pass 1 / Pass 2 determinism

- `.if` / `.elseif`: the condition expression **must fully resolve in the
  pass that parses it**. A forward or otherwise-unresolved reference →
  `CASM_DIAG_CONDITIONAL_OPERAND_UNRESOLVED` (WP81 `.RES` precedent). This
  makes Pass 1 and Pass 2 evaluate the identical value, so they take the
  identical branch — no decision record needed.
- `.ifdef` / `.ifndef`: "defined **at this point in the source**" — a
  symbol whose `DEFINED_AT_OFFSET` is at or after the `.ifdef`'s own
  offset counts as *not yet defined*, in **both** passes. WP93 confirms
  the offset key (global vs per-file under `.INCLUDE`) and whether a
  small Pass-1 decision record is a safer belt-and-braces than the
  offset compare.
- The existing whole-assembly `emitCheckPassAgreement` (WP30) still
  guards the assembled-byte total as a backstop.

### Diagnostics (`diagnostics.s`, `common.inc`) — `$5B` onward

Proposed (WP93 assigns final codes/strings):

- `CASM_DIAG_CONDITIONAL_WITHOUT_IF` — `.else`/`.elseif`/`.endif` with no
  open `.if`.
- `CASM_DIAG_UNTERMINATED_CONDITIONAL` — EOF inside a conditional.
- `CASM_DIAG_CONDITIONAL_ELSE_AFTER_ELSE` — `.elseif`/`.else` after
  `.else` at the same level.
- `CASM_DIAG_CONDITIONAL_NESTING_OVERFLOW` — deeper than the limit.
- `CASM_DIAG_CONDITIONAL_OPERAND_UNRESOLVED` — `.if`/`.elseif` expression
  did not resolve in-pass.
- `CASM_DIAG_IFDEF_EXPECTS_NAME` — `.ifdef`/`.ifndef` operand is not a
  bare identifier.

All new message strings assemble to PETSCII; any host-side decoder masks
`& $7F`.

### `/M` and `/L`

- `/M`: unchanged — a suppressed branch defines no symbols.
- `/L`: WP98 decides and pins whether a suppressed line renders as a
  no-address "skipped" row or is omitted; the row-width `.assert`
  invariants must hold either way. `/L` for a program with no
  conditionals stays byte-identical to pre-Phase-15.

## Atomic Increments (Work Packages)

**WP93 — Design freeze + prerequisite reconciliation.** No behavior
change. Freeze the suppression mechanism (A vs B), the `.ifdef`
determinism approach, the nesting depth, the six diagnostic codes/strings
(`$5B`+) and their `.assert`s, the `CASM_DIRECTIVE_*` subtype values, and
the conditional-stack storage layout — assign all the `common.inc`
constants with doc comments but no readers/writers yet. Build clean (all
link configs, test image), byte-identical artifacts. Record every
decision in this plan's Progress log. (Mirrors Phase 14 WP86.)

**WP94 — Lexer: conditional directive tokens.** `lnDirective` recognises
`.if`/`.elseif`/`.else`/`.endif`/`.ifdef`/`.ifndef` → new subtypes. New
`test_casm_lexer` cases (each keyword; a bad form like `.iff`, `.endi`).
No parser/pass wiring. Standalone lexer harness green; no regression.

**WP95 — Conditional stack + suppression scanner (`cond.s` or `casm.s`).**
The bounded nesting stack + the WP93-chosen suppression scanner, wired
into `casmRunPass`'s per-statement loop, reset per pass. New standalone
`test_casm_cond` harness: push/pop balance, overflow, nested skip levels,
`.else` toggling emit state, structural scan does not touch the symbol
table or evaluator. No production-fixture behavior yet beyond
`.if`/`.endif` with a literal condition.

**WP96 — `.if` / `.else` / `.endif` pass-driver wiring + `.if EXPR`
truthiness + production fixtures.** Full integration in `casm.s` /
`parser.s`; `.if EXPR` evaluated inline with the strict "resolve in-pass
or diagnose" rule; Pass 1 == Pass 2 branch identity. New
`casm_phase15_test.d64` (`CMakeLists.txt`, mirroring
`casm_phase14_test_d64`, overlay build-event wrapper, `cmake-overlay-events`
checklist). Fixtures, each COMP- or diagnostic-verified against a
hand-derived reference (`project-casm-trusted-reference-rule`):
1. `.if 1` … `.endif` — body assembled;
2. `.if 0` … `.endif` — body omitted, output identical to the body
   physically absent;
3. `.if 0` with a body that references an undefined symbol / half-written
   line — still assembles cleanly (proves structural scan);
4. nested `.if` inside a taken and inside a skipped branch;
5. `.if screenw` where `screenw` is a **forward** constant → rejected
   (`CONDITIONAL_OPERAND_UNRESOLVED`);
6. `.endif` with no `.if`; `.if 1` with no `.endif` (EOF) — each the
   correct diagnostic at the right location;
7. a taken branch defines a label used *after* the `.endif` — resolves
   normally; a skipped branch's label is genuinely absent (a later
   reference to it → `UNDEFINED SYMBOL`).
Live VICE verification per `vice-mcp-testing` (boot Command64, FLUSH
before/after, fire `c64-overlay-api` test events).

**WP97 — `.elseif` chain + `.ifdef` / `.ifndef`.** The `.elseif` state
machine (first truthy branch wins; once any branch is taken the rest of
the chain is suppressed; `.elseif` after `.else` → diagnostic).
`.ifdef`/`.ifndef` with the WP93 determinism rule. Fixtures: an
`.if/.elseif/.elseif/.else` ladder exercising each landing;
`.ifdef FOO` true and false; `.ifdef` of a symbol defined *later* in the
source → treated as undefined in **both** passes, output byte-identical;
`.ifndef` guard pattern (define-once).

**WP98 — `/M` `/L` interaction + no-conditionals regression + DASH
survey.** `/L` behavior for suppressed lines defined and fixture-pinned;
`/M` re-verified unaffected. A curated no-`.if` regression set
(`casmhello`-class, a Phase 13 fixture, `casmchain1`) proven byte-
identical. DASH surveyed for any conditional-assembly candidate; adopt
only a clear win (likely none — document that), re-verify `dash.ref.hex`
either way. DASH `AGENTS.md` note if the dual-assembler subset changes.

**WP99 — Phase 15 consolidated completion gate.** Fresh, together (not
per-WP citation) re-run of every `test_casm_*` harness + every Phase 15
production fixture + the no-conditionals regression set. Docs: new
"Conditional Assembly" section in `docs/casm-utility.md` (+ programmer's
reference note + wiki mirrors), `wiki/tasks/casm.md`, `brain/task.md`,
`brain/KNOWLEDGE.md` Phase 15 closing section, `CHANGELOG.md`. Version
bump `casm.s` → **`0.6.1`** (build auto-increments). Walkthrough in
`brain/walkthroughs/`. Explicit user sign-off for the whole phase.

## Expected Files

| File | Planned action |
| --- | --- |
| `brain/plans/2026-09-01-casm-phase15-conditional-assembly.md` | Create (this file); append Progress |
| `brain/plans/2026-09-01-casm-phase15-wpNN-*.md` | Create per WP (detailed sub-plan) |
| `src/external/casm/common.inc` | Modify — directive subtypes, diag codes `$5B`+, conditional-stack layout, `.assert`s (WP93) |
| `src/external/casm/lexer.s` | Modify — six conditional directive keywords (WP94) |
| `src/external/casm/cond.s` (new) *or* `casm.s` | Create/Modify — conditional stack + suppression scanner (WP95) |
| `src/external/casm/parser.s` | Modify — `.if`/`.elseif` operand, `.ifdef` name operand, dispatch (WP96/97) |
| `src/external/casm/casm.s` | Modify — `casmRunPass` suppression gate, per-pass reset, version bump (WP96/99) |
| `src/external/casm/diagnostics.s` | Modify — six new message strings (WP93/96/97) |
| `src/external/casm/listing.s` | Modify only if WP98 shows a suppressed-line `/L` row is wanted |
| `tests/src/casm_cond/*` (new harness) | Create (WP95) |
| `cmake/GenerateCasmTestFixtures.cmake`, `CMakeLists.txt` | Modify — lexer/cond/production fixtures, `casm_phase15_test_d64` image + overlay wrapper |
| `src/external/dash/*`, `src/external/dash/AGENTS.md` | Modify only if WP98 adopts a conditional (likely not) |
| `docs/casm-utility.md`, `docs/casm-programmers-reference.md`, `wiki/*`, `wiki/tasks/casm.md`, `brain/task.md`, `brain/KNOWLEDGE.md`, `CHANGELOG.md` | Modify (WP99) |
| `brain/walkthroughs/2026-09-01-casm-phase15-*.md` | Create per WP + consolidated (WP99) |
| memory `MEMORY.md` + new files | Modify/Create (WP99) |

## Stop Conditions

Halt and get renewed direction if:

- any existing `test_casm_*` harness or any curated no-conditionals
  regression fixture fails, or a no-change rebuild alters any assembled
  `.ref` artifact;
- CASM MAIN cannot stay within its approved `$7400` envelope after an
  increment (raising it is a separate, separately-approved decision —
  `project-os-sub1000-segment-full` context);
- Pass 1 and Pass 2 take a **different branch** at any conditional site,
  or disagree on any assembled byte for a Phase 15 fixture — do not
  "fix forward", stop;
- the suppression mechanism cannot keep a suppressed branch's source from
  reaching the expression evaluator / symbol table (the whole point of
  Scoping Decision 2 and Technical Design approach A);
- a `.if EXPR` truthiness rule would require a comparison operator to be
  useful in practice — that is Scoping-Decision-2 territory, stop and
  re-scope rather than smuggling operators in;
- the frozen `exprEvaluate` / `symbolsLookup` ABI would need a signature
  change (the "lookup without escalating" path must already exist or be a
  pure addition);
- a genuinely new defect outside Phase 15's scope surfaces — default is
  disclose-and-defer as its own task, not an inline fix, unless the user
  directs otherwise in the moment (record the deviation);
- the `casm_phase15_test.d64` source-text budget overflows the image
  (`project-casm-testd64-source-vs-output-size` — a fixture's disk cost
  is its raw source size).

## Documentation, Task, and DOX Updates

- **At activation** (on approval): create the Taskwarrior Phase 15 parent
  + WP93 task; add a "Phase 15" section skeleton to `wiki/tasks/casm.md`
  and `brain/task.md` with status `[/]`; branch plan
  (`feature/casm-phase15`, WPs on `feature/casm-phase15-wpNN`).
- **Per WP**: the WP's own detailed sub-plan on file first; append this
  plan's Progress log; tick the WP in the trackers; Taskwarrior task
  closed; per-WP walkthrough.
- **At completion (WP99)**: `docs/casm-utility.md` (new "Conditional
  Assembly" section — the six directives, the truthiness rule, the
  `.ifdef` "defined so far" semantics, nesting limit, the six
  diagnostics, and the explicit note that there are no comparison
  operators so `.if` cannot test equality), `docs/casm-programmers-
  reference.md`, wiki mirrors, `wiki/Home.md`, `wiki/tasks/casm.md`
  closeout, `brain/KNOWLEDGE.md` Phase 15 closing section, `CHANGELOG.md`
  `[Unreleased] → Added`, `casm.s` version `0.6.1`, memory
  (`project-casm-phase15-complete` top-level record).

## Completion Gate

Phase 15 is complete only when **all** of:

- WP93-99 individually complete and user-approved, each with its own
  detailed sub-plan and per-WP walkthrough on file;
- a single consolidated live re-verification (all `test_casm_*` harnesses
  + all Phase 15 production fixtures + the no-conditionals regression
  set), run fresh together, recorded in `brain/walkthroughs/` with real
  evidence (COMP transcripts, VICE screenshots/register reads, overlay
  test events) — not per-WP citations;
- a no-`.if` program proven byte-identical to its pre-Phase-15 output;
- Pass 1 and Pass 2 proven to take identical branches (a fixture with a
  `.ifdef` of a later-defined symbol is the sharp test);
- CASM within the `$7400` MAIN envelope; both link configs pass; test
  image builds; build-number check passes;
- all trackers synchronized (Taskwarrior, `brain/task.md`,
  `wiki/tasks/casm.md`, `brain/KNOWLEDGE.md`, `CHANGELOG.md`, memory);
- CASM version at `0.6.1`;
- **explicit user approval** to close the phase. No self-declared
  completion.

## Progress

- 2026-09-01: Plan drafted for review. Scoping decisions 1-4 captured
  from the user (Phase 15 = Conditional Assembly, anonymous labels stay
  deferred; truthiness + `.ifdef`/`.ifndef`, no comparison operators;
  `.if`/`.elseif`/`.else`/`.endif` + `.ifdef`/`.ifndef`; version target
  `0.6.1`). Pre-planning survey of `lexer.s`/`parser.s`/`casm.s`/
  `common.inc`/`diagnostics.s` recorded in Research Summary. Central open
  design question (suppression mechanism + `.ifdef` Pass1/Pass2
  determinism) flagged for WP93 to freeze.
- 2026-09-01: **Approved by user** ("Begin implementation of Phase 15").
  Taskwarrior Phase 15 parent `0678049c` + WP93 `ef34f19f` created (no
  Taskwarrior MCP this session -- `task` CLI, per
  `feedback-taskwarrior-mcp-fallback`). Branch `feature/casm-phase15`
  created off `main` (`1b3597b`). `wiki/tasks/casm.md` + `brain/task.md`
  Phase 15 skeletons added.
- 2026-09-01: **WP93 sub-plan drafted**
  (`brain/plans/2026-09-01-casm-phase15-wp93-design-freeze.md`) with
  proposed freezes D1-D6: directive subtypes `$0C`-`$11`; structural
  scan-mode suppression (approach A); `.if`/`.elseif` resolve-in-pass +
  a 64-byte Pass-1 decision bitmap replayed in Pass 2 for every
  conditional site (removes the `.ifdef`+`.INCLUDE` offset-ordering
  risk); 16-deep conditional stack in a new `cond.s`; diag codes
  `$5B`-`$61`; `.ifdef`/`.ifndef` bare-identifier operand. Awaiting
  approval before WP93 implementation.
- 2026-09-01: **WP93 approved + implemented.** D1-D6 frozen as proposed.
  `common.inc` (subtypes `$0C`-`$11`, diag codes `$5B`-`$61`,
  `CASM_DIAG_LAST` -> `$61`, `CASM_COND_MAX_DEPTH`/`_SITES`/
  `_BITMAP_BYTES`); new storage-only `cond.s` (195 B BSS: depth + eight
  16-wide per-level arrays + 64-B decision bitmap); `diagnostics.s`
  (7 strings + table entries); `verify_casm_diag_table.py` extended.
  Full build clean, all 31 `test_casm_*` targets build, `OK: all 97
  diagnostic identifiers`, deliberate-break confirmed. CODE size
  **byte-identical** to baseline (zero new instructions); MAIN headroom
  1,902 -> 1,509 B. Walkthrough
  `brain/walkthroughs/2026-09-01-casm-phase15-wp93-design-freeze.md`.
  Awaiting sign-off before WP94.
- 2026-09-01: **WP93 closed (user-approved), committed `37bd4c8`.**
- 2026-09-01: **WP94 implemented.** `lexer.s` `lnDirective` recognises
  `.if`/`.elseif`/`.else`/`.endif`/`.ifdef`/`.ifndef` -> the D1 subtypes
  (six new `compareTokenText` blocks appended to the linear recognition
  chain before the `CASM_DIRECTIVE_UNKNOWN` tail; `compareTokenText` is
  exact-length + case-folded so `.IF` never shadows `.IFDEF`). Six
  keyword strings added. `test_casm_lexer`: new shared `dirCaseCheck`
  helper + eight cases (six accepted keywords -> correct subtype; `.IFF`
  and `.ENDI` -> `CASM_DIRECTIVE_UNKNOWN`), source rows 13-20 (string
  modes 19-26). Harness envelope `$1100` -> `$1200` (+228 measured
  overflow, next round-page fit, WP87 precedent). No parser/pass wiring.
  Build clean, all 31 `test_casm_*` targets build. **Live VICE:
  `casm_include_test.d64`, `test_casm_lexer` -> `CASM LEXER: PASS`
  (26 cases).** casm CODE +96 B / RODATA +40 B; MAIN headroom 1,373 B.
  `BUILD_CASM` -> 1410. Awaiting sign-off before WP95.
- 2026-09-01: **WP94 closed (user-approved), committed `fb21ff9`.**
- 2026-09-01: **WP95 implemented.** `cond.s` state machine -- nine
  routines (reset / openIf / elseif / else / endif / currentlyEmitting /
  topParentEmitting / atEof / siteDecision) implementing the D3/D4
  frozen design: emit-state = `parentEmitting AND (NOT priorTaken) AND
  decision`, and the Pass-1-record / Pass-2-replay 64-byte decision
  bitmap. `casm.s` gets one `jsr condResetForPass` per pass, nothing
  else. New `test_casm_cond` unit harness (15 cases, narrowest link of
  any casm harness) -> live **`CASM COND: PASS`**; `casmassert1` COMP OK
  on `0.6.0.1411` proves the `casm.s` change is byte-neutral. All 32
  `test_casm_*` targets build. MAIN headroom 1,373 -> 1,000 B (watch
  item for WP96-99). Sub-plan
  `brain/plans/2026-09-01-casm-phase15-wp95-cond-state-machine.md`;
  walkthrough
  `brain/walkthroughs/2026-09-01-casm-phase15-wp95-cond-state-machine.md`.
  Awaiting sign-off before WP96.
- 2026-09-01: **WP95 closed (user-approved), committed `ecbd717`.**
  WP96 sub-plan drafted
  (`brain/plans/2026-09-01-casm-phase15-wp96-pass-driver-wiring.md`) --
  proposes reshaping the WP96/97 boundary to "truthiness family
  (`.if`/`.elseif`/`.else`/`.endif`) then symbol family
  (`.ifdef`/`.ifndef`)" rather than "3 then elseif+2". Awaiting approval.
- 2026-09-01: **WP96 approved (incl. reshape) + implemented.**
  `.if`/`.elseif`/`.else`/`.endif` working end to end: `parser.s`
  `parserEvalConditionExpr` + conditional-subtype routing; `casm.s`
  `crpScanSuppressed` structural scanner + `crpCond*` handlers +
  `casmRunPass` gate + `crpDone` `condAtEof`. New `casm_phase15_test.d64`
  (10 fixtures, `test_casm_cond` rehomed). Live: **6/6 accepted fixtures
  COMP OK** (incl. `casmifskip` -- a skipped branch with un-assemblable
  source), **4/4 rejected fixtures** with correct diagnostics + carets,
  `test_casm_cond` PASS, `casmassert1` regression byte-identical. All 32
  harnesses build. **MAIN headroom 1,000 -> 499 B** (WP97 envelope risk).
  Sub-plan / walkthrough:
  `brain/{plans,walkthroughs}/2026-09-01-casm-phase15-wp96-pass-driver-wiring.md`.
  `BUILD_CASM` 1413. Awaiting sign-off before WP97.
- 2026-09-01: **WP96 closed (user-approved), committed `e28dd7d`.** User
  authorised "grow if needed" for the MAIN envelope in WP97. WP97 sub-plan
  drafted (`brain/plans/2026-09-01-casm-phase15-wp97-ifdef.md`) -- key
  simplification: WP95's decision bitmap already guarantees Pass1==Pass2
  for `.ifdef`, so no `DEFINED_AT_OFFSET` compare is needed. Awaiting
  approval. User also authorised subagent use for the remaining WPs.
- 2026-09-02: **WP97 approved + implemented (subagent scaffolded the
  fixtures).** `.ifdef`/`.ifndef` working: `casm.s` `crpCondIfdef`/
  `crpCondIfndef`; the WP95 decision bitmap makes a forward `.ifdef`
  read as not-defined identically in both passes (no `DEFINED_AT_OFFSET`
  compare). Live: `casmifdeffwd` + `casmifdefguard` prove P1 == P2;
  5/6 fixtures COMP OK + `EXPECTS A NAME` diagnostic + `test_casm_cond`
  PASS. MAIN headroom 499 -> 360 B, still within `$7400`. `BUILD_CASM`
  1415. Sub-plan / walkthrough
  `brain/{plans,walkthroughs}/2026-09-01-casm-phase15-wp97-ifdef.md`.
  Awaiting sign-off before WP98.
- 2026-09-02: **WP97 CLOSED (user-approved).** WP98 implemented +
  live-verified: `/L` renders a suppressed content line with a blank
  address column (ca65-style; new `CASM_LISTING_META_FLAG_SUPPRESSED`
  bit) -- `casmifL1` proves lines 3-4 blank, directive/real lines
  normal, `FILES COMPARE OK`; `casmifM1` proves `/M` never lists a
  suppressed-branch symbol; `TEST_CASM_COND` green; DASH surveyed -> no
  adoption, byte-identical. `BUILD_CASM` 1416, MAIN headroom 327 B (no
  grow). Walkthrough
  `brain/walkthroughs/2026-09-01-casm-phase15-wp98-listing-regression-dash.md`.
  Awaiting sign-off before WP99.
- 2026-09-02: **WP98 CLOSED (user-approved, 37a12c5). WP99 gate run --
  GREEN.** CASM `0.6.0` -> `0.6.1` build `1417` (version bump only, zero
  code delta -- BSS end `$AAB9` identical to WP98, 327 B headroom).
  Fresh full build clean (74 targets); `verify_casm_diag_table.py` green
  (97 ids incl. `$5B-$61`). `casmifsym` + `casmifp1p2` fixtures added.
  Live VICE (`CASM V0.6.1.1417`): `test_casm_cond` PASS; the full
  conditional matrix (`casmif1/0/skip/else/elif/nest/defguard/p1p2` COMP
  + P1==P2; `casmifsym` UNDEFINED SYMBOL on skipped-branch label;
  `casmiffwd` .IF NOT RESOLVED; `casmelseelse` AFTER .ELSE; `casmifL1`
  /L blank address) + no-`.if` regression witnesses `casmassert1` /
  `casmincbin1` COMP OK. Docs: `docs/casm-utility.md` Conditional
  Assembly section + Example 5, programmer's reference, wiki mirrors,
  Home, tasks, CHANGELOG, KNOWLEDGE. Walkthrough
  `brain/walkthroughs/2026-09-01-casm-phase15-wp99-completion-gate.md`.
  Memory `project-casm-phase15-complete`. Committed. **Awaiting explicit
  phase sign-off; merge to `main` is a separate step.**
