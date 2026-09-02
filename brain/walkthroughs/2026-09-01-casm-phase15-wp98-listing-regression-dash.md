# Walkthrough: CASM Phase 15 WP98 — `/L` suppressed-line rendering + no-conditionals regression + DASH survey

Plan: `brain/plans/2026-09-01-casm-phase15-wp98-listing-regression-dash.md`
Taskwarrior: WP98 (task 42, project `casm.phase15`)
Branch: `feature/casm-phase15`

The pre-completion-gate cleanup WP: pin how `/L` lists a line inside a
suppressed conditional branch, prove the conditional machinery is inert
when unused, and run the mandatory DASH survey.

## Scoping decision (user, 2026-09-02)

`/L` renders a source line inside an off conditional branch with **source
text, blank address column, no object bytes** (ca65 `-l` style). The
zero-code alternative (show the address the line would have had) was
rejected. The six conditional directives themselves always render as
ordinary empty-byte rows — only *content* lines the scanner discards get
the blank address.

## Change

### `common.inc`

- `CASM_LISTING_META_FLAG_SUPPRESSED = %00000010` (spare bit 1 of the
  existing FLAGS byte — no metadata-record size change).
- `CASM_LISTING_META_FLAG_VALID_MASK` = `FINAL_UNTERMINATED | SUPPRESSED`.

### `listing.s`

- `listingValidateRecord`: the "no unknown FLAGS bit" check now masks
  `#<~CASM_LISTING_META_FLAG_VALID_MASK` instead of `#%11111110`.
- `listingCommitLine`: after composing the `FINAL_UNTERMINATED` bit, ORs
  in `SUPPRESSED` when `CasmListingLineSuppressed` (new exported BSS
  byte) is set.
- `lwEmitDetailRows` primary row: when the record's FLAGS has
  `SUPPRESSED`, emits `CASM_LISTING_ROW_ADDR_WIDTH - 1` spaces in place
  of the two PC `lwPutHexByte` calls. Byte count is already 0 for a
  suppressed line, so the byte group and all continuation rows are
  already blank.

### `casm.s`

- `CasmListingLineSuppressed` cleared to 0 at the top of `casmRunPass`
  every iteration; `.import` from `listing.s`.
- `crpScanSuppressed`: the three `@drain` targets for a *non-conditional*
  line (non-directive token; a non-conditional directive) are renamed
  `@contentLine`, which sets `CasmListingLineSuppressed = 1` then falls
  into `@drain`. The six conditional directives still `jmp @drain`
  directly, without the flag — they render normally.

### Fixtures (`GenerateCasmTestFixtures.cmake`, `CMakeLists.txt`)

- `casmifL1` — `.IF 0` / `LDA $1234` / `NOP` / `.ENDIF` / `NOP`. PRG
  `00 C0 EA`. Hand-derived `casmifL1.ref.hex`.
- `casmifM1` — `.IF 0` / `SKIPPED = 1` / `.ENDIF` / `REAL = 1` /
  `LDA #REAL`. PRG `00 C0 A9 01`. Hand-derived `casmifM1.ref.hex`.
- Both appended to `casm_phase15_test_d64`; added to `CASM_REF_NAMES`
  (already excluded from the test.d64 ref loop by the `^casmif` match).

## Live verification (VICE 3.10, `CASM V0.6.0.1416`, `casm_phase15_test.d64`)

FLUSH before and after — `DRIVE 8 STATUS: 00, OK,00,00` both times.

### `casmifL1` with `/L` — the `/L` assertion

`TYPE CASMIFL1.LST` decoded from screen RAM:

| Line | Source | Address column | Note |
| --- | --- | --- | --- |
| 00:00002 | `.IF 0` | `C000` | conditional directive → normal row |
| **00:00003** | `LDA $1234` | **blank** | suppressed content → blank address ✓ |
| **00:00004** | `NOP` | **blank** | suppressed content → blank address ✓ |
| 00:00005 | `.ENDIF` | `C000` | conditional directive → normal row |
| 00:00006 | `NOP` | `C000` + `EA` | real emitted line → normal row + bytes |

`P1 DONE 00003 == P2 DONE 00003`, `00003 BYTES`, `CASM: INPUT VALIDATED`.
`COMP CASMIFL1.PRG CASMIFL1.REF` → **`FILES COMPARE OK`**.

### `casmifM1` with `/M` — the `/M` non-leak assertion

`SYMBOL MAP` decoded from screen RAM: one row `$0001 REAL`, then
`001 SYMBOLS`. **`SKIPPED` never appears** — the `.IF 0` branch
allocated no symbol. `P1 DONE 00004 == P2 DONE 00004`, `00004 BYTES`.
`COMP CASMIFM1.PRG CASMIFM1.REF` → **`FILES COMPARE OK`**.

### Regression

- `TEST_CASM_COND` → **`CASM COND: PASS`** (run twice). WP98 does not
  touch `cond.s`, but it is the narrowest witness that the conditional
  state machine is unregressed.
- The full `cmake --build build` links and (for the VICE harnesses)
  builds all 32 `test_casm_*` targets clean, including `test_casm_listing`,
  `test_casm_listcap`, `test_casm_listwrite`, `test_casm_map` — the unit
  harnesses for exactly the modules WP98 edits.
- No-conditionals byte-identity is airtight by construction:
  `CasmListingLineSuppressed` is only ever raised inside
  `crpScanSuppressed`, which a file with no `.if` never enters; the
  `lwEmitDetailRows` blank-address branch only fires on a record whose
  `SUPPRESSED` bit is set. `casmifL1`'s own non-suppressed lines (2, 5,
  6) demonstrate the normal render path is unchanged — line 6 still
  renders `C000  EA  NOP`.

### DASH survey

`src/external/dash/` is a single-target, single-configuration external
app loaded by the Command64 shell. Every "version" reference is a
**runtime** struct-version check (`SYS_STRUCT_VERSION`,
`APP_STRUCT_VERSION` compared against a live `DOS_GET_SYSTEM_INFO`
field), not a build-time switch. No debug stubs, no build variants, no
target-address toggles. **No conditional-assembly adoption** — same
outcome as the Phase 12 WP71 / Phase 13 WP84 / Phase 14 WP91 surveys.

`git diff --stat -- src/external/dash/` is empty; `dash.ref.hex`
unchanged; `cmake --build build --target dash` succeeds (the
manifest→binary generator's source-hash gate would `FATAL_ERROR` on any
drift). DASH is byte-identical, provenance intact.

## Build + envelope

- Full `cmake --build build` clean. `BUILD_CASM` → 1416.
- `ld65 -m`: CODE `$3800-$905F`, RODATA `$9060-$9D08`, BSS `$9D09-$AAB9`.
  MAIN envelope `$3800 + $7400 = $AC00`. **Headroom `$AC00 - $AAB9` =
  327 bytes** (360 at WP97 close; WP98 cost ~33 B). **Fits `$7400` — no
  envelope grow.** 327 B is thin; WP99 is a version bump only (no code).
- Both link configs (`casm_3800`, `casm_3900`) link; test images build;
  build-number check passes.

Overlay `test/pass` event fired.

## Status

WP98 source-complete, build- and live-VICE-verified: the `/L`
blank-address rendering (`casmifL1` — suppressed lines 3-4 blank,
directive/real lines normal, `FILES COMPARE OK`), the `/M` non-leak
(`casmifM1` — map lists `REAL`, never `SKIPPED`, `FILES COMPARE OK`),
`TEST_CASM_COND` green, and the DASH survey (no adoption, byte-identical).
Committed. Requesting sign-off to close WP98 and start WP99 (Phase 15
consolidated completion gate: fresh full sweep, docs incl. a new
"Conditional Assembly" section, version bump to CASM 0.6.1, walkthrough).
