---
feature: dash-mod-wp3-computed-constants-assert-invariants
created: 2026-09-01
status: done (user-approved 2026-09-01)
taskwarrior: task 52 (child of 94ec17b3)
depends-on: DASH-MOD WP2 (full @local migration, done + user-approved 2026-09-01 -- brain/walkthroughs/2026-09-01-dash-mod-wp2-full-local-migration.md); DASH-MOD WP1 (CASM .ASSERT ca65 action keyword)
---

# Plan: DASH-MOD WP3 - Computed constants + `.ASSERT` invariants

## Status

**Done — user-approved 2026-09-01.** Third WP of
the DASH Modernization increment. Parent:
`brain/plans/2026-09-01-dash-modernization.md`. WP1 and WP2 done +
approved. Branch: `feature/casm-phase14`. Baseline: DASH shipping
manifest sha256 `3238b786...`, 4766 bytes (unchanged since Phase 14
WP91; WP2 was a byte-preserving rename). Walkthrough:
`brain/walkthroughs/2026-09-01-dash-mod-wp3-computed-constants-assert-invariants.md`.

## Objective

Replace DASH's magic numbers with named constants declared in `dmain.s`'s
equate prologue (shared by both assemblers), and add build-time
`.assert` structural invariants in `dash_wrapper.s` (ca65-only -- CASM's
expression grammar has no comparison operator; see `## .ASSERT
approach`). **Output-preserving: the assembled DASH.PRG must stay
byte-for-byte identical to the pre-WP3 shipping manifest** under both
ca65 and native CASM. A computed `PAGECOUNT` of 3 assembles identically
to `#3`; assertions emit no bytes. Any non-zero byte delta is a
stop-and-explain (Stop Conditions).

**Delivered:**
- A broad named-constant block at the top of `dmain.s` (extending the
  existing `DISPATCHVECTOR = $70` ... `SRCIDX = $7F` equates): screen
  geometry, screen-code glyphs, per-row Y indices, page indices +
  `PAGECOUNT`, DOS API call codes, `DOS_GET_SYSTEM_INFO` / app-record
  struct offsets and sizes, VMM state / fail-stage enums, VMM block
  geometry, VMM/REU flag bit-masks, and the `DOS_ERR_SLOT_EMPTY` code.
- Every corresponding literal at its use site across `dscr.s`, `dfmt.s`,
  `dsys.s`, `dapp.s`, `dvmm.s`, `ddata.s` replaced by the constant.
- A `.assert` invariant block in **`dash_wrapper.s`** (the ca65-only
  build wrapper), after its `.include "dmain.s"`, using ca65's real
  comparison operators: the ZP `$70-$8F` map is contiguous / in range /
  non-overlapping two-byte pairs; DOS API codes in the `$40-$5F` band;
  `PAGECOUNT = 3`; `(* - PAGEROUTINETABLE) / 2 = PAGECOUNT`. See
  `## .ASSERT approach` -- CASM cannot express equality/range asserts, so
  these are ca65-only and rely on the ca65<->CASM byte cross-check as the
  CASM-side backstop.

**Excluded (deferred, by design):**
- Any structural change, routine restructure, or behavior change -- WP4
  (event loop / key dispatch / page dispatch) and WP5 (frame / renderer
  helpers) own that. WP3 only renames literals and adds assertions.
- The `dmain.s` key-code literals (`#$85/#$86/#$87` F-keys, `#$54/#$74`
  etc.) -- these are consumed by the key-dispatch chain WP4 rewrites;
  naming them now then reworking the chain is churn. WP3 leaves the
  `POLLINPUT` key ladder untouched. (Exception: `DISPATCHPAGE`'s own
  `CMP #3` becomes `#PAGECOUNT` -- it is the direct target of this WP.)
- The `SELECTSYS/APP/VMM` page-index literals (`LDA #0/#1/#2`) -- WP4
  collapses those three blocks into one parametrized path; it will use
  the `PAGE_SYS/PAGE_APP/PAGE_VMM` constants this WP defines.
- No `.ASSERT` on the R6 relocation header/footer. R6 relocation is
  performed entirely post-link (`tools/reloc.py` for ca65, CASM's
  per-operand emission classification) plus a single `HEADER`-segment
  word in the ca65-only `dash_wrapper.s`; there is nothing in the shared
  dual-assembler source to assert on. The existing ca65<->CASM byte
  cross-check already covers relocation correctness. (Documented here and
  in the walkthrough per the user's 2026-09-01 decision.)
- `dfmt.s` gets light treatment only: `SCREENCODE_SPACE`,
  `PETSCII_SYMBOL_BASE`/`PETSCII_LOWER_BASE` band bounds, `DEC_RADIX`.
  Pure-idiom literals (`#$0F` nibble mask, `#4`/`#16` shift/loop
  counters) stay as-is -- naming them reduces clarity.
- `AGENTS.md` "Zero Page Allocation" section gets a one-line note that
  the ZP map is now `.ASSERT`-guarded; the full AGENTS.md rewrite is WP6.

## Scoping Decisions (user-confirmed 2026-09-01)

1. **Constant scope: broad.** Moderate set (PAGECOUNT, struct offsets,
   API codes, VMM enums + flag masks) *plus* full screen-geometry
   constants (`SCREEN_COLS=40`, `SCREEN_ROWS=25`, `SCREEN_RAM=$0400`,
   `COLOR_RAM=$D800`, per-row Y indices). Accepted that this overlaps
   WP5's renderer refactor -- WP5 will consume these constants rather
   than re-deriving them.
2. **Placement: all in `dmain.s` prologue.** Extend the existing `=`
   equate block at the top of `dmain.s`. Satisfies AGENTS.md's "equates
   precede every use" and the WP2/WP91 "no mid-code equate" constraint
   for both assemblers unambiguously. `PAGECOUNT` is a literal there; the
   `(* - PAGEROUTINETABLE)/2` cross-check lives as a `.ASSERT` next to
   the table in `ddata.s`.
3. **R6 header/footer `.ASSERT`: dropped, documented.** (See Excluded.)
4. **`.ASSERT` invariants: ca65-only, in `dash_wrapper.s`** (confirmed
   2026-09-01 after the blocking finding below). CASM's expression
   grammar has no equality/comparison/NOT operator, so it cannot express
   any of the planned structural invariants. Rather than an unreadable
   `1/(1+(a^b))` truthiness idiom, a CASM-grammar expansion, or dropping
   the invariants entirely, the `.assert` block lives in the ca65-only
   wrapper where real operators are available. It is checked on every
   `dash_ref` build; the CASM side is covered transitively because CASM's
   output is byte-compared against ca65's.

## .ASSERT approach

**Blocking finding (2026-09-01, before any edit):** CASM's expression
grammar recognizes only `+ - | ^ & << >> * /` as operators
(`expr.s parseOperatorTail`; `brain/plans/2026-08-21-casm-phase13-wp83-assert.md`
Decision 3 correction). `CASM_TOKEN_EQUALS` is statement-level only
(named-constant definition); `<`/`>` are byte-extraction prefixes, not
comparisons. So native-CASM `.ASSERT` is **nonzero-truthiness only** and
cannot express `a = b`, `a >= b`, or `(x & $FF) = 0`. WP83 foresaw this
and deferred the resolution to "when DASH adoption is planned" -- i.e.
here.

**Resolution (Scoping Decision 4):** the structural `.assert` invariants
go in `dash_wrapper.s`, which only ca65 ever assembles. ca65 has the full
operator set. Concretely, appended after `.include "dmain.s"`:

```ca65
; --- STRUCTURAL INVARIANTS (ca65-only; CASM lacks comparison operators.
;     CASM side is covered by the ca65<->CASM byte cross-check.) ---
.assert CURRENTROW    = DISPATCHVECTOR + 2, error
.assert SCREENDESTPTR = CURRENTROW    + 1, error
.assert STRINGSRCPTR  = SCREENDESTPTR + 2, error
.assert CURRENTCOL    = STRINGSRCPTR  + 2, error
.assert FMTWORK       = CURRENTCOL    + 1, error
.assert DIV10REM      = FMTWORK       + 2, error
.assert COLORPTR      = DIV10REM      + 1, error
.assert CHARSTASH     = COLORPTR      + 2, error
.assert MAXLEN        = CHARSTASH     + 1, error
.assert SRCIDX        = MAXLEN        + 1, error
.assert DISPATCHVECTOR >= $70, error
.assert SRCIDX        <= $8F, error
.assert PAGECOUNT = 3, error
.assert DOS_ALLOC_MEM >= $40, error
.assert DOS_GET_APP_INFO <= $5F, error
.assert (PAGEROUTINETABLE_END - PAGEROUTINETABLE) / 2 = PAGECOUNT, error
```

(`PAGEROUTINETABLE_END` is a new zero-byte location label added in
`ddata.s` immediately after the three `.WORD` entries, in increment 1 --
it makes the table-size invariant explicit instead of leaning on
`DASHVERSTR` happening to follow the table.)

`dash_wrapper.s` is **not** in the manifest's `source_sha256` set (that
tracks only the seven shipped-bytes sources) and is **not** packaged as a
SEQ on `command64_casm_utils.d64` -- it is purely the ca65 cross-check
harness. Changing it does not touch the shipped artifact provenance.

A real CASM comparison operator remains a separately-planned future item
(it would expand Phase 12's frozen expression grammar project-wide); if
it lands later, these asserts can migrate into the shared source.

## Dual-assembler constraints (re-confirmed per file during implementation)

- **Every constant expression must evaluate identically under ca65 and
  native CASM.** AGENTS.md "Expressions are bounded": parenthesised
  arithmetic and the Phase 12 operators are available, but only where
  both assemblers agree. Increment 1 assembles the whole constant block
  under both before any use-site edits; each later increment re-checks
  via byte identity.
- **Every constant RHS is a bare literal** (`NAME = 40`, `NAME = $D4`).
  Native CASM's *named-constant-definition* parser does **not** accept an
  operator in the RHS -- `SYS_VMMFLAG_ACTIVE = 1<<0` gave `EXPECTED
  NEWLINE` at the `<` (found in inc8, 2026-09-01). Operators (`* + > <<`)
  are fine at *instruction-operand* use sites (proven in inc2:
  `#(2 * SCREEN_COLS)`, `#>COLOR_RAM`), just not in a `NAME = ...`
  definition. So flag masks are written as `1`/`2`/`4`/`8`, not `1<<n`.
  Also: no forward references (the block is first in the file), no
  `@local` on a constant RHS (`LOCAL_IN_CONSTANT`,
  `reference-local-label-in-constant-precedent`), no mid-code `=`.
- **`.assert` lives only in `dash_wrapper.s`** (ca65-only, see
  `## .ASSERT approach`). The shared seven sources get **no** `.ASSERT`
  directive this WP -- only constant use-site edits. `dash_wrapper.s` is
  not subject to the dual-assembler subset or `check_casm_source_bytes`.
- **`check_casm_source_bytes.py`** must still pass every renamed shared file
  (uppercase ASCII, no case-colliding identifiers). New constant names
  are all-uppercase.

## Constant inventory (indicative -- finalized per file during implementation)

All declared in `dmain.s` prologue, grouped by comment banner. Increment
1 adds the geometry / page / API groups (referenced by the `.assert`
block); the rest land in their owning file's increment.

**Screen geometry / glyphs**
- `SCREEN_COLS = 40`, `SCREEN_ROWS = 25`
- `SCREEN_RAM = $0400`, `COLOR_RAM = $D800`
- `SCREEN_CELLS = SCREEN_COLS * SCREEN_ROWS` (1000; used in
  `CLEARSCREEN`'s `(25*40)-(3*256)` remainder bound as
  `SCREEN_CELLS - (3 * 256)` -- verify both assemblers fold to 232)
- `COLORRAM_DELTA_HI = $D4` (screen-ptr-high -> color-ptr-high add in
  `SCREENPUTCHAR`; kept as a plain byte, not `(COLOR_RAM-SCREEN_RAM)>>8`,
  to avoid a `>>` cross-check risk)
- `SCREENCODE_SPACE = $20`, `SCREENCODE_VBAR = $5D`
- `TABROW_COLOR_OFFSET = 2 * SCREEN_COLS` (`HIGHLIGHTTABS`)
- `DEFAULT_TEXT_COLOR = $0E`, `ACTIVE_TAB_COLOR = $01`

**Per-row Y indices** (System page rows 6-15, App header row 4 + slot
base row 5, VMM rows 4/6/8-14, frame rows) -- named
`ROW_SYS_VER = 6` ... `ROW_APP_HEADER = 4`, `ROW_APP_SLOT0 = 5`,
`ROW_VMM_TITLE = 4` etc. Exact set enumerated during the per-file
increments.

**Pages**
- `PAGE_SYS = 0`, `PAGE_APP = 1`, `PAGE_VMM = 2`
- `PAGECOUNT = 3`

**DOS API call codes** (mirror the OS service bus)
- `DOS_EXIT = $4C`, `DOS_GET_SYSTEM_INFO = $5C`,
  `DOS_GET_APP_INFO = $5D`, `DOS_ALLOC_MEM = $48`, `DOS_FREE_MEM = $49`,
  `DOS_VMM_READ = $59`, `DOS_VMM_WRITE = $5A`
- `DOS_ERR_SLOT_EMPTY = $02`
- `OS_API = $1000` (the `JSR $1000` service-bus entry)

**System-info record** (`SYSINFOBUF`, offsets mirror `SYS_INFO_OFF_*` in
`include/command64.inc`)
- `SYS_STRUCT_VERSION = 2`, `SYS_STRUCT_SIZE = 24`
- `SYS_OFF_STRUCTVERSION = 0` ... `SYS_OFF_OSPATCH = 22`,
  `SYS_OFF_APPUSEDSLOTS = 21`, `SYS_OFF_APPMAXSLOTS = 20`, etc. -- full
  map from `dsys.s`'s existing `SYSINFOBUF+N` comments.
- `SYS_VMMFLAG_ACTIVE = 1<<0`, `SYS_VMMFLAG_REU_PROBED = 1<<1`
- `VIDEO_NTSC = 0`, `VIDEO_PAL = 1`

**App record** (`APPBUF`)
- `APP_STRUCT_VERSION = 1`, `APP_STRUCT_SIZE = 24`, `APP_MAX_SLOTS = 16`
- `APP_OFF_FLAGS = 3`, `APP_OFF_LOADADDR = 4`, `APP_OFF_SIZE = 6`,
  `APP_OFF_NAMELEN = 8`, `APP_OFF_NAMEDATA = 9`
- `APP_FLAG_USED = 1<<0`, `APP_FLAG_RUNNING = 1<<1`,
  `APP_FLAG_REU = 1<<2`, `APP_FLAG_STACK = 1<<3`
- App-page column indices: `COL_APP_NAME = 2`, `COL_APP_RANGE = 18`,
  `COL_APP_SIZE = 28`, `COL_APP_FLAGS = 33`; `APP_NAME_WIDTH = 15`

**VMM test**
- `VMM_BLOCK_COUNT = 16`, `VMM_BLOCK_SIZE = $0100`,
  `VMM_PATTERN_COUNT = 3`
- `VMMSTATE_UNAVAIL = 0` ... `VMMSTATE_CLEANUPFAIL = 5`
- `VMMFAIL_ALLOC = 0` ... `VMMFAIL_INTERNAL = 5`

**dfmt.s (light)**
- `DEC_RADIX = 10`, `PETSCII_SYMBOL_BASE = $40`,
  `PETSCII_LOWER_BASE = $60`

(The full `.assert` block is in `## .ASSERT approach` above -- it lands in
`dash_wrapper.s`, ca65-only.)

## Atomic Increments

Each increment ends with: `check_casm_source_bytes.py` clean, `cmake
--build build --target dash_ref`, `cmp` of `build/dash_ref.prg` against
the pre-WP3 shipping-manifest transcription -> **byte-identical**.

1. **Core structural constants (`dmain.s`) + full `.assert` block
   (`dash_wrapper.s`); no use-site edits.** Add the constants the
   `.assert` block references (ZP equates already exist; add `PAGECOUNT`,
   `PAGE_SYS/APP/VMM`, the `DOS_*` API codes) plus the cross-cutting
   geometry constants (`SCREEN_COLS/ROWS/RAM`, `COLOR_RAM`). Add the
   `.assert` block to `dash_wrapper.s` after `.include "dmain.s"`.
   `cmake --build build --target dash_ref`: builds clean (every `.assert`
   passes -- a false one aborts the ca65 link) and `dash_ref.prg` is
   byte-identical (constants unused, asserts emit nothing). Then one
   native-CASM check that CASM still accepts the constant block: `CASM
   DMAIN.S /O:DW3.PRG` on `command64_casm_utils.d64` under VICE ->
   `INPUT VALIDATED`, `COMP DW3.PRG DASH.REF` -> `FILES COMPARE OK`.
   (Scratch output name, not `DASH.PRG`: the CMake
   `command64_casm_utils_d64` target now packages `build/dash.prg`, so
   `/O:DASH.PRG` fails with `OUTPUT WRITE FAILED` -- `fileCreateOutput`
   has no replace mode, `project-casm-filecreateoutput-no-replace`.
   `DW3.PRG` from a prior increment's run also collides, and the CMake
   disk target does **not** reliably rebuild on a bare `--build` -- `rm
   build/command64_casm_utils.d64` before rebuilding for each native
   check.) Front-loads the assert + constant-cross-check risk. If a `.assert`
   fires, see Stop Conditions. File-specific constants (per-row Y
   indices, column indices, struct offsets, VMM enums) are added in
   their own file's increment below, alongside their first use, so each
   constant lands in the same diff as the literals it replaces.
2. `dscr.s` -> screen geometry, glyph, row, color constants at use sites.
   ca65 byte-identical.
3. `dfmt.s` -> the three light constants. ca65 byte-identical.
4. `dsys.s` -> `SYS_*` struct offsets/sizes, row indices, API codes, VMM
   flag masks, `VIDEO_*`. ca65 byte-identical.
5. `dapp.s` -> `APP_*` struct offsets/sizes/flags, `APP_MAX_SLOTS`,
   column indices, `DOS_ERR_SLOT_EMPTY`, `DOS_GET_APP_INFO`, row base.
   ca65 byte-identical.
6. `dvmm.s` -> `VMMSTATE_*` / `VMMFAIL_*` enums, `VMM_BLOCK_COUNT` /
   `VMM_BLOCK_SIZE` / `VMM_PATTERN_COUNT`, API codes, row indices. ca65
   byte-identical.
7. `ddata.s` + `dmain.s` `DISPATCHPAGE` -> `CMP #3` becomes
   `CMP #PAGECOUNT`; `ddata.s` data-side literals reviewed (none expected
   to change -- `TABCOLSTART`/`TABCOLLEN`/row templates are layout data,
   stay raw). ca65 byte-identical.
8. **Native CASM + manifest.** Rebuild `command64_casm_utils_d64` (fresh,
   no stale `DW3.PRG`), then full `CASM DMAIN.S /O:DW3.PRG` on it under
   VICE (image.d64 u8, utils u9, `DRIVE 9`); `COMP DW3.PRG DASH.REF` ->
   `FILES COMPARE OK`. Extract `DW3.PRG` (`cc1541 -X`); `cmp` against
   `build/dash_ref.prg` and the
   pre-WP3 shipping bytes -> byte-identical three ways.
   `build_dash_manifest.py <native prg> --cross-check build/dash_ref.prg`
   regenerates `dash.ref.hex` -- **same 4766 bytes, same sha256**, fresh
   `source_sha256` for the (up to seven) changed files, no
   `--allow-host-bytes`. `dash` + full `cmake --build build` +
   `image_d64` clean.
9. Fire `c64-overlay-api` test events (curl fallback).

## Expected Files

| File | Planned action |
| --- | --- |
| `src/external/dash/dmain.s` | Modify -- constant prologue; `DISPATCHPAGE` `#PAGECOUNT` |
| `src/external/dash/dscr.s` `dfmt.s` `dsys.s` `dapp.s` `dvmm.s` | Modify -- literals -> constants at use sites |
| `src/external/dash/ddata.s` | Modify -- data-side literal review (likely no change) |
| `src/external/dash/dash_wrapper.s` | Modify -- ca65-only `.assert` invariant block (not in manifest hashes, not on the utils disk) |
| `src/external/dash/dash.ref.hex` | Regenerate -- source hashes only (7 shipped sources), bytes unchanged |
| `src/external/dash/BUILD_DASH_REF` | Auto |
| `src/external/dash/AGENTS.md` | Modify -- one-line note: ZP map + PAGECOUNT are `.assert`-guarded in `dash_wrapper.s` (ca65-only; CASM lacks comparison operators). Full rewrite still WP6. |
| `brain/walkthroughs/2026-09-0X-dash-mod-wp3-computed-constants-assert-invariants.md` | Create |
| `brain/plans/2026-09-01-dash-modernization.md` | Append Progress |
| `wiki/tasks/dash-modernization.md` | Tick WP3 |

## Stop Conditions

- ca65 `dash_ref.prg` differs by any byte from the pre-WP3
  shipping-manifest bytes after any increment -> that increment's last
  batch is wrong (a constant expression folded differently, or a rename
  hit the wrong literal); bisect and revert.
- Native CASM `DASH.PRG` is not byte-identical to `dash_ref.prg`.
- A `.assert` fires during the `dash_ref` (ca65) build. Two sub-cases:
  (a) the assertion is mis-stated (wrong expected value / operator) ->
  fix the assertion, it is new code; (b) the assertion is correct and
  exposes a real latent inconsistency in DASH -> **disclose and defer**
  as a separate follow-up (do not fix the underlying code inline in
  WP3), unless the user directs otherwise in the moment.
- A constant expression evaluates differently between ca65 and CASM (byte
  mismatch), or CASM rejects a constant form -> drop that constant to the
  plainest form (bare literal RHS); if still unequal, it stays a literal
  at the use site and is noted.
- `build_dash_manifest.py` reports any byte change or would need
  `--allow-host-bytes`.
- `check_casm_source_bytes.py` rejects a renamed file.
- A no-change rebuild changes an artifact.
- Any construct needed that is outside the dual-assembler subset.

## Documentation, Task, and Tracker Updates

- **At approval:** Taskwarrior WP3 (child of `94ec17b3`).
- **At completion:** walkthrough (with the full final constant list and
  both assemblers' assert-pass evidence); parent plan Progress;
  `wiki/tasks/dash-modernization.md` tick; one-line `AGENTS.md` note.
  `CHANGELOG` / DASH version bump remain at WP6.

## Completion Gate

- All literals in scope replaced by constants; every deferred set
  (key-code ladder, `SELECT*` page literals, dfmt idiom literals, R6
  assert, CASM comparison operator) explicitly listed as deferred, not
  forgotten.
- ca65 `dash_ref` == native CASM `DASH.PRG` == pre-WP3 shipping manifest,
  byte-for-byte (4766 bytes, sha256 `3238b786...`).
- The `.assert` invariant block is present in `dash_wrapper.s` and the
  `dash_ref` (ca65) build passes it -- shown in the walkthrough. (Native
  CASM never sees it; its correctness on the CASM side is transitive via
  the byte cross-check.)
- `dash.ref.hex` regenerated: identical bytes, identical sha256, updated
  source hashes, `--cross-check` MATCHES, no `--allow-host-bytes`.
- `dash` + `dash_ref` + `command64_casm_utils_d64` + `image_d64` +
  full `cmake --build build` clean.
- Walkthrough with live evidence; trackers synced; explicit user
  approval.
- Runtime is **not** separately re-verified here -- byte-identical output
  means the running DASH is bit-for-bit the shipped one. Runtime
  re-verification starts at WP4, the first WP that changes bytes.

## Progress

- 2026-09-01: Drafted for review. Scoping decisions 1-3 captured from the
  user (broad constant scope; all in `dmain.s` prologue; R6 assert
  dropped + documented). Constant inventory and `.ASSERT` block sketched
  from a full read of all seven sources.
- 2026-09-01: **Approved.** Taskwarrior task 52. Pre-WP3 bytes snapshot
  taken (sha256 `3238b786...`, 4766 bytes).
- 2026-09-01: **Blocking finding before any edit.** CASM's expression
  grammar has **no equality/comparison/logical-NOT operator** -- only
  `+ - | ^ & << >> * /` (`brain/plans/2026-08-21-casm-phase13-wp83-assert.md`
  Decision 3 correction; re-verified against `expr.s parseOperatorTail`).
  `.ASSERT` in CASM is nonzero-truthiness only. Every structural invariant
  this WP was built around (`PAGECOUNT = 3`, ZP contiguity `a = b+2`,
  API-band `a >= $40`) is an equality or range check that CASM cannot
  express. WP83 explicitly punted this to "when WP84/DASH adoption is
  planned". Implementation paused; options put to the user.
- 2026-09-01: **Plan revised, re-approved.** Scoping Decision 4: the
  `.assert` invariant block moves to `dash_wrapper.s` (ca65-only, full
  operator set); the shared seven sources get no `.ASSERT` this WP. CASM
  side covered transitively by the ca65<->CASM byte cross-check. See
  `## .ASSERT approach`. Constant adoption scope unchanged. Ready for
  increment 1.
- 2026-09-01: **Increment 1 complete.** `dmain.s` prologue: PAGE/GEOMETRY/
  DOS-API constant groups (`PAGE_SYS/APP/VMM`, `PAGECOUNT`,
  `SCREEN_COLS/ROWS/RAM`, `COLOR_RAM`, `OS_API`, `DOS_*`). `ddata.s`:
  zero-byte `PAGEROUTINETABLE_END:` marker. `dash_wrapper.s`: 20-line
  ca65-only `.assert` block (ZP contiguity x10 + range x2, PAGECOUNT,
  table-size, PAGE_SYS/VMM, API-band x2) using the 4-arg
  `.assert cond, error, "msg"` form. `check_casm_source_bytes` clean.
  ca65 `dash_ref` builds clean -- **every `.assert` passes** -- and
  `dash_ref.prg` byte-identical to the pre-WP3 manifest (`3238b786...`).
  Native CASM: P1/P2 01638 statements (was 01621; +17 = the new
  `NAME = value` lines + label), `04766 BYTES`, `INPUT VALIDATED`; the
  constant block and `PAGEROUTINETABLE_END` label assemble clean under
  CASM. `COMP DW3.PRG DASH.REF` -> `FILES COMPARE OK`; extracted
  `DW3.PRG` `cmp`-identical to `dash_ref.prg` and pre-WP3 bytes (3-way,
  all `3238b786...`).
  Findings: (a) CASM's `.ASSERT` accepts ca65's 4-arg form fine but
  emits nothing and cannot compare -- confirmed the wrapper is the right
  home. (b) `command64_casm_utils_d64` packages `build/dash.prg`, so
  `/O:DASH.PRG` gives `CASM: OUTPUT WRITE FAILED` (clean error, not a
  hang -- `project-casm-filecreateoutput-no-replace` "hang" note may be
  stale); switched the cross-check runs to `/O:DW3.PRG`. (c) the CMake
  disk target does not rebuild on a bare `--build`; `rm` the `.d64`
  first before each native check.
- 2026-09-01: **Increment 2 (`dscr.s`) complete.** New constants:
  `COLORRAM_DELTA_HI`, `SCREENCODE_SPACE`, `SCREENCODE_VBAR`,
  `TEXT_COLOR`, `ACTIVE_TAB_COLOR` (dmain.s prologue). dscr.s use sites:
  `#$20`/`#$0E`/`#$01`/`#$5D` glyph+color literals, `#40`/`#25` cursor
  bounds -> `#SCREEN_COLS`/`#SCREEN_ROWS`, `#$D4` -> `#COLORRAM_DELTA_HI`,
  `#3` tab count -> `#PAGECOUNT`, `#2*40` -> `#(2 * SCREEN_COLS)`, `#$D8`
  -> `#>COLOR_RAM`. Left raw: `$0400`/`$D800` screen/color RAM base
  addresses and `DRAWFRAME`'s `$0400+N*40` row math (WP5 collapses those
  loops), `#$04` screen-base-high in `COMPUTEROWADDR`. ca65 `dash_ref`
  byte-identical (`3238b786...`), all `.assert` pass. Native CASM
  `P1/P2 01643`, `04766 BYTES`, `INPUT VALIDATED`; `COMP DW3.PRG
  DASH.REF` -> `FILES COMPARE OK`; extracted DW3.PRG 3-way byte-identical.
  The `>` / `*` / `+` constant-expression forms are proven equal under
  both assemblers -- later increments (plain `= literal` constants) are
  lower risk and batch their native check into increment 8.
- 2026-09-01: **Increments 3-7 complete (ca65 byte-identical each).**
  Commits `casm: DASH-MOD WP3 inc3..inc7`.
  - inc3 `dfmt.s`: `DEC_RADIX`, `PETSCII_SYMBOL_BASE`, `PETSCII_LOWER_BASE`;
    `#$20`/band-bounds/`#10` at use sites. Nibble masks + shift counters
    left as idiom.
  - inc4 `dsys.s`: `SCREENCODE_DOT`, `COL_CONTENT`, `ROW_SYS_*` (11),
    `SYS_STRUCT_VERSION/SIZE`, full `SYS_OFF_*` field map,
    `SYS_VMMFLAG_ACTIVE/REU_PROBED`, `VIDEO_NTSC/PAL`. `#$5C`/`JSR $1000`
    -> `#DOS_GET_SYSTEM_INFO`/`JSR OS_API`; every `SYSINFOBUF+N` ->
    `SYSINFOBUF+SYS_OFF_*` (two-byte fields as `...+1`); rows/column/
    maxlen/dot/video/flag literals named.
  - inc5 `dapp.s`: `SCREENCODE_DASH`, `ROW_APP_HEADER/SLOT0`,
    `COL_APP_RANGE/SIZE/FLAGS`, `APP_NAME_WIDTH`, `APP_STRUCT_VERSION/
    SIZE`, `APP_MAX_SLOTS`, `APP_OFF_*`, `APP_FLAG_*`, `DOS_ERR_SLOT_EMPTY`.
    `DAPPPRINTFLAGS` label structure untouched (WP5).
  - inc6 `dvmm.s`: `ROW_VMM_*` (8), `VMM_BLOCK_COUNT`, `VMM_PATTERN_COUNT`,
    `VMM_ALLOC_PARAGRAPHS`, `VMMSTATE_*` (6), `VMMFAIL_*` (6). Every
    `VMMPAGESTATE`/`VMMFAILSTAGE` literal (read + write) named; DOS API
    codes, alloc-size `#<>`, sys-record reuse, loop bounds, rows/column/
    maxlen named. Pattern-index / parity literals and the `$66-$6C` OS
    VMM-param ZP block left as-is (shared ABI).
  - inc7 `dmain.s`/`ddata.s`: `DISPATCHPAGE` `CMP #3` -> `#PAGECOUNT`,
    resets -> `#PAGE_SYS`; new `VMM_BLOCK_SIZE`. `SYSINFOBUF`/`APPBUF`/
    `VMMBUFFER` `.RES` counts -> `SYS_STRUCT_SIZE`/`APP_STRUCT_SIZE`/
    `VMM_BLOCK_SIZE`. Stale "no equates" comment fixed. One `check_casm_
    source_bytes` catch fixed (lowercase `x` in a new comment).
  All 7 CASM sources pass `check_casm_source_bytes`. ca65 `dash_ref`
  byte-identical to `3238b786...` after every increment; all `.assert`
  pass throughout.
- 2026-09-01: **Increment 8 complete -- full native CASM + manifest.**
  First native run hit `CASM: EXPECTED NEWLINE` on
  `SYS_VMMFLAG_ACTIVE = 1<<0`: CASM's *named-constant-definition* parser
  rejects an operator in the RHS (operators are fine at instruction-
  operand use sites, per inc2). Fixed: all flag masks written as plain
  `1`/`2`/`4`/`8`. Also converted two `EXITAPP` operands missed earlier
  (`#$4C`/`JSR $1000` -> `#DOS_EXIT`/`JSR OS_API`). Re-ran: native CASM
  `V0.5.2.1404` P1/P2 `01728 STATEMENTS`, `04766 BYTES`, `INPUT
  VALIDATED` -- the `SYS_OFF_*+1` two-byte-field arithmetic, the enum
  constants, and `.RES SYS_STRUCT_SIZE`/`.RES APP_STRUCT_SIZE`/`.RES
  VMM_BLOCK_SIZE` all assemble clean. `COMP DW3.PRG DASH.REF` -> `FILES
  COMPARE OK`; extracted `DW3.PRG` `cmp`-identical to `dash_ref.prg` and
  the pre-WP3 bytes (3-way, all `3238b786...`). `dash.ref.hex`
  regenerated: byte payload untouched (only provenance + 7
  `source_sha256` lines), `--cross-check MATCHES`, no `--allow-host-bytes`.
  `dash` (`3238b786...`), full `cmake --build build`, and `image_d64`
  all green. Overlay `test`/`pass` fired.
- 2026-09-01: **WP3 source-complete.** AGENTS.md updated (ZP-map
  `.assert` note; "Expressions are bounded" -> constant-def RHS must be a
  bare literal; `.ASSERT` -> equality/range invariants are ca65-only).
  Walkthrough written. Parent plan Progress + `wiki/tasks/
  dash-modernization.md` synced. Awaiting user sign-off before WP4.
- 2026-09-01: **WP3 closed — user-approved.** Taskwarrior task 52 done.
