---
feature: casm-phase11-wp58-apply-fault-injection
created: 2026-08-08
status: complete
taskwarrior: d297b689-3fba-4e16-81f7-8176b39a07e2
depends-on: d8b09018-8c17-4c98-8ee7-e32d755952ea
---

# Plan: CASM Phase 11 WP58 - Apply Fault-Injection Across File/VMM-Touching Modules

## Status and Authorization

**Approved 2026-08-09.** WP57 (complete) proved the interception
mechanism against exactly one fault (`fileCreateOutput` / `DOS_OPEN_FILE`).
This plan applies it across the parent plan's full named scope: every
module that owns a file handle or VMM allocation, and every disclosed
failure category (`CREATE_FAILED`/`WRITE_FAILED`/`CLOSE_FAILED`/
`DELETE_FAILED`/`SHORT_WRITE`, no-REU/OOM/missing-device/no-disk/disk-full/
partial-read-write).

Parent plan:
`brain/plans/2026-08-08-casm-phase11-base-release-hardening-documentation.md`.
Prerequisite: WP57
(`brain/plans/2026-08-08-casm-phase11-wp57-fault-injection-design-spike.md`,
complete 2026-08-08) — this plan is WP57's own final increment.

Baseline: CASM `0.2.0` build `1260`, Phases 1-10 complete.

## Objective

Close the fault-injection gap WP55 originally disclosed, for real, across
every module the parent plan names — not by re-deriving the mechanism
(WP57 already proved it) but by mapping it precisely onto this codebase's
actual call-site topology, which turns out to be narrower and more uneven
than "six modules, six surfaces."

## Reconciled Findings: The Real Call-Site/Diagnostic Matrix

Traced every `jsr OS_API` call site across all six named modules directly
(not inferred from the parent plan's module list).

### `fileio.s` — 5 operations, WP57 already proved 1 of 5

| Operation | Diagnostic on failure | Proven by WP57? |
|---|---|---|
| `DOS_OPEN_FILE` (`fileCreateOutput`) | `CASM_DIAG_OUTPUT_CREATE_FAILED` (substituted unconditionally; `A` from `OS_API` never read) | **Yes** |
| `DOS_WRITE_FILE` (`fileWrite`) | `CASM_DIAG_OUTPUT_WRITE_FAILED` on carry; `CASM_DIAG_OUTPUT_SHORT_WRITE` when the returned byte count underruns the request (`CasmIoLenLo/Hi` vs `CasmRequestLo/Hi`) | No |
| `DOS_CLOSE_FILE` (`fileClose`) | Caller-supplied diagnostic (`Y` input), substituted unconditionally | No |
| `DOS_DELETE_FILE` (`fileDelete`) | Not yet traced in this plan — same file, needs a line-level check during Increment 1 | No |
| `DOS_READ_FILE` (`fileRead`) | **Reads the OS's returned byte count, not just carry**: on a carry-set failure, a *zero* returned count is treated as `CASM_STREAM_EOF`, a *nonzero* count is `CASM_DIAG_INPUT_READ_FAILED`. A naive carry-only fault (WP57's original shape) would misclassify as EOF. | No — needs the richer canned-return shape below |

### `vmm_store.s` — 4 operations, all newly in scope

| Operation | Diagnostic(s) on failure | Inspects `OS_API`'s returned `A`? |
|---|---|---|
| `DOS_ALLOC_MEM` (`vmmStoreAlloc`) | `CASM_DIAG_VMM_UNAVAILABLE` if `A = VMM_ERR_INVALID` ($02, no REU/uninitialized); `CASM_DIAG_VMM_ALLOC_FAILED` otherwise (covers `VMM_ERR_NOMEM` $01 and a full local registry) | **Yes** — the only operation in the entire fault surface that branches on the OS's specific returned code, not just carry |
| `DOS_FREE_MEM` (`vmmStoreFree`) | `CASM_DIAG_VMM_FREE_FAILED`, substituted unconditionally | No |
| `DOS_VMM_READ` (`vmmWindowRead`) | `CASM_DIAG_VMM_TRANSFER_FAILED`, substituted unconditionally | No |
| `DOS_VMM_WRITE` (`vmmWindowWrite`) | `CASM_DIAG_VMM_TRANSFER_FAILED`, substituted unconditionally | No |

This is the codebase's direct answer to the parent plan's named "no-REU"
and "out-of-memory" cases: they are the *same call* (`DOS_ALLOC_MEM`)
distinguished only by the canned `A` value the fault stub returns —
`VMM_ERR_INVALID` for no-REU, anything else nonzero for OOM/rejected.

### `source.s` / `symbols.s` / `reloc.s` / `include.s` — zero direct `OS_API` calls

None of these four modules call `OS_API` directly. Traced every one of
their `vmmStoreAlloc`/`vmmStoreFree`/`vmmWindowRead`/`vmmWindowWrite` call
sites (source.s: 1 alloc + 1 write + 2 reads; symbols.s: 1 alloc + 1 read +
1 write + 1 read; reloc.s: 1 alloc + 1 write + 1 read; include.s: 1 alloc +
2 reads + 3 writes) — every one propagates `vmm_store.s`'s diagnostic
**unchanged** (`bcs <label> / rts`, no remapping to a module-specific
constant). There is nothing to verify about diagnostic *translation* here,
because none happens. What genuinely needs verification, per module, is
**state cleanup**: does a forced mid-operation VMM failure leave that
module's own registry/index/cursor state consistent, or does it leak a
slot, corrupt a partially-written structure, or leave a stale flag —
exactly the class of defect the happy-path fixtures (which never fail
mid-operation) cannot exercise. This reframes the parent plan's "every
module that owns a file handle or VMM allocation" into concrete per-module
questions rather than a uniform fault-injection task repeated four times.

### `include.s`'s one direct `OS_API` call — excluded, with reason

`includeResolveDevice` calls `DOS_PARSE_PREFIX` directly (device-prefix
string parsing, e.g. stripping `"8:"`). This is pure string parsing, not a
disk/REU/device condition — it has no meaningful "disk full" or "no REU"
failure shape, and forcing it to fail would test a code path with no
real-world trigger. Excluded from this WP's scope; not silently dropped,
recorded here so it isn't rediscovered as a gap later.

## Canned-Failure Shape: Extending WP57's Contract

WP57's prototype needed only `SEC` before `RTS` — sufficient for every
`fileio.s`/`vmm_store.s` operation *except* two, both traced above:

1. **`DOS_READ_FILE`**: the fault stub must also set a nonzero returned
   byte count (`HexValLo`/`HexValHi`, mirroring what `fileRead` copies into
   `CasmIoLenLo`/`CasmIoLenHi`) or the injected failure is silently
   reclassified as EOF, not exercised as `CASM_DIAG_INPUT_READ_FAILED` at
   all.
2. **`DOS_ALLOC_MEM`**: the fault stub must set a specific returned `A`
   (`VMM_ERR_INVALID` for the no-REU case, any other nonzero value for the
   OOM/rejected case) to reach the intended branch in `vmmStoreAlloc`.

The shared fault-injection library (below) extends WP57's control table
with an optional per-arm "canned return" descriptor (a byte count for
reads, a specific `A` for `DOS_ALLOC_MEM`) rather than the single fixed
`SEC`-only shape — every other operation keeps using the plain shape
unchanged.

## Shared Infrastructure: Extracting `faultStub` from the Prototype

WP57's `faultStubEntry`/control table lived inline in
`casm_faultinject.s`. Duplicating that across ~6-10 fixtures would drift
and multiply maintenance cost. Increment 1 extracts it into a shared
include (`tests/src/casm_faultinject/faultstub.inc`, `.include`d by every
fixture below, matching this codebase's existing shared-include convention
for `command64.inc`/`common.inc`), extended with the canned-return
descriptor above. `casm_faultinject.s` itself is refactored to consume the
shared include, proving the extraction changes no behavior (its existing
`CASM FAULTINJECT: PASS` result must be unchanged).

## Proposed Fixture Matrix

- **`casm_faultinject`** (existing, refactored onto the shared include):
  add the remaining 4 `fileio.s` operations — `WRITE_FAILED`/
  `SHORT_WRITE` (two distinct cases against `fileWrite`), `CLOSE_FAILED`,
  `DELETE_FAILED`, and `DOS_READ_FILE`'s EOF-vs-error disambiguation using
  the new canned-byte-count shape.
- **`casm_faultvmm`** (new; collision-safe basename, mirrors `casm_vmm.s`'s own module
  linkage): `vmm_store.s`'s own 4 operations against its own diagnostics —
  including both `DOS_ALLOC_MEM` branches (no-REU via `VMM_ERR_INVALID`,
  OOM via any other rejection).
- **Per-caller state-cleanup fixtures**, one per module, each linking that
  module plus `vmm_store.s` plus the shared fault-injection include
  (matching each module's own existing test harness's linkage exactly, so
  these are new fault-focused siblings, not retrofits of the existing
  large regression harnesses): a forced failure on each of that module's
  own `vmmStoreAlloc`/`vmmWindowRead`/`vmmWindowWrite` call sites, asserting
  the specific state-consistency question identified for that module
  during Increment 2 (registry/slot leak, partial structure, stale flag —
  exact assertions TBD per module, recorded as each fixture is built, not
  assumed here).

## Scope

Included:

- Extract the shared `faultstub.inc` library; refold `casm_faultinject.s`
  onto it with zero behavior change (verified by re-running it).
- `fileio.s`'s remaining 4 operations (5 total including WP57's proven 1).
- `vmm_store.s`'s own 4 operations against its own diagnostics, including
  the no-REU/OOM branch distinction.
- Per-caller state-cleanup fixtures for `source.s`/`symbols.s`/`reloc.s`/
  `include.s`, scoped per Increment 2's findings.
- Recording, per fixture, whether it *adds* coverage alongside any existing
  genuinely-full-disk fixture or is intended to eventually *replace* one —
  an open question below, not assumed.

Excluded:

- `include.s`'s `DOS_PARSE_PREFIX` call (reasoned above).
- `listing.s` — WP55's original disclosed gap, but explicitly owned by
  WP59 (`listing.s`/`map.s` hardening), not this WP, per the parent plan's
  own WP breakdown.
- Any production source change (this WP is test infrastructure only,
  exactly like WP57).
- Missing-device/no-disk as *distinct* fault shapes: traced that every
  `fileio.s`/`vmm_store.s` failure path this WP covers collapses those
  into the same carry-set contract already covered by `CREATE_FAILED`/
  etc. above — no module branches differently for "wrong device" vs
  "generic I/O failure" the way `vmmStoreAlloc` branches for no-REU vs
  OOM, so no separate fixture is needed for them specifically.

## Open Questions For This Review

1. The per-caller state-cleanup fixtures' exact assertions are deliberately
   left TBD per module above rather than guessed now — confirm that's the
   right call (define each as its own fixture is built, informed by that
   module's real registry/cursor contract) rather than fully speccing all
   four before any implementation starts.
2. Should any of this WP's new fault-injected fixtures *replace* an
   existing fixture that currently relies on a genuinely full disk to
   prove a failure path (WP55's disclosed gap), or should they stand
   alongside the existing ones unchanged? Default proposed here: add
   alongside, don't replace — a real full-disk fixture proves the actual
   KERNAL/1541 behavior at least once, which fault-injection (by design)
   never touches; removing it would trade a slower but genuine proof for a
   faster but synthetic one. Confirm or redirect.
3. `fileDelete`'s exact diagnostic-substitution behavior wasn't traced in
   this planning pass (flagged as a gap in the `fileio.s` table above) —
   confirm it's fine to resolve that as part of Increment 1's own tracing
   work rather than blocking this plan's approval on it now.

## Expected Files

New: `tests/src/casm_faultinject/faultstub.inc` (shared library),
`tests/src/casm_faultinject_vmm/casm_faultvmm.s`, one new fixture
directory per caller module (`casm_faultinject_source`,
`casm_faultinject_symbols`, `casm_faultinject_reloc`,
`casm_faultinject_include`, naming TBD to avoid collision with each
module's existing non-fault harness). Modified:
`tests/src/casm_faultinject/casm_faultinject.s` (refactored onto the
shared include, plus the 4 new `fileio.s` cases), `CMakeLists.txt` (one
new `if(TEST_NAME STREQUAL ...)` block per new fixture, matching the
existing convention exactly). No `src/external/casm/` or `src/command64/`
change.

## Atomic Increments

1. Trace `fileDelete`'s diagnostic-substitution behavior (the one gap left
   from this plan's own research) and extract `faultstub.inc` from
   `casm_faultinject.s`'s current inline implementation, extended with the
   canned-return descriptor (byte count for reads, specific `A` for
   `DOS_ALLOC_MEM`). Refold `casm_faultinject.s` onto it; verify
   `CASM FAULTINJECT: PASS` still holds unchanged before adding anything
   new.
2. Add `fileio.s`'s remaining 4 operations to `casm_faultinject.s`:
   `WRITE_FAILED`, `SHORT_WRITE`, `CLOSE_FAILED`, `DELETE_FAILED`, plus
   `DOS_READ_FILE`'s EOF-vs-error disambiguation.
3. Build `casm_faultvmm`: `vmm_store.s`'s own 4 operations against
   its own diagnostics, including both `DOS_ALLOC_MEM` branches.
4. For each of `source.s`/`symbols.s`/`reloc.s`/`include.s`: identify the
   real state-consistency question at each of that module's own VMM call
   sites (informed by reading its registry/cursor contract directly, not
   assumed), build the fixture, and record the specific assertion chosen.
5. Wire every new fixture into `CMakeLists.txt` and `test_image_d64`.
6. Verify every new and refactored fixture live in VICE (per
   `reference-vice-shell-underscore-petscii` for any fixture name
   containing `_`, and `reference-vice-checkpoint-verification` for
   state assertions beyond a screen-printed PASS/FAIL).
7. Produce the WP58 walkthrough and request completion approval.

### Increment 3 Packaging Amendment (Approved 2026-08-09)

`test_casm_faultinject_vmm` collided with the existing fixture after D64's
16-character filename truncation: both became `test.casm.faulti`, replacing
rather than coexisting. The fixture basename is therefore `casm_faultvmm`
(`test.casm.faultv` on disk). Adding that distinct entry then proved
`test.d64` is at its directory-track ceiling (`ERROR: Dir track full`). User
approved preserving every existing `test.d64` entry and packaging
`test_casm_faultvmm` on `casm_overflow_test.d64` instead, matching the
repository's established overflow-image policy. For Increment 3, this
amendment supersedes Atomic Increment 5's general `test_image_d64` placement
requirement; both disk targets must still build clean.

## Verification

- Every fixture prints a clean PASS with `FailCount = 0`, verified live in
  VICE, not just built.
- The refactored `casm_faultinject` reproduces WP57's exact
  `CASM FAULTINJECT: PASS` result before any new case is added — proves
  the shared-library extraction is behavior-preserving.
- For `DOS_ALLOC_MEM`'s two branches specifically: confirm both
  `CASM_DIAG_VMM_UNAVAILABLE` (via `VMM_ERR_INVALID`) and
  `CASM_DIAG_VMM_ALLOC_FAILED` (via any other rejection) are independently
  exercised and correctly distinguished — not just one of the two.
- No `src/external/casm/` or `src/command64/` change; no `image_d64`
  (production) target content change.

## Stop Conditions

- Any per-caller fixture's forced VMM failure surfaces a real, previously
  undisclosed state-consistency bug (as opposed to confirming correct
  cleanup) — stop and disclose immediately, don't fold it silently into
  the fixture as an expected-fail case.
- `fileDelete`'s traced behavior (Increment 1) turns out to need a
  canned-return shape beyond what's already scoped — amend this plan
  before continuing rather than improvising it inline.
- The shared-library extraction changes `casm_faultinject`'s observable
  behavior in any way — stop and fix before adding new cases on top of a
  now-unverified foundation.

## Completion Gate

WP58 completes only when: every fixture in the proposed matrix (as
finalized after this plan's review) is built and passes live in VICE, the
shared-library refactor is proven behavior-preserving, the two `Open
Questions` above are resolved, the user completes a walkthrough, and
explicit completion approval is given. Version bump: `VERSION_STAGE`
bump deferred to whichever WP first changes production source (WP58 itself
does not, matching WP57's own precedent).

## Progress

- 2026-08-08: Plan drafted as WP57's own final increment. Traced the real
  call-site/diagnostic matrix for all 6 named modules directly against
  current source (not inferred): `fileio.s` has 5 operations (WP57 already
  proved 1); `vmm_store.s` has 4, with `DOS_ALLOC_MEM` uniquely branching
  on the OS's returned error code (the concrete mechanism for the parent
  plan's named "no-REU" vs "OOM" cases); `source.s`/`symbols.s`/`reloc.s`/
  `include.s` make no direct `OS_API` calls at all and propagate
  `vmm_store.s`'s diagnostics unchanged, reframing their fault-injection
  need from "diagnostic translation" (there is none) to "state cleanup on
  a forced mid-operation failure" (unverified today). Found two operations
  needing a richer canned-failure shape than WP57's `SEC`-only prototype:
  `DOS_READ_FILE` (needs a faked byte count to avoid being misread as EOF)
  and `DOS_ALLOC_MEM` (needs a specific `A` to reach the intended branch).
  Excluded `include.s`'s lone direct `OS_API` call (`DOS_PARSE_PREFIX`,
  pure string parsing, no disk/REU failure shape) with reasoning recorded
  rather than silently dropped. Not yet approved.
- 2026-08-09: User approved this plan. Increment 1 (trace `fileDelete`'s
  diagnostic-substitution behavior, extract `faultstub.inc`, refold
  `casm_faultinject.s` onto it, and verify `CASM FAULTINJECT: PASS` still
  holds unchanged) is now authorized to begin.
- 2026-08-09: Increment 1 complete. Traced `fileDelete` (`fileio.s:366-376`):
  `fdFailed` substitutes `CASM_DIAG_OUTPUT_DELETE_FAILED` unconditionally on
  carry-set and never reads `OS_API`'s returned `A` -- the identical
  SEC-only shape as `fileCreateOutput`, so it needs no richer canned-return
  descriptor of its own (Open Question 3 resolved: no plan amendment
  needed). Extracted `faultInstall`/`faultStubEntry` and the control table
  into `tests/src/casm_faultinject/faultstub.inc`, extending it with
  `FaultReturnA` (configurable `A` on the canned-failure return, needed by
  `DOS_ALLOC_MEM`'s branch on `VMM_ERR_INVALID` vs. other rejection -- see
  `vsaAllocFailed`, `vmm_store.s:134-143`, which `cmp`s `A` directly with no
  reload) and `FaultSetCount`/`FaultReturnCountLo/Hi` (optional canned
  `HexValLo/Hi` byte count on that same path, needed so `DOS_READ_FILE`'s
  fault isn't misread as EOF by `fileRead`). Both default to 0, reproducing
  WP57's original `SEC`+`A=0` shape exactly for every operation that
  doesn't yet use them. `fileWrite`'s `SHORT_WRITE` case (a carry-CLEAR
  success with an under-count, a different shape entirely) is explicitly
  left out of this descriptor -- deferred to whichever later increment
  first exercises it, not solved speculatively here. Refactored
  `casm_faultinject.s` onto the shared include (net +1 line: the `.include`
  replaces both extracted routines and the control table's `.byte`/`.word`
  declarations); added `faultstub.inc` to `CMakeLists.txt`'s
  `TMP_CA65_SRCS_casm_faultinject` so it participates in the hash-gate and
  per-object `DEPENDS` like every other app-local `.inc`. `cmake --build
  build --target test_casm_faultinject` succeeded clean (build 1002, 1,508
  code bytes, +20 over the pre-refactor 1,488 -- the new descriptor fields
  and the `FaultSetCount` branch in `faultStubEntry`, present but unused by
  Increment 1's own two cases). Full `test_image_d64` also builds clean.
  Live-verified in VICE (`build/test.d64`, unit 8, dispatched as
  `test_casm_faulti` via the shell with the underscore sent as raw PETSCII
  byte 164, per `reference-vice-shell-underscore-petscii`): screen showed
  `CASM FAULTINJECT: PASS` and a clean return to `C64[8]:>`, reproducing
  WP57's exact result -- the shared-library extraction is behavior-
  preserving, as the Verification section requires before Increment 2 adds
  any new case on top of it.
- 2026-08-09: Increment 2 complete. Added opt-in `FaultReturnSuccess` to the
  shared stub for `fileWrite`'s carry-clear short-write shape, retaining the
  carry-set default for all existing cases. Expanded `casm_faultinject` from
  two to eight real-`fileio.s` cases: disarmed create, forced create failure,
  write failure, short write, caller-selected close failure, delete failure,
  zero-byte EOF normalization, and nonzero read failure. The first live run
  printed `......F.` because the EOF fixture left `FaultSetCount` disabled:
  `fileRead` had correctly seeded `HexValLo/Hi` with its one-byte request, so
  the injected carry-set return remained nonzero and correctly selected
  `CASM_DIAG_INPUT_READ_FAILED`. Enabled an explicit canned zero count and
  reran; this was a fixture setup defect, not a production finding. Final
  final build 1005 is 1,919 code bytes with 281 relocation points;
  `test_image_d64` builds clean. Live VICE 3.10 verification over MCP port
  7000 printed `........`, `CASM FAULTINJECT: PASS`, and returned normally to
  `C64[8]:>`. No production source or production image content changed. User
  approved Increment 2 on 2026-08-09.
- 2026-08-09: Increment 3 complete and user-approved. Added collision-safe
  `test_casm_faultvmm`
  (source `tests/src/casm_faultinject_vmm/casm_faultvmm.s`) linking the real
  `vmm_store.s`/`resources.s` with shared `faultstub.inc`. Five cases prove
  `DOS_ALLOC_MEM` returns distinct `CASM_DIAG_VMM_UNAVAILABLE`
  (`VMM_ERR_INVALID`) and `CASM_DIAG_VMM_ALLOC_FAILED` (`VMM_ERR_NOMEM`),
  while rejected `DOS_FREE_MEM`/`DOS_VMM_READ`/`DOS_VMM_WRITE` return their
  expected diagnostics and leave the registry slot owned for retry cleanup.
  Initial full-image integration found the long planned name collided with
  existing `test_casm_faultinject` at D64's 16-character limit; the shortened
  basename fixed that, after which `test.d64` proved its directory track was
  full. Applied the user-approved packaging amendment above: existing
  `test.d64` content remains intact and the new 7-block fixture lives on
  `casm_overflow_test.d64` as `test_casm_faultv` (72 blocks remain). Final
  build 1001 is 1,335 code bytes with 179 relocation points; no-change rebuild
  stable; both disk targets build clean. Live VICE 3.10 verification booted
  Command64 from unit 8, switched to the overflow image on unit 9, printed
  `.....`, `CASM FAULT VMM: PASS`, and returned normally to `C64[9]:>`.
- 2026-08-09: Increment 4 implementation and verification complete, pending
  user acceptance. Added collision-safe `test_casm_faultsource`, covering
  source allocation failure (no owner), load-write failure (file/VMM owners
  retained then centrally cleaned), retryable `sourceReadSpanChunk` failure,
  and `sourceRefill` failure setting source ERROR while preserving cleanup
  ownership. A first run's third-case failure was a harness expectation error
  (`casmcat1` contains ASCII `1`, not `A`); corrected without production
  changes. Final build 1001 is 9,329 code bytes with 1,264 relocations;
  `test_image_d64` and `casm_overflow_test_d64` build clean, with the latter
  carrying `test_casm_faults` and 25 blocks free. A hot-reattach rerun wedged
  during case 2; one workflow-approved soft reset and fresh Command64 boot
  produced `....`, `CASM FAULT SOURCE: PASS`, and `C64[9]:>`. VICE remained
  running throughout.
- 2026-08-10: Increment 4's remaining three modules (`symbols.s`, `reloc.s`,
  `include.s`) completed and live-verified, closing Atomic Increment 4 in
  full.
  - `casm_faultsymbols` (basename shortened to `casm_fsym`: the obvious name
    collided with `test_casm_faultsource` at the D64 16-char truncation
    boundary, the same defect class Increment 3 hit). Five cases against the
    real `symbols.s`/`vmm_store.s`/`resources.s`: `DOS_ALLOC_MEM` (no-owner
    invariant), a chain-walk read failure during `symbolsInsert` (not
    misread as `CASM_DIAG_DUPLICATE_SYMBOL`, no bump-allocator advance), a
    write failure during `symbolsInsert` (count unchanged, proven by a
    retry landing at the expected index), a chain-walk read failure during
    `symbolsLookup` (propagated, not silently "not found"), and a
    `symbolsReadByIndex` read failure. First run found two real fixture bugs
    (not production bugs): three cases loaded the fault function code into
    `A` via `armNextCall` *after* already loading the real `nameLen`
    argument, silently corrupting it to 1 -- one case (`insertFind`)
    accidentally inserted a stray 1-byte record as a side effect, which
    then caused a later case (`lookupFind`) to "pass" for the wrong reason.
    Fixed by arming the fault before loading call arguments in all three
    sites. Build 1002 (1,880 code bytes, 249 relocations); live VICE
    verified on `casm_overflow_test.d64` (unit 9): `.....`,
    `CASM FAULT SYMBOLS: PASS`, `C64[8]:>`.
  - `casm_freloc`: reloc.s's own isolation precedent (CasmPc/CasmPassMode/
    CasmRelocatableMode as this harness's own stand-ins, `fileWrite`
    stubbed, matching `casm_reloc.s`). Three cases: `DOS_ALLOC_MEM`
    (no-owner invariant), a `relocRecord` write failure (count unchanged,
    proven by a retry's table offset read back through the exported
    `CasmRelocVmmSlot`), and `relocFinalize`'s first table-copy-chunk read
    failure (propagates before ever reaching `fileWrite`). Build 1000
    (1,494 code bytes, 215 relocations); live VICE verified on
    `casm_overflow_test.d64`: `...`, `CASM FAULT RELOC: PASS`, `C64[8]:>`.
  - `casm_finc`: include.s's own directly-exported VMM entry points only
    (`includeCatalogInit`/`includeCatalogRead`/`includeEventRecord`/
    `includeEventReplay`) -- deliberately does not link `source.s`/
    `fileio.s`, so `includeCatalogLoad`/`includeCatalogWrite`'s own fault
    coverage is explicitly deferred (private routine, only reachable via
    the on-miss path, would need the full heavy link chain for marginal
    additional coverage over already-proven read/write shapes). Four
    cases: `DOS_ALLOC_MEM` (no-owner invariant), an `includeCatalogRead`
    transfer-window failure, an `includeEventRecord` write failure (count
    unchanged, checked directly via the exported `CasmIncludeEventCount`),
    and an `includeEventReplay` read failure (cursor unchanged, checked
    directly via the exported `CasmIncludeEventCursor`). `casm_overflow_
    test_d64` had only 7 blocks free (too little for this ~9-block PRG,
    after `casm_freloc` landed there first) -- packaged instead on
    `casm_listing_test_d64` (149 blocks free, self-contained, no
    sourceLoad/fixture coupling, matching `test_casm_cliderive`/
    `test_l15release`'s own placement precedent). Build 1000 (2,047 code
    bytes, 284 relocations); live VICE verified self-booted directly from
    `casm_listing_test.d64` on unit 8 (this disk carries `command64`
    itself): `....`, `CASM FAULT INCLUDE: PASS`, `C64[8]:>`.
  - Hit the same OS_API-vector wedge Increment 4's `source.s` fixture first
    disclosed: re-running a fault fixture in the same VICE session without
    an intervening machine reset leaves `$1000`/`$1001` pointing at the
    PRIOR run's `faultStubEntry` (never restored -- there is no
    `faultUninstall`), so the next fixture's own `faultInstall` captures
    that stale stub address as `RealApiVector` and wedges on its first
    real `OS_API` passthrough. Confirmed via `vice_registers_get`/
    `vice_disassemble` (PC stuck bouncing at `faultStubEntry`'s own
    entry). Not a fixture defect -- a soft `vice_machine_reset` plus a
    fresh Command64 boot before each fixture's dispatch avoids it
    reliably, and every case above was reproduced clean after adopting
    that discipline. Worth a durable note for whoever verifies WP59+
    fixtures in the same VICE session.
  - Full project build (`cmake --build build`, all targets) succeeds
    clean; `test_image_d64`, `casm_overflow_test_d64`, and
    `casm_listing_test_d64` all build with no errors. No `src/external/
    casm/` or `src/command64/` (production) source changed -- test
    infrastructure only, per this plan's own scope.
  - Atomic Increment 4 is now fully closed across all four in-scope
    modules (`source.s`, `symbols.s`, `reloc.s`, `include.s`). Remaining
    before WP58 can close: Atomic Increments 5-7 (wire every fixture into
    `test_image_d64`/verify live -- already substantially done
    incrementally above, but not yet formally re-checked as one pass --
    and the WP58 walkthrough/completion-approval request), plus user
    acceptance of Increment 4 itself (still pending, per the prior entry
    above) and of this session's follow-on work.
- 2026-08-10: Atomic Increment 5 (wire every fixture into its disk target,
  per Increment 3's packaging amendment superseding the original literal
  `test_image_d64`-only requirement) formally re-checked as one pass across
  all six WP58 fault-injection fixtures, not just verified incrementally as
  each was built:

  | Fixture | Disk | Blocks | Disk free after |
  | --- | --- | --- | --- |
  | `test_casm_faultinject` | `test.d64` | 10 | 43 |
  | `test_casm_faultvmm` | `casm_overflow_test.d64` | 7 | -- |
  | `test_casm_faultsource` | `casm_overflow_test.d64` | 47 | -- |
  | `test_casm_fsym` | `casm_overflow_test.d64` | 10 | -- |
  | `test_casm_freloc` | `casm_overflow_test.d64` | 8 | 7 |
  | `test_casm_finc` | `casm_listing_test.d64` | 11 | 149 |

  Deleted and freshly rebuilt `test.d64`, `casm_overflow_test.d64`, and
  `casm_listing_test.d64` from scratch (not incremental `cc1541` appends,
  which the WP58 Increment 4 session already learned can mask a stale/
  corrupted prior state) and confirmed every fixture's expected block count
  in each disk's own build-time directory listing. Followed with a full
  `cmake --build build` (every target, no restriction) which completed with
  exit 0 and no errors. `casm_overflow_test.d64` is down to 7 blocks free --
  any further Phase 11 fixture needing that disk will need a new placement
  decision, matching `casm_finc`'s own precedent this increment.
- 2026-08-10: Atomic Increment 6 (live-verify every new and refactored
  fixture) completed as one consolidated pass across all six WP58
  fault-injection fixtures, each on its own fresh `vice_machine_reset` +
  Command64 reboot per the OS_API-vector wedge hazard Increment 4
  disclosed:

  | Fixture | Result |
  | --- | --- |
  | `test_casm_faultinject` | `........` `CASM FAULTINJECT: PASS` (8/8) |
  | `test_casm_faultvmm` | `.....` `CASM FAULT VMM: PASS` (5/5) |
  | `test_casm_faultsource` | `....` `CASM FAULT SOURCE: PASS` (4/4) |
  | `test_casm_fsym` | `.....` `CASM FAULT SYMBOLS: PASS` (5/5) |
  | `test_casm_freloc` | `...` `CASM FAULT RELOC: PASS` (3/3) |
  | `test_casm_finc` | `....` `CASM FAULT INCLUDE: PASS` (4/4) |

  `test_casm_faultsource`'s first run in this pass printed
  `CASM FAULT SOURCE: FAIL` (`.FFF`) -- investigated immediately rather
  than accepted as a fixture regression, since nothing in Increment 5
  touched production or fixture source. Root cause: dispatch method, not
  the fixture. `sourceLoad` allocates VMM first, then does real file I/O
  against the real `casmcat1` fixture on `casm_overflow_test.d64`; the
  one-shot `9:test_casm_faultsource` shell dispatch form loads and runs
  the target but restores `CurrentDevice` to `SavedDevice` (8, per
  `shell.asm`'s `sdExt` handler) *before* jumping to `UserProgStart` --
  so the fixture's own real `DOS_OPEN_FILE` call looked for `casmcat1` on
  `test.d64` (device 8), which doesn't carry that fixture, and every case
  past the alloc-only first one failed for a reason with nothing to do
  with fault injection. `allocFailureLeavesNoOwner` (case 1) passed
  regardless, since it fails at the VMM-alloc step before ever touching a
  file. Switching to the persistent-drive form (`9:` alone, then the bare
  command with no prefix -- `sdExtSwitchDrive`'s own shortcut, matching
  how Increment 4's original verification phrased it as "switched to the
  overflow image on unit 9") reproduced a clean PASS immediately. Every
  fixture doing real file I/O must be dispatched this way; VMM-only
  fixtures (`fsym`/`freloc`/`finc`) are unaffected either way since they
  never call `DOS_OPEN_FILE`, but this pass used the persistent-drive form
  uniformly for consistency.
  Also corrected an oversight the user caught mid-pass: the `c64-overlay-
  api` `testing` state should be triggered before each dispatch, not just
  `success`/`pass`/`fail` after -- the first three fixtures in this pass
  (`faultinject`/`faultvmm`/`faultsource`) were reported without it; every
  fixture from `fsym` onward includes it.
  No production or fixture source changed as a result of this increment
  (the one apparent failure was fully explained by dispatch method, not
  fixed by editing anything). Atomic Increment 6 is closed.
- 2026-08-10: Atomic Increment 7 complete. Produced the consolidated
  WP58 walkthrough at
  `brain/walkthroughs/2026-08-08-casm-phase11-wp58-apply-fault-injection.md`,
  covering all seven increments, the two hazards disclosed (the OS_API-
  vector wedge and the one-shot `9:name` dispatch's `CurrentDevice`
  revert), the full 29-case/6-fixture live-VICE result table, and the
  plan's own Verification/Stop-Condition/Open-Questions criteria checked
  off explicitly. Open Question 2 (add-alongside vs. replace existing
  full-disk fixtures) was followed by default throughout but never
  separately re-confirmed by the user mid-plan the way Open Questions 1
  and 3 were -- flagged in the walkthrough for explicit sign-off alongside
  the completion-approval request itself. Also cleaned up a stray `--help`
  D64 image file accidentally created in the repo root by an earlier
  `cc1541 --help` invocation during this session's own investigation
  (untracked, unrelated to any fixture, removed before this entry).
  Walkthrough is the completion-approval request; awaiting explicit user
  approval before closing WP58/task #40.
- 2026-08-11: User explicitly approved WP58 completion, including the
  add-alongside resolution for Open Question 2. WP58 and Taskwarrior task #40
  are complete. CASM remains `0.2.0` build `1260`; this test-infrastructure
  package changed no production source and requires no version bump.
