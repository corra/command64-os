# CASM Phase 10 WP54 Verification Walkthrough

Status: Complete; user approved 2026-08-08
Branch: `feature/casm-phase10-wp53`
Candidate: CASM `0.1.55` build `1258`

## Scope

WP54 activates `/M` and `/L` in production `casm.s`: removes the
`NOT IMPLEMENTED` block WP51-53 left in place while `map.s` (WP52) and
`listing.s` (WP50/WP51/WP53) shipped with no live call site, and wires
`cliDeriveListingName`, `listingCaptureInit`/`Finalize`, `outputCommit`,
`listingWriteFile`, and `diagClearLoc`+`mapPrint` into the real
`start`/`casmRunPass` sequence in the plan's exact specified order. Adds a
unified `artifactsAbort` fatal-routing path. No production PRG/R6 bytes
change as a result of `/M`/`/L` being requested.

## Scope Deviation: Increment 1 Dropped

The plan's Completion Gate lists "harness/production matrix" as required.
Increment 1's dedicated `test_casm_phase10` stand-in/event-log harness (with
systematic failure injection at every stage) was never built — deferred
during increments 2-5 on the judgment that the primitives already carry
their own WP51-53 unit coverage. Before starting increment 7, this was
raised explicitly to the user rather than silently accepted: build the
harness now, or accept increment 6's live production-fixture matrix as
substitute Completion Gate evidence. User chose the substitute. Increment 1
is therefore formally dropped from WP54's scope, not merely postponed.

## Implementation Review

Re-checked every plan requirement and Stop Condition against the actual
diff (`eaa712e..HEAD` at review time, i.e. everything since the WP53
boundary commit):

- **Initialization/CLI, Pass Sequence, Completion Order** (increments 2-4):
  traced the actual `casm.s` call sequence line-by-line against the plan's
  specified Pass 2 preparation order (1: `sourceRewind`, 2:
  `includeReplayReset`, 3: `/L`-only `listingCaptureInit`, 4: `lexerInit`,
  5: `fileCreateOutput`, 6: `relocInit`, 7: `emitInit`/EMIT mode/
  `casmRunPass`) and completion order (1: include replay final check, 2:
  pass agreement, 3: `/L` capture finalize, 4: emit finalize, 5: reloc
  finalize, 6: source close, 7: PRG commit, 8: `/L` listing write, 9: `/M`
  map print, 10: success line, 11: exit) — **exact match**, no deviation
  beyond the already-recorded `listingStateInit`/`listingFileInit`
  reordering (moved ahead of `resourcesInit`, both pure BSS clears that
  cannot fail, so `artifactsAbort` is safe from the first fatal exit
  onward).
- **Unified Abort** (increment 5): `artifactsAbort` chains `listingAbort`
  then `outputAbort`, both already independently documented to preserve the
  primary diagnostic and never delete an already-committed artifact.
  `startFatal` rerouted through it; a second near-fatal trampoline
  (`startFatalNear1`) added for Pass 1's two checks, pushed out of direct
  `bcs` branch range by the growing Pass 2 tail.
- **Production Option/Artifact Matrix** (increment 6): 5/5 planned fixture
  categories (static/`/S`, R6/forward-reference, multi-root cross-file,
  31-char map-row boundary, `.INCLUDE` with a reference crossing the
  boundary) × all 4 option combinations, on a new dedicated
  `casm_phase10_test_d64` disk. 15/15 `comp` byte-identity checks against
  the no-options baseline passed (whole-file compare, so R6 footer identity
  needed no separate check). Found and fixed a real bug: `.INCLUDE`d
  records under `/L` failed `CASM: LISTING REPLAY MISMATCH` because
  `listingValidateRecord`/`listingWriteFile` both re-read a record's fields
  from `CasmVmmBuffer` *after* calling `listingResolveFilename`, which for
  an included file reaches `includeCatalogRead` and overwrites that same
  buffer as its own documented VMM transfer scratch — fixed by stashing the
  needed fields (`CasmListValidByteCountLo/Hi`; the `CasmListCurrentRecord`
  snapshot) before the resolve call. Re-verified clean post-fix, 3/3 further
  `comp` checks passed.
- **Envelope/Regressions/Review** (increment 7): 18553 code bytes at both
  linked origins (`$3800`/`$3900`), 4.63KB below the pre-approved `$5B00`
  cap, no zero-page growth (`listing.s`'s two new fields are ordinary BSS).
  A 25-target regression build (17 `test_casm_*` harnesses, `casm` itself,
  7 disk images) built clean. A live post-fix spot-check
  (`casmreloc1.s` baseline vs. `/M /L`, `comp` → `FILES COMPARE OK`)
  confirmed the debug-instrumentation add/revert cycle from the `.INCLUDE`
  bug hunt left no PRG regression.
- **Stop Conditions**: listing capture starts only after `sourceRewind`/
  `includeReplayReset` and ends before `emitFinalize`/`relocFinalize`; PRG
  committed (`outputCommit`) before any listing write, listing before the
  map; no simultaneous outputs (PRG and listing use separate handles at
  different times); `artifactsAbort` never deletes a committed artifact;
  `/M`'s block calls only `diagClearLoc`+`mapPrint`, no listing
  import/call; success text (`diagPrintPhase2Ready`) unchanged, only moved
  later in sequence; no Pass 1/replay/PRG/R6 logic changed (Pass 1 gained
  only a branch-range trampoline); envelope within cap; no zero-page
  growth; WP55 scope untouched. Also reviewed an incidental `expr.s`
  change (`CasmExprResolverAddrPad` grew 1→2 bytes): a legitimate
  BSS-alignment retune for a page-boundary `.assert` in
  `TEST_CASM_PASSCHECK` re-tripped by `listing.s`'s CODE growth — no
  behavioral, PRG, or R6 impact. **No findings.**

## Runtime Walkthrough

All live via VICE MCP (VICE 3.10, real `x64sc` true-drive-emulation runs,
not simulation):

1. `banner.s` (~350-line production fixture) through all four option
   combinations (none, `/M`, `/L`, `/M /L`) — each produced the correct
   artifact set. Incidentally exercised a disk-full failure path:
   `CASM: LISTING WRITE FAILED` correctly retained the already-committed
   PRG and suppressed map/success.
2. `casm_phase10_test_d64`'s 5 fixture categories × 4 option combinations —
   15/15 `comp` byte-identity checks passed; one real bug found and fixed
   (above), re-verified clean.
3. Post-fix spot-check: `casmreloc1.s` baseline vs. `/M /L`, map output
   (`$3400 START`/`$340E MSG`/`002 SYMBOLS`) matched increment 6's
   originally recorded values exactly, `comp relbase relml` →
   `FILES COMPARE OK`.
4. Production `casm` sanity: booted `casm_phase10_test.d64` fresh, ran with
   no source argument. Printed `CASM V0.1.55.1258` then
   `CASM: SOURCE FILE REQUIRED` — normal, expected behavior, confirming the
   real application boots and runs unaffected beyond the intended `/M`/`/L`
   activation.

## Envelope and Regression Verification

Final envelope: `casm` 18553 code bytes at both `$3800`/`$3900` origins
(unchanged `$5500` MAIN size from WP53, 4.63KB below the `$5B00` cap). A
25-target build (all `test_casm_*` harnesses, `casm`, and every CASM disk
image — `casm_listing_test_d64`, `casm_include_test_d64`,
`casm_overflow_test_d64`, `casm_phase10_test_d64`,
`command64_casm_utils_d64`, `image_d64`, `test_image_d64`) completed with
zero errors.

## Version-Only Completion Increment

User approved WP54 completion 2026-08-08. Applied the only production
change this increment authorizes: `VERSION_STAGE` `"54"` → `"55"` in
`casm.s`. Results:

- The hash-gated build counter advanced exactly once: `1257` → `1258`.
- Code size held stable at 18553 bytes (a 2-character string literal swap
  has no size delta).
- Production `casm` prints `CASM V0.1.55.1258` and runs normally (Runtime
  Walkthrough item 4).

## Completion Gate

Met 2026-08-08. CASM stands at `0.1.55` build `1258`, stable on a clean
rebuild. `/M` and `/L` are both fully implemented in production. WP55
(verification, walkthrough, and the Phase 10 completion gate) is unblocked
but not yet activated; it requires its own explicit activation per the
parent plan.
