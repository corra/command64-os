---
feature: banner-casm-source-validation
created: 2026-07-27
status: proposed
---

# BANNER CASM Source Validation Plan

## Objective

Make `src/external/banner/banner.s` valid input for the current native CASM
assembler while preserving its existing ca65/ld65 production build and runtime
behavior. Correct the independently discovered glyph-column indexing defect and
replace the inaccurate CASM-compatibility claim with a verified contract.

This plan is not implementation approval. Source, build, task, and functional
documentation changes begin only after explicit user approval.

## Current Findings

The source is assembled in production by `add_ca65_app`, but it is not valid
for CASM as written:

- `ASL` at lines 142 and 149 uses ca65's accepted bare accumulator form. CASM
  requires `ASL A`; bare `ASL` is classified as implied mode and produces
  `CASM: INVALID ADDRESSING MODE`.
- The punctuation dispatcher uses ca65 anonymous labels (`:+` and `:`), while
  current CASM accepts named `IDENTIFIER:` labels only.
- `MESSAGE_BUF` uses `.RES 128, 0`; current CASM supports `.ORG`, `.BYTE`, and
  `.WORD`, but not `.RES`.
- The source intentionally has no `.ORG`. It can use CASM's default R6
  relocatable mode, but cannot be assembled with `/S` unless a static origin is
  added. This plan keeps the source relocatable and does not add `.ORG`.
- `RB_BIT_LOOP` initializes `Y` to `$10`, then uses `BIT_TABLE,Y`. This reads
  beyond the five-byte table and exits after one iteration because `$11` is not
  less than `5`. The table already contains the masks, so `Y` must be an index
  starting at zero.

## Applicable Contracts

- Keep BANNER in the external-application user-space range and preserve its
  ca65/ld65 `add_ca65_app` production target.
- Keep the implementation in one source file; do not introduce a CASM-only
  duplicate unless dual-dialect source proves impossible.
- Preserve the existing private zero-page addresses and document their use in
  the source. Do not expand into OS-owned zero page.
- Build only through CMake. Do not invoke ca65, ld65, or other assembler/linker
  tools directly.
- Test native assembly and execution only after booting Command64 and launching
  CASM/BANNER from its shell as required by
  `.agents/workflows/vice-mcp-testing.md`.

## Scope

### In Scope

- Freeze and inspect the existing ca65 BANNER artifact as the behavioral and
  layout oracle.
- Convert the two accumulator shifts to explicit `ASL A` syntax.
- Replace each anonymous punctuation-dispatch label with a unique named label.
- Replace `.RES 128, 0` with a CASM-supported representation that reserves 128
  zero-initialized bytes and remains accepted by ca65.
- Correct `RB_BIT_LOOP` so `Y` indexes all five `BIT_TABLE` entries from 0 to 4.
- Audit every remaining statement against the current CASM grammar, including
  low/high-byte extraction, indexed addressing, indirect addressing,
  directives, labels, expressions, and branch ranges.
- Verify the existing ca65 production target and native CASM output.
- Update the owning task/status records, changelog, knowledge/memory records,
  walkthrough, and applicable DOX documentation when implementation changes
  their durable contracts.

### Out of Scope

- General ca65 compatibility in CASM.
- Adding `.RES`, anonymous-label, or bare-accumulator aliases to CASM.
- Replacing BANNER's production ca65/ld65 target with CASM.
- Changing the font, supported character set, command-line interface, line-wrap
  policy, load policy, or external-application ABI.
- Refactoring unrelated BANNER parsing or rendering code.

## Expected Files

- `src/external/banner/banner.s`
- `wiki/tasks/` owning BANNER task record, selected during implementation
  discovery; create a focused task only if none exists
- `CHANGELOG.md` or the repository's applicable dated changelog
- `brain/KNOWLEDGE.md`
- `brain/MEMORY.md`
- `brain/walkthroughs/2026-07-27-banner-casm-source-validation.md`
- Applicable `AGENTS.md` files only if the DOX closeout finds a durable contract
  change; otherwise record that they were intentionally unchanged

Build files are not expected to change. Any required CMake change is a material
deviation and stops implementation for plan amendment and renewed approval.

## ABI, Storage, and Layout Effects

- Entry point and labels remain in one global source scope.
- Zero-page usage remains unchanged: existing scratch locations `$64-$65`,
  `$72-$79`, and `$FB-$FC` are neither moved nor expanded by this work.
- `MESSAGE_BUF` remains exactly 128 contiguous zero-initialized bytes.
- Replacing `.RES` must not shift the effective BANNER layout relative to the
  ca65 oracle. If the current linked artifact does not serialize equivalent
  zero-filled bytes, stop and amend the plan rather than silently changing the
  image contract.
- Explicit `ASL A` and named-label substitutions must emit the same instruction
  bytes as the existing ca65 source.
- The bit-loop correction intentionally changes runtime execution: five glyph
  columns are rendered from table masks `$10,$08,$04,$02,$01` instead of one
  out-of-bounds lookup.

## Register, Flag, and Scratch Contracts

- The index calculation retains `A` as the shifted glyph index and uses carry
  exactly as the existing `ASL`/`ROL` pairs require; changing to `ASL A` is
  syntax-only.
- `RB_BIT_LOOP` uses `Y=0..4` exclusively as `BIT_TABLE` index.
- `PHA`/`PLA` continues to preserve the glyph row byte around character output.
- `JSR $FFD2` clobber assumptions remain unchanged; no value may be newly kept
  only in `A`, `X`, `Y`, or flags across that call.
- Named punctuation labels introduce no storage or stack effects.

## Atomic Implementation Increments

1. **Freeze the oracle.** Build the existing `banner` target through CMake;
   record source revision, build number, PRG size, load address, relevant bytes,
   and hash. Inspect the 128-byte `MESSAGE_BUF` representation.
2. **Perform syntax-only conversion.** Change both shifts to `ASL A`, replace
   anonymous labels with descriptive named labels, and replace `.RES` only
   after the oracle establishes equivalent storage semantics.
3. **Repair glyph iteration.** Initialize `Y` to zero and retain the existing
   increment/compare loop so exactly five table entries are visited.
4. **Run static audit.** Check all source forms against the documented current
   CASM grammar and calculate every relative branch span after final layout.
5. **Verify ca65 production build.** Rebuild `banner` and the appropriate disk
   image through CMake; inspect output metadata and compare all expected
   syntax-only regions with the oracle. Confirm a no-change rebuild does not
   increment `BUILD_BANNER`.
6. **Verify native CASM assembly.** Place/use `banner.s` on the designated CASM
   utility image, boot Command64, invoke CASM from the shell in default
   relocatable mode, and require successful output creation with no diagnostic.
7. **Verify runtime behavior.** Launch the CASM-produced BANNER from the
   Command64 shell, render representative glyphs, confirm five columns per
   glyph and six rows, verify six-character wrapping, and require return to a
   `c64[<device>]:>` prompt.
8. **Close documentation.** Record evidence in a walkthrough, update required
   task/state/changelog files, perform the DOX pass, and ask the user whether
   the task is done. Do not mark it done before approval.

## Verification Matrix

### Source Acceptance

- CASM accepts both `ASL A` statements as accumulator mode.
- No anonymous-label or unsupported-directive syntax remains.
- CASM completes both passes without syntax, mode, undefined-symbol, branch,
  pass-disagreement, or output errors.
- Repeated native assembly is deterministic for unchanged source and inputs.

### Host Build

- `cmake -S . -B build` succeeds if configuration is rerun.
- `cmake --build build --target banner` succeeds with zero errors and warnings.
- The applicable image target succeeds and contains BANNER and `banner.s`.
- Output load address, R6 footer, relocation count, extent, and buffer size are
  inspected rather than inferred from command success.

### Functional Cases

- Empty input and help forms still print usage and return to the shell.
- `BANNER A` proves left and right columns across all six rows.
- `BANNER MW` exercises dense and alternating row patterns.
- `BANNER 012345` fits one six-character block line.
- `BANNER 0123456` wraps the seventh character to a second block line.
- `BANNER !?.` exercises punctuation dispatch after anonymous-label removal.
- A message at the 120-byte copy cap neither overruns `MESSAGE_BUF` nor loops.

### Runtime Evidence

- Use the disk selected by the build target and confirm it contains Command64,
  CASM, BANNER source, and the generated output before starting VICE.
- Prove Command64 startup with `Command 64-DOS Version`.
- Launch CASM and generated BANNER by application name from the shell; do not
  Autostart either application.
- Capture assembly-success, rendering, and shell-return evidence.
- Permit at most one clean VICE recovery and classify failures using the
  mandatory workflow.

## Failure and Stop Conditions

- If `.BYTE`-based storage cannot preserve the existing 128-byte buffer layout,
  stop and amend the plan; do not redesign storage opportunistically.
- If named labels or the final source exceed CASM identifier, source, symbol,
  output, relocation, or branch limits, record exact measurements and stop.
- If ca65 and CASM require incompatible syntax for any remaining construct,
  stop before creating duplicate source and request an architectural decision.
- If native R6 output differs from the expected relocation behavior, classify
  and investigate it independently; do not alter BANNER to mask a CASM defect.
- If the production build or existing behavior regresses, preserve evidence and
  perform root-cause analysis before proposing another edit.
- If VICE MCP is unavailable, do not use a web emulator. Ask the user to run the
  documented local VICE walkthrough and provide the evidence.
- Any build-system, ABI, zero-page, command-line, or output-format change is a
  material deviation requiring an amended plan and renewed approval.

## Documentation and DOX Closeout

- Correct the source's CASM-compatible claim only after both assemblers accept
  it and native execution is demonstrated.
- Record the exact CASM language restrictions and conversion evidence in the
  walkthrough, not as a new general CASM language promise.
- Re-read the DOX chain for every changed path after editing. Update the nearest
  owning `AGENTS.md` only if purpose, ownership, durable workflow, constraints,
  artifacts, or verification contracts changed.
- If no DOX contract changed, leave the files untouched and state that reason
  in the walkthrough and completion report.

## Completion Gate

Implementation is ready for user review only when:

- the source is accepted by current CASM and by the existing ca65 build;
- storage/layout inspection proves the 128-byte buffer contract;
- the renderer visits all five glyph columns without out-of-bounds table reads;
- required static, build, native-assembly, and runtime evidence is recorded;
- task, changelog, knowledge, memory, walkthrough, and DOX closeout are current;
- the user receives manual reproduction steps.

The task remains open until the user reviews the walkthrough and explicitly
confirms it is done.
