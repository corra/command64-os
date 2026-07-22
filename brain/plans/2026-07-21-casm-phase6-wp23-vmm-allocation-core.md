---
feature: casm-phase6-wp23-vmm-allocation-core
created: 2026-07-21
status: complete
---

# Plan: CASM Phase 6A WP23 - VMM Allocation Core

## Objective

WP23 creates `vmm_store.s` and wires real `DOS_ALLOC_MEM`/`DOS_FREE_MEM` calls
behind the existing `resources.s` registry, replacing `cleanupVmmStub`'s
current no-op-on-REU behavior with a real free. It owns the two decisions
WP22 deliberately deferred: the MAIN envelope size Phase 6A needs (measured
against a real link, not estimated in advance) and the literal `CASM_DIAG_*`
hex values for the four VMM failure categories WP22 identified. It
implements no windowed read/write transfer (WP24) and no fixtures beyond
what static build/link verification requires (WP25 owns the fixture matrix).

Taskwarrior: `8782e75d-d935-4e15-bf3c-d0488a1533a8`.

Prerequisite: WP22 must complete with explicit user approval, expected to
advance CASM to `0.1.24`. WP23's Taskwarrior UUID exists, is pending, and is
blocked on WP22. Approval of this plan is required before activation or
source edits, in addition to WP22's own completion.

## Reconciliation Findings (inherited from WP22)

- `CasmVmmRegistry`'s existing 3-byte record (`CASM_VMM_REC_FLAG/SEGHI/BANK`)
  is confirmed sufficient: `vmmFree`'s real input is exactly `VmmSegHi`
  (page index) and `VmmBank`, both already stored per slot. WP23 must not
  grow the record without a demonstrated need.
- A single CASM VMM allocation is capped at 65536 bytes (16 pages) so a fixed
  `SegHi:Bank` pair plus a 16-bit `Off` cursor addresses the whole
  allocation. `vmm_store.s` must reject (at the CASM level, before ever
  calling `DOS_ALLOC_MEM`) any requested size above that cap.
- `DOS_ALLOC_MEM` takes a paragraph count (16-byte units) and rounds up to
  whole 4KB pages; requesting exactly the bytes needed, not a padded round
  number, minimizes rounding waste within the 8-slot/512KB registry ceiling.
- `VMM_ERR_INVALID` from an allocation WP23 itself sized (never
  zero-paragraph) means VMM-unavailable, not malformed input.
- `VMM_ERR_NOMEM` means allocation exhaustion, distinct from VMM-unavailable.
- Zero-page: no growth authorized. `$7C-$7F` (`CasmVmmSegHi`/`CasmVmmBank`/
  `CasmVmmOffLo`/`CasmVmmOffHi`) is available for staging OS-call arguments;
  WP23 does not need `OffLo`/`OffHi` for allocation/free (only WP24's
  transfers use them), but must not claim them for an unrelated purpose.
- The `$2A00` MAIN envelope has 243 bytes headroom before any Phase 6A code
  exists. Real `DOS_ALLOC_MEM`/`DOS_FREE_MEM` wiring plus registry-record
  translation is expected to exceed that; WP23 measures the actual overflow
  from a real build and proposes a specific new size to the user, following
  the WP13 ($2000->$2800) and WP19 ($2800->$2A00) precedent of deciding from
  a measured link attempt rather than a pre-estimated figure.

## Inherited Contract

- Phase 0C.4 VMM record model and failure contract, frozen in
  `brain/KNOWLEDGE.md` by WP22.
- Resource ownership is registered before use and released through
  `resourcesCleanup`; WP23 introduces no new cleanup owner, only a real
  implementation behind the existing `resourceRegisterVmm`/`resourceReleaseVmm`
  call sites.
- `cleanupVmmStub` is replaced, not duplicated; there is exactly one VMM
  cleanup path after WP23.

## Scope

Included:

- create `vmm_store.s` with `vmmStoreAlloc` and `vmmStoreFree`;
- wire `vmmStoreAlloc` to `DOS_ALLOC_MEM` (function `$48`) and register the
  result through the existing `resourceRegisterVmm`;
- wire `vmmStoreFree` to `DOS_FREE_MEM` (function `$49`) using a registry
  slot's stored `SegHi`/`Bank`, and call it from the real
  `resourcesCleanup` path in place of `cleanupVmmStub`;
- reject (before any OS call) an allocation request whose size exceeds the
  65536-byte single-allocation cap;
- reserve and raise `CASM_DIAG_*` values `$28-$2B` for VMM-unavailable,
  allocation-exhausted, free-failed, and (reserved only, raised by WP24)
  transfer-failed;
- measure a real link at both relocation bases and propose the exact new
  MAIN size to the user;
- static verification (object sizes, segments, imports, relocation count,
  headroom) with no runtime fixture.

Excluded:

- `DOS_VMM_READ`/`DOS_VMM_WRITE` windowed transfer wrappers (WP24);
- any symbol, hash, or Pass 1/Pass 2 code (Phase 6B);
- runtime fixtures exercising allocation/free/exhaustion behavior on real
  hardware/VICE (WP25 owns the fixture matrix WP22 defined; WP23 may add the
  fixture *source* only if a later amendment finds it cannot be deferred
  without an untestable interim state — not expected).

## Expected Files

| File | Action |
| --- | --- |
| `src/external/casm/vmm_store.s` | create: `vmmStoreAlloc`, `vmmStoreFree` |
| `src/external/casm/resources.s` | replace `cleanupVmmStub` with a real `vmmStoreFree` call |
| `src/external/casm/common.inc` | reserve `CASM_DIAG_VMM_*` `$28-$2B`; add the 65536-byte cap constant |
| `src/external/casm/casm.s` | stage increment only at completion |
| `src/external/casm/BUILD_CASM` | build-managed increment |
| `CMakeLists.txt` | propose and apply the measured MAIN size change |
| `brain/plans/2026-07-21-casm-phase6-wp23-vmm-allocation-core.md` | activate/update progress |
| `brain/KNOWLEDGE.md`, `brain/MEMORY.md`, `brain/task.md` | synchronize implementation evidence |
| `wiki/tasks/casm.md`, `CHANGELOG.md` | synchronize status and functional record |
| `brain/walkthroughs/2026-07-21-casm-phase6-wp23-vmm-allocation-core.md` | verification walkthrough |

No parser, emitter, lexer, opcode, expr, state, or fixture file is expected
to change. Discovery of such a need stops WP23 for an amended plan.

## ABI and Constants (proposed; final values confirmed during implementation)

```text
CASM_VMM_ALLOC_MAX_BYTES = 65536   ; single-allocation addressing cap
```

Diagnostics, contiguous with Phase 5's `$27` ceiling:

```text
CASM_DIAG_VMM_UNAVAILABLE     = $28   ; VMM_ERR_INVALID: no REU / not initialized
CASM_DIAG_VMM_ALLOC_FAILED    = $29   ; VMM_ERR_NOMEM: allocation exhausted
CASM_DIAG_VMM_FREE_FAILED     = $2A   ; DOS_FREE_MEM rejected the stored handle
CASM_DIAG_VMM_TRANSFER_FAILED = $2B   ; reserved for WP24; not raised by WP23
CASM_DIAG_PHASE6A_LAST        = $2B
```

Assert `$28 = CASM_DIAG_PHASE5_LAST + 1`, contiguous values through `$2B`,
and `CASM_DIAG_PHASE6A_LAST = $2B`, matching the existing per-phase
contiguous-range assertion pattern.

`vmmStoreAlloc`:

- inputs: `X`/`Y` = requested byte count (Lo/Hi);
- outputs: C clear and `X` = registry slot on success; C set and `A` =
  `CASM_DIAG_VMM_ALLOC_TOO_LARGE` (local, pre-OS-call), `CASM_DIAG_VMM_UNAVAILABLE`,
  `CASM_DIAG_VMM_ALLOC_FAILED`, or `CASM_DIAG_REGISTRY_FULL` on failure;
- clobbers: A, X, Y and OS API-defined volatile registers.

`vmmStoreFree`:

- inputs: `X` = registry slot;
- outputs: C clear on success (including an already-free slot, matching
  `resourceReleaseHandle`'s idempotent precedent); C set and `A` =
  `CASM_DIAG_VMM_FREE_FAILED` on a rejected `DOS_FREE_MEM` call;
- clobbers: A, X, Y and OS API-defined volatile registers.

Exact register/flag/scratch contracts, the byte-count-to-paragraph
conversion, and the final MAIN size are confirmed and finalized during
implementation per the CASM local `AGENTS.md` requirement that every
work-package plan states these before implementation, not before approval of
this outline.

## Atomic Increments

1. After plan approval and WP22 completion, start WP23 in Taskwarrior and
   mark it active in wiki and brain. Capture the clean `0.1.24` baseline.
2. Add `CASM_VMM_ALLOC_MAX_BYTES` and the four `$28-$2B` diagnostics with
   assertions to `common.inc`.
3. Add `vmm_store.s` with `vmmStoreAlloc`/`vmmStoreFree`; wire the CASM-side
   size cap check ahead of any OS call.
4. Replace `cleanupVmmStub` with a real `vmmStoreFree` call in
   `resources.s`; verify `resourcesCleanup`'s retry-on-failure behavior
   still holds for a rejected free.
5. Run `cmake -S . -B build`, then attempt to build CASM at both bases.
   Measure the actual MAIN overflow and propose a specific new size to the
   user before proceeding further.
6. After the size is approved, rebuild at both bases; inspect `vmm_store.o`,
   linked segment sizes, relocation count, and MAIN headroom.
7. Static-verify: no unauthorized zero-page/BSS growth beyond what the
   registry already reserved, correct diagnostic values, and no accidental
   symbol/pass/relocation code.
8. Update records and walkthrough. Dry-run the next stage increment, verify
   exactly one build-number increment and no-change stability, compare
   artifacts, then restore the pre-dry-run baseline before requesting
   completion approval.
9. After explicit completion approval, apply the verified increment,
   rebuild twice, complete WP23, and leave WP24 pending separate approval.

## Failure and Cleanup

A failed `DOS_ALLOC_MEM` registers no ownership. A failed `DOS_FREE_MEM`
leaves the registry slot owned so a later cleanup pass can retry it,
matching `cleanupFileRecord`'s existing retry-on-failure precedent — WP23
must not silently drop ownership on a free failure. No other resource type
is affected.

## Verification

- ca65/ld65 builds both relocation bases without warning/error.
- `vmm_store.o` contains only the expected CODE, no unauthorized RODATA/
  DATA/ZEROPAGE.
- `$28-$2B` diagnostics are asserted contiguous with Phase 5's range.
- The CASM-level size-cap check is exercised statically (code path exists
  and is reachable before any OS call).
- MAIN headroom is measured and recorded at the new approved size.
- The completion dry run increments the build number exactly once, remains
  stable on no-change rebuild, and is restored before approval.
- `git diff --check` passes and changed paths match this plan.

## Stop and Completion Gates

Stop if WP22 is not complete and approved, if the registry record needs
growth beyond what WP22 confirmed, if zero-page growth becomes necessary, if
the measured MAIN overflow is large enough to suggest a design problem
rather than ordinary code growth, or if `DOS_ALLOC_MEM`/`DOS_FREE_MEM`
behave differently from WP22's `vmm.asm` research at implementation time.
WP23 completes only after all evidence is recorded, the user explicitly
approves the walkthrough and the proposed MAIN size, and the verified
post-approval increment passes. Completion does not activate WP24
automatically.

## Documentation and DOX

Update this plan, `brain/KNOWLEDGE.md`, `brain/MEMORY.md`, `brain/task.md`,
`wiki/tasks/casm.md`, `CHANGELOG.md`, Taskwarrior, and the WP23 walkthrough.
Re-read the root and `src`/`external`/`casm` DOX chain after source edits.
`AGENTS.md` changes only if a durable local contract or child index changes.

## Reserved Downstream Plan Slugs

- WP24: `2026-07-21-casm-phase6-wp24-windowed-transfer-and-replay.md`
- WP25: `2026-07-21-casm-phase6-wp25-verification-closeout.md`

## Progress

- 2026-07-21: Drafted by WP22; WP23 remains inactive pending WP22's own
  completion approval and separate approval of this plan.
- 2026-07-22: User approved this plan as drafted; the fixture question was
  resolved as static verification only. Activated on `feature/casm-phase6-wp23`
  from `feature/casm-phase6-wp22` at `d0878d6`, baseline `0.1.24` build 1095.
  Implemented `vmm_store.s` and the `resources.s`/`common.inc` wiring;
  resolved two ABI questions with the user (dropped the unreachable
  `CASM_DIAG_VMM_ALLOC_TOO_LARGE` path in favor of carry-safe rounding; kept
  the zero-byte-count local rejection). Measured MAIN usage
  (10,647/10,752 bytes, 105 bytes free) and found no size change was needed,
  unlike the WP13/WP19 precedent; user confirmed proceeding on that basis.
  User ran a VICE sanity check, confirmed clean assemble/exit, and approved
  the walkthrough and completion. Final `0.1.25` build 1097 matched the
  verified dry run exactly; no-change rebuild stable; both images pass. WP23
  is complete. Walkthrough:
  `brain/walkthroughs/2026-07-21-casm-phase6-wp23-vmm-allocation-core.md`.
