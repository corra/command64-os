---
feature: casm-phase6-wp22-prerequisite-reconciliation
created: 2026-07-21
status: complete
---

# Plan: CASM Phase 6A WP22 - Prerequisite Reconciliation and Phase 0C.4 Freeze

## Objective

WP22 is the CASM Phase 6A entry gate, mirroring the role WP16 played for
Phase 5. It verifies the Phase 5 baseline, researches and freezes the exact
OS VMM primitive contract CASM must program against, resolves the open
dependency items the Phase 6 parent plan raised against WP22 specifically,
creates the CASM Phase 6A Taskwarrior milestone and WP22-WP25 child tasks,
defines the fixture matrix that binds WP23-WP25's verification work, and
advances CASM's stage version as required for a completed work package.

WP22 implements no `vmm_store.s`, no real `DOS_ALLOC_MEM`/`DOS_FREE_MEM`
wiring, and no fixtures. Those remain WP23-WP25.

Parent contract:
`brain/plans/2026-07-21-casm-phase6-vmm-storage-and-symbol-table.md`.

## Baseline

- Branch: `feature/casm-phase6-wp22`, created from `main` at `dcb74bb`
  ("Merge CASM Phase 5 expression evaluator").
- Phase 5 is complete at CASM `0.1.23`, build 1094.
- Phase 5 completion evidence:
  `brain/walkthroughs/2026-07-21-casm-phase5-wp21-verification-closeout.md`.
- The approved MAIN envelope is `$2A00`; Phase 5 leaves 243 bytes headroom.
- `CasmVmmRegistry` already exists in `resources.s` (8 slots, 3-byte records:
  flag/SegHi/Bank) with `resourceRegisterVmm`/`resourceReleaseVmm` and a
  `cleanupVmmStub` placeholder that clears the registry entry without ever
  calling `DOS_FREE_MEM`.
- `common.inc` already reserves `CasmVmmSegHi`/`CasmVmmBank`/`CasmVmmOffLo`/
  `CasmVmmOffHi` at `$7C-$7F` as CASM's private VMM transfer scratch, and
  `CasmPassScratch0-3` at `$88-$8B` as reserved Pass/emission scratch.
- Taskwarrior holds no Phase 6 records (`task project:command64.casm list`
  returns no matches beyond the closed Phase 5 tree).

## Dependency Review

### CASM Phase 5 Ownership

WP21 owns Phase 5 closure and is not reopened by WP22. WP22 only verifies the
closed gate above and stops if wiki, brain, Taskwarrior, artifact, or
user-approval evidence disagrees.

### OS VMM Primitive Contract (researched from `src/command64/vmm.asm`)

`docs/vmm-api.md` documents the calling convention; this section records the
implementation-level facts WP22 found by reading `vmm.asm` directly, because
several of them are not visible from the API doc alone and materially bound
Phase 6A's design:

- **Allocation granularity.** `DOS_ALLOC_MEM` takes a paragraph count
  (16-byte units) and rounds up to whole 4KB pages
  (`PageCount = (Paragraphs + 255) >> 8`). Every allocation therefore wastes
  up to 4095 bytes to rounding; CASM should prefer fewer, larger allocations
  over many small ones.
- **Allocation identity is exactly (SegHi, Bank).** `vmmAlloc` always returns
  `VmmSegLo = 0`; the allocation's base is fully identified by
  `VmmSegHi` (page index, 0-255) and `VmmBank` (0-15). This confirms
  dependency item 6 from the parent plan directly: `DOS_FREE_MEM`'s actual
  input (`vmmFree`: `VmmSegHi` = page index, `VmmBank` = bank) is exactly the
  two fields `CasmVmmRegistry` already stores per slot
  (`CASM_VMM_REC_SEGHI`, `CASM_VMM_REC_BANK`). **The registry record does not
  need to grow.** `cleanupVmmStub` and `resourceReleaseVmm`'s callers can
  pass those two stored bytes straight into `X`/`Y` for `DOS_FREE_MEM`.
- **A single allocation's addressable window is capped at 64KB by the 16-bit
  `Off` cursor, independent of how many pages were actually granted.**
  `vmmComputeAddress` computes `Address = (Seg << 4) + Off` where `Seg` is
  fixed at the allocation's base (`SegLo = 0`, `SegHi` = page index) and
  `Off` (`VmmOffLo/Hi`) is a 16-bit value CASM supplies per read/write call.
  Since `Off` tops out at 65535, only the first 64KB of a larger allocation
  is reachable through a fixed `SegHi`/`Bank` pair and a varying `Off`;
  reaching further would require CASM to recompute `SegHi` itself, which the
  registry does not track and the OS API gives no help doing. **Frozen
  decision**: a single CASM VMM allocation is capped at 65536 bytes (16
  pages). Storage needs beyond that use additional registry slots (up to
  `CASM_VMM_CAPACITY = 8`, i.e. up to 512KB total), never a single `Off`
  value at or beyond the owning allocation's granted size.
- **`DOS_VMM_READ`/`DOS_VMM_WRITE` perform no bounds checking against the
  allocation's granted size.** `vmmReadBlock`/`vmmWriteBlock` only check
  `vmmInitialized`; they compute an address and DMA the requested byte count
  unconditionally. An `Off` + count that runs past an allocation's granted
  pages will silently read or corrupt whatever REU page happens to follow —
  possibly another live CASM allocation, the OS's own reserved 4KB
  environment block, or another allocation the OS's page allocator gave out.
  **Frozen decision**: CASM's own windowed transfer wrapper (WP24) must
  independently track each allocation's granted byte size and refuse any
  request whose `offset + count` would exceed it, since the OS provides no
  such protection.
- **`VMM_ERR_INVALID` is overloaded.** `vmmAlloc` returns it both for
  "VMM not initialized" (no REU detected at boot) and for "zero-paragraph
  request" (`vaZeroErr`) — the two cases are not distinguishable from the
  return code alone. CASM will never issue a zero-paragraph request except
  as an internal bug, so a `VMM_ERR_INVALID` return from an allocation CASM
  itself sized is treated as a REU-unavailable/environment failure, not a
  malformed-input diagnostic.
- **REU memory is uninitialized garbage at boot**, per
  `brain/walkthroughs/2026-05-14-env-var-remediation.md`'s prior VMM
  consumer. Phase 6A's replay verification must write a known pattern before
  ever reading it back; it must never assume implicit zero-fill.
- **REU presence in the supported local test environment is already
  established**, not an open question: the environment-variable subsystem
  (`SET`/`PATH`) has used the same VMM primitives at runtime since
  2026-05-14. Phase 6A is CASM's first VMM consumer, not the OS's first.

### Zero-Page Sufficiency

`$7C-$7F` (VMM transfer scratch) is confirmed sufficient for Phase 6A: one
allocation's active `SegHi`/`Bank`/`OffLo`/`OffHi` is exactly four bytes, and
Phase 6A performs one transfer at a time (no concurrent windows). No zero-page
growth is requested by WP22. Phase 6B's own zero-page needs (hash bucket
cursor, collision-chain traversal pointers) are out of scope for WP22 and
remain WP26's decision against the reserved `$88-$8B` Pass scratch group.

### MAIN Envelope

243 bytes of headroom cannot fit real `DOS_ALLOC_MEM`/`DOS_FREE_MEM` wiring
plus windowed read/write wrappers. Unlike the zero-page and registry-record
questions above, this is not something WP22 can resolve by research alone —
Phase 4's WP13 and Phase 5's WP19 both set their MAIN envelope increase
*within* the implementing work package, once real code existed to link and
measure, not in the preceding freeze package. **Reconciliation**: WP22 does
not set a new MAIN size. It records that WP23 must request one, sized against
an actual link attempt, following the same precedent. WP22 flags this so the
requirement is not rediscovered as a surprise mid-WP23.

### Diagnostics

Four new failure categories are needed and none exist yet: VMM unavailable
(REU absent/uninitialized), allocation exhausted (`VMM_ERR_NOMEM`), free
failure, and transfer failure. Following the established contiguous
`CASM_DIAG_PHASE<n>_LAST` pattern (Phase 5 ends at `CASM_DIAG_RESOLVER_FAILED
= $27`), the next four values (`$28-$2B`) are available. **Reconciliation**:
matching the Phase 5 precedent (WP16 fixed no diagnostic values; WP17
assigned and reserved them), WP22 fixes only the *count and semantics* of the
new diagnostics. WP23 assigns and reserves the literal `$28-$2B` values when
it writes the ABI, exactly as WP17 did for `$24-$27`.

### Taskwarrior

Confirmed empty for Phase 6. WP22 creates the CASM Phase 6A parent milestone
and WP22-WP25 child tasks, and reserves (but does not create) the CASM Phase
6B milestone and WP26-WP31 slugs, matching how WP16 reserved WP18-WP21 slugs
without creating their task records.

### Downstream Order

```text
WP22 contract/task freeze (this plan)
  -> WP23 VMM allocation core
  -> WP24 windowed transfer and replay
  -> WP25 CASM Phase 6A verification and completion gate
  -> WP26 CASM Phase 6B prerequisite reconciliation and Phase 0C.5 freeze
  -> ... (Phase 6B, per the parent plan)
```

Only one downstream work package may be active. Approval or implementation of
an earlier package does not approve a later package.

## Contract to Freeze (Phase 0C.4)

### VMM Record Model

- One CASM "VMM record store" allocation is obtained through
  `DOS_ALLOC_MEM`, capped at 65536 bytes (16 pages) so a fixed `SegHi:Bank`
  pair plus a 16-bit `Off` cursor addresses the whole allocation.
- Ownership is registered in the existing `CasmVmmRegistry` (`flag`,
  `SegHi`, `Bank`) immediately after a successful allocation and before any
  transfer against it; no new registry fields are required.
- `resourceReleaseVmm`'s cleanup path calls real `DOS_FREE_MEM` with the
  stored `SegHi`/`Bank`, replacing `cleanupVmmStub`'s current no-op-on-REU
  behavior. A failed free preserves the record (matching
  `cleanupFileRecord`'s retry-on-failure precedent) rather than silently
  dropping ownership.
- Every windowed read/write call is bounds-checked by CASM against the
  issuing allocation's granted size before it reaches `DOS_VMM_READ`/
  `DOS_VMM_WRITE`, because the OS performs no such check itself.
- A fresh allocation's contents are undefined; no Phase 6A or 6B routine may
  assume implicit zero-fill.

### Failure Contract

- `VMM_ERR_INVALID` from an allocation CASM itself sized (never
  zero-paragraph) is treated as VMM-unavailable, not malformed input.
- `VMM_ERR_NOMEM` is allocation exhaustion, distinct from REU-unavailable.
- A CASM-side bounds violation (`offset + count` beyond the allocation's
  granted size) is a CASM-internal fatal error, never forwarded to the OS.
- All four new diagnostic categories route through the existing
  `resourcesCleanup`/`exitFatal` path; Phase 6A introduces no new cleanup
  owner.

### Explicitly Deferred to Phase 6B (not frozen here)

- Symbol record layout, hash function, bucket count, collision chains.
- Any interpretation of VMM record *contents* — Phase 6A stores and replays
  opaque bytes only.

## Scope

Included:

- verify Phase 5 completion and baseline artifacts;
- research and freeze the OS VMM primitive contract above from
  `src/command64/vmm.asm` and `docs/vmm-api.md`;
- create the CASM Phase 6A Taskwarrior milestone and WP22-WP25 child tasks in
  `wiki/tasks/casm.md` and `brain/task.md`; reserve CASM Phase 6B's slugs
  without creating its records;
- freeze the Phase 0C.4 contract above in `brain/KNOWLEDGE.md`;
- define the WP23-WP25 fixture matrix below as binding verification guidance;
- create the detailed WP23 plan;
- update planning/session/changelog records required by the repository;
- advance CASM to `0.1.24` and increment `BUILD_CASM` exactly once; and
- produce a WP22 walkthrough and request explicit completion approval.

Excluded:

- `vmm_store.s` or any VMM allocation/transfer implementation;
- `resources.s`, `common.inc`, CMake, or linker changes;
- the CASM Phase 6A MAIN envelope size decision (WP23's, per the
  Dependency Review);
- literal diagnostic hex values (WP23's, per the Dependency Review);
- Taskwarrior completion of WP22 or activation of WP23 before user approval;
- Phase 5 record rewriting; and
- completion of the CASM Phase 6A milestone.

## Expected Files

| File | Action |
|---|---|
| `brain/plans/2026-07-21-casm-phase6-wp22-prerequisite-reconciliation.md` | this plan |
| `brain/plans/2026-07-21-casm-phase6-vmm-storage-and-symbol-table.md` | reconcile MAIN/diagnostic deferral notes |
| `brain/plans/2026-07-21-casm-phase6-wp23-vmm-allocation-core.md` | create detailed WP23 plan |
| `brain/KNOWLEDGE.md` | add Phase 0C.4 contract |
| `brain/MEMORY.md` | record unchanged layout and verified artifact measurements |
| `brain/task.md` | register CASM Phase 6A hierarchy and WP22 progress |
| `wiki/tasks/casm.md` | register CASM Phase 6A hierarchy and matching UUIDs |
| `CHANGELOG.md` | record the WP22 contract/version increment |
| `brain/walkthroughs/2026-07-21-casm-phase6-wp22-prerequisite-reconciliation.md` | create verification walkthrough |
| `src/external/casm/casm.s` | stage `23` -> `24` only |
| `src/external/casm/BUILD_CASM` | build-managed single increment |
| Taskwarrior | create CASM Phase 6A parent and WP22-WP25 records |

No `cmake/`, `CMakeLists.txt`, or CASM source file other than the version
string may change.

## ABI, Storage, and Runtime Effects

- No VMM ABI is implemented by WP22.
- No zero-page, BSS, stack, file, VMM, lexer, parser, opcode, emitter, or
  output behavior changes.
- The PRG payload must be byte-identical except for the version-stage/build
  banner bytes and relocation metadata necessarily affected by those bytes.
- No resource is acquired and no cleanup path changes.

## Verification and Fixture Strategy (binding on WP23-WP25)

WP22 itself changes no runtime behavior and therefore has no fixtures of its
own — matching WP16's precedent for Phase 5. This section fixes the fixture
matrix WP23-WP25 must implement against, so the Phase 0C.4 contract above is
falsifiable rather than aspirational:

| Fixture | Exercises |
|---|---|
| `vmmalloc1` | Single allocation succeeds; registry slot records the correct `SegHi`/`Bank`; free succeeds; registry slot clears. |
| `vmmalloc2` | Re-allocating after a free reuses the freed page(s) (proves `DOS_FREE_MEM` actually marked the MCT free, not just cleared CASM's registry). |
| `vmmalloc3` | Filling all 8 `CasmVmmRegistry` slots, then a 9th register call returns the existing `CASM_DIAG_REGISTRY_FULL` unchanged. |
| `vmmalloc4` | An allocation request that exhausts REU capacity returns the new VMM-exhaustion diagnostic and exits cleanly with no partial ownership. |
| `vmmwrite1`/`vmmread1` | A known byte pattern written through the windowed wrapper is read back correctly via a *different* staging buffer. |
| `vmmreplay1` | Write a pattern, discard the RAM copy (zero the staging buffer), read back fresh, and compare byte-for-byte — the literal Phase 6A completion-gate wording ("written, read, and replayed"). |
| `vmmoffset1` | A transfer at/near the 65536-byte single-allocation cap confirms the windowing math is correct at the edge Phase 6A chose to enforce. |
| `vmmbounds1` | A deliberately oversized `offset + count` against a smaller granted allocation is rejected by CASM's own bounds check before any `DOS_VMM_READ`/`WRITE` call — never forwarded to the OS. |
| `vmmfree1` | Using a slot's stored handle after it has been freed is rejected by CASM's own registry state, not merely by chance REU contents. |
| `vmmnoreu` (manual, if the test harness can toggle REU) | `VMM_ERR_INVALID` from allocation is reported as the VMM-unavailable diagnostic and CASM exits cleanly without corrupting the shell. If the local VICE/hardware configuration cannot toggle REU per run, this case is documented as manually deferred rather than silently dropped. |

All fixtures are independent of source, symbol, or expression semantics, per
the master plan's Phase 6A gate. WP25 owns building and running this matrix;
WP23/WP24 own implementing the code it exercises.

## Atomic Implementation Increments

1. Capture clean baseline: status, `BUILD_CASM`, version banner, both link-base
   artifact measurements, and hashes needed for the bounded comparison.
2. Verify Phase 5 closure across walkthrough, wiki, brain, git history, and
   Taskwarrior. Stop rather than repair Phase 5 if any evidence disagrees.
3. Research and record the OS VMM primitive contract from `vmm.asm` (already
   done above; re-verify against the file at implementation time in case it
   has changed since this plan was drafted).
4. Create the CASM Phase 6A Taskwarrior milestone and WP22-WP25 child tasks;
   reserve CASM Phase 6B slugs.
5. Synchronize the CASM Phase 6A hierarchy into `wiki/tasks/casm.md` and
   `brain/task.md`.
6. Freeze the Phase 0C.4 contract in `brain/KNOWLEDGE.md`; record unchanged
   storage ownership in `brain/MEMORY.md`.
7. Create the detailed WP23 plan, including the deferred MAIN-size and
   diagnostic-value decisions it now owns explicitly.
8. Dry-run and verify the mandatory stage increment, then restore
   `0.1.23.1094`. Verify artifacts, documentation, task agreement, DOX scope,
   and whitespace; write the walkthrough and request explicit completion
   approval.
9. Only after explicit user approval: apply stage `23` -> `24`, build once to
   update `BUILD_CASM`, build again to prove no-change stability, and mark
   WP22 complete. Leave the CASM Phase 6A milestone open.
10. Separately request approval before activating WP23.

Each increment is reviewed before the next. A failed implementation receives a
root-cause analysis; no repeated speculative edits are allowed.

## Verification

- `git diff --check` is clean.
- Changed paths are limited to the expected-files table.
- Taskwarrior, wiki, and brain contain identical UUIDs and statuses for the
  CASM Phase 6A parent and WP22-WP25.
- WP22 is the only started CASM Phase 6 child before completion approval.
- `cmake --build build --target casm` succeeds at both relocation bases.
- `BUILD_CASM` advances exactly once; a no-change rebuild leaves it unchanged.
- CODE, RODATA, BSS, MAIN headroom, PRG size, and relocation count are
  recorded and confirmed unchanged apart from version metadata.
- No C64 runtime session is required because WP22 changes no runtime
  behavior.
- The prohibited `c64-testing` MCP and web emulators are not used.

## Stop Conditions

- Phase 5 completion evidence disagrees.
- The `vmm.asm` research above no longer matches the file at implementation
  time (e.g., the OS VMM contract changed since this plan was drafted).
- Any VMM allocation/transfer/symbol/fixture/build-system change appears
  necessary.
- The version increment changes more than version metadata or overflows the
  approved `$2A00` MAIN envelope.
- A record-model, failure-contract, or dependency conflict requires a
  parent-contract change beyond the clarifications already recorded.
- WP23 implementation would begin before WP22 completion approval.

## Documentation and DOX Closeout

Re-read the root, `src`, `src/external`, `src/external/casm`, `wiki`, and
`wiki/tasks` DOX chains after edits. Update an AGENTS.md only if WP22 changes
a durable local contract or child index; otherwise report it intentionally
unchanged. Do not mark WP22 done until the walkthrough is presented and the
user explicitly confirms completion.

## Completion Gate

WP22 completes only when all increments pass, CASM Phase 6A records agree,
the Phase 0C.4 contract is durable, the WP23 plan exists but is not active,
CASM is verified at `0.1.24`, and the user explicitly approves WP22
completion.

## Progress

- 2026-07-21: Plan drafted on `feature/casm-phase6-wp22` from `main` at
  `dcb74bb`. Researched the OS VMM primitive contract directly from
  `src/command64/vmm.asm` (not just the API doc) and found: the existing
  3-byte `CasmVmmRegistry` record already matches `DOS_FREE_MEM`'s real input
  exactly, so it does not need to grow; a single allocation's addressable
  window is capped at 64KB by the 16-bit `Off` cursor regardless of how many
  pages were granted, which is now a frozen Phase 6A design constraint; the
  OS performs no bounds checking on `DOS_VMM_READ`/`WRITE`, so CASM's own
  windowed wrapper must self-enforce it; `VMM_ERR_INVALID` is ambiguous
  between "no REU" and "zero-paragraph request"; and REU contents are
  undefined at boot. Reconciled the parent plan's MAIN-envelope-size and
  diagnostic-value items as WP23's decisions, not WP22's, matching how WP13
  and WP19 set their own MAIN sizes rather than an earlier freeze package
  doing it for them. Defined a nine-case fixture matrix binding on
  WP23-WP25. Awaiting user review before task activation, Taskwarrior
  creation, or any documentation edit.
- 2026-07-21 (later): User approved beginning WP22 implementation. Captured
  the clean baseline (`0.1.23` build 1094, PRG hash matching the WP21
  closeout exactly). Created the CASM Phase 6A Taskwarrior milestone
  (`d68e6c58`) and WP22-WP25 children (`eb7541e5`/`8782e75d`/`228daccc`/
  `544a04bd`), sequentially dependent. Synchronized `wiki/tasks/casm.md` and
  `brain/task.md`. Froze the Phase 0C.4 contract in `brain/KNOWLEDGE.md` and
  recorded findings in `brain/MEMORY.md`. Added the `CHANGELOG.md`
  `[Unreleased]` entry. Drafted the detailed WP23 plan
  (`brain/plans/2026-07-21-casm-phase6-wp23-vmm-allocation-core.md`), which
  now owns the deferred MAIN-envelope-size and diagnostic-value decisions.
  Dry-ran the version-only completion candidate: `0.1.24` build 1095, exactly
  2 changed bytes (`cmp -l`) versus the baseline PRG, unchanged CODE/
  relocation counts; restored to `0.1.23` build 1094 via `git checkout` and
  reproduced the baseline hash exactly. Verified both `test_image_d64` and
  `image_d64` at the restored baseline; `git diff --check` clean. Walkthrough
  drafted: `brain/walkthroughs/2026-07-21-casm-phase6-wp22-prerequisite-reconciliation.md`.
  Awaiting explicit user completion approval before applying the final
  `0.1.24` increment.
- 2026-07-22: User confirmed the runtime banner at the restored `0.1.23`
  build 1094 baseline and explicitly approved WP22 completion. Applied the
  verified `0.1.23` -> `0.1.24` increment for real: build 1095 reproduced the
  dry run's PRG hash exactly
  (`66594cd2b278b78705cacddf6e0a70d41c7574f8c2e84c6a101006bdd4958e64`), an
  immediate no-change rebuild held at 1095, and both `test_image_d64` and
  `image_d64` passed. Marked WP22 complete in Taskwarrior, `wiki/tasks/casm.md`,
  and `brain/task.md`; WP23 (`8782e75d`) is now unblocked but requires its own
  separate plan approval before activation. WP22 is complete.
