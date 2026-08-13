# CASM Phase 11 WP63 Verification Walkthrough

Status: Draft, awaiting user's own runtime walkthrough and explicit approval
Branch: `feature/casm-phase11-wp60`
Candidate: CASM `0.2.2` build `1266` (unchanged — this work package's only
production-adjacent change is entirely confined to test-harness sources
under `tests/src/`; CASM's own version/build did not move)

## Scope

WP63 is Phase 11's closing work package: a full regression build, the
first-ever consolidated live-VICE re-run of every `test_casm_*` harness
across all six CASM disk images in one continuous session, and the user's
own runtime walkthrough before Phase 11 is marked done. Per the plan
(`brain/plans/2026-08-12-casm-phase11-wp63-verification-walkthrough-completion-gate.md`),
no new production behavior was planned — WP63 was meant to verify that
WP56-62's changes hold together, not add anything new.

## Deviation From Plan

The plan's own Stop Conditions call for a newly-discovered defect to become
"a separately scoped, separately approved follow-up, not an inline WP63
fix." That happened here, and the user explicitly overrode it: **a
genuine, previously-undetected regression was found during live
verification, and the user directed an inline fix within WP63 rather than
deferring it.** This walkthrough documents that defect, its root cause, the
fix, and its verification as the primary content of WP63's own Completion
Gate evidence — in addition to, not instead of, the consolidated harness
regression the plan asked for.

## Baseline Reconciliation

- WP56-62 confirmed complete across Taskwarrior, `wiki/tasks/casm.md`, and
  `brain/task.md`; UUIDs match the plan's own `depends-on` chain.
- CASM version/build confirmed directly from source: `0.2.2` build `1266`.
- Authoritative harness roster re-derived from `CMakeLists.txt` (not
  assumed from the plan's own estimate): 28 `test_casm_*` targets across
  `test.d64` (6), `casm_overflow_test.d64` (7), `casm_listing_test.d64`
  (15, plus non-`casm_`-prefixed `test_l15release`) — `test_casm_opcodes`
  ships on both `casm_listing_test.d64` and `casm_opcode_test.d64` (counted
  once). `casm_include_test_d64`/`casm_phase10_test_d64` carry only raw
  production fixtures, no dedicated harness.
- Starting revision: git HEAD `33267feb4da381b80debeeec61602d15e0a96075`,
  18,581 code bytes, 2,806 relocation points, all 7 CASM-related image
  md5sums captured before any change.
- A full regression build (`casm` target, all 28 harnesses, all 7 disk
  images) was clean; a subsequent no-change rebuild of `casm` alone left
  `BUILD_CASM` (`1266`) and `casm.prg`'s md5
  (`d50055869f7bc896746d64420520a1ab`) identical before/after.

## Cross-WP Interaction Review

The four checks the plan names were all completed clean (`CLD` ordering,
WP59 fixes vs. WP61 determinism, fault-injection/opcode-boundary test
isolation, WP62 doc accuracy) — one small pre-existing documentation gap
(`includeCatalogInit` missing from `wiki/casm-programmers-reference.md`'s
documented `start:` sequence, predating Phase 11 entirely) was found and
fixed in place, following WP55's own precedent for a stale-doc gap.

## Harness Regression: The Defect

Live regression on `casm_overflow_test.d64`, dispatched in the plan's own
listed order (`test_casm_include`, `test_casm_catalog`, `test_casm_event`,
`test_casm_faultvmm`, `test_casm_faultsource`, ...): `test_casm_faultsource`
produced `.fff` — one pass, three real failures — with **no PASS/FAIL
banner at all**, reproduced identically on 3 separate fresh-boot attempts.
Critically, `test_casm_faultsource` **passed cleanly in isolation** (fresh
boot, dispatched alone, nothing run before it).

**Root cause, established through direct evidence, not inferred:**

1. Bisection (fresh boot, `test_casm_faultvmm` alone, then
   `test_casm_faultsource`) reproduced the failure — narrowing the trigger
   to `test_casm_faultvmm` specifically, not `test_casm_catalog`/`event`.
2. Disassembling the resident code in VICE confirmed `test_casm_faultsource`
   ran to actual completion (its unconditional `DOS_PRINT_STR`/`DOS_EXIT`
   sequence is straight-line code, and the shell returned cleanly) — the
   missing banner was a display-rendering artifact (same class already
   seen with `test_casm_include`), not a crash.
3. A scratch, uncommitted ca65/ld65 diagnostic build (deleted after use,
   never part of the tracked source) instrumented `writeFailureCleansCentrally`
   to dump registers/state at its real (unfaulted) VMM allocation call.
   Live output: `A=$29 C=1 ST=$00 FC=$00 VC=$00` — `A=$29` decodes to
   `CASM_DIAG_VMM_ALLOC_FAILED`, not the `$2B`
   (`CASM_DIAG_VMM_TRANSFER_FAILED`) the test expects. The real,
   *unfaulted* VMM allocation `sourceLoad` performs before ever reaching
   its own targeted fault injection was itself failing.
4. Read the full 4096-byte OS-level VMM Memory Control Table (`VmmMctBase
   = $C000`, `src/command64/vmm.asm`) directly from VICE memory before and
   after `test_casm_faultvmm` ran: byte-identical (`01 01` then 4094 free
   bytes) — ruling out both the CASM-level software registry
   (`CasmVmmRegistry`, confirmed fully reset by `resourcesInit` on every
   case) and real REU/MCT exhaustion.
5. A second scratch probe calling `OS_API` directly (bypassing the
   harness's own `faultInstall`) hit a runaway, stack-consuming loop —
   pointing at the shared `$1000` OS_API dispatch vector itself, not at
   REU/registry state.
6. Confirmed via direct `grep` across every fault-injection harness:
   `casm_faultvmm.s`, `casm_faultsource.s`, `casm_freloc.s`, `casm_finc.s`,
   `casm_fsym.s`, and `casm_faultinject.s` each call `faultInstall`
   (`tests/src/casm_faultinject/faultstub.inc`) exactly once and **never
   call `faultUninstall`** before their own `DOS_EXIT`. `faultInstall`
   patches the fixed, OS-resident `$1000` OS_API vector to redirect
   through that program's own `faultStubEntry`; never restoring it leaves
   `$1000` dangling into that program's now-overwritten memory once the
   next program loads at the same address. Every OS_API call the *next*
   program makes then jumps through that dangling pointer into unrelated
   bytes of its own image — explaining both the spurious `ALLOC_FAILED`
   (garbage that happened to look like a valid diagnostic code) and the
   runaway loop (garbage that happened to be a branch-to-self pattern).
   `casm_flist.s`/`casm_flmeta.s` already show the correct paired
   `faultInstall`/`faultUninstall` pattern; the six single-case harnesses
   above never picked it up. This is a defect introduced whenever each
   harness was originally written across WP57/58, only exposed now because
   WP63 is the first session to run them all back-to-back without an
   intervening reset.

## Fix

Added `jsr faultUninstall` immediately before `DOS_EXIT` in all six
affected harnesses:

- `tests/src/casm_faultinject_vmm/casm_faultvmm.s`
- `tests/src/casm_faultinject_source/casm_faultsource.s`
- `tests/src/casm_faultinject_reloc/casm_freloc.s`
- `tests/src/casm_faultinject_include/casm_finc.s`
- `tests/src/casm_faultinject_symbols/casm_fsym.s`
- `tests/src/casm_faultinject/casm_faultinject.s`

All six `BUILD_TEST_CASM_*` counters incremented via the real CMake
targets (content-hash gate, not hand-edited). Test infrastructure only —
no production CASM source, ABI, diagnostic, or output byte changed.
`CASM`'s own version/build (`0.2.2` build `1266`) is unaffected.

## Post-Fix Verification

**Full regression build**: `cmake --build build` (every target, every
image) exits 0, zero errors. No-change rebuild of `casm` alone stable
(`BUILD_CASM` still `1266`, `casm.prg` md5 unchanged). `git diff --check`
clean.

**Live harness regression, fresh boots, one consolidated pass per disk
image** (all PASS, zero failures):

- `test.d64` (6): `test_casm_pass1`, `test_casm_symbols`,
  `test_casm_reloc`, `test_casm_vmm`, `test_casm_expr` (verified earlier
  in this same session before the regression was found),
  `test_casm_faultinject` (`CASM FAULTINJECT: PASS`, verified post-fix).
- `casm_overflow_test.d64` (7): `test_casm_include` (14/14 cases, known
  display-banner artifact only), `test_casm_catalog`, `test_casm_event`,
  `test_casm_faultvmm`, `test_casm_faultsource` (`CASM FAULT SOURCE:
  PASS` — the exact original failing sequence, re-run fresh, now clean
  with its banner correctly displayed), `test_casm_fsym` (`CASM FAULT
  SYMBOLS: PASS`), `test_casm_freloc` (`CASM FAULT RELOC: PASS`).
- `casm_listing_test.d64` (15 + `test_l15release`), one continuous
  session: `test_casm_listing`, `test_casm_listcap`, `test_casm_map`,
  `test_casm_passcheck`, `test_l15release` (5/5 checks OK, no
  regression), `test_casm_cliderive`, `test_casm_spanread`,
  `test_casm_spancommit`, `test_casm_listwrite`, `test_casm_frame`,
  `test_casm_finc` (`CASM FAULT INCLUDE: PASS`), `test_casm_flist`
  (`CASM FAULT LIST: PASS` — confirms its own already-correct
  `faultInstall`/`faultUninstall` pairing still works unaffected),
  `test_casm_flmeta` (`CASM FAULT META: PASS`), `test_casm_opcodes`,
  `test_casm_bounds`, `test_casm_lexer`.
- `casm_opcode_test.d64` `comp` cross-checks: live on-device `casm
  casmopall.s` / `casm casmreloc1.s` / `casm casmfa2p.s` (each `CASM:
  INPUT VALIDATED`, version banner `CASM V0.2.1266` unchanged) followed
  by `comp <name>.prg <name>.ref` — all three `FILES COMPARE OK`.

All 28 `test_casm_*` targets plus the 3 `comp` cross-checks are now
live-verified in this session, post-fix, with zero failures anywhere.

## Not Yet Done

- Production `/M`/`/L`/`/S`/`/O` end-to-end re-confirmation, determinism
  dual-assembly re-confirmation, and the `CLD`-placement check: the plan's
  own text treats these as re-citations of WP55's and WP61's already-
  established evidence (byte-identity proofs that predate WP63 and are
  unaffected by a test-infrastructure-only fix), not required fresh
  exercises — not independently re-run this session.
- Known-bug re-confirmation (the three disclosed non-critical bugs —
  `fileCreateOutput`'s missing `@0:` marker, the `/L` blank-line artifact,
  the phantom-EOF-byte defect — remaining open, tracked, and disclosed):
  not independently re-checked in this walkthrough; no WP63 action touched
  any of the three, so no re-verification is expected to be necessary, but
  it has not been explicitly re-confirmed in writing here.
- **Not yet git-committed.**
- `brain/KNOWLEDGE.md`'s existing Phase 11 section not yet updated with
  this closing note.
- The user's own runtime walkthrough and explicit completion approval.

## Disclosed Findings Summary

1. **The defect and fix themselves** (above) — the walkthrough's primary
   finding, fully disclosed, fixed, and verified.
2. `test_casm_include`'s final `PASS` banner still does not render on
   screen (14/14 cases confirmed correct via direct screen-byte counting,
   not the banner) — a pre-existing, already-disclosed display artifact,
   not touched by this work.
3. VICE MCP session tooling (checkpoints, single-step, `run_until`) proved
   intermittently unreliable during this investigation — stale register
   reads, delayed reset application, and checkpoints that registered a hit
   but did not reliably halt execution. Full server-process restarts
   (`tools/vice_mcp_start.sh stop`/`start`) recovered a clean, trustworthy
   session each time. Screenshots, bulk memory reads, and `run_until`
   (used carefully, with generous wait times) remained reliable throughout
   — a VICE-testing process note for future sessions, not a product
   finding.
4. VICE's own keyboard-queue mechanism appears to buffer keystrokes across
   a `vice_machine_reset` call on the same server process — queued
   commands from before a reset were observed replaying automatically
   once the machine rebooted. A full server-process restart does not
   exhibit this. Also a process note, not a product finding.

## Completion Gate

Not yet closed. Outstanding before WP63/Phase 11 can be marked complete:

1. This walkthrough's own remaining "Not Yet Done" items above (or an
   explicit user decision to accept them as satisfied by existing
   WP55/61/WP-known-bug evidence).
2. `brain/KNOWLEDGE.md`'s Phase 11 section update.
3. Explicit user approval of the working-tree diff, ideally followed by a
   git commit (not yet made — awaiting instruction).
4. The user's own manual runtime walkthrough and explicit sign-off, per
   this project's established convention.
