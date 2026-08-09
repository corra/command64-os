---
feature: casm-phase11-wp58-apply-fault-injection
created: 2026-08-08
status: approved
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
- **`casm_faultinject_vmm`** (new, mirrors `casm_vmm.s`'s own module
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
`tests/src/casm_faultinject_vmm/casm_faultinject_vmm.s`, one new fixture
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
3. Build `casm_faultinject_vmm`: `vmm_store.s`'s own 4 operations against
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
