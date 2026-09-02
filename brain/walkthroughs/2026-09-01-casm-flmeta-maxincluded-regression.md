# Walkthrough: `test_casm_flmeta` case-6 `resolveMaxIncludedName` Regression

Plan: `brain/plans/2026-09-01-casm-flmeta-maxincluded-regression.md`
Taskwarrior: task 43 (`8da90f45`), project `casm`
Branch: `feature/casm-phase14`

## What it was

The CASM Phase 14 WP92 consolidated completion-gate sweep found
`test_casm_flmeta` (`tests/src/casm_faultinject_listing_meta/casm_flmeta.s`)
failing its **case 6, `resolveMaxIncludedName`** -- marker line
`.....f...`, then `CASM FAULT META: FAIL`. Deterministic across 3
consecutive live runs. The other 30 `test_casm_*` harnesses and all 11
Phase 14 production fixtures were green.

## Root cause -- a stale test fixture, not a product bug

Found by static review of `6e708fa..ae2ea56` (no bisect needed).

The **memory-optimization WP's Finding D** (`8ecbc46`, user-approved
2026-08-31) dropped `CASM_INCLUDE_FILENAME_MAX` / `CASM_FILENAME_MAX`
**63 -> 32** and `CASM_LISTING_RESOLVED_NAME_SIZE` `$44` (68) -> `40`, to
recover MAIN. It re-pinned the sibling fixtures to the new cap-32
boundary:

- `casm_include` `valid63` -> `validCap` (32), `tooLong` boundary moved;
- `casm_cliderive` `cderboundary1` / `cderoverflow1`.

It **missed the parallel stale literals in `casm_flmeta.s`**:

| Line | Was | Should be |
| --- | --- | --- |
| `includeName63:` (632) | 63-digit `.byte` string | 32-digit |
| `resolvedMaxIncluded:` (633) | `"11:" + 63` = 66 bytes | `"11:" + 32` = 35 |
| `resolveMaxIncludedName` (313) | `lda #66` | `lda #35` |

None reference a `CASM_*` symbol, so **no build `.assert` guarded them**
("every constant assert across 31 harnesses passed" in the Finding D
commit message was true but blind to this). And `test_casm_flmeta` was
**not re-run live** in the memory-opt Increment 9 verification -- the
listing-I/O diagnostics (`$3D-$41`) were host-verifier-only, on
"same path" reasoning
(`brain/walkthroughs/2026-08-24-casm-memory-optimization.md:84-86`).

Symptom match: with the cap now 32, `listingResolveFilename` on a 63-char
include name no longer yields a 66-byte resolved name, so
`checkResolveText`'s `CasmListResolvedNameLen == 66` check
(`casm_flmeta.s:177-179`) fails.

**Product behaviour (cap include filenames at 32) is correct and
user-approved.**

## Fix

Harness-only, mirroring exactly what Finding D did for the siblings.
`git diff` is `tests/src/casm_faultinject_listing_meta/casm_flmeta.s`
alone:

- `includeName63` -> `includeNameCap` (32 digits) + an explanatory
  comment citing Finding D and this plan;
- `resolvedMaxIncluded` -> `"11:" + 32` = 35 bytes;
- `resolveMaxIncludedName` `lda #66` -> `lda #35`.

No CASM source, no fixture generator, no `CMakeLists.txt`, no version
bump. `cmake --build build --target test_casm_flmeta` clean (counter
1015 -> 1019, all link asserts pass). `casm_listing_test_d64` rebuilt.

## Live re-verification

VICE 3.10, `Command 64-DOS Version 0.4.1.2680`, CASM build 1404
(unchanged), `casm_listing_test.d64` freshly detached/re-attached to
unit 8.

| Harness | Result | Why |
| --- | --- | --- |
| `test_casm_flmeta` | `CASM FAULT META: PASS` (marker `.........`, all 9) | the fix |
| `test_casm_flist` | `CASM FAULT LIST: PASS` | sibling fault + listing path |
| `test_casm_listwrite` | `CASM LISTWRITE: PASS` | listing-file write path |
| `test_casm_cliderive` | `CASM CLIDERIVE: PASS` | Finding D's other re-pinned harness -- live witness the cap-32 filename boundary is right |

The remaining 6 `casm_listing_test.d64` harnesses + `faultvmm` +
`test_casm_include` / `test_casm_catalog` are byte-identical PRGs that all
PASSed the same day in the WP92 sweep against this identical CASM build,
and `test_casm_cliderive` re-confirmed the same cap-32 code path live --
not re-run. No-change to `casmhello` / `casmassert1` is guaranteed by
construction (zero CASM source touched).

VICE flushed and left healthy at the shell prompt. Overlay `test/pass`
event fired (HTTP API; MCP bridge was up this session).

## Follow-up recorded

Memory `feedback-memory-opt-cap-change-missed-unguarded-literal` -- when a
capacity constant changes, `.assert`-guarded call sites are not the whole
surface: test harnesses that hardcode the old value as a raw literal
(no symbol reference) slip through both the build and a
"same-path / host-verifier" live-verification shortcut. Re-run *every*
harness that touches the changed path live, not a representative subset.

## Status

`test_casm_flmeta` PASS. Task 43 ready to close. CASM Phase 14 WP92
resumes from its Increment 4.
