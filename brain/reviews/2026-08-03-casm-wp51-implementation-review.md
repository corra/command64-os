---
feature: casm-phase10-wp51-listing-stores-capture
created: 2026-08-03
status: draft
---

# WP51 Implementation Review (Atomic Increment 9)

Full re-read of every production file WP51 touched (`listing.s`, `source.s`,
`emit.s`, `casm.s`, `diagnostics.s`, `common.inc`), checked bullet-by-bullet
against `brain/plans/2026-07-29-casm-phase10-wp51-listing-stores-capture.md`.
No discrepancies found; no source changes made by this review.

## Storage Architecture

- `listingCaptureInit` requests exactly two `$FFFF`-byte (65,535) allocations
  via `vmmStoreAlloc` (`listing.s:198-208`); `vmmStoreAlloc` itself rounds to
  a 65,536-byte/16-page grant (verified in `vmm_store.s`, unchanged by WP51).
- A second-allocation failure leaves the first slot's number stored in
  `CasmListingMetaVmmSlot` and returns without freeing it -- matches the
  plan's "second-allocation failure leaves the first centrally owned for
  fatal cleanup," consistent with `symbols.s`/`reloc.s`'s own precedent of
  never freeing explicitly outside `resourcesCleanup`.
- Metadata: `listingMetaAppend` checks count against `CASM_LISTING_META_MAX`
  (4,096) before append, zero-fills all 16 bytes first (`lmaZeroLoop`), then
  stages named fields, computes `offset = index << 4` via four `asl/rol`
  shifts, and writes exactly `CASM_LISTING_META_REC_SIZE` (16) bytes in one
  `vmmWindowWrite`. `listingReplayNext` reads the same way, repeat-stable at
  EOF (`lrnHaveRecord`'s carry-based index-vs-count comparison, unchanged
  cursor on EOF/failure).
- Byte mirror: `CasmListingStage`/`StageLen` buffer up to
  `CASM_LISTING_STAGE_SIZE` (64, asserted equal to `CASM_VMM_BUFFER_SIZE`)
  bytes; `listingFlushStage` copies into `CasmVmmBuffer`, derives the
  destination as `cursor - StageLen`, writes one `vmmWindowWrite`, clears
  `StageLen` only on success. No byte-at-a-time VMM call exists anywhere in
  `listing.s`.

## Source Capture

- Exactly 11 new BSS bytes in `source.s`: four internal
  (`CasmSourceBlockBase*`/`CasmSourceLineStart*`) plus the seven-byte public
  `CasmSourceCompleted*` sidecar -- confirmed by grep, matches WP50's frozen
  budget with none held back.
- `sourceSetLineCapture`: `A=0` disables and clears
  `CasmSourceCompletedFlags` entirely (also clearing any stale VALID);
  nonzero sets the private `CASM_SOURCE_CAPTURE_ENABLED` bit and re-anchors
  `LineStart` from the live cursor. Carry always clear; no VMM/filesystem
  call.
- `sourceTakeCompletedLine`: masks off the private ENABLED bit on the
  returned value (`and #%01111111`), clears VALID on consume
  (`and #%11111110`) while preserving ENABLED/reserved bits, preserves X/Y
  (no register touches either register), never fails, never touches VMM or
  filesystem. Matches the ABI exactly.
- `sourceCaptureNewline`/`sourceCaptureFinal` (not re-quoted here, reviewed
  in increment 2's own progress notes and re-checked now): publish on
  CR/LF/CRLF/EOF/frame-pop, raise `CASM_DIAG_LISTING_REPLAY_MISMATCH` on an
  unconsumed sidecar, and the CRLF one-byte `LineStart` nudge fix from
  increment 2 is still in place at the LF-swallow site in
  `sourceNextResult`.

## Listing Module ABI

- `listingStateInit`: clears every WP51-added field (state, record/replay
  counters, byte cursor/full/stage-length, transaction-active) without
  acquiring any resource -- confirmed increment 4's own found-and-fixed bug
  (missing byte-cursor/stage/txn resets) is still fixed; no regression.
- `listingCaptureInit`: requires `NONE`, allocates both slots, resets
  counters, enables source capture only after both allocations succeed, sets
  `ENABLED` last. Diagnostics propagate unchanged from `vmmStoreAlloc`.
- `listingBeginLine`: no-op when disabled; duplicate begin (already-active
  transaction) raises `REPLAY_MISMATCH`; otherwise snapshots PC, byte
  cursor, and full flag and marks active.
- `listingMirrorByte`: no-op when disabled; requires an active transaction;
  rejects before mutation when already full; stages/advances/flushes on
  every full 64-byte stage; sets `CasmListingByteFull` on the exact
  65,536-byte wrap (cursor `0000` after increment). Stack-balanced on every
  exit path (verified in increment 8's audit, re-confirmed here).
- `listingCommitLine`: no-op when disabled; requires an active transaction;
  no-pending or synthetic-only completion clears the transaction with no
  record; a real physical line translates the sidecar's
  `FINAL_UNTERMINATED` bit into the metadata record's own bit, computes the
  byte delta (plain subtract, or 16-bit negate on the exact-wrap case
  distinguished via `CasmListingTxnFullFlag` vs the live `CasmListingByteFull`),
  and always clears the transaction whether or not the append succeeds.
- `listingCaptureFinalize`: requires `ENABLED`, no active transaction, and
  no unconsumed sidecar (peeked directly, never consumed here); flushes the
  final partial stage, disables source capture, marks `COMPLETE`. Neither
  VMM allocation is freed here -- both stay live for WP53, per the plan.

## Emitter Integration (`emit.s`)

`emitByte` stacks the input byte across `emitRawByte`; on success, restores
it and calls `listingMirrorByte` (no-op when disabled) before the PC
increment; a `listingMirrorByte` failure returns before the PC increment; a
prior `emitRawByte` failure discards the stacked byte via `tax/pla/txa`
without disturbing its own diagnostic in `A`. Exactly matches the plan's
six-step sequence. Stack balance re-verified in increment 8's audit.

## Pass and Include Integration (`casm.s`)

- `crpListingBegin`/`crpListingCommit` gate on `CasmPassMode ==
  CASM_PASS_MODE_EMIT` (Pass 2 only), no-op (clc/rts) in Pass 1 -- both
  helpers are also no-ops when capture itself is disabled, so this gate
  only matters once WP54 ever turns capture on in production.
- `casmRunPass` begins a transaction at the top of every iteration and
  commits after every label/instruction/directive dispatch branch and after
  NEWLINE, before looping; `crpDone` (EOF) commits once more with no record
  of its own for EOF.
- `crpInclude`'s `crpIncCommit` commits the parent's own line -- the
  `.INCLUDE` statement itself -- immediately before `crpIncPush` switches
  traversal into the child; any earlier catalog/event resolution failure
  routes to `crpIncFail` directly and commits nothing.

## Diagnostics (`common.inc`, `diagnostics.s`)

`$39`-`$3C` (`NAME_COLLISION`/`RECORDS_FULL`/`BYTES_FULL`/`REPLAY_MISMATCH`)
contiguous with Phase 9's own last diagnostic, all four asserted by
`.assert` chains; `$3D`-`$41` reserved for WP53 with their own contiguity
asserts, no message-table entries yet (correct -- not WP51's job).
`diagPrintFatal`'s range cap was bumped to `CASM_DIAG_PHASE10_WP51_LAST + 1`
in increment 6, confirmed still in place, so all four WP51 diagnostics
render real text instead of falling through to "INTERNAL ERROR."

## Harnesses

- `test_casm_listing` (11 fixtures) exercises `listing.s` directly with
  synthetic staged fields: allocation/grant failure, metadata
  zero-fill/offsets/replay, 4,096/4,097-record boundary, 63/64/65-byte
  stage boundary, 65,535/65,536/65,537-byte boundary, transaction
  edge cases, and finalize preconditions. All eleven fixtures confirmed
  passing live under VICE (increments 3-4).
- `test_casm_listcap` (7 fixtures) drives a real two-pass assembly with
  capture genuinely enabled through `casm.s`'s actual dispatch shape
  (reimplemented verbatim in the harness): newline variants, final
  unterminated line, deferred-data byte-count/255-length boundary,
  labels + nested `.INCLUDE` with parent-resume ordering, multi-root
  synthetic-separator attribution, and capture-off/on PRG identity. All
  seven fixtures confirmed passing live under VICE, first attempt
  (increment 6).

## Envelopes (Increment 7)

Re-verified in this review: `casm` ($4900), `test_casm_pass1` ($4700),
`test_casm_passcheck` ($4300, tightened in increment 7),
`test_casm_frame` ($4700), `test_casm_listing` ($1300),
`test_casm_listcap` ($4B00), `test_casm_catalog`/`test_casm_event`
($1E00 each) are all at the smallest 256-byte-aligned fit measured
against a real `ld65 -m` map.

## Stop Conditions Checked

- BSS growth: exactly 11 new source.s bytes, none in listing.s beyond its
  own module state (no additional source-side capture storage).
- VMM allocations: exactly six `vmmStoreAlloc` call sites exist in the
  entire tree (source/symbols/reloc/include-event/listing-meta/
  listing-byte) -- listing.s added exactly two, not a third.
- No byte-at-a-time VMM write exists in `listing.s`.
- Metadata record is exactly 16 bytes (`.assert
  CASM_LISTING_META_REC_SIZE = 16`); the 65,536-byte endpoint is
  unambiguous (exact wrap detection, not an off-by-one range check).
- No envelope needed to exceed `$4C00` (highest is `$4B00`).
- `crpInclude`'s parent-before-child commit order is intact; no Pass 2
  source I/O was added (capture reads only already-buffered source state);
  no PRG/relocation/provenance/parser change outside the documented
  `emitByte` sequence; no new zero-page use anywhere in the diff.

## Conclusion

Every plan requirement checked against the actual WP51 diff (`4ae8b67..HEAD`)
holds. No defects found in this pass; no source changes made. Ready for
Atomic Increment 9's second half: a user-run runtime walkthrough under VICE
(see companion checklist) before requesting completion approval and the
`0.1.52` version bump (Increment 10).
