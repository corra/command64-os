---
feature: casm-dash-wp2-system-information-api
created: 2026-07-26
updated: 2026-07-27
status: complete
---

# Plan: DASH WP2 - System Information API

## Objective

Implement the WP1-approved system snapshot service as a bounded, read-only OS
API. It must remain useful without an REU, never modify the MCT or app table,
and write exactly one validated public record.

Parent: `brain/plans/2026-07-26-casm-dash-system-dashboard.md`.
Dependency: `brain/plans/2026-07-26-casm-dash-wp1-api-contract-freeze.md`.

## Prerequisites

- WP1 contract explicitly approved.
- Service number, record, statuses, pointer rules, clobbers, and capacity
  semantics frozen.
- Baseline `command64`, API, VMM, and test-image builds pass.
- Current segment headroom measured from the activation build.
- Version source and program-limit semantics resolved.

## Mandatory Activation Review

Before implementation, re-trace the dispatcher, version source, VMM init,
MCT, app-table initialization, memory symbols, and API tests. Compare current
behavior against WP1 and this plan.

Any material discrepancy affecting scope, files, ABI, storage, failure
behavior, counts, or verification stops work. Record expected/observed
behavior and root cause, amend the plan, and obtain renewed approval. Do not
repair predecessor contracts silently inside WP2.

## Inherited Contract

Exact numbers and offsets come from approved WP1. WP2 must not substitute the
parent draft's provisional 22-byte record if WP1 changes it.

Required semantics:

- One call returns one coherent snapshot.
- No-REU is a successful snapshot with invalid optional fields, not a blanket
  API failure.
- All output is little-endian where wider than one byte.
- No partial record is visible on failure.
- VMM count fields use WP1's logical/physical distinction.
- `$C000` ownership is represented consistently with loader protection.

## Expected Files

Production:

- `include/command64.inc`
- `include/ca65/command64.inc`
- `src/command64/api.asm`
- `src/command64/vmm.asm`, only for an approved reusable read-only counter
- `src/command64/apptable.asm`, only for an approved read-only count helper
- Version-generation source only if WP1 requires it
- `CMakeLists.txt`, only for version/test wiring

Tests:

- Prefer extending `tests/src/api/api.s`; `test.d64` is already at its
  directory-entry ceiling.
- Reuse `tests/src/vmm/vmm.s` for regression, not duplicate coverage.

Documentation and records:

- `wiki/api-reference.md` and byte-identical `docs/api-reference.md`
- `wiki/programmers-reference.md` and mirror
- `wiki/vmm-api.md` and mirror when count semantics change
- `brain/MEMORY.md` only if ownership or addresses change
- `brain/KNOWLEDGE.md`, `CHANGELOG.md`, and applicable DOX

## Design and Call Path

```text
caller -> JSR $1000 -> apiHandler -> ahGetSystemInfo
  -> validate/stash destination
  -> gather non-VMM scalar fields
  -> inspect VMM/app-table availability
  -> count approved MCT states without writing
  -> validate complete snapshot
  -> emit exactly STRUCT_SIZE bytes
  -> return approved A/C status
```

Prefer no persistent state. Temporary counters must use OS-owned documented
storage or resident BSS approved by WP1; never use caller-owned `$70-$8F`.

Potential helpers:

- `sysInfoValidateBuffer`
- `vmmCountPageStates`
- `aptCountUsedReadOnly`
- bounded record writer

Helper names and placement are implementation details unless exposed.

## Data Collection Rules

- Version comes from WP1's authoritative source.
- Current device and video standard are read once per snapshot.
- User start uses `UserProgStart`; limit semantics follow WP1.
- VMM unavailable clears validity bits and stores approved sentinels.
- Unknown MCT bytes follow WP1's corruption policy.
- App count comes from the approved authority, not an unchecked stale header.
- Do not disable interrupts for a 4096-byte scan unless an actual concurrent
  writer is discovered and reviewed.

## ABI, Storage, and Segment Effects

- Add identical public constants to both include dialects.
- Add one dispatcher branch and handler.
- Prefer no new persistent state.
- If counters require resident bytes, document owner, lifetime, clobbers, and
  address/segment; update `brain/MEMORY.md` if ownership changes.
- Measure Api/Vmm/AppTable/ShellExt boundaries after each increment.
- Stop before resident code approaches or overlaps `UserProgStart` (`$3800`).

## Failure and Cleanup

- Reject pointer wrap and disallowed destinations before writing.
- Validate all fatal conditions before the first destination write.
- No-REU returns success with unavailable fields.
- Malformed MCT/header behavior follows WP1 exactly.
- No allocation, file, or channel is acquired, so cleanup is state
  restoration only.
- Preserve all registers, flags, ZP, VMM parameters, and pointers promised by
  WP1.
- The call must leave MCT, app table, allocator, device, and shell state
  byte-for-byte unchanged.

## Atomic Increments

1. Add public constants and compile-time offset/size assertions in both
   include dialects.
2. Add dispatcher recognition with an explicit temporary error stub.
3. Implement destination validation and scalar fields.
4. Add valid-buffer and guard-byte tests.
5. Implement no-VMM successful snapshot behavior.
6. Implement read-only MCT counting.
7. Implement app count/capacity reporting.
8. Add malformed-state handling required by WP1.
9. Add preservation, repeated-call, and exact-size tests.
10. Update mirrored public documentation and durable records.
11. Run full static verification and request user runtime checks.

## Verification

Build targets, confirmed at activation:

```sh
cmake -S . -B build
cmake --build build --target command64
cmake --build build --target test_api
cmake --build build --target test_vmm
cmake --build build --target test_image_d64
cmake --build build --target image_d64
```

Required tests:

- Prefix and suffix guard bytes around the destination.
- Version/size/status/capability bytes exact.
- Pointer wrap and invalid destination leave output unchanged.
- No-REU snapshot returns static fields and unavailable VMM fields.
- Known safe MCT pattern produces approved counts.
- Unknown MCT state follows approved policy.
- MCT checksum/bytes are identical before and after the call.
- Repeated calls are identical when state is unchanged.
- Used/free/total invariants follow WP1 semantics.
- Both include dialects remain semantically identical.

Controlled MCT tests must modify only approved safe entries and restore every
byte before exit. Do not corrupt environment/app-table allocations.

User runtime checks:

- With REU: valid capability and plausible counts; repeated calls do not
  reduce free pages; existing VMM test still passes.
- Without REU: static fields remain available and optional fields are
  unavailable. Use an approved launch path if normal app-table loading cannot
  run without VMM.

## Stop Conditions

- WP1 field meaning is ambiguous.
- Reliable physical capacity is required but unavailable.
- Counter storage would invade caller ZP.
- Any MCT/app-table byte changes.
- Guard bytes change or partial output appears on error.
- Version sources disagree.
- App count and table scan disagree without a frozen corruption rule.
- Segment growth threatens `$1000` or `UserProgStart` (`$3800`) boundaries.
- No safe no-REU test path exists and no alternative is approved.

## Completion Gate

Present exact implemented bytes, measured segment delta, build/test evidence,
MCT before/after evidence, and REU/no-REU walkthrough. Ask the user whether
WP2 is complete. Do not activate WP3 or mark records complete before approval.
