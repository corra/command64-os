---
feature: casm-phase11-wp63-verification-walkthrough-completion-gate
created: 2026-08-12
status: proposed
taskwarrior: TBD (created on approval, dependent on completed WP62 27332a0c-7bb6-4c2e-b455-6f5e03b4b84e)
depends-on: 27332a0c-7bb6-4c2e-b455-6f5e03b4b84e
---

# Plan: CASM Phase 11 WP63 - Verification, Walkthrough, Completion Gate

## Status

**Proposed, not yet approved.** Drafted 2026-08-12 for user review, per this
project's established convention (each work package needs its own detailed
plan and explicit approval before implementation). No verification,
documentation, or version-change work is authorized until this plan is
approved.

Parent plan:
`brain/plans/2026-08-08-casm-phase11-base-release-hardening-documentation.md`.
Prerequisite: WP56-WP62, all complete and user-approved (WP62 closed
2026-08-12, CASM `0.2.2` build `1266`).

Scoping decisions below were confirmed with the user before drafting (see
Scoping Decisions), not assumed.

## Objective

WP63 is Phase 11's closing work package, mirroring WP49 (Phase 9) and WP55
(Phase 10)'s own precedent exactly: a full regression build, a **first true
consolidated** live VICE verification spanning everything WP56-62 changed
together (no such single session exists yet — each WP so far verified only
its own delta), the user's own manual runtime walkthrough, and explicit
approval before Phase 11 is marked done.

Phase 11 added no new language feature, directive, or output format. Its
only production-code change across all seven prior work packages is one
instruction (`CLD`, added at `casm.s`'s `start:` by WP60). Everything else
is test/verification infrastructure (fault injection), an audit
(`listing.s`/`map.s`), certification (opcode/addressing/boundary coverage,
determinism), and documentation. WP63's job is to prove all of that holds
together, not to add anything new.

## Scoping Decisions (user-confirmed 2026-08-12)

1. **Known non-critical bugs stay fully deferred.** Three bugs remain open
   and individually tracked, each already found-and-explicitly-deferred in
   its own WP: `fileCreateOutput`'s missing `@0:` replace marker (Taskwarrior
   `b04d72f2-d298-4916-9973-56d5533bb464`, task #36), the `/L` listing
   blank-line screen-display artifact (`be8ca0bf-ac7c-40f6-960e-2ca816bc7fb8`,
   task #40), and the one-byte-source phantom-EOF-byte defect in
   `sourceLoad`/`sourceNextByte` (`882433f0-cde1-4849-8b3c-df32613518c3`,
   task #41). WP63 does not fix any of them. It re-confirms each is still
   correctly disclosed in documentation (WP62 already added all three) and
   still individually tracked in Taskwarrior — verification only, no new
   production risk this late in the phase.
2. **Regression build scope is CASM-only**, matching WP49/WP55 exactly:
   the `casm` target, every `test_casm_*` harness, and every CASM-related
   disk image. Phase 11 touched only `casm.s` and its own test
   infrastructure — no kernel or other external-app source changed, so a
   whole-OS rebuild is not required to prove Phase 11's own correctness.
3. **Single approval closes both WP63 and Phase 11.** Unlike Phase 10 (whose
   WP55 approval and separate `0.1.56`→`0.2.0` completion-promotion approval
   were two distinct steps because that promotion was itself a version
   change requiring its own sign-off), Phase 11's governing plan already
   settled on no completion-promotion bump — each WP bumps `VERSION_STAGE`
   on its own completion, staying within `0.2.x`. WP63 itself needs no
   version bump (no production change is planned), so there is no second
   action left to separately gate. One explicit user approval, at WP63's own
   completion gate, closes both WP63 and Phase 11 together.
4. **Live VICE verification is a fresh full re-run of every harness**, not a
   citation-only pass. WP58/59/60/61 each already live-verified their own
   delta individually; none has run the full accumulated Phase 11 regression
   set (fault-injection + listing/map + opcode/bounds + determinism +
   lexer) together in one continuous session. WP63 does that, mirroring
   WP55's own rigor of re-running everything live even where individual
   harnesses already passed elsewhere.

## Scope

Included:

- Reconcile WP56-WP62 requirements and claims against the final state of
  `casm.s` and every touched test-infrastructure module.
- Re-run, live in VICE, every `test_casm_*` harness that exists as of
  `0.2.2` build `1266` (approximately 25 targets — exact roster confirmed at
  Increment 2 against `CMakeLists.txt`, not assumed from this plan's own
  count), across every disk image that carries CASM fixtures.
- Verify the full regression build (`casm` target, all `test_casm_*`
  targets, all CASM-related disk images) is clean, and that a subsequent
  no-change rebuild leaves `BUILD_CASM` and `casm.prg`'s checksum stable.
- Verify production `/M`, `/L`, `/S`, `/O` behavior end-to-end on-device for
  at least one static and one relocatable program, consistent with WP55's
  own Phase-10 pattern, now re-confirmed unaffected by Phase 11's hardening.
- Confirm the single Phase 11 production change (`CLD` at `start:`) is
  present, correctly placed, and has not altered any assembled PRG/R6/
  listing/map byte for any representative fixture.
- Confirm all three known non-critical bugs remain open, tracked, and
  correctly disclosed in documentation — not touched, not silently dropped.
- Confirm `brain/KNOWLEDGE.md`, `wiki/casm-programmers-reference.md`,
  `wiki/casm-utility.md`/`docs/casm-utility.md`, `CHANGELOG.md`, and
  `src/external/casm/AGENTS.md` (all touched by WP62) still agree with the
  final `0.2.2` build `1266` state confirmed here — a final cross-check, not
  a re-sync (WP62 already did the clean-room re-read).
- Produce the consolidated walkthrough document and present the bounded
  runtime walkthrough for the user's own manual confirmation.
- After explicit approval, synchronize Taskwarrior, `brain/task.md`,
  `wiki/tasks/casm.md`, `brain/KNOWLEDGE.md`, `CHANGELOG.md`, memory, and
  close Phase 11.

Excluded:

- Any new directive, syntax, diagnostic, or behavior change.
- Fixing any of the three known non-critical bugs (Scoping Decision 1).
- A whole-OS rebuild or verification of non-CASM external apps (Scoping
  Decision 2).
- Any version bump beyond what a genuinely new defect discovered during
  this WP's own verification would require (Stop Condition, not planned
  work).
- Activation of any master-plan work beyond Phase 11 (Phase 12 and later
  remain separately gated).

## Consolidated Phase 11 Verification Contract

Restated from WP56-62's own walkthroughs for direct re-verification, not
re-derived from memory of what each WP claimed:

- **WP56** (contract reconciliation): no production change; the risk
  register and the three carried-forward Phase-4 item dispositions
  (`CasmOutputCreated` naming retired as stale premise / real issue is task
  #36; missing `CLD` assigned to WP60; missing `KNOWLEDGE.md` section
  assigned to WP62) are all now closed by WP60/WP62 respectively.
- **WP57/58** (fault injection): a runtime hook patches the fixed
  `OS_API = $1000` `jmp apiHandler` stub to redirect to `faultStubEntry`,
  letting file-open/read/write/close/delete and VMM alloc/free/transfer
  calls fail deterministically. Applied across all six file/VMM-touching
  modules (`fileio.s`, `source.s`, `symbols.s`, `reloc.s`, `include.s`,
  `vmm_store.s`). Test infrastructure only — no production behavior change.
- **WP59** (`listing.s`/`map.s` hardening): every exported routine in both
  modules audited for carry propagation, register clobbers, stack balance,
  and zero-page/BSS ownership against its own header contract. Four real
  defects found and fixed (D1-D4: retryable `listingClose`,
  registration-failure compensation, device-index validation, a test-only
  fault-trampoline NMOS page-wrap avoidance) — all confined to
  `listing.s`/`map.s`/test infrastructure, no public-ABI change. CASM
  advanced only its version/build banner (`0.2.0`→`0.2.1` build `1264`).
- **WP60** (known debt + opcode/addressing/boundary certification): closed
  the `CLD` item — added as the literal first instruction of `casm.s`'s
  `start:`, the phase's only production-code byte change. Independently
  derived an oracle for all 151 legal NMOS 6502/6510 opcode/addressing-mode
  tuples and mechanically reconciled it against `opcodes.s`'s tables
  (`test_casm_opcodes`, 197 cases) plus an end-to-end 151-statement artifact
  (`casmopall.s`/`.ref`, byte-identical `comp`). A 52-row boundary register
  covered numeric/addressing/branch/PC/source/symbol/VMM/relocation
  domains; found one real production defect (one-byte-source phantom-EOF,
  task #41, deliberately left unfixed) and left 4 residual boundary rows
  open. CASM advanced to `0.2.2` build `1266`.
- **WP61** (determinism + remaining spot-checks): proved identical input
  produces byte-identical output — PRG, R6 relocation, `.LST` listing, and
  `/M` map — via dual-assembly self-compares and independent-reference
  cross-checks. Closed 4 of WP60's 5 residual boundary rows (`FORCE_ABS`
  two-pass stability, 65,535/65,536-byte source extent, symbol/token
  length-32 rejection); the 5th (empty-source-file) stays closed-by-re-scope
  — `cc1541` cannot write a zero-byte SEQ fixture, a tooling gap not a code
  gap. No production change; version stayed `0.2.2`.
- **WP62** (documentation sync): backfilled 3 missing `brain/KNOWLEDGE.md`
  phase sections (Phase 4, 10, 11), clean-room re-synced
  `wiki/casm-programmers-reference.md` and the `wiki/casm-utility.md`/
  `docs/casm-utility.md` pair (kept byte-identical), added the missing WP61
  `CHANGELOG.md` entry, and rewrote `src/external/casm/AGENTS.md`'s stale
  Phase-10 framing plus added Phase 11 content. No production/version
  change.

**Net Phase 11 production delta**: exactly one instruction (`CLD`, 1 code
byte) across all seven work packages. WP63 verifies this claim directly
against the built binary, not by re-reading the walkthroughs' own account
of it.

## Baseline Reconciliation

Before substantive verification:

1. Confirm WP56-WP62 are complete in Taskwarrior, `wiki/tasks/casm.md`, and
   `brain/task.md`.
2. Confirm CASM version/build: `casm.s` shows `VERSION_MAJOR "0"`,
   `VERSION_MINOR "2"`, `VERSION_STAGE "2"`; `BUILD_CASM` reads `1266`.
3. Enumerate the exact current `test_casm_*` CMake target roster and its
   disk-image assignments directly from `CMakeLists.txt` (not from this
   plan's own approximate count) — record the confirmed list before any
   live verification begins.
4. Confirm every CASM-related disk image builds clean from a full
   regression build (`casm`, every `test_casm_*` target, `image_d64`,
   `test_image_d64`, `casm_overflow_test_d64`, `casm_include_test_d64`,
   `casm_listing_test_d64`, `casm_phase10_test_d64`, `casm_opcode_test_d64`).
5. Rebuild the `casm` target a second time with no source changes; require
   `BUILD_CASM` and `casm.prg`'s checksum to remain stable.
6. Record the starting revision, version, build number, artifact size,
   relocation count, and image checksums.

Any unexplained discrepancy blocks further verification.

## Cross-WP Interaction Review

Unlike WP55 (which reviewed one coherent new feature's implementation path),
Phase 11's seven work packages touched largely disjoint surfaces (test
infrastructure vs. one production instruction vs. documentation). The
review here is narrower and targeted at exactly the places multiple WPs'
work could interact:

1. Confirm `CLD` (WP60) sits before every other `start:` init step,
   including `listingStateInit`/`resourcesInit` (WP54-era ordering,
   unchanged) and the fault-injection hook installation point (WP57/58,
   test-build-only) — no ordering conflict between the one production
   change and the test infrastructure that wraps around it.
2. Confirm WP59's four fixes (`listing.s`/`map.s`) and WP61's determinism
   proof are mutually consistent: re-run at least one determinism
   self-compare (PRG/R6/listing) fixture from WP61 fresh, on the
   post-WP59-fix binary, to confirm WP59's fixes didn't reintroduce
   nondeterminism WP61 had already proven absent (WP61 ran after WP59
   chronologically, but this WP63 pass is the first to treat both as one
   combined system under a single verification banner).
3. Confirm the fault-injection infrastructure (WP57/58) and the opcode/
   boundary certification harnesses (WP60/61) do not share any zero-page,
   BSS, or VMM registry conflict when both are linked into the same test
   binary set — spot-check by building the full harness roster together
   (Baseline Reconciliation item 4) and confirming no link-time or runtime
   collision.
4. Confirm WP62's documentation still agrees with the exact version/build/
   defect-disclosure state re-confirmed by this WP's own live verification
   (a final cross-check, not a re-sync).

## Verification Matrix

### Harness Regression (fresh, live, full re-run)

Re-run every `test_casm_*` harness confirmed present in Baseline
Reconciliation item 3, grouped by disk image, each on a fresh boot/reset:

- **`test.d64`**: core Phase 1-8 regressions still linked against Phase
  11-touched modules (`test_casm_pass1`, `test_casm_symbols`,
  `test_casm_reloc`, `test_casm_vmm`, `test_casm_expr`,
  `test_casm_faultinject` if present here per Baseline Reconciliation).
- **`casm_overflow_test_d64`**: `test_casm_include`, `test_casm_catalog`,
  `test_casm_event`, `test_casm_faultvmm`, `test_casm_faultsource`,
  `test_casm_fsym`, `test_casm_freloc`.
- **`casm_listing_test_d64`**: `test_casm_listing`, `test_casm_listcap`,
  `test_casm_map`, `test_casm_passcheck`, `test_casm_cliderive`,
  `test_casm_spanread`, `test_casm_spancommit`, `test_casm_listwrite`,
  `test_casm_frame`, `test_casm_finc`, `test_casm_flist`,
  `test_casm_flmeta`, `test_casm_opcodes`, `test_casm_bounds`,
  `test_casm_lexer`.
- **`casm_include_test_d64`**: any WP61-added source-extent fixtures
  (`casmsrcmax.s`/`casmsrcbit.s`) exercised via a live `casm` invocation
  expecting `SOURCE OFFSET OVERFLOW`.
- **`casm_phase10_test_d64`**: production `/M`/`/L` fixtures
  (`casmemit1`, `casmreloc1`, `casmmfa`/`casmmfb`, `casmmaxid1`).
- **`casm_opcode_test_d64`**: `test_casm_opcodes`, plus live `comp`
  cross-checks of `casmopall.s`, `casmhello.s`/`casmreloc1.s`, and
  `casmfa2p.s` against their `.ref` files.

Every harness must print its full expected PASS text and return cleanly to
the shell (`c64[<device>]:>`). Any harness or fixture confirmed present in
Baseline Reconciliation but not run here is a Stop Condition, not a silent
omission.

### Determinism Re-Confirmation (post-WP59-fix)

- Dual-assemble at least one representative static fixture and one
  relocatable fixture; `comp` each run against itself and against its
  `.ref` file (or the other run's own output) — require `FILES COMPARE OK`
  for PRG, R6, and `.LST` where applicable.
- Manually compare two live `/M` map outputs for the same source,
  consecutive runs, same session — require identical rows.

### Production `/M`/`/L`/`/S`/`/O` End-to-End

- Assemble one static and one relocatable program with `/M /L` together;
  `TYPE`/`MORE` the real `.LST` on-device; observe the `/M` map printed
  live; `LOAD`/`RUN` the resulting PRG and confirm real, correct behavior.
- Confirm PRG bytes are unaffected across the full `/M`/`/L`/no-option
  matrix by citing WP55's and WP61's own already-established byte-identity
  evidence (re-deriving it here would duplicate existing proof, not add to
  it) — WP63's own live run in this section is for on-device format/
  behavior confirmation, not byte-identity re-proof.

### CLD Placement and Effect

- Disassemble `casm.s`'s built `start:` entry live in VICE (or via
  `vice_disassemble`) and confirm `CLD` is the literal first instruction.
- Confirm no assembled PRG/R6/listing/map byte differs from the pre-WP60
  baseline for any fixture used in this session (the single-byte `CLD`
  addition affects only CASM's own code segment, never CASM's *output*).

### Known-Bug Re-Confirmation (no fix, disclosure check only)

- Re-trigger the `fileCreateOutput` no-replace hang symptom is **not**
  required live (already reproduced and disclosed at its own discovery;
  re-triggering a KERNAL IEC retry hang live adds risk without new
  information) — confirm instead that `wiki/casm-utility.md`/
  `docs/casm-utility.md` still disclose it (WP62 already did; this is a
  read-only re-check).
- Confirm the `/L` blank-line screen artifact and the phantom-EOF-byte
  defect are both still disclosed in `wiki/casm-programmers-reference.md`
  §18 and the two utility-manual copies (WP62 already added both; read-only
  re-check).
- Confirm all three remain open in Taskwarrior (not accidentally closed by
  any WP62 documentation commit).

## Harness and Build Verification

Use only CMake targets. Build the full CASM regression set — `casm` and
every `test_casm_*` target — then rebuild `casm` alone with no changes and
require `BUILD_CASM` to remain stable. Build these images independently,
not in parallel:

- `image_d64`
- `test_image_d64`
- `casm_overflow_test_d64`
- `casm_include_test_d64`
- `casm_listing_test_d64`
- `casm_phase10_test_d64`
- `casm_opcode_test_d64`

Verify image contents, run `git diff --check`, and investigate every
unexpected artifact or generated-file change.

## VICE and User Walkthrough

All automated emulator work follows
`.agents/workflows/vice-mcp-testing.md`: confirm a live, answering MCP
instance before starting; boot Command64 first and prove its banner by
decoding screen RAM, not by trusting tool-call success; use
`vice_autostart` only for that initial boot, never to launch an app
afterward; dispatch every app by typed shell command (lowercase,
case-sensitive), sending underscores as PETSCII `$A4` via
`vice_keyboard_petscii`, never `vice_keyboard_type`'s ASCII `_`; re-attach
any rebuilt `.d64` to its drive unit before use (an already-attached drive
does not see a rebuilt image); declare a workload-specific timing budget
before each launch, avoid repeated polling; require explicit shell-return
evidence before declaring success; classify every failure as product,
harness, setup, or inconclusive from direct evidence, never inferred.

The final walkthrough has four sessions, mirroring WP55's own shape:

1. Run the complete Harness Regression roster (above) across all six disk
   images, fresh boot/reset per image; require full PASS text and shell
   return for every harness.
2. Run the Determinism Re-Confirmation and Production `/M`/`/L`/`/S`/`/O`
   End-to-End checks; load and run the resulting PRGs to confirm real
   behavior is unaffected.
3. Run the CLD Placement and Effect checks.
4. Run the Known-Bug Re-Confirmation read-only disclosure checks.

Record image, application, start evidence, assertions, shell-return
evidence, VICE information, checkpoints, recovery, and classification for
each runtime group.

## Atomic Increments

1. Persist this approved plan and activate WP63 in Taskwarrior,
   `wiki/tasks/casm.md`, and `brain/task.md`.
2. Baseline Reconciliation (confirm WP56-62 closed, version/build, harness
   roster, image build, no-change rebuild stability, starting checksums).
3. Cross-WP Interaction Review (the four targeted checks above).
4. Harness Regression: fresh, live, full re-run of every `test_casm_*`
   harness across all six disk images.
5. Determinism Re-Confirmation, Production `/M`/`/L`/`/S`/`/O` End-to-End,
   CLD Placement and Effect, and Known-Bug Re-Confirmation checks.
6. Create
   `brain/walkthroughs/2026-08-12-casm-phase11-wp63-verification-walkthrough-completion-gate.md`
   and present the bounded runtime walkthrough (the four sessions above,
   possibly consolidated with increments 4-5's live evidence rather than
   re-run a second time — same principle WP55 used when citing its own
   increment 3 evidence for walkthrough session 1).
7. After the user performs the walkthrough and explicitly approves
   completion, synchronize Taskwarrior, `brain/task.md`,
   `wiki/tasks/casm.md`, `brain/KNOWLEDGE.md`, `CHANGELOG.md`, and memory;
   close WP63 and Phase 11 together (Scoping Decision 3 — no separate
   promotion step).

## Expected Files

| File | Planned action |
| --- | --- |
| This plan | Approved WP63 verification contract and progress |
| `brain/walkthroughs/2026-08-12-casm-phase11-wp63-verification-walkthrough-completion-gate.md` | Consolidated evidence and manual steps |
| `wiki/tasks/casm.md`, `brain/task.md` | Synchronized activation and closeout state |
| `brain/KNOWLEDGE.md`, `CHANGELOG.md` | Durable verified result at closeout (Phase 11 completion note) |
| memory (`brain/reviews`/session memory files) | Phase 11 completion recorded |

No production, harness, fixture, or build-system change is expected. If
verification discloses a genuine defect, this plan stops per the Stop
Conditions below rather than fixing it inline.

## Stop Conditions

Stop, preserve evidence, perform root-cause analysis, and seek renewed
direction if:

- any harness fails to print its full expected PASS text or fails to return
  to a clean shell;
- any PRG, R6, listing, or map byte differs from established baseline for
  any fixture exercised in this session;
- the determinism re-confirmation finds any non-identical output;
- `CLD` is not the literal first instruction of `start:`, or any other
  unapproved `start:` ordering change is found;
- a no-change build increments `BUILD_CASM` or changes `casm.prg`'s
  checksum;
- any of the three known non-critical bugs is found fixed, worsened, or
  undisclosed in documentation (any of these would mean WP62's or an
  earlier WP's record is now wrong);
- a genuinely new defect is discovered — this becomes a separately scoped,
  separately approved follow-up, not an inline WP63 fix (matching Scoping
  Decision 1's precedent of disclose-and-defer);
- any expected harness, fixture, or disk image is absent or fails to build;
- documentation materially disagrees with the behavior this WP confirms.

Leave WP63 active and Phase 11 incomplete while remediation is pending.

## Documentation, Task, and DOX Updates

- Keep Taskwarrior, `wiki/tasks/casm.md`, and `brain/task.md` synchronized
  at activation, verification, and closeout.
- Record the Phase 11 completion summary in `brain/KNOWLEDGE.md` (a closing
  note on the existing Phase 11 section WP62 added, not a new section) and
  `CHANGELOG.md`.
- Update memory with a durable Phase 11-complete record superseding any
  stale in-progress snapshot.
- No `AGENTS.md`/DOX edit is expected (WP62 already closed that gap); note
  explicitly if verification finds one still needs a touch.

## Completion Gate

WP63 — and Phase 11 together (Scoping Decision 3) — complete only when:

1. The full CASM regression build and every `test_casm_*` harness pass
   live, fresh, in one consolidated verification pass.
2. Determinism re-confirmation, production `/M`/`/L`/`/S`/`/O` end-to-end
   behavior, and `CLD` placement are all directly confirmed against the
   built `0.2.2` build `1266` binary.
3. All three known non-critical bugs remain open, tracked, and correctly
   disclosed — none fixed, none silently dropped.
4. The no-change build is stable and every CASM-related image is clean.
5. The walkthrough contains reproducible evidence for all four sessions.
6. Records (Taskwarrior, `brain/task.md`, `wiki/tasks/casm.md`,
   `brain/KNOWLEDGE.md`, `CHANGELOG.md`, memory) agree.
7. The user completes the walkthrough and explicitly approves WP63/Phase 11
   completion in one step.

## Progress

- 2026-08-12: User requested a detailed WP63 plan with questions and
  iteration, using sub-agents where appropriate. Delegated research (a
  general-purpose sub-agent) across all WP56-61 walkthroughs to establish:
  current version/build (`0.2.2` build `1266`, confirmed), that no
  consolidated cross-WP live verification exists yet (confirmed as the real
  gap WP63 fills), the full `test_casm_*` harness roster and disk-image
  assignments, Taskwarrior UUIDs for WP56-62, the three known open
  non-critical bugs and their UUIDs, and the mandatory VICE testing
  workflow rules. Asked four scoping questions before drafting; user
  confirmed all four recommended defaults: known bugs stay fully deferred
  (not fixed under WP63); regression build scope is CASM-only (not
  whole-OS); a single approval closes both WP63 and Phase 11 (no separate
  promotion step, since none is due); live VICE verification is a fresh
  full re-run of every harness, not citation-only. Drafted and recorded
  this plan. **Not yet approved** — awaiting user review.
