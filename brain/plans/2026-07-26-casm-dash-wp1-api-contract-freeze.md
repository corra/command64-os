---
feature: casm-dash-wp1-api-contract-freeze
created: 2026-07-26
status: draft
---

# Plan: DASH WP1 - API Contract Freeze

## Objective

Freeze the byte-exact public contracts needed by DASH for system snapshots and
application enumeration. WP1 is a design and verification package only: it
must produce an approved contract before constants, dispatcher code, tests, or
functional documentation change.

Parent plan: `brain/plans/2026-07-26-casm-dash-system-dashboard.md`.

## Prerequisites

- Re-read the current DOX chain for every inspected path.
- Record the activation commit and preserve unrelated worktree changes.
- Confirm that `$5C` and `$5D` remain unassigned.
- Re-read the live dispatcher, VMM, app-table, loader, includes, API tests,
  memory map, and public API documentation; do not rely on this draft alone.
- Confirm whether the contract is general public ABI, not DASH-private ABI.

## Mandatory Activation Review

Every implementation work package begins by reviewing dependencies and
discrepancies against current code and approved predecessor plans. The review
must cite observed behavior, not names or historical documentation.

If a material discrepancy changes scope, files, ABI, storage, failure
semantics, verification, or an inherited decision:

1. Stop the work package before implementation.
2. Record expected versus observed behavior and root cause.
3. Identify affected predecessors and downstream plans.
4. Amend this plan with the minimal proposed resolution.
5. Obtain renewed explicit approval before continuing.

Minor observations that change no contract or work product may be recorded in
the walkthrough without amendment.

## Discrepancies to Resolve

1. **Service numbers:** `$5C/$5D` are currently free but must be checked
   against parallel plans when WP1 activates.
2. **Pointer convention:** the draft uses X/Y for the system destination and
   `$FB/$FC` for the app destination. Freeze either this asymmetric ABI or one
   consistent pointer convention.
3. **Status convention:** define carry and A for success, empty slot, invalid
   index, unavailable storage, malformed private data, and invalid arguments.
4. **Failure writes:** freeze whether destination is unchanged or cleared on
   each failure. Partial records are forbidden.
5. **Version encoding:** current OS version components are textual constants,
   not shared numeric bytes. Freeze binary, character, or generated encoding
   and one authoritative source.
6. **Program limit:** freeze `$C000` exclusive or `$BFFF` inclusive. Never
   publish `$CFFF` as user space because `$C000-$CFFF` is the MCT.
7. **Protected ranges:** decide whether the API reports explicit ranges or
   only the externally loadable interval.
8. **REU capacity:** current detection does not discover physical capacity.
   Separate physical capacity from the logical 4096-page MCT or mark capacity
   unavailable. Do not claim 16MB of physical RAM without detection.
9. **MCT counting:** define unknown page-state behavior and whether counts
   represent logical allocator state or physical capacity.
10. **App-table availability:** `vmmInitialized` does not prove `aptInit`
    succeeded; `AptSegLo/Hi` has no bank or explicit validity marker.
11. **Running state:** `APT_FLAG_RUNNING` is not currently maintained, and
    `DOS_EXIT` bypasses a simple post-JSR clear. Freeze the user-required WP3
    design for a truthful lifecycle across both normal return and `DOS_EXIT`.
12. **REU/stack flags:** current private flags have no producer. Freeze them as
    reserved or define truthful semantics.
13. **Name representation:** a 16-byte field cannot preserve all 16 characters
    and guarantee a terminator. Choose length+16 bytes, 17 terminated bytes,
    or a fixed-width non-terminated field.
14. **Range validity:** define zero size, inclusive-end overflow, and malformed
    private records.
15. **Destination safety:** define null, wraparound, protected region,
    I/O/ROM, and implementation-scratch overlap behavior.
16. **Register contract:** freeze A/X/Y, C/Z/N, decimal mode, interrupt state,
    `$61-$6F`, `$FB-$FE`, and VMM parameter preservation.
17. **App-count authority:** freeze compile-time capacity, header values,
    occupied-slot scans, and corruption handling.

## Contract Deliverables

The approved WP1 document must define:

- Final service numbers and names.
- Exact input and output registers.
- Exact status values and carry meaning.
- Record version negotiation and little-endian encoding.
- Every record byte, reserved byte, bit, size, and validity rule.
- Caller-buffer ownership and write boundaries.
- Output mutation on every status.
- Register, flag, zero-page, and persistent-state clobbers.
- Physical REU versus logical VMM semantics.
- App-table availability and bank identity strategy.
- Running-state policy.
- Compatibility and extension policy for future record versions.
- A test matrix with exact expected results.

## User-Frozen V1 Decisions

- Capacity fields describe the logical 4096-page MCT allocator only. They do
  not claim physical REU capacity detection.
- WP3 must implement a truthful running-state lifecycle covering normal return
  and `DOS_EXIT` before the public running bit is considered valid.
- The public app name representation is one length byte followed by 16 bounded
  name bytes. WP1 must freeze padding and invalid-length behavior.

## Proposed Starting Point

Reserve, subject to activation review:

```text
$5C DOS_GET_SYSTEM_INFO
$5D DOS_GET_APP_INFO
```

Recommended system behavior:

- Return a versioned fixed record.
- Succeed without an REU and capability-gate unavailable fields.
- Report `$C000` as the exclusive user limit.
- Report logical MCT page counts and explicitly mark physical REU capacity as
  unavailable/not represented in v1.

Recommended app behavior:

- Return an occupied record only with C clear.
- Return distinct C-set statuses for empty, invalid, unavailable, and
  malformed.
- Leave destination unchanged on every C-set result.
- Use an explicit name length plus 16 raw/padded name bytes.

These recommendations are not frozen until user approval.

## Expected Files

WP1 may add or update only planning records:

- `brain/plans/2026-07-26-casm-dash-wp1-api-contract-freeze.md`
- Parent plan, only if an approved decision changes it.

Activation review reads, but does not edit:

- `src/command64/api.asm`
- `src/command64/apptable.asm`
- `src/command64/vmm.asm`
- `src/command64/shell.asm`
- `include/command64.inc`
- `include/ca65/command64.inc`
- `include/vmm.inc`
- `include/ca65/vmm.inc`
- `tests/src/api/api.s`
- `tests/src/vmm/vmm.s`
- `wiki/api-reference.md`, `docs/api-reference.md`
- `wiki/programmers-reference.md`, `docs/programmers-reference.md`
- `wiki/vmm-api.md`, `docs/vmm-api.md`
- `brain/MEMORY.md`

## ABI and Storage Effects

WP1 itself changes no ABI or runtime storage. It must estimate downstream:

- Dispatcher and Api segment growth.
- System snapshot helper and counters.
- App query normalization code.
- Any persistent app-table validity/bank/running-state bytes.
- Temporary staging needs without consuming caller-owned `$70-$8F`.
- Resident end growth toward `UserProgStart`.

## Atomic Increments

1. Reconcile service-number and pointer conventions.
2. Freeze common statuses and output-on-error behavior.
3. Freeze system-record fields and validity bits.
4. Freeze app-record fields, name representation, and range rules.
5. Freeze VMM capacity/count semantics.
6. Freeze app-table availability, bank, and running-state strategy.
7. Freeze register/ZP/flag clobbers and destination safety.
8. Freeze compatibility/versioning policy.
9. Freeze test fixtures and acceptance evidence.
10. Present the complete contract for explicit approval.

## Verification

- Confirm record offsets add exactly to declared sizes.
- Confirm all multi-byte fields explicitly say little-endian.
- Confirm every status defines carry, A, and destination mutation.
- Confirm every optional field has a validity rule.
- Confirm no field claims unavailable physical-capacity knowledge.
- Confirm zero size and overflow cannot become plausible wrapped ranges.
- Confirm both include dialects can represent the same constants.
- Confirm proposed implementation fits current segment boundaries by estimate;
  actual measurement belongs to WP2/WP3.

WP1 may run baseline read-only builds after activation, but it changes no
production or test files.

## Stop Conditions

- `$5C/$5D` are reserved elsewhere.
- Physical capacity is mandatory without an approved detection design.
- Truthful running state is mandatory without an exit-path design.
- Version data has no authoritative representation.
- Record validity cannot distinguish unavailable from zero.
- Destination safety requires unapproved memory ownership.
- The worktree cannot isolate this plan from unrelated work.

## Approval Gate

WP1 is not complete until the user approves the exact ABI, records, statuses,
clobbers, capacity semantics, running-state policy, and verification matrix.
WP2 must not activate before that approval.
