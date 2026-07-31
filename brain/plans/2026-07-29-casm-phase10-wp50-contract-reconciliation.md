---
feature: casm-phase10-wp50-contract-reconciliation
created: 2026-07-29
status: active-approved
taskwarrior: ad82f04d-0d34-4902-9a2c-ae27292902cf
---

# Plan: CASM Phase 10 WP50 - Contract Reconciliation and ABI Freeze

## Status and Authorization

This dedicated plan is approved and WP50 is active. WP50 freezes the exact ABI
required by WP51-WP55 but implements no map or listing behavior. No production
source, version, build, fixture, or memory-layout change is authorized until the
separate WP50 completion-only increment described below.

Parent plan: `brain/plans/2026-07-29-casm-phase10-symbol-map-listing.md`.

Baseline: CASM `0.1.50`, originally build 1204. Build 1205 on `main` as of
2026-07-31 -- see "Baseline Build Drift" below; no CASM source or behavior
changed.

## Objective

Reconcile the approved Phase 10 contract with the live Phase 9 source, lexer,
parser, include, emitter, symbol, output, resource, memory, and test
architecture. Freeze source-line spans, listing transactions, metadata, the
65,536-byte endpoint, diagnostics, fixture ownership, and stop conditions before
WP51 planning or implementation.

WP50's only eventual production change is the standard completion-only version
increment from `0.1.50` to `0.1.51` after verification and explicit approval.

## Reconciled Findings

1. `CasmStmtLoc*` preserves statement file, line, and column but not source
   offset or physical line length.
2. `CasmSourceOffset*` is a per-boundary count, not an absolute VMM address.
3. `CasmSourceVmmCursor*` is a refill read head up to 256 bytes ahead of parse.
4. The 39-byte token record and 47-byte lexer state are frozen and cannot grow.
5. Whitespace, comments, 255-byte lines, newline normalization, deferred data
   directives, and include frames prevent reliable token-based reconstruction.
6. `.INCLUDE` physically consumes its terminator before `sourceFramePush`, while
   the buffered normalized newline is invalidated by the push.
7. EOF creates no row itself, but may complete a final comment-only,
   whitespace-only, or statement line that must be recorded.
8. `emitByte`, not `emitRawByte`, is the source-generated-byte boundary.
9. The next free diagnostic is `$39`.
10. MAIN uses the `$4300` envelope with 85 bytes recorded headroom; private zero
    page is fully allocated.
11. Two `/L` allocations bring worst-case VMM ownership to six of eight slots.
12. Exactly 65,536 bytes require state beyond a wrapped 16-bit cursor.

## Phase 0C.20 Source-Span Freeze

### Source Block Position

WP51 may add exactly four source-owned internal bytes:

```text
CasmSourceBlockBaseLo/Hi
CasmSourceLineStartLo/Hi
```

- Block base is the absolute source-VMM address of the installed refill block.
- A fetched byte's offset is block base plus block index before advancement.
- Line start tracks the first physical byte of the active line.
- CR, LF, CRLF, EOF, frames, roots, and synthetic separators update it
  explicitly.
- No reporting consumer reconstructs position from `CasmSourceVmmCursor`.

### Completed-Line Sidecar

WP51 may add this seven-byte source-owned public sidecar outside frozen records:

| Field | Bytes |
|---|---:|
| `CasmSourceCompletedStartLo/Hi` | 2 |
| `CasmSourceCompletedLength` | 1 |
| `CasmSourceCompletedFileId` | 1 |
| `CasmSourceCompletedLineLo/Hi` | 2 |
| `CasmSourceCompletedFlags` | 1 |

Flags:

```text
bit 0: VALID
bit 1: SYNTHETIC_ONLY
bit 2: FINAL_UNTERMINATED
bits 3-7: reserved, always zero
```

- Publish exactly once when a physical line completes.
- Length excludes CR, LF, and CRLF.
- A separator with no physical line is synthetic-only and produces no record.
- A separator terminating a real final line publishes that physical line.
- EOF publishes a final line only when physical payload exists.
- Empty source and EOF after a physical newline publish no additional line.
- Capture identity and line before root/frame transition.
- Keep the sidecar valid until consumed by the listing transaction.

### Public Routine

WP51 implements `sourceTakeCompletedLine` with this proposed ABI:

- Input: none.
- Pending line: carry clear; `A = flags` with `VALID`; fields remain readable;
  pending-valid state is consumed.
- No pending line: carry clear; `A = 0`.
- No failure, VMM, or filesystem operation.
- Preserve `X` and `Y`; clobber `A`, flags, and source validity state.

If WP51 analysis shows preserving both index registers is materially worse than
a volatile ABI, stop and amend before implementation.

## Listing Transaction Freeze

When `/L` is enabled, WP51 wraps each Pass 2 `parserParseStatement` iteration.

Before parsing, snapshot starting PC, byte cursor, and full flag and mark one
transaction active. After dispatch, call `sourceTakeCompletedLine`, append one
record only for a physical line, assign the mirrored-byte delta, and clear the
transaction only after append succeeds.

- Parser NEWLINE commits a zero-byte physical row.
- EOF creates no row but can commit a pending final physical line.
- Empty source and synthetic-only separators create no row.
- Parse/emission failure commits no partial record.
- `.INCLUDE` commits its parent line immediately before `sourceFramePush`, so
  parent metadata precedes child traversal.
- No listing path loads includes or adds Pass 2 filesystem I/O.

## Metadata ABI

Freeze one 16-byte record:

| Offset | Field | Size |
|---:|---|---:|
| 0 | Packed file ID | 1 |
| 1 | Flags | 1 |
| 2-3 | Physical line | 2 |
| 4-5 | Source VMM offset | 2 |
| 6 | Source payload length | 1 |
| 7 | Reserved | 1 |
| 8-9 | Starting PC | 2 |
| 10-11 | Byte-stream offset | 2 |
| 12-13 | Emitted-byte count | 2 |
| 14-15 | Reserved | 2 |

Record flag bit 0 means `FINAL_UNTERMINATED`; all others are reserved zero.
Exactly 4,096 zero-filled records consume 65,536 bytes. Check count before
append, derive record offset by left-shifting index four bits, omit synthetic
rows, and embed no filename or formatting state.

## Emitted-Byte Endpoint

Freeze a 16-bit cursor plus `CasmListingByteFull`:

- Cursor is the next free offset while not full.
- Byte 65,536 writes at `$FFFF`, wraps cursor, and sets full.
- The next byte fails before mutation.
- Zero-byte rows remain valid after full.
- Nonzero-byte rows cannot begin after full.
- Per-line count is checked for 16-bit overflow.
- Mirroring is Pass 2-only and must agree transactionally with successful PRG
  emission without changing PC.
- WP51 freezes exact ordering around `emitRawByte` after carry-path analysis.

## Diagnostic Reservation

```text
$39 CASM_DIAG_LISTING_NAME_COLLISION
$3A CASM_DIAG_LISTING_RECORDS_FULL
$3B CASM_DIAG_LISTING_BYTES_FULL
$3C CASM_DIAG_LISTING_REPLAY_MISMATCH
$3D CASM_DIAG_LISTING_CREATE_FAILED
$3E CASM_DIAG_LISTING_WRITE_FAILED
$3F CASM_DIAG_LISTING_CLOSE_FAILED
$40 CASM_DIAG_LISTING_DELETE_FAILED
$41 CASM_DIAG_LISTING_SHORT_WRITE
```

Reuse filename-too-long and generic VMM diagnostics. Reuse malformed-output
only if WP53 proves identical semantics; otherwise amend. WP50 adds no constants.

## File Ownership Freeze

WP53 uses listing-specific handle, resource slot, open/close state, replacement
state, validity state, and deletion eligibility. WP50 must trace `DOS_OPEN_FILE`
replacement semantics and stop if safe cleanup requires an unapproved OS change.

### Resolved: Listing Replacement Requires No OS Change

Traced `fileOpen` (`src/command64/file.asm`), `normalizeName`, and
`parsePointerDevice` (`src/command64/utils.asm`):

- `normalizeName` only case-shifts A-Z; `@` and `:` pass through untouched.
- `parsePointerDevice` matches only a literal `8:`/`9:`/`10:`/`11:` at the
  string's start, strips exactly those bytes, and forwards the remainder
  verbatim through `SETNAM`.

Consequence: CASM may embed CBM DOS's native `@0:` replace marker itself,
between the device prefix and the basename -- `cliDeriveListingName`/
`CasmListingName` construct `<device-digits>:@0:<basename>.LST`.
`parsePointerDevice` still strips the leading `8:`/`9:`/`10:`/`11:` for device
targeting exactly as today; the untouched `@0:<basename>.LST` remainder reaches
the drive. No `DOS_OPEN_FILE` change, no new OS API, and no existence probe are
required.

`@0:` is unconditionally safe on real CBM DOS whether or not the target file
already exists: the drive performs an atomic scratch-and-rename internally
(creates if absent, replaces if present), and the previous valid file survives
untouched if the write is interrupted. WP53 therefore always opens the listing
write with the embedded `@0:` marker -- no existence check, no
create-vs-replace branch, and the atomicity comes for free.

This mechanism is traced from source only and is not yet runtime-verified
against this project's `DOS_OPEN_FILE` plus VICE-emulated-1541 stack. WP53's
harness (`test_casm_listwrite`) must add a fixture that writes a listing over
an already-existing file of the same name through the real OS/VICE path and
confirms the drive honors `@0:` as expected before WP53 relies on it in
production sequencing.

## Fixture Ownership

- WP51: line forms/newlines/bounds, deferred data directives, include traversal,
  synthetic separators, metadata and mirror endpoints, capture failures.
- WP52: 0/1/512 symbols, definition order, case/name limits, static/relocatable
  values, and exact map framing.
- WP53: name derivation, device/collision/overflow, formatting/continuations,
  PETSCII/CR, listing I/O failures, and valid-PRG retention.
- WP54: option combinations, roots/includes, static/R6 identity, conditional
  allocation, and map suppression.
- WP55: full regression/bounds, memory/ABI/stack/carry/resource/artifact audit,
  implementation review, native walkthrough, and `0.2.0` gate.

## Baseline Build Drift

Commit `f3b2e14` (DASH WP6, 2026-07-30) changed `include/ca65/command64.inc`,
a shared header CASM's build depends on. `add_ca65_app`'s hash-gate correctly
bumped every dependent build counter by exactly one, including
`src/external/casm/BUILD_CASM` (`1204` -> `1205`) and all nine
`tests/src/casm_*` build files, with zero CASM source or behavior change.
Confirmed by inspecting the commit diff: only `BUILD_CASM`-family counter
files and the shared header changed; no file under `src/external/casm/`
changed. WP50's measured baseline below is therefore CASM `0.1.50` build
`1205`, not the plan's original `1204`.

## Baseline Measurement Record

Recorded 2026-07-31 from a from-source `ld65 --mapfile` relink of the current
`casm_3900.cfg` (unmodified `.o`s, no rebuild) and from `build/casm.prg`:

- PRG size: 18,694 bytes (`build/casm.prg`, `0x0000`-`0x48FF` plus 2-byte load
  address). Footer bytes `00 38 38 08 52 36` confirm the R6 relocation-table
  marker (`52 36` = ASCII `R6`) is intact and terminal.
- Segments (from relink): `CODE` `003900`-`00670B` (`002E0C` = 11,788 bytes),
  `RODATA` `00670C`-`00718D` (`000A82` = 2,690 bytes), `BSS`
  `00718E`-`007BAB` (`000A1E` = 2,590 bytes), `HEADER` `009000`-`009001`
  (2 bytes).
- MAIN envelope: `$3900`-`$7BFF` (`$4300` = 17,152 bytes). Used through
  `$7BAB`; free from `$7BAB` to `$7C00` = 85 bytes, matching the plan's
  Reconciled Findings #10 exactly.
- Zero page: `common.inc` and `vmm_store.s`/`opcodes.s`/`cli.s` show CASM's
  private zero page fully allocated, consistent with Reconciled Findings #10
  ("private zero page is fully allocated"); WP50 approves no new zero-page
  byte, so no further slot accounting is needed until a work package requests
  one.
- File handles: `MAX_HANDLES = 8` (`include/ca65/command64.inc:166`), shared
  OS-wide, not CASM-specific.
- VMM stores: current worst-case CASM occupancy and the Phase 10 two-store
  addition are already reconciled in the parent plan's "Conditional VMM
  Stores" section (six of eight slots worst-case); no new finding here.

No `image_d64`/`test_image_d64` rebuild was performed in this recording
increment since no source changed; a same-source rebuild was already
confirmed stable (`casm` target reported up to date, no build-counter
movement) before this record was written.

## Scope

Included:

- Record and synchronize this plan and parent amendments.
- Measure the unchanged baseline through existing CMake targets.
- Develop and obtain approval for the WP51 plan.
- After explicit completion approval, apply only the `0.1.51` version increment
  and verify stability.

Excluded:

- Runtime reporting, `listing.s`, `map.s`, constants, BSS, VMM, or fixtures.
- Source/parser/lexer/emitter/file/diagnostic behavior changes.
- Activation or implementation of WP51-WP55.
- The optional progress feature.

## Expected Files

Planning: this plan, parent/task/knowledge/memory/changelog/DOX records.

Completion-only: `src/external/casm/casm.s`, build-managed `BUILD_CASM`, WP50
walkthrough, and final status records.

## Atomic Increments

1. Record this plan and activate only WP50.
2. Reconcile durable records.
3. Measure the unchanged `0.1.50` baseline.
4. Develop and approve WP51's dedicated plan.
5. Produce the WP50 walkthrough and request completion approval.
6. Only after approval, apply `0.1.51`, rebuild, synchronize, and request final
   closure.

## Verification

- Build CASM twice and confirm stable build number.
- Build `image_d64`, `test_image_d64`, and current CASM-specific images.
- Record PRG size/header/footer/relocations, CODE/RODATA/BSS, MAIN headroom,
  zero-page, file slots, and VMM slots.
- Confirm no behavior/artifact change before version-only completion.
- Verify Taskwarrior dependencies, `git diff --check`, and DOX closeout.

## Stop Conditions

- Sidecar cannot cover normalization, EOF, includes, and transitions without
  frozen-record growth.
- More than 11 source BSS bytes are required.
- Metadata exceeds 16 bytes or 65,536 bytes is ambiguous.
- Safe deletion requires an unapproved OS API change.
- New zero page is required or Phase 9 replay/provenance is weakened.
- Baseline differs materially or runtime changes appear before WP51 approval.

## Completion Gate

WP50 completes only after this plan and WP51's plan are approved, durable
records and Taskwarrior agree, baseline/documentation verification passes, the
user approves completion, version-only `0.1.51` builds stably, and the user
confirms final closure. Completion does not activate WP51.

## Progress

- 2026-07-29: User approved this plan. WP50 was activated; WP51-WP55 remain
  pending and blocked. No production or memory-layout change is authorized in
  this recording increment.
- 2026-07-31: Reconciled Findings 1-12, the source-span/sidecar freeze, the
  metadata ABI, the emitted-byte endpoint, and the diagnostic reservation were
  independently re-traced against the live `0.1.50` build 1204 source and
  confirmed exact, including a live `ld65 --mapfile` relink confirming the
  85-byte MAIN headroom claim precisely. Resolved the previously open listing
  file-ownership question (see "Resolved: Listing Replacement Requires No OS
  Change" above): WP53 embeds CBM DOS `@0:` itself, no OS change needed,
  pending a runtime fixture. No production or memory-layout change was made in
  this increment.
- 2026-07-31: Recorded the full baseline measurement (see "Baseline Build
  Drift" and "Baseline Measurement Record" above): committed CASM build is
  `1205`, not the plan's original `1204`, due to a harmless shared-header
  hash-gate bump from unrelated DASH work; no CASM source or behavior changed.
  Atomic increments 2 and 3 are complete. Increment 4 (WP51's dedicated plan)
  was already drafted and user-approved (`approved-blocked`) prior to this
  session. Remaining: produce the WP50 walkthrough and request completion
  approval (increment 5), then the version-only `0.1.51` bump (increment 6).
