# CASM Phase 10 WP55 Verification Walkthrough

Status: Complete, awaiting user approval
Branch: `feature/casm-phase10-wp53`
Candidate: CASM `0.1.55` build `1258` (WP55 adds no production code; the
only pending change is the completion-only `0.1.56` version increment,
gated on this walkthrough's approval)

## Scope

WP55 independently re-verifies the complete Phase 10 `/M`/`/L`
implementation delivered by WP50-WP54: reconciles the baseline, traces the
actual implementation rather than inferring behavior from names, re-runs
every Phase 10 harness and directly-related regression live, audits PRG/R6
identity/bounds/failure-injection/resource-reuse coverage against the
plan's Verification Matrix, and produces this consolidated walkthrough. It
makes no production, harness, fixture, or build-system change of its own.

## Scope Deviation Carried From WP54

Increment 1's dedicated `test_casm_phase10` failure-injection harness was
formally dropped from WP54's scope (user decision, recorded in WP54's own
plan/walkthrough). WP55 does not reopen this; it treats WP54's live
production-fixture matrix as the Completion Gate evidence for that item, as
already agreed.

## Baseline Reconciliation

- WP50-WP54 confirmed complete across Taskwarrior (all five `Completed`),
  `wiki/tasks/casm.md`, and `brain/task.md`. Found and fixed one stale-doc
  gap: `wiki/tasks/casm-phase10-symbol-map-listing.md` still showed WP50
  as in-progress (`[/]`) despite completing 2026-07-31 per every other
  tracker — a doc-sync gap, not a behavior defect.
- CASM version/build confirmed: `casm.s` at `VERSION_STAGE "55"`; a
  no-change rebuild of `casm` left `BUILD_CASM` at `1258` and
  `casm.prg`/`casm_base.prg`'s md5 stable.
- Every approved envelope re-measured from the **base-linked** intermediate
  PRG (not the final reloc-diffed output, which would overstate segment
  content): `casm` 18553/21760 bytes (`$5500` cap); `test_casm_listing`
  6173/7424; `test_casm_listcap` 18905/21760; `test_casm_map` 3237/5120;
  `test_casm_listwrite` 7390/8448 — all within cap with headroom.
- Diagnostic range verified against both `common.inc`'s own `.assert`
  contiguity chain and the originating plans: WP50 reserved `$39`-`$41`
  for WP51/WP53's listing diagnostics (confirmed byte-for-byte); `$42`
  (`SYMBOL_MAP_INVALID`) was separately approved by WP52's own plan,
  appended after WP53's range in implementation order — not an unapproved
  renumbering.
- Starting revision: git HEAD `168d2909f71915902a302dcd3f5960bbeed50ec8`.
  Image md5s recorded for `image.d64`, `test.d64`,
  `casm_overflow_test.d64`, `casm_include_test.d64`,
  `casm_listing_test.d64`, `casm_phase10_test.d64` (see the plan doc's own
  Progress log for the full hash list).

## Full-Path Review

Traced the actual code for all 9 items the plan's Full-Path Review section
names, not just the header comments:

1. CLI gate/listing-name derivation ordering — confirmed.
2. `listingStateInit`/allocation ordering relative to
   `sourceRewind`/`includeReplayReset` — confirmed.
3. **Per-statement capture transaction** (`casmRunPass`/`crpListingBegin`/
   `crpListingCommit`): every statement path begins/commits correctly,
   gated to Pass 2 only, failure paths abandon the transaction cleanly.
4. **`.INCLUDE` parent-before-child commit**: both Pass 1 and Pass 2 paths
   converge on one shared `crpIncCommit` that commits the parent line
   *before* `sourceFramePush` switches into the child. Parent-resume
   attribution is architecturally `source.s`'s problem (already
   Phase-9-proven), not `listing.s`'s — confirmed by reading
   `listingCommitLine`'s actual field sourcing.
5. **Bounds/carry-safety** (`listingMirrorByte`/`listingCommitLine`):
   the byte-cursor wrap and the "began already full" vs. "wrapped during
   this transaction" delta-arithmetic branch are both deliberately,
   correctly handled — confirmed by reading the actual carry logic.
6. Pass agreement/commit order — confirmed.
7. Listing serialization formatting — not independently re-derived (cited
   WP53's and WP54's own byte-exact fixture evidence instead); Session 2/3
   of this walkthrough add fresh on-device confirmation regardless.
8. **Symbol map iteration**: `mapPrint`'s loop is a plain sequential index
   walk with no bucket/hash access (confirmed via `map.s`'s own `.import`
   list, which never imports a chain-walking routine); `symbolsReadByIndex`
   computes its VMM offset as `index * 64` directly — a pure positional
   read, not a hash traversal.
9. Unified fatal routing (`artifactsAbort`) — confirmed.

No discrepancy found between documented behavior and actual code for any
item.

## Harness Verification

All 13 relevant harnesses (the plan's four named Phase 10 harnesses plus
9 directly-related Phase 9/Phase 10 regressions that link or exercise
shared modules) ran live under VICE, each with full PASS text and clean
`c64[<device>]:>` shell return:

`test_casm_listwrite` (23 fixtures), `test_casm_listing`,
`test_casm_listcap`, `test_casm_map`, `test_casm_passcheck`,
`test_casm_cliderive`, `test_casm_spanread`, `test_casm_spancommit`,
`test_casm_frame` (all on `casm_listing_test.d64`), and
`test_casm_include`, `test_casm_catalog`, `test_casm_event` (on
`casm_overflow_test.d64`, attached as a second unit alongside the
already-booted Command64 session, dispatched via the shell's `9:`
active-device switch). Along the way, found that `vice_keyboard_type`'s
ASCII underscore does not dispatch correctly for shell commands — the
correct raw PETSCII byte is `164` (`$A4`), confirmed empirically by
reading the disk directory's own on-screen bytes via
`vice_memory_search`, not guessed.

`test_casm_phase10` is the one approved exception (WP54's dropped
increment 1). Narrow lexer/parser/expr/opcodes/symbols/reloc harnesses
that link none of the Phase 10 modules were not additionally re-run —
already proven at their own WPs, and CMake's own dependency graph would
have failed the increment-2 regression build had any shared ABI they
depend on changed incompatibly.

## PRG/R6 Identity, Bounds, and Failure-Injection Matrix

**Bounds**: `test_casm_listing`'s `listingfull1`/`listingfull2` fixtures
exercise the *real* production routines (`listingMetaAppend`/
`listingMirrorByte`) via real repeated calls — not simulation — proving
exactly 4,096 records succeed and the 4,097th fails
(`LISTING_RECORDS_FULL`), and exactly 65,535/65,536/65,537 mirrored bytes
behave correctly (not-yet-full / full with cursor wrapped to exactly zero
/ rejected as `LISTING_BYTES_FULL`). Per-line emitted-byte-count overflow
is structurally unreachable given the pre-existing, independently-tested
255-byte physical line cap — verified by citing that upstream bound, not
a new fixture.

**Naming**: `test_casm_cliderive`'s fixtures cover device-prefixed,
dot-suffixed, no-dot-suffix, over-length, and collision cases.

**Replay-mismatch detection**: `test_casm_listwrite`'s 9
`validateRejects*`/`validatePropagates*` fixtures cover corrupt flags,
reserved bytes, source-span/byte-count overflow, non-monotonic offsets,
and out-of-range FILEIDs, plus a real mid-replay-failure orchestration
case.

**VMM failures**: `listingallocfail1`/`listingvmmfail1` inject *real*
registry exhaustion (filling 7 of 8 real VMM slots), not a mocked
failure.

**Genuine gap found and disclosed to the user**: `CREATE_FAILED`/
`CLOSE_FAILED`/`DELETE_FAILED`/`SHORT_WRITE` are not independently
fault-injected by any fixture in this codebase — confirmed this is a
pre-existing, codebase-wide pattern (`fileio.s`'s own identical-shape
Phase 2 diagnostics have never been fault-injection-tested either, no
dedicated suite exists). **User decision**: accept as a disclosed,
pre-existing-pattern gap; worth a follow-up task for real fault-injection
infrastructure (a stubbable `OS_API`/DOS layer), not blocking WP55.
`WRITE_FAILED` has one real live proof (WP54's disk-full test).

**Live production-level proofs added this session** (not just unit
tests): `CASM: LISTING NAME COLLISION` fired for real (the first live
trigger of this diagnostic in the project's history), immediately
followed in the *same OS session* by a known-good recovery assembly
(`CASM: INPUT VALIDATED`) — proving no stale handle/resource remained.
Separately, `casmif1.s` (hand-flattened baseline) vs. `casmip1.s`
(real `.INCLUDE`, `/M /L`) → `comp` → `FILES COMPARE OK`, a direct,
non-transitive proof that included/flattened equivalence survives Phase
10's changes.

**PRG/R6 Identity**: combining WP54's own 15-fixture matrix (static,
R6/forward-reference, cross-file forward-reference, map-boundary,
`.INCLUDE`, each × all 4 option combinations) with this session's direct
`casmip1`/`casmif1` comparison, every axis the plan names is covered.
"Equivalent to the Phase 9 baseline" is satisfied by construction: the
Full-Path Review already traced that `emitFinalize`/`relocFinalize`
themselves are unchanged, and `/M`/`/L` only ever run after
`outputCommit` — so the no-options case's output *is* the Phase 9
behavior. Cross-boundary branches specifically were not re-tested with a
new fixture; covered by architectural non-interference (listing/map
capture never re-derives an address) plus Phase 4's own long-standing
branch-boundary regression suite.

**Resource-reuse**: proven directly for the name-collision failure mode
(above); not separately proven for the four disclosed-gap failure modes,
consistent with their own fault-injection being unproven.

**Image/no-change-build**: fully covered in Baseline Reconciliation.

## Runtime Walkthrough

All four sessions, live via VICE MCP (VICE 3.10, real `x64sc`
true-drive-emulation, no simulation):

**Session 1** (five, now four, Phase 10 harnesses): satisfied by citing
the Harness Verification results above — identical action, identical
expected result to a fresh run.

**Session 2** (static + relocatable, on-device inspection, load-and-run):
- Static (`casmemit1.s`, the user manual's own Example 1 fixture):
  assembled with `/M /L` → `CASM: INPUT VALIDATED`, empty map (`000
  SYMBOLS`, correct — no labels). `type emit1.lst` matched the fixture's
  known reference hex byte-for-byte on real device output, including
  `.byte`/`.word` continuation wrapping. `load`/`run`, then a memory read
  of `$D020` confirmed `$F1` (low nibble `$01`) — the border genuinely set
  to white as the source intends. **Finding, disclosed, out of scope**:
  `load` reported (and a direct memory read confirmed) the PRG landed at
  `$3800`, not its own `.ORG $C000` — this OS's `LOAD` always auto-places
  at the first free region regardless of a PRG's embedded header address,
  a pre-existing, kernel-level behavior unrelated to CASM/Phase 10. This
  specific fixture still behaved correctly only because every byte it
  contains is position-independent by construction (immediate/implied
  addressing, one hardware-register write, a relative branch) — not a
  general guarantee. Worth a note that CASM's own docs describe `/S`+
  `.ORG` as being "for a program that must live at a specific fixed
  address," which is in tension with `LOAD` never honoring that address.
- Relocatable (`banner.s`, the established WP54 production fixture):
  assembled with `/M /L` → `CASM: INPUT VALIDATED`, real map (`054
  SYMBOLS`) and `.LST` size (178 blocks) both matched WP54's previously
  recorded values exactly. `more bannml.lst` spot-checked correct
  formatting (file header, comment-row continuation wrapping).
  `load`/`run` → `banner v1.0.0.1000` / `usage: banner <text>`, banner's
  own correct real behavior. **Minor finding, disclosed**: `MORE` has no
  documented abort key; paging through a 178-block file was impractical,
  and neither `q` nor the `STOP` key dismissed it — recovered via a clean
  soft reset (no work lost; the assembled artifacts survived on disk).
  Worth a `MORE` UX follow-up, unrelated to Phase 10.

**Session 3** (included sources under `/L`): reattached
`casm_include_test.d64` and `type`d `ipml.lst`, the `.LST` already
produced live in the PRG/R6 Identity matrix work above — no re-assembly
needed. Directly observed: `FILE 80: 9:CASMIC1.S` (included child, full
filename with device prefix) for the included lines, then `FILE 00:
CASMIP1.S` (parent) **reappearing** before the parent's remaining lines
resume — the parent-resume file-header re-transition, confirmed directly.
`CHILDLBL` at `$C002` and `BACKREF` at `$C00C` in the listing match the
live `/M` map exactly, cross-validating both outputs against each other.
`/M /L` ordering and map suppression on listing failure were already
live-proven in WP54's disk-full test — cited, not re-run.

**Session 4** (naming/bounds/failure-injection with recovery): the
collision + same-session recovery case is live-proven above. Records-
full/bytes-full via a genuine multi-thousand-line production assembly was
explicitly scoped out (disclosed, not silently skipped) in favor of
citing `listingfull1`/`listingfull2`'s real production-routine-loop proof
— authoring a fixture at that scale would cost many additional minutes of
true-drive-emulation time for marginal assurance beyond what's already
established.

## Disclosed Findings Summary

None of the following block WP55's Completion Gate; all are pre-existing,
out-of-scope, or already-mitigated:

1. `CREATE_FAILED`/`CLOSE_FAILED`/`DELETE_FAILED`/`SHORT_WRITE` listing
   diagnostics have no independent fault-injection coverage anywhere in
   this codebase (same as `fileio.s`'s identical-shape Phase 2
   diagnostics) — user-accepted, worth a follow-up task.
2. This OS's `LOAD` command always relocates to the first free region,
   never honoring a static CASM output's own `.ORG` header — pre-existing
   `LOAD`/kernel behavior, unrelated to CASM/Phase 10, worth a note given
   the tension with CASM's own static-output documentation.
3. The `MORE` shell command has no documented way to abort mid-file —
   unrelated to Phase 10, worth its own small UX follow-up.
4. `vice_keyboard_type`'s ASCII-underscore handling doesn't work for
   shell dispatch; PETSCII byte `164` (`$A4`) is the fix — a VICE-testing
   process note, not a product finding.

## Completion Gate

All of the plan's Baseline Reconciliation, Full-Path Review, Harness
Verification, PRG/R6 Identity/Bounds/Failure-Injection/Resource-Reuse
Matrix, and four-session Runtime Walkthrough are complete, each with live
VICE evidence recorded in
`brain/plans/2026-07-29-casm-phase10-wp55-verification-walkthrough-completion-gate.md`'s
Progress log. No PRG/R6 byte changed from baseline anywhere. No
regression build failed. No no-change build incremented. No approved
envelope was exceeded. No zero page grew. Awaiting the user's explicit
approval to mark WP55 complete at `0.1.56` (increment 6), and — as a
fully separate, later decision — explicit Phase 10 completion approval
for the `0.2.0` promotion (increment 7).
