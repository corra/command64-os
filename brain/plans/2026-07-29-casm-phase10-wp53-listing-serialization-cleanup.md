---
feature: casm-phase10-wp53-listing-serialization-cleanup
created: 2026-07-29
status: approved-blocked
taskwarrior: aa57f461-36a9-455c-966f-ac484ec57b41
depends-on: 0bf2e86b-0bd0-443a-b84b-b2c258e98181
---

# Plan: CASM Phase 10 WP53 - Listing Naming, Serialization, and Cleanup

## Status

Approved but blocked by WP52 completion. No implementation is active.
Completion target: CASM `0.1.54`.

## Objective

Implement `.LST` derivation, PRG commit state, listing-specific file ownership,
metadata/source/byte replay, exact 40-column PETSCII serialization, buffered
writes, and incomplete-listing cleanup. Production `/L` remains gated to WP54.

## Listing Name

Add `CasmListingName[64]`, length, and `cliDeriveListingName`. Derive from final
output name: preserve device/basename, replace final suffix after device colon or
append `.LST`, reject empty filename/basename, overflow, malformed state, and
byte-identical PRG collision before resources. Use existing filename/malformed
diagnostics and `$39` collision.

## Source Read API

Add `sourceReadSpanChunk`: input absolute offset and 1-64 byte length in existing
VMM offset/I/O length cells; validate against authoritative loaded source and
return bytes in `CasmVmmBuffer`. Range disagreement raises `$3C`; transfer
failure remains generic. It changes no traversal state and exposes no source
slot.

## PRG Commit

Add `CasmOutputCommitted` and `outputCommit`. After emit/relocation finalization,
close/release the PRG handle and mark committed only on success. Amend
`outputAbort` so committed PRGs are never deleted; uncommitted behavior remains.

## Listing File State

Add listing handle, slot, state, opened, valid, committed, and delete-pending
state. Listing type is SEQ. Add dedicated create/write/close/delete/abort paths
mapping `$3D-$41`. Per WP50's frozen file-ownership resolution, the write-mode
open always embeds CBM DOS's native `@0:` replace marker between the device
prefix and basename (`<device-digits>:@0:<basename>.LST`) -- no existence
probe, no create-vs-replace branch, no OS change. This requires no new
`DOS_OPEN_FILE` semantics: `parsePointerDevice` strips the existing `8:`/`9:`/
`10:`/`11:` device prefix exactly as today, and `normalizeName` passes `@`/`:`
through untouched, so the embedded `@0:` reaches the drive unmodified. Add a
`test_casm_listwrite` fixture that writes a listing over an already-existing
same-name file through the real OS/VICE path and confirms the drive honors
`@0:` before this mechanism is relied on in production sequencing (WP54).
Abort preserves primary diagnostics, retries bounded close/delete, leaves
failed handles registered, and is repeat-safe.

## Serializer

`listingWriteFile` requires complete capture, derived name, closed source
traversal, committed PRG, live source/listing VMM, and no listing handle. It
creates listing, replays records, validates ranges/reserved fields, resolves
filenames, formats rows, buffers writes, closes, and marks committed.

Buffers: current record 16 bytes; row 41 bytes (40 + CR); reuse `CasmIoBuffer`
as a 256-byte aggregate after traversal closes. Never split a row; flush before
overflow and at final partial data; never issue zero-length writes.

## Filename Resolution

Top-level headers preserve original CLI spelling. Included headers use resolved
decimal device, colon, and prefix-stripped catalog name (`8:NAME` through
`11:NAME`), requiring no Phase 9 record growth.

## Exact Formatting

Headers preserve full names with 31-byte chunks. Detail rows follow the frozen
columns. Emit primary row, then all byte continuations, then all source
continuations. Use uppercase hex, five-digit decimal lines, exact source bytes,
space-filled fields, max 40 bytes before PETSCII CR.

## Validation

Require known flags, zero reserved bytes, valid source and byte ranges,
monotonic byte ranges, address/count consistency, and resolvable file identity.
Raise `$3C` on disagreement and generic VMM diagnostics on transfer failure.

## Diagnostics

Activate/render `$3D` create, `$3E` write, `$3F` close, `$40` delete, and `$41`
short-write. Listing file diagnostics are locationless.

## Harness

Add `test_casm_listwrite` covering suffix/device/collision/overflow; top-level
and resolved include headers; 31/32/63 name chunks; zero/four/five bytes;
14/15/28/29/255 source bytes; byte-first continuation order; line/address
bounds; raw PETSCII/CR; empty listing; aggregate 255/256/preflush/final partial;
create/write/short/close/delete failures; retry/repeat abort; primary
preservation; committed PRG retention and uncommitted PRG deletion.

## Production Boundary

Link all routines but retain `/L` NOT IMPLEMENTED and add no production calls to
`outputCommit` or `listingWriteFile`; WP54 owns sequencing.

## Envelope

Start from WP52, use smallest aligned increase, stop above preapproved `$5800`,
measure harness separately, and add no zero page.

## Expected Files

Modify `cli.s`, `listing.s`, `source.s`, `fileio.s`, `common.inc`,
`diagnostics.s`, CMake; add `tests/src/casm_listwrite/`; update fixture/image/
test DOX and durable records/walkthrough.

## Atomic Increments

1. Name derivation/tests.
2. Source span reader.
3. PRG commit/abort protection.
4. Listing file ownership/I/O/abort.
5. Replay validation/filename resolution.
6. Formatters and aggregate serializer.
7. Failure harness, linkage without activation, envelopes/regressions.
8. Review, walkthrough, approval, stable `0.1.54`, synchronization.

## Verification

Build via CMake at both origins; compare every listing byte; enforce row/CR and
aggregate bounds; prove no source I/O; verify commit-before-listing; exercise
all cleanup paths and artifact retention; audit resource/carry/stack/primary
diagnostics; confirm `/L` remains gated, stable builds, diff check, DOX.

## Stop Conditions

Direct source-slot exposure, include-record growth, row >40, another 256-byte
buffer, split rows, unsafe artifact distinction/deletion, extra listing handle,
source I/O, early `/L`, envelope >`$5800`, zero-page growth, or changed PRG/R6.

## Completion Gate

Requires WP52 completion, implementation/tests/envelopes/review/walkthrough,
explicit approval, stable `0.1.54`, and synchronized records. Does not activate
WP54.

## Progress

- 2026-07-29: User approved this plan. WP53 remains blocked by WP52; no
  implementation is authorized.
