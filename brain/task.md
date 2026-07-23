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
  - WP31 (`86d8ac7e`) is unblocked in Taskwarrior but not yet planned in
    detail, per the CASM AGENTS.md per-work-package-plan-approval
    requirement
  - **CASM Phase 6B WP31 (verification, walkthrough, and completion gate)
    is now the active CASM thread, gated on its own dedicated plan.**

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
