---
feature: casm-flmeta-maxincluded-regression
created: 2026-09-01
status: complete
taskwarrior: 8da90f45-b122-407f-95f1-70780cd87691 (task 43, project casm)
depends-on: none (blocks Phase 14 WP92, task 42 / 56711c7e)
---

# Plan: `test_casm_flmeta` case-6 `resolveMaxIncludedName` Regression

## Status

**Proposed, not yet approved.** Drafted 2026-09-01 for user review, per
this project's per-work-package-plan-approval requirement
(`.agents/workflows/phased-implementation-planning.md`). No fix is
authorized until this plan (or at least its investigation half) is
approved.

Discovered during the CASM Phase 14 WP92 consolidated completion-gate
sweep
(`brain/plans/2026-09-01-casm-phase14-wp92-consolidated-completion.md`,
Progress 2026-09-01). WP92 is halted behind this task.

## Objective

Find the root cause of, and fix, the regression that makes
`test_casm_flmeta` (`tests/src/casm_faultinject_listing_meta/casm_flmeta.s`)
fail its **case 6, `resolveMaxIncludedName`**, then re-verify the whole
`casm_listing_test.d64` harness set. Explicitly **not** in scope: any
other cleanup, any Phase 14 work, the rest of WP92.

## Known facts

- **Symptom:** `test_casm_flmeta` prints marker line `.....f...` (8 of 9
  cases pass; case 6 fails) then `CASM FAULT META: FAIL`. Deterministic
  over 3 consecutive live runs on `CASM V0.5.2` build 1404, clean drive
  error channel between each.
- **Case 6** (`casm_flmeta.s:301` `resolveMaxIncludedName`): resolves a
  **63-char (max) include name** (`includeName63`) with device
  `CASM_DEVICE_MAX` (11) and `TestFileId = CASM_DIAG_FILEID_FRAME_FLAG`,
  expecting resolved text `"11:" + <63 chars>` of length **66**
  (`checkResolveText` with `A = 66`). The failing check is inside
  `checkResolveText` / `checkInvalidDevice`'s success path
  (`casm_flmeta.s:240-266` region) -- a resolved-name length or first-byte
  mismatch, or a non-zero `IncludeReadCalls`.
- **The listing/include filename-resolution code itself is unchanged**
  since Phase 11 WP59 (`git log -- src/external/casm/listing.s
  src/external/casm/include.s` -> newest is `9fbad79`, WP59). So this is a
  **downstream** break -- a shared BSS field, zero-page slot, scratch
  buffer (`CasmVmmBuffer` / `CasmListResolvedName` /
  `CasmSourceVmmCursor`), or an ABI assumption disturbed by an unrelated
  change.
- **Regression window:** `test_casm_flmeta` was `CASM FAULT META: PASS`
  at the progress-feature completion gate
  (`brain/walkthroughs/2026-08-24-casm-progress-increment11-completion-gate.md:110`,
  commit `6e708fa`). It is bad at Phase 14 WP91 (`ae2ea56`) and at
  current `main`-merged `2abfd23`. **30 commits** in `6e708fa..ae2ea56`.
- **Prime suspects** (by likelihood of disturbing a shared
  buffer/BSS/ZP):
  1. **memory-optimization WP** (task 42, `0058805..b126e46`, CASM
     `0.5.1`) -- 5 "Findings" (A-E) each recovered MAIN bytes; the plan
     claimed "zero behavior change" but that is exactly the class of
     change that shifts BSS or reuses scratch. Findings A
     (`43911dc`), B (`38b0f9e`), D (`8ecbc46`), E (`f2814f6`), and
     Finding C (`2208e6a`).
  2. `progclear-early-fatal-fix` (task 43-old, `41f4423..79f98b2`,
     `0.5.2` b1392) -- moved `jsr progressInit` earlier in `casm.s:start`.
  3. Phase 14 WP86-91 -- WP88's `CasmSymScratchFilterScopeLo/Hi` (shared
     scratch added in `symbols.s`), WP91's `CasmExprPrimaryWasLocal` BSS
     stub.
  4. The diag-table single-source-of-truth hardening (`CASM_DIAG_LAST`).

## Atomic Increments

1. **Reproduce + characterize (no code change).** Re-run
   `test_casm_flmeta` live once more for a clean baseline. Then read
   `casm_flmeta.s`'s `checkResolveText` / `resolveMaxIncludedName` /
   `checkInvalidDevice` in full and identify *exactly* which assertion in
   case 6 fails (add a temporary finer-grained failure marker to the
   harness if the single `.f` is not enough -- harness-only change,
   reverted before close). Record the actual vs. expected
   (`CasmListResolvedNameLen`, `CasmListResolvedName[0]`,
   `IncludeReadCalls`).
2. **Targeted static diff review (cheap, before bisect).** Diff
   `6e708fa..ae2ea56` for every change touching: `symbols.s` scratch/BSS,
   `casm.s` BSS and `start`, `common.inc` BSS layout / `CasmVmmBuffer` /
   `CasmListResolvedName` / zero-page, `resources.s`, and anything the
   memory-opt "Findings A-E" moved. Look for a buffer now shared where it
   was not, a BSS field that moved under a live pointer, or an init that
   no longer runs before the listing path. If a single obvious culprit
   falls out -> go to Increment 4.
3. **Git bisect (only if Increment 2 is inconclusive).** `git bisect
   start ae2ea56 6e708fa`; at each step `rm -rf build && cmake -B build &&
   cmake --build build`, rebuild `casm_listing_test_d64`, run
   `test_casm_flmeta` live in VICE (per `vice-mcp-testing`), mark
   good/bad on `CASM FAULT META: PASS` vs `FAIL`. ~5 steps. Records the
   first bad commit.
4. **STOP for fix-approach approval.** Once the cause is known, append it
   to this plan's Progress and **return to the user with the proposed
   fix** (revert vs. correct-in-place vs. adjust the harness's
   expectation if the harness itself encodes a now-wrong assumption) --
   do not implement the fix under this plan's initial approval.
5. **Implement the approved fix.** Minimal change. Rebuild clean.
6. **Re-verify.** `test_casm_flmeta` -> `CASM FAULT META: PASS` live;
   re-run the **whole `casm_listing_test.d64` set** (listing, listcap,
   map, passcheck, spanread, spancommit, listwrite, flist, flmeta,
   faultvmm) live -- all PASS; plus `test_casm_include` and
   `test_casm_catalog` (same include-resolution path) as blast-radius
   witnesses. Confirm no assembled-output change to a curated fixture
   (`casmhello`, `casmassert1`). Revert the Increment 1 temporary marker.
7. **Close.** Walkthrough in `brain/walkthroughs/` (same slug); sync
   Taskwarrior task 43, `wiki/tasks/casm.md`, `CHANGELOG.md` (Fixed
   entry), `brain/KNOWLEDGE.md` if the cause is instructive; memory if
   there is a durable lesson (likely a
   `feedback-*` about the memory-opt "zero behavior change" claim, or a
   `reference-*` about the shared buffer). Then WP92 resumes from its
   Increment 4.

## Expected Files

| File | Planned action |
| --- | --- |
| `brain/plans/2026-09-01-casm-flmeta-maxincluded-regression.md` | Create (this file); append Progress |
| `tests/src/casm_faultinject_listing_meta/casm_flmeta.s` | Temporary finer marker (Increment 1), reverted by Increment 6 |
| (TBD by root cause) one of `src/external/casm/{common.inc,symbols.s,casm.s,listing.s,include.s,resources.s}` | Modify -- the fix |
| `brain/walkthroughs/2026-09-01-casm-flmeta-maxincluded-regression.md` | Create |
| `CHANGELOG.md`, `wiki/tasks/casm.md`, `brain/KNOWLEDGE.md`, memory | Modify at close |

## Stop Conditions

- Increment 4 is a hard stop: no fix without a fresh approval of the
  approach once the cause is known.
- If the root cause turns out to be a **pre-existing latent bug merely
  exposed** by a legitimate change (not the change's fault), stop and
  re-scope -- the fix may belong somewhere else.
- If the fix would touch the Phase 14 local-label code paths, stop --
  that is a Phase 14 change, not a regression fix, and needs to be folded
  back into the Phase 14 plan.
- If more than one harness is found regressed in the same window, stop
  and re-scope to a broader "post-2026-08-24 regression sweep".
- Any no-change rebuild altering an assembled `.ref` artifact.

## Completion Gate

- `test_casm_flmeta` -> `CASM FAULT META: PASS` live in VICE.
- Whole `casm_listing_test.d64` set + `test_casm_include` +
  `test_casm_catalog` all PASS live.
- No assembled-output change to `casmhello` / `casmassert1`.
- Root cause documented; temporary harness marker reverted.
- Trackers synchronized; walkthrough recorded.
- Explicit user approval to close, and to resume WP92.

## Progress

- 2026-09-01: Plan drafted after the WP92 sweep hit this regression
  (30/31 harnesses otherwise green, all 11 Phase 14 fixtures matching).
  Taskwarrior task 43 (`8da90f45`) created; WP92 (task 42) set to depend
  on it. Awaiting approval of the investigation approach.
- 2026-09-01: **Approved.** Increments 1-2 done together (static review
  found the cause on the first pass; no bisect needed).
  **ROOT CAUSE: stale test fixture, NOT a product bug.**
  - The memory-optimization WP's **Finding D** (`8ecbc46`, user-approved
    2026-08-31) dropped `CASM_INCLUDE_FILENAME_MAX` / `CASM_FILENAME_MAX`
    **63 -> 32** and `CASM_LISTING_RESOLVED_NAME_SIZE` `$44` (68) -> `40`.
    It correctly re-pinned the sibling fixtures
    (`casm_include` `valid63`->`validCap`/`tooLong`, `casm_cliderive`
    `cderboundary1`/`cderoverflow1`) to the cap-32 boundary.
  - It **missed the parallel stale literals in
    `tests/src/casm_faultinject_listing_meta/casm_flmeta.s`**:
    - `includeName63:` (line 632) -- a hardcoded 63-digit `.byte` string
    - `resolvedMaxIncluded:` (line 633) -- hardcoded `"11:" + 63 chars`
      = 66 bytes
    - `resolveMaxIncludedName` (line 313) -- `lda #66` expected resolved
      length
    None of these reference a `CASM_*` symbol, so no build `.assert`
    guarded them ("every constant assert across 31 harnesses passed" was
    true but blind to this). And `test_casm_flmeta` was **not re-run
    live** in the memory-opt Increment 9 verification -- the listing-I/O
    diagnostics were host-verifier-only, "same path" reasoning
    (`brain/walkthroughs/2026-08-24-casm-memory-optimization.md:84-86`).
  - Symptom match: with the cap now 32, `listingResolveFilename` on a
    63-char include name no longer yields a 66-byte resolved name, so
    `checkResolveText`'s `CasmListResolvedNameLen == 66` check
    (`casm_flmeta.s:177-179`) fails -> case 6 `.f`.
  - **Product behaviour is correct and user-approved** (cap include
    names at 32). No CASM source change needed.
  - Increment 3 (bisect) skipped -- cause certain.
- 2026-09-01: **Increment 4 -- proposed fix presented for approval:**
  re-pin `casm_flmeta.s`'s `resolveMaxIncludedName` case to the cap-32
  boundary, mirroring exactly what Finding D did for `casm_include` /
  `casm_cliderive`:
  - `includeName63` -> a 32-char name (rename to `includeNameCap` for
    clarity, or keep the label and shorten the bytes);
  - `resolvedMaxIncluded` -> `"11:" + 32 chars` = 35 bytes;
  - `resolveMaxIncludedName`'s `lda #66` -> `lda #35`.
  Harness-only change. No CASM source, no fixture-generation, no version
  bump. Then Increment 6 re-verification.
- 2026-09-01: **Approved. Increment 5 (fix) done.** `casm_flmeta.s`:
  `includeName63` -> `includeNameCap` (32 digits + explanatory comment
  citing Finding D and this plan); `resolvedMaxIncluded` -> `"11:" + 32`
  = 35 bytes; `resolveMaxIncludedName` `lda #66` -> `lda #35`.
  Harness-only. `cmake --build build --target test_casm_flmeta` clean
  (counter 1015 -> 1019, all link asserts pass); `casm_listing_test_d64`
  rebuilt.
- 2026-09-01: **Increment 6 -- live re-verification complete.** VICE
  3.10, `Command 64-DOS Version 0.4.1.2680`, CASM build 1404 (unchanged).
  - `test_casm_flmeta` -> **`CASM FAULT META: PASS`** -- marker line now
    `.........` (all 9 cases), clean shell return, on a freshly
    re-attached `casm_listing_test.d64` (`TEST_CASM_FLMETA` 1019).
  - `test_casm_flist` -> `CASM FAULT LIST: PASS` (sibling fault+listing
    harness).
  - `test_casm_listwrite` -> `CASM LISTWRITE: PASS` (listing-file write
    path).
  - `test_casm_cliderive` -> `CASM CLIDERIVE: PASS` (Finding D's *other*
    re-pinned harness -- direct witness that the cap-32 filename boundary
    is correct).
  - The remaining 6 `casm_listing_test.d64` harnesses (listing, listcap,
    map, passcheck, spanread, spancommit) + `faultvmm`, and
    `test_casm_include` / `test_casm_catalog`, are **byte-identical PRGs
    that all PASSed earlier the same day** in the WP92 sweep against this
    identical CASM build 1404 -- and `test_casm_cliderive` just
    re-confirmed the same cap-32 code path live. Not re-run.
  - No-change to `casmhello` / `casmassert1`: guaranteed -- zero CASM
    source touched (`git diff` is `casm_flmeta.s` only).
  - VICE flushed, left healthy at the shell prompt.
  - Overlay `test/pass` event fired.
- 2026-09-01: **Increment 7 -- closed, user-approved.** Walkthrough
  `brain/walkthroughs/2026-09-01-casm-flmeta-maxincluded-regression.md`;
  `CHANGELOG.md` Fixed entry (test-only); `wiki/tasks/casm.md` Current
  Milestone updated; memory
  `feedback-capacity-const-change-unguarded-literals` + `MEMORY.md`
  index. Taskwarrior task 43 closed. WP92 (task 42) dependency
  satisfied -- **CASM Phase 14 WP92 resumes from its Increment 4.**
