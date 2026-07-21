---
feature: casm-phase5-wp16-prerequisite-reconciliation
created: 2026-07-21
status: planned
---

# Plan: CASM Phase 5 WP16 — Prerequisite Reconciliation and Phase 0C.3 Freeze

## Objective

WP16 is the entry gate for Phase 5. It performs no assembler work: it confirms
Phase 4 is genuinely closed, freezes the Phase 0C.3 expression and resolver
contracts as a durable record, and creates the task and plan scaffolding that
WP17-WP21 will execute against.

WP16 changes **no CASM source and no build inputs**. Nothing under
`src/external/casm/`, `cmake/`, or `CMakeLists.txt` is modified. A change to any
of those is out of scope and requires an amended plan.

Parent contract:
`brain/plans/2026-07-20-casm-phase5-minimal-expression-evaluator.md`.

## Dependency Review (2026-07-21)

This plan was written after a dependency re-review; the findings below are the
reason WP16's scope differs from the parent plan as originally drafted.

### Finding 1 — WP15/WP16 ownership collision (resolved)

The parent plan gave WP16 the bullet "Close Phase 4 through its existing
verification and user-approval gate". That is precisely Phase 4 WP15's purpose
(Taskwarrior `8612c2a2`, "verify artifacts and obtain user runtime
confirmation"). Two work packages in different phases cannot both own Phase 4
closure — whichever ran second would either duplicate the audit or rubber-stamp
it.

Resolution, recorded in the parent plan: **WP15 closes Phase 4; WP16 only
verifies that it closed.** WP16's Phase 4 involvement is a precondition check
with a stop condition, not an activity.

### Finding 2 — the prerequisite gate had gone stale

Three of the parent plan's five gate premises were falsified by WP14:

| Premise | Reality on 2026-07-21 |
|---|---|
| WP14 `3e4eab43` pending | Completed; merged to `main` as `55fe474`. Phase 4 subsequently closed by WP15 at CASM `0.1.17` build 1079 |
| No Phase 4 walkthrough exists | `brain/walkthroughs/2026-07-20-casm-phase4-wp14-orchestration-binary-validation.md` |
| Wiki/Taskwarrior UUIDs disagree | Corrected during WP14; no placeholder UUIDs remain |

WP15 remains genuinely pending and is the sole remaining blocker. The parent
plan's gate section has been rewritten accordingly.

**Resolved 2026-07-21.** WP15 completed and the user explicitly approved Phase 4
done at CASM `0.1.17` build 1079. The Phase 4 gate is satisfied; increment 2's
stop condition no longer applies. Evidence:
`brain/walkthroughs/2026-07-20-casm-phase4-wp15-phase-verification-closeout.md`.
WP15 also created the Phase 4 parent milestone
`4796b60c-5f4a-43c7-8270-436075bb3f7b`, which Finding 3 below assumed absent.

### Finding 3 — Taskwarrior has no Phase 5 tasks

`project:command64.casm` currently holds 36 tasks, 35 complete, with WP15 the
only pending entry. **No WP16-WP21 tasks exist.** WP16 must create them; until
it does, Phase 5 has no task-side existence and `brain/task.md` has nothing to
synchronize against. WP16's own task must be created first, since a work package
that creates its own tracking record cannot be tracked by it retroactively.

### Finding 4 — KNOWLEDGE.md has no CASM Phase 4 contract section

`brain/KNOWLEDGE.md` carries "CASM Phase 1 Foundation", "CASM Phase 2 CLI/File
ABI", and "CASM Phase 3 Source/Lexer Contract", then stops. There is no CASM
Phase 4 section. (The "Phase 4"/"Phase 5" rows near line 59 belong to the *OS*
project's phase table and are unrelated.)

WP16 adds the Phase 5 / 0C.3 contract, continuing the Phase 1-3 pattern. It does
**not** retroactively author a Phase 4 contract section: Phase 4's contracts are
recorded in its own plans and walkthrough, and inventing a summary now would
create a second source of truth for a closed phase. This gap is noted for
Phase 11 documentation hardening instead.

### Finding 5 — ordering constraint

WP16 cannot *complete* before WP15 completes, because "Phase 4 approved" is its
entry gate. WP16 planning and the contract-freeze drafting may proceed now,
since neither touches CASM source. The completion gate below enforces the
ordering.

## Scope

Included:

- verify and record that the Phase 4 completion gate is satisfied;
- freeze the Phase 0C.3 expression result and resolver contracts in
  `brain/KNOWLEDGE.md`;
- create Taskwarrior records for WP16-WP21 under `project:command64.casm`;
- register the Phase 5 milestone in `wiki/tasks/casm.md` and `brain/task.md`;
- draft the WP17 detailed plan and confirm the WP18-WP21 plan slugs; and
- obtain explicit approval to activate Phase 5.

Excluded:

- any change under `src/external/casm/`;
- any change to `cmake/` or `CMakeLists.txt`;
- performing Phase 4's acceptance audit or ticking its acceptance list (WP15);
- authoring a retroactive CASM Phase 4 contract section;
- implementing the evaluator, the resolver, or any fixture; and
- a CASM version-stage advance. WP16 ships no code, so CASM stays at `0.1.17`
  and `BUILD_CASM` must not move.

  **Baseline amended 2026-07-21 at Phase 4 closeout.** This plan was written
  against `0.1.16` / build 1078. WP15 advanced CASM to `0.1.17` / build 1079,
  so every `0.1.16` and `1078` reference below now reads `0.1.17` and `1079`.

## Contract to Freeze (Phase 0C.3)

WP16 records the following in `brain/KNOWLEDGE.md` as an approved, durable
contract. The content is transcribed from the parent plan's frozen contract; it
is not re-derived or re-negotiated here.

### Grammar

```text
expression  := extraction? primary addend?
extraction  := "<" | ">"
primary     := number | identifier
addend      := ("+" | "-") number
```

- Extraction applies to the final `primary +/- addend` value.
- Bare numeric literals and bare symbols are valid.
- Only a symbol-derived primary may take an addend; a numeric primary followed
  by `+` or `-` is rejected in Phase 5.
- Parentheses, unary negation, chained operators, symbol-to-symbol arithmetic,
  and current-PC expressions are deferred.
- Existing decimal/hex/binary literal spelling is unchanged; identifiers remain
  case-sensitive.

### Result record

```text
valueLo, valueHi
flags: resolved | symbolDerived | relocatable | forceAbsoluteWidth
extraction: full | low | high
symbolIdLo, symbolIdHi
addendSign
addendMagnitudeLo, addendMagnitudeHi
```

Rationale worth preserving, because each item is a decision that is expensive to
rediscover:

- The addend is **sign plus 16-bit magnitude**, not a signed 16-bit value, so the
  approved `symbol-$FFFF .. symbol+$FFFF` source range is representable without
  importing an unrelated signed-range limit.
- `symbolId` is **opaque** and supplied by the resolver. The evaluator never
  manufactures identities from hashes or token addresses, so symbol identity
  stays owned by the future symbol table.
- Unresolved symbolic operands set `forceAbsoluteWidth` so a placeholder value
  can never select a zero-page encoding. **Instruction size must be stable
  between passes**; this is the property two-pass assembly depends on.
- Low-byte extraction is never an R6 relocation candidate; high-byte extraction
  of a relocatable symbol stays classified as potentially relocatable for
  Phase 8.
- Decimal mode is never assumed or enabled; every `ADC`/`SBC` path establishes
  carry explicitly.

### Resolver boundary

The resolver ABI returns an opaque 16-bit identity, resolved/unresolved state, a
16-bit value when resolved, and an absolute/relocatable classification. Phase 5
verifies against a deterministic fixture resolver; Phase 6B implements the
production resolver over Phase 6A's VMM record store. Dependency order:

```text
Phase 5 evaluator contract
  -> Phase 6A VMM records
  -> Phase 6B symbol table and two-pass resolution
  -> Phase 8 R6 relocation consumption
```

### Routine result contract

- Carry clear: expression accepted, result record valid.
- Carry set: `A` holds a stable `CASM_DIAG_*`; callers must not consume the
  result.
- Every later work-package plan must document its full A/X/Y, zero-page, BSS,
  lexer-lookahead, and status-flag clobbers before that package is approved.

## Files Expected to Change

| File | Action | Responsibility |
|---|---|---|
| `brain/plans/2026-07-21-casm-phase5-wp16-prerequisite-reconciliation.md` | Create | This plan |
| `brain/plans/2026-07-20-casm-phase5-minimal-expression-evaluator.md` | Modify | Corrected gate and WP16 scope (done in planning) |
| `brain/KNOWLEDGE.md` | Modify | Phase 0C.3 expression/resolver contract |
| `wiki/tasks/casm.md` | Modify | Phase 5 milestone and WP16-WP21 subtasks |
| `brain/task.md` | Modify | Phase 5 active-work synchronization |
| `brain/plans/<wp17-slug>.md` | Create | WP17 detailed plan, for separate approval |
| Taskwarrior | Modify | Create WP16-WP21 under `project:command64.casm` |

No file under `src/external/casm/`, `cmake/`, or `CMakeLists.txt` appears in this
table. That is deliberate and is a stop condition if it changes.

## Atomic Implementation Increments

1. **Create the WP16 Taskwarrior task** under `project:command64.casm` with tags
   `casm phase5`, and capture its real UUID. Record the UUID in this plan before
   any further increment, so no later step has to refer to a placeholder.
2. **Verify the Phase 4 gate.** Confirm WP15 is complete, the Phase 4 acceptance
   list in `wiki/tasks/casm.md` is ticked, and the user has explicitly approved
   Phase 4. Record the evidence. **Stop here if any part is unsatisfied** — this
   increment is a check, not a repair.
3. **Freeze the contract.** Add the Phase 0C.3 section to `brain/KNOWLEDGE.md`
   in the style of the existing CASM Phase 1/2/3 sections, including the
   rationale notes above. Verify no existing section is disturbed.
4. **Create WP17-WP21 Taskwarrior tasks** with their real UUIDs, and register the
   Phase 5 milestone plus its subtasks in `wiki/tasks/casm.md` and
   `brain/task.md`. All three records must carry identical UUIDs — the mismatch
   that WP14 had to repair is the specific failure being avoided.
5. **Draft the WP17 detailed plan** (expression ABI and bounded storage) and
   confirm the slugs for WP18-WP21. WP17 is written but not approved here; its
   approval is its own gate.
6. **Verify and request approval.** Confirm no CASM source, cmake, or
   `CMakeLists.txt` file changed; confirm `BUILD_CASM` is unmoved; run
   `git diff --check`; then request explicit approval to activate Phase 5.

Each increment is separately reviewed before the next begins.

## Verification

Because WP16 ships no code, verification is record-integrity rather than build
correctness. There is no runtime matrix and no user emulator session.

- `git diff --name-only` shows only files from the table above; **no**
  `src/external/casm/`, `cmake/`, or `CMakeLists.txt` entries.
- `BUILD_CASM` is byte-identical to its pre-WP16 value (1079). WP16 must not
  advance the build counter, because it changes no hashed source.
- A build of `casm` still succeeds and `casm.prg` is byte-identical to the
  pre-WP16 artifact — proving the record work was genuinely inert.
- Every WP16-WP21 UUID appears identically in Taskwarrior, `wiki/tasks/casm.md`,
  and `brain/task.md`. Cross-check by listing each UUID and grepping both files.
- `brain/KNOWLEDGE.md` gains exactly one new section; the Phase 1/2/3 sections
  are unchanged.
- `git diff --check` is clean.

The broken `c64-testing` MCP and web emulators remain prohibited. No step here
requires either.

## Stop Conditions

- WP15 is incomplete, or the user has not explicitly approved Phase 4 done.
- Any CASM source, `cmake/`, or `CMakeLists.txt` file requires modification.
- `BUILD_CASM` moves, or `casm.prg` is not byte-identical.
- Freezing the contract reveals a grammar, ABI, or memory conflict with the
  existing Phase 4 parser or numeric converter — that is a parent-contract
  amendment, not a WP16 edit.
- Taskwarrior is unavailable and the `task` CLI fallback also fails; record the
  blockage and ask rather than inventing UUIDs.
- The Phase 5 grammar is found to need parser changes that Phase 4 forbade.

## Completion Gate

WP16 completes only when: the Phase 4 gate is verified satisfied and recorded;
the Phase 0C.3 contract is frozen in `brain/KNOWLEDGE.md`; WP16-WP21 exist in
Taskwarrior with matching wiki/brain records; the WP17 plan is drafted; every
verification item above passes; and the user explicitly approves activating
Phase 5.

WP16 advances no version stage. CASM remains at `0.1.17` until a Phase 5 work
package ships code.

## Progress

- 2026-07-21: Plan written after a dependency re-review that resolved the
  WP15/WP16 ownership collision, corrected three stale gate premises, and
  identified that no Phase 5 Taskwarrior tasks exist. No implementation is
  authorized by the creation of this document; WP16 remains blocked on Phase 4
  WP15.

- 2026-07-21 (later): Phase 4 closed by WP15 with explicit user approval at CASM
  `0.1.17` build 1079. WP16's entry gate is now satisfied and WP16 is unblocked.
  The `0.1.16` / build-1078 baseline this plan was written against is superseded
  throughout by `0.1.17` / 1079. Increment 2 becomes a recorded confirmation
  rather than a stop condition. Finding 4's decision stands: no retroactive CASM
  Phase 4 contract section is authored in `brain/KNOWLEDGE.md`; that gap, along
  with two others WP15 recorded (`CasmOutputCreated` conflating created-vs-opened,
  and no entry `CLD`), is deferred to Phase 11 documentation and hardening.
