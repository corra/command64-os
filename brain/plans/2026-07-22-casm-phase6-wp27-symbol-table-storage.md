---
feature: casm-phase6-wp27-symbol-table-storage
created: 2026-07-22
status: planned
---

# Plan: CASM Phase 6B WP27 - Symbol Table Storage and Hash Index

## Objective

WP27 implements `symbols.s`: VMM-backed symbol records over Phase 6A storage,
plus a bounded RAM hash-bucket index, providing `symbolsInit`, `symbolsInsert`,
and `symbolsLookup`. It is built and fixture-tested in complete isolation --
no `casm.s`, `parser.s`, or `opcodes.s` call site exists after WP27 --
mirroring exactly how `vmm_store.s` was built and fixture-tested in WP23-25
before any production call site existed. WP28 (Pass 1) is what wires this
module into real assembly.

Taskwarrior: `0dd437f3-3248-4294-aee7-39bb8571f1c8`.

Prerequisite: WP26 is complete and approved (CASM `0.1.28` build 1103).
Approval of this plan is required before activation or source edits, per the
CASM `AGENTS.md` gate.

**This plan amends one figure WP26 froze.** WP26's Phase 0C.5 contract set
the symbol record at 37 bytes. Reconciling it against Phase 6A's existing
32-byte VMM transfer buffer (`CasmVmmBuffer`/`CASM_VMM_BUFFER_SIZE`) found
that 37 bytes cannot pass through a single windowed transfer at all --
`vwPrepareTransfer` rejects any request over 32 bytes outright. Fixing that
buffer size reopened whether to also choose a record size that makes
record-index-to-VMM-offset arithmetic cheap, since that arithmetic runs on
every symbol lookup and insert. The user chose to pad the record to 64 bytes
and grow the buffer to match (see Dependency Review item 1). This is a
tracked, explicit amendment to the Phase 0C.5 contract, not a silent
deviation -- `brain/KNOWLEDGE.md`'s Phase 0C.5 section is updated by this
plan's own Atomic Increments to record it.

## Baseline

- CASM `0.1.28` build 1103. MAIN unchanged since WP26 (a documentation-only
  work package).
- `CASM_VMM_BUFFER_SIZE = 32` (`common.inc`); `CasmVmmBuffer: .res
  CASM_VMM_BUFFER_SIZE` (`vmm_store.s`); `vwPrepareTransfer` rejects any
  transfer request over 32 bytes before ever calling the OS.
- Zero page `$70-$8F` fully allocated. `CasmPassScratch0-3` ($88-$8B) remain
  unused; the parent Phase 6 plan predicted `symbols.s` would need them for
  "hash-bucket/collision-chain cursors," but this plan's design (Dependency
  Review item 5) shows they are not actually needed there -- everything
  `symbols.s` must persist across a call is a value, not a pointer, so it
  lives in ordinary BSS instead, leaving the zero-page group free for
  WP28's own Pass 1/Pass 2 state.
- No `symbols.s` exists. No `CASM_SYMBOL_*` constant exists in `common.inc`.
  `CASM_DIAG_PHASE6A_LAST = $2B` is the last assigned diagnostic.

## Dependency Review and Discrepancies Reconciled

1. **The frozen 37-byte symbol record cannot pass through the existing
   32-byte VMM transfer buffer -- confirmed by direct inspection, not
   theoretical.** `vwPrepareTransfer` (`vmm_store.s:229-238`) rejects any
   request where `CasmIoLenLo > CASM_VMM_BUFFER_SIZE` (32) before any OS
   call. A 37-byte record would need two transfers per access (splitting at
   some byte boundary), doubling the OS-call cost of every insert and every
   step of every hash-chain walk. `common.inc`'s own comment on
   `CASM_VMM_BUFFER_SIZE` already anticipated this exact situation: "not
   sized against any real Phase 6B record (not yet designed)." **Resolved
   per the user's confirmed decision: grow both the buffer and the record to
   64 bytes.** VMM footprint becomes `512 * 64 = 32768` bytes (still one
   `vmmStoreAlloc` call, comfortably under the existing 65536-byte
   single-allocation cap; `32768 / 16 = 2048` whole paragraphs, no rounding
   surprise). The record's meaningful fields keep their exact WP26-frozen
   offsets (`NameLen@0`, `Name@1..31`, `Value@32-33`, `Flags@34`,
   `Next@35-36`); bytes 37-63 (27 bytes) are reserved padding, explicitly
   zero-filled on every write (item 4 below), not left undefined.
2. **Growing `CASM_VMM_BUFFER_SIZE` is a superset-compatible change to an
   already-shipped Phase 6A constant.** Every existing `test_casm_vmm`
   fixture transfers 32 bytes or fewer; none depends on the buffer being
   *exactly* 32. Confirmed no fixture or production code compares
   `CASM_VMM_BUFFER_SIZE` against a literal `32` anywhere outside its own
   declaration and assert. **Resolved: re-run `test_casm_vmm` unchanged
   after the constant edit as a regression check (Atomic Increment 2) before
   writing any new `symbols.s` code** -- if it doesn't pass unchanged, stop
   and investigate before proceeding, since that would mean the buffer-size
   assumption was wrong somewhere this review missed.
3. **Offset arithmetic is now a single shift, not a multiply.** With a
   64-byte (power-of-two) record, `offset = recordIndex << 6` -- six
   `ASL`/`ROL` pairs on the 16-bit index, unrolled (no loop overhead, fixed
   12-instruction cost), replacing what would otherwise be a 3-term
   shift-add multiply by 37 (`(idx<<5) + (idx<<2) + idx`) executed on every
   hash-chain comparison step. This was the whole point of the padding
   decision (item 1).
4. **Unused padding bytes are explicitly zero-filled on every insert, not
   left undefined.** The frozen record layout language ("unused tail
   undefined") was written before this plan's 64-byte amendment. Zero-filling
   costs nothing extra -- the padding is already inside the same single
   `vmmWindowWrite` call that writes the rest of the record -- and removes
   any future dependency on chain-walk comparisons being correctly
   `NameLen`-bounded rather than accidentally comparing into stale/undefined
   bytes. **Resolved: `symbolsInsert` zero-fills all 64 bytes of
   `CasmVmmBuffer` before populating `NameLen`/`Name`/`Value`/`Flags`/`Next`,
   every time.**
5. **`symbols.s` needs no zero-page budget beyond the existing general-purpose
   pointer group.** The parent Phase 6 plan's dependency review predicted
   `CasmPassScratch0-3` would hold "hash-bucket/collision-chain cursors."
   Designing the actual algorithm (Contract, item 3 below) found that the
   only *pointer* `symbols.s` needs is the caller-supplied name pointer,
   which fits the existing general-purpose `CasmPtr0Lo/CasmPtr0Hi` (already
   used this way by `parser.s` and others). The chain-walk cursor, name
   length, and value being inserted are plain values, not pointers needing
   indirect addressing, so they live in new private ordinary BSS cells in
   `symbols.s` itself. **Resolved: no zero-page change in this plan; the
   `CasmPassScratch0-3` group stays free for WP28.**
6. **`symbols.s` must not repeat the shared-scratch clobber bug WP23/24
   already hit three times.** `vwPrepareTransfer` documents
   `CasmValue0Lo`/`CasmValue0Hi` as its own clobbered offset+count scratch;
   WP25's walkthrough records `vmmStoreFree`, `resourcesCleanup`'s VMM loop,
   and `vmmReplay` each independently discovering this the hard way before
   being fixed. **Resolved: `symbols.s` never stashes state that must
   survive a `vmmWindowRead`/`vmmWindowWrite` call in `CasmValue0Lo/Hi` (or
   `CasmVmmOffLo/Hi`/`CasmIoLenLo/Hi`, which are legitimate *per-call
   inputs* `symbols.s` sets fresh before each transfer, not state that
   survives across one) -- everything that must survive lives in
   `symbols.s`'s own private BSS cells (item 5).**
7. **`symbolsLookup`'s calling convention must match the Phase 5 resolver
   callback ABI exactly, so WP28 can bind it directly with no adapter.**
   Re-reading `expr.s`'s resolver contract: `exprEvaluate` passes `X/Y`
   pointing to its *own* `CasmExprResolverOutput` buffer and expects the
   callback to write the five `CASM_RESOLVE_*` bytes there, returning `C`
   clear to accept. **Resolved: `symbolsLookup` takes `X/Y` as a
   caller-supplied output-view pointer (not an internally-owned buffer),
   exactly matching this convention** -- WP28 binds `symbolsLookup`'s
   address directly as the resolver in place of `parserRejectIdentifier`,
   with zero glue code, the same way WP20's test harness bound its synthetic
   resolver.
8. **A `vmmWindowRead` failure during a chain walk is an internal error, not
   "symbol not found."** Once `symbolsInit`'s `vmmStoreAlloc` succeeds and the
   slot stays registered for the process lifetime, every subsequent
   `vmmWindowRead`/`Write` request stays within the allocated range by
   construction (offsets are always `recordIndex << 6` for `recordIndex`
   in `0..CasmSymbolCount`, which never reaches `CASM_SYMBOL_MAX`'s VMM
   bound). **Resolved: a `C`-set return from `vmmWindowRead`/`Write` inside
   `symbols.s` propagates as `C` set with the existing
   `CASM_DIAG_VMM_TRANSFER_FAILED` (Phase 6A) -- no new diagnostic needed,
   since that failure genuinely is what occurred.**
9. **Symbol-table exhaustion is practically fixture-testable here, unlike
   Phase 6A's REU-exhaustion case.** WP25 had to manually defer
   `vmmalloc4` because CASM's registry cap could never be reached through
   normal calls. `CASM_SYMBOL_MAX = 512` has no such problem: a fixture can
   simply insert 512 distinct real symbols through the real API and observe
   the 513th rejected. **Resolved: `symfull1` (Verification, below) is a
   real automated fixture, not a manual deferral** -- flagged here only
   because it is a pleasant contrast to WP25's experience, not because it
   needed reconciling.
10. **Diagnostic reservation follows the Phase 5/WP17 precedent exactly.**
    WP17 "declares stable values only" for all of Phase 5's diagnostics
    ($24-$27) in one early work package, even though later packages raise
    them progressively. **Resolved: WP27 reserves the full Phase 6B block
    (`$2C`-`$2F`) in `common.inc` now, with contiguity asserts, but only
    wires `diagnostics.s` message-table entries for the two this WP actually
    raises (`CASM_DIAG_DUPLICATE_SYMBOL` `$2C`, `CASM_DIAG_SYMBOL_TABLE_FULL`
    `$2E`)** -- `CASM_DIAG_UNDEFINED_SYMBOL` (`$2D`) and
    `CASM_DIAG_PASS_MISMATCH` (`$2F`) stay reserved/unprintable until WP28
    and WP30 respectively implement their raise paths.
11. **No new cleanup owner is needed.** `resourcesCleanup`'s existing VMM
    loop (`resources.s:273-284`) already calls `vmmStoreFree` against every
    registered registry slot regardless of which module registered it.
    `symbols.s` registers its one allocation through `vmmStoreAlloc` (which
    itself calls `resourceRegisterVmm`) and needs no explicit free call or
    new cleanup path of its own.
12. **No "get symbol by index" accessor is built now.** Phase 6B's resolver
    contract only ever needs "look up by name" (Pass 1 forward references,
    Pass 2 resolution); a future Phase 8 relocation consumer might want to
    re-fetch a record by the opaque ID `symbolsLookup` returns, but building
    that now would be speculative design for an unapproved future phase.
    Deferred, not forgotten -- flagged here so a future reader knows it was a
    deliberate scope decision.

## Contract (Phase 0C.5 amendment + WP27 implementation)

1. **`CASM_VMM_BUFFER_SIZE` amended from 32 to 64.** Sole change to
   `vmm_store.s`: `CasmVmmBuffer`'s size follows the constant automatically.
   `vwPrepareTransfer`'s bounds check (`cmp #CASM_VMM_BUFFER_SIZE + 1`) needs
   no logic change, only the constant.
2. **`CASM_SYMBOL_REC_SIZE = 64`**, amending WP26's 37-byte figure. Layout
   (offsets unchanged from WP26's freeze):

   ```text
   Offset  Size  Field
   0       1     NameLen (1..31)
   1       31    Name (fixed 31-byte slot)
   32      2     ValueLo/ValueHi
   34      1     Flags (bit 0 = DEFINED; remaining bits reserved)
   35      2     NextLo/NextHi (16-bit collision-chain record index,
                       $FFFF = end of chain)
   37      27    Reserved padding, zero-filled on every write
   ```

   `CASM_SYMBOL_MAX = 512` (unchanged from WP26). Total VMM footprint
   `512 * 64 = 32768` bytes, one `vmmStoreAlloc` call.
3. **Hash function (unchanged from WP26's freeze):** rotate-left-1-XOR fold
   over the identifier's exact case-sensitive bytes, masked to 7 bits across
   128 buckets:

   ```text
   ; A = 0 (hash accumulator)
   ; for each byte b in name:
   loop:
       asl a           ; bit 7 -> Carry, bit 0 <- 0
       bcc noCarry
       ora #1          ; wrap the lost high bit into bit 0
   noCarry:
       eor (CasmPtr0Lo), y   ; XOR with the next name byte
       iny
       ...
   ; after the loop:
   and #$7F            ; mask to 7 bits -> bucket index (0-127)
   ```

   `CasmSymbolBuckets: .res 256` (128 buckets x 2-byte head-record-index,
   `$FFFF` = empty), new persistent BSS in `symbols.s`.
4. **Offset arithmetic: a single unrolled 16-bit left-shift-by-6,**
   replacing WP26's shift-add-multiply-by-37 concern entirely:

   ```text
   ; recordIndex (Lo/Hi) -> CasmVmmOffLo/OffHi
   lda recordIndexLo
   sta CasmVmmOffLo
   lda recordIndexHi
   sta CasmVmmOffHi
   asl CasmVmmOffLo
   rol CasmVmmOffHi
   asl CasmVmmOffLo
   rol CasmVmmOffHi
   asl CasmVmmOffLo
   rol CasmVmmOffHi
   asl CasmVmmOffLo
   rol CasmVmmOffHi
   asl CasmVmmOffLo
   rol CasmVmmOffHi
   asl CasmVmmOffLo
   rol CasmVmmOffHi        ; x64, six shifts, unrolled
   ```
5. **New private BSS in `symbols.s` (ordinary BSS, not zero page --
   Dependency Review item 5):**

   ```text
   CasmSymbolVmmSlot:      .res 1   ; registry slot from symbolsInit's vmmStoreAlloc
   CasmSymbolCount:        .res 2   ; bump allocator, 0..512
   CasmSymbolBuckets:      .res 256 ; 128 x 2-byte head-record-index, $FFFF = empty
   CasmSymScratchLen:      .res 1   ; nameLen, persisted across the call
   CasmSymScratchValLo:    .res 1
   CasmSymScratchValHi:    .res 1
   CasmSymScratchCursorLo: .res 1   ; chain-walk record-index cursor
   CasmSymScratchCursorHi: .res 1
   CasmSymScratchBucket:   .res 1   ; bucket index, 0-127
   ```
6. **Public routines and calling convention:**

   ```text
   symbolsInit
     Inputs:  none
     Outputs: C clear on success; C set + A = CASM_DIAG_VMM_UNAVAILABLE or
              CASM_DIAG_VMM_ALLOC_FAILED (propagated from vmmStoreAlloc,
              unchanged Phase 6A diagnostics)
     Effect:  one vmmStoreAlloc(32768) call; CasmSymbolVmmSlot = returned
              slot; CasmSymbolCount = 0; all 128 CasmSymbolBuckets entries
              set to $FFFF

   symbolsInsert
     Inputs:  CasmPtr0Lo/CasmPtr0Hi = namePtr; A = nameLen (1..31);
              X/Y = value (Lo/Hi)
     Outputs: C clear, X/Y = new record index (Lo/Hi)
              C set, A = CASM_DIAG_DUPLICATE_SYMBOL (exact case-sensitive
                  name already DEFINED) or CASM_DIAG_SYMBOL_TABLE_FULL
                  (CasmSymbolCount already at CASM_SYMBOL_MAX) or
                  CASM_DIAG_VMM_TRANSFER_FAILED (internal, item 8 above)

   symbolsLookup
     Inputs:  CasmPtr0Lo/CasmPtr0Hi = namePtr; A = nameLen (1..31);
              X/Y = pointer to a caller-owned 5-byte CASM_RESOLVE_* view
     Outputs: C clear always (matches the Phase 5 resolver ABI exactly --
              "not found" is reported through the view, never C set, except
              the internal CASM_DIAG_VMM_TRANSFER_FAILED case from item 8,
              which is the one case this routine is permitted to report via
              C set since it is not a resolution outcome at all)
              View filled: RESOLVED set + Value populated on a match;
              RESOLVED clear on no match
   ```

   Both `symbolsInsert` and `symbolsLookup` share a private
   `symbolsFindChain` helper that walks a bucket's chain via
   `vmmWindowRead`, comparing `NameLen` then exactly that many `Name` bytes
   (never the full 31-byte slot -- padding past `NameLen` is meaningful only
   because it's zero-filled, not because comparisons rely on it). On a
   match, `CasmVmmBuffer` still holds the matched record for the caller to
   extract `Value` from. `symbolsInsert` on a miss prepends the new record
   at the bucket's chain head (`Next` = the bucket's *original* head read at
   the start of the walk, not the last cursor visited) and appends it at
   VMM record index `CasmSymbolCount` (i.e., the record array grows
   append-only; chain order is unrelated to array position).
7. **New diagnostics, contiguous after `CASM_DIAG_PHASE6A_LAST = $2B`:**

   ```text
   CASM_DIAG_DUPLICATE_SYMBOL  = $2C  ; raised by symbolsInsert; printable
   CASM_DIAG_UNDEFINED_SYMBOL  = $2D  ; reserved; WP28 raises/prints it
   CASM_DIAG_SYMBOL_TABLE_FULL = $2E  ; raised by symbolsInsert; printable
   CASM_DIAG_PASS_MISMATCH     = $2F  ; reserved; WP30 raises/prints it
   CASM_DIAG_PHASE6B_LAST      = $2F
   ```

   Same `.assert ... = CASM_DIAG_PHASE6A_LAST + n` contiguity pattern as
   every prior phase range.

## Scope

Included:

- `src/external/casm/symbols.s`: `symbolsInit`, `symbolsInsert`,
  `symbolsLookup`, private `symbolsFindChain` helper, all BSS in Contract
  item 5.
- `common.inc`: `CASM_VMM_BUFFER_SIZE` 32 -> 64; new `CASM_SYMBOL_*`
  constants and asserts; diagnostics `$2C`-`$2F` with contiguity asserts.
- `vmm_store.s`: no logic change, only inherits the grown `CasmVmmBuffer`
  from the amended constant.
- `diagnostics.s`: message-table entries for `CASM_DIAG_DUPLICATE_SYMBOL`
  and `CASM_DIAG_SYMBOL_TABLE_FULL` only.
- A standalone `tests/src/casm_symbols/casm_symbols.s` fixture harness
  (mirrors `test_casm_vmm`'s structure: its own `diagPrintFatal` stub to
  avoid dragging in the lexer/diagnostics chain via `resources.s`'s
  `exitSuccess`/`exitFatal`), plus its `BUILD_TEST_CASM_SYMBOLS` counter and
  a `CMakeLists.txt` special case in the `TEST_CA65_SRCS` loop.
- MAIN envelope measurement and a justified size proposal (not pre-sized
  here, per the WP13/19/23/24/26 precedent).

Excluded (each requires its own dedicated plan per `AGENTS.md`):

- any `parser.s`, `opcodes.s`, `emit.s`, or `casm.s` change (`CasmParserStmt`
  growth, `CasmPassMode`, label grammar, and Pass 1/Pass 2 orchestration are
  all WP28);
- Pass 2 resolution/emission (WP29);
- relative-branch migration and Pass 1/Pass 2 disagreement detection (WP30);
- binding `symbolsLookup` as the actual `exprEvaluate` resolver in production
  (WP28) -- WP27 only proves the routine works to that exact ABI via its own
  test harness.

## Expected Files

| File | Action |
| --- | --- |
| `brain/plans/2026-07-22-casm-phase6-wp27-symbol-table-storage.md` | this document |
| `src/external/casm/symbols.s` | Create |
| `src/external/casm/common.inc` | Modify: `CASM_VMM_BUFFER_SIZE` amendment, `CASM_SYMBOL_*` constants, diagnostics `$2C-$2F` |
| `src/external/casm/vmm_store.s` | No logic change; buffer size follows the amended constant |
| `src/external/casm/diagnostics.s` | Modify: message-table entries for `$2C`/`$2E` |
| `tests/src/casm_symbols/casm_symbols.s` | Create: fixture driver |
| `tests/src/casm_symbols/BUILD_TEST_CASM_SYMBOLS` | Create |
| `CMakeLists.txt` | Add `casm_symbols` special case to `TEST_CA65_SRCS`; MAIN size if the measured overflow requires it |
| `wiki/tasks/casm.md`, `brain/task.md`, `brain/KNOWLEDGE.md`, `CHANGELOG.md` | Closeout updates; `KNOWLEDGE.md`'s Phase 0C.5 section is amended (37 -> 64 bytes) as part of this WP, not silently left stale |

## ABI, Storage, and Runtime Effects

- `CASM_VMM_BUFFER_SIZE`: 32 -> 64 (Phase 6A constant amendment; regression
  covered by re-running `test_casm_vmm` unchanged, item 2 above).
- New: `CASM_SYMBOL_REC_*` offsets, `CASM_SYMBOL_REC_SIZE = 64`,
  `CASM_SYMBOL_MAX = 512`, and the BSS listed in Contract item 5.
- New diagnostics `$2C`-`$2F` (two printable now, two reserved).
- No change to the Phase 4 parser/opcode/emit ABI, the Phase 5 expression
  ABI, or `vmm_store.s`/`resources.s`'s existing call signatures --
  `symbolsInit`/`Insert`/`Lookup` are net-new call sites into
  already-stable Phase 6A routines.

## Verification Plan

Sequential fixtures in `test_casm_symbols` (sequential, not independent
per-case, matching `test_casm_vmm`'s precedent -- symbol-table state has
real cross-call side effects across one PRG execution):

1. `syminit1` -- `symbolsInit` succeeds; registry slot obtained;
   `CasmSymbolCount = 0`; spot-check several `CasmSymbolBuckets` entries
   equal `$FFFF`.
2. `symins1` -- insert one symbol; verify `C` clear, record index 0
   returned, `CasmSymbolCount = 1`.
3. `symlook1` -- look up the just-inserted name; verify `RESOLVED` set and
   the correct `Value` returned via the caller-supplied output view.
4. `symlookmiss1` -- look up a name never inserted; verify `C` clear and
   `RESOLVED` clear (never `C` set for "not found," per the frozen
   contract).
5. `symdup1` -- insert the same name again; verify `C` set +
   `CASM_DIAG_DUPLICATE_SYMBOL`; `CasmSymbolCount` unchanged.
6. `symcase1` -- insert two names differing only in case (`Loop` vs.
   `LOOP`); verify both succeed as distinct symbols.
7. `symchain1` -- insert enough names to force at least one real bucket
   collision (chosen or volume-driven); verify every inserted name remains
   independently look-up-able (chain-walk correctness, not just
   single-record correctness).
8. `symlen1` -- insert and look up a 31-byte (maximum-length) identifier;
   verify correct round-trip with no truncation.
9. `sympad1` -- after an insert, directly `vmmWindowRead` the record and
   confirm all 27 padding bytes are zero.
10. `symfull1` -- insert `CASM_SYMBOL_MAX` (512) distinct symbols via a
    generated-name loop (not 512 literal fixture lines); verify the 513th
    returns `C` set + `CASM_DIAG_SYMBOL_TABLE_FULL` and `CasmSymbolCount`
    stays at exactly 512.

Build both relocation bases and `test_image_d64`; run in VICE; record the
full dot/summary matrix in the walkthrough. Every failing fixture is
investigated before completion is requested, matching WP25's discipline.

## Atomic Implementation Increments

1. Amend `common.inc`: `CASM_VMM_BUFFER_SIZE` 32 -> 64; add `CASM_SYMBOL_*`
   constants/asserts; add diagnostics `$2C`-`$2F` with contiguity asserts.
2. Rebuild and re-run `test_casm_vmm` unchanged; confirm all 7 existing
   fixtures still pass before writing any `symbols.s` code (Dependency
   Review item 2's regression gate).
3. Add `diagnostics.s` message-table entries for `$2C`/`$2E`.
4. Implement `symbols.s` incrementally: `symbolsInit`, then
   `symbolsFindChain`, then `symbolsInsert`, then `symbolsLookup` --
   matching WP23/24's own incremental-build style.
5. Create `tests/src/casm_symbols/casm_symbols.s` and
   `BUILD_TEST_CASM_SYMBOLS`; add the `casm_symbols` CMake special case.
6. Implement fixtures 1-10 incrementally, confirming the build after each
   small batch.
7. Build both relocation bases and `test_image_d64`; measure MAIN overflow;
   propose and get approval for the new MAIN size, matching the
   WP13/19/23/24/26 precedent.
8. Run the harness in VICE (ask the user); record the dot/summary output in
   a walkthrough.
9. Amend `brain/KNOWLEDGE.md`'s Phase 0C.5 section to reflect the 64-byte
   record (superseding WP26's 37-byte figure) as part of this WP's own
   closeout, not a separate follow-up.
10. Apply the version-only completion increment (`0.1.28` -> `0.1.29`),
    rebuild, confirm no-change-rebuild stability, both images pass.
11. Update `wiki/tasks/casm.md`, `brain/task.md`, `CHANGELOG.md`, and
    Taskwarrior.

## Failure and Cleanup

`symbolsInit`'s `vmmStoreAlloc` failure propagates its existing
`CASM_DIAG_VMM_UNAVAILABLE`/`CASM_DIAG_VMM_ALLOC_FAILED` unchanged -- no new
failure mode. `symbolsInsert` never leaves partial VMM/RAM state: the bucket
head and `CasmSymbolCount` are only updated after a successful
`vmmWindowWrite` of the new record. Central `resourcesCleanup` already frees
the registered VMM allocation on every exit path (Dependency Review item
11); `symbols.s` registers no separate cleanup owner. The test harness
follows `test_casm_vmm`'s precedent: a failing fixture prints an `F` and
continues rather than aborting, and calls `DOS_EXIT` directly rather than
through the full production cleanup contract.

## Documentation and DOX Closeout

Update this plan, `brain/KNOWLEDGE.md` (amend Phase 0C.5's record size),
`brain/task.md`, `wiki/tasks/casm.md`, `CHANGELOG.md`, Taskwarrior, and a new
walkthrough with the full fixture matrix. `AGENTS.md` needs no change (it
does not cite symbol-record specifics). Re-read the `src`/`external`/`casm`/
`tests` DOX chain after source edits.

## Stop Conditions

Stop if the `test_casm_vmm` regression check (Atomic Increment 2) fails
after the buffer-size amendment -- that would mean an assumption this review
missed. Stop if any of fixtures 1-10 fails and its scope or fix is not small
and well-understood enough for the user to approve fixing in place, matching
WP25's precedent. Stop if a further material discrepancy is found during
implementation, requiring this plan to be amended and re-approved.

## Completion Gate

WP27 is complete when fixtures 1-10 pass in VICE, both images build, the
measured MAIN size is approved and applied, the version-only increment is
verified, `brain/KNOWLEDGE.md`'s Phase 0C.5 section reflects the 64-byte
record, and the user explicitly approves. This does not activate WP28, which
remains separately gated per `AGENTS.md`.

## Progress

- 2026-07-22: Drafted after WP26 closed (CASM `0.1.28` build 1103). Found
  and reconciled a real conflict WP26's freeze missed: the frozen 37-byte
  symbol record cannot pass through Phase 6A's existing 32-byte VMM transfer
  buffer at all. Asked the user how to resolve it, since fixing the buffer
  size reopened whether to also choose a multiply-friendly record size;
  user chose to pad the record to 64 bytes and grow the buffer to match,
  replacing the offset arithmetic's shift-add multiply with a single
  16-bit shift-left-6. Designing the exact insert/lookup algorithm in
  enough detail to remove implementation ambiguity surfaced two further
  corrections to the parent Phase 6 plan's own predictions: `symbols.s`
  needs none of the zero-page `CasmPassScratch0-3` group after all (its
  transient state is all values, not pointers, so it lives in ordinary BSS
  instead, leaving that zero-page group free for WP28), and its calling
  convention must avoid `CasmValue0Lo/Hi` for anything spanning a nested
  `vmmWindowRead`/`Write` call, since that exact shared-scratch bug class
  already bit `vmm_store.s` three times during WP23-25. `symbolsLookup`'s
  signature is designed to match the Phase 5 resolver callback ABI exactly,
  so WP28 can bind it with zero adapter code. Awaiting user approval before
  implementation begins.
