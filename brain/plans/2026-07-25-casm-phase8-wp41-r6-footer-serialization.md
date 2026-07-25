---
feature: casm-phase8-wp41-r6-footer-serialization
created: 2026-07-25
status: planned
---

# Plan: CASM Phase 8 WP41 - Native R6 Footer Serialization

## Objective

Implement Phase 0C.14 Contract items 5-6: append the relocation table
`relocRecord` has been accumulating (WP40) to the output file, followed by
the R6 footer (base address, entry count, magic), immediately after
`emitFinalize` succeeds -- gated entirely on relocatable mode, so static
output stays exactly the plain PRG it is today. This is the WP that makes
the relocation table observable for the first time: WP39/WP40 both had to
defer their own end-to-end proof to "once the footer exists" -- that gap
closes here.

Taskwarrior: `005c8fec-684d-4f0d-a171-c7519081bef2` (unblocked by WP40's
completion).

Prerequisite: CASM Phase 8 WP40 is complete and approved (CASM `0.1.42`
build 1154, relocation table storage and all six emission-site hooks
wired). Approval of this plan is required before activation or source
edits, per the CASM `AGENTS.md` gate.

## Baseline

- CASM `0.1.42` build 1154. MAIN headroom 106 of 13824 bytes -- tight;
  another bump is plausible, measured during implementation rather than
  pre-guessed.
- `reloc.s` (WP40) owns `CasmRelocVmmSlot` (exported) and `CasmRelocCount`
  (private, 2 bytes) for the VMM-backed table; `relocRecord` already
  appends entries during Pass 2's real emission.
- `emit.s` (WP39) owns `CasmRelocatableMode` (exported): 0 for a static
  assembly (explicit `.ORG`), 1 for the implicit relocatable default,
  settled by the time Pass 2's dispatch completes.
- `fileio.s`'s `fileWrite` (confirmed by re-reading its exact contract)
  takes an arbitrary `X/Y` source pointer and `CasmIoLenLo/Hi` byte count
  -- it is not tied to `CasmEmitBuffer`, so it can write directly from
  `CasmVmmBuffer` (already used as reloc.s's own transfer window) with no
  new buffer.
- `casm.s`'s `start` routine, confirmed by re-reading the current sequence:
  `jsr emitFinalize / bcs startFatalNear / jsr diagPrintPhase2Ready / jsr
  sourceClose / ...`. `emitFinalize` (`emitFlush`) fully drains
  `CasmEmitBuffer` and leaves the file position immediately after the last
  program byte -- the exact point a table/footer write can append with no
  seeking.
- `vmm_store.s`'s `vmmWindowRead`/`vmmWindowWrite` both already accept any
  byte count `0..64` (`CASM_VMM_BUFFER_SIZE`, matching `CasmEmitBuffer`'s
  own `CASM_EMIT_BUFFER_SIZE = 64`) -- confirmed identical chunk-size
  convention already used throughout this codebase.
- `tools/reloc.py`'s exact byte layout (already the authoritative
  reference, re-confirmed by re-reading it): table of 16-bit LE offsets,
  then 2-byte LE base address, then 2-byte LE relocation count, then the
  ASCII magic `"R6"` (`$52 $36`).

## Dependency Review and Discrepancies Reconciled

1. **The master plan's own gate text ("static fixtures remain ordinary
   PRGs") implies relocatable fixtures do not** -- and a direct
   consequence, easy to miss, is that every relocatable-mode trusted
   reference built in WP38-WP40 is now stale the moment this WP lands.
   Enumerated by checking each fixture's source for an `.ORG`: `casmorg1`,
   `casmnoorg1`, `casmordhaz1`, `casmrelop1`, and `casmrelop2` are all
   relocatable-mode (no `.ORG`) and will each gain a real footer;
   `casmorgexpl1` (explicit `.ORG $3400`) and every fixture predating WP38
   (`.ORG` was mandatory before it, so all of them use it) stay static and
   are unaffected. This WP's scope therefore includes **updating five
   existing `.ref.hex` manifests**, not only adding new ones -- confirmed
   by hand-deriving each fixture's exact relocation offsets from its
   already-established program bytes (Contract item 4 below).
2. **A real, deliberate WP38 invariant breaks by design, not by
   regression.** `casmorgexpl1.ref.hex`'s own header comment currently
   states it is "deliberately byte-identical" to `casmorg1.ref.hex",
   proving the implicit default and an explicit `.ORG $3400` produced the
   same output -- true only because neither had a footer yet.
   `casmorgexpl1` stays static (unaffected); `casmorg1` gains a footer.
   They diverge after this WP, which is the *correct*, intended outcome
   (relocatable and static output are supposed to differ once R6 exists),
   not a fixture defect. `casmorgexpl1.ref.hex`'s comment needs a
   correction noting this was a WP38-era, pre-R6 equivalence, so a future
   reader does not mistake the divergence for a regression.
3. **`relocFinalize` belongs in `reloc.s`, not a new `output.s` module.**
   The master plan's original file table proposed a separate `output.s`
   for "native PRG serialization," but `reloc.s` already owns every piece
   of state a footer write needs (`CasmRelocVmmSlot`, `CasmRelocCount`),
   and the routine's only new external dependencies are `fileWrite`
   (`fileio.s`) and `CasmRelocatableMode` (`emit.s`) -- both cheap,
   already-precedented imports. Introducing a new module for one routine
   would fragment state ownership rather than simplify it.
4. **The write mechanism chunks the table through the same 64-byte
   transfer window `reloc.s` already uses**, avoiding any new buffer:
   read up to `CASM_VMM_BUFFER_SIZE` bytes of the table into
   `CasmVmmBuffer` via `vmmWindowRead`, `fileWrite` that same chunk
   immediately, advance, and repeat until `CasmRelocCount * 2` bytes are
   written (at most 128 chunks for a full 4096-entry table). The 6-byte
   footer (base address, count, magic) is then staged into the same
   now-free `CasmVmmBuffer` and written with one final `fileWrite` call.
5. **The footer's magic bytes must be explicit hex (`$52`, `$36`), not a
   ca65 character literal.** This is raw binary file-format data that must
   match `tools/reloc.py`'s `MAGIC = b"R6"` exactly; relying on ca65's
   default charmap for `'R'`/`'6'` would risk PETSCII translation the same
   way this codebase already avoids for command-buffer/diagnostic bytes.
6. **No new diagnostic is needed.** Every failure mode `relocFinalize` can
   hit already has a correctly-shaped diagnostic that propagates
   unchanged: `vmmWindowRead` failure -> `CASM_DIAG_VMM_TRANSFER_FAILED`;
   `fileWrite` failure -> `CASM_DIAG_OUTPUT_WRITE_FAILED`/
   `CASM_DIAG_OUTPUT_SHORT_WRITE`. The master plan's "check output-size...
   overflow" is already covered by existing mechanisms (`CasmPcOverflow`
   for the program itself, WP40's `CASM_RELOC_MAX` cap for the table) --
   no new size check is needed for the footer itself, which is always
   exactly 6 bytes.
7. **No new cleanup logic is needed.** `relocFinalize` writes through the
   same `fileWrite` primitive and propagates failure through the same
   `bcs startFatalNear` -> `startFatal` -> `outputAbort` path every other
   Pass 2 failure already uses; a partial table/footer write left in a
   failed output file is deleted exactly like a partial program would be.
8. **Runtime relocation-loading verification (loading a generated R6
   fixture at several page-aligned addresses and confirming it still
   runs correctly) is explicitly WP42's job**, per WP37's own proposed
   breakdown ("WP42: ... Loads generated R6 fixtures at multiple
   page-aligned addresses per the master plan's literal gate text"). This
   WP's own verification proves the footer's *bytes* are structurally
   correct (via `COMP` against hand-derived references, matching every
   prior WP's verification style), not that the OS loader's `aptRelocate`
   correctly patches and runs the result -- that observability gap closes
   at WP42, not here.

## Contract to Freeze (amends Phase 0C.14)

1. New `reloc.s` export: `relocFinalize`. No-ops (`C` clear) immediately
   if `CasmRelocatableMode` is 0 (static assembly -- output stays exactly
   the plain PRG it is today). Otherwise: writes `CasmRelocCount * 2`
   bytes of table content in `<= 64`-byte chunks (`vmmWindowRead` then
   `fileWrite` per chunk, reusing `CasmVmmBuffer`), then stages and writes
   the 6-byte footer (`CASM_DEFAULT_ORIGIN` little-endian, `CasmRelocCount`
   little-endian, `$52 $36`) in one final `fileWrite` call.
2. `casm.s` calls `relocFinalize` unconditionally, immediately after
   `emitFinalize` succeeds and before `diagPrintPhase2Ready`, propagating
   failure through the existing `startFatalNear` trampoline.
3. `reloc.s` gains two new imports: `fileWrite` (`fileio.s`),
   `CasmRelocatableMode` (`emit.s`).
4. Five existing trusted-reference manifests are updated with their
   hand-derived footers (byte-for-byte, computed from each fixture's
   already-established program bytes and relocation-eligible operand
   positions):
   - `casmorg1.ref.hex`: 0 entries -- append `00 34 00 00 52 36` (6 bytes).
   - `casmnoorg1.ref.hex`: 1 entry (JMP TARGET's `VAL_HI` at program
     offset 2) -- append `02 00 00 34 01 00 52 36` (8 bytes).
   - `casmordhaz1.ref.hex`: identical to `casmnoorg1`'s updated footer
     (same program bytes, same single relocation offset) -- append the
     same 8 bytes, preserving the fixture's original byte-identity intent.
   - `casmrelop1.ref.hex`: 4 entries (offsets 2, 4, 8, 9 -- `MID`'s
     `VAL_HI`, `LDA #>DATA`'s extracted `VAL_LO`, `.WORD DATA`'s `VAL_HI`,
     `.BYTE >DATA`'s extracted `VAL_LO`) -- append `02 00 04 00 08 00 09
     00 00 34 04 00 52 36` (14 bytes).
   - `casmrelop2.ref.hex`: 2 entries (offsets 1, 3 -- `LDA >TARGET`'s
     extracted `VAL_LO`, `.WORD >TARGET`'s extracted `VAL_LO`) -- append
     `01 00 03 00 00 34 02 00 52 36` (10 bytes).
   `casmorgexpl1.ref.hex` is unchanged (static, no footer); its header
   comment is corrected to note the WP38-era equivalence to `casmorg1` was
   pre-R6 and no longer holds.
5. Runtime relocation-loading verification (multiple page-aligned load
   addresses) remains out of scope for this WP, per Dependency Review
   item 8.

## Scope

Included in WP41:

- `reloc.s`: `relocFinalize` and its two new imports.
- `casm.s`: the `relocFinalize` call site.
- Five existing `.ref.hex` manifests updated with hand-derived footers;
  `casmorgexpl1.ref.hex`'s stale equivalence comment corrected.
- Verification proving: static fixtures are still byte-identical
  (regression); every relocatable fixture's *new, larger* output matches
  its updated trusted reference exactly, including the table content, base
  address, count, and magic.

Excluded from WP41 (deferred to WP42 per the Phase 0C.14 breakdown):

- Loading a generated R6 fixture at a non-default page-aligned address and
  confirming it still runs correctly (the OS loader's `aptRelocate` side).
- Any new end-to-end fixture beyond what's needed to prove footer
  correctness for the shapes already established in WP38-WP40.

## Expected Files

| File | Action |
| --- | --- |
| `brain/plans/2026-07-25-casm-phase8-wp41-r6-footer-serialization.md` | this document |
| `src/external/casm/reloc.s` | `relocFinalize`, two new imports |
| `src/external/casm/casm.s` | `relocFinalize` call site, new import |
| `tests/fixtures/casm/casmorg1.ref.hex` | append footer |
| `tests/fixtures/casm/casmnoorg1.ref.hex` | append footer |
| `tests/fixtures/casm/casmordhaz1.ref.hex` | append footer |
| `tests/fixtures/casm/casmrelop1.ref.hex` | append footer |
| `tests/fixtures/casm/casmrelop2.ref.hex` | append footer |
| `tests/fixtures/casm/casmorgexpl1.ref.hex` | correct stale comment only |
| `wiki/tasks/casm.md`, `brain/task.md`, `brain/KNOWLEDGE.md` (Phase 0C.18), `CHANGELOG.md` | completion records |

## ABI, Storage, and Runtime Effects

- No new persistent state -- `relocFinalize` uses `reloc.s`'s existing
  `CasmRelocVmmSlot`/`CasmRelocCount` and `CasmVmmBuffer` (already shared,
  already scoped to one call at a time).
- Output file contract changes observably for relocatable-mode assemblies
  only: the PRG grows by `(CasmRelocCount * 2) + 6` bytes. Static output
  is byte-for-byte unchanged.
- MAIN size: not pre-sized; measured during implementation, a bump is
  plausible given 106 bytes of current headroom.

## Verification and Fixture Strategy

- Every existing static fixture (`casmemit1`, `casmhello`, `casmorgexpl1`,
  `casmbig1`, etc.) re-run unmodified and confirmed byte-identical --
  proves `relocFinalize`'s static no-op path is correct.
- Every relocatable fixture (`casmorg1`, `casmnoorg1`, `casmordhaz1`,
  `casmrelop1`, `casmrelop2`) re-run and compared via `COMP` against its
  *updated* trusted reference -- the first real end-to-end proof that
  WP39's classification and WP40's recording produced the *correct*
  offsets, not merely that assembly didn't crash (closing the
  observability gap both of those WPs explicitly deferred to this point).
- Manual field-by-field inspection of at least one generated R6 file
  (e.g. via a hex-dump or `DEBUG`) cross-checked against its trusted
  reference's own hand-derivation comments, confirming the base address,
  count, and magic land exactly where the master plan's contract says they
  should.

## Atomic Implementation Increments

1. `reloc.s`: implement `relocFinalize` and its two new imports.
2. `casm.s`: add the `relocFinalize` call site and import.
3. Update the five stale `.ref.hex` manifests with hand-derived footers;
   correct `casmorgexpl1.ref.hex`'s comment.
4. Build, measure MAIN headroom via `ld65 -m`, propose and apply any
   necessary size bump with the measured justification.
5. Re-run the full regression and relocatable-fixture matrix.
6. User runtime verification in the supported local emulator; record a
   walkthrough.
7. Version-only completion increment, no-change rebuild check, all three
   disk images, `brain/KNOWLEDGE.md` Phase 0C.18 entry, task/changelog
   updates, request completion approval.

## Failure and Cleanup

No new resource-ownership path (Dependency Review item 7); `relocFinalize`
reuses the existing `fileWrite`/`outputAbort` failure and cleanup shape
unchanged.

## Documentation and DOX Closeout

Update this plan's Progress section, `brain/KNOWLEDGE.md` (new Phase
0C.18 entry amending 0C.14-0C.17), `wiki/tasks/casm.md`, `brain/task.md`,
`CHANGELOG.md`, and Taskwarrior.

## Stop Conditions

Stop if CASM Phase 8 WP40 is not complete and approved. Stop if a hand-
derived footer for any of the five updated fixtures does not match
CASM's actual output during verification -- that would mean either this
plan's offset derivation or WP39/WP40's underlying classification/
recording has a real defect, and either requires amending this document
before proceeding, not silently adjusting the reference to match.

## Completion Gate

WP41 is complete when: every static fixture remains byte-identical; every
relocatable fixture's output matches its updated trusted reference exactly
(table, base address, count, and magic all correct); MAIN headroom is
measured and any necessary bump is justified and applied; the user
completes a runtime walkthrough; and the user explicitly approves
completion, together with the version-only increment and
`brain/KNOWLEDGE.md`/task/changelog updates.

## Progress

- 2026-07-25: Drafted after WP40's approval. Found, by checking the master
  plan's own gate text ("static fixtures remain ordinary PRGs") against
  every fixture built since WP38 rather than assuming only new fixtures
  were needed, that five existing trusted references
  (`casmorg1`/`casmnoorg1`/`casmordhaz1`/`casmrelop1`/`casmrelop2`) become
  stale the moment this WP lands and must be updated with hand-derived
  footers, not just left alone -- a real, easy-to-miss piece of scope.
  Also found that `casmorgexpl1.ref.hex`'s WP38-era claim of being
  "deliberately byte-identical" to `casmorg1.ref.hex` breaks by design
  once `casmorg1` gains a footer and `casmorgexpl1` (explicit `.ORG`,
  static) does not -- the correct, intended outcome, not a regression, but
  the stale comment needs correcting so a future reader does not mistake
  it for one. Confirmed `fileWrite`'s existing contract already supports
  writing from an arbitrary buffer (not tied to `CasmEmitBuffer`), so the
  footer write needs no new buffer beyond `reloc.s`'s own `CasmVmmBuffer`
  window. Scoped runtime relocation-loading verification (loading at a
  non-default page and confirming correct execution) explicitly to WP42,
  matching WP37's own original phase breakdown.
