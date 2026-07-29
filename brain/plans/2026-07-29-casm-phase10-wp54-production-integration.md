---
feature: casm-phase10-wp54-production-integration
created: 2026-07-29
status: approved-blocked
taskwarrior: f4b598fd-bab1-4394-9415-c71e3ea1cfa5
depends-on: aa57f461-36a9-455c-966f-ac484ec57b41
---

# Plan: CASM Phase 10 WP54 - Production Integration

## Status

Approved but blocked by WP53 completion. Completion target: CASM `0.1.55`.

## Objective

Activate `/M` and `/L` while preserving passes, PRG/R6 bytes, include replay,
provenance, diagnostics, cleanup, and no-option behavior.

## Initialization and CLI

Call allocation-free `listingStateInit` after source/file/CLI state init. Remove
the `/M`/`/L` NOT IMPLEMENTED block. Derive PRG name, then derive listing name
only for `/L`, before source/resource work.

## Pass Sequence

Pass 1 is unchanged and allocates/captures no listing state.

Pass 2 preparation order:

1. `sourceRewind`
2. `includeReplayReset`
3. `/L` only: `listingCaptureInit` (two stores and source capture)
4. `lexerInit`
5. `fileCreateOutput`
6. `relocInit`
7. `emitInit`, EMIT mode, `casmRunPass`

Completion order:

1. Include replay final check
2. Pass agreement
3. `/L`: listing capture finalize
4. Emit finalize
5. Relocation finalize
6. Source close
7. PRG commit
8. `/L`: listing serialization/commit
9. `/M`: clear stale location and print map
10. Existing `INPUT VALIDATED` success line
11. Successful central cleanup/exit

Listing allocation therefore fails before partial PRG creation; map prints only
after every requested file is committed.

## Option Matrix

- No options: PRG then success line.
- `/M`: PRG, map, success.
- `/L`: PRG, listing, success.
- `/M /L`: PRG, listing, map, success.
- `/S` changes only existing static/R6 behavior.

## Unified Fatal Routing

Add `artifactsAbort`: preserve primary, call listing abort then output abort,
return primary/first cleanup failure, then `exitFatal`. Committed flags retain
valid artifacts; uncommitted artifacts close/delete; all live resources remain
registered for central cleanup. Replace direct `outputAbort` fatal routing.

Failures before PRG create leave no artifacts; Pass 2/capture failures delete
partial PRG; PRG commit failures delete PRG; listing failures retain committed
PRG and suppress map/success; map failures retain committed PRG/listing and
suppress success.

## Integration Harness

Add `test_casm_phase10` with stand-in modules and bounded event log. Verify exact
call order for all option/static/root/include combinations and inject failures at
every derivation/init/pass/rewind/allocation/create/finalize/check/close/commit/
listing/map stage. Assert calls stop correctly, artifacts/resources, map/success
suppression, primary diagnostics, `/M` no listing stores, `/L` exactly two, and
Pass 1 capture disabled.

## Production Fixtures

Exercise static/R6, forward/back symbols, map boundaries, blank/comment/
continuations, roots, nested/repeated includes, output names/devices, and all
option combinations. For each source require identical PRG hashes and R6 tables
with no options, `/M`, `/L`, and both.

## Envelope

Start from WP53, choose smallest aligned increase, stop above preapproved
`$5B00`, measure harness independently, and add no zero page.

## Expected Files

Modify `casm.s`, optionally common/file I/O ABIs already planned, and CMake; add
`tests/src/casm_phase10/`, complete fixtures/artifacts, user documentation,
test/CASM DOX, tasks, knowledge, memory, changelog, and walkthrough.

## Atomic Increments

1. Harness and expected sequences.
2. Listing init/CLI activation.
3. Conditional post-rewind allocation.
4. Capture completion and commit/listing/map/success order.
5. Unified abort.
6. Production option/artifact matrix.
7. Envelope/regressions/review/walkthrough.
8. Approval, stable `0.1.55`, synchronized closure.

## Verification

Build via CMake at both origins; build all Phase 10 and prior CASM tests/images;
verify exact event/failure matrix; compare PRG/R6 hashes; prove no Pass 2 or
serialization source I/O, one output handle, ordering/retention, carry/stack/
scratch/cleanup, stable rebuild, diff check, and DOX.

## Stop Conditions

Listing before rewind or after PRG create, inability to commit PRG before
listing, simultaneous outputs, unsafe committed artifacts, `/M` listing
resources, changed success text beyond order, pass/replay/PRG/R6 changes,
envelope >`$5B00`, zero-page growth, or premature WP55 scope.

## Completion Gate

Requires WP53 completion, harness/production matrix, identity proof, measured
envelopes, review, user walkthrough/approval, stable `0.1.55`, and synchronized
records. Does not activate WP55.

## Progress

- 2026-07-29: User approved this plan. WP54 remains blocked by WP53; no
  integration implementation is authorized.
