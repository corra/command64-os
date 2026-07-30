---
feature: casm-dash-wp8-vmm-test-page
created: 2026-07-26
updated: 2026-07-30
status: source-complete, hardware-verification-pending
---

# Plan: DASH WP8 - VMM Test Page

## Activation Review & Context

- **Activation Branch**: `feature/casm-dash-wp8-vmm-test-page`
- **Activation SHA**: `f02c294890d2e0a78154114fbe27e3e98975f5a5` (branched from
  `casm-dash` immediately after merging WP7, `368bac3`, into it).
- **Prerequisites confirmed**: WP1 API contract, WP2/WP3 services, WP4
  relocatable skeleton, WP5 panel primitives, WP6 system page, WP7
  applications page are all present on `casm-dash` at activation.

### Re-reads performed

- `include/ca65/vmm.inc` / `include/vmm.inc`: `VmmSegLo=$68`, `VmmSegHi=$69`,
  `VmmOffLo=$6A`, `VmmOffHi=$6B`, `VmmBank=$6C`.
- `include/ca65/command64.inc`: `HexValLo=$66`, `HexValHi=$67`,
  `DOS_ALLOC_MEM=$48`, `DOS_FREE_MEM=$49`, `DOS_VMM_READ=$59`,
  `DOS_VMM_WRITE=$5A`.
- `src/command64/api.asm` (`ahAllocMem`/`ahFreeMem`/`ahVmmRead`/`ahVmmWrite`),
  `src/command64/vmm.asm`, `tests/src/vmm/vmm.s` (existing `test_vmm`
  regression, already-proven alloc/write/read/free call shape).
- Current DASH sources: `dmain.s` (event loop/dispatch), `ddata.s` (shared
  state/tables), `dsys.s` (system page + `QUERYSYSTEMINFO` helper, reused
  here for capability refresh), `dfmt.s` (formatters/`PETTOSCREEN`), `dscr.s`
  (bounded screen primitives), `dapp.s` (applications page, current style
  reference), `AGENTS.md` (dual-assembler subset rules, ZP `$70-$8F`
  allocation, uppercase-only, provenance workflow).

### Discrepancies found and resolved (user-confirmed 2026-07-30)

1. **WP7 not yet merged into `casm-dash`.** Resolved: merged
   `feature/casm-dash-wp7-applications-page` into `casm-dash` first (merge
   commit `f02c294`), then branched WP8 from `casm-dash`.
2. **`dvmm.s` was a stale WP4-era stub** using unbounded `PRINTAT` and raw
   `$72`/`$77` cursor writes, not the WP5/WP6/WP7 bounded
   `SCREENSETCURSOR`/`SCREENPUTSTRING`/`SCREENPUTCHAR` primitives. Resolved:
   full rewrite to the bounded style, consistent with `dsys.s`/`dapp.s`.
3. **Hardware verification scope.** The plan's Verification/Completion Gate
   requires real REU hardware evidence (3x test runs, free-page-count
   baseline, no-REU behavior, multi-address checks). Per
   `[[feedback-vice-testing]]`, this implementation pass does not drive VICE
   to fake or substitute for that evidence. Scope for this pass: implement
   `dvmm.s`/`ddata.s`/`dmain.s`, keep the ca65 cross-check (`dash_ref`)
   buildable, and leave native CASM assembly, manifest regeneration
   (`build_dash_manifest.py`), and the actual multi-run hardware
   verification to the user/Companion Agent before the Completion Gate is
   declared satisfied.

### Frozen implementation details (not previously spelled out in the plan)

- `VmmSegLo` ($68) is hardware-forced to `0` by `vmmAlloc`
  (`src/command64/vmm.asm`); the true allocation identity is the 2-byte pair
  `(VmmSegHi, VmmBank)`, returned as `(X, Y)` from `DOS_ALLOC_MEM`. DASH
  stores only those two bytes as identity; `VmmSegLo` is written as a literal
  `0` before every transfer, never read back from the allocation result.
- Because all 16 transfer blocks are 256-byte-aligned (`$0000, $0100, ...,
  $0F00`), `VmmOffLo` is always `0` and `VmmOffHi` is exactly the block index
  (`0..15`). This also means the absolute-offset-dependent pattern rules
  (parity, mod 256) collapse to being functions of the local 0-255 index
  within a block — no separate absolute-offset arithmetic is needed to
  generate or verify pattern bytes, only to report a failing offset
  (`FailOffHi = blockIndex`, `FailOffLo = local index`).
- Test trigger key: `T`/`t` (shifted/unshifted, matching the existing
  `R`/`Q` case-insensitive handling in `dmain.s`), wired in `EVENTLOOP` but
  gated to `CURRPAGE == 2` (VMM page) — pressing `T` on another page is
  ignored, per Atomic Increment 9 ("Wire T only on VMM page").
- Page state variable and per-test detail fields live in application RAM
  (`ddata.s`), not zero page: `$70-$8F` is already fully allocated per
  `AGENTS.md`.

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
   pattern/cleanup-failure details. **Done** (see Activation Review above).
2. Implement availability gating and Ready/Unavailable rendering. **Done**
   (`DVMMREFRESHCAP`/`DVMMRENDERSTATUS`/`DVMMRENDERDETAIL` in `dvmm.s`).
3. Implement allocation, immediate identity save, and successful free.
   **Done** (`DVMMRUNTEST`/`DVMMRT_ALLOCOK`/`DVMMRT_CLEANUP` in `dvmm.s`).
4. Implement bounded offset/count helper. **Done** (`DVMMCHECKBLOCK`;
   unreachable in correct operation given the static 16-block loop, kept as
   defense-in-depth per the plan's explicit requirement).
5. Implement pattern generation. **Done** (`DVMMGENBYTE`/`DVMMFILLPATTERN`).
6. Implement full-page writes. **Done** (`DVMMRT_WOK`/`DVMMSETIDENTITY` in
   `dvmm.s`).
7. Implement full-page reads/comparison and mismatch capture. **Done**
   (`DVMMRT_READPHASE`/`DVMMCOMPAREBLOCK`/`DVMMCLEARBUFFER`).
8. Implement unified cleanup preserving primary errors. **Done**
   (`DVMMRT_CLEANUP`/`DVMMRT_FREEFAIL`).
9. Wire T only on VMM page and redraw result. **Done** (`TRYRUNVMMTEST` in
   `dmain.s`, gated on `CURRPAGE == 2`).
10. Run repeated no-leak and no-REU verification. **Not started** -- requires
    real REU hardware/VICE evidence; deferred to the user/Companion Agent
    per the Activation Review's discrepancy #3. The ca65 cross-check
    (`dash_ref`) and the full `command64_casm_utils_d64`/`image_d64` targets
    build clean as of this pass (source-level verification only, no runtime
    evidence yet).

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
- Same behavior at `$3800/$5000/$9000`.

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

### 2026-07-30 close-out decision

Source implementation is complete and builds clean (`dash_ref` ca65 cross-
check, `command64_casm_utils_d64`, `image_d64` all pass, including the
project's own uppercase-source and branch-range checks). The Completion
Gate's hardware-dependent items (repeated free-page evidence, no-REU
behavior, multi-address results) were **not** executed this pass -- offered
as a live-VICE option and explicitly declined by the user, who chose to
close WP8 out at source-complete instead. This plan is left in
`source-complete, hardware-verification-pending` status rather than
`complete`; whoever picks up WP9 (or resumes WP8) should treat the hardware
Completion Gate items above as still open, not satisfied by this pass.
