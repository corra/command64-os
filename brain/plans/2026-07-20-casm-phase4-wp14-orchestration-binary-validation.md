---
feature: casm-phase4-wp14-orchestration-binary-validation
created: 2026-07-20
status: planned
---

# Plan: CASM Phase 4 WP14 Orchestration and Binary Validation

## Objective

WP14 converts the WP13 temporary driver into the approved Phase 4 production
orchestration path and proves that the native assembler emits trusted numeric
static PRGs byte-for-byte. It also establishes repeatable reference artifacts
and a bounded acceptance matrix for the parser, opcode matcher, emitter, and
fatal cleanup path.

This plan governs Taskwarrior UUID `3e4eab43-0f48-4db5-843f-c749bcb79d8a`.
The task remains pending until this plan is explicitly approved.

## Prerequisites and Dependency Resolution

- WP11, WP12, and WP13 are complete and user-approved at CASM `0.1.15`.
- The diagnostic source-context feature already merged after WP13. It is named
  **DSC1** in current planning; historical `WP15` comments refer to DSC1 and
  do not refer to Phase 4 WP15.
- DSC1 documentation must be reconciled before WP14 captures its baseline.
  WP14 validates the current post-DSC1 executable because that is the code
  Phase 5 will inherit.
- Phase 4 WP15 depends on completed WP14 and must not begin concurrently.
- Phase 5 remains blocked until both WP14 and WP15 are user-approved.

The existing parent plan named only four packages and folded final verification
into WP14, while Taskwarrior has separate WP14 and WP15 tasks. The corrected
split is:

- WP14: production orchestration, trusted reference infrastructure, binary
  comparisons, negative-path matrix, and WP14 runtime confirmation.
- WP15: independent Phase 4 acceptance audit, final artifacts, walkthrough,
  record synchronization, and phase completion approval.

## Scope

Included:

- replace temporary-driver status with a documented production compiler loop;
- formalize output creation, finalization, abort, close, and exit ownership;
- create independent trusted reference PRGs for existing numeric fixtures;
- place reference files on `test.d64` for native `COMP` verification;
- add representative syntax, addressing-mode, range, PC, and cleanup cases;
- verify exact output for `casmemit1` and `casmhello`;
- prove failed assembly leaves no partial output;
- automated build, map, artifact, disk, and no-change checks; and
- user runtime confirmation and WP14 completion approval.

Excluded:

- labels, symbols, expressions, VMM, two-pass assembly, or relocation;
- `.STATIC`, `.RELOC`, `.INCLUDE`, `/M`, or `/L` implementation;
- a complete all-151-opcode certification matrix, which remains Phase 11
  hardening; and
- Phase 4 final closure, which belongs to WP15.

## Trusted Reference Strategy

Reference bytes must not be produced by CASM or by code that calls CASM. The
source of truth is a reviewed hexadecimal manifest containing the complete PRG,
including its two-byte load address. A reusable repository script converts the
manifest to binary during the build.

Planned artifacts:

```text
tests/fixtures/casm/casmemit1.ref.hex
tests/fixtures/casm/casmhello.ref.hex
scripts/hex_manifest_to_bin.py
```

The script is build-integrated, accepts one explicit input and output, rejects
non-hex content and odd digit counts, and verifies optional declared byte count
and SHA-256 metadata. It does not assemble 6502 source and therefore cannot
repeat an opcode-table defect from CASM.

Reference names are based on the fixtures that actually exist. The stale
parent-plan names `casmnum1` and `casmnum2` are retired; no duplicate fixture
family is created.

Canonical `casmemit1.ref` bytes:

```text
00 C0 A9 01 8D 20 D0 A2 10 E8 D0 FD 60 01 02 FF 34 12 CD AB
```

`casmhello.ref` contains the reviewed bytes already documented in the WP13
fixture and walkthrough. Its manifest must be reviewed against the literal
addresses and message bytes before approval of the reference increment.

Host verification checks generated reference length and hash. Runtime
verification uses Command 64's native `COMP` utility to compare CASM output
against the reference on `test.d64`.

## Production Orchestration Contract

### Entry ownership

`casm.s` remains responsible for:

- resource, CLI, file, source, and lexer initialization;
- output-name derivation and output creation;
- calling the compiler loop;
- routing success through central cleanup; and
- aborting partial output before routing a primary failure to `exitFatal`.

### Compiler loop

The loop may remain in `casm.s` if the audit proves it is cohesive and bounded,
or move to `compiler.s` if separation materially clarifies the ABI. That choice
must be made in the first implementation increment and recorded before source
movement. It must not introduce the future Pass 1/Pass 2 architecture early.

Compiler contract:

- Inputs: source open, lexer initialized, output owned, emitter initialized.
- Success: carry clear after EOF and `emitFinalize`; output is complete but
  remains centrally owned for checked close during cleanup.
- Failure: carry set, `A = CASM_DIAG_*`; no module closes or exits directly.
- Clobbers: A, X, Y and the documented parser/opcode/emitter scratch set.
- No success path may print `INPUT VALIDATED` until the final buffered write
  succeeds.

### Failure ownership

- Parser, matcher, and emitter return the primary diagnostic unchanged.
- `startFatal` invokes `outputAbort` before `exitFatal`.
- `outputAbort` must preserve the primary diagnostic and attempt to delete a
  created partial output.
- Cleanup closes every still-owned input/output handle exactly once.
- Cleanup failure may replace success but must never replace a primary compile
  error.

The audit must trace each success/failure path to `DOS_EXIT`, including create,
write, flush, explicit source close, output abort, and cleanup-close failures.

## Acceptance Matrix

### Successful reference programs

| Fixture | Coverage | Required comparison |
|---|---|---|
| `casmemit1` | implied, immediate, absolute, relative, `.BYTE`, `.WORD` | native `COMP` against `casmemit1.ref` |
| `casmhello` | immediate, absolute JSR, data payload, runnable shell return | native `COMP` against `casmhello.ref` |

### Syntax and delimiter boundaries

- missing operand after `#`;
- missing index register;
- wrong indexed-indirect register;
- trailing token after a complete operand;
- empty `.BYTE` and `.WORD` lists;
- leading, trailing, and doubled commas;
- missing `.ORG` operand and trailing `.ORG` token; and
- empty lines/comments around valid statements.

### Addressing and numeric boundaries

- representative legal case for every `CASM_MODE_*` value;
- illegal mnemonic/mode combinations;
- immediate and zero-page-indirect values at `$FF` and `$100`;
- zero-page/absolute promotion at `$00FF`/`$0100`;
- literal `$FFFF` and literal overflow;
- branch displacements `-128`, `-129`, `+127`, and `+128`; and
- PC advance ending at `$FFFF` versus advancing past `$FFFF`.

### Output and cleanup

- derived output name and explicit `/O` name;
- `/S` accepted; `/M` and `/L` rejected without leaving output;
- syntax/mode/range failure after output creation deletes the partial PRG;
- successful final flush and checked close;
- no stale output from a previous failed run is mistaken for new success; and
- a valid CASM run after every failure returns to an intact shell.

## Files Expected to Change

| File | Action | Responsibility |
|---|---|---|
| `brain/plans/2026-07-20-casm-phase4-wp14-orchestration-binary-validation.md` | Create | Detailed WP14 contract |
| `src/external/casm/casm.s` | Modify | Production orchestration and stale temporary labels |
| `src/external/casm/compiler.s` | Conditional create | Compiler loop only if the approved increment selects separation |
| `cmake/GenerateCasmTestFixtures.cmake` | Modify | Additional source fixtures |
| `tests/fixtures/casm/*.ref.hex` | Create | Reviewed reference manifests |
| `scripts/hex_manifest_to_bin.py` | Create | Reusable strict binary fixture converter |
| `CMakeLists.txt` | Modify | Generate/install references on `test.d64` |
| `wiki/tasks/casm.md` | Modify | Correct UUID and WP14 status/evidence |
| `brain/task.md` | Modify | Current CASM milestone state |
| `brain/KNOWLEDGE.md` | Modify | Trusted-reference and orchestration decisions |
| `CHANGELOG.md` | Modify at completion | WP14 functional closeout |
| `brain/walkthroughs/2026-07-20-casm-phase4-wp14-orchestration-binary-validation.md` | Create at completion | Evidence and manual confirmation |

No `ms-dos/` file is created, modified, or used as source.

## ABI, Storage, and Memory Effects

- Preferred outcome: no new persistent BSS and no new zero-page allocation.
- A `compiler.s` extraction, if selected, exports one routine and imports the
  existing parser/opcode/emitter ABI; it must not duplicate state.
- Reference generation is host build tooling and consumes no C64 runtime RAM.
- Current post-DSC1 MAIN headroom is 422 bytes, measured from a fresh link map
  in increment 1 (`$3400` build BSS ends at `$5A59`; `$2800` MAIN ends at
  `$5C00`). The DSC1 step-8 estimate of 432 bytes predated the `cf31a33`
  post-merge fix. Any linked growth must be measured from both `$3400` and
  `$3500` maps.
- If production orchestration cannot fit the `$2800` envelope with at least a
  reviewed safety margin, stop for an amended memory plan; do not silently
  raise the envelope.

## Atomic Implementation Increments

1. Reconcile DSC1 documentation and capture clean pre-WP14 build/map/artifact
   baselines. No CASM behavior change.
2. Add strict hex-manifest conversion tooling plus `casmemit1.ref`; integrate
   it into `test_image_d64`; verify exact generated bytes and no-change build.
3. Add and independently review `casmhello.ref`; integrate and verify it.
4. Audit the current driver and decide in-place production loop versus
   `compiler.s`; amend this plan if the selected structure changes ABI or
   storage.
5. Implement the production orchestration label/module decision and complete
   the full success/fatal path trace. Build and inspect both link maps.
6. Add missing syntax/address/range boundary fixtures without changing
   unrelated diagnostic behavior. Build the test image.
7. Perform automated artifact, disk-directory, reference hash, and no-change
   checks; prepare the WP14 walkthrough.
8. Ask the user to run the WP14 runtime matrix, including both native `COMP`
   comparisons and cleanup cases.
9. After explicit approval, advance CASM `0.1.15` to `0.1.16`, synchronize
   records, rebuild/reinspect, confirm the final banner, and close WP14.

Each increment is separately reviewed before the next begins.

## Automated Verification

- Configure only when CMake inputs change.
- Build `casm`, then confirm a no-change rebuild preserves `BUILD_CASM`.
- Build `test_image_d64` and `image_d64`.
- Validate reference manifest byte count/hash and generated binary equality.
- Inspect CASM load address, R6 footer, linked code/data, BSS, relocation count,
  and both link-map end addresses.
- Inspect both disk directories and confirm no existing shipping app or test
  fixture was displaced.
- Run `git diff --check` and the DOX closeout audit.

These checks do not execute CASM. The broken `c64-testing` MCP and web
emulators are prohibited.

## Manual Verification

The user performs the saved walkthrough in the supported local emulator or on
hardware:

1. Assemble `casmemit1`; run native `COMP` against `casmemit1.ref`.
2. Assemble `casmhello`; run native `COMP` against `casmhello.ref`.
3. Load/run `casmhello`; confirm its message and safe shell return.
4. Exercise every negative matrix fixture and confirm diagnostic/location.
5. Confirm failed runs leave no partial output in `DIR`.
6. Run `DIR`, another external app, and CASM again after failures.
7. Confirm the final `0.1.16` banner after the approved version increment.

## Stop Conditions

- DSC1 is not reconciled or the inspected source differs from its recorded
  implementation.
- Reference bytes cannot be justified independently of CASM.
- A binary comparison fails.
- Any success/fatal path can leak a handle, retain partial output, replace the
  primary diagnostic, or print success before a checked final write.
- Link headroom becomes unsafe or either link configuration exceeds `$2800`.
- A required acceptance case needs labels, expressions, or later-phase scope.
- Any material deviation from this plan lacks renewed approval.

## Completion Gate

WP14 completes only after all automated checks pass, both reference comparisons
pass in the user's runtime environment, cleanup behavior is confirmed, the
walkthrough is approved, CASM advances to `0.1.16`, and the real Taskwarrior
UUID plus wiki/brain/changelog records agree. WP14 completion does not complete
Phase 4; it unblocks WP15.

## Progress

- 2026-07-20: Detailed plan saved. Task remains pending and no implementation
  is authorized by creation of this document alone.
- 2026-07-20: Increment 1 complete on branch `feature/casm-phase4-wp14` (created
  off post-DSC1 `main`). No CASM behavior change.
  - DSC1 record reconciled: its plan marked `completed`, step-9 and post-merge
    fix (`cf31a33`) progress entries added, headroom corrected to 422 bytes.
  - Clean pre-WP14 baseline captured (build stable, no behavior change):
    - `BUILD_CASM` = 1068, stable across two no-change rebuilds. Main's committed
      1066 was stale bookkeeping (its hash predated the final DSC1 source edits);
      the working-tree bump to 1068 is correct for the current sources.
    - `casm.prg` load address `$3400`; total 11039 bytes; reloc.py reports 8691
      code bytes and 1170 relocation points; `R6` footer present. reloc output
      is byte-identical to `build/casm.prg` (deterministic).
    - `$3400` link map: CODE `$3400-$4E32` (`$1A33`), RODATA `$4E33-$55F2`
      (`$7C0`), BSS `$55F3-$5A59` (`$467`). `$3500` map ends BSS at `$5B59`.
      Both link within `$2800`; MAIN headroom 422 bytes.
  - Increment gate: pausing for user review before increment 2 (reference
    tooling), per the "separately reviewed" cadence.
- 2026-07-21: Increments 2 and 3 complete (trusted reference infrastructure).
  No CASM behavior change.
  - `scripts/hex_manifest_to_bin.py`: strict manifest->binary converter with no
    6502 knowledge. Verified it rejects single/odd hex digits, non-hex tokens,
    over-long tokens, wrong `# bytes:`/`# sha256:` metadata, empty output,
    unknown/typo directives, and duplicate directives (8/8 guard tests), while
    accepting the valid manifests.
  - `tests/fixtures/casm/casmemit1.ref.hex` (20 bytes) and `casmhello.ref.hex`
    (40 bytes): reviewed manifests hand-assembled from the fixture sources, NOT
    from CASM. `casmemit1` bytes match the plan's canonical string and the WP13
    walkthrough; `casmhello` message bytes are the fixture's own `.BYTE` inputs
    decoding to "YES IT BUILDS! -- CASM"+CR+NUL. SHA-256:
    casmemit1 = 3fa0fd91...0fa450f8; casmhello = b33414b7...37aa9bec.
  - `CMakeLists.txt`: `casm_reference_fixtures` target converts each manifest to
    `build/casm_refs/<name>.ref`; `test_image_d64` depends on it and appends both
    as PRGs (lowercase `-f`, `-T PRG`) to `test.d64`.
  - Verified: both refs generate with matching SHA-256; both land on `test.d64`
    as PRG (`c1541 -dir`) alongside the intact `casmemit1`/`casmhello` SEQ
    sources; all shipping apps and every existing fixture intact; 337 blocks
    free. No-change rebuild leaves `BUILD_CASM` at 1068 and does not relink casm.
  - Increment gate: pausing for user review before increment 4 (driver audit /
    module-structure decision), which is the first increment that touches CASM
    source behavior.
- 2026-07-21: Early positive binary-equality evidence. User ran the native
  runtime and reports `COMP casmemit1.prg casmemit1.ref` and
  `COMP casmhello.prg casmhello.ref` both byte-identical. This validates two
  things at once: the independently hand-assembled reference bytes are correct,
  and the CASM emitter reproduces them exactly. Because the references were
  derived without CASM, the agreement is not circular.
  - Caveat: this result is on the CURRENT code (post-DSC1 WP13 temporary
    driver), captured BEFORE the increment-5 orchestration change. The two COMP
    comparisons must be re-run after increment 5, since that increment can alter
    the output path or the derived output name.
  - Still outstanding for the full runtime matrix (increment 8): the negative
    syntax/addressing/range/PC fixtures (increment 6) and the cleanup / partial-
    output-deletion cases, none of which this evidence exercises.
  - Output-name derivation confirmed by user: CASM auto-derives the output name
    from the input basename (`casmemit1` -> `casmemit1.prg`); no `/O` was passed
    for the COMP runs above. Increment 5's production orchestration must
    preserve this auto-derivation (and the increment-8 re-run must confirm the
    same `<input>.prg` name still results).
- 2026-07-21: Increment 4 complete (driver audit + module decision). Read-only
  analysis; no source changed.

  DECISION: keep the compiler loop IN-PLACE in `casm.s`. No `compiler.s`
  extraction. Rationale: the loop is ~35 lines, cohesive and bounded; it is
  tightly coupled to the entry init sequence and the shared `startInitFatal` /
  `startFatal` trampolines; the real module boundaries (parser/opcode/emit/
  fileio/resources) are already clean `.export` ABIs, so the loop is only
  dispatch glue. Extraction would export `startParseLoop`, duplicate the fatal
  linkage, and add a translation unit for no ABI clarity gain, while tempting
  the premature Pass 1/Pass 2 split this plan forbids. No new BSS/ZP is needed,
  matching the preferred ABI outcome. This decision changes no ABI or storage,
  so no plan amendment is required.

  AUDIT FINDING: the current post-DSC1 driver already implements the full
  production orchestration contract correctly. Traced paths:
  - Entry ownership: `start` does resource/CLI/fileio/source/lexer init,
    output-name derivation (`cliDeriveOutputName`), output creation
    (`fileCreateOutput`), then the loop. All init failures funnel through
    `startInitFatal` -> `startFatal`.
  - Success: loop dispatches MNEMONIC (`opcodesFindOpcode`+`emitInstruction`),
    DIRECTIVE (`emitDirective`), NEWLINE (no-op), EOF -> `emitFinalize`
    (= `emitFlush`, the final buffered write) -> print INPUT VALIDATED ->
    explicit `sourceClose` -> `exitSuccess`. The output is intentionally NOT
    closed here; it stays registry-owned and is closed by `resourcesCleanup`.
    This matches the contract line "output remains centrally owned for checked
    close during cleanup" verbatim. INPUT VALIDATED prints only after the final
    buffered write succeeds; a later output-close failure surfaces via
    `exitSuccess` as CLEANUP_FAILED (allowed: "cleanup failure may replace
    success").
  - Failure: parser/matcher/emitter return the primary diagnostic unchanged in
    A; `startFatal` calls `outputAbort` (preserves primary in `CasmFilePrimary`,
    closes the output with a checked close, deletes the partial PRG gated on
    `CasmOutputCreated`) then `exitFatal`, which prints the PRIMARY diagnostic
    BEFORE `resourcesCleanup`, so a cleanup failure can never mask a compile
    error.
  - Single-close: handles live in `CasmFileRegistry`; `sourceClose` /
    `outputAbort` deregister on success, and `resourcesCleanup` is guarded and
    only closes still-owned records, so every handle closes exactly once.
  - Pre-creation safety: `fileIoInit` sets `CasmOutputState = CLOSED` and
    `CasmOutputCreated = 0`, so an init-time fatal reaching `outputAbort` skips
    both the close and the delete (safe no-op) -- no spurious
    OUTPUT_CLOSE_FAILED before output exists.

  IMPLICATION FOR INCREMENT 5: no structural rewrite is warranted. Increment 5
  reduces to (a) replacing the stale "WP13 temporary driver / WP14 replaces
  this" framing in `casm.s` with production-orchestration documentation that
  records the in-place decision and the traced contract, and (b) rebuilding and
  re-inspecting both link maps. Because this is comment-only, the emitted bytes
  are expected to be identical (so the increment-8 COMP re-run should still
  pass), while `BUILD_CASM` will bump once for the source-text change.
- 2026-07-21: Increment 5 complete (production orchestration documented).
  Comment-only change to `casm.s`; no instruction, data, or ABI change.
  - Replaced the stale file header ("Phase 2 ... Tokenization and assembly begin
    later") with the production orchestration description; corrected the `start`
    header; replaced the "WP13 temporary driver / WP14 replaces this" block with
    a production compiler-loop contract comment recording the dispatch rules,
    the diagnostic funnel, the registry-owned checked close, the INPUT VALIDATED
    ordering, and the in-place (no `compiler.s`) decision and its rationale.
  - Verified comment-only: a filtered diff shows no changed non-comment line.
  - `BUILD_CASM` 1068 -> 1069 (expected: source text feeds the content hash).
  - Link maps re-inspected and BYTE-IDENTICAL in layout to the increment-1
    baseline: CODE `$3400-$4E32` (`$1A33`), RODATA (`$7C0`), BSS (`$467`),
    `$3400` ends `$5A59`, `$3500` ends `$5B59`. Both within `$2800`; headroom
    unchanged at 422 bytes.
  - `casm.prg` differs from the increment-1 baseline in exactly ONE byte:
    offset `$1A45`, `'8'` -> `'9'` -- the last digit of the build number in
    CASM's own version banner. Size unchanged (11039), relocation count
    unchanged (1170). Because this byte lives in CASM's banner and not in the
    PRGs CASM emits, the increment-8 COMP comparisons for `casmemit1` and
    `casmhello` are unaffected by this increment.
- 2026-07-21: Increment 6 complete (acceptance-matrix fixtures). 21 new fixtures
  added to `GenerateCasmTestFixtures.cmake` and registered in `CMakeLists.txt`.
  No CASM source change; `BUILD_CASM` stays 1069.

  Expectations were derived statically from `parser.s`/`emit.s`, not by running
  CASM; the increment-8 runtime matrix confirms them. A relevant structural
  fact: the parser DEFERS `.BYTE`/`.WORD` operand lists to the emission engine,
  so their delimiter diagnostics are raised in `emit.s`, not `parser.s`.

  Syntax/delimiter: `casmbyte0` (empty `.BYTE`), `casmword0` (empty `.WORD`),
  `casmcma1` (leading comma), `casmcma2` (doubled comma), `casmcma3` (trailing
  comma), `casmbyrng` (`.BYTE $100`), `casmorg4` (trailing `.ORG` token),
  `casmcmnt` (comments/blank lines around valid statements, positive).
  `casmcma2`/`casmcma3` emit a byte BEFORE failing, so they are also
  partial-output cases.

  Addressing/numeric: `casmimm1` (`#$FF` ok) / `casmimm2` (`#$100` range),
  `casmzp1` (ZP vs absolute promotion at `$FF`/`$0100`), `casmzpi1` (ZP-indirect
  at `$FF`) / `casmzpi2` (`$100`, exact diagnostic to be confirmed at runtime),
  branch boundaries `casmbrp1` (+127 ok), `casmbrp2` (+128 fail), `casmbrn1`
  (-128 ok), `casmbrn2` (-129 fail) -- all computed from nextPc = `$C002`;
  `casmpcend` (PC ends exactly at `$FFFF`, ok) / `casmpcovf` (past `$FFFF`,
  ADDRESS OVERFLOW).

  Cleanup: `casmpart` assembles several statements into the output PRG and only
  then fails, so it exercises the `startFatal` -> `outputAbort` partial-PRG
  delete. Verified by `DIR` showing no leftover output.

  DEFECT FOUND (`casmorg3`, `.ORG` with no operand): CASM silently accepts it.
  `parseOperandSequence` classifies the bare directive via `posImplied` as
  OPKIND_IMPLIED with value 0, `posDone` returns success, and `emitOrg` never
  inspects OpKind -- so the origin is set to `$0000` and a `00 00` PRG header is
  emitted with no diagnostic. The WP14 acceptance matrix explicitly requires a
  missing `.ORG` operand to be rejected, so this is a genuine gap, not a fixture
  error. Fixing it is an assembler behavior change (a new OpKind guard in
  `emitOrg`, roughly 10 bytes against 422 bytes of headroom) and is being raised
  for an explicit decision rather than changed unilaterally.

  Disk verified: all 21 fixtures present on `test.d64` (79 entries, up from 58),
  both `.ref` PRGs intact, 316 blocks free, no shipping app or existing fixture
  displaced.
- 2026-07-21: `.ORG` operand defect FIXED in WP14 (user-approved, using the
  existing `CASM_DIAG_SYNTAX_ERROR` `$1C` rather than a new code, so the Phase 4
  diagnostic range and its contiguity asserts are untouched).
  - `emitOrg` now requires `CASM_OPKIND_ABSOLUTE` before setting the origin.
    That kind covers both zero-page and absolute numeric operands, so it is
    exactly the set `.ORG` should accept. The guard rejects the bare `.ORG`
    (OPKIND_IMPLIED) and every other operand form the shared statement grammar
    can produce -- `.ORG A`, `.ORG #$10`, `.ORG $10,X`, `.ORG ($10)` -- each of
    which previously became a silent `$0000` or bogus origin, because the value
    fields alone cannot distinguish them from a real address.
  - Ordering: the OpKind guard runs BEFORE the duplicate-`.ORG` check, so a
    malformed `.ORG` is always diagnosed as malformed regardless of position.
    `casmorg2` (two well-formed `.ORG`s) still reports DUPLICATE ORG, so there
    is no regression.
  - New fixture `casmorg5` (`.ORG A`) covers the non-numeric operand case that
    the broadened guard enables; `casmorg3`'s comment no longer documents the
    defect as expected behavior.
  - Cost: CODE `$1A33` -> `$1A41` (+14 bytes). Headroom 422 -> 408 bytes; both
    `$3400` and `$3500` still link within `$2800`. RODATA and BSS unchanged.
    `BUILD_CASM` 1069 -> 1070. Disk now 80 entries, 315 blocks free.
  - Runtime confirmation of `casmorg3`/`casmorg5` is part of increment 8; the
    fix is a static change verified by build and link inspection only.
- 2026-07-21: Increment 7 complete (automated verification + walkthrough).
  - All host checks pass: `casm`/`image_d64`/`test_image_d64` build; a no-change
    rebuild preserves `BUILD_CASM` at 1070; both reference manifests regenerate
    byte-identically to their build artifacts; `reloc.py` output is
    byte-identical to `build/casm.prg`; `git diff --check` clean.
  - Artifacts: load address `$3400`, `R6` footer present, 11057 bytes, 1172
    relocation points.
  - Link maps: `$3400` CODE `$3400-$4E40` (`$1A41`), RODATA `$7C0`, BSS `$467`,
    end `$5A67`; `$3500` end `$5B67`. Both within `$2800`; headroom 408 bytes.
  - Disks: `image.d64` retains all 9 shipping apps (464 blocks free);
    `test.d64` holds 23 PRG + 57 SEQ including both `.ref` PRGs (315 blocks
    free). Nothing displaced.
  - Walkthrough saved at
    `brain/walkthroughs/2026-07-20-casm-phase4-wp14-orchestration-binary-validation.md`
    with a 6-group runtime matrix (A binary equality, B positives, C syntax,
    D range/PC, E cleanup/partial-output, F CLI options). Every expected result
    is flagged as statically derived and awaiting runtime confirmation.
  - Increment gate: increment 8 is the user's runtime execution of that matrix.
- 2026-07-21: Third trusted reference added, `casmmodes`, closing the
  per-addressing-mode byte-coverage gap identified in the test plan.
  - `casmmodes.seq` carries one legal statement for each of the 13
    `CASM_MODE_*` values, in mode order. ZEROPAGE_Y uses `LDX $10,Y` because
    that mode exists only for LDX/STX; zero-page vs absolute is driven by
    operand width (`$10` vs `$1234`), re-exercising the promotion logic.
  - `casmmodes.ref.hex` (30 bytes, sha256 c9315d13...d29c94f0) was hand-assembled
    from the documented 6502 instruction set. It was deliberately NOT derived
    from `opcodes.s`: taking the bytes from CASM's own table would make the
    comparison circular and could copy a table defect into its own reference.
  - Independent cross-check performed AFTER the manifest was fixed: the opcode
    bytes in `opcodes.s` were diffed against the hand-derived ones and agree on
    all 13 (ASL accum `$0A`; BNE `$D0`; INX `$E8`; JMP indirect `$6C`; the eight
    LDA forms `A9 A5 B5 AD BD B9 A1 B1`; LDX zp,Y `$B6`). Two independent
    derivations agreeing raises confidence in both. Had they disagreed, that
    would have been recorded as a finding rather than resolved by editing the
    manifest.
  - Wired through `CASM_REF_NAMES`, so it generates and installs on `test.d64`
    exactly like the other two. Disk now 24 PRG + 58 SEQ, 313 blocks free; all
    shipping apps intact; `BUILD_CASM` unchanged at 1070 (no CASM source
    touched).
  - Test plan updated: new cases G2.8 (assembles) and G2.9 (COMP against the
    reference), a per-mode offset table for localising a mismatch, traceability
    row now byte-certified, and the coverage-gap section records the gap as
    CLOSED while noting the remaining limit (one opcode per mode, not all 151).
  - The assembled output must never be run: it ends in a `JMP` through an
    uninitialised vector and a backward branch.
- 2026-07-21: SECOND DEFECT found and fixed — `CASM_MODE_ZEROPAGE_Y` was
  unreachable. Found by the first runtime execution of the new `casmmodes`
  comparison, i.e. by the very artifact added to close the mode-coverage gap.
  - Symptom: `COMP CASMMODES.PRG CASMMODES.REF` reported a mismatch at offset
    `$0A` (CASM `$BE` vs reference `$B6`) and then a cascade of shifted bytes,
    because CASM emitted the 3-byte `LDX absolute,Y` form where the 2-byte
    `LDX zero-page,Y` form belongs. Offsets `0-9` matched, so `,X` promotion was
    already correct; only `,Y` was broken.
  - Root cause: `opcodesFindOpcode` tested the ZeroPage,Y support bit against
    `ofMaskHi` with `1 << (CASM_MODE_ZEROPAGE_Y - 8)`. That mode is 5, so its bit
    lives in the LOW mask byte; ca65 silently evaluates the resulting negative
    shift to `$00` with no diagnostic, so the AND always failed and the mode was
    dead code. Verified directly: ca65 assembles `1 << (5-8)` to `$00` and
    `1 << 5` to `$20` without complaint. The opcode table itself was correct
    (`$B6` present, LDX maskLo `$6C` has bit 5 set) — only the test was wrong.
  - Severity: a miscompilation, not merely a size regression. Zero-page,Y wraps
    within page zero (`($10+Y) & $FF`) while absolute,Y does not, so the emitted
    code reads a different address whenever `Y > $EF`.
  - Fix: read `ofMaskLo` with the correct bit, mirroring the `,X` path. Zero
    code-size cost (CODE unchanged at `$1A41`, headroom still 408 bytes).
  - Static guard (user-selected option): the four compile-time mask bits are now
    defined once as `OF_BIT_LO_*` / `OF_BIT_HI_*` constants, each asserted to be
    a non-zero value below 256, and the use sites name the constant instead of
    re-deriving the shift. Both failure directions were verified by deliberately
    breaking them: re-introducing the exact original wrong-half expression trips
    the `OF_BIT_LO_ZEROPAGE_Y` assert, and renumbering the mode into the high
    half trips a ca65 range error. The build is clean after restoring.
  - Process note: this is the second defect the WP14 acceptance work has found
    (after the bare `.ORG`), and the first found at runtime rather than by
    reading. It vindicates the trusted-reference rule — the reference bytes were
    hand-derived from the 6502 instruction set rather than from `opcodes.s`, so
    they could disagree with CASM. Had the reference been generated from CASM's
    own table, the comparison would have passed and the bug would have survived.
  - `BUILD_CASM` is now 1077 (the negative-test cycles each bumped the counter).
    The test plan and walkthrough were updated to expect banner `0.1.15.1077`.
  - G2.9 must be re-run to confirm the fix; it is now the regression test for
    this defect.
- 2026-07-21: G2.9 CONFIRMED PASS by user runtime. `COMP CASMMODES.PRG
  CASMMODES.REF` reports the files identical after the `CASM_MODE_ZEROPAGE_Y`
  fix. This closes the loop on the second defect: the same comparison that
  exposed it now certifies one correct opcode byte for each of the 13
  `CASM_MODE_*` values, including the indexed, indirect, ZP,Y and accumulator
  modes that `casmemit1`/`casmhello` never reach. `casmmodes.ref` is now the
  standing regression test for that defect.
- 2026-07-21: Increment 8 COMPLETE — user reports the full runtime matrix passes
  on build `0.1.15.1077`, i.e. after both defect fixes. All ten groups (G0
  environment, G1 binary equality, G2 positives incl. the per-mode certification,
  G3 syntax/delimiter, G4 addressing/range/PC, G5 cleanup and partial-output
  deletion, G6 CLI options, G7 stale output, G8 regression, G9 DSC1
  presentation) are green. Recorded in the test plan's Result column and
  summarised in the walkthrough.
  - This confirms by execution several behaviours WP14 had only verified by
    reading: the `outputAbort` partial-PRG delete (G5.1-G5.4), the contrast case
    where a pre-emission failure leaves nothing to abort (G5.5), `/M` and `/L`
    rejection before output creation (G6.4/G6.5), and that a valid run after
    every failure still returns to an intact shell (G5.6/G5.7).
  - Both defect fixes are runtime-confirmed: G3.7/G3.8 (bare `.ORG` and `.ORG A`
    now rejected) and G2.9 (`CASM_MODE_ZEROPAGE_Y` now reachable), with G8.2
    confirming no duplicate-`.ORG` regression from the guard ordering.
  - Outstanding for the record only, not blocking: G4.2 and G7.1-G7.3 were
    "record what happens" probes rather than pass/fail assertions, so their
    observed values still need writing down — the exact diagnostic `casmzpi2`
    produces, and what actually happens when CASM assembles over an existing
    output file. The latter is the `,P,W` no-replace hazard documented in the
    test plan's isolation protocol; knowing the real behaviour would let that
    section be tightened or relaxed.
