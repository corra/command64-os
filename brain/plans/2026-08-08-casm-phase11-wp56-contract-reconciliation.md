---
feature: casm-phase11-wp56-contract-reconciliation
created: 2026-08-08
status: approved
taskwarrior: 636eddce-4777-4ccb-b79f-0e9903fdd10d
depends-on: ca5d69aa-b674-4a24-a7fa-55160755d47a
---

# Plan: CASM Phase 11 WP56 - Contract Reconciliation and Audit-Risk Triage

## Status and Authorization

**Approved 2026-08-08.** No production source, version, or build change is
authorized by this plan (WP56 itself changes no CASM behavior). WP56 mirrors
WP50's role for Phase 10
(`brain/plans/2026-07-29-casm-phase10-wp50-contract-reconciliation.md`): it
produces the risk register and remediation plans every later Phase 11 WP
depends on, but changes no CASM behavior itself.

Parent plan:
`brain/plans/2026-08-08-casm-phase11-base-release-hardening-documentation.md`
(approved 2026-08-08 — WP56-63 breakdown confirmed as-is, `0.2.x` per-WP
version bumps confirmed, WP57 confirmed as its own design-spike plan before
WP58 is detailed).

Baseline: CASM `0.2.0` build `1260`, Phases 1-10 complete and user-approved.

## Objective

Produce two things, per the parent plan's WP56 definition:

1. A **prioritized, module-by-module audit order** for WP58-61 to follow,
   based on real risk signals (age, prior independent audit depth, test
   fixture coverage, known-bug history) rather than build order.
2. A **concrete remediation plan for each of the 3 carried-forward Phase 4
   debt items** (`brain/task.md` line 285-287), each resolved by direct
   source tracing in this WP, not by re-asserting the original one-line
   descriptions.

This WP performs no fix, no fixture, no version bump. It is investigation and
triage recorded as a durable reference for WP58-63.

## Reconciled Findings: Module Inventory and Audit-Risk Register

All 18 modules under `src/external/casm/`, ordered by first-commit date
(age), with size, existing dedicated test-fixture directories under
`tests/src/`, and known-bug history pulled from `brain/KNOWLEDGE.md` and this
project's memory records.

| Module | LOC | First touched | Test dirs (approx.) | Known-bug history |
|---|---:|---|---|---|
| `casm.s` | 774 | 2026-07-16 | orchestration only, no dedicated dir | none disclosed |
| `cli.s` | 604 | 2026-07-16 | `casm_cliderive` | none disclosed |
| `diagnostics.s` | 1525 | 2026-07-16 | cross-cut, no dedicated dir | none disclosed |
| `fileio.s` | 646 | 2026-07-16 | cross-cut | **open**: `fileCreateOutput` has no `@0:` replace marker, hangs KERNAL IEC retry on rerun (TW #36) |
| `resources.s` | 368 | 2026-07-16 | cross-cut | none disclosed |
| `source.s` | 2729 | 2026-07-16 | `casm_spancommit`, `casm_spanread` | zero-size `.SEQ` open edge case (documented, not a defect) |
| `state.s` | 210 | 2026-07-16 | cross-cut | none disclosed |
| `emit.s` | 700 | 2026-07-17 | cross-cut (Phase 6B WP28-31 gate) | none disclosed |
| `lexer.s` | 1106 | 2026-07-17 | cross-cut (Phase 3 gate) | none disclosed |
| `opcodes.s` | 472 | 2026-07-17 | `casmmodes.ref`-style certification (Phase 4) | none disclosed |
| `parser.s` | 615 | 2026-07-17 | cross-cut (Phase 3/6B gates) | none disclosed |
| `expr.s` | 647 | 2026-07-21 | `casm_expr` | none disclosed |
| `symbols.s` | 509 | 2026-07-22 | `casm_symbols` | none disclosed |
| `vmm_store.s` | 411 | 2026-07-22 | `casm_vmm` | **fixed**: `CasmValue0Lo/Hi` clobbered by `vwPrepareTransfer` on every window call; `CasmSourceVmmCursor` is a refill head, not parse position (both documented as reference memory, both closed) |
| `reloc.s` | 267 | 2026-07-25 | `casm_reloc` | none disclosed |
| `include.s` | 933 | 2026-07-26 | `casm_frame`, `casm_include`, `casm_catalog`, `casm_event` | **fixed**: WP46 had two cancelling bugs hidden by a false-passing test (frame stack) |
| `listing.s` | 2360 | 2026-08-03 | `casm_listcap`, `casm_listing`, `casm_listwrite`, `casm_map` (shared) | **fixed**: `listingMirrorByte` clobbers Y silently; **fixed**: `listingResolveFilename`/`includeCatalogRead` clobbered `CasmVmmBuffer` before caller re-read `BYTECOUNT` |
| `map.s` | 329 | 2026-08-05 | `casm_map` | none disclosed (newest module, built immediately before Phase 10 closed) |

### Audit Priority Tiers

**Tier 1 — highest priority (newest, least independently audited):**
`listing.s`, `map.s`. Both post-date every phase-closing verification gate
except WP55's own Full-Path Review, which traced specific call sequences,
not every exported routine. This is exactly WP59's stated scope; WP56 does
not duplicate it here, only confirms the priority ranking.

**Tier 2 — file/VMM-owning modules with real prior-bug history, also WP58's
fault-injection targets:** `fileio.s` (open TW #36 bug), `vmm_store.s`
(2 fixed clobber bugs), `include.s` (2 fixed cancelling bugs), `source.s`
(one disclosed edge case). `symbols.s` and `reloc.s` are WP58 fault-injection
targets by module-ownership (they hold VMM allocations) but have no
disclosed bug history — include them in WP58's fault-injection pass per the
parent plan's explicit module list, but they do not need the same
line-by-line contract re-audit priority as the four modules above.

**Tier 3 — older, phase-closed, individually verification-gated already:**
`expr.s` (Phase 5 gate), `symbols.s`/`emit.s`/`parser.s` (Phase 6B WP28-31
gate), `lexer.s`/`opcodes.s` (Phase 3/4 gates), `reloc.s` (Phase 8 WP37-42
gate). Each of these closed under its own phase's completion gate with a
walkthrough; re-audit only the specific contracts WP60's opcode/addressing-
mode sweep or WP61's determinism pass actually touch, not exhaustively.

**Tier 4 — stable infrastructure, low change frequency, no dedicated test
dir because they're exercised by every fixture indirectly:** `casm.s`,
`cli.s`, `state.s`, `resources.s`. Lowest priority; `diagnostics.s` is
promoted out of Tier 4 despite being infrastructure because of its size
(1,525 LOC, largest non-`source.s`/`listing.s` module) and because every
other module's failure path routes through it — recommend a Tier 2/3
boundary spot-check in WP61 rather than full re-audit.

This register is the audit order WP58 (fault-injection targets), WP59
(`listing.s`/`map.s`), WP60 (opcode/addressing-mode sweep — Tier 3 modules),
and WP61 (determinism + whatever remains) each start from.

## Reconciled Findings: The 3 Carried-Forward Phase 4 Debt Items

Each traced directly against current `0.2.0` source, not against the
original 2026-07-21 one-line description.

### 1. `CasmOutputCreated` "conflates created with opened existing"

Traced `fileCreateOutput` (`src/external/casm/fileio.s:163-206`):
`CasmOutputCreated` is set to `CASM_OUTPUT_CREATED` (line 183) only on the
success path of a `DOS_OPEN_FILE` call issued in `CASM_FILE_MODE_WRITE`
(write-create) mode. On real CBM DOS, a write-mode open with a plain
filename (no `@0:` prefix) does not silently succeed against an
already-existing file — and this codebase's own separately-tracked bug (TW
#36, `project-casm-filecreateoutput-no-replace` memory) confirms the actual
failure shape: it **hangs** on KERNAL IEC retry rather than returning
success or a clean error. There is currently no code path in which
`fileCreateOutput` returns success against a pre-existing filename.

**Finding: the debt item's premise does not hold against the current
source.** `CasmOutputCreated` is accurately named — every path that sets it
true did, in fact, just create the file. The genuine risk here is not a
semantic conflation in this flag; it's the already-tracked TW #36 hang,
which is a distinct problem (missing `@0:` marker) with its own task.

**Remediation plan:** No code change under this item. Retire the debt note
in `brain/task.md` (line 285-287) as resolved-by-tracing, replacing it with
a pointer to TW #36 as the actual related (and already tracked) issue. No
WP60 action item beyond this documentation correction.

### 2. No `CLD` at CASM's application entry point

Traced `start:` (`src/external/casm/casm.s:118` onward) — confirmed no
`CLD` or `SED` anywhere in `casm.s`. Searched all of `src/command64/` (the
Command64 OS/shell source) for `CLD`: only one hit, and it changes this
finding's conclusion. `apiHandler` (`src/command64/api.asm:43-44`), the
single centralized dispatcher every `jsr OS_API` call reaches, executes
`cld` as its literal first instruction — comment: `; Ensure binary mode
for all OS services`. Every OS-mediated operation clears decimal mode
before doing anything else, unconditionally.

Traced when CASM's own control flow first reaches `OS_API`:
`start:` (`casm.s:145-147`) prints the version banner via
`jsr diagPrintString` before `cliParse` (line 149) and before any Pass
1/Pass 2 statement parsing; `diagPrintString` (`diagnostics.s:99-102`) is
`lda #DOS_PRINT_STR / jsr OS_API`. This is CASM's first `OS_API` call,
reached before any code path that could execute the expression evaluator's
`ADC`/`SBC`. **Decimal mode is therefore already guaranteed clear for the
entirety of CASM's arithmetic-sensitive code, today, as an emergent
consequence of the banner print's placement** — not because `casm.s` itself
ever clears it.

`src/external/dash/dmain.s`'s `START:` label issues `CLD` explicitly as its
first instruction anyway (comment: `; CLEAR DECIMAL MODE`), showing this
codebase's established pattern is to make the guarantee structural at the
application level rather than rely on an incidental early OS call.

**Finding (corrected from this plan's first pass): not a live bug.** CASM's
arithmetic is safe today. It is safe for a fragile reason, though — it
depends on `diagPrintString`'s call site staying before Pass 1 in `start:`.
A future refactor that reorders, guards, or removes that early banner print
(plausible: e.g. a `/Q` quiet-mode flag suppressing the banner) would
silently reopen the gap with no test catching it, since nothing currently
asserts the ordering as a contract.

**Remediation plan (user-confirmed 2026-08-08):** WP60 still adds `CLD` as
the literal first instruction of `casm.s`'s `start:`, mirroring `dmain.s`.
Record it as **structural hardening against an implicit ordering
invariant**, not as a live-bug fix — the distinction matters for how WP60's
own completion note and the `KNOWLEDGE.md` Phase 4 section (item 3, assigned
to WP62) describe it. Verification remains by inspection (confirm the
instruction precedes every reachable `ADC`/`SBC` path); no fixture is
required since there is no longer a failure mode to reproduce.

### 3. No dedicated CASM Phase 4 contract section in `brain/KNOWLEDGE.md`

Confirmed by direct inspection: `brain/KNOWLEDGE.md` has `### CASM Phase 3
Source/Lexer Contract` at line 132 and `### CASM Phase 5 Expression/Resolver
Contract` at line 229, with nothing for Phase 4 between them. Every phase
from 5 onward has its own section; Phase 4 (parser completion, opcode
table, numeric emission, orchestration — WP12-15, closed 2026-07-21) does
not.

**Finding: confirmed gap, straightforward backfill.**

**Remediation plan:** WP60 (documentation half) or WP62 (systematic doc
sync) adds `### CASM Phase 4 Parser/Opcode/Emission Contract (approved
2026-07-21)` between the existing Phase 3 and Phase 5 sections, following
the exact heading and content convention neighboring sections already use
(contract statement, frozen ABI/data shapes, cross-references). Source
material: `brain/plans/2026-07-20-casm-phase4-wp14-orchestration-binary-
validation.md`, `2026-07-20-casm-phase4-wp15-phase-verification-closeout.md`,
and `2026-07-21-casm-phase4-wp14-test-plan.md`, plus direct re-reading of
`parser.s`/`opcodes.s`/`emit.s` as they stand today (not as those plans
described them at the time, per this WP's own "clean-room re-read" standard
that WP62 later applies project-wide). **Assign to WP62** rather than WP60,
since WP62 is explicitly the systematic documentation-sync WP and this is a
pure documentation gap with no code action — WP60 keeps only items 1 and 2
above (a documentation-only retraction and a one-instruction code fix).

## Scope

Included:

- Record this plan, obtain approval.
- The module inventory and audit-priority register above.
- The 3 debt-item findings and remediation plans above.
- Update `brain/task.md`'s carried-forward note (line 285-287) to reflect
  disposition once this plan is approved (item 1 retired-by-tracing, item 2
  assigned to WP60, item 3 assigned to WP62) — a durable-record edit, not a
  production change, so it can happen at approval rather than waiting for
  WP60/WP62 to close.
- After approval, develop WP57's dedicated design-spike plan (per the
  parent plan's confirmed sequencing) as WP56's own final increment, mirroring
  WP50's pattern of producing the next WP's plan as part of its own
  completion gate.

Excluded:

- Any CASM source change (the `CLD` fix belongs to WP60).
- Any `brain/KNOWLEDGE.md` content change (the Phase 4 section belongs to
  WP62).
- Full exported-routine-by-routine audits of any module (that's WP58-61's
  work; this WP only orders it).
- Fault-injection infrastructure design (that's WP57).

## Expected Files

Planning only: this plan, parent plan cross-reference, `brain/task.md` debt
note update, Taskwarrior. No `src/external/casm/` change, no version bump,
no build.

## Atomic Increments

1. Record this plan; request approval.
2. On approval, update `brain/task.md`'s Phase 4 carried-forward note with
   the 3 dispositions above.
3. Develop and record WP57's dedicated fault-injection design-spike plan
   (separate file, per the parent plan's confirmed WP57-first sequencing).
4. Produce the WP56 walkthrough summary (no runtime verification needed —
   this WP changed no behavior) and request completion approval.

## Verification

Since this WP makes no production or behavioral change, verification is:

- Confirm every claim in the "Reconciled Findings" sections above traces to
  a specific file/line already cited (no unverified claim carried forward).
- Confirm the module inventory table accounts for all 18 `.s` files under
  `src/external/casm/` (cross-check against a fresh `ls`/`wc -l` at
  completion in case WP57 planning or other concurrent work adds a module).
- Confirm `brain/task.md` and this plan agree after increment 2.
- No build/image verification required (no source changed).

## Stop Conditions

- Any of the 3 debt items' remediation plan turns out to require a design
  decision only the user can make (e.g. if `CLD` tracing had revealed a
  behavioral dependency on decimal mode somewhere, forcing a scope
  discussion) — none did, but if WP60/WP62 execution surfaces one, stop
  there, not here.
- The module inventory surfaces a previously-undisclosed real bug during
  triage (as opposed to confirming already-known ones) — stop and disclose
  immediately rather than folding it silently into the register.

## Completion Gate

WP56 completes only after this plan is approved, the `brain/task.md` update
is made, WP57's dedicated plan is drafted and recorded, and the user
approves WP56's completion. No version bump accompanies WP56's closure
(no production source changed) — matching WP50's precedent, WP56's own
completion carries no `VERSION_STAGE` change; the phase's first bump happens
at WP57 or WP60's own completion gate, whichever closes first.

## Progress

- 2026-08-08: Plan drafted. Traced the module inventory (18 files, ages,
  test-dir coverage, known-bug history from `brain/KNOWLEDGE.md` and memory
  records) and produced the 4-tier audit-priority register. Traced all 3
  carried-forward Phase 4 debt items directly against current source:
  item 1 (`CasmOutputCreated`) found to be a stale premise — the flag is
  accurately named, no code change needed, retire the note and cross-
  reference TW #36 as the real related issue; item 2 (no `CLD`) confirmed
  as a real narrow correctness-hardening gap, with `src/external/dash/
  dmain.s`'s own `CLD`-as-first-instruction already an in-repo precedent for
  the fix, assigned to WP60; item 3 (missing Phase 4 `KNOWLEDGE.md` section)
  confirmed by direct inspection (gap between the Phase 3 and Phase 5
  section headings), assigned to WP62. Not yet approved.
