# Walkthrough: DASH-MOD WP5 - Frame / screen / renderer helper refactor

Plan: `brain/plans/2026-09-01-dash-mod-wp5-renderer-helper-refactor.md`
Parent: `brain/plans/2026-09-01-dash-modernization.md`
Taskwarrior: WP5 task 54 (child of `94ec17b3`)
Branch: `feature/casm-phase14`

## What this WP delivers

DASH's repeated renderer blocks collapse into shared helpers, and the
dead `PRINTAT` routine is removed -- every rendered screen
**pixel-identical**. Second byte-changing WP.

| | before WP5 | after WP5 |
| --- | --- | --- |
| shipping sha256 | `08f8f7ce...` | `4a49612e...` |
| PRG size | 4713 bytes | **4579 bytes** (-134) |
| code bytes | 3787 | 3669 (-118) |
| relocation entries | 459 | 443 (-16) |
| P1/P2 statements | 1719 | 1659 |

### Changes

- **`dscr.s` `COPYFRAMEROW`** -- the 7 near-identical 40-byte row-copy
  loops (`ROW0LOOP`..`ROW23LOOP`, 7 global labels) collapse to one helper
  (dest row in A, source pointer in X/Y; screen destination via the
  existing `COMPUTEROWADDR`, source via `(ptr),Y`) called 7 times from
  `DRAWFRAME`. Rows/order unchanged: 0/1/2/3/21/22/23 with
  `BORDERROW`/`TITLEROW`/`TABSROW`/.../`STATUSROW`.
- **`dapp.s` `DAPPPRINTFLAGS`** -- the 4 inline U/R/V/S cells
  (`DAPPF{U,R,V,S}_{OFF,PRINT}`, 8 labels) -> one `LDX #0 .. CPX
  #APP_FLAG_COUNT` loop over parallel `APPFLAGMASKS` / `APPFLAGCHARS`
  tables (`ddata.s`). Drops the `PHA`/`PLA` juggling -- `SCREENPUTCHAR`
  preserves X, now the loop index.
- **`dfmt.s` `PRINTAT` removed** -- dead code (no `JSR` anywhere, not in
  `PAGEROUTINETABLE`; only a `dsys.s` comment mentioned it). Routine + 4
  labels gone.
- **`dsys.s` `DSYSLABEL`** -- the 12 identical `LDA #row / JSR DSYSSETROW
  / LDA #cols / LDX/LDY <label> / JSR SCREENPUTSTRING` System-page row
  openers -> `LDA #row / LDX/LDY <label> / JSR DSYSLABEL`.
- New `dmain.s` constants: `ROW_FRAME_TOP/TITLE/TABS/TABSEP/MIDSEP/
  STATUS/BOTTOM`, `APP_FLAG_COUNT = 4`. `ddata.s`: `APPFLAGMASKS` /
  `APPFLAGCHARS` tables.

### `dvmm.s` survey (increment 6 -- no code change)

Metrics: 8 `LDA #COL_CONTENT / LDY #<row> / JSR SCREENSETCURSOR`
cursor-openers; 19 `LDA #SCREEN_COLS / ... / JSR SCREENPUTSTRING` string
prints; 20 `CMP #VMMSTATE_* / #VMMFAIL_*` enum compares across the
status-word / fail-stage / instruction-line ladders.

**Findings (recorded, not acted on -- per the WP5 scope decision):**
1. A `DVMMLABEL` helper (mirroring `DSYSLABEL`) would collapse the 8
   openers -- a clean ~25-30 byte win.
2. The 3 enum -> string `CMP/BEQ/set-ptr/JMP` ladders (status: 6 states,
   stage: 6, instruction: 3) could each become a `.WORD` pointer table
   indexed by the contiguous `0..N` enum value with one bounds check --
   ~-80 bytes and much flatter, but it rewrites the capability-gated
   display selection this WP was told to leave alone.
3. A `DVMMPUTLINE` tail helper is byte-neutral (adds a JSR/RTS) -- skip.

**Recommendation:** #1 + #2 as a small dedicated follow-up (a "WP5b" or a
post-WP6 item), not folded into WP5.

### Deferred (explicitly, not forgotten)

- `dvmm.s` refactor (above).
- The `dsys.s` video/vmm string branches that set X/Y then `JMP @PRINT`
  (cursor already positioned) -- a `DSYSPUTLINE` was judged not worth it.
- Anonymous labels (`:+`/`:-`) -- no CASM equivalent.
- The `$3400`/`$5000`/`$9000` **user** hardware runtime matrix -> WP6.

## Behaviour preservation

Full analysis in the plan. Key points:

- **`COPYFRAMEROW`** copies the same 40 source bytes into the same 40
  destination cells (`$0400 + N*40 .. +39`) in the same order.
  `COMPUTEROWADDR` is the exact row-address routine `SCREENPUTCHAR` and
  `DRAWMIDROWS` already use; `CURRENTROW` / `STRINGSRCPTR` are free in
  `DRAWFRAME` (no string primitive runs between the 7 calls, and
  `DRAWMIDROWS` re-initialises `CURRENTROW` right after).
- **`DAPPPRINTFLAGS`** loops `USED/RUNNING/REU/STACK` (`{1,2,4,8}`) with
  chars `{$15,$12,$16,$13}` = `U R V S` -- same cells, same order, same
  letter-if-set-else-`-` rule. `APPBUF+APP_OFF_FLAGS` is stable for the
  row render, so re-reading it each pass == the stacked copy.
- **`DSYSLABEL`** parks the label pointer across `DSYSSETROW`'s Y clobber
  (X/ptr-low is preserved); identical effect to the inline sequence.
- **`PRINTAT`** is unreachable; removing it changes no live code path.

## Verification

### ca65 <-> native CASM byte-identity

- Every increment: `check_casm_source_bytes.py` clean; `dash_ref` (ca65)
  builds; all 21 `.assert`s pass; `reloc.py` clean.
- **Native CASM under VICE** (`CASM V0.5.2.1404`, 16MB REU): fresh
  `command64_casm_utils_d64`, `CASM DMAIN.S /O:DW5.PRG` -> `P1/P2 01659
  STATEMENTS`, `04579 BYTES`, `INPUT VALIDATED`. `COMP DW5.PRG DASH.REF`
  -> **`FILES COMPARE OK`**. Extracted `DW5.PRG` `cmp`-identical to
  `build/dash_ref.prg` (4579 bytes) -- ca65 and native CASM produce the
  identical refactored binary, relocation table included.

### Manifest re-baseline

`build_dash_manifest.py <native DW5.PRG> --cross-check
build/dash_ref.prg` rewrote `dash.ref.hex`: **4713 -> 4579 bytes, sha256
`08f8f7ce...` -> `4a49612e...`**, `cross-check: MATCHES dash_ref.prg
byte-for-byte`, fresh `source_sha256`, **no `--allow-host-bytes`**.
`dash` CMake target rebuilt `dash.prg` at `4a49612e...` (== native);
full `cmake --build build` + `image_d64` green.

### Runtime pass (agent, VICE)

DASH run from the Command64 shell -- loaded at **$3800** (System page
`USER RANGE: $3800-$BFFF`), relocated from its `$3400` build base. All
checks via screen-RAM decode:

| Action | Observed |
| --- | --- |
| launch | Frame: top/tab-sep/mid-sep/bottom borders + corners; title `command 64 system dashboard`; tab bar; status bar `f1/f3/f5 page  r refresh  q quit`; version banner `dash v0.1.4` -- all pixel-identical. System body: os ver 0.4.1, device 8, video PAL, range `$3800-$BFFF`, protected `$C000-$CFFF`, vmm active/reu unprobed, page size 4096, totals 4096, used/free 3712/384, apps 8/16 |
| F3 | Applications: header + slot 0 `dash  3800-4654  0e55  u---` -- **flag column `u---`** (table-driven `DAPPPRINTFLAGS`, identical to pre-WP5) |
| F5 | VMM Test: `status: ready` |
| `T` | test runs -> `status: PASSED`, `pattern: 3 / 3`, `allocation seg: $02 bank: $00` |
| `R` | redraw -- VMM page persists |
| F1 | System page re-renders |
| `Q` | clean exit to `c64[8]:>`; `flush` -> `DR 8 STATUS: 00, OK` -- shell responsive |

The range / size / used-free **numbers** differ from earlier WPs only
because DASH itself is now 134 bytes smaller (its own load range) and the
OS's live VMM page split varies between boots -- the layout, field order,
format and glyphs are byte-identical. No render difference.

### Relocation audit

`AGENTS.md`'s Verification-section rules still hold: `.WORD` renderer
pointers, absolute label operands and `#>label` high bytes get entries;
`$1000` (`OS_API`), `$FFE4` (`KERNAL_GETIN`), screen/colour RAM and ZP
`$70-$8F` do not. The new `COPYFRAMEROW` uses `(ptr),Y` (ZP indirect, no
entry); `DAPPPRINTFLAGS` / the `dsys.s` openers use `#<label` (excluded)
+ `#>label` (entry). Net -16 entries (459 -> 443), all accounted for by
the removed inline `LDA label,X` operands and `PRINTAT`.

## Build evidence

- `dash_ref`, `dash`, `command64_casm_utils_d64`, `image_d64`, full
  `cmake --build build` all clean.
- `casm.prg` unchanged.
- `check_casm_source_bytes.py` clean on all 7 shipped sources (two
  lowercase-comment slips caught and fixed during implementation).

## AGENTS.md

Added a "Renderer helpers" entry (`COPYFRAMEROW`, `DSYSLABEL`,
table-driven `DAPPPRINTFLAGS`, `PRINTAT` removed, the `dvmm.s` survey
note). Full rewrite still WP6.

## Sign-off requested

WP5 is complete and verified: `DRAWFRAME` -> `COPYFRAMEROW`,
`DAPPPRINTFLAGS` -> table loop, `DSYSLABEL` extracted, dead `PRINTAT`
removed, `dvmm.s` surveyed. Rendering pixel-identical (live-verified at
`$3800`), ca65 == native CASM byte-for-byte (4579 bytes, `4a49612e...`),
manifest re-baselined, full build green, **net -134 shipped bytes** and
-30 global labels. Requesting approval to close WP5 and proceed to WP6
(consolidated gate + re-baseline + relocation audit + AGENTS.md rewrite
+ CHANGELOG + DASH version bump + **user runtime sign-off** -- needs its
own detailed sub-plan).
