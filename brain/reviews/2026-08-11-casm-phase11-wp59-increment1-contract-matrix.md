# CASM Phase 11 WP59 Increment 1 Contract Matrix

Status: Frozen for user review
Branch: `feature/casm-phase11-wp59`
Baseline: CASM `0.2.0` build `1260`
Plan: `brain/plans/2026-08-11-casm-phase11-wp59-listing-map-hardening.md`

## Scope and Method

This is the Increment 1 gate artifact. It traces all 19 exported routines in
`listing.s` and `map.s` directly from current source, including every
load-bearing private callee. It records the current header contract, actual
success/failure state commits, existing fixture evidence, and the missing proof
assigned to later approved increments.

No production or fixture source changed while producing this matrix.

Notation:

- `A/C` means the diagnostic or stream selector in `A` and carry status are an
  inseparable return contract.
- `SP` means the stack pointer must equal its entry value on every return.
- "unspecified A" means a path promises carry/no mutation only; WP59 must not
  accidentally strengthen that ABI through a test expectation.
- Shared scratch names refer to `common.inc` zero-page or shared transfer state,
  not module-private allocation.

## Exported Routine Matrix

| # | Routine | Inputs and success return | Failure/no-op return | Declared clobber and scratch | Existing evidence | Frozen WP59 gap |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `listingStateInit` | none; `A=NONE`, C clear | none | A only; writes listing state, record/replay counters, byte cursor/full, stage length, transaction flag | repeated setup in `casm_listing`/`casm_listwrite` | poison BSS; assert every load-bearing field, X/Y preservation, C/A, SP, repeat safety |
| 2 | `listingCaptureInit` | state `NONE`; allocates metadata and mirror stores, enables source capture; `A=NONE`, C clear | bad state -> `STREAM_STATE_FAILED`; VMM diagnostic propagated; state unchanged | A/X/Y, `CasmValue0Lo/Hi`, resource registry | normal dual allocation; second-allocation exhaustion | wrong-state A/C/SP; injected first allocation unavailable/OOM; injected second allocation failure; exact first-slot ownership after second failure |
| 3 | `listingMetaAppend` | staged pending record; write then increment count; C clear | records full or VMM transfer failure; count unchanged | A/X/Y, VMM buffer/off/count | field layout, reserved-zero, 4096 boundary, freed-slot failure | injected real VMM write failure, A/C/SP, no count/cursor commit |
| 4 | `listingReplayReset` | capture `COMPLETE`; resets replay and expected-byte cursors; `A=NONE`, C clear | wrong state -> `STREAM_STATE_FAILED` | A only | normal/repeated replay setup | explicit wrong-state and exact cursor mutation; X/Y/SP |
| 5 | `listingReplayNext` | prior reset; data -> `A=DATA`, C clear and cursor advances; EOF -> `A=EOF`, C clear, cursor stable | VMM transfer failure; cursor stable | A/X/Y, VMM buffer/off/count | ordered replay, repeat-stable EOF, freed-slot failure | injected read failure after valid records; exact cursor and A/C/SP |
| 6 | `listingBeginLine` | enabled capture; snapshots PC/cursor/full, activates transaction; `A=NONE`, C clear | duplicate -> `REPLAY_MISMATCH`, C set; disabled -> C clear/no-op, A unspecified | A only | normal snapshot, duplicate begin, transitive disabled use | explicit disabled-state no-mutation without constraining A; X/Y/SP |
| 7 | `listingMirrorByte` | A=byte, enabled active transaction; stage/cursor advance, optional flush; C clear | no transaction -> mismatch; full -> bytes full; flush failure -> VMM diagnostic; disabled -> C clear/no-op, A unspecified | A/X/Y, VMM buffer/off/count; one balanced PHA/PLA path | transaction rejection, 63/64/65 stage edges, 65535/65536/65537 store edges | injected stage-flush failure, retained stage/cursor commit-point state, disabled no-op, every PHA/PLA return SP |
| 8 | `listingCommitLine` | active transaction; consumes sidecar; appends zero/one record; clears transaction; `A=NONE`, C clear | missing transaction -> mismatch; append failure propagates and clears transaction; disabled -> C clear/no-op, A unspecified | A/X/Y, pending record, VMM scratch | real/synthetic/no sidecar, zero-byte line, ordinary byte delta | explicit missing transaction; injected append failure; exact-full delta; disabled no-op; A/C/SP and clear-on-failure |
| 9 | `listingCaptureFinalize` | enabled, no transaction/sidecar; flushes stage, disables capture, sets `COMPLETE`; `A=NONE`, C clear | wrong state -> stream state; active transaction/sidecar -> mismatch; flush failure propagated; state unchanged | A/X/Y, VMM scratch | transaction/sidecar rejection, partial-stage success | wrong state; injected final flush failure; capture-enable/state invariants; A/C/SP |
| 10 | `listingFileInit` | none; closed/invalid/zero state; `A=NONE`, C clear, Z set | none | A/flags; explicitly preserves X/Y | used before all file fixtures | poison all file BSS; assert each field, X/Y, C/A/Z, SP, repeat safety |
| 11 | `listingCreate` | state closed and derived name; open/register; state open, opened/valid true; `A=NONE`, C clear | bad state -> stream state; open or registration reject -> listing create failed | A/X/Y, `HexVal*`, `FileHandle`, OS volatile, `CasmValue1Lo` | normal, prefixed, replacement | bad state; open injection; registry failure; compensating close/delete and retry ownership; A/C/SP |
| 12 | `listingWrite` | state open, pointer X/Y, requested count; exact count -> `A=NONE`, C clear | bad state; OS write failed; short write; latter two invalidate listing | A/X/Y, `HexVal*`, `FileHandle`, request state; balanced PHP/PLP | successful disk write/readback | bad state; write/short injection; exact returned count, valid flag, PHP/PLP SP |
| 13 | `listingClose` | currently requires open; closes/releases and clears ownership; `A=NONE`, C clear | bad state; close failed -> listing close failed and `CLOSE_FAILED` | A/X/Y and `fileClose` scratch | normal close | confirmed retry defect; registered/unregistered close; close failure then unlimited caller retry; A/C/SP/ownership |
| 14 | `listingDelete` | derived plain name; delete -> `A=NONE`, C clear | OS reject -> listing delete failed | A/X/Y, OS volatile | transitive successful abort delete | direct success; injected delete failure; exact name and A/C/SP |
| 15 | `listingAbort` | A=primary or none; best-effort close/delete; returns primary or first cleanup diagnostic; carry reflects nonzero A | failed close stops before delete; failed delete marks pending; committed listing bypasses delete | A/X/Y, private primary, nested close/delete scratch | normal uncommitted abort, committed preservation, primary preservation with successful cleanup | close/delete failure and retry; no-primary secondary selection; registered/unregistered ownership; every PHA/PLA and tail path SP |
| 16 | `listingValidateRecord` | VMM buffer record plus reset expected offset; validates and resolves; advances expected offset; `A=NONE`, C clear | structural mismatch or propagated catalog VMM failure; expected offset unchanged | A/X/Y, filename resolver scratch and byte-count stash | valid root/frame, flags/padding/span/PC/offset/id failures, catalog failure | invalid device 7/12; exact failure commit point; register/SP; re-prove shared-buffer stash |
| 17 | `listingResolveFilename` | A=packed root/frame ID; fills resolved name/length; `A=NONE`, C clear | ID mismatch -> replay mismatch; catalog read failure propagated | A/X/Y, `CasmPtr0Lo/Hi`, catalog/VMM scratch; balanced initial PHA/PLA | root/frame names, bounds, catalog failure, long header transitively | device 8/11 boundaries and invalid 7/12 before table index; resolved output unusable on failure; every PHA/PLA SP |
| 18 | `listingWriteFile` | capture complete, listing name, source closed, PRG committed, listing closed; creates/serializes/closes/commits; `A=NONE`, C clear | bad precondition -> stream state/no artifact; later failure returns primary after one abort | A/X/Y and all listing/source/include/VMM/file formatter scratch | empty/golden/continuation/aggregate/corruption cases | complete precondition matrix; replay/catalog/source/mirror/write/short/close/abort failure injection; immediate-stop, primary, cleanup, SP, artifact state |
| 19 | `mapPrint` | none; header, definition-order rows, total; `A=NONE`, C clear | invalid record or propagated symbol VMM failure | A/X/Y, map BSS, VMM scratch, diagnostics volatile | empty/one/order/case/31-char/bounds/repeat/corruption/VMM/full table | validation edges, partial-output failure, decimal transitions, diagnostics-clobber assumptions, A/C/SP |

## Private Transitive Call Tree

### Listing storage and capture

- `listingCaptureInit` -> `vmmStoreAlloc` twice -> `sourceSetLineCapture`.
- `listingMetaAppend` -> `vmmWindowWrite`.
- `listingReplayNext` -> `vmmWindowRead`.
- `listingMirrorByte` -> private `listingFlushStage` -> `vmmWindowWrite`.
- `listingCommitLine` -> `sourceTakeCompletedLine` -> `listingMetaAppend`.
- `listingCaptureFinalize` -> `listingFlushStage` -> `sourceSetLineCapture`.

### Listing file lifecycle

- `listingCreate` -> private `listingBuildOpenName` -> `DOS_OPEN_FILE` ->
  `resourceRegisterHandle`; registration failure currently calls
  `DOS_CLOSE_FILE` directly.
- `listingWrite` -> `DOS_WRITE_FILE`.
- `listingClose` -> `fileClose` for registered ownership.
- `listingDelete` -> `DOS_DELETE_FILE`.
- `listingAbort` -> `listingClose` -> `listingDelete`, with private
  `laRecordSecondary` preserving primary failure.

### Listing validation and serialization

- `listingValidateRecord` -> `listingResolveFilename` ->
  `includeCatalogRead` for frame IDs.
- `listingWriteFile` -> create, replay reset/next, validation/resolution,
  private record/header/detail emitters, source-span and byte-mirror readers,
  aggregate append/flush, write, close, and abort.
- Private formatting boundary: `lwHexNibble`, `lwPutChar`, `lwPutHexByte`,
  `lwPutSpaces`, `lwPutRawBytes`, `lwPutDec5`, and `lwd5Emit`.
- Private replay/output boundary: `lwReadByteMirrorChunk`, `lwPutByteGroup`,
  `lwPutSourceCols`, `lwEmitByteGroupRow`, `lwEmitSourceRow`, `lwAppendRow`,
  `lwFlushAggregate`, `lwEmitFileHeader`, `lwEmitDetailRows`, and
  `lwEmitRecordRows`.

### Map

- `mapPrint` -> `symbolsReadByIndex` -> private `mapValidateRecord` -> private
  `mapFormatRow` -> `mapWriteHexByte` -> `mapWriteNibble` ->
  `diagPrintString`.
- EOF -> private `mapFormatTotal` -> `diagPrintString`.

All private routines above are load-bearing and remain inside WP59's audit
boundary even though fixtures invoke only exports.

## Shared Scratch and Storage Freeze

Neither `listing.s` nor `map.s` defines private zero-page storage.

Listing uses imported shared state including:

- `CasmValue0Lo/Hi` through VMM allocation;
- `CasmValue1Lo` while staging an opened handle across registration;
- `CasmPtr0Lo/Hi` while resolving filenames;
- `CasmVmmOffLo/Hi`, `CasmIoLenLo/Hi`, and `CasmVmmBuffer` for VMM transfer;
- `HexValLo/Hi` and `FileHandle` for OS file calls;
- `CasmIoBuffer` as the post-source-close aggregate listing buffer.

Map owns only ordinary BSS and uses imported VMM transfer state through
`symbolsReadByIndex`.

Increment 8 performs the final static live-range proof. Any need for a new
zero-page byte is a plan stop condition.

## Confirmed Defect Paths

### D1: `CLOSE_FAILED` cannot retry

1. `listingClose` accepts only `CASM_FILE_STATE_OPEN`
   (`listing.s:1177-1179`).
2. A rejected `fileClose` stores `CASM_FILE_STATE_CLOSE_FAILED`
   (`listing.s:1194-1198`).
3. A direct retry therefore takes `lclBadState` and returns
   `CASM_DIAG_STREAM_STATE_FAILED` without another close attempt
   (`listing.s:1177-1179`, `1200-1203`).
4. `listingAbort` calls `listingClose` for every non-closed state
   (`listing.s:1260-1264`), so its promised retry is blocked by the same
   precondition.

Disposition: confirmed production defect; fix and inject direct/abort retries
in Increment 4.

### D2: registration failure loses ownership

1. `DOS_OPEN_FILE` succeeds and the handle is held only in `CasmValue1Lo`
   (`listing.s:1060-1064`).
2. `resourceRegisterHandle` rejects.
3. The failure path calls `DOS_CLOSE_FILE` once, ignores carry, does not record
   opened state, and does not delete the artifact (`listing.s:1078-1085`).
4. `listingWriteFile` returns directly on create failure because its comment
   assumes nothing was created (`listing.s:2354-2356`).

Disposition: confirmed production defect. Increment 4 records listing-private
ownership using the existing handle/state plus `CASM_INVALID_SLOT`, then closes
and deletes through retryable abort while preserving create failure as primary.

### D3: included-device table index is unchecked

1. A frame ID resolves through `includeCatalogRead`.
2. `listingResolveFilename` reads the catalog device, subtracts 8, and uses the
   result as an index (`listing.s:1502-1510`).
3. No range check precedes access to the four-entry `includeDeviceStrLo/Hi`
   tables.

Disposition: confirmed validation defect. Increment 6 accepts only 8-11 and
maps invalid metadata to `CASM_DIAG_LISTING_REPLAY_MISMATCH`.

## Stale Local Contract Findings

- `listing.s:8-9`, `15-18`, and `1566-1567` still describe `/L` as not wired
  into production.
- `map.s:8-10` still describes `/M` as not implemented.

Disposition: correct module/routine-local comments in Increment 8. Broad manual
and knowledge-base synchronization remains WP62.

## Frozen Increment Assignment

| Increment | Matrix responsibility |
| --- | --- |
| 2 | harness primitives; init, re-entry, disabled, wrong-state, register, flag, and stack contracts |
| 3 | capture allocation/read/write/stage/final-flush failures and commit points |
| 4 | D1/D2 lifecycle fixes plus create/write/short/close/delete/abort retry coverage |
| 5 | serializer transitive failure and cleanup matrix |
| 6 | D3 device validation and filename/catalog boundaries |
| 7 | map validation, decimal, partial-output, register, and stack expansion |
| 8 | final static ZP/BSS/export/header audit |
| 9 | consolidated build, artifact compatibility, and live verification |
| 10 | walkthrough, records, completion approval, and verified `0.2.1` increment |

## Increment 1 Gate

The matrix freezes these requirements before executable work:

- exactly 19 exported routines are in scope;
- all listed private transitive paths are load-bearing audit targets;
- D1-D3 are production defects assigned to WP59;
- no valid listing/map format change is expected or permitted;
- no new zero-page byte, diagnostic, public record, or envelope growth is
  pre-authorized;
- later fixture expectations must follow the current documented ABI and must
  not invent stronger disabled-path `A` guarantees.

Requested user decision: approve this matrix and activate Increment 2, or
request corrections while Increment 1 remains active.
