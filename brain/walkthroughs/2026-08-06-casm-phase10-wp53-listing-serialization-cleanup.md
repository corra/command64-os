# CASM Phase 10 WP53 Verification Walkthrough

Status: Complete; user approved 2026-08-06
Branch: `feature/casm-phase10-wp53`
Candidate: CASM `0.1.54` build `1237`

## Scope

WP53 implements `.LST` name derivation, PRG commit protection, listing-specific
file ownership (create/write/close/delete/abort against a real `.LST` file,
including CBM DOS's native `@0:` replace-on-open marker), a random-access
source reader for the serializer (`sourceReadSpanChunk`), replay validation
and FILEID/filename resolution, and the full row/aggregate serializer
(`listingWriteFile`) implementing the frozen 40-column listing format. `/L`
remains rejected by production orchestration until WP54; WP53 writes no
`.LST` file from any production call site and adds no reachable production
behavior change.

## Implementation Review

Re-checked every plan requirement and Stop Condition against the actual diff
across all seven implementation increments:

- **Listing Name / PRG Commit / File Ownership** (increments 1-4): name
  derivation, `outputCommit`/`outputAbort` commit protection, and real
  create/write/close/delete/abort against CBM DOS, all VICE-proven.
- **Replay Validation / Filename Resolution** (increment 5):
  `listingValidateRecord` and `listingResolveFilename`, structural checks
  unified into one running-offset comparison per the field's own header
  comment, no separate upper-bound check needed.
- **Formatters and Aggregate Serializer** (increment 6): `listingWriteFile`
  formats the frozen row layout (file headers with 31-byte chunking, detail
  rows with independent byte/source continuations, uppercase hex, 5-digit
  zero-padded line numbers, exact verbatim source bytes) and buffers through
  the reused `CasmIoBuffer`, flushing before any row would split across the
  256-byte boundary.
- **Failure Harness and Regressions** (increment 7): failure/boundary cases
  reached through the real `listingWriteFile` orchestration, not routines in
  isolation.
- **Stop Conditions**: no direct source-slot exposure (`sourceReadSpanChunk`
  keeps its registry slot private); no Phase 9 include-record growth (reuses
  `CASM_INCLUDE_PHYS_REC_DEVICE`/`_NAME` verbatim); every row exactly 40
  bytes + CR (`common.inc` column-width `.assert`s); no second 256-byte
  buffer (`CasmIoBuffer` reused, confirmed by grep -- no new `.res 256`
  anywhere in `listing.s`); no split rows (`lwAppendRow`'s flush-before-
  overflow threshold, proven by increment 7's aggregate-boundary case); no
  unsafe artifact deletion (`listingAbort`'s committed-check, proven by
  increment 4's `abortAfterCommitProtects` and increment 7's mid-replay
  failure case); exactly one listing handle (`listingWriteFile`'s own
  `CasmListFileState == CLOSED` precondition); no source I/O beyond
  `sourceReadSpanChunk`'s own random-access reads; `/L`/`/M` still gated by
  `CasmCliOptions AND (CASM_OPT_MAP | CASM_OPT_LIST)` in `casm.s`'s `start`
  (file untouched by WP53); envelope `$5500`, below the `$5800` ceiling; no
  zero-page growth (every new WP53 field is `.res` inside `listing.s`'s own
  `BSS` segment; all reused scratch -- `CasmPtr0Lo/Hi`, `CasmValue0Lo/Hi`,
  `CasmVmmOffLo/Hi`, `CasmIoLenLo/Hi` -- are `common.inc`'s existing fixed
  zero-page cells, none newly defined); no PRG/R6 changes (`listingWriteFile`
  never touches output or relocation bytes).

## Runtime Walkthrough

User ran the harness live under VICE across the increment 5-7 sessions; this
increment's own closing re-verification, all on the current committed state
(`build/` rebuilt clean):

1. `test_casm_listwrite` (23 fixtures spanning increments 1, 4, 5, 6, 7):
   `CASM LISTWRITE: PASS`, 23/23, fresh hard-reset boot.
2. `test_casm_listing` (WP51's own capture harness, unmodified by WP53 except
   the `.LST` I/O routines' own new cross-module link requirements):
   `CASM LISTING: PASS`.
3. `test_casm_listcap` (WP51's real two-pass-assembly-with-capture-enabled
   harness -- the most exercising regression check available for
   `listing.s`'s shared capture state): `CASM LISTCAP: PASS`.
4. `test_casm_map` (WP52's own harness, unrelated to listing but shares
   `listing.s`'s linked object graph in several harnesses): `CASM MAP: PASS`.
5. Production `casm` sanity: ran with no source argument from the real
   `COMMAND64` shell on `image.d64`. Printed `CASM V0.1.54.1237` then `CASM:
   SOURCE FILE REQUIRED` -- normal, expected behavior, confirming the real
   application boots and runs unaffected by the WP53 changes linked into it.

Two real bugs were found and fixed during increments 5 and 6 (both already
committed with their own detailed explanations): a test-fixture A-register
clobber in `validatePropagatesVmmTransferFailure` that made a passing check
report as a failure regardless of actual behavior, and a genuine production
bug in `listing.s` where the `"FILE "` header-prefix text was written in
uppercase ca65 source (producing shifted PETSCII) instead of lowercase
(producing the unshifted PETSCII the arithmetic hex-digit formatter already
emits) -- see `reference-casm-charmap-hex-digit-formatting` and
`reference-casm-listingmirrorbyte-clobbers-y` in the session's own memory
records for the full detail. Increment 7's own three new cases (byte+source
continuation together, aggregate flush boundary, mid-replay validation
failure through the real orchestration) passed clean on the first VICE
attempt with no further bugs found.

## Envelope and Regression Verification

Final envelopes: `casm` (`$5500`), `test_casm_listwrite` (`$2100`),
`test_casm_listing` (`$1D00`), `test_casm_frame` (`$5000`),
`test_casm_passcheck` (`$4D00`), `test_casm_pass1` (`$5100`),
`test_casm_listcap` (`$5500`) -- each the smallest 256-byte-aligned fit
measured at the point its own overflow was hit. A full clean rebuild
(`rm -rf` a scratch build directory, reconfigure, `-j4`) and a subsequent
no-change rebuild both completed with zero errors across every target,
including `image_d64`, `test_image_d64`, and `casm_listing_test_d64`; the
no-change rebuild triggered no compile/link steps at all and reproduced an
identical `casm.prg` (md5-verified).

## Version-Only Completion Increment

User approved WP53 completion 2026-08-06. Applied the only production change
this increment authorizes: `VERSION_STAGE` `"53"` -> `"54"` in `casm.s`.
Results:

- The hash-gated build counter advanced exactly once: `1236` -> `1237`.
- A no-change rebuild immediately after held both the build counter and
  `casm.prg`'s md5 stable.
- `build/casm.prg` is 24,044 bytes (up from WP52's build -- real growth from
  WP53's `listing.s` additions across all seven increments, not a
  version-string artifact).
- Production `casm` prints `CASM V0.1.54.1237` and runs normally (see Runtime
  Walkthrough item 5).

## Completion Gate

Met 2026-08-06. CASM stands at `0.1.54` build `1237`, stable on a clean
rebuild. WP54 (production integration) is unblocked but not yet activated;
it requires its own explicit activation per the parent plan. `/L` remains
gated -- WP54 owns wiring `listingWriteFile`/`outputCommit` into the real
Pass 2 tail.
