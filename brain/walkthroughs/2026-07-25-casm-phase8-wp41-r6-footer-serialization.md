---
feature: casm-phase8-wp41-r6-footer-serialization
created: 2026-07-25
status: complete
---

# Walkthrough: CASM Phase 8 WP41 Native R6 Footer Serialization

Plan: `brain/plans/2026-07-25-casm-phase8-wp41-r6-footer-serialization.md`

Taskwarrior: `005c8fec-684d-4f0d-a171-c7519081bef2` (WP41); part of the CASM
Phase 8 milestone.

## Outcome

WP41 implemented Phase 0C.14 Contract items 5-6: `relocFinalize` appends
WP40's accumulated relocation table, then a 6-byte R6 footer (base address,
entry count, `"R6"` magic), to the output file immediately after
`emitFinalize` succeeds -- gated entirely on `CasmRelocatableMode`, so
static output (an explicit `.ORG`) stays exactly the plain PRG it always
was. This is the WP that makes the relocation table observable for the
first time: WP39 and WP40 both had to defer their own end-to-end proof to
"once the footer exists"; that gap closes here. Implementation matched the
plan closely, with no material deviations.

Two real pre-existing defects were found and fixed during this WP's own
verification, both the same bug class: a standalone test harness that
allocates VMM storage but never calls `resourcesCleanup` before `DOS_EXIT`,
leaking the allocation permanently at the OS/REU tracking level (not just
the harness's own 8-slot registry, which a fresh `DOS_EXIT` does not
implicitly release). `test_casm_reloc.s` (new in WP40) had this defect from
its introduction; `test_casm_symbols.s` (WP27) had it independently and far
longer. Both are fixed as part of this WP's closeout -- see Drive-By Fixes.

## Baseline

| Item | Value |
| --- | --- |
| Branch | `feature/casm-phase8-wp41` |
| Branch point | `feature/casm-phase8-wp40` at `15d2d35` |
| Baseline version | `0.1.42` build 1154 |
| Plan approval | Approved as drafted |

## Implementation

- `common.inc`: `CASM_R6_MAGIC_0 = $52` / `CASM_R6_MAGIC_1 = $36`, explicit
  hex rather than ca65 character literals, matching `tools/reloc.py`'s
  `MAGIC = b"R6"` exactly without depending on this file's charmap.
- `reloc.s`: new export `relocFinalize`. No-ops (`C` clear) immediately if
  `CasmRelocatableMode` is 0. Otherwise loops copying `CasmRelocCount * 2`
  bytes from VMM to the output file in `<= 64`-byte chunks (`vmmWindowRead`
  then an immediate `fileWrite` per chunk, reusing the existing
  `CasmVmmBuffer` transfer window -- no new buffer), then stages and writes
  the 6-byte footer (`CASM_DEFAULT_ORIGIN` little-endian, `CasmRelocCount`
  little-endian, the two magic bytes) in one final `fileWrite` call. Two
  new imports: `fileWrite` (`fileio.s`), `CasmRelocatableMode` (`emit.s`).
- `casm.s`: `relocFinalize` called unconditionally immediately after
  `emitFinalize` succeeds and before `diagPrintPhase2Ready`, propagating
  failure through the existing `startFatalNear` trampoline -- no new
  failure/cleanup path (Dependency Review item 7 of the plan).
- Five existing trusted-reference manifests updated with hand-derived
  footers (`tests/fixtures/casm/`): `casmorg1.ref.hex` (0 entries, `00 34
  00 00 52 36`), `casmnoorg1.ref.hex` and `casmordhaz1.ref.hex` (1 entry
  each, byte-identical footers, preserving their original
  byte-identity intent), `casmrelop1.ref.hex` (4 entries), `casmrelop2.ref.hex`
  (2 entries). `casmorgexpl1.ref.hex` is unchanged (static, no footer); its
  header comment corrected to note its WP38-era "byte-identical to
  casmorg1" claim was pre-R6 only, and the divergence after this WP is the
  intended outcome of R6 relocation existing at all, not a regression.
- MAIN size bump: `$3600` -> `$3700` (103 bytes measured overflow from
  `relocFinalize` and its imports; 153 bytes headroom at the new size, the
  smallest round-page step above the overflow, matching every prior
  phase's precedent). `test_casm_pass1`/`test_casm_passcheck` (which link
  `reloc.s` whole) bumped identically.
- `tests/src/casm_reloc/casm_reloc.s`: added stand-in `CasmRelocatableMode`
  BSS byte and a stub `fileWrite`, exported, to satisfy `relocFinalize`'s
  two new imports at link time -- unreachable from this harness's own
  fixtures (none call `relocFinalize`; the real proof of its correctness
  is the end-to-end fixture matrix, since it needs a real open output
  file).

## Drive-By Fixes: Two VMM-Leak Defects Found During Verification

The user's first verification pass reported `test_casm_pass1` failing all
7 fixtures with `"fffffff"` while every other test passed. The symptom
matched this codebase's own historical pattern for VMM/REU registry
exhaustion (WP33). Tracing found `test_casm_reloc.s` (introduced in WP40,
carried unmodified into this WP until now) never called `resourcesCleanup`
before `DOS_EXIT`, unlike every other standalone harness's established
alloc-then-free-within-one-fixture or free-before-exit pattern. Its two
VMM allocations (`relocinit1`'s, shared by `relocrecord1`/`relocmeasure1`,
and `relocfull1`'s own separate one) leaked permanently at the OS/REU
tracking level on every run, exhausting capacity for whatever test ran
next in the same VICE session. Fixed by adding a `resourcesCleanup` call
before the final PASS/FAIL print and `DOS_EXIT`.

Auditing every other standalone harness for the same defect class found
`test_casm_symbols.s` (WP27, unrelated to this WP's own scope) has the
identical gap: `syminit1`'s `symbolsInit` call allocates the symbol
table's VMM storage via `vmmStoreAlloc`, and the harness never freed it
before `DOS_EXIT` either. Fixed identically (`resourcesCleanup` added
before exit), since it is the same well-precedented one-line fix and
leaving a known, freshly-discovered leak in place would just reproduce the
same confusing "unrelated next test fails" symptom later. `test_casm_vmm.s`
(explicit `vmmStoreFree` within each fixture) and `test_casm_expr.s` (no
VMM allocation at all) were confirmed already safe.

## Static Verification

- `casm` build 1154 (baseline) -> 1156 (implementation, version-only
  increment applied together since no separate pre-completion candidate
  build was requested) -- no-change rebuild confirmed stable at 1156.
- `image_d64`, `test_image_d64`, and `casm_overflow_test_d64` all build
  clean.
- MAIN measured via `ld65 -m`: CODE `$254E` (9550) + RODATA `$93F` (2367)
  + BSS `$7DA` (2010) = 13927 of 14080 bytes -- **153 bytes headroom**.
- `hex_manifest_to_bin.py` independently recomputed and confirmed byte
  count and SHA-256 for all five updated references before any runtime
  test: `casmorg1` 10 bytes, `casmnoorg1`/`casmordhaz1` 14 bytes each
  (identical hash), `casmrelop1` 27 bytes, `casmrelop2` 18 bytes.
- `test_casm_reloc` and `test_casm_symbols` rebuilt after their respective
  `resourcesCleanup` fixes; both link and build clean.

## Runtime Verification

The user ran the full verification matrix across two passes (the second
after the two VMM-leak fixes) and confirmed: "all tests pass."

| Check | Result |
| --- | --- |
| `TEST_CASM_RELOC` (post-fix) | pass |
| `TEST_CASM_SYMBOLS` (post-fix) | pass |
| `TEST_CASM_PASS1` (originally failing all 7 fixtures) | pass |
| `TEST_CASM_PASSCHECK` | pass |
| `CASM CASMORG1` / `COMP CASMORG1.PRG CASMORG1.REF` (new footer) | pass |
| `CASM CASMNOORG1` / `COMP CASMNOORG1.PRG CASMNOORG1.REF` (new footer) | pass |
| `CASM CASMORDHAZ1` / `COMP CASMORDHAZ1.PRG CASMORDHAZ1.REF` (new footer) | pass |
| `CASM CASMRELOP1` / `COMP CASMRELOP1.PRG CASMRELOP1.REF` (new footer) | pass |
| `CASM CASMRELOP2` / `COMP CASMRELOP2.PRG CASMRELOP2.REF` (new footer) | pass |
| `CASM CASMORGEXPL1` / `COMP CASMORGEXPL1.PRG CASMORGEXPL1.REF` (static regression) | pass |
| `CASM CASMEMIT1` / `COMP CASMEMIT1.PRG CASMEMIT1.REF` (static regression) | pass |
| `CASM CASMHELLO` / `RUN` (static regression) | pass |
| `TEST_CASM_EXPR` | pass |
| `TEST_CASM_VMM` | pass |

## Documentation and DOX Closeout

- `brain/KNOWLEDGE.md`: Phase 0C.18 as-built section added, amending Phase
  0C.14-0C.17 with the exact implemented mechanism and the two drive-by
  fixes.
- `wiki/tasks/casm.md`: WP41 checked complete.
- `brain/task.md`: WP41 entry added and closed.
- `CHANGELOG.md`: Unreleased entry added.
- Taskwarrior: WP41 (`005c8fec-684d-4f0d-a171-c7519081bef2`) completed;
  WP42 unblocked.

## Completion

**CASM Phase 8 WP41 is complete**, per the completion gate in
`brain/plans/2026-07-25-casm-phase8-wp41-r6-footer-serialization.md`:
every static fixture remains byte-identical, every relocatable fixture's
output matches its updated trusted reference exactly (table, base
address, count, and magic all correct), MAIN headroom is measured (153/
14080, size bumped to `$3700`), a no-change rebuild holds `BUILD_CASM`
stable, all three disk images build clean, two real VMM-leak defects found
during verification are fixed and confirmed, and the user confirmed the
runtime results. Final CASM `0.1.43` build 1156. WP42 (verification,
walkthrough, and Phase 8 completion gate) remains separately gated and
unstarted per `AGENTS.md`.
