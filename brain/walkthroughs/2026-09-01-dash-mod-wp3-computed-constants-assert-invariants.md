# Walkthrough: DASH-MOD WP3 - Computed constants + `.ASSERT` invariants

Plan: `brain/plans/2026-09-01-dash-mod-wp3-computed-constants-assert-invariants.md`
Parent: `brain/plans/2026-09-01-dash-modernization.md`
Taskwarrior: WP3 task 52 (child of `94ec17b3`)
Branch: `feature/casm-phase14`
Baseline: DASH shipping manifest sha256 `3238b786...`, 4766 bytes.

## What this WP delivers

DASH's magic numbers are replaced by ~110 named constants declared in
`dmain.s`'s equate prologue, plus a 16-line `.assert` structural-invariant
block in `dash_wrapper.s`. **Output-preserving: the assembled DASH.PRG is
byte-for-byte identical to the pre-WP3 shipping manifest** (`3238b786...`,
4766 bytes) under both ca65 (`dash_ref`) and native CASM on real
hardware.

### Constant groups (all in `dmain.s` prologue, before any code)

| group | examples |
| --- | --- |
| Page model | `PAGE_SYS/APP/VMM`, `PAGECOUNT` |
| Screen geometry / glyphs | `SCREEN_COLS/ROWS/RAM`, `COLOR_RAM`, `COLORRAM_DELTA_HI`, `SCREENCODE_SPACE/VBAR/DOT/DASH`, `TEXT_COLOR`, `ACTIVE_TAB_COLOR`, `COL_CONTENT` |
| Formatting | `DEC_RADIX`, `PETSCII_SYMBOL_BASE`, `PETSCII_LOWER_BASE` |
| System page | `ROW_SYS_*` (11), `SYS_STRUCT_VERSION/SIZE`, `SYS_OFF_*` field map, `SYS_VMMFLAG_ACTIVE/REU_PROBED`, `VIDEO_NTSC/PAL` |
| Applications page | `ROW_APP_HEADER/SLOT0`, `COL_APP_RANGE/SIZE/FLAGS`, `APP_NAME_WIDTH`, `APP_STRUCT_VERSION/SIZE`, `APP_MAX_SLOTS`, `APP_OFF_*`, `APP_FLAG_*`, `DOS_ERR_SLOT_EMPTY` |
| VMM test page | `ROW_VMM_*` (8), `VMM_BLOCK_COUNT`, `VMM_PATTERN_COUNT`, `VMM_ALLOC_PARAGRAPHS`, `VMM_BLOCK_SIZE`, `VMMSTATE_*` (6), `VMMFAIL_*` (6) |
| DOS service bus | `OS_API`, `DOS_EXIT`, `DOS_GET_SYSTEM_INFO`, `DOS_GET_APP_INFO`, `DOS_ALLOC_MEM`, `DOS_FREE_MEM`, `DOS_VMM_READ`, `DOS_VMM_WRITE` |

Use-site conversions across `dscr.s`, `dfmt.s`, `dsys.s`, `dapp.s`,
`dvmm.s`, `dmain.s` (`DISPATCHPAGE` + `EXITAPP` + `START`), and `ddata.s`
(`.RES` counts -> `SYS_STRUCT_SIZE` / `APP_STRUCT_SIZE` / `VMM_BLOCK_SIZE`;
new zero-byte `PAGEROUTINETABLE_END:` marker).

### `.assert` invariant block (`dash_wrapper.s`, ca65-only)

CASM's expression grammar has **no equality/comparison/NOT operator**
(only `+ - | ^ & << >> * /` -- `brain/plans/2026-08-21-casm-phase13-wp83-assert.md`
Decision 3 correction), so a native-CASM `.ASSERT` is nonzero-truthiness
only and cannot express any of the planned invariants (WP83 explicitly
deferred this to "when DASH adoption is planned"). Per the user's
2026-09-01 decision, the block lives in `dash_wrapper.s` (the ca65-only
build wrapper -- full operator set, never assembled by CASM, not in the
manifest hashes, not on the utils disk). It is checked on every
`dash_ref` build; the CASM side is covered transitively because CASM's
`DASH.PRG` is byte-compared against this ca65 build.

16 assertions: the `$70-$8F` ZP scratch map is contiguous / in range /
non-overlapping two-byte pairs (12); `PAGECOUNT = 3`;
`(PAGEROUTINETABLE_END - PAGEROUTINETABLE) / 2 = PAGECOUNT`;
`PAGE_SYS = 0`; `PAGE_VMM = PAGECOUNT - 1`; DOS API codes in the
`$40-$5F` band (2).

### Excluded (deferred, explicitly not forgotten)

- The `POLLINPUT` key-code ladder (`#$85/#$86/#$87` F-keys, `#$54/#$74`
  etc.) and `SELECTSYS/APP/VMM` page-index literals, and
  `TRYRUNVMMTEST`'s `CMP #2` -- WP4 rewrites that whole graph and will
  consume the `PAGE_*` constants.
- `DRAWFRAME`'s `$0400 + N*40` row math and the 7 row-copy loops -- WP5
  collapses them.
- `dfmt.s` nibble masks (`#$0F`) and shift counters (`#4`/`#16`) -- pure
  idiom.
- The `$66-$6C` OS VMM-call parameter ZP block in `dvmm.s` -- shared
  cross-component ABI, documented inline.
- No `.assert` on the R6 relocation header/footer -- R6 is entirely a
  post-link concern (`tools/reloc.py` / CASM emission classification +
  the `HEADER` word in `dash_wrapper.s`); nothing in the shared source to
  assert on.
- A real CASM comparison operator (would expand Phase 12's frozen
  expression grammar project-wide) -- separate future item.

## Atomic increments

| # | scope | ca65 `dash_ref` vs pre-WP3 manifest |
| --- | --- | --- |
| 1 | constant prologue (core groups) + full `.assert` block; no use-site edits | byte-identical; all asserts pass |
| 2 | `dscr.s` | byte-identical |
| 3 | `dfmt.s` | byte-identical |
| 4 | `dsys.s` | byte-identical |
| 5 | `dapp.s` | byte-identical |
| 6 | `dvmm.s` | byte-identical |
| 7 | `ddata.s` + `DISPATCHPAGE`/`START` | byte-identical |
| 8 | full native CASM + manifest regen | byte-identical (3-way) |

Increments 1 and 2 each ran a native-CASM cross-check immediately (they
introduced the risky forms -- `.assert` position, `#>CONST`,
`#(a * b)`); 3-7 batched their native check into increment 8.

## Findings

1. **CASM has no comparison operator** -- resolved by putting `.assert`
   in the ca65-only wrapper (see above).
2. **CASM's named-constant-definition RHS must be a bare literal.**
   `SYS_VMMFLAG_ACTIVE = 1<<0` gave `CASM: EXPECTED NEWLINE` at the `<`
   (increment 8's first native run). Operators are fine at
   *instruction-operand* use sites (`#(2 * SCREEN_COLS)`, `#>COLOR_RAM`
   both proven in increment 2), just not in a `NAME = ...` line. Flag
   masks rewritten as `1`/`2`/`4`/`8`. AGENTS.md "Expressions are
   bounded" bullet updated.
3. `command64_casm_utils_d64` packages `build/dash.prg`, so `CASM ...
   /O:DASH.PRG` fails `OUTPUT WRITE FAILED` (a clean error, *not* the
   hang `project-casm-filecreateoutput-no-replace` predicted -- that note
   may be stale). Cross-check runs use `/O:DW3.PRG`. Also: the CMake disk
   target does not rebuild on a bare `--build` -- `rm` the `.d64` first.
4. `EXITAPP` had two raw operands (`#$4C` / `JSR $1000`) that the
   per-file increments missed; folded into increment 8.

## Verification -- byte-identical, three ways (`3238b786...`, 4766 bytes)

1. **ca65 `dash_ref`** rebuilt after every increment: byte-identical to
   `hex_manifest_to_bin.py`'s transcription of the pre-WP3 manifest, and
   the `dash_ref` link **passes all 16 `.assert`s** (a false one aborts
   the link).
2. **Native CASM under VICE** (`CASM V0.5.2.1404`, 16MB REU): booted
   Command64 (`image.d64` u8), `command64_casm_utils.d64` u9, `DRIVE 9`,
   `CASM DMAIN.S /O:DW3.PRG` -> `P1: DONE 01728 STATEMENTS`, `P2: DONE
   01728`, `DONE: P1 01728, P2 01728, 04766 BYTES`, `CASM: INPUT
   VALIDATED`. `COMP DW3.PRG DASH.REF` -> **`FILES COMPARE OK`**.
3. Extracted native `DW3.PRG` (`cc1541 -X`): `cmp` byte-identical to
   `build/dash_ref.prg` and the pre-WP3 shipping bytes. All three sha256
   `3238b786...`.

### Manifest regenerated

`scripts/build_dash_manifest.py <native DW3.PRG> --cross-check
build/dash_ref.prg` rewrote `src/external/dash/dash.ref.hex`: **byte
payload untouched**, only the provenance line and the 7 `source_sha256`
lines changed (all 7 sources moved this WP), `cross-check: MATCHES
dash_ref.prg byte-for-byte`, no `--allow-host-bytes`. `dash` CMake target
then rebuilt `dash.prg` at sha256 `3238b786...`, re-validating every
source hash.

## Build evidence

- `dash_ref`, `dash`, `command64_casm_utils_d64`, `image_d64`, and a full
  `cmake --build build` all clean.
- `BUILD_DASH_REF` counter bumped (real rebuilds).
- `casm.prg` unchanged (no CASM source touched).
- `check_casm_source_bytes.py` clean on all 7 shipped sources.

## Overlay events

`test`/`pass` for `dash-mod-wp3` (increments 1, 2, 8) via the
`c64-overlay-api` MCP.

## Runtime note

Not separately re-verified: byte-identical output means the running DASH
is bit-for-bit the shipped one. Runtime re-verification starts at WP4,
the first WP that changes bytes.

## Sign-off requested

WP3 is complete and verified: ~110 named constants adopted across all 7
DASH sources, 16 ca65-only structural `.assert` invariants added, DASH
output byte-identical under ca65 and native CASM (triple-checked),
manifest regenerated with matching bytes and fresh source hashes, full
build green, all deferred sets listed. Two dual-assembler findings
documented in AGENTS.md. Requesting approval to close WP3 and proceed to
WP4 (event loop / key dispatch / page dispatch refactor -- needs its own
detailed sub-plan first).
