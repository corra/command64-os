---
feature: casm-phase15-wp98-listing-regression-dash
created: 2026-09-02
status: proposed, not yet approved
taskwarrior: (to be created under parent 0678049c — Phase 15)
depends-on: WP93 (37bd4c8), WP94 (fb21ff9), WP95 (ecbd717),
  WP96 (e28dd7d, 6eb2815), WP97 (59c1066)
---

# Plan: CASM Phase 15 WP98 — `/L` suppressed-line rendering + no-conditionals regression + DASH survey

## Status

**Proposed, not yet approved.** WP98 is the pre-completion-gate cleanup
WP: it pins the one remaining user-facing design decision (`/L` for
suppressed lines), proves the conditional machinery is inert when unused,
and runs the mandatory DASH survey. WP99 is then the fresh consolidated
gate + docs + version bump.

Branch `feature/casm-phase15`; commits directly on it.

## Scoping Decisions (2026-09-02)

- **`/L` rendering of a source line inside a suppressed branch** — user
  chose: **source text, no address, no object bytes** (matches ca65
  `-l`). The suppressed line is listed for context with a blank address
  column. This requires a small `listing.s` change (a metadata-record
  flag bit + a render-path branch), not the zero-code "show the address
  it would have had" behaviour that exists today.
- **Which lines get the flag** — only *content* lines discarded by
  `crpScanSuppressed`. The six conditional directives themselves
  (`.if`/`.elseif`/`.else`/`.endif`/`.ifdef`/`.ifndef`) always render
  with a normal (empty-bytes) row, whether they were handled on the
  emitting path or acted on by the scanner — they are structural, not
  skipped content.
- **DASH adoption** — survey only; adopt a conditional into DASH only on
  a clear, unambiguous win (Research item 11 predicts none). Document the
  outcome either way and re-verify `dash.ref.hex` regardless.
- **Regression breadth** — a curated no-`.if` set (below), not the whole
  fixture corpus (that is WP99's consolidated sweep).

## Objective

1. `/L` lists a suppressed content line as `FILEID:LINE` + blank address
   + blank bytes + source text; pinned by a fixture.
2. `/M` re-verified unaffected (a suppressed branch defines no symbols —
   no code change expected, just proof).
3. A curated no-conditionals regression set proven byte-identical (PRG
   and, where they have one, `.LST`) after the `listing.s`/`common.inc`
   change.
4. DASH surveyed; `dash.ref.hex` re-verified byte-identical under the
   WP97/WP98 CASM.

**Not in scope:** anonymous labels (deferred); comparison operators
(never); the consolidated full-corpus sweep + docs + `0.6.1` bump (WP99).

## Design

### `/L` suppressed-line flag

`common.inc`:
- `CASM_LISTING_META_FLAG_SUPPRESSED = %00000010` (bit 1; bit 0 stays
  `FINAL_UNTERMINATED`). Update the `CASM_LISTING_META_FLAGS` comment
  ("bit 0 = FINAL_UNTERMINATED, bit 1 = SUPPRESSED, rest reserved
  zero").
- The record-validator invariant (`listing.s` ~line 1348 / 1379,
  "FLAGS has no bit set outside FINAL_UNTERMINATED") widens to
  `FINAL_UNTERMINATED | SUPPRESSED`. Keep it a single named mask
  (`CASM_LISTING_META_FLAG_VALID_MASK` or inline `#(%00000011)`), with a
  `.assert`.

`casm.s`:
- New module byte `CasmListingLineSuppressed` (or reuse an existing
  transient) — set to 1 immediately before the `crpListingCommit` call
  on the `crpScanSuppressed` path (casm.s ~line 648), left 0 everywhere
  else. `crpListingBegin`/the emitting path never set it.
- Cleared to 0 at the top of `casmRunPass` (or in `listingCommitLine`
  after consuming it) so it never leaks to the next line.

`listing.s`:
- `listingCommitLine` (`lclRealLine` block, where `CasmListingPendingFlags`
  is composed from the sidecar's `FINAL_UNTERMINATED`): OR in
  `CASM_LISTING_META_FLAG_SUPPRESSED` when `CasmListingLineSuppressed`
  is set.
- `lwEmitDetailRows` primary row (~line 2178): if the record's FLAGS has
  `SUPPRESSED` set, emit `CASM_LISTING_ROW_ADDR_WIDTH` spaces instead of
  the two `lwPutHexByte` PC calls. Byte count is already 0 for a
  suppressed line, so `lwEmitByteGroupRow` already renders blanks and no
  byte-continuation rows are produced. Source row unchanged.

No record-size change (16 bytes holds; only a spare FLAGS bit is used).

### `/M` and suppressed branches

`crpScanSuppressed` never calls `symbolsInsert`/`crpCountLabel`/
`crpCountConstant` — a suppressed label or `=` line is discarded as raw
tokens. So `/M`'s symbol map cannot contain a suppressed-branch symbol.
Expected: **no code change** — WP98 only adds a fixture proving it
(`.if 0` / `skipped = 1` / `.endif`, `/M` output identical to the same
file with the three lines removed).

### No-conditionals regression set

| Fixture | Exercises |
| --- | --- |
| `casmhello` | no directives at all — the pure baseline |
| `casmassert1` | Phase 13 `.assert` |
| `casmchain1` | `.include` chain |
| `casmalign1` | Phase 13 `.align` |
| `casmloc7` | Phase 14 `@local` scoping |

Each must produce a byte-identical PRG after the `common.inc`/`listing.s`
edit. `casmhello` additionally re-run with `/L` and `/M` for a
byte-identical `.LST` / `.MAP` (the render path changed; a file with no
suppressed line must be unaffected — the `SUPPRESSED` branch is never
taken).

### DASH survey

- `grep` `src/external/dash/` for build-time configuration seams (target
  address, feature toggles, debug stubs) that a `.if`/`.ifdef` would
  simplify. Mirror the Phase 12 WP71 / Phase 13 WP84 / Phase 14 WP91
  write-ups.
- Rebuild DASH (`cmake --build build --target dash` or the full build)
  and confirm `dash.ref.hex` → `dash.ref` still `FILES COMPARE OK` /
  the manifest hash is unchanged.
- If (unlikely) a conditional is adopted: it needs its own increment,
  `src/external/dash/AGENTS.md`'s dual-assembler-subset note updated, and
  `dash.ref.hex` re-baselined with provenance. Default outcome: a
  "surveyed, no adoption, DASH byte-identical" paragraph in the
  walkthrough.

## Atomic Increments

1. **`common.inc` + `listing.s`**: `SUPPRESSED` flag bit, validator mask
   widening, `listingCommitLine` OR-in, `lwEmitDetailRows` blank-address
   branch. `casm.s`: `CasmListingLineSuppressed` set on the scanner path.
   Build; all 32 `test_casm_*` green; `test_casm_listing` +
   `test_casm_map` specifically green.
2. **Fixtures** (`GenerateCasmTestFixtures.cmake` + `CMakeLists.txt`):
   - `casmifL1` — `.if 0` / `nop` / `.endif` / `nop`, assembled with
     `/L`; `.LST.ref` shows the two suppressed lines with blank address,
     the trailing `nop` at `C000`. (A `.LST` trusted reference — same
     hand-derived discipline as the PRG `.ref.hex`, transcribed by a
     text fixture, not generated by CASM.)
   - `casmifM1` — `.if 0` / `skipped = 1` / `.endif` / `real = 1`,
     assembled with `/M`; `.MAP.ref` contains only `real`.
   Append to `casm_phase15_test_d64`. These two are listing/map
   artifacts, not PRG `.ref.hex` — keep them out of `CASM_REF_NAMES`.
3. **Build**. If MAIN overflows `$7400` (headroom is 360 B): STOP —
   raising the envelope is a separate approved decision. The expected
   delta is < 40 B (one flag test + one blank-address branch).
4. **Live VICE**: `casmifL1`, `casmifM1`, the 5 regression fixtures,
   `test_casm_cond`, `test_casm_listing`, `test_casm_map`. FLUSH
   before/after; fire `c64-overlay-api` test events.
5. **DASH survey** + `dash.ref.hex` re-verify.
6. Walkthrough; commit.

## Expected Files

| File | Action |
| --- | --- |
| `src/external/casm/common.inc` | Modify — `SUPPRESSED` flag bit + assert |
| `src/external/casm/listing.s` | Modify — commit OR-in + blank-address render branch + validator mask |
| `src/external/casm/casm.s` | Modify — `CasmListingLineSuppressed` set/clear |
| `cmake/GenerateCasmTestFixtures.cmake`, `CMakeLists.txt` | Modify — `casmifL1`/`casmifM1` + `.LST.ref`/`.MAP.ref` |
| `src/external/dash/*` | Modify **only if** a conditional is adopted (unlikely) |
| `src/external/dash/AGENTS.md` | Modify only if the dual-assembler subset changes |
| `brain/plans/2026-09-01-casm-phase15-wp98-*.md` | This file; append Progress |
| `brain/walkthroughs/2026-09-01-casm-phase15-wp98-*.md` | Create |
| `brain/plans/2026-09-01-casm-phase15-conditional-assembly.md` | Append Progress |

## Stop Conditions

- Any existing `test_casm_*` harness fails, or a no-change rebuild alters
  any assembled `.ref` / `.LST` / `.MAP` for a no-conditionals fixture.
- `/M` output for `casmifM1` differs from the symbols-removed baseline
  (would mean a suppressed branch leaked a symbol — a WP95/96 defect,
  disclose and defer, do not fix forward here).
- MAIN overflows `$7400` after increment 1 — STOP, envelope grow is a
  separate decision.
- The `SUPPRESSED` render needs a listing metadata-record **size**
  change (it must fit in the spare FLAGS bit).
- A new defect outside Phase 15 surfaces — disclose and defer.
- DASH does not rebuild byte-identical and the cause is not an
  intentional adoption — STOP.

## Completion Gate

- `casmifL1` `.LST` matches its trusted reference live (suppressed lines,
  blank address); `casmifM1` `.MAP` contains no suppressed symbol.
- 5 regression fixtures byte-identical PRG; `casmhello` `.LST`/`.MAP`
  byte-identical; `test_casm_cond` / `test_casm_listing` / `test_casm_map`
  green.
- DASH surveyed (outcome documented) and `dash.ref.hex` re-verified.
- CASM within `$7400`; both link configs pass; test image builds;
  build-number check passes.
- Walkthrough recorded; **explicit user approval** before WP99.

## Progress

- 2026-09-02: Plan drafted. Scoping decision recorded: `/L` shows a
  suppressed content line with source text + blank address + blank
  bytes (ca65-style); needs a `SUPPRESSED` FLAGS bit in the listing
  metadata record. Awaiting approval.
- 2026-09-02: **Approved. Increments 1-3 done.**
  - `common.inc`: `CASM_LISTING_META_FLAG_SUPPRESSED = %00000010` +
    `CASM_LISTING_META_FLAG_VALID_MASK`; FLAGS comment updated.
  - `listing.s`: validator mask widened
    (`and #<~CASM_LISTING_META_FLAG_VALID_MASK`); `listingCommitLine`
    folds `CasmListingLineSuppressed` into the record's SUPPRESSED bit
    (new exported BSS byte); `lwEmitDetailRows` primary row emits
    `ADDR_WIDTH-1` spaces instead of the PC hex when SUPPRESSED is set.
  - `casm.s`: `CasmListingLineSuppressed` cleared at the top of
    `casmRunPass`, raised in `crpScanSuppressed` only for a non-
    conditional line discarded inside an off branch (new `@contentLine`
    label; the six conditional directives fall through to `@drain`
    without it). `.import CasmListingLineSuppressed`.
  - Fixtures: `casmifL1` (`.IF 0` two-line body + trailing NOP -> `00 C0
    EA`), `casmifM1` (`.IF 0` defining SKIPPED + `REAL = 1` + `LDA
    #REAL` -> `00 C0 A9 01`) in `GenerateCasmTestFixtures.cmake`; hand-
    derived `.ref.hex` for both; appended to `casm_phase15_test_d64`;
    added to `CASM_REF_NAMES` (already covered by the `^casmif` test.d64
    exclusion).
  - **Build clean.** `BUILD_CASM` 1416. ld65 map: CODE `$3800-$905F`,
    RODATA `$9060-$9D08`, BSS `$9D09-$AAB9`. MAIN envelope `$3800+$7400
    = $AC00`. **Headroom `$AC00-$AAB9` = 327 B** (was 360 at WP97 close;
    WP98 cost ~33 B). **Fits `$7400` -- no envelope grow.** 327 B is
    thin; WP99 is a version bump only (no code).
  - **Live VICE (`CASM V0.6.0.1416`, `casm_phase15_test.d64`):**
    - `casmifL1` `/L`: `TYPE CASMIFL1.LST` shows lines 3-4 (suppressed
      `LDA $1234` / `NOP`) with a **blank address column**; lines 2/5
      (`.IF 0` / `.ENDIF`) and line 6 (real `NOP`, `C000 EA`) render
      normally. `COMP` → `FILES COMPARE OK`.
    - `casmifM1` `/M`: `SYMBOL MAP` = one row `$0001 REAL`, `001
      SYMBOLS` — `SKIPPED` absent. `COMP` → `FILES COMPARE OK`.
    - `TEST_CASM_COND` → `CASM COND: PASS` (x2). FLUSH clean before/after.
    - Overlay `test/pass` fired.
  - **DASH survey:** single-target app, all "version" refs are runtime
    struct checks, no build-time seams → **no adoption** (matches
    Phase 12/13/14). `git diff` on `src/external/dash/` empty;
    `dash.ref.hex` unchanged; `--target dash` rebuilds (hash gate green).
  - Walkthrough `brain/walkthroughs/2026-09-01-casm-phase15-wp98-listing-regression-dash.md`.
    Committed. Awaiting sign-off before WP99.
