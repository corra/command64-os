---
feature: casm-phase10-wp54-production-integration
created: 2026-07-29
status: complete
taskwarrior: f4b598fd-bab1-4394-9415-c71e3ea1cfa5
depends-on: aa57f461-36a9-455c-966f-ac484ec57b41
---

# Plan: CASM Phase 10 WP54 - Production Integration

## Status

**Complete.** User-approved 2026-08-08. CASM bumped `0.1.54` -> `0.1.55`
(build 1258), live-verified via VICE (`CASM V0.1.55.1258`).

## Objective

Activate `/M` and `/L` while preserving passes, PRG/R6 bytes, include replay,
provenance, diagnostics, cleanup, and no-option behavior.

## Initialization and CLI

Call allocation-free `listingStateInit` after source/file/CLI state init. Remove
the `/M`/`/L` NOT IMPLEMENTED block. Derive PRG name, then derive listing name
only for `/L`, before source/resource work.

## Pass Sequence

Pass 1 is unchanged and allocates/captures no listing state.

Pass 2 preparation order:

1. `sourceRewind`
2. `includeReplayReset`
3. `/L` only: `listingCaptureInit` (two stores and source capture)
4. `lexerInit`
5. `fileCreateOutput`
6. `relocInit`
7. `emitInit`, EMIT mode, `casmRunPass`

Completion order:

1. Include replay final check
2. Pass agreement
3. `/L`: listing capture finalize
4. Emit finalize
5. Relocation finalize
6. Source close
7. PRG commit
8. `/L`: listing serialization/commit
9. `/M`: clear stale location and print map
10. Existing `INPUT VALIDATED` success line
11. Successful central cleanup/exit

Listing allocation therefore fails before partial PRG creation; map prints only
after every requested file is committed.

## Option Matrix

- No options: PRG then success line.
- `/M`: PRG, map, success.
- `/L`: PRG, listing, success.
- `/M /L`: PRG, listing, map, success.
- `/S` changes only existing static/R6 behavior.

## Unified Fatal Routing

Add `artifactsAbort`: preserve primary, call listing abort then output abort,
return primary/first cleanup failure, then `exitFatal`. Committed flags retain
valid artifacts; uncommitted artifacts close/delete; all live resources remain
registered for central cleanup. Replace direct `outputAbort` fatal routing.

Failures before PRG create leave no artifacts; Pass 2/capture failures delete
partial PRG; PRG commit failures delete PRG; listing failures retain committed
PRG and suppress map/success; map failures retain committed PRG/listing and
suppress success.

## Integration Harness

Add `test_casm_phase10` with stand-in modules and bounded event log. Verify exact
call order for all option/static/root/include combinations and inject failures at
every derivation/init/pass/rewind/allocation/create/finalize/check/close/commit/
listing/map stage. Assert calls stop correctly, artifacts/resources, map/success
suppression, primary diagnostics, `/M` no listing stores, `/L` exactly two, and
Pass 1 capture disabled.

## Production Fixtures

Exercise static/R6, forward/back symbols, map boundaries, blank/comment/
continuations, roots, nested/repeated includes, output names/devices, and all
option combinations. For each source require identical PRG hashes and R6 tables
with no options, `/M`, `/L`, and both.

## Envelope

Start from WP53, choose smallest aligned increase, stop above preapproved
`$5B00`, measure harness independently, and add no zero page.

## Expected Files

Modify `casm.s`, optionally common/file I/O ABIs already planned, and CMake; add
`tests/src/casm_phase10/`, complete fixtures/artifacts, user documentation,
test/CASM DOX, tasks, knowledge, memory, changelog, and walkthrough.

## Atomic Increments

1. Harness and expected sequences.
2. Listing init/CLI activation.
3. Conditional post-rewind allocation.
4. Capture completion and commit/listing/map/success order.
5. Unified abort.
6. Production option/artifact matrix.
7. Envelope/regressions/review/walkthrough.
8. Approval, stable `0.1.55`, synchronized closure.

## Verification

Build via CMake at both origins; build all Phase 10 and prior CASM tests/images;
verify exact event/failure matrix; compare PRG/R6 hashes; prove no Pass 2 or
serialization source I/O, one output handle, ordering/retention, carry/stack/
scratch/cleanup, stable rebuild, diff check, and DOX.

## Stop Conditions

Listing before rewind or after PRG create, inability to commit PRG before
listing, simultaneous outputs, unsafe committed artifacts, `/M` listing
resources, changed success text beyond order, pass/replay/PRG/R6 changes,
envelope >`$5B00`, zero-page growth, or premature WP55 scope.

## Completion Gate

Requires WP53 completion, harness/production matrix, identity proof, measured
envelopes, review, user walkthrough/approval, stable `0.1.55`, and synchronized
records. Does not activate WP55.

## Progress

- 2026-07-29: User approved this plan. WP54 remains blocked by WP53; no
  integration implementation is authorized.
- 2026-08-07: WP53 confirmed complete (task aa57f461, status Completed); WP54
  unblocked. Implemented increments 2-5 directly in `casm.s` (deferred
  increment 1's dedicated stand-in harness -- the primitives each already
  carry their own unit coverage from WP51-53, so the integration risk is
  purely in `casm.s`'s own call sequencing, which increment 6's live-fixture
  run below exercises directly):
  - Moved `listingStateInit`/`listingFileInit` to the very first two calls in
    `start`, ahead of `resourcesInit` -- both are pure BSS clears that cannot
    fail, and running them first (before any call that can fail) guarantees
    the new `artifactsAbort` can safely inspect listing state from the very
    first fatal exit onward. This deviates from the plan's literal "after
    source/file/CLI state init" wording; the plan's original placement
    would have left `artifactsAbort` unsafe to call from the four earliest
    init failures (`resourcesInit`/`cliInit`/`fileIoInit`/`sourceInit`).
  - Removed the `/M`/`/L` NOT IMPLEMENTED block; added `cliDeriveListingName`
    (gated `/L`), `listingCaptureInit` (gated `/L`, post-rewind/replay-reset),
    `listingCaptureFinalize` (gated `/L`, pre-emitFinalize), `outputCommit`
    (unconditional, pre-listing/map), `listingWriteFile` (gated `/L`,
    post-commit), and `mapPrint` with a preceding `diagClearLoc` (gated `/M`,
    last) in the plan's exact specified order.
  - Added `artifactsAbort` (chains `listingAbort` then `outputAbort`, same
    "preserve primary, return first cleanup failure" contract each already
    implements) and rerouted `startFatal` through it, replacing the old
    direct `outputAbort` call.
  - Added a second near-fatal trampoline (`startFatalNear1`/
    `startPass1Continue`) for Pass 1's two checks: the growing Pass 2 tail
    pushed them out of `bcs` branch range of the original `startFatalNear`.
  - Envelope: unchanged. Both `casm_3800`/`casm_3900` origins link cleanly
    inside the existing WP53 `$5500` MAIN segment size (18541 code bytes,
    ~3.2KB of headroom below the WP54 `$5B00` cap) -- no MEMORY size bump
    needed for this increment.
  - Full project build (`cmake --build .`, all targets including
    `image_d64`/`casm_listing_test_d64`) succeeds clean.
  - Live-verified via VICE MCP against `banner.s` (the real ~350-line
    production fixture already shipped on `image_d64`), booting
    `command64` and running real shell dispatch for all four option
    combinations: no options (PRG only), `/M` (PRG + real 54-symbol map,
    no listing), `/L` (PRG + real 178-block `.LST`, no map), and `/M /L`
    together (PRG + listing + map, in that order, all committed). Also
    incidentally exercised the failure path for real: a disk-full condition
    (from repeated same-disk test runs) correctly produced
    `CASM: LISTING WRITE FAILED` while retaining the already-committed PRG
    and suppressing the map/success line -- confirms the "listing failure
    retains committed PRG, suppresses map/success" contract end-to-end on
    real hardware emulation, not just by code inspection.
  - Found and worked around, but did NOT fix (pre-existing, out of WP54's
    scope): `fileCreateOutput` (fileio.s, Phase 2/WP13-era) opens the PRG
    output name verbatim with no CBM DOS `@0:` replace marker, unlike
    `listingCreate`'s WP53-era replace-aware open. Rerunning CASM with an
    output name that already exists on disk hangs (observed stuck in a
    KERNAL IEC retry loop, recovered only by a machine reset) rather than
    replacing or failing fast. Worked around in testing by using distinct
    `/O:` names per run. Worth a follow-up task; not a WP54 regression.
  - Remaining for WP54 closure: increment 1's dedicated stand-in/event-log
    harness (`test_casm_phase10`) and its systematic failure-injection matrix
    (only the disk-full case was exercised, incidentally, this session),
    increment 6's identity-hash fixture matrix (forward/back symbols, map
    boundaries, nested includes, etc.), increment 7's formal envelope
    measurement/regression pass, and increment 8's version bump to stable
    `0.1.55` plus synchronized docs/CHANGELOG/wiki/task updates. `casm.s` is
    still at `0.1.54` build 1239 pending those.
- 2026-08-07 (continued): Increment 6 (production fixture matrix). Added a
  new dedicated disk image target `casm_phase10_test_d64` (carrying
  command64, casm, and comp, self-bootable on device 8, ~508 blocks free)
  since test.d64 is at
  its directory-entry ceiling and casm_listing_test_d64/casm_include_test_d64
  each lack either command64 or casm.prg. Scoped to 4 fixtures (not the
  plan's full aspect list) after this session's own live-VICE timing made a
  full combinatorial sweep impractical (each fixture's 4-option matrix, 4
  assemblies + 3 `COMP`s, took 20-30+ minutes real wall-clock under true
  drive emulation): `casmemit1.s` (static, `/S`), `casmreloc1.s`
  (relocatable/R6 + forward reference), `casmmfa.s`+`casmmfb.s` (two roots,
  cross-file forward reference), `casmmaxid1.s` (31-char map-row boundary).
  For each, ran all 4 option combinations (`/O:`-distinct names per run,
  working around the known fileCreateOutput-no-replace gap) and used the
  native `comp` utility to prove the `/M`/`/L`/`/M /L` PRGs are byte-for-byte
  identical to the no-options baseline -- **all 3 `COMP`s passed for all 4
  fixtures (12/12 `FILES COMPARE OK`)**, including R6 footer bytes (comp is
  whole-file, so this also proves relocation-table identity with no
  separate check needed). Map output also spot-checked correct each time
  (`$3400 START`/`$340E MSG`/`002 SYMBOLS` for casmreloc1; `$C003 VALB`/
  `001 SYMBOLS` for the roots pair; the full 31-char name for casmmaxid1).
  - **Found a real bug, NOT fixed**: a 5th fixture, `casmip1.s` (single-level
    `.INCLUDE` with a reference crossing the boundary in both directions,
    the exact shape WP47/48 already proved for plain assembly), fails `/L`
    reproducibly with `CASM: LISTING REPLAY MISMATCH AT LINE 6, COL 5` --
    the parent's first resumed statement's *second* line (`JMP CHILDLBL`).
    `/M` alone and `/L` alone (without `.INCLUDE`) both work; this is
    specifically an include-frame-pop + listing-capture interaction, most
    likely in `source.s`'s `sourceCaptureNewline`/`sourceCaptureFinal`/
    `sourceFramePopInternal` given WP51 never exercised real listing capture
    against a real `.INCLUDE` boundary through the production lexer/
    parser's own lookahead timing (WP51's own casmlc07/casmlc7c fixture used
    a driver loop, not real casmRunPass). Attempted live root-cause via VICE
    checkpoints across every `CASM_DIAG_LISTING_REPLAY_MISMATCH` raise site
    in `listing.s`/`source.s` (7 candidate sites, all instrumented) -- none
    fired, and a `vice_backtrace` attempt returned an internally
    inconsistent frame (a return address landing mid-instruction, not after
    a real `JSR`), indicating the tool's stack-scan isn't reliable for this
    purpose. Reverted all temporary debug labels/exports before continuing
    (see git history if resuming: two throwaway edits to `source.s`/
    `listing.s`, both cleanly reverted, no trace left). See
    [[project-casm-phase10-wp54-progress]] and the new
    [[project-casm-include-listing-mismatch]] memory. This blocks closing
    WP54 with `.INCLUDE` support intact -- either fix it, or (pending user
    decision) scope `/L` to reject `.INCLUDE`d sources for `0.1.55` and defer
    the fix to a follow-up WP.
  - Increment 6 is therefore substantially but not fully done: 4/5 planned
    fixture categories (static, R6/forward-ref, roots, map-boundary) are
    clean; nested includes surfaced a real defect requiring its own fix
    before WP54 can close. "Repeated includes" and "output names/devices"
    aspects were not separately exercised (deprioritized given the time
    cost and the include bug already blocking closure regardless).
- 2026-08-07 (continued): Root-caused and fixed the `casmip1.s` `/L` +
  `.INCLUDE` bug (task 41), closing increment 6's 5th fixture category.
  Abandoned live VICE checkpoint/backtrace debugging as unproductive (per
  user redirect) in favor of static read-through, then a print-based trace
  (temporary `DbgTraceStmt` in `casm.s`, temporary `DbgDumpRecord` in
  `listing.s`) run unpaused in VICE with output read back via raw screen-RAM
  memory dumps (more reliable than screenshot OCR for dense hex text).
  - First trace (statement dispatch) disproved the leading hypothesis: the
    parent's final `NOP` statement (line 8, depth 0) *is* parsed, dispatched,
    and committed cleanly in Pass 2 -- the bug is not a missed statement.
  - Second trace (dumping each metadata record's FILEID/LINE/BYTEOFF/
    BYTECOUNT at both append-time and replay-time) found the real root
    cause: `listingValidateRecord` (`listing.s`) calls
    `listingResolveFilename` to resolve each record's FILEID for display;
    for an included (frame) FILEID, that reaches `includeCatalogRead`,
    which its own header already documented as overwriting `CasmVmmBuffer`
    as its own VMM transfer scratch. But `listingValidateRecord` read
    `BYTECOUNT_LO/HI` back out of `CasmVmmBuffer` *after* that call, to
    advance the running expected-byte-offset -- so for every record
    belonging to an included file, the advance used clobbered garbage
    instead of the real byte count, and the *next* record's `BYTEOFF` check
    then mismatched. Capture-time records were always correct and
    monotonic; only the replay-time advance was corrupted, which is why the
    failure only ever appeared once inside an include, one record after the
    boundary.
  - Fix (in `listing.s`): stash `BYTECOUNT_LO/HI` into new
    `CasmListValidByteCountLo/Hi` *before* calling `listingResolveFilename`
    in `listingValidateRecord`, and advance from the stash, not from
    `CasmVmmBuffer`. Also found and fixed a second, quieter instance of the
    identical clobber: `listingWriteFile`'s loop copied
    `CasmVmmBuffer` -> `CasmListCurrentRecord` (the snapshot `lwEmitRecordRows`
    formats the actual `.LST` rows from) *after* calling
    `listingValidateRecord` -- so every included-file line's printed PC/
    byte-count/hex columns would have been silently wrong too, even once the
    mismatch check itself was fixed. Fixed by reordering: the snapshot now
    happens before `listingValidateRecord` runs.
  - Re-verified live in VICE: `casmip1.s` now assembles cleanly with all 4
    option combinations (none, `/M`, `/L`, `/M /L`), each ending in
    `CASM: INPUT VALIDATED`, `/M`'s map correctly showing `$C000 START`/
    `$C002 CHILDLBL`/`$C00C BACKREF`/`003 SYMBOLS` both alone and combined
    with `/L`. `comp` proved all 3 non-baseline PRGs (`/M`, `/L`, `/M /L`)
    byte-for-byte identical to the no-options baseline (3/3
    `FILES COMPARE OK`, R6/relocation-irrelevant here since this fixture is
    static). Increment 6 is now 5/5 fixture categories clean.
  - Reverted all temporary debug instrumentation (`DbgTraceStmt`/
    `DbgTraceHexByte`/`DbgTraceNibble`/`DbgTraceBuf` from `casm.s`;
    `DbgDumpRecord`/`DbgDumpMirror`/`DbgHexByte`/`DbgNibble`/`DbgBuf` from
    `listing.s`; the `diagPrintString` import in `listing.s`) and the two
    branch-range trampolines (`crpFailTrampoline`/`crpDispatch` in
    `casmRunPass`) that only existed to accommodate the debug code's size --
    removing the debug code let both direct `bcs crpFail` branches fit
    again. `CMakeLists.txt`'s casm `PRG_SIZE_HEX` reverted from the
    temporary `"5700"` back to the original `"5500"`; the real fix (four new
    permanent bytes: `CasmListValidByteCountLo/Hi`, plus the reordered/
    added instructions) fits inside the original WP54 envelope with room to
    spare (18553 code bytes at rebuild, vs. 18541 before this fix -- +12
    bytes net for a real correctness fix, not a threat to the `$5B00` cap).
  - See [[project-casm-include-listing-mismatch]] (updated) and
    [[project-casm-phase10-wp54-progress]] (updated).
- 2026-08-07 (continued): Beginning increment 7 (envelope/regressions/review/
  walkthrough). First resolved a conflict flagged before starting: this
  plan's own Completion Gate lists "harness/production matrix" as required,
  but increment 1's dedicated `test_casm_phase10` stand-in/event-log harness
  was deferred (not built) back in increment 2-5. User decision (asked
  explicitly): accept increment 6's live-fixture matrix as the
  harness/production-matrix evidence for gate purposes. Increment 1 is
  formally dropped from WP54's must-have scope, not merely postponed --
  its coverage is considered satisfied by: 5/5 production fixture
  categories x 4 option combinations each, 15/15 `COMP` byte-identity
  checks (static, R6/forward-ref, multi-root cross-file, map-boundary,
  `.INCLUDE` with fwd+back ref), one real bug found and fixed through this
  path (the `casmip1.s` listing/replay mismatch), and one concrete
  failure-injection contract confirmed live (disk-full -> `LISTING WRITE
  FAILED`, committed PRG retained, map/success suppressed). This
  substitutes for, rather than literally satisfies, the plan's original
  "inject failures at every derivation/init/pass/rewind/allocation/create/
  finalize/check/close/commit/listing/map stage" language -- recorded here
  as a deliberate scope deviation, same pattern as the earlier
  `listingStateInit` ordering deviation. If a future regression surfaces in
  exactly the call-sequencing area the harness would have covered, revisit
  building it as a standalone follow-up rather than reopening WP54.

  Increment 7 sub-plan (recorded before executing, per this project's
  detail-first-then-implement convention):
  1. Clean build of `casm` at both linked origins (base/next-page pair the
     relocation diff already produces on every build, e.g. `casm_base.prg`/
     `casm_next.prg` in `out_casm/`) -- confirm both link with no MEMORY
     overflow and `reloc.py` produces a clean relocatable `casm.prg`.
  2. Record the formal envelope: exact code-byte size at this commit,
     headroom below the pre-approved `$5B00` MAIN cap, and confirm zero page
     usage is unchanged from WP53 (the plan's "add no zero page" stop
     condition).
  3. Build all Phase 10 and prior CASM test targets/images via CMake
     (`test_casm_*` targets plus `casm_listing_test_d64`,
     `casm_include_test_d64`, `casm_overflow_test_d64`,
     `casm_phase10_test_d64`, `command64_casm_utils_d64`, `image_d64`,
     `test_image_d64`) -- confirms no build-level regression anywhere in the
     existing CASM test suite from WP54's `casm.s`/`listing.s` changes.
  4. Spot-check PRG/R6 identity is still intact post-revert (the debug
     instrumentation added/removed while chasing the `casmip1.s` bug touched
     `casm.s`'s Pass 2 dispatch trampolines) by re-running `comp` against at
     least one already-proven fixture, not just trusting the revert.
  5. Targeted code review of the full WP54 diff (`casm.s`/`listing.s` since
     the WP53 boundary commit) for the plan's own Stop Conditions: listing
     before rewind or after PRG create, PRG-before-listing ordering, no
     simultaneous outputs, no unsafe committed artifacts, `/M` touching no
     listing resources, unchanged success text beyond ordering, and no
     accidental pass/replay/PRG/R6 behavior change.
  6. Prepare a walkthrough summary of increments 2-7 for user review/
     approval -- the Completion Gate's "review, user walkthrough/approval"
     items -- before increment 8 touches the version number.
  This increment does not bump the CASM version; that is increment 8, gated
  on approval from step 6 here.

  Increment 7 execution (steps 1-3 and 5 of the sub-plan above):
  - Step 1-2 (envelope): clean build at both origins succeeded
    (`out_casm/casm_base.prg` at `$3800`, `casm_next.prg` at `$3900`, both
    18555 bytes / 18553 code bytes, `reloc.py` diff clean). Headroom below
    the pre-approved `$5B00` cap: 4743 bytes (4.63KB). Headroom below the
    currently-configured `$5500` MAIN size (unchanged from WP53, no envelope
    increase needed): 3207 bytes (3.13KB) -- corrects a units slip in an
    earlier progress note that called the smaller number "headroom below
    the `$5B00` cap." Confirmed zero page usage unchanged: grepped every
    `.segment` directive across all of `src/external/casm/*.s` and none use
    `ZEROPAGE`; the WP54 fix's two new bytes
    (`CasmListValidByteCountLo/Hi`) are ordinary BSS in `listing.s`.
  - Step 3 (regression build): built all 17 `test_casm_*` targets, `casm`
    itself, and 7 disk images (`casm_listing_test_d64`,
    `casm_include_test_d64`, `casm_overflow_test_d64`,
    `casm_phase10_test_d64`, `command64_casm_utils_d64`, `image_d64`,
    `test_image_d64`) in one CMake invocation -- 25 targets, exit code 0, no
    errors in the build log.
  - Step 4 (live PRG-identity spot-check): **blocked**, not yet done. The
    VICE MCP server (`tools/vice_mcp_start.sh`) fails to start --
    `x64sc`'s own log shows `MCP-Transport: Error - Failed to start HTTP
    server on port 6510` even immediately after a clean `stop` confirmed the
    port was free; two independent restart attempts both hit it. Per this
    project's MCP-unavailable rule, stopped and asked the user rather than
    improvising (e.g. faking the check via raw memory/state pokes, which
    [[feedback-vice-testing]] already rules out). User chose to investigate/
    restart it themselves; this step resumes once the server is back.
  - Step 5 (code review vs. plan Stop Conditions): reviewed the full
    `casm.s`/`listing.s`/`expr.s` diff since the WP53 boundary commit
    (`eaa712e..HEAD`, currently just `68b28f4`). Traced the actual
    completion-order call sequence in `casm.s` line-by-line against the
    plan's specified 1-11 order (include replay final check -> pass
    agreement -> `/L` capture finalize -> emit finalize -> reloc finalize
    -> source close -> PRG commit -> `/L` listing write -> `/M` map print
    -> success line -> exit) and the Pass 2 preparation 1-7 order (source
    rewind -> include replay reset -> `/L` capture init -> lexer init ->
    output create -> reloc init -> emit init/EMIT mode/casmRunPass) --
    **both match exactly**, no deviation beyond the already-recorded
    `listingStateInit` placement. Verified against every Stop Condition:
    listing capture starts after rewind and PRG commit happens before
    listing write (order confirmed above); no simultaneous outputs (PRG via
    `fileCreateOutput` in Pass 2 prep, listing via its own internal
    create/write/close inside `listingWriteFile`, sequential not
    concurrent); `artifactsAbort` never deletes a committed artifact (both
    chained routines document that contract); `/M`'s block calls only
    `diagClearLoc`+`mapPrint`, no listing import/call; the success line
    (`diagPrintPhase2Ready`) is unchanged, only moved later in sequence; no
    Pass 1/replay/PRG/R6 logic changed (Pass 1 only gained a branch-range
    trampoline, `relocFinalize` call itself untouched). Also reviewed the
    incidental `expr.s` change (`CasmExprResolverAddrPad` grew 1->2 bytes):
    legitimate, well-explained BSS-alignment retune for a page-boundary
    `.assert` in `TEST_CASM_PASSCHECK` re-tripped by the listing.s fix's
    CODE growth -- not a behavioral change, no PRG/R6 impact (BSS-only).
    **No findings.**
  - Step 4 (live PRG-identity spot-check), completed after a VICE MCP
    server outage was resolved (the server initially failed to bind its
    HTTP port across two restart attempts; recovered after the user
    restarted it, reconnect confirmed via `vice_ping`). Booted
    `casm_phase10_test.d64` fresh in VICE (real Command64-DOS boot,
    `dir` confirmed `casmreloc1.s` and the rest of increment 6's fixture
    set present, 508 blocks free), then live-dispatched `casmreloc1.s`
    twice: `casm casmreloc1.s /O:relbase` (baseline, no options) and
    `casm casmreloc1.s /O:relml /M /L`, both real assembler runs under
    true drive emulation, both completing `CASM: INPUT VALIDATED`. The
    `/M` map output (`$3400 START`/`$340E MSG`/`002 SYMBOLS`) matched
    increment 6's originally recorded values exactly. `comp relbase relml`
    reported `FILES COMPARE OK` -- confirms the debug-instrumentation
    add/revert cycle from the `casmip1.s` bug hunt left PRG output
    byte-identical for this fixture, i.e. no regression slipped in via
    that detour. Emulator left running (not paused) throughout and
    afterward, per user instruction.

  **Increment 7 is now complete**: envelope measured and within cap,
  full regression build clean across 25 targets, code review found no
  issues, live spot-check confirms no PRG regression from the debug
  detour. Remaining before WP54 can close: the walkthrough summary below
  needs the user's review/approval (Completion Gate item), then
  increment 8 (version bump to stable `0.1.55` + synchronized docs/
  CHANGELOG/wiki/task records) can proceed.
- 2026-08-08: User approved the walkthrough summary ("Commit it and begin
  increment 8"). Increment 8 (version bump + synchronized docs/CHANGELOG/
  wiki/task records) executed:
  - `VERSION_STAGE` bumped `"54"` -> `"55"` in `casm.s` (the sole code
    change; a version-only completion increment per this project's
    established pattern from WP50-53). Full 25-target rebuild clean; build
    counter advanced exactly once (`1257` -> `1258`); code size unchanged
    at 18553 bytes (a 2-character string literal swap has no size delta).
    Live-verified via VICE: booted `casm_phase10_test.d64` fresh, ran
    `casm` with no source argument, confirmed `CASM V0.1.55.1258` then
    `CASM: SOURCE FILE REQUIRED` on real emulated hardware.
  - `CHANGELOG.md`: added a WP54 entry under `### Added`, ahead of the
    existing WP53 entry, following the same format/depth WP52/WP53 used.
  - `wiki/casm-utility.md` (mirrored verbatim to `docs/casm-utility.md`):
    version banner bumped, Phase 10 status callout rewritten (no longer
    "planning-only"), `/M`/`/L` parameter descriptions rewritten to
    describe real behavior, a new "Map and Listing Output (`/M`, `/L`)"
    section added with concrete examples, and both switches removed from
    "Not Yet Supported" (replaced with the real remaining gap: an `/O`/`/L`
    output-name collision hangs rather than replacing, a pre-existing
    `fileCreateOutput` limitation, not a WP54 regression).
  - `wiki/casm-programmers-reference.md`: status banner rewritten (was
    still describing Phase 10 as "planning-only, no code landed" despite
    WP50-53 having shipped modules already); architecture diagram gained
    `map.s`/`listing.s` nodes; the `start` call-sequence description in
    §1 updated to the real WP54 order; §5's CLI table `/M`/`/L` rows marked
    implemented; a new §17 "Symbol Map & Listing Output (Phase 10,
    complete)" added, covering `map.s`'s `mapPrint` contract, `listing.s`'s
    two lifecycles (capture and file), the WP54 wiring/artifact-safety
    order, and the real WP54 `CasmVmmBuffer`-clobber bug fix; old §17
    Coverage renumbered to §18 (content updated: `/M`/`/L` moved to
    "Works", diagnostic count corrected to 66, the `fileCreateOutput` gap
    added as a real "not yet implemented" item); old §18 Diagnostic
    Reference renumbered to §19 (added the 10 missing Phase 10 rows,
    `$39`-`$42`, and corrected the `$0A` `NOT_IMPLEMENTED` row to no longer
    list `/M`/`/L`); old §19 Extending renumbered to §20. All internal
    anchors and the two cross-references from `casm-utility.md` updated to
    match.
  - `wiki/tasks/casm.md` and `wiki/tasks/casm-phase10-symbol-map-listing.md`:
    WP54 checked off complete with completion metadata; WP55 lines updated
    from "Blocked by WP54" to "Unblocked, not yet started." Phase 10's own
    Acceptance checklist left unchecked deliberately — that belongs to
    WP55's own verification-walkthrough-completion-gate, not this WP.
  - `brain/walkthroughs/2026-08-08-casm-phase10-wp54-production-integration.md`
    added, matching WP53's own walkthrough-doc precedent (checked before
    writing this entry, not assumed): Scope, the increment-1 scope
    deviation, Implementation Review, Runtime Walkthrough, Envelope/
    Regression, Version-Only Completion Increment, and Completion Gate
    sections.
  - Taskwarrior task 36 marked `Completed` (`task 36 done`), matching
    WP53's own precedent (task 35/`aa57f461` was marked `Completed` with an
    `End` date on its own user approval, not left `Pending`) — verified by
    checking task 35's actual history before writing this entry, since an
    earlier draft of this note incorrectly guessed the opposite convention.

**WP54 is complete.** `/M` and `/L` are both fully implemented in
production CASM `0.1.55` (build 1258). WP55 (verification, walkthrough, and
the Phase 10 completion gate) is unblocked and ready to start whenever the
user wants to begin it — it is a separate, not-yet-approved plan and this
document does not activate it.
