# CASM Phase 11 WP58 Verification Walkthrough

Status: Complete; user-approved 2026-08-11
Branch: `feature/casm-phase11-wp58`
Candidate: CASM `0.2.0` build `1260` (unchanged — WP58 is test infrastructure
only; `VERSION_STAGE` bump deferred per the plan's own precedent, matching
WP57)

## Scope

WP58 applies WP57's proven runtime `OS_API` fault-interception mechanism
across every real call site the parent plan named: all five `fileio.s`
operations, all four `vmm_store.s` operations (including both `DOS_ALLOC_MEM`
branches), and the state-consistency contract at each of `source.s`/
`symbols.s`/`reloc.s`/`include.s`'s own VMM call sites. No production source
(`src/external/casm/`, `src/command64/`) changed at any point — this is test
infrastructure only, exactly like WP57.

## Implementation Review

Re-checked every plan requirement, Atomic Increment, and Stop Condition
against the actual work across all seven increments:

- **Increment 1** (shared library extraction): `faultstub.inc` extracted
  from WP57's inline prototype in `casm_faultinject.s`, extended with the
  canned-return descriptor (`FaultReturnA` for `DOS_ALLOC_MEM`'s branch,
  `FaultSetCount`/`FaultReturnCountLo/Hi` for `DOS_READ_FILE`'s EOF-vs-error
  disambiguation, `FaultReturnSuccess` for `fileWrite`'s `SHORT_WRITE`
  shape). `fileDelete`'s diagnostic-substitution behavior (Open Question 3)
  was traced and found to need no richer descriptor of its own — resolved
  without a plan amendment. Refactor verified behavior-preserving: identical
  `CASM FAULTINJECT: PASS` before any new case was added.
- **Increment 2** (`fileio.s`'s remaining 4 operations): expanded
  `casm_faultinject` from 2 to 8 real cases — create/write/short-write/
  close/delete/EOF-normalization/read-failure, covering every disclosed
  `fileio.s` diagnostic shape.
- **Increment 3** (`casm_faultvmm`): `vmm_store.s`'s own 4 operations
  against its own diagnostics, proving both `DOS_ALLOC_MEM` branches
  (`CASM_DIAG_VMM_UNAVAILABLE` via `VMM_ERR_INVALID`, `CASM_DIAG_VMM_ALLOC_
  FAILED` via any other rejection) independently. Hit and resolved a
  16-char D64 filename collision (`test_casm_faultinject_vmm` truncating
  identically to the existing fixture) — user-approved packaging amendment
  moved it to `casm_overflow_test.d64`.
- **Increment 4** (`source.s`/`symbols.s`/`reloc.s`/`include.s` state-
  consistency fixtures): built across two sessions.
  - `source.s` (`casm_faultsource`, 4 cases): alloc-no-owner, load-write
    centralized cleanup, retryable span-read failure, refill-sets-ERROR.
  - `symbols.s` (`casm_fsym`, 5 cases): alloc-no-owner, insert-find-failure
    (bump-allocator untouched), insert-write-failure (count unchanged),
    lookup-find-failure (propagated, not silently "not found"),
    read-by-index failure. Found and fixed a real **fixture** bug (not
    production): three cases loaded the fault op-code into `A` via
    `armNextCall` *after* already loading the real `nameLen` argument,
    silently corrupting it to 1 — one case's corrupted call accidentally
    inserted a stray record, which then made an unrelated later case
    "pass" for the wrong reason. Fixed by re-ordering (arm before loading
    call arguments) in all three sites.
  - `reloc.s` (`casm_freloc`, 3 cases): alloc-no-owner, record-write-failure
    (count unchanged, proven via direct VMM readback through the exported
    `CasmRelocVmmSlot`), finalize-read-failure (propagates before ever
    reaching `fileWrite`). Isolated from `emit.s`/`fileio.s`, matching
    `casm_reloc.s`'s own precedent.
  - `include.s` (`casm_finc`, 4 cases): alloc-no-owner, catalog-read
    failure, event-record-write failure (count unchanged, exported
    directly), event-replay-read failure (cursor unchanged, exported
    directly). Deliberately scoped to include.s's directly-exported VMM
    entry points only — `includeCatalogLoad`/`includeCatalogWrite`'s own
    fault coverage is an explicit, recorded deferral (private routine,
    only reachable via the on-miss path, needs the full `source.s`/
    `fileio.s` link chain for marginal additional coverage over
    already-proven read/write shapes).
  Basenames `fsym`/`freloc`/`finc` (not `faultsymbols`/`faultreloc`/
  `faultinclude`) — `fsym` specifically because the obvious name collided
  with `test_casm_faultsource` at the 16-char D64 truncation boundary, the
  same defect class Increment 3 hit; the other two shortened to match for
  naming consistency.
- **Increment 5** (wiring): formally re-checked as one pass, not just
  incrementally. All six fixtures confirmed correctly wired: `test_casm_
  faultinject` stays on `test.d64` (43 blocks free); `test_casm_faultvmm`/
  `faultsource`/`fsym`/`freloc` on `casm_overflow_test.d64` (down to 7
  blocks free — the next Phase 11 fixture needing that disk will need a new
  placement decision); `test_casm_finc` on `casm_listing_test.d64` (149
  blocks free — self-contained, no `sourceLoad`/fixture coupling, matching
  `test_casm_cliderive`/`test_l15release`'s own precedent, since the
  overflow disk had no room left for it). All three disks deleted and
  freshly rebuilt from scratch (not incremental `cc1541` appends); a full
  `cmake --build build` (every target) completed with exit 0.
- **Increment 6** (consolidated live verification): all six fixtures
  re-verified in one pass, each on its own fresh `vice_machine_reset` +
  Command64 reboot — required by a real hazard this increment disclosed
  (see below). `test_casm_faultsource` FAILed on its first run in this pass
  (`.FFF`); investigated immediately rather than accepted, root-caused to
  dispatch method (not a fixture regression — see below), and reproduced
  clean immediately after correcting it.
- **Increment 7** (this document): WP58 walkthrough and completion-approval
  request.

## Two Hazards Disclosed (Neither a Production Bug)

1. **OS_API-vector wedge across fixture runs in one VICE session.**
   `faultInstall` patches `$1001`/`$1002` (the `OS_API` `jmp` target) to
   `faultStubEntry` and never restores it — there is no `faultUninstall`.
   Re-running any fault fixture in the same VICE session without an
   intervening machine reset leaves the vector pointing at the PRIOR run's
   `faultStubEntry` address; the next fixture's own `faultInstall` then
   captures that stale stub as `RealApiVector` and wedges on its first real
   `OS_API` passthrough (confirmed via `vice_registers_get`/
   `vice_disassemble`: PC stuck bouncing at `faultStubEntry`'s own entry).
   Not a fixture defect — a soft reset plus fresh Command64 boot before
   each fixture's dispatch avoids it reliably, and this discipline is now
   recorded for whoever verifies WP59+ fixtures live.
2. **One-shot `9:name` shell dispatch reverts `CurrentDevice` before
   execution.** `shell.asm`'s `sdExt` handler restores `CurrentDevice` to
   `SavedDevice` before jumping to `UserProgStart`, so a fixture doing real
   file I/O (only `casm_faultsource`, via `sourceLoad`) must be dispatched
   with the persistent-drive form (`9:` alone, then the bare command) to
   keep `CurrentDevice` on the disk actually carrying its fixture file.
   The one-shot form is fine for every VMM-only fixture (`faultinject`/
   `faultvmm`/`fsym`/`freloc`/`finc`, none of which call `DOS_OPEN_FILE`).

## Runtime Walkthrough

All six fixtures, live in VICE 3.10, each on a fresh reset + reboot
(Increment 6's consolidated pass):

| Fixture | Disk | Result |
| --- | --- | --- |
| `test_casm_faultinject` | `test.d64` (unit 8) | `........` `CASM FAULTINJECT: PASS` (8/8) |
| `test_casm_faultvmm` | `casm_overflow_test.d64` (unit 9) | `.....` `CASM FAULT VMM: PASS` (5/5) |
| `test_casm_faultsource` | `casm_overflow_test.d64` (unit 9) | `....` `CASM FAULT SOURCE: PASS` (4/4) |
| `test_casm_fsym` | `casm_overflow_test.d64` (unit 9) | `.....` `CASM FAULT SYMBOLS: PASS` (5/5) |
| `test_casm_freloc` | `casm_overflow_test.d64` (unit 9) | `...` `CASM FAULT RELOC: PASS` (3/3) |
| `test_casm_finc` | `casm_listing_test.d64` (unit 8, self-boot) | `....` `CASM FAULT INCLUDE: PASS` (4/4) |

29 cases total across the six fixtures, every one green on this pass.

## Verification Against the Plan's Own Criteria

- Every fixture prints a clean PASS, verified live in VICE, not just
  built. ✓ (table above)
- The refactored `casm_faultinject` reproduces WP57's exact `CASM
  FAULTINJECT: PASS` before any new case was added. ✓ (Increment 1)
- `DOS_ALLOC_MEM`'s two branches independently exercised and correctly
  distinguished. ✓ (`casm_faultvmm`, Increment 3)
- No `src/external/casm/` or `src/command64/` change; no `image_d64`
  (production) content change. ✓ (confirmed via `git diff --stat` against
  `main` for the committed increments, and `git status` for this session's
  uncommitted work — only `tests/src/casm_faultinject*/`, `CMakeLists.txt`,
  and this plan/walkthrough changed)
- Full project build (`cmake --build build`, every target) succeeds clean
  with no errors. ✓ (Increment 5, re-confirmed Increment 6)

## Open Questions Resolution

1. **Per-caller assertions defined per-fixture, not pre-specified.**
   Confirmed as the right call in practice — each module's real
   registry/cursor contract (documented in its own header comments) drove
   the specific invariant each fixture proves, and no two modules needed
   the same shape.
2. **Add alongside existing full-disk fixtures, don't replace.** Followed
   throughout by default — no existing fixture was removed or replaced by
   any WP58 fixture. Never explicitly re-confirmed by the user mid-plan the
   way Open Questions 1 and 3 were; flagging here for explicit sign-off as
   part of this completion approval.
3. **`fileDelete`'s diagnostic behavior resolved during Increment 1's own
   tracing**, not blocking plan approval. Resolved: needs no richer
   canned-return descriptor (see Increment 1 above).

## Stop Conditions — None Triggered

- No per-caller fixture's forced VMM failure surfaced a real,
  undisclosed state-consistency bug — every "failure" encountered
  (`symbols.s`'s A-register clobber, `faultsource`'s dispatch-method
  artifact) was a test-harness or verification-procedure defect, not a
  production defect, and each was disclosed and fixed rather than folded
  in silently.
- `fileDelete` needed no canned-return shape beyond what Increment 1
  already scoped.
- The shared-library extraction never changed `casm_faultinject`'s
  observable behavior.

## Completion Gate

All conditions met and explicitly approved by the user on 2026-08-11:

- Every fixture in the finalized matrix built and passes live in VICE. ✓
- The shared-library refactor is proven behavior-preserving. ✓
- Open Questions 1 and 3 resolved during implementation; the user accepted
  Open Question 2's add-alongside resolution as part of completion approval.
- This walkthrough and WP58 are complete.

No version bump is needed: WP58 changed test infrastructure only, matching
WP57's precedent. CASM remains `0.2.0` build `1260`.
