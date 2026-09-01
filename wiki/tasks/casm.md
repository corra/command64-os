# CASM Native Assembler

Status: [/]
Taskwarrior: Phase 14 parent (`4cf10e7c-9365-46cf-94e1-5e4bd8d44635`)
Plan: `brain/plans/2026-09-01-casm-phase14-local-anonymous-labels.md`

## Goal

Implement `casm` as a native Command 64 external application that assembles
documented 6502/6510 source on the C64 and emits static or Command 64
R6-relocatable PRG files.

## Current Milestone

**Phase 14 (Local Labels) is underway**, approved 2026-09-01. Adds ca65
`@name` cheap-local labels scoped to the nearest preceding global label
(anonymous `:`/`:+`/`:-` labels are explicitly deferred to a later phase).
WP86 (design freeze: new symbol-record scope field, LOCAL flag, four new
diagnostic identifiers, no behavior change) is source-complete and
build-verified, awaiting sign-off. WP87-92 remain (lexer, symbol-layer
scope filtering, pass-driver wiring + production fixtures, `/M` map
rendering, DASH adoption, consolidated completion gate). Plan:
`brain/plans/2026-09-01-casm-phase14-local-anonymous-labels.md`. WP86
walkthrough:
`brain/walkthroughs/2026-09-01-casm-phase14-wp86-design-freeze.md`.

**The optional progress and processing indication feature is complete**,
user-approved 2026-08-31 at CASM `0.4.0` -> `0.5.0` build `1380`. It is
outside the master plan's numbered phases: it adds an in-place transient
status line and the `P1:`/`P2:`/`LOAD`/`WRITE`/`DONE` persistent lines
while CASM assembles, with byte-identical assembled output. Delivered over
eleven separately-approved increments, closing with a full implementation
review (three doc/robustness findings fixed) and a fresh consolidated
31-harness + 10-`casmpg*`-fixture live re-verification. Final walkthrough:
`brain/walkthroughs/2026-08-24-casm-progress-increment11-completion-gate.md`.
See the "Optional Feature - Progress and Processing Indication" section
below and `wiki/tasks/casm-progress-indication.md`.

**Phase 12 is complete**, user-approved 2026-08-20 at CASM `0.3.0` build
`1324` (WP64-76, including WP71's full DASH adoption and WP76's
corrective forward-reference Pass 1/2 width-agreement fix). Final
walkthrough: `brain/walkthroughs/2026-08-20-casm-phase12-wp75-
verification-walkthrough-completion-gate.md`.

**Phase 13 (Data Construction Directives) is complete**, user-approved
2026-08-21 at CASM `0.4.0` build `1349` (WP81-85: `.RES`/`.FILL`/`.ALIGN`,
`.INCBIN`, `.ASSERT`, DASH adoption of `.RES`, and a consolidated
completion gate covering all 29 `test_casm_*` harnesses and all 14 Phase
13 production fixtures). Final walkthrough: `brain/walkthroughs/
2026-08-21-casm-phase13-wp85-consolidated-completion.md`.

An unnumbered interim hardening effort (WP77-WP80, deliberately not "Phase
13" — that name/number stays reserved for the master plan's Data
Construction Directives, see `brain/plans/2026-07-16-casm-assembler-
implementation-plan.md:468`) was approved 2026-08-20:
`brain/plans/2026-08-20-casm-post-phase12-hardening.md`.

- [x] WP80 **`.TEXT` disposition closed, user-approved 2026-08-20** (no
      Taskwarrior task; documentation only). Decision: `.BYTE "string"`
      literals (WP74) remain the sole, deduplicated string spelling; `.TEXT`
      is not added. No `.TEXT` implementation ever existed in
      `src/external/casm/` to remove.
- [x] WP77 **named-constant chaining parse failure fixed, user-approved
      2026-08-20** (Taskwarrior 42,
      `b1369c8c-8fc6-4038-825c-1103a106257c`). Root cause: `ppsConstant`'s
      `@identifierStore` (`parser.s:512`) claimed to fall through to
      `@requireTerminator` but actually fell into `@curAddr`'s `*`-RHS
      handler, whose `jsr lexerNext` consumed the real NEWLINE terminator,
      desyncing parsing onto the following line. Fixed with an explicit
      `jmp @requireTerminator`. `test_casm_expr` re-run clean, no
      regression; new permanent fixture `casmchain1.s`/`.ref` added
      (COMP-verified `FILES COMPARE OK`). Plan:
      `brain/plans/2026-08-20-casm-post-phase12-hardening.md`. Walkthrough:
      `brain/walkthroughs/2026-08-20-casm-post-phase12-hardening-wp77.md`.
- [x] WP78 **listing/TYPE screen double-line-advance fix complete,
      user-approved 2026-08-20** (Taskwarrior 40,
      `be8ca0bf-ac7c-40f6-960e-2ca816bc7fb8`). Root cause was not
      `listing.s` (its 40-column rows are correct by design, locked by
      `.assert` invariants) but Command64's generic `TYPE` command
      (`cmdType`, `src/command64/shell.asm`) forwarding a file's raw CR to
      KERNAL CHROUT unconditionally, even when the KERNAL's own deferred
      line-wrap had already advanced the cursor. Fixed by skipping the CR
      when `KernalScreenColumn` ($D3) already reads 40 (the KERNAL's
      lazy-wrap pending state, not 0 -- confirmed empirically via a live
      `PEEK(211)` BASIC test after a first, incorrect `==0` check silently
      failed to fix anything). Hit and resolved a real `CommandShell`
      segment zero-slack overflow by moving `cmdType` into the existing
      `ShellExt` overflow segment (same pattern as `cmdMore`). Plan:
      `brain/plans/2026-08-20-casm-post-phase12-hardening.md` (Progress
      log has full detail).
- [ ] WP79 **deferred, not fixed** (Taskwarrior 41,
      `882433f0-cde1-4849-8b3c-df32613518c3`): `sourceNextByte` phantom EOF
      byte on exactly-1-byte sources. Investigated live 2026-08-20 and
      root-caused to a real 1541-DOS-firmware/VICE-true-drive-emulation
      quirk -- a SEQ file whose last sector holds only 1 valid byte
      delivers 3 phantom padding bytes via KERNAL CHRIN before READST
      signals EOI. Confirmed via direct D64 sector inspection that
      `cc1541`'s on-disk data and byte-count field are correct; the extra
      bytes come from the emulated drive/KERNAL layer itself, not from
      `source.s`/`fileio.s`/`file.asm`. A first fix attempt (per-handle
      "already saw EOI" latch in `file.asm`) did not resolve it and was
      reverted. Recommended next step: a dedicated investigation absorbing
      Taskwarrior tasks 22 and 35 (same underlying defect class), not a
      continuation of this plan. Full trail:
      `brain/plans/2026-08-20-casm-post-phase12-hardening.md`.

**This hardening plan is closed** (user-approved 2026-08-21) with WP77,
WP78, and WP80 complete, and WP79 explicitly left open/deferred.

## Phase 13 - Data Construction Directives (CASM 0.4, target)

Plan: `brain/plans/2026-08-21-casm-phase13-data-construction-directives.md`.
Adds `.RES`, `.FILL`, `.ALIGN`, `.INCBIN`, and `.ASSERT`. Approved
2026-08-21. WP numbering continues Phase 12's running counter (WP81-85);
version promotes to `0.4.0` at WP85 (whole-phase completion), not per-WP.

- [x] WP81 **`.RES`/`.FILL`/`.ALIGN` fixed-fill directives complete,
      user-approved 2026-08-21** (Taskwarrior 42). New
      `CASM_DIRECTIVE_RES/FILL/ALIGN` ($07-$09) and four diagnostics
      ($4B-$4E: unresolved operand, `.FILL` value required, value out of
      range, `.ALIGN` boundary zero). `parser.s`'s new `ppsFillDirective`
      requires both operands to fully resolve in the parsing pass itself
      (no Pass-1-tolerant placeholder, unlike an ordinary instruction
      operand) -- a genuine forward reference is a diagnostic error.
      `emit.s`'s new `emitRes`/`emitFill`/`emitAlign`/`emitFillLoop`/
      `emitAlignMod` share one byte-loop-emission shape; none interact with
      the R6 relocation table. Found and fixed a real defect during
      fixture verification: `ppsFillDirective` was missing its initial
      `lexerNext`, producing a spurious `MALFORMED EXPRESSION` on every
      fixture. New `test_casm_directives` isolation harness (9/9
      live-verified, modeled on `casm_bounds.s`'s narrow-link precedent)
      plus 7 production fixtures on the new, proactively-created
      `casm_phase13_test_d64` disk (3 accepted COMP-verified byte-identical,
      4 rejected diagnostics live-verified). Regression witnesses
      (`test_casm_expr`/`test_casm_pass1`/`test_casm_frame`) confirmed
      clean. Nine envelope bumps plus one disk relocation
      (`test_casm_event` moved off the now-full `casm_overflow_test_d64`).
      Plan: `brain/plans/2026-08-21-casm-phase13-wp81-res-fill-align.md`.
      Walkthrough: `brain/walkthroughs/2026-08-21-casm-phase13-wp81-res-
      fill-align.md`.
- [x] WP82 **`.INCBIN` complete, user-approved 2026-08-21** (Taskwarrior
      44). New `CASM_DIRECTIVE_INCBIN` ($0A) and three filename-grammar
      diagnostics ($4F-$51, own identity per Scoping Decision 1, not a
      reuse of `.INCLUDE`'s). `lexer.s`'s new `lexerScanIncbinOperand`
      mirrors `lexerScanIncludeOperand`'s structure exactly; `parser.s`'s
      new `ppsIncbin` mirrors `ppsInclude`'s thin shape; `emit.s`'s new
      `emitIncbin` streams the file through the existing managed
      `inputStreamOpen`/`Read`/`Close` wrappers and `emitByte` (no
      catalog/VMM machinery needed, unlike `.INCLUDE` -- Scoping Decision
      2: relies on the existing whole-assembly `emitCheckPassAgreement`
      for Pass1/Pass2 length agreement, no dedicated per-occurrence
      check). Found and fixed two real defects: a recurring `jmp (abs)`
      page-boundary hazard in `expr.s` (third occurrence, widened
      `CasmExprResolverAddrPad` 2->3 bytes), and a `cc1541 -f`
      filename-encoding mismatch (uppercase-typed argument encodes as
      bit-7-set PETSCII, lowercase-typed as unshifted -- explains, for
      the first time in this project's own history, why existing
      `.INCLUDE` fixtures already pair uppercase source text with
      lowercase `-f` packaging arguments). One accepted production
      fixture (COMP-verified against a real 4-byte binary asset) plus two
      rejected diagnostics fixtures, all live-verified. Regression
      witnesses (`test_casm_expr`/`test_casm_pass1`/`test_casm_frame`)
      confirmed clean. Fifteen envelope bumps across `casm` and six test
      harnesses. Plan:
      `brain/plans/2026-08-21-casm-phase13-wp82-incbin.md`. Walkthrough:
      `brain/walkthroughs/2026-08-21-casm-phase13-wp82-incbin.md`.
- [x] WP83 **`.ASSERT` complete, user-approved 2026-08-21** (Taskwarrior
      task, project `casm.phase13`, `+wp83`). New
      `CASM_DIRECTIVE_ASSERT` ($0B) and three diagnostics ($52-$54).
      `parser.s`'s new `ppsAssert` requires the expression to fully
      resolve in both passes (strict, mirrors WP81's own `.RES`/`.FILL`/
      `.ALIGN` precedent) and reuses the lexer's existing `lnString`/
      `CASM_TOKEN_STRING` tokenizer (WP74) for the optional message --
      no new dedicated scanner needed, a mid-implementation simplification
      confirmed with the user. `emit.s`'s new `emitAssert` emits zero
      bytes on success, diagnoses `CASM_DIAG_ASSERTION_FAILED` on a
      zero/false expression; `diagnostics.s` echoes a user-supplied
      message inline when one is given. **Found and corrected a real
      error in this WP's own plan**: CASM's expression grammar has no
      equality/comparison operator at all (verified against `expr.s`),
      so `.ASSERT` can only test nonzero-arithmetic truthiness, not
      equality/alignment invariants -- shipped as scoped, a real
      comparison operator deferred as a separate follow-up (affects
      WP84's real DASH target sites). Also found and fixed a recurring
      `jmp (abs)` page-boundary hazard in `expr.s` (fourth occurrence,
      widened `CasmExprResolverAddrPad` 3->4 bytes) and `diagPrintFatal`'s
      own branch-range fragility (twice, same class WP81's own comment
      already flags). Four production fixtures (one accepted, COMP-
      verified zero-byte emission; three rejected diagnostics), all
      live-verified. Regression witnesses (`test_casm_expr`/
      `test_casm_pass1`/`test_casm_frame`) confirmed clean. Plan:
      `brain/plans/2026-08-21-casm-phase13-wp83-assert.md`. Walkthrough:
      `brain/walkthroughs/2026-08-21-casm-phase13-wp83-assert.md`.
- [x] WP84 **DASH adoption of `.RES` complete, user-approved
      2026-08-21**. Converts `ddata.s`'s five zero/fill-byte
      sites (`FMTBUF`/`SYSINFOBUF`/`APPBUF`/`BORDERROW`/`VMMBUFFER`) to
      `.RES`. Narrowed from the master plan's original framing on two
      independently verified findings: `.ASSERT` DASH adoption deferred
      entirely (its targets are equality invariants, same
      comparison-operator gap WP83 found); `.FILL` DASH adoption dropped
      in favor of `.RES` with an explicit value (**ca65 has no `.FILL`
      directive at all**, verified directly -- would have broken the
      dual-assembler cross-check). Native CASM assembly `COMP`-verified
      against the ca65 cross-check build; regenerated `dash.ref.hex`
      proven byte-identical to the pre-conversion manifest three
      independent ways (live `COMP`, host-side `cc1541 -X` extraction +
      SHA-256, `build_dash_manifest.py --cross-check`). Relocation
      spot-check clean at `$3800`/`$5000`/`$9000`, matching WP71's own
      recorded results exactly. `AGENTS.md` updated to document
      `.RES`/`.FILL`'s dual-assembler status. CASM's own regression
      witnesses confirmed clean. Plan:
      `brain/plans/2026-08-21-casm-phase13-wp84-dash-adoption.md`.
      Walkthrough: `brain/walkthroughs/2026-08-21-casm-phase13-wp84-dash-
      adoption.md`.
- [x] WP85 **consolidated completion gate complete, user-approved
      2026-08-21, closing the whole of Phase 13** (Taskwarrior task,
      project `casm.phase13`, `+wp85`).
      Full sweep (confirmed with the user, matching WP75's own Phase-12-
      closing precedent over a narrower Phase-13-only pass): all 29
      `test_casm_*` harnesses mapped to their six disk images by direct
      `CMakeLists.txt` inspection, then re-run fresh in one continuous
      set of live-VICE sessions, all PASS; all 14 Phase 13 production
      fixtures re-verified together, each matching its own WP's original
      recorded result exactly. DASH's `dash.ref.hex` re-confirmed via a
      cheap host-side SHA-256 check (no second hardware run needed).
      CASM promoted `0.3.0` -> `0.4.0` (completion-only, no behavior
      change), live-verified via version banner and a COMP-clean fixture
      re-run. Full clean rebuild and no-change rebuild both stable. No
      regressions or new defects found. Plan: `brain/plans/2026-08-21-
      casm-phase13-wp85-consolidated-completion.md`. Walkthrough:
      `brain/walkthroughs/2026-08-21-casm-phase13-wp85-consolidated-
      completion.md`.

**Phase 13 is fully closed.**

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

The generated `test.d64` provides `casmshort`, `casm256`, and `casmmulti`
SEQ fixtures for the short, exact-256-byte, and multi-block input cases.
The zero-block `casmempty` fixture (`CANNOT OPEN INPUT` via Commodore DOS,
per Phase 2 Acceptance above) was later removed from the build: `cc1541
-L`, used to create its directory entry with no file content, sets
track/sector to 0, suspected of corrupting `test.d64`. No equivalent
zero-block fixture remains on the disk.

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
- [x] `544a04bd-4ccb-47c6-9013-8af57aa37353`: WP25 verification, walkthrough,
      and completion gate. Plan approved as drafted:
      `brain/plans/2026-07-21-casm-phase6-wp25-verification-closeout.md`.
      Active on `feature/casm-phase6-wp25` from `3fd1f10`, CASM `0.1.26`
      build 1099 baseline. Reconciled the stale acceptance checklist above
      and a test-harness build-dependency hazard (must stub
      `diagPrintFatal`, matching WP20's lexer-stub precedent for `expr.s`).
      `vmmalloc4` (REU exhaustion) and `vmmnoreu` documented as manually
      deferred rather than automated. Implemented `tests/src/casm_vmm/casm_vmm.s`
      (7 automated fixtures) — the first real execution of WP23/WP24's code,
      which found and fixed 3 defects: a wrong diagnostic expectation in the
      test's own `vmmalloc3` case, and two real `vmm_store.s` bugs
      (`vwPrepareTransfer` rejecting the valid exact-65536-byte boundary;
      `vmmReplay` clobbering its stashed slot via a zero-page cell
      `vwPrepareTransfer` also uses — the same shared-scratch bug class WP23
      caught twice already). All fixed with explicit user approval to fix in
      place. All 7 fixtures pass. Walkthrough:
      `brain/walkthroughs/2026-07-21-casm-phase6-wp25-verification-closeout.md`.
      User approved completion. Final `0.1.27` build 1102 matches the
      dry-run PRG hash exactly; no-change rebuild stable; both images pass.
      **WP25 is complete, and with it the CASM Phase 6A milestone.**

## Phase 6A Acceptance

- [x] Phase 0C.4 VMM record contract and task hierarchy are frozen by WP22.
- [x] Real `DOS_ALLOC_MEM`/`DOS_FREE_MEM` wiring replaces `cleanupVmmStub`
      (WP23).
- [x] Windowed `DOS_VMM_READ`/`DOS_VMM_WRITE` transfers are bounds-checked by
      CASM against each allocation's granted size (WP24, defect-fixed by
      WP25).
- [x] Bounded VMM records are written, read, and replayed without depending
      on source or symbol semantics. Verified by WP25's `test_casm_vmm`
      fixture matrix (`vmmreplay1` covers write/read/replay together); all
      7 automated cases pass in VICE.
- [/] Allocation-exhaustion (registry-full) diagnostics are stable and exit
      cleanly with no partial ownership, verified by `vmmalloc3`. No-REU
      (`vmmnoreu`) and real REU-capacity exhaustion (`vmmalloc4`) remain
      manually deferred, not automated — the supported harness has no
      per-run REU toggle, and CASM's own 512KB registry cap can never mark
      the OS's 16MB-tracked MCT full through normal calls.
- [x] User completed the WP25 runtime walkthrough and approved CASM
      Phase 6A. **CASM Phase 6A is complete.**

CASM Phase 6B (symbol table and two-pass assembly) remains a separately
gated phase; its work packages (WP26-WP31) are reserved in the parent plan
but not yet created in Taskwarrior. CASM Phase 6B may not begin before CASM
Phase 6A's own completion gate and explicit user approval.

# CASM Phase 6B - Symbol Table and Two-Pass Assembly

Note: this is CASM-local phase numbering, distinct from the unrelated,
already-completed top-level project phase of the same name ("Phase 6B:
Binary Relocator") recorded elsewhere in `brain/KNOWLEDGE.md`. Always write
"CASM Phase 6B" in full to avoid ambiguity.

Parent Taskwarrior UUID: `166e5352-5aa0-45bd-8bee-5baf0e878798` -
"CASM Phase 6B: Symbol table and two-pass assembly". Depended on WP26-WP31
below. **Complete as of CASM `0.1.33` build 1131 (WP31's approval).**

Parent plan:
`brain/plans/2026-07-21-casm-phase6-vmm-storage-and-symbol-table.md`
WP26 plan:
`brain/plans/2026-07-22-casm-phase6-wp26-prerequisite-reconciliation.md`

## Phase 6B Work Packages

- [x] `58c94a92-48f8-4039-8dcc-44f42d193d3c`: WP26 prerequisite reconciliation
      and Phase 0C.5 freeze. Implemented on `feature/casm-phase6-wp26` from
      `main` at `da0cc3c`. Verified the CASM Phase 6A completion gate, then
      found and resolved two discrepancies beyond the parent Phase 6 plan's
      own review: `opcodesFindOpcode` has no channel through which a caller
      can force absolute-width addressing at all, and the statement grammar
      has no label-definition production, so a naive design would have
      clobbered the label name via the shared transient token buffer. Froze
      the Phase 0C.5 contract after the user confirmed three architectural
      decisions: a single `CasmPassMode` flag gated at one point in
      `emitRawByte` (not an event bus); `CasmParserStmt` growing from 6 to 7
      bytes (not a parallel cell); and a 128-bucket/512-symbol VMM-backed
      hash table. No symbol-table or pass source was written -- the only
      source change is the version-only completion increment. Version-bump
      dry-run confirmed a `0.1.27` -> `0.1.28` stage bump changes exactly 2
      bytes (version/build digits) versus the baseline; the real increment
      was then applied for real: final CASM `0.1.28` build 1103, no-change
      rebuild stable (a second build did not re-increment), both
      `image_d64` and `test_image_d64` build clean. **WP26 is complete.**
- [x] `0dd437f3-3248-4294-aee7-39bb8571f1c8`: WP27 symbol table storage and
      hash index. Plan approved as drafted:
      `brain/plans/2026-07-22-casm-phase6-wp27-symbol-table-storage.md`.
      Active on `feature/casm-phase6-wp27` from `feature/casm-phase6-wp26`'s
      tip, CASM `0.1.28` build 1112 baseline. Reconciled a real conflict
      WP26's freeze missed: the frozen 37-byte symbol record cannot pass
      through Phase 6A's existing 32-byte `CasmVmmBuffer` transfer window at
      all -- `vwPrepareTransfer` rejects any request over 32 bytes outright.
      User resolved it by padding the record to 64 bytes (power of two) and
      growing the buffer to match, which also replaced what would have been
      a 3-term shift-add multiply-by-37 (record-index-to-VMM-offset
      arithmetic, run on every symbol lookup/insert) with a single 16-bit
      shift-left-by-6. Designing the exact algorithm surfaced two further
      corrections to the parent Phase 6 plan's own predictions: `symbols.s`
      needs none of the zero-page `CasmPassScratch0-3` group after all (its
      transient state is all values, not pointers, so it lives in ordinary
      BSS instead, leaving that zero-page group free for WP28), and its
      calling convention deliberately avoids `CasmValue0Lo/Hi` for anything
      spanning a nested `vmmWindowRead`/`Write` call, since that exact
      shared-scratch-clobber bug class hit `vmm_store.s` three separate
      times during WP23-25. `symbolsLookup`'s signature matches the Phase 5
      `exprEvaluate` resolver callback ABI exactly, so WP28 can bind it
      directly with zero adapter code. While extending `diagnostics.s`,
      found and fixed (with explicit user approval) a pre-existing Phase 6A
      defect: `diagPrintFatal`'s message-selection bound never covered
      `$28`-`$2B`, so all four Phase 6A VMM diagnostics had silently fallen
      back to the generic "UNKNOWN" message since WP23/24 -- never caught
      before, fixed alongside wiring the new `$2C`-`$2F` Phase 6B
      diagnostics since the bound-check edit had to move past `$2B`
      regardless. Implemented `src/external/casm/symbols.s`
      (`symbolsInit`/`symbolsInsert`/`symbolsLookup`, a private
      `symbolsFindChain` chain-walk helper, 64-byte VMM-backed records, a
      128-bucket rotate-XOR hash index, 512-symbol capacity) -- built and
      fixture-tested in complete isolation, no `casm.s`/`parser.s`/
      `opcodes.s` call site yet (that is WP28). `common.inc` amended
      (`CASM_VMM_BUFFER_SIZE` 32 -> 64, new `CASM_SYMBOL_*` constants,
      diagnostics `$2C`-`$2F`). Added a standalone
      `tests/src/casm_symbols/casm_symbols.s` harness with 10 fixtures
      (`syminit1`, `symins1`, `symlook1`, `symlookmiss1`, `symdup1`,
      `symcase1`, `symchain1`, `symlen1`, `sympad1`, `symfull1`) -- all 10
      fully implemented and passing. Measured MAIN overflow (848 bytes);
      user approved `$2B00` -> `$2F00` (176 bytes free after rounding). User
      ran both `TEST_CASM_VMM` (regression check for the buffer-size
      amendment) and `TEST_CASM_SYMBOL` (the new 10-fixture matrix) in VICE
      from `build/test.d64`: both passed with no `F` failures. Version-only
      completion increment applied: final CASM `0.1.29` build 1113,
      no-change rebuild stable, both `image_d64` and `test_image_d64` build
      clean. Walkthrough:
      `brain/walkthroughs/2026-07-22-casm-phase6-wp27-symbol-table-storage.md`.
      **WP27 is complete.** WP28 (`712fe7af`) is now unblocked in
      Taskwarrior but requires its own dedicated plan drafted and approved
      before activation, per the CASM AGENTS.md gate.
- [x] `712fe7af-1e41-46c9-9a19-49c2632cd15a`: WP28 Pass 1 - address
      assignment and definitions. Plan approved as drafted:
      `brain/plans/2026-07-22-casm-phase6-wp28-pass1-address-assignment.md`.
      Active on `feature/casm-phase6-wp28` from `feature/casm-phase6-wp27`'s
      tip, per this project's branch-per-WP convention. Wired WP27's
      VMM-backed symbol table into a real two-pass foundation: added
      `CASM_PASS_MODE_MEASURE`/`CASM_PASS_MODE_EMIT`, gated at exactly one
      point in `emitRawByte` (`emit.s`) -- measure mode skips the actual
      byte write but still advances `CasmPc`. Added label-statement grammar
      to `parser.s` (colon-terminated `LABEL:` identifier statements) that
      insert into the symbol table via `symbolsInsert`, with duplicate
      detection. Wired `expr.s`'s resolver callback to call `symbolsLookup`
      for real (previously a stub, `parserRejectIdentifier`), so
      identifiers in expressions now resolve against the symbol table
      WP27 built. Added `CASM_PARSER_STMT_FORCE_ABS`, growing
      `CasmParserStmt` from 6 to 7 bytes, to force absolute-width
      addressing for symbol-derived operands so a label used as a
      branch/zero-page-eligible operand always assembles to the same
      width in both passes -- preventing a Pass 1/Pass 2 size
      disagreement. Caught and fixed two defects during implementation,
      before any test run: the force-absolute flag was originally going to
      derive from `CASM_EXPR_FLAG_FORCE_ABS` (set only when unresolved),
      which would have let Pass 1/Pass 2 disagree on size for
      already-resolved backward references -- corrected to derive from
      `CASM_EXPR_FLAG_SYMBOL_DERIVED` (set on any resolver success,
      resolved or not); and `emit.s`'s pass-mode gate as originally
      spec'd would have clobbered the byte to emit with `CasmPassMode`'s
      own value -- fixed to stash the byte in X first. Added a standalone
      `tests/src/casm_pass1/casm_pass1.s` harness with 7 fixtures (label +
      bare, label + mnemonic on the same line, forward reference,
      backward reference, undefined symbol under measure-mode tolerance,
      duplicate-label detection, and a comprehensive fixture combining a
      forward reference, 3 labels, and `.BYTE`/`.WORD` directives). Found
      and fixed two test-fixture defects during VICE verification, not
      implementation defects: a zero-page collision in
      `tests/src/casm_expr/casm_expr.s` (its own mock lexer's
      `ScriptLo`/`ScriptHi` cursor at `$70`/`$71` collided with `expr.s`'s
      new use of `CasmPtr0Lo`/`Hi` at the same address -- fixed by moving
      the test's cursor to `$7C`/`$7D`); and the generated `p1size1`
      fixture used lowercase `.byte`/`.word` directive keywords, which
      CASM's lexer's `isIdFirst`/`isIdCont` never accept (only uppercase,
      unshifted `$41`-`$5A` or shifted PETSCII `$C1`-`$DA`), raising
      `CASM_DIAG_INVALID_SOURCE_BYTE` on the `b` -- fixed by capitalizing
      to `.BYTE`/`.WORD` to match every other fixture's convention. User
      ran all 7 `casm_pass1` fixtures and a `test_casm_expr` regression
      re-run in VICE from `build/test.d64`: both passed with no `F`
      failures. Measured MAIN overflow; user approved `$2F00` -> `$3000`.
      Version-only completion increment applied: final CASM `0.1.30`
      build 1123, no-change rebuild stable, both `image_d64` and
      `test_image_d64` build clean. Walkthrough:
      `brain/walkthroughs/2026-07-22-casm-phase6-wp28-pass1-address-assignment.md`.
      **WP28 is complete.** WP29 (`8e989bdf`) is now unblocked in
      Taskwarrior but requires its own dedicated plan drafted and approved
      before activation, per the CASM AGENTS.md gate.
- [x] `8e989bdf-7aed-4bfe-ae9c-3771edb7caf5`: WP29 Pass 2 - resolution and
      emission. Plan approved as drafted:
      `brain/plans/2026-07-23-casm-phase6-wp29-pass2-resolution-emission.md`.
      Active on `feature/casm-phase6-wp29` from `feature/casm-phase6-wp28`'s
      tip, CASM `0.1.30` build 1123 baseline. Direct research against the
      current source found WP29's real scope narrower than the parent plan's
      prose suggested: WP28 had already bound `symbolsLookup` as the
      production resolver and made `parserParseExpressionValue` pass-mode-
      aware, so WP29 needed zero changes to `symbols.s`/`parser.s`/
      `opcodes.s`/`emit.s` -- it is purely a `casm.s` orchestration rewrite.
      Rewrote `start` as a true two-pass driver sharing one new private
      dispatch routine, `casmRunPass`: Pass 1 runs
      `CASM_PASS_MODE_MEASURE` to `EOF` with no output file (labels insert
      via `symbolsInsert`); on success, Pass 2 calls `sourceRewind`/
      `lexerInit` again, moves `fileCreateOutput` to this point (previously
      called before Pass 1), sets `CASM_PASS_MODE_EMIT`, and re-drives the
      identical dispatch for real (labels are a no-op the second time).
      Building surfaced a real ca65 branch-range error (three `bcs`
      branches pushed past +/-127 bytes by the new code) -- fixed with two
      near trampolines (`startInitFatal` for pre-Pass-1 failures,
      `startFatalNear` for Pass 1/Pass 2 failures), the same class of fix
      this codebase has hit before. Per the user's confirmed decisions:
      reused WP28's already-hand-verified `p1fwd1`/`p1back1`/`p1size1`
      fixtures directly as the new trusted-reference source (three new
      `tests/fixtures/casm/*.ref.hex` manifests, no new `.seq` files) and
      reused `p1undef1` unmodified as the one end-to-end "real `casm.s`
      Pass 2 fails cleanly on an undefined symbol" fixture. Also corrected,
      per the user's confirmed decision, a real discrepancy found during
      dependency review: both the master plan's Foundational Design
      Constraints and `AGENTS.md`'s Local Contracts still described a
      structured "Pass 2 emission events" design from 2026-07-16 that WP26
      had already overridden on 2026-07-22 (single `CasmPassMode` flag,
      events deferred to Phase 10) without either document being updated --
      both corrected in place, cross-referencing WP26's plan. Measured MAIN
      directly via `ld65 -m`: 12137 of 12288 bytes used, 151 bytes headroom
      -- no size increase needed. User ran the full VICE matrix (the five
      pre-existing Phase 4/5 trusted references as a non-symbol regression
      check, the three new label references, and the `p1undef1` failure
      case) from `build/test.d64` and `build/image.d64`: all passed.
      Version-only completion increment applied: final CASM `0.1.31` build
      1126, no-change rebuild stable, both `image_d64` and `test_image_d64`
      build clean. Walkthrough:
      `brain/walkthroughs/2026-07-23-casm-phase6-wp29-pass2-resolution-emission.md`.
      **WP29 is complete.** WP30 (`a9a117d2`) is now unblocked in
      Taskwarrior but requires its own dedicated plan drafted and approved
      before activation, per the CASM AGENTS.md gate.
- [x] `a9a117d2-b4e5-4f5c-8df1-19239b1e4cf7`: WP30 relative branches and
      Pass 1/Pass 2 disagreement detection. Plan approved as drafted:
      `brain/plans/2026-07-23-casm-phase6-wp30-branches-and-disagreement-detection.md`.
      Active on `feature/casm-phase6-wp30` from `feature/casm-phase6-wp29`'s
      tip, CASM `0.1.31` build 1126 baseline. Planning-time inspection
      confirmed `opcodesFindOpcode` resolves any branch mnemonic to
      `CASM_MODE_RELATIVE` before ever consulting `CASM_PARSER_STMT_FORCE_ABS`,
      so relative-branch resolution needed no `opcodes.s` changes -- WP30's
      only planned production code was `CASM_DIAG_PASS_MISMATCH` detection
      (`CasmPass1FinalPc` + `emitCheckPassAgreement`, co-located in `emit.s`
      per the user's confirmed decision so a new standalone
      `test_casm_passcheck` harness could prove the fatal path fires, since
      `casm.s` itself can never be linked by any test harness).
      Per the user's confirmed decision, added three new fixtures closing a
      real coverage gap (no prior fixture, Phase 4 included, had ever used a
      label as a branch target): `brfwd1`/`brback1` (new trusted references)
      and `brrng1` (reuses Phase 4's exact `casmbrp2` boundary with a label
      operand). `brfwd1` immediately exposed a real, previously-latent
      defect: `eiRelative` computed the `-128..127` range check even in
      `CASM_PASS_MODE_MEASURE`, using the `$0000` placeholder
      `pevMeasureUnresolved` stores for a still-unresolved forward
      reference -- producing a spurious `CASM_DIAG_BRANCH_OUT_OF_RANGE` in
      Pass 1 regardless of the real, in-range Pass 2 distance. Latent since
      Phase 4 (`eiRelative` predates Phase 6B); `brrng1` had been passing
      before the fix only coincidentally (the right diagnostic for the
      wrong reason). Presented the exact root cause and proposed fix to the
      user before touching source, since it was not in the approved plan's
      scope; fixed with explicit approval by making `eiRelative`
      pass-mode-aware (skip the range check entirely in `MEASURE` mode,
      mirroring the existing `CASM_DIAG_UNDEFINED_SYMBOL` pattern). The fix
      itself pushed one existing branch out of ca65's +/-127-byte range,
      fixed with a `bcc :+ / jmp eiRet / :` trampoline. Measured MAIN
      directly via `ld65 -m`: 12191 of 12288 bytes used, 97 bytes headroom
      -- no size increase needed. User ran the full VICE matrix twice (round
      1 caught the `brfwd1` defect; round 2, after the fix, added a
      regression check against Phase 4's literal-target branch fixtures
      `casmbrp1`/`brp2`/`brn1`/`brn2` since they exercise the same
      `eiRelative` path the fix touched): both rounds confirmed "All tests
      pass." Version-only completion increment applied: final CASM
      `0.1.32` build 1130, no-change rebuild stable, both `image_d64` and
      `test_image_d64` build clean. Walkthrough:
      `brain/walkthroughs/2026-07-23-casm-phase6-wp30-branches-and-disagreement-detection.md`.
      **WP30 is complete.** WP31 (`86d8ac7e`) is now unblocked in
      Taskwarrior but requires its own dedicated plan drafted and approved
      before activation, per the CASM AGENTS.md gate.
- [x] `86d8ac7e-0725-44b8-81ae-dcef143a20ad`: WP31 verification, walkthrough,
      and completion gate. Plan approved as drafted:
      `brain/plans/2026-07-23-casm-phase6-wp31-verification-closeout.md`.
      Active on `feature/casm-phase6-wp31` from `feature/casm-phase6-wp30`'s
      tip, CASM `0.1.32` build 1130 baseline. Closed the last unchecked
      Phase 6B Acceptance item -- duplicate/undefined/case-sensitive/
      max-length behavior -- with real end-to-end proof through production
      `casm.s`, not just WP27/28's isolated module-level proof. Found a
      real, non-obvious byte-encoding pitfall before writing any fixture: a
      case-sensitivity `.seq` fixture using ordinary mixed-case ASCII text
      would test nothing, since CASM's lexer only accepts unshifted
      (`$41-$5A`) or shifted (`$C1-$DA`) PETSCII as identifier bytes and raw
      `.seq` files (unlike WP27's ca65-assembled test harness) receive no
      charmap conversion. Confirmed the correct shifted-byte values
      empirically by compiling `"Case"`/`"CASE"` directly with ca65 before
      constructing `casmcase1.seq`'s shifted-byte label via `string(ASCII
      204/207/207/208 ...)` in the fixture generator. Added `casmmaxid1.seq`
      (31-character label via `string(REPEAT "A" 31 ...)`) for the
      max-length item. Reused `p1dup1.seq`/`p1undef1.seq` unmodified for
      duplicate/undefined through real `casm.s` -- no new files needed. Per
      the user's confirmed decisions: skipped a new end-to-end
      symbol-table-full fixture (already covered by WP27's isolated proof
      plus the duplicate-symbol fixture's shared propagation path), and used
      a 7-fixture targeted Phase 3/4 regression sample (`casmwp11`,
      `casmzp1`, `casmcma2`, `casmorg3`, `casmzpi2`, `casmpcovf`,
      `casmnumerrh`) rather than a full 60-fixture historical re-run, given
      WP30's `eiRelative` defect was narrowly specific to a live-counter
      difference check no other Phase 4 diagnostic shares. No production
      source changed at all -- unlike WP30, this WP's new fixture
      categories found no latent defect; every case passed on the first
      VICE run. User ran the full consolidated matrix (5 standalone test
      harnesses, 12 byte-identical trusted references, 3 diagnostic
      fixtures through real `casm.s`, and the 7-fixture regression sample)
      from `build/test.d64` and `build/image.d64`: "All tests pass."
      Version-only completion increment applied: final CASM `0.1.33` build
      1131, no-change rebuild stable, both `image_d64` and `test_image_d64`
      build clean. Walkthrough:
      `brain/walkthroughs/2026-07-23-casm-phase6-wp31-verification-closeout.md`.
      **WP31 is complete, and with it the CASM Phase 6B milestone closes.**

## Phase 6B Acceptance

- [x] Symbol table duplicate, undefined, case-sensitive, and max-length
      behavior match the frozen contract.
- [x] Pass 1 assigns addresses and definitions without emitting output.
- [x] Pass 2 resolves symbols and emits final output.
- [x] Relative branches are computed from resolved symbols.
- [x] A Pass 1/Pass 2 disagreement is treated as fatal.
- [x] Static programs with forward and backward references match trusted
      reference binaries byte-for-byte.

**All six items are checked. WP26-WP31 are complete and approved (CASM
`0.1.33` build 1131). CASM Phase 6B is complete.** CASM Phase 7 (VMM-backed
source and multiple top-level inputs) and Phase 8 (R6 relocation
consumption) remain separately gated and unstarted, per the master plan's
own sequencing -- neither is activated by this closure.

## Phase 7 Work Packages

- [x] `25e69c58-b1cf-4c43-8aa9-5ae79b015375`: WP32 prerequisite
      reconciliation and Phase 0C.10 freeze. Plan approved as drafted:
      `brain/plans/2026-07-23-casm-phase7-wp32-prerequisite-reconciliation.md`.
      Verified the CASM Phase 6B completion gate (`0.1.33` build 1131, 97
      bytes MAIN headroom, `ld65 -m` measurement matched WP31's own figure
      exactly). Found the master plan's stated Phase 7 rationale ("sources
      larger than the RAM window", "byte-at-a-time OS calls") is stale --
      `source.s` already streams any file size in bounded 256-byte OS
      blocks -- and that the only confirmed hard gap is CLI-level:
      `cli.s`'s `cliCopySource` hard-rejects a second source token. Asked
      the user two architectural questions given that finding (whether to
      still build a VMM-cached source model despite the stale rationale,
      and what capacity to freeze for multiple source names); both
      recommended options were confirmed: VMM-cached whole-source load (for
      the real remaining benefit of eliminating Pass 2's forced second
      physical disk read), and an 8-slot x 64-byte `CasmSourceNames` array.
      Froze the Phase 0C.10 contract: one pre-pass VMM load stage, a
      65535-byte combined multi-file cap (not 65536 -- `vmmStoreAlloc`
      cannot represent that count in 16 bits), VMM-backed refill filling
      the existing 256-byte `CasmIoBuffer` through up to four 64-byte
      transfers (`CASM_VMM_BUFFER_SIZE` cannot grow without breaking the
      WP27 symbol-record contract), file-boundary identity/line resets
      using the already-unused `CasmSourceFileId` placeholder from Phase 3,
      and conditional (multi-file-only) diagnostic filename printing. Found
      no new `CASM_DIAG_*` identifier is expected -- a contrast with every
      prior phase. No symbol-table, source, or CLI source was written --
      the only source change is the version-only completion increment.
      Final CASM `0.1.34` build 1132, no-change rebuild stable, both
      `image_d64` and `test_image_d64` build clean. **WP32 is complete.**
- [x] WP33 VMM-backed single-file load and traversal equivalence. Plan
      approved as drafted:
      `brain/plans/2026-07-24-casm-phase7-wp33-vmm-backed-source-load.md`.
      Active on `feature/casm-phase7-wp33` from `main` at `ab7445b`.
      Implemented Contract items 1-3 of the Phase 0C.10 freeze: a new
      `sourceLoad` pre-pass (opens `CasmSourceName`, streams it in 256-byte
      OS blocks, writes each into a 65535-byte VMM allocation through up to
      four 64-byte `vmmWindowWrite` chunks); a VMM-backed `sourceRefill`
      (chunked `vmmWindowRead` into `CasmIoBuffer` instead of a direct OS
      read); and simplified `sourceOpen`/`sourceRewind`/`sourceClose` (pure
      cursor resets, no OS calls -- `CASM_DIAG_SOURCE_REWIND_FAILED` becomes
      declared-but-unreachable, not removed). `sourceFetchPhysical` and
      every byte-classification/newline-normalization routine needed zero
      changes, confirmed by tracing that they only ever consult the block
      index/length window and a delivered-byte offset, both meaningful
      identically regardless of where `CasmIoBuffer`'s contents came from.
      Two new fixtures (`casmvmm65`/`casmvmm128`) target the new internal
      64-byte VMM chunk boundary that `casm256` (always four full chunks)
      never exercised. MAIN bumped `$3000` -> `$3200` (236-byte overflow at
      the old size) for `casm`, and `$3200` -> `$3300` for the
      `casm_pass1`/`casm_passcheck` standalone harnesses (both link
      `source.s` whole).

      Two real defects were found through user runtime testing and fixed,
      matching the WP25/WP30 precedent that a genuinely new fixture
      category can surface a latent defect, not just prove new code
      correct:
      - `sourceRefill`'s VMM-read copy omitted the `<CasmIoBuffer` low-byte
        term entirely (`CasmIoBuffer` links at `$5FDA`, not page-aligned),
        so every refill wrote 218 bytes before the real buffer, corrupting
        whatever BSS state happened to sit there. This produced two
        seemingly unrelated symptoms depending on which fixture's chunk
        offsets hit which cell: `casmemit1` failed with a spurious
        `OUTPUT WRITE FAILED` plus a real drive-level `32, SYNTAX ERROR`;
        `casmhello` failed with a spurious `DUPLICATE ORG`. Fixed by adding
        the missing term as its own correctly-carried addition, mirroring
        `sourceLoad`'s already-correct write-side pointer computation.
      - `test_casm_pass1` never freed `sourceLoad`'s new per-fixture VMM
        allocation (only `symbolsInit`'s was ever accounted for
        pre-WP33), so the 8-slot VMM registry filled exactly after 4 of 7
        fixtures (`....`) and the remaining three failed with the registry
        already full (`fff`). Fixed by calling `resourcesCleanup` after
        each fixture in `casm_pass1.s`, freeing both VMM slots before the
        next fixture allocates its own.

      User ran the full verification matrix after both fixes:
      `TEST_CASM_PASS1` and `TEST_CASM_PASSCHECK` both pass; all 12
      byte-identical trusted references pass; all 7 Phase 3 traversal
      fixtures and both new `casmvmm65`/`casmvmm128` chunk-boundary
      fixtures produced their hand-derived expected diagnostics. Final CASM
      `0.1.35` build 1137, no-change rebuild stable, both `image_d64` and
      `test_image_d64` build clean. MAIN headroom 273 of 12800 bytes.
      Walkthrough:
      `brain/walkthroughs/2026-07-24-casm-phase7-wp33-vmm-backed-source-load.md`.
      **WP33 is complete.**
- [x] WP34 multi-file CLI and file-boundary provenance. Plan approved as
      drafted:
      `brain/plans/2026-07-24-casm-phase7-wp34-multi-file-cli-and-provenance.md`.
      Active on `feature/casm-phase7-wp34` from `feature/casm-phase7-wp33`'s
      tip. Implemented Contract items 4, 6, and 7 of the Phase 0C.10
      freeze: `cli.s` grew `CasmSourceNames`/`CasmSourceLens` (8 slots x 64
      bytes)/`CasmSourceCount`, with `cliCopySource` writing through a
      compile-time slot-address lookup table (`cliSourceSlotLo/Hi`, since
      64 does not divide evenly into 256) rather than a runtime multiply;
      `source.s`'s `sourceLoad` became an outer loop over every top-level
      file, recording each one's start offset into a new 16-byte
      `CasmSourceFileTable` (offsets only -- a file's end is implicitly the
      next file's start, halving the size from the original 4-bytes/entry
      sketch) and inserting one synthetic LF between files whose content
      doesn't already end in a newline; `sourceRefill` gained a
      file-boundary check (`srCheckFileBoundary`) that resets
      `CasmSourceFileId`/line/column and, per the user's confirmed
      decision, unconditionally clears the pending-CR latch at every
      boundary so a bare-CR-ending file can never phantom-collapse with a
      following file's leading LF. A new explicit combined-cap check
      (`slCheckCap`, reusing `CASM_DIAG_SOURCE_OFFSET_OVERFLOW`) was
      required since the per-file cap `sourceLoad` gets from
      `inputStreamOpen` resets every file -- correcting the scope of
      WP33's "free" finding, which only held for exactly one file.
      `fileio.s`'s `inputStreamOpen` was generalized from a hardcoded
      single-buffer pointer to a caller-supplied X/Y pointer (its only
      caller, `sourceLoad`, already needed to select a different file each
      loop iteration). `test_casm_pass1`/`test_casm_passcheck` needed their
      own small stand-in copies of the new `cli.s`-owned symbols (neither
      links `cli.s`), caught before it became a link failure rather than a
      silent regression. A single-file assembly (`CasmSourceCount == 1`)
      takes an identical code path to WP33's, confirmed by every existing
      single-file trusted reference and both standalone harnesses
      re-passing unmodified. MAIN bumped `$3200` -> `$3500` (a 507-byte
      overflow at the old size). Six new multi-file fixtures
      (`casmmf1`/`casmmf2`/`casmmf3`, two-file forward-reference,
      two-file-with-synthetic-newline, and three-file cases; plus
      `casmmfcr1`/`casmmfcr2` for the cross-file pending-CR regression)
      plus a combined-overflow pair (`casmmfovf1`/`casmmfovf2`, 40000/30000
      bytes) that needed its own dedicated `casm_overflow_test.d64` disk
      image -- the real 65535-byte cap cannot be exercised with less
      content, and the shared `test.d64` had no room left for it. User ran
      the full verification matrix (both standalone harnesses, all 12
      pre-existing byte-identical references, all 3 new multi-file
      references, the cross-file pending-CR fixture, the 9th-source-file
      rejection, and the combined-overflow boundary) and confirmed: "all
      test pass." `AGENTS.md`'s stale "Phase 2 accepts one unquoted source
      filename" contract corrected. Final CASM `0.1.36` build 1139,
      no-change rebuild stable, all three disk images (`image_d64`,
      `test_image_d64`, `casm_overflow_test_d64`) build clean. MAIN
      headroom 261 of 13568 bytes. Walkthrough:
      `brain/walkthroughs/2026-07-24-casm-phase7-wp34-multi-file-cli-and-provenance.md`.
      **WP34 is complete.**
- [x] WP35 diagnostic filename integration. Plan approved as drafted:
      `brain/plans/2026-07-24-casm-phase7-wp35-diagnostic-filename-integration.md`.
      Active on `feature/casm-phase7-wp35` from `feature/casm-phase7-wp34`'s
      tip. Implemented Phase 0C.10 Contract item 5: `state.s`'s
      `CasmDiagState` block grew in place by 2 bytes
      (`CasmDiagLocFileId`/`CasmStmtLocFileId`, assert updated 530 -> 532
      -- lower-risk than the `CasmLabelName`-style external-block
      precedent, since every field here has exactly one clear write site,
      unlike `CasmParserStmt`'s wholesale writers); all three
      `diagSetLocFrom*` routines and `diagStampStmtLoc`
      (`diagnostics.s`) now carry file identity alongside line/column;
      `diagPrintSourceContext` prints `IN FILE <name>` on its own line
      before `AT LINE...`, gated on `CasmSourceCount > 1`, reusing WP34's
      exported `cliSourceSlotLo/Hi` table for the filename lookup (no new
      lookup mechanism needed).

      Found WP32's original rationale for gating filename printing ("the
      40-column diagnostic window is already full") described a
      different print statement than the one this WP touches -- the
      trailer this WP extends already silently wraps past 40 columns in
      its own worst case today. The real, still-valid reason to gate on
      `CasmSourceCount > 1` is keeping single-file diagnostic text
      byte-identical, not a hard column budget; the gating decision itself
      was unchanged, only its stated justification was corrected.

      `test_casm_pass1`/`test_casm_passcheck` needed **zero source
      changes** -- confirmed by successful build/link, not assumed: both
      already carried the exact stand-in symbols
      (`CasmSourceCount`/`cliSourceSlotLo/Hi`) this WP's new imports
      needed, as a direct side effect of WP34's own harness fix. New
      fixture pair `casmmfdiag1`/`casmmfdiag2` (invalid byte in the
      *first* file, complementing the existing `casmmfcr1`/`casmmfcr2`
      non-first-file case) proves the filename prints correctly for file
      index 0 too. User ran the full verification matrix (single-file
      diagnostic text regression, byte-identical trusted references,
      both new filename fixtures, both standalone harnesses) and
      confirmed: "all test pass." Final CASM `0.1.37` build 1141,
      no-change rebuild stable, all three disk images (`image_d64`,
      `test_image_d64`, `casm_overflow_test_d64`) build clean. MAIN
      headroom 189 of 13568 bytes (no bump needed). Walkthrough:
      `brain/walkthroughs/2026-07-24-casm-phase7-wp35-diagnostic-filename-integration.md`.
      **WP35 is complete.**
- [x] WP36 verification, walkthrough, and Phase 7 completion gate. Plan
      approved as drafted:
      `brain/plans/2026-07-24-casm-phase7-wp36-verification-closeout.md`.
      Active on `feature/casm-phase7-wp36` from `feature/casm-phase7-wp35`'s
      tip. Bundled the full accumulated WP32-35 fixture/harness matrix into
      one consolidated verification run and closed two gaps a fresh trace
      found before implementation:

      1. **No fixture had ever proven a large, under-cap input actually
         assembles successfully** -- the master plan's own Phase 7 gate text
         ("large ... inputs assemble successfully with correct diagnostics")
         was only half-covered by the four checked Acceptance items below;
         every existing "large" fixture was either invalid syntax (pure
         `sourceRefill` traversal/chunk-boundary proof) or deliberately over
         the 65535-byte cap (the failure path). Closed with a new fixture
         pair, `casmbiga.s`/`casmbigb.s` (3000 `NOP` statements each, 6000
         total), and its trusted reference `casmbig1.ref.hex` (`00 C0`
         header + `EA` x 6000) -- generated from one reviewed
         single-opcode repetition rule rather than a hand-typed manifest,
         per the user's confirmed verification method. `casmbig1` closes
         both halves of the gate text ("large" and "multiple") in one
         fixture.
      2. **WP31's targeted 7-fixture Phase 3/4 diagnostic-category
         regression sample (`casmwp11`/`casmzp1`/`casmcma2`/`casmorg3`/
         `casmzpi2`/`casmpcovf`/`casmnumerrh`) had never been re-run since
         Phase 7 replaced the entire source-loading layer those fixtures
         depend on to reach the lexer/parser at all** -- confirmed by
         reading WP33's own plan (which explicitly used a *different*
         fixture set and noted no "same as before" baseline existed yet)
         and re-checking WP34/35's verification sections. Closed by
         re-running the same 7 fixtures, unmodified, as part of this WP's
         consolidated matrix.

      A real implementation-time discrepancy against the plan surfaced and
      was corrected with the user's approval: `casmbiga.seq`/`casmbigb.seq`'s
      raw source text (12011/12000 bytes -- source text is far larger than
      its 1-byte-per-`NOP` assembled output) did not fit on `test.d64`
      alongside every other CASM/OS fixture (only 110 blocks were free;
      96 were needed, leaving no room for the trailing `edlinfull`
      fixture). Fixed by moving `casmbiga.s`/`casmbigb.s` and `casmbig1`'s
      `COMP` verification (plus `comp.prg` itself) onto the existing
      `casm_overflow_test_d64` disk image -- the same dedicated image
      `casmmfovf1`/`casmmfovf2` already used for exactly the same
      "too large for test.d64" reason -- rather than inventing a third disk
      image or shrinking the fixture to a size too small to meaningfully
      demonstrate "large."

      User ran the full consolidated matrix (5 standalone harnesses, 16
      byte-identical trusted references including the new `casmbig1`, 7
      diagnostic-fixture scenarios, the 7-fixture Phase 3/4 regression
      sample) and confirmed: "all tests pass." No production source defect
      was found. Final CASM `0.1.38` build 1142, no-change rebuild stable,
      all three disk images (`image_d64`, `test_image_d64`,
      `casm_overflow_test_d64`) build clean. MAIN headroom 189 of 13568
      bytes (unchanged -- WP36 added no production code). Walkthrough:
      `brain/walkthroughs/2026-07-24-casm-phase7-wp36-verification-closeout.md`.
      **WP36 is complete, and with it the CASM Phase 7 milestone closes.**

## Phase 7 Acceptance

- [x] Small (single-file) inputs remain byte-identical through the new
      VMM-backed source path before the old OS-refill path is retired.
      (WP33)
- [x] Multiple ordered top-level source files assemble into one combined
      symbol scope, with correct file and line provenance across
      boundaries. (WP34)
- [x] Diagnostics raised in a non-first file report the correct filename,
      line, and column. (WP35)
- [x] A combined multi-file source exceeding 65535 bytes fails cleanly with
      the existing overflow diagnostic; a 9th top-level source file is
      rejected with the existing `CASM_DIAG_EXTRA_SOURCE` diagnostic. (WP34)
- [x] A large, under-cap input assembles successfully, closing the master
      plan's own gate-text wording literally, not just its four
      operationalized items above. (WP36, `casmbig1`)

**All five items are checked. WP32-WP36 are complete and approved (CASM
`0.1.38` build 1142). CASM Phase 7 is complete.** CASM Phase 8 (native R6
relocation consumption) remains separately gated and unstarted, per the
master plan's own sequencing -- this closure does not activate it.

# CASM Phase 8 - Native R6 Relocation

Parent Taskwarrior UUID: `c50df549-a7ae-4859-bd16-45a843425ce6` -
"CASM Phase 8: Native R6 relocation". Depends on WP37-WP42 below.

Parent plan:
`brain/plans/2026-07-16-casm-assembler-implementation-plan.md` (Phase 8
section)
WP37 plan:
`brain/plans/2026-07-24-casm-phase8-wp37-prerequisite-reconciliation.md`

## Phase 8 Work Packages

- [x] `285322e5-ef7e-468e-bf53-b19b110dccb0`: WP37 prerequisite
      reconciliation and Phase 0C.14 freeze. Plan approved as drafted:
      `brain/plans/2026-07-24-casm-phase8-wp37-prerequisite-reconciliation.md`.
      Active on `feature/casm-phase8-wp37` from `main` at `07b5062`
      (Phase 7's `feature/casm-phase7-wp36` merged to `main` first, per the
      user's confirmed decision, matching this project's established
      phase-transition convention). Verified the CASM Phase 7 completion
      gate (`0.1.38` build 1142, 189 bytes MAIN headroom). Found the
      default is inverted today (`.ORG` required, not merely absent) and
      that most of the relocatable-value ABI already exists end to end
      from Phase 5/6B foresight with only a producer missing -- the
      producer belongs in `expr.s` (gated on a whole-assembly relocatable-
      mode flag), not `symbols.s`, since no named-constant symbol kind
      exists before Phase 12 and every current symbol is a label. Found by
      tracing every `VAL_HI`/extracted-`VAL_LO` write in `emit.s` that four
      emission sites (not one) need the relocation hook, including two
      easy-to-miss cases: `.BYTE >label` already parses successfully today
      as a silent non-relocatable constant, and `LDA #>label` shares its
      code path with zero-page modes and must be distinguished from them.
      Found, mirroring WP32's precedent, that `symbol +/- constant`
      addends are always safely representable under the R6 common-page-
      delta model by associativity, so no new "unrepresentable expression"
      diagnostic is expected -- only a relocation-table-capacity one.
      User confirmed three architectural decisions: default relocatable
      origin `$3400` (matches CASM's own link address and every external
      app's `add_ca65_app` convention); `/S`-only scope this phase,
      deferring `.STATIC`/`.RELOC` source preamble directives; and a
      4096-entry/8192-byte relocation table capacity cap. Proposed WP38-
      WP42 breakdown recorded in the plan and in `brain/KNOWLEDGE.md`'s
      Phase 0C.14 section. Taskwarrior milestone (`c50df549`) and WP37-WP42
      child tasks (`285322e5`-WP37 through WP42, chained by dependency)
      created. Version-only completion increment applied: final CASM
      `0.1.39` build 1143, no-change rebuild stable, R6 footer of `casm.prg`
      itself unchanged in shape (base `$3400`, 1554 relocation entries),
      all three disk images (`image_d64`, `test_image_d64`,
      `casm_overflow_test_d64`) build clean. **WP37 is complete.**

- [x] `e8d31694-0602-42bd-8234-416f3af5b31a`: WP38 optional `.ORG`, default
      relocatable origin, and `/S` wiring. Plan approved as drafted:
      `brain/plans/2026-07-24-casm-phase8-wp38-default-origin-and-static-override.md`.
      Active on `feature/casm-phase8-wp38` from `feature/casm-phase8-wp37`'s
      tip. `.ORG` is now optional; absence defaults to relocatable mode at
      `CASM_DEFAULT_ORIGIN` ($3400); `/S` forces static mode and still
      requires an explicit `.ORG`. Found and closed two mechanism gaps
      during planning: `emitInit` never primed `CasmPc` (safe only while
      `.ORG` was mandatory-and-first), and `crpLabel` never guarded against
      a label preceding `.ORG` at all -- a latent gap since Phase 4 no
      fixture had ever exercised. Both closed by one unified mechanism:
      `CasmOrgSet` renamed `CasmOutputStarted` and broadened to "a label, a
      byte, or an explicit `.ORG` has already been processed this pass";
      a new exported `emitMarkStarted` (replacing `emitRequireOrg`) is the
      shared guard for `emitInstruction`/`emitByteList`/`emitWordList`
      (renamed call target only) and a new call added to `crpLabel`, run
      unconditionally before the pass-mode branch so both passes agree
      identically on a late `.ORG`. The late-`.ORG` case reuses
      `CASM_DIAG_DUPLICATE_ORG` per the user's confirmed decision -- no new
      diagnostic identifier. `test_casm_pass1`/`test_casm_passcheck` needed
      their own `CasmCliOptions` stand-in, found via a real link failure
      during implementation. Reused the existing `casmorg1` fixture
      (Phase 4 WP13, no `.ORG`) as the primary positive case -- its
      expected outcome flips from `CASM_DIAG_ORG_REQUIRED` to a successful
      relocatable assembly, the intended effect of this WP. Added
      `casmorgexpl1` (byte-identical trusted reference to `casmorg1`,
      proving implicit-default and explicit-`.ORG $3400` equivalence),
      `casmnoorg1` (forward-referenced label under the implicit origin), and
      `casmorglate1` (label then `.ORG`, closing the latent gap). User ran
      the full verification matrix (7 new-behavior checks, 3 new-rejection
      checks, 5 regression spot-checks including both standalone harnesses)
      and confirmed: "All tests pass." Final CASM `0.1.40` build 1145,
      no-change rebuild stable, all three disk images build clean. MAIN
      headroom 128 of 13568 bytes (down from 189; this WP cost 61 bytes, no
      bump needed). Walkthrough:
      `brain/walkthroughs/2026-07-24-casm-phase8-wp38-default-origin-and-static-override.md`.
      **WP38 is complete.**

- [x] `4a26fc20-3fcf-4d77-b41b-a46704af1491`: WP39 relocation
      classification. Plan approved as drafted:
      `brain/plans/2026-07-24-casm-phase8-wp39-relocation-classification.md`.
      Active on `feature/casm-phase8-wp39` from `feature/casm-phase8-wp38`'s
      tip. `CASM_EXPR_FLAG_RELOCATABLE` is now a real, correctly-produced
      classification; a new `CASM_PARSER_STMT_RELOCATABLE` bit is derived
      from it at the same site `FORCE_ABS` already is. No relocation table
      or emission-site change -- WP40 consumes the classification, this WP
      only makes it correct. Found and closed a real ordering hazard:
      `parserParseStatement` evaluates an instruction's operand expression
      inline, before `casmRunPass` ever dispatches to `emitInstruction`, so
      a no-`.ORG` source whose first statement is a bare instruction with a
      symbol operand (`JMP TARGET`, no leading label) would classify that
      symbol before relocatable mode was locked in -- WP38's own
      `casmnoorg1` fixture didn't catch this since it starts with a label.
      Resolved by moving the commit trigger into
      `parserParseExpressionValue` itself, skipped for `.ORG`'s own operand
      (which can itself reference a symbol per WP28's design; an
      unconditional trigger would make `.ORG` spuriously reject itself as
      a duplicate). Added `CasmRelocatableMode` (`emit.s`), since
      `CasmOutputStarted` alone cannot record *which* mode was chosen. User
      confirmed two module-boundary design decisions: `parser.s` calling
      `emit.s`'s `emitMarkStarted` directly (extending the existing
      `CasmPassMode`-read precedent), and extending `exprEvaluate`'s input
      ABI with a new relocatable-mode parameter rather than having `expr.s`
      import `emit.s` state directly (keeping `expr.s`/`test_casm_expr`
      decoupled from `emit.s`). `test_casm_expr`'s `CASE` table grew a 9th
      per-case field; all 30 pre-existing cases pass `relocMode = 0`
      (confirmed safe by re-reading the exact instruction sequence); four
      new `relocMode = 1` cases added, including a new `<ABSVAL` script
      isolating the new input-driven path from extraction-clearing (`ABSVAL`'s
      mock resolver never sets `RELOCATABLE` itself, unlike `RELVAL`). New
      end-to-end fixture `casmordhaz1` (no `.ORG`, `JMP TARGET` as the
      literal first statement) proves the ordering-hazard fix, deliberately
      byte-identical to `casmnoorg1`'s output. User ran the full
      verification matrix (`TEST_CASM_EXPR`'s 34 cases, the ordering-hazard
      fixture, and a full regression sample) and confirmed: "All tests
      pass." Final CASM `0.1.41` build 1147, no-change rebuild stable, all
      three disk images build clean. MAIN headroom 68 of 13568 bytes (down
      from 128; this WP cost 60 bytes, no bump needed). Walkthrough:
      `brain/walkthroughs/2026-07-24-casm-phase8-wp39-relocation-classification.md`.
      **WP39 is complete.**

- [x] `2175e962-2221-4308-8e3b-920065852d2d`: WP40 relocation table storage
      and emission-site hooks. Plan approved as drafted:
      `brain/plans/2026-07-24-casm-phase8-wp40-relocation-table-and-emission-hooks.md`.
      Active on `feature/casm-phase8-wp40` from `feature/casm-phase8-wp39`'s
      tip. New module `reloc.s`: `relocInit` allocates the 8192-byte
      (4096-entry) table unconditionally every Pass 2 run (VMM cost only,
      not MAIN); `relocRecord` no-ops under `CASM_PASS_MODE_MEASURE` and
      otherwise appends `CasmPc - CASM_DEFAULT_ORIGIN` via one immediate
      `vmmWindowWrite` per entry, deliberately not batched (the shared
      `CasmVmmBuffer` is also used transiently by `symbolsLookup` between a
      statement's relocatable operands, risking the same shared-scratch-
      clobber bug class this codebase has hit three times before).
      Re-tracing every byte-emission call site (not trusting WP37's
      original four-site enumeration) found a real correctness gap:
      `emitInstruction`'s absolute-family branch and `emitWordList` both
      emit a `VAL_LO`/`VAL_HI` pair, and `<`/`>` extraction is
      grammatically reachable at both (`LDA >LABEL`, `.WORD >LABEL`), so a
      naive "record `VAL_HI` when relocatable" check would wrongly mark a
      genuine constant `$00` padding byte as needing a page-delta patch.
      Resolved with two new `emit.s` helpers (`emitMaybeRecordHi`/`Lo`)
      using `VAL_HI`'s own zero/nonzero state to disambiguate, no new ABI
      field needed. Wired at six call sites across four logical emission
      points, with `eiTwoByte` additionally gated on
      `CasmInsn.Mode == CASM_MODE_IMMEDIATE` (re-verified, not re-assumed,
      that this guard is still needed: `ofRequire8Bit` is shared with
      indexed-indirect/indirect-indexed addressing, so `LDA (>LABEL),Y` is
      equally reachable and must never be recorded). New diagnostic
      `CASM_DIAG_RELOC_TABLE_FULL` at `$30`; `diagPrintFatal`'s selection
      bound extended to cover it. New standalone `test_casm_reloc` harness
      is the only real proof of `relocRecord`'s correctness at this stage
      (no R6 footer exists until WP41 to observe the table any other way);
      its `relocfull1` case does a genuine fill of all 4096 entries, not a
      poked shortcut. Two new end-to-end fixtures (`casmrelop1`,
      `casmrelop2`) prove the new hooks do not corrupt program bytes.
      User ran the full verification matrix (`TEST_CASM_RELOC`'s 4 cases,
      both new fixtures, and a full regression sample including 5
      standalone harnesses) and confirmed: "all tests pass." Final CASM
      `0.1.42` build 1154, no-change rebuild stable, all three disk images
      build clean. MAIN size bumped `$3500` -> `$3600` (144 bytes
      overflow; 106 bytes headroom at the new size). Walkthrough:
      `brain/walkthroughs/2026-07-24-casm-phase8-wp40-relocation-table-and-emission-hooks.md`.
      Separately from this WP's own scope, `casmempty.s` was removed from
      `test.d64`'s build during this session (`cc1541 -L`'s zero
      track/sector directory entry suspected of corrupting the disk),
      committed independently before this WP's own commit.
      **WP40 is complete.**

- [x] `005c8fec-684d-4f0d-a171-c7519081bef2`: WP41 native R6 footer
      serialization. Plan approved as drafted:
      `brain/plans/2026-07-25-casm-phase8-wp41-r6-footer-serialization.md`.
      Active on `feature/casm-phase8-wp41` from `feature/casm-phase8-wp40`'s
      tip. `reloc.s` gains `relocFinalize`, called unconditionally from
      `casm.s` right after `emitFinalize` succeeds; no-ops for a static
      assembly, otherwise appends the accumulated table (chunked through
      the existing `CasmVmmBuffer` window, no new buffer) and the 6-byte
      R6 footer (base address, entry count, `"R6"` magic as explicit hex,
      matching `tools/reloc.py` exactly) in one final write. This is the
      WP that makes the relocation table observable for the first time --
      WP39/WP40 both deferred their own end-to-end proof to "once the
      footer exists." Found, by checking the master plan's gate text
      against every fixture built since WP38 rather than assuming only new
      fixtures were needed, that five existing trusted references
      (`casmorg1`, `casmnoorg1`, `casmordhaz1`, `casmrelop1`, `casmrelop2`)
      go stale the instant this WP lands and need hand-derived footers, all
      verified byte-for-byte and hash-for-hash before any runtime test;
      `casmorgexpl1.ref.hex`'s stale "byte-identical to casmorg1" comment
      corrected (the divergence is the intended outcome of R6 existing,
      not a regression). MAIN size bumped `$3600` -> `$3700` (103 bytes
      overflow; 153 bytes headroom at the new size). The user's first
      verification pass found `TEST_CASM_PASS1` failing all 7 fixtures
      ("fffffff"); root-caused to `test_casm_reloc.s` (WP40) never calling
      `resourcesCleanup` before `DOS_EXIT`, permanently leaking two VMM/REU
      allocations and starving the next test's own allocation in the same
      VICE session. Fixed. Auditing every other standalone harness for the
      same defect class found `test_casm_symbols.s` (WP27, outside this
      WP's original scope) with the identical gap; fixed identically with
      the user's approval, rather than leaving a known leak in place.
      Second verification pass: user confirmed "all tests pass" across the
      full matrix (`TEST_CASM_RELOC`, `TEST_CASM_SYMBOLS`,
      `TEST_CASM_PASS1`, `TEST_CASM_PASSCHECK`, all five updated
      relocatable fixtures via `COMP`, and the static regression sample).
      Final CASM `0.1.43` build 1156, no-change rebuild stable, all three
      disk images build clean. Walkthrough:
      `brain/walkthroughs/2026-07-25-casm-phase8-wp41-r6-footer-serialization.md`.
      **WP41 is complete.**

- [x] `186aadb1-462d-48d1-87bb-e1c9af6c75e1`: WP42 verification, walkthrough,
      and Phase 8 completion gate. Plan approved as drafted:
      `brain/plans/2026-07-25-casm-phase8-wp42-verification-and-completion-gate.md`.
      Active on `feature/casm-phase8-wp42` from `feature/casm-phase8-wp41`'s
      tip. Traced the master plan's literal Phase 8 gate text against every
      WP38-WP41 verification section and found the one real gap every prior
      WP had deferred here: no relocatable fixture had ever been loaded
      away from its assembled address and actually run -- every one was
      checked exclusively via `COMP` against a byte reference, proving the
      file correct but never that the OS's existing `aptRelocate` loader
      (`src/command64/loader.asm`) correctly consumes CASM's native R6
      output. Closed it with a new fixture, `casmreloc1` -- its one
      relocatable byte reuses the already-proven immediate high-byte-
      extraction shape (`LDY #>label`, established correct by `casmrelop2`
      in WP40), so it tests `aptRelocate`'s consumption rather than
      introducing a new classification risk. Also re-ran WP31's 7-fixture
      Phase 3/4 diagnostic regression sample, unrun since WP36 despite
      WP39 materially changing the expression-evaluation core those
      fixtures depend on (`exprEvaluate`'s new parameter,
      `parserParseExpressionValue`'s new commit-trigger site) -- all 7
      reproduced their established outcomes correctly. User ran the full
      consolidated matrix (6 standalone harnesses, 22 byte-identical
      references including `casmreloc1`, 8 diagnostic scenarios, the
      7-fixture regression sample, static-fixture regression, and --
      the new part -- `casmreloc1` loaded and run at `$3400` (zero-delta
      control), `$4000`, and `$5000`, printing the same correct message at
      every address) and confirmed: "All tests pass." One non-reproducible
      anomaly noted during this WP: a single report of `TEST_CASM_PASS1`
      failing with the same VMM/REU-exhaustion signature WP41 twice
      diagnosed and fixed, despite a fresh VICE reset before the run and no
      further leak found on re-inspection of `casm_pass1.s`/
      `casm_passcheck.s` (both confirmed correct). Did not reproduce on a
      full from-scratch re-run in order; recorded as an open, unresolved,
      non-blocking observation rather than a confirmed defect, since no
      root cause could be identified or fixed. Checked all six Phase 8
      Acceptance items. Final CASM `0.1.44` build 1157, no-change rebuild
      stable, all three disk images build clean. Walkthrough:
      `brain/walkthroughs/2026-07-25-casm-phase8-wp42-verification-and-completion-gate.md`.
      **WP42 is complete, and with it the CASM Phase 8 milestone closes.**

## Phase 8 Acceptance

- [x] Relocatable output is the default; `/S` forces static output, still
      requiring an explicit `.ORG`. (WP38)
- [x] Every relocatable high byte (absolute/indexed/indirect operands,
      `.WORD` symbols, and `>symbol` high-byte extraction) is recorded at
      its correct code offset; constants, branches, `<symbol`, and
      zero-page operands are excluded. (WP39/WP40)
- [x] Relocation-table-capacity overflow is checked and diagnosed cleanly.
      (WP40)
- [x] The native R6 table and footer match `tools/reloc.py`'s byte layout
      exactly; CASM never invokes `tools/reloc.py` at runtime. (WP41)
- [x] Command 64 loads and runs generated R6 fixtures at several
      page-aligned addresses; static fixtures remain ordinary PRGs. (WP42:
      `casmreloc1` loaded and run at `$3400`/`$4000`/`$5000` via the OS's
      existing `aptRelocate` loader -- the first time any CASM-generated
      R6 output was actually loaded away from its assembled address and
      executed, rather than only byte-compared.)
- [x] The user completes the Phase 8 runtime walkthrough and approves.
      (WP42)

**All six items are checked. WP37-WP42 are complete and approved (CASM
`0.1.44` build 1157). CASM Phase 8 is complete.** That closure did not
activate the separately gated CASM Phase 9 (`.include` processing); Phase 9
was later activated through WP43 below.

# CASM Phase 9 - Include Processing

Parent Taskwarrior UUID: `687ada7e-4175-41b4-93f3-9e8df85c1a5c`.

Parent plan:
`brain/plans/2026-07-25-casm-phase9-include-processing.md`.

## Phase 9 Work Packages

- [x] `2826144e-b7c6-4372-8e1d-74cfff242d1a`: WP43 prerequisite
      reconciliation and Phase 0C.19 freeze. Dedicated plan:
      `brain/plans/2026-07-25-casm-phase9-wp43-prerequisite-reconciliation.md`.
      User approved completion. Final CASM `0.1.45` build 1160; no-change build
      stable, all three disk images pass, and no functional include behavior was
      added. WP44 remains pending separate plan approval and activation.
- [x] `2682d04b-05b0-4828-b88f-852234e3d006`: WP44 quoted include operand
      grammar. Detailed plan approved and active at
      `brain/plans/2026-07-25-casm-phase9-wp44-quoted-include-operand-grammar.md`;
      user-approved complete at CASM `0.1.46` build 1166. The corrected 14-case
      `test_casm_includ` runtime, stable no-change build, legacy whole-object
      harnesses, and all three disk images pass. WP45 remains pending.
- [x] `199b4da7-987a-44cf-a84d-b4e0b786f5d0`: WP45 physical file catalog and
      dynamic source loading. Detailed plan approved and active at
      `brain/plans/2026-07-25-casm-phase9-wp45-physical-file-catalog-and-dynamic-source-loading.md`.
      Standalone `include.s` module plus a dedicated `test_casm_catalog`
      harness only; `casmRunPass` keeps returning `CASM_DIAG_NOT_IMPLEMENTED`
      at `.INCLUDE` until WP46 wires frame traversal. Implementation complete:
      the 12-case `test_casm_catalog` harness, all standalone/whole-object
      regressions, and all three disk images pass statically; MAIN grown
      `$3A00` -> `$3E00` (694-byte measured overflow, user-approved). User
      runtime testing found and fixed two real defects (a harness device
      assumption; a genuine `sourceAppendFile` shared-scratch aliasing bug
      in `source.s`) before confirming all 12 cases pass
      (`CASM CATALOG: PASS`). User approved completion. Final CASM `0.1.47`
      build 1171; no-change rebuild stable; all three disk images pass.
      Walkthrough:
      `brain/walkthroughs/2026-07-25-casm-phase9-wp45-physical-file-catalog-and-dynamic-source-loading.md`.
      **WP45 complete.** WP46 remains pending separate plan approval and
      activation.
- [x] `005a1819-eda6-4fa5-89e1-5848a5076a7d`: WP46 frame stack, nested
      traversal, and cycle detection. Detailed plan approved and active at
      `brain/plans/2026-07-26-casm-phase9-wp46-frame-stack-nested-traversal-and-cycle-detection.md`.
      Standalone `source.s` frame stack (`sourceFramePush`, automatic pop
      via a rewired `sourceRefill`) plus a dedicated `tests/src/casm_frame`
      harness only; `casmRunPass` keeps returning
      `CASM_DIAG_NOT_IMPLEMENTED` at `.INCLUDE` until WP47 wires real
      dispatch. Implementation complete: the 8-case `tests/src/casm_frame`
      harness, all standalone/whole-object regressions, and all three disk
      images pass statically; MAIN grown `$3E00` -> `$4000` (221-byte
      measured overflow, user-approved). Also fixes a pre-existing WP34
      diagnostic-echo file-identity gap. User runtime testing found four
      real production defects, each masking the next: (1) `lexerFill`
      captured token provenance *before* `sourceNextByte`, going stale
      exactly when that call resolved a child's EOF and popped -- fixed
      with new `CasmSourceResult*` fields captured inside
      `sourceFetchPhysical`; (2) that capture clobbered `A` at `sfpEof`,
      destroying the `CASM_SOURCE_EOF` return; (3) depth-0 traversal had
      no end cap of its own and overran into `.INCLUDE` children appended
      mid-traversal -- fixed with a fixed `CasmSourceTopLevelEndLo/Hi`
      snapshot; (4) `sourceFramePush` saved `CasmSourceVmmCursor` (the
      bulk-refill read head, already at the file's end for any
      sub-256-byte fixture) rather than the logical parse position --
      fixed to `cursor - (blockLen - blockIndex)`. Fix 4 exposed that
      `frSinglePushPop` had been passing for the wrong reason, two
      cancelling bugs producing coincidentally correct line numbers. All
      8 cases confirmed passing on the clean, instrumentation-removed
      binary, which fits the original `$4000` envelope (no envelope
      amendment ships). User approved completion. Final CASM `0.1.48`
      build 1191; no-change rebuild stable; all three disk images pass.
      Walkthrough:
      `brain/walkthroughs/2026-07-26-casm-phase9-wp46-frame-stack-nested-traversal-and-cycle-detection.md`.
      **WP46 complete.** WP47 remains pending separate plan approval and
      activation.
- [x] `579096d9-ce77-44db-96a9-c32654238949`: WP47 ordered include graph and
      Pass 2 replay. Plan:
      `brain/plans/2026-07-29-casm-phase9-wp47-ordered-include-graph-and-pass2-replay.md`.
      Wires the first real production `.INCLUDE` dispatch into `casmRunPass`
      (Pass 1 loads/pushes/records an ordered event per include site; Pass 2
      replays those events with zero source-filesystem I/O), adds the
      16-byte include-event log in the metadata allocation's already-reserved
      second half, and gives `includeCatalogInit` its first production call
      site. User-confirmed scope: WP46's deferred per-frame diagnostic echo
      save/restore stays deferred; Pass 2 defensively re-derives child
      identity via `includeCatalogFind` and compares it against the recorded
      event (`emitCheckPassAgreement` precedent). End-to-end fixtures ship
      with CASM-vs-CASM flattened-equivalence diffing on a **new**
      `casm_include_test_d64` image, not `casm_overflow_test_d64` as
      originally planned: that disk was down to ~10 free blocks (WP34's
      combined-cap pair alone occupies 277) and this WP's verification
      writes eight output PRGs back to the disk it reads from. Also factored
      `includeCatalogLookup` out of `includeCatalogLoad` so Pass 2 has an
      entry point structurally incapable of filesystem I/O, rather than one
      merely trusted not to perform it. MAIN grown `$4000` -> `$4200`
      (measured 16,718-byte minimum, 178 bytes headroom);
      `test_casm_catalog` `$1B00` -> `$1C00`. One defect caught in code
      review before runtime: `crpParentIdentity` indexed the frame array
      with a stale `A`, reading frame 0 at every depth -- coincidentally
      correct at depth 1, wrong from depth 2 up. Zero-Pass-2-source-I/O
      proven structurally (the only reachable open path sits inside the
      `CASM_PASS_MODE_MEASURE` branch). All runtime checks passed on the
      first attempt: `test_casm_event`'s 15 cases, and all four end-to-end
      pairs reporting `FILES COMPARE OK`. User approved completion. Final
      CASM `0.1.49` build 1196; no-change rebuild stable; all four disk
      images pass. Walkthrough:
      `brain/walkthroughs/2026-07-29-casm-phase9-wp47-ordered-include-graph-and-pass2-replay.md`.
      **WP47 complete.** At WP47 closeout, WP48 remained pending separate plan
      approval and activation.
- [x] `797bb460-6d82-453c-8f55-7aa53d2eb095`: WP48 included-source diagnostics
      and tracebacks. **Complete** (2026-07-29). Plan:
      `brain/plans/2026-07-29-casm-phase9-wp48-included-source-diagnostics-and-tracebacks.md`,
      branch `feature/casm-phase9-wp48`. Fixed a live defect: a diagnostic
      raised inside an included file previously named the wrong file
      (`CasmSourceFileId` never tracks nested-frame identity). Bit-packs
      (kind, id) into the existing token-record `FILE_ID` byte rather than
      growing the frozen 39-byte record; adds a bounded include-site
      traceback rendered from the still-live frame stack at
      `diagPrintFatal` time (no new raise-time snapshot needed). No new
      `CASM_DIAG_*` values.
      Implementation and host-side verification are complete at candidate
      build 1203. User-approved envelopes: production `$4300`,
      `test_casm_pass1` `$4200`, `test_casm_frame` `$4100`; `test_casm_passcheck`
      remains `$4000`. Review-found unterminated-child line-drain crossing is
      fixed with a packed-identity boundary check and dedicated fixture.
      Post-pop traceback depth and originating-root recovery are retained in
      bounded frame arrays.
      First runtime pass confirmed filenames/columns but exposed resume-line
      misuse (`LINE 3`); dedicated include-site line arrays now correct it.
      `test_casm_event` grew to approved `$1D00` after a measured 31-byte
      overflow from the shared source-frame arrays.
      The user confirmed all runtime walkthrough cases pass and explicitly
      approved completion on 2026-07-29. Final CASM `0.1.50` build 1204;
      WP49 remains pending and was not activated.
- [x] `a8c3dbf0-9333-4489-9c3b-3e752049b693`: WP49 verification, walkthrough,
      and Phase 9 completion gate. **Complete** (2026-07-29). Approved plan:
      `brain/plans/2026-07-29-casm-phase9-wp49-verification-walkthrough-and-completion-gate.md`.
      Verification-only scope; production behavior changes require an amended
      plan and renewed approval. Host/static verification passed, all four disk
      images built independently, and the user reported the complete runtime
      matrix passes. Walkthrough:
      `brain/walkthroughs/2026-07-29-casm-phase9-wp49-verification-walkthrough-and-completion-gate.md`.
      The user explicitly approved completion. CASM remains `0.1.50` build
      1204; the approved verification-only package required no version change.

## Phase 9 Acceptance

- [x] `.INCLUDE` accepts one quoted 1-63-byte raw PETSCII filename and rejects
      malformed operands deterministically.
- [x] Explicit child devices override inherited parent devices; no search path
      or fallback probing occurs.
- [x] Nested includes support 16 active levels, detect direct/indirect cycles,
      and permit sequential reinclusion.
- [x] Up to 32 distinct physical files and 128 include events are bounded and
      diagnosed; distinct source bytes remain capped at 65,535.
- [x] Pass 2 opens no source files and exactly replays Pass 1's event graph.
- [x] Included labels, branches, static output, and relocatable R6 output match
      equivalent flattened trusted references.
- [x] Included diagnostics identify the physical location and parent include
      traceback.
- [x] The user completes the runtime walkthrough and explicitly approves Phase
      9 completion.

**All eight acceptance items are checked. WP43-WP49 are complete and approved;
CASM Phase 9 is complete at CASM `0.1.50` build 1204. Master-plan Phase 10,
Symbol Map and Listing, remains inactive and separately gated.**

## Phase 10 - Symbol Map and Listing

- [x] Parent Taskwarrior `32e09eea-691d-40bc-aa7a-7d2299fe093b`: implement
      deterministic `/M` symbol-map output and native `/L` listing files without
      changing generated PRG bytes. Complete at CASM `0.2.0` build 1260,
      user-approved 2026-08-08.
- Approved governing plan:
  `brain/plans/2026-07-29-casm-phase10-symbol-map-listing.md`.
- Milestone task: `wiki/tasks/casm-phase10-symbol-map-listing.md`.
- [x] WP50 `ad82f04d-0d34-4902-9a2c-ae27292902cf`: contract reconciliation and
      ABI freeze. Complete at CASM `0.1.51` build 1206, user-approved
      2026-07-31, per
      `brain/plans/2026-07-29-casm-phase10-wp50-contract-reconciliation.md` and
      `brain/walkthroughs/2026-07-31-casm-phase10-wp50-contract-reconciliation.md`.
- [x] WP51 `a64fa847-1b46-44fd-be3b-8ad7b1055c92`: listing stores and capture
      events. Complete at CASM `0.1.52` build 1222, user-approved
      2026-08-03, per
      `brain/plans/2026-07-29-casm-phase10-wp51-listing-stores-capture.md` and
      `brain/walkthroughs/2026-08-03-casm-phase10-wp51-listing-stores-capture.md`.
- [x] WP52 `0bf2e86b-0bd0-443a-b84b-b2c258e98181`: deterministic symbol map.
      Complete, per
      `brain/plans/2026-07-29-casm-phase10-wp52-deterministic-symbol-map.md`.
- [x] WP53 `aa57f461-36a9-455c-966f-ac484ec57b41`: listing naming,
      serialization, and cleanup. Complete at CASM `0.1.54` build 1237,
      user-approved 2026-08-06, per
      `brain/plans/2026-07-29-casm-phase10-wp53-listing-serialization-cleanup.md`
      and
      `brain/walkthroughs/2026-08-06-casm-phase10-wp53-listing-serialization-cleanup.md`.
- [x] WP54 `f4b598fd-bab1-4394-9415-c71e3ea1cfa5`: production integration —
      `/M` and `/L` fully wired into `casm.s`'s real `start`/`casmRunPass`
      sequence. Complete at CASM `0.1.55` build 1258, user-approved
      2026-08-08, per
      `brain/plans/2026-07-29-casm-phase10-wp54-production-integration.md`.
      Increment 1's dedicated failure-injection harness was formally
      dropped from scope (user decision) in favor of increment 6's live
      production-fixture matrix as Completion Gate evidence — see the
      plan's own Progress log.
- [x] WP55 `94d98a2b-7ad4-49f0-bf33-38702690eca9`: verification, walkthrough,
      and Phase 10 completion gate. Complete at CASM `0.1.56` build 1259,
      user-approved 2026-08-08, per
      `brain/plans/2026-07-29-casm-phase10-wp55-verification-walkthrough-completion-gate.md`
      and
      `brain/walkthroughs/2026-08-08-casm-phase10-wp55-verification-walkthrough-completion-gate.md`.
      Independently re-verified WP50-54's complete `/M`/`/L`
      implementation: baseline reconciliation, a 9-item full-path code
      review, 13/13 harnesses live under VICE, a PRG/R6 identity/bounds/
      failure-injection audit, and a 4-session live runtime walkthrough.
      Four non-blocking findings disclosed (a pre-existing, codebase-wide
      fault-injection gap for four raw-I/O listing diagnostics; this OS's
      `LOAD` always relocating regardless of a static CASM output's own
      `.ORG`; `MORE` having no abort key; a VICE-testing process note).
- [x] Obtain explicit Phase 10 completion approval before the separate
      `0.1.56` -> `0.2.0` promotion. Approved 2026-08-08; promotion
      applied: `VERSION_MINOR`/`VERSION_STAGE` changed together in
      `casm.s`, build `1259` -> `1260`, live-verified via VICE
      (`CASM V0.2.0.1260`).

**Phase 10 is complete.** CASM stands at `0.2.0` build 1260, user-approved
2026-08-08. `/M` and `/L` are both fully implemented in production `casm`,
independently re-verified by WP55, with no assembly, listing, or map
behavior changed beyond the version/build artifact itself.

## Phase 11 - Base-Release Hardening and Documentation

- [x] WP56 `636eddce-4777-4ccb-b79f-0e9903fdd10d`: contract reconciliation
      and audit-risk triage. User-approved 2026-08-09.
- [x] WP57 `d8b09018-8c17-4c98-8ee7-e32d755952ea`: fault-injection
      infrastructure design spike. User-approved 2026-08-08; established the
      runtime `$1000` `OS_API` interception mechanism.
- [x] WP58 `d297b689-3fba-4e16-81f7-8176b39a07e2`: apply fault injection
      across file/VMM-touching modules. User-approved complete 2026-08-11;
      29 cases across six fixtures pass live in VICE, with no production
      source or version change.
- [x] WP58 Increment 1: extracted the shared `faultstub.inc` and proved the
      refactor behavior-preserving in live VICE.
- [x] WP58 Increment 2: expanded `casm_faultinject` to eight `fileio.s`
      cases covering create/write/short-write/close/delete/read failures and
      EOF discrimination. Final build 1005 and `test_image_d64` pass; live VICE
      printed `........`, `CASM FAULTINJECT: PASS`, and returned to
      `C64[8]:>`. User-approved 2026-08-09.
- [x] WP58 Increment 3 complete, user-approved 2026-08-09: added
      collision-safe `test_casm_faultvmm` with distinct no-REU/OOM and
      failed free/read/write ownership-retention cases. Final build 1001;
      `test_image_d64` and `casm_overflow_test_d64` pass. The fixture lives on
      the overflow image as `test_casm_faultv` because `test.d64` has no free
      directory entries. Live VICE printed `.....`, `CASM FAULT VMM: PASS`,
      and returned to `C64[9]:>`.
- [x] WP58 Increment 4: state-cleanup fixtures cover `source.s`, `symbols.s`,
      `reloc.s`, and `include.s`; all pass live in VICE.
- [x] WP58 Increments 5-7: all six fixtures are wired to their disk targets,
      freshly rebuilt, consolidated live verification passes 29/29 cases, and
      the walkthrough and completion gate are user-approved.
- [x] WP59 `4a1fab7c-28af-4404-af39-6f283b552e55`: harden every exported
      `listing.s`/`map.s` routine and its private transitive paths. Detailed
      plan approved 2026-08-11.
- [x] WP59 Increment 1: frozen 19-export contract matrix user-approved.
- [x] WP59 Increment 2 user-approved 2026-08-11: `test_casm_flist` passes
      15/15 live in VICE, restores the real
      API vector before print/exit, and returns to `C64[8]:>`. Build 1001;
      listing test disk has 126 blocks free. No production CASM change.
- [x] WP59 Increment 3 user-approved 2026-08-11: eight new deterministic
      allocation/write/flush/replay/serializer
      cases bring `test_casm_flist` to 23/23 live VICE passes. Build 1007;
      `$2200` unchanged; 118 disk blocks free. No production CASM change.
- [x] WP59 Increment 4 user-approved 2026-08-11: listing lifecycle fixes and
      deterministic retry/cleanup verification complete.
      `test_casm_flist` passes 33/33 live in VICE; build 1009, `$2200`
      unchanged, 112 listing-disk blocks free, no test artifacts remain.
      Production CASM build 1261 remains `0.2.0`; no public ABI or valid-output
      format changed.
- [x] WP59 Increment 5 user-approved 2026-08-11: eight full-serializer cases
      bring `test_casm_flist` to 41/41
      live VICE passes. Build 1014; `$2400` test envelope; 105 disk blocks
      free; no `FLI05*.LST` artifacts. Production CASM unchanged.
- [x] WP59 Increment 6 user-approved 2026-08-11: filename and included-device
      validation hardening complete. The
      approved split keeps 41 Increment 2-5 cases in `test_casm_flist` and puts
      nine device/name/header/snapshot cases in `test_casm_flmeta`; both pass
      live (41/41 and 9/9), return to `C64[8]:>`, and leave no `FLI06*.LST`
      artifact. Listing disk has 75 blocks free. Production CASM build 1262
      remains `0.2.0`; no public ABI, storage, diagnostic, or valid-output
      format changed.
- [x] WP59 Increment 7 user-approved 2026-08-11: expanded map validation,
      decimal-boundary, determinism, formatting, and exported-contract coverage
      complete. `test_casm_map` build
      1012 passes 23/23 live in VICE, returns to `C64[8]:>`, and leaves 71
      listing-disk blocks free. No production source or valid map bytes changed.
- [x] WP59 Increment 8 user-approved 2026-08-11: static ownership, shared-scratch, BSS initialization,
      exported-state, local-header, and DOX audit complete. No defect found: no
      private ZP, unsafe scratch lifetime,
      uninitialized load-bearing BSS, or ownership disagreement. Stale pre-WP54
      comments corrected without executable/ABI/storage/output change. CASM
      build 1263 and map harness build 1013 retain prior code/relocation sizes;
      no-change rebuilds stable.
- [x] WP59 Increment 9 user-approved 2026-08-11: consolidated builds, artifacts,
      regressions, WP58 compatibility, and production `/M`/`/L` live
      verification complete. Full and image builds plus no-change rebuild pass;
      a shared-fixture NMOS indirect-JMP page-boundary hazard was replaced by a
      patched absolute JMP with no production impact. Live WP58/listing/metadata
      regressions pass 8/8, 41/41, and 9/9; the final map image remains 23/23.
      Production `/M`, `/L`, and `/M /L` smokes validate, create expected
      listing/map artifacts, and return to `C64[8]:>`. User-approved 2026-08-11.
- [x] WP59 Increment 10 and completion user-approved 2026-08-11. The
      completion walkthrough records every export/private path, fix, metric,
      fixture result, compatibility check, and manual confirmation step.
      CASM advanced to `0.2.1.1264`; the PRG differs from `0.2.0.1263` only at
      the stage and build banner bytes. A second image build is stable, and the
      live `0.2.1.1264` banner returns to `C64[8]:>`. WP59 is complete.
- [x] WP60 `bd441121-dffa-4d69-8f3a-8572e0643322`: opcode, addressing, and
      boundary hardening. **Complete 2026-08-12 at CASM `0.2.2` build
      `1266`.** Detailed ten-increment plan approved 2026-08-12 at
      `brain/plans/2026-08-11-casm-phase11-wp60-opcode-addressing-boundary-hardening.md`.
- [/] WP60 Increment 1 complete 2026-08-12, awaiting user approval: all 151
      legal NMOS 6502/6510 tuples independently frozen and mechanically
      reconciled byte-for-byte against `opcodes.s`'s `opcodeMaskLo/Hi`,
      `opcodeRunOffset`, `opcodeBytes`, and `modeLength`, with the
      151/151/151 one-to-one mask-bit/opcode-byte correspondence proven. No
      production defect found; no production or fixture change.
- [/] WP60 Increment 2 complete 2026-08-12, awaiting user approval: inventoried
      existing evidence across all 8 required boundary domains (52 rows: 13
      reuse, 9 strengthen, 30 add). Several gaps are pre-generated `.seq`
      fixtures never wired to an automated assertion. Flagged a plan-text
      correction: VMM window-transfer chunk boundary is 64/65 bytes, not
      255/256. No production or fixture change.
- [x] WP60 Increment 3 complete 2026-08-12: added `CLD` as the literal first
      instruction at `casm.s`'s `start:` entry point. Build 1265: code bytes
      18580 -> 18581 (exactly +1), relocations unchanged at 2806; no-change
      rebuild stable; `image_d64` builds clean at the unchanged 334-block
      baseline. No BSS/zero-page/ABI change; CASM remains `0.2.1`.
- [x] WP60 Increment 4 complete 2026-08-12: `test_casm_opcodes` direct
      matcher harness (opcodes.s only) with 151 legal-tuple cases plus 46
      focused cases (unsupported modes, 8-bit range, ZP/Absolute selection,
      FORCE_ABS, ZP,X/ZP,Y independence incl. the LDX/STX/LDY/STY role swap,
      all eight branches, Implied/Accumulator distinctness) = 197 cases, each
      asserting opcode/mode/length or diagnostic, A/carry, statement
      preservation, stack balance, and (legal tuples) a 151-bit coverage
      bitmap. Joined `casm_listing_test_d64` (test.d64 directory full); both
      disk targets build clean. Live VICE: 197/197 pass, `CASM OPCODES:
      PASS`, normal `C64[8]:>` return. Production CASM unchanged.
- [x] WP60 Increments 5-7 complete 2026-08-12: end-to-end 151-tuple
      `casmopall.s`/`casmopall.ref` native `COMP` proof (Increment 5);
      numeric/addressing/branch/PC boundary hardening via `test_casm_expr`
      and a new `test_casm_bounds` harness (Increment 6); symbol/relocation/
      VMM/source boundary hardening across `test_casm_symbols`,
      `test_casm_reloc`, `test_casm_vmm`, and `test_casm_spanread`
      (Increment 7). Increment 7 independently reproduced a real,
      previously-suspected-but-unresolved one-byte-source phantom-EOF-byte
      defect in `sourceLoad`/`sourceNextByte` (see `brain/task.md`); left as
      a ready-to-activate regression case, not fixed under WP60. All
      production CASM unchanged since Increment 3; see `brain/task.md` for
      full detail.
- [x] WP60 Increment 8 complete 2026-08-12: consolidated build and live-VICE
      re-verification of everything Increments 3-7 introduced, after a full
      clean/unrestricted rebuild. `casm.prg` re-confirmed byte-identical
      (18581 code bytes, 2806 relocations, build `1265`) since Increment 3;
      no-change rebuild stable; no disk-capacity overflow. Live VICE re-ran
      the complete changed/affected harness set (opcodes, opcode-all COMP,
      bounds, spanread, symbols, reloc, vmm) plus a production `/M /L`
      smoke assembly, all PASS with clean shell returns. Record:
      `brain/reviews/2026-08-12-casm-phase11-wp60-increment8-consolidated-verification.md`.
      Requesting user review before Increment 9 activates.
- [x] WP60 Increment 9 complete 2026-08-12: audit and walkthrough
      reconciling the Increment 1 opcode oracle (151/151/151, re-proven live
      three times over) and the Increment 2 boundary register (52 required
      rows) against Increments 6-7: 48/52 closed, 4 residual items flagged
      for an explicit accept/defer decision (`FORCE_ABS` two-pass
      re-resolution untested; source 65,535/65,536-byte extent boundary
      untested; symbol name-length-32 rejection uncovered, owned by
      `lexer.s`; empty-source-file row is a `cc1541` tooling gap, not a code
      gap). The one real production defect found (Increment 7's one-byte-
      source phantom-EOF-byte) is now tracked separately as Taskwarrior task
      42 (`882433f0-cde1-4849-8b3c-df32613518c3`), not folded into WP60. No
      production, fixture, or build-system change. Walkthrough:
      `brain/walkthroughs/2026-08-12-casm-phase11-wp60-increment9-audit-walkthrough.md`.
      Requesting review before Increment 10 (version bump to `0.2.2`)
      activates.
- [x] WP60 Increment 10 complete 2026-08-12, **WP60 complete**: version-only
      bump, `0.2.1` -> `0.2.2` (build `1266`). First build's byte delta
      against the pre-bump PRG is exactly 2 bytes, both in the banner
      string (version-stage digit, build-counter last digit); size and
      `image_d64` free-block count unchanged. Second build proved no-change
      stability (counter and hash both held). Independently re-derived the
      code/relocation envelope: 18581 bytes / 2806 relocations, unchanged
      since Increment 3. Live VICE: `CASM V0.2.2.1266` banner, the
      `casmopall.s`/`casmopall.ref` native `COMP` round trip, and
      `test_casm_opcode` (197/197) all pass under `0.2.2`, clean shell
      returns. Taskwarrior task 40 marked done. The 4 residual boundary
      items from Increment 9 and the separately tracked phantom-EOF-byte
      defect (Taskwarrior UUID `882433f0-cde1-4849-8b3c-df32613518c3`)
      remain open by design, not blocking this completion. See
      `brain/task.md` for full detail.
- [x] WP61 `f6845310-bcce-4448-b5f2-0aa19a73723b`: determinism and remaining
      boundary spot-checks. **Complete 2026-08-12 at CASM `0.2.2` build
      `1266`** (no version bump: no production change occurred across
      WP61). Nine-increment plan approved 2026-08-12 at
      `brain/plans/2026-08-12-casm-phase11-wp61-determinism-and-boundary-spot-checks.md`.
- [/] WP61 Increment 1 complete 2026-08-12, awaiting user approval: all 5
      in-scope items (determinism + the 4 boundary residuals) dispositioned
      with source-trace-confirmed mechanisms and exact expected
      diagnostics; disk free space re-surveyed on every candidate target.
      No production or fixture change. See `brain/task.md` for full detail.
- [/] WP61 Increment 2 complete 2026-08-12, awaiting user approval:
      determinism proof for PRG/R6. `casmhello.s`, `casmreloc1.s`, and
      `casmopall.s` each assembled twice live to independent output names;
      all 3 self-compares (`FILES COMPARE OK`) plus 2 independent-reference
      cross-checks (also `FILES COMPARE OK`) passed. PRG and R6 relocation
      determinism both closed. No production defect; joined
      `casm_opcode_test_d64` with 2 pre-existing fixtures rather than
      adding a new disk. See `brain/task.md` for full detail.
- [/] WP61 Increment 3 complete 2026-08-12, awaiting user approval:
      determinism proof for listing and map, both using `casmopall.s` on
      the already-attached `casm_opcode_test_d64` (no new fixture/disk).
      `/L`: `comp m1.lst m2.lst` -> `FILES COMPARE OK`. `/M`: two live runs'
      screen RAM independently decoded and diffed, identical 8-symbol map
      both times (manual/live evidence, `/M` writes no file). **WP61's full
      determinism charter (PRG, R6, listing, map) is closed.** No
      production defect. See `brain/task.md` for full detail.
- [/] WP61 Increments 4-7 complete 2026-08-12, awaiting user approval:
      closed all 3 remaining WP60-flagged boundary residuals. Increment 4
      (FORCE_ABS two-pass): new `casmfa2p.s` forward-reference fixture,
      self-compare and reference cross-check both `FILES COMPARE OK`.
      Increment 5 (symbol/token length-32): new
      `tests/src/casm_lexer/casm_lexer.s`, the first harness anywhere in
      this codebase to link `lexer.s` directly -- `CASM LEXER: PASS`
      (2/2). Increment 6 (source extent): new `casmsrcmax.s` (exactly
      65,535 bytes) accepts; combined with a 1-byte second file (65,536)
      rejects with `CASM: SOURCE OFFSET OVERFLOW`, no partial output.
      Increment 7 (consolidated verification): a full unrestricted rebuild
      caught and fixed a build-system-only bug (Increment 4's `casmfa2p`
      reference wasn't excluded from `test.d64`'s already-full directory,
      overflowing it) -- no production impact. Re-ran the complete changed
      set live from the clean rebuild; all PASS. `casm.prg` remains
      byte-identical to its WP60 `0.2.2` state throughout. See
      `brain/task.md` for full detail.
- [x] WP61 Increment 8 complete 2026-08-12: audit and walkthrough. All 5
      Increment-1-register items closed; one build-system defect found and
      fixed within WP61 (Increment 7), zero production defects. No version
      bump due (no production change). Walkthrough:
      `brain/walkthroughs/2026-08-12-casm-phase11-wp61-increment8-audit-walkthrough.md`.
      **User approved WP61 completion 2026-08-12.** Taskwarrior task
      `f6845310-bcce-4448-b5f2-0aa19a73723b` closed.
- [/] WP62 `27332a0c-7bb6-4c2e-b455-6f5e03b4b84e`: documentation sync.
      Seven-increment plan approved 2026-08-12 at
      `brain/plans/2026-08-12-casm-phase11-wp62-documentation-sync.md`;
      Increment 1 (scope/staleness register freeze) activated.
- [/] WP62 Increment 1 complete 2026-08-12, awaiting user approval:
      clean-room re-read of `brain/KNOWLEDGE.md`,
      `wiki/casm-programmers-reference.md`,
      `wiki/casm-utility.md`/`docs/casm-utility.md`, `CHANGELOG.md`, and
      `src/external/casm/AGENTS.md`. `KNOWLEDGE.md` is missing Phase 4,
      10, **and** 11 sections (bigger gap than WP56 originally flagged);
      exact insertion points pinned. Cataloged version/build staleness and
      undocumented known bugs across the two user-facing docs, a missing
      WP61 `CHANGELOG.md` entry, and significant staleness in
      `src/external/casm/AGENTS.md` (still describes closed Phase 10 as
      inactive, no Phase 11 content). No documentation change made yet.
      See `brain/task.md` for full detail.
- [x] WP62 Increments 2-6 complete 2026-08-12, awaiting user approval:
      implemented via two parallel background agents (KNOWLEDGE.md/AGENTS.md
      vs. the three user-facing docs/CHANGELOG), then independently
      verified against the Increment 1 register before committing. Added
      the 3 missing `brain/KNOWLEDGE.md` phase sections at their pinned
      insertion points; fixed all cataloged discrepancies in
      `wiki/casm-programmers-reference.md` and
      `wiki/casm-utility.md`/`docs/casm-utility.md` (kept byte-identical);
      added the missing WP61 `CHANGELOG.md` entry (one count inaccuracy
      caught and fixed during review); rewrote
      `src/external/casm/AGENTS.md`'s stale Phase 10 framing and added
      Phase 11 content. No production change; no version bump. See
      `brain/task.md` for full detail. Requesting review before Increment 7
      (audit and walkthrough) activates.
- [x] WP62 Increment 7 complete 2026-08-12, awaiting user approval to close
      WP62: reconciled all 18 Increment 1 register rows against the
      Increments 2-6 commit, all closed; confirmed CASM remains `0.2.2`
      build `1266` directly against `casm.s`; confirmed the two utility docs
      stay byte-identical; task logs already accurate, no fix needed.
      Walkthrough at
      `brain/walkthroughs/2026-08-12-casm-phase11-wp62-increment7-audit-walkthrough.md`.
- [x] WP62 complete 2026-08-12, user approved. Taskwarrior task 42 closed.
      CASM remains `0.2.2` build `1266` (documentation-only work package).
- [x] WP63 plan approved 2026-08-12, activated (Taskwarrior task 42):
      `brain/plans/2026-08-12-casm-phase11-wp63-verification-walkthrough-completion-gate.md`.
      Full regression build, fresh consolidated live-VICE re-run of every
      `test_casm_*` harness, and the user's own runtime walkthrough before
      Phase 11 is marked done. Known non-critical bugs (#36/#40/#41) stay
      deferred. **Deviation from plan**: live regression found a real,
      newly-discovered defect (not one of the 3 known bugs) -- 6
      fault-injection test harnesses (`casm_faultvmm.s`,
      `casm_faultsource.s`, `casm_freloc.s`, `casm_finc.s`,
      `casm_fsym.s`, `casm_faultinject.s`) never called `faultUninstall`
      before exit, leaving the shared `$1000` OS_API vector dangling for
      whatever ran next in the same session. User explicitly directed an
      inline fix (overriding the plan's disclose-and-defer default for
      new defects); fixed and live-reverified clean. This is test
      infrastructure only, no production CASM behavior changed. See
      `brain/task.md` for full root-cause and verification detail.
      Committed `93a5365`. **User approved 2026-08-13. WP63 complete;
      Phase 11 (WP56-63) complete.** CASM remains `0.2.2` build `1266`
      (test-infrastructure-only work package, no version bump). Full
      walkthrough:
      `brain/walkthroughs/2026-08-12-casm-phase11-wp63-verification-walkthrough-completion-gate.md`.

## Phase 12 - Constants and Expanded Expressions (CASM 0.3)

- [/] Governing plan **approved 2026-08-13** (Taskwarrior task 43,
      `c547c74f-5080-4f2e-b086-e4e2273b5336`, started):
      `brain/plans/2026-08-13-casm-phase12-constants-expanded-expressions.md`.
      Approves WP64-71 (contract freeze; named constants; current-address
      symbol; parens/precedence; arithmetic/bitwise operators; character
      literals; relocation-algebra closure; verification/walkthrough/
      completion gate) as drafted, no changes. Also folds in a lowercase-
      PETSCII symbol convention note (real C64 platforms are single-case;
      Command64's mixed-case charset is an anomaly) — see
      `docs/casm-utility.md`/`wiki/casm-programmers-reference.md` and
      memory `reference-c64-lowercase-petscii-convention`. Taskwarrior
      task 44 (`c307441c-74ab-47a8-bb4c-e997d38bcf99`) created for WP64.
- [x] WP64 **complete, user-approved 2026-08-13**:
      `brain/plans/2026-08-13-casm-phase12-wp64-contract-freeze.md`.
      Design-only (no production source change): precedence-climbing
      evaluator architecture, a formal relocation representability rule
      (new operators are static-operand-only; a relocatable operand
      reaching one is `CASM_DIAG_EXPR_RELOC_UNSUPPORTED`, since the
      relocation table can only ever represent one symbol plus a static
      addend), a paren-vs-indirect-addressing rule (`(expr)` only after
      a binary operator, never as a whole operand), the named-constant
      symbol-table ABI (`CASM_SYMBOL_FLAG_CONSTANT`), the current-address
      symbol's design, diagnostic numbers `$43`-`$45`, and a rough
      envelope-size budget (114 bytes of headroom remain; recommends a
      `$5500`→`$6000` bump). Hand-verified against real
      `parser.s`/`common.inc` source and recorded as a new Phase 12
      section in `brain/KNOWLEDGE.md`. Walkthrough:
      `brain/walkthroughs/2026-08-13-casm-phase12-wp64-contract-freeze.md`.
      Taskwarrior task 44 done. WP65 (named constants) is next and needs
      its own detailed plan and separate approval before any source edit.
- [x] WP65 **complete, user-approved 2026-08-14** (Taskwarrior task 45,
      `e32c08c8-1435-43b2-a075-a2bb2f6e0c8f`, done):
      `brain/plans/2026-08-13-casm-phase12-wp65-named-constants.md`.
      `identifier = expr` named constants with full forward-reference
      support (including genuine transitive-cycle detection via
      `CASM_DIAG_EXPR_CIRCULAR`), resolved by deferring constant value
      resolution to the existing Pass1→Pass2 seam so constants can
      reference labels (not just other constants) per WP64's own
      representability rule. Live-verified against the real `casm.prg`
      binary under VICE: a numeric constant, a constant referencing
      another constant with an addend, and a constant forward-referencing
      a not-yet-defined label all produce byte-exact correct output;
      mutual and self-reference cycles correctly raise `CIRCULAR CONSTANT
      DEFINITION`; a constant redefining a label's name correctly raises
      `DUPLICATE SYMBOL`. Full disk-image tree rebuilds clean. Three
      commits on `feature/casm-phase12-wp65` (`baa7045`, `07bdecf`,
      `dd4bb9b`). Walkthrough:
      `brain/walkthroughs/2026-08-13-casm-phase12-wp65-named-constants.md`.
      See `brain/task.md` for full detail including two real findings
      (new source-position infrastructure needed; an addend-consumption
      bug caught live). WP66 (current-address symbol) is next and needs
      its own detailed plan and separate approval before any source edit.
- [x] WP66 **complete, user-approved 2026-08-14** (Taskwarrior task 43
      under this session's numbering, `074c9d56-f6d9-4d65-8de4-96421d4c21b1`,
      done):
      `brain/plans/2026-08-14-casm-phase12-wp66-current-address-symbol.md`.
      `*` as a new expression primitive (`CASM_TOKEN_STAR`), evaluating to
      `CasmPc`, relocatable by construction — resolved inline in
      `exprEvaluate`'s own new `curAddr` arm (never through the resolver
      callback) and falling through into the identifier arm's shared
      addend/extraction tail, so `*+N`/`*-N`/`<*`/`>*` all work for free.
      `name = *` also ships (user-confirmed in-scope, not deferred):
      `ppsConstant` gained a third RHS arm and `crpConstant` computes the
      value inline from `CasmPc` at Pass 1 (no resolution-sweep needed,
      unlike a label forward-reference), with a new `CasmConstantIsCurAddr`
      flag driving `CASM_SYMBOL_FLAG_LABEL_DERIVED` alongside `RESOLVED` —
      a combination no other RHS kind produces, and one Increment 4's own
      live trace of `crpConstant` caught before it shipped silently wrong
      (a naive numeric-RHS-shaped implementation would have classified
      `name = *` as static). Live-verified against the real `casm.prg`
      binary under VICE: `bufstart = *` and bare `*` combined with
      extraction+addend (`lda #<*+3`) both produce byte-exact correct
      output (`CASM: INPUT VALIDATED`, PRG bytes extracted and hand-
      checked); `test_casm_expr` (45 cases, 7 new), `test_casm_symbols`,
      `test_casm_pass1`, `test_casm_include`, and `test_casm_frame` all
      still PASS. Full disk-image tree rebuilds clean (three test-harness
      envelope bumps, one disk-capacity relocation). Walkthrough:
      `brain/walkthroughs/2026-08-14-casm-phase12-wp66-current-address-
      symbol.md`. WP67 (parentheses and explicit precedence) is next and
      needs its own detailed plan and separate approval before any source
      edit.
- [x] WP67 **complete, user-approved 2026-08-14** (Taskwarrior task 43
      under this session's numbering, `8d988ac6-730a-440a-bc6e-a12e0c36888d`,
      done):
      `brain/plans/2026-08-14-casm-phase12-wp67-parens-precedence.md`.
      Precedence-climbing evaluator architecture (WP64's own design, built
      here for the first time) plus parenthesized sub-expressions:
      `exprEvaluate` split into `parsePrimary`/`parseOperatorTail`, a
      parenthesized group recursing into the same pair, bounded to 8
      levels (`CASM_EXPR_PAREN_MAX_DEPTH`) via the hardware stack.
      User-confirmed scoping fork: WP67 lifts the pre-existing restriction
      that only `IDENTIFIER`/`*` could take a trailing addend, so `1+1`
      now succeeds instead of `CASM_DIAG_EXPR_UNSUPPORTED` — a deliberate,
      disclosed change to two existing fixtures, not a silent regression.
      WP64's relocation-representability rule enforced per operator
      application for the first time (`CASM_DIAG_EXPR_RELOC_UNSUPPORTED`);
      `ppsConstant`'s own RHS grammar stays untouched (separate
      user-confirmed scoping decision, matching WP65/66's precedent). Two
      real integration gaps caught live, not by static reading: both new
      diagnostics needed message-table entries in `diagnostics.s` (would
      otherwise have silently fallen through to a generic "unknown
      diagnostic" message), and `posImmediate`'s own token whitelist
      needed `CASM_TOKEN_LPAREN` added (without it, `lda #(1+2)` tripped
      `SYNTAX ERROR` before `exprEvaluate` was ever reached). A live
      "regression" (`test_casm_listcap` failing 5 of 7 fixtures) turned
      out, after bisection against the pre-WP67 source, to be a disk-
      capacity crunch (`casm_listing_test_d64` hit 0 free blocks, leaving
      no runtime headroom for the harness's own 10 output-file writes),
      not a code defect — resolved by relocating three self-contained
      harnesses to `casm_include_test_d64`. Live-verified: `#<(SCREENW+2)`
      and `#(1+2)` (a named constant and pure numbers inside a group) both
      produce byte-exact correct output; `LBL1+(LBL2)` (two relocatable
      labels) correctly produces `CASM: EXPRESSION RELOCATION UNSUPPORTED`
      with the source-context caret pointing at the right token; 10 new
      `test_casm_expr` cases (`CASE_COUNT` 45→55) plus every other
      regression harness (`symbols`, `pass1`, `include`, `frame`,
      `listcap`, `passcheck`, `bounds`, `cliderive`, `lexer`) all PASS.
      Full disk-image tree rebuilds clean. Walkthrough: `brain/
      walkthroughs/2026-08-14-casm-phase12-wp67-parens-precedence.md`.
      WP68 (arithmetic/bitwise operators) is next and needs its own
      detailed plan and separate approval before any source edit.
- [x] WP68 **active, plan approved 2026-08-14** (Taskwarrior task 43,
      `c1b8e145-0a9c-4e15-aaab-4e82fc253363`, depends on WP67):
      `brain/plans/2026-08-14-casm-phase12-wp68-arithmetic-bitwise-
      operators.md`. Implements static-only `*`, `/`, `<<`, `>>`, `&`,
      `^`, `|`, unary `-`, and unary `~` against WP67's precedence parser.
      Approved semantics are unsigned 16-bit multiply/divide, checked
      multiply and left-shift overflow, logical right shift, 0-15 shift
      counts, and two's-complement unary negation. Modulo and expanded
      named-constant RHS grammar remain excluded. Atomic Increment 1
      (baseline and contract audit) complete: narrow builds pass; an
      immediate no-change rebuild preserved all three artifact hashes and
      build counters (`casm` 1296, expression 1047, lexer 1005); `$6000`
      production/`$1000` expression caps confirmed; no new zero-page is
      available or planned; unresolved operands must be rejected before
      value access. Atomic Increment 2 complete: stable `/`, `&`, `^`, `|`,
      `~`, `<<`, `>>` tokens added; `*`/`-` remain contextual; shift tokens
      retain first-byte provenance and lone `<`/`>` remain extraction.
      Expanded real-lexer harness builds clean at build 1008; CASM build
      1298 links within `$6000`. One branch-range build failure was fully
      diagnosed and corrected with an absolute-JMP trampoline. Bounded VICE
      run proved boot/dispatch but remained at `LOADING...` for both allowed
      observations, so live result is inconclusive and deferred to Increment
      9 rather than called a product failure. Atomic Increment 3 (precedence
      dispatcher, existing `+`/`-` behavior first) reached its envelope stop
      gate: narrow expression/CASM builds link, but `test_casm_pass1`
      overflows its `$5500` whole-link cap by 130 bytes during
      `test_image_d64`. No cap changed. Smallest round-page fit is `$5600`,
      user-approved and applied. Atomic Increment 3 complete: full test image
      builds with 12 blocks free; exact-PETSCII VICE launch ran all 55
      expression fixtures to `CASM EXPR: PASS` and returned to `c64[8]:>`.
      Increment 4 implemented bitwise/unary semantics and nine focused cases,
      then stopped at its envelope gate: `test_casm_expr` exceeds `$1000` by
      161 bytes. User approved `$1100`, which now links all 64 cases.
      Packaging then found `test_casm_pass1` 175 bytes beyond `$5600`; no
      second cap changed. User approved `$5700`. Atomic Increment 4 complete:
      full test image builds with 6 blocks free; all 64 expression cases pass
      live under VICE and return normally. Increment 5 (checked shifts) is
      implemented with seven focused cases, then stopped at its envelope
      gate: `test_casm_expr` exceeds `$1100` by 225 bytes. No cap changed;
      user approved `$1200`, but once RODATA fit ld65 exposed BSS 55 bytes
      beyond that cap. This is staged segment reporting, not new growth.
      User approved the true `$1300` fit; 71-case harness and CASM 1301 now
      link. Packaging then found `test_casm_pass1` 2 bytes beyond `$5700`.
      User approved `$5800`. Atomic Increment 5 complete: full test image
      builds with 3 blocks free; all 71 expression cases pass live under
      VICE and return normally. Increment 6 (software multiplication and
      division) detailed plan approved. Atomic Step 1 complete: new
      self-bootable `casm_phase12_test.d64` carries Command64, CASM,
      expression/lexer harnesses and has 470 free blocks. Existing harness
      packaging is unchanged until Step 2.
      Increments 6-9 complete, each behind its own detailed, user-approved
      subordinate plan (Increment 6 multiply/division, Increment 7
      relocation/unresolved/parser integration, Increment 8 harness/
      envelope verification, Increment 9 live end-to-end). Every
      WP64-frozen operator now proven both algebraically (97-case
      `test_casm_expr`) and live through the real `casm.prg` production
      pipeline, including the first live proof of `CASM_DIAG_EXPR_
      DIV_ZERO`. Two real defects found and fixed, both disclosed and
      user-approved before the fix: `parser.s`'s operand-entry token
      whitelists never accepted `CASM_TOKEN_MINUS`/`TILDE` (and,
      pre-existing since WP66, `STAR`), so `LDA #-1`-shaped operand forms
      failed `SYNTAX ERROR`. Production `casm` cap raised `$6000` ->
      `$6100`; CASM promoted `0.2.2` -> `0.2.3`. Docs
      (`wiki`/`docs casm-utility.md`, `wiki/casm-programmers-
      reference.md`), `brain/KNOWLEDGE.md`, and `CHANGELOG.md` updated.
      **WP68 complete, user-approved 2026-08-15.** Taskwarrior task 43
      marked done. Walkthrough:
      `brain/walkthroughs/2026-08-15-casm-phase12-wp68-arithmetic-
      bitwise-operators.md`. Phase 12 itself remains open (WP69,
      character literals, still pending).
- [x] WP69 **character literals complete, user-approved 2026-08-15**
      (Taskwarrior task 44, `fe24c370-a520-450d-b281-f56eab2fd7ce`,
      depends on WP64):
      `brain/plans/2026-08-15-casm-phase12-wp69-character-literals.md`.
      Two user-confirmed scoping decisions, deliberately narrower than
      every other Phase 12 primitive: no backslash escapes (one literal
      byte between quotes, verbatim); restricted to immediate/`.BYTE`
      contexts only, never a general expression primary. Because of that
      restriction, `expr.s` needed zero changes -- `CASM_TOKEN_CHAR`
      never reaches `exprEvaluate`; `posImmediate`/`emitByteList` each
      gained a direct short-circuit instead. Two new diagnostics
      (`$47`/`$48`), the last of WP64's reserved Phase 12 range. Found
      and fixed a real 6502 branch-range overflow (`lnAngle`'s `beq`
      sites, fixed with a trampoline matching `lnHexJmp`/`lnBinJmp`) and
      a stale doc claim (`BYTE`-suffix printing, corrected by live
      evidence). Production `casm` cap `$6100`->`$6200`; three
      test-harness caps bumped the same round-page step, all
      user-approved. Live-verified against the real `casm.prg`: success
      fixture COMP byte-exact, three forbidden-form fixtures each raised
      the exact diagnostic and location, `test_casm_lexer` (4 new cases)
      and `test_casm_expr` (unaffected) both re-ran clean. CASM promoted
      `0.2.3` -> `0.2.4`, live-verified as `V0.2.4.1311`. Taskwarrior
      task 44 marked done. Walkthrough: `brain/walkthroughs/2026-08-15-
      casm-phase12-wp69-character-literals.md`. Watch item for WP70:
      `casm_listing_test_d64` is down to 7 free blocks from this WP's
      shared-module growth, the same capacity crunch WP67 already
      resolved once for this disk.
- [x] WP70 **relocation algebra closure complete, user-approved
      2026-08-15** (Taskwarrior task 45,
      `99886bbd-782b-412e-9bd4-efff9c6bfd47`, depends on WP68/69):
      `brain/plans/2026-08-15-casm-phase12-wp70-relocation-algebra-
      closure.md`. Consolidated verification, no new production
      behavior. Traced the two governing relocation rules directly in
      `expr.s`: `+`/`-` reject only when both operands are relocatable;
      every WP68 operator and both unary operators reject if either
      operand is relocatable at all. Found a genuine, previously-unproven
      gap by reading every Phase 12 fixture's own source: no fixture
      anywhere combines a relocatable label with a static addend and
      verifies the resulting R6 relocation table. Closed with
      `casmrelacc.seq` (R6-verified through the new recursive
      architecture for the first time) and `casmarelocb.seq` (a second
      distinct operator, `&`, live-rejecting a real relocatable label).
      A hand-derivation mistake in the first reference draft was caught
      by the fixture's own COMP mismatch and corrected from spec. CASM
      promoted `0.2.4` -> `0.2.5`, live-verified as `V0.2.5.1312`.
      Walkthrough: `brain/walkthroughs/2026-08-15-casm-phase12-wp70-
      relocation-algebra-closure.md`.
- [x] WP71 **DASH Phase 12 adoption complete, user-approved 2026-08-18**
      (Taskwarrior task 43,
      `e126dbb8-fc8e-4b94-a93a-ec6121a19fb8`): named private-ZP constants,
      native CASM/ca65 byte identity, genuine native `dash.ref.hex` provenance,
      stable production/no-change builds, and live `$3800`/`$5000`/`$9000`
      relocation checks all pass. Walkthrough: `brain/walkthroughs/2026-08-18-
      casm-phase12-wp71-dash-adoption.md`. CASM promoted `0.2.6` -> `0.2.7`;
      WP74 unblocked.
- [x] WP72 **named-constant zero-page width selection fix complete,
      user-approved 2026-08-17** (Taskwarrior task 44,
      `d439019e-5487-4f76-bf08-3fc792d43813`): `brain/plans/2026-08-17-
      casm-phase12-wp72-constant-zeropage-width.md`. Inserted ad hoc,
      discovered mid-WP71 (DASH adoption): a resolved named constant
      (equate) referenced as an instruction operand always forced
      absolute (3-byte) addressing, never zero-page (2-byte), even when
      in range -- unlike an identical literal operand. Root cause:
      `expr.s`'s `identifier` proc set its internal `SYMBOL_DERIVED` flag
      unconditionally for every resolved symbol, label or constant alike;
      `parser.s` derives `FORCE_ABS` from that flag, and `opcodes.s`
      takes the absolute branch before ever checking the value. Fixed
      with a single-site gate in the same branch already used to
      classify `RELOCATABLE` correctly; labels and `*` are unaffected.
      Found and fixed an unrelated pre-existing off-by-one in
      `casm_expr`'s own harness (`CASE_COUNT`, silently skipping the
      table's true last case) and a second, separate, confirmed-harmless
      dormant quirk left deliberately unfixed. Fail-before/pass-after
      unit proof, full regression clean, `dash_ref` ca65 cross-check
      byte-identical, new end-to-end native-CASM fixture (`casmzpconst1`,
      mirroring DASH's real source) COMP-verified byte-exact. Walkthrough:
      `brain/walkthroughs/2026-08-17-casm-phase12-wp72-constant-
      zeropage-width.md`. WP71 resumes its own blocked Atomic Step 5.
- [x] WP73 **forward-label resolver-state/pass-agreement fix complete,
      user-approved 2026-08-18** (Taskwarrior task 44,
      `34c11d87-811e-4aa2-b705-1cd59e91a23a`): an unresolved forward label
      read stale `CONSTANT|RESOLVED` symbol-kind flags left by a preceding
      equate lookup, causing Pass 1 zero-page and Pass 2 absolute widths.
      `expr.s` now checks resolution before consuming symbol-kind flags.
      Added the 100th `casm_expr` case and `casmfwdstale1` native/COMP fixture;
      live results are `CASM EXPR: PASS` and `FILES COMPARE OK`. Host builds
      for opcodes, pass1, reloc, symbols, and `dash_ref` pass. Walkthrough:
      `brain/walkthroughs/2026-08-18-casm-phase12-wp73-forward-label-
      resolver-state.md`. CASM promoted `0.2.5` -> `0.2.6`; WP71 may resume.
- [x] WP74 **ca65-compatible `.BYTE` string literals complete**
      (Taskwarrior task 44,
      `a61634af-b482-476b-a20b-5442334d1315`): double-quoted verbatim-PETSCII
      strings, empty strings, mixed byte lists, no escapes or implicit
       terminator. Includes mandatory DASH adoption/native-ca65 proof. Phase 13
       must remove/replace or separately justify its tentative `.TEXT` concept.
       Plan: `brain/plans/2026-08-18-casm-phase12-wp74-string-literals.md`.
      Implementation, disk regression, no-change rebuild, documentation, and
      live relocated-harness verification pass. Completion walkthrough:
      `brain/walkthroughs/2026-08-19-casm-phase12-wp74-string-literals.md`.
      User approved completion on 2026-08-19; CASM advanced `0.2.7` -> `0.2.8`.
- [x] WP76 **forward-reference Pass 1/2 width-agreement fix complete,
      user-approved 2026-08-20** (Taskwarrior task 44, UUID
      `25420ff2-5dd5-46d0-a790-4d10dda0b947` -- discovered mid-WP75
      Increment 5, corrective WP inserted per the WP72/WP73 precedent).
      A named constant referenced inside an arithmetic expression before
      its own defining statement disagreed on instruction width between
      Pass 1 (forced absolute while unresolved) and Pass 2 (always
      resolved, took WP72's zero-page exemption) -- confirmed live via
      direct memory read (`CasmPass1FinalPc=$0013` vs `CasmPc=$0012`).
      Fixed with a per-constant `DEFINED_AT_OFFSET` bookmark gating WP72's
      exemption on source-position order. `casmarithfwd.s` fixed; all 11
      WP75 Increment 5 fixtures re-verified together, zero regressions.
      Found and disclosed a second, unrelated defect (constant-to-constant
      chaining breaks parsing) as its own Taskwarrior task, deferred.
      Plan: `brain/plans/2026-08-20-casm-phase12-wp76-forward-reference-
      pass-agreement-fix.md`. Walkthrough: `brain/walkthroughs/2026-08-20-
      casm-phase12-wp76-forward-reference-pass-agreement-fix.md`.
- [x] WP75 **consolidated Phase 12 completion gate complete, user-approved
      2026-08-20** (Taskwarrior task 43,
      `d3440667-c9bd-49cc-9013-80d9bd96d035`). Increment 1: DASH full
      Phase 12 syntax adoption. Increments 2-5: clean regression build,
      no-change rebuild, byte-identity vs. pre-Phase-12 baseline,
      consolidated live-VICE session covering all 30 `test_casm_*`
      harnesses and all 11 Phase 12 production fixtures, zero regressions
      (found and fixed a real regression along the way under WP76).
      Increment 6: DASH regen re-verified against WP76's fixed `casm.prg`,
      byte-identical. Increment 7: documentation reconciliation across
      `docs/casm-utility.md`, `wiki/casm-programmers-reference.md`,
      `brain/KNOWLEDGE.md`, `CHANGELOG.md`. Increment 8: version promotion
      `0.2.8` -> `0.3.0`, live-verified (`CASM V0.3.0.1324`), no-change
      rebuild stable. Increment 9: tracker sync. Increment 10: final
      walkthrough plus the user's own manual runtime approval. Plan:
      `brain/plans/2026-08-19-casm-phase12-wp75-verification-walkthrough-
      completion-gate.md`. Walkthrough: `brain/walkthroughs/2026-08-20-
      casm-phase12-wp75-verification-walkthrough-completion-gate.md`.

## Optional Feature - Progress and Processing Indication

- [x] Taskwarrior `1acb36e3-2c0e-4f24-998b-279b2578bee4`: bounded,
      always-on progress for source loading, include traversal, both passes,
      and output writing. **COMPLETE, user-approved 2026-08-31 at CASM
      `0.4.0` -> `0.5.0` build `1380`.**
- Plan: `brain/plans/2026-07-29-casm-feature-progress-indication.md`.
- Task: `wiki/tasks/casm-progress-indication.md`.
- This optional feature is outside the master plan's numbered phases and did
  not replace Phase 10, Symbol Map and Listing.
- Delivered over eleven separately-approved increments: design/ABI freeze
  (Inc 2), `progress.s` core + pass/source/include/directive/output
  integration (Inc 3-7), automated verification with a dedicated
  `casm_progress_test_d64` disk (Inc 8), full implementation review that
  fixed three doc/robustness findings (Inc 9), live runtime acceptance
  (Inc 10), and the consolidated completion gate (Inc 11: a fresh
  31-harness + 10-`casmpg*`-fixture live sweep against `V0.5.0.1380`, no
  findings). Increment plans/walkthroughs:
  `brain/{plans,walkthroughs}/2026-08-24-casm-progress-incrementNN-*.md`;
  implementation review
  `brain/reviews/2026-08-24-casm-progress-implementation-review.md`.
- Deferred, recorded: the `DONE: ... nnnnn BYTES` display is a 16-bit
  accumulator and wraps for an output PRG larger than 65535 bytes (the
  written file is still correct). Not worth a wider counter for a
  whole-address-space `.FILL`.

## Optional Feature - Memory Optimization

- [x] Taskwarrior task 42, UUID `33d69dd5-c96b-4d3a-a27c-9fd93cc31de3` (CLOSED 2026-08-31, user-approved):
      recover roughly 2 KB of CASM's MAIN envelope across five independent
      findings with a strict "identical observable behavior" contract -- no
      change to diagnostic text/identifiers, accepted filenames, assembled
      output, or progress display.
- Plan: `brain/plans/2026-08-24-casm-memory-optimization.md` (approved
  2026-08-31).
- Findings: **D** filename caps (`CASM_FILENAME_MAX`/`CASM_INCLUDE_FILENAME_MAX`
  = 63 multiplied into 13 MAIN buffers, ~520 B, runs first); **B** shared
  `"CASM: "` prefix + trailing CR helper in `diagnostics.s` (587 B); **A**
  gate the exported-but-uncalled `diagDumpToken` behind a build switch (509 B);
  **C** dense diagnostic dispatch table replacing six range blocks + a 9-way
  chain (231 B); **E** `PROG_DIGIT` macro (6 inline expansions) -> divisor-table
  loop in `progress.s` (~150 B). Finding F (`CasmDiagLineBufA`/`B` sizing)
  recorded but explicitly NOT actioned -- product tradeoff, out of scope.
- Envelope stays `$7400` per Scoping Decision 4; recovered bytes are banked
  as working headroom, not returned.
- **All 10 increments executed 2026-08-31** (prerequisite task 33 merged to
  `main` earlier that day). Actual savings: D 482, E 108, A 653, B 585,
  C 240 = **2,068 bytes**. `__MAIN_LAST__` `$A97D` -> `$A169`; headroom at
  `$7400` 642 -> 2,710. Version `0.5.0` -> `0.5.1`.
- Increment 2 established the true reachable filename maximum is 23 bytes;
  user approved cap = 32 (Finding D), moving the `FILENAME TOO LONG`
  boundary 63 -> 32.
- `scripts/verify_casm_diag_table.py` (POST_BUILD on `casm`) decodes the
  linked `casm.prg` and checks every diagnostic id's exact frozen text;
  proven fault-detecting.
- Live VICE (Increment 9): 5/7 former dispatch ranges + both locationless
  sub-cases + Finding D filename cap, all correct. Exposed a pre-existing
  defect deferred to Taskwarrior 43 (`diagPrintFatal`'s
  `progressClearTransient` reads uninitialized `CasmProgFlags` for
  pre-`startPass1` diagnostics; garbles the banner on early fatal exit;
  confirmed byte-identical on `main`, from progress-indication Increment 7).
- Walkthrough `brain/walkthroughs/2026-08-24-casm-memory-optimization.md`;
  **CLOSED 2026-08-31, user-approved. Taskwarrior 42 done.**

## Known Non-Critical Bugs

- [x] Taskwarrior 43 (`5dad4e4f-8392-468f-8807-0ff37a98c33c`), **CLOSED
      2026-08-31, user-approved (CASM `0.5.2` build 1392):** `diagPrintFatal` read uninitialized `CasmProgFlags` on an
      early fatal, garbling the banner. `casm.s:start` called `progressInit`
      only at `startPass1`, so any diagnostic raised before Pass 1 (CLI /
      file / lexer-init failures -- `FILENAME TOO LONG`, `CANNOT OPEN
      INPUT`, `UNKNOWN OPTION`, ...) reaches `diagPrintFatal` ->
      `progressClearTransient` with `CasmProgFlags` holding uninitialized
      RAM; if bit 0 is set, its 34-cursor-left + space-fill erase runs over
      the current screen line. Diagnostic *text* is still correct; the
      defect is cosmetic and pre-Pass-1 only. Pre-existing on `main` from
      progress-indication Increment 7; exposed during the memory-
      optimization WP's Increment 9 and deferred per that plan's stop
      condition. Fixed by moving the single `jsr progressInit` from `startPass1` up into
      `casm.s:start`'s early-init block (before `resourcesInit`, with
      `diagClearLoc`/`listingStateInit`). Net code size zero; no change to
      any successful assembly. Plan/walkthrough
      `brain/{plans,walkthroughs}/2026-08-31-casm-progclear-early-fatal-fix.md`.

- [ ] Taskwarrior `be8ca0bf-ac7c-40f6-960e-2ca816bc7fb8`: **listing output
      shows a blank line between each row when printed to a real C64 screen.**
      Root cause: `listing.s` (Phase 10 / WP51-WP53) correctly emits exactly
      one trailing PETSCII CR per row after filling all 40 content columns
      (`CASM_LISTING_ROW_WIDTH` / `CASM_LISTING_ROW_SIZE`, see
      `src/external/casm/common.inc:1198-1201`) -- no double-CR is emitted
      inside `listing.s` itself. The blank line is a downstream
      exact-width-line + CR display artifact: any consumer that prints these
      full-40-column rows via standard KERNAL CHROUT-style output gets an
      auto-wrap advance at column 40 from the screen editor, then a second
      advance from the explicit trailing CR. `diagnostics.s`'s caret/source-echo
      window already documents and avoids this exact failure mode by capping
      at 38 columns instead of 40 (`wiki/casm-programmers-reference.md:1013-1018`).
      Not intentional spacing -- neither the WP51 nor WP53 design docs mention
      deliberate blank-line spacing between listing rows. Fix candidates: cap
      the screen-print path below 40 columns, suppress/account for KERNAL
      auto-wrap when printing listing rows, or confirm whichever routine
      displays `.LST` output to screen should not be raw-printing full-width
      rows at all. Non-critical: does not affect `.LST` file content on disk,
      only on-screen presentation. A dedicated plan must be written and
      approved before any source edits begin, per this project's convention.

## Future Feature Backlog

Ideas recorded for later consideration. None of these are planned in detail
yet, activated, or authorized for implementation. Each is outside the master
plan's numbered phases (`brain/plans/2026-07-16-casm-assembler-implementation-plan.md`).
Per this project's convention, a dedicated plan (design/ABI review, atomic
increments, verification matrix) must be written and approved before any
source edits begin, the same way the progress-indication feature above was
handled.

- [ ] Taskwarrior `54dff46d-b802-4534-9b29-fc78bb907e26`: **build duration
      display on completion.** Print elapsed wall/cycle time after CASM
      finishes, on both the successful summary and a fatal-diagnostic exit.
      Distinct from the progress-indication feature above, which explicitly
      excludes elapsed time from its transient/persistent lines (CIA timer
      ownership and PAL/NTSC conversion policy were out of scope there) --
      this idea would need to make that same CIA-timer-ownership decision
      for itself, scoped only to a single before/after duration readout
      rather than live timing.
- [ ] Taskwarrior `1acb36e3-2c0e-4f24-998b-279b2578bee4`: **progress
      display.** Already tracked above as an approved-but-deferred plan; not
      a new idea.
- [ ] Taskwarrior `0e0de8db-e161-49e5-8da0-3eb3e2146945`: **real-time `/M`
      symbol map emission.** Today `/M` (`casm.s:318-329`) calls `mapPrint`
      once, after Pass 2 and any `/L` listing are already committed, which
      walks the complete VMM-backed symbol table via `symbolsReadByIndex`
      and prints every row in one batch (`map.s`). This idea would instead
      emit each symbol's map row as it is defined during assembly (most
      naturally Pass 1, where `symbolsInsert` first creates the record),
      rather than as a single post-hoc dump. Needs its own design review:
      whether Pass 1 is the right emission point given Pass 2 is the pass
      that currently owns all committed output, how this interacts with
      `/L`'s existing Pass-2-emission-event model, and whether it changes
      the deterministic-definition-order guarantee `/M`'s gate depends on
      (`/M` must still never change generated PRG bytes).
