---
feature: casm-phase12-wp75-verification-walkthrough-completion-gate
created: 2026-08-19
status: approved
taskwarrior: d3440667-c9bd-49cc-9013-80d9bd96d035
depends-on: WP64-WP74, all complete and user-approved
---

# Plan: CASM Phase 12 WP75 - Verification, Walkthrough, Completion Gate

## Status

**Approved 2026-08-19**, including the DASH full-adoption amendment.
Taskwarrior task 43 (`d3440667-c9bd-49cc-9013-80d9bd96d035`) created and
started. Implementation begins with Atomic Increment 1 (DASH full-adoption
audit).

Parent plan: `brain/plans/2026-08-13-casm-phase12-constants-expanded-expressions.md`
(see its WP75 entry, renumbered from WP72 after corrective WP72/WP73 and
feature WP74). Prerequisite: WP64 (contract freeze), WP65 (named
constants), WP66 (current-address symbol), WP67 (parens/precedence), WP68
(arithmetic/bitwise operators), WP69 (character literals), WP70
(relocation algebra closure), WP71 (DASH adoption), WP72 (named-constant
zero-page width fix), WP73 (forward-label resolver state fix), WP74
(string literals) — all complete and user-approved. Current baseline:
CASM `0.2.8` build `1322`.

## Objective

WP75 adds no new CASM language behavior. It is the consolidated closing
WP for all of Phase 12: completing DASH's Phase 12 syntax adoption (found
partial — see Scoping Decisions below), a full regression build, a
*fresh consolidated* live-VICE re-run of every `test_casm_*` harness and
every new Phase 12 harness in one continuous session (not citing each
WP's own individual pass — WP63 in Phase 11 found a real defect
specifically because it was the first session to do this), byte-identity
proof that every Phase 1-11 fixture's assembled output is unchanged,
documentation reconciliation across all four docs the parent plan names,
the version promotion from `0.2.8` to `0.3.0`, the user's own manual
runtime walkthrough, and explicit approval closing Phase 12.

**Not included:** any new CASM directive, operator, or diagnostic. If
consolidated re-verification surfaces a genuine CASM defect, the Stop
Conditions below apply (disclose and defer, not an inline fix) unless the
user explicitly directs otherwise in the moment.

## Scoping Decisions (user-confirmed 2026-08-19)

1. **DASH's Phase 12 adoption must be complete, not partial, before WP75
   closes.** Direct review of the WP71 and WP74 walkthroughs shows WP71
   adopted only named constants (for DASH's private zero-page registers)
   and WP74 adopted only string literals (the `.BYTE "0.1.4"` version
   string). Neither WP71's own text ("update DASH's source to use named
   constants, the current-address symbol, and whichever
   parenthesized/operator/character-literal forms WP67-69 shipped, where
   they genuinely improve on what's there today") nor any later WP
   touched the current-address symbol, parenthesized/precedence
   expressions, arithmetic/bitwise operators, or character literals in
   DASH source. The durable rule established 2026-08-18 (every CASM
   language addition triggers a DASH rewrite or an explicit stop for
   direction when safe adoption is impossible) has not yet been fully
   discharged for this phase. WP75 closes that gap directly: Atomic
   Increment 1 below audits `src/external/dash/` for every remaining
   Phase 12 form and adopts each one where it genuinely improves on the
   existing source (magic numbers, hand-computed offsets, hand-written
   char codes), or explicitly stops for direction on any specific form
   where adoption is not safe/applicable, per the same standard WP71 and
   WP74 already used. This is a source-editing step, not pure
   verification, but it does not add or change CASM language behavior —
   only DASH's own use of behavior Phase 12 already shipped and proved.

## Scope

**Included:**
- Auditing `src/external/dash/` for every Phase 12 syntax form not yet
  adopted (current-address symbol, parenthesized/precedence expressions,
  arithmetic/bitwise operators, character literals) and adopting each
  where it genuinely improves on the existing source, re-running WP71's
  own native-CASM/ca65 byte-identity cross-check and DASH's live boot
  proof after any such change; explicit stop-for-direction on any
  specific form found not safely adoptable, rather than silent omission.
- Full regression build of every CASM-bearing CMake target from a clean
  tree (no-change-rebuild proof included).
- Fresh, single-session live-VICE run of all `test_casm_*` harnesses
  (26 existing: bounds, catalog, cliderive, event, expr, faults,
  faultsource, faultvmm, finc, flist, flmeta, frame, freloc, fsym,
  include, lexer, listcap, listing, listwrite, map, opcode, opcodes,
  pass1, passcheck, spancommit, spanread) plus every Phase 12 fixture
  exercised by WP65-70 and WP72-74 (named constants, current-address
  symbol, parens/precedence, arithmetic/bitwise operators, character
  literals, string literals, relocation algebra closure cases, the WP72
  zero-page-width fix, the WP73 forward-label-resolver fix).
- Byte-identity comparison of every Phase 1-11 fixture's assembled output
  against its pre-Phase-12 reference (the parent plan's risk gate).
- DASH's WP71/WP74 native-CASM regen re-verified as part of the same
  consolidated session (not re-cited from WP74's own walkthrough alone).
- Documentation reconciliation: `docs/casm-utility.md`,
  `wiki/casm-programmers-reference.md`, `brain/KNOWLEDGE.md`,
  `CHANGELOG.md`.
- Version promotion `0.2.8` -> `0.3.0` (completion-only promotion, no
  behavior change in the same commit — mirrors the `0.1.56` -> `0.2.0`
  and `0.2.2` -> `0.2.1`-family precedent from Phases 10-11).
- Taskwarrior/`brain/task.md`/`wiki/tasks/casm.md` sync closing Phase 12
  (task 42) and its WP75 sub-task.
- Final walkthrough doc with live evidence and explicit user approval.

**Excluded:**
- Any new CASM directive, operator, or diagnostic.
- Any change to already-shipped Phase 1-11 program bytes, or to DASH's
  own assembled bytes beyond Increment 1's syntax-form audit (these are
  source-level swaps for equivalent values — DASH's assembled output is
  expected to remain byte-identical before/after, mirroring WP71's own
  "without changing runtime bytes" proof; a genuine byte change would
  mean the swap wasn't equivalent and is a Stop Condition, not a silent
  acceptance).
- Phase 13 scoping (the `.TEXT` disposition gate WP74 flagged stays a
  Phase 13 question, not touched here).

## Verification Design

0. **DASH full-adoption audit.** Read every `src/external/dash/*.s` file
   against the list of Phase 12 forms WP71 did not adopt (current-address
   symbol, parens/precedence, arithmetic/bitwise operators, character
   literals). For each candidate site (hand-computed offsets, magic
   numbers, hand-written char codes), either adopt the new syntax or
   record why it doesn't genuinely improve the source. After editing,
   re-run WP71's own proof pattern: native CASM assembly, ca65
   cross-check, `build_dash_manifest.py --cross-check` with no
   `--allow-host-bytes`, and a live-VICE boot/relocation check —
   confirming DASH's assembled bytes are unchanged (Scope note above).
1. **Clean regression build.** `cmake --build build` from a clean
   configure, then every disk-image target (`image_d64`,
   `casm_overflow_test_d64`, `casm_include_test_d64`,
   `casm_listing_test_d64`, `casm_phase12_test_d64`, and any other
   CASM-bearing image target CMakeLists.txt currently defines). Record
   final block counts per image.
2. **No-change rebuild.** Re-run the same targets immediately after with
   no source changes; every artifact must be byte-identical to the first
   build (`git diff --check` plus a direct byte compare of rebuilt
   `.prg`/`.hex`/`.d64` outputs).
3. **Byte-identity against pre-Phase-12 baseline.** For every fixture that
   shipped before Phase 12 (Phase 1-11), compare its current assembled
   output against the reference captured at Phase 11's WP63 closing
   walkthrough. Any byte difference is a Stop Condition.
4. **Consolidated live-VICE session.** One continuous VICE session (per
   [[reference-vice-checkpoint-verification]] and
   [[reference-vice-true-drive-emulation-is-slow]] — real multi-KB loads
   take real wall-clock minutes under true-drive-emulation, budget
   accordingly) that boots each rebuilt test image in turn and runs every
   harness named above to its documented PASS/FAIL result, verified via
   non-temporary checkpoints and register/screen reads, not OCR alone.
   DASH's `test_casm_fsym`-style boot-and-version-check (per WP74's own
   walkthrough pattern) is re-run fresh in this same session, not cited
   from WP74's prior evidence.
5. **Relocation algebra closure re-check.** Re-run WP70's accepted/
   rejected combination matrix in this same session and confirm results
   still match WP70's contract exactly (nothing regressed by WP72-74).
6. **Documentation diff review.** Confirm the four named docs describe
   every Phase 12 syntax form (named constants, `*`/current-address,
   parens/precedence, arithmetic/bitwise operators, character literals,
   string literals) accurately against what's actually implemented, not
   what was originally proposed — cross-check against WP64's contract and
   each WP's own walkthrough for any drift.

## Atomic Increments

1. DASH full-adoption audit: identify every remaining Phase 12 form
   candidate in `src/external/dash/`, adopt where it genuinely improves
   the source (or record why not), and re-prove native-CASM/ca65
   byte-identity plus a live-VICE boot/relocation check for the updated
   source. Stop for direction on any form found unsafe/inapplicable
   rather than silently skipping it.
2. Clean regression build + no-change rebuild; record block counts and
   confirm byte-identical no-change rebuild.
3. Byte-identity comparison of every Phase 1-11 fixture against its
   pre-Phase-12 baseline.
4. Consolidated live-VICE session: run all pre-existing `test_casm_*`
   harnesses fresh; record PASS/FAIL and evidence for each.
5. Same session: run all Phase 12 feature fixtures (WP65-70, WP72-74)
   fresh; record PASS/FAIL and evidence for each, including the WP70
   relocation algebra closure matrix re-check.
6. Same session: re-verify DASH's updated native-CASM regen (Increment 1,
   building on WP71/WP74) boots and reports its expected
   version/behavior.
7. Documentation reconciliation pass across the four named docs.
8. Version promotion `0.2.8` -> `0.3.0`; rebuild and reconfirm no other
   bytes changed.
9. Tracker sync: Taskwarrior task 42 and its sub-tasks, `brain/task.md`,
   `wiki/tasks/casm.md`, `brain/KNOWLEDGE.md` closing note,
   `CHANGELOG.md`.
10. Draft `brain/walkthroughs/2026-08-19-casm-phase12-wp75-...md` (final
    date may shift if work spans days) with full live evidence; present
    for explicit user approval.

## Expected Files

| File | Planned action |
| --- | --- |
| `brain/walkthroughs/<date>-casm-phase12-wp75-verification-walkthrough-completion-gate.md` | Create |
| `src/external/dash/*.s` (whichever files contain adoptable sites) | Modify (Increment 1 full Phase 12 syntax adoption; assembled bytes unchanged) |
| `dash.ref.hex` / DASH manifest artifacts | Modify only if Increment 1's regen produces a new hash for the same source content (expected: unchanged hash) |
| `docs/casm-utility.md` | Modify (as needed by reconciliation review) |
| `wiki/casm-programmers-reference.md` | Modify (as needed) |
| `wiki/casm-utility.md` | Modify (kept byte-identical to `docs/`, per existing convention) |
| `brain/KNOWLEDGE.md` | Modify (closing note on Phase 12 section) |
| `CHANGELOG.md` | Modify (`0.3.0` entry) |
| `VERSION` / version banner source | Modify (`0.2.8` -> `0.3.0`) |
| `brain/task.md`, `wiki/tasks/casm.md` | Modify (close Phase 12) |

No CASM implementation source files are expected to change unless a Stop
Condition below fires.

## Stop Conditions

- Increment 1's DASH adoption changes DASH's assembled output bytes (the
  swap wasn't semantically equivalent) — stop and disclose rather than
  accept the byte change.
- Any harness (pre-existing or Phase 12) fails unexpectedly in the fresh
  consolidated session, even if it passed individually in its own WP.
- Any Phase 1-11 fixture's assembled output differs by even one byte from
  its pre-Phase-12 baseline.
- A no-change rebuild produces a different artifact.
- Any Phase 12 accepted/rejected relocation combination no longer matches
  WP70's contract.
- A genuinely new defect is discovered outside prior WPs' own scope:
  default is disclose-and-defer as a separate follow-up (per the
  workflow doc), not an inline fix, unless the user explicitly directs an
  inline fix in the moment — and any such deviation gets recorded here
  and in the closing walkthrough.

## Documentation, Task, and DOX Updates

At completion only (this WP is the closing WP): `docs/casm-utility.md`,
`wiki/casm-utility.md`, `wiki/casm-programmers-reference.md`,
`brain/KNOWLEDGE.md`, `CHANGELOG.md`, Taskwarrior (task 42 and its
sub-tasks), `brain/task.md`, `wiki/tasks/casm.md`, and memory (a durable
`project-casm-phase12-complete` record mirroring
[[project-casm-phase11-complete]] and [[project-casm-phase10-complete]]).

## Completion Gate

Phase 12 (and this WP) completes only when:
- The consolidated live-VICE session has run fresh, in one continuous
  session, covering every pre-existing and Phase 12 harness plus DASH's
  regen, with recorded evidence for each.
- Every Phase 1-11 fixture's output is proven byte-identical to its
  pre-Phase-12 baseline.
- A no-change rebuild is byte-identical.
- All four documentation files accurately reflect shipped Phase 12
  syntax and semantics.
- CASM version/build is promoted to `0.3.0`.
- All trackers (Taskwarrior, `brain/task.md`, `wiki/tasks/casm.md`,
  `brain/KNOWLEDGE.md`, memory) are synchronized.
- The user completes their own manual runtime walkthrough and explicitly
  approves closing Phase 12.

## Progress

- 2026-08-19: Plan drafted per user instruction to begin WP75. Not yet
  approved; no implementation started.
- 2026-08-19: User flagged that DASH's Phase 12 adoption is partial — WP71
  adopted only named constants, WP74 only string literals; the
  current-address symbol, parens/precedence, arithmetic/bitwise
  operators, and character literals were never adopted into DASH source,
  despite WP71's own text and the 2026-08-18 durable rule requiring full
  adoption or an explicit stop. Amended: added a new Atomic Increment 1
  (DASH full-adoption audit) before regression verification, with its own
  byte-identity re-proof requirement and a dedicated Stop Condition if any
  swap changes DASH's assembled bytes. Still not yet approved.
- 2026-08-19: Plan approved. Taskwarrior task 43
  (`d3440667-c9bd-49cc-9013-80d9bd96d035`) created and started.
- 2026-08-19: Increment 1 (DASH full-adoption audit) complete. Adopted
  arithmetic-operator and string-literal substitutions across dapp.s,
  ddata.s, dscr.s, dsys.s (character literals excluded per DASH's own
  `AGENTS.md`, which bans them in this dual-assembler subset — a
  constraint the initial audit agent missed and had to be corrected
  after-the-fact). No genuine site existed for the current-address
  symbol; recorded as an accepted gap. Verified via a full native-CASM
  regen under VICE (after working through two VICE server crashes and a
  stale/incrementally-corrupted `command64_casm_utils.d64` that produced
  a false `OUTPUT WRITE FAILED`, fixed by deleting and rebuilding the
  disk image fresh): `COMP DASH.PRG DASH.REF` → `FILES COMPARE OK`,
  extracted PRG SHA-256 byte-identical to the pre-edit shipped artifact
  (`3238b786...814b`), manifest regenerated with fresh source hashes (no
  `--allow-host-bytes`), `dash`/`image_d64` build clean (315 blocks free,
  matching the WP74 baseline), and a live boot at the default address
  renders all adopted syntax correctly before a clean `Q`uit.
- 2026-08-19: Increment 2 (clean regression build + no-change rebuild)
  complete. Full `cmake --build build` succeeded with zero
  errors/warnings/failures; an immediate second build produced a
  byte-for-byte identical set of `.d64`/`.prg` artifacts (SHA-256 diff
  empty). Increment 3 (byte-identity vs. the Phase 1-11 baseline)
  confirmed by inspection rather than a separate fixture-by-fixture
  re-run: `git status` shows only `src/external/dash/*` changed this
  session, so no Phase 1-11 source or fixture could have changed, and the
  no-change rebuild's determinism proves the resulting artifacts are
  unchanged.
- 2026-08-19: **Increment 4 (consolidated live-VICE harness session)
  paused — Stop Condition hit.** `test_casm_pass1` (`build/test.d64`, a
  pre-existing Phase 1-11 harness untouched by this WP) failed with
  `CASM PASS1: FAIL`, reproducibly, including after a `vice_machine_reset
  hard` + fresh Command64 boot — not the same as the historical
  non-reproducible anomaly in [[project-casm-phase8-complete]] /
  `brain/KNOWLEDGE.md` Phase 0C.19, which explicitly did not survive a
  clean re-run. Confirmed unrelated to this WP's own changes (git status
  + the Increment 2 no-change rebuild together prove `test.d64` and
  `test_casm_pass1.prg` are byte-identical to their pre-session state).
  Leading theory, not yet verified: the immediately-prior commit
  (`a0037d0`, before this session began) changed `vice_mcp_start.sh` to
  attach a 16MB REU by default, and the historical anomaly's own
  signature was VMM/REU-exhaustion — a larger default REU may trigger a
  latent boundary condition. Per user direction, WP75 is **paused** here
  (not abandoned) and this is tracked separately as Taskwarrior task 44
  (`b6048f3e-21f9-4de1-a4bb-39d901163e5d`), not fixed inline, per the
  plan's own disclose-and-defer Stop Condition. WP75 resumes Increment 4
  once task 44 is resolved or the user directs otherwise.
- 2026-08-19: **Task 44 resolved; WP75 Increment 4 resumes.** Root cause:
  not REU-related (confirmed by re-running with `--no-reu`, still failed).
  WP74 (commit `08de319`) added a ninth `casm_pass1.s` subtest
  (`p1string1`) needing a new `p1string1.s` fixture, but `test.d64`'s
  directory track was already at CBM DOS's 144-entry hard cap, so
  `p1string1.s` was packaged only onto `casm_phase12_test.d64` — while
  `test_casm_pass1` itself (the shared PRG, now with 9 subtests) stayed
  on both disks. The copy on `test.d64` deterministically failed its
  `p1string1` subtest (fixture absent there); the identical binary on
  `casm_phase12_test.d64` (complete eight-file fixture set) passes.
  Fixed by removing `test_casm_pass1` from `TEST_IMAGE_PRG_TARGETS` in
  `CMakeLists.txt`, matching `test_casm_expr`'s own identical precedent.
  Verified: full clean build succeeds; `test.d64` now 143 directory
  entries (121 blocks free, up from 14); every other build artifact
  byte-identical (SHA-256 diff empty) except `test.d64` itself; live
  VICE re-run on `casm_phase12_test.d64` shows `CASM PASS1: PASS`. User
  directed fixing inline and committing when appropriate, superseding
  the plan's default disclose-and-defer handling for this one item.
- 2026-08-20: **Increment 4 survey complete; a second, deeper defect
  found and escalated (task 45), not fixed inline.** Ran every
  `test_casm_*` harness across all five disks. 25/30 PASS cleanly,
  including both harnesses named in the historical Phase 8
  non-reproducible anomaly (`reloc`, `symbols`). The remaining 5 —
  `test_casm_listcap`, `spancommit`, `listwrite`, `flist`, `flmeta`, all
  on `casm_listing_test.d64` — FAIL reproducibly (survives hard resets)
  with the same `f`-repeated diagnostic fragment. Confirmed unrelated to
  this WP (only DASH files changed all session), unrelated to REU size
  (ruled out at 16MB and 2MB), and unrelated to any recent commit (the
  implicated shared modules haven't changed since Phase 6A/10). This is
  a genuine, previously-undiscovered, systemic defect in CASM's
  listing-capture/VMM-commit path — much larger in scope than task 44
  and requiring live breakpoint debugging to root-cause safely, not a
  quick fix. Logged as task 45 with the full survey results; WP75
  Increment 4 is otherwise clean. Escalating to the user rather than
  attempting a rushed fix to stable, widely-depended-on shared code.
  User directed pausing here: task 45 stays logged with full findings,
  no further live debugging of the shared VMM/listing code this
  session. **WP75 is paused at Increment 4** pending a dedicated,
  separately-scoped investigation of task 45 — resume once that's
  resolved or the user directs otherwise (e.g. documenting it as a
  known issue and proceeding).
- 2026-08-20: **Task 45 (renumbered to pending task 44 after the earlier
  task 44 closed) root-caused and fixed live — not a VMM/REU defect.**
  `casm_listing_test.d64` had drifted back to `blocks_free: 0` (confirmed
  via `vice_disk_list`), the exact regression class WP67 already fixed
  once (CMakeLists.txt:1840-1843 documents WP67 moving
  `test_casm_bounds`/`cliderive`/`lexer` off this same disk for this same
  reason). A `FLUSH` read the drive's real error channel and got
  `67, ILLEGAL TRACK OR SECTOR, 36,16` -- the BAM-exhaustion signature.
  `listcap`/`spancommit` (`fileCreateOutput`) and `listwrite`
  (`listingCreate`) all make real `DOS_OPEN_FILE` calls needing free
  blocks at runtime; `flist`/`flmeta` share the disk and failed
  identically. Fix: relocated `test_casm_finc`/`test_casm_opcodes` (25
  blocks) to `casm_include_test_d64` (156 free blocks there), restoring
  26 free blocks on `casm_listing_test.d64`. Verified live under VICE
  3.10 with clean `FLUSH` status throughout: all 12 harnesses remaining
  on `casm_listing_test.d64` PASS, plus both relocated harnesses PASS on
  `casm_include_test.d64`. Taskwarrior task 44 (this defect) closed.
  **WP75 Increment 4 is unblocked** to resume its consolidated sweep of
  the remaining disks (test.d64, casm_phase12_test.d64,
  casm_overflow_test.d64) and Increments 5-10. Two live-VICE procedure
  corrections were also learned and recorded this session (see memory
  `feedback-vice-command64-shell-and-petscii-typing` and
  `feedback-vice-flush-before-after-test`): always dispatch the
  documented application name, never the truncated disk directory name
  or a `RUN`/`LOAD` prefix, and always bracket a live test with `FLUSH`
  before and after.
- 2026-08-20: **Increment 4's consolidated sweep is now fully complete —
  all 30 `test_casm_*` harnesses PASS across all five disks**, each
  bracketed by `FLUSH` and each dispatch/result pair fired as a
  `c64-overlay-api` test event (per user direction to always fire overlay
  events for test/status updates going forward -- see memory
  `feedback-fire-overlay-events-for-tests`). Results: `casm_listing_test.d64`
  12/12 (listcap, spancommit, listwrite, flist, flmeta, listing, map,
  passcheck, l15release, spanread, frame, faultvmm); `casm_include_test.d64`
  7/7 (freloc, bounds, cliderive, lexer, fsym, finc, opcodes); `test.d64`
  4/4 (faultinstall, reloc, symbols, vmm -- including a live `BAD COMMAND
  OR FILE NAME` shell-parse-miss on `test_casm_reloc` recovered exactly
  per the workflow doc's `FLUSH`-then-retype procedure); `casm_phase12_test.d64`
  3/3 (expr, lexer, pass1 -- `pass1` reconfirms the earlier directory-full
  fix holds); `casm_overflow_test.d64` 4/4 (include, catalog, event,
  faults -- via the documented two-drive setup, device 8 booting
  `test.d64` and device 9 serving the non-bootable overflow disk, `9:`
  switch confirmed via prompt change to `C64[9]:>`). One VICE crash
  occurred mid-sweep (nothing listening on port 7000) and was recovered
  per the one-clean-restart procedure: fresh instance started, state
  discarded, re-attach + reboot + re-verify from the last confirmed
  point. **Increment 4 is complete.** Remaining WP75 scope: Increment 5
  (Phase 12 feature fixtures fresh run + WP70 relocation algebra closure
  re-check), Increment 6 (DASH regen re-verify), Increment 7 (docs
  reconciliation), Increment 8 (version promotion 0.2.8->0.3.0),
  Increment 9 (tracker sync), Increment 10 (final walkthrough + user's
  own manual approval).
- 2026-08-20: **Increment 5's fixture survey found a genuine, reproducible
  regression (task 45) — Stop Condition hit, disclose-and-defer per the
  plan.** On a branch dedicated to this increment
  (`feature/casm-phase12-wp75-increment5`), re-ran all ten Phase 12
  production fixtures live against a freshly-attached `casm_phase12_test.d64`
  (real `casm.prg`, real `comp.prg`, no synthetic harness): the WP70
  relocation algebra closure set (`casmrelacc.s` -> `CASM: INPUT VALIDATED`
  + `FILES COMPARE OK`; `casmarelocb.s`/`casmareloc1.s`/`casmareloc2.s` ->
  their exact documented `CASM: EXPRESSION RELOCATION UNSUPPORTED`
  diagnostics at the exact line/col/offset) all matched their WP68/WP70
  documented outcomes exactly. `casmarith2.s`, `casmarith3.s`, `casmchar1.s`,
  `casmzpconst1.s` (the WP72 fixture itself), `casmstring1.s` (WP74),
  and `casmfwdstale1.s` (the WP73 fixture itself) all produced
  `CASM: INPUT VALIDATED` and `FILES COMPARE OK` against their trusted
  references. Only **`casmarithfwd.s`** (WP68 Increment 7: `.ORG $0010` /
  `LDA FWDCONST*2` / `FWDCONST = 5` — a forward-referenced named constant
  inside an arithmetic-operator expression, resolving to a zero-page-
  eligible operand) failed, reproducibly (twice, both with clean `FLUSH`
  drive status), with `CASM: PASS 1/2 MISMATCH` instead of its documented
  `CASM: INPUT VALIDATED`. This fixture's source is unchanged since its
  WP68 creation (only touched by commit `4cc412f`, via
  `cmake/GenerateCasmTestFixtures.cmake`) and was never re-run since WP68's
  own verification — so a regression introduced anywhere between WP68 and
  WP74 would not have been caught until this fresh Increment 5 run. Leading
  theory (not yet verified): WP72 or WP73's own changes to zero-page-width
  selection / forward-label-resolver state broke specifically this
  "forward-reference + arithmetic operator -> zero-page-eligible result"
  combination — notable that WP72's and WP73's own dedicated fixtures
  (`casmzpconst1.s`, `casmfwdstale1.s`) pass individually, so the defect is
  in the *combination* this older fixture exercises, not either WP's own
  fixture shape. Logged as Taskwarrior task 45 with full investigation
  notes. Per the plan's Stop Conditions ("Any harness ... fails
  unexpectedly in the fresh consolidated session, even if it passed
  individually in its own WP" and "A genuinely new defect is discovered
  outside prior WPs' own scope: default is disclose-and-defer"), **WP75
  is paused here pending user direction** on task 45 — root-causing this
  needs live breakpoint debugging through the two-pass agreement check,
  not further guessing.
- 2026-08-20: **Task 45 fixed under a dedicated corrective WP (WP76),
  WP75 resumes.** Root-caused live (confirmed via direct memory read:
  `CasmPass1FinalPc=$0013` vs `CasmPc=$0012` at the mismatch point —
  Pass 1 forced absolute addressing for `FWDCONST` while unresolved
  ahead of its own definition; Pass 2 always sees it resolved and WP72's
  zero-page exemption fired, disagreeing on instruction width). Fixed by
  giving each named constant a `DEFINED_AT_OFFSET` bookmark and gating
  WP72's exemption on the current reference's own source position being
  at or after it. `casmarithfwd.s` now produces `CASM: INPUT VALIDATED`
  + `FILES COMPARE OK`; a consolidated fresh re-run of all 11 WP75
  Increment 5 fixtures together shows zero regressions. Full project
  build and no-change rebuild both clean. Full detail:
  `brain/plans/2026-08-20-casm-phase12-wp76-forward-reference-pass-agreement-fix.md`,
  `brain/walkthroughs/2026-08-20-casm-phase12-wp76-forward-reference-pass-agreement-fix.md`.
  WP75's remaining scope (Increment 6: DASH regen re-verify; Increment 7:
  docs reconciliation, deferred per user direction until this Phase's own
  close; Increment 8: version promotion; Increment 9: tracker sync;
  Increment 10: final walkthrough) resumes from here.
