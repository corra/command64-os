---
feature: casm-phase9-wp45-physical-file-catalog-and-dynamic-source-loading
created: 2026-07-25
status: complete
---

# Plan: CASM Phase 9 WP45 - Physical File Catalog and Dynamic Source Loading

## Objective

Add the new `src/external/casm/include.s` module: an 8KB metadata VMM store,
device/name canonicalization, a deduplicated physical-file catalog, and a
transient child-file load/append path that appends a new file's bytes to the
existing 65,535-byte source store without disturbing live traversal. WP45 is a
standalone module proven by its own dedicated test harness, exactly like WP27
(symbol table) and WP33 (VMM-backed source load) before their production call
sites existed. It adds **no** call site in `casm.s`/`source.s`'s production
traversal path: `casmRunPass` continues to return `CASM_DIAG_NOT_IMPLEMENTED`
at a valid `.INCLUDE` statement, unchanged from WP44. Frame push, traversal
switching, and wiring `include.s` into a live assembly are WP46's job.

Parent plan: `brain/plans/2026-07-25-casm-phase9-include-processing.md`.
Prerequisite plans: WP43 (`brain/plans/2026-07-25-casm-phase9-wp43-prerequisite-reconciliation.md`),
WP44 (`brain/plans/2026-07-25-casm-phase9-wp44-quoted-include-operand-grammar.md`).

Taskwarrior: `199b4da7-987a-44cf-a84d-b4e0b786f5d0` (pending activation).

## User-Confirmed Scope Decisions

Four architectural forks were resolved with the user before this plan was
written (superseding any looser wording in earlier records):

1. **Wiring boundary**: WP45 stays a standalone module plus harness. It does
   not touch `casmRunPass`'s `.INCLUDE` dispatch. `casm.s`'s existing WP44
   comment ("WP45 replaces this temporary semantic boundary with child
   loading") is corrected in this WP to name WP46 instead — that comment was
   written during WP44 before WP45 was actually planned in detail, and does
   not match the parent plan's own WP45/WP46 scope split.
2. **Device inheritance**: `DOS_OPEN_FILE` (`docs/api-reference.md`) resolves
   a device only from an explicit `<n>:` prefix in the filename string it is
   given, or else `CurrentDevice` — it has no separate device argument. Since
   an unprefixed child must inherit its *including parent's* resolved device
   (which may differ from `CurrentDevice`), `include.s` synthesizes an
   explicit `<n>:`-prefixed filename into a new transient scratch buffer
   before ever calling the file-open path, whenever the resolved device is
   not what `DOS_OPEN_FILE` would default to on its own.
3. **Append-cursor split**: `sourceLoad`'s private per-file streaming body
   (open, chunked read, chunked VMM write, close, combined-cap check) is
   factored into a shared private routine parameterized by a starting append
   offset. `sourceLoad`'s existing pre-pass loop keeps using
   `CasmSourceVmmCursorLo/Hi` exactly as today. A new dynamic entry point,
   `sourceAppendFile`, uses `CasmSourceLoadedLenLo/Hi` (the existing
   "how much is loaded so far" total) as both the append position and, on
   success, the new total — `CasmSourceVmmCursorLo/Hi` (the traversal read
   cursor) and `sourceRefill` are untouched by this WP.
4. **Test harness**: a new dedicated harness, `tests/src/casm_catalog/`
   (target `test_casm_catalog`), separate from WP44's grammar-only
   `test_casm_include`. `include.s` is a distinct module with distinct
   failure modes; the existing grammar harness and its regression surface
   stay untouched.

## Prerequisites and Baseline

- WP44 is complete and approved at CASM `0.1.46` build 1166. Current branch
  `feature/casm-phase9-wp43` (WP44 was implemented directly on this branch,
  not a separate child branch, a deviation from the branch-per-WP convention
  used through Phase 6B/7/8; WP45 continues on the same lineage unless the
  user asks for a new child branch at activation).
- Measured directly via `ld65 -m` against `build/build_casm_cfg/casm_3400.cfg`:
  CODE ends `$5A94`, RODATA ends `$643B`, BSS ends `$6C56`. Total MAIN use is
  `$3856` (14,422) of `$3A00` (14,848): **426 bytes free** at the current
  `$3400`/`$3A00` envelope.
- `.INCLUDE` already parses completely (WP44): `CasmIncludeFilename`/
  `CasmIncludeFilenameLen` (parser.s, 65 bytes exported BSS) hold the 1-63
  byte original-spelling payload with prefix retained. `casmRunPass` detects
  a parsed include and returns `CASM_DIAG_NOT_IMPLEMENTED` before any emitter
  effect.
- The next free diagnostic number is `$34` (`CASM_DIAG_PHASE9_WP44_LAST = $33`).
- `resources.s`'s VMM registry has 8 slots. Production use today: 1 (source
  store, `source.s`), 1 (symbol table, `symbols.s`), 1 more only in a
  relocatable Pass 2 build (relocation table, `reloc.s`) — 2 or 3 of 8 owned.
  WP45 adds one more (the metadata store), leaving at least 4 of 8 free,
  matching WP43's Phase 0C.19 freeze (item 11).
- `vmm_store.s` (`vmmStoreAlloc`/`vmmWindowRead`/`vmmWindowWrite`) and
  `resources.s` (`resourceRegisterVmm`) need no changes: the metadata store is
  an ordinary registry-owned allocation like the symbol table's and source
  store's own.
- `fileio.s`'s `inputStreamOpen`/`inputStreamRead`/`inputStreamClose` already
  take a caller-supplied X/Y filename pointer (generalized in WP34) and
  already register/release through the central file registry — WP45 reuses
  these directly for a transient child open, exactly as `sourceLoad` does for
  each top-level file today.
- `DOS_PARSE_PREFIX` (`$57`) already exists and is the correct primitive for
  device resolution: input `X` = zero-page offset holding the string pointer
  (not an X/Y pair); output `A` = resolved device (8-11) or `CurrentDevice` if
  absent, `C` = 1 if a prefix was present. CASM's private zero page
  (`$70-$8F`) is fully allocated; WP45 borrows an already-existing transient
  pointer cell for the one instant this call needs it (mirrors `cli.s`'s
  `CasmPtr0Lo/Hi` reuse pattern), never adding a new persistent zero-page
  byte.
- No CASM code parses device prefixes today. `cliDeriveOutputName`
  (`cli.s`) only *detects* a colon to reject it as an extension separator; it
  never resolves a device number. WP45 introduces the first real prefix
  *resolution* in this codebase.
- No case-fold helper exists. `symbols.s`'s comparison is deliberately
  case-**sensitive** (distinguishes shifted/unshifted PETSCII as different
  identifier bytes) and must not be reused or generalized for this purpose.

## Dependency Review and Reconciled Discrepancies

1. **Stale casm.s comment.** `crpDir`'s comment in `casm.s` claims WP45 itself
   replaces the temporary `.INCLUDE` boundary. The parent plan's own WP45/WP46
   split (physical catalog vs. frame stack/traversal) makes that impossible:
   a successful catalog+load with no frame stack still has nowhere to resume
   parsing from. Corrected in this WP to reference WP46 (Scope Decision 1).
2. **Device-inheritance gap.** Per Phase 0C.19 (frozen in WP43), an unprefixed
   child inherits its *parent's* resolved device, but `DOS_OPEN_FILE` only
   ever knows an explicit prefix or `CurrentDevice`. WP43's own dependency
   finding 9 anticipated using the OS's prefix parser but did not notice this
   consequence: CASM must be able to force a *non-default* device onto
   `DOS_OPEN_FILE`, which requires constructing an explicit prefixed string
   even when the child's own spelling had none (Scope Decision 2).
3. **Cursor-reuse hazard is immediate, not deferred.** WP43 finding 4 flagged
   that `CasmSourceVmmCursorLo/Hi`'s dual role (write cursor during load, read
   cursor during traversal) "cannot simultaneously" serve both roles once
   Pass 1 discovers includes dynamically. Tracing the actual moment an
   `.INCLUDE` is encountered confirms this is not a future WP46 concern: even
   a call made *outside* live traversal must append at the true end of
   content (`CasmSourceLoadedLenLo/Hi`), never at whatever value
   `CasmSourceVmmCursorLo/Hi` currently holds mid-traversal, or it would
   silently overwrite already-loaded top-level bytes between the current read
   position and the end of content. This makes the cursor split
   (Scope Decision 3) a WP45 requirement regardless of the standalone-only
   wiring decision, not something WP45 can defer to WP46.
4. **Physical record needs only one stored spelling, not two.** WP43's
   Frozen Observable Contract lists both "case-folded ... filename" identity
   and "the original spelling remains available for diagnostics" as separate
   requirements, which could be read as needing two stored strings. Storing
   only the original (post-prefix-removal) spelling and case-folding both
   operands *live*, byte-by-byte, during every catalog comparison satisfies
   both requirements with one 64-byte buffer per record, matching WP43's
   128-byte record budget with room to spare (8 control bytes + 64 name bytes
   + 56 reserved = 128) instead of requiring a wider record.
5. **No hash index needed.** `symbols.s` uses a 128-bucket hash for up to 512
   symbols; the physical catalog caps at 32 records. A linear scan with cheap
   early-outs (flag, then device, then name length, before ever comparing
   bytes) is simpler and sufficient at this N — WP45 does not add a hash
   table.
6. **Top-level files are not cataloged by WP45.** The parent plan assigns
   "replace CLI-only filename lookup with catalog lookup" to WP48
   (diagnostics), not WP45. WP45's catalog is therefore populated **only** by
   its own test harness's direct calls — no production top-level file gets a
   physical-catalog entry yet. This is consistent with the standalone-only
   decision and must not be treated as a gap: WP46/47/48 decide how and when
   top-level roots join the same catalog.
7. **Shared VMM staging buffer aliasing hazard.** `vmmWindowRead`/
   `vmmWindowWrite` always transfer through the one shared `CasmVmmBuffer`
   (64 bytes). A catalog lookup's search key (the candidate's folded name/
   device) must be captured into `include.s`'s own BSS *before* any
   `vmmWindowRead` call that reads a different candidate record overwrites
   `CasmVmmBuffer` out from under it. This is the same aliasing bug class
   that hit `vmm_store.s` three times (WP23-25) and hit WP44's own test
   harness (`CasmPtr0/1` clobbered by the real directive classifier) — WP45's
   implementation must not repeat it.

## `include.s` Design

### Storage

New BSS, private to `include.s` unless otherwise noted:

- `CasmIncludeMetaSlot` (1 byte, exported): the VMM registry slot granted to
  the 8KB metadata allocation.
- `CasmIncludeCatalogCount` (1 byte, exported): 0-32, count of populated
  physical records.
- `CasmIncludeKeyDevice` (1 byte): the device being looked up, captured
  before any `CasmVmmBuffer`-aliasing call.
- `CasmIncludeKeyName` (64 bytes) / `CasmIncludeKeyLen` (1 byte): the
  case-folded search key, captured the same way.
- `CasmIncludeOpenName` (68 bytes): transient synthesis buffer for the
  `<device>:<filename>` string handed to `fileOpenInput`/`DOS_OPEN_FILE`
  when the resolved device does not match what `DOS_OPEN_FILE` would default
  to (Scope Decision 2). Never persisted into a catalog record.

### Metadata VMM Store

- One 8KB (`CASM_INCLUDE_META_BYTES = 8192`) allocation via `vmmStoreAlloc`,
  granted once by `includeCatalogInit`.
- Bytes `0-4095`: 32 physical records, 128 bytes each
  (`CASM_INCLUDE_PHYS_REC_SIZE = 128`, `CASM_INCLUDE_PHYS_CAPACITY = 32`).
- Bytes `4096-8191`: reserved, untouched by WP45. WP47 freezes the
  include-event log's exact layout inside this same reserved span (matching
  WP43's 2048-events/2048-reserved proposal) rather than requiring a second
  allocation.

### Physical Record Layout (frozen by this WP)

| Offset | Size | Field | Notes |
| --- | --- | --- | --- |
| 0 | 1 | Flags | `CASM_RESOURCE_FREE`/`CASM_RESOURCE_OWNED`, matching `resources.s`'s existing convention |
| 1 | 1 | Device | 8-11 |
| 2 | 1 | NameLen | 1-63 |
| 3 | 1 | Reserved | 0 |
| 4-5 | 2 | SourceStartLo/Hi | offset into the combined source store |
| 6-7 | 2 | SourceLengthLo/Hi | this file's byte span |
| 8-71 | 64 | Name | original spelling (prefix already removed), null-terminated |
| 72-127 | 56 | Reserved | zero-filled |

Transferred as two fixed 64-byte `vmmWindowRead`/`vmmWindowWrite` windows per
record (offsets `+0` and `+64`), matching WP43's proposal and the existing
`CASM_VMM_BUFFER_SIZE` transfer contract. Compile-time asserts pin every
offset and the 128-byte total, mirroring `CASM_SYMBOL_REC_SIZE`'s precedent
in `symbols.s`.

### Public ABI

`includeCatalogInit`
- Allocates the 8KB metadata store, zeroes `CasmIncludeCatalogCount`. Called
  once, analogous to `symbolsInit`/`sourceInit`.
- Outputs: `C` clear, `A = CASM_DIAG_NONE`; `C` set with
  `CASM_DIAG_INCLUDE_METADATA_ALLOC_FAILED` if `vmmStoreAlloc` rejects the
  request.

`includeResolveDevice` (private helper)
- Inputs: parent's resolved device (1 byte); X/Y = pointer to the child's
  original spelling (may or may not carry a `<n>:` prefix).
- Resolves the device via `DOS_PARSE_PREFIX` (borrowing a transient
  zero-page pointer cell); if no prefix was found (`C` clear from the OS
  call), the *parent's* device is substituted for the OS's own
  `CurrentDevice`-based default, not the OS-returned value.
- Outputs: resolved device (1 byte); pointer/length of the filename bytes
  after any prefix.

`includeFoldCompare` (private helper)
- Case-folds unshifted/shifted PETSCII letters to one canonical byte value
  for comparison only; never mutates stored bytes. Compares two spans
  (device + folded name + length) for catalog identity.

`includeCatalogFind`
- Inputs: device, pointer/length of a filename (post-prefix-removal).
- Captures the folded search key into `CasmIncludeKeyDevice`/
  `CasmIncludeKeyName`/`CasmIncludeKeyLen` first (Reconciled Discrepancy 7),
  then linearly scans populated records (cheap-early-out order: flag, device,
  name length, then folded bytes).
- Outputs: `C` clear with the matching record index on a hit; `C` set
  (not-found, not a failure) when no record matches.

`includeCatalogLoad`
- Inputs: parent's resolved device; X/Y = pointer to the child's original
  spelling (as captured by `CasmIncludeFilename`, WP44).
- Resolves the device and post-prefix name (`includeResolveDevice`), then
  `includeCatalogFind`s it.
- On a cache hit: returns the existing record index; performs no file I/O,
  no source append, and no catalog write (deduplication — Phase 0C.19 item
  6, "repeated expansion... shares one immutable physical byte copy").
- On a miss: rejects if the catalog is full
  (`CASM_DIAG_INCLUDE_CATALOG_FULL`); otherwise synthesizes an explicit
  prefixed open string only if needed (Scope Decision 2), opens the child
  transiently through the existing `fileOpenInput`/`inputStreamRead`/
  `inputStreamClose` family, streams it into the source store via the new
  `sourceAppendFile` (below), writes a new physical record (both transfer
  windows) with the original spelling, resolved device, and the append's
  reported start/length, increments `CasmIncludeCatalogCount`, and returns
  the new record index.
- A failure at any step (open/read/close/append/catalog-full/transfer)
  leaves whatever was already registered (transient file handle, any VMM
  work already committed) for the central resource owner's generic cleanup
  sweep, matching every other CASM init-path failure (`sourceLoad`'s own
  documented precedent).
- Outputs: `C` clear with the record index; `C` set with a propagated or
  catalog-specific `CASM_DIAG_*`.

### `source.s` Addition: `sourceAppendFile`

- Refactor: extract `sourceLoad`'s existing per-file body (open, `slCheckCap`,
  chunked `vmmWindowWrite` via `CasmVmmBuffer`, close, synthetic-newline
  decision) into a private routine parameterized by a 16-bit starting append
  offset, shared by `sourceLoad`'s existing static loop (unchanged behavior,
  still using `CasmSourceVmmCursorLo/Hi` as its own running offset exactly as
  today) and the new export below.
- `sourceAppendFile` (new export): inputs X/Y = filename pointer (already
  resolved/prefixed by the caller if needed — `source.s` performs no device
  resolution of its own). Appends at `CasmSourceLoadedLenLo/Hi` (the existing
  "total loaded" field, serving here as the next append offset too), checked
  against `CASM_SOURCE_VMM_MAX_BYTES` the same way `slCheckCap` already does.
  On success, advances `CasmSourceLoadedLenLo/Hi` by the appended count and
  returns the file's start offset (the pre-call value) and length (the
  appended count) so `include.s` can populate its physical record.
  `CasmSourceVmmCursorLo/Hi` (the traversal read cursor) and `sourceRefill`
  are not read or written by this routine.
- No synthetic inter-file newline is inserted by `sourceAppendFile` — that
  behavior is specific to `sourceLoad`'s flat multi-top-level-file
  concatenation and does not apply to an included file's own span (frame
  boundaries, not synthetic bytes, will separate included content once WP46
  adds traversal).

## Constants and Diagnostics

- `common.inc` additions: `CASM_INCLUDE_META_BYTES = 8192`,
  `CASM_INCLUDE_PHYS_REC_SIZE = 128`, `CASM_INCLUDE_PHYS_CAPACITY = 32`, field
  offset constants, and compile-time layout/total-size asserts.
- New diagnostic: `$34` `CASM_DIAG_INCLUDE_CATALOG_FULL` (the 32-slot physical
  catalog is full), `CASM_DIAG_PHASE9_WP45_LAST = $34`.
- Reused, not duplicated: `CASM_DIAG_INPUT_OPEN_FAILED`/
  `CASM_DIAG_INPUT_READ_FAILED`/`CASM_DIAG_INPUT_CLOSE_FAILED` (Phase 2, for
  transient child I/O — identical semantics to `sourceLoad`'s own reuse for
  top-level files) and `CASM_DIAG_SOURCE_OFFSET_OVERFLOW` (combined-cap
  overflow during append, per WP43's own instruction to reuse where semantics
  match exactly). Tracing every metadata-store call site found two more
  diagnostics originally planned ($35 alloc-failed, $36 transfer-failed) were
  unreachable: `vmmStoreAlloc`/`vmmWindowRead`/`vmmWindowWrite` already
  propagate their own `CASM_DIAG_VMM_ALLOC_FAILED`/`CASM_DIAG_VMM_UNAVAILABLE`/
  `CASM_DIAG_VMM_TRANSFER_FAILED` for every failure mode those two would have
  covered — the same "reserved but unreachable" situation WP23 found for
  `CASM_DIAG_VMM_ALLOC_TOO_LARGE`. Dropped before implementation rather than
  kept as dead diagnostics.
- Diagnostic *location* for any WP45 failure is set by the caller (the test
  harness in this WP; a real `.INCLUDE` site in WP46) via the existing
  `diagSetLocFromStmt`-style mechanism — `include.s` itself raises no
  location, matching `symbols.s`/`vmm_store.s`'s own precedent of being
  location-agnostic library modules.

## Storage Effects

- Base-RAM (registry) growth: one more VMM registry slot consumed at runtime
  (within the existing 8-slot cap; no `resources.s` change).
- BSS growth: `include.s`'s own new state (slot, count, key buffers, open-name
  synthesis buffer) plus `source.s`'s `sourceAppendFile` addition (no new
  persistent field beyond what already exists — it reads/writes
  `CasmSourceLoadedLenLo/Hi` in place).
- No zero-page growth: the `DOS_PARSE_PREFIX` call reuses an existing
  transient pointer cell for the one instant it is needed.
- No change to `CasmIncludeFilename`/`CasmIncludeFilenameLen` (WP44, frozen),
  `CasmTokenRecord`, `CasmParserStmt`, or any Phase 3 state.s span.
- MAIN code/RODATA growth must fit the current 426-byte headroom at `$3A00`
  or trigger the stop condition below — this WP does not pre-approve a MAIN
  amendment the way WP44's did; a real measured overflow is presented to the
  user before any envelope change.

## Scope

Included:

- `src/external/casm/include.s`: metadata store init, device/name
  canonicalization, catalog find/load, transient child load/append.
- `source.s`: `sourceAppendFile` and the shared private streaming-body
  refactor.
- `common.inc`: constants, record layout, diagnostics `$34-$36`.
- Dedicated `tests/src/casm_catalog/` harness and `casm_overflow_test_d64`
  packaging.
- Correcting `casm.s`'s stale WP45 comment (Scope Decision 1).
- Task, plan, walkthrough, knowledge, changelog, and DOX synchronization.

Excluded:

- Any `casmRunPass`/`casm.s` production call site for `.INCLUDE` (WP46).
- Frame stack, push/pop, nested traversal, statement-boundary semantics,
  cycle detection, depth enforcement, or file-aware echo identity (WP46).
- Include-event recording, Pass 2 replay, or correspondence checks (WP47).
- Included-source diagnostic rendering, traceback, or CLI-catalog unification
  for top-level files (WP48).
- Cataloging any top-level (`CasmSourceNames`) file.
- Any change to `sourceRefill`, `sourceRewind`, or the traversal read cursor.

## Expected Files

| File | Planned action |
| --- | --- |
| `src/external/casm/include.s` | new module: catalog store, canonicalization, find/load |
| `src/external/casm/source.s` | `sourceAppendFile`; factor out shared per-file streaming body |
| `src/external/casm/common.inc` | metadata/record constants, diagnostics `$34-$36` |
| `src/external/casm/casm.s` | correct the stale WP45 comment to reference WP46 |
| `tests/src/casm_catalog/casm_catalog.s` | new dedicated harness |
| `CMakeLists.txt` | `include.s` in the CASM object set; `test_casm_catalog` target and `casm_overflow_test_d64` packaging |
| `wiki/tasks/casm.md`, `brain/task.md` | synchronized task state |
| `brain/KNOWLEDGE.md`, `CHANGELOG.md` | durable verified result at closeout |
| `brain/walkthroughs/2026-07-25-casm-phase9-wp45-physical-file-catalog-and-dynamic-source-loading.md` | evidence and manual steps |
| `src/external/casm/AGENTS.md` | only if implementation changes a durable local contract |

## Harness Design and Test Matrix

`test_casm_catalog` links `include.s`, `source.s`, `state.s`, `fileio.s`,
`resources.s`, `vmm_store.s`, `common.inc` (mirroring `test_casm_vmm`'s
whole-object precedent) and drives the public ABI directly against real
fixture files — it does not implement any WP46+ behavior and does not call
`casmRunPass`.

Required cases:

- catalog init succeeds and reports zero populated records;
- a new file loads on first request: catalog miss, transient open/read/close
  succeeds, source bytes appended, new record correctly populated (device,
  name, start, length), catalog count incremented;
- a repeated request for the identical (device, name) is a cache hit: no
  second open, no second append, source store length unchanged, same record
  index returned;
- same folded name on two different explicit devices catalogs as two
  distinct records;
- case-varied spellings of the same name on the same device fold to the same
  record (a hit, not a duplicate);
- an unprefixed lookup correctly inherits a supplied "parent device" rather
  than `CurrentDevice` when they differ;
- an explicit child prefix overrides the supplied parent device;
- 32nd distinct file succeeds; 33rd fails with
  `CASM_DIAG_INCLUDE_CATALOG_FULL`;
- open/read failure on a missing or unreadable file propagates the existing
  Phase 2 diagnostics unchanged;
- two sequential appends leave the source store's combined length exactly
  additive (no synthetic newline inserted between them, unlike `sourceLoad`);
- an append that would exceed `CASM_SOURCE_VMM_MAX_BYTES` fails with
  `CASM_DIAG_SOURCE_OFFSET_OVERFLOW` and leaves the prior content's length
  unchanged;
- `sourceAppendFile` called after `sourceLoad`'s own top-level content is
  present appends strictly after it, never disturbing the existing bytes or
  the (still zero, unread) traversal cursor;
- metadata allocation failure path (forced, e.g. by exhausting the VMM
  registry first) reports `CASM_DIAG_INCLUDE_METADATA_ALLOC_FAILED`;
- existing lexer/parser/source/VMM/symbol harnesses remain unchanged and
  pass.

## Atomic Increments

1. After explicit approval, mark WP45 active in Taskwarrior,
   `wiki/tasks/casm.md`, and `brain/task.md`.
2. Add `common.inc` constants, the frozen physical-record layout, and
   diagnostics `$34-$36` with compile-time assertions.
3. Refactor `sourceLoad`'s shared per-file body and add `sourceAppendFile`;
   verify `sourceLoad`'s own existing behavior is provably unchanged
   (identical object code for the unaffected static path where feasible, or
   an explicit behavioral argument if not).
4. Implement `include.s`: metadata store, device resolution, case-fold
   compare, catalog find, catalog load (transient open/read/append/record
   write).
5. Correct `casm.s`'s stale WP45 comment to reference WP46.
6. Add and build `test_casm_catalog`; package it on `casm_overflow_test_d64`.
7. Run static, narrow, regression, image, artifact, and no-change-build
   checks; create the walkthrough and present runtime instructions to the
   user.
8. After user runtime verification and explicit completion approval only,
   increment CASM's version-only stage, rebuild, synchronize closeout
   records, and complete WP45. Do not activate WP46 automatically.

## Failure and Cleanup

- Every transient child open registers through the existing central file
  registry; a failure at any step is released by `resourcesCleanup`'s
  existing generic sweep, with no new manual unwind path.
- `includeCatalogLoad` performs no partial catalog write: a new record is
  written only after the append and both catalog-slot windows succeed; a
  mid-sequence failure leaves `CasmIncludeCatalogCount` unadvanced and the
  target slot's flag byte still `CASM_RESOURCE_FREE`.
- `sourceAppendFile` advances `CasmSourceLoadedLenLo/Hi` only after every
  chunk of the new file has been written successfully; a failed append never
  partially advances the total.

## Verification

- `git diff --check` and all relevant ca65 compile-time assertions pass.
- `test_casm_catalog` passes its complete matrix in the supported local
  emulator, as performed by the user (never the broken `c64-testing` MCP or a
  web emulator).
- Existing standalone lexer, parser, expression, symbol, VMM, relocation,
  include-grammar, and CASM regression targets build and pass unchanged.
- Two consecutive `cmake --build build --target casm` builds hold the same
  `BUILD_CASM` value after the first content-driven increment.
- `image_d64`, `test_image_d64`, and `casm_overflow_test_d64` build clean.
- Measure MAIN via `ld65 -m` against the current `$3A00` envelope; compare
  against this plan's 426-byte baseline.
- Confirm zero production call sites reference `include.s`'s public ABI
  (only the new harness does) and that `casmRunPass`'s `.INCLUDE` statement
  behavior is byte-for-byte unchanged from WP44.

## Documentation, Task, and DOX Updates

- Keep Taskwarrior, `wiki/tasks/casm.md`, and `brain/task.md` synchronized at
  activation, verification, and closeout.
- Record stable implementation findings in `brain/KNOWLEDGE.md`, user-visible
  change in `CHANGELOG.md`, and evidence/manual confirmation in the
  walkthrough.
- Re-read the root, `src`, `src/external`, `src/external/casm`, `tests`,
  `wiki`, and `wiki/tasks` DOX chain before implementation and perform a
  closeout DOX pass.
- Update `src/external/casm/AGENTS.md` only if implementation establishes or
  changes a durable local contract (e.g., the physical record layout, once
  frozen by real code rather than this plan alone).

## Stop Conditions

Stop, amend this plan, and request renewed approval if:

- the append-cursor split cannot be achieved without touching
  `sourceRefill`, `sourceRewind`, or any other traversal-time routine;
- the 128-byte physical record cannot hold flags, device, name length,
  start/length, and a 63-byte-plus-null name within two 64-byte transfer
  windows;
- device resolution cannot be made to force a non-`CurrentDevice` device onto
  `DOS_OPEN_FILE` without a persistent (not transient) zero-page or BSS
  change beyond what this plan approves;
- case-folding requires touching `symbols.s`'s case-sensitive comparison or
  hash;
- code/RODATA no longer fits the current `$3A00` MAIN envelope;
- `test_casm_catalog` cannot exercise the real `include.s`/`source.s` ABI
  without duplicating production logic;
- any existing parser, emitter, two-pass, relocation, or WP44 grammar
  behavior regresses;
- a production call site for `include.s` turns out to be unavoidable to
  prove this WP's own behavior (it should not be — the harness calls the
  public ABI directly).

## Completion Gate

WP45 is complete only after this plan is explicitly approved, implementation
and the full verification matrix pass, the user performs the runtime
walkthrough, the user explicitly approves completion, CASM advances its
version-only stage with a stable no-change build, and all durable records
agree. Completion does not activate WP46.

## Progress

- 2026-07-25: Drafted. User confirmed all four scope forks (standalone
  wiring, explicit-prefix device synthesis, append-cursor split via a shared
  refactored helper, and a new dedicated `test_casm_catalog` harness) before
  this plan was written. Awaiting approval to activate.
- 2026-07-26: User approved the plan. Activated WP45 in Taskwarrior,
  `wiki/tasks/casm.md`, and `brain/task.md`.
- 2026-07-26: Increment 2 added `common.inc` constants, the frozen 128-byte
  physical record layout, and diagnostic `$34`. Tracing every metadata-store
  call site found two originally-planned diagnostics ($35 alloc-failed, $36
  transfer-failed) unreachable -- `vmmStoreAlloc`/`vmmWindowRead`/
  `vmmWindowWrite` already propagate correct diagnostics for every failure
  those would have covered, the same class of finding as WP23's dropped
  `CASM_DIAG_VMM_ALLOC_TOO_LARGE`. Dropped before implementation.
- 2026-07-26: Increment 3 refactored `sourceLoad`'s per-file body (retargeted
  `slCheckCap`/`slVmmWrite` to a new shared `CasmSourceStreamCursorLo/Hi`,
  with thin copy-in/copy-out glue at the loop boundaries) and added
  `sourceAppendFile`. Confirmed by construction that `CasmSourceVmmCursorLo/Hi`
  (the live traversal read cursor) is never read or written by the new path.
- 2026-07-26: Increment 4 implemented `include.s` (`includeCatalogInit`,
  `includeResolveDevice`, `includeFoldByte`, `includeCaptureKey`,
  `includeCatalogRead`/`Write`, `includeCatalogFind`,
  `includeSynthesizeOpenName`, `includeCatalogLoad`). Discovered during
  implementation that `DOS_PARSE_PREFIX` (`parsePointerDevice`,
  `src/command64/utils.asm`) advances its caller's zero-page pointer past a
  recognized prefix in place, eliminating the need for (and risk of) an
  independent colon scan. Found and fixed two defects before any build: an
  invalid `(zp),X` addressing mode in the open-name synthesis loop (fixed by
  swapping to Y for the indirect source read, X for the direct-indexed
  destination write), and a genuine miss/failure ambiguity in
  `includeCatalogFind`'s return value (fixed by having the miss path
  explicitly set `A = CASM_DIAG_NONE`). Also caught and fixed a latent
  bounds-check gap in the record-name copy (relied on a second null-scan
  instead of the already-known, bounded `CasmIncludeKeyLen`).
- 2026-07-26: Building surfaced one invalid addressing mode, several 6502
  branch-range errors in `include.s` (fixed with local jump trampolines,
  matching this project's established precedent) and in the new test
  harness (fixed by giving every test case its own local fail tail instead
  of one shared distant label, matching `casm_pass1.s`'s own convention).
  Production `casm` then measured a 694-byte overflow at the existing
  `$3A00` envelope; the user approved growing it to `$3E00` (+1024 bytes).
  Final `casm` build 1169 passes and holds stable on a no-change rebuild;
  measured MAIN use is 15,541 of 15,872 bytes (331 bytes headroom).
  `test_casm_pass1`/`test_casm_passcheck` (both link `source.s` whole)
  continue to fit their existing `$3A00` envelope unchanged.
- 2026-07-26: Increment 5 corrected `casm.s`'s stale WP44-era comment to
  name WP46 instead of WP45.
- 2026-07-26: Increment 6 added the 12-case `tests/src/casm_catalog/`
  harness (new fixtures `casmcat1`-`casmcat5.seq` via
  `cmake/GenerateCasmTestFixtures.cmake`) and wired it into `CMakeLists.txt`
  and `casm_overflow_test_d64` packaging (bare lowercase disk names,
  matching the established cc1541/ca65 case-pairing convention). Adjusted
  the test matrix during implementation: the "same name on two different
  devices" case is exercised through `includeResolveDevice` in isolation
  rather than two real `includeCatalogLoad` opens, since the test
  environment mounts only one physical/emulated device.
- 2026-07-26: Increment 7 verification: `test_casm_catalog` build 1002
  passes and holds stable on a no-change rebuild; all other standalone CASM
  harnesses rebuild successfully (each bumped once from `common.inc`'s
  shared content-hash change, no behavior change expected or observed);
  `image_d64`, `test_image_d64`, and `casm_overflow_test_d64` all build
  clean; `git diff --check` passes. Walkthrough drafted:
  `brain/walkthroughs/2026-07-25-casm-phase9-wp45-physical-file-catalog-and-dynamic-source-loading.md`.
  Awaiting the user's runtime confirmation of `test_casm_catalog` and
  explicit completion approval before the version-only increment.
- 2026-07-26 (runtime round 1): user's first run reported `.fffff....ff`
  with `D1=$0B` (`CASM_DIAG_INPUT_OPEN_FAILED`) via added debug
  instrumentation. Found the harness hardcoded device 8 for every real-load
  case, but the user's actual setup boots `test.d64` on device 8 and runs
  `casm_overflow_test.d64` (carrying the `casmcat*` fixtures) from device 9.
  Traced `cmdLoad` (`shell.asm`) and confirmed `CurrentDevice` is only
  transiently overridden by an embedded `LOAD "x",n` prefix and always
  restored afterward, with no separate "device loaded from" tracked
  anywhere -- but a debug probe proved `CurrentDevice` was already correctly
  9 when the harness ran (a bare `sourceAppendFile` call succeeded), so
  capturing it once at startup into a new `TestDevice` field and using that
  everywhere instead of a hardcoded device was correct and sufficient.
  Corrected `catresolve1`'s own fake-parent-device pick to always differ
  from `TestDevice`, since a coincidental match would have made the
  inheritance test unable to distinguish itself from a CurrentDevice
  fallback.
- 2026-07-26 (runtime round 2): after the device fix, the user's second run
  reported `.ff.f.......`. Expanded debug instrumentation to dump
  `catload1`'s actual record fields, revealing `START=$0012 LENGTH=$0000`
  instead of the expected `START=$08 LENGTH=$0A`. Found a genuine production
  bug in `sourceAppendFile`: it stashed the file's start offset in
  `CasmValue0Lo/Hi`, which `vwPrepareTransfer` (`vmm_store.s`, reached via
  `slVmmWrite` on every chunk write) already documents as its own
  offset+count scratch and clobbers on the very first chunk -- the observed
  `$12` (18) was exactly `vwPrepareTransfer`'s own `8+10` computation
  bleeding through. Fixed by moving the stashed value to a new, never-shared
  field, `CasmSourceAppendStartLo/Hi`, writing `CasmValue0Lo/Hi` only once,
  at the very end, after every clobbering call has already run.
- 2026-07-26 (runtime round 3): after both fixes, the user reran
  `test_casm_catalo` and confirmed all 12 cases pass
  (`CASM CATALOG: PASS`). Removed all debug instrumentation from the
  harness. Re-verified the full static matrix after both fixes: `casm`
  build 1170 (no-change stable), MAIN 15,563/15,872 bytes (309 bytes
  headroom); `test_casm_catalog` build 1009 (no-change stable);
  `test_casm_pass1`/`test_casm_passcheck` still fit `$3A00` unchanged; all
  other standalone harnesses and all three disk images build clean;
  `git diff --check` passes. Walkthrough updated with the confirmed runtime
  evidence. Awaiting the user's explicit completion approval before the
  version-only increment.
- 2026-07-26 (completion): user approved completion. CASM advanced once to
  `0.1.47` build 1171, matching the pre-bump artifact byte-for-byte apart
  from the version-stage digits (a text-only substitution of equal length,
  so the PRG size/R6 footer are unchanged from the pre-increment
  measurement). A no-change rebuild held 1171. All three disk images
  rebuilt and passed. Taskwarrior, `wiki/tasks/casm.md`, and `brain/task.md`
  closed WP45. **WP45 is complete.** WP46 is unblocked in Taskwarrior but
  not activated; it remains separately gated on its own dedicated plan.
