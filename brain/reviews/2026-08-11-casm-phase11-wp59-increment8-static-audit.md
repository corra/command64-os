# CASM Phase 11 WP59 Increment 8 Static Audit

## Result

No production defect, private zero-page allocation, unsafe shared-scratch live
range, uninitialized load-bearing BSS, ownership disagreement, or unintended
valid-output behavior was found in `listing.s` or `map.s`.

## Zero Page And Scratch

- Neither module defines a `ZEROPAGE` segment, fixed private alias, `.exportzp`,
  or `.importzp` symbol.
- `listing.s` uses only shared `common.inc` pointer/value/I/O/VMM aliases and
  consumes or reinitializes each before subordinate calls can invalidate it.
- Persistent listing values that cross OS, VMM, include, source, or file calls
  live in BSS. This includes requested write lengths, primary diagnostics,
  validation byte counts, serializer records, row cursors, and running spans.
- `map.s` retains cursor/count state in BSS. `symbolsReadByIndex` initializes
  transfer aliases for each read, and `mapPrint` retains no register or shared-ZP
  value across `diagPrintString`; Increment 7 proves volatile A/X/Y behavior.

## BSS And Repeat Safety

- Production calls `listingStateInit` and `listingFileInit` before any fallible
  initialization or fatal cleanup path.
- Capture transactions, pending metadata, validation state, file ownership,
  serializer records, row cursors, and aggregate state all have dominating
  writes before reads. Failed close/delete state is intentionally retained for
  caller-driven retry.
- Every `mapPrint` entry clears cursor and count. Scratch and row buffers are
  fully overwritten before use; the 40-byte row buffer bounds the maximum
  39-byte formatted record including CR and null.

## Ownership And Exports

- Listing ownership still begins immediately after successful open. Registered
  handles close through `fileClose`; private unregistered handles close through
  `DOS_CLOSE_FILE`; committed listings are never deleted.
- `map.s` owns no VMM, file, source, or cleanup resource. Its sole export,
  `mapPrint`, is consumed by production and the map harness.
- Listing routine and state exports have production or direct-harness consumers,
  except `CasmListingOpenName`. That unused legacy export is retained and
  documented because removal would be an unapproved module-ABI change.

## Corrections

- Updated stale pre-WP54 comments in `listing.s` and `map.s` to describe active
  production `/L` and `/M` integration.
- Updated stale `test_casm_map` historical/link-order comments.
- No executable instruction, storage declaration, export set, diagnostic,
  output format, or ownership behavior changed.

## DOX Pass

`src/external/casm/AGENTS.md`, `tests/AGENTS.md`, and the root DOX remain
accurate. The audit introduced no durable contract requiring a DOX change.
