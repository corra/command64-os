---
feature: casm-dash-wp9-integration-relocation-audit
created: 2026-07-26
status: draft
---

# Plan: DASH WP9 - Integration and Relocation Audit

## Objective

Prove that the final native-CASM DASH source produces one reproducible R6
artifact with complete and exclusive relocation entries, no private OS memory
dependencies, correct image packaging, no regressions, and identical behavior
at `$3800`, `$5000`, and `$9000`.

WP9 is an audit/integration package, not an open-ended defect-remediation
package.

## Prerequisites

- WP1-WP8 each have explicit completion approval.
- Final API ABI, DASH source order, source names, memory envelope, and artifact
  policy are frozen.
- DASH has passed a narrow `$3800` runtime check.
- VMM cleanup and no-REU behavior have user evidence.
- Active CASM baseline/version is identified; parallel CASM changes are either
  complete or explicitly excluded.
- Final disk names and production/test placement are frozen.

## Mandatory Activation Review

At activation, review every predecessor dependency and discrepancy against
current source, build targets, CASM CLI, R6 format, loader, image capacity,
documentation, and worktree state.

A material discrepancy includes any changed prerequisite, source order/name,
command, artifact format/path, API, memory ownership, relocation expectation,
new tool, fixture/image, runtime matrix, or DOX contract.

For any material discrepancy:

1. Stop the active increment.
2. Record expected and observed behavior plus root cause.
3. Assign the issue to a predecessor, WP9, WP10, or a new remediation WP.
4. Amend the appropriate plan with the minimal resolution.
5. Obtain renewed explicit approval before implementation.
6. Rerun the narrow failed check and then the full WP9 matrix.

Do not silently fix CASM, loader, API, or VMM defects in WP9.

## Artifact and Packaging Contract

Freeze a truthful native-CASM provenance chain:

1. Seven ordered `.s` files are authoritative source.
2. CASM under Command 64 creates the candidate R6 PRG.
3. A reviewed hex manifest records the approved bytes.
4. Existing `scripts/hex_manifest_to_bin.py` may transcribe/validate those
   bytes but performs no assembly.
5. CMake packages the generated PRG as `dash` without claiming host assembly.
6. Source changes cannot silently leave a stale shipping artifact; use an
   approved source hash/manual regeneration gate or stop.
7. Production source SEQs are packaged only if explicitly approved.

Use a dedicated production artifact path rather than placing a shipping app
under test references. Do not add files to `test.d64` without checking its
known directory-entry saturation.

## Expected Files

Likely integration files, subject to activation review:

- `CMakeLists.txt`
- DASH source and local DOX under `src/external/dash/`
- Approved DASH manifest/artifact path
- Existing `scripts/hex_manifest_to_bin.py` reused unchanged
- `cmake/cc1541.cmake` inspected; changed only if generic packaging is
  insufficient and an amendment is approved

Audit inputs, normally unchanged:

- `tools/reloc.py`
- `src/external/casm/reloc.s`
- `src/command64/loader.asm`
- Public API includes and implementations
- Existing CASM relocation harnesses/references

No one-off script is permitted. If a reusable R6 inspector becomes necessary,
stop, plan it under `tools/`, integrate tests/build use, and reapprove WP9.

## R6 Audit Contract

Layout:

```text
2-byte PRG load header
N program bytes
count * 2-byte little-endian relocation offsets
2-byte footer base
2-byte footer count
$52,$36 magic
```

For every relocation entry:

- Offset is relative to program bytes, not the PRG header.
- Offset is within `[0,N)`.
- Entry is unique and deterministic.
- Target is an eligible high byte of a relocatable value.
- Table/footer bytes are never targets.

Required positive classes include local JSR/JMP high operands, `#>label`,
renderer `.WORD` entries, local data/string pointers, and eligible absolute
indexed local table operands.

Required exclusions include `$1000`, KERNAL jump-table targets, VIC/SID/color/
CIA/REU registers, fixed screen addresses, OS/app ZP, branch displacements,
ordinary literals, and table/footer bytes.

## Private-Address Audit

Tie source expressions and decoded operands to findings; raw byte scans alone
are insufficient. DASH must not directly consume:

- `$C000-$CFFF` MCT/private OS space.
- App-table VMM segment or private offsets.
- REU registers `$DF00-$DF0A`.
- Undocumented `$61-$6F` uses.
- Kernel body entry points other than public `$1000` and documented KERNAL
  jump-table calls.

## Atomic Increments

1. Freeze baseline, artifact names/path, source hashes, command, and expected
   relocation ledger.
2. Assemble final DASH through native CASM in approved order.
3. Record and independently validate the reviewed artifact/manifest.
4. Audit header, payload length, every R6 entry, footer, and SHA-256.
5. Audit fixed/private address uses against source and decoded operands.
6. Wire production image packaging and stale-artifact protection.
7. Run OS/API/CASM/DASH static regression matrix.
8. Request user `$3800/$5000/$9000`, REU, no-REU, and lifecycle matrix.
9. Stop/amend on discrepancies; otherwise prepare WP9 walkthrough.
10. Ask for explicit WP9 completion approval.

## Static Verification Matrix

- Configure and build `command64`, `casm`, applicable API/VMM tests,
  `image_d64`, and required test images.
- Native command uses exactly the approved files/order and fits 80 bytes.
- Candidate output and reviewed artifact are byte-identical.
- Header is `$3400`; footer base/count/magic are exact.
- Every relocation offset is bounded, unique, complete, and exclusive.
- No forbidden fixed/private address is relocation-dependent.
- No-change native assembly is byte-identical.
- Production image contains one unambiguous `dash` PRG.
- Disk blocks, free blocks, and directory entries remain valid.
- Existing CASM relocation references and API/VMM regressions pass.
- No-change host rebuild does not produce unintended build-counter changes.
- Git status/diff contains only approved files.

Likely commands must be reconfirmed at activation:

```sh
cmake -S . -B build
cmake --build build --target command64
cmake --build build --target casm
cmake --build build --target test_api
cmake --build build --target test_vmm
cmake --build build --target image_d64
cmake --build build --target test_image_d64
```

## User Runtime Matrix

For the same artifact at `$3800`, `$5000`, and `$9000`:

- Frame/title/tabs/status render correctly.
- F1/F3/F5 relocated dispatch works.
- R refreshes deterministically.
- System fields are correct or explicitly unavailable.
- Applications page reports DASH at the actual relocated range.
- Q returns cleanly.

With REU:

- Record free pages before test.
- Run VMM test at least three times.
- Confirm all patterns pass and free pages return to baseline.

Without REU:

- DASH launches through the approved path.
- VMM page reports unavailable.
- T performs no transfer/allocation.
- Navigation and exit remain safe.

Run at least five launch/quit cycles and check stack, screen, app table, and
VMM page stability.

## Stop Conditions

- Any predecessor lacks approval.
- Native CLI or source limits differ materially.
- Shipping artifact can become stale relative to source.
- Disk capacity/directory limit is exceeded.
- Any R6 entry is missing, duplicated, out of bounds, or forbidden.
- DASH accesses private OS/VMM state.
- Behavior differs by load address.
- Allocation leaks or cleanup fails.
- Existing regression fails.
- Loader/CASM/API remediation is required.
- New R6 tooling is needed but unplanned.

## Completion Gate

Present artifact provenance/hash/size, disk inventory, complete relocation and
private-address ledgers, static builds, and user runtime results. Ask whether
WP9 is complete. Do not mark it complete or activate WP10 closeout before the
user's explicit response.
