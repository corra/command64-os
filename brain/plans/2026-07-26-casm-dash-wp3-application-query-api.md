---
feature: casm-dash-wp3-application-query-api
created: 2026-07-26
updated: 2026-07-27
status: complete
---

# Plan: DASH WP3 - Application Query API

## Objective

Implement the WP1-approved public query for one application slot. Return a
normalized record for occupied slots while distinguishing empty, invalid,
unavailable, and malformed states. Never expose the private app-table VMM
identity or raw 40-byte layout.

Parent: `brain/plans/2026-07-26-casm-dash-system-dashboard.md`.
Dependencies: WP1 contract and approved WP2 completion.

## Prerequisites

- WP1 exact app ABI approved.
- WP2 complete and approved.
- Name representation, range arithmetic, statuses, pointer ABI, output-on-
  failure, and running-state policy frozen.
- App-table availability and bank strategy frozen.
- Existing API/VMM tests pass and resident headroom is measured.

## Mandatory Activation Review

Re-trace `aptInit`, `aptSlotBase`, registration/removal, run/exit paths,
VMM byte/block reads, bank handling, and every app flag producer. Compare the
live code to WP1 and this plan.

Any material discrepancy stops implementation. Record expected versus
observed behavior and root cause, amend affected plans, and obtain renewed
approval. In particular, do not hide app-table validity, bank, or running-
state fixes inside the query routine without approved scope.

## Known Activation Hazards

- App-table helpers set segment/offset but may rely on ambient `VmmBank=0`.
- `aptSlotBase` clobbers shared scratch.
- `vmmReadByte` returns zero when unavailable and cannot report mid-read
  failure.
- `vmmInitialized` does not prove app-table allocation succeeded.
- Removal clears flags but leaves stale name/address/size bytes.
- Full 16-character private names may have no terminator.
- Private range helpers use exclusive end while DASH displays inclusive end.
- `APT_FLAG_RUNNING`, `APT_FLAG_REU`, and `APT_FLAG_STACK` lack current
  truthful producers.
- `DOS_EXIT` resets the stack and jumps to the shell, complicating running-bit
  cleanup.

## Expected Files

Production:

- `include/command64.inc`
- `include/ca65/command64.inc`
- `src/command64/api.asm`
- `src/command64/apptable.asm`
- `src/command64/vmm.asm`, only for an approved safe read helper
- `src/command64/shell.asm`, only if WP1 approved truthful running lifecycle

Tests:

- Prefer extending `tests/src/api/api.s`.
- Re-run `tests/src/vmm/vmm.s` as regression.

Documentation and records:

- `wiki/api-reference.md` and `docs/api-reference.md`
- `wiki/programmers-reference.md` and mirror
- `brain/MEMORY.md` only for actual ownership/address changes
- `brain/KNOWLEDGE.md`, `CHANGELOG.md`, and affected DOX

## Call Path

```text
caller -> JSR $1000 -> apiHandler -> ahGetAppInfo
  -> validate reserved input, index, and destination
  -> validate VMM/app-table availability
  -> establish explicit table segment and bank
  -> read flags only
     -> unused: EMPTY, do not copy stale bytes
  -> read and normalize name/address/size/flags
  -> validate zero size and inclusive-end overflow
  -> emit exactly one public record
  -> return approved status
```

Potential private helpers:

- `aptValidateAvailable`
- `aptQuerySlotNormalized`
- `aptReadNameNormalized`
- `aptComputeInclusiveEnd`
- `aptPublicFlags`

Do not return `AptSegLo/Hi`, `VmmOffLo/Hi`, or `VmmBank`.

## Public/Private Mapping

- Validate slot against approved public capacity before offset arithmetic.
- Read flags first and stop on an empty slot.
- Normalize private flags into a stable public bitset rather than accidentally
  freezing every private bit.
- Normalize names exactly as WP1 specifies, bounded by private field size.
- Return load address and byte size little-endian.
- Compute or validate inclusive end only after size is proven nonzero.
- Reject 16-bit overflow; never return a plausible wrapped range.
- Define whether loaded size excludes R6 table/footer according to loader
  registration behavior, and document it.

## Running-State Increment

The user requires a truthful `R` flag for v1. Implement it as a separately
reviewed atomic increment within WP3:

- Establish a persistent current-slot identity or a complete private-flag
  lifecycle.
- Cover normal `RTS` return and `DOS_EXIT` stack-reset/jump behavior.
- Clear stale running state on every shell re-entry path.
- Prove `FREE` semantics remain correct.

If this cannot be made complete, stop and amend WP1/WP3; do not publish a
best-effort running flag or continue to WP4.

## ABI, Storage, and Segment Effects

- Add identical app service, record, status, and public flag constants to both
  includes.
- Prefer field-by-field normalized reads to avoid a resident staging buffer.
- If staging is required, allocate bounded resident storage with an explicit
  owner; never use external-app `$70-$8F`.
- Explicitly set and preserve/restore VMM bank and parameters according to
  WP1.
- Measure AppTable/ShellExt and pre-API boundaries after each increment.
- Any persistent validity/bank/running byte requires memory-map and DOX review.

## Failure and Cleanup

- Invalid index/reserved input fails before VMM access.
- Unavailable must not masquerade as an empty zero byte.
- Empty reads flags only and never copies stale private fields.
- Malformed records never produce a partial valid-looking output.
- Query acquires no allocation or file, so cleanup restores promised scratch,
  pointers, VMM parameters, and registers.
- All private header, slot, MCT, and allocator bytes remain unchanged.
- Mid-read hardware failures cannot be promised detectable if the underlying
  primitive cannot report them; document the limitation.

## Atomic Increments

1. Add public constants/assertions in both include dialects.
2. Add dispatcher branch with explicit temporary error stub.
3. Implement argument and destination validation.
4. Implement app-table availability and explicit bank setup.
5. Implement empty-slot result without stale copy.
6. Implement occupied flags/address/size reads.
7. Implement name normalization.
8. Implement zero-size and end-overflow handling.
9. Emit exact public record and preserve promised state.
10. Add occupied/empty/invalid/unavailable/malformed tests.
11. Implement and verify the user-required truthful running lifecycle.
12. Update mirrored docs and durable records.
13. Run full regression and request runtime checks.

## Verification

Build:

```sh
cmake --build build --target command64
cmake --build build --target test_api
cmake --build build --target test_vmm
cmake --build build --target test_image_d64
cmake --build build --target image_d64
```

Required controlled cases:

- Occupied slot with known name/load/size/flags.
- Full 16-character name under the frozen normalization rule.
- Empty slot containing deliberately stale nonzero private bytes.
- Invalid indices 16 and `$FF`.
- Nonzero reserved input.
- Zero-sized occupied record.
- Inclusive-end overflow.
- Valid upper-bound range.
- VMM/app table unavailable.
- Destination prefix/suffix guards.
- Private header/slot bytes identical before and after query.
- Ambient `VmmBank` preloaded nonzero; query still reads the correct table and
  obeys preservation rules.
- Repeated query does not change used slots or VMM pages.

Any test that mutates private records must save and restore the complete raw
slot/header and must not corrupt the test program's own registration.

User walkthrough:

- Load multiple applications at distinct addresses.
- Query all occupied and empty slots.
- Confirm names/ranges/sizes/flags and no stale rows.
- Exercise running state through both approved return paths if implemented.
- Run `APPS` and `FREE` afterward to prove table integrity.
- Repeat without REU using an approved direct-launch path if needed.

## Stop Conditions

- App-table bank or validity cannot be established safely.
- Query must expose private pointers/layout.
- Full names cannot satisfy WP1 format.
- Empty queries leak stale data.
- Any private/MCT byte changes.
- Inclusive arithmetic wraps.
- Truthful running state cannot cover `DOS_EXIT`.
- Required staging has no approved owner.
- Resident growth threatens `UserProgStart` (`$3800`).

## Completion Gate

Present public/private mapping, all status evidence, guard and immutability
results, bank-contamination result, code/storage delta, and running-state proof
or approved limitation. Ask the user whether WP3 is complete before WP4
activation or completion records.
