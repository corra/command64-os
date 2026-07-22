---
feature: casm-phase5-wp16-prerequisite-reconciliation
created: 2026-07-21
revised: 2026-07-21
status: complete
---

# Plan: CASM Phase 5 WP16 - Prerequisite Reconciliation and Phase 0C.3 Freeze

## Objective

WP16 is the Phase 5 entry and recovery gate. It verifies the completed Phase 4
baseline, reconciles Taskwarrior records left by an abandoned Phase 5 attempt,
freezes the Phase 0C.3 expression/resolver contract, creates the detailed WP17
plan, and advances CASM from `0.1.17` to `0.1.18` as required for a completed
CASM work package.

WP16 implements no evaluator, resolver, parser adapter, or expression fixture.
Those remain separately planned WP17-WP21 work.

Parent contract:
`brain/plans/2026-07-20-casm-phase5-minimal-expression-evaluator.md`.

## Baseline

- Branch point: `9e58b8a44647028bc392656cdcbff9bc99927279`.
- Phase 4 is complete at CASM `0.1.17`, build 1079.
- Phase 4 completion evidence:
  `brain/walkthroughs/2026-07-20-casm-phase4-wp15-phase-verification-closeout.md`.
- The approved MAIN envelope is `$2800`; Phase 4 leaves 408 bytes headroom at
  both `$3400` and `$3500` relocation bases.
- WP16 starts from a clean worktree on `feature/casm-phase5-wp16-2`.

## Dependency Review

### Phase 4 Ownership

WP15 owns Phase 4 closure. WP16 only verifies the closed gate and stops if its
wiki, brain, Taskwarrior, artifact, or user-approval evidence disagrees. WP16
must not repeat or retroactively alter the Phase 4 acceptance decision.

### Recovered Taskwarrior State

Taskwarrior is not empty. The prior attempt created these records without
synchronizing the repository:

| Work | UUID | Observed state |
|---|---|---|
| WP16 | `0062fd20-929d-4ffd-a2b5-032db5ec4109` | pending with start timestamp |
| Phase 5 parent | `6b72d639-53d0-4d1a-92ba-8c4d56096388` | pending |
| WP17 | `3b09ea77-c325-4072-90fc-9812181a4e04` | pending with start timestamp |
| WP18 | `8f9467b6-e37d-4701-a4a6-6f90bd8fbf5b` | pending with start timestamp |
| WP19 | `4acf22c2-8253-4673-918a-8dd38cc18221` | incorrectly completed |
| WP20 | `41d120ed-b550-4551-9694-e66bd6f65cef` | pending with start timestamp |
| WP21 | `225a69ce-b46c-404d-a86b-d2c4494e9c3f` | pending |

The repository at the baseline contains no Phase 5 task section in
`wiki/tasks/casm.md` or `brain/task.md`. WP16 must preserve every existing UUID,
reopen WP19, stop downstream started tasks without completing them, encode the
WP16 -> WP21 dependency chain, and synchronize all three record systems.
Inventing replacement UUIDs is forbidden.

### Work-Package Version Rule

The earlier WP16 plan prohibited source and build changes, but
`src/external/casm/AGENTS.md` requires every completed CASM work package to
advance the stage. WP16 therefore includes one final source increment:

- change only `VERSION_STAGE` in `src/external/casm/casm.s` from `17` to `18`;
- allow the normal build helper to advance `BUILD_CASM` exactly once;
- verify a second no-change build does not advance it again.

No other CASM source or build-system file is in scope. If the stage cannot be
represented or the build helper changes more than expected, stop.

### Decimal-Mode Dependency

The Phase 4 baseline contains no entry `CLD`. Phase 5 therefore cannot claim
that decimal mode is not assumed. The frozen rule is narrower and testable:

- Phase 5 does not execute `SED` or `CLD` in evaluator routines;
- every evaluator `ADC`/`SBC` path establishes carry explicitly;
- the application-level entry-mode assumption remains inherited technical debt
  for a separately approved hardening package.

WP17-WP21 must not silently broaden this into a caller-independent decimal-mode
guarantee.

### Evaluation and Emission Boundary

The evaluator creates no output bytes or relocation records. WP20 may pass a
resolved expression value to existing instruction/directive emission, but that
is adapter behavior, not evaluator ownership. Unresolved expressions remain
metadata-only in Phase 5 and must not be emitted as placeholder zero values.

### Downstream Order

```text
WP16 contract/task freeze
  -> WP17 ABI and bounded storage
  -> WP18 numeric/checking core
  -> WP19 symbol/extraction/resolver behavior
  -> WP20 parser adapter and fixture harness
  -> WP21 verification and completion gate
  -> Phase 6A VMM records
  -> Phase 6B production symbol table/two-pass resolution
  -> Phase 8 relocation consumption
```

Only one downstream work package may be active. Approval or implementation of
an earlier package does not approve a later package.

## Contract to Freeze

### Grammar

```text
expression  := extraction? primary addend?
extraction  := "<" | ">"
primary     := number | identifier
addend      := ("+" | "-") number
```

- Extraction applies after `primary +/- addend` evaluation.
- Bare numeric literals and symbols are valid.
- Only symbol-derived primaries accept an addend.
- Numeric arithmetic, parentheses, unary negation, chained operators,
  symbol-to-symbol arithmetic, and current-PC expressions are deferred.
- Existing decimal/hex/binary spelling and case-sensitive identifiers remain
  unchanged.

### Result Record

```text
valueLo, valueHi
flags: resolved | symbolDerived | relocatable | forceAbsoluteWidth
extraction: full | low | high
symbolIdLo, symbolIdHi
addendSign
addendMagnitudeLo, addendMagnitudeHi
```

- Addends use sign plus unsigned 16-bit magnitude.
- `symbolId` is an opaque resolver-owned identity.
- Unresolved symbols retain addend and extraction metadata and set
  `forceAbsoluteWidth`; placeholder values may not choose zero-page encoding.
- Low extraction is not relocatable. High extraction preserves potential
  relocation classification for Phase 8.
- Resolved arithmetic outside `$0000..$FFFF` fails instead of wrapping.

### Resolver and Routine ABI

- The resolver returns identity, resolved state, optional 16-bit value, and
  absolute/relocatable classification.
- Carry clear means the expression result record is valid.
- Carry set means `A` contains a stable `CASM_DIAG_*`; callers must not consume
  the result record.
- WP17-WP21 plans must state A/X/Y, status flags, stack, zero-page, BSS,
  lexer-lookahead, and self-modifying-code effects before implementation.

## Scope

Included:

- verify Phase 4 completion and baseline artifacts;
- repair Phase 5 task-record state without replacing valid UUIDs;
- freeze the contract above in `brain/KNOWLEDGE.md`;
- synchronize the Phase 5 parent and WP16-WP21 in Taskwarrior,
  `wiki/tasks/casm.md`, and `brain/task.md`;
- draft the detailed WP17 plan and reserve exact WP18-WP21 slugs;
- update planning/session/changelog records required by the repository;
- advance CASM to `0.1.18` and increment `BUILD_CASM` exactly once; and
- produce a WP16 walkthrough and request explicit completion approval.

Excluded:

- expression ABI declarations or evaluator implementation;
- parser, opcode, emitter, lexer, diagnostic, fixture, CMake, or linker changes;
- Taskwarrior completion of WP16 or activation of WP17 before user approval;
- Phase 4 record rewriting; and
- completion of the Phase 5 parent milestone.

## Expected Files

| File | Action |
|---|---|
| `brain/plans/2026-07-21-casm-phase5-wp16-prerequisite-reconciliation.md` | amend and approve this plan |
| `brain/plans/2026-07-20-casm-phase5-minimal-expression-evaluator.md` | reconcile dependencies and boundaries |
| `brain/plans/2026-07-21-casm-phase5-wp17-expression-abi.md` | create detailed WP17 plan |
| `brain/KNOWLEDGE.md` | add Phase 0C.3 contract |
| `brain/MEMORY.md` | record unchanged layout and verified artifact measurements |
| `brain/task.md` | register Phase 5 hierarchy and WP16 progress |
| `wiki/tasks/casm.md` | register Phase 5 hierarchy and matching UUIDs |
| `CHANGELOG.md` | record the WP16 contract/version increment |
| `brain/walkthroughs/2026-07-21-casm-phase5-wp16-prerequisite-reconciliation.md` | create verification walkthrough |
| `src/external/casm/casm.s` | stage `17` -> `18` only |
| `src/external/casm/BUILD_CASM` | build-managed single increment |
| Taskwarrior | reconcile parent and WP16-WP21 records |

No `cmake/`, `CMakeLists.txt`, or other CASM source file may change.

## ABI, Storage, and Runtime Effects

- No expression ABI is implemented by WP16.
- No zero-page, BSS, stack, file, VMM, lexer, parser, or output behavior changes.
- The PRG payload must be byte-identical except for the version-stage/build
  banner bytes and relocation metadata necessarily affected by those bytes.
- No resource is acquired and no cleanup path changes.

## Atomic Implementation Increments

1. Capture clean baseline: status, `BUILD_CASM`, version banner, both link-base
   artifact measurements, and hashes needed for the bounded comparison.
2. Verify Phase 4 closure across walkthrough, wiki, brain, git history, and
   Taskwarrior. Stop rather than repair Phase 4 if any evidence disagrees.
3. Reconcile Taskwarrior: preserve existing UUIDs, stop premature WP17/WP18/WP20
   starts, reopen the incorrectly completed WP19, encode sequential dependencies,
   and leave WP16 as the only active work package.
4. Synchronize the Phase 5 parent and WP16-WP21 UUIDs/statuses into
   `wiki/tasks/casm.md` and `brain/task.md`.
5. Freeze the Phase 0C.3 contract in `brain/KNOWLEDGE.md`; record unchanged
   storage ownership in `brain/MEMORY.md`.
6. Create the detailed WP17 plan. Confirm reserved slugs for WP18-WP21, but do
   not create speculative implementation plans for those packages.
7. Dry-run and verify the mandatory stage increment, then restore `0.1.17.1079`.
   Verify artifacts, documentation, task agreement, DOX scope, and whitespace;
   write the walkthrough and request explicit completion approval.
8. Only after explicit user approval: apply stage `17` -> `18`, build once to
   update `BUILD_CASM`, build again to prove no-change stability, and mark WP16
   complete. Leave the Phase 5 parent open.
9. Separately request approval before activating WP17.

Each increment is reviewed before the next. A failed implementation receives a
root-cause analysis; no repeated speculative edits are allowed.

## Verification

- `git diff --check` is clean.
- Changed paths are limited to the expected-files table.
- Taskwarrior, wiki, and brain contain identical UUIDs and statuses for the
  Phase 5 parent and WP16-WP21; WP19 exists exactly once and is pending.
- WP16 is the only started Phase 5 child before completion approval.
- `cmake --build build --target casm` succeeds at both relocation bases.
- `BUILD_CASM` advances exactly once; a no-change rebuild leaves it unchanged.
- CODE, RODATA, BSS, MAIN headroom, PRG size, and relocation count are recorded.
- Artifact comparison confirms no functional payload change outside version
  metadata.
- No C64 runtime session is required because WP16 changes no runtime behavior.
- The prohibited `c64-testing` MCP and web emulators are not used.

## Stop Conditions

- Phase 4 completion evidence disagrees.
- A valid existing Taskwarrior UUID would need replacement or Taskwarrior fails.
- Any evaluator/parser/emitter/fixture/build-system change appears necessary.
- The version increment changes more than version metadata or overflows the
  approved MAIN envelope.
- A grammar, resolver, storage, relocation, or decimal-mode conflict requires a
  parent-contract change beyond the clarifications already recorded.
- WP17 implementation would begin before WP16 completion approval.

## Documentation and DOX Closeout

Re-read the root, `src`, `src/external`, `src/external/casm`, `wiki`, and
`wiki/tasks` DOX chains after edits. Update an AGENTS.md only if WP16 changes a
durable local contract or child index; otherwise report it intentionally
unchanged. Do not mark WP16 done until the walkthrough is presented and the user
explicitly confirms completion.

## Completion Gate

WP16 completes only when all increments pass, Phase 5 records agree, the
Phase 0C.3 contract is durable, the WP17 plan exists but is not active, CASM is
verified at `0.1.18`, and the user explicitly approves WP16 completion.

## Progress

- 2026-07-21: Original plan drafted after Phase 4 dependency review.
- 2026-07-21: Phase 4 closed at `0.1.17` build 1079 with explicit approval.
- 2026-07-21: Recovery review on `feature/casm-phase5-wp16-2` found partial
  Taskwarrior creation, an incorrectly completed WP19, premature downstream starts, repository
  record divergence, the work-package version-rule conflict, decimal-mode
  wording ambiguity, and evaluator/emitter boundary ambiguity. Plan revised;
  no WP16 implementation is authorized until this revision is approved.
- 2026-07-21: Revised plan approved and implemented through its completion
  candidate. Taskwarrior UUIDs were
  preserved, WP19 was reopened, downstream starts were stopped, sequential
  dependencies were recorded, and repository task records were synchronized.
  Phase 0C.3 was frozen and the detailed WP17 plan created. The `0.1.18.1080`
  version-only dry run passed both link bases, no-change rebuild, release image,
  and three-byte-only artifact comparison; `0.1.17.1079` was then restored as
  required before completion approval. WP16 and the Phase 5 parent remain open.
- 2026-07-21: User explicitly approved WP16 completion. The verified final
  increment advanced CASM to `0.1.18` build 1080; the immediate no-change build
  preserved 1080 and `image_d64` passed. WP16 is complete. The Phase 5 parent
  remains open and WP17 remains pending separate approval.
