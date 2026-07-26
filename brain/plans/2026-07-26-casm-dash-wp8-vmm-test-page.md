---
feature: casm-dash-wp8-vmm-test-page
created: 2026-07-26
status: draft
---

# Plan: DASH WP8 - VMM Test Page

## Objective

Implement a safe repeatable VMM test that allocates one 4KB page, transfers and
compares deterministic patterns, frees on every post-allocation path, and
degrades safely without an REU.

Prerequisites: approved WP1/WP2 API and approved WP4-WP7 completion.

## Mandatory Activation Review

Re-read final VMM availability semantics, VMM API contracts, allocator rounding,
block transfer behavior, DASH buffers/state, and existing VMM tests. Any
material discrepancy in allocation units, range ownership, API status,
cleanup, buffer size, or no-REU behavior stops work, requires amendment, and
requires renewed approval.

## Decisions to Freeze

- Allocate `$0100` paragraphs (4096 bytes) with X=`$00`, Y=`$01`.
- Test the full 4KB page in sixteen 256-byte blocks per pattern.
- Use one 256-byte transfer buffer and regenerate expected bytes during
  comparison.
- Interpret `$00/$FF` and `$55/$AA` as alternating patterns by absolute byte
  parity; incrementing pattern uses absolute offset modulo 256.
- On free failure, enter `Cleanup failed`, retain ownership identity, disable
  retest, and instruct restart/reset; do not allocate another page.

## Expected Files

- `src/external/dash/dvmm.s`
- `src/external/dash/ddata.s`
- `src/external/dash/dmain.s`
- `src/external/dash/dsys.s`, only for approved capability refresh reuse
- `src/external/dash/dfmt.s`, only for status/offset formatting

## State Contract

Page states:

```text
0 Unavailable
1 Ready
2 Running
3 Passed
4 Failed
5 Cleanup failed
```

Persist in application RAM:

- Allocation-owned flag.
- Returned segment/page and bank identity.
- Pattern index.
- Failure stage: allocation/write/read/compare/free/internal.
- 16-bit failing offset.
- Expected and actual bytes.
- Primary API status only when the API defines a meaningful value.

Save allocation identity immediately after successful `DOS_ALLOC_MEM`; never
trust OS parameter ZP to retain it across calls.

## Test Algorithm

1. Query/consume approved VMM availability. If unavailable, remain disabled.
2. Reject T if an allocation is already owned or cleanup previously failed.
3. Request one 4KB page and set ownership immediately on success.
4. For each of three patterns:
   - For offsets `$0000,$0100,...,$0F00`, generate 256 bytes.
   - Restore VMM identity, offset, and count `$0100` before each write.
   - Write with `DOS_VMM_WRITE`.
   - For the same offsets, clear buffer, read with `DOS_VMM_READ`, regenerate
     expected value per absolute offset, and compare all 256 bytes.
   - On mismatch, save exact offset/expected/actual and enter cleanup.
5. Attempt `DOS_FREE_MEM` exactly once whenever allocation succeeded.
6. Clear ownership only after successful free.
7. Set Passed only after all patterns and free succeed.

The OS block APIs do not enforce allocation bounds. DASH must prove all offsets
and counts remain in `[0,$1000)`.

## API Parameter Contract

- `$66/$67`: byte count `$0100` for each transfer.
- `$68/$69`: allocation segment.
- `$6A/$6B`: current 4KB-relative offset.
- `$6C`: bank.
- X/Y: relocated C64 buffer pointer.
- A: `$5A` write or `$59` read; `$48` allocate; `$49` free.
- Restore every parameter before every API call.

## Failure and Cleanup

- Allocation failure: no ownership, no free, state Failed.
- Write/read failure: save primary stage and attempt free.
- Compare mismatch: save offset/bytes and attempt free.
- Free success after primary failure: retain primary failure display.
- Free failure: state Cleanup failed supersedes only cleanup status while
  preserving primary failure details.
- Internal bounds/state failure follows the same cleanup path.
- No error exits DASH or leaves navigation unusable.
- No direct REU register or MCT access.

## Atomic Increments

1. Confirm the frozen one-buffer/full-page decisions and freeze remaining
   pattern/cleanup-failure details.
2. Implement availability gating and Ready/Unavailable rendering.
3. Implement allocation, immediate identity save, and successful free.
4. Implement bounded offset/count helper.
5. Implement pattern generation.
6. Implement full-page writes.
7. Implement full-page reads/comparison and mismatch capture.
8. Implement unified cleanup preserving primary errors.
9. Wire T only on VMM page and redraw result.
10. Run repeated no-leak and no-REU verification.

## Verification

- Static loop proof: 16 blocks x 256 bytes = 4096 bytes, last transfer
  `$0F00-$0FFF`; no offset reaches `$1000`.
- Pattern vectors verified at block boundaries and offsets 0/1/255/256/4095.
- Allocation identity survives every OS call through app storage.
- Every post-allocation branch reaches one cleanup owner.
- Exactly one free attempt per owned allocation.
- Passed state implies free succeeded and ownership is clear.
- Cleanup failed disables retest.
- Existing `test_vmm` regression passes.
- With REU, user runs at least three tests and confirms free-page count returns
  to baseline each time.
- Injected/read/write/compare failures, where safely testable, report correct
  stage and still free.
- Without REU, T performs no allocation/transfer and navigation/Q remain safe.
- Same behavior at `$3400/$4000/$5000`.

## Stop Conditions

- VMM availability is not truthful.
- Allocation size/identity contract differs.
- Transfer helper can exceed the allocation.
- Any path can leak or double-free.
- API failures lack enough information for the planned UI and no honest stage-
  only display is approved.
- Cleanup failure permits another allocation.
- Testing would require direct MCT/REU access.

## Completion Gate

Present bounds proof, pattern vectors, ownership/control-flow audit, existing
VMM regression, repeated free-page evidence, no-REU behavior, and multi-address
results. Ask whether WP8 is complete before WP9 activation.
