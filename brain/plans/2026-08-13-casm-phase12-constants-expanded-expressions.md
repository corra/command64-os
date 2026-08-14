---
feature: casm-phase12-constants-expanded-expressions
created: 2026-08-13
status: approved
taskwarrior: c547c74f-5080-4f2e-b086-e4e2273b5336
depends-on: none (Phase 11 closed 2026-08-13)
---

# Plan: CASM Phase 12 - Constants and Expanded Expressions (CASM 0.3)

## Status and Authorization

**Approved 2026-08-13.** The WP64-71 breakdown, sequencing, and version
target below are confirmed as drafted (all three Open Questions resolved
as-is — see Progress). This approval creates the task hierarchy and
authorizes WP64's own detailed plan, but does not itself authorize source
edits. WP64 (and every WP after it) still requires its own detailed plan
and explicit user approval before implementation, per
`.agents/workflows/phased-implementation-planning.md`.

Parent plan: `brain/plans/2026-07-16-casm-assembler-implementation-plan.md`
(the master CASM implementation plan — see its own Phase 12 section,
lines 406-418, for the frozen, one-paragraph scope this plan expands into
work packages).

Baseline: CASM `0.2.2` build `1266`, Phases 1-11 complete and user-approved
(Phase 11 closed 2026-08-13 — see
`brain/plans/2026-08-08-casm-phase11-base-release-hardening-documentation.md`
and its WP63 closing walkthrough,
`brain/walkthroughs/2026-08-12-casm-phase11-wp63-verification-walkthrough-completion-gate.md`).

## Objective

Phase 12 is CASM's first *feature* phase since Phase 10 (Phase 11 was
hardening-only, no new behavior). Per the master plan it adds: named
constant definitions, a current-address symbol, parenthesized/explicit-
precedence expressions, multiplication/division/shifts/bitwise
operations/unary negation/complement, character literals with documented
string encoding, circular-definition and division-by-zero diagnostics, and
relocation algebra limited to combinations that remain representable.
Target version: CASM `0.3` (the master plan's own explicit version target
for this phase, unlike Phase 11 which stayed within `0.2.x`).

**Risk gate (master plan, verbatim):** expanded expressions must preserve
the base relocation classifier and must not change existing program bytes.
Every currently-shipping fixture's assembled output must remain
byte-identical after this phase.

## Scoping Decisions (user-confirmed 2026-08-13)

Three open questions were resolved before drafting the work-package
breakdown below, not assumed:

1. **Work Packages, not a single-phase increment list.** Mirrors Phase
   10 (WP50-55) and Phase 11 (WP56-63)'s own precedent — appropriate given
   Phase 12 bundles 7 largely-independent sub-features, several of which
   carry their own real design risk (relocation algebra, an evaluator
   architecture change for precedence).
2. **A dedicated contract-freeze WP comes first**, before any sub-feature
   implementation. Mirrors Phase 6A (VMM Storage Foundation) and Phase
   11's own WP56 (contract reconciliation): the relocation-classifier
   risk gate is a genuine cross-cutting design question — how does
   `CASM_EXPR_FLAG_RELOCATABLE` (and the classifier that produces it)
   extend to cover multiplication/division/shifts/bitwise/parenthesized
   forms, and which combinations on relocatable operands get accepted vs.
   diagnosed as unrepresentable — and answering it piecemeal inside each
   later WP risks inconsistent rules or a late architectural rework.
3. **Work-package order is proposed here for approval**, not left
   unordered. See below.

## Proposed Work-Package Breakdown

Numbering starts at WP64 (Phase 11 closed at WP63). **This breakdown,
including WP boundaries and order, is the primary thing under review in
this plan** — nothing below is final until approved, matching the Phase
11 governing plan's own framing.

Dependency spine (load-bearing order): **WP64 → WP67 → WP68 → WP70 →
WP71**. WP65, WP66, and WP69 are proposed in this position but are
largely independent of each other and of the spine — flag if you'd rather
reorder or interleave them.

- **WP64 — Contract freeze: expression evaluator architecture and
  relocation algebra.** No production behavior change. Designs, before
  any implementation: how the relocation classifier extends to
  multiplication/division/shifts/bitwise/parenthesized expressions and
  exactly which operator/operand combinations on relocatable values are
  representable in one R6 relocation entry vs. must be rejected; the
  parser architecture change needed for explicit precedence (precedence
  climbing vs. a recursive-descent rewrite of `expr.s`, and its cost in
  code size/cycles per the project's own performance standard); the
  symbol-table ABI for a new "named constant" symbol kind distinct from a
  label; the current-address symbol's own representation (almost
  certainly relocatable, since it's PC-relative to load address); and the
  diagnostic numbering for circular-definition and division-by-zero
  (extending `common.inc`'s contiguous diagnostic-range convention); and
  the lowercase-PETSCII-only convention
  ([[reference-c64-lowercase-petscii-convention]], user-flagged
  2026-08-13) for every new token/symbol form this phase introduces —
  named constants, the current-address symbol's own token, and character-
  literal documentation all default to and recommend lowercase, matching
  real C64 convention rather than treating mixed case as equally
  idiomatic just because CASM's existing case-sensitivity permits it.
  Produces the contract every later WP in this phase implements against.
- **WP65 — Named constant definitions.** New directive/syntax for
  `name = expression` (exact syntax TBD in WP64's contract — needs to
  distinguish cleanly from a label definition; lowercase per the
  convention above, not `NAME`), a new symbol-table entry kind, and the
  circular-definition diagnostic (`a = b`, `b = a`). Usable immediately
  with the *existing* single-symbol-plus-addend expression grammar;
  becomes more useful once WP67/WP68 land, not blocked on them.
- **WP66 — Current-address symbol.** A new expression primitive (the
  master plan doesn't name its exact token; ca65 convention is `*`) that
  yields the current assembly-position address, relocatable by
  construction. Independent of WP65.
- **WP67 — Parentheses and explicit precedence.** The evaluator
  architecture change WP64 designs: grouping and precedence rules for
  everything that follows. Proposed *before* WP68 so operators are
  correct-by-construction against a stable precedence contract from the
  start, rather than shipping flat left-to-right evaluation now and
  changing already-shipped expression results later when precedence
  lands.
- **WP68 — Arithmetic and bitwise operators.** Multiplication, division
  (plus the division-by-zero diagnostic), shifts, bitwise AND/OR/XOR,
  unary negation, and complement — "where practical on the 6510" per the
  master plan, since the 6502/6510 has no native multiply/divide and
  needs a software routine, a real cycle-cost/code-size question for
  WP64 to size and this WP to implement against. Depends on WP67's
  precedence contract being in place.
- **WP69 — Character literals and documented string encoding.**
  Lexer-level: recognizing `'a'`-style literals and defining exactly how
  they encode (PETSCII, matching this project's existing charmap
  conventions — see [[reference-casm-petscii-identifier-case]] and
  [[reference-casm-charmap-hex-digit-formatting]] for the established
  pattern this needs to stay consistent with). Documentation examples
  default to lowercase per
  [[reference-c64-lowercase-petscii-convention]]. Independent of the rest;
  placed late here only because it's lower-risk and doesn't block or get
  blocked by anything else, not because it's lower priority.
- **WP70 — Relocation algebra closure.** Consolidated verification that
  every operator/operand combination WP65-69 actually shipped matches
  WP64's representability contract exactly: accepted combinations produce
  correct R6 relocation entries, rejected combinations produce a clear
  diagnostic rather than silently wrong output. This is where the master
  plan's risk gate gets its direct proof, not assumed from WP64's design
  alone.
- **WP71 — Verification, walkthrough, completion gate.** Mirrors WP49
  (Phase 9), WP55 (Phase 10), and WP63 (Phase 11)'s own closing pattern:
  full regression build, a *consolidated* fresh live-VICE re-run of every
  `test_casm_*` harness plus every new Phase 12 harness in one continuous
  session (not just citing each WP's own individual pass — WP63 found a
  real defect specifically because it was the first session to do this),
  byte-identity proof that every Phase 1-11 fixture's output is
  unchanged, the user's own manual runtime walkthrough, and explicit
  approval before Phase 12 is marked done.

## Completion Gate

Phase 12 completes only when every work package above (as finalized after
this plan's review) is individually planned, approved, implemented, and
verified; the relocation-classifier risk gate is directly proven, not
assumed; every Phase 1-11 fixture's assembled output remains
byte-identical; documentation (`docs/casm-utility.md`,
`wiki/casm-programmers-reference.md`, `brain/KNOWLEDGE.md`,
`CHANGELOG.md`) reflects the new syntax and semantics; and the user
completes the native runtime walkthrough and explicitly approves the
`0.3` release.

## Open Questions For This Review

**Resolved 2026-08-13 — all three confirmed as drafted, no changes
requested.** Recorded as asked, matching the Phase 11 governing plan's
own precedent for this section:

1. Does the WP64-71 breakdown above match the intended shape, or should
   any of these be split, merged, or reordered? In particular: should
   WP65/WP66/WP69 (the independent ones) be reordered, combined, or
   interleaved with the dependency-spine WPs rather than run sequentially
   after them?
2. Exact syntax for named constants (`NAME = expr`? `NAME .EQU expr`?
   something else?) and the current-address symbol's token (`*`
   conflicts with multiplication once WP68 lands — needs its own
   resolution, likely context-sensitive parsing or a different token) are
   both left to WP64's own design rather than fixed here. Confirm that's
   the right level for this governing plan, or specify a preference now.
3. Version target: master plan says `0.3` for Phase 12. Default plan,
   matching every prior feature phase's pattern: each WP bumps
   `VERSION_STAGE` on its own completion within `0.2.x` until the whole
   phase is ready, then a final completion-promotion WP (like Phase 10's
   own separate `0.1.56` → `0.2.0` promotion step) bumps to `0.3.0`.
   Confirm or redirect.

## Progress

- 2026-08-13: User asked to begin Phase 12. Per
  `.agents/workflows/phased-implementation-planning.md`, "beginning"
  means drafting and getting approval for a detailed plan, not writing
  code. Found Phase 12 already scoped in the master plan
  (`brain/plans/2026-07-16-casm-assembler-implementation-plan.md:406-418`)
  — 7 sub-features plus a relocation-preservation risk gate, no prior
  detailed plan existed. Asked three scoping questions (Work-Package
  structure vs. single phase, dedicated contract-freeze WP vs. handling
  the risk gate per-WP, and who proposes WP ordering); user confirmed all
  three recommended defaults. Drafted the WP64-71 breakdown above and
  recorded it for review. Taskwarrior task 43
  (`c547c74f-5080-4f2e-b086-e4e2273b5336`) created as the Phase 12
  parent, status `Pending`, not yet started. **Not yet approved** — the
  three Open Questions above remain live.
- 2026-08-13: User flagged a previously-undocumented convention gap: real
  C64 platforms run a single-case PETSCII mode, so idiomatic symbols are
  single-case (lowercase) by convention — Command64's mixed-case charset
  (and CASM's resulting true case-sensitivity) is an anomaly, not a
  license to mix cases. Not previously noted anywhere; added to
  `docs/casm-utility.md`/`wiki/casm-utility.md` (kept byte-identical) and
  `wiki/casm-programmers-reference.md`'s existing case-sensitivity
  sections, recorded as memory
  [[reference-c64-lowercase-petscii-convention]], and folded into this
  plan's WP64 (contract freeze — applies to every new token/symbol form
  this phase introduces), WP65 (named-constant syntax examples switched
  to lowercase), and WP69 (character-literal documentation examples). No
  source/behavior change — CASM already supports whatever case a user
  types; this is a documentation/convention note only. User also mentioned
  a possible future single-case-mode feature for Command64 itself
  (OS/charset-level, broader than CASM) — noted in the memory as a future
  idea, not scoped or added to this plan's own WP breakdown.
- 2026-08-13: **User approved this governing plan as drafted.** WP64-71
  breakdown, sequencing, and version-bump timing confirmed with no
  changes. This authorizes WP64's own detailed plan; source edits remain
  gated on WP64's own plan and separate approval, per this project's
  per-WP convention. Next: draft WP64 (contract freeze).
