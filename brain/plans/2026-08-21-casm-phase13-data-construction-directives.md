---
feature: casm-phase13-data-construction-directives
created: 2026-08-21
status: proposed
taskwarrior: TBD (created on approval)
depends-on: CASM Phase 12, complete (brain/walkthroughs/2026-08-20-casm-phase12-wp75-verification-walkthrough-completion-gate.md); post-Phase-12 hardening (WP77/78/80 closed, WP79 deferred — brain/plans/2026-08-20-casm-post-phase12-hardening.md)
---

# Plan: CASM Phase 13 - Data Construction Directives

## Status

**Proposed, not yet approved.** Drafted 2026-08-21 for user review, per
this project's per-work-package-plan-approval requirement
(`.agents/workflows/phased-implementation-planning.md`). This document
authorizes nothing by itself — WP81 (the first work package) needs its own
detailed plan and explicit approval before any implementation begins,
same as every other WP in this project.

Parent plan: `brain/plans/2026-07-16-casm-assembler-implementation-plan.md`
— see its own Phase 13 section (`## Future Native Release Phases`) for the
frozen, one-paragraph scope this plan expands into work packages.

Baseline: CASM `0.3.0` build `1325`, Phase 12 complete, post-Phase-12
hardening closed (WP77/78/80 done, WP79 explicitly deferred — see that
plan's Progress log for why, unrelated to this phase).

WP numbering continues the same running counter Phase 12 used (WP64-76);
the post-Phase-12 hardening set used WP77-80 as a deliberately
non-numbered interim effort. **Phase 13's work packages start at WP81.**

## Objective

Per the master plan, Phase 13 adds five new directives: `.RES` (reserve N
bytes), `.FILL` (emit N bytes of a fixed value), `.ALIGN` (pad to a
boundary), `.INCBIN` (include a raw binary file's bytes), and `.ASSERT`
(compile-time expression check with an optional message, no emission).
The master plan also settles one open question already: `.TEXT` is not
part of this phase (closed by the post-Phase-12 hardening plan's WP80 —
`.BYTE "string"` literals from Phase 12 WP74 remain the sole string
spelling).

**Risk gate**, mirroring every prior phase's own: none of these directives
may change any existing program's assembled bytes. `.RES`/`.FILL`/`.ALIGN`
are new byte-emitting constructs with no existing syntax to collide with,
so this is lower-risk than Phase 12's expression-precedence work — the
real risk is scoped to each directive's own correctness (Pass1/Pass2
byte-count agreement, chiefly) rather than to existing behavior.

## Research Summary

A pre-planning research pass (this session, 2026-08-21) surveyed the
existing directive/emission/file-I/O infrastructure. Findings that shape
the work-package breakdown below:

1. **Directive dispatch has three tiers already**, and each new directive
   picks the one matching its grammar:
   - Single-expression operand, reuses `parseOperandSequence` (like
     `.ORG`): candidate for `.ALIGN`'s boundary and (with an addendum for
     the optional fill byte) `.FILL`.
   - Deferred/comma-list operand (`ppsDeferOperands`, like `.BYTE`/`.WORD`):
     candidate for `.RES` (count[, value]) and `.FILL` (count, value) if a
     single-expression grammar doesn't fit cleanly.
   - Dedicated scanner (`ppsInclude`/`lexerScanIncludeOperand`, like
     `.INCLUDE`): required for `.INCBIN`'s quoted filename, and useful
     precedent for `.ASSERT`'s optional trailing quoted message.
2. **No bulk-fill emission primitive exists.** `.RES`/`.FILL`/`.ALIGN`'s
   padding all reduce to the same shape: loop calling `emitByte` N times.
   This is consistent with how `.BYTE`/`.WORD` lists already work, not a
   gap to fill first — but it does mean these three directives share
   almost all of their implementation, which is why they're grouped into
   one work package below.
3. **Forward-referenced counts/boundaries must be rejected outright**, not
   tolerated as a Pass-1 placeholder like ordinary operands — confirmed as
   the right call (user-approved 2026-08-21) to avoid reopening the exact
   Pass1/Pass2 byte-count disagreement class WP76 just fixed. A `.RES`
   count directly determines byte length, unlike an instruction operand
   whose *width* is pass-invariant regardless of value.
4. **`.ALIGN` has zero interaction with the R6 relocation table.** Padding
   bytes are inert filler, structurally identical to `.BYTE $00` — never
   calls `relocRecord`. Its padding count is `(N - (CasmPc mod N)) mod N`,
   a plain scalar computed directly from `CasmPc`, not a
   `CasmParserStmt.Val*` that could leak into relocation bookkeeping.
5. **`.INCBIN` can safely reuse the existing single-slot file-I/O
   primitives** (`fileOpenInput`/`fileRead`/`fileClose`, the same ones
   `.INCLUDE`'s loader uses transiently) because the entire source is
   VMM-preloaded before Pass 1/Pass 2 statement execution ever begins —
   `CasmInputState` is guaranteed `CLOSED` while directives run, so there
   is no slot conflict with `.INCLUDE`'s own (already-closed-by-then)
   usage.
6. **The CASM envelope (currently `$6500`) has been under-forecast on
   nearly every prior WP** (the WP74 bump itself landed only 17 bytes
   under a prior "confident" estimate). Budget for at least one
   mid-WP envelope-bump negotiation per work package below, not one for
   the whole phase.
7. **`.STATIC`/`.RELOC` are directive IDs the lexer already recognizes but
   `emit.s` explicitly rejects as not-implemented** (reserved since
   Phase 8/9-era). Confirmed (user-approved 2026-08-21): **stay deferred**,
   out of Phase 13's scope. New directive IDs are allocated after them
   (`CASM_DIRECTIVE_COUNT` currently `$07`; new IDs start at `$07` and
   `.STATIC`($05)/`.RELOC`($06) remain reserved-but-unimplemented).
8. **DASH dogfooding** (mandatory per this project's convention — every
   new CASM syntax addition triggers a scoped DASH rewrite) was surveyed
   directly against `src/external/dash/*.s`:
   - `.RES`: strong fits — `ddata.s:342` `VMMBUFFER` (256 zero bytes, its
     own comment names CASM's missing reserve directive as the reason for
     the 16-row zero-fill), plus `ddata.s:74` `SYSINFOBUF`, `ddata.s:165`
     `APPBUF`, `ddata.s:29` `FMTBUF` (all write-before-read scratch
     buffers currently expressed as literal zero-byte lists).
   - `.FILL`: one genuine fit — `ddata.s:43` `BORDERROW`, a corner-char +
     38×`$40` (repeated non-zero screen code) + corner-char row template.
   - `.ALIGN`: **no genuine candidate in DASH.** Nothing depends on
     alignment for indexing or layout; the one plausible candidate
     (`PAGEROUTINETABLE`, `ddata.s:8`) is only 3 entries and its existing
     `ASL`+`TAY` indexing is already correct, not a defect an alignment
     directive would fix. Forcing a conversion there would be contrived.
     **User-confirmed (2026-08-21): implement `.ALIGN`, explicitly defer
     its DASH-adoption requirement** as a documented exception, same
     treatment as `.INCBIN` below — not an oversight, a recorded decision.
   - `.INCBIN`: **no genuine candidate in DASH** — no external binary
     asset (font, charset, sprite data) exists anywhere in its source.
     **User-confirmed (2026-08-21): implement, defer DASH adoption.**
   - `.ASSERT`: strong fit — `dmain.s:143`
     `DISPATCHRETURNMINUSONE`/`DISPATCHRETURN`, a one-byte trampoline
     filler whose correctness invariant (`DISPATCHRETURN` must be exactly
     one byte past `DISPATCHRETURNMINUSONE`) is today enforced only by a
     hand-written comment. Secondary candidates: compile-time size
     assertions on `SYSINFOBUF`/`APPBUF`/`VMMBUFFER` (today checked only
     at runtime via `CMP #24`/`#256` against `STRUCTSIZE` — a compile-time
     `.ASSERT` would be a genuine complement, not a duplicate).

## Scoping Decisions (user-confirmed 2026-08-21)

1. **Work-package split: group by mechanism, not one-WP-per-directive or
   one-WP-for-everything.** `.RES`/`.FILL`/`.ALIGN` share the same
   byte-loop-emission pattern and go in one WP (WP81). `.INCBIN` (file
   I/O) and `.ASSERT` (expression-only, no emission) each get their own WP
   (WP82, WP83), isolating their distinct risk/envelope profiles.
2. **Forward-referenced counts/boundaries are a diagnostic error** in all
   three of `.RES`/`.FILL`/`.ALIGN` — full resolution required in both
   passes, no Pass-1 placeholder tolerance.
3. **`.STATIC`/`.RELOC` stay deferred**, unrelated to this phase.
4. **DASH adoption is one consolidated work package at the end (WP84)**,
   mirroring Phase 12's own WP71 precedent and its stated reasoning
   ("rather than scatter DASH edits into each syntax-delivering WP...
   one dedicated WP adopts the new syntax into DASH's real source once it
   all exists"). WP84 converts
   `VMMBUFFER`/`SYSINFOBUF`/`APPBUF`/`FMTBUF` to `.RES`, `BORDERROW` to
   `.FILL`, and `DISPATCHRETURNMINUSONE`'s invariant (plus optionally the
   three buffer-size checks) to `.ASSERT`. `.ALIGN` and `.INCBIN` get no
   DASH conversion in WP84 — their dogfood requirement is explicitly
   waived per decisions above, not silently skipped.
5. **`.ALIGN` and `.INCBIN` DASH-adoption requirement is explicitly
   waived**, recorded as a deliberate exception (not an oversight) per the
   research above — no genuine, non-contrived DASH use case exists for
   either today.

## Proposed Work-Package Breakdown

Numbering starts at WP81. **This breakdown, including WP boundaries,
order, and the WP84 DASH-adoption consolidation, is the primary thing
under review in this plan** — nothing below is final until approved.

Dependency spine: **WP81 → WP82 → WP83 → WP84 → WP85**. WP82 and WP83 are
largely independent of each other (different mechanisms, no shared new
infrastructure) and could be reordered or interleaved if preferred — flag
if so.

- **WP81 — `.RES`/`.FILL`/`.ALIGN` (fixed-fill directives).** New
  `CASM_DIRECTIVE_RES`/`FILL`/`ALIGN` constants (`common.inc`), lexer
  recognition, parser grammar (count[, value] for `.RES`/`.FILL`; boundary
  for `.ALIGN`), Pass1/Pass2 byte-emission loop reusing `emitByte`,
  strict resolved-operand requirement (Scoping Decision 2), new
  `CASM_DIAG_*` diagnostics for unresolved-operand/out-of-range/zero-
  boundary cases. Test harness unit fixtures + native/COMP production
  fixtures, mirroring WP74's pattern. Needs its own detailed sub-plan
  before implementation (see below).
- **WP82 — `.INCBIN`.** New `CASM_DIRECTIVE_INCBIN` constant, dedicated
  quoted-filename scanner (reusing/mirroring `.INCLUDE`'s), bounded-chunk
  file read via `fileOpenInput`/`fileRead`/`fileClose` streamed straight
  to `emitByte`, Pass1/Pass2 file-identity/length agreement (per the
  master plan's own line: "records and verifies native file identity/
  length between passes"), reused `CASM_DIAG_INPUT_*` diagnostics plus new
  filename-grammar diagnostics mirroring `CASM_DIAG_INCLUDE_FILENAME_*`.
- **WP83 — `.ASSERT`.** New `CASM_DIRECTIVE_ASSERT` constant, expression
  operand plus optional quoted message (dedicated scanner, mirroring
  `.INCLUDE`'s trailing-comma-string handling if any, or `ppsInclude`'s
  shape directly), no emission at all — pure Pass1/Pass2 evaluate-and-
  compare, fails with a new diagnostic (printing the message if present)
  on a false assertion. Genuinely the lowest-risk WP of the three
  (touches no emission/relocation machinery).
- **WP84 — DASH adoption.** Converts the five real sites identified above
  (`.RES` ×4, `.FILL` ×1, `.ASSERT` ×1-4) to native CASM syntax, natively
  assembles DASH inside VICE, COMP-verifies byte-identical against a
  ca65-built reference, updates `dash.ref.hex`/`scripts/build_dash_
  manifest.py` per WP71's own precedent.
- **WP85 — Consolidated completion-gate verification.** Full regression
  across every WP81-84 fixture together (not just each WP's own individual
  pass — WP46's cancelling-bugs-false-pass precedent), version promotion,
  closing walkthrough, user sign-off for the whole phase.

## Version Target

The master plan's Phase 13 heading says "(CASM 0.3)" — but CASM's version
constants (`casm.s:17-19`) already read `0.3.0` as of Phase 12's own
completion (Phase 12 itself was the "(CASM 0.3)" phase per the master
plan's Phase 12 heading). The master plan's Phase 13 annotation appears to
predate Phase 12's actual version-numbering outcome. **Confirmed
(2026-08-21): Phase 13 promotes to `0.4.0`** on completion (WP85),
following this project's existing minor-version-per-feature-phase
convention (Phase 10 → `0.2.0`, Phase 12 → `0.3.0`).

## Stop Conditions

- Any harness/test fails unexpectedly, including a currently-passing
  fixture regressing after any WP81-84 change.
- Any approved envelope ceiling is exceeded without a fresh, explicit
  bump approval (expected at least once per WP, per the Research Summary).
- A no-change rebuild changes any artifact.
- A genuinely new defect is discovered outside the current WP's own scope:
  disclose and defer as a separate follow-up (default), do not fix inline
  unless explicitly directed in the moment.
- WP85's consolidated regression pass finds any fixture that only passed
  before due to a since-removed compensating bug (WP46 precedent).

## Documentation, Task, and DOX Updates

- Taskwarrior: a Phase 13 parent task on approval of this plan, plus one
  task per WP (WP81-85), mirroring Phase 12's structure.
- `wiki/tasks/casm.md`: new "Phase 13" section, subtasks per WP, updated
  as each WP closes.
- `brain/task.md`: per-WP progress entries as work proceeds.
- `brain/KNOWLEDGE.md`: closing note once Phase 13 is fully closed.
- `CHANGELOG.md`: entry per the project's existing per-phase convention.
- Memory: record Phase 13 scoping now (this plan's existence), update to
  completion once WP85 closes.

## Completion Gate (whole phase)

- All five directives (`.RES`/`.FILL`/`.ALIGN`/`.INCBIN`/`.ASSERT`)
  implemented, each with its own live-verified completion gate (WP81-83).
- WP84's DASH conversions live-verified: native CASM assembly of DASH
  COMP-identical to a ca65-built reference.
- WP85's consolidated regression pass clean across every fixture from
  WP81-84 together, plus the full pre-existing CASM suite (no regression).
- Version promoted to the agreed target (proposed `0.4.0` above).
- `wiki/tasks/casm.md`/`brain/task.md`/`brain/KNOWLEDGE.md`/
  `CHANGELOG.md`/memory all synchronized.
- Closing walkthrough recorded in `brain/walkthroughs/`.
- User explicitly approves closing the whole phase.

## Progress

- 2026-08-21: Plan drafted after a research pass into existing directive/
  emission/file-I/O infrastructure and a DASH-source dogfood-candidate
  survey. Scoping decisions confirmed with user (WP split by mechanism,
  strict forward-reference rejection, `.STATIC`/`.RELOC` deferred,
  `.align`/`.incbin` DASH-adoption explicitly waived, consolidated WP84
  DASH adoption). WP81's detailed sub-plan drafted alongside this one
  (`brain/plans/2026-08-21-casm-phase13-wp81-res-fill-align.md`).
- 2026-08-21: Remaining two open questions confirmed: version target
  `0.4.0` (not `0.3.x`, correcting the master plan's stale heading), and
  WP84 DASH adoption stays consolidated (not scattered inline per-WP).
  This master plan's breakdown is now fully confirmed. Awaiting explicit
  approval of the breakdown as a whole, then WP81's own plan, before
  implementation begins.
