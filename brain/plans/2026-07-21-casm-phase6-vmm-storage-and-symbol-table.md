---
feature: casm-phase6-vmm-storage-and-symbol-table
created: 2026-07-21
status: planned
---

# Plan: CASM Phase 6A/6B - VMM Storage Foundation and Symbol Table / Two-Pass Assembly

## Goal and Rationale

Phase 6 gives CASM the two remaining foundations Phase 8 (native R6 relocation)
requires: bounded VMM-backed record storage, and a real symbol table with
deterministic two-pass assembly. It replaces the Phase 5 fixture resolver with
the production resolver described in that phase's contract, without
implementing relocation-record generation, includes, listings, or macros.

Per the approved master plan
(`brain/plans/2026-07-16-casm-assembler-implementation-plan.md`), this is two
separately gated phases sharing one dependency chain:

```text
Phase 5 evaluator contract (done)
  -> Phase 6A VMM records
  -> Phase 6B symbol table and two-pass resolution
  -> Phase 8 R6 relocation consumption
```

Phase 6A must reach its own completion gate — bounded VMM records written,
read, and replayed without symbol semantics — before Phase 6B begins. This
document plans both because they are tightly coupled and the user asked for
Phase 6 as a unit, but it preserves two independent milestones, two
independent completion gates, and two independent user-approval points, matching
every prior CASM phase.

**Naming collision to flag up front.** `brain/KNOWLEDGE.md`'s top-level
project phase table already has unrelated, completed, top-level phases named
"Phase 6A: App Manager", "Phase 6B: Binary Relocator", and "Phase 6C: External
Editor (VI)" (lines 61-63). CASM's own phase numbering is a separate,
CASM-local namespace defined in the master CASM plan, and the two schemes
collide on the label "Phase 6A/6B" in the same file. All wiki, Taskwarrior,
KNOWLEDGE.md, and changelog entries for this work must be written as
"CASM Phase 6A" / "CASM Phase 6B" (never bare "Phase 6A/6B") to keep the two
namespaces distinguishable. This is a documentation-hygiene reconciliation,
not a functional dependency.

## Prerequisite Gate

Phase 5 is complete: user-approved at CASM `0.1.23` build 1094
(`brain/plans/2026-07-20-casm-phase5-minimal-expression-evaluator.md`,
`brain/walkthroughs/2026-07-21-casm-phase5-wp21-verification-closeout.md`).
Taskwarrior parent `6b72d639` and all six WP16-WP21 children are complete.
WP21's closeout explicitly recorded "Phase 6A remains inactive" as its last
line — this plan is the first Phase 6 artifact since then.

**Gate satisfied.** Phase 6A implementation may begin once WP22 (below) is
approved. Phase 6B implementation may not begin until Phase 6A's own
completion gate (WP25) is met and the user approves Phase 6A done.

## Dependency Review and Discrepancies Reconciled

1. **MAIN envelope has almost no headroom.** WP21 measured CASM at `$2A00`
   MAIN with exactly 243 bytes free, and its stop conditions forbid any
   CODE/BSS growth outside a version-only bump. Real `DOS_ALLOC_MEM`/
   `DOS_FREE_MEM`/`DOS_VMM_READ`/`DOS_VMM_WRITE` wiring plus a symbol table
   and two-pass orchestration cannot fit in 243 bytes. **Reconciled**: WP22
   and WP26 (the two freeze work packages) must each request an explicit,
   separately justified MAIN envelope increase before any other Phase 6
   source changes, exactly as WP13 ($2000->$2800) and WP19 ($2800->$2A00)
   did. This plan does not pre-approve a new size; each freeze WP proposes
   one sized to its own module's measured needs.

2. **Zero page is fully allocated but was pre-provisioned for this work.**
   `common.inc` already reserves `CasmVmmSegHi`/`CasmVmmBank`/`CasmVmmOffLo`/
   `CasmVmmOffHi` ($7C-$7F) as "I/O and VMM transfer scratch," and
   `CasmPassScratch0-3` ($88-$8B) as "Pass and emission transient scratch...
   reserved until the corresponding approved phases define narrower
   aliases." **Reconciled**: Phase 6A should be able to use the existing VMM
   scratch group without growing the 32-byte `$70-$8F` budget; Phase 6B's
   Pass 1/Pass 2 state and hash-bucket/collision-chain cursors are the
   intended consumers of the Pass scratch group. WP22 and WP26 must confirm
   this is sufficient before writing any code, and only request a zero-page
   extension if concrete register pressure proves it is not — the budget has
   never grown past 32 bytes and that should not change without a specific,
   demonstrated need.

3. **Pass 1 needs a "measure but do not emit" mode that does not exist yet.**
   `emit.s` currently advances `CasmPc` and performs buffered PRG output in
   the same pass (Phase 4's single-pass numeric model). Phase 6B's Pass 1
   must assign addresses and define labels by driving the same
   parser/opcode-size logic *without* writing output bytes, then Pass 2 must
   reparse the identical source (via the existing Phase 3 `sourceRewind`
   contract) and emit for real. **Reconciled**: this is a material
   architecture decision, not an implementation detail, and WP26 must freeze
   exactly how pass mode is threaded through `parser.s`/`opcodes.s`/`emit.s`
   (a mode flag consulted at emission time, vs. two separate entry points,
   vs. an emission-event callback later reused by Phase 10's listing
   consumer) before WP28/WP29 write any code.

4. **Absolute-width stability must be verified, not assumed.** Phase 5 WP19
   already stores `forceAbsoluteWidth` on unresolved symbolic operands, and
   the master plan's high-risk analysis forbids automatic zero-page
   shrinking for symbol operands. What has not yet been independently
   audited is whether `opcodesFindOpcode`'s existing zero-page/absolute
   promotion logic actually *consults* that flag when Phase 6B starts
   feeding it real (possibly-unresolved-in-Pass-1) symbol values, rather than
   only the Phase 5 fixture harness's synthetic resolver. **Reconciled**:
   WP26 (freeze) and WP28 (Pass 1) must each include a static audit step
   confirming the mode selector reads `forceAbsoluteWidth` before Pass 1
   commits an instruction length, since Pass 1/Pass 2 size disagreement is
   defined as an internal fatal error by the master plan.

5. **Relative branches move from immediate to symbol-resolved computation.**
   Phase 4's `emitOrg`/branch path computes displacement from a numeric
   operand known at parse time; Phase 6B introduces forward-declared branch
   targets. Two-pass assembly resolves this structurally (all label
   addresses are known by the time Pass 2 runs), but the `-128..127` range
   check and diagnostic must move to consume a *resolved symbol* value
   through the Phase 5 expression/resolver ABI rather than a raw parsed
   number. **Reconciled**: WP30 owns this migration explicitly rather than
   folding it silently into WP29.

6. **The Phase 6A VMM registry already has a real record shape and a stub
   to replace.** `resources.s` already defines `CasmVmmRegistry`
   (`CASM_VMM_REC_FLAG/SEGHI/BANK`, 8 slots) and calls a placeholder
   `cleanupVmmStub` that clears the registry entry without ever calling
   `DOS_FREE_MEM`. **Reconciled**: WP23 replaces `cleanupVmmStub` with a real
   free call and extends `resourceRegisterVmm`/`resourceReleaseVmm` only if
   the frozen record contract needs fields the current 3-byte record does
   not carry (e.g., paragraph count for `DOS_FREE_MEM` symmetry) — WP22 must
   check the OS `DOS_FREE_MEM` contract (`docs/vmm-api.md`) for what it
   actually requires as input before deciding whether the registry record
   needs to grow.

7. **No REU / VMM-uninitialized behavior is unspecified for CASM.**
   `docs/vmm-api.md` documents a `vmmInitialized` safety check that fails
   `DOS_ALLOC_MEM` with `VMM_ERR_INVALID` when no REU was detected at OS
   startup. CASM has never previously depended on VMM, so it has no defined
   behavior for this failure. **Reconciled**: WP22 must define a stable
   `CASM_DIAG_*` for VMM allocation failure (distinct from the existing
   generic ones) and confirm with the user whether the supported local
   VICE/hardware test configuration guarantees REU presence, since a
   silent VMM dependency failure would block all of Phase 6A verification.

8. **No hash algorithm or bucket count exists yet anywhere in this
   codebase.** A repository-wide search found no prior hash-table
   implementation to reuse or diverge from (the only "hash" hit outside CASM
   is an unrelated EDLIN command-line branch label). **Reconciled**: WP26
   must select and document a specific, 6502-efficient hash function, bucket
   count, and collision-chain layout from first principles — this plan does
   not pre-select one, consistent with the master plan leaving it as a
   Phase 6B freeze decision ("a documented 6502-efficient hash").

9. **Taskwarrior currently holds zero Phase 6 tasks.** `task
   project:command64.casm list` returns no matches beyond the closed Phase 5
   tree. **Reconciled**: WP22 creates the CASM Phase 6A milestone and its
   child WP22-WP25 tasks; WP26 creates the CASM Phase 6B milestone and its
   child WP26-WP31 tasks, mirroring how WP16 and (implicitly) each prior
   phase's first work package created its own milestone rather than assuming
   one exists.

## Frozen Contracts Carried Forward (not re-litigated by Phase 6)

- The Phase 5 expression result and resolver ABI (`CASM_EXPR_*`,
  `CASM_RESOLVE_*`, nine-byte result record, five-byte resolver output view)
  is stable. Phase 6B implements the resolver *callback* against that exact
  ABI; it does not change it.
- Symbolic operands remain absolute-width unless a later explicit
  zero-page-forcing syntax is approved (not in Phase 6).
- The base assembler reparses source in Pass 2 rather than storing a syntax
  tree in VMM (master plan foundational constraint).
- Only a relocatable symbol plus/minus an absolute addend is supported
  relocation algebra; general relocatable arithmetic remains out of scope.
- Resource ownership (file handles and VMM allocations) is registered
  centrally in `resources.s` before use and released through
  `resourcesCleanup`, matching every previous phase.

## Scope

### CASM Phase 6A: VMM Storage Foundation

Included:

- real `DOS_ALLOC_MEM`/`DOS_FREE_MEM` wiring replacing `cleanupVmmStub`;
- bounded VMM-backed record storage: capacity, allocation granularity, record
  layout, and a documented failure contract;
- windowed `DOS_VMM_READ`/`DOS_VMM_WRITE` transfer wrappers with bounded
  base-RAM staging buffers;
- deterministic record replay (write, free the RAM staging window, read back,
  compare) as the Phase 6A verification method;
- no-REU / allocation-failure diagnostics and clean fatal-path behavior.

Excluded:

- symbol semantics, hashing, or any interpretation of record contents;
- Pass 1/Pass 2 orchestration;
- relocation records.

### CASM Phase 6B: Symbol Table and Two-Pass Assembly

Included:

- VMM-backed symbol records plus a bounded base-RAM hash bucket array with
  VMM collision chains, built on Phase 6A storage;
- duplicate-definition, undefined-reference, case-sensitivity, and
  maximum-identifier-length behavior;
- Pass 1: address assignment, label/definition insertion, deterministic size
  calculation without emission;
- Pass 2: resolution through the Phase 5 resolver ABI and real byte emission
  through the existing `emit.s` engine;
- relative branch range enforcement against resolved symbol values;
- Pass 1/Pass 2 size or final-PC disagreement treated as an internal fatal
  error;
- replacement of the Phase 5 fixture resolver with the production resolver in
  CASM's normal (non-test) build.

Excluded:

- `.include` processing;
- relocation record generation or R6 serialization (Phase 8);
- listings, maps, macros, constants, or expanded expression arithmetic.

## Proposed Work Packages

Numbering continues from Phase 5's WP16-WP21.

### CASM Phase 6A

- **WP22: prerequisite reconciliation and Phase 0C.4 freeze.** Verify the
  Phase 5 gate (already satisfied above). Create the CASM Phase 6A
  Taskwarrior milestone and WP22-WP25 child tasks in `wiki/tasks/casm.md`
  and `brain/task.md`. Check `DOS_FREE_MEM`'s actual input contract against
  the current 3-byte `CasmVmmRegistry` record and decide whether it must
  grow. Confirm the existing `$7C-$7F` VMM zero-page scratch is sufficient.
  Define the `CASM_DIAG_*` for VMM allocation/no-REU failure. Propose and
  get approval for the MAIN envelope size Phase 6A needs. Record the Phase
  0C.4 VMM record contract (capacity, record layout, replay semantics,
  failure behavior) in `brain/KNOWLEDGE.md`. Implements no VMM source; the
  final increment is version-only.
- **WP23: VMM allocation core.** Create `vmm_store.s`. Wire real
  `DOS_ALLOC_MEM` into allocation, `DOS_FREE_MEM` into `cleanupVmmStub`'s
  replacement, and register/release through the existing `resources.s`
  registry. Define the record capacity ceiling and what happens when it is
  exhausted.
- **WP24: windowed transfer and replay.** Implement bounded
  `DOS_VMM_READ`/`DOS_VMM_WRITE` wrappers with a fixed base-RAM staging
  buffer, offset/bank carry handling within one allocation, and a
  deterministic replay routine (write pattern, discard RAM copy, read back,
  compare) usable by fixtures.
- **WP25: CASM Phase 6A verification, walkthrough, and completion gate.**
  Deterministic fixtures for allocation, exhaustion, free, no-REU failure,
  and read/write/replay through both base-RAM-only and VMM-backed paths,
  independent of any symbol semantics — matching the master plan's Phase 6A
  gate exactly. Build both images, confirm no-change rebuild stability,
  record the walkthrough, request explicit user approval, then close the
  CASM Phase 6A milestone. Does not activate CASM Phase 6B.

### CASM Phase 6B

- **WP26: prerequisite reconciliation and Phase 0C.5 freeze.** Verify CASM
  Phase 6A's completion gate is satisfied and stop if not. Create the CASM
  Phase 6B Taskwarrior milestone and WP26-WP31 child tasks. Freeze: symbol
  record layout; hash function, bucket count, and collision-chain layout;
  duplicate/undefined/case-sensitivity rules; maximum identifier length
  (already bounded to 31 bytes by the Phase 3 token contract — confirm this
  is also the symbol-name bound); the Pass 1 "measure without emitting" mode
  and how it threads through `parser.s`/`opcodes.s`/`emit.s`; confirmation
  that `opcodesFindOpcode`'s mode selection already consults
  `forceAbsoluteWidth`; and the Pass 1/Pass 2 disagreement fatal-error
  contract. Propose and get approval for the MAIN envelope size Phase 6B
  needs. Record the Phase 0C.5 contract in `brain/KNOWLEDGE.md`. Implements
  no symbol-table or pass source; the final increment is version-only.
- **WP27: symbol table storage and hash index.** Create `symbols.s`: VMM-backed
  symbol records over Phase 6A storage, bounded RAM hash buckets, insertion,
  lookup, and duplicate/undefined detection per the WP26 freeze.
- **WP28: Pass 1 — address assignment and definitions.** Drive the existing
  lexer/parser/opcode-table over the full source in the frozen "measure, do
  not emit" mode, assigning `CasmPc` addresses, inserting label definitions
  into the WP27 symbol table, and calculating stable per-statement sizes.
  Includes the static audit of `forceAbsoluteWidth` consultation from the
  Dependency Review.
- **WP29: Pass 2 — resolution and emission.** Rewind and reparse source via
  the Phase 3 `sourceRewind` contract; bind the WP27 symbol table as the
  production resolver callback against the unchanged Phase 5 resolver ABI;
  emit real bytes through the existing `emit.s` engine using resolved
  expression results.
- **WP30: relative branches and Pass 1/Pass 2 disagreement detection.**
  Migrate branch displacement computation to consume resolved symbol values
  (per Dependency Review item 5) and implement the internal fatal error for
  any Pass 1/Pass 2 size or final-PC mismatch.
- **WP31: CASM Phase 6B verification, walkthrough, and completion gate.**
  Forward- and backward-reference static fixtures matching trusted reference
  binaries byte-for-byte (master plan's Phase 6B gate), duplicate/undefined/
  case-sensitivity error fixtures, disagreement-detection fixtures, both
  images, no-change rebuild stability, walkthrough, explicit user approval,
  then close the CASM Phase 6B milestone. Does not activate Phase 7 or
  Phase 8.

## Expected Files

| File | Action | Responsibility |
| --- | --- | --- |
| `brain/plans/2026-07-21-casm-phase6-vmm-storage-and-symbol-table.md` | Create | Parent contract and dependency plan (this document) |
| `brain/plans/<phase6a-wp-slug>.md` | Create later | Dedicated approved plan per WP22-WP25 |
| `brain/plans/<phase6b-wp-slug>.md` | Create later | Dedicated approved plan per WP26-WP31 |
| `src/external/casm/vmm_store.s` | Create later | Bounded VMM-backed record storage (WP23-24) |
| `src/external/casm/resources.s` | Modify later | Real VMM free wiring, registry record growth if justified |
| `src/external/casm/symbols.s` | Create later | VMM symbol table and RAM hash index (WP27) |
| `src/external/casm/pass1.s` | Create later | Address assignment and definitions (WP28) |
| `src/external/casm/pass2.s` | Create later | Resolution and emission (WP29) |
| `src/external/casm/emit.s` | Modify later | Pass-mode threading, resolved-symbol branch displacement |
| `src/external/casm/parser.s`, `opcodes.s` | Modify later | Pass-mode threading, `forceAbsoluteWidth` consultation |
| `src/external/casm/common.inc` | Modify later | VMM record ABI, symbol record ABI, new diagnostics, pass-mode constants |
| `cmake/GenerateCasmTestFixtures.cmake` | Modify later | VMM and symbol/two-pass fixtures |
| `CMakeLists.txt` | Modify later | MAIN envelope size increases, new trusted references if added |
| `wiki/tasks/casm.md` | Modify in WP22/WP26 | CASM Phase 6A and 6B milestones and subtasks |
| `brain/task.md` | Modify in WP22/WP26 | Active work synchronization |
| `brain/KNOWLEDGE.md` | Modify in WP22/WP26 | Phase 0C.4 and 0C.5 contract rationale |

No source or task file listed as a later action is authorized by approval of
this parent contract alone; each WP still requires its own dedicated plan
and approval per the CASM local `AGENTS.md` contract.

## Failure and Cleanup Behavior

- VMM allocation and read/write failures return a stable diagnostic and
  register no partial ownership; a failed `DOS_ALLOC_MEM` must not be
  registered, and a failed `DOS_VMM_READ`/`WRITE` must not be treated as
  success.
- Symbol table and pass failures propagate through the existing central
  cleanup path (`resourcesCleanup`, `exitFatal`); Phase 6 introduces no new
  cleanup owner.
- A Pass 1/Pass 2 disagreement is a fatal internal error, not a recoverable
  diagnostic; it must still route through central cleanup before exit.
- A material ABI, grammar, memory, hash, or dependency change stops
  implementation until the affected work-package plan is amended and
  re-approved.

## Verification Plan

CASM Phase 6A fixtures cover: allocation success/exhaustion, free, no-REU
failure, windowed read/write correctness across a single allocation's offset
range, and deterministic replay through both base-RAM-only and VMM-backed
paths, independent of any symbol semantics.

CASM Phase 6B fixtures cover: forward references, backward references,
duplicate definitions, undefined references, case-sensitive identity,
maximum-length identifiers, relative branches computed from resolved
forward/backward labels, Pass 1/Pass 2 disagreement (synthetic, if it can be
triggered deterministically), and byte-identical output against trusted
reference binaries for every existing Phase 4/5 fixture plus new
label-bearing programs.

Both sub-phases follow the existing CASM-local DOX contract: no broken
`c64-testing` MCP, no web emulator; build artifacts are inspected with
repository tooling and the user performs runtime checks locally.

## Documentation and DOX Closeout

Every implemented work package updates task records and required brain
artifacts. Functional completion also updates the changelog, memory/session
state, and walkthrough. The DOX chain is re-read after edits; `AGENTS.md`
files change only if the implementation changes a durable local contract —
this is expected at least once for the Phase 6B pass-mode architecture
decision (Dependency Review item 3), since it changes how `parser.s`/
`opcodes.s`/`emit.s` are used.

## Completion Gate

CASM Phase 6A is complete only when WP22-WP25 are complete, automated
evidence and the manual walkthrough are recorded, and the user explicitly
approves completion. CASM Phase 6B may not begin before that approval.

CASM Phase 6B is complete only when WP26-WP31 are complete, automated
evidence and the manual walkthrough are recorded, and the user explicitly
approves completion. This document's own approval does not activate either
sub-phase's implementation and does not close Phase 5.

## Progress

- 2026-07-21: Parent contract drafted after Phase 5 closed at CASM `0.1.23`
  build 1094. Dependency review found nine items requiring reconciliation
  before implementation: a near-zero MAIN headroom that both freeze WPs must
  address, a zero-page budget that appears pre-provisioned but is
  unconfirmed, an unbuilt Pass 1 "measure without emitting" mode, an
  unaudited `forceAbsoluteWidth` consultation path, a branch-displacement
  migration from immediate to resolved-symbol computation, a VMM registry
  record whose sufficiency against `DOS_FREE_MEM`'s real contract is
  unchecked, undefined no-REU behavior, no prior hash-table implementation
  to draw on, and zero existing Taskwarrior records for either sub-phase.
  Also flagged a documentation naming collision between CASM's internal
  "Phase 6A/6B" and the top-level project's unrelated, already-completed
  "Phase 6A/6B/6C" in `brain/KNOWLEDGE.md`. Proposed WP22-WP25 (CASM Phase
  6A) and WP26-WP31 (CASM Phase 6B). Awaiting user review before WP22's
  dedicated plan is drafted and CASM Phase 6A implementation begins.
- 2026-07-21: Detailed WP22 plan drafted on `feature/casm-phase6-wp22`:
  `brain/plans/2026-07-21-casm-phase6-wp22-prerequisite-reconciliation.md`.
  Direct research against `src/command64/vmm.asm` resolved dependency items
  1, 2, 6, and 7 from this document concretely (registry record confirmed
  sufficient without growth; zero-page confirmed sufficient; a new 64KB
  single-allocation addressing cap frozen; no-REU/zero-paragraph error-code
  ambiguity documented) and reassigned the MAIN-envelope-size and literal
  diagnostic-value decisions to WP23, matching how WP13/WP19 made those
  decisions inside their own implementing work package rather than in a
  preceding freeze package. CASM Phase 6A remains unimplemented; only WP22's
  plan exists so far, pending approval.
- 2026-07-22: WP22 complete. User approved completion after confirming the
  runtime banner at the restored baseline; the verified `0.1.23` -> `0.1.24`
  increment was applied for real (build 1095), a no-change rebuild held
  stable, and both disk images passed. CASM Phase 6A's Taskwarrior milestone,
  wiki, and brain records agree. WP23 (`8782e75d`) is unblocked but not
  active; its detailed plan
  (`brain/plans/2026-07-21-casm-phase6-wp23-vmm-allocation-core.md`) exists
  and awaits separate approval. No `vmm_store.s` or VMM allocation code
  exists yet.
