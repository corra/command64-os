# Walkthrough: DASH-MOD WP4 - Event loop / key dispatch / page dispatch refactor

Plan: `brain/plans/2026-09-01-dash-mod-wp4-event-loop-dispatch-refactor.md`
Parent: `brain/plans/2026-09-01-dash-modernization.md`
Taskwarrior: WP4 task 53 (child of `94ec17b3`)
Branch: `feature/casm-phase14`

## What this WP delivers

The duplication in `dmain.s`'s event loop is gone, with **DASH's
observable behaviour unchanged**. This is the **first WP to change DASH's
shipped bytes** since Phase 14 WP91.

| | before WP4 | after WP4 |
| --- | --- | --- |
| shipping sha256 | `3238b786...` | `08f8f7ce...` |
| PRG size | 4766 bytes | **4713 bytes** (-53) |
| code bytes | 3828 | 3787 (-41) |
| relocation entries | 465 | 459 (-6) |
| P1/P2 statements | 1728 | 1719 |

### Changes (`dmain.s`, `START`..`DISPATCHPAGE`)

- **`MARKREDRAW`** (`LDA #1 / STA NEEDREDRAW / RTS`) -- one helper for the
  five sites that previously inlined the redraw request (`START`, the
  page select, `TRYRUNVMMTEST`, `SETREDRAW`).
- **F1/F3/F5 -> page select, computed.** `SELECTSYS` / `SELECTAPP` /
  `SELECTVMM` (three near-identical blocks) are deleted. The function
  keys are consecutive (`$85`/`$86`/`$87`) and map 1:1 onto page indices,
  so: `CPX #KEY_F1` / `CPX #(KEY_F1 + PAGECOUNT)` range-check, then
  `SEC / SBC #KEY_F1` yields the page index directly into one select
  path.
- **`T`/`R`/`Q` case-fold.** Each key had two `CPX #k / BEQ` pairs (the
  unshifted `$54`/`$52`/`$51` and the shifted/lowercase-charset
  `$74`/`$72`/`$71`, differing only in bit 5). Now: `TXA / AND
  #KEY_CASE_MASK / TAX` folds bit 5, then one compare each.
- `JSR $FFE4` -> `JSR KERNAL_GETIN`; `TRYRUNVMMTEST`'s `CMP #2` ->
  `CMP #PAGE_VMM` (with a `@IGNORE` local for the off-page path);
  `DISPATCHPAGE`'s `ASL A` documented against `PAGE_ROUTINE_ENTRY_SIZE`.
- **New `dmain.s` constants:** `PAGE_ROUTINE_ENTRY_SIZE = 2`,
  `KERNAL_GETIN = $FFE4`, `KEY_F1 = $85`, `KEY_CASE_MASK = $DF`,
  `KEY_T = $54`, `KEY_R = $52`, `KEY_Q = $51` (the WP3-deferred key
  literals).
- **`dash_wrapper.s`:** 5 new ca65-only `.assert`s
  (`PAGE_ROUTINE_ENTRY_SIZE = 2`; `KEY_F1 + PAGECOUNT <= $88`; each
  `KEY_x` is already in case-folded form) -- 21 assertions total.

### Deferred (explicitly, not forgotten)

- Renderer helpers -- `DRAWFRAME`'s 7 row loops, `DAPPPRINTFLAGS` -> WP5.
- Key->action jump table (user chose computed-no-table: smaller,
  idiomatic, no second trampoline mechanism).
- Anonymous labels (`:+`/`:-`) -- no CASM equivalent.
- The exhaustive `$3400`/`$5000`/`$9000` **user** hardware runtime matrix
  -> WP6's consolidated gate.

## Behaviour preservation

Full input -> effect table (in the plan). Every current input produces
the identical effect:

- `$85`/`$86`/`$87` -> pages 0/1/2 + redraw (identical indices).
- `$54`/`$74` -> `TRYRUNVMMTEST`; `$52`/`$72` -> `SETREDRAW`;
  `$51`/`$71` -> `EXITAPP`.
- `$00` -> loop; F7 / shift-F7 / shift-letters / any other key ->
  ignored (fold matches nothing handled).

**Fold uniqueness:** `b AND $DF == $54` iff `b in {$54,$74}` (and
likewise for `$52`, `$51`) -- no third byte folds onto a handled code, so
no key gains a spurious action. Verified live (see below).

## Verification

### ca65 <-> native CASM byte-identity

- Every increment: `check_casm_source_bytes.py` clean; `dash_ref` (ca65)
  builds; all 21 `.assert`s pass; `reloc.py` clean.
- **Native CASM under VICE** (`CASM V0.5.2.1404`, 16MB REU): fresh
  `command64_casm_utils_d64`, `CASM DMAIN.S /O:DW4.PRG` -> `P1/P2 01719
  STATEMENTS`, `04713 BYTES`, `INPUT VALIDATED`. `COMP DW4.PRG DASH.REF`
  -> **`FILES COMPARE OK`**. Extracted `DW4.PRG` `cmp`-identical to
  `build/dash_ref.prg` (4713 bytes) -- ca65 and native CASM produce the
  identical refactored binary, including the relocation table.

### Manifest re-baseline

`build_dash_manifest.py <native DW4.PRG> --cross-check
build/dash_ref.prg` rewrote `dash.ref.hex`: **4766 -> 4713 bytes,
sha256 `3238b786...` -> `08f8f7ce...`**, `cross-check: MATCHES
dash_ref.prg byte-for-byte`, fresh `source_sha256`, **no
`--allow-host-bytes`**. `dash` CMake target rebuilt `dash.prg` at
`08f8f7ce...` (== native); full `cmake --build build` + `image_d64`
green.

### Runtime pass (agent, VICE)

DASH run from the Command64 shell (`dash`), which loads it at **$3800**
(System page shows `USER RANGE: $3800-$BFFF`) -- i.e. relocated from its
`$3400` build base, so this is a relocated-base run. All checks via
screen-RAM decode:

| Action | Observed |
| --- | --- |
| launch | System page: os ver 0.4.1, device 8, video PAL, user range `$3800-$BFFF`, protected `$C000-$CFFF`, vmm active / reu unprobed, page size 4096, totals 4096, used/free 3728/368, apps 8/16 |
| F3 | Applications page: header + slot 0 = `dash  3800-46ca  0ecb  u---` |
| F5 | VMM Test page: `status: ready` |
| `T` (`$54`) | test runs -> `status: PASSED`, `pattern: 3 / 3`, `allocation seg: $02 bank: $00` |
| `R` (`$52`) | redraw -- VMM page persists, re-renders |
| F1 | System page |
| lowercase `r` (`$72`) | folds -> redraw, System page persists (no crash, no page change) |
| lowercase `t` (`$74`) on System page | **ignored** -- T is VMM-page-only |
| `Q` (`$51`) | clean exit to `c64[8]:>`; `flush` -> `DR 8 STATUS: 00, OK` -- shell fully responsive |

Every binding behaves exactly as before the refactor. Overlay
`test`/`pass` fired.

## Build evidence

- `dash_ref`, `dash`, `command64_casm_utils_d64`, `image_d64`, full
  `cmake --build build` all clean.
- `casm.prg` unchanged (no CASM source touched).
- `check_casm_source_bytes.py` clean on all 7 shipped sources.

## AGENTS.md

Updated: "Event loop / key dispatch" entry added (computed F-key select,
`KEY_CASE_MASK` fold, `MARKREDRAW`, `T` page-gate); "Dispatch Trampoline"
entry rewritten to current form (`PAGECOUNT` validate,
`PAGE_ROUTINE_ENTRY_SIZE` index, `@RETURNMINUSONE`/`@RETURN`); "Exit
Procedure" `JSR $1000` -> `JSR OS_API`. Full rewrite still WP6.

## Runtime note

Runtime **was** re-verified this WP (first byte-changing WP) -- agent
pass above. The exhaustive multi-address user matrix
(`$3400`/`$5000`/`$9000`) is WP6.

## Sign-off requested

WP4 is complete and verified: `dmain.s` event loop / key dispatch / page
select refactored, behaviour identical (live-verified at the `$3800`
relocated base), ca65 == native CASM byte-for-byte (4713 bytes,
`08f8f7ce...`), manifest re-baselined, full build green, all deferred
sets listed. Requesting approval to close WP4 and proceed to WP5
(frame / renderer helper refactor -- needs its own detailed sub-plan).
