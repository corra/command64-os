# DEBUG REU and Address Syntax WP7 Detailed Plan

**Status:** Draft, pending approval

**Created:** 2026-08-04

**Parent plan:** `brain/plans/2026-08-03-debug-reu-and-address-syntax.md`

**Work package:** WP7, Integrated Regression and Documentation (final WP)

**Implementation target:** `src/external/debug/debug.s` (version literals only),
`wiki/debug-test-plan.md`/`docs/debug-test-plan.md` (new regression suites),
`wiki/debug-utility.md`/`docs/debug-utility.md` (version-string examples),
`CHANGELOG.md`, `src/external/debug/AGENTS.md` and any other DOX affected,
`brain/task.md`, the parent plan's own closure

**Implementation branch:** `feature/debug-reu-address-wp7` (branched from
`debug` after WP6 merged, commit `ebe2b05`)

## 1. Purpose

WP1-WP6 each shipped and VICE-verified their own slice of the combined
feature (`=` execution syntax for `G`/`T`/`P`; `XA`/`XD`/`XM`/`XS` REU
commands) but validated it only through each work package's own throwaway
plan-doc test matrix — none of that verification was ever folded into
DEBUG's permanent regression suite (`wiki/debug-test-plan.md`, Suites 1-13),
and DEBUG's displayed version has stayed `0.4.0` throughout despite Design
Decision #4 (parent plan Section 4, item 15) calling for a minor version bump
once the *combined* user-facing feature ships. WP7 closes the parent plan by:

1. Formalizing the `=` syntax and REU command family into two new permanent
   regression suites in the test plan document.
2. Running the complete regression (existing Suites 1-13 plus the two new
   suites) under VICE, in both REU-enabled and REU-disabled environments.
3. Bumping DEBUG's version from `0.4.0` to `0.5.0`.
4. Performing the DOX closeout and a final documentation sweep.
5. Producing one combined manual walkthrough and closing the parent plan.

WP7 makes **no command grammar or behavior changes**. Any regression failure
discovered here is a bug report to the user, not a license to silently patch
and expand WP7's scope (Section 3.2).

## 2. Confirmed Baseline

1. `debug` branch is at `ebe2b05` (WP6 merged). DEBUG build 1126: 8,288 code
   bytes, 1,024 relocation points, `MAIN` envelope `$2400` bytes at `$3800`
   (occupied range `$3800-$5C00`, 928 bytes headroom).
2. `wiki/debug-test-plan.md`/`docs/debug-test-plan.md` currently define
   Suites 1-13 (UI/input, hex arithmetic, memory manipulation, registers,
   `G`, version/help, file I/O, disassembly, inline assembler, `T`, `P`, ROM
   safety, exit banking). No suite currently exercises `=` syntax or any `X`
   command — those were verified only in `brain/plans/2026-08-03-debug-reu-
   address-syntax-wp{1,2,3,4,5,6}.md`'s own VICE matrices, which are not
   permanent regression material and are not re-run by future unrelated
   work.
3. `src/external/debug/debug.s:10-12` defines `VERSION_MAJOR="0"`,
   `VERSION_MINOR="4"`, `VERSION_STAGE="0"`, rendered as `DEBUG v0.4.0.<build>`
   (`debug.s:4274` area). Four documentation sites hardcode the illustrative
   string `DEBUG v0.4.0.1101`: `wiki/debug-test-plan.md:23`,
   `docs/debug-test-plan.md:23`, `wiki/debug-utility.md:586`,
   `docs/debug-utility.md:586`. `CHANGELOG.md:1139` records the prior `0.4.0`
   bump as precedent for how a version-bump changelog entry reads.
4. Design Decision #15 (parent plan Section 4) is the only documented reason
   the version has not moved past `0.4.0` since WP1: "Increment DEBUG's minor
   version for the combined user-facing feature" was explicitly deferred to
   this work package, not skipped.
5. REU-enabled VICE testing throughout WP1-WP6 relied on `-reu -reusize 512`
   (or an equivalent persisted VICE setting) per
   `[[reference-vice-checkpoint-verification]]`-adjacent precedent in
   `brain/plans/2026-07-02-code-review-remediation.md:994`. REU-disabled
   testing in that same precedent used the OS's own "not initialized"
   fallback path rather than a raw-state poke, consistent with
   `[[feedback-vice-testing]]`. This session's running VICE instance had no
   `-reu` CLI flag yet still reported an active VMM during WP6 verification,
   meaning REU emulation is enabled by a persisted VICE setting (not CLI
   flags) in the current environment — Increment 3 must confirm the exact
   toggle (`vice_set_setting`/`vice_get_setting`, or a fresh `-reu`-flagged
   launch) before relying on it, not assume the WP6 session's state.
6. No `docs/debug-memory-map.md` or `wiki/debug-memory-map.md` exists in this
   repository despite the parent plan Section 12 aspiring to one; it was
   never created by WP1-WP6 and creating it is a documentation-architecture
   decision beyond WP7's charter of regression + closeout. WP7 does not
   create this file (Section 3.2).
7. `wiki/user-manual.md` and `wiki/programmers-reference.md` were not
   modified by any of WP1-WP6; Increment 5 checks whether either references
   DEBUG's command surface in a way the REU/`=` feature makes stale.

## 3. Scope

### 3.1 Included

- Add **Test Suite 14: Permissive Execution Address Syntax** to
  `wiki/debug-test-plan.md` (mirrored byte-identical to `docs/`), covering
  `G`/`T`/`P` bare vs. `=` forms, whitespace tolerance, and the negative
  grammar from parent plan Section 10.2.
- Add **Test Suite 15: REU Command Family** to the same document, covering
  `XA`/`XD`/`XM`/`XS` lifecycle, registry exhaustion/reuse, page-offset
  parsing, transfer round-trips and boundaries, `Q` cleanup, and the
  REU-disabled fallback, drawn from parent plan Sections 10.3-10.6 and
  WP1-WP6's own verified matrices.
- Execute the full regression (Suites 1-15) under VICE:
  - Once with REU enabled (Suites 1-15 all applicable).
  - Once with REU disabled (Suites 1-13 plus Suite 15's REU-disabled rows
    only; Suite 14 does not depend on REU and is not re-run a second time
    for that reason alone, per Section 6.4).
- Bump `VERSION_MINOR` from `"4"` to `"5"` in `debug.s` (`VERSION_STAGE`
  stays `"0"`), producing `DEBUG v0.5.0.<build>`.
- Update the four hardcoded `DEBUG v0.4.0.1101` illustrative strings to the
  post-bump build's actual `DEBUG v0.5.0.<build>` string.
- Add a `CHANGELOG.md` entry for the version bump, following the `0.4.0`
  bump's precedent (`CHANGELOG.md:1139`).
- Perform the mandatory DOX closeout: re-check `src/external/debug/AGENTS.md`
  for drift (WP6 already added the `MAIN` envelope/`$6000` contract line;
  confirm nothing else changed) and check whether any other `AGENTS.md` in
  the repository references DEBUG's command surface or version.
- Check `wiki/user-manual.md` and `wiki/programmers-reference.md` for stale
  DEBUG capability claims; update only if Increment 5 finds actual drift.
- Produce one combined manual walkthrough exercising `=` syntax, the full
  REU lifecycle, and a real transfer end-to-end, then ask the user to
  confirm it before marking WP7 (and the parent plan) complete.
- Update `brain/task.md`, create/activate the WP7 Taskwarrior task, and mark
  the parent plan document `Status: Implemented` once WP7 is confirmed.

### 3.2 Excluded

- Any change to command grammar, parsing, validation, or transfer behavior.
  A regression failure is reported to the user as a bug, not silently
  patched under WP7's scope.
- Creating `docs/debug-memory-map.md`/`wiki/debug-memory-map.md` (Section
  2, item 6) — flagged as a documentation gap for the user to decide on
  separately, not created here.
- Any of the parent plan Section 13 deferred items (breakpoint lists, `T`/`P`
  repeat counts, REU-aware `D`/`E`/`F`/etc., raw `SegHi:Bank` addressing,
  direct `$DF00-$DF0A` register access, >64KB single allocation, implicit
  base-RAM VMM fallback).
- Further `MAIN` envelope changes (WP6's `$2400` bytes has 928 bytes of
  headroom; a version-string length change of one character does not
  materially affect code size, and no new logic is added).

## 4. New Regression Suite Content

### 4.1 Test Suite 14: Permissive Execution Address Syntax

Add after Suite 13 in `wiki/debug-test-plan.md`. Draws directly from parent
plan Section 10.2 and WP1's own verification
(`brain/plans/2026-08-03-debug-reu-and-address-syntax-wp1.md`).

- **Test 14.1 — Equivalent Valid Forms**: `G 4000`, `G=4000`, `G =4000`,
  `G= 4000`, `G = 4000` all target `$4000` identically (verify via `R` after
  each, or via a temporary checkpoint at `$4000`). Repeat the bare/`=`
  equivalence for `T` and `P` (target `regPC`, not direct execution).
- **Test 14.2 — No-Argument Behavior Unchanged**: bare `G`, `T`, `P` (no
  address) behave exactly as Suites 5, 10, and 11 already establish;
  `=`-syntax is not required and does not appear.
- **Test 14.3 — Negative Grammar**: `G =`, `G ==`, `G =G000`, `G =10000`,
  `G =4000 EXTRA`, `T =4000 02`, `P =4000 02`, `G =0001:0000` all print
  `error`, execute nothing, and leave `regPC`/`currentAddr` unchanged from
  before the command.
- **Pass criteria**: every equivalent form reaches identical target state;
  every negative form is rejected without executing, tracing, or proceeding.

### 4.2 Test Suite 15: REU Command Family

Add after Suite 14. Draws from parent plan Sections 10.3-10.6 and the
verified matrices in `brain/plans/2026-08-0{3,4,5,6}-debug-reu-address-
syntax-wp{1,2,3,4,5,6}.md`.

- **Test 15.1 — Allocation Lifecycle**: `XA 0001` (minimum), `XA 0100` (4KB),
  `XA 1000` (64KB boundary) all succeed with correct `SEG`/`BANK`/`PARA`/
  `PAGES`/`SIZE` fields; `XA 0000` and `XA 1001` are rejected; four
  successive `XA`s fill the registry, a fifth is rejected with the free
  registry-full selector while REU pages remain free; `XD` releases a valid
  handle and is silent on success; repeated `XD` on the same handle is
  rejected; `Q` releases every active allocation and returns to the shell
  cleanly (WP6's own closeout session already demonstrated this in Section
  4).
- **Test 15.2 — Status Reporting**: bare `XS` reports `VMM ACTIVE`/
  `PAGES TOTAL=`/`ALLOC=`/`FREE=` and one row per active DEBUG allocation, or
  `NONE` when the registry is empty; `XS handle` reports one record; invalid/
  inactive/out-of-range handles are rejected before any OS call.
- **Test 15.3 — Page-Offset Parsing**: the equivalence table (`0000==0000:
  0000`, `0FFF==0000:0FFF`, `1000==0001:0000`, `1020==0001:0020`,
  `FFFF==000F:0FFF`) and the malformed-syntax table (`:`, `0001:`, `:0020`,
  `0001::0020`, `0001:1000`, `0010:0000`, `000G:0000`, `0001:000G`,
  `0001:0020X`) from parent plan Section 10.4, all against a real allocation.
- **Test 15.4 — Transfer Round-Trips and Boundaries**: single-byte transfer
  at offset zero and at the final valid allocation byte; a transfer ending
  exactly at allocation capacity; rejection of one byte beyond capacity
  (before DMA); a 256-byte chunk-boundary crossing; a `0000:0FFF`-to-
  `0001:0000` page-boundary crossing; flat/page-relative operand equivalence;
  rejection of `0000:1000` and `000F:0FFF`+length-two; acceptance of
  `000F:0FFF`+length-one only for a 64KB allocation; rejection of zero
  length, invalid direction, missing operands, trailing garbage, and a
  C64-side wrap — all per parent plan Section 10.5. Every successful
  transfer must print the real `XM XFER=xxxx OK` count and be verified
  byte-exact via `D`/`C`, not just "did not error" (WP6's preflight-only
  verification is no longer sufficient now that DMA is real).
- **Test 15.5 — REU-Disabled Environment**: boot with REU disabled; `XS`
  reports `VMM INACTIVE`; `XA` and `XM` fail cleanly with the VMM-unavailable
  selector; `XD` rejects a nonexistent handle without an OS call; ordinary
  `G`/`T`/`P`/`D`/`E`/etc. commands still work; `Q` exits normally with no
  allocations to clean up.
- **Pass criteria**: every positive case succeeds with the documented output
  and, for transfers, byte-exact verified data; every negative case is
  rejected before any OS/DMA call; REU-disabled operation never crashes or
  hangs ordinary DEBUG use.

## 5. Version Bump

1. `src/external/debug/debug.s:11`: `VERSION_MINOR "4"` -> `VERSION_MINOR
   "5"`. `VERSION_MAJOR`/`VERSION_STAGE` unchanged.
2. Build DEBUG; confirm the banner prints `DEBUG v0.5.0.<build>` and that the
   version-literal edit alone does not change code size in any way that
   threatens the `MAIN` envelope (a one-character string constant; expect
   zero or near-zero byte delta).
3. Update the four illustrative `DEBUG v0.4.0.1101` strings (Section 2, item
   3) to the actual post-bump build number observed in step 2, matching the
   existing convention of citing a real build number rather than an
   invented one.
4. Add a `CHANGELOG.md` entry under `### Changed` (or the closest existing
   heading used by the `0.4.0` precedent) noting the bump and its cause: the
   combined `=`-syntax and REU-command feature is now complete.

## 6. Atomic Implementation Increments

### Increment 0: Regression Suite Authoring

1. Draft Test Suite 14 and Test Suite 15 text (Section 4) directly into
   `wiki/debug-test-plan.md`.
2. Copy `wiki/debug-test-plan.md` to `docs/debug-test-plan.md` verbatim
   (existing byte-identical mirror convention).
3. No build required; this is a documentation-only increment.

Exit criterion: both new suites read as concrete, executable procedures with
unambiguous pass criteria, matching the existing Suites 1-13's format.

### Increment 1: Version Bump

1. Apply Section 5's `debug.s` edit.
2. Build `debug`; record the new build number and confirm code size is
   materially unchanged.
3. Update the four illustrative version strings (Section 5, item 3).

Exit criterion: DEBUG reports `v0.5.0.<build>` and every doc example matches
the real build.

### Increment 2: REU-Enabled Full Regression

1. Build `image_d64` and `test_image_d64`.
2. Boot Command64 under VICE with REU enabled (confirm the toggle per
   Section 2, item 5 — do not assume the prior session's state).
3. Run Suites 1-15 in full against DEBUG build from Increment 1.
4. Record any failure as a bug report (Section 3.2) rather than fixing it
   inline; if a failure occurs, stop and ask the user how to proceed before
   continuing WP7.

Exit criterion: Suites 1-15 pass with REU enabled, or every failure is
explicitly reported to the user with no silent scope expansion.

### Increment 3: REU-Disabled Regression

1. Reboot VICE with REU disabled (the confirmed toggle from Increment 2,
   set to the opposite state).
2. Run Suites 1-13 (general regression) and Suite 15's Test 15.5
   (REU-disabled behavior) only — Suite 14 (`=` syntax) does not depend on
   REU state and is not meaningfully re-verified by repeating it.
3. Record any failure the same way as Increment 2.

Exit criterion: ordinary DEBUG operation is unaffected by REU absence, and
`XA`/`XM` fail cleanly per Test 15.5.

### Increment 4: DOX Closeout

1. Re-read `src/external/debug/AGENTS.md`; confirm it still accurately
   describes DEBUG's REU ownership, zero-page contract, and `MAIN` envelope
   after the version bump (expect no further edit — WP6 already updated the
   envelope contract).
2. Grep the repository for other `AGENTS.md` files referencing DEBUG's
   command surface, version, or REU capability; update only genuine drift.

Exit criterion: no DOX file makes a claim about DEBUG that the shipped
`0.5.0` build contradicts.

### Increment 5: Final Documentation Sweep

1. Check `wiki/user-manual.md` and `wiki/programmers-reference.md` for
   DEBUG capability claims made stale by the REU/`=` feature; update only if
   found.
2. Confirm `wiki/debug-utility.md`/`docs/debug-utility.md` (already fully
   updated through WP6) need no further change beyond Section 5's version
   strings.
3. Regenerate `release/docs` and `release/` binaries via the `release`
   CMake target (established convention from WP6's commit).

Exit criterion: no other document in the repository makes a stale claim
about DEBUG's REU/`=`-syntax capability or version.

### Increment 6: Combined Walkthrough and Parent Plan Closure

1. Produce one manual walkthrough covering: `=` syntax equivalence, a full
   `XA`/`XS`/`XM`/`XD`/`Q` lifecycle with a real byte-exact round-trip
   transfer, and REU-disabled fallback behavior — condensing parent plan
   Section 11's fifteen-step walkthrough into one coherent VICE session.
2. Ask the user to confirm the walkthrough.
3. On confirmation: update `brain/task.md`, close the WP7 Taskwarrior task,
   mark the parent plan document's `Status` as `Implemented`, and record
   final closure state in memory.

Exit criterion: user confirms the walkthrough; parent plan is closed.

## 7. Documentation and Tracking

1. Create `wiki/tasks/debug-reu-address-syntax-wp7.md` following the WP1-6
   convention.
2. Create and activate the matching Taskwarrior task via the `task` CLI.
3. Synchronize `brain/task.md`.
4. Record build/regression evidence after each increment.
5. Update `brain/MEMORY.md`/auto-memory on completion, marking the parent
   REU/address-syntax feature fully closed.

## 8. Approval Questions

1. Is formalizing Suites 14-15 into the permanent `wiki/debug-test-plan.md`
   approved, rather than leaving WP1-6's plan-doc matrices as the only
   record?
2. Is the `0.4.0` -> `0.5.0` minor version bump approved as written (Section
   5), including updating the four illustrative version-string doc sites?
3. Is the REU-disabled toggle method (Section 2, item 5 — confirm via
   `vice_get_setting`/`vice_set_setting` or a fresh `-reu`-flagged relaunch,
   not a raw-state poke) approved for Increment 3?
4. If Increment 2 or 3 finds a genuine regression, is "stop and report to
   the user rather than silently fixing under WP7" the correct response
   (Section 3.2), or should minor, obviously-safe fixes be made inline with
   the finding documented afterward?

## 9. Completion Gate

WP7 — and the parent plan — may be presented for user confirmation when:

1. Test Suites 14 and 15 exist in `wiki/debug-test-plan.md`/`docs/debug-
   test-plan.md`, byte-identical between the two.
2. Suites 1-15 pass under VICE with REU enabled; Suites 1-13 plus Test 15.5
   pass with REU disabled; any failure was explicitly reported to and
   resolved with the user, not silently patched.
3. DEBUG reports `v0.5.0.<build>`, and every doc site citing an illustrative
   version string matches a real build.
4. The DOX closeout and final documentation sweep found and fixed (or
   explicitly flagged as out of scope) every stale claim.
5. `image_d64`, `test_image_d64`, and `release` all build clean.
6. A combined manual walkthrough is confirmed by the user.
7. `brain/task.md`, Taskwarrior, and memory reflect WP7 and the parent
   plan's closure.

Do not mark WP7 or the parent plan complete until the user confirms the
walkthrough.
