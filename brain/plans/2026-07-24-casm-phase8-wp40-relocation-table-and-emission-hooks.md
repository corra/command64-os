---
feature: casm-phase8-wp40-relocation-table-and-emission-hooks
created: 2026-07-24
status: planned
---

# Plan: CASM Phase 8 WP40 - Relocation Table Storage and Emission-Site Hooks

## Objective

Implement Phase 0C.14 Contract item 4: a VMM-backed, append-only relocation
table, and wire the four (really six call sites, see Dependency Review) byte
positions that must record an entry into it. This WP produces no R6 footer
-- the table exists in VMM only, unread by anything until WP41 appends it
to the output file. Program bytes themselves are unaffected: this WP adds a
side-channel recording, not a code-generation change.

Taskwarrior: `2175e962-2221-4308-8e3b-920065852d2d` (unblocked by WP39's
completion).

Prerequisite: CASM Phase 8 WP39 is complete and approved (CASM `0.1.41`
build 1147, `CASM_PARSER_STMT_RELOCATABLE` correctly classified). Approval
of this plan is required before activation or source edits, per the CASM
`AGENTS.md` gate.

## Baseline

- CASM `0.1.41` build 1147. MAIN headroom 68 of 13568 bytes -- tight; this
  WP is expected to need a size bump (new module, new call sites), measured
  during implementation rather than pre-guessed.
- `CasmParserStmt.Flags` bit 1 (`CASM_PARSER_STMT_RELOCATABLE`) is now
  correctly derived (WP39) at every operand-bearing statement's expression
  evaluation.
- `CASM_VMM_CAPACITY = 8`; a Pass 2 run today uses at most 2 of 8 slots
  (combined source load, symbol table). `CASM_VMM_ALLOC_MAX_BYTES = 65536`
  per allocation.
- `CASM_VMM_BUFFER_SIZE = 64` (frozen since WP27, cannot grow without
  breaking the symbol-record contract); `vmmWindowWrite`/`vmmWindowRead`
  accept any byte count `0..64`, not only exact 64-byte transfers --
  confirmed by re-reading `vwPrepareTransfer`'s bounds check
  (`cmp #CASM_VMM_BUFFER_SIZE + 1`).
- The next free `CASM_DIAG_*` identifier is `$30` (confirmed: no
  `CASM_DIAG_*` constant is defined at `$30` or above today).
- `CasmPc` (`emit.s`) holds the address of the byte about to be written at
  the moment `emitByte` is called for it (pre-increment) -- confirmed by
  re-reading `emitByte`'s exact instruction order (`jsr emitRawByte` then
  `inc CasmPc`).
- `casm.s`'s `start` routine calls `fileCreateOutput` immediately before
  Pass 2's `emitInit`/`casmRunPass(EMIT)` -- the natural insertion point for
  a one-time relocation-table allocation, mirroring how the output file
  itself is created exactly once, for Pass 2 only.

## Dependency Review and Discrepancies Reconciled

1. **Re-tracing every byte-emission call site (not trusting WP37's original
   four-site enumeration at face value) found two of the four need a
   two-sided check, not a single flag check -- a real, previously
   unaccounted-for correctness gap.** `emitInstruction`'s length-3 branch
   and `emitWordList` both emit a `VAL_LO` byte *and* a `VAL_HI` byte for
   the same logical value. WP37's freeze described only "the high byte" as
   relocatable at these two sites -- correct for the common case
   (`JMP LABEL`, `.WORD LABEL`, no extraction), where `VAL_LO` is a genuine
   low byte (never relocatable) and `VAL_HI` is the genuine high byte
   (relocatable). But `<`/`>` extraction is grammatically reachable at
   *both* sites, not just in `.BYTE`/immediate context:
   `parseOperandSequence`'s `posAbsolute` accepts a leading `CASM_TOKEN_LESS`/
   `CASM_TOKEN_GREATER` exactly like `posImmediate` does (confirmed by
   re-reading the dispatch table, not assumed), so `LDA >LABEL` is valid
   absolute-mode syntax today (`FORCE_ABS` always promotes a symbol-derived
   operand away from zero-page, so this never reaches `eiTwoByte`). `.WORD`'s
   per-element parse uses the identical `parserParseExpressionValue` as
   every other operand, so `.WORD >LABEL` is equally reachable. In both
   cases, extraction moves the real relocatable byte into `VAL_LO` and
   zeroes `VAL_HI` (`expr.s`'s `applyExtraction`, unchanged by WP39) --
   `RELOCATABLE` stays set (only `<` clears it), so a naive
   "record `VAL_HI` when `RELOCATABLE`" check would **wrongly mark a
   genuine constant `$00` byte as needing a page-delta patch**, corrupting
   it at load time on any non-default page.
2. **Resolution: use `VAL_HI`'s own zero/nonzero state, already available
   with no new ABI field, to disambiguate.** At both two-byte sites: record
   the `VAL_LO` position when `RELOCATABLE` is set **and** `VAL_HI == 0`
   (the extraction case -- `VAL_LO` holds the real relocatable byte);
   record the `VAL_HI` position when `RELOCATABLE` is set **and**
   `VAL_HI != 0` (the full-value case -- `VAL_HI` holds the real relocatable
   byte). This is sound specifically in Pass 2 (`CASM_PASS_MODE_EMIT`) with
   a resolved symbol: a genuine relocatable address is always `>= $3400`
   (`CASM_DEFAULT_ORIGIN`), so its real high byte can never legitimately be
   zero -- `VAL_HI == 0` reliably means "extraction happened," never a
   coincidental full-value match. `.BYTE`'s single-byte site and
   `eiTwoByte`'s immediate-mode site need no such disambiguation: each
   already emits exactly one byte total, and each already has an existing
   guarantee that `VAL_HI == 0` by the time it reaches emission
   (`.BYTE`'s `eblRange`; immediate's `ofRequire8Bit` in `opcodesFindOpcode`,
   confirmed by re-reading both -- neither exempts a symbol-derived operand
   from the check), so checking `RELOCATABLE` alone there is already
   equivalent to the fuller rule.
3. **`eiTwoByte`'s immediate-mode site genuinely needs its `CASM_MODE_IMMEDIATE`
   guard, confirmed by re-tracing rather than assumed.** `ofRequire8Bit`
   (`opcodesFindOpcode`) is also called for `CASM_OPKIND_INDEXED_INDIRECT`/
   `CASM_OPKIND_INDIRECT_INDEXED` (`(zp,X)`/`(zp),Y`), so `LDA (>LABEL),Y`
   is *also* syntactically reachable with `RELOCATABLE` set and `VAL_HI == 0`,
   reaching the identical `eiTwoByte` code path as immediate mode. Per the
   master plan's explicit exclusion list, an indexed-indirect/indirect-
   indexed pointer byte must never be relocatable regardless of what the
   underlying symbol looks like (it is data the *program* reads at runtime
   to form an address, not something the *loader* can patch at load time).
   `eiTwoByte` must check `CasmInsn.Mode == CASM_MODE_IMMEDIATE` before
   consulting `RELOCATABLE` at all -- confirming WP37's original finding
   was correct, not (as briefly suspected during this WP's own research) a
   redundant check.
4. **Symbol-derived operands never reach zero-page addressing at all**,
   confirmed by re-reading `opcodesFindOpcode`'s `ZEROPAGE`/`ZEROPAGE_X`/
   `ZEROPAGE_Y` branches: each checks `CASM_PARSER_STMT_FORCE_ABS` first and
   promotes to the absolute-family mode whenever it is set, and `FORCE_ABS`
   is unconditionally set for any symbol-derived operand (WP28). So a
   relocatable value can never end up in a genuine zero-page addressing
   mode -- only in `CASM_MODE_IMMEDIATE` at the `eiTwoByte` site, never
   `CASM_MODE_ZEROPAGE`/`_X`/`_Y`. No additional guard is needed beyond the
   `CASM_MODE_IMMEDIATE` check in item 3.
5. **The relocation table should be allocated unconditionally, every Pass 2
   run, regardless of whether the assembly turns out static or
   relocatable.** VMM allocation is REU-backed, not base-RAM/MAIN-envelope
   space, so an unused 8192-byte grant for a static assembly costs nothing
   that matters (one more `DOS_ALLOC_MEM`/`DOS_FREE_MEM` pair, one of 8
   registry slots for the duration of Pass 2 -- comfortable headroom, 2 of
   8 normally in use). The alternative -- snapshotting Pass 1's
   `CasmRelocatableMode` determination (mirroring `CasmPass1FinalPc`'s
   existing snapshot precedent) to skip allocation for a static assembly --
   was considered and rejected as unnecessary complexity for a real cost of
   approximately zero. In static mode, `CASM_PARSER_STMT_RELOCATABLE` is
   never set (WP39: it is only ever OR'd in when `CasmRelocatableMode` was
   nonzero at classification time), so the table simply stays empty (zero
   entries) for a static assembly and is freed normally at cleanup.
6. **Table entries write immediately, one at a time, through
   `vmmWindowWrite` -- not staged/batched across statements.** A batching
   design (accumulating several entries in a small base-RAM buffer before
   one larger flush) was considered for efficiency, but rejected: the only
   available shared transfer window is `CasmVmmBuffer`
   (`CASM_VMM_BUFFER_SIZE = 64`, frozen), which `symbolsLookup` *also*
   transiently uses on every identifier resolution -- and symbol lookups
   are interleaved with relocation recording within the same statement
   (`LDA TARGET` resolves `TARGET` via `symbolsLookup`, which uses
   `CasmVmmBuffer`, *before* `emitInstruction` gets a chance to record
   anything). Accumulating relocation entries in that same shared buffer
   across calls would silently clobber them the next time a symbol is
   resolved -- exactly the shared-scratch-clobber bug class this codebase
   has already hit three separate times (WP23-25's `vwPrepareTransfer`/
   `vmmReplay` cells). A dedicated new staging buffer would avoid the
   clobber but cost scarce MAIN bytes at 68 free. Writing each entry
   immediately (`vmmWindowWrite` already accepts a 2-byte transfer, per
   Baseline) needs no new persistent buffer and cannot be clobbered, since
   nothing is held in `CasmVmmBuffer` across any other call.
7. **`relocRecord`'s "code offset" is `CasmPc - CASM_DEFAULT_ORIGIN`,
   computed once inside `relocRecord` itself from `CasmPc`'s current value**
   (the address of the byte about to be written, per Baseline), not passed
   in by each call site -- avoids duplicating the subtraction at up to six
   call sites. This is always well-defined when `relocRecord` is actually
   invoked, since it is only ever called when `CASM_PARSER_STMT_RELOCATABLE`
   is already set, which itself is only ever true under relocatable mode
   (`CasmPc` therefore always `>= CASM_DEFAULT_ORIGIN`).
8. **Table entries come out in ascending offset order for free.** Pass 2
   emits bytes in strictly increasing address order, so entries are
   recorded in strictly increasing offset order with no separate sort step
   -- matching `tools/reloc.py`'s own diff-based construction, which
   produces its table in the same ascending order by simple iteration.
9. **No end-to-end fixture in this WP can observe the table's actual
   contents** -- no R6 footer exists until WP41, so nothing outside CASM
   can read the VMM table back. This WP's own correctness is proven two
   ways: a new standalone `test_casm_reloc` harness (mirroring the
   `test_casm_symbols`/`test_casm_vmm` isolated-module-first precedent)
   directly exercises `relocInit`/`relocRecord` -- allocation, sequential
   append, offset arithmetic, capacity rejection, and the
   `CASM_PASS_MODE_MEASURE` no-op gate -- by reading the raw VMM bytes back
   through `vmmWindowRead`; and existing/new end-to-end fixtures prove the
   new emission-site hooks do not change any *program* byte (the table is a
   side channel, invisible in the PRG output itself, so every existing
   trusted reference re-run unmodified is a real regression proof). Full
   proof that the *right* offsets were recorded for a real program waits
   for WP41's footer, matching the same observability-gap pattern WP39
   already established for its own classification bit.

## Contract to Freeze (amends Phase 0C.14)

1. New module `src/external/casm/reloc.s`: `relocInit` (allocate
   `CASM_RELOC_TABLE_BYTES` = 8192 bytes via `vmmStoreAlloc`, register the
   returned slot, reset the entry count to 0; called once from `casm.s`
   immediately before Pass 2's `emitInit`, unconditionally regardless of
   mode per Dependency Review item 5) and `relocRecord` (no-ops under
   `CASM_PASS_MODE_MEASURE`; otherwise computes `CasmPc - CASM_DEFAULT_ORIGIN`
   and appends it via one `vmmWindowWrite`; fails with a new
   `CASM_DIAG_RELOC_TABLE_FULL` at `$30` when the entry count already
   equals `CASM_RELOC_MAX` = 4096).
2. `emit.s` gains two small private helpers -- `emitMaybeRecordHi` (record
   iff `CASM_PARSER_STMT_RELOCATABLE` set and `VAL_HI != 0`) and
   `emitMaybeRecordLo` (record iff `CASM_PARSER_STMT_RELOCATABLE` set and
   `VAL_HI == 0`) -- called immediately before the corresponding `emitByte`
   call at each site, propagating a `relocRecord` failure exactly like an
   `emitByte` failure today.
3. Call-site wiring (Dependency Review items 1-4):
   - `emitInstruction`'s shared length-3 branch: `emitMaybeRecordLo` before
     the `VAL_LO` `emitByte`, `emitMaybeRecordHi` before the `VAL_HI`
     `emitByte`. Covers `CASM_MODE_ABSOLUTE`/`_X`/`_Y`/`_INDIRECT`
     uniformly, no per-mode branching (WP37's original finding, unchanged).
   - `eiTwoByte`: `emitMaybeRecordLo`-equivalent check before the single
     `VAL_LO` `emitByte`, gated additionally on
     `CasmInsn.Mode == CASM_MODE_IMMEDIATE` (Dependency Review item 3).
   - `emitByteList`: `emitMaybeRecordLo` before the single `VAL_LO`
     `emitByte` (the `VAL_HI == 0` half of the check is redundant with
     `eblRange`'s existing guarantee but included for uniformity).
   - `emitWordList`: `emitMaybeRecordLo` before the `VAL_LO` `emitByte`,
     `emitMaybeRecordHi` before the `VAL_HI` `emitByte`.
4. `common.inc`: `CASM_RELOC_MAX = 4096`, `CASM_RELOC_TABLE_BYTES = 8192`,
   `CASM_DIAG_RELOC_TABLE_FULL = $30` and its message-table entry.

## Scope

Included in WP40:

- `reloc.s` (new): `relocInit`, `relocRecord`, private VMM-slot storage.
- `emit.s`: `emitMaybeRecordHi`/`emitMaybeRecordLo` and their four call
  sites (`emitInstruction` x2, `eiTwoByte` x1, `emitByteList` x1,
  `emitWordList` x2 -- six call sites total per Dependency Review items
  1-4).
- `casm.s`: one new `relocInit` call before Pass 2's `emitInit`.
- `common.inc`: new constants and diagnostic.
- `diagnostics.s`: new message-table entry.
- New standalone `tests/src/casm_reloc/casm_reloc.s` harness.
- New/updated fixtures proving the emission-site hooks do not change any
  program byte (regression) and that a program combining every relocatable
  operand shape assembles successfully.

Excluded from WP40 (deferred to WP41):

- R6 footer serialization (base address, entry count, magic).
- Appending the table to the output file.
- Any change to the default-origin/`.ORG` mechanism (WP38) or the
  classification mechanism itself (WP39) -- both are consumed here
  unmodified.

## Expected Files

| File | Action |
| --- | --- |
| `brain/plans/2026-07-24-casm-phase8-wp40-relocation-table-and-emission-hooks.md` | this document |
| `src/external/casm/reloc.s` | new: `relocInit`, `relocRecord` |
| `src/external/casm/emit.s` | `emitMaybeRecordHi`/`Lo`, six call sites |
| `src/external/casm/casm.s` | `relocInit` call; `.import` additions |
| `src/external/casm/common.inc` | `CASM_RELOC_MAX`, `CASM_RELOC_TABLE_BYTES`, `CASM_DIAG_RELOC_TABLE_FULL` |
| `src/external/casm/diagnostics.s` | new message-table entry |
| `CMakeLists.txt` | register `reloc.s` for the `casm` target; new `test_casm_reloc` target |
| `tests/src/casm_reloc/casm_reloc.s` | new standalone harness |
| `cmake/GenerateCasmTestFixtures.cmake` | new end-to-end fixtures |
| `wiki/tasks/casm.md`, `brain/task.md`, `brain/KNOWLEDGE.md` (Phase 0C.17), `CHANGELOG.md` | completion records |

## ABI, Storage, and Runtime Effects

- New VMM allocation: 8192 bytes, one registry slot, held for the duration
  of Pass 2 only, allocated unconditionally.
- New `CASM_DIAG_RELOC_TABLE_FULL` at `$30`.
- No change to `CasmParserStmt`, `CASM_EXPR_FLAG_RELOCATABLE`, or any
  existing exported symbol's contract -- purely additive.
- No zero-page impact (reloc.s's own state is ordinary BSS/VMM, matching
  the symbol table's and source loader's precedent).
- MAIN size: not pre-sized; measured during implementation. A bump is
  expected given 68 bytes of current headroom and a genuinely new module
  plus six call sites.

## Verification and Fixture Strategy

- `test_casm_reloc` (new standalone harness, isolated from `emit.s`/
  `casm.s`): `relocInit` allocation and registration; sequential
  `relocRecord` appends with correct offset arithmetic (verified by reading
  the raw VMM bytes back via `vmmWindowRead`); the `CASM_PASS_MODE_MEASURE`
  no-op gate; capacity rejection at exactly `CASM_RELOC_MAX` entries
  (`CASM_DIAG_RELOC_TABLE_FULL`).
- Every existing static and WP38/39 fixture (`casmemit1`, `casmhello`,
  `casmorg1`, `casmnoorg1`, `casmordhaz1`, etc.) re-run unmodified and
  confirmed byte-identical -- proves the six new call sites never change a
  program byte, only add a side-channel VMM write.
- New end-to-end fixtures, each proving successful assembly (not table
  contents, per Dependency Review item 9) for the shapes newly reasoned
  about in this plan: an absolute operand (`JMP LABEL`), `.WORD LABEL`,
  `.BYTE >LABEL`, `LDA #>LABEL`, and the two-sided extraction cases found
  during this WP's own research (`.WORD >LABEL`, `LDA >LABEL` in absolute
  context) -- each confirmed to still produce its already-established
  correct program bytes.

## Atomic Implementation Increments

1. `common.inc`: add `CASM_RELOC_MAX`, `CASM_RELOC_TABLE_BYTES`,
   `CASM_DIAG_RELOC_TABLE_FULL`, and asserts.
2. `diagnostics.s`: add the new message-table entry.
3. `reloc.s`: implement `relocInit`/`relocRecord`.
4. `emit.s`: implement `emitMaybeRecordHi`/`Lo` and wire the six call
   sites.
5. `casm.s`: add the `relocInit` call and new imports.
6. `tests/src/casm_reloc/casm_reloc.s`: new standalone harness; register
   its CMake target.
7. Add end-to-end fixtures; re-run every existing trusted reference as
   regression.
8. Build, measure MAIN headroom via `ld65 -m`, propose and apply any
   necessary size bump with the measured justification.
9. User runtime verification in the supported local emulator; record a
   walkthrough.
10. Version-only completion increment, no-change rebuild check, all three
    disk images, `brain/KNOWLEDGE.md` Phase 0C.17 entry, task/changelog
    updates, request completion approval.

## Failure and Cleanup

`relocInit`'s VMM allocation is registered through the existing central
resource registry (`resourceRegisterVmm`), so it is freed automatically by
`resourcesCleanup` on every success and failure path exactly like the
symbol table's and source loader's allocations -- no new cleanup logic is
needed. A `relocRecord` failure (`CASM_DIAG_RELOC_TABLE_FULL`) is fatal and
routes through the existing `emitByte`-failure propagation shape at each
call site.

## Documentation and DOX Closeout

Update this plan's Progress section, `brain/KNOWLEDGE.md` (new Phase 0C.17
entry amending 0C.14-0C.16), `wiki/tasks/casm.md`, `brain/task.md`,
`CHANGELOG.md`, and Taskwarrior.

## Stop Conditions

Stop if CASM Phase 8 WP39 is not complete and approved. Stop if
implementation surfaces a further material discrepancy against this
document -- in particular, if a legitimate operand shape is found where
the `VAL_HI` zero/nonzero disambiguation (Dependency Review items 1-2)
does not correctly identify the relocatable byte, since that is the one
genuinely new piece of reasoning this WP introduces beyond WP37's original
enumeration.

## Completion Gate

WP40 is complete when: `test_casm_reloc`'s full fixture matrix passes;
every existing static and WP38/39 fixture remains byte-identical; the new
end-to-end fixtures assemble successfully with correct program bytes; MAIN
headroom is measured and any necessary bump is justified and applied; the
user completes a runtime walkthrough; and the user explicitly approves
completion, together with the version-only increment and
`brain/KNOWLEDGE.md`/task/changelog updates.

## Progress

- 2026-07-24: Drafted after WP39's approval. Re-traced every byte-emission
  call site from scratch rather than trusting WP37's original four-site
  enumeration, and found a real, previously unaccounted-for correctness
  gap: `emitInstruction`'s absolute-family branch and `emitWordList` both
  emit a `VAL_LO`/`VAL_HI` pair for one logical value, and `<`/`>`
  extraction turns out to be grammatically reachable at both sites (not
  only `.BYTE`/immediate), confirmed by re-reading `parseOperandSequence`'s
  dispatch table directly. A naive "record `VAL_HI` when `RELOCATABLE`"
  check would wrongly mark a genuine constant `$00` byte (the padding
  `applyExtraction` leaves behind) as needing a page-delta patch, corrupting
  it at load time. Resolved using `VAL_HI`'s own zero/nonzero state --
  already available, no new ABI field needed -- to tell a genuine
  full-value high byte from an extracted-value low byte parked next to a
  zero pad. Also re-verified (rather than re-assumed) that `eiTwoByte`
  genuinely needs its `CASM_MODE_IMMEDIATE` guard: `ofRequire8Bit` is
  shared with indexed-indirect/indirect-indexed addressing, so
  `LDA (>LABEL),Y` is equally reachable and must never be recorded, per the
  master plan's explicit exclusion of indexed-indirect/indirect-indexed
  pointer bytes. Recommends unconditional relocation-table allocation
  (VMM cost only, not MAIN-envelope) and immediate (unbatched)
  `vmmWindowWrite` per entry, rejecting a batched design that would reuse
  the shared `CasmVmmBuffer` across calls -- the same shared-scratch-
  clobber bug class this codebase has already hit three times, since
  `symbolsLookup` also transiently uses that buffer between a statement's
  relocation-eligible operands.
