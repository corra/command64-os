# CASM Native Assembler

Status: [/]
Taskwarrior: 29 (`099257cc`)
Plan: `brain/plans/2026-07-16-casm-phase3-source-stream-lexer.md`

## Goal

Implement `casm` as a native Command 64 external application that assembles
documented 6502/6510 source on the C64 and emits static or Command 64
R6-relocatable PRG files.

## Current Milestone

Phase 3 extends the managed Phase 2 input foundation with a rewindable,
file-aware source stream and bounded minimal lexer. It normalizes logical
newlines, tracks one-based source locations, exposes deterministic rewind, and
produces a temporary token dump. It does not parse statements, evaluate
expressions, define symbols, emit machine code, or create production output.

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

Plan: `brain/plans/2026-07-17-casm-phase4-statement-parser-opcode-table.md`

## Tasks

- [x] Task UUID `31bb2198`: implement statement parser and syntax validation.
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
- [x] Task UUID `501bc58c`: implement opcode table and addressing mode matcher.
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
- [x] Task UUID `83ab4f2d`: implement numeric directives and byte/word emission.
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
- [ ] Task UUID `8612c2a2-afdd-4c8f-bf42-4947bc486f97`: verify artifacts and obtain user runtime confirmation.

## Phase 4 Acceptance

- [ ] Syntactic errors and operand delimiters are fully validated.
- [ ] 6502 addressing mode mapping and numeric size boundaries are enforced.
- [ ] Relative branch distance checks are validated.
- [ ] Output PRG files match reference binary files byte-for-byte.
- [ ] CASM remains within the approved MAIN envelope (raised $2000 -> $2800 in
      WP13 to fit the emission engine).
- [ ] Build, artifact, and build-number checks pass.
- [ ] The user completes the runtime walkthrough and approves Phase 4.
