---
feature: casm-phase11-wp57-fault-injection-design-spike
created: 2026-08-08
status: complete
taskwarrior: d8b09018-8c17-4c98-8ee7-e32d755952ea
depends-on: 636eddce-4777-4ccb-b79f-0e9903fdd10d
---

# Plan: CASM Phase 11 WP57 - Fault-Injection Infrastructure Design Spike

## Status and Authorization

**Proposed, awaiting approval.** This is a design spike, not an
implementation plan: its job is to converge on one concrete interception
mechanism and prove it works end-to-end on one real fault, not to build
fault-injection coverage for every module. WP58 (applying it across
`fileio.s`/`source.s`/`symbols.s`/`reloc.s`/`include.s`/`vmm_store.s`) gets
its own plan only after this spike closes, per the parent plan's confirmed
sequencing.

Parent plan:
`brain/plans/2026-08-08-casm-phase11-base-release-hardening-documentation.md`.
Prerequisite: WP56
(`brain/plans/2026-08-08-casm-phase11-wp56-contract-reconciliation.md`,
approved 2026-08-08) — this plan is WP56's own final increment.

Baseline: CASM `0.2.0` build `1260`, Phases 1-10 complete.

## Objective

The parent plan names three candidate mechanisms: a test-only build variant
of `fileio.s`/`vmm_store.s`, a link-time substitution, or a runtime hook.
Resolve which one WP58 builds on, by:

1. Finding the actual interception surface (there may be one, or several).
2. Evaluating each candidate against this codebase's real constraints, not
   in the abstract.
3. Prototyping the winning candidate against exactly one fault (a forced
   `DOS_OPEN_FILE` failure on a chosen call) and proving it live in VICE.
4. Only then defining WP58's scope precisely enough to plan it.

## Reconciled Finding: One Universal Interception Point

Traced every file- and VMM-touching call site CASM makes. `fileio.s`
(`DOS_OPEN_FILE`/`DOS_CLOSE_FILE`/`DOS_READ_FILE`/`DOS_WRITE_FILE`/
`DOS_DELETE_FILE`) and `vmm_store.s` (`DOS_ALLOC_MEM`/`DOS_FREE_MEM`/
`DOS_VMM_READ`/`DOS_VMM_WRITE`) both dispatch exclusively through
`jsr OS_API`, where `OS_API = $1000` (`include/ca65/command64.inc:48`).
`source.s`, `symbols.s`, `reloc.s`, and `include.s` hold VMM allocations but
make no direct OS calls of their own — they go through `vmm_store.s`'s
exported routines, so they have no separate interception surface to design
for.

`$1000` is a 3-byte stub (`jmp apiHandler`, `src/command64/api.asm:12-16`)
kept stable specifically so it never needs to move even if the real
dispatcher does — the OS's own comment says as much
(`include/ca65/command64.inc:47`: "every Kick app hardcodes `jsr $1000`.
Use `OS_API` instead."). `apiHandler` itself (`api.asm:43-102`) does `cld`
first, stashes the caller's `X`, then linearly scans `apiFuncTable` for the
function code in `A` and jumps to the matching handler.

**Consequence: every fault this phase needs to inject — file and VMM alike,
across all six target modules — funnels through exactly one fixed address.**
WP58's scope is not six module-specific interception problems; it is one
interception problem at `$1000`, applied with different function-code/
call-ordinal targeting per fixture. This substantially narrows the design
space from what the parent plan's phrasing ("does this live in a test-only
build variant of `fileio.s`/`vmm_store.s`...") suggested.

## Candidate Mechanisms

### A. Runtime hook at `$1000` (recommended candidate)

Before a fault-injection test runs, patch the 3-byte stub at `$1000` from
`jmp apiHandler` to `jmp faultStub`, where `faultStub` is a small new
routine (not a modification of `api.asm` or any CASM module) resident
somewhere in RAM CASM's own build doesn't use. `faultStub` checks a
test-owned control table (function code → armed/not, call-ordinal
countdown, synthesized failure shape) before either returning a canned
failure (set carry, load the configured `A`/`X`/`Y`) or falling through to
the real `apiHandler` unchanged.

- Tests the exact production `casm.prg` and exact production OS — zero
  source diff between what ships and what's under test. This is the
  strongest answer to the parent plan's "does it risk masking a real bug by
  being too permissive" concern: nothing about CASM's or the OS's own
  source changes, so a bug that depends on the literal shipped bytes is
  still exercised.
- Open question (this spike's job): where does `faultStub` physically live?
  `project-os-sub1000-segment-full` (memory) already established that OS
  segments below `$1000` are full — ruled out. CASM's own MAIN envelope
  (`$3900`-`$7BFF` at last measurement, WP50) is fully claimed by CASM
  itself and has only 85 bytes of headroom — too small and too fragile
  (any CASM growth reclaims it). Needs a RAM region neither CASM nor the OS
  claims during a test run — candidate: high memory below `UserProgEnd`
  (`$CFFF` per `build_config.inc`) if CASM's own envelope doesn't reach
  there, or a region the test harness itself owns and loads after CASM but
  before execution starts. This spike's first increment resolves this with
  a real memory-map check, not a guess.
- Arming mechanism: a small loader PRG (test-only, built like any other
  test fixture) that runs before CASM, installs `faultStub` and its control
  table at the resolved RAM address, patches `$1000`, sets the control
  table for the specific fault the fixture wants, then chains into CASM
  exactly as the shell would. VICE MCP tools (`vice_memory_write`,
  `vice_autostart`) can perform/verify this installation and can also arm
  the control table directly via `vice_memory_write` for a scripted test,
  without needing the loader PRG for every case.

### B. Test-only OS build variant (fallback candidate)

A separate CMake target builds `api.asm` with `apiHandler` extended (behind
a build flag, never in `image_d64`/`test_image_d64`) to check the same kind
of control table before dispatching, baked in at build time instead of
patched at runtime.

- Avoids the RAM-placement problem entirely (the variant build controls its
  own layout).
- Real risk, already flagged in the parent plan: a second `apiHandler` body
  can silently drift from production's, and every drift is exactly the
  kind of gap this phase exists to close, not introduce. Mitigate only by
  keeping the diff to a single inserted check at the top of the existing
  routine, never a fork — but that mitigation is itself an ongoing
  discipline cost, not a one-time design decision.
- Candidate only if Increment 1 (memory-map check) shows Candidate A has no
  viable RAM target.

### C. Link-time substitution inside CASM modules (rejected)

Build test-variant `fileio.s`/`vmm_store.s` objects where each `jsr OS_API`
becomes `jsr faultAwareOsApi`.

- Requires editing every call site across the six target modules for the
  test build, meaning the binary under test is not the shipped binary —
  the exact risk the parent plan's own WP57 framing called out by name.
  A bug tied to the literal `jsr OS_API` call-site shape would go
  unexercised. Rejected as a primary candidate; not pursued further unless
  both A and B fail the spike.

## Spike Questions (this WP's actual work)

1. Where can `faultStub` and its control table live without colliding with
   CASM's own envelope, the OS's resident state, or VICE/test-harness
   memory? Requires a real measurement, not the prior baseline's number
   alone (CASM's envelope size varies slightly by build).

   **Resolved 2026-08-08.** Relinked the current `0.2.0` build 1260 object
   files against `build/build_casm_cfg/casm_3900.cfg` (`ld65 --mapfile`,
   unmodified `.o`s): `CODE $3900-$75CA`, `RODATA $75CB-$8177`,
   `BSS $8178-$8D70` — MAIN usage now ends at `$8D70`, only 144 bytes under
   the config's own `$8E00` ceiling (`MAIN: start=$3900, size=$5500`).
   CASM has grown substantially since WP50's pre-Phase-10 baseline
   (`$7BAB` then). Per `wiki/programmers-reference.md`'s documented memory
   map, User Program Space is one contiguous RAM block from
   `UserProgStart` through `$BFFF` (BASIC ROM banked out for the whole
   session, not toggled per-app), and `$C000-$CFFF` is separately reserved
   for the OS's own VMM Memory Control Table — so the window from the MAIN
   ceiling (`$8E00`) up to `$BFFF` (~13KB) is genuine free RAM, contiguous,
   and not claimed by CASM, the OS, or any other resident state. (The
   `HEADER` segment at `$9000` in the same `.cfg` is a linker-bookkeeping
   placeholder for the 2-byte PRG load-address prefix, not a real runtime
   RAM occupant — confirmed by the same placeholder address appearing in
   the unrelated `casm_3800.cfg` variant regardless of that build's actual
   `MAIN` start.)

   **Candidate A is viable.** Recommend the fault-injection loader place
   `faultStub` + control table at a fixed address comfortably clear of the
   current ceiling — e.g. `$A000` (0.5KB clear of `$8E00`, 8KB clear of
   `$C000`) — but do not hardcode that address as a magic number in the
   stub's own source: CASM's MAIN ceiling has moved once already (WP50 to
   now) and has only 144 bytes of headroom left, so a future WP is likely
   to bump `casm_3900.cfg`'s `size=` again. WP58's own plan should have the
   test harness read the real link-map end address at build time (a
   CMake-generated constant, matching how `build_config.inc` already
   generates other build-specific values) and assert it stays below the
   chosen stub address, rather than trusting a number recorded once here.
2. What does the control table need to express? At minimum: function code
   (the `A` value CASM passes), a call-ordinal countdown (fail the 1st vs.
   3rd call to `DOS_WRITE_FILE`, to reach mid-transfer partial-write cases),
   and the synthesized failure shape (carry set, chosen `A`/`X`/`Y`). Confirm
   this is sufficient for the parent plan's named cases (no-REU, OOM,
   missing-device, no-disk, disk-full, partial read/write) before WP58
   commits to it — some of these (no-REU, missing-device) may be states
   `apiHandler`'s real handlers already detect and return correctly, in
   which case fault-injection only needs to force the *return value*, not
   simulate real hardware absence.
3. How is the control table armed per-fixture — a dedicated loader PRG per
   fixture (heavier, but keeps arming logic out of CASM's own test
   harness), or direct `vice_memory_write` from the test script before
   `vice_autostart`/`vice_execution_run` (lighter, but ties fixtures to the
   VICE MCP toolchain rather than a CMake-buildable artifact)? Given
   `reference-vice-true-drive-emulation-is-slow` (memory) already
   establishes that real hardware-timed I/O is expected to be slow, prefer
   whichever option keeps iteration fast during WP58, and record the
   choice's effect on `test_image_d64` generation.
4. What happens to a fault-injected call's own bookkeeping? E.g. a forced
   `DOS_OPEN_FILE` failure must still leave `CasmOutputState`/
   `CasmOutputHandle` exactly as a genuine KERNAL failure would (no
   partial registration) — confirm `faultStub`'s canned failure return is
   indistinguishable from a real one at every calling module's own error
   path, not just at the `OS_API` boundary.

## Scope

Included:

- Resolve Spike Question 1 by direct memory-map inspection (build maps,
  `include/ca65/command64.inc`, current CASM envelope measurement).
- Prototype `faultStub` for exactly one fault: force the *n*-th
  `DOS_OPEN_FILE` call to fail with a chosen diagnostic-equivalent
  carry/`A` return.
- Prove it live: one CASM test fixture that calls `fileCreateOutput`,
  observe (via VICE MCP checkpoints/register reads, per
  `reference-vice-checkpoint-verification`) that the forced failure reaches
  CASM's own `CASM_DIAG_OUTPUT_CREATE_FAILED` path exactly as a genuine
  failure would.
- Record the resolved answers to Spike Questions 2-4 as the frozen contract
  WP58's own plan starts from.

Excluded:

- Fault-injecting any module besides the one proof-of-concept path.
- Any of the parent plan's named failure categories besides a single forced
  create failure (no-REU, OOM, missing-device, no-disk, disk-full, partial
  read/write, close/delete failures — all deferred to WP58).
- Any CASM or OS production source change.
- `image_d64`/`test_image_d64` production content change (a new
  fault-injection-only test target is in scope; the shipping targets are
  not touched).

## Expected Files

New, test-only: a `faultStub` source module (location TBD by Increment 1 —
likely `tests/src/casm_faultinject/` alongside the other `tests/src/casm_*`
fixture directories), one loader/arming mechanism, one proof-of-concept
fixture. Planning: this plan, parent/WP56 cross-references, Taskwarrior.
No `src/external/casm/` or `src/command64/` change.

## Atomic Increments

1. Resolve Spike Question 1: measure current CASM envelope and OS resident
   footprint from a real build/link map; identify a concrete free RAM
   region for `faultStub` + control table, or conclude Candidate A is
   infeasible and fall back to Candidate B.
2. Draft `faultStub`'s minimal design: control-table layout, the
   `$1000`-patch mechanism, and the fallthrough-to-real-`apiHandler` path.
3. Build the one-fault prototype (forced `DOS_OPEN_FILE` failure) and the
   proof-of-concept fixture.
4. Verify live in VICE per `reference-vice-checkpoint-verification`:
   confirm the forced failure is indistinguishable from genuine at
   `fileCreateOutput`'s own boundary (Spike Question 4).
5. Record final answers to Spike Questions 2-4 and the chosen candidate as
   this plan's frozen output.
6. Produce the WP57 walkthrough and request completion approval, gated on
   the user confirming the prototype run.
7. Only after approval, develop WP58's own dedicated plan against the now-
   resolved mechanism — mirrors WP56/WP50's "next WP's plan is this WP's
   own final increment" pattern.

## Verification

- The prototype fault-injection run is demonstrated live in VICE, not just
  asserted: a checkpoint at `fileCreateOutput`'s failure path is hit, with
  the diagnostic/state confirmed to match the genuine-failure contract
  exactly (same diagnostic code, same `CasmOutputState`, no partial
  registry entry).
- A no-fault control run of the same fixture (control table entirely
  disarmed) reproduces today's genuine passing behavior byte-for-byte,
  proving `faultStub`'s fallthrough path is truly a no-op when disarmed.
- No `image_d64`/`test_image_d64` (production) target changes.

## Stop Conditions

- No RAM region can host `faultStub` without colliding with CASM's own
  envelope or OS resident state across realistic CASM builds — fall back to
  Candidate B per this plan's own contingency, don't silently force
  Candidate A.
- The forced failure is distinguishable from genuine failure at any CASM
  module boundary (e.g. a real KERNAL failure leaves different zero-page
  state than `faultStub`'s canned return) — the prototype must be corrected
  or the mechanism reconsidered before WP58 builds on it.
- Arming granularity (Spike Question 3) can't reach the call-ordinal
  precision the parent plan's partial-read/write cases need — stop and
  amend rather than let WP58 discover this mid-implementation.

## Completion Gate

WP57 completes only when: Spike Questions 1-4 are answered with evidence
(not assumption), the one-fault prototype is proven live in VICE with a
control run confirming no regression when disarmed, the user confirms the
demonstration, and WP58's own dedicated plan is drafted and recorded against
the resolved mechanism. No version bump — this WP adds test-only
infrastructure, no production source changes, matching the parent plan's
"each WP bumps `VERSION_STAGE` on its own completion" convention only for
WPs that actually change production source.

**Met 2026-08-08.** User confirmed the live demonstration
(`CASM FAULTINJECT: PASS`) as satisfying the completion gate. WP58's
dedicated plan is drafted as this WP's final increment (see
`brain/plans/2026-08-08-casm-phase11-wp58-apply-fault-injection.md`).

## Progress

- 2026-08-08: Plan drafted as WP56's own final increment, per the parent
  plan's confirmed WP57-first sequencing. Traced every file/VMM call site
  across `fileio.s` and `vmm_store.s` and confirmed all of them — and by
  extension `source.s`/`symbols.s`/`reloc.s`/`include.s`, which hold no
  direct OS calls of their own — funnel through the single fixed
  `OS_API = $1000` stub (`api.asm:12-16`), narrowing WP58's scope to one
  interception point rather than six. Evaluated three candidate mechanisms;
  recommended a runtime hook at `$1000` (Candidate A) as primary, a
  test-only OS build variant (Candidate B) as fallback if RAM placement
  proves infeasible, and rejected link-time CASM-module substitution
  (Candidate C) per the parent plan's own "tests a different binary than
  what ships" concern. Not yet approved; Increment 1 (RAM-placement
  measurement) has not yet run.
- 2026-08-08: Increment 1 complete — see the Spike Questions section above
  for the resolved RAM-placement answer (`$8E00`-`$BFFF` free, Candidate A
  viable). User approved continuing into Increments 2-5 in the same
  session.
- 2026-08-08: Increments 2-4 complete. Built
  `tests/src/casm_faultinject/casm_faultinject.s`: a self-contained harness
  (following `casm_vmm.s`'s precedent of linking a real CASM module —
  `fileio.s` plus `resources.s` — into a standalone fixture) that installs
  `faultStubEntry` by patching the `$1001`/`$1002` operand of the real
  `$1000` `jmp apiHandler` stub, leaving the `jmp` opcode itself untouched.
  The stub mirrors `apiHandler`'s own `cld` and touches only `A`, matching
  its ABI. Because `fileCreateOutput`'s failure path substitutes its own
  `CASM_DIAG_OUTPUT_CREATE_FAILED` unconditionally without reading `OS_API`'s
  returned `A` (traced during WP56), the canned failure return needed no
  synthesized register content beyond `SEC` — confirming Spike Question 4
  for this specific call. Two cases: `controlRunSucceeds` (disarmed,
  real create succeeds) and `armedRunFails` (armed for the next
  `DOS_OPEN_FILE` call, forced failure, verified `CasmOutputState`/
  `CasmOutputCreated` show no partial registration — indistinguishable from
  a genuine failure). Wired into `CMakeLists.txt` alongside `casm_vmm`'s own
  block; built clean (`test_casm_faultinject.prg`, 1,488 code bytes) and
  linked into `test_image_d64` with zero CASM/OS source changes.
  Verified live in VICE (build 1260 `test.d64`, unit 8): dispatched via the
  shell as `test_casm_faulti` (16-char truncated on-disk name — the
  underscore, not a dot, and typed as raw PETSCII byte 164 via
  `vice_keyboard_petscii`, not literal ASCII `_`, matching the WP55
  walkthrough's own prior finding that `vice_keyboard_type` doesn't map
  ASCII underscore correctly for shell dispatch). Screen showed
  `CASM FAULTINJECT: PASS`. Both Increment 4's control and armed cases
  passed against the real, unmodified `fileCreateOutput` under genuine
  `OS_API` dispatch — the mechanism is proven, not just designed.
  Along the way, hit and resolved two live-session issues unrelated to the
  mechanism itself: the VICE MCP server was listening on port 7000, not the
  tool's default assumption; and an initial "stuck screen" during
  `command64` autostart was actually the shell's own boot prompt, not a
  hang.
