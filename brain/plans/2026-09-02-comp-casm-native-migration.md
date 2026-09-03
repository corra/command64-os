---
feature: comp-casm-native-migration
created: 2026-09-02
status: COMPLETE - all six increments user-approved 2026-09-02; walkthrough signed off
taskwarrior: 74845ecf-9e39-4253-8e78-6dfb4104d635
depends-on: LABEL CASM-native migration, complete and user-approved 2026-09-02
---

# Plan: COMP - Full Migration to Native CASM

## Status

**APPROVED 2026-09-02; INCREMENT 1 COMPLETION CANDIDATE.** The user approved
this plan and selected emitted storage. Increment 1 froze the ca65 artifact,
BSS/relocation baseline, functional matrix, and proposed native layout in
`brain/reviews/2026-09-02-comp-casm-native-increment1-layout-baseline.md`.
The user approved the exact layout on 2026-09-02. Increment 2 converted the
source and recorded static evidence in
`brain/reviews/2026-09-02-comp-casm-native-increment2-source-conversion.md`.
The user approved the Increment 2 source gate on 2026-09-02. Increment 3's
independent derivation is recorded in `src/external/comp/comp-derivation.md`;
the user approved the derivation as the independent reviewer on 2026-09-02,
activating native assembly and comparison. Increment 3 native assembly is a
completion candidate: CASM 0.6.2 build 1419 produced a 1,228-byte R6 PRG
byte-exact to the derivation (`casm_r6_verify` PASS at three bases) after two
byte-neutral Increment-2 source fixes; evidence in
`brain/reviews/2026-09-02-comp-casm-native-increment3-oracle-and-native-assembly.md`.
The Increment 3 gate was approved 2026-09-02. Increment 4 (manifest + build
transition) is a completion candidate: `scripts/build_comp_manifest.py` +
`src/external/comp/comp.ref.hex` created, ca65 path removed, manifest-derived
`comp` target ships with `${COMP_TARGET}` preserved, full build clean,
stale-source guard verified; evidence in
`brain/reviews/2026-09-02-comp-casm-native-increment4-manifest-and-build-transition.md`.
The Increment 4 gate was approved 2026-09-02. Increment 5 (functional and
bootstrap verification) is a completion candidate: the migrated comp.prg was
driven live on `command64_comp_func_test.d64` and passed all 12 planned
matrix scenarios with clean shell returns, both handles close on every
open/exit path checked, and the cross-device defect is unchanged; evidence in
`brain/reviews/2026-09-02-comp-casm-native-increment5-functional-verification.md`.
The Increment 5 gate was approved 2026-09-02. Increment 6 (consolidation) is
a completion candidate: fresh `rm -rf build` + full build clean, 16
COMP-carrying image targets build, `comp.prg` deterministic and == manifest,
stale-source hard-fails, `casm_oracle_inventory` + `casm_r6_verify` green,
docs updated (CHANGELOG / KNOWLEDGE / EXTERNAL / audit register /
comp-command.md), found-not-fixed CASM line-wrap filed as Taskwarrior 43. The
completion walkthrough is
`brain/walkthroughs/2026-09-02-comp-casm-native-migration.md`; the completion
gate (reviewer + user sign-off) is the only open item.

This is Stage 2 of
`brain/reviews/2026-09-01-external-applications-casm-native-viability.md`.
It follows the completed LABEL pilot but adds the program's first explicit
true-BSS disposition. It is not a numbered CASM Phase or Work Package.

## Objective

Retire COMP's ca65/ld65 build and make COMP a CASM-native application assembled
only by native CASM under Command64. Ship it from a source-hash-bound reviewed
manifest backed by an independent byte and R6 relocation derivation.

Preserve COMP's same-device behavior while changing its storage layout from
unemitted ld65 BSS to 208 bytes of emitted zero-filled CASM `.RES` storage.

## Prepared Baseline

- Source: `src/external/comp/comp.s` plus `common.inc`, 509 + 39 lines.
- Current toolchain: `add_ca65_app(comp ... "0800")`.
- Current artifact: 1,020 bytes, SHA-256
  `e4de95c814b2bf7bff6c0346f9d1b8e178b4b62db651bba71856f63c5c5c8bf8`.
- Current R6 shape: base `$3800`, 890-byte image, 61 relocation entries.
- The current artifact's relocation table includes three references into
  unemitted BSS beyond the program image. Therefore
  `scripts/casm_r6_verify.py build/comp.prg` correctly rejects it as a native
  self-contained R6 oracle; this is a baseline layout property, not evidence
  of a newly introduced defect.
- BSS consists of two 40-byte filename buffers and two 64-byte read buffers:
  208 bytes total.
- `COMP` is packaged on the production/test images and many CASM-specific
  verification images. Preserving the target name and `C64_PRG_PATH` contract
  is mandatory.
- Known pre-existing defect: cross-device comparisons can falsely report a
  size mismatch because opening the second file can invalidate the first
  stream. It remains tracked in `wiki/tasks/comp-cross-device-regression.md`.

## Approved Scoping Decisions

1. **Emit all 208 storage bytes.** Append the filename and chunk buffers as
   zero-filled `.RES` data. The native artifact will grow by approximately 208
   bytes before any syntax-dependent size differences. This is preferred over
   fixed-memory or VMM storage because it keeps COMP self-contained and avoids
   new runtime coupling.
2. **Preserve behavior, not old file identity.** The old and new artifacts
   cannot be byte-identical because the old BSS is absent from the PRG. Compare
   the common code/data prefix structurally at the same base, independently
   derive the new storage and R6 layout, then verify behavior.
3. **Retire ca65 in the same migration.** No standing `comp_ref` target or
   dual-assembler source restriction remains. A one-time build of the frozen
   pre-migration source may be used only as post-derivation differential
   evidence.
4. **Do not fix the cross-device defect here.** Same-device comparison is the
   migration regression contract. Cross-device behavior remains disclosed and
   separately tracked; migration must not make it worse.
5. **Do not use migrated COMP to prove itself.** The canonical oracle is
   independently derived. Initial native output is checked host-side against
   the reviewed manifest and with the pre-migration COMP where useful. Only
   after that bootstrap passes may the new COMP participate in live
   self/regression comparisons.
6. **No new version banner.** COMP currently emits no banner despite retaining
   unused ca65 version definitions. Adding one would change behavior. Remove
   the unused definitions and bind the manifest to `comp.s` and `BUILD_COMP`;
   no generated version source is needed.
7. **Inline and retire `common.inc`.** Its zero-page-valued constants trigger
   the known CASM included-constant addressing defect. Inline them in `comp.s`,
   as LABEL does, so zero-page instructions retain their two-byte encoding.

## Scope

Included:

- Convert `comp.s` to uppercase-ASCII native CASM syntax, inline the app-private
  constants, and delete `common.inc`.
- Remove ca65 segments, import/header, preprocessor definitions, and generated
  `build_comp.inc` dependency.
- Adopt CASM `@local` labels and literals only where byte behavior is explicit
  and reviewable.
- Emit the 208-byte storage block in the native image.
- Add `comp.ref.hex`, `comp-derivation.md`, and
  `scripts/build_comp_manifest.py`.
- Replace `add_ca65_app(comp ...)` with a manifest-derived `comp` target while
  preserving `${COMP_TARGET}` and every disk-image dependency.
- Add `command64_comp_test_d64` containing Command64, CASM, the frozen
  pre-migration COMP bootstrap binary/reference as needed, COMP source, and
  purpose-built comparison fixtures.
- Add COMP to the native-manifest oracle inventory and audit register.
- Update task, application, build, provenance, and user documentation.

Excluded:

- Cross-device stream-contract remediation.
- ERRORLEVEL or external-app return status.
- New COMP options, parser behavior, messages, or compare semantics.
- Shared storage/version/manifest framework generalization.
- CASM language changes or fixes.
- Migration of FORMAT or another application.

## Implementation Increments

### Increment 1 - Freeze Baseline and Layout

- Build and hash the current ca65 artifact from the implementation-start
  commit.
- Record its code/data extent, BSS addresses, symbols, and all 61 current
  relocation entries.
- Define the exact native image order: code, messages, `File1Buf`, `File2Buf`,
  `Buf1`, `Buf2`, then R6 relocation table/footer.
- Predict the native loaded end and prove it stays within the external-app
  memory envelope.
- Freeze same-device behavior fixtures before source conversion.

Gate: user approves the exact address/storage ledger before conversion.

### Increment 2 - Native Source Conversion

- Convert `comp.s` to uppercase ASCII and documented CASM syntax; inline the
  constants from `common.inc` and retire the include.
- Remove `.SEGMENT`, `.IMPORT`, manual header, `.DEFINE`, and
  `build_comp.inc` use.
- Preserve every instruction, branch, message byte, API selector, KERNAL
  address, zero-page assignment, and control-flow path except address changes
  caused by the new base/layout.
- Emit all four buffers with `.RES` and explicit zero fill where required by
  CASM semantics.
- Run `scripts/check_casm_source_bytes.py` before packaging.

Gate: static source review and source-size/symbol-capacity checks pass.

### Increment 3 - Independent Oracle and Native Assembly

- Derive all bytes from NMOS 6502 encodings, documented CASM semantics, PRG
  framing, and R6 rules without consulting CASM output or ca65 bytes as the
  answer.
- Record every instruction/data range, 208-byte zero-fill range, branch
  displacement, relocation eligibility/exclusion, sorted offset, count, and
  footer in `src/external/comp/comp-derivation.md`.
- Obtain independent reviewer sign-off before assigning
  `CANONICAL-INDEPENDENT`.
- Assemble through native CASM on `command64_comp_test.d64` and classify any
  mismatch before editing source or oracle.
- Run `casm_r6_verify.py` at `$3800`, `$5000`, and `$9000` equivalents after
  native-base relocation.

Gate: reviewed oracle and native artifact agree exactly.

### Increment 4 - Manifest and Build Transition

- Create `scripts/build_comp_manifest.py` as an app-specific manifest
  transcription tool, never a build step.
- Bind `comp.ref.hex` to `comp.s` and `BUILD_COMP` hashes.
- Remove COMP's ca65 source glob, entry variable, `add_ca65_app` block, and
  ca65-not-found fatal branch.
- Add the manifest-derived `comp` target with unchanged target/property names.
- Confirm every production, test, CASM phase, overflow, listing, oracle, and
  utility disk that currently references `${COMP_TARGET}` still resolves to
  the new artifact without per-disk rewiring.

Gate: configuration and all affected image dependency graphs succeed.

### Increment 5 - Functional and Bootstrap Verification

- Compare native output against `comp.ref` without relying on migrated COMP as
  the sole authority.
- After bootstrap validation, run the migrated COMP against identical files,
  one mismatch, more than ten mismatches, both size-asymmetry directions,
  missing first/second files, missing/extra arguments, slash option, and raw
  PRG bytes including load addresses.
- Verify both handles close on all error/exit paths.
- Run at least one established CASM fixture comparison to prove COMP still
  serves its repository-wide verification role.
- Characterize the known cross-device case and confirm it is unchanged, not
  fixed or worsened.

Gate: complete observed result matrix with clean shell returns.

### Increment 6 - Consolidation and Completion Gate

- Fresh configure and full build with zero warnings/errors.
- Build every image target affected by `${COMP_TARGET}`.
- Verify production `comp.prg` equals manifest bytes and is deterministic.
- Verify no-change rebuild identity and stale-source hard failure.
- Run oracle inventory reconciliation and R6 verification.
- Update `CHANGELOG.md`, `brain/KNOWLEDGE.md`, `brain/task.md`,
  `brain/EXTERNAL.md`, task docs, applicable release/docs files, and DOX.
- Produce `brain/walkthroughs/2026-09-02-comp-casm-native-migration.md`.
- Ask the user for reviewer and completion-gate sign-off; do not mark the task
  complete before approval.

## Verification Requirements

- Native CASM reports `CASM: INPUT VALIDATED` for the exact reviewed source.
- Manifest body, byte count, artifact hash, and all source hashes reconcile.
- All native R6 entries are sorted, unique, point inside the emitted image,
  and relocate correctly at three bases.
- Common pre-/post-migration code and message bytes reconcile after accounting
  for base/layout relocation; all differences are explained.
- Full CMake build and all COMP-carrying disk targets succeed.
- Functional matrix passes on same-device inputs.
- Existing cross-device limitation remains explicitly open.
- Independent reviewer signs the derivation before completion.
- User explicitly approves the completion walkthrough before trackers close.

## Risks and Controls

| Risk | Control |
| --- | --- |
| Migrated COMP circularly validates itself | Independent oracle, host byte check, and frozen old COMP bootstrap before new COMP is trusted |
| Emitted buffers alter absolute addresses and relocation offsets | Full address and relocation ledger; same-base normalized comparison |
| Included zero-page constants select absolute addressing | Test include behavior first; inline constants if the known CASM defect remains |
| PETSCII literals change message bytes | Derive every message byte; retain explicit numeric bytes where semantics are not plain text |
| Widely reused target breaks CASM test images | Preserve target name/property and enumerate every `${COMP_TARGET}` consumer |
| Migration accidentally absorbs cross-device fix | Explicit exclusion and before/after characterization |

## Approval Gate

Implementation requires explicit user approval of this plan. Approval creates
the Taskwarrior migration task and activates Increment 1 only; later increments
remain gated by their recorded evidence and the final completion sign-off.
