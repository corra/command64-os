# CASM Phase 11 WP59 Listing and Map Hardening Walkthrough

## Completion State

WP59 implementation, audit, build, compatibility, and live verification are
complete and user-approved. CASM advanced to `0.2.1` after walkthrough
approval; the final version-only artifact and live banner were verified.

## Export Audit

The frozen detailed contracts and evidence are in
`brain/reviews/2026-08-11-casm-phase11-wp59-increment1-contract-matrix.md`.

| Export | Final disposition |
| --- | --- |
| `listingStateInit` | Poisoned/repeated initialization, registers, flags, and stack proven. |
| `listingCaptureInit` | Wrong state and both allocation-failure boundaries proven. |
| `listingMetaAppend` | Layout, limits, VMM failure, and commit point proven. |
| `listingReplayReset` | Repeated reset, wrong state, cursor, and register contract proven. |
| `listingReplayNext` | Ordered data, stable EOF, read failure, and cursor contract proven. |
| `listingBeginLine` | Normal, duplicate, disabled, mutation, and stack paths proven. |
| `listingMirrorByte` | Transaction, stage, full-store, flush-failure, and disabled paths proven. |
| `listingCommitLine` | Sidecar/no-sidecar, exact-full, append failure, and transaction cleanup proven. |
| `listingCaptureFinalize` | State, active-work rejection, partial flush, and retry invariants proven. |
| `listingFileInit` | Poisoned/repeated BSS initialization and A/X/Y/C/Z/SP contract proven. |
| `listingCreate` | State/open/register failures and private ownership compensation proven; fixed D2. |
| `listingWrite` | State, write, short-write, invalidation, returned-count, and stack paths proven. |
| `listingClose` | Registered/private ownership and unlimited caller-driven retry proven; fixed D1. |
| `listingDelete` | Exact-name success and injected failure contract proven. |
| `listingAbort` | Primary/secondary selection, close/delete retry, committed retention, and stack proven. |
| `listingValidateRecord` | Structural, offset, catalog, device, commit-point, and buffer-clobber paths proven. |
| `listingResolveFilename` | Root/frame bounds and devices 7/8/11/12 proven; fixed D3. |
| `listingWriteFile` | Preconditions and all replay/source/mirror/write/close/abort boundaries proven. |
| `mapPrint` | Validation, order, partial failure, totals, repeat, formatting, A/C/SP, and volatile print registers proven. |

`CasmListingOpenName` is the sole exported state symbol without a current
consumer. It is retained and documented as legacy module ABI rather than
removed without authorization.

## Private Paths

- Capture/storage: both allocations, metadata writes, replay reads, stage
  flushing, source sidecar consumption, and final capture disable were covered.
- File lifecycle: open-name construction, open/register, registered and private
  close, delete, abort, and secondary-diagnostic preservation were covered.
- Serializer: filename resolution, metadata replay, headers, byte groups,
  source columns, decimal/hex formatting, aggregate append/flush, close, and
  abort were covered.
- Map: symbol read, record validation, row/hex formatting, diagnostic output,
  and total formatting were covered.
- Static review found no private zero page, unsafe shared-scratch live range,
  uninitialized load-bearing BSS, ownership disagreement, or residual stack,
  register, carry, or valid-output defect.

## Fixed Defects

1. `listingClose` now permits one close attempt per call from `OPEN` or
   `CLOSE_FAILED`, retaining ownership until success.
2. Registration failure records private ownership, then performs retryable
   close/delete compensation while preserving `LISTING_CREATE_FAILED`.
3. Included listing devices are validated as 8-11 before indexing the
   four-entry device table; invalid metadata returns replay mismatch.
4. The test-only shared fault trampoline uses a RAM-patched absolute JMP rather
   than a relocatable indirect-JMP pointer that could land at `$xxFF` and invoke
   the NMOS page-wrap bug.

No new diagnostic, public record, production zero-page byte, or valid listing
or map format was introduced.

## Build And Artifact Evidence

- Production CASM build 1263: 18,580 code bytes and 2,806 relocations.
- Final map harness build 1013: 4,036 code bytes and 625 relocations.
- Listing harnesses retain the approved `$2400` and `$1A00` envelopes.
- The unrestricted build, `image_d64`, `casm_listing_test_d64`, and
  `casm_overflow_test_d64` pass; the no-change rebuild is stable.
- Representative valid PRG and R6 bytes remain unchanged from `0.2.0`.
- Listing rows and map ordering/format remain unchanged from `0.2.0`.
- The final listing test image has 72 blocks free after shared-stub placement
  hardening.

## Live VICE Evidence

| Program/path | Result |
| --- | --- |
| `test_casm_faultinject` | 8/8, `CASM FAULTINJECT: PASS`, shell return |
| `test_casm_flist` | 41/41, `CASM FAULT LIST: PASS`, shell return |
| `test_casm_flmeta` | 9/9, `CASM FAULT META: PASS`, shell return |
| `test_casm_map` | 23/23, `CASM MAP: PASS`, shell return |
| Production `/M` | `SYMBOL MAP`, `000 SYMBOLS`, input validated, shell return |
| Production `/L` | two-block formatted `.LST`, input validated, shell return |
| Production `/M /L` | map plus two-block `.LST`, input validated, shell return |

Every run used Command64 application dispatch under VICE 3.10, relayed overlay
testing/pass events, and returned to `C64[8]:>`. VICE remains running.

## Manual Confirmation

1. Boot `build/casm_listing_test.d64` and run `test_casm_flist`,
   `test_casm_flmeta`, and `test_casm_map` using PETSCII `$A4` for underscores.
2. Confirm 41, 9, and 23 dots respectively, each PASS banner, and `C64[8]:>`.
3. Boot `build/casm_phase10_test.d64` and run
   `casm casmemit1.s /o:m9b /m /l`.
4. Confirm `SYMBOL MAP`, `000 SYMBOLS`, `CASM: INPUT VALIDATED`, and shell
   return; `DIR` must show `m9b` PRG and `m9b.lst` SEQ.
5. Run `type m9b.lst` and visually confirm the file header and formatted source,
   byte, address, and continuation rows.

## Final Version Verification

- The user approved WP59 completion on 2026-08-11.
- CASM advanced from `0.2.0.1263` to `0.2.1.1264`.
- The PRG remains 24,200 bytes with 18,580 code bytes and 2,806 relocations.
- Byte comparison found exactly two changes: the banner stage byte `0` to `1`
  and build-number byte `3` to `4`.
- A second `image_d64` build retained build 1264 and the same SHA-256
  `fb1889317e2c7478cb037087889d4dc1615cc257a9d88c08157a914d9a4faa65`.
- Live VICE printed `CASM V0.2.1.1264`, the expected source-file-required
  diagnostic, and returned to `C64[8]:>`.
- WP59 and Taskwarrior task `4a1fab7c-28af-4404-af39-6f283b552e55` are complete.
