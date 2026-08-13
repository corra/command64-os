# Project Tasks

- [x] Taskwarrior (`2386a65f-c972-4f69-8c83-0b4032a8fd97`): DEBUG REU/address
      syntax WP6 chunked `XM` transfers
  - Plan: `brain/plans/2026-08-06-debug-reu-address-syntax-wp6.md`
  - Branch: `feature/debug-reu-address-wp6` (based on `debug` after WP5
    merge, commit `28ae49f`)
  - Plan approved 2026-08-06; user confirmed the walkthrough 2026-08-04;
    complete
  - Precise envelope headroom confirmed: 159 bytes free before this WP
    (debug.s has no separate BSS segment, so `reloc.py`'s 8,033 code-byte
    figure for build 1124 already is the true `MAIN` footprint). Plan
    expands `MAIN` from `$2000` to `$2400` (`CMakeLists.txt:185`) as a
    prerequisite, keeping DEBUG's occupied range at `$3800-$5C00` with a
    1024-byte margin below the `$6000` test-fixture convention.
  - [x] Increment 0: envelope expansion (`$2000`->`$2400`); build stayed
        8,033 code bytes, confirming the expansion alone is inert
  - [x] Increment 1: `stageReuTransfer`/`advanceReuTransfer` added (build
        1125: 8,187 code bytes, 999 relocation points)
  - [x] Increment 2: transfer loop and real DMA wired into `cmdReuMove`
        (build 1126: 8,288 code bytes, 1,024 relocation points; 928 bytes
        headroom remaining in the 9,216-byte `MAIN` envelope)
  - [x] Increment 3: partial-failure path (static review only — no safe
        live fault-injection trigger identified; agreed with user)
  - [x] Increment 4: VICE-verified round-trip (single-chunk and 768-byte
        3-chunk), 4KB page-boundary crossing, flat/page-relative operand
        equivalence, exact-end-of-64KB-allocation transfer, and rejection
        (no DMA) of over-capacity/invalid-handle/invalid-direction/
        malformed-page-offset commands; `image_d64`/`test_image_d64` build
        clean; CHANGELOG, `wiki`/`docs/debug-utility.md`,
        `wiki`/`docs/debug-test-plan.md`, and
        `src/external/debug/AGENTS.md` updated. User confirmed the
        walkthrough 2026-08-04; merged onto `debug` at `ebe2b05`.

- [x] Taskwarrior (`683f2802-9cba-409f-b5bc-881e349e15b2`): DEBUG REU/address
      syntax WP7 integrated regression and documentation (final WP)
  - Plan: `brain/plans/2026-08-04-debug-reu-address-syntax-wp7.md`
  - Branch: `feature/debug-reu-address-wp7` (based on `debug` after WP6
    merge, commit `ebe2b05`)
  - Plan approved 2026-08-04 (test-suite formalization, version bump, REU
    toggle method, and "fix minor safe issues inline, report larger ones"
    all confirmed)
  - Formalizes `=`-syntax and REU regression as permanent Test Suites 14-15
    in `wiki/debug-test-plan.md`; runs the full regression under VICE with
    REU enabled and disabled; bumps DEBUG `0.4.0` -> `0.5.0`; DOX closeout;
    final documentation sweep; closes the parent plan on user confirmation
  - [x] Increment 0: authored Test Suites 14-15 in
        `wiki`/`docs/debug-test-plan.md`
  - [x] Increment 1: version bump (`0.4.0` -> `0.5.0`); build 1127, 8,288
        code bytes (unchanged); updated the four illustrative
        `DEBUG v0.4.0.1101` doc strings and `wiki/debug-utility.md`'s stale
        header/REU-summary text found during the sweep
  - [x] Increment 2: REU-enabled full regression (Suites 1-15) under VICE —
        no failures; confirmed `REU=1` via `vice_get_setting` before
        starting, not assumed
  - [x] Increment 3: REU-disabled regression (Suites 1-13 + Test 15.5) under
        VICE — no failures; REU toggled off/on via `vice_set_setting`
  - [x] Increment 4: DOX closeout — no drift found beyond WP6's own update
  - [x] Increment 5: final documentation sweep (`user-manual.md`,
        `programmers-reference.md` — no stale claims found) and `release/`
        regenerated
  - [x] Real product gap found during the walkthrough (user-prompted): the
        in-app `?` help text (`debugHelpMsg`) had never been updated across
        WP1-WP6 despite `debug.s`'s own maintenance rule — missing the
        entire `X` family and the `=` prefix note on `G`/`T`/`P`. Fixed
        inline (format-matching addition, no behavior change); build 1128,
        8,411 code bytes (+123); VICE-confirmed `?` output correct.
  - [x] Increment 6: combined walkthrough presented and confirmed by the
        user 2026-08-04, after the help-text fix; merged onto `debug`

- [x] Taskwarrior (`a4809e03-ee37-4973-8fc6-2896bf2ea69c`): DEBUG REU/address
      syntax WP5 unified `XM` parsing and preflight
  - Plan: `brain/plans/2026-08-06-debug-reu-address-syntax-wp5.md`
  - Branch: `feature/debug-reu-address-wp5` (based on `debug` after WP4
    merge, commit `b81afcf`)
  - Plan approved 2026-08-06
  - [x] Increment 1-3 implemented together: DEBUG build 1124 (8,033 code
        bytes, 959 relocation points, still within the 8KB `MAIN`
        envelope but with little headroom left); VICE-verified all four
        flat/`page:offset` equivalence pairs against a 64KB allocation
        produce identical `XM PREFLIGHT OK` results; all five malformed
        `page:offset` forms (`0001:1000`, `0010:0000`, `0001:`, plus the
        parser's own zero-digit/5-digit rejections) reject correctly;
        allocation-window boundary matrix against a 4KB allocation
        (exact-fill accept, one-byte-over reject, final-byte accept,
        one-past-capacity reject) and the 64KB-allocation boundary
        (`000F:0FFF`+length-1 accept, +length-2 reject) both pass exactly;
        C64-window wrap (`FFFF`+length-2 reject, +length-1 accept) passes;
        direction/trailing-input/missing-arg/zero-length/invalid-and-
        inactive-handle cases all reject with the correct selector
  - [x] Increment 4: static grep confirmed zero `DOS_VMM_READ`/
        `DOS_VMM_WRITE` call sites; BSS growth is exactly 8 bytes; `G`/
        `T`/`P`/`Q` regression re-verified via the checkpoint/register
        procedure ([[reference-vice-checkpoint-verification]]) —
        `PC=$6000` on `G`, `PC=$6101` on both `T` and `P`, clean `Q`
        return with the remaining allocation cleaned up; `image_d64` and
        `test_image_d64` built with no warnings; CHANGELOG.md and
        brain/MEMORY.md updated, including a flag that WP6 has very
        little `MAIN` envelope headroom remaining
  - [x] User confirmed WP5 completion on 2026-08-06

- [x] Taskwarrior (`4141acb7-d8a7-4cb1-babd-9628f24616df`): DEBUG REU/address
      syntax WP4 status reporting (`XS`/`XS handle`)
  - Plan: `brain/plans/2026-08-05-debug-reu-address-syntax-wp4.md`
  - Branch: `feature/debug-reu-address-wp4` (based on `debug` after WP3
    merge, commit `597ec59`)
  - Plan approved 2026-08-04
  - [x] Increment 1: `XS handle`; DEBUG build 1123 (7,615 code bytes, 893
        relocation points); VICE-verified `XS handle` output is
        byte-identical to that allocation's original `XA` line; invalid
        (`XS 9`), inactive (freed then re-queried), and trailing-input
        (`XS 1 EXTRA`) cases all reject before any OS call
  - [x] Increment 2: bare `XS`; VICE-verified zero/one/two-allocation cases
        print the correct rows or `NONE`; REU-disabled (post-reset, true
        hardware-off state confirmed via `vmmInitialized` at `$1FA0`)
        correctly shows `VMM INACTIVE` and all-zero counters
  - [x] Increment 3: static grep confirmed zero `DOS_VMM_READ`/
        `DOS_VMM_WRITE` call sites; BSS growth is exactly 24 bytes
        (`sysInfoBuf`); `image_d64` and `test_image_d64` built with no
        warnings; CHANGELOG.md and brain/MEMORY.md updated, including a
        flagged (not fixed) finding that `ahGetSystemInfo`'s
        `ALLOC=`/`FREE=` page counters are unstable across calls despite
        `TOTAL`/`ALLOC`/`FREE` always summing correctly — root cause is in
        `src/command64/api.asm`/`vmm.asm`, outside WP4's `debug.s` scope
  - [x] WP1 `G`/`T`/`P`/`Q` regression re-verified 2026-08-05 against build
        1123 using a checkpoint/register-based procedure (see WP3 entry
        below for the method); no longer a manual-only check
  - [x] User confirmed WP4 completion on 2026-08-04

- [x] Taskwarrior (`49b81383-9e58-4f51-95f2-f7f7ad3a0427`): DEBUG REU/address
      syntax WP3 allocation lifecycle (`XA`/`XD`/`Q` cleanup)
  - Plan: `brain/plans/2026-08-05-debug-reu-address-syntax-wp3.md`
  - Branch: `feature/debug-reu-address-wp3` (based on `debug` after WP2 merge,
    commit `bd5539d`)
  - [x] Increment 1: `XA` allocation; DEBUG build 1120 (7,203 code bytes, 822
        relocation points); VICE-verified `XA 0001`/`0100`/`1000` register and
        print the documented `SEG=/BANK=/PARA=/PAGES=/SIZE=` summary
        (`1000` paragraphs correctly shows `SIZE=10000`); `XA 0000`/`1001`
        rejected with no registry change; registry-full rejected on the 5th
        concurrent allocation
  - [x] Increment 2: `XD` release; DEBUG build 1121 (7,265 code bytes, 835
        relocation points); VICE-verified a valid handle frees silently, a
        repeated `XD` reports inactive, and an out-of-range handle (`XD 9`)
        rejects before any OS call
  - [x] Increment 3: `freeAllReu` and `Q` routing; DEBUG build 1122 (7,349
        code bytes, 851 relocation points, within the 8KB `MAIN` envelope);
        VICE-verified `Q` with four active allocations releases all four and
        returns to `c64[8]:>`; a DEBUG restart confirmed all four handles
        report inactive (no leaked allocation); REU-disabled boot confirmed
        `XA`/`XD` fail cleanly and `Q` with no allocations exits normally
  - [x] Increment 4: static grep confirmed zero `DOS_VMM_READ`/
        `DOS_VMM_WRITE`/`DOS_GET_SYSTEM_INFO` call sites; BSS growth is
        exactly 3 bytes (`reuXferParaLo/Hi`, `reuXferSlot`) beyond WP2's
        20-byte registry; `image_d64` and `test_image_d64` built with no
        warnings; CHANGELOG.md, brain/MEMORY.md, and the WP3 task spec
        updated
  - [x] User confirmed WP3 completion on 2026-08-04
  - [x] WP1 `G`/`T`/`P`/`Q` regression re-verified 2026-08-05: a
        checkpoint-based procedure (non-temporary `exec` checkpoints at
        `$6000` and DEBUG's computed breakpoint target `$6101`, held and
        inspected via `vice_read_registers`/`vice_read_memory` instead of
        screen-text OCR) replaces the earlier manual-only re-check.
        Confirmed `PC=$6000` on `G =6000`, `PC=$6101` on both `T =6100`
        and `P =6100` (matching DEBUG's installed `$00` BRK byte there),
        byte restoration to `EA` after each trap, and clean `c64[8]:>`
        return after `Q`. Finding: *temporary* checkpoints did not
        reliably hold the pause for inspection in this MCP (execution had
        already continued by the time state was read); non-temporary
        checkpoints, explicitly deleted after use, held reliably. Detailed
        procedure recorded in
        `brain/walkthroughs/2026-08-05-debug-reu-address-syntax-wp3.md`.

- [x] Taskwarrior (`91036469-8479-4a27-83ab-e74158f2fdea`): DEBUG REU/address
      syntax WP2 extended dispatch and registry foundation
  - Plan: `brain/plans/2026-08-04-debug-reu-address-syntax-wp2.md`
  - Branch: `feature/debug-reu-address-wp2`
  - [x] Increment 1: exact dispatch, stubs, selectors, build 1116, and VICE
        routing complete; malformed tokens rejected before stub dispatch
  - [x] Increment 2: 20-byte registry and explicit startup initialization;
        DEBUG build 1117 and VICE zero/reset/stub-preservation checks passed
  - [x] Increment 3: all three registry helpers implemented; DEBUG build 1119
        and direct VICE carry/register/selector path verification passed
  - [x] Increment 4: DEBUG build 1119 rebuilt clean (6,885 code bytes, 762
        relocation points, within the 8KB `MAIN` envelope); `image_d64` and
        `test_image_d64` built with no warnings; VICE matrix on `image.d64`
        confirmed bare/argument `XA`/`XD`/`XM`/`XS` route to the temporary
        stub, `X`/`X A`/`XX`/`X?`/`XAA`/`XMAP`/`XA0100`/`XA:0100` all reject
        with no stub text, lowercase `xa` normalizes identically, and stub
        handlers make no memory writes (static: each is `jmp reuStub` ->
        `API_PRINT_STR` only); re-ran WP1 `G =6000`/`T =6100`/`P =6100`/`Q`
        against safe RTS/NOP fixtures with clean shell return; static grep
        confirms zero `DOS_ALLOC_MEM`/`DOS_FREE_MEM`/`DOS_VMM_READ`/
        `DOS_VMM_WRITE`/`DOS_GET_SYSTEM_INFO` call sites in `debug.s`
  - [x] User confirmed WP2 completion on 2026-08-04
  - [x] Merged into `debug` (commit `bd5539d`) on 2026-08-04

- [x] Taskwarrior (`adfecaf3-212c-4e91-bcf5-f1c79f673eae`): DEBUG REU/address
      syntax WP1 parser foundation and permissive `=`
  - Plan: `brain/plans/2026-08-03-debug-reu-and-address-syntax-wp1.md`
  - Branch: `feature/debug-reu-address-wp1-plan`
  - [x] Increment 1: added `requireEnd` and `parseOptionalEquals`; DEBUG build
        1112 succeeded with 6,580 code bytes and 721 relocation points
  - [x] Increment 2: `G` integrated and verified under VICE on DEBUG build
        1113; valid bare/`=` forms matched, invalid forms did not execute, and
        no-argument behavior remained compatible
  - [x] Increment 3: shared `T`/`P` integrated and verified under VICE on
        DEBUG build 1114; invalid forms preserved PC, trace/proceed behavior
        and ROM handling remained compatible
  - [x] Increment 4: focused regression, artifact review, DOX, and walkthrough
        including safe `$6000+` rerun and stale test-plan range correction
        completed; user confirmed the walkthrough on 2026-08-04
  - [x] User confirmed WP1 completion on 2026-08-04

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
  - Carried forward to Phase 11, triaged by WP56 2026-08-08 (see
    `brain/plans/2026-08-08-casm-phase11-wp56-contract-reconciliation.md`):
    - `CasmOutputCreated` "conflates created with opened existing" --
      **retired, no code change.** Traced `fileCreateOutput`
      (`src/external/casm/fileio.s:163-206`): the flag is only ever set true
      on genuine creation; a write-mode open against an existing filename
      currently hangs on KERNAL IEC retry rather than succeeding (that hang
      is the real, already-tracked issue -- see TW #36, "CASM
      fileCreateOutput has no @0: replace marker").
    - No `CLD` at entry -- **not a live bug (corrected 2026-08-08 from
      WP56's own first pass): `apiHandler` (`src/command64/api.asm:44`)
      already does `cld` on every `OS_API` call, and CASM's first `OS_API`
      call (`diagPrintString`'s banner print, `casm.s:147`) is reached
      before any arithmetic-sensitive code path -- decimal mode is already
      clear when it matters, but only as an emergent, fragile consequence
      of that call ordering, not a structural guarantee.** Assigned to
      WP60 anyway (user-confirmed), reframed as hardening against the
      implicit ordering invariant (mirror `src/external/dash/dmain.s`'s
      explicit `CLD`-as-first-instruction), not as a fix for a live defect.
    - No CASM Phase 4 contract section in `brain/KNOWLEDGE.md` --
      **confirmed gap, assigned to WP62.** Section jumps from Phase 3
      (line 132) straight to Phase 5 (line 229).

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

- [x] `687ada7e-4175-41b4-93f3-9e8df85c1a5c` CASM Phase 9: include processing
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
  - [x] `579096d9-ce77-44db-96a9-c32654238949` WP47 ordered include graph and
        Pass 2 replay — complete 2026-07-29. Plan:
        `brain/plans/2026-07-29-casm-phase9-wp47-ordered-include-graph-and-pass2-replay.md`
    - First real production `.INCLUDE` dispatch in `casmRunPass`: Pass 1
      loads/pushes and records one ordered event per include site; Pass 2
      replays with zero source-filesystem I/O. Also gives
      `includeCatalogInit` its first production call site
    - Frozen 16-byte include-event record in the metadata allocation's
      already-reserved second half (offset 4096); parent identity carries a
      kind tag (top-level root vs nested frame) because WP45/46 deliberately
      never cataloged top-level files (WP48's job)
    - User-confirmed scope: WP46's deferred per-frame echo save/restore
      stays deferred; Pass 2 defensively re-derives child identity and
      compares it against the recorded event
    - Factored `includeCatalogLookup` out of `includeCatalogLoad` so Pass 2
      calls an entry point *structurally* incapable of filesystem I/O rather
      than one merely trusted not to perform it. Zero-Pass-2-source-I/O is
      proven by reachability: the only open path in a pass sits inside the
      `CASM_PASS_MODE_MEASURE` branch
    - Deviation from plan (user-approved): end-to-end fixtures ship on a new
      `casm_include_test_d64` image, not `casm_overflow_test_d64` — that
      disk had ~10 free blocks and this WP's verification writes eight
      output PRGs to the disk it reads from
    - MAIN `$4000` -> `$4200` (measured 16,718-byte minimum, 178 bytes
      headroom); `test_casm_catalog` `$1B00` -> `$1C00`
    - Defect caught in code review before runtime: `crpParentIdentity`
      indexed the frame array with a stale `A` (the parent-kind constant),
      reading frame 0 at every depth — coincidentally correct at depth 1,
      wrong from depth 2 up
    - All runtime checks passed first attempt: `test_casm_event`'s 15 cases,
      and all four end-to-end pairs `FILES COMPARE OK` (cross-boundary
      labels/branches both directions, three-level nesting, sequential
      reinclusion, relocatable with relocation table). User approved
      completion. Final CASM `0.1.49` build 1196; no-change rebuild stable;
      all four disk images pass. **WP47 complete.** WP48 unblocked in
      Taskwarrior but deliberately not activated
  - [x] `797bb460-6d82-453c-8f55-7aa53d2eb095` WP48 included-source diagnostics
        and tracebacks — complete 2026-07-29. Plan:
        `brain/plans/2026-07-29-casm-phase9-wp48-included-source-diagnostics-and-tracebacks.md`,
        branch `feature/casm-phase9-wp48`
    - Fixed a live defect: a diagnostic raised inside an included file
      previously named the wrong file — `CasmSourceFileId` only tracked the
      top-level index and is never updated while a nested frame is active
    - User-confirmed scope: bit-pack (kind, id) into the existing 1-byte
      `FILE_ID` field rather than grow the frozen 39-byte token record; add
      a dedicated `CasmFrameSiteColumn` array rather than reuse
      `CasmFrameResumeColumn` for the traceback's per-frame column
    - Traceback renders from the still-live frame stack at
      `diagPrintFatal` time — no raise-time snapshot needed, since nothing
      pops a frame before cleanup runs
    - No new `CASM_DIAG_*` values. `test_casm_pass1`/`test_casm_passcheck`
      will need `include.s` added to their link for the first time, likely
      forcing envelope bumps
    - [x] Implement packed root/catalog provenance and dedicated include-site
      column capture
    - [x] Implement catalog-backed physical filenames and bounded traceback
      rendering with non-masking fallback
    - [x] Add the production nested-failure fixture chain and build all four
      disk images
    - [x] Fix review-found parent-byte append after unterminated child EOF and
      add a dedicated nested boundary fixture
    - [x] Recover post-pop traceback depth and originating root from retained
      bounded frame metadata
    - [x] Replace runtime-disproven resume-line reuse with dedicated include-site
      line arrays; raise `test_casm_pass1` to approved `$4200`
    - [x] Raise whole-object `test_casm_event` to approved `$1D00` after its
      measured 31-byte overflow
    - [x] Complete the user runtime walkthrough and approve completion; user
          reported all tests pass and explicitly approved completion on
          2026-07-29. Final CASM `0.1.50` build 1204; WP49 remains pending and
          inactive
  - [x] `a8c3dbf0-9333-4489-9c3b-3e752049b693` WP49 verification, walkthrough,
        and Phase 9 completion gate
    - [x] Obtain approval for the detailed verification-only plan
    - [x] Activate WP49 and synchronize repository and Taskwarrior state
    - [x] Reconcile the frozen WP43-WP48 baseline and review full execution paths
      - [x] Confirm version/build, envelopes, harness targets, images, and
            production Pass 1/Pass 2/traversal/cleanup paths
      - [x] Resolve the stale CMake production-headroom comment (196 recorded
            there versus final WP48's 85) through an approved narrow amendment
    - [x] Run static, harness, regression, envelope, artifact, and image checks
    - [x] Verify trusted references, failure handling, cleanup, and stable rebuild
    - [x] Produce and complete the user runtime walkthrough
    - [x] Obtain explicit approval before marking WP49 and Phase 9 complete
    - User explicitly approved completion on 2026-07-29. CASM remains
      `0.1.50` build 1204; master-plan Phase 10 remains inactive.

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
# Active Regression Work

- [x] Cross-device `COPY` regression (`wiki/tasks/copy-cross-device-regression.md`)
  - [x] Reproduce `copy banner.s 8:banner.s` with device 9 active.
  - [x] Confirm the copied file differs in size.
  - [x] Correct data-channel sequencing and failure cleanup.
  - [x] Verify byte equality by extracting both D64 payloads.
  - [x] Obtain user completion confirmation.
- [ ] Cross-device `COMP` regression (`wiki/tasks/comp-cross-device-regression.md`)
  - [x] Reproduce false `FILES ARE DIFFERENT SIZES` on identical files.
  - [ ] Add a public multi-file open contract and update `COMP`.
- [/] User-program origin and external relocation (`wiki/tasks/user-program-origin-relocation.md`)
  - [x] Select relevant changes from the incomplete DASH branch.
  - [x] Make `$3800` the fresh-build default and relocate R6 external commands.
  - [x] Rebuild packaged applications and smoke-test CASM.
  - [ ] Smoke-test a non-relocatable external command.

# CASM Phase 10 - Symbol Map and Listing

- [ ] Taskwarrior #34 (`32e09eea-691d-40bc-aa7a-7d2299fe093b`): CASM Phase 10
      Symbol Map and Listing
  - Approved governing plan:
    `brain/plans/2026-07-29-casm-phase10-symbol-map-listing.md`
  - Milestone task: `wiki/tasks/casm-phase10-symbol-map-listing.md`
  - [x] WP50 (`ad82f04d-0d34-4902-9a2c-ae27292902cf`): contract reconciliation
        and ABI freeze; complete at CASM `0.1.51` build 1206, user-approved
        2026-07-31, per
        `brain/plans/2026-07-29-casm-phase10-wp50-contract-reconciliation.md`
        and
        `brain/walkthroughs/2026-07-31-casm-phase10-wp50-contract-reconciliation.md`
  - [x] WP51 (`a64fa847-1b46-44fd-be3b-8ad7b1055c92`): listing stores and
        capture events; complete at CASM `0.1.52` build 1222, user-approved
        2026-08-03, per
        `brain/plans/2026-07-29-casm-phase10-wp51-listing-stores-capture.md`
        and
        `brain/walkthroughs/2026-08-03-casm-phase10-wp51-listing-stores-capture.md`;
        Task Warrior task closed, WP52 unblocked
  - [x] WP52 (`0bf2e86b-0bd0-443a-b84b-b2c258e98181`): deterministic symbol
        map; approved plan
        `brain/plans/2026-07-29-casm-phase10-wp52-deterministic-symbol-map.md`;
        branch `feature/casm-phase10-wp52` (based on `casm-phase10` after
        catching it up to `main`, commit `a69ccd8`)
    - [x] `symbolsReadByIndex` added to `symbols.s` (stateless, definition-
          order record read by index; distinct from the hash-chain-walking
          `symbolsFindChain`)
    - [x] `CASM_DIAG_SYMBOL_MAP_INVALID` ($42) added with its own
          contiguity assertion and `diagPrintFatal` case (kept out of the
          dense message-table array to avoid pre-filling WP53's still-
          unimplemented $3D-$41 reserved range)
    - [x] `map.s` added: `mapPrint`/`mapValidateRecord`/`mapFormatRow`/
          private hex+decimal formatters; linked into production `casm`
          via the existing source glob, with no `casm.s` call site (`/M`
          stays NOT IMPLEMENTED until WP54, per plan)
    - [x] `tests/src/casm_map/casm_map.s` harness: 16 fixtures (empty/one/
          full table, insertion order vs. hash order, case sensitivity,
          31-byte name, boundary addresses, repeated printing, read-index
          bounds, invalid NameLen/Flags/padding, VMM failure via a freed
          slot) -- VICE-verified 16/16 PASS on `casm_listing_test_d64`
    - [x] Envelope: casm.prg `$4900` -> `$4B00` (+512, 150 bytes headroom
          after map.s's 362-byte overflow); test_casm_pass1 `$4700`->`$4800`
          and test_casm_passcheck `$4300`->`$4400` (symbols.s linked whole)
    - [x] Disk capacity fallout (symbols.s growth cascading into two
          already-near-capacity test disks) resolved per user direction:
          test_casm_passcheck and test_l15release relocated from
          test.d64/casm_overflow_test.d64 to casm_listing_test_d64
          (523->442 blocks free there; both origin disks back to their
          pre-WP52 headroom)
    - [x] CASM version bumped `0.1.52` -> `0.1.53` (build unchanged in
          code size; version-string length identical)
    - [x] Regression: production `casm`, `test_casm_map` (16/16),
          `test_casm_passcheck` (2/2) all VICE-verified clean;
          `test_casm_symbols` initially hung after a device-switch
          mid-session (device/IEC anomaly, not a real assertion failure) --
          user reset the machine and confirmed `test_casm_symbols` passes
          in full
    - [x] User confirmed the walkthrough 2026-08-05; ready to commit and
          merge onto `casm-phase10`
  - [x] WP53 (`aa57f461-36a9-455c-966f-ac484ec57b41`): listing naming,
        serialization, and cleanup; approved plan
        `brain/plans/2026-07-29-casm-phase10-wp53-listing-serialization-cleanup.md`;
        branch `feature/casm-phase10-wp53`
    - [x] Increment 1: `cliDeriveListingName` (`cli.s`) + `test_casm_cliderive`
          (7/7 PASS via shell)
    - [x] Increment 2: `sourceReadSpanChunk` (`source.s`) + `test_casm_spanread`
          (8/8 PASS via shell)
    - [x] Increment 3: `outputCommit`/`CasmOutputCommitted` (`fileio.s`),
          `outputAbort` amended so a committed PRG is never deleted +
          `test_casm_spancommit` (5/5 PASS via shell)
    - [x] Increment 4: `.LST` file I/O (`listingFileInit`/`Create`/`Write`/
          `Close`/`Delete`/`Abort`, `listing.s`), diagnostics `$3D`-`$41`
          activated, CBM DOS's native `@0:` replace-on-open marker proven
          against a real stale-file replace + `test_casm_listwrite` (5/5
          PASS via VICE)
    - [x] Increment 5: `listingValidateRecord`/`listingResolveFilename`
          (`listing.s`) + 12 new `test_casm_listwrite` fixtures, 17/17 PASS
          via VICE; found/fixed a test-fixture A-clobber bug during
          verification (not a product bug)
    - [x] Increment 6: `listingWriteFile` (`listing.s`), the full `.LST`
          serializer (row/header formatters, aggregate buffering with
          flush-before-split) + 3 new fixtures (empty listing, byte-exact
          golden-path readback, 31/32-char header chunk), 20/20 PASS via
          VICE; found/fixed two real bugs -- a production charmap bug
          (`"FILE "` header text needed lowercase ca65 source to match the
          hex formatter's unshifted output) and a test-fixture bug
          (`listingMirrorByte` clobbers Y internally, silently drifting a
          loop index held across the call)
    - [x] Increment 7: 3 new fixtures closing coverage gaps (byte+source
          continuation together, aggregate-flush boundary, mid-replay
          validation failure through the real `listingWriteFile`
          orchestration), 23/23 PASS via VICE, no bugs found
    - [x] Full clean rebuild + no-change rebuild both stable (md5-identical
          `casm.prg`); regression pass of `test_casm_listing`/
          `test_casm_listcap`/`test_casm_map` all VICE-confirmed clean;
          production `casm` sanity (prints version banner, runs normally,
          `/L`/`/M` still `NOT IMPLEMENTED`)
    - [x] CASM version bumped `0.1.53` -> `0.1.54` (build `1236` -> `1237`)
    - [x] User approved 2026-08-06; walkthrough
          `brain/walkthroughs/2026-08-06-casm-phase10-wp53-listing-serialization-cleanup.md`;
          Task Warrior task closed, WP54 unblocked
  - [x] WP54 (`f4b598fd-bab1-4394-9415-c71e3ea1cfa5`): production integration;
        approved plan
        `brain/plans/2026-07-29-casm-phase10-wp54-production-integration.md`
    - [x] Activated `/M` and `/L` in `casm.s`'s real `start`/`casmRunPass`
          sequence: `cliDeriveListingName`, `listingCaptureInit`/`Finalize`,
          `outputCommit`, `listingWriteFile`, `diagClearLoc`+`mapPrint` wired
          in the plan's exact specified order (PRG committed before listing,
          listing before map); unified `artifactsAbort` fatal routing
    - [x] Increment 1's dedicated `test_casm_phase10` failure-injection
          harness formally dropped from scope (user decision) in favor of
          increment 6's live production-fixture matrix as Completion Gate
          evidence
    - [x] 5 fixture categories x 4 option combinations on a new
          `casm_phase10_test_d64` disk, 15/15 `comp` byte-identity checks
          against baseline; found and fixed a real bug (`.INCLUDE` under
          `/L` failed `LISTING REPLAY MISMATCH` from a `CasmVmmBuffer`
          clobber in `listingResolveFilename`/`includeCatalogRead`), fixed
          in `listing.s`, re-verified clean
    - [x] Formal envelope/regression pass: 18553 code bytes at both
          `$3800`/`$3900` origins, 4.63KB below the `$5B00` cap, no
          zero-page growth; 25-target regression build clean; code review
          against every plan Stop Condition, no findings; live post-fix
          spot-check (`comp` `FILES COMPARE OK`)
    - [x] CASM version bumped `0.1.54` -> `0.1.55` (build `1257` -> `1258`)
    - [x] User approved 2026-08-08; walkthrough
          `brain/walkthroughs/2026-08-08-casm-phase10-wp54-production-integration.md`;
          Task Warrior task closed, WP55 unblocked
  - [x] WP55 (`94d98a2b-7ad4-49f0-bf33-38702690eca9`): verification,
        walkthrough, and phase gate; approved plan
        `brain/plans/2026-07-29-casm-phase10-wp55-verification-walkthrough-completion-gate.md`
    - [x] Baseline reconciliation (found/fixed one stale-doc gap, no
          behavior discrepancies) and a 9-item full-path code review, both
          tracing actual code rather than inferring from names
    - [x] 13/13 relevant harnesses (the plan's four named Phase 10
          harnesses plus 9 directly-related regressions) PASS live under
          VICE, including `test_casm_include`/`catalog`/`event` dispatched
          from a second attached unit
    - [x] PRG/R6 identity/bounds/failure-injection/resource-reuse audit:
          bounds and naming fully proven by existing real-routine-loop
          fixtures; disclosed one accepted gap (`CREATE`/`CLOSE`/`DELETE`/
          `SHORT_WRITE` listing diagnostics have no independent
          fault-injection coverage anywhere in this codebase, a
          pre-existing pattern predating Phase 10, not introduced by it);
          3 new live production-level proofs added (`LISTING NAME
          COLLISION` firing for real with same-session recovery, and a
          direct `comp` proving included/flattened equivalence survives
          `/M /L`)
    - [x] 4-session runtime walkthrough: on-device `.LST`/map inspection
          plus load-and-run behavioral confirmation for a static
          (`casmemit1.s`) and relocatable (`banner.s`) program, and live
          confirmation of the `.INCLUDE` parent-resume file-header
          re-transition, cross-validated against the `/M` map
    - [x] CASM version bumped `0.1.55` -> `0.1.56` (build `1258` -> `1259`)
    - [x] User approved 2026-08-08; walkthrough
          `brain/walkthroughs/2026-08-08-casm-phase10-wp55-verification-walkthrough-completion-gate.md`;
          Task Warrior task closed
  - [x] Obtain explicit completion approval before the separate `0.2.0`
        promotion. User-approved 2026-08-08 ("Approved. Finally, merge onto
        casm-phase10"). Applied: `VERSION_MINOR`/`VERSION_STAGE` in `casm.s`
        changed together (`"1"`/`"56"` -> `"2"`/`"0"`), build `1259` ->
        `1260`, code size -1 byte (harmless string-literal delta),
        no-change rebuild stable, 25-target regression clean, live-verified
        via VICE (`CASM V0.2.0.1260`). **CASM Phase 10 is complete.**

- [ ] Taskwarrior #37 (`ca5d69aa-b674-4a24-a7fa-55160755d47a`): CASM Phase 11
      Base-Release Hardening and Documentation
  - Governing plan:
    `brain/plans/2026-08-08-casm-phase11-base-release-hardening-documentation.md`
  - Open questions (WP breakdown, `0.2.x` versioning, WP57-before-WP58
    sequencing) confirmed as drafted 2026-08-08
  - [x] Taskwarrior #38 (`636eddce-4777-4ccb-b79f-0e9903fdd10d`): WP56
        contract reconciliation and audit-risk triage
    - Plan: `brain/plans/2026-08-08-casm-phase11-wp56-contract-reconciliation.md`
    - No production source, version, or build change (planning/triage only)
    - Triaged the 3 Phase 4 carried-forward debt items: `CasmOutputCreated`
      retired as a stale premise (real issue is TW #36, `fileCreateOutput`'s
      missing `@0:` replace marker); missing entry `CLD` confirmed as a
      real narrow hardening gap, assigned to WP60; missing Phase 4
      `brain/KNOWLEDGE.md` section confirmed, assigned to WP62
    - Produced the 4-tier module audit-priority register (18 files under
      `src/external/casm/`) and WP57's dedicated design-spike plan as this
      WP's own final increment
    - User approved completion 2026-08-09. **WP56 complete.**
  - [x] Taskwarrior #39 (`d8b09018-8c17-4c98-8ee7-e32d755952ea`): WP57
        fault-injection infrastructure design spike
    - Plan: `brain/plans/2026-08-08-casm-phase11-wp57-fault-injection-design-spike.md`
    - Traced every file/VMM call site in `fileio.s`/`vmm_store.s` (and by
      extension `source.s`/`symbols.s`/`reloc.s`/`include.s`, which hold no
      direct `OS_API` calls of their own) to the single fixed
      `OS_API = $1000` stub; chose a runtime hook there (Candidate A) over
      a test-only OS build variant or link-time module substitution
    - Built `tests/src/casm_faultinject/casm_faultinject.s`: patches the
      `$1000` `jmp apiHandler` stub's operand to install `faultStubEntry`,
      proven against the real, unmodified `fileCreateOutput`/
      `DOS_OPEN_FILE` with a disarmed control case and an armed forced-
      failure case (no partial `CasmOutputState`/`CasmOutputCreated`
      registration -- indistinguishable from a genuine failure)
    - Live-verified in VICE (build 1260 `test.d64`): `CASM FAULTINJECT:
      PASS`; no `image_d64`/`test_image_d64` production content changed
    - User confirmed the live demonstration 2026-08-08. **WP57 complete.**
    - WP58's dedicated plan drafted as this WP's final increment
  - [x] Taskwarrior (`d297b689-3fba-4e16-81f7-8176b39a07e2`): WP58
        apply fault-injection across file/VMM-touching modules
    - Plan: `brain/plans/2026-08-08-casm-phase11-wp58-apply-fault-injection.md`
    - Scope: extract `faultstub.inc` from WP57's inline prototype; add
      `fileio.s`'s remaining 4 operations (`WRITE_FAILED`/`SHORT_WRITE`/
      `CLOSE_FAILED`/`DELETE_FAILED` plus `DOS_READ_FILE` EOF-vs-error);
      build `casm_faultinject_vmm` for `vmm_store.s`'s 4 operations
      (`DOS_ALLOC_MEM`'s two branches distinguishing no-REU from OOM); one
      fixture per remaining VMM-holding module (`source.s`/`symbols.s`/
      `reloc.s`/`include.s`) built from that module's own registry/cursor
      contract
    - User approved the plan 2026-08-09
    - [x] Increment 1: traced `fileDelete` (`fileio.s:366-376`) -- identical
          SEC-only shape as `fileCreateOutput`, no plan amendment needed
          (Open Question 3 resolved). Extracted
          `tests/src/casm_faultinject/faultstub.inc`, extended with
          `FaultReturnA` (for `DOS_ALLOC_MEM`'s `VMM_ERR_INVALID` branch)
          and `FaultSetCount`/`FaultReturnCountLo/Hi` (for `DOS_READ_FILE`'s
          EOF-vs-error disambiguation), both defaulting to 0 so every
          existing operation keeps WP57's original shape unchanged.
          `fileWrite`'s carry-clear `SHORT_WRITE` shape deliberately left
          out, deferred to whichever increment first needs it. Refactored
          `casm_faultinject.s` onto the shared include; wired
          `faultstub.inc` into `CMakeLists.txt`'s `TMP_CA65_SRCS` list for
          the hash gate. Build 1002, 1,508 code bytes (+20); `test_image_d64`
          clean. Live-verified in VICE: `CASM FAULTINJECT: PASS`, matching
          WP57's exact result -- shared-library extraction proven
          behavior-preserving before Increment 2 adds anything new.
    - [x] Increment 2: extended `faultstub.inc` with opt-in
          `FaultReturnSuccess` while preserving carry-set as the default;
          expanded `casm_faultinject.s` from 2 to 8 cases covering
          `WRITE_FAILED`, `SHORT_WRITE`, `CLOSE_FAILED`, `DELETE_FAILED`,
          zero-byte read EOF normalization, and nonzero
          `INPUT_READ_FAILED`. The first live run (`......F.`) exposed a
          fixture setup error: the EOF case had not explicitly replaced
          fileRead's seeded request count with zero. Corrected by enabling
          the canned zero count; no production defect or source change.
          Final build 1005 is 1,919 code bytes with 281 relocation points;
          `test_image_d64` builds clean. Live VICE 3.10 verification on MCP
          port 7000 produced `........`, `CASM FAULTINJECT: PASS`, and a
          normal return to `C64[8]:>`. User approved Increment 2 on
          2026-08-09.
    - [x] Increment 3 complete and user-approved 2026-08-09: added
          collision-safe `test_casm_faultvmm`, with five real-`vmm_store.s`
          cases distinguishing no-REU from OOM and proving failed free/read/
          write operations retain ownership for retry cleanup. The original
          long name collided with Increment 2's fixture at D64's 16-character
          limit; the distinct name then proved `test.d64`'s directory track
          full. User approved packaging it on `casm_overflow_test.d64` instead
          (`test_casm_faultv`, 72 blocks free), preserving all `test.d64`
          content. Final build 1001: 1,335 code bytes, 179 relocations;
          no-change rebuild stable; both disk targets clean. Live VICE 3.10:
          `.....`, `CASM FAULT VMM: PASS`, normal `C64[9]:>` return.
    - [x] Increment 4 implementation/verification: added
          `test_casm_faultsource` with four source allocation/write/read
          cleanup cases. Corrected one fixture-only trusted-byte expectation
          (`casmcat1` is ASCII `1`). Final build 1001: 9,329 code bytes,
          1,264 relocations; both disk targets clean; overflow image has 25
          blocks free. After one soft-reset recovery from a wedged hot-attach
          session, live VICE produced `....`, `CASM FAULT SOURCE: PASS`, and
          a normal `C64[9]:>` return. No production source changed.
    - Increments 4-7 completed all source/symbol/relocation/include fixtures,
      disk wiring, full build, consolidated live verification, and walkthrough.
      All 29 cases across six fixtures pass. User approved completion
      2026-08-11; WP58 changed test infrastructure only and left CASM at
      `0.2.0` build `1260`. **WP58 complete.**
  - [x] Taskwarrior #40 (`4a1fab7c-28af-4404-af39-6f283b552e55`): WP59
        `listing.s`/`map.s` hardening
    - Plan:
      `brain/plans/2026-08-11-casm-phase11-wp59-listing-map-hardening.md`
    - User approved the ten-increment plan 2026-08-11; each increment remains
      separately gated by the preceding increment's review.
    - [x] Increment 1: matrix frozen at
      `brain/reviews/2026-08-11-casm-phase11-wp59-increment1-contract-matrix.md`
      and user-approved 2026-08-11.
    - [x] Increment 2 user-approved 2026-08-11:
      added repeat-safe `faultUninstall` plus `test_casm_flist` with 15 API-
      restore/init/re-entry/disabled/transaction/wrong-state register/flag/stack
      cases. Build 1001: 5,782 PRG bytes, 4,294 relocatable code bytes, 740
      relocation points; `$2200` envelope unchanged. Self-bootable listing disk
      has 126 blocks free. Live VICE 3.10: 15 dots, `CASM FAULT LIST: PASS`,
      normal `C64[8]:>` return through restored real API; no recovery. No
      production CASM source, ABI, version, or output change.
    - [x] Increment 3 user-approved 2026-08-11:
      eight deterministic capture allocation, metadata write, mirror-stage/
      final flush, replay read, and serializer mirror-read cases bring
      `test_casm_flist` to 23 cases. Final build 1007: 7,799 PRG bytes, 5,785
      relocatable code bytes, 1,003 relocations; `$2200` unchanged; no-change
      rebuild stable; listing disk has 118 blocks free. Final VICE 3.10 run:
      23 dots, `CASM FAULT LIST: PASS`, normal `C64[8]:>` return, overlay
      `testing`/`pass` events relayed, no recovery. Two harness-only defects
      were corrected transparently: invalid serializer root setup found during
      review, and the shared SP checker counting its own two-byte JSR frame.
      No production source, ABI, version, or valid artifact changed.
    - [x] Increment 4 user-approved 2026-08-11:
      retryable registered/unregistered close and registration-failure
      close-then-delete compensation fix D1/D2 with no storage/public-ABI
      change. Ten new lifecycle cases bring `test_casm_flist` to 33/33 live
      VICE passes. Harness build 1009: 9,259 PRG bytes, 6,885 code bytes, 1,183
      relocations; `$2200` unchanged; listing disk 112 blocks free and no
      `FLI04*.LST` artifacts after runtime. Production CASM build 1261: 18,572
      code bytes, 2,806 relocations, about 210 bytes `$5500` headroom; still
      `0.2.0`. `test_casm_frame` required the smallest test-only envelope step
      `$5000` -> `$5100` after an 18-byte overflow. `image_d64` and listing
      disk build; no-change counters stable. VICE 3.10: 33 dots, PASS, normal
      `C64[8]:>` return; overlay testing/pass; no recovery.
    - [x] Increment 5 user-approved 2026-08-11:
      eight serializer replay/catalog/source/write/short/final-close/abort-
      close/abort-delete cases plus strengthened mirror-read evidence bring
      `test_casm_flist` to 41/41 live VICE passes. Build 1014: 11,033 PRG
      bytes, 8,169 code bytes, 1,428 relocations; measured `$2200` overflow by
      446 bytes required the smallest `$2400` test envelope (53 bytes
      headroom). Listing disk has 105 blocks free and no `FLI05*.LST`
      artifacts. Overlay testing/pass, normal `C64[8]:>` return, no recovery.
      Production CASM remains build 1261 and no-change counters are stable.
    - [x] Increment 6 user-approved 2026-08-11: included-device range validation, filename/
      catalog boundaries, header continuation, and shared-buffer snapshot proof.
      Implementation and verification are complete, awaiting user approval.
      `listingResolveFilename` rejects included devices outside 8-11 before
      device-table indexing. The approved load-envelope split retains 41 cases
      in `test_casm_flist` (build 1018, 11,093 bytes, `$2400`) and adds nine in
      `test_casm_flmeta` (build 1001, 7,369 bytes, `$1A00`). Host, D64, and
      regenerated R6 artifacts are byte-identical; the disk has 75 blocks free.
      Live VICE 3.10 passes 41/41 and 9/9 with both PASS banners and normal
      `C64[8]:>` returns; no `FLI06*.LST` remains. Initial false loader failures
      were invalid test-driver runs using PETSCII `$5F` left-arrow for `_`, then
      paused execution; exact `$A4` underscores and resume corrected setup.
    - [x] Increment 7 user-approved 2026-08-11: expand map validation edges, decimal transitions,
      repeat determinism, address formatting, and exported `mapPrint` contract
      coverage without changing valid output order or bytes.
      Implementation and verification complete, awaiting user approval.
      `test_casm_map` now has 23 cases covering NameLen 32/255, DEFINED-clear,
      each reserved flag bit, padding endpoints 37/63, partial-output VMM
      failure, totals 9/10/99/100/255/256/511/512, repeat output,
      `$0000`/`$FFFF`, A/carry/SP, and volatile print registers. Build 1012:
      5,294-byte PRG, 4,036 code bytes, 625 relocations, unchanged `$1400`
      envelope with 1,084-byte headroom. Live VICE passes 23/23 with
      `CASM MAP: PASS` and `C64[8]:>`; no production change.
    - [x] Increment 8 user-approved 2026-08-11: complete static ownership, shared-scratch,
      load-bearing BSS initialization, exported-state ABI, stale local-header,
      and DOX audit for `listing.s` and `map.s`.
      Implementation and verification complete, awaiting user approval. Review:
      `brain/reviews/2026-08-11-casm-phase11-wp59-increment8-static-audit.md`.
      No production defect, private ZP, unsafe scratch lifetime, uninitialized
      load-bearing BSS, or ownership mismatch found. Stale pre-WP54 source and
      harness comments corrected only. `CasmListingOpenName` is the sole unused
      legacy export and remains documented/retained to avoid an ABI change.
      Comment-driven CASM 1263/map 1013 rebuilds preserve 18,580/4,036 code
      bytes and 2,806/625 relocations; no-change rebuilds stable; disk 71 free.
    - [x] Increment 9 user-approved 2026-08-11: consolidated narrow/full builds, PRG/R6 and
      no-change stability, listing/map regressions, affected WP58 compatibility,
      production `/M`/`/L`/combined smoke paths, shell return, and artifact
      comparisons.
      Implementation and verification are complete and user-approved.
      Unrestricted, production-image, listing-image, and overflow-image builds
      pass with a stable no-change rebuild. A consolidated-build failure exposed
      the shared fixture's potentially page-straddling `JMP (RealApiVector)`;
      replacing it with a RAM-patched absolute JMP avoids the NMOS page-wrap
      hazard without production impact. Live VICE passes WP58 compatibility
      8/8, listing 41/41, metadata 9/9, and the previously final map 23/23.
      Production `/M`, `/L`, and `/M /L` each validate input, return to
      `C64[8]:>`, and create the expected map/listing outputs.
    - [x] Increment 10 user-approved 2026-08-11: The
      completion walkthrough at
      `brain/walkthroughs/2026-08-11-casm-phase11-wp59-listing-map-hardening.md`
      records all 19 exports, private paths, fixes, metrics, regressions,
      compatibility evidence, remaining gate, and manual confirmation steps.
      User approved completion; CASM `0.2.1.1264` differs from `0.2.0.1263`
      only at the stage and build banner bytes. The second image build retained
      build 1264 and the same PRG hash; the live banner and shell return pass.
      **WP59 complete.**
  - [/] Taskwarrior (`bd441121-dffa-4d69-8f3a-8572e0643322`): WP60 opcode,
        addressing, and boundary hardening
    - Plan:
      `brain/plans/2026-08-11-casm-phase11-wp60-opcode-addressing-boundary-hardening.md`
    - User approved the ten-increment plan 2026-08-12 and activated Increment 1
      only; each later increment remains separately gated by the preceding
      increment's review. Taskwarrior child created dependent on completed
      WP59 (`4a1fab7c-28af-4404-af39-6f283b552e55`).
    - [/] Increment 1 implementation/verification complete 2026-08-12, awaiting
          user approval. Froze all 151 legal NMOS 6502/6510 tuples
          independently at
          `brain/reviews/2026-08-12-casm-phase11-wp60-increment1-opcode-oracle.md`,
          mapped each to its parser `OpKind`/selection condition and a
          representative fixture statement, and mechanically reconciled the
          oracle against `opcodes.s`'s `opcodeMaskLo/Hi`, `opcodeRunOffset`,
          `opcodeBytes`, and `modeLength` -- exact match on all five tables,
          151/151/151 one-to-one mask-bit/opcode-byte correspondence proven.
          No production defect found; no production, fixture, or build-system
          change.
    - [/] Increment 2 implementation/verification complete 2026-08-12, awaiting
          user approval. Inventoried existing evidence across all 8 required
          boundary domains at
          `brain/reviews/2026-08-12-casm-phase11-wp60-increment2-boundary-register.md`:
          52 required rows, 13 reuse, 9 strengthen, 30 add. Several `add`/
          `strengthen` gaps are pre-generated `.seq` fixtures with correct
          boundary values that were never wired to an automated in-code
          assertion (manual-VICE-only, one -- `brrng1` -- with a documented
          historical wrong-reason pass). Flagged a plan-text correction: the
          VMM window-transfer chunk boundary is actually 64/65 bytes
          (`CASM_VMM_BUFFER_SIZE`), not the plan's literal 255/256. No
          production, fixture, or build-system change.
    - [x] Increment 3 complete 2026-08-12: added `CLD` as the literal first
          instruction at `start:` in `casm.s`, before `diagClearLoc` and
          every other init. `casm.s` is the linker entry object
          (`CASM_ENTRY`), confirmed by source trace to be the true load-time
          entry point. Build 1265: code bytes 18580 -> 18581 (exactly +1, the
          `CLD` opcode byte), relocations unchanged at 2806, base unchanged
          at `$3800`; no-change rebuild stable at 1265. `image_d64` builds
          clean, 334 blocks free (unchanged baseline). No BSS/zero-page/ABI
          change; CASM remains `0.2.1`. Hardens an implicit invariant (the
          existing first `OS_API` call already clears decimal incidentally)
          rather than fixing a reproduced live bug.
    - [x] Increment 4 complete 2026-08-12: added `test_casm_opcodes`, a
          direct matcher harness linking only `opcodes.s` (no parser/emit/
          VMM/file ownership); `CasmParserStmt` declared and fed directly,
          `diagSetLocFromStmt` stubbed locally. 151 legal-tuple cases (from
          the Increment 1 oracle) plus 46 focused cases (unsupported-mode
          rejection; 8-bit range accept/reject at `$00`/`$FF`/`$0100`;
          ZP/Absolute selection at `$00`/`$FF`/`$0100`/`$FFFF`; `FORCE_ABS`
          zero-page-shrink prevention; independent ZP,X/ZP,Y promotion incl.
          the LDX/STX/LDY/STY X<->Y role swap; all eight branches resolving
          to Relative with unconstrained 16-bit targets; Implied/Accumulator
          distinctness) = 197 cases. Each asserts opcode/mode/length or
          diagnostic, A/carry, `CasmParserStmt` byte-for-byte preservation,
          stack balance, and (legal tuples only) a 151-bit coverage bitmap
          with duplicate/missing detection. Compile-time asserts freeze 56
          mnemonics, 13 modes, 151 tuples, and the 10-byte case record.
          Build 1000: 3145 code bytes, 107 relocations, 3367-byte PRG (well
          under `$1400`); no-change rebuild stable. `test.d64`'s directory
          track is full, so the harness joins `casm_listing_test_d64`
          instead; both disk targets build clean. Live VICE 3.10: booted
          Command64 `0.4.1.2663`, dispatched via PETSCII `$A4` underscores,
          197/197 dots with zero `F`s, `CASM OPCODES: PASS`, normal
          `C64[8]:>` return, no recovery. Production CASM unchanged.
    - [x] Increment 5 complete 2026-08-12: added `casmopall.s` (one legal
          statement per the Increment 1 oracle's 151 tuples, same row order,
          `.ORG $C000`, `$12`/`$1234` representative operands, all eight
          branches targeting a same-numbered `TGnn` label placed immediately
          after their own instruction so every displacement is mechanically
          `$00`) via a new block in `GenerateCasmTestFixtures.cmake`, and its
          independently authored `tests/fixtures/casm/casmopall.ref.hex`
          (opcode+length transcribed mechanically from the frozen oracle,
          NOT from `opcodes.s`; full 151-row per-statement offset manifest
          using native `COMP`'s own 24-bit file-offset space so a mismatch
          localizes directly; self-validated through
          `hex_manifest_to_bin.py`, 323 bytes, sha256 recorded in the
          manifest). Added the dedicated self-bootable `casm_opcode_test_d64`
          (`command64`, `casm`, `comp`, `test_casm_opcodes`, `casmopall.s`,
          `casmopall.ref`) without touching `test.d64` or
          `casm_listing_test_d64` (`casmopall`/`casmbig1` both excluded from
          the generic `CASM_REF_NAMES` -> `test.d64` loop). `image_d64`
          rebuilt unchanged at 334 blocks free / build `1265`; CASM version
          unchanged. Live VICE 3.10: attached `casm_opcode_test.d64` to unit
          8 under an already-resident Command64 `0.4.1.2663` (no autostart),
          ran `casm casmopall.s /s /o:opall.prg` -> `CASM: INPUT VALIDATED`,
          then `comp opall.prg casmopall.ref` -> `FILES COMPARE OK`, both
          returning to `C64[8]:>`; `opall.prg` and `casmopall.ref` both 2
          blocks on disk. Proves the native assemble-then-COMP round trip
          byte-for-byte for all 151 legal combinations end to end. Requesting
          user review before Increment 6 (numeric/addressing/branch/PC
          boundaries) activates.
    - [x] Increment 6 complete 2026-08-12: Numeric Literal domain (4 new
          `casm_expr.s` cases: bare `$00FF`/`$0100` isolated from their
          prior addend-only context, `$10000` proving
          `exprParseNumeric`'s own digit-accumulation overflow ->
          `CASM_DIAG_OPERAND_OUT_OF_RANGE` distinct from the existing
          `sOver`/`sUnder` *expression*-overflow cases, and a bare
          `CASM_NUMBER_BINARY` literal (`%11111111`) never previously
          exercised by this harness); `CASE_COUNT` 34 -> 38, build 1038.
          Addressing Width's other two required rows (ZP/Absolute
          crossover, 8-bit-mode rejection) are satisfied retroactively by
          Increment 4's `test_casm_opcodes` focused cases, committed before
          this register row was reconciled -- re-classified `add`/`add` ->
          `reuse`, flagged here rather than silently assumed; its third row
          (`FORCE_ABS` stability across a genuine second measure/emit pass)
          remains open, deferred to a follow-up (single-pass `FORCE_ABS`
          shrink-prevention is already covered by Increment 4).
          Relative Branch (7/7) and Program Counter (5/5) domains: new
          `tests/src/casm_bounds/casm_bounds.s`, linking only `emit.s` (no
          lexer/parser/source), driving `emitInstruction`/`emitDirective`
          directly via hand-built `CasmParserStmt`/`CasmInsn` records --
          proves displacement COMPUTATION/range-checking, a different
          production routine than Increment 4's mode-SELECTION-only
          matcher. Branch targets independently reconciled against
          `nextPc=CasmPc(after opcode)+1`, matching Phase 4/6's own
          `casmbrp1`/`brn1`/`brp2`/`brn2` literals at their two shared
          boundaries. Caught and fixed two false-result bugs before this
          harness could be trusted: (1) `CasmOutputStarted`/`CasmPcOverflow`
          are private to `emit.s` (not `.export`ed) -- this harness's own
          same-named BSS bytes were disconnected shadows, never written by
          real code, and one (`CasmPcOverflow`) read back *accidentally
          nonzero* uninitialized RAM, producing a false PASS on the wrap-
          endpoint and PC-end-at-`$FFFF` cases before a temporary per-case
          marker (later removed) proved a genuine count/labeling
          discrepancy and traced it to this; fixed by dropping those three
          assertions in favor of only genuinely observable shared state
          (`CasmPc`, and `pcRejectOverflow`'s indirect proof via the next
          write's own returned diagnostic). (2) the repeat-reset case
          depends on `CasmCliOptions` genuinely reading 0 (not static) to
          observe `emitInit`'s real default-origin priming -- BSS is not
          guaranteed zeroed on load, so it is now zeroed explicitly in
          `start:` rather than trusted to `.res`. `test_casm_expr` build
          1038, `test_casm_bounds` build 1004 (3145 -> then settling at
          1352 code bytes, 215 relocations). Neither disk-space-limited;
          `test_casm_bounds` joins `casm_listing_test_d64` (test.d64's
          directory track already full, matching Increment 4's own
          `test_casm_opcodes` precedent); `image_d64`/full build unaffected,
          no production change. Live VICE 3.10: `test_casm_expr` on
          `test.d64` -> `CASM EXPR: PASS` (38/38); `test_casm_bounds` on
          `casm_listing_test.d64` -> `CASM BOUNDS: PASS` (12/12), both
          returning to `C64[8]:>`. Underscore program names required
          PETSCII `$A4` via `vice_keyboard_petscii`, not literal ASCII `_`
          via `vice_keyboard_type` (matches
          `reference_vice_shell_underscore_petscii` memory) -- the first
          attempt at each dispatch mistyped this and hit `BAD COMMAND OR
          FILE NAME`/`FILE NOT FOUND`, corrected on retry. Requesting user
          review before Increment 7 (source/symbol/VMM/relocation
          boundaries) activates.
    - [x] Increment 7 complete 2026-08-12. **Symbol domain** (`casm_symbols.s`,
          4 new fresh-table cases after `symfull1`): name length 1
          (`symlenmin1`); values `$0000`/`$FFFF` (`symvalzero1`/
          `symvalmax1`, RESOLVED-flag checked independent of the value
          bytes); 511 symbols isolated as its own checkpoint
          (`sym511boundary1`, asserting the 511th insert's own returned
          record index is exactly 510). Name length 0/32 not added:
          `symbolsInsert` trusts nameLen as an unenforced 1..31
          precondition (confirmed by source trace) -- 0 is structurally
          unreachable from the real lexer, and 32 is `lexer.s`'s own
          `CASM_DIAG_TOKEN_TOO_LONG` boundary, a different module than this
          harness links; both remain open, not silently assumed covered.
          **Relocation domain** (`casm_reloc.s`, 3 new fixtures plus a
          `fileWrite` stub upgrade from discard-everything to capturing
          the most recent call's bytes): empty-table R6 footer
          (`relocempty1`, count=0 verified byte-for-byte); offset `$FFFF`
          via `CasmPc=CASM_DEFAULT_ORIGIN-1`'s unsigned-subtraction wrap
          (`relocoffmax1`); full 4096-entry table with distinct per-entry
          offsets (unlike `relocfull1`'s static-offset fill), footer
          count=4096 verified, and a `vmmWindowRead` re-read of the table's
          own last 6 bytes (entries 4093-4095) near its full 8192-byte
          extent (`relocfinalize4096_1`). **VMM domain** (`casm_vmm.s`):
          `vmmoffset1` strengthened in place with a `REC_PAGES==16`
          assertion and a diagnostic-code compare on its existing
          one-past-window rejection; new `vmmlastbyte1` (real byte-pattern
          round-trip at offset 65535, not just carry-clear); new
          `vmmpage1` (isolated literal `4095` accept / `4096` reject with
          diagnostic compare, one granted page); new `vmmchunk1` (the real
          single-call transfer cap is `CASM_VMM_BUFFER_SIZE`=64 bytes, not
          the plan's literal "255/256" -- confirmed via `vwPrepareTransfer`
          source trace, matching Increment 2's own flagged correction for
          this same domain; 64 accepted, 65 rejected with diagnostic
          compare). **Source domain** (`casm_spanread.s`, extended with a
          parameterized `loadNamedFixture` alongside the untouched original
          `loadFixture`): 5 new cases wiring previously-unwired real
          fixtures to genuine `sourceNextByte` assertions --
          `srcCr1`/`srcCrlf1` (CR-only and CRLF both collapse to one
          NEWLINE, identical expected sequence proving the collapse),
          `srcBlank1` (consecutive LFs each produce their own NEWLINE),
          `srcFinCr1` (trailing lone CR resolves as a newline before EOF),
          `srcSplit1` (255-byte run + CRLF straddling the real 256-byte
          source refill-chunk boundary, proving the pending-CR latch
          survives a refill). Two Source rows explicitly NOT closed, both
          documented rather than silently dropped or faked:
          - Empty source file: `cc1541` cannot write a zero-byte SEQ entry
            at all (`ERROR: Unexpected filesize when reading
            casmsrc0.seq`), confirmed live; no fixture-pipeline path to
            this boundary today.
          - One-byte source file: `srcOneByte1` (written, built, run) caught
            a **real production defect**, independently reproducing and
            precisely characterizing an already-suspected, never-resolved
            issue -- WP51 Increment 9's own `fixEmpty` fixture comment in
            `cmake/GenerateCasmTestFixtures.cmake` was deliberately widened
            from 1 byte to 4 specifically to dodge "sourceLoad's
            phantom-byte over-read... at an exactly-1-byte file," pending a
            fix that never landed. Live evidence: after the fixture's real
            `Z` byte, the next `sourceNextByte` call returns
            `A=CASM_SOURCE_BYTE`, `CasmSourceResultByte=$00` (a spurious
            phantom byte) instead of `CASM_SOURCE_EOF`. Per this plan's
            stop conditions, no production fix is authorized without
            root-cause analysis and explicit approval; the routine is left
            in `casm_spanread.s`, deliberately not called from `start:`, as
            a ready-to-activate regression test. **Recommend a dedicated
            Taskwarrior item for this defect**, separate from WP60.
          `test_casm_spanread`'s envelope grew `$2C00`->`$3000` (644
          measured bytes). No production change. Live VICE 3.10 (all four
          harnesses): `CASM SYMBOLS: PASS`, `CASM RELOC: PASS`,
          `CASM VMM: PASS`, `CASM SPANREAD: PASS` (13/13, one case
          withdrawn as above), all returning to `C64[8]:>`. Requesting
          user review before Increment 8 (consolidated build/compatibility
          verification) activates, and a decision on the phantom-byte
          defect (separate task vs. folding root-cause+fix into a later
          WP60 increment under explicit approval).
    - [x] Increment 8 complete 2026-08-12: consolidated build and
          compatibility verification, recorded at
          `brain/reviews/2026-08-12-casm-phase11-wp60-increment8-consolidated-verification.md`.
          Reconfigured and built narrowly (`casm`, `test_casm_opcodes`,
          `test_casm_bounds`, `test_casm_expr`, `test_casm_reloc`,
          `test_casm_symbols`, `test_casm_vmm`, `test_casm_spanread`,
          `casm_opcode_test_d64`, `casm_listing_test_d64`,
          `casm_overflow_test_d64`), then `image_d64`/`test_image_d64`, then
          a full unrestricted build -- no target failed. No-change rebuild
          left `BUILD_CASM` at `1265` with an identical hash. Independently
          re-ran `tools/reloc.py` against fresh base/base+1-page casm links:
          18581 code bytes, 2806 relocations, byte-identical to
          `build/casm.prg` -- matches Increment 3 exactly, proving
          Increments 4-7 never touched `casm.s` again. Inspected every
          WP60-relevant disk's directory/block capacity: no overflow;
          `image.d64` unchanged at 334 blocks free. Live VICE 3.10 re-ran
          the full changed/affected set from scratch: `test_casm_opcode`
          (197/197, `CASM OPCODES: PASS`), the `casmopall.s`/`casmopall.ref`
          native `COMP` round trip (`FILES COMPARE OK`), `test_casm_bounds`
          (`CASM BOUNDS: PASS`), `test_casm_spanre` (`CASM SPANREAD: PASS`),
          `test_casm_symbol` (`CASM SYMBOLS: PASS`), `test_casm_reloc`
          (`CASM RELOC: PASS`), `test_casm_vmm` (`CASM VMM: PASS`), and a
          production `/M /L` smoke assembly of the real 151-statement
          `casmopall.s` (`SYMBOL MAP` printed 8 branch-target symbols,
          `CASM: INPUT VALIDATED`, `casmoml.prg`+`casmoml.lst` both
          committed to disk) -- all returned cleanly to `C64[8]:>`. Two
          harness-side issues surfaced and resolved without any production
          or fixture change: dispatch typos (untruncated name; literal
          ASCII `_` instead of PETSCII `$A4` via `vice_keyboard_petscii`,
          matching `reference_vice_shell_underscore_petscii`), and a
          disk-selection mistake targeting the directory-full `test.d64`
          for the first `/M /L` smoke attempt, which correctly produced
          `CASM: OUTPUT WRITE FAILED` / `Drive 8 status: 72, DISK FULL` --
          a real product diagnostic, not a defect -- resolved by retrying on
          `casm_opcode_test.d64`. No production defect found; no production,
          fixture, or build-system change. Requesting user review before
          Increment 9 (audit and walkthrough, record synchronization)
          activates.
    - [x] Increment 9 complete 2026-08-12: audit and walkthrough at
          `brain/walkthroughs/2026-08-12-casm-phase11-wp60-increment9-audit-walkthrough.md`.
          Reconciled the Increment 1 opcode oracle (151/151/151, re-proven
          live twice more at Increments 4/5/8) and the Increment 2 boundary
          register (52 required rows) against what Increments 6-7 actually
          closed: 48/52 closed, 4 residual -- `FORCE_ABS` stability across a
          genuine two-pass re-resolution (untested, single-pass shrink-
          prevention is covered); the source domain's 65,535-byte accepted
          extent and 65,536-byte first-reject boundary (never attempted);
          symbol name-length-32 rejection (owned by `lexer.s`, zero coverage
          anywhere in `tests/`); the empty-source-file row remains a tooling
          gap, not a code gap (`cc1541` cannot write a zero-byte SEQ entry).
          Recorded the one real production defect Increment 7 found and left
          unfixed (the one-byte-source phantom-EOF-byte in
          `sourceLoad`/`sourceNextByte`) as its own Taskwarrior item, task 42
          / UUID `882433f0-cde1-4849-8b3c-df32613518c3`, project `casm`,
          separate from WP60 per Increment 7's own recommendation. Recorded
          the two test-harness-only bugs Increment 6 found and fixed (both
          non-production). No production, fixture, or build-system change
          in this increment; `brain/KNOWLEDGE.md`, `brain/MEMORY.md`, and
          `CHANGELOG.md` need no edits since no owned fact in those files
          changed at this increment (all reserved for Increment 10's
          completion). Requesting accept/defer decisions on the 4 residual
          boundary items and approval to activate Increment 10 (version
          bump to `0.2.2`, final no-change proof).
    - [x] Increment 10 complete 2026-08-12: version-only completion
          increment. `casm.s`'s `VERSION_STAGE "1" -> "2"` (`0.2.1` ->
          `0.2.2`). First build (1265 -> 1266): `cmp -l` against the
          pre-bump `casm.prg` shows exactly 2 differing bytes, both in the
          banner string -- the version-stage digit (`1`->`2`) and the
          build-counter's own last digit (`5`->`6`); PRG size unchanged at
          24201 bytes; `image_d64` unchanged at 334 blocks free. Second
          build (no source change): build counter held at 1266 with an
          identical `BUILD_CASM` hash -- no-change stability confirmed.
          Independently re-derived the envelope via `tools/reloc.py` against
          fresh base/base+1-page links: 18581 code bytes, 2806 relocations,
          byte-identical to `build/casm.prg` -- unchanged since Increment 3.
          Live VICE 3.10: `CASM V0.2.2.1266` banner confirmed (bare `casm` ->
          `CASM: SOURCE FILE REQUIRED`, clean shell return); re-ran the
          `casmopall.s`/`casmopall.ref` native `COMP` round trip under
          `0.2.2` -> `CASM: INPUT VALIDATED` / `FILES COMPARE OK`; re-ran
          `test_casm_opcode` -> `CASM OPCODES: PASS` (197/197), clean shell
          return. One dispatch mistake mid-increment (sent `test_casm_opcode`
          via plain `vice_keyboard_type`, resending literal ASCII `_` instead
          of PETSCII `$A4` -- the same class of error Increment 6 already
          hit once) put the shell into an apparent stall; recovered with one
          soft reset + reboot per the mandatory testing workflow's recovery
          procedure, then redispatched correctly. No production defect;
          WP60's only production change remains the single `CLD` byte from
          Increment 3. Taskwarrior task 40 (`bd441121-dffa-4d69-8f3a-8572e0643322`)
          marked done. **WP60 is complete at CASM `0.2.2` build `1266`.**
          The 4 residual boundary items from Increment 9 (`FORCE_ABS`
          two-pass re-resolution; source 65,535/65,536-byte extent boundary;
          symbol name-length-32 rejection; empty-source-file tooling gap)
          and the separately tracked phantom-EOF-byte defect (Taskwarrior
          UUID `882433f0-cde1-4849-8b3c-df32613518c3`) remain open,
          explicitly deferred rather than blocking this completion. (Note:
          bare Taskwarrior numeric IDs are unstable across sessions as
          tasks complete and free their ID for reuse -- this defect's ID
          has since shifted from 42 to 41; cite the UUID.)
  - [/] Taskwarrior (`f6845310-bcce-4448-b5f2-0aa19a73723b`): WP61
        determinism and remaining boundary spot-checks
    - Plan:
      `brain/plans/2026-08-12-casm-phase11-wp61-determinism-and-boundary-spot-checks.md`
    - User approved the nine-increment plan 2026-08-12 and activated
      Increment 1 only; each later increment remains separately gated by
      the preceding increment's review. Taskwarrior task created dependent
      on completed WP60 (`bd441121-dffa-4d69-8f3a-8572e0643322`).
    - Scope (user-confirmed 2026-08-12): determinism proof (PRG/R6/
      listing/map self-compare) plus the 4 boundary items WP60 Increment 9
      deferred (`FORCE_ABS` two-pass stability; source 65,535/65,536-byte
      extent; symbol/token name-length-32; empty-source-file explicitly
      re-scoped as a tooling gap, not carried forward again). The
      phantom-EOF-byte defect stays out of scope, tracked separately.
    - [/] Increment 1 implementation/verification complete 2026-08-12,
          awaiting user approval. Register at
          `brain/reviews/2026-08-12-casm-phase11-wp61-increment1-scope-register.md`:
          all 5 in-scope items dispositioned with source-trace-confirmed
          mechanisms -- FORCE_ABS derivation (`parser.s:526-575`) confirmed
          pass-invariant by construction (syntactic, not value-based),
          closing an "add" for end-to-end proof only, not a design concern;
          source-extent overflow confirmed to return
          `CASM_DIAG_SOURCE_OFFSET_OVERFLOW` (`$15`) via `slCheckCap`'s
          16-bit-carry check (`source.s:631-643`); token length-32
          rejection confirmed at `lexerTokenAppend` (`lexer.s:525-537`,
          `CASM_TOKEN_TEXT_MAX=31`) with zero existing `lexer.s`-linked
          harness anywhere in `tests/`. Re-surveyed disk free space on
          every candidate: `test.d64` and `casm_overflow_test.d64` remain
          unusable for new files (34 and 7 blocks free respectively,
          `test.d64`'s count drifted 36->34 since WP60's own survey for
          unexplained but harmless BAM-allocation reasons, confirmed
          content-identical); `casm_opcode_test.d64` (489 free) and
          `command64_casm_utils.d64` (245 free) both have ample room;
          `casm_include_test_d64` (542 free, not previously surveyed) is
          proposed as the Increment 6 extent-fixture disk instead of a new
          disk, pending a purpose/capacity check at that increment's
          activation. No production or fixture change. Requesting user
          review before Increment 2 (determinism proof: PRG/R6) activates.
    - [/] Increment 2 implementation/verification complete 2026-08-12,
          awaiting user approval. Record at
          `brain/reviews/2026-08-12-casm-phase11-wp61-increment2-determinism-prg-r6.md`.
          Appended pre-existing fixtures `casmhello.s` (static, no
          relocation) and `casmreloc1.s` (relocatable, real R6 footer) plus
          `casmreloc1.ref` to `casm_opcode_test_d64` (489 -> 480 blocks
          free), avoiding a new disk or multi-drive setup. Live VICE:
          each of `casmhello.s`, `casmreloc1.s`, and the 151-statement
          `casmopall.s` assembled twice to independently named outputs;
          all 3 self-compares (`comp` between the two runs) returned
          `FILES COMPARE OK`; `casmreloc1.s` and `casmopall.s` additionally
          cross-checked against their independently-trusted `.ref` files,
          also `FILES COMPARE OK` -- anchoring the self-compare proof to
          externally-derived bytes, not just internal run-to-run
          consistency. PRG determinism closed (3/3 fixtures spanning
          small-static, small-relocatable, and large-exhaustive shapes);
          R6 relocation determinism closed (1/1 relocatable fixture). No
          production defect; only build-system change is the fixture
          placement above. Requesting user review before Increment 3
          (determinism proof: listing and map) activates.
    - [/] Increment 3 implementation/verification complete 2026-08-12,
          awaiting user approval. Record at
          `brain/reviews/2026-08-12-casm-phase11-wp61-increment3-determinism-listing-map.md`.
          Extended the determinism proof to `/L` and `/M` using the same
          `casmopall.s` fixture on the same already-attached
          `casm_opcode_test.d64`, no new fixture or disk needed. `/L`:
          dual-assembled to `m1.lst`/`m2.lst`, `comp` -> `FILES COMPARE OK`.
          `/M`: dual-assembled and independently decoded both runs' screen
          RAM via `vice_memory_read` -- identical 8-row symbol map
          (`$C033 tg22` through `$C047 tg32`, `008 SYMBOLS`) both times,
          explicitly recorded as manual/live evidence since `/M` writes no
          file to `comp`. No production defect; no production or fixture
          change. **WP61's full determinism charter (PRG, R6, listing, map)
          is now closed.** Requesting user review before Increment 4
          (FORCE_ABS two-pass closure) activates.
    - [x] Increment 4 complete 2026-08-12. Record at
          `brain/reviews/2026-08-12-casm-phase11-wp61-increment4-force-abs-closure.md`.
          New `casmfa2p.s` (`.ORG $0010` / `LDA TARGET` (forward ref) /
          `TARGET: NOP`) + hand-authored `casmfa2p.ref.hex`, joined
          `casm_opcode_test_d64`. Live VICE: assembled twice, `comp` vs the
          trusted reference and self-compare between the two runs both
          `FILES COMPARE OK` -- `LDA TARGET` emitted as 3-byte absolute
          (`AD 13 00`), never shrinking to 2-byte zero-page, closing WP60's
          residual FORCE_ABS two-pass item. No production defect/change.
    - [x] Increment 5 complete 2026-08-12. Record at
          `brain/reviews/2026-08-12-casm-phase11-wp61-increment5-lexer-length32-closure.md`.
          New `tests/src/casm_lexer/casm_lexer.s`, linking only `lexer.s`
          (no parser/source/state.s), local BSS + stub `sourceNextByte`
          feeding a fixed-length identifier byte run through the real
          `lnId` scan loop via `lexerNext`. Joined `casm_listing_test_d64`.
          Live VICE: `CASM LEXER: PASS` (2/2) -- 31 bytes accept
          (length recorded exactly 31), 32 bytes reject
          (`CASM_DIAG_TOKEN_TOO_LONG`, length left at 31, unmodified). No
          production defect/change. Closes WP60's residual symbol/token
          name-length-32 item.
    - [x] Increment 6 complete 2026-08-12. Record at
          `brain/reviews/2026-08-12-casm-phase11-wp61-increment6-source-extent-closure.md`.
          New `casmsrcmax.seq` (exactly 65,535 bytes: `.ORG $C000\n` + 16381
          `NOP\n` lines, `string(REPEAT ...)`-generated for an exact byte
          count) and `casmsrcbit.seq` (exactly 1 byte). Added `command64`
          to `casm_include_test_d64` (previously casm/comp only) so both
          join it directly bootable. Live VICE: `casm casmsrcmax.s` alone
          (65,535 combined) -> `CASM: INPUT VALIDATED`, `xmax.prg`
          committed; `casm casmsrcmax.s casmsrcbit.s` (65,536 combined) ->
          `CASM: SOURCE OFFSET OVERFLOW` (`$15`), no location trailer
          (matches the `casmmfovf1/2` precedent), no partial output
          committed. Confirmed this fires in `sourceLoad`'s raw-streaming
          `slCheckCap` phase, before any lexing -- does not exercise or
          mask the separately-tracked phantom-EOF-byte defect. No
          production defect/change. Closes WP60's residual source-extent
          item.
    - [x] Increment 7 complete 2026-08-12. Record at
          `brain/reviews/2026-08-12-casm-phase11-wp61-increment7-consolidated-verification.md`.
          First full unrestricted rebuild failed (`Dir track full` on
          `test_image_d64`): Increment 4 added `casmfa2p` to
          `CASM_REF_NAMES` without extending the existing
          `casmbig1`/`casmopall` test.d64-exclusion list to cover it,
          overflowing the already-full 144-entry directory. Fixed by
          adding `casmfa2p` to that exclusion list (its source also lives
          only on `casm_opcode_test_d64`) -- a build-system-only fix, no
          production impact, found only because this increment finally ran
          a full unrestricted build. After the fix: clean full build,
          no-change rebuild stable at 1266/unchanged hash, `test.d64`
          re-confirmed at exactly 144/144 content-identical to the WP60
          baseline, `casm.prg` independently re-derived as byte-identical
          (18581 bytes/2806 relocations) -- zero production change through
          Increment 6. Live VICE re-ran the full changed set from the
          clean rebuild: `test_casm_opcode` (197/197),
          `casmopall.s`/`casmreloc1.s`/`casmfa2p.s` each vs their `.ref`
          (`FILES COMPARE OK` all three), `test_casm_lexer` (2/2), and the
          source-extent reject case (`SOURCE OFFSET OVERFLOW`, no partial
          output) -- all clean shell returns.
    - [/] Increment 8 complete 2026-08-12, awaiting user approval: audit
          and walkthrough at
          `brain/walkthroughs/2026-08-12-casm-phase11-wp61-increment8-audit-walkthrough.md`.
          Reconciled the Increment 1 register's 5 in-scope items against
          Increments 2-6: all 5 closed (determinism; FORCE_ABS two-pass;
          source extent; symbol/token length-32; empty-source-file closed
          by re-scope at Increment 1 itself). One build-system-only defect
          found and fixed within WP61 (Increment 7's `test.d64` directory-
          overflow oversight); zero production defects; `casm.prg` remains
          byte-identical to its WP60 `0.2.2` state throughout. No version
          bump due (no production change occurred, per the user-confirmed
          bump-only-if-changed policy). **User approved WP61 completion
          2026-08-12.** Taskwarrior task
          `f6845310-bcce-4448-b5f2-0aa19a73723b` marked done. **WP61 is
          complete at CASM `0.2.2` build `1266`.** The empty-source-file
          boundary row remains closed by re-scope (tooling gap) and the
          phantom-EOF-byte defect remains separately tracked (Taskwarrior
          UUID `882433f0-cde1-4849-8b3c-df32613518c3`), neither blocking
          this completion.
  - [/] Taskwarrior (`27332a0c-7bb6-4c2e-b455-6f5e03b4b84e`): WP62
        documentation sync
    - Plan: `brain/plans/2026-08-12-casm-phase11-wp62-documentation-sync.md`
    - User approved the seven-increment plan 2026-08-12 and activated
      Increment 1 only; each later increment remains separately gated by
      the preceding increment's review. Taskwarrior task created dependent
      on completed WP61 (`f6845310-bcce-4448-b5f2-0aa19a73723b`).
    - Scope (user-confirmed 2026-08-12): full clean-room re-sync of
      `brain/KNOWLEDGE.md` (backfilling Phase 4, Phase 10, **and** Phase 11
      -- a bigger gap than WP56 originally flagged, found during this
      plan's own research), `wiki/casm-programmers-reference.md`,
      `wiki/casm-utility.md`/`docs/casm-utility.md` (kept in sync, not
      consolidated), `CHANGELOG.md` (add the missing WP61 entry), and
      `src/external/casm/AGENTS.md`. No CASM version bump (documentation-
      only, matching WP56's precedent).
    - [/] Increment 1 implementation/verification complete 2026-08-12,
          awaiting user approval. Register at
          `brain/reviews/2026-08-12-casm-phase11-wp62-increment1-staleness-register.md`.
          Clean-room re-read of all 6 in-scope items. Confirmed
          `KNOWLEDGE.md`'s CASM sections stop at Phase 9 WP48 with no Phase
          10/11 content and pinned exact insertion points (Phase 10 after
          the Phase 9 WP48 section and after the interleaved DASH section,
          Phase 11 last, both chronological by close date). Cataloged 6
          discrepancies in `wiki/casm-programmers-reference.md` (stale
          version/build in 3 places, a missing `CLD` in the documented
          `start:` sequence, undocumented WP60 opcode-certification
          strength, two undocumented known non-critical bugs) and 3 in
          `wiki/casm-utility.md`/`docs/casm-utility.md` (same version
          staleness and missing known-bugs disclosure). Confirmed
          `CHANGELOG.md`'s WP61 gap. Found `src/external/casm/AGENTS.md`
          more stale than the plan anticipated: it still describes Phase 10
          (WP50-55) as "remain inactive," has zero Phase 11 content, and
          carries a `0.1.9`-threshold version-migration note now moot at
          `0.2.2` -- Increment 6 will need a real rewrite, not a light
          touch. No documentation change made in this increment. Requesting
          user review before Increment 2 (`KNOWLEDGE.md` backfill)
          activates.
    - [x] Increments 2-6 complete 2026-08-12, implemented via two parallel
          background agents per user direction (Agent A: Increments 2 and
          6; Agent B: Increments 3-5), then independently verified by this
          agent against the Increment 1 register and current source before
          committing.
          - **Increment 2** (`brain/KNOWLEDGE.md`): added
            `### CASM Phase 4 Parser/Opcode/Emission Contract`,
            `### CASM Phase 10 Symbol Map/Listing Contract`, and
            `### CASM Phase 11 Base-Release Hardening Contract`, at the
            exact pinned insertion points (Phase 4 between Phase 3/5;
            Phase 10 after the interleaved DASH section; Phase 11 last,
            before `## C64 Platform Constraints Discovered`) -- verified
            by grepping the file's heading order post-edit. Phase 4
            content spot-checked against
            `brain/plans/2026-07-20-casm-phase4-wp14-orchestration-binary-validation.md`
            (the `CASM_MODE_ZEROPAGE_Y` ca65-negative-shift defect, the
            bare-`.ORG`-origin-zero defect, and the `0.1.17` completion
            version) -- all confirmed accurate.
          - **Increment 3** (`wiki/casm-programmers-reference.md`): fixed
            all 6 cataloged discrepancies -- version/build in 3 places,
            the missing `CLD` in the documented `start:` sequence
            (verified directly against `casm.s:118-128`), WP60's
            certification strength, and both known-bug disclosures, plus
            a new determinism note.
          - **Increment 4** (`wiki/casm-utility.md`/`docs/casm-utility.md`):
            version/banner fix, known-bugs disclosure in end-user framing;
            confirmed byte-identical after edit (`diff` clean).
          - **Increment 5** (`CHANGELOG.md`): added the missing WP61
            entry. Caught and fixed one inaccuracy during review -- the
            agent's draft said "closed 4... the 5th... re-scoped" (implying
            5 total items), corrected to the accurate "closed the 4
            items... plus [the re-scoped one]" (4 total: 3 actioned + 1
            re-scoped), matching WP61's own walkthrough.
          - **Increment 6** (`src/external/casm/AGENTS.md`): rewrote the
            stale "WP50-WP55 remain inactive" framing into historical
            record, collapsed the 5 "approved-but-blocked" WP50-54 bullets
            into one durable-facts block (dropping only the gating
            language), added Phase 11 content, and resolved the `0.1.9`
            version-migration note by restating it as reapplying at the
            next analogous threshold (`0.2.9`) rather than marking it
            moot -- reviewed and accepted as sound reasoning, not just
            hedging.
          - No production source change; no CASM version bump (matches
            WP56's precedent for documentation-only work). Requesting user
            review before Increment 7 (audit and walkthrough) activates.
  - WP63 remains unplanned in detail, per this project's
    per-work-package-plan-approval requirement.

# Deferred Optional Work

- [ ] Taskwarrior #33 (`1acb36e3-2c0e-4f24-998b-279b2578bee4`): CASM optional
      progress and processing indication feature
  - Plan: `brain/plans/2026-07-29-casm-feature-progress-indication.md`
  - Task: `wiki/tasks/casm-progress-indication.md`
  - This feature is outside the master plan's numbered phases and does not
    replace Phase 10, Symbol Map and Listing.
  - [ ] Complete design/ABI review after CASM Phase 9 closes.
  - [ ] Implement bounded load, include, pass, and output progress.
  - [ ] Meet the 5% representative and 10% stress slowdown limits.
  - [ ] Complete full implementation review before runtime acceptance or merge.

- [ ] Taskwarrior #40 (`54dff46d-b802-4534-9b29-fc78bb907e26`): CASM optional
      build duration display on completion (success and failure)
  - Backlog entry only, recorded 2026-08-08:
    `wiki/tasks/casm.md` "Future Feature Backlog" section
  - Distinct from the progress-indication feature above, which explicitly
    excludes elapsed time; needs its own CIA-timer-ownership decision
  - No plan drafted yet

- [ ] Taskwarrior #41 (`0e0de8db-e161-49e5-8da0-3eb3e2146945`): CASM optional
      real-time `/M` symbol map emission during assembly
  - Backlog entry only, recorded 2026-08-08:
    `wiki/tasks/casm.md` "Future Feature Backlog" section
  - Today `/M` (`casm.s:318-329`) batch-prints the full symbol map via
    `mapPrint` once, after Pass 2 and `/L` are committed; this idea emits
    each row as it is defined instead
  - No plan drafted yet
