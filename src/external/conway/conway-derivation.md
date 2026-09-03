---
title: CONWAY — independent byte + R6 relocation derivation record
date: 2026-09-03
status: reviewed and approved (user, 2026-09-03)
oracle-class: Native application manifest (+ R6 PRG)
manifest: src/external/conway/conway.ref.hex
plan: brain/plans/2026-09-03-conway-casm-native-migration.md
---

# CONWAY — Canonical Byte / R6 Derivation

Per `.agents/workflows/canonical-byte-oracles.md`. This record is the
correctness oracle for `src/external/conway/conway.ref.hex`; the manifest
itself is only the shipped artifact + stale-source guard.

CONWAY is the program's first **multi-module** migration (two ca65 objects
flattened into one CASM `.INCLUDE` chain) and its first with **screen-code
text data** and **page-aligned emitted storage**.

## Artifact under derivation

- Native CASM output `CNW.PRG`, **4660 bytes**, load `$3400`.
- SHA-256 `2fc65181a1e4aa1eba01b6d9362a596b6c951e33e427e74b8af63ccc0f055182`.
- Produced by native CASM `0.6.2` build `1419` on Command 64 under VICE
  3.10, `CASM CONWAY.S /O:CNW.PRG` from the SEQ sources on a dedicated
  assembly disk; extracted with `cc1541 -X`.
- `P1 DONE 01143`, `P2 DONE 01143`, `04660 BYTES`, `CASM: INPUT VALIDATED`.
- Program image `$3400..$44BF` (**4288 bytes**) + **182**-entry R6 table
  (364 bytes) + 6-byte footer (`<base $3400><count 182>` + `"R6"`).

## Source identity (all under `src/external/conway/`)

| File | Role | SHA-256 |
| --- | --- | --- |
| `conway.s` | entry module, constants inline | `2be1373359e9e56c8e64cbc3fe34b1399623b3e1f2d08f606f5f5b2217cfd548` |
| `conwaygrid.s` | grid/draw half, `.INCLUDE`d last | `b953f845bf3cf4006bbf2af3108e9f08ed14e46a7260a83d172071cb505b0560` |
| `CONWAY_VERSION` | app version `0.4.1` → generated `conwayver.s` | `f62184cee8787f2f6941c82041a5725d4edc9aa293ebe5dbf664406e82ec1fe1` |
| `BUILD_CONWAY` | build counter `1063` → generated `conwayver.s` | `11fea490858bcefc4afb526c76dba4af24bcaca54174f651515cc867eb58738d` |
| `conwayver.s` (generated, not checked in) | `EXITBANNER` + `MENUVERSION` | `915e1a90d96d2eedf16c2031ad96608459830bfc824ab47783660a4a952e2695` |
| `conwaymenu.s` (generated, not checked in) | screen-code menu/status data | `85a2626902eca61882c9f06e383fd01e73f54c9944bacd4740349adc37cc7201` |

## Layout ledger (CASM emits at `$3400`; verified against a `-g` label file
of the byte-identical independent build)

| Address | Contents |
| --- | --- |
| `$3400` | `START` (entry; 2-byte CBM load header precedes at file offset 0) |
| `$3444` | `MAINLOOP` |
| `$3531` | `EXITTOSHELL` |
| `$3577` | `DRAWMENU` … menu render routines |
| `$36E8` | `MENUDESCRIPTORS` (18×`.WORD src,dst` + `0,0`), `MENUARROWLO/HI` |
| `$3746` | `EXITBANNER` (from `conwayver.s`) — `C3 CF CE D7 C1 D9 20 56` + `"0.4.1.1063"` + `0D 00` |
| `$375A` | `MENUVERSION` — `"0.4.1.1063"` (10 bytes, no terminator) |
| `$3764` | `conwaymenu.s`: `MENUTITLE` … 22 screen-code strings … |
| `$3945` | `STATUSTEXT` (40 bytes) + `STATUSTEXTEND` |
| `$396D` | `conwaygrid.s` code: `RANDOMIZEGRID` … |
| `$3A31` | `COMPUTENEXT` |
| `$3C19` | `DRAWSIMULATIONSTATUS` … draw/convert routines |
| `$3CA7` | `PRESETBIRTHMASKS` / `PRESETSURVIVALMASKS` (36 bytes), read-only tables |
| `$3CCB` | `RULEBIRTH` (`.RES 9,0`), `RULESURVIVAL`, `RULEMASKSCRATCH`, `TEMPVALLO/HI` |
| `$3CE0` | `DIGITBUF` (`.RES 5,0`) — ends `$3CE4` |
| `$3CE5`→`$3D00` | `.ALIGN 256` padding (27 bytes) |
| `$3D00` | **`GRID0`** (`.RES 960,0`) — page-aligned; ends `$40BF` |
| `$40C0`→`$4100` | `.ALIGN 256` padding (64 bytes) |
| `$4100` | **`GRID1`** (`.RES 960,0`) — page-aligned; ends `$44BF` |

Image end `$44BF`; total image 4288 bytes. **This matches the Increment-1
prediction exactly** (`$3400..$44BF`, ≈ 187 bytes below the retired ca65
`$3800` build because the ca65 object-file boundary `.align 256` gap has no
equivalent after a textual `.INCLUDE`; `GRID0`/`GRID1` alignment is instead
guaranteed by their explicit `.ALIGN 256`).

## Independent code/data byte derivation

The full 4288-byte opcode/operand/data stream is corroborated
**independently of CASM** by an **independent ca65/ld65 assembly of the
same four sources, linked at the same `$3400` base**. The transform (a
scriptable, line-by-line-reviewable pass — `scripts` were run ad hoc, not
committed, per Scoping Decision 4):

- the three `.INCLUDE "…"` lines are replaced by the referenced file text
  (identical to what native CASM's `.INCLUDE` does);
- `LSR A` / `ASL A` / `ROL A` → ca65's `lsr a` / `asl a` / `rol a` spelling
  (same opcode);
- a `.segment "HEAD" / .word $3400` + `.segment "CODE"` wrapper and a
  `$3400` linker config are prepended (CASM's implicit origin + load
  header).

ca65 `@local` labels, `.BYTE`/`.WORD` operand lists, paren + `<`/`>`
expressions, `LABEL + 1` operand arithmetic, and `.RES n, 0` are all
accepted verbatim by both assemblers, which still select opcodes,
addressing modes, and branch displacements independently.

**Result: 0 byte differences across all 4288 image bytes.**
(`conway_ref.prg` image SHA-256 of the 4288-byte body matches `CNW.PRG`'s
4288-byte image body.)

### Screen-code transform (the one mechanical text transform)

`conwaymenu.s` is generated by `scripts/gen_conway_menu.py` from a 23-entry
ASCII string table. Transform, identical to the retired ca65
`include/ca65/screencode.inc` `.CHARMAP`:

- `$20`–`$3F` → identity (space, digits, punctuation)
- `$61`–`$7A` → `b − $60` (`a`→`$01` … `z`→`$1A`)
- anything else → hard error

Spot-verified against the retired ca65 `build/conway.prg`:
`MENUTITLE` = `03 0F 0E 17 01 19 20 0D 15 0C 14 09 16 05 12 13 05`
("conway multiverse"), `STATUSTEXT` = `13 10 3A 10 01 15 13 05 20 12 3A 12
0E 04 …`, `MENUPRESET7`, `MENUNONETEXT` — all identical to the ca65
charmap output. **The on-screen text is byte-preserved**; only the *source*
representation changed (`.CHARMAP` macro → explicit `.BYTE`).

### Version data

`EXITBANNER` and `MENUVERSION` (`scripts/gen_conway_version.py`) reproduce
the retired ca65 bytes **exactly** — `build/conway.prg` offset `$3AE7` =
`C3 CF CE D7 C1 D9 20 56 30 2E 34 2E 31 2E 31 30 36 33 0D 00`, offset
`$3D37` = `30 2E 34 2E 31 2E 31 30 36 33`. No visual change (CONWAY's
banner already used a lowercase `v` = `$56`).

## R6 relocation ledger

- **182 entries**, strictly ascending, unique, offsets `$0018`–`$089D`
  (all `< $10C0`, the image length).
- Every entry points at an in-image high byte (pages `$34`–`$3D`, `$41`).
- Composition: **≈ 159 absolute operands / `.WORD` pointer-table high
  bytes + ≈ 23 `#>LABEL` high-byte immediates = 182.** Fixed addresses
  (`SCREEN`/`COLORRAM`/`VIC_*`/`JIFFY_CLK`/KERNAL/`OS_API`) and `#<LABEL`
  low-byte immediates get **no** entry, as expected.
- **This is exactly the retired ca65 build's relocation count (182 —
  `tools/reloc.py` on the `$3800`/`$3900` pair).** The initial CASM run
  emitted 186; four spurious entries were traced to named constants
  (`MENU_NONE_LEN`, `MENU_VERSION_LEN`) defined in an `.INCLUDE'd` file
  being treated as relocatable (CASM 0.6.2 defect, same family as
  `project-casm-included-constant-zp-absolute` / Taskwarrior 42). Moving
  those three text-length constants inline into `conway.s` removed all
  four; no CASM change.
- `scripts/casm_r6_verify.py CNW.PRG` → **PASS**, including clean
  relocation to `$3800` (+4 pages), `$5000` (+28), `$9000` (+92); `GRID0`
  (`$3D00`) and `GRID1` (`$4100`) remain page-aligned at every base.

## Live functional evidence (VICE 3.10, dispatched `conway` from the
Command 64 shell; relocated to `UserProgStart` by `sdExt`)

| Check | Result |
| --- | --- |
| Menu renders | Title "conway multiverse", rule underline, 9 presets with `bN/sN` columns, "current rule" birth `3` / survival `23`, 3 control lines, prompt "q:exit to shell", "0.4.1.1063" right-aligned row 23 — **all screen-code text correct** |
| Preset arrow | `>` at preset 1 initially |
| Key `7` | arrow → preset 7; birth summary `3`, survival summary `012345678` (life-without-death S0-8) |
| `RETURN` | simulation starts; grid drawn (`$A0`/`$20` cells); status row "sp:pause r:rnd c:clear q:menu  gen:NNNNN"; generation counter advances (observed `00433`) |
| `Q` (sim) | returns to menu, menu redrawn |
| `Q` (menu) | screen cleared, "CONWAY v0.4.1.1063" printed, **clean return to `c64[8]:>`** |

Not yet exercised (byte-identical to the corroborated reference; deferred
to the completion-gate sweep): B/S rule edit, `R` random-start, `SPACE`
pause + colour, `R`/`C` in-sim, RUN/STOP key.

## Reviewer reproduction checklist

1. `sha256sum` the six source files above.
2. Regenerate `conwayver.s` / `conwaymenu.s`; confirm hashes.
3. Independent ca65 `$3400` build of the four sources (transform above) →
   compare the 4288-byte image body to `CNW.PRG`'s → expect 0 diff.
4. `casm_r6_verify.py CNW.PRG` → PASS; footer `base $3400 count 182 'R6'`.
5. Confirm `GRID0` = `$3D00`, `GRID1` = `$4100` from a `-g` label file.
6. Live `COMP CNW.PRG CONWAY.REF` on the C64 → `FILES COMPARE OK`
   (Increment 4).
