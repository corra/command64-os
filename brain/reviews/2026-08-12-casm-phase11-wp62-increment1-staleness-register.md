# CASM Phase 11 WP62 Increment 1 Scope and Staleness Register

Status: Frozen for user review
Baseline: CASM `0.2.2` build `1266`
Plan: `brain/plans/2026-08-12-casm-phase11-wp62-documentation-sync.md`
Taskwarrior: `27332a0c-7bb6-4c2e-b455-6f5e03b4b84e`

## Scope and Method

This is the Increment 1 gate artifact. It records a clean-room re-read of
every in-scope file against current code/records, catalogs every
discrepancy found, and confirms the exact source material and insertion
points for the `brain/KNOWLEDGE.md` backfill. No documentation edit is made
in this increment.

## 1. `brain/KNOWLEDGE.md`

Confirmed CASM sections run `### CASM Phase 1 Foundation` (line 106) through
`### CASM Phase 9 WP48 Included-Source Diagnostics` (line 1978), immediately
followed by `### DASH System Dashboard (WP1-WP9, 2026-07-26 to 2026-07-30)`
(chronologically after Phase 9, before Phase 10's 2026-08-08 close), then a
different major section, `## C64 Platform Constraints Discovered` (an
appendix-style reference table, not part of the chronological phase
narrative). No section exists for CASM Phase 10 or any of Phase 11.

**Gap 1 — Phase 4** (parser completion, opcode table, numeric emission,
orchestration; WP12-15, closed 2026-07-21): confirmed missing (sections jump
`### CASM Phase 3 ...` line 159 -> `### CASM Phase 5 ...` line 256).
Source material: `brain/plans/2026-07-20-casm-phase4-wp14-orchestration-
binary-validation.md`, `2026-07-20-casm-phase4-wp15-phase-verification-
closeout.md`, `2026-07-21-casm-phase4-wp14-test-plan.md`, plus a direct
re-read of `parser.s`/`opcodes.s`/`emit.s` as they stand today. Insertion
point: between the Phase 3 and Phase 5 sections.

**Gap 2 — Phase 10** (symbol map/listing; WP50-55, closed 2026-08-08):
confirmed missing. Source material: `brain/plans/2026-07-29-casm-phase10-
symbol-map-listing.md` and the WP50-55 walkthroughs, plus a direct re-read
of `map.s`/`listing.s`. Insertion point: immediately after the Phase 9 WP48
section, before `### DASH System Dashboard` (chronological -- Phase 10
closed 2026-08-08, after WP48's 2026-07-25 but the DASH heading's own date
range, 2026-07-26 to 2026-07-30, predates Phase 10's close; the DASH
section stays where it is and Phase 10's new section goes after it,
preserving overall chronological order by close date).

**Gap 3 — Phase 11** (base-release hardening; WP56-61, closed 2026-08-12):
confirmed missing. Source material: `brain/plans/2026-08-08-casm-phase11-
base-release-hardening-documentation.md` and every WP56-61 walkthrough/
review already produced. Insertion point: after the new Phase 10 section
(chronologically last).

Heading/content convention confirmed from Phase 3 and Phase 5 sections:
`### CASM Phase N <Name> (approved/frozen <date>)` heading, then bullet
points covering contract statement, frozen ABI/data shapes, and
cross-references to the governing plan(s). The new sections will match this
exactly.

## 2. `wiki/casm-programmers-reference.md` (1139 lines, read in full)

| Location | Current text | Discrepancy |
| --- | --- | --- |
| Line 11 | "Status: Phase 10 complete (build 1260, version 0.2.0)" | Stale: Phase 11 (WP56-61) is now also complete; current build `1266`, version `0.2.2` |
| Line 94-97 | `casm.s: start` sequence listed as `diagClearLoc -> listingStateInit -> ...` | Missing `CLD`: WP60 Increment 3 added `CLD` as the literal first instruction of `start:`, before `diagClearLoc` -- confirmed by direct source read, not reflected here |
| Line 147 | "Version banner: ... (currently 0.2.0)" | Stale: currently `0.2.2` |
| Line 898 | "As of build 1260 / v0.2.0 (Phase 9 complete; Phase 10 complete):" | Stale: should read current build/version and note Phase 11 complete |
| §18 Coverage | Opcode/addressing coverage stated as "supported" with no certification claim | WP60 exhaustively certified all 151 legal opcode/mode combinations (independent oracle + direct matcher + end-to-end artifact); worth citing as strengthened evidence, not just "implemented" |
| §18 "Not yet implemented" | Lists `fileCreateOutput` replace-on-exists gap only | Missing two known non-critical bugs already tracked in `wiki/tasks/casm.md`'s "Known Non-Critical Bugs" section: the listing blank-line screen-display artifact, and the one-byte-source phantom-EOF-byte defect (WP60 Increment 7, Taskwarrior UUID `882433f0-cde1-4849-8b3c-df32613518c3`) -- both are real, user-observable-adjacent limitations this reference should disclose |
| §1 Architecture / §18 Coverage | No mention of WP61's determinism proof | Worth one line citing that identical input is now proven to produce byte-identical output (PRG/R6/listing; map by live comparison) -- a real, newly-established property, not previously documented anywhere in this file |

No other discrepancy found in the remaining ~950 lines (module ABI tables,
diagnostic reference table, zero-page contract, etc.) -- cross-checked
against current `common.inc` diagnostic count (through `$42`) and zero-page
layout, both still accurate.

## 3. `wiki/casm-utility.md` / `docs/casm-utility.md` (457 lines each, byte-identical, one read stands for both)

| Location | Current text | Discrepancy |
| --- | --- | --- |
| Line 4 | "Version: 0.2.0 (build 1260)" | Stale: currently `0.2.2` build `1266` |
| Line 18-25 | "CASM Phase 10 is complete..." banner | Should extend to note Phase 11's hardening/certification work, in end-user terms (more thoroughly verified, not new behavior) |
| "Not Yet Supported" section | Lists `.STATIC`/`.RELOC`, expression limits, capacity limits, and the replace-on-exists gap | Missing the same two known non-critical bugs as the programmer's reference (blank-line listing display, one-byte-source phantom EOF) -- this is the user-facing doc, so these belong here at least as much as in the internal reference |

No other discrepancy found in the command syntax, language reference,
examples, or diagnostic-reading sections -- spot-checked against current
`cli.s`/`common.inc` behavior (option list, diagnostic message text, example
byte encodings) and all still accurate.

## 4. `CHANGELOG.md`

Confirmed: a `### Changed` entry exists for WP60 (CLD hardening) plus one
for "CASM exhaustive opcode/addressing/boundary certification, WP60
complete, bumped to 0.2.2" -- but no entry anywhere for WP61. Confirmed gap,
per the plan's user-confirmed decision to add one framed as test-
infrastructure/verification work (no production change).

## 5. `src/external/casm/AGENTS.md` (269 lines, read in full)

More stale than the plan anticipated -- this is not a narrow "check for
drift" pass, it needs real content updates:

| Location | Current text | Discrepancy |
| --- | --- | --- |
| Lines 88-91 | "WP50-WP55 remain inactive and each requires a dedicated approved plan" | Badly stale: Phase 10 (WP50-55) closed 2026-08-08. This sentence describes a state that ended over a week before this pass |
| Lines 138-168 | WP50-54 each described as "approved-but-blocked plan" | All are long since implemented and closed; these read as forward-looking constraints on unstarted work, not historical record |
| (whole file) | No mention of Phase 11 (WP56-61) at all | The entire base-release-hardening/certification/determinism body of work is undocumented here |
| Lines 192-196 | "a separately planned and approved multi-digit representation must be completed before any work package at version `0.1.9` may be completed" | Version is now `0.2.2` (past the `0.1.9` threshold this note gates); the migration this note requires apparently never triggered because the project moved to a `0.2.x` minor series instead. Needs a decision at Increment 6: mark this constraint satisfied/moot, or confirm it still applies to some future `0.2.9`-style threshold |

This file's staleness is the single largest finding of this register --
Increment 6 should budget for a real rewrite of the Phase 9/10-era
forward-looking language into historical record, plus new Phase 11 content,
not a light touch.

## 6. `brain/task.md` / `wiki/tasks/casm.md`

Both were kept current through WP60/WP61's own execution (this agent's own
running work). Spot-checked against this register's findings: no
inconsistency found. No change anticipated at Increment 7 beyond a possible
confirmation note, unless a later increment's research surfaces something
new.

## Sign-off

All 6 in-scope items reviewed; discrepancies cataloged above. The
`brain/KNOWLEDGE.md` gap is larger than WP56 originally flagged (3 missing
phases, not 1) and `src/external/casm/AGENTS.md` is more stale than
anticipated (forward-looking Phase 10 language never updated after closure,
zero Phase 11 content) -- both already known and accepted by the user
before this plan was approved (KNOWLEDGE.md gap) or newly confirmed here
(AGENTS.md depth). No documentation change made in this increment.

Requesting user approval before Increment 2 (`brain/KNOWLEDGE.md` backfill)
activates.
