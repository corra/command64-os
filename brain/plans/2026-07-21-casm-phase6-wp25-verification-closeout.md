---
feature: casm-phase6-wp25-verification-closeout
created: 2026-07-22
status: complete
---

# Plan: CASM Phase 6A WP25 - Verification, Walkthrough, and Completion Gate

## Objective

WP25 builds and runs the fixture matrix WP22 defined, records the runtime
verification evidence, and closes the CASM Phase 6A milestone. Unlike Phase
5 (whose analogous work was split across WP20's fixture harness and WP21's
verification/closeout), the parent plan bundles all three into this single
package — this is the parent plan's own design, not a discrepancy to
correct. WP25 implements no new production VMM behavior; it exercises what
WP23/WP24 already built.

Taskwarrior: `544a04bd-4ccb-47c6-9013-8af57aa37353`.

Prerequisite: WP24 is complete and approved (CASM `0.1.26` build 1099,
commit `3ac7dd1`). WP25's Taskwarrior UUID is pending, unblocked. Approval
of this plan is required before activation or source edits, per the CASM
`AGENTS.md` gate.

## Reconciliation Findings

- **Stale acceptance checklist (fixed on this branch, before this plan).**
  `wiki/tasks/casm.md`'s Phase 6A Acceptance section still showed WP23's
  real `DOS_ALLOC_MEM`/`DOS_FREE_MEM` wiring and WP24's windowed-transfer
  bounds checking as unchecked, even though both shipped and were approved.
  Checked off; left the write/read/replay and diagnostic-stability items
  open since those describe runtime properties only WP25's fixture run can
  actually verify.
- **The test harness must stub `diagPrintFatal`, not import the real one.**
  `resources.s`'s `exitSuccess`/`exitFatal` reference `diagPrintFatal`
  (`diagnostics.s`), which itself imports `CasmTokenRecord`/`CasmLookahead*`/
  `CasmDiagLoc*`/`sourceDrainLineTail` — pulling in `lexer.s` and `source.s`
  transitively. ld65 links whole object files once any symbol from them is
  referenced, so importing `resourceRegisterVmm` alone would drag in all of
  `resources.o`, including its `diagPrintFatal` reference, and from there
  the entire lexer/source chain — even though the VMM test never calls
  `exitSuccess`/`exitFatal`. WP20's `casm_expr.s` already solved the
  identical problem for `expr.s`'s lexer/diagnostic dependencies by
  exporting its own minimal stand-ins (`lexerNext`, `diagSetLocFromToken`,
  `CasmTokenRecord`, `CasmTokenText`) instead of importing the real modules.
  WP25's test driver does the same: export a trivial local `diagPrintFatal`
  stub, keeping the harness isolated to `vmm_store.s` + `resources.s` +
  `common.inc`.
- **`CasmVmmBuffer` is one shared buffer, not "a different staging
  buffer."** WP22's fixture matrix described `vmmwrite1`/`vmmread1` as
  writing a pattern and reading it back "via a *different* staging buffer,"
  but WP24 deliberately implemented a single fixed `CasmVmmBuffer` (matching
  `CasmIoBuffer`'s precedent), not a caller-supplied pointer. The test
  instead keeps its own reference copy of the pattern in ordinary test-driver
  memory (outside `CasmVmmBuffer`), writes it, zero-fills `CasmVmmBuffer`,
  reads it back, and compares against the retained reference — exactly the
  technique `vmmReplay` itself already implements. `vmmwrite1`/`vmmread1`
  and `vmmreplay1` end up exercising overlapping code paths; see Scope.
- **`vmmalloc4` ("REU exhaustion") is not reachable through normal
  allocation calls.** The OS's MCT tracks 4096 pages (16MB) independent of
  the REU's real physical size; CASM's own registry caps total usage at 8
  slots x 65536 bytes = 512KB (128 pages) — CASM can never mark enough of
  the MCT to make `vmmAlloc` genuinely return `VMM_ERR_NOMEM` through normal
  calls, regardless of the real REU size (a prior remediation plan
  documents the standard VICE test setup as `-reu -reusize 512`, i.e. a
  512KB REU, but even a real 512KB REU doesn't change this: the MCT
  bookkeeping is independent of physical REU capacity). Resolved below:
  documented as manually deferred rather than automated.

### Real Defects Caught by the First Runtime Matrix

WP23/WP24's code had never actually executed before this WP25 fixture ran
for the first time (both explicitly deferred a real call site). The first
real run found three defects — two in production `vmm_store.s` code, one in
the test itself — none caught by static review or the ca65/ld65 build:

- **Test defect (`vmmalloc3`).** The fixture expected a 9th allocation
  against a full registry to return `CASM_DIAG_REGISTRY_FULL`, but
  `vmmStoreAlloc` deliberately collapses that into `CASM_DIAG_VMM_ALLOC_FAILED`
  (freeing the just-granted OS memory again first), per its own documented
  WP23 ABI — `CASM_DIAG_REGISTRY_FULL` is `resourceRegisterVmm`'s internal
  code, never surfaced by `vmmStoreAlloc` itself. The wrong expectation made
  the fixture bail out before its free loop ran, permanently leaking all 8
  slots and cascading into every fixture after it failing (`..fffff`).
  Fixed by correcting the test's expectation; production code was already
  right. User approved fixing this within WP25.
- **Production defect (`vwPrepareTransfer`, `vmm_store.s`).** The
  offset+count 16-bit overflow check rejected the exact-65536-byte boundary
  case (a full-cap allocation's last valid window) along with genuinely
  out-of-range requests, because both wrap the 16-bit add and set carry.
  Fixed by checking whether the wrapped remainder is exactly zero (valid,
  true sum was exactly 65536) versus nonzero (true sum exceeds the cap).
  User approved fixing this within WP25 rather than opening a separate
  remediation plan, given the narrow, well-understood scope.
- **Production defect (`vmmReplay`, `vmm_store.s`).** Stashed the input
  slot in `CasmValue0Lo` across its two internal calls to
  `vmmWindowWrite`/`vmmWindowRead` — but both call `vwPrepareTransfer`,
  which documents `CasmValue0Lo`/`CasmValue0Hi` as its own clobbered
  offset+count scratch. The first call's `vwPrepareTransfer` overwrote the
  stashed slot with the offset+count sum, so the second call read back a
  corrupted, out-of-range "slot" that `vwPrepareTransfer`'s own bounds
  check correctly rejected. The exact same class of shared-scratch bug WP23
  already caught twice (`vmmStoreFree`, `resourcesCleanup`'s VMM loop), now
  found a third time in `vmmReplay`. Fixed by stashing in `CasmValue1Lo`
  instead, which neither `vwPrepareTransfer` nor its callees touch. Found
  by adding temporary per-step diagnostic instrumentation to the failing
  fixture (printing which internal check failed) after live VICE debugging
  proved too fragile to trust in this session (a stray leftover breakpoint
  and an improvised direct-PC-jump both produced misleading state); the
  instrumentation was removed once the bug was confirmed fixed.

## Inherited Contract

- Phase 0C.4 VMM record model and failure contract, frozen in
  `brain/KNOWLEDGE.md` by WP22, implemented by WP23/WP24.
- Phase 6A completion gate (parent plan, `brain/KNOWLEDGE.md`): bounded VMM
  records can be written, read, and replayed without depending on source or
  symbol semantics.
- `vmmStoreAlloc`/`vmmStoreFree`/`vmmWindowRead`/`vmmWindowWrite`/`vmmReplay`
  are stable ABI; WP25 calls them but does not change them.
- No prohibited C64-testing MCP or web emulator; runtime checks are
  performed by the user in the supported local VICE environment.

## Scope

Included:

- a new standalone test harness, `tests/src/casm_vmm/casm_vmm.s`, built the
  same way as `test_casm_expr` (a `casm_vmm` special case appended to the
  `TEST_CA65_SRCS` loop in `CMakeLists.txt`, pulling in `vmm_store.s`,
  `resources.s`, and `common.inc`, plus the harness's own stub
  `diagPrintFatal`);
- a sequential fixture run (not an independent-per-case table, since VMM
  operations have real side effects on shared registry/REU state across one
  PRG execution) covering, in order:
  1. `vmmalloc1` — allocate, verify the registry slot's `SegHi`/`Bank`/
     `Pages` fields, free, verify the slot clears.
  2. `vmmalloc2` — allocate the same size again; verify `SegHi`/`Bank`
     match the just-freed page (proves `DOS_FREE_MEM` actually marked the
     MCT free, not just cleared CASM's registry); free again.
  3. `vmmalloc3` — allocate 8 small (1-page) requests to fill the registry;
     verify a 9th returns `CASM_DIAG_VMM_ALLOC_FAILED` (`vmmStoreAlloc`
     deliberately collapses a registry-full `resourceRegisterVmm` rejection
     into the same public diagnostic as an OS-level allocation failure, per
     its WP23 ABI — `CASM_DIAG_REGISTRY_FULL` is `resourceRegisterVmm`'s own
     internal-boundary code, not `vmmStoreAlloc`'s; a first real run of this
     fixture caught an earlier draft expecting the wrong one, which masked
     the free loop below and cascaded into every later fixture failing);
     free all 8, restoring a clean registry for the remaining cases.
  4. `vmmwrite1`/`vmmread1`/`vmmreplay1` — allocate one small region; write
     a known pattern (kept in the test driver's own memory, not
     `CasmVmmBuffer`) via `vmmWindowWrite`; separately zero `CasmVmmBuffer`
     and read it back via `vmmWindowRead`, comparing against the retained
     pattern; then call `vmmReplay` directly and confirm the same result;
     free the allocation.
  5. `vmmoffset1` — allocate a full 65536-byte (16-page) region; confirm a
     window ending exactly at the last valid byte succeeds and a window one
     byte past it is rejected locally; free.
  6. `vmmbounds1` — allocate a small (1-page) region; confirm a
     deliberately oversized `offset + count` is rejected locally
     (`CASM_DIAG_VMM_TRANSFER_FAILED`) before any OS call; free.
  7. `vmmfree1` — allocate, free, then confirm a transfer against the
     now-freed slot is rejected by CASM's own registry state.
- `vmmalloc4` (REU/allocation exhaustion) and `vmmnoreu` are both documented
  as manually deferred, per the user's decision: automated construction of
  either is impractical (`vmmalloc4` would require directly manipulating
  OS-owned MCT memory rather than exercising it through a documented API;
  `vmmnoreu` needs a per-run REU toggle the supported harness doesn't have).
  The walkthrough records the reasoning WP22/this plan already established
  for both, rather than treating either as silently dropped;
- pass/fail dot printing and a final summary line, matching
  `test_casm_expr`'s reporting convention;
- build both relocation bases and `test_image_d64`; run in VICE; record the
  full matrix result in the walkthrough;
- close the CASM Phase 6A milestone in Taskwarrior/wiki/brain upon explicit
  user approval.

Excluded:

- any change to `vmmStoreAlloc`/`vmmStoreFree`/`vmmWindowRead`/
  `vmmWindowWrite`/`vmmReplay`'s documented ABI;
- any symbol, hash, or Pass 1/Pass 2 code (Phase 6B);
- activation of CASM Phase 6B (a separate gate, separately approved).

## Open Questions (resolved by the user)

1. **`vmmalloc4` construction.** Resolved: documented as manually deferred,
   alongside `vmmnoreu`, rather than implemented by directly manipulating
   OS-owned MCT memory. The walkthrough records why automated construction
   isn't practical for either case.
2. **Test target/PRG naming.** Confirmed: `casm_vmm` -> `test_casm_vmm`,
   matching `casm_expr` -> `test_casm_expr`, starting at
   `TEST_PRG_SIZE = "1000"` and measured/adjusted during implementation if
   it overflows.

## Expected Files

| File | Action |
| --- | --- |
| `tests/src/casm_vmm/casm_vmm.s` | create: fixture driver |
| `tests/src/casm_vmm/BUILD_TEST_CASM_VMM` | create: build counter (required by `add_ca65_app`) |
| `CMakeLists.txt` | add the `casm_vmm` special case to the `TEST_CA65_SRCS` loop |
| `src/external/casm/vmm_store.s` | unplanned: fix two real defects (`vwPrepareTransfer`'s exact-cap overflow rejection; `vmmReplay`'s clobbered slot stash) the first runtime matrix caught |
| `src/external/casm/casm.s` | stage increment only at completion |
| `src/external/casm/BUILD_CASM` | build-managed increment |
| `wiki/tasks/casm.md` | Phase 6A Acceptance closeout; already partially reconciled on this branch |
| `brain/plans/2026-07-21-casm-phase6-wp25-verification-closeout.md` | activate/update progress |
| `brain/KNOWLEDGE.md`, `brain/MEMORY.md`, `brain/task.md` | synchronize implementation evidence; close Phase 6A |
| `CHANGELOG.md` | synchronize status and functional record |
| `brain/walkthroughs/2026-07-21-casm-phase6-wp25-verification-closeout.md` | verification walkthrough with the full runtime matrix |

`resources.s`/`common.inc` did not need to change; `vmm_store.s` needed two
narrow bug fixes (see Reconciliation Findings), each explicitly approved
in place rather than triggering the "stop for an amended plan" gate below,
since both were small, well-understood corrections to arithmetic
correctness rather than ABI or scope changes.

## Atomic Increments

1. After plan approval, start WP25 in Taskwarrior and mark it active in
   wiki/brain. Capture the clean `0.1.26` baseline.
2. Create `tests/src/casm_vmm/casm_vmm.s` and `BUILD_TEST_CASM_VMM`; add the
   `casm_vmm` CMake special case.
3. Implement fixtures 1-3 (`vmmalloc1`-`vmmalloc3`) and confirm they build.
4. Implement fixtures 4-7 (`vmmwrite1`/`vmmread1`/`vmmreplay1`,
   `vmmoffset1`, `vmmbounds1`, `vmmfree1`).
5. Document `vmmalloc4` and `vmmnoreu` as manually deferred in the
   walkthrough, per the user's decision — no source change for either.
6. Build both relocation bases and `test_image_d64`. Run the harness in
   VICE (ask the user); record dot/summary output.
7. Update `wiki/tasks/casm.md`'s remaining Phase 6A Acceptance items based
   on the actual runtime result.
8. Draft the walkthrough with the full matrix result, then request explicit
   completion approval (which also closes CASM Phase 6A itself, per the
   parent plan — WP25 is the milestone's own completion gate).
9. After approval, apply the version increment, rebuild twice, complete
   WP25 and the CASM Phase 6A milestone in Taskwarrior/wiki/brain. Leave
   CASM Phase 6B (WP26+) pending its own separately gated start.

## Failure and Cleanup

The test harness is not a production code path; a fixture failure prints an
`F` and continues to the next case (matching `test_casm_expr`'s
convention) rather than aborting, so one broken case doesn't hide evidence
about the others. The harness calls `DOS_EXIT` directly at the end, not
through `resourcesCleanup`'s full contract, matching `test_casm_expr`'s own
precedent (a test driver, not a production app).

## Verification

- ca65/ld65 builds both relocation bases for `test_casm_vmm` without
  warning/error.
- `test_image_d64` includes `test_casm_vmm` alongside the existing fixtures.
- The user runs `TEST_CASM_VMM` in VICE and reports the dot/summary output;
  the walkthrough records it verbatim.
- Every fixture that fails is investigated before completion is requested —
  a red fixture is a stop condition, not something to note and proceed past.
- `git diff --check` passes and changed paths match this plan.

## Stop and Completion Gates

Stop if WP24 is not complete and approved, if a fixture reveals a defect
whose scope or fix isn't small and well-understood enough for the user to
approve fixing in place (the two `vmm_store.s` defects the first runtime
matrix actually found were both judged narrow enough to fix directly, per
explicit user approval each time — a defect requiring an ABI change or a
non-obvious redesign would instead need its own remediation plan), or if
the `vmmalloc4`/`vmmnoreu` deferral reasoning turns out wrong (e.g., REU
can in fact be toggled per-run in the supported environment). WP25
completes only after the full matrix has run, all evidence is recorded,
the user explicitly approves the walkthrough, and the verified
post-approval increment passes. Completion closes the CASM Phase 6A
milestone but does not activate CASM Phase 6B, which remains separately
gated.

## Documentation and DOX

Update this plan, `brain/KNOWLEDGE.md`, `brain/MEMORY.md`, `brain/task.md`,
`wiki/tasks/casm.md`, `CHANGELOG.md`, Taskwarrior, and the WP25 walkthrough.
Re-read the root and `src`/`external`/`casm`/`tests` DOX chain after source
edits. `AGENTS.md` changes only if a durable local contract or child index
changes.

## Reserved Downstream Plan Slugs

CASM Phase 6B's WP26-WP31 slugs remain reserved in the parent plan but are
not created until Phase 6A's completion gate is approved and CASM Phase 6B
is separately gated to begin, matching the parent plan's own sequencing.

## Progress

- 2026-07-22: Drafted on `feature/casm-phase6-wp25` from `feature/casm-phase6-wp24`
  at `3ac7dd1` (CASM `0.1.26` build 1099). Reconciled a stale acceptance
  checklist (WP23/WP24 items left unchecked), a test-harness build-dependency
  hazard (must stub `diagPrintFatal` like WP20 did for lexer symbols), and a
  wording mismatch between WP22's fixture matrix and WP24's actual
  single-buffer design. Found that `vmmalloc4` (REU exhaustion) is not
  reachable through normal allocation calls given CASM's own 512KB cap
  against a 16MB-tracked MCT. User resolved both open questions: document
  `vmmalloc4` as manually deferred alongside `vmmnoreu` rather than
  directly manipulating OS-owned MCT memory, and confirmed `casm_vmm`/
  `test_casm_vmm` naming starting at `TEST_PRG_SIZE = "1000"`.
- 2026-07-22 (later): User approved the plan as drafted. Activated on
  `feature/casm-phase6-wp25` from `3fd1f10`. Implemented
  `tests/src/casm_vmm/casm_vmm.s` with 7 automated fixtures. The first real
  execution of WP23/WP24's code found three defects: a wrong diagnostic
  expectation in the test's own `vmmalloc3` case, and two real
  `vmm_store.s` bugs (`vwPrepareTransfer` rejecting the valid exact-65536
  boundary; `vmmReplay` clobbering its stashed slot via a zero-page cell
  `vwPrepareTransfer` also uses). All three fixed with explicit user
  approval to fix in place. All 7 fixtures pass. Dry-ran the version-only
  completion candidate: `0.1.27` build 1102, exactly 2 changed bytes versus
  the candidate PRG; restored to `0.1.26` build 1101 via `git checkout` and
  reproduced exactly. User approved completion; final `0.1.27` build 1102
  verified, no-change rebuild stable, both images pass. WP25 is complete,
  and with it the CASM Phase 6A milestone closes. CASM Phase 6B remains
  separately gated and unstarted.
