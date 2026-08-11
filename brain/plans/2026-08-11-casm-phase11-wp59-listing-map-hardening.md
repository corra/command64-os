---
feature: casm-phase11-wp59-listing-map-hardening
created: 2026-08-11
status: approved
amendment-status: approved
taskwarrior: 4a1fab7c-28af-4404-af39-6f283b552e55
depends-on: d297b689-3fba-4e16-81f7-8176b39a07e2
---

# Plan: CASM Phase 11 WP59 - Listing and Map Hardening

## Status and Authorization

**Approved 2026-08-11.** Approval activates Increment 1 only: freeze and review
the routine-contract matrix. No production source, fixture, build, version, or
release change is authorized until the Increment 1 user gate passes. WP59
Taskwarrior child `4a1fab7c-28af-4404-af39-6f283b552e55` is active under the
Phase 11 parent and depends on completed WP58.

Parent plan:
`brain/plans/2026-08-08-casm-phase11-base-release-hardening-documentation.md`.
Prerequisite: WP58, complete and user-approved 2026-08-11.

Baseline: CASM `0.2.0` build `1260`, Phases 1-10 complete; Phase 11 WP56-WP58
complete.

## Objective

Harden every exported routine in `listing.s` and `map.s`, Phase 11's two
highest-risk modules, by verifying and correcting:

- carry, zero-flag, and diagnostic propagation;
- declared `A`/`X`/`Y` preservation and clobber behavior;
- stack balance on every success, failure, no-op, and retry path;
- shared zero-page scratch lifetimes across subordinate calls;
- BSS initialization and repeat-invocation safety;
- file, VMM, registry, and artifact ownership during failure and cleanup;
- output compatibility for every valid `/L` and `/M` input.

This is a general routine-contract audit, not a repeat of WP55's selected
full-path behavioral review. Confirmed defects found by the audit are fixed in
WP59 rather than deferred.

## Inherited Decisions

1. WP59 audits `listing.s` and `map.s` first because WP56 ranks them Tier 1:
   newest, least independently audited, and previously affected by register and
   shared-buffer clobber defects.
2. The audit is exhaustive for these two modules' exported routines and their
   private transitive paths. Phase 11 remains risk-based outside this boundary.
3. WP58's runtime `$1000` `OS_API` interception mechanism is reused for
   deterministic file and VMM failures.
4. Synthetic fault fixtures remain alongside existing real-disk coverage; they
   do not replace it.
5. Confirmed production defects are fixed within WP59.
6. An opened listing whose handle registration fails remains listing-private
   owned state until it is closed and its uncommitted artifact is deleted.
7. Invalid included-file device metadata is rejected in `listing.s` with
   `CASM_DIAG_LISTING_REPLAY_MISMATCH`; no new diagnostic is introduced.
8. Close retries are caller-driven and unlimited. Each invocation makes exactly
   one close attempt; no internal retry loop is permitted.
9. `faultUninstall` is added for the new WP59 listing harness only. Existing
   WP58 harnesses must rebuild against the shared include but are not modified
   to call it in this work package.
10. New listing coverage uses one focused contract/fault harness. Map coverage
    extends `test_casm_map`; no unified listing/map harness is introduced.
11. WP59 completion advances CASM from `0.2.0` to `0.2.1` only after all
    verification and explicit completion approval.
12. Ten atomic increments are retained so audit evidence, fixture foundations,
    production fixes, and completion remain separately reviewable.

## Reconciled Audit Surface

### Exported `listing.s` routines

The audit covers all 18 exported routines:

1. `listingStateInit`
2. `listingCaptureInit`
3. `listingMetaAppend`
4. `listingReplayReset`
5. `listingReplayNext`
6. `listingBeginLine`
7. `listingMirrorByte`
8. `listingCommitLine`
9. `listingCaptureFinalize`
10. `listingFileInit`
11. `listingCreate`
12. `listingWrite`
13. `listingClose`
14. `listingDelete`
15. `listingAbort`
16. `listingValidateRecord`
17. `listingResolveFilename`
18. `listingWriteFile`

Every exported listing-state symbol is also audited for intentional ABI,
initialization, ownership, and test-only leakage.

### Private `listing.s` paths

The exported-routine audit includes all load-bearing private callees:

- `listingFlushStage`, `listingBuildOpenName`, and `laRecordSecondary`;
- row-buffer, hexadecimal, decimal, spacing, and raw-byte formatters;
- byte-mirror and source-span readers;
- byte/source continuation row emitters;
- aggregate append/flush logic;
- file-header and detail-record serialization.

### Exported `map.s` routine

`mapPrint` is the sole map export. Its transitive audit includes
`mapValidateRecord`, `mapFormatRow`, `mapWriteHexByte`, `mapWriteNibble`, and
`mapFormatTotal`, plus assumptions made across `symbolsReadByIndex` and
`diagPrintString`.

## Existing Coverage and Gaps

Existing `test_casm_listing`, `test_casm_listcap`, `test_casm_listwrite`, and
`test_casm_map` already prove normal storage/replay, capture integration,
listing serialization, symbol ordering, major capacity bounds, structural
record rejection, and selected VMM failures. WP59 adds only missing contract
and failure evidence:

- wrong-state results for replay, finalize, create, write, close, and serializer
  preconditions;
- explicit `A`/carry/zero/register/stack checks rather than screen behavior
  alone;
- first/second allocation and stage/final-flush failures;
- listing create/write/short-write/close/delete failure injection;
- retry and primary-diagnostic preservation after cleanup failures;
- serializer failures at replay, catalog, source, mirror, aggregate-write, and
  final-close boundaries;
- malformed included-device metadata;
- map validation edges and decimal transitions not covered by WP52;
- BSS poisoning/re-entry and shared-zero-page live-range checks.

## Confirmed Defects and Required Corrections

### 1. Failed listing close is not retryable

The current header promises retry after `CASM_FILE_STATE_CLOSE_FAILED`, but
`listingClose` accepts only `CASM_FILE_STATE_OPEN`. A later direct call or
`listingAbort` therefore returns `CASM_DIAG_STREAM_STATE_FAILED` without making
another `DOS_CLOSE_FILE` attempt.

Required correction:

- accept both `OPEN` and `CLOSE_FAILED`;
- make one close attempt per invocation;
- retain handle, slot, opened flag, and failure state after rejection;
- clear ownership only after successful close;
- support both registered and listing-private unregistered handles;
- prove direct and `listingAbort`-driven retry.

### 2. Registration failure can leave an artifact or handle

After `DOS_OPEN_FILE` succeeds, `resourceRegisterHandle` failure currently
attempts one unchecked close, records no ownership, and never deletes the
created/replaced `.LST` artifact.

Required correction:

- record the real handle immediately in `CasmListFileHandle`;
- set `CasmListFileSlot = CASM_INVALID_SLOT` to represent listing-private,
  unregistered ownership;
- set `CasmListFileOpened` and file state before compensation;
- preserve `CASM_DIAG_LISTING_CREATE_FAILED` as the primary diagnostic;
- route compensation through committed-aware listing cleanup;
- close an unregistered handle directly through `DOS_CLOSE_FILE`;
- delete the uncommitted listing only after close succeeds;
- retain retry state after close or delete failure;
- allow the production fatal path's later `artifactsAbort` call to retry;
- never register the failed handle retroactively and never silently abandon it.

The existing state plus `CASM_INVALID_SLOT` is the preferred representation.
No new enum or BSS field is added unless implementation proves that
representation ambiguous; such a finding is a stop condition requiring plan
amendment.

### 3. Included-file device metadata is unchecked

`listingResolveFilename` currently subtracts `CASM_DEVICE_MIN` and indexes the
four-entry device-string table without validating the catalog device.

Required correction:

- accept only devices 8-11 before table indexing;
- reject devices below 8 or above 11 with
  `CASM_DIAG_LISTING_REPLAY_MISMATCH`;
- leave resolved-name output non-consumable on failure;
- preserve valid device 8 and 11 output bytes exactly.

### 4. Stale local implementation headers

`listing.s` and `map.s` still contain Phase 10 comments saying `/L` or `/M` is
not wired into production. WP59 corrects stale routine/module-local comments
needed to understand the audited code. Broad manual, knowledge-base, and
cross-tier synchronization remains WP62 unless WP59 changes a durable contract
that must be documented immediately.

## ABI, Storage, and Output Effects

- No new zero-page byte is planned or authorized.
- Listing-private unregistered ownership reuses existing handle, slot, opened,
  valid, committed, delete-pending, and file-state fields.
- No public OS API, command-line grammar, diagnostic number, listing record,
  symbol record, map row, listing row, PRG, or R6 format changes.
- Valid `/L` and `/M` outputs must remain byte-identical to the `0.2.0`
  baseline.
- Invalid internal metadata and failed cleanup become safer and more
  deterministic.
- CASM MAIN-envelope growth is not pre-authorized.

## Register, Flag, Stack, and Scratch Contract

The Increment 1 matrix records for every exported routine:

- all input registers and state cells;
- returned `A`, carry, and any promised zero state;
- preserved and clobbered `X`/`Y` values;
- shared zero-page and BSS scratch used directly or transitively;
- stack delta at each return;
- state mutation permitted before and after each failure point.

Fixture rules:

- use sentinel `A`/`X`/`Y` values where preservation is promised;
- compare `TSX` snapshots before and after each tested path;
- test `listingFileInit`'s documented Z-set and X/Y preservation explicitly;
- do not strengthen disabled-hook `A` behavior unless the existing header
  promises it; test only carry/no-op where `A` is unspecified;
- verify subordinate failures propagate their documented `A`/carry pair unless
  the caller intentionally substitutes a listing-specific diagnostic;
- poison private BSS before initialization and repeat initialization in one run;
- trace shared scratch values across every `OS_API`, VMM, source, include,
  resource, diagnostics, and file call.

## Failure and Cleanup Contract

1. The first nonzero diagnostic remains primary.
2. A cleanup failure is returned only when no primary diagnostic exists.
3. A failed close retains ownership for a later caller-driven retry.
4. A failed delete leaves `Opened` and `DeletePending` set for retry.
5. A committed listing is never deleted.
6. An uncommitted partial listing is deleted only after its handle is closed.
7. A registered handle closes through `fileClose`; an unregistered listing-
   private handle closes directly through `DOS_CLOSE_FILE`.
8. No failure advances metadata count, replay cursor, byte cursor, symbol-map
   cursor, or serializer state beyond its documented commit point.
9. No internal retry loop can hang on a missing device or failed drive.
10. Every test exit restores the original `OS_API` vector before `DOS_EXIT`.

## Fault-Stub Amendment

Add `faultUninstall` to
`tests/src/casm_faultinject/faultstub.inc` for the new WP59 harness:

- restore `$1001/$1002` from `RealApiVectorLo/Hi` captured by `faultInstall`;
- be repeat-safe;
- leave the real `OS_API` passthrough usable after restoration;
- be called from every WP59 harness success/failure exit;
- retain machine reset as emergency recovery, not the normal inter-run rule.

Existing WP58 fixture source is not retrofitted in WP59. All WP58 targets must
rebuild against the include change, and at least one existing WP58 fixture must
run live to prove backward compatibility.

## Harness Design

### New focused listing harness

Tentative target: `test_casm_flist` in a collision-safe directory under
`tests/src/`. Its final target and 16-character D64 name are frozen in Increment
2 after checking the generated disk directory.

The harness links the real listing module and the narrowest real subordinate
set needed for each fixture. It supplies:

- WP58 fault interception plus `faultUninstall`;
- register sentinels and stack-depth checks;
- BSS poisoning and state snapshots;
- deterministic call-count targeting;
- exact diagnostic/carry/state assertions;
- explicit cleanup and vector restoration before exit.

### Increment 6 harness split amendment (approved 2026-08-11)

Increment 6 originally added its nine filename/device/header cases to
`test_casm_flist`, growing the previously live-proven Increment 5 artifact from
11,033 bytes (44 blocks) to 12,319 bytes (49 blocks). The resulting PRG does not
complete `KernalLOAD` under the required VICE workflow. A temporary checkpoint
immediately after `shellLoadPrg`'s `JSR KernalLOAD` received zero hits after 90
seconds, proving the load stalls before relocation and before harness entry.

Host-side RCA ruled out an invalid build or disk artifact:

- extracting the 49-block file from `casm_listing_test.d64` produces a
  byte-identical copy of `build/test_casm_flist.prg`;
- regenerating the R6 artifact from the `$3800`/`$3900` link pair also produces
  a byte-identical copy;
- the footer reports base `$3800`, 9,157 code bytes, and 1,577 relocation
  points; the complete PRG is 12,319 bytes;
- the D64 chain contains all 49 blocks and the correct final-sector byte count.

The amended test boundary is therefore:

- restore `test_casm_flist` to its live-proven 41 Increment 2-5 cases and its
  smallest measured fitting envelope;
- add collision-safe target `test_casm_flmeta` for Increment 6's nine
  filename/device/header/snapshot cases;
- link both targets through the same real `listing.s`, file/VMM/resource
  dependencies, and shared fault stub; do not duplicate or change production
  behavior to accommodate the split;
- package both on `casm_listing_test.d64`, which had 100 free blocks with the
  stalled 49-block combined harness and therefore has sufficient measured
  capacity for two focused artifacts;
- require byte-identical host/D64/R6 validation for both artifacts, successful
  Command64 loading, 41/41 and 9/9 case passes, normal shell return, and no
  `FLI06*.LST` artifacts.

This is a test-only packaging amendment. It authorizes no production ABI, BSS,
zero-page, diagnostic, format, or valid-output change. The user approved it on
2026-08-11.

### Existing map harness

Extend `tests/src/casm_map/casm_map.s`; do not create a second map target.

### Disk placement

- Do not add to `test.d64`; its directory track is full.
- Do not add a substantial fixture to `casm_overflow_test.d64`; WP58 left about
  seven blocks free.
- Prefer the self-bootable `casm_listing_test.d64`.
- If the new fixture does not fit with safe margin, stop and seek approval for a
  dedicated WP59 image rather than removing or moving existing coverage.

## Atomic Increments

### Increment 1 - Freeze the routine-contract matrix

- Trace all 19 exported routines (18 listing plus `mapPrint`) and their private
  transitive call trees directly from current source.
- Record inputs, outputs, carry/zero, register, stack, scratch, state mutation,
  and cleanup contracts.
- Map every existing fixture to each path and identify only real gaps.
- Confirm the three defects above against exact current line paths.
- Produce no production or fixture change.

Gate: user reviews the frozen matrix before executable work begins.

### Increment 2 - Build the listing contract-harness foundation

- Add the focused listing harness and CMake linkage.
- Add `faultUninstall` to the shared include and prove install/uninstall restores
  real API passthrough.
- Add register sentinels, `TSX` stack checks, BSS poisoning, state snapshots,
  and common reporting.
- Cover initialization/re-entry, disabled hooks, duplicate/missing
  transactions, and wrong-state paths.
- Freeze target name, envelope, and disk placement from measured output.

Gate: no production source change; narrow target and affected WP58 targets
build, and the harness exits with the real API vector restored.

### Increment 3 - Harden capture and VMM failures

Inject and verify:

- first metadata allocation failure;
- second byte-mirror allocation failure;
- metadata append write failure;
- mirror-stage flush failure;
- final partial-stage flush failure;
- metadata replay read failure;
- serializer byte-mirror read failure.

Assert exact ownership, unchanged counters/cursors after rejected operations,
retryable staged bytes, transaction disposition, and non-advancement to
`COMPLETE` after failed finalization.

### Increment 4 - Fix listing file lifecycle

- Implement retryable `OPEN`/`CLOSE_FAILED` close behavior.
- Distinguish registered and unregistered ownership by slot validity.
- Implement registration-failure compensation and retry state.
- Inject create, registration, write, short-write, close, and delete failures.
- Verify direct and `listingAbort` retry, committed preservation, uncommitted
  deletion, and primary/secondary diagnostic selection.

Gate: no handle or artifact becomes ownerless on any tested path.

### Increment 5 - Harden serializer failures

Inject failures at:

- metadata replay;
- record/catalog validation;
- source-span read;
- byte-mirror read;
- aggregate write and short write;
- final close;
- abort close and delete.

Verify first-failure preservation, immediate stop after fatal error, bounded row
and aggregate cursors, cleanup retry state, artifact disposition, and stack
balance through nested formatter exits.

### Increment 6 - Validate filename/device metadata

- Add device-range validation before table indexing.
- Verify included devices 8 and 11.
- Reject devices 7 and 12 with replay mismatch.
- Verify root identity, catalog read failure, maximum include filename, and
  header continuation boundaries.
- Re-prove that `includeCatalogRead` clobbering `CasmVmmBuffer` cannot corrupt
  the current listing-record snapshot.
- Apply the approved harness split above: retain the 41 previously proven cases
  in `test_casm_flist` and run these nine cases in `test_casm_flmeta`.

### Increment 7 - Expand map contract coverage

Add cases for:

- NameLen 32 and 255;
- DEFINED clear and independent reserved flag bits;
- nonzero reserved bytes at offsets 37 and 63;
- VMM failure after one or more valid rows;
- decimal totals at 9/10, 99/100, 255/256, and 511/512;
- repeat determinism and `$0000`/`$FFFF` address formatting;
- exported `mapPrint` carry/register/stack contract;
- documented `diagPrintString` clobber assumptions.

Valid map output order and bytes must not change.

### Increment 8 - Complete static ownership and local-header audit

- Prove neither module defines private zero-page storage.
- Audit every shared-scratch live range across subordinate calls.
- Prove load-bearing BSS is initialized before first read and repeat-safe.
- Review every exported listing-state symbol for intentional ABI.
- Correct stale local comments saying `/L` or `/M` remains unimplemented.
- Perform the DOX pass; update local contracts only if behavior or ownership
  changed.

### Increment 9 - Consolidated verification

Build and inspect:

- new listing hardening target;
- Increment 6's split `test_casm_flmeta` target;
- `test_casm_listing`, `test_casm_listcap`, `test_casm_listwrite`, and expanded
  `test_casm_map`;
- all WP58 fault targets affected by `faultstub.inc`;
- `casm`, `casm_listing_test_d64`, production `image_d64`, and full unrestricted
  build;
- no-change rebuild stability, PRG/R6 headers/trailers, sizes, and relocation
  counts.

Live verification under `.agents/workflows/vice-mcp-testing.md`:

- boot and identify Command64 before every application launch;
- run every new contract/fault case and all affected regressions;
- run at least one unchanged WP58 harness after `faultUninstall` is added;
- verify production `/L`, `/M`, and `/M /L` smoke paths;
- prove shell return after every harness;
- keep VICE running after tests unless recovery requires restart.

Compare representative valid PRG/R6/listing/map artifacts against the `0.2.0`
baseline. Any unexplained valid-output difference is a stop condition.

### Increment 10 - Walkthrough and completion gate

- Record every exported routine and its audit disposition.
- Record every private path reviewed and every fixture result.
- Record fixed defects, measured storage/envelope effects, artifact comparisons,
  and remaining disclosed risks.
- Update Taskwarrior, `wiki/tasks/casm.md`, `brain/task.md`, `CHANGELOG.md`,
  `brain/KNOWLEDGE.md`, `brain/MEMORY.md`, and applicable DOX.
- Produce the WP59 walkthrough and request explicit completion approval.
- Only after approval, advance CASM to `0.2.1`, verify the version-only artifact
  delta and stable no-change rebuild, then mark WP59 complete.

## Expected Files

Planned production/local-contract changes:

- `src/external/casm/listing.s`
- `src/external/casm/map.s` only if its audit finds a source/header defect
- `src/external/casm/AGENTS.md` only for a changed durable local contract

Planned test/build changes:

- `tests/src/casm_faultinject/faultstub.inc`
- one new focused listing harness directory under `tests/src/`
- a second focused `tests/src/casm_faultinject_listing_meta/` directory only
  for the approved Increment 6 harness split
- `tests/src/casm_map/casm_map.s`
- `CMakeLists.txt`
- `tests/AGENTS.md` for durable fixture placement/launch verification

Planned records:

- this plan and a later walkthrough;
- `wiki/tasks/casm.md`, Taskwarrior, and `brain/task.md`;
- `CHANGELOG.md`, `brain/KNOWLEDGE.md`, and `brain/MEMORY.md` at completion;
- CASM version/build records after explicit completion approval.

`casm.s`, `common.inc`, OS source, output formats, and public diagnostics are
not expected to change. Any need to change them is disclosed before proceeding.

## Verification Matrix Summary

| Area | Required proof |
| --- | --- |
| Init/re-entry | poisoned BSS, exact state, X/Y/Z promises, repeat safety |
| Carry/diagnostics | every exported success/failure/no-op branch |
| Stack | entry/exit `SP` equality for every exercised path |
| VMM | allocation/write/read/final-flush failures with commit-point state |
| File lifecycle | create/register/write/short/close/delete and retries |
| Serializer | replay/catalog/source/mirror/write/close/delete failures |
| Device metadata | valid 8/11, invalid 7/12, no out-of-range table access |
| Map | validation edges, decimal transitions, partial-output failure |
| Ownership | no orphan handle, allocation, partial artifact, or stale vector |
| Compatibility | valid PRG/R6/listing/map bytes unchanged from `0.2.0` |
| Integration | full build, disk images, live VICE, shell return |

## Stop Conditions

Stop, disclose, and amend this plan before continuing if:

- listing-private unregistered ownership cannot be represented safely with the
  existing state plus `CASM_INVALID_SLOT`;
- a new zero-page byte, public state enum, diagnostic, output record, or file
  format is required;
- CASM's production MAIN envelope must grow;
- a stack imbalance is found;
- an exported routine relies on undocumented subordinate register preservation;
- a committed PRG or listing can be deleted by a tested failure path;
- a handle, VMM allocation, or uncommitted artifact cannot remain retry-owned;
- valid `/L` or `/M` output bytes change;
- `faultUninstall` changes existing WP58 fixture behavior or cannot restore the
  API vector exactly;
- `casm_listing_test.d64` cannot hold the new fixture with safe margin;
- map audit requires an ordering or format change;
- a material change extends beyond listing/map hardening.

## Documentation, Task, and DOX Rules

- On approval, create a WP59 Taskwarrior child dependent on completed WP58 and
  add it to `wiki/tasks/casm.md` before implementation.
- Keep plan progress, wiki status, Taskwarrior annotations, and `brain/task.md`
  synchronized after each accepted increment.
- Correct stale comments local to audited source immediately.
- Defer broad clean-room documentation synchronization to WP62 unless WP59
  changes a durable behavior that would otherwise leave current docs false.
- Perform a DOX pass after every meaningful edit and update the nearest owning
  `AGENTS.md` only when purpose, ownership, contracts, workflow, or durable
  verification changes.

## Completion Gate

WP59 completes only when:

1. all 19 exported routines have an explicit audit disposition;
2. every private transitive path has audit or fixture evidence;
3. close retry, registration cleanup, and device validation are fixed;
4. every new and existing listing/map fixture passes;
5. affected WP58 targets remain compatible with the shared stub amendment;
6. valid `/L` and `/M` artifacts remain byte-identical to baseline;
7. no ownership, stack, zero-page, BSS, register, or carry defect remains in
   the audited boundary;
8. consolidated build and live VICE verification pass;
9. task, documentation, walkthrough, and DOX records agree;
10. the user explicitly approves completion and the verified `0.2.1` increment.

## Review Questions

All design questions raised during drafting are resolved:

- fix confirmed defects within WP59: yes;
- registration failure policy: close, then delete, preserving primary;
- invalid-device validation owner: listing-side check;
- harness structure: one focused listing harness plus expanded map harness;
- Increment 6 harness structure: pending approval to split the 41 proven cases
  from nine metadata/header cases after the combined PRG stalled in
  `KernalLOAD`;
- unregistered close ownership: listing-private pending state;
- `faultUninstall`: add for WP59 only, no WP58 source retrofit;
- invalid-device diagnostic: existing replay mismatch;
- close retries: unlimited caller-driven, one attempt per call;
- completion version: `0.2.1`;
- granularity: ten increments.

The user approved this plan as written on 2026-08-11. Increment 1 is active;
later increments remain gated by the Increment 1 matrix review, and material
deviations still require an amended plan and renewed approval.

## Progress

- 2026-08-11: User approved the dedicated plan. Created and started
  Taskwarrior child `4a1fab7c-28af-4404-af39-6f283b552e55` dependent on
  completed WP58, created branch `feature/casm-phase11-wp59`, and activated
  Increment 1 only.
- 2026-08-11: Increment 1 contract matrix frozen at
  `brain/reviews/2026-08-11-casm-phase11-wp59-increment1-contract-matrix.md`.
  Traced all 19 exports and private transitive paths, mapped existing evidence
  and later-increment gaps, froze shared-scratch/storage constraints, and
  confirmed the exact D1-D3 production defect paths. No production, fixture,
  build, version, ABI, or artifact changed. Awaiting user review before
  Increment 2 activation.
- 2026-08-11: User approved the Increment 1 matrix and activated Increment 2.
  Added repeat-safe `faultUninstall` to the shared WP58 include and a focused
  `test_casm_flist` harness with 15 cases covering exact API-vector restore and
  real passthrough, poisoned/repeated listing capture and file initialization,
  documented X/Y/Z/A/carry/stack contracts, disabled hook no-ops, duplicate or
  missing transactions, and every frozen wrong-state entry. The `$2200`
  envelope fit without adjustment: final build 1001 is 5,782 PRG bytes, 4,294
  relocatable code bytes, and 740 relocation points. The collision-safe
  23-block fixture is on self-bootable `casm_listing_test.d64`, leaving 126
  blocks free. Narrow target and disk builds pass. Live VICE 3.10 verification
  booted Command64 `0.4.1.2663`, printed 15 dots and `CASM FAULT LIST: PASS`,
  and returned through the restored real API to `C64[8]:>` with no recovery.
  VICE remains running. No production CASM source, ABI, version, or output
  changed. Increment 2 implementation and verification are complete, awaiting
  user approval before Increment 3.
- 2026-08-11: User approved Increment 2 and activated Increment 3 capture/VMM
  deterministic failure hardening.
- 2026-08-11: Increment 3 implementation and verification complete, awaiting
  user approval. Expanded `test_casm_flist` from 15 to 23 cases: distinct first
  allocation unavailable/OOM returns, second-allocation ownership retention,
  metadata-write commit point, failed 64-byte stage flush with public-path
  recovery, failed partial final flush with retry, replay-read cursor stability,
  and serializer byte-mirror read failure with real close/delete cleanup. No
  production defect or stop condition surfaced. Review caught one fixture setup
  defect before runtime (`CasmSourceCount=0` would have stopped serializer
  validation before the intended mirror read); corrected with a valid root
  identity and ordinary listing name. The first live run's 15 old cases passed
  and all eight new cases failed because shared `checkSpDiag` compared SP while
  its own JSR return address was still stacked -- a harness checker defect, not
  eight CASM failures. Corrected by discounting that two-byte frame; temporary
  stage instrumentation was removed. Final build 1007 is 7,799 PRG bytes,
  5,785 relocatable code bytes, and 1,003 relocation points in the unchanged
  `$2200` envelope; no-change rebuild stable. The 31-block fixture leaves 118
  disk blocks free. Final VICE 3.10 run printed 23 dots, `CASM FAULT LIST:
  PASS`, and returned to `C64[8]:>` with no recovery. The stream overlay
  received `testing` before dispatch and `pass` afterward. VICE remains running.
  No production source, ABI, version, or valid artifact changed.
- 2026-08-11: User approved Increment 3 and activated Increment 4 listing file
  lifecycle fixes and deterministic retry/cleanup verification.
- 2026-08-11: Increment 4 implementation and verification complete, awaiting
  user approval. Fixed D1 by allowing one caller-driven close attempt from
  either `OPEN` or `CLOSE_FAILED`, using `fileClose` for registered slots and
  direct `DOS_CLOSE_FILE` for `CASM_INVALID_SLOT`. Fixed D2 by recording opened
  listing ownership before registry insertion and routing registration failure
  through retryable close-then-delete compensation while preserving
  `CASM_DIAG_LISTING_CREATE_FAILED`. No BSS, zero page, enum, diagnostic, public
  ABI, or valid output format changed. Ten new deterministic cases bring
  `test_casm_flist` to 33. Review corrected two fixture-only issues before live
  acceptance: registration cases now preserve both A and carry across fake-
  registry cleanup, and retry cases explicitly uninstall the injected fault
  rather than relying on countdown wraparound. Final harness build 1009 is
  9,259 PRG bytes, 6,885 relocatable code bytes, and 1,183 relocation points in
  the unchanged `$2200` envelope; no-change rebuild stable. Production CASM
  build 1261 is 18,572 code bytes, 2,806 relocations, and about 210 bytes of
  BSS-inclusive `$5500` headroom. Whole-linked `test_casm_frame` exceeded its
  test-only `$5000` envelope by 18 bytes; the smallest page-aligned `$5100`
  increase resolves it. `image.d64` has 334 blocks free and the listing disk
  112. Live VICE 3.10 printed 33 dots, `CASM FAULT LIST: PASS`, and returned to
  `C64[8]:>`; the post-run directory contains no `FLI04*.LST` artifacts. The
  overlay received `testing` before dispatch and `pass` afterward. No recovery
  was needed and VICE remains running.
- 2026-08-11: User approved Increment 4 and activated Increment 5 serializer
  transitive failure and cleanup hardening.
- 2026-08-11: Increment 5 implementation and verification complete, awaiting
  user approval. Added eight full-`listingWriteFile` cases for metadata replay,
  include-catalog, source-span, aggregate write, aggregate short-write, final
  close, abort-close, and abort-delete failures; strengthened Increment 3's
  existing serializer mirror-read case with boundary counters and artifact
  safety. Opt-in `CASM_FAULT_BOUNDARY_COUNTERS` in `faultstub.inc` records only
  the WP59 harness's open/write/close/delete/VMM-read calls, leaving every WP58
  fixture's compiled behavior unchanged. Controllable include/source stand-ins
  prove immediate stop after first failure, exact primary preservation, stack
  balance, committed-PRG safety, and retry cleanup. The harness now passes
  41/41 live in VICE 3.10, returns to `C64[8]:>`, and leaves no `FLI05*.LST`
  artifacts; overlay `testing`/`pass` events were relayed and no recovery was
  needed. Final build 1014 is 11,033 PRG bytes, 8,169 relocatable code bytes,
  and 1,428 relocations. Eight cases overflowed `$2200` by 446 measured bytes;
  the smallest page-aligned `$2400` test envelope fits with 53 bytes headroom.
  The 44-block harness leaves 105 listing-disk blocks free. Production CASM is
  unchanged at build 1261 (18,572 code bytes, 2,806 relocations); production
  and harness no-change counters are stable. VICE remains running.
- Increment 6 (filename/included-device validation hardening) and later
  increments: implemented and live-verified in the working session but not
  yet committed, pending user approval. Not included in this record.
