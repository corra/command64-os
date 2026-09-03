# COMP CASM-Native Migration

Status: [x] COMPLETE — all six increments user-approved 2026-09-02; walkthrough signed off
Taskwarrior: 74845ecf-9e39-4253-8e78-6dfb4104d635 (task 42, project `comp`)
Plan: `brain/plans/2026-09-02-comp-casm-native-migration.md`

## Goal

Retire COMP's ca65/ld65 build and ship a native-CASM artifact from a reviewed,
source-hash-bound manifest backed by an independent byte and R6 derivation.

## Approved Preparation Decision

- [x] Use 208 bytes of emitted zero-filled `.RES` storage for both filename
      buffers and both 64-byte comparison buffers.
- [x] Keep the known cross-device stream invalidation defect out of migration
      scope and tracked in `comp-cross-device-regression.md`.
- [x] Preserve COMP's target name and its role on all CASM verification disks.
- [x] Do not use migrated COMP as the sole proof of its own bytes.
- [x] Inline app constants and retire `common.inc` to avoid CASM's known
      included-zero-page constant addressing defect.

## Implementation Gates

- [x] Obtain explicit approval of the detailed migration plan.
- [x] Create and synchronize the Taskwarrior migration task.
- [x] Freeze the ca65 artifact, address/BSS layout, relocation ledger, and
      same-device behavior baseline.
- [x] Obtain approval of the exact native emitted-storage layout.
- [x] Convert `comp.s` to uppercase native CASM syntax and retire `common.inc`.
- [x] Independently derive and peer-review all bytes and R6 entries; user
      approved the derivation on 2026-09-02 before native output was consulted.
- [x] Assemble and bootstrap-verify native COMP without circular self-proof
      (Increment 3, user-approved 2026-09-02; native bytes == derivation).
- [x] Add the reviewed manifest and manifest transcription tool
      (Increment 4: `comp.ref.hex` + `scripts/build_comp_manifest.py`).
- [x] Replace the ca65 target with a manifest-derived target (Increment 4,
      user-approved 2026-09-02; `${COMP_TARGET}` preserved).
- [x] Verify every disk image that consumes `${COMP_TARGET}` (Increment 6:
      16 COMP-carrying image targets build clean).
- [x] Complete the functional matrix and characterize the unchanged
      cross-device limitation (Increment 5, user-approved 2026-09-02; 12/12).
- [x] Complete clean-build, determinism, stale-source, inventory, and R6
      checks (Increment 6: fresh build clean, comp.prg deterministic ==
      manifest, stale-source hard-fails, inventory OK, R6 PASS).
- [x] Produce the completion walkthrough and obtain explicit user sign-off
      (`brain/walkthroughs/2026-09-02-comp-casm-native-migration.md`,
      approved 2026-09-02).

## Completion Rule

Do not mark this task complete until the independent derivation is reviewed,
the walkthrough contains observed build/live evidence, and the user explicitly
approves completion.
