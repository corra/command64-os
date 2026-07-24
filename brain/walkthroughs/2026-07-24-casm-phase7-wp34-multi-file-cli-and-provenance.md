---
feature: casm-phase7-wp34-multi-file-cli-and-provenance
created: 2026-07-24
status: complete
---

# Walkthrough: CASM Phase 7 WP34 Multi-File CLI and File-Boundary Provenance

Plan: `brain/plans/2026-07-24-casm-phase7-wp34-multi-file-cli-and-provenance.md`

Taskwarrior: `7fedccb3-8464-4b4d-a49e-2ac200e99dd4` (WP34); part of the CASM
Phase 7 milestone `1a0d0dc8-3267-4885-aa83-adf923d56422`.

## Outcome

WP34 implemented Contract items 4, 6, and 7 of the Phase 0C.10 freeze: CASM
now accepts up to 8 ordered top-level source filenames on one command line,
all loaded into one combined VMM stream before Pass 1 begins
(`sourceLoad`, generalized from WP33's single-file loop), with file
identity and per-file line numbering correctly reset at each file boundary
during traversal (`sourceRefill`). Diagnostic filename printing remains
WP35's job -- this WP only needed `CasmSourceFileId`/line/column to be
*correct* across boundaries, not yet *visible* in a diagnostic.

Per the user's confirmed decision, the pending-CR newline latch now clears
unconditionally at every file-boundary transition, closing a real
correctness hazard found during planning: a file ending in a bare CR
immediately followed by a file starting with LF could otherwise
phantom-collapse across the boundary.

## Baseline

| Item | Value |
| --- | --- |
| Branch | `feature/casm-phase7-wp34` |
| Branch point | `feature/casm-phase7-wp33` at `73af6e8` |
| Baseline version | `0.1.35` build 1137 |
| Plan approval | Approved as drafted, including the confirmed pending-CR-clear decision |

## Implementation

- `common.inc`: `CASM_SOURCE_COUNT_MAX = 8`.
- `cli.s`: `CasmSourceNames` (8 x 64 bytes), `CasmSourceLens` (8 bytes),
  `CasmSourceCount` replacing the single `CasmSourceName`/`CasmSourceLen`
  pair. `cliCopySource` writes through a new compile-time slot-address
  lookup table (`cliSourceSlotLo/Hi`, exported for `source.s` to reuse)
  rather than a runtime multiply -- `CASM_FILENAME_BUFFER_SIZE` (64) does
  not divide evenly into 256. The indirect write itself needed care: `Y`
  is the established `CommandBuffer` cursor throughout `cli.s`'s call
  chain and cannot also serve as the `(zp),Y` destination index, so the
  destination pointer advances one byte at a time (`Y` fixed at 0 per
  store) with the real `Y` stashed around each store via
  `CasmCliDestIndex` (a previously-declared, never-used scratch alias).
  `cliDeriveOutputName` derives from slot 0 only, keeping its existing
  column-scanning algorithm unchanged in shape.
- `fileio.s`: `inputStreamOpen` generalized from a hardcoded single
  `CasmSourceName` pointer to a caller-supplied X/Y pointer, matching
  `fileOpenInput`'s own convention -- its sole caller, `sourceLoad`,
  already needed to select a different file each loop iteration.
- `source.s`: `sourceLoad` became an outer loop over
  `CasmSourceLoadIndex = 0 .. CasmSourceCount - 1`, wrapping WP33's
  per-file inner logic unchanged; a new 16-byte `CasmSourceFileTable`
  records each file's start offset only (a file's end is implicitly the
  next file's start, or the grand total for the last file); a new
  `slCheckCap` enforces the combined 65535-byte cap explicitly (not free
  once more than one file exists); a synthetic LF is inserted between
  files whose last written byte was not already CR or LF (never after the
  last file); a new `slVmmWrite` helper factors the "stage cursor, call
  vmmWindowWrite, check failure, advance cursor" sequence shared by the
  main chunk loop and the synthetic-newline write. `sourceRefill` gained
  `srCheckFileBoundary` (checked at the top of every call) and a 3-way
  `min` in `srComputeRemaining` (via a new shared `srMin` helper) that
  additionally caps each refill's transfer at the next file boundary, so
  a single installed block never spans two files.
- `tests/src/casm_pass1/casm_pass1.s` and
  `tests/src/casm_passcheck/casm_passcheck.s`: both gained their own
  stand-in copies of `CasmSourceNames`/`CasmSourceCount`/
  `cliSourceSlotLo/Hi` (neither links `cli.s`) -- caught during
  implementation before it became a link failure.
- `cmake/GenerateCasmTestFixtures.cmake` / `CMakeLists.txt`: six new
  fixtures (`casmmf1`/`casmmf2`/`casmmf3` byte-identical multi-file
  references, `casmmfcr1`/`casmmfcr2` cross-file pending-CR regression,
  `casmmfovf1`/`casmmfovf2` combined-overflow boundary); MAIN bumped
  `$3200` -> `$3500` (`casm`), `$3300`/`$3200` -> `$3500`
  (`casm_pass1`/`casm_passcheck`).
- `AGENTS.md`: corrected the stale "Phase 2 accepts one unquoted source
  filename" contract to describe the WP34 multi-file grammar.

## A Mid-Implementation Discrepancy: Disk Space

The combined-overflow fixtures (`casmmfovf1.seq`/`casmmfovf2.seq`,
40000/30000 bytes -- the real 65535-byte cap cannot be exercised with less
content) do not fit on the shared `test.d64`, which was already full with
every other CASM/OS fixture. Presented to the user with two options: drop
the packaged fixture (verify the check by code review only, matching
WP27's symbol-table-full precedent), or build a dedicated disk image just
for this test. The user chose the dedicated disk: a new
`casm_overflow_test_d64` CMake target (`casm.prg` plus the two oversized
fixtures only, ~330 blocks free after packaging) rather than either
dropping the fixture or restructuring `test.d64`'s packaging.

## Static Verification

- `casm` build 1138 (implementation) -> 1139 (version-only completion
  increment), no-change rebuild stable at each step.
- `image_d64`, `test_image_d64`, and the new `casm_overflow_test_d64` all
  build clean.
- MAIN measured via `ld65 -m`: CODE `$2311` (8977) + RODATA `$091C` (2332)
  + BSS `$7CE` (1998) = 13307 of 13568 bytes -- 261 bytes headroom.
- All three new `.ref.hex` manifests (`casmmf1`, `casmmf2`, `casmmf3`)
  self-validated against `hex_manifest_to_bin.py` before wiring in; all
  new `.seq` fixtures' byte counts confirmed via `wc -c` against their
  intended exact lengths.

## Runtime Verification

The user ran the full verification matrix across two sessions:

**Standalone harnesses (regression):**

| Harness | Result |
| --- | --- |
| `TEST_CASM_PASS1` | pass, all 7 sub-fixtures |
| `TEST_CASM_PASSCHECK` | pass |

**Pre-existing byte-identical trusted references (12, unaffected
single-file path):**

| Reference | Result |
| --- | --- |
| `casmemit1` / `casmhello` / `casmmodes` / `casmnum2` / `casmexprn` | identical |
| `p1fwd1` / `p1back1` / `p1size1` | identical |
| `brfwd1` / `brback1` | identical |
| `casmcase1` / `casmmaxid1` | identical |

**New multi-file byte-identical trusted references:**

| Reference | Proves | Result |
| --- | --- | --- |
| `casmmf1` (`CASMMFA.S CASMMFB.S`) | cross-file forward symbol resolution, no synthetic newline needed | identical |
| `casmmf2` (`CASMMFC.S CASMMFD.S`) | synthetic inter-file newline insertion (file C has no trailing newline) | identical |
| `casmmf3` (`CASMMFE.S CASMMFF.S CASMMFG.S`) | the file loop generalizes past exactly two files | identical |

**Diagnostic fixtures:**

| Fixture | Result |
| --- | --- |
| `casmmfcr1`/`casmmfcr2` (cross-file pending-CR) | `INVALID SOURCE BYTE AT LINE 2, COL 1` -- confirms the pending-CR latch did not leak across the file boundary |
| 9th source file (`CASM A B C D E F G H I`) | `CASM: TOO MANY SOURCE FILES` |
| `casmmfovf1`/`casmmfovf2` (combined overflow, `casm_overflow_test.d64`) | `CASM: SOURCE OFFSET OVERFLOW`, no location trailer |

The user confirmed: "all test pass."

## Documentation and DOX Closeout

- `brain/KNOWLEDGE.md`: Phase 0C.12 as-built section added, amending Phase
  0C.10/0C.11 with the exact implemented shape.
- `AGENTS.md`: stale single-source-filename contract corrected.
- `wiki/tasks/casm.md`: WP34 checked complete; Phase 7 Acceptance updated
  (3 of 4 items now checked; diagnostic filename reporting remains WP35's).
- `brain/task.md`: WP34 entry added and closed.
- `CHANGELOG.md`: Unreleased entry added.
- Taskwarrior: WP34 (`7fedccb3-8464-4b4d-a49e-2ac200e99dd4`) completed.

## Completion

**CASM Phase 7 WP34 is complete**, per the completion gate in
`brain/plans/2026-07-24-casm-phase7-wp34-multi-file-cli-and-provenance.md`:
the full verification matrix passed, MAIN headroom is measured and
justified, `AGENTS.md`'s contract is corrected, a no-change rebuild holds
`BUILD_CASM` stable, all three disk images build clean, and the user
confirmed the runtime results. WP35 (diagnostic filename integration)
remains separately gated and unstarted per `AGENTS.md`.
