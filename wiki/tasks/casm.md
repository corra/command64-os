# CASM Native Assembler

Status: [/]
Taskwarrior: 30 (`6b72d639`)
Plan: `brain/plans/2026-07-20-casm-phase5-minimal-expression-evaluator.md`

## Goal

Implement `casm` as a native Command 64 external application that assembles
documented 6502/6510 source on the C64 and emits static or Command 64
R6-relocatable PRG files.

## Current Milestone

Phase 5 adds a bounded expression evaluator and resolver boundary without
implementing symbol storage, two-pass assembly, or relocation emission.

**Phase 4 is complete**, approved by the user on 2026-07-21 at CASM `0.1.17`
build 1079. WP11-WP15 are all closed.

WP16-WP18 are complete. CASM is `0.1.20` build 1085. WP19 is next but remains
pending a reconciled detailed plan; WP20-WP21 remain blocked.

## Phase 1 Prerequisite

- [x] User confirms the Phase 0 memory, resource, diagnostic, version, and
      initial link-size contracts required by the Phase 1 plan.

Source implementation must not begin until this gate is satisfied.

## Phase 1 Subtasks

- [x] Task UUID `ef6a001e`: create synchronized task records and the
      CASM-local DOX contract.
- [x] Task UUID `7b318ab7`: declare the approved zero-page, bounded base-RAM,
      and module ABI.
- [x] Task UUID `05e59de2`: implement central resource ownership, cleanup,
      and exit paths.
- [x] Task UUID `8891fe27`: implement minimal fixed-string diagnostics.
- [x] Task UUID `eb83b449`: implement the PRG entry point and complete version
      banner.
- [x] Task UUID `c6c3b55e`: register the ca65 target and add CASM to the
      release disk.
- [x] Task UUID `5a0e36c5`: verify configure, standalone build, R6 artifact,
      and disk image.
- [x] Task UUID `161ed5a9`: record the walkthrough and obtain user runtime
      confirmation.

## Phase 1 Acceptance

- [x] CASM-local DOX and memory ownership are documented.
- [x] `cmake --build build --target casm` succeeds.
- [x] The generated `casm.prg` has a valid PRG header and R6 footer.
- [x] A no-change rebuild does not increment `BUILD_CASM`.
- [x] `cmake --build build --target image_d64` succeeds.
- [x] The release disk directory contains `CASM` without losing another app.
- [x] All terminal paths pass through repeat-safe central cleanup.
- [x] The user launches CASM, confirms the version banner, and confirms safe
      return to an intact shell twice in succession.
- [x] A walkthrough records build evidence and manual confirmation steps.
- [x] The user explicitly approves marking Phase 1 done.

## Completion

Completed 2026-07-16. The user confirmed all runtime walkthrough steps passed
in local emulation and approved marking Phase 1 done.

## Phase 2 Prerequisite

- [x] User approved the Phase 0B command grammar, filename and input-buffer
      limits, read/EOF behavior, managed file ownership, and output-runtime
      deferral defined by the Phase 2 plan.

Approved 2026-07-16 before Phase 2 source implementation.

## Phase 2 Subtasks

- [x] Task UUID `ba51bd58`: synchronize task records and record Phase 0B
      approval.
- [x] Task UUID `79d7f6aa`: declare the shared CLI, file, and stream ABI.
- [x] Task UUID `5d997dfd`: implement the bounded command-line parser.
- [x] Task UUID `8e0711ad`: implement managed native file wrappers.
- [x] Task UUID `b7d0e543`: implement real central file-handle cleanup.
- [x] Task UUID `3bc11e77`: extend CLI and file-service diagnostics.
- [x] Task UUID `1d2c1761`: integrate Phase 2 entry-point orchestration.
- [x] Task UUID `0870f804`: correct EOF carry propagation and preserve the
      registered resource slot across `DOS_CLOSE_FILE`; build 1011 runtime
      verified by the user.
- [x] Task UUID `9e4d8175`: verify artifacts and obtain user runtime
      confirmation.

## Phase 2 Acceptance

- [x] CLI parsing passes every approved bounded acceptance case.
- [x] Input streaming handles short-final-block, exact-block, and multi-block
      files. The user accepted `CANNOT OPEN INPUT` for the zero-block
      `casmempty` directory entry as a Commodore DOS device limitation.
- [x] Every open handle is registered or compensating-closed.
- [x] Explicit close and fatal cleanup leave no confirmed handle leak.
- [x] Primary diagnostics survive secondary cleanup failures by static audit;
      runtime primary diagnostics remained stable across all exercised errors.
- [x] CASM remains within the measured `$1000` `MAIN` envelope with 1,391 bytes
      of combined headroom.
- [x] `cmake --build build --target casm` succeeds and the R6 artifact is
      structurally valid.
- [x] A no-change rebuild does not increment `BUILD_CASM`.
- [x] `cmake --build build --target image_d64` succeeds without losing another
      application.
- [x] A walkthrough records build evidence and manual confirmation steps.
- [x] The user explicitly approved marking Phase 2 done on 2026-07-16.

## Verification Policy

- Do not use the broken `c64-testing` MCP.
- Do not use a web emulator.
- Build and inspect artifacts with repository tooling.
- The user performs runtime verification in the supported local emulator or
  on hardware.
- Do not mark the milestone done before the user confirms the walkthrough.

The generated `test.d64` provides `casmempty`, `casmshort`, `casm256`, and
`casmmulti` SEQ fixtures for the zero-block limitation, short,
exact-256-byte, and multi-block input cases.

The Phase 2 walkthrough and confirmed CLI matrix are recorded in
`brain/walkthroughs/2026-07-16-casm-phase2-cli-file-services.md`.

Phase 2 completed on 2026-07-16 after the user confirmed the full build 1014
walkthrough and approved closing the milestone. Later assembler phases remain
separate prerequisite-gated work.

## Phase 3 Prerequisite

- [x] User approved the Phase 0C.1 source-stream, newline, location, token,
      numeric-shape, and bounds contracts in the Phase 3 plan.
- [x] User approved beginning Work Package 1 on 2026-07-16.

## Phase 3 Subtasks

- [x] Task UUID `65832339`: synchronize task records, dependency corrections,
      and approved Phase 0C.1 contracts.
- [x] Task UUID `9ab8caf3`: investigate DEBUG assembler reuse feasibility.
- [x] Task UUID `9e0c03f3`: declare shared source/lexer ABI and bounded state.
- [x] Task UUID `fcb0e164`: implement the rewindable source backend. `source.s`
      created, entry point routed through the source API, `$15` overflow
      mapping. User runtime fixture matrix confirmed and completion approved on
      2026-07-16; build 1020 advanced CASM to `0.1.6`.
- [x] Task UUID `9c733c1a`: implement newline normalization and provenance.
      CR/LF/CRLF collapsing with the pending-CR latch (including the block-split
      case), final-CR resolution, line/column provenance, `sourceGetLocation`,
      and five newline fixtures. User runtime matrix confirmed and completion
      approved on 2026-07-16; build 1022 advanced CASM to `0.1.7`.
- [x] Task UUID `cda20f5b`: implement deterministic rewind and bounded line API.
      Option A partitioned single buffer, `sourceRewind`, `sourceNextLine`,
      `inputStreamReadInto`, absolute cursor, and the `$1000` → `$2000` envelope
      increase. User runtime matrix confirmed and completion approved on
      2026-07-17; build 1025 advanced CASM to `0.1.8`.
- [x] Task UUID `7196a56f`: implement the minimal lexer core (Option 1
      static-only). `lexer.s` with the lookahead, token primitives,
      whitespace/comment skipping, and punctuation tokens, plus the
      `CASM_LEXER_STATE_*` enum. User non-regression confirmed and completion
      approved on 2026-07-17; build 1028, CASM at `0.1.9`.
- [x] Task UUID `9e1a1a12`: implement textual and numeric token scanning.
- [x] Task UUID `3367d36d`: implement mnemonic classification.
- [x] Task UUID `a68d3603`: integrate diagnostics and temporary token dump.
- [x] Task UUID `178b0884`: verify artifacts and obtain user runtime
      confirmation.

## Phase 3 Acceptance

- [x] Phase 0C.1 and the DEBUG reuse decision are recorded.
- [x] Source traversal and rewind are byte-, newline-, and location-identical.
- [x] CR, LF, and CRLF normalize correctly across input-block boundaries.
- [x] Lines, tokens, offsets, cursors, and locations fail before overflow.
- [x] All approved token classes and lexical failure cases are deterministic.
- [x] The temporary token dump reports correct file, line, and column data.
- [x] CASM stays within the approved $2000 MAIN envelope.
- [x] Build, artifact, release-disk, and no-change build checks pass.
- [x] The user completes the runtime walkthrough.
- [x] The user explicitly approves marking Phase 3 done.

# CASM Phase 4 — Statement Parser, Opcode Table, and Numeric Static Assembly

Milestone task UUID: `4796b60c-5f4a-43c7-8270-436075bb3f7b` (created during WP15
increment 2; Phases 1-3 each had a parent record but Phase 4 had none, leaving
WP11-WP15 orphaned. The completed Phase 3 UUID `099257cc` was deliberately not
reused.)

Plan: `brain/plans/2026-07-17-casm-phase4-statement-parser-opcode-table.md`
WP15 plan: `brain/plans/2026-07-20-casm-phase4-wp15-phase-verification-closeout.md`

## Tasks

- [x] Task UUID `82a11475`: implement statement parser and syntax validation.
      `parser.s` with `parserParseStatement` (LL(1) statement/operand grammar
      over the lexer's single-token buffer) and `parseNumericValue` (decimal/
      hex/binary to 16-bit with a 24-bit sticky-overflow bounds check).
      `CasmParserStmt` record, opkind equates, and diagnostics `$1C`–`$1E`
      added. A temporary parse driver in `casm.s` replaced the WP10 token dump
      so syntax diagnostics surface through the fatal path; WP14 replaces it.
      Targeted fixtures (`casmwp11` plus `casmerr1`–`casmerr5`) added. User
      runtime confirmed the valid fixture prints `INPUT VALIDATED`, each error
      fixture prints its diagnostic, and `casmshort` correctly reports
      `SYNTAX ERROR` on its deferred-label `JMP START_LABEL`. Completion
      approved on 2026-07-17; build 1042 advanced CASM to `0.1.13`.
- [x] Task UUID `a3f90f05`: implement opcode table and addressing mode matcher.
      `opcodes.s` with the compressed legal-6502 table (56 mnemonic mode masks,
      run offsets, 151 packed opcodes) and `opcodesFindOpcode`, which resolves
      the WP11 operand kind to a concrete `CASM_MODE_*` (with ZP/absolute
      promotion and branch detection), verifies mnemonic support, and records
      opcode/mode/length in the exported `CasmInsn`. Added `CASM_MODE_*`,
      `CasmInsn`, and `CASM_DIAG_INVALID_ADDR_MODE` ($1F); reused `$1E` for
      8-bit operand overflow. Relative displacement/range check deferred to
      WP13 per the amended parent plan. The temporary `casm.s` driver now runs
      the matcher on mnemonic statements. Fixtures `casmam1`/`casmam2`
      (invalid mode) and `casmrng1` (immediate 8-bit overflow) added. User
      runtime confirmed all cases. Completion approved on 2026-07-17; build
      1047 advanced CASM to `0.1.14`.
- [x] Task UUID `ded1cfd9`: implement numeric directives and byte/word emission.
      New `emit.s` engine: `CasmPc` tracking, PRG load-address header + bounded
      64-byte staged writes, `.ORG`/`.BYTE`/`.WORD` handling, per-instruction
      operand encoding, and the relative-branch displacement + range check
      moved here from WP12. Added diagnostics `$20`–`$23`; refined the parser to
      leave `.BYTE`/`.WORD` operand lists for the emitter; made output
      operational (emit by default, `/S` accepted, `/M`/`/L` still rejected).
      The MAIN envelope was raised `$2000`→`$2800` (approved) to fit emission.
      Fixtures `casmemit1` (valid → PRG), `casmorg1`/`casmorg2`/`casmbr1`
      (error paths), and `casmhello` (runnable print-and-exit demo). User
      runtime confirmed all cases. Completion approved on 2026-07-17; build
      1053 advanced CASM to `0.1.15`.
- [x] Task UUID `3e4eab43-0f48-4db5-843f-c749bcb79d8a`: execute orchestration and
      end-to-end binary validation. Added `scripts/hex_manifest_to_bin.py` (a
      strict, 6502-agnostic manifest→binary converter with byte-count and
      SHA-256 checks) and three reviewed reference manifests — `casmemit1.ref`
      (20 bytes), `casmhello.ref` (40), `casmmodes.ref` (30, one legal statement
      per `CASM_MODE_*`) — each hand-assembled from the 6502 instruction set
      rather than from CASM, generated at build time and installed on `test.d64`
      for native `COMP`. The WP13 "temporary driver" was audited against the
      production orchestration contract, found to already satisfy it, and so was
      documented in place; no `compiler.s` was extracted. Added 23
      acceptance-matrix fixtures (delimiter, `.ORG`, immediate/ZP boundaries,
      branch ±128/±129, PC at and past `$FFFF`, partial-output cleanup). Two
      defects found and fixed: a bare `.ORG` silently assembled as `.ORG $0000`
      (`emitOrg` now requires `CASM_OPKIND_ABSOLUTE`), and
      `CASM_MODE_ZEROPAGE_Y` was unreachable so every `LDX $10,Y` assembled as
      absolute,Y — a miscompilation, since zero-page,Y wraps within page zero —
      now fixed and guarded by build-breaking asserts. User runtime confirmed
      the full matrix. Completion approved on 2026-07-21; build 1078 advanced
      CASM to `0.1.16`.
- [x] Task UUID `8612c2a2-afdd-4c8f-bf42-4947bc486f97`: verify artifacts and
      obtain user runtime confirmation. Independent acceptance audit found and
      corrected three record defects (missing Phase 4 parent milestone; three
      phantom wiki UUIDs for WP11-WP13; stale Phase 3 milestone text). Static
      audit clean: 52/52 carry sites, no `SED`, balanced stack, sound output
      lifecycle and diagnostic preservation. Both link configs fit `$2800` with
      408 bytes headroom; R6 artifact cross-checked field by field; all three
      trusted references verified end to end by independent transcription.
      WP14's two open evidence gaps closed: G4.2 confirmed
      `OPERAND OUT OF RANGE`; G7 confirmed CASM does not clobber an existing
      output file. User runtime confirmed and completion approved on
      2026-07-21; build 1079 advanced CASM to `0.1.17`.
      Walkthrough:
      `brain/walkthroughs/2026-07-20-casm-phase4-wp15-phase-verification-closeout.md`

## Phase 4 Acceptance

- [x] Syntactic errors and operand delimiters are fully validated.
- [x] 6502 addressing mode mapping and numeric size boundaries are enforced.
- [x] Relative branch distance checks are validated.
- [x] Output PRG files match reference binary files byte-for-byte.
- [x] CASM remains within the approved MAIN envelope (raised $2000 -> $2800 in
      WP13 to fit the emission engine).
- [x] Build, artifact, and build-number checks pass.
- [x] The user completes the runtime walkthrough and approves Phase 4.

**Phase 4 complete — approved by the user on 2026-07-21 at CASM `0.1.17`
build 1079.** Milestone `4796b60c-5f4a-43c7-8270-436075bb3f7b`.

# CASM Phase 5 - Minimal Expression Evaluator

Parent Taskwarrior UUID: `6b72d639-53d0-4d1a-92ba-8c4d56096388`

Plan: `brain/plans/2026-07-20-casm-phase5-minimal-expression-evaluator.md`

## Phase 5 Work Packages

- [x] `0062fd20-929d-4ffd-a2b5-032db5ec4109`: WP16 prerequisite
      reconciliation and Phase 0C.3 freeze. Recovery review preserved all
      existing UUIDs, reopened incorrectly completed WP19, stopped premature
      downstream starts, and encoded sequential Taskwarrior dependencies.
      User approved completion; CASM advanced to `0.1.18` build 1080.
- [x] `3b09ea77-c325-4072-90fc-9812181a4e04`: WP17 expression ABI and bounded
      storage. Added the exact nine-byte ABI and bounded accessors; user approved
      completion at `0.1.19` build 1082.
- [x] `8f9467b6-e37d-4701-a4a6-6f90bd8fbf5b`: WP18 numeric primary and checked
      arithmetic core. Numeric compatibility, checked helpers, diagnostics, and
      fixtures approved complete at `0.1.20` build 1085.
- [x] `4acf22c2-8253-4673-918a-8dd38cc18221`: WP19 symbol, extraction, and
      resolver behavior. Active on `feature/casm-phase5-wp19` from `755fc45`;
      test plan, deterministic resolver, and fixtures remain WP20 scope. User
      approved expanding CASM MAIN from `$2800` to `$2A00` for the evaluator and
      declaring the shared five-byte resolver callback output ABI. Candidate
      build 1088 passed both links and the test image with 298-byte headroom.
      User approved completion at `0.1.21` build 1089.
- [x] `41d120ed-b550-4551-9694-e66bd6f65cef`: WP20 parser adapter and expression
      fixture harness. Active on `feature/casm-phase5-wp20` from `56d8078` with
      approved production adapter and standalone fixture-harness scope.
      Candidate builds pass with 243-byte CASM headroom; user confirmed the
      harness, trusted adapter reference, resolver failure, and cleanup matrix.
      Completion approved at `0.1.22` build 1093.
- [x] `225a69ce-b46c-404d-a86b-d2c4494e9c3f`: WP21 verification, walkthrough,
      and completion gate. Active on `feature/casm-phase5-wp21` from `8afb438`.
      Thirty-case harness, independent audit, and both images pass; consolidated
      runtime gate passed with all five references and cleanup confirmed. The
      `0.1.23.1094` dry run passed and was restored for approval. User approved
      completion; final `0.1.23` build 1094 is stable and both images pass.

## Phase 5 Acceptance

- [x] Phase 0C.3 contract and task hierarchy are frozen by WP16.
- [x] Expression ABI and storage remain bounded within the approved MAIN area.
- [x] Numeric behavior remains byte-compatible with Phase 4.
- [x] Resolved, unresolved, relocatable, extraction, and addend cases pass.
- [x] Existing Phase 4 reference programs remain byte-identical.
- [x] User completed the WP21 runtime walkthrough and approved Phase 5.

# CASM Phase 6A - VMM Storage Foundation

Note: this is CASM-local phase numbering, distinct from the unrelated,
already-completed top-level project phases of the same name
("Phase 6A: App Manager", "Phase 6B: Binary Relocator") recorded elsewhere in
`brain/KNOWLEDGE.md`. Always write "CASM Phase 6A" in full to avoid ambiguity.

Parent Taskwarrior UUID: `d68e6c58-ac89-44f4-81a2-40b14093585b`

Parent plan:
`brain/plans/2026-07-21-casm-phase6-vmm-storage-and-symbol-table.md`
WP22 plan:
`brain/plans/2026-07-21-casm-phase6-wp22-prerequisite-reconciliation.md`

## Phase 6A Work Packages

- [x] `eb7541e5-c3aa-4528-bdcd-2571d96688d9`: WP22 prerequisite reconciliation
      and Phase 0C.4 freeze. Active on `feature/casm-phase6-wp22` from
      `dcb74bb`. Researched the OS VMM primitive contract directly from
      `src/command64/vmm.asm`: confirmed the existing 3-byte
      `CasmVmmRegistry` record already matches `DOS_FREE_MEM`'s real input
      (SegHi/Bank) and needs no growth; froze a new 65536-byte single-
      allocation addressing cap (the 16-bit `Off` cursor cannot reach further
      from a fixed SegHi/Bank pair); confirmed the OS performs no bounds
      checking on `DOS_VMM_READ`/`WRITE`, so CASM's windowed wrapper must
      self-enforce it; and documented that `VMM_ERR_INVALID` is ambiguous
      between "no REU" and "zero-paragraph request". Deferred the MAIN-
      envelope-size and literal diagnostic-value decisions to WP23, matching
      how WP13/WP19 made those calls inside their own implementing package.
      Defined the nine-case fixture matrix binding on WP23-WP25. Dry-run
      `0.1.24.1095` differed from baseline by exactly 2 bytes (version/build
      digits only); user confirmed the runtime banner at the restored
      baseline before approval. User approved completion; final `0.1.24`
      build 1095 verified, no-change rebuild stable, both images pass.
- [x] `8782e75d-d935-4e15-bf3c-d0488a1533a8`: WP23 VMM allocation core. Plan
      approved as drafted (static verification only, no runtime fixtures).
      Active on `feature/casm-phase6-wp23` from `feature/casm-phase6-wp22` at
      `d0878d6`, CASM `0.1.24` build 1095 baseline. Created `vmm_store.s`
      (`vmmStoreAlloc`/`vmmStoreFree`) wired to `DOS_ALLOC_MEM`/`DOS_FREE_MEM`;
      replaced `cleanupVmmStub` with a real free in `resourcesCleanup`. No
      16-bit byte count can exceed the 65536-byte cap after rounding, so the
      plan's proposed `CASM_DIAG_VMM_ALLOC_TOO_LARGE` was dropped as
      unreachable; carry-safe rounding clamps the one wraparound-prone input
      range instead, and a zero-byte-count request is rejected locally so a
      later `VMM_ERR_INVALID` stays unambiguous. Reserved diagnostics
      `$28`-`$2B`. Measured MAIN usage: 10,647/10,752 bytes, 105 bytes free —
      no size change needed. User ran a VICE sanity check (CASM against a
      trusted fixture) confirming clean assemble/exit, then approved the
      walkthrough and completion. Final `0.1.25` build 1097 matches the
      dry-run PRG hash exactly; no-change rebuild stable; both images pass.
      Walkthrough:
      `brain/walkthroughs/2026-07-21-casm-phase6-wp23-vmm-allocation-core.md`.
      WP23 is complete; WP24 (`228daccc`) is unblocked but requires its own
      separate plan approval before activation.
- [x] `228daccc-f389-48cf-bd52-9f1ac610234a`: WP24 windowed transfer and
      replay. Plan approved as drafted:
      `brain/plans/2026-07-21-casm-phase6-wp24-windowed-transfer-and-replay.md`.
      Active on `feature/casm-phase6-wp24` from `a60cb89`, CASM `0.1.25`
      build 1097 baseline. Reconciled a real gap the WP22 freeze left open:
      the mandated windowed-transfer bounds check has no registry field to
      read a granted size from; growing `CASM_VMM_REC_SIZE` from 3 to 4
      bytes (adds a page-count field) while keeping `resourceRegisterVmm`
      the registry's sole writer. Staging buffer size deferred to a real
      link measurement; bounds-violation diagnostic shares
      `CASM_DIAG_VMM_TRANSFER_FAILED` with a genuine OS-level rejection.
      Implemented `vmmWindowRead`/`vmmWindowWrite`/`vmmReplay` with a
      dedicated 32-byte `CasmVmmBuffer`, reusing already-reserved `$78-$7F`
      scratch (no new zero-page byte). Measured MAIN overflow (123 bytes);
      user approved `$2A00` -> `$2B00` (133 bytes free). User ran a VICE
      sanity check and confirmed clean assemble/exit. Completion dry-run
      `0.1.26.1099` verified (2-byte diff, no-change rebuild stable);
      baseline `0.1.25.1098` restored exactly. Walkthrough:
      `brain/walkthroughs/2026-07-21-casm-phase6-wp24-windowed-transfer-and-replay.md`.
      User approved completion. Final `0.1.26` build 1099 matches the
      dry-run PRG hash exactly; no-change rebuild stable; both images pass.
      WP24 is complete; WP25 (`544a04bd`) is unblocked but requires its own
      separate plan approval before activation.
- [ ] `544a04bd-4ccb-47c6-9013-8af57aa37353`: WP25 verification, walkthrough,
      and completion gate.

## Phase 6A Acceptance

- [x] Phase 0C.4 VMM record contract and task hierarchy are frozen by WP22.
- [x] Real `DOS_ALLOC_MEM`/`DOS_FREE_MEM` wiring replaces `cleanupVmmStub`
      (WP23).
- [x] Windowed `DOS_VMM_READ`/`DOS_VMM_WRITE` transfers are bounds-checked by
      CASM against each allocation's granted size (WP24).
- [ ] Bounded VMM records are written, read, and replayed without depending
      on source or symbol semantics (code exists since WP24; runtime
      verification is WP25's job).
- [ ] No-REU and allocation-exhaustion diagnostics are stable and exit
      cleanly with no partial ownership.
- [ ] User completes the WP25 runtime walkthrough and approves CASM
      Phase 6A.

CASM Phase 6B (symbol table and two-pass assembly) remains a separately
gated phase; its work packages (WP26-WP31) are reserved in the parent plan
but not yet created in Taskwarrior. CASM Phase 6B may not begin before CASM
Phase 6A's own completion gate and explicit user approval.
