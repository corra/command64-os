---
feature: casm-phase9-wp43-prerequisite-reconciliation
created: 2026-07-25
status: complete
---

# Plan: CASM Phase 9 WP43 - Prerequisite Reconciliation and Phase 0C.19 Freeze

## Objective

Verify Phase 8's completion gate, reconcile the current Phase 7/8 source
architecture against the master plan's older Phase 9 assumptions, freeze the
Phase 0C.19 include-processing contract, and create the Phase 9 task hierarchy.
WP43 implements no functional include behavior. Its only eventual source change
is the standard version-only completion increment after verification and user
approval.

Parent plan: `brain/plans/2026-07-25-casm-phase9-include-processing.md`.

Branch: `feature/casm-phase9-wp43`, a child of the Stage 9 parent branch
`feature/casm-stage9`. Both currently share baseline commit `b279365`; WP43's
first commit advances only the child branch.

Taskwarrior:

- Parent `687ada7e-4175-41b4-93f3-9e8df85c1a5c`.
- WP43 `2826144e-b7c6-4372-8e1d-74cfff242d1a` (active).
- WP44 `2682d04b-05b0-4828-b88f-852234e3d006`.
- WP45 `199b4da7-987a-44cf-a84d-b4e0b786f5d0`.
- WP46 `005a1819-eda6-4fa5-89e1-5848a5076a7d`.
- WP47 `579096d9-ce77-44db-96a9-c32654238949`.
- WP48 `797bb460-6d82-453c-8f55-7aa53d2eb095`.
- WP49 `a8c3dbf0-9333-4489-9c3b-3e752049b693`.

WP44-WP49 are sequentially dependent and remain pending separate detailed-plan
approval.

## Verified Baseline

- Phase 8 is complete and user-approved at CASM `0.1.44` build 1157. The
  subsequent merged LABEL/API work changed the shared ca65 include and
  legitimately advanced CASM's content-hash counter to 1159 without changing
  its stage; WP43 starts at `0.1.44` build 1159 on `b279365`.
- MAIN `$3400` + `$3700` uses 13,927 of 14,080 bytes: 153 bytes free.
- Private zero page `$70-$8F` is fully allocated.
- Source store: one 65,535-byte VMM allocation.
- Symbol store: one 32KB VMM allocation.
- Relocation store: one 8KB VMM allocation in relocatable Pass 2.
- Resource capacity: eight file records and eight VMM records.
- Top-level source capacity: eight names, each 63 bytes plus null.
- `CasmIoBuffer` is 256 bytes; `CasmVmmBuffer` is 64 bytes and cannot grow
  without breaking the frozen symbol-record invariant.
- The next free diagnostic number after Phase 8 is `$31`.

## Dependency Findings

1. `sourceLoad` completes before Pass 1, closes every input, and fixes one
   immutable combined stream. Include filenames are discovered only later by
   the parser, so Phase 9 requires dynamic Pass 1 append plus graph capture.
2. A live-handle frame stack conflicts with deterministic VMM replay and the
   eight-handle limit. Frames store VMM positions; handles remain transient.
3. `.INCLUDE` lexical classification already exists, but quotes are currently
   invalid source bytes and generic operand parsing cannot represent a
   filename.
4. The 31-byte token payload cannot carry the approved 63-byte filename. A
   dedicated 64-byte operand buffer is mandatory.
5. The flat source cursor is overloaded for load and traversal. It must split
   before dynamic append is safe.
6. Loading a child through `CasmIoBuffer` overwrites unread parent refill data.
   Frame push must save the consumed VMM position, invalidate the refill
   window, then restore/refill on pop; no second 256-byte buffer is approved.
7. Physical provenance and include-instance provenance are distinct. The same
   physical file can be included repeatedly from different sites while sharing
   one stored byte span.
8. Diagnostics index CLI filenames directly and line echoes lack file identity;
   both assumptions fail under nesting.
9. Device-prefix parsing exists in the OS file layer, but canonical identity is
   not exposed as an API. CASM must resolve the approved prefix itself and fold
   supported PETSCII letters for bounded identity comparison.
10. The 65,535-byte source allocation can remain if the cap is explicitly over
    all distinct physical source bytes. Multi-allocation source storage is not
    approved for Phase 9.
11. One 8KB metadata allocation raises maximum production VMM ownership from
    three to four slots, still within the eight-slot registry.
12. `emitDirective` is the wrong owner for includes: include processing changes
    token source and must be dispatched by `casmRunPass` after specialized
    parsing, not treated as byte emission.

## Phase 0C.19 Contract to Freeze

The binding contract is the parent plan's Frozen Observable Contract, with
these implementation-level bounds:

1. Dedicated quoted scanner and 64-byte include operand; no token-record growth.
2. One 65,535-byte immutable physical source store.
3. One 8KB metadata VMM store.
4. 32 physical files, 128 include events, 16 active include levels.
5. Device-plus-folded-name physical identity; original name retained for print.
6. Repeated expansion with deduplicated bytes; active-stack-only cycle checks.
7. Compact BSS frame stack; one shared refill buffer invalidated on push/pop.
8. Pass 1 filesystem discovery; Pass 2 ordered event replay with zero source
   filesystem operations.
9. Logical statement boundaries at every frame/root transition.
10. Physical location plus bounded parent traceback for included diagnostics.
11. No include search list, escapes, implicit include-once, or source segments
    beyond the first allocation.
12. No zero-page growth. MAIN growth is measured and justified per implementing
    WP rather than guessed here.

## Proposed Record Shapes

These shapes bind planning and must be finalized with compile-time offsets in
the implementing WP before code is written:

- Physical record: 128 bytes, power-of-two indexed, transferred as two 64-byte
  windows. Fields include flags, resolved device, name length, source start,
  source length, printable/canonical name storage, and reserved padding.
- Include event: 16 bytes, power-of-two indexed. Fields include parent file ID,
  child file ID, parent line/column, event ordinal, and reserved replay fields.
- Frame: compact BSS record with physical ID, current/end VMM offsets,
  line/column, pending-CR, and parent event identity. WP46 freezes exact size
  after tracing every source-normalization field needed to resume.

The physical/event proposal consumes 4096 + 2048 = 6144 bytes, leaving 2048
bytes reserved within the approved 8KB metadata allocation.

## Diagnostic Reservation Proposal

Starting at `$31`, implementing plans may assign a contiguous Phase 9 range for:

- include filename expected/invalid/too long;
- include open/read/close failure;
- depth exceeded and cycle detected;
- physical catalog full and event log full;
- metadata allocation/transfer failure;
- replay mismatch.

Reuse existing diagnostics only where semantics and source-context behavior are
identical. Combined source-byte overflow may continue to use
`CASM_DIAG_SOURCE_OFFSET_OVERFLOW`.

## Scope

Included in WP43:

- record this plan and the approved parent plan;
- create and synchronize Phase 9/WP43-WP49 task records;
- record Phase 0C.19 in `brain/KNOWLEDGE.md`;
- correct the master plan's stale live-handle wording;
- update CASM-local DOX with the approved planning contract;
- measure and record the unchanged baseline;
- after explicit completion approval, perform the version-only stage increment.

Excluded:

- all `.INCLUDE` grammar or runtime source changes;
- `include.s`, metadata records, frame storage, diagnostics, or fixtures;
- MAIN size changes;
- activation or implementation of WP44-WP49.

## Expected Files

| File | Action |
| --- | --- |
| `brain/plans/2026-07-25-casm-phase9-include-processing.md` | add parent plan |
| `brain/plans/2026-07-25-casm-phase9-wp43-prerequisite-reconciliation.md` | add this plan |
| `wiki/tasks/casm.md` | add parent and WP43-WP49 records |
| `brain/task.md` | synchronize active work |
| `brain/KNOWLEDGE.md` | add Phase 0C.19 freeze |
| `brain/plans/2026-07-16-casm-assembler-implementation-plan.md` | correct stale handle wording |
| `src/external/casm/AGENTS.md` | add approved Phase 9 planning contract |
| `src/external/casm/casm.s` | version-only completion increment later |
| `src/external/casm/BUILD_CASM` | build-managed increment later |

## Atomic Increments

1. Create and link Taskwarrior parent/WP43-WP49 tasks; activate WP43 only.
2. Add the parent and dedicated WP43 plans.
3. Synchronize wiki, brain task, knowledge, master-plan, and DOX records.
4. Verify records, task dependencies, and a clean documentation diff.
5. Ask the user whether WP43 is complete.
6. Only after completion approval, apply the `0.1.44` -> `0.1.45`
   version-only increment, build, verify no-change stability and images, update
   walkthrough/changelog/status, and ask for final closure if the user wants
   the version increment handled as a separate completion increment.

## Verification

- `task project:command64.casm all` shows one Phase 9 parent and WP43-WP49.
- Parent depends on all children; each implementing WP depends on its immediate
  predecessor; only WP43 is active.
- `git diff --check` passes.
- No production include behavior, fixture, MAIN, zero-page, version, or build
  number changes appear in this recording increment.
- DOX closeout confirms the CASM-local contract points to both plans and does
  not claim `.INCLUDE` is already implemented.

## Failure and Cleanup

WP43 has no runtime behavior. If a confirmed source fact contradicts the freeze,
stop and amend this plan before WP44 planning. Do not patch around a contract
conflict during implementation.

## Stop Conditions

- Phase 8 completion evidence is invalid or incomplete.
- Task UUID/dependency synchronization differs between Taskwarrior and records.
- A required design choice remains unresolved.
- The proposed metadata shape cannot fit the approved VMM transfer/capacity
  constraints.
- Any functional source change appears before WP44 approval.

## Completion Gate

WP43 is complete only when all records are synchronized, the Phase 0C.19 freeze
is present, Taskwarrior dependencies are verified, documentation checks pass,
the version-only completion increment is built and stable, and the user
explicitly approves completion. Completion does not activate WP44.

## Progress

- 2026-07-25: User approved the detailed Phase 9 architecture and WP43 record.
  Created the Taskwarrior parent and WP43-WP49 children, chained dependencies,
  and activated WP43 only. Recording plans and synchronized contracts; no
  functional source or version change authorized in this increment.
- 2026-07-25 (verification): Two consecutive `casm` builds held the merged
  baseline at `0.1.44` build 1159. `image_d64`, `test_image_d64`, and
  `casm_overflow_test_d64` all built successfully. `build/casm.prg` is 15,239
  bytes, starts with load address `$3400`, and ends with R6 footer bytes
  `00 34 79 06 52 36` (base `$3400`, 1657 entries, `R6`). No functional source,
  version stage, build counter, fixture, or MAIN-size change resulted from WP43.
  Walkthrough:
  `brain/walkthroughs/2026-07-25-casm-phase9-wp43-prerequisite-reconciliation.md`.
  Awaiting explicit user completion approval before the version-only
  `0.1.44` -> `0.1.45` increment.
- 2026-07-25 (branch topology): Merged the LABEL branch into `main`, created
  `feature/casm-stage9` at updated `main` commit `b279365`, and retained the
  WP43 working state on child branch `feature/casm-phase9-wp43`. Revalidated
  two no-change CASM builds at `0.1.44` build 1159.
- 2026-07-25 (completion): User approved WP43 completion. Applied the sole
  authorized source change, `VERSION_STAGE` 44 -> 45; the content-hash build
  advanced once to 1160 and a second build held stable. All three disk images
  pass. `build/casm.prg` remains 15,239 bytes with load address `$3400` and R6
  footer `00 34 79 06 52 36`. Taskwarrior and durable records closed WP43;
  WP44 remains pending separate plan approval and activation.
