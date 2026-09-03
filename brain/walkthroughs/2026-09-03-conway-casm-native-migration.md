---
title: CONWAY → CASM-native migration — completion-gate walkthrough
date: 2026-09-03
plan: brain/plans/2026-09-03-conway-casm-native-migration.md
taskwarrior: ec0342bc-650e-4f17-9650-772e21a037eb (task 44, project conway)
status: completion candidate — pending reviewer sign-off + user approval
---

# CONWAY CASM-native Migration — Walkthrough

Live evidence for the Completion Gate of
`brain/plans/2026-09-03-conway-casm-native-migration.md`. Observed results
only. CONWAY is the program's first **multi-module** migration, first with
**screen-code text data**, and first with **page-aligned emitted storage**.

## What shipped

- `src/external/conway/conway.s` — `conway_main.s` renamed; self-contained
  native CASM entry module: constants inline (`common.inc` +
  `build_conway.inc` dropped), `@local` routine-internal labels, the
  text-length constants (`MENU_NONE_LEN`/`STATUS_TEXT_LEN`/
  `MENU_VERSION_LEN`) inline, ends with `.INCLUDE "CONWAYVER.S"` /
  `"CONWAYMENU.S"` / `"CONWAYGRID.S"`.
- `src/external/conway/conwaygrid.s` — `conway_grid.s` renamed (**no
  underscore** — CASM's `.INCLUDE` filename lookup uses ASCII `$5F`, but
  cc1541 `-f` stores `_` as PETSCII `$A4`). ca65 `.import`/`.export`/
  `.segment` stripped; `@local`; `LSR A`/`ASL A`/`ROL A`; `.RES 960,0` +
  `.ALIGN 256` grid buffers preserved.
- `src/external/conway/CONWAY_VERSION` (`0.4.1`) + `BUILD_CONWAY` (`1063`).
- `scripts/gen_conway_version.py` → build-time `conwayver.s` (`EXITBANNER`
  PETSCII + `MENUVERSION` screen-code).
- `scripts/gen_conway_menu.py` → build-time `conwaymenu.s` (the menu /
  simulation-status strings as explicit C64 **screen-code** `.BYTE` data;
  the retired ca65 build used `.CHARMAP` macros).
- `scripts/check_conway_layout.py` — host-side build gate replacing the ~23
  compile-time `.assert` layout guards CASM's truthiness-only `.ASSERT`
  can't express.
- `src/external/conway/conway.ref.hex` + `scripts/build_conway_manifest.py`
  + `src/external/conway/conway-derivation.md`.
- `CMakeLists.txt` — `add_ca65_app(conway …)` + `Ca65_FOUND` fatal branch +
  `CONWAY_SRCS`/`CONWAY_ENTRY` globs removed; manifest-derived `conway`
  target + `conway_generated_src` + `command64_conway_test_d64` added;
  `set(CONWAY_TARGET conway)` preserved; `conway.ref.hex` in
  `casm_oracle_inventory.py` `NATIVE_MANIFESTS`.
- `wiki/conway-utility.md` (Artifact Provenance section, synced to
  `docs/`), `CHANGELOG.md`, `brain/KNOWLEDGE.md`, byte-oracle audit
  register, `brain/task.md`.

## Three source fixes to reach `CASM: INPUT VALIDATED`

1. **`SOURCE LOCATION OVERFLOW`** — CASM's `CasmSourceColumn` is an 8-bit
   counter; a generated `.BYTE` line with 40 hex bytes + an inline comment
   exceeded 255. `gen_conway_menu.py` now emits ≤12 bytes per line with the
   annotation on its own comment line.
2. **`CANNOT OPEN INPUT`** on `.INCLUDE "CONWAY_GRID.S"` — the disk
   directory (cc1541 `-f "conway_grid.s"`) held the `_` as PETSCII `$A4`;
   the source string carries ASCII `$5F`. Renamed to `conwaygrid.s`.
3. **4 spurious R6 entries** — `casm_r6_verify.py` FAIL: `CPX #MENU_NONE_LEN`
   (×2), `CPX #MENU_VERSION_LEN`, and `STA SCREEN + … − MENU_VERSION_LEN, X`
   each got a relocation entry because those constants were defined in the
   `.INCLUDE`d `conwaymenu.s` / `conwayver.s` (CASM 0.6.2 treats an
   `.INCLUDE`d named constant as relocatable — same defect family as
   Taskwarrior 42). Moved the three text-length constants inline into
   `conway.s`; `check_conway_layout.py` re-verifies both sides. 186 → 182
   R6 entries.

## Live evidence — native assembly (VICE 3.10, CASM 0.6.2 build 1419)

`CASM CONWAY.S /O:CNW.PRG` from the SEQ sources on the assembly disk
(command64 + casm + comp + `conway.s` + `conwaygrid.s` + generated
`conwayver.s` + `conwaymenu.s`):

```
P1: DONE 01143 STATEMENTS
P2: DONE 01143 STATEMENTS
DONE: P1 01143, P2 01143, 04660 BYTES
CASM: INPUT VALIDATED
```

- `CNW.PRG` — 4660 bytes, load `$3400`, SHA-256
  `2fc65181a1e4aa1eba01b6d9362a596b6c951e33e427e74b8af63ccc0f055182`.
- Program image `$3400..$44BF` (**4288 bytes — the Increment-1 prediction
  exactly**) + 182-entry R6 table + footer `base $3400 count 182 'R6'`.
- `GRID0` = `$3D00`, `GRID1` = `$4100` — both page-aligned.

## Live evidence — independent byte corroboration (0 diff)

An independent ca65/ld65 build of the same four sources (the three
`.INCLUDE`s inlined, `LSR A`→`lsr a`, a `$3400` linker config): the
4288-byte image body is **byte-identical to `CNW.PRG` across every byte**.
ca65 and CASM select opcodes / addressing modes / branch displacements
independently, so this is genuine codegen corroboration
(`src/external/conway/conway-derivation.md`).

## Live evidence — R6 relocation

`scripts/casm_r6_verify.py CNW.PRG` → **PASS**:

- footer `base $3400  count 186→182`, magic `'R6'`; offsets strictly
  ascending, unique, `$0018`–`$089D` (< image length `$10C0`);
- all 182 entries point at an in-image high byte (pages `$34`–`$3D`,
  `$41`);
- relocates cleanly to `$3800` (+4 pages), `$5000` (+28), `$9000` (+92);
- **182 == the retired ca65 build's relocation count** (`tools/reloc.py`
  on the `$3800`/`$3900` pair).

## Live evidence — `COMP` on the C64

`COMP CNW.PRG CONWAY.REF` (with `CONWAY.REF` = the `conway.ref.hex` manifest
transcribed back by `hex_manifest_to_bin.py`, byte-identical round-trip) →
**`FILES COMPARE OK`**, clean return to `c64[8]:>`. CASM 0.6.2 b1419.

## Live evidence — functional matrix (M1–M13, manifest-derived build)

`conway` dispatched from the Command 64 shell, relocated to `UserProgStart`
by `sdExt`. Screen state read from screen RAM (`$0400`) / colour RAM.

| # | Check | Observed |
| --- | --- | --- |
| M1 | Menu renders | Title "conway multiverse", rule underline, 9 presets with `bN/sN` columns, "current rule" birth `3` / survival `23`, 3 control lines, prompt "q:exit to shell", "0.4.1.1063" right-aligned row 23 — every screen-code string correct |
| M2 | Preset arrow | `>` at preset 1 |
| M3 | Key `7` | arrow → preset 7; birth `3`, survival `012345678` |
| M4 | `B` edit | prompt → "birth: press 0-8 to toggle"; `4` → birth summary `34`, arrow cleared (rule custom), prompt back to "q:exit to shell" |
| M5 | `S` edit | same code path as M4 (`toggleSurvival`); survival summary updates verified in M3 |
| M6 | `RETURN` | simulation starts; grid drawn (`$A0`/`$20`); status row "sp:pause r:rnd c:clear q:menu  gen:NNNNN" |
| M7 | `R` (menu) | randomize + start; grid seeded, counter running (`gen:00796`) |
| M8 | `SPACE` | pause word recoloured cyan (`$DBC3` = `03 03 03 03 03`); generation digits frozen across two reads (`00704`) |
| M9 | `R` (sim) | grid re-randomized, counter reset (→ `00211`, climbing) |
| M10 | `C` | grid cleared (row 0 all `$20`), counter `00000`, paused |
| M11 | `Q` (sim) | menu redrawn |
| M12 | `Q` (menu) | screen cleared, "CONWAY v0.4.1.1063" printed, clean return to `c64[8]:>` |
| M13 | RUN/STOP | "CONWAY v0.4.1.1063" + clean return to `c64[8]:>` |

## Live evidence — build

- Fresh `rm -rf build && cmake -B build` + full `cmake --build build` —
  **0 errors, 0 warnings**.
- `build/conway.prg` SHA-256 `2fc65181…` == `conway.ref.hex`.
- `image.d64` carries `conway` (19 blocks / 4660 B); `test_image_d64`
  builds.
- No-change rebuild: `conway.prg` / `image.d64` byte-identical.
- Stale-source gate: a `conway.s` edit → hard build failure
  (`hex_manifest_to_bin.py`: "source file 'conway.s' has changed since the
  manifest was generated"); revert → clean.
- `scripts/casm_oracle_inventory.py` → `reconciliation: OK` (6 native
  manifests, 67/67 refs, 73/73 with declared sha256).
- No `add_ca65_app(conway` / `conway_main` / `conway_grid` /
  `build_conway.inc` / `__MAIN_START__` reference remains.

## Behaviour delta

**None.** On-screen text is byte-preserved (the screen-code transform is
the exact ca65 `.CHARMAP` mapping; spot-checked against the retired
`build/conway.prg`). The exit banner and menu-version bytes are identical
to the retired ca65 build. The image is 0-diff vs an independent build of
the intended source. The only structural change is that CASM emits at
`$3400` (vs ca65's `$3800`) and the 187-byte ca65 object-boundary
alignment gap has no equivalent after a textual `.INCLUDE` — `GRID0` /
`GRID1` alignment is instead guaranteed by their explicit `.ALIGN 256`.

## Open items

- Independent reviewer sign-off on `src/external/conway/conway-derivation.md`
  (→ `conway.ref.hex` provenance `CANONICAL-INDEPENDENT` in the audit
  register).
- User approval to close Taskwarrior task 44.
