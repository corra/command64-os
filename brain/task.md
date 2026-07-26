# Project Tasks

- [x] Taskwarrior UUID `13a45324`: CASM Phase 1 native application scaffold
  - [x] `ef6a001e` Create synchronized task records and CASM-local DOX contract
  - [x] `7b318ab7` Declare approved zero-page, base-RAM, and module ABI
  - [x] `05e59de2` Implement central resource ownership and exit paths
  - [x] `8891fe27` Implement minimal diagnostics
  - [x] `eb83b449` Implement entry point and version banner
  - [x] `c6c3b55e` Integrate ca65 target and release disk
  - [x] `5a0e36c5` Verify configure, target, R6 artifact, and disk image
  - [x] `161ed5a9` Record walkthrough and obtain user runtime confirmation
  - [x] Confirm the Phase 0 contracts required by the Phase 1 plan before
        source implementation

- [x] Taskwarrior #29 (`df2f766c`): CASM Phase 2 CLI and native file-service
      foundation
  - [x] `ba51bd58` Synchronize task records and record approved Phase 0B
        contracts
  - [x] `79d7f6aa` Declare shared CLI, file, and stream ABI
  - [x] `5d997dfd` Implement bounded command-line parser
  - [x] `8e0711ad` Implement managed native file wrappers
  - [x] `b7d0e543` Implement real central file-handle cleanup
  - [x] `3bc11e77` Extend CLI and file-service diagnostics
  - [x] `1d2c1761` Integrate Phase 2 entry-point orchestration
  - [x] `0870f804` Correct EOF carry propagation and preserve the registered
        resource slot across `DOS_CLOSE_FILE`; build 1011 runtime verified
  - [x] `9e4d8175` Verify artifacts and obtain user runtime confirmation

- [x] Taskwarrior #29 (`099257cc`): CASM Phase 3 source stream and minimal
      lexer
      (corrected from `[/]` during WP15 increment 2: Taskwarrior has recorded
      this Completed since 2026-07-17 and all eleven subtasks were ticked, so
      the in-progress marker was stale. This is a record-truth correction to a
      long-approved phase, not a Phase 4 acceptance tick.)
  - [x] `65832339` Synchronize task records, dependency corrections, and
        approved Phase 0C.1 contracts
  - [x] `9ab8caf3` Investigate DEBUG assembler reuse feasibility
  - [x] `9e0c03f3` Declare shared source/lexer ABI and bounded state
  - [x] `fcb0e164` Implement the rewindable source backend; user runtime matrix
        confirmed and completion approved 2026-07-16; build 1020 advanced CASM
        to `0.1.6`
  - [x] `9c733c1a` Implement newline normalization and provenance; user runtime
        matrix confirmed and completion approved 2026-07-16; build 1022 advanced
        CASM to `0.1.7`
  - [x] `cda20f5b` Implement deterministic rewind and bounded line API (Option A
        partitioned buffer, envelope raised to `$2000`); user runtime matrix
        confirmed and completion approved 2026-07-17; build 1025 advanced CASM to
        `0.1.8`
  - [x] `7196a56f` Implement the minimal lexer core (Option 1 static-only);
        `lexer.s` with lookahead, token primitives, whitespace/comment skipping,
        and punctuation tokens; user non-regression confirmed and completion
        approved 2026-07-17; build 1028, CASM at `0.1.9`
  - [x] `9e1a1a12` Implement textual and numeric token scanning
  - [x] `3367d36d` Implement mnemonic classification
  - [x] `a68d3603` Integrate diagnostics and temporary token dump
  - [x] `178b0884` Verify artifacts and obtain user runtime confirmation

- [x] Taskwarrior (`4796b60c-5f4a-43c7-8270-436075bb3f7b`): CASM Phase 4
      statement parser, opcode table, and numeric static assembly
      **COMPLETE — user approved 2026-07-21 at CASM `0.1.17` build 1079.**
  - Parent milestone created 2026-07-21 during WP15 increment 2. Phases 1-3 each
    had a parent record; Phase 4 had none, so WP11-WP15 were orphaned. The
    completed Phase 3 UUID `099257cc` was deliberately not reused.
  - [x] `82a11475` WP11: implement statement parser and syntax validation;
        build 1042, CASM `0.1.13`
  - [x] `a3f90f05` WP12: implement opcode table and addressing mode matcher;
        build 1047, CASM `0.1.14`
  - [x] `ded1cfd9` WP13: implement numeric directives and byte/word emission
  - [x] `3e4eab43` WP14: orchestration and end-to-end binary validation;
        build 1078, CASM `0.1.16`
  - [x] `8612c2a2` WP15: verification and phase closeout; build 1079,
        CASM `0.1.17`
  - Phase 4 approved done by the user on 2026-07-21. Phase 5 is now unblocked.
  - Carried forward to Phase 11: `CasmOutputCreated` conflates "created" with
    "opened an existing file"; no `CLD` at entry; no CASM Phase 4 contract
    section in `brain/KNOWLEDGE.md`.

- [x] Taskwarrior (`3e4eab43-0f48-4db5-843f-c749bcb79d8a`): CASM Phase 4 WP14: execute orchestration and end-to-end binary validation
  - [x] Create detailed implementation plan
  - [x] Obtain phased implementation approval
  - [x] Increment 1: reconcile DSC1 documentation and capture baselines
  - [x] Increment 2: strict hex-manifest conversion tooling and `casmemit1.ref`
  - [x] Increment 3: `casmhello.ref` integrated and verified
  - [x] Increment 4: compiler loop driver audit and module decision
  - [x] Increment 5: production orchestration documented
  - [x] Increment 6: syntax, addressing, range, PC, and cleanup fixtures added
  - [x] Fix `.ORG` operand defect and verify regression safety
  - [x] Increment 7: host-side verification and manual walkthrough setup
  - [x] Add `casmmodes.ref` per-addressing-mode byte certification
  - [x] Fix unreachable `CASM_MODE_ZEROPAGE_Y` and add build-breaking guard
  - [x] Increment 8: user runtime matrix verification — all groups pass
  - [x] Increment 9: advance to `0.1.16` build 1078 and synchronize records
  - Completed 2026-07-21. Two defects found and fixed; WP14 does not complete
    Phase 4 — it unblocks WP15.
  - Outstanding for the record only: observed values for G4.2 (`casmzpi2`
    diagnostic) and G7.1–G7.3 (assembling over an existing output file).

- [x] Taskwarrior (`8612c2a2-afdd-4c8f-bf42-4947bc486f97`): CASM Phase 4 WP15: verify artifacts and obtain user runtime confirmation
  - Plan: `brain/plans/2026-07-20-casm-phase4-wp15-phase-verification-closeout.md`
  - Activated 2026-07-21 on `feature/casm-phase4-wp15` from clean tree `55fe474`.
  - [x] Increment 1: confirm WP14 complete and its records agree
  - [x] Increment 2: reconcile records (Phase 4 parent milestone `4796b60c`
        created; phantom wiki UUIDs `31bb2198`/`501bc58c`/`83ab4f2d` replaced
        with the real `82a11475`/`a3f90f05`/`ded1cfd9`; stale Phase 3 milestone
        text replaced in `wiki/tasks/casm.md` and here)
  - [x] Increment 3: clean baseline captured at `d75adca`
  - [x] Increment 4: both link configs fit `$2800` with 408 bytes headroom;
        R6 artifact cross-checked (11057 B, base `$3400`, 1172 relocations)
  - [x] Increment 5: both disks verified; 3 trusted refs match end to end by
        independent transcription; non-circular provenance confirmed
  - [x] Increment 6: static audit — 52/52 carry sites clean, no `SED`, stack
        balanced, output lifecycle and diagnostic preservation sound
  - [x] Increment 7: advanced to `0.1.17`, `BUILD_CASM` 1078 -> 1079 exactly
        once and stable on no-change rebuild; banner `CASM V0.1.17.1079`
  - [x] Increment 8: walkthrough written with pending manual steps
  - [x] Increment 9: user executed the smoke set, shell-integrity checks, and
        both WP14 gap captures — all pass. G4.2 confirmed
        `OPERAND OUT OF RANGE`; G7 falsified the predicted deletion hazard
        (no clobber; `fileDelete`'s `checkDeviceReady` preflight bails on the
        latched `63,FILE EXISTS`, so the delete never runs)
  - [x] Increment 10: user approved Phase 4 done on 2026-07-21
  - Walkthrough: `brain/walkthroughs/2026-07-20-casm-phase4-wp15-phase-verification-closeout.md`

- [x] Taskwarrior (`6b72d639-53d0-4d1a-92ba-8c4d56096388`): CASM Phase 5
      minimal expression evaluator
  - Parent plan: `brain/plans/2026-07-20-casm-phase5-minimal-expression-evaluator.md`
  - [x] `0062fd20-929d-4ffd-a2b5-032db5ec4109`: WP16 prerequisite
        reconciliation and Phase 0C.3 freeze
    - Detailed plan: `brain/plans/2026-07-21-casm-phase5-wp16-prerequisite-reconciliation.md`
    - Active on `feature/casm-phase5-wp16-2` from baseline `9e58b8a`
    - Existing Phase 5 Taskwarrior UUIDs preserved; WP19 reopened after rollback
    - Premature WP17/WP18/WP20 starts stopped; sequential dependencies recorded
    - [x] Phase 4 baseline and completion evidence verified
    - [x] Phase 0C.3 contract frozen in `brain/KNOWLEDGE.md`
    - [x] Wiki/brain/Taskwarrior hierarchy synchronized
    - [x] Detailed WP17 plan drafted; WP18-WP21 slugs reserved
    - [x] Version-only completion candidate dry-run verified; baseline restored
    - [x] User approved completion; advanced to `0.1.18` build 1080
    - [x] Final build, no-change rebuild, and release image verified
    - Walkthrough: `brain/walkthroughs/2026-07-21-casm-phase5-wp16-prerequisite-reconciliation.md`
  - [x] `3b09ea77-c325-4072-90fc-9812181a4e04`: WP17 expression ABI and bounded
        storage; depends on WP16
    - Active on `feature/casm-phase5-wp17` from WP16 commit `3b53513`
    - Detailed plan: `brain/plans/2026-07-21-casm-phase5-wp17-expression-abi.md`
    - [x] Captured `0.1.18.1080` baseline and diagnostic range `$00-$23`
    - [x] Added exact result offsets, flags, enums, diagnostics, and assertions
    - [x] Added 36-byte CODE / 9-byte BSS `expr.o`; no imports or zero page
    - [x] Verified both link bases, 363-byte headroom, and release image
    - [x] Dry-run `0.1.19.1082` and no-change rebuild; restored build 1081
    - [x] User approved completion; final `0.1.19` build 1082 verified
    - Walkthrough: `brain/walkthroughs/2026-07-21-casm-phase5-wp17-expression-abi.md`
  - [x] `8f9467b6-e37d-4701-a4a6-6f90bd8fbf5b`: WP18 numeric primary and checked
        arithmetic core; depends on WP17
    - Active on `feature/casm-phase5-wp18` from WP17 commit `2bb5e4b`
    - Test plan: `brain/plans/2026-07-21-casm-phase5-wp18-test-plan.md`
    - [x] Extended printable Phase 5 diagnostics through `$27`
    - [x] Moved numeric core/scratch behind parser compatibility wrapper
    - [x] Added optional addend parsing and checked add/sub/apply helpers
    - [x] Added trusted `casmnum2` and three radix-overflow fixtures
    - [x] Both links and test image pass with 107-byte MAIN headroom
    - [x] Dry-run `0.1.20.1085`; restored `0.1.19.1084`
    - [x] User approved completion; final `0.1.20` build 1085 verified
    - Walkthrough: `brain/walkthroughs/2026-07-21-casm-phase5-wp18-numeric-primary.md`
  - [x] `4acf22c2-8253-4673-918a-8dd38cc18221`: WP19 symbol, extraction, and
        resolver behavior; reopened and dependent on WP18
    - Active on `feature/casm-phase5-wp19` from WP18 commit `755fc45`
    - Detailed plan: `brain/plans/2026-07-21-casm-phase5-wp19-symbol-resolver.md`
    - Baseline: `0.1.20.1085`, 10,133 MAIN bytes, 107-byte headroom
    - Test plan, deterministic resolver, and fixtures remain WP20 scope
    - User approved CASM MAIN expansion from `$2800` to `$2A00` after the first
      candidate exceeded the old envelope by 214 bytes
    - User approved shared five-byte resolver callback output ABI declarations
    - [x] Added resolver callback/trampoline and bounded evaluator
    - [x] Added resolved/unresolved addend and extraction classification
    - [x] Both links and test image pass with 298-byte `$2A00` MAIN headroom
    - [x] Dry-run `0.1.21.1089`; restored candidate `0.1.20.1088`
    - [x] User approved completion; final `0.1.21` build 1089 verified
    - Walkthrough: `brain/walkthroughs/2026-07-21-casm-phase5-wp19-symbol-resolver.md`
  - [x] `41d120ed-b550-4551-9694-e66bd6f65cef`: WP20 parser adapter and expression
        fixture harness; depends on WP19
    - Active on `feature/casm-phase5-wp20` from WP19 commit `56d8078`
    - Plan: `brain/plans/2026-07-21-casm-phase5-wp20-parser-adapter.md`
    - Test plan: `brain/plans/2026-07-21-casm-phase5-wp20-test-plan.md`
    - Baseline: `0.1.21.1089`, 298-byte `$2A00` MAIN headroom
    - [x] Added exact 27-case evaluator/resolver test plan
    - [x] Migrated parser and `.BYTE`/`.WORD` paths to expression adapter
    - [x] Removed all `parseNumericValue` callers/export
    - [x] Added standalone `test_casm_expr` and production adapter fixtures
    - [x] Both CASM/test links and `test_image_d64` pass; CASM headroom 243 bytes
    - [x] User confirmed harness, adapter reference, resolver failure, and cleanup
    - [x] Dry-run `0.1.22.1093`; restored candidate `0.1.21.1092`
    - [x] User approved completion; final `0.1.22` build 1093 verified
    - Walkthrough: `brain/walkthroughs/2026-07-21-casm-phase5-wp20-parser-adapter.md`
  - [x] `225a69ce-b46c-404d-a86b-d2c4494e9c3f`: WP21 verification, walkthrough,
        and completion gate; depends on WP20
    - Active on `feature/casm-phase5-wp21` from WP20 commit `8afb438`
    - Plan: `brain/plans/2026-07-21-casm-phase5-wp21-verification-closeout.md`
    - Coverage gaps: positive zero, negative zero, repeated extraction
    - [x] Expanded harness to 30 cases with exact token-column checks
    - [x] Independent carry/stack/token/unresolved audit found no contract defect
    - [x] CASM/harness no-change builds and both relocation bases pass
    - [x] Test and release images pass with correct inventories
    - [x] User confirmed 30-case harness, five references, and cleanup matrix
    - [x] Dry-run `0.1.23.1094`; restored candidate `0.1.22.1093`
    - [x] User approved completion; final `0.1.23` build 1094 verified
    - Walkthrough: `brain/walkthroughs/2026-07-21-casm-phase5-wp21-verification-closeout.md`

- [x] Taskwarrior (`d68e6c58-ac89-44f4-81a2-40b14093585b`): CASM Phase 6A VMM
      storage foundation (complete). CASM-local phase numbering; distinct
      from the unrelated, already-completed top-level "Phase 6A/6B"
      elsewhere in `brain/KNOWLEDGE.md` — always write "CASM Phase 6A" in
      full.
  - Parent plan: `brain/plans/2026-07-21-casm-phase6-vmm-storage-and-symbol-table.md`
  - [x] `eb7541e5-c3aa-4528-bdcd-2571d96688d9`: WP22 prerequisite
        reconciliation and Phase 0C.4 freeze
    - Detailed plan: `brain/plans/2026-07-21-casm-phase6-wp22-prerequisite-reconciliation.md`
    - Active on `feature/casm-phase6-wp22` from `main` commit `dcb74bb`
    - [x] Phase 5 baseline and completion evidence verified (`0.1.23` build 1094)
    - [x] Researched OS VMM primitive contract directly from `src/command64/vmm.asm`
    - [x] Confirmed `CasmVmmRegistry`'s 3-byte record already matches `DOS_FREE_MEM`'s
          real input (SegHi/Bank); no registry growth needed
    - [x] Froze a 65536-byte single-allocation addressing cap (16-bit `Off` cursor
          limit from a fixed SegHi/Bank pair)
    - [x] Documented that `DOS_VMM_READ`/`WRITE` perform no OS-side bounds checking;
          CASM's windowed wrapper must self-enforce it
    - [x] Deferred MAIN-envelope-size and literal diagnostic-value decisions to WP23
    - [x] Defined the nine-case WP23-WP25 fixture matrix
    - [x] Created CASM Phase 6A Taskwarrior milestone and WP22-WP25 child tasks
    - [x] Synchronized `wiki/tasks/casm.md` and `brain/task.md`
    - [x] Freeze Phase 0C.4 contract in `brain/KNOWLEDGE.md`
    - [x] Record findings in `brain/MEMORY.md`
    - [x] CHANGELOG.md `[Unreleased]` entry
    - [x] Detailed WP23 plan drafted (`brain/plans/2026-07-21-casm-phase6-wp23-vmm-allocation-core.md`)
    - [x] Version-only completion candidate dry-run verified (`0.1.24.1095`,
          2-byte diff); baseline `0.1.23.1094` restored via `git checkout`
    - [x] Both images verified at restored baseline; `git diff --check` clean
    - [x] Walkthrough drafted: `brain/walkthroughs/2026-07-21-casm-phase6-wp22-prerequisite-reconciliation.md`
    - [x] User approved completion; final `0.1.24` build 1095 verified,
          no-change rebuild stable, both images pass
  - [x] `8782e75d-d935-4e15-bf3c-d0488a1533a8`: WP23 VMM allocation core
    - Detailed plan: `brain/plans/2026-07-21-casm-phase6-wp23-vmm-allocation-core.md`
    - User approved the plan as drafted; fixture question resolved as static
      verification only (no runtime fixtures in WP23, matrix remains WP25's)
    - Active on `feature/casm-phase6-wp23` from `feature/casm-phase6-wp22`
      commit `d0878d6`; baseline CASM `0.1.24` build 1095
    - [x] Added `CASM_VMM_ALLOC_MAX_BYTES` and `$28`-`$2B` diagnostics with
          contiguous-range asserts to `common.inc`
    - [x] Created `vmm_store.s` (`vmmStoreAlloc`/`vmmStoreFree`), wired to
          `DOS_ALLOC_MEM`/`DOS_FREE_MEM`
    - [x] Resolved during implementation: no 16-bit byte count can exceed the
          65536-byte cap after rounding, so `CASM_DIAG_VMM_ALLOC_TOO_LARGE` is
          unreachable and was dropped; carry-safe rounding clamps the
          65,521-65,535 wraparound range to 4,096 paragraphs instead
    - [x] Zero-byte-count requests rejected locally before any OS call,
          keeping a later `VMM_ERR_INVALID` unambiguous
    - [x] Found and fixed two register-clobber bugs before building: slot vs.
          SegHi/Bank staging collision in `vmmStoreFree`, and `X` clobbered
          across `jsr vmmStoreFree` in `resourcesCleanup`'s VMM loop
    - [x] Exported `CasmVmmRegistry`; replaced `cleanupVmmStub` with a real
          `vmmStoreFree` call in `resourcesCleanup`; `CasmVmmCount` now
          maintained incrementally (no bulk reset), matching `CasmFileCount`
    - [x] Measured MAIN usage: 10,647/10,752 bytes, 105 bytes free; no size
          change needed (unlike the WP13/WP19 precedent); user confirmed
    - [x] Static verification: `vmm_store.o` is CODE-only (144 bytes); imports/
          exports match exactly; both relocation bases and `test_image_d64`/
          `image_d64` pass
    - [x] Walkthrough drafted: `brain/walkthroughs/2026-07-21-casm-phase6-wp23-vmm-allocation-core.md`
    - [x] Completion dry-run verified (`0.1.25.1097`, 2-byte diff, no-change
          rebuild stable); baseline `0.1.24.1096` restored via `git checkout`,
          reproduced exactly; both images pass at restored baseline
    - [x] User ran the VICE sanity check (CASM against a trusted fixture);
          confirmed clean assemble/exit -- resourcesCleanup's rewired VMM
          loop is a no-op today with no allocation call site yet
    - [x] User approved walkthrough, no-change MAIN size decision, and
          completion
    - [x] Final verified increment applied: `0.1.25` build 1097 matches the
          dry-run PRG hash exactly; no-change rebuild stable across two more
          builds; both images pass
  - [x] `228daccc-f389-48cf-bd52-9f1ac610234a`: WP24 windowed transfer and
        replay
    - Detailed plan: `brain/plans/2026-07-21-casm-phase6-wp24-windowed-transfer-and-replay.md`
    - User approved the plan as drafted, including both resolved open
      questions (deferred staging buffer size; shared `$2B` diagnostic)
    - Active on `feature/casm-phase6-wp24` from `a60cb89`; baseline CASM
      `0.1.25` build 1097
    - Reconciled a real gap: the Phase 0C.4 bounds-checking mandate has no
      registry field to read a granted size from; growing
      `CASM_VMM_REC_SIZE` 3 -> 4 bytes (adds a page-count field), keeping
      `resourceRegisterVmm` the sole registry writer
    - [x] Implemented `vmmWindowRead`/`vmmWindowWrite`/`vmmReplay` in
          `vmm_store.s`; bounds-check slot range, buffer-size fit, slot
          ownership, offset+count overflow, and granted-page count before
          any OS call, via a shared private `vwPrepareTransfer`
    - [x] Added `CasmVmmBuffer` (32 bytes) as the fixed staging buffer,
          reusing already-reserved `$78-$7F` scratch for offset/count (no
          new zero-page byte)
    - [x] Measured MAIN overflow (123 bytes at `$2A00`); user approved
          `$2A00` -> `$2B00` (133 bytes free)
    - [x] Static verification: `vmm_store.o` BSS is exactly the new buffer;
          `resources.o` BSS grew by exactly 8 bytes (registry growth);
          zero-page and diagnostic contracts unchanged; both relocation
          bases and both images pass
    - [x] User ran a VICE sanity check (CASM against a trusted fixture);
          confirmed clean assemble/exit
    - [x] Walkthrough drafted: `brain/walkthroughs/2026-07-21-casm-phase6-wp24-windowed-transfer-and-replay.md`
    - [x] Completion dry-run verified (`0.1.26.1099`, 2-byte diff, no-change
          rebuild stable); baseline `0.1.25.1098` restored via `git checkout`,
          reproduced exactly; both images pass at restored baseline
    - [x] User approved walkthrough and completion
    - [x] Final verified increment applied: `0.1.26` build 1099 matches the
          dry-run PRG hash exactly; no-change rebuild stable across two more
          builds; both images pass
  - [x] `544a04bd-4ccb-47c6-9013-8af57aa37353`: WP25 verification, walkthrough,
        and completion gate
    - Detailed plan: `brain/plans/2026-07-21-casm-phase6-wp25-verification-closeout.md`
    - User approved the plan as drafted, including both resolved open
      questions (`vmmalloc4`/`vmmnoreu` manually deferred; `casm_vmm`/
      `test_casm_vmm` naming/size confirmed)
    - Active on `feature/casm-phase6-wp25` from `3fd1f10`; baseline CASM
      `0.1.26` build 1099
    - Reconciled: stale acceptance checklist (WP23/WP24 items were
      unchecked, now fixed), a test-harness build-dependency hazard (must
      stub `diagPrintFatal` like WP20 did for lexer symbols instead of
      importing the real `diagnostics.s`, which would transitively pull in
      `lexer.s`/`source.s`), and a wording mismatch between WP22's fixture
      matrix ("a different staging buffer") and WP24's actual single
      `CasmVmmBuffer` design
    - [x] Created `tests/src/casm_vmm/casm_vmm.s` (7 automated fixtures:
          `vmmalloc1-3`, `vmmreplay1` covering write/read/replay,
          `vmmoffset1`, `vmmbounds1`, `vmmfree1`); `vmmalloc4`/`vmmnoreu`
          documented as manually deferred
    - [x] First real run of WP23/WP24's code found three defects: a wrong
          test expectation in `vmmalloc3` (`CASM_DIAG_REGISTRY_FULL` vs.
          `vmmStoreAlloc`'s actual `CASM_DIAG_VMM_ALLOC_FAILED`), and two
          production bugs in `vmm_store.s` — `vwPrepareTransfer` rejecting
          the valid exact-65536-byte boundary case, and `vmmReplay` stashing
          its slot in a zero-page cell `vwPrepareTransfer` itself clobbers
          (the same shared-scratch bug class WP23 caught twice already).
          All three fixed with explicit user approval to fix in place
    - [x] All 7 automated fixtures pass in VICE after the fixes
    - [x] Phase 6A Acceptance checklist closed out in `wiki/tasks/casm.md`
          based on the actual runtime result
    - [x] Walkthrough: `brain/walkthroughs/2026-07-21-casm-phase6-wp25-verification-closeout.md`
    - [x] User approved completion; final `0.1.27` build 1102 matches the
          dry-run PRG hash exactly; no-change rebuild stable; both images
          pass. **WP25 complete; CASM Phase 6A milestone complete.**
  - **CASM Phase 6A closed 2026-07-22 at CASM `0.1.27` build 1102. CASM
    Phase 6B WP26 (below) is now the active CASM thread.**

- [x] Taskwarrior (`58c94a92-48f8-4039-8dcc-44f42d193d3c`): CASM Phase 6B
      WP26 prerequisite reconciliation and Phase 0C.5 freeze
  - Branch `feature/casm-phase6-wp26`
  - Plan: `brain/plans/2026-07-22-casm-phase6-wp26-prerequisite-reconciliation.md`
  - Status: complete; documentation/task-tracking only, no symbol-table or
    pass source written -- the only source change was the version-only
    completion increment
  - Plan required two review iterations before implementation began: fixed
    a bug where the first draft's label-statement design would have
    clobbered the label name via the shared transient token buffer
    (`CasmTokenText`), and tightened the Pass 1/Pass 2 mode-gating design to
    a single check point in `emitRawByte` rather than two redundant checks
  - Dry-ran the version bump (2-byte diff versus baseline, confined to the
    version/build banner digits), then applied it for real: final CASM
    `0.1.28` build 1103, no-change rebuild stable, both `image_d64` and
    `test_image_d64` build clean. **WP26 complete.**
  - WP27 (symbol table storage), WP28 (Pass 1), WP29 (Pass 2), WP30
    (branch/disagreement detection), and WP31 (verification) remain
    separately gated and unplanned in detail, per the CASM AGENTS.md
    per-work-package-plan-approval requirement

- [x] Taskwarrior (`0dd437f3-3248-4294-aee7-39bb8571f1c8`): CASM Phase 6B
      WP27 symbol table storage and hash index
  - Branch `feature/casm-phase6-wp27`, from `feature/casm-phase6-wp26`'s
    tip; baseline CASM `0.1.28` build 1112
  - Plan: `brain/plans/2026-07-22-casm-phase6-wp27-symbol-table-storage.md`
  - Reconciled beyond WP26's freeze: the 37-byte symbol record could not
    fit through Phase 6A's existing 32-byte `CasmVmmBuffer` window at all;
    user chose to pad the record to 64 bytes and grow the buffer to match,
    replacing a 3-term multiply-by-37 with a single 16-bit shift-left-6 for
    record-index-to-VMM-offset arithmetic
  - Found `symbols.s` needs none of the predicted `CasmPassScratch0-3`
    zero-page group (its transient state is all values, not pointers, so it
    lives in ordinary BSS) -- leaves that group free for WP28
  - Calling convention deliberately avoids `CasmValue0Lo/Hi` across nested
    `vmmWindowRead`/`Write` calls (the shared-scratch-clobber bug class that
    hit `vmm_store.s` three times in WP23-25); `symbolsLookup`'s signature
    matches the Phase 5 resolver callback ABI exactly for zero-adapter WP28
    binding
  - Found and fixed (user-approved) a pre-existing Phase 6A defect:
    `diagPrintFatal`'s message bound never covered `$28`-`$2B`, so all four
    Phase 6A VMM diagnostics silently fell back to "UNKNOWN" since
    WP23/24 -- fixed alongside wiring diagnostics `$2C`-`$2F`
  - Implemented `src/external/casm/symbols.s` (`symbolsInit`/`symbolsInsert`/
    `symbolsLookup`, private `symbolsFindChain`, 64-byte VMM records,
    128-bucket hash index, 512-symbol cap), built and fixture-tested in
    isolation -- no `casm.s`/`parser.s`/`opcodes.s` call site yet (WP28)
  - `common.inc` amended (`CASM_VMM_BUFFER_SIZE` 32 -> 64, `CASM_SYMBOL_*`
    constants, diagnostics `$2C`-`$2F`)
  - New `tests/src/casm_symbols/casm_symbols.s` harness: 10 fixtures
    (`syminit1`, `symins1`, `symlook1`, `symlookmiss1`, `symdup1`,
    `symcase1`, `symchain1`, `symlen1`, `sympad1`, `symfull1`), all passing
  - MAIN grown `$2B00` -> `$2F00` (848-byte measured overflow, 176 bytes
    headroom). User ran `TEST_CASM_VMM` (regression) and `TEST_CASM_SYMBOL`
    (new matrix) in VICE from `build/test.d64`: both passed, no `F`
    failures
  - Final CASM `0.1.29` build 1113, no-change rebuild stable, both
    `image_d64` and `test_image_d64` build clean. **WP27 complete.**
  - Walkthrough:
    `brain/walkthroughs/2026-07-22-casm-phase6-wp27-symbol-table-storage.md`
  - WP28 (`712fe7af`) is unblocked in Taskwarrior but not yet planned in
    detail; WP29 (Pass 2), WP30 (branch/disagreement detection), and WP31
    (verification) remain separately gated, per the CASM AGENTS.md
    per-work-package-plan-approval requirement
  - **CASM Phase 6B WP28 (Pass 1 - address assignment and definitions) is
    now the active CASM thread, gated on its own dedicated plan.**

- [x] Taskwarrior (`712fe7af-1e41-46c9-9a19-49c2632cd15a`): CASM Phase 6B
      WP28 Pass 1 - address assignment and definitions
  - Branch `feature/casm-phase6-wp28`, from `feature/casm-phase6-wp27`'s
    tip, per this project's branch-per-WP convention
  - Plan: `brain/plans/2026-07-22-casm-phase6-wp28-pass1-address-assignment.md`
  - Wired WP27's VMM-backed symbol table into a real two-pass foundation:
    `CASM_PASS_MODE_MEASURE`/`CASM_PASS_MODE_EMIT` gated at exactly one
    point in `emitRawByte` (`emit.s`) -- measure mode skips the actual byte
    write but still advances `CasmPc`
  - Added label-statement grammar to `parser.s` (colon-terminated `LABEL:`
    identifier statements) inserting into the symbol table via
    `symbolsInsert`, with duplicate detection
  - Wired `expr.s`'s resolver callback to call `symbolsLookup` for real
    (previously a stub, `parserRejectIdentifier`), so identifiers in
    expressions now resolve against the symbol table
  - Added `CASM_PARSER_STMT_FORCE_ABS`, growing `CasmParserStmt` from 6 to
    7 bytes, forcing absolute-width addressing for symbol-derived operands
    so a label always assembles to the same width in both passes
  - Caught and fixed two defects during implementation, before any test
    run: the force-absolute flag was corrected to derive from
    `CASM_EXPR_FLAG_SYMBOL_DERIVED` (set on any resolver success) rather
    than `CASM_EXPR_FLAG_FORCE_ABS` (set only when unresolved), which would
    have let Pass 1/Pass 2 disagree on size for already-resolved backward
    references; and `emit.s`'s pass-mode gate as originally spec'd would
    have clobbered the byte to emit with `CasmPassMode`'s own value --
    fixed to stash the byte in X first
  - New `tests/src/casm_pass1/casm_pass1.s` harness: 7 fixtures (label +
    bare, label + mnemonic same line, forward reference, backward
    reference, undefined symbol under measure-mode tolerance,
    duplicate-label detection, and a comprehensive forward-ref + 3-label +
    `.BYTE`/`.WORD` fixture)
  - Found and fixed two test-fixture defects during VICE verification (not
    implementation defects): a zero-page collision in
    `tests/src/casm_expr/casm_expr.s` (its mock lexer's `ScriptLo`/
    `ScriptHi` cursor at `$70`/`$71` collided with `expr.s`'s new use of
    `CasmPtr0Lo`/`Hi`, fixed by moving the test's cursor to `$7C`/`$7D`);
    and the generated `p1size1` fixture used lowercase `.byte`/`.word`,
    which CASM's lexer never accepts (only uppercase unshifted/shifted
    PETSCII), fixed by capitalizing to match every other fixture
  - MAIN grown `$2F00` -> `$3000`. User ran all 7 `casm_pass1` fixtures and
    a `test_casm_expr` regression re-run in VICE from `build/test.d64`:
    both passed, no `F` failures
  - Final CASM `0.1.30` build 1123, no-change rebuild stable, both
    `image_d64` and `test_image_d64` build clean. **WP28 complete.**
  - Walkthrough:
    `brain/walkthroughs/2026-07-22-casm-phase6-wp28-pass1-address-assignment.md`

- [x] Taskwarrior (`8e989bdf-7aed-4bfe-ae9c-3771edb7caf5`): CASM Phase 6B
      WP29 Pass 2 - resolution and emission
  - Branch `feature/casm-phase6-wp29`, from `feature/casm-phase6-wp28`'s
    tip, CASM `0.1.30` build 1123 baseline
  - Plan: `brain/plans/2026-07-23-casm-phase6-wp29-pass2-resolution-emission.md`
  - Direct research found WP29's real scope narrower than the parent plan's
    prose: WP28 already bound `symbolsLookup` as the production resolver and
    made `parserParseExpressionValue` pass-mode-aware, so WP29 needed zero
    changes to `symbols.s`/`parser.s`/`opcodes.s`/`emit.s` -- purely a
    `casm.s` orchestration rewrite
  - Rewrote `start` as a two-pass driver sharing one new private dispatch,
    `casmRunPass`: Pass 1 runs `CASM_PASS_MODE_MEASURE` to `EOF` with no
    output file (labels insert via `symbolsInsert`); Pass 2 calls
    `sourceRewind`/`lexerInit` again, moves `fileCreateOutput` here (from
    its old pre-Pass-1 position), sets `CASM_PASS_MODE_EMIT`, and re-drives
    the identical dispatch for real (labels are a no-op the second time)
  - Building surfaced a real ca65 branch-range error (three `bcs` branches
    pushed past +/-127 bytes) -- fixed with two near trampolines
    (`startInitFatal` for pre-Pass-1 failures, `startFatalNear` for Pass
    1/Pass 2 failures) rather than widening one, the same class of fix this
    codebase has hit before
  - Per the user's confirmed decisions: reused WP28's already-hand-verified
    `p1fwd1`/`p1back1`/`p1size1` fixtures directly as the new
    trusted-reference source (3 new `tests/fixtures/casm/*.ref.hex`
    manifests, no new `.seq` files) and reused `p1undef1` unmodified as the
    one end-to-end "real `casm.s` Pass 2 fails cleanly on undefined symbol"
    fixture
  - Corrected a real discrepancy found during dependency review: the master
    plan and `AGENTS.md` both still described a structured "Pass 2 emission
    events" design (2026-07-16) that WP26 had already overridden
    (2026-07-22) without either document being updated -- both corrected in
    place, cross-referencing WP26's plan
  - Confirmed by direct inspection that relative-branch displacement
    computation needs zero code changes (already consumes resolved symbol
    values via `CasmParserStmt.VAL_LO/HI` regardless of origin) -- WP30's
    remaining work is range-check verification and disagreement detection
  - Measured MAIN directly via `ld65 -m`: 12137 of 12288 bytes, 151 bytes
    headroom, no size increase needed. User ran the full VICE matrix (5
    pre-existing Phase 4/5 trusted references as a non-symbol regression
    check, 3 new label references, 1 undefined-symbol failure case) from
    `build/test.d64` and `build/image.d64`: all passed ("All tests pass")
  - Final CASM `0.1.31` build 1126, no-change rebuild stable, both
    `image_d64` and `test_image_d64` build clean. **WP29 complete.**
  - Walkthrough:
    `brain/walkthroughs/2026-07-23-casm-phase6-wp29-pass2-resolution-emission.md`

- [x] Taskwarrior (`a9a117d2-b4e5-4f5c-8df1-19239b1e4cf7`): CASM Phase 6B
      WP30 relative branches and Pass 1/Pass 2 disagreement detection
  - Branch `feature/casm-phase6-wp30`, from `feature/casm-phase6-wp29`'s
    tip, CASM `0.1.31` build 1126 baseline
  - Plan: `brain/plans/2026-07-23-casm-phase6-wp30-branches-and-disagreement-detection.md`
  - Confirmed by direct inspection that `opcodesFindOpcode` resolves any
    branch mnemonic to `CASM_MODE_RELATIVE` before ever consulting
    `CASM_PARSER_STMT_FORCE_ABS`, so relative-branch resolution needed no
    `opcodes.s` changes -- the only planned production code was
    `CASM_DIAG_PASS_MISMATCH` detection
  - Per the user's confirmed decisions: co-located `CasmPass1FinalPc` +
    `emitCheckPassAgreement` in `emit.s` (not `casm.s`, which can never be
    linked by a standalone harness) so a new `test_casm_passcheck` unit
    harness could prove the fatal path fires directly; added 3 new
    relative-branch fixtures (`brfwd1`, `brback1`, `brrng1`) closing a real
    gap -- no prior fixture, Phase 4 included, had ever used a label as a
    branch target
  - `brfwd1` immediately exposed a real, previously-latent defect (not a
    fixture-authoring mistake): `eiRelative` computed the `-128..127` range
    check even in `CASM_PASS_MODE_MEASURE`, using the `$0000` placeholder
    `pevMeasureUnresolved` stores for a still-unresolved forward reference
    -- producing spurious `CASM_DIAG_BRANCH_OUT_OF_RANGE` in Pass 1
    regardless of the real, in-range Pass 2 distance. Latent since Phase 4;
    `brrng1` had been passing before the fix only coincidentally (right
    diagnostic, wrong reason -- Pass 1's spurious error, not Pass 2's real
    one)
  - Presented the exact root cause and proposed fix to the user before
    touching source (not in the approved plan's scope); fixed with
    explicit approval by making `eiRelative` pass-mode-aware, mirroring the
    existing `CASM_DIAG_UNDEFINED_SYMBOL` tolerate-in-MEASURE/
    enforce-in-EMIT pattern. The fix itself pushed an existing branch past
    ca65's +/-127-byte range, fixed with a `bcc :+ / jmp eiRet / :`
    trampoline
  - Measured MAIN directly via `ld65 -m`: 12191 of 12288 bytes, 97 bytes
    headroom, no size increase needed. User ran the full VICE matrix twice
    (round 1 caught the `brfwd1` defect; round 2, post-fix, added a
    regression check against Phase 4's literal-target branch fixtures
    `casmbrp1`/`brp2`/`brn1`/`brn2`): both rounds confirmed "All tests pass"
  - Final CASM `0.1.32` build 1130, no-change rebuild stable, both
    `image_d64` and `test_image_d64` build clean. **WP30 complete.**
  - Walkthrough:
    `brain/walkthroughs/2026-07-23-casm-phase6-wp30-branches-and-disagreement-detection.md`

- [x] Taskwarrior (`86d8ac7e-0725-44b8-81ae-dcef143a20ad`): CASM Phase 6B
      WP31 verification, walkthrough, and completion gate
  - Branch `feature/casm-phase6-wp31`, from `feature/casm-phase6-wp30`'s
    tip, CASM `0.1.32` build 1130 baseline
  - Plan: `brain/plans/2026-07-23-casm-phase6-wp31-verification-closeout.md`
  - Closed the last unchecked Phase 6B Acceptance item
    (duplicate/undefined/case-sensitive/max-length behavior) with real
    end-to-end proof through production `casm.s`, not just WP27/28's
    isolated module-level proof
  - Found a real, non-obvious byte-encoding pitfall before writing any
    fixture: a naive mixed-case-ASCII case-sensitivity `.seq` fixture would
    test nothing, since CASM's lexer only accepts unshifted (`$41-$5A`) or
    shifted (`$C1-$DA`) PETSCII as identifier bytes and raw `.seq` files
    receive no ca65 charmap conversion (unlike WP27's ca65-assembled test
    harness). Confirmed the correct shifted-byte values empirically by
    compiling `"Case"`/`"CASE"` directly with ca65 before constructing
    `casmcase1.seq`'s shifted-byte label via `string(ASCII 204/207/207/208
    ...)`
  - Added `casmmaxid1.seq` (31-character label) for the max-length item;
    reused `p1dup1.seq`/`p1undef1.seq` unmodified for duplicate/undefined
    through real `casm.s` -- no new files needed there
  - Per the user's confirmed decisions: skipped a new end-to-end
    symbol-table-full fixture (already covered by WP27's isolated proof
    plus the duplicate-symbol fixture's shared propagation path) and used a
    7-fixture targeted Phase 3/4 regression sample rather than a full
    60-fixture historical re-run, given WP30's `eiRelative` defect was
    narrowly specific to a live-counter difference check no other Phase 4
    diagnostic shares
  - No production source changed at all -- unlike WP30, this WP's new
    fixture categories found no latent defect; every case passed on the
    first VICE run
  - User ran the full consolidated matrix (5 standalone test harnesses, 12
    byte-identical trusted references, 3 diagnostic fixtures through real
    `casm.s`, 7-fixture regression sample) from `build/test.d64` and
    `build/image.d64`: "All tests pass"
  - Final CASM `0.1.33` build 1131, no-change rebuild stable, both
    `image_d64` and `test_image_d64` build clean. **WP31 complete.**
  - Walkthrough:
    `brain/walkthroughs/2026-07-23-casm-phase6-wp31-verification-closeout.md`
  - **CASM Phase 6B milestone (`166e5352-5aa0-45bd-8bee-5baf0e878798`) is
    complete.** CASM Phase 7 (VMM-backed source, multiple top-level inputs)
    and Phase 8 (R6 relocation consumption) remain separately gated and
    unstarted; neither is activated by this closure.

- [x] Taskwarrior (`25e69c58-b1cf-4c43-8aa9-5ae79b015375`): CASM Phase 7
      WP32 prerequisite reconciliation and Phase 0C.10 freeze
  - Plan:
    `brain/plans/2026-07-23-casm-phase7-wp32-prerequisite-reconciliation.md`
  - Verified the CASM Phase 6B completion gate (`0.1.33` build 1131, 97
    bytes MAIN headroom, `ld65 -m` measurement matched WP31's own figure
    exactly, confirming no source has moved since Phase 6B closed)
  - Found the master plan's stated Phase 7 rationale is stale: "sources
    larger than the RAM window" and "byte-at-a-time OS calls" describe a
    problem `source.s` doesn't have -- it already streams any file size in
    bounded 256-byte OS blocks. The only confirmed hard gap is CLI-level:
    `cli.s`'s `cliCopySource` hard-rejects a second positional source token
  - Asked the user two architectural questions given that finding: whether
    to still build a VMM-cached source model despite the stale rationale
    (for the real remaining benefit of eliminating Pass 2's forced second
    physical disk read on `sourceRewind`), and what capacity to freeze for
    `CasmSourceNames`. Both recommended options confirmed: VMM-cached
    whole-source load; 8-slot x 64-byte array (matching the existing
    `CASM_FILE_CAPACITY`/`CASM_VMM_CAPACITY = 8` convention)
  - Froze the Phase 0C.10 contract: one pre-pass load stage populating a
    single VMM allocation from every input file in order; a 65535-byte
    (not 65536 -- `vmmStoreAlloc` cannot represent that count in 16 bits)
    combined multi-file cap, generalizing rather than tightening today's
    existing single-file limit; VMM-backed refill filling the existing
    256-byte `CasmIoBuffer` through up to four 64-byte transfers, since
    `CASM_VMM_BUFFER_SIZE` cannot grow without breaking the WP27
    symbol-record contract; file-boundary identity/line resets driving the
    already-unused `CasmSourceFileId` placeholder from Phase 3; and
    diagnostic filename printing conditional on more than one source file,
    keeping single-file diagnostic text byte-identical to today's
  - Found no new `CASM_DIAG_*` identifier is expected for Phase 7 -- a
    contrast with every prior phase (6A added 4, 6B added 4); every new
    failure mode reuses an existing diagnostic, including
    `CASM_DIAG_EXTRA_SOURCE` whose message text is already plural
  - No symbol-table, source, or CLI source was written -- the only source
    change is the version-only completion increment
  - Proposed WP33 (VMM-backed load/traversal equivalence), WP34 (multi-file
    CLI/provenance), WP35 (diagnostic filename integration), WP36
    (verification/closeout); none authorized by WP32 itself
  - **CASM Phase 7 milestone (`1a0d0dc8-3267-4885-aa83-adf923d56422`,
    depending on WP32-WP36) created. Final CASM `0.1.34` build 1132,
    no-change rebuild stable, both `image_d64` and `test_image_d64` build
    clean. WP32 complete.** WP33-WP36 each require their own dedicated plan
    and approval before activation.

- [x] Taskwarrior (`ac152eb9-f202-41e3-bdf5-8ce5af9a8a88`): CASM Phase 7
      WP33 VMM-backed source load and traversal equivalence
  - Plan: `brain/plans/2026-07-24-casm-phase7-wp33-vmm-backed-source-load.md`
  - Active on `feature/casm-phase7-wp33` from `main` at `ab7445b`
  - Implemented Phase 0C.10 Contract items 1-3: new `sourceLoad` pre-pass
    (opens `CasmSourceName`, streams it in 256-byte OS blocks, writes each
    into a 65535-byte VMM allocation through up to four 64-byte
    `vmmWindowWrite` chunks); VMM-backed `sourceRefill` (chunked
    `vmmWindowRead` into `CasmIoBuffer`); simplified
    `sourceOpen`/`sourceRewind`/`sourceClose` (pure cursor resets, no OS
    calls). `sourceFetchPhysical` and every byte-classification/
    newline-normalization routine needed zero changes -- confirmed by
    tracing that they only consult the block index/length window and a
    delivered-byte offset, meaningful identically regardless of data
    source
  - Per the user's confirmed scoping decision, WP33 stayed single-file
    only: no `CasmSourceNames` array or file table yet, since no WP33
    fixture could exercise them with more than one input (deferred to
    WP34)
  - New `casmvmm65`/`casmvmm128` fixtures target the internal 64-byte VMM
    chunk boundary `casm256` (always four full chunks) never exercised.
    MAIN bumped `$3000` -> `$3200` (`casm`) and `$3200` -> `$3300`
    (`casm_pass1`/`casm_passcheck`, both link `source.s` whole)
  - Two real defects found through user runtime testing and fixed
    (matching the WP25/WP30 precedent -- a genuinely new fixture category
    surfacing a latent defect, not just proving new code correct):
    - `sourceRefill`'s VMM-read copy omitted the `<CasmIoBuffer` low-byte
      term (`CasmIoBuffer` links at `$5FDA`, not page-aligned), so every
      refill wrote 218 bytes before the real buffer, corrupting whatever
      BSS state sat there -- surfaced as two seemingly unrelated symptoms
      (`casmemit1`: spurious `OUTPUT WRITE FAILED` plus a real drive-level
      `32, SYNTAX ERROR`; `casmhello`: spurious `DUPLICATE ORG`) depending
      on which fixture's chunk offsets hit which cell. Fixed by adding the
      missing term as its own correctly-carried addition
    - `test_casm_pass1` never freed `sourceLoad`'s new per-fixture VMM
      allocation (only `symbolsInit`'s was accounted for pre-WP33), so the
      8-slot VMM registry filled after 4 of 7 fixtures (`....`) and the
      rest failed with the registry already full (`fff`). Fixed by calling
      `resourcesCleanup` after each fixture in `casm_pass1.s`
  - User ran the full verification matrix after both fixes: standalone
    harnesses, all 12 byte-identical trusted references, all 7 Phase 3
    traversal fixtures, and both new chunk-boundary fixtures all matched
    their hand-derived expected results
  - Final CASM `0.1.35` build 1137, no-change rebuild stable, both
    `image_d64` and `test_image_d64` build clean. MAIN headroom 273 of
    12800 bytes
  - Walkthrough:
    `brain/walkthroughs/2026-07-24-casm-phase7-wp33-vmm-backed-source-load.md`
  - **WP33 is complete.** WP34 (multi-file CLI and file-boundary
    provenance) remains separately gated and unstarted.

- [x] Taskwarrior (`035c0295-ae69-4795-b85d-a0c113e80cb8`): CASM Phase 7
      WP34 multi-file CLI and file-boundary provenance
  - Plan:
    `brain/plans/2026-07-24-casm-phase7-wp34-multi-file-cli-and-provenance.md`
  - Active on `feature/casm-phase7-wp34` from `feature/casm-phase7-wp33`'s
    tip
  - Implemented Phase 0C.10 Contract items 4, 6, 7: `cli.s` grew
    `CasmSourceNames`/`CasmSourceLens` (8 slots) /`CasmSourceCount`,
    `cliCopySource` writing through a compile-time slot-address lookup
    table (`cliSourceSlotLo/Hi`) since 64 doesn't divide evenly into 256;
    `source.s`'s `sourceLoad` became an outer file loop recording each
    file's start offset into a new 16-byte `CasmSourceFileTable`
    (offsets only -- halved from the original 4-bytes/entry sketch since a
    file's end is implicitly the next file's start) and inserting a
    synthetic LF between files that don't already end in a newline;
    `sourceRefill` gained a file-boundary check resetting
    `CasmSourceFileId`/line/column and, per the user's confirmed decision,
    unconditionally clearing the pending-CR latch at every boundary so a
    bare-CR-ending file can never phantom-collapse with a following file's
    leading LF
  - Found the combined 65535-byte cap is genuinely not free once more than
    one file exists (correcting the scope of WP33's own "free" finding,
    which only held for `N=1`) -- added an explicit `slCheckCap` check
  - Generalized `fileio.s`'s `inputStreamOpen` from a hardcoded
    single-buffer pointer to a caller-supplied X/Y pointer (needed since
    `sourceLoad` now selects a different file each loop iteration)
  - Caught that `test_casm_pass1`/`test_casm_passcheck` would silently
    fail to link under the new signature (neither links `cli.s`) before it
    became a real problem -- both gained their own small stand-in copies
    of the new `cli.s`-owned symbols
  - A single-file assembly (`CasmSourceCount == 1`) takes an identical
    code path to WP33's by construction (the boundary check's gating
    condition), confirmed by every existing single-file trusted reference
    and both standalone harnesses re-passing unmodified
  - MAIN bumped `$3200` -> `$3500` (507-byte overflow at the old size)
  - New fixtures: `casmmf1`/`casmmf2`/`casmmf3` (two/two-with-synthetic-
    newline/three-file cross-file symbol resolution, byte-identical
    trusted references), `casmmfcr1`/`casmmfcr2` (cross-file pending-CR
    regression). `casmmfovf1`/`casmmfovf2` (combined-overflow boundary,
    40000/30000 bytes) needed their own dedicated `casm_overflow_test.d64`
    disk image -- per the user's confirmed decision, the real cap cannot
    be exercised with less content and `test.d64` had no room left
  - User ran the full verification matrix (both standalone harnesses, all
    12 pre-existing plus 3 new byte-identical references, the cross-file
    pending-CR fixture, 9th-source-file rejection, combined-overflow
    boundary) across two sessions and confirmed: "all test pass"
  - Corrected `AGENTS.md`'s stale "Phase 2 accepts one unquoted source
    filename" contract
  - Final CASM `0.1.36` build 1139, no-change rebuild stable, all three
    disk images (`image_d64`, `test_image_d64`, `casm_overflow_test_d64`)
    build clean. MAIN headroom 261 of 13568 bytes
  - Walkthrough:
    `brain/walkthroughs/2026-07-24-casm-phase7-wp34-multi-file-cli-and-provenance.md`
  - **WP34 is complete.** WP35 (diagnostic filename integration) remains
    separately gated and unstarted.

- [x] Taskwarrior (`7fedccb3-8464-4b4d-a49e-2ac200e99dd4`): CASM Phase 7
      WP35 diagnostic filename integration
  - Plan:
    `brain/plans/2026-07-24-casm-phase7-wp35-diagnostic-filename-integration.md`
  - Active on `feature/casm-phase7-wp35` from `feature/casm-phase7-wp34`'s
    tip
  - Implemented Phase 0C.10 Contract item 5: `state.s`'s `CasmDiagState`
    block grew in place by 2 bytes (`CasmDiagLocFileId`/
    `CasmStmtLocFileId`, assert 530 -> 532) -- lower-risk than an
    external-block precedent like `CasmLabelName`'s, since every field
    here has exactly one clear write site, unlike `CasmParserStmt`'s
    wholesale writers; all three `diagSetLocFrom*` routines plus
    `diagStampStmtLoc` (`diagnostics.s`) now carry file identity;
    `diagPrintSourceContext` prints `IN FILE <name>` on its own line
    before `AT LINE...`, gated on `CasmSourceCount > 1`, reusing WP34's
    exported `cliSourceSlotLo/Hi` table for the lookup
  - Found WP32's original rationale for the gating decision ("the
    40-column diagnostic window is already full") described a different
    print statement than the one this WP actually touches -- the trailer
    already silently wraps past 40 columns in its own worst case today.
    The real, still-valid reason to gate on `CasmSourceCount > 1` is
    single-file text stability, not a column budget; corrected the stated
    rationale without changing the decision
  - `test_casm_pass1`/`test_casm_passcheck` needed zero source changes --
    confirmed by successful build/link: both already carried the exact
    stand-in symbols this WP's new imports needed, as a side effect of
    WP34's own harness fix
  - New fixture pair `casmmfdiag1`/`casmmfdiag2` (invalid byte in the
    first file) complements the existing `casmmfcr1`/`casmmfcr2`
    non-first-file case, proving file index 0 prints correctly too
  - User ran the full verification matrix (single-file diagnostic text
    regression, byte-identical trusted references, both new filename
    fixtures, both standalone harnesses) and confirmed: "all test pass"
  - Final CASM `0.1.37` build 1141, no-change rebuild stable, all three
    disk images build clean. MAIN headroom 189 of 13568 bytes (no bump
    needed)
  - Walkthrough:
    `brain/walkthroughs/2026-07-24-casm-phase7-wp35-diagnostic-filename-integration.md`
  - **WP35 is complete. All four Phase 7 Acceptance items are now
    checked.** WP36 (verification, walkthrough, and Phase 7 completion
    gate) remains separately gated and unstarted.

- [x] Taskwarrior (`c69b675f-def4-4fbb-a767-e32794e77af5`): CASM Phase 7
      WP36 verification, walkthrough, and completion gate
  - Plan:
    `brain/plans/2026-07-24-casm-phase7-wp36-verification-closeout.md`
  - Active on `feature/casm-phase7-wp36` from `feature/casm-phase7-wp35`'s
    tip
  - Bundled the full accumulated WP32-35 fixture/harness matrix; found and
    closed two real gaps before implementation: (1) no fixture had ever
    proven a large, under-cap input actually assembles successfully -- the
    master plan's own gate text ("large ... inputs assemble successfully")
    was only half-covered by the four checked Acceptance items, since every
    existing "large" fixture was either invalid syntax or deliberately over
    the cap; (2) WP31's 7-fixture Phase 3/4 diagnostic regression sample had
    never been re-run since Phase 7 replaced the entire source-loading
    layer those fixtures depend on
  - Closed gap 1 with a new fixture pair, `casmbiga.s`/`casmbigb.s` (3000
    `NOP` statements each) and trusted reference `casmbig1.ref.hex`
    (`00 C0` + `EA` x 6000) -- generated from one reviewed single-opcode
    repetition rule per the user's confirmed verification method, closing
    both the "large" and "multiple" halves of the gate text in one fixture.
    Closed gap 2 by re-running WP31's same 7 fixtures unmodified
  - Real implementation-time discrepancy found and fixed with user
    approval: `casmbiga.seq`/`casmbigb.seq`'s raw source text (12011/12000
    bytes) did not fit on `test.d64` (only 110 blocks free, 96 needed,
    leaving no room for the trailing `edlinfull` fixture). Fixed by moving
    both files plus `casmbig1`'s `COMP` verification (and `comp.prg` itself)
    onto the existing `casm_overflow_test_d64` disk image -- the same
    dedicated image `casmmfovf1`/`casmmfovf2` already used for identical
    "too large for test.d64" reasons
  - User ran the full consolidated matrix (5 standalone harnesses, 16
    byte-identical trusted references including the new `casmbig1`, 7
    diagnostic-fixture scenarios, the 7-fixture Phase 3/4 regression sample)
    and confirmed: "all tests pass." No production source defect found
  - Final CASM `0.1.38` build 1142, no-change rebuild stable, all three
    disk images (`image_d64`, `test_image_d64`, `casm_overflow_test_d64`)
    build clean. MAIN headroom 189 of 13568 bytes (unchanged)
  - Walkthrough:
    `brain/walkthroughs/2026-07-24-casm-phase7-wp36-verification-closeout.md`
  - **WP36 is complete. CASM Phase 7 milestone
    (`1a0d0dc8-3267-4885-aa83-adf923d56422`) is complete.** CASM Phase 8
    (native R6 relocation consumption) remains separately gated and
    unstarted; neither this closure nor any individual WP activates it.

- [/] Taskwarrior (`c50df549-a7ae-4859-bd16-45a843425ce6`): CASM Phase 8
      native R6 relocation
  - [x] `285322e5-ef7e-468e-bf53-b19b110dccb0` WP37 prerequisite
        reconciliation and Phase 0C.14 freeze
    - Plan:
      `brain/plans/2026-07-24-casm-phase8-wp37-prerequisite-reconciliation.md`
    - Active on `feature/casm-phase8-wp37` from `main` at `07b5062` --
      `feature/casm-phase7-wp36` was merged to `main` first, per the user's
      confirmed decision, since `main` had not been advanced past WP32 and
      this project's convention merges a phase's closeout WP to `main`
      before the next phase's first WP branches from it
    - Verified the CASM Phase 7 completion gate (`0.1.38` build 1142, 189
      bytes MAIN headroom)
    - Found the default is inverted today (`.ORG` required, not merely
      absent) -- there is no relocatable output path at all yet
    - Found most of the relocatable-value ABI (`CASM_EXPR_FLAG_RELOCATABLE`)
      already exists end to end from Phase 5/6B foresight with only a
      producer missing; the producer belongs in `expr.s` (gated on a
      whole-assembly relocatable-mode flag), not `symbols.s`, since no
      named-constant symbol kind exists before Phase 12 and every current
      symbol is a label
    - Found, by tracing every `VAL_HI`/extracted-`VAL_LO` write in
      `emit.s`, that four emission sites (not one) need the relocation
      hook: `emitInstruction`'s shared length-3 branch (covers absolute/
      absolute,X/absolute,Y/indirect uniformly), `emitWordList`, and two
      easy-to-miss cases -- `emitByteList`'s `.BYTE >label` (already parses
      successfully today as a silent non-relocatable constant) and
      `eiTwoByte`'s `CASM_MODE_IMMEDIATE` case (`LDA #>label`, which must
      be distinguished from the zero-page modes sharing its code path)
    - Found, mirroring WP32's precedent, that `symbol +/- constant`
      addends are always safely representable under the R6 common-page-
      delta model by associativity, so no new "unrepresentable expression"
      diagnostic is expected -- only a relocation-table-capacity one
    - User confirmed three architectural decisions: default relocatable
      origin `$3400`; `/S`-only scope this phase (deferring `.STATIC`/
      `.RELOC` source directives); 4096-entry/8192-byte relocation table
      capacity cap
    - Taskwarrior milestone (`c50df549`) and WP37-WP42 child tasks created,
      chained by dependency; Phase 0C.14 contract recorded in
      `brain/KNOWLEDGE.md`; `wiki/tasks/casm.md` updated with the Phase 8
      section
    - Version-only completion increment applied: final CASM `0.1.39` build
      1143, no-change rebuild stable, R6 footer of `casm.prg` itself
      unchanged in shape (base `$3400`, 1554 relocation entries), all three
      disk images build clean. **WP37 is complete**, approved by the user
  - [x] `e8d31694-0602-42bd-8234-416f3af5b31a` WP38 optional `.ORG`, default
        relocatable origin, and `/S` wiring
    - Plan:
      `brain/plans/2026-07-24-casm-phase8-wp38-default-origin-and-static-override.md`
    - Active on `feature/casm-phase8-wp38` from `feature/casm-phase8-wp37`'s
      tip
    - `.ORG` is now optional; absence defaults to relocatable mode at
      `CASM_DEFAULT_ORIGIN` ($3400); `/S` forces static mode and still
      requires an explicit `.ORG`
    - Found and closed two mechanism gaps during planning: `emitInit` never
      primed `CasmPc` (safe only while `.ORG` was mandatory-and-first), and
      `crpLabel` never guarded against a label preceding `.ORG` at all -- a
      latent gap since Phase 4 no fixture had ever exercised
    - Both closed by one unified mechanism: `CasmOrgSet` renamed
      `CasmOutputStarted` and broadened to "a label, a byte, or an explicit
      `.ORG` has already been processed this pass"; new exported
      `emitMarkStarted` (replacing `emitRequireOrg`) is the shared guard for
      `emitInstruction`/`emitByteList`/`emitWordList` (renamed call target
      only) and a new call added to `crpLabel`, run unconditionally before
      the pass-mode branch so both passes agree identically on a late
      `.ORG`
    - Late-`.ORG` case reuses `CASM_DIAG_DUPLICATE_ORG` per the user's
      confirmed decision -- no new diagnostic identifier
    - `test_casm_pass1`/`test_casm_passcheck` needed their own
      `CasmCliOptions` stand-in, found via a real link failure during
      implementation, not assumed
    - Reused the existing `casmorg1` fixture (Phase 4 WP13, no `.ORG`) as
      the primary positive case -- expected outcome flips from
      `CASM_DIAG_ORG_REQUIRED` to a successful relocatable assembly, the
      intended effect of this WP, not a regression. Added `casmorgexpl1`
      (byte-identical trusted reference to `casmorg1`, proving
      implicit-default/explicit-`.ORG $3400` equivalence), `casmnoorg1`
      (forward-referenced label under the implicit origin), and
      `casmorglate1` (label then `.ORG`, closing the latent gap)
    - User ran the full verification matrix (7 new-behavior checks, 3
      new-rejection checks, 5 regression spot-checks including both
      standalone harnesses) and confirmed: "All tests pass"
    - Final CASM `0.1.40` build 1145, no-change rebuild stable, all three
      disk images build clean. MAIN headroom 128 of 13568 bytes (down from
      189; this WP cost 61 bytes, no bump needed)
    - Walkthrough:
      `brain/walkthroughs/2026-07-24-casm-phase8-wp38-default-origin-and-static-override.md`
    - **WP38 is complete**, approved by the user
  - [x] `4a26fc20-3fcf-4d77-b41b-a46704af1491` WP39 relocation
        classification
    - Plan:
      `brain/plans/2026-07-24-casm-phase8-wp39-relocation-classification.md`
    - Active on `feature/casm-phase8-wp39` from `feature/casm-phase8-wp38`'s
      tip
    - `CASM_EXPR_FLAG_RELOCATABLE` is now a real, correctly-produced
      classification; a new `CASM_PARSER_STMT_RELOCATABLE` bit is derived
      from it at the same site `FORCE_ABS` already is. No relocation table
      or emission-site change -- WP40 consumes the classification
    - Found and closed a real ordering hazard: `parserParseStatement`
      evaluates an instruction's operand expression inline, before
      `casmRunPass` ever dispatches to `emitInstruction`, so a no-`.ORG`
      source whose first statement is a bare instruction with a symbol
      operand (`JMP TARGET`, no leading label) would classify that symbol
      before relocatable mode was locked in -- WP38's own `casmnoorg1`
      fixture didn't catch this since it starts with a label
    - Resolved by moving the commit trigger into
      `parserParseExpressionValue` itself, skipped for `.ORG`'s own
      operand (which can itself reference a symbol per WP28's design; an
      unconditional trigger would make `.ORG` spuriously reject itself as
      a duplicate)
    - Added `CasmRelocatableMode` (`emit.s`), since `CasmOutputStarted`
      alone cannot record *which* mode was chosen
    - User confirmed two module-boundary design decisions: `parser.s`
      calling `emit.s`'s `emitMarkStarted` directly, and extending
      `exprEvaluate`'s input ABI with a new relocatable-mode parameter
      rather than having `expr.s` import `emit.s` state directly (keeping
      `expr.s`/`test_casm_expr` decoupled from `emit.s`)
    - `test_casm_expr`'s `CASE` table grew a 9th per-case field; all 30
      pre-existing cases pass `relocMode = 0` unchanged; four new
      `relocMode = 1` cases added, including a new `<ABSVAL` script
      isolating the new input-driven path from extraction-clearing
    - New end-to-end fixture `casmordhaz1` proves the ordering-hazard fix,
      deliberately byte-identical to `casmnoorg1`'s output
    - User ran the full verification matrix (`TEST_CASM_EXPR`'s 34 cases,
      the ordering-hazard fixture, full regression sample) and confirmed:
      "All tests pass"
    - Final CASM `0.1.41` build 1147, no-change rebuild stable, all three
      disk images build clean. MAIN headroom 68 of 13568 bytes (down from
      128; this WP cost 60 bytes, no bump needed)
    - Walkthrough:
      `brain/walkthroughs/2026-07-24-casm-phase8-wp39-relocation-classification.md`
    - **WP39 is complete**, approved by the user
  - [x] `2175e962-2221-4308-8e3b-920065852d2d` WP40 relocation table
        storage and emission-site hooks
    - Plan:
      `brain/plans/2026-07-24-casm-phase8-wp40-relocation-table-and-emission-hooks.md`
    - Active on `feature/casm-phase8-wp40` from `feature/casm-phase8-wp39`'s
      tip
    - New module `reloc.s`: `relocInit` allocates the 8192-byte
      (4096-entry) table unconditionally every Pass 2 run (VMM cost only,
      not MAIN); `relocRecord` no-ops under `CASM_PASS_MODE_MEASURE` and
      otherwise appends `CasmPc - CASM_DEFAULT_ORIGIN` via one immediate
      `vmmWindowWrite` per entry, deliberately not batched through the
      shared `CasmVmmBuffer` (also used transiently by `symbolsLookup`
      between a statement's relocatable operands)
    - Re-tracing every byte-emission call site found a real correctness
      gap beyond WP37's original four-site enumeration: `emitInstruction`'s
      absolute-family branch and `emitWordList` both emit a
      `VAL_LO`/`VAL_HI` pair, and `<`/`>` extraction is reachable at both
      (`LDA >LABEL`, `.WORD >LABEL`), so a naive "record `VAL_HI` when
      relocatable" check would wrongly mark a genuine constant `$00`
      padding byte as needing a page-delta patch
    - Resolved with two new `emit.s` helpers (`emitMaybeRecordHi`/`Lo`)
      using `VAL_HI`'s own zero/nonzero state to disambiguate, no new ABI
      field needed; wired at six call sites, with `eiTwoByte` additionally
      gated on `CasmInsn.Mode == CASM_MODE_IMMEDIATE` (re-verified that
      this guard is still needed, since `ofRequire8Bit` is shared with
      indexed-indirect/indirect-indexed addressing)
    - New diagnostic `CASM_DIAG_RELOC_TABLE_FULL` at `$30`; new standalone
      `test_casm_reloc` harness (the only real proof of `relocRecord`'s
      correctness until WP41's footer exists); two new end-to-end fixtures
      (`casmrelop1`, `casmrelop2`) proving the new hooks don't corrupt
      program bytes
    - User ran the full verification matrix (`TEST_CASM_RELOC`'s 4 cases,
      both new fixtures, full regression sample) and confirmed: "all tests
      pass"
    - Final CASM `0.1.42` build 1154, no-change rebuild stable, all three
      disk images build clean. MAIN size bumped `$3500` -> `$3600` (144
      bytes overflow; 106 bytes headroom at the new size)
    - Walkthrough:
      `brain/walkthroughs/2026-07-24-casm-phase8-wp40-relocation-table-and-emission-hooks.md`
    - Separately from this WP's own scope, `casmempty.s` was removed from
      `test.d64`'s build during this session (`cc1541 -L`'s zero
      track/sector directory entry suspected of corrupting the disk),
      committed independently (`cad491a`) before this WP's own commit
    - **WP40 is complete**, approved by the user
  - [x] `005c8fec-684d-4f0d-a171-c7519081bef2` WP41 native R6 footer
        serialization
    - Plan:
      `brain/plans/2026-07-25-casm-phase8-wp41-r6-footer-serialization.md`
    - Active on `feature/casm-phase8-wp41` from `feature/casm-phase8-wp40`'s
      tip
    - `reloc.s` gains `relocFinalize`, called unconditionally from `casm.s`
      right after `emitFinalize` succeeds; no-ops for a static assembly,
      otherwise appends the accumulated table (chunked through the
      existing `CasmVmmBuffer` window) and the 6-byte R6 footer (base
      address, entry count, `"R6"` magic as explicit hex) in one final
      write, matching `tools/reloc.py`'s exact byte layout -- the first WP
      to make the relocation table observable end to end
    - Found that five existing trusted references (`casmorg1`,
      `casmnoorg1`, `casmordhaz1`, `casmrelop1`, `casmrelop2`) go stale the
      instant this WP lands (each gains a real footer it didn't have
      before); updated all five with hand-derived footers, verified
      byte-for-byte and hash-for-hash before any runtime test.
      `casmorgexpl1.ref.hex`'s stale "byte-identical to casmorg1" comment
      corrected -- the divergence is the intended outcome of R6 existing,
      not a regression
    - MAIN size bumped `$3600` -> `$3700` (103 bytes overflow; 153 bytes
      headroom at the new size)
    - First verification pass: user reported `TEST_CASM_PASS1` failing all
      7 fixtures ("fffffff"). Root-caused to `test_casm_reloc.s` (WP40)
      never calling `resourcesCleanup` before `DOS_EXIT`, permanently
      leaking two VMM/REU allocations and starving the next test's own
      allocation in the same VICE session. Fixed
    - Audited every other standalone harness for the same defect class;
      found `test_casm_symbols.s` (WP27, outside this WP's original scope)
      with the identical gap (`symbolsInit`'s VMM allocation never freed);
      fixed identically with the user's approval
    - Second verification pass: user confirmed "all tests pass" across the
      full matrix (`TEST_CASM_RELOC`, `TEST_CASM_SYMBOLS`,
      `TEST_CASM_PASS1`, `TEST_CASM_PASSCHECK`, all five updated
      relocatable fixtures via `COMP`, static regression sample)
    - Final CASM `0.1.43` build 1156, no-change rebuild stable, all three
      disk images build clean
    - Walkthrough:
      `brain/walkthroughs/2026-07-25-casm-phase8-wp41-r6-footer-serialization.md`
    - **WP41 is complete**, approved by the user
  - [x] `186aadb1-462d-48d1-87bb-e1c9af6c75e1` WP42 verification,
        walkthrough, and Phase 8 completion gate
    - Plan:
      `brain/plans/2026-07-25-casm-phase8-wp42-verification-and-completion-gate.md`
    - Active on `feature/casm-phase8-wp42` from `feature/casm-phase8-wp41`'s
      tip
    - Found the one real gap every prior Phase 8 WP had deferred here: no
      relocatable fixture had ever been loaded away from its assembled
      address and actually run -- every one was checked exclusively via
      `COMP` against a byte reference, never proving the OS's existing
      `aptRelocate` loader correctly consumes CASM's native R6 output
    - Closed it with a new fixture, `casmreloc1`, whose one relocatable
      byte reuses the already-proven immediate high-byte-extraction shape
      (`LDY #>label`, established correct by `casmrelop2` in WP40) -- tests
      `aptRelocate`'s consumption, not a new CASM classification case
    - Also re-ran WP31's 7-fixture Phase 3/4 diagnostic regression sample,
      unrun since WP36 despite WP39 materially changing the expression-
      evaluation core those fixtures depend on; all 7 reproduced correctly
    - User ran the full consolidated matrix (6 standalone harnesses, 22
      byte-identical references including `casmreloc1`, 8 diagnostic
      scenarios, the 7-fixture regression sample, static-fixture
      regression, and `casmreloc1` loaded and run at `$3400`/`$4000`/`$5000`)
      and confirmed: "All tests pass"
    - One non-reproducible anomaly noted: a single report of
      `TEST_CASM_PASS1` failing with the same VMM/REU-exhaustion signature
      WP41 diagnosed twice, despite a fresh VICE reset and no further leak
      found on re-inspection of `casm_pass1.s`/`casm_passcheck.s`. Did not
      reproduce on a full from-scratch re-run; recorded as an open,
      unresolved, non-blocking observation, not a confirmed defect
    - Checked all six Phase 8 Acceptance items
    - Final CASM `0.1.44` build 1157, no-change rebuild stable, all three
      disk images build clean
    - Walkthrough:
      `brain/walkthroughs/2026-07-25-casm-phase8-wp42-verification-and-completion-gate.md`
    - **WP42 is complete, and with it the CASM Phase 8 milestone closes**,
      approved by the user

- [/] `687ada7e-4175-41b4-93f3-9e8df85c1a5c` CASM Phase 9: include processing
  - Parent plan:
    `brain/plans/2026-07-25-casm-phase9-include-processing.md`
  - [x] `2826144e-b7c6-4372-8e1d-74cfff242d1a` WP43 prerequisite
        reconciliation and Phase 0C.19 freeze
    - Dedicated plan:
      `brain/plans/2026-07-25-casm-phase9-wp43-prerequisite-reconciliation.md`
    - User approved completion; final CASM `0.1.45` build 1160, no-change build
      stable, all three disk images pass
    - Branch `feature/casm-phase9-wp43`, child of Stage 9 parent branch
      `feature/casm-stage9` at baseline `b279365`
    - WP44 remains pending separate detailed-plan approval and activation
  - [x] `2682d04b-05b0-4828-b88f-852234e3d006` WP44 quoted include operand
    grammar
    - Detailed plan approved and active:
      `brain/plans/2026-07-25-casm-phase9-wp44-quoted-include-operand-grammar.md`
    - User-approved complete at CASM `0.1.46` build 1166
    - Corrected 14-case runtime, stable no-change build, whole-object harnesses,
      and all three disk images pass; WP45 remains pending
  - [x] `199b4da7-987a-44cf-a84d-b4e0b786f5d0` WP45 physical file catalog and
        dynamic source loading
    - Detailed plan approved and active:
      `brain/plans/2026-07-25-casm-phase9-wp45-physical-file-catalog-and-dynamic-source-loading.md`
    - Standalone `include.s` module plus a dedicated `test_casm_catalog`
      harness only, per user-confirmed scope; no `casmRunPass` call site yet
    - Implementation complete: new `include.s` (8KB metadata VMM store,
      `DOS_PARSE_PREFIX`-based device resolution, case-folded catalog
      identity, deduplicated catalog load) and `source.s`'s
      `sourceAppendFile` (shared stream cursor distinct from the live
      traversal read cursor); one new diagnostic `$34`
      `CASM_DIAG_INCLUDE_CATALOG_FULL` (two originally-planned ones found
      unreachable and dropped, mirroring WP23's own precedent)
    - Linking `include.s` overflowed production `casm`'s `$3A00` MAIN
      envelope by 694 measured bytes; user approved growing it to `$3E00`
      (+1024 bytes, 309 bytes headroom). Final build 1170 passes, no-change
      stable
    - New 12-case `test_casm_catalog` harness (build 1009) packaged on
      `casm_overflow_test_d64` (`test_casm_catalo`, 16-char disk name) with
      5 new tiny fixtures (`casmcat1`-`casmcat5`)
    - `test_casm_pass1`/`test_casm_passcheck` (both link `source.s` whole)
      continue to fit their existing `$3A00` envelope unchanged; all other
      standalone harnesses and all three disk images build clean
    - User runtime testing found and fixed two real defects before the
      final pass: (1) the harness itself hardcoded device 8, but the
      user's two-drive VICE setup runs the fixture disk from device 9 --
      fixed by capturing the real `CurrentDevice` at startup instead of
      assuming a fixed device; (2) a genuine `sourceAppendFile` bug
      (`source.s`) stashed the file's start offset in the shared
      `CasmValue0Lo/Hi` scratch pair, which `vwPrepareTransfer`
      (`vmm_store.s`) clobbers on every chunk write -- fixed with a new,
      never-shared `CasmSourceAppendStartLo/Hi` field. Same aliasing bug
      class as WP23-25/WP44's own precedent
    - User confirmed all 12 cases pass: `CASM CATALOG: PASS`
    - Walkthrough:
      `brain/walkthroughs/2026-07-25-casm-phase9-wp45-physical-file-catalog-and-dynamic-source-loading.md`
    - User approved completion; final CASM `0.1.47` build 1171, no-change
      rebuild stable, all three disk images pass. **WP45 complete.**
  - [x] `005a1819-eda6-4fa5-89e1-5848a5076a7d` WP46 frame stack, nested
        traversal, and cycle detection
    - Detailed plan approved and active:
      `brain/plans/2026-07-26-casm-phase9-wp46-frame-stack-nested-traversal-and-cycle-detection.md`
    - Standalone `source.s` frame stack plus a dedicated `tests/src/casm_frame`
      harness only, per user-confirmed scope; no `casmRunPass` call site yet
    - Also fixes a pre-existing WP34 diagnostic-echo file-identity gap
      (`diagResolveView` matched cached lines by number only)
    - Implementation complete: 16-slot frame stack (`sourceFramePush`,
      depth/cycle checks before any mutation), fully automatic pop via a
      rewired `sourceRefill` (`srEofOrPop`/`sourceFramePopInternal`,
      private), and `sourceResetBoundaryEcho` shared by both the extended
      `srCheckFileBoundary` and the new push/pop paths. Two new
      diagnostics `$35-$36` (depth exceeded, cycle detected)
    - Linking the new frame stack overflowed production `casm`'s `$3E00`
      MAIN envelope by 221 measured bytes; user chose the tighter "exactly
      what's needed" amendment to `$4000` (292 bytes headroom). Build 1173
      passes, no-change stable
    - New 8-case `tests/src/casm_frame` harness (build 1001) packaged on
      `casm_overflow_test_d64` with 10 new real-CASM-syntax fixtures
      (`casmfrp1`-`4`, `casmfrc1`-`3`, `casmfrcr1`, `casmfrr1`-`2`)
    - `test_casm_pass1`/`test_casm_passcheck`/`test_casm_catalog` (all link
      `source.s` whole) needed matching envelope bumps; all other
      standalone harnesses and all three disk images build clean
    - Walkthrough:
      `brain/walkthroughs/2026-07-26-casm-phase9-wp46-frame-stack-nested-traversal-and-cycle-detection.md`
    - User runtime testing found four real production defects, each masking
      the next: (1) `lexerFill` captured token provenance *before*
      `sourceNextByte`, going stale exactly when that call resolved a
      child's EOF and popped -- fixed with new `CasmSourceResult*` fields
      captured inside `sourceFetchPhysical` (`state.s`/`source.s`/
      `lexer.s`, plus the matching contract in `casm_include.s`'s stand-in
      `sourceNextByte`); (2) that capture clobbered `A` at `sfpEof`,
      destroying the `CASM_SOURCE_EOF` return; (3) depth-0 traversal had no
      end cap of its own and overran into `.INCLUDE` children appended
      mid-traversal (`CasmSourceLoadedLen` grows) -- fixed with a fixed
      `CasmSourceTopLevelEndLo/Hi` snapshot taken at `sourceLoad`'s
      completion; (4) `sourceFramePush` saved `CasmSourceVmmCursor` (the
      bulk-refill read head, already at the file's end for any
      sub-256-byte fixture) rather than the logical parse position --
      fixed to `cursor - (blockLen - blockIndex)`
    - Fix 4 exposed that `frSinglePushPop` had been *passing for the wrong
      reason*: the pop re-read the child's bytes while the parent's line
      counter read 4, so re-read `C1`/`C2` were stamped lines 4/5,
      coincidentally matching the expected `P3=4, P4=5`. Two independent
      bugs were cancelling into a green test
    - Incidental: CODE growth pushed `CasmExprResolverAddrLo` onto a
      `$xxFF` low byte, tripping `expr.s`'s NMOS 6502 JMP-indirect
      page-wrap `.assert`; fixed with one pad byte in `expr.s` itself
    - All 8 cases confirmed passing by the user on the clean,
      instrumentation-removed binary (`test_casm_frame` build 1023), which
      fits the original `$4000` envelope -- the temporary `$4200` bump was
      reverted, so no envelope amendment ships
    - User approved completion. Final CASM `0.1.48` build 1191; no-change
      rebuild stable; full suite and all three disk images pass;
      `git diff --check` clean. **WP46 complete.** WP47 is unblocked in
      Taskwarrior by dependency but not activated -- it remains pending
      separate plan approval
  - [ ] `579096d9-ce77-44db-96a9-c32654238949` WP47 ordered include graph and
        Pass 2 replay
  - [ ] `797bb460-6d82-453c-8f55-7aa53d2eb095` WP48 included-source diagnostics
        and tracebacks
  - [ ] `a8c3dbf0-9333-4489-9c3b-3e752049b693` WP49 verification, walkthrough,
        and Phase 9 completion gate

- [/] Taskwarrior #24 (`a45d0395`): Implement external `COMP` utility
  - [x] Create active Taskwarrior task
  - [x] Write detailed implementation plan for approval
  - [x] Review external app, `MORE`, and `DEBUG` reuse candidates
  - [x] Implement after explicit approval
  - [x] Build `image_d64` and `test_image_d64`
  - [ ] Manually verify

- [ ] Taskwarrior #25 (`57d2cf4e`): Future external app return-code support
  - [x] Confirm current `DOS_EXIT` has no meaningful app return-code channel
  - [ ] Design ERRORLEVEL-style status support outside `COMP` scope

- [x] Task #25: Fix EDLIN physical hardware save truncation
  - [x] Preserve final EOI byte in `DOS_READ_FILE`
  - [x] Check KERNAL write status after `CHROUT`
  - [x] Read EDLIN target drive post-close status after `W`
  - [x] Verify with `make all`
  - [x] Manual physical-hardware verification

- [x] Workspace initialization & state management setup
- [x] Project infrastructure setup: Taskwarrior & Codebase Memory initialized, Code Wiki created (2026-06-25)

- [x] Phase 2A: Core Dispatcher Proof-of-Concept (`CLS`, `ECHO`, `EXIT`, Command Loop)
  - [x] Kick Assembler toolchain setup and verification
  - [x] PETSCII API layer (`src/command64/petsci.asm`)
  - [x] Command loop, dispatcher, built-in handlers (`src/command64/shell.asm`)
  - [x] Build entry point and segment layout (`build/command64.asm`)
  - [x] Constants and KERNAL equates (`include/command64.inc`)
  - [x] `build/command64.prg` assembles — 0 errors, 0 warnings

- [x] Phase 2A Code Review & Remediation (2026-05-02)
  - [x] Static review: 14 findings (11 Critical, 3 Major) — `brain/reviews/2026-05-02_phase2a-command64.md`
  - [x] All findings remediated — `brain/plans/2026-05-02_phase2a-command64-code-review-remediation.md`
  - [x] Real-hardware test: `CLS` works, `ECHO` crashes fixed, `EXIT` hang fixed
  - [x] CommandBuffer relocated from $0300 (KERNAL vectors!) to $1400
  - [x] cmdCompare X-register dispatch bug fixed (all 3 commands verified)
  - [x] EXIT: `jmp ($0338)` → `jmp $E37B` (BASIC warm start ROM)

- [x] Phase 2A Follow-on
  - [x] Raw GETIN input loop — fixes `"` quote-mode control code injection
  - [x] Fix Y-register clobbering in PETSCII/Shell routines
  - [x] Fix PETSCII string encoding bug (block graphics in badCmdMsg)
  - [x] Improve parser robustness (ignore empty lines, trim spaces)
  - [x] VMM API specification (`include/vmm.inc`)

- [x] Phase 2B: External command support / PATH search
  - [x] Define loader memory map ($2000+)
  - [x] Implement directory search (`path.asm`) with auto-.prg extension
  - [x] Implement binary loader (`loader.asm`) with custom address support
  - [x] Integrate with `shellDispatch` (auto-run if no internal match)
  - [x] Case-insensitive matching (`normalizeName`)
  - [x] Create test environment (`tests/testcmds.d64`)

- [x] Phase 2B Verification
  - [x] Verify `HELLO` from shell (string output)
  - [x] Verify `COLOR` from shell (visual check)
  - [x] Verify `EXTCLS` from shell (functionality check)
  - [x] Verify case-insensitivity (e.g., `hello` vs `HELLO`)
  - [x] Verify custom load address (e.g., `load hello 3000`)

- [x] Phase 2C: Virtual Memory Manager (VMM)
  - [x] Define VMM ABI and REU hardware registers
  - [x] Relocate MCT to safe RAM ($C000) for 16MB support
  - [x] Remap ZP pointers to safe/FAC1 workspace to prevent BASIC corruption
  - [x] Implement `vmmInit` (MCT clearing and REU detection)
  - [x] Implement `vmmAlloc` / `vmmFree` with 4KB Page Byte-Map strategy
  - [x] Implement `vmmReadByte` / `vmmWriteByte` (REU DMA primitives)
  - [x] Stabilize shell: move `CommandBuffer` to Cassette Buffer ($033C)
  - [x] Add version tracking (0.2.3 Build 2301) and startup banner
  - [x] Implement `HELP` internal command
  - [x] Implement `DIR` internal command (non-destructive)

- [x] Phase 2C Code Review Round 1 — Service Bus & VMM Backtracking (2026-05-11)
  - [x] Review conducted (5-agent parallel review) — `brain/reviews/2026-05-11_command64-phase2c-api-vmm.md`
  - [x] Remediation plan written — `brain/plans/2026-05-11-api-vmm-bug-remediation.md`
  - [x] A — Fixed `ahSetCarry`/`ahClearCarry`: `$0104,x` → `$0106,x` + updated comment
  - [x] B — Fixed `vaSearchReset`/`vaCommitAlloc`: reconstruct MCT ptr as `#>VmmMctBase + VmmOffHi`
  - [x] E — Fixed `ahFreeMem` branch: added `lda $0103,x` after `sta` to set Z from status
  - [x] F — Fixed `build_tests.sh` shebang, paths, and OUTDIR (covered in Round 3 + OUTDIR absolute path)
  - [x] J — Fixed `vmmtest.asm`: save X/Y to $64/$65 after alloc, restore before free

- [x] Phase 2C Code Review Round 2 — Residual Bugs (2026-05-11)
  - [x] Bug verification conducted — `brain/reviews/2026-05-11_command64-bug-verification.md`
  - [x] Remediation plan written — `brain/plans/2026-05-11_command64-remediation-round2.md`
  - [x] Implement C4: Correct `SpecificLoad` comments
  - [x] Implement C8: Clear `TempHi` in `printDecimal16`
  - [x] Implement I2: Add VMM initialization safety check

- [x] Phase 2C Code Review Round 3 — Safety Hardening (2026-05-11)
  - [x] Review conducted — `brain/reviews/2026-05-11_command64-round3-gemini-review.md`
  - [x] Remediation plan written — `brain/plans/2026-05-11_command64-remediation-round3.md`
  - [x] Task 1: Secure `vmmFree`
  - [x] Task 2: Secure `vmmReadByte`

- [x] Phase 3: File System Integration (Handle-based I/O)
  - [x] Architecture design and planning — `brain/plans/phase3-filesystem.md`
  - [x] Define FCB structure and Handle Table layout
  - [x] Extend DOS API with file primitives ($3D, $3E, $3F, $40)
  - [x] Implement `TYPE` internal command
  - [x] Implement `COPY` internal command
  - [x] Create file integration test program — `tests/src/filetest.asm`

- [x] Phase 3 Remediation & Shell Polish (2026-05-12)
  - [x] Resolve Load Error / Register Mismatches — `brain/plans/filesystem-remediation.md`
  - [x] Fix DIR block reporting (16-bit) — `brain/walkthroughs/dir-report-fix.md`
  - [x] Implement `DEL` / `ERASE` commands — `brain/plans/filesystem-extended-cmds.md`
  - [x] Implement `REN` / `RENAME` commands
  - [x] Add destructive backspace (INST/DEL) handling in shell input loop

- [x] Phase 4: External System Utilities
  - [x] Develop `DEBUG` utility (Dump, Enter, Fill, Move, Compare, Search, Hex Math, Regs, Go, Quit)
  - [x] Refine `DEBUG` UI for 40-column display (8-byte rows, midpoint separator)
  - [x] Remediate `DEBUG` bugs (case sensitivity, register safety, inclusive ranges) — `brain/plans/debug-utility.md`
  - [x] Verify `DEBUG` via formal test plan — `brain/walkthroughs/debug-test-plan.md`
  - [x] Implement `RUN` / `G` internal commands for program execution at [address]
  - [x] Remediate `DEBUG` range and dump bugs (uppercase L parsing, dump range support) — `brain/plans/debug-range-remediation.md`
  - [x] Refactor range checks to eliminate redundancy in `debug.asm` — `brain/plans/debug-refactor-ranges.md`
  - [x] Fix hex letter parsing in `parseHexArg` (`debug.asm`) — `brain/plans/debug-hex-parsing-fix.md`
  - [x] Fix Y-register clobbering in `prLength` (`debug.asm`) — `brain/plans/debug-prlength-y-preservation.md`
  - [x] Add build tracking to `LABEL` external utility — `brain/plans/label-build-tracking.md`
  - [x] Remediate Phase 1 Peer Review findings (interactive registers, load tracking, global range check) and complete Phase 1 I/O (N/L/W) type prefixes and SEQ/USR custom loaders — `brain/reviews/2026-06-28_debug-phase1-peer-review.md`
  - [x] Implement Phase 3 software breakpoint debugger (T/P commands, instruction decoder, CBINV intercept, and stack launch) — `brain/walkthroughs/2026-06-30-debug-phase3-breakpoint-debugger.md`

- [ ] Phase 5: Environment & Multi-Device Support
  - [x] Implement `DRIVE` command (with `DEVICE`/`DEV` aliases)
  - [x] Add support for multiple devices (8, 9, 10, 11)
  - [x] CLI: Generalize device targeting syntax for commands like DIR, TYPE, VOL, LABEL (Task #24)
  - [x] Refactor device routing into filesystem and API layer
  - [ ] Support subdirectories (1581 / SD2IEC)
  - [x] Environment variable storage (`SET`, `PATH`) in REU
  - [x] Remediate environment hang and PATH bugs (2026-05-14) — `brain/plans/2026-05-14-env-var-remediation.md`

- [ ] Phase 6: Advanced OS Features
  - [x] Phase 6A: App Manager Phase A (Program registry APPS/PS/FREE) (Completed 2026-07-04)
  - [x] Implement Binary Relocator (to support `RUN` at arbitrary addresses) (Completed 2026-07-05)
  - [x] Conway & conwayca memory Safety & Relocation Crash Remediation (Completed 2026-07-08)
  - [/] Taskwarrior #26 (`f4eba87e`): Conway Multiverse Generalization, Menu and Counter
    - [x] Gather transcript research and document Conway Multiverse rules
    - [x] Update high-level plan for production ca65/ld65 tools
    - [x] Write detailed implementation plan
    - [x] Obtain phased implementation approval
    - [x] Phase 1: extend contracts and verify build/memory headroom
    - [x] Implement Main Menu screen with preset selections
    - [x] Implement Custom Rule editing mode (one Birth/Survival toggle per
      edit command)
    - [x] Phase 3: 16-bit generation counter implemented and manually verified
    - [x] Phase 2: compact presets and RAM-table solver implemented and
      manually verified
    - [x] Phase 4: compact menu renderer implemented and approved
    - [x] Phase 5: menu/simulation state machine, cyan/green pause indicator,
      and stack-safe exits implemented and functionally confirmed by the user
    - [/] Phase 6: update documentation, project records, and walkthrough
    - [x] Increment Conway to `0.4.1.1057` and synchronize current-version
      documentation
    - [x] Display the full `0.4.1.1058` patch/build version at the bottom-right
      of the main menu without overlapping dynamic prompts; visually confirmed
      by the user
    - [ ] Phase 7.1: replace one-digit B/S editing with persistent full-set
      entry, clearing the selected set and finishing on RETURN
    - [ ] Phase 7.2: update documentation, verification evidence, walkthrough,
      and task records for the full-set editor
    - [ ] Build and inspect size/alignment/relocation artifacts
    - [ ] Complete user-run C64/VICE verification
  - [ ] Add Oscar64 C-Language runtime support
  - [ ] Phase 6D: Cooperative VMM Swapping & Memory Safety


- [ ] Time, Date & Disk Label Support
  - [x] VOL / LABEL Command Implementation (Task #17)
    - [x] Implement `cmdVol` routine in `shell.asm` to read and print the disk header name/ID
    - [x] Implement `cmdLabel` routine in `shell.asm` to write a new name to the disk header using the floppy disk command channel
    - [x] Register `VOL` and `LABEL` in the command table and the `HELP` output
    - [x] Verify functionality on standard D64 disk images
    - [x] LABEL: Fix interaction inconsistencies (Task #21)
    - [x] LABEL: Implement syntax updates for quotes and spaces (Task #22)
    - [x] LABEL: Support target device parameter like 9:NEWLABEL (Task #23)
  - [x] TIME Command Implementation (Taskwarrior #15)
    - [x] Implement TOD clock initialization routine at system boot
    - [x] Implement `cmdTime` handler in `shell.asm` to format and print time
    - [x] Implement CIA 1 TOD register write routines to allow user clock adjustments
    - [x] Register `TIME` in the command table and the `HELP` output
    - [x] Verify direct and interactive setting/display round-trips
    - [x] Verify midnight rollover advances the software date
  - [x] DATE Command Implementation (Taskwarrior #16)
    - [x] Define system date storage structures in resident kernel RAM
    - [x] Implement `cmdDate` handler in `shell.asm` to print and parse date inputs
    - [x] Register `DATE` in the command table and the `HELP` output
    - [x] Verify direct and interactive setting/display round-trips
    - [x] Verify leap-year validation
    - [x] Verify midnight and month rollover

- [x] MORE Command Implementation (Taskwarrior #24)
  - [x] Add `MORE` to the internal command table and help text
  - [x] Stream file contents through existing DOS open/read/close API calls
  - [x] Add C64 screen pagination with `-- More --` prompt
  - [x] Document `MORE` and target-device prefix support
  - [x] Verify clean build with `make all`
  - [x] Complete manual C64/VICE workflow verification

- [ ] Pac-Man ca65 Rewrite
  - [x] Phase 1: Core Setup & Build Pipeline
    - [x] Create `BUILD_PACMAN` file
    - [x] Create `src/external/pacman/common.inc` with zero-page definitions and constants
    - [x] Create skeleton `src/external/pacman/pacman_main.s`
    - [x] Delete old Kick Assembler `pacman.asm`
    - [x] Update `CMakeLists.txt` with ca65 build rules for `pacman`
    - [x] Compile skeleton successfully

  - [x] Phase 2: Maze Layout, Draw Engine, and Pac-Man Movement
    - [x] Define 28x24 maze Walls and Items arrays in `pacman_game.s`
    - [x] Implement fast screen/color block rendering in `pacman_game.s`
    - [x] Implement keyboard poll and direction buffering in `pacman_main.s`
    - [x] Implement Pac-Man move timers, level speed scaling, and dot/pellet eating slowdown

  - [x] Phase 3.1: Blinky AI Integration and Code Review Remediation
    - [x] Review Phase 2 regressions and the active Blinky integration
    - [x] Synchronize `wiki/tasks/pacman-ca65-rewrite.md` and Taskwarrior
    - [x] Correct actor redraw ordering and manually verify actor visibility
    - [x] Repair and harden `autotile.py`
    - [x] Integrate `autotile.py` into the Pac-Man CMake target
    - [x] Synchronize Pac-Man documentation with current behavior
    - [x] Implement and manually verify Pac-Man/Blinky collision and life-loss handling
    - [x] Classify Blinky corner loops and verify the invisible-target symptom
      is resolved by collision handling
    - [x] Complete build verification and user-run C64/VICE walkthrough
    - [ ] Deferred: restore the exact 240-dot maze after visual revisions
    - [ ] Deferred: implement ghost warp-tunnel behavior
