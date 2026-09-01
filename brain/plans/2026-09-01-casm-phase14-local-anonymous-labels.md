---
feature: casm-phase14-local-anonymous-labels
created: 2026-09-01
status: approved
taskwarrior: 4cf10e7c-9365-46cf-94e1-5e4bd8d44635 (Phase 14 parent); WP86 5224c364-6181-4408-81a7-0c3519d0ac98
depends-on: CASM Phase 13, complete and user-approved 2026-08-21 (brain/walkthroughs/2026-08-21-casm-phase13-wp85-consolidated-completion.md); CASM progress feature complete 2026-08-31 (0.5.x); post-Phase-13 open item WP79 (deferred, unrelated)
---

# Plan: CASM Phase 14 - Local Labels (CASM 0.6)

## Status

**Approved 2026-09-01.** WP86 is now underway on `feature/casm-phase14`
(WPs branch as `feature/casm-phase14-wpNN`). Taskwarrior: Phase 14 parent
`4cf10e7c-9365-46cf-94e1-5e4bd8d44635`, WP86
`5224c364-6181-4408-81a7-0c3519d0ac98`.

Parent plan: `brain/plans/2026-07-16-casm-assembler-implementation-plan.md`
— see its own **Phase 14: Local and Anonymous Labels (CASM 0.4)** section
for the frozen scope this plan expands into work packages. (The parent
plan pins Phase 14 at "CASM 0.4"; CASM has since moved past that through
the unnumbered progress-indication feature. This plan targets **CASM
0.6.0** — Phase 13 closed at 0.4.0, the progress feature took it to 0.5.0,
and post-progress hardening reached 0.5.2 build 1392.)

Baseline: CASM `0.5.2` build `1392` (`src/external/casm/BUILD_CASM`),
Phase 13 complete, progress feature complete, `progclear-early-fatal-fix`
(task 43) merged to `main` at `79f98b2`.

WP numbering continues the running counter. Phase 13 used WP81-85; the
post-Phase-12 hardening set used WP77-80; post-Phase-13 individual fixes
used ad-hoc task numbers, not WP numbers. **Phase 14's work packages start
at WP86.**

## Objective

Deliver **named local labels** scoped to the nearest preceding global
label, using ca65's `@name` "cheap local" spelling. A local label:

- is defined with `@name:` and referenced as `@name` in any expression
  position a global label is already legal in (branch/absolute operand,
  `.byte`/`.word` operand, `.assert`, named-constant RHS);
- is visible only within the scope opened by the most recent global label
  and closed by the next global label (or EOF);
- gets its address assigned in Pass 1, in definition order, identically in
  Pass 2, exactly as a global label does;
- may reuse a name already used as a local under a different global label,
  and may shadow a global name within its scope;
- produces scoped diagnostics — an undefined/duplicate local names its
  owning global label in the message — and appears in the `/M` symbol map
  qualified by its owning global.

**Explicitly excluded from Phase 14** (deferred, per user decision
2026-09-01):

- **Anonymous forward/backward labels** (`:` definition, `:+` / `:-` /
  `:++` references). The master plan lists these as the "optional" half of
  Phase 14; they become their own separately-planned phase. They need new
  lexer token handling, an anonymous-label ring buffer, and Pass 1/Pass 2
  positional-identity matching — a materially different mechanism from
  named locals, and better isolated.
- Nested/hierarchical scopes, `.scope`/`.proc` blocks, `::` global-scope
  override, unnamed local scopes. Phase 14 has exactly one level: global
  label opens a flat local scope.
- Any change to how global labels, constants, or existing expression
  grammar behave. Locals are purely additive: a source file containing no
  `@` token must assemble to byte-identical output.

## Scoping Decisions (user-confirmed 2026-09-01)

1. **Syntax: ca65 `@name` cheap locals.** An identifier prefixed with `@`,
   scoped to the nearest preceding non-local label. Chosen for
   compatibility with the toolchain CASM already tracks (`ca65`) and
   because it needs no change to the directive namespace. Leading-dot
   `.name` (rejected — collides with directive scanning) and
   leading-underscore convention (rejected — not real scoping) were the
   alternatives.
2. **Anonymous labels deferred** to a later, separately-planned phase
   (see Objective / Excluded).
3. **DASH adoption IS in scope** — a dedicated work package (WP91)
   migrates suitable DASH-internal labels to `@local` and re-verifies DASH
   builds byte-identical, mirroring Phase 12 WP71 and Phase 13 WP84.
4. **Scope stored in reserved record padding.** Two of the 18 reserved
   padding bytes (offsets 46-63) in the existing 64-byte symbol record
   hold the owning-scope record index; one spare flag bit marks the record
   LOCAL. No change to the VMM symbol-table allocation, no new side table,
   no new cleanup owner.

## Research Summary

Pre-planning survey of the current tree (this session, 2026-09-01):

1. **Lexer identifier scanning** (`lexer.s` `lnId` / `isIdFirst` /
   `isIdCont`): first char is `A-Z a-z _`; continuation adds `0-9`. A
   single-char identifier equal to `A`/`X`/`Y` is reclassified
   `CASM_TOKEN_REGISTER`; otherwise `classifyMnemonic` may reclassify to
   `CASM_TOKEN_MNEMONIC`; else `CASM_TOKEN_IDENTIFIER`. `@`
   (`CASM_PETSCII_AT`, not currently a defined constant) is today an
   invalid source byte. Directives are a separate leading-`.` scan
   (`lnDirective`), not identifiers.
2. **Statement dispatch** (`parser.s` `parserParseStatement`): a leading
   `CASM_TOKEN_IDENTIFIER` goes to `ppsLabel`, which copies the name into
   `CasmLabelName`/`CasmLabelNameLen` then requires `COLON` (label) or
   `EQUALS` (named constant, `ppsConstant`). It never inserts a symbol —
   `casm.s`'s pass driver (`crpLabel` / `crpConstant`) does, via
   `symbolsInsert`.
3. **Symbol record** (`common.inc`): 64 bytes. Live fields end at
   `CASM_SYMBOL_REC_DEFINED_AT_OFFSET_HI` = 45. Offsets **46-63 are
   reserved padding**, zero-filled by `symbolsInsert`'s staging-record
   wipe. Flags byte (offset 34) uses bits 0-3
   (DEFINED/CONSTANT/RESOLVED/LABEL_DERIVED); **bits 4-7 are free**.
   `CASM_SYMBOL_MAX` = 512, `CASM_SYMBOL_BUCKET_COUNT` = 128.
4. **Insert ABI** (`symbols.s`): `symbolsInsert` already reads a family of
   caller-set `CasmSymbolInsert*` module globals (WP65 pattern) rather
   than packing everything into registers. Adding
   `CasmSymbolInsertScopeLo/Hi` and a LOCAL bit in `CasmSymbolInsertFlags`
   fits that pattern with no signature change.
5. **Lookup / resolver ABI** (`symbols.s` `symbolsLookup`): calling
   convention is frozen to match `exprEvaluate`'s resolver callback
   (`expr.s`). It is bound as the resolver with zero adapter code. A
   scope filter therefore cannot be a new parameter — it must be a
   module global (`CasmSymbolLookupScopeLo/Hi` + an "apply scope filter"
   flag) that the pass driver sets before each statement's expression
   evaluation, read inside `symbolsFindChain`.
6. **Two-pass model** (`casm.s`): Pass 1 assigns addresses; Pass 2
   re-parses identically and re-evaluates expressions against the
   now-complete table. Forward references are resolved in Pass 2. A
   forward reference of unknown width is assumed 16-bit in Pass 1 (WP76
   width-agreement work). **Local forward references inherit exactly this
   existing behavior** — no new width machinery, but the plan must show
   Pass 2 re-establishes `CasmCurrentScope` in lockstep with Pass 1 so a
   `@fwd` reference resolves against the same scope in both passes.
7. **Deferred named-constant references** (`symbols.s` REF_* fields,
   offsets 37-43): a constant whose RHS is a forward identifier stores a
   name+offset bookmark for the Pass1→Pass2 resolution sweep. If a
   constant's RHS is allowed to be a local label, that bookmark must also
   capture the scope. **Decision: forbid a local label on a named
   constant's RHS in Phase 14** (`@x = ...` and `foo = @x` both rejected
   with a clear diagnostic) — keeps the sweep untouched.

   **Precedent note (2026-09-01):** this is an implementation-cost decision,
   not an industry norm. Both `@x = expr` and `foo = @x` assemble in
   **ca65** (the toolchain CASM tracks and cross-checks against — see
   `src/external/casm/AGENTS.md`) and in **Turbo Macro Pro running natively
   on the C64** — the closest architectural analogue to CASM (native,
   two-pass, forward refs resolved in Pass 2). ACME, 64tass, KickAssembler
   and DASM likewise treat a local label as a first-class symbol legal on
   either side of `=`. Some cross-assembler ports (e.g. tmpx / 64tass
   reading TMP source) apply the stricter behavior CASM is adopting here.
   CASM Phase 14 therefore knowingly ships a native-assembler-compatibility
   gap: the `@name` *spelling* is ca65-compatible but the *usage rules* are
   stricter, and a TMP/ca65 source using this construct will not port
   cleanly. WP92 user-facing docs must state this divergence explicitly
   alongside the syntax description, not leave it as an internal limit.

   **Revisit trigger:** reconsider in the separately-planned anonymous-label
   phase, or at the first real TMP/ca65 source-import friction — whichever
   comes first — rather than waiting for an unspecified "real need". If
   relaxed, the `REF_*` bookmark grows a 2-byte owning-scope field and the
   Pass1→Pass2 sweep must re-establish `CasmCurrentScope` per deferred
   re-eval (the same cross-pass scope-desync risk the Stop Conditions
   guard).
8. **Map output** (`map.s` `mapPrint`): iterates records in definition
   order via `symbolsReadByIndex`, prints name + value + flags. Local
   rendering adds a qualified-name branch keyed on the LOCAL flag +
   SCOPE field.
9. **Listing** (`listing.s`): 40-column rows locked by `.assert`
   invariants; consumes resolved values, not symbol identity. Expected
   untouched; WP90 proves it byte-identical for a no-locals program and
   defines behavior for a program with locals (value only, same as any
   symbol).
10. **MAIN envelope**: CASM MAIN is at `$7400` after the memory-opt WP
    (task 42). Scope-filter compare in `symbolsFindChain`, scope tracking
    in `casm.s`, and qualified-name printing in `map.s` all add code.
    Envelope pressure is a real risk and a Stop Condition below.
11. **Phase test image**: Phase 13 got `casm_phase13_test.d64`
    (`CMakeLists.txt:2528`). Per the per-phase-test-images workflow,
    Phase 14 gets its own `casm_phase14_test.d64` (WP89).

## Technical Design

### Syntax and lexing

- New constant `CASM_PETSCII_AT` in `common.inc`.
- `@` is legal **only as an identifier's first character**. `lnId` is
  entered when the lookahead is `@` OR passes `isIdFirst`. When entered on
  `@`, the `@` is appended to the token text, consumed, and scanning
  continues with the normal `isIdCont` loop, which must then see a valid
  `isIdFirst` byte (not a digit, not another `@`, not a terminator).
- A bare `@` (followed by whitespace/newline/terminator) →
  `CASM_DIAG_INVALID_SOURCE_BYTE` at the `@` (or a dedicated
  `CASM_DIAG_MALFORMED_LOCAL_LABEL` — WP86 decides which; leaning toward
  reusing the existing invalid-source-byte diag to avoid a new code).
- `@@name`, `@1` → same rejection.
- A `@`-led token is never a register or mnemonic (length ≥ 2, leading
  `@`); it emits `CASM_TOKEN_IDENTIFIER` unconditionally. **No new token
  type** — downstream code distinguishes a local by testing whether
  `CasmTokenText[0] == '@'` / `CasmLabelName[0] == '@'`.
- Max identifier length is unchanged (`CASM_IDENT`/token-too-long path);
  the `@` counts toward it.

### Symbol record and flags (`common.inc`)

```
CASM_SYMBOL_FLAG_LOCAL   = %00010000   ; bit 4; record is a @local label
CASM_SYMBOL_REC_SCOPE_LO = 46          ; owning global label's record index, low
CASM_SYMBOL_REC_SCOPE_HI = 47          ; ... high; meaningful only when LOCAL set
```

New `.assert`s: `CASM_SYMBOL_REC_SCOPE_LO = CASM_SYMBOL_REC_DEFINED_AT_OFFSET_HI + 1`,
`CASM_SYMBOL_REC_SCOPE_HI = CASM_SYMBOL_REC_SCOPE_LO + 1`,
`CASM_SYMBOL_REC_SCOPE_HI < CASM_SYMBOL_REC_SIZE`, and a bit-disjointness
assert for the flag byte.

### Insert path (`symbols.s`)

- New exported inputs `CasmSymbolInsertScopeLo` / `CasmSymbolInsertScopeHi`.
- `symbolsInsert` copies them into `CASM_SYMBOL_REC_SCOPE_LO/HI`
  **only when `CasmSymbolInsertFlags` has `CASM_SYMBOL_FLAG_LOCAL` set**
  (same conditional-copy shape as the CONSTANT / REF_* fields). Non-local
  callers leave them at the record's zero-fill.
- Duplicate detection: `symbolsFindChain` currently matches on
  name-length + name-bytes only. It must additionally require
  `SCOPE == CasmSymScratchFilterScope` **when the record being examined
  has LOCAL set** (and, symmetrically, skip LOCAL records entirely when
  the filter is "global-only"). This makes `@loop` under `main:` and
  `@loop` under `draw:` genuinely distinct records, and lets a local
  shadow a global of the same name.

### Lookup path (`symbols.s`)

- New module globals `CasmSymbolLookupScopeLo` / `CasmSymbolLookupScopeHi`
  and `CasmSymbolLookupMode` (`0` = global-only,
  `1` = local-in-scope). The pass driver sets these immediately before any
  `exprEvaluate` call (and before any direct `symbolsLookup`), based on
  whether the *reference token* starts with `@`.
- Because one expression can mix `@local` and `global` references,
  `CasmSymbolLookupMode` cannot be statement-global. **Decision:** the
  resolver adapter path keys the mode off the *queried name itself* — the
  name passed to `symbolsLookup` still carries its leading `@`, so
  `symbolsFindChain` inspects `(CasmPtr0Lo),0`: `@` ⇒ local mode, filter
  scope = `CasmSymbolLookupScope` (the current scope, set once per
  statement); otherwise ⇒ global-only. This keeps the frozen resolver ABI
  and needs only the current-scope value as a module global.
- `symbolsFindChain`'s hash is computed over the exact name bytes
  including `@`, so `@loop` and `loop` land in (generally) different
  buckets — no behavior change for existing global lookups.

### Pass driver (`casm.s`)

- New BSS `CasmCurrentScopeLo` / `CasmCurrentScopeHi`, init to
  `CASM_SYMBOL_CHAIN_END` ($FFFF = "no scope open") at the start of **each
  pass**.
- `crpLabel`:
  - global label (name does not start with `@`): after a successful
    `symbolsInsert`, record the returned record index into
    `CasmCurrentScope`. (Pass 2: `symbolsInsert` will report
    `CASM_DIAG_DUPLICATE_SYMBOL` — the existing Pass-2 re-definition path
    already handles this by looking the symbol up instead; `CasmCurrentScope`
    is set from that lookup's record index on that path too.)
  - local label (name starts with `@`):
    - if `CasmCurrentScope == $FFFF` → `CASM_DIAG_LOCAL_WITHOUT_SCOPE`
      (new code) at the label.
    - else set `CasmSymbolInsertFlags |= CASM_SYMBOL_FLAG_LOCAL |
      CASM_SYMBOL_FLAG_DEFINED` (locals are force-abs like globals, WP39),
      `CasmSymbolInsertScope = CasmCurrentScope`, value = `CasmPc`, then
      `symbolsInsert`. Duplicate within the same scope →
      `CASM_DIAG_DUPLICATE_SYMBOL`, message scoped (see Diagnostics).
- Before evaluating a statement's operand expression, set
  `CasmSymbolLookupScope = CasmCurrentScope` (whether or not the operand
  contains a local — cheap, and correct).
- A local label as a *statement of its own* (`@name:` on its own line) is
  the only definition form; `@name` appearing mid-expression is always a
  reference.

### Diagnostics (`diagnostics.s`, `common.inc`)

- New `CASM_DIAG_LOCAL_WITHOUT_SCOPE` (next free code; WP86 assigns the
  numeric value and its message string, e.g. `LOCAL LABEL BEFORE ANY
  GLOBAL LABEL`).
- Scoped message enrichment: `CASM_DIAG_DUPLICATE_SYMBOL` and the
  undefined-symbol diagnostic, when the offending name starts with `@`,
  append ` IN <ownerGlobalName>` (owner name fetched via
  `symbolsReadByIndex(CasmCurrentScope)`). WP86 decides the exact wording
  and whether it is a suffix on the existing message or a distinct code
  (`CASM_DIAG_DUPLICATE_LOCAL` / `CASM_DIAG_UNDEFINED_LOCAL`). Leaning
  toward distinct codes for clean `.ref`-testable message bytes.
- All new/!changed message strings assemble to PETSCII; any host-side
  decoder masks `& $7F` (see `reference-casm-message-strings-petscii-mask`).

### Map output (`map.s`)

- `mapPrint`: when a record has `CASM_SYMBOL_FLAG_LOCAL`, print the
  qualified name `<ownerGlobal>@<local>` (owner fetched by
  `symbolsReadByIndex(SCOPE)`), keeping definition order. Column layout
  and truncation rule: WP90 (must stay within the existing map row width;
  truncate the *qualified* name, not just the local part).

### Testing model

- **No-locals regression is the risk gate**, every WP: a curated set of
  existing production fixtures (at minimum `casmhello`, `casmmodes`,
  `casmchain1`, a Phase 13 `.res`/`.fill` fixture) must still `COMP` as
  `FILES COMPARE OK` against their unchanged `.ref`.
- Phase 14 production fixtures live on a new `casm_phase14_test.d64`
  (WP89), each COMP-verified against a **hand-derived** `.ref.hex`
  (bytes derived from the 6502 spec + known `.org`, never from CASM —
  `project-casm-trusted-reference-rule`).
- Standalone `test_casm_*` harnesses for the lexer (WP87) and symbol
  layer (WP88, new `test_casm_scope`) follow the existing
  isolated-module-harness precedent.

## Atomic Increments (Work Packages)

**WP86 — Prerequisite reconciliation and design freeze.** No behavior
change. Assign the new `common.inc` constants (`CASM_PETSCII_AT`,
`CASM_SYMBOL_FLAG_LOCAL`, `CASM_SYMBOL_REC_SCOPE_LO/HI`, the new diag
code(s)) and their `.assert`s; add the `CasmSymbolInsertScope*` /
`CasmSymbolLookupScope*` / `CasmCurrentScope*` storage with doc comments
but no readers/writers yet; settle the open wording/code choices flagged
above (malformed-local diag, duplicate/undefined-local codes vs. message
suffix). Build clean (all links, test image), byte-identical artifacts.
Record decisions in this plan's Progress log.

**WP87 — Lexer `@`-prefixed identifier scanning.** `lnId` accepts a
leading `@`; malformed forms rejected. New `test_casm_lexer` fixtures
(accepted `@a`, `@loop2`, `@x_y`; rejected bare `@`, `@@a`, `@1`). No
parser/pass wiring. Standalone harness green; no regression in the
existing lexer harness.

**WP88 — Symbol layer scope support.** `symbolsInsert` scope stamping
under the LOCAL flag; `symbolsFindChain` scope-filtered matching (local
records honour the scope filter; global-only lookups skip local records);
`symbolsLookup` mode keyed off a leading `@` in the queried name +
`CasmSymbolLookupScope`. New standalone `test_casm_scope` harness:
same-name locals in two scopes are distinct; local shadows global; wrong-
scope lookup misses; global lookup never returns a local. `map.s` /
`symbolsReadByIndex` unchanged and re-verified.

**WP89 — Pass 1/Pass 2 driver wiring + scoped diagnostics + production
fixtures.** `casm.s` maintains `CasmCurrentScope` (both passes,
identically); `crpLabel` stamps local defs and emits
`CASM_DIAG_LOCAL_WITHOUT_SCOPE`; scoped duplicate/undefined messages.
New `casm_phase14_test.d64` (`CMakeLists.txt`, mirroring the
`casm_phase13_test_d64` block; add to the overlay build-event wrapper;
`cmake-overlay-events` skill checklist). Fixtures, each COMP-verified:
1. local as a backward branch target inside one scope;
2. the same local name reused as a branch target under two different
   globals (proves isolation);
3. a forward local reference (`bne @done` before `@done:`), resolved in
   Pass 2, output byte-identical to the hand reference;
4. `@x:` before any global label → `LOCAL WITHOUT SCOPE` rejection;
5. duplicate `@x:` in one scope → scoped `DUPLICATE` rejection;
6. `@x` referenced but never defined in scope → scoped `UNDEFINED`
   rejection;
7. a local shadowing a global of the same name — reference resolves to
   the local;
8. `@x = 1` and `y = @x` → rejected (constant-RHS locals forbidden,
   Research item 7).
Live VICE verification per `vice-mcp-testing` (boot Command64, FLUSH
before/after, fire `c64-overlay-api` test events).

**WP90 — `/M` symbol-map local rendering + `/L` non-regression.**
`map.s` qualified-name branch; deterministic definition order;
truncation within the existing row width. Fixture: a program with two
globals and locals under each, `/M` output compared to a hand-written
reference. `/L` listing proven byte-identical to pre-Phase-14 for a
no-locals program, and defined (value-only) for a with-locals program.

**WP91 — DASH adoption.** Survey `src/external/dash/` (and its
`AGENTS.md`) for internal label groups that are natural locals; migrate
the clear wins to `@local`. Re-verify DASH assembles byte-identical
(`dash.ref.hex` provenance — `project-dash-manifest-interim-ca65` is
superseded; provenance is real native-CASM since WP71). Update DASH
`AGENTS.md`: it currently bans CASM character literals wholesale
(`reference-dash-no-character-literals`) — add an explicit clause that
`@local` labels ARE permitted (they have no ca65-charmap divergence) and
note the migration.

**WP92 — Phase 14 consolidated completion gate.** Fresh, together (not
per-WP citation) re-run of every `test_casm_*` harness + every Phase 14
production fixture + the no-locals regression set. Docs: new "Local
labels" section in `docs/casm-programmers-reference.md`, updates to
`docs/casm-utility.md`, `wiki/` mirrors, `wiki/tasks/casm.md`,
`CHANGELOG.md`. Version bump to **CASM 0.6.0** (build auto-increments).
Walkthrough in `brain/walkthroughs/`. Explicit user sign-off.

## Expected Files

| File | Planned action |
| --- | --- |
| `brain/plans/2026-09-01-casm-phase14-local-anonymous-labels.md` | Create (this file); append Progress |
| `src/external/casm/common.inc` | Modify — new constants, flag bit, record offsets, `.assert`s |
| `src/external/casm/lexer.s` | Modify — `@`-led identifier scanning (WP87) |
| `src/external/casm/symbols.s` | Modify — scope insert/filter/lookup (WP88) |
| `src/external/casm/parser.s` | Modify — allow `@`-led identifier as label-def statement; reject on constant RHS (WP88/89) |
| `src/external/casm/casm.s` | Modify — `CasmCurrentScope` tracking, local stamping, lookup-scope set (WP89) |
| `src/external/casm/diagnostics.s` | Modify — new/scoped diagnostic strings (WP86/89) |
| `src/external/casm/map.s` | Modify — qualified local-name rendering (WP90) |
| `src/external/dash/*` , `src/external/dash/AGENTS.md` | Modify — local-label adoption + doc clause (WP91) |
| `cmake/GenerateCasmTestFixtures.cmake` | Modify — lexer/scope/production fixtures |
| `CMakeLists.txt` | Modify — `casm_phase14_test_d64` image target + overlay wrapper |
| `tests/src/casm_scope/*` (new harness) | Create (WP88) |
| `docs/casm-programmers-reference.md`, `docs/casm-utility.md`, `wiki/*`, `wiki/tasks/casm.md`, `CHANGELOG.md`, `VERSION` | Modify (WP92) |
| `brain/walkthroughs/2026-09-01-casm-phase14-*.md` | Create per WP + consolidated (WP92) |
| memory `MEMORY.md` + new files | Modify/Create (WP92) |

## Stop Conditions

Halt and get renewed direction if:

- any existing `test_casm_*` harness or any curated no-locals regression
  fixture fails, or a no-change rebuild alters any assembled `.ref`
  artifact;
- CASM MAIN cannot stay within its approved `$7400` envelope after an
  increment (raising it is a separate, separately-approved decision —
  `project-os-sub1000-segment-full` context);
- Pass 1 and Pass 2 disagree on any assembled byte for a Phase 14 fixture
  (local forward-reference width, or a scope-tracking desync between
  passes) — do not "fix forward", stop;
- the frozen `exprEvaluate` resolver ABI would need a signature change to
  carry scope (the module-global design must hold);
- a genuinely new defect outside Phase 14's scope surfaces — default is
  disclose-and-defer as its own task, not an inline fix, unless the user
  directs otherwise in the moment (record the deviation);
- the `casm_phase14_test.d64` source-text budget overflows the image (see
  `project-casm-testd64-source-vs-output-size` — a fixture's disk cost is
  its raw source size).

## Documentation, Task, and DOX Updates

- **At activation** (on approval): create the Taskwarrior Phase 14 parent
  + WP86 task; add the "Phase 14" section skeleton to `wiki/tasks/casm.md`
  with status `[/]`; note the branch plan (`feature/casm-phase14`, WPs on
  `feature/casm-phase14-wpNN`).
- **Per WP**: append this plan's Progress log; tick the WP in
  `wiki/tasks/casm.md`; Taskwarrior task closed; per-WP walkthrough.
- **At completion (WP92)**: `docs/casm-programmers-reference.md` (new
  "Local labels" section — syntax, scope rule, diagnostics, `/M`
  rendering, and the constant-RHS restriction stated explicitly as a
  known ca65 / Turbo Macro Pro divergence, per Research item 7),
  `docs/casm-utility.md`,
  `wiki/casm-programmers-reference.md` + `wiki/casm-utility.md` +
  `wiki/Home.md` mirrors, `wiki/tasks/casm.md` closeout paragraph,
  `brain/KNOWLEDGE.md` Phase 14 closing note, `CHANGELOG.md` Unreleased →
  Added entry, `VERSION` → `0.6.0`, memory (`project-casm-phase14-complete`
  top-level record; supersede nothing that isn't actually superseded).

## Completion Gate

Phase 14 is complete only when **all** of:

- WP86-92 individually complete and user-approved;
- a single consolidated live re-verification (all `test_casm_*` harnesses
  + all Phase 14 production fixtures + the no-locals regression set), run
  fresh together, recorded in `brain/walkthroughs/` with real evidence
  (COMP transcripts, VICE screenshots/register reads, overlay test
  events) — not per-WP citations;
- a no-locals program proven byte-identical to its pre-Phase-14 output;
- CASM within the `$7400` MAIN envelope; both link configs pass; test
  image builds; build-number check passes;
- all trackers synchronized (Taskwarrior, `brain/task.md`,
  `wiki/tasks/casm.md`, `brain/KNOWLEDGE.md`, `CHANGELOG.md`, memory);
- CASM version at `0.6.0`;
- **explicit user approval** to close the phase. No self-declared
  completion.

## Progress

- 2026-09-01: Plan drafted for review. Scoping decisions 1-4 captured from
  the user (syntax `@name`; anonymous labels deferred; DASH adoption in
  scope; scope in reserved record padding).
- 2026-09-01: **Approved by user.** Taskwarrior Phase 14 parent
  `4cf10e7c` + WP86 `5224c364` created (no Taskwarrior MCP this session —
  `task` CLI, per `feedback-taskwarrior-mcp-fallback`). Branch
  `feature/casm-phase14` created off `main` (`79f98b2`). WP86 started.
- 2026-09-01: WP86 source-complete. Added `CASM_SYMBOL_FLAG_LOCAL`,
  `CASM_SYMBOL_REC_SCOPE_LO/HI` (+ asserts), four new diagnostic
  identifiers `$57-$5A` (+ contiguity asserts, message table
  deliberately not yet updated — see walkthrough), and unread/unwritten
  scope storage (`CasmSymbolInsertScopeLo/Hi`,
  `CasmSymbolLookupScopeLo/Hi` in `symbols.s`; `CasmCurrentScopeLo/Hi` in
  `casm.s`). Full native build clean: `casm` target, `image_d64`,
  `casm_phase13_test_d64`, `test_image_d64` all built without error;
  `casm.prg` unchanged in code size/relocation count (zero new
  instructions this WP). Walkthrough:
  `brain/walkthroughs/2026-09-01-casm-phase14-wp86-design-freeze.md`.
  Awaiting user sign-off before WP87.
- 2026-09-01: **WP86 approved by user.** Taskwarrior WP86 (`5224c364`)
  closed. WP87 created (`31728848-3018-4bd4-aae3-ac68f5d3eea0`), depends
  on WP86, started.
- 2026-09-01: WP87 source-complete. `lexer.s` `lnId`/dispatch accept a
  leading `@` (legal only when immediately followed by an `isIdFirst`
  byte; malformed forms report `CASM_DIAG_INVALID_SOURCE_BYTE`, the same
  code a bare `@` already produced). Seven new `test_casm_lexer` cases
  (4 malformed, 3 accepted), harness bumped `$1000` -> `$1100`
  (measured +140 byte overflow, standard round-page-fit convention).
  `casm.prg` +66 code bytes over WP86 baseline (23737 -> 23803), zero
  diagnostic-table change (codes still unproduced). Live VICE: user
  approved taking over the running instance (previously showing a Conway
  demo); `casm_phase12_test_d64` rebuilt fresh, Command64 booted, `test_
  casm_lexer` dispatched via the shell, `CASM LEXER: PASS` (26/26 cases)
  at a clean `c64[8]:>` return. Walkthrough:
  `brain/walkthroughs/2026-09-01-casm-phase14-wp87-lexer-local-
  identifiers.md`. Awaiting user sign-off before WP88.
- 2026-09-01: **WP87 approved by user.** Taskwarrior WP87 (`31728848`)
  closed. WP88 created (`c345de9c-b450-4266-912d-e5c075f77cd5`), depends
  on WP87, started.
- 2026-09-01: WP88 source-complete. `symbolsInsert` stamps
  `CASM_SYMBOL_REC_SCOPE_LO/HI` for LOCAL records; `symbolsFindChain`'s
  `sfcMatch` scope-checks a candidate only when it carries the LOCAL
  flag; `symbolsInsert`/`symbolsLookup` each copy their own
  Insert/LookupScope into a shared `CasmSymScratchFilterScopeLo/Hi`
  before calling the chain walker. Design simplified from WP86's
  original "name-prefix mode dispatch" doc comment: unnecessary, since a
  local's stored name already includes the literal `@`. **Found and
  fixed a real live defect**: the scope-filter copy clobbered `A`
  (nameLen) before `jsr symbolsFindChain` in both routines, missed by
  static review and a clean build; caught only by the new
  `test_casm_scope` harness's first live run (`CASM SCOPE: FAIL`, 2/12
  cases), fixed with `pha`/`pla`, re-verified `PASS` 12/12, and the
  pre-existing `test_casm_symbols` (Phase 6B/WP60) harness re-run live
  to prove the fix didn't regress the unscoped call shape (`PASS`).
  New dedicated `casm_phase14_test_d64` created (test.d64 hit its
  directory-entry ceiling live adding this WP's harness). Walkthrough:
  `brain/walkthroughs/2026-09-01-casm-phase14-wp88-symbol-scope-
  support.md`. Awaiting user sign-off before WP89.
- 2026-09-01: **WP88 approved by user.** WP88 (`c345de9c`) closed. WP89
  created (`bb4e956b-ec93-4216-97b1-f1f29ee7e0f7`), depends on WP88,
  started.
- 2026-09-01: WP89 source-complete. `casm.s`: `CasmCurrentScope` as a
  global-label ordinal (reset per pass, bumped by `crpLabel` identically
  both passes); `crpLabel` splits global vs `@local`, stamps LOCAL+scope
  on Pass-1 insert, raises `LOCAL_WITHOUT_SCOPE`/`DUPLICATE_LOCAL`;
  `casmRunPass` publishes `CasmSymbolLookupScope` before each statement's
  operand-expression eval. `parser.s`/`expr.s`: `LOCAL_IN_CONSTANT`
  rejects `@` on either side of `=`; `CasmExprPrimaryWasLocal` flag lets
  `pevUnresolved` raise `UNDEFINED_LOCAL`. `diagnostics.s` + the verify
  script wired for codes `$57-$5A` (now "90 diagnostic identifiers");
  `diagPrintFatal`'s runtime range check retargeted to
  `CASM_DIAG_PHASE14_WP86_LAST`. Two real defects found live: stale
  fatal-diagnostic location (fixed with `diagSetLocFromStmt` in
  `crpLabel`) and the un-retargeted runtime range check (printed
  `INTERNAL ERROR` for `$57`). 9 production fixtures on a rebuilt
  `casm_phase14_test_d64` (4 accepted `FILES COMPARE OK`, 5 rejected with
  correct scoped diagnostics + source locations, all live-verified on
  `CASM V0.5.2.1399`). No-locals regression: `casmassert1` COMP OK on
  1399. MAIN headroom 2245 bytes. NOTE: `c64-overlay-api` MCP was down
  all session -- overlay test events fired via curl fallback from
  mid-WP89 on (see walkthrough + `feedback-overlay-api-curl-fallback`).
  Walkthrough:
  `brain/walkthroughs/2026-09-01-casm-phase14-wp89-pass-driver-wiring.md`.
  Awaiting user sign-off before WP90.
- 2026-09-01: **Standalone hardening** (Taskwarrior
  `df92683b-8e68-4350-8e0e-b80ad7c80720`, not a Phase 14 WP), user-directed
  after the WP89 review question. Collapsed the three hardcoded "highest
  valid diagnostic id" sites (`diagPrintFatal` runtime range check, the
  `diagMsgLo`/`diagMsgHi` length asserts, `verify_casm_diag_table.py`)
  onto one `CASM_DIAG_LAST` symbol in `common.inc`. The build-breaking
  table-length assert now pins the runtime check and the verify script to
  the same value -- they can no longer drift behind the table (the WP89
  defect). Deliberate-break test confirmed the assert fires. Assembled
  logic byte-identical. Walkthrough:
  `brain/walkthroughs/2026-09-01-casm-diag-table-single-source-of-truth.md`.
- 2026-09-01: **WP89 approved by user.** WP89 (`bb4e956b`) closed. WP90
  created (`f7010987-a1b3-4f97-8f07-439a496504db`), started.
- 2026-09-01: Research item 7 expanded (no behavior change) after a user
  industry-consistency question. Recorded that forbidding a local label on
  a constant's RHS is an implementation-cost decision, not a norm: ca65
  and Turbo Macro Pro (native on the C64 — CASM's closest architectural
  analogue) both allow `@x = expr` and `foo = @x`; CASM matches the
  stricter cross-assembler-port behavior instead. Item 7 now carries the
  precedent survey, names it a known ca65/TMP divergence WP92 docs must
  state explicitly, and replaces the vague "revisit if a real need
  appears" trigger with "revisit in the anonymous-label phase or at first
  TMP/ca65 source-import friction".
- 2026-09-01: WP90 source-complete. `map.s`: `mapPrint`/`mapFormatRow`
  render a `@local` row as `<owner>@<local>` (owner = the most recent
  global in the definition-order walk), capped at 31 bytes;
  `mapPrint` cross-checks each local's stored SCOPE ordinal against the
  walk's global count. `mapValidateRecord` rebuilt per-field for the real
  WP65/76/86 record layout -- **folded in a user-approved latent fix**:
  before this, every named constant defined past file offset 0 tripped
  `SYMBOL MAP INVALID` under `/M` (`DEFINED_AT_OFFSET` at 44-45 checked as
  reserved; `/M` untested with constants since Phase 10). `test_casm_map`
  now 25 cases (was 23), harness MAIN `$1400`->`$1600`; live `CASM MAP:
  PASS`. Production fixtures `casmmaploc` (renders `MAIN@LOOP` /
  `DRAW@DONE`) and `casmmapconst` (constant, no `SYMBOL MAP INVALID`) on
  `casm_phase14_test_d64`, live-verified on `CASM V0.5.2.1403`; `/M` and
  `/L` PRGs `FILES COMPARE OK` vs baseline. Overlay events fired via curl
  (MCP still down). Walkthrough:
  `brain/walkthroughs/2026-09-01-casm-phase14-wp90-map-local-rendering.md`.
  Awaiting user sign-off before WP91.
- 2026-09-01: **WP90 approved by user.** WP90 (`f7010987`) closed. WP91
  created (`af6a65ad-3d1a-42d4-9b1d-d0b26cc26c2a`), started.
- 2026-09-01: WP91 source-complete. `dfmt.s`: `FORMATDEC16`/`PETTOSCREEN`/
  `DIV10` adopt `@LOOP`/`@DONE`/`@SKIP` (5 global labels -> routine
  `@locals`, all verified locally-referenced). DASH `AGENTS.md` gains a
  "Dual-Assembler Subset" clause: `@local` shared with ca65, anon
  `:+`/`:-` not; the no-mid-code-`=` and no-`@name`-reuse-per-scope
  constraints. **Zero byte change proven three ways**: ca65 `dash_ref`
  byte-identical (4766 B, sha `3238b786`) to the prior manifest; native
  CASM under VICE (`0.5.2.1403`, REU) -> 4766 B, `COMP DASH.PRG DASH.REF`
  -> `FILES COMPARE OK`; extracted native `dash.prg` `cmp`-identical to
  both. `dash.ref.hex` regenerated via `build_dash_manifest.py
  --cross-check` (same bytes, fresh source hashes, no `--allow-host-bytes`).
  Folded in a WP89 build gap: `test_casm_include` stubs the expr
  evaluator and lacked `CasmExprPrimaryWasLocal` -> added a 1-byte BSS
  stub. Full `cmake --build build` green. Walkthrough:
  `brain/walkthroughs/2026-09-01-casm-phase14-wp91-dash-adoption.md`.
  Awaiting user sign-off before WP92.
