---
feature: casm-phase6-wp24-windowed-transfer-and-replay
created: 2026-07-22
status: planned
---

# Plan: CASM Phase 6A WP24 - Windowed Transfer and Replay

## Objective

WP24 implements bounded `DOS_VMM_READ`/`DOS_VMM_WRITE` windowed transfer
wrappers over a registered VMM allocation, plus a deterministic replay
routine (write a pattern, discard the RAM copy, read it back, compare) —
the literal wording of Phase 6A's completion gate ("bounded VMM records are
written, read, and replayed"). It implements no symbol, hash, or Pass 1/Pass
2 code (Phase 6B) and no fixture *matrix* (WP25 owns building and running
the nine-case matrix WP22 defined; WP24 owns only the production code that
matrix will exercise).

Taskwarrior: `228daccc-f389-48cf-bd52-9f1ac610234a`.

Prerequisite: WP23 is complete and approved (CASM `0.1.25` build 1097,
commit `42968f0`). WP24's Taskwarrior UUID is pending, unblocked. Approval
of this plan is required before activation or source edits, per the CASM
`AGENTS.md` gate.

## Reconciliation Findings

Reviewing the Phase 0C.4 contract (frozen by WP22) and WP23's actual
implementation together surfaced one real gap and two ABI details that were
implicit rather than written down. None of these were WP23's to solve —
WP23's scope explicitly excluded windowed transfer — but WP24 cannot be
planned honestly without naming them:

- **The frozen contract requires per-allocation bounds-checking that no
  current field can perform.** WP22's Phase 0C.4 freeze states: "CASM's own
  windowed transfer wrapper (WP24) must independently track each
  allocation's granted byte size and refuse any request whose `offset +
  count` would exceed it" (`brain/plans/2026-07-21-casm-phase6-wp22-prerequisite-reconciliation.md`,
  OS VMM Primitive Contract section). But `CasmVmmRegistry`'s 3-byte record
  (`flag`/`SegHi`/`Bank`) — confirmed sufficient by WP22 and left unchanged
  by WP23 specifically for allocation/free identity — has no field to read
  a granted size back from. WP23's "must not grow the record without a
  demonstrated need" was scoped to its own allocation/free ABI, which
  genuinely needed no growth; WP24 has the demonstrated need the freeze
  anticipated but did not resolve. **Proposed resolution**: grow
  `CASM_VMM_REC_SIZE` from 3 to 4 bytes, adding `CASM_VMM_REC_PAGES` — the
  granted 4KB-page count (1-16, one byte), computed identically to
  `vmmAlloc`'s own paragraph-to-page rounding
  (`PageCount = (Paragraphs + 255) >> 8`), which `vmmStoreAlloc` already
  derives locally before calling `DOS_ALLOC_MEM`. `resourceRegisterVmm`
  gains a third input (the page count) and remains the registry's sole
  writer — `vmm_store.s` still never writes `CasmVmmRegistry` directly,
  preserving the single-writer discipline WP23 established. Bonus: a 4-byte
  record makes the existing slot-to-byte-offset computation
  (`slot*3` = `ASL` + `ADC`) a plain `slot*4` (two `ASL`s, no add) in both
  `resources.s` and `vmm_store.s`.
- **`DOS_VMM_READ`/`DOS_VMM_WRITE` take their Seg/Off/Bank/count arguments
  through fixed OS zero-page cells, not registers.** Unlike
  `DOS_ALLOC_MEM`/`DOS_FREE_MEM` (pure `A`/`X`/`Y`), `ahVmmRead`/`ahVmmWrite`
  (`src/command64/api.asm`) read `VmmSegLo/Hi` (`$68`/`$69`), `VmmOffLo/Hi`
  (`$6A`/`$6B`), `VmmBank` (`$6C`), and `HexValLo/Hi` (`$66`/`$67`) directly;
  only the C64-side buffer pointer travels in `X`/`Y`. This is not
  undocumented guesswork: `src/external/edlin/buffer.s` already does exactly
  this (`sta VmmSegLo` / `sta VmmOffLo` / ... before `jsr OS_API`) as a
  working, shipped precedent. WP24 follows the same pattern, staging through
  CASM's own `$7C-$7F` first (`CasmVmmSegHi`/`CasmVmmBank`/`CasmVmmOffLo`/
  `CasmVmmOffHi`, reserved by WP22 "for staging OS-call arguments" and
  explicitly left unused by WP23), then copying into the OS cells
  immediately before each `DOS_VMM_READ`/`DOS_VMM_WRITE` call. `VmmSegLo`
  ($68) is always written as 0, matching `vmmAlloc`'s own convention.
- **No existing buffer is safe to reuse for VMM transfer staging.**
  `CasmIoBuffer` (256 bytes, `fileio.s`) is documented as staying reserved
  for source input; reusing it for VMM transfers would silently corrupt an
  in-progress source read. WP24 needs its own dedicated staging buffer,
  sized against a real link and fixture need during implementation rather
  than fixed in advance (user decision), matching the MAIN-size decision's
  own precedent.

## Inherited Contract

- Phase 0C.4 VMM record model and failure contract, frozen in
  `brain/KNOWLEDGE.md` by WP22 and implemented by WP23.
- A CASM-side bounds violation (`offset + count` beyond the allocation's
  granted size) is a CASM-internal fatal error, never forwarded to the OS
  (WP22's Failure Contract).
- Resource ownership is registered before use and released through
  `resourcesCleanup`; WP24 introduces no new cleanup owner and calls no new
  OS-level acquire/release primitive (transfer is not acquisition).
- `vmmStoreAlloc`/`vmmStoreFree` (WP23) are stable ABI; WP24 extends
  `resourceRegisterVmm`'s input (see above) but does not change
  `vmmStoreAlloc`/`vmmStoreFree`'s own documented inputs/outputs.

## Scope

Included:

- grow `CASM_VMM_REC_SIZE` to 4 bytes (`CASM_VMM_REC_PAGES` added); update
  `resourceRegisterVmm`'s input and both slot-offset computations
  (`resources.s`, `vmm_store.s`) to `slot*4`;
- `vmmStoreAlloc` computes and passes the granted page count to
  `resourceRegisterVmm` (no change to `vmmStoreAlloc`'s own external ABI);
- a bounded base-RAM staging buffer, sized against a real link and fixture
  need during implementation rather than fixed in advance;
- `vmmWindowRead`/`vmmWindowWrite` (names proposed, confirmed during
  implementation): given a registry slot, a 16-bit offset, and a byte count,
  bounds-check `offset + count` against the slot's `SegHi`/`Bank`/`Pages`
  before ever writing the OS's `Vmm*`/`HexVal*` cells or issuing
  `DOS_VMM_READ`/`DOS_VMM_WRITE`;
- a deterministic replay routine usable by WP25's fixtures: write a pattern
  through `vmmWindowWrite`, discard/zero the RAM staging copy, read it back
  through `vmmWindowRead`, leave both buffers available for the caller to
  compare;
- raise `CASM_DIAG_VMM_TRANSFER_FAILED` (`$2B`, already reserved by WP23)
  for both a rejected `DOS_VMM_READ`/`DOS_VMM_WRITE` call and a CASM-side
  bounds violation — one shared value for both, per user decision, matching
  `vmmStoreAlloc`'s own precedent of collapsing a local rejection and an
  OS-level failure into one diagnostic;
- measure a real link at both relocation bases and propose the exact new
  MAIN size to the user (105 bytes of WP23 headroom cannot plausibly absorb
  a new staging buffer plus transfer code; treated as expected, not a design
  problem);
- static verification (object sizes, segments, imports, relocation count,
  headroom), plus whatever minimal runtime check is needed to confirm the
  registry-growth migration didn't regress WP23's now-live cleanup path
  (exact form confirmed during implementation, matching WP23's own
  after-the-fact manual-check precedent).

Excluded:

- any symbol, hash, or Pass 1/Pass 2 code (Phase 6B);
- the WP25 fixture matrix itself (`vmmalloc*`, `vmmwrite1`/`vmmread1`,
  `vmmreplay1`, `vmmoffset1`, `vmmbounds1`, `vmmfree1`, `vmmnoreu`) — WP24
  provides the code under test, WP25 owns building and running it;
- any change to `vmmStoreAlloc`/`vmmStoreFree`'s documented external ABI.

## Open Questions (resolved by the user)

1. **Staging buffer size.** Deferred to implementation-time measurement,
   matching the MAIN-size decision's own precedent (WP13/WP19/WP23): WP24
   sizes the buffer against a real link and fixture need rather than
   guessing a number now.
2. **Diagnostic reuse for the local bounds-violation.** Resolved: a
   CASM-side `offset + count` rejection shares `CASM_DIAG_VMM_TRANSFER_FAILED`
   ($2B) with a genuine `DOS_VMM_READ`/`DOS_VMM_WRITE` OS-level rejection.
   Phase 6A's diagnostic count stays at four, matching WP22's freeze and
   `vmmStoreAlloc`'s own precedent of collapsing a local rejection and an
   OS-level failure into one value (`CASM_DIAG_VMM_ALLOC_FAILED`).

## Expected Files

| File | Action |
| --- | --- |
| `src/external/casm/vmm_store.s` | add `vmmWindowRead`, `vmmWindowWrite`, replay routine; grow the page-count plumbing into `vmmStoreAlloc` |
| `src/external/casm/resources.s` | grow `CASM_VMM_REC_SIZE`/`resourceRegisterVmm`'s input; update slot-offset math |
| `src/external/casm/common.inc` | add `CASM_VMM_REC_PAGES` offset, staging buffer size constant, updated registry-size assert |
| `src/external/casm/casm.s` | stage increment only at completion |
| `src/external/casm/BUILD_CASM` | build-managed increment |
| `CMakeLists.txt` | propose and apply the measured MAIN size change |
| `brain/plans/2026-07-21-casm-phase6-wp24-windowed-transfer-and-replay.md` | activate/update progress |
| `brain/KNOWLEDGE.md`, `brain/MEMORY.md`, `brain/task.md` | synchronize implementation evidence |
| `wiki/tasks/casm.md`, `CHANGELOG.md` | synchronize status and functional record |
| `brain/walkthroughs/2026-07-21-casm-phase6-wp24-windowed-transfer-and-replay.md` | verification walkthrough |

No parser, emitter, lexer, opcode, expr, state, or fixture file is expected
to change. Discovery of such a need stops WP24 for an amended plan.

## ABI and Storage (proposed; final values confirmed during implementation)

```text
CASM_VMM_REC_PAGES = 3   ; new registry record offset (flag=0, SegHi=1, Bank=2, Pages=3)
CASM_VMM_REC_SIZE  = 4   ; grown from 3
```

`resourceRegisterVmm` (revised):

- inputs: `X` = segment high byte, `Y` = REU bank, page count staged through
  a zero-page byte (exact cell confirmed during implementation -- likely
  reusing `CasmValue0Hi`-adjacent scratch, not `$7C-$7F`, which stays
  reserved for `vmmWindowRead`/`Write`'s own OS-call staging);
- outputs/clobbers: unchanged from WP23.

`vmmWindowRead`/`vmmWindowWrite`:

- inputs: `X` = registry slot, 16-bit offset and byte count staged in
  zero-page (exact cells confirmed during implementation), buffer pointer;
- outputs: C clear on success; C set and `A` = `CASM_DIAG_VMM_TRANSFER_FAILED`
  on a rejected OS call or a local bounds violation (one shared value for
  both);
- clobbers: A, X, Y and OS API-defined volatile registers.

Exact register/flag/scratch contracts and the staging-buffer size are
confirmed and finalized during implementation, matching WP23's own
precedent for deferring these past outline approval.

## Atomic Increments

1. After plan approval, start WP24 in Taskwarrior and mark it active in
   wiki/brain. Capture the clean `0.1.25` baseline.
2. Grow `CASM_VMM_REC_SIZE` to 4 in `common.inc`; update the registry-size
   assert.
3. Update `resourceRegisterVmm` to accept and store the page count; update
   both slot-offset computations to `slot*4`.
4. Update `vmmStoreAlloc` to compute and pass the granted page count
   (mirroring the OS's own rounding) with no change to its external ABI.
5. Add the staging buffer and `vmmWindowRead`/`vmmWindowWrite` with the
   bounds check ahead of any OS call.
6. Add the replay routine.
7. Run `cmake -S . -B build`, then attempt to build CASM at both bases.
   Measure the actual MAIN overflow and propose a specific new size to the
   user before proceeding further.
8. After the size is approved, rebuild at both bases; inspect
   `vmm_store.o`, linked segment sizes, relocation count, and MAIN headroom.
9. Static-verify: no unauthorized zero-page/BSS growth beyond what this plan
   authorizes, correct diagnostic values, and no accidental symbol/pass/
   relocation code.
10. Update records and walkthrough. Dry-run the next stage increment, verify
    exactly one build-number increment and no-change stability, compare
    artifacts, then restore the pre-dry-run baseline before requesting
    completion approval.
11. After explicit completion approval, apply the verified increment,
    rebuild twice, complete WP24, and leave WP25 pending separate approval.

## Failure and Cleanup

WP24 introduces no new resource-ownership category; a windowed transfer
failure does not affect the owning allocation's registry state (the slot
remains owned either way -- only `vmmStoreFree` releases ownership). A
failed transfer is reported to the caller and does not itself trigger
cleanup or exit; that remains the caller's decision, matching every prior
diagnostic that is not a resource-acquisition failure.

## Verification

- ca65/ld65 builds both relocation bases without warning/error.
- The grown registry record's size and offsets are asserted at build time.
- `vmmWindowRead`/`vmmWindowWrite`'s bounds check is exercised statically
  (code path exists and is reachable before any OS call).
- MAIN headroom is measured and recorded at the new approved size.
- The completion dry run increments the build number exactly once, remains
  stable on no-change rebuild, and is restored before approval.
- `git diff --check` passes and changed paths match this plan.

## Stop and Completion Gates

Stop if WP23 is not complete and approved, if the registry growth proposed
above turns out insufficient (e.g. a page count cannot represent something
discovered during implementation), if zero-page growth beyond `$7C-$7F`'s
already-reserved bytes becomes necessary, or if `DOS_VMM_READ`/`DOS_VMM_WRITE`
behave differently from WP22's `vmm.asm` research at implementation time.
WP24 completes only after all evidence is recorded, the user explicitly
approves the walkthrough and the proposed MAIN size, and the verified
post-approval increment passes. Completion does not activate WP25
automatically.

## Documentation and DOX

Update this plan, `brain/KNOWLEDGE.md`, `brain/MEMORY.md`, `brain/task.md`,
`wiki/tasks/casm.md`, `CHANGELOG.md`, Taskwarrior, and the WP24 walkthrough.
Re-read the root and `src`/`external`/`casm` DOX chain after source edits.
`AGENTS.md` changes only if a durable local contract or child index changes.

## Reserved Downstream Plan Slugs

- WP25: `2026-07-21-casm-phase6-wp25-verification-closeout.md`

## Progress

- 2026-07-22: Drafted on `feature/casm-phase6-wp24` from `feature/casm-phase6-wp23`
  at `42968f0` (CASM `0.1.25` build 1097). Reconciled the Phase 0C.4
  bounds-checking mandate against the current 3-byte registry record (a real
  gap, not previously resolved) and proposed growing it to 4 bytes. User
  resolved both open questions: defer the staging buffer's exact size to a
  real link measurement, and share `CASM_DIAG_VMM_TRANSFER_FAILED` between a
  local bounds violation and a genuine OS-level rejection. Awaiting plan
  approval before activation.
