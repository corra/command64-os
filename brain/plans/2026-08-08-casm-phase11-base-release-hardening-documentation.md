---
feature: casm-phase11-base-release-hardening-documentation
created: 2026-08-08
status: proposed
taskwarrior: ca5d69aa-b674-4a24-a7fa-55160755d47a
depends-on: 94d98a2b-7ad4-49f0-bf33-38702690eca9
---

# Plan: CASM Phase 11 - Base-Release Hardening and Documentation

## Status and Authorization

**Proposed, not yet approved.** This is a draft for the user's review — the
work-package breakdown, sequencing, and version target below are all open for
adjustment before this plan is approved. Approval creates the task hierarchy
(already partially seeded — see Taskwarrior above) and authorizes each
individual WP's own detailed plan, but does not itself authorize source edits.
Each work package still requires its own detailed plan and explicit user
approval before implementation, per this project's established convention.

Parent plan: `brain/plans/2026-07-16-casm-assembler-implementation-plan.md`
(the master CASM implementation plan — see its own Phase 11 section for the
frozen, one-paragraph-per-bullet scope this plan expands into work packages).

Baseline: CASM `0.2.0` build `1260`, Phases 1-10 complete and user-approved
(Phase 10 closed 2026-08-08 — see
`brain/plans/2026-07-29-casm-phase10-symbol-map-listing.md`).

## Objective

Phase 11 adds no new language feature, directive, or output format. It is a
hardening and documentation phase: audit the complete CASM `0.1`/`0.2` base
release (every module built across Phases 1-10) for correctness under
boundary and failure conditions the happy-path test suites don't exercise,
close known carried-forward debt, and bring every tier of documentation back
into agreement with the actual shipped behavior. It ends with the user's own
manual runtime walkthrough deciding whether the base release is done — per
the master plan, "the task is not marked done without that confirmation."

## Scoping Decisions (user-confirmed 2026-08-08)

Two open questions from the master plan's broad Phase 11 bullet list were
resolved before drafting this plan, not assumed:

1. **Risk-based audit, not exhaustive systematic audit.** Prioritize the
   newest and least-audited modules (`listing.s`, `map.s` — Phase 10, built
   under real production pressure across WP51-54, never independently
   re-audited the way WP55 re-audited their *behavior* rather than their
   *internal contracts*), the 3 already-known carried-forward items from
   Phase 4 (below), and the disclosed fault-injection gap — then expand
   outward by risk rather than working through every module in build order.
   This plan explicitly records what was *not* exhaustively re-audited and
   why, rather than silently narrowing scope.
2. **Build real fault-injection infrastructure.** The master plan's own
   Phase 11 bullet names "no-REU, out-of-memory, missing-device, no-disk,
   disk-full, partial read/write, and output-cleanup behavior" as in-scope.
   WP55 already found and disclosed that `CASM_DIAG_LISTING_CREATE_FAILED`/
   `CLOSE_FAILED`/`DELETE_FAILED`/`SHORT_WRITE` (and `fileio.s`'s own
   identical-shape Phase 2 diagnostics) have never been independently
   fault-injected anywhere in this codebase, for lack of any stubbable
   `OS_API` layer — every existing failure proof relies on a genuinely
   full disk or genuinely exhausted registry. Phase 11 builds that
   infrastructure rather than continuing to cite the gap as accepted.

## Known Carried-Forward Debt (found during this plan's own research, not new)

Recorded in `brain/task.md` (Phase 4 section) since 2026-07-21 and never
individually actioned:

1. `CasmOutputCreated` conflates "created" with "opened an existing file" —
   needs tracing to its actual call sites to determine whether this is a
   real correctness bug (e.g. affecting `outputAbort`'s delete-vs-preserve
   decision) or a naming/comment inaccuracy with no behavioral effect.
2. No `CLD` (clear decimal mode) at CASM's application entry point. Also
   independently flagged in `brain/KNOWLEDGE.md` (Phase 5 section) as
   "inherited hardening debt rather than a Phase 5 guarantee" — every
   `ADC`/`SBC` path in the expression evaluator already establishes carry
   explicitly and executes neither `SED` nor `CLD` itself, so the real
   question is whether the C64 KERNAL/Command64 OS already guarantees binary
   mode at application entry (in which case this is a documentation-only
   fix) or whether a stale `D` flag from a prior application could actually
   corrupt CASM's own arithmetic (a real bug).
3. No dedicated CASM Phase 4 contract section in `brain/KNOWLEDGE.md` —
   compare against later phases' own KNOWLEDGE.md sections (Phase 5 onward
   all have one) and backfill the gap for the parser/opcode-table/numeric-
   emission contracts Phase 4 established.

## Proposed Work-Package Breakdown

Numbering starts at WP56 (Phase 10 closed at WP55). **This breakdown is the
primary thing under review in this plan** — order, granularity, and scope of
each WP are all negotiable before approval.

- **WP56 — Contract reconciliation.** Mirrors WP50's role for Phase 10: no
  production behavior change. Triage every CASM module for audit risk (age,
  prior test depth, real-bug history), formally scope in the 3 carried-
  forward items above with a concrete remediation plan for each, and
  produce the prioritized, module-by-module audit order every later WP in
  this phase follows. Produces the risk register this plan's "risk-based,
  not exhaustive" scoping decision depends on being able to point to.
- **WP57 — Fault-injection infrastructure.** Design and build a stubbable
  `OS_API`/DOS layer (or equivalent interception point) so file-open/read/
  write/close/delete and VMM alloc/free/transfer calls can be made to fail
  deterministically, on demand, without needing a genuinely full disk or
  genuinely exhausted registry. Needs its own dedicated plan given the size
  (this is new, permanent test infrastructure, not a one-off fixture) —
  candidate design questions for that plan: does this live in a test-only
  build variant of `fileio.s`/`vmm_store.s`, a link-time substitution, or a
  runtime hook; what's the envelope cost; does it risk masking a real bug
  by being too permissive.
- **WP58 — Apply fault-injection across file/VMM-touching modules.**
  Exercise `CREATE_FAILED`/`WRITE_FAILED`/`CLOSE_FAILED`/`DELETE_FAILED`/
  `SHORT_WRITE` and the no-REU/OOM/missing-device/no-disk/disk-full/
  partial-read-write cases using WP57's infrastructure, not just for
  `listing.s` (WP55's original disclosed gap) but for every module that
  owns a file handle or VMM allocation: `fileio.s`, `source.s`, `symbols.s`,
  `reloc.s`, `include.s`, `vmm_store.s` itself.
- **WP59 — `listing.s`/`map.s` hardening.** The newest, least individually
  audited modules. Verify carry propagation, register clobbers, stack
  balance, and zero-page/BSS ownership against each routine's own header
  contract, the way WP55's Full-Path Review did for the specific call
  sequences it traced — but here applied as a general audit of every
  exported routine in these two modules, not just the ones WP55's
  particular verification matrix happened to exercise.
- **WP60 — Known debt + opcode/addressing-mode coverage.** Close the 3
  Phase-4 carried-forward items per WP56's remediation plan. Separately,
  systematically exercise every documented 6502/6510 opcode across every
  addressing mode it supports (the master plan's own "every official
  opcode/addressing-mode combination" bullet) plus literal/address/PC/
  source/symbol/VMM/relocation boundary values — likely reusing and
  extending Phase 4's own `casmmodes.ref`-style per-addressing-mode
  certification precedent rather than inventing a new methodology.
- **WP61 — Determinism + remaining spot-checks.** Confirm identical input
  produces identical output (re-assemble representative fixtures twice,
  compare PRG/R6/listing/map bytes). Close out whatever WP56's triage
  flagged as needing attention that isn't already covered by WP57-60.
- **WP62 — Documentation sync.** Systematic pass, not incidental fixes:
  user manual (`wiki`/`docs/casm-utility.md`), programmer's reference
  (`wiki/casm-programmers-reference.md`), API-adjacent references this
  phase's changes touch, `brain/KNOWLEDGE.md`, `brain/task.md`,
  `wiki/tasks/casm.md`, `CHANGELOG.md`, and any `AGENTS.md`/DOX file whose
  durable contract actually changed. Given WP54/WP55 already found real,
  multi-week-old staleness in several of these files incidentally, this WP
  should start from a clean-room re-read of each doc against current code,
  not from a diff against what's already believed correct.
- **WP63 — Verification, walkthrough, completion gate.** Mirrors WP49
  (Phase 9) and WP55 (Phase 10)'s own closing pattern: full regression
  build, live VICE verification, the user's own manual runtime walkthrough,
  and explicit approval before the phase is marked done.

## Completion Gate

Phase 11 completes only when every work package above (as finalized after
this plan's review) is individually planned, approved, implemented, and
verified; the 3 carried-forward items are each either fixed or explicitly
re-scoped with reasoning; the fault-injection infrastructure is real and
exercised, not just designed; documentation agrees with shipped behavior
across every tier the master plan names; and the user completes the native
runtime walkthrough and explicitly approves the base release.

## Open Questions For This Review

1. Does the WP56-63 breakdown above match the intended shape, or should any
   of these be split, merged, or reordered?
2. Version target: the master plan gives Phase 11 no explicit version
   number (unlike Phase 10's `0.2` and Phase 12's `0.3`). Default plan,
   absent other direction: each WP bumps `VERSION_STAGE` on its own
   completion (matching every prior phase's pattern), staying within
   `0.2.x` — no `0.3` bump, since that's reserved for Phase 12's new
   language features. Confirm or redirect.
3. WP57's fault-injection infrastructure is the largest unknown in this
   breakdown — worth a design spike/sub-plan before committing to WP58's
   scope, or should WP57 and WP58 be planned together from the start?

## Progress

- 2026-08-08: Branch `casm-phase11` created from `main` (post-Phase-10-merge
  tip, `4b943e2`). User asked for a detailed implementation plan with
  questions and iteration, not a unilateral draft. Researched the master
  plan's own Phase 11 definition and found 3 pre-existing carried-forward
  items from Phase 4 (recorded above) that had never been individually
  actioned, plus the direct connection between Phase 11's own scope and
  WP55's disclosed fault-injection gap. Presented findings and asked two
  scoping questions; user confirmed risk-based (not exhaustive) audit
  prioritization and building real fault-injection infrastructure. Drafted
  a WP56-63 breakdown and asked for reaction before finalizing. User asked
  to record this plan for review per established convention — done here.
  Taskwarrior task 37 (`ca5d69aa-b674-4a24-a7fa-55160755d47a`) created as
  the Phase 11 parent, status `Pending`, not yet started. This plan is
  **not yet approved** — the three Open Questions above remain live.
