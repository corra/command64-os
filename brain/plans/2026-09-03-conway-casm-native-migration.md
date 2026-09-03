---
feature: conway-casm-native-migration
created: 2026-09-03
status: complete — user-approved 2026-09-03
taskwarrior: ec0342bc-650e-4f17-9650-772e21a037eb
depends-on: FORMAT CASM-native migration (complete, merged to main 2026-09-02, commit c6f7b11); COMP CASM-native migration (complete, merge 877019b)
---

# Plan: CONWAY — Migration to Native CASM (ca65 Retirement)

## Status

**COMPLETE — user-approved 2026-09-03.** Taskwarrior task
`ec0342bc-650e-4f17-9650-772e21a037eb` (project `conway`) closed;
`conway-derivation.md` reviewer-approved; `conway.ref.hex` provenance
`CANONICAL-INDEPENDENT`. CONWAY is CASM-native; ca65 retired. Each
increment gate was approved by the user in turn; the completion gate
(reviewer sign-off + task closure) approved 2026-09-03. `CASM: INPUT VALIDATED`; image
0-diff vs an independent `$3400` ca65 build; `casm_r6_verify` PASS (182
entries == ca65 baseline); live `COMP CNW.PRG CONWAY.REF` → `FILES COMPARE
OK`; functional matrix M1–M13 verified on the manifest-derived build;
fresh full build clean; docs + walkthrough + trackers synced. **Completion
Gate open:** (1) independent reviewer sign-off on `conway-derivation.md`,
(2) user approval to close task 44.

Stage 4 of the external-applications CASM-native migration
(`brain/reviews/2026-09-01-external-applications-casm-native-viability.md`,
which ranks CONWAY as "high viability; recommended first multi-module
migration"). It follows the completed LABEL pilot, FORMAT, and COMP. This
plan reuses their proven shape (`brain/plans/2026-09-02-format-casm-native-migration.md`,
`brain/plans/2026-09-02-comp-casm-native-migration.md`) and calls out only
where CONWAY differs. It is not a numbered CASM Phase or Work Package.

## Objective

Retire CONWAY's ca65/ld65 build and make CONWAY a CASM-native application:
assembled only by native CASM under Command64, shipped from a reviewed
hex manifest (`src/external/conway/conway.ref.hex`) bound to source hashes,
backed by an independent byte + R6 relocation derivation record.

CONWAY is the program's first **multi-module** migration (two ca65 object
files linked by ld65) and its first migration with **screen-code text
data** and **page-aligned emitted storage**.

Delivers:

1. `src/external/conway/conway.s` — native-CASM entry module: inline
   constants (folding `common.inc` + the used parts of `command64.inc`),
   main code, menu/simulation logic, `@local` labels, then
   `.INCLUDE "CONWAYVER.S"`, `.INCLUDE "CONWAYMENU.S"`, and
   `.INCLUDE "CONWAY_GRID.S"` at the end (Scoping Decision 1).
2. `src/external/conway/conway_grid.s` — native-CASM grid/draw half, ca65
   `.export`/`.import`/`.segment`/`.include` machinery stripped, `@local`
   labels, `.ALIGN 256` + `.RES 960, 0` grid buffers preserved.
3. `src/external/conway/CONWAY_VERSION` (`0.4.1`) + `BUILD_CONWAY` →
   `scripts/gen_conway_version.py` → `conwayver.s` (build product).
4. `scripts/gen_conway_menu.py` → `conwaymenu.s` (build product):
   mechanically transcribes the menu/status ASCII strings to explicit
   screen-code `.BYTE` data, replacing the ca65 `.CHARMAP`/`.MACRO`/
   `.REPEAT` machinery (Scoping Decision 2).
5. `scripts/check_conway_layout.py` — host-side build gate replacing the
   ~23 ca65 `.assert` layout guards CASM cannot express (Scoping
   Decision 3).
6. `src/external/conway/conway.ref.hex` + `scripts/build_conway_manifest.py`
   + `src/external/conway/conway-derivation.md`.
7. `CMakeLists.txt`: `add_ca65_app(conway …)` + its `Ca65_FOUND` fatal
   branch + the `CONWAY_SRCS`/`CONWAY_ENTRY` globs removed; manifest-derived
   `conway` target + `conwayver.s`/`conwaymenu.s` generator commands +
   `command64_conway_test_d64` added; `CONWAY_TARGET` still points at
   `conway` so `IMAGE_BASE_PRG_TARGETS` is unchanged.
8. `scripts/casm_oracle_inventory.py` — `conway.ref.hex` added to
   `NATIVE_MANIFESTS`.
9. `wiki/conway-utility.md` (Artifact Provenance section added), synced to
   `docs/`; `CHANGELOG.md`; `brain/KNOWLEDGE.md`; `brain/task.md`;
   `wiki/tasks/conway-multiverse.md`; byte-oracle audit register row.

**Does NOT deliver:** any change to CONWAY's simulation rules, presets,
menu layout, key bindings, generation counter, timing, screen colours, the
grid-swap scheme, or the exit-to-shell path. The on-screen text is
byte-preserved (Scoping Decision 2 changes *how* the screen-code bytes are
produced, not the bytes). No new CASM language features are requested; no
CASM fixes.

## Scoping Decisions (user-confirmed 2026-09-03)

1. **Module flattening: `.INCLUDE` chain, keep the split.** `conway.s`
   retains the constants and the `conway_main.s` body; it ends with
   `.INCLUDE "CONWAY_GRID.S"` (plus the two generated includes). Both files
   stay individually reviewable and are packaged as SEQ on the test disk.
   The ca65 `.import`/`.export` pairs are deleted — after textual inclusion
   every label is in one global namespace, exactly what the cross-module
   references already assume. `conway_main.s` is renamed to `conway.s`
   (the manifest/entry file); `conway_grid.s` keeps its name.

2. **Screen-code text: generated `.BYTE` include (`gen_conway_menu.py`).**
   *Recommended and adopted.* The menu, preset, control, prompt, and
   simulation-status strings are currently ca65 `.byte "…"` literals inside
   `screencode_mixed` / `petscii_mixed` `.CHARMAP` blocks
   (`include/ca65/screencode.inc`) that remap lowercase `a`–`z` → `$01`–`$1A`
   and pass `$20`–`$3F` through unchanged. CASM has **no** `.CHARMAP` /
   `.ENCODING` / `.MACRO` / `.REPEAT`, and its string literals emit raw
   bytes — unusable for screen memory. `scripts/gen_conway_menu.py` holds
   the ASCII strings in a clearly-labelled table (label → text, matching
   the current source symbol names), applies the exact documented transform
   (identity for `$20`–`$3F`; `c → c - $60` for `$61`–`$7A`; reject
   anything else), and emits `conwaymenu.s` with one `.BYTE` line per
   string plus its `…END` label and a trailing `; "ascii"` comment. The
   transform and a full byte enumeration go in `conway-derivation.md`.
   Rejected alternative — hand-baking ~30 `.BYTE` blocks directly into
   `conway.s` — is more error-prone to review and mixes generated-looking
   data into the hand-written module.

3. **The ~23 `.assert` layout guards → `scripts/check_conway_layout.py`
   build gate.** CASM `.ASSERT` is truthiness-only with a bare expression
   and no `<=` / `<>` operators
   (`reference-casm-constant-rhs-and-assert-operator-limits`), so guards
   like `.assert 4 + (menuPreset1End - menuPreset1) <= 40` cannot be
   expressed. `check_conway_layout.py` recomputes every invariant
   (row-crossing checks for all 20 menu descriptors, the 40-column status
   row, `STATUS_TEXT_LEN = 40`, `GEN_DIGITS_OFFSET + 5 = 1000`, the birth/
   survival field bounds, the pause-colour field bound, the menu-version
   column/overlap/screen-crossing checks) from `conwaymenu.s` +
   `common.inc`'s successors in `conway.s` and fails the build on any
   violation. It runs PRE_BUILD on `command64_conway_test_d64` and in the
   full-build verification. Kept permanently, off-target.

4. **No ca65 differential kept; no transformed-copy reference.** The
   correctness oracle is `conway-derivation.md` + live `COMP` +
   `casm_r6_verify.py`, as COMP's migration did. No `conway_ref` target, no
   dual-assembler source restriction. A one-time, non-committed ca65 build
   of the frozen pre-migration source may be used in Increment 4 only as
   post-derivation differential evidence (structural, at the same base).

5. **App-specific tooling twins.** `gen_conway_version.py` and
   `build_conway_manifest.py` are parameterised copies of LABEL's/FORMAT's.
   `gen_conway_menu.py` and `check_conway_layout.py` are new and
   CONWAY-specific. Generalising any of these into shared tooling is
   deferred to a separate cleanup once 4–5 CASM-native apps exist.

6. **ca65 retired in this same plan** (like LABEL / FORMAT / COMP) — the
   CASM-native syntax is only unconditionally safe once ca65 no longer
   compiles the sources.

7. **Use CASM features where byte behaviour stays explicit and
   reviewable** (as LABEL/FORMAT/COMP): inline named constants; `@local`
   for every routine-internal branch target (routine entry points and
   cross-routine `JMP` targets stay global — see Technical Notes);
   `.RES count, 0` for the rule tables, digit buffers, and the two grid
   buffers; `.ALIGN 256` for grid alignment. No character/string literals
   in `conway.s` itself (all its text is screen-code data via
   `conwaymenu.s`; `exitBanner` is PETSCII and moves to `gen_conway_version.py`
   output alongside the banner). `.IF` / `.ASSERT` have no useful site
   (Decision 3 moves the checks host-side).

8. **Verification bar: live VICE, no hardware.** Dispatch CONWAY from the
   Command64 shell; verify the menu renders correctly (screenshot the
   screen-code text), each preset 1–9 selects and updates the birth/
   survival summary + arrow, `B`/`S` edit toggles a neighbour count and
   marks the rule custom, `RETURN`/`R` start the simulation, the
   generation counter advances and the status row reads correctly, `SPACE`
   pauses (pause word recolours), `C` clears, `Q` and RUN/STOP return
   cleanly to `C64[8]:>`. Plus the LABEL/COMP bar: byte-exact to the
   derivation, no-change rebuild identical, live `COMP CNW.PRG CONWAY.REF`
   → `FILES COMPARE OK`, `casm_r6_verify.py` PASS at `$3400` + two other
   bases. Grid page-alignment verified by reading the relocated buffer
   addresses under VICE.

## Prepared Baseline (to be frozen in Increment 1 from the implementation-start commit)

- Sources: `src/external/conway/conway_main.s` (666 lines) +
  `conway_grid.s` (692 lines) + `common.inc` (76 lines); combined ≈ 35.4 KB,
  comfortably under CASM's 64 KB source cap.
- Current toolchain: `add_ca65_app(conway "${CONWAY_ENTRY}" CONWAY_SRCS 1040 "1400" "256")`
  (`CMakeLists.txt:414-427`); `CODE_ALIGN=256`.
- Current artifact: `build/conway.prg` — size + SHA-256 recorded in
  Increment 1.
- Current R6 shape: ≈ 182 relocation entries (viability review), base to be
  recorded; well under CASM's 4096 cap. Symbol count ≈ 182, under the 512
  cap.
- Grid buffers `grid0` / `grid1`: two 960-byte `.res` blocks, `.align 256`,
  already emitted in `CODE` (not linker BSS) — so the PRG already carries
  ≈ 1920 bytes of zero fill plus alignment padding. Confirm whether ld65
  currently truncates trailing zero fill in the last segment (affects the
  loaded end address and the manifest).
- `CONWAY` is packaged in `IMAGE_BASE_PRG_TARGETS` (`CMakeLists.txt:1820`)
  and the docs list (`CMakeLists.txt:1619`). Preserving the `conway` target
  name and `C64_PRG_PATH` contract is mandatory.
- Dispatch path: external command via `sdExt`; Increment 1(a) confirms the
  loader relocates a dispatched R6 CONWAY (expected trivially true from
  LABEL/FORMAT — `src/command64/shell.asm` `sdExt` calls
  `relocateExternalCommand`).

## Technical Notes

### How CONWAY differs from LABEL / FORMAT / COMP

| Aspect | LABEL/FORMAT/COMP | CONWAY | Handling |
| --- | --- | --- | --- |
| Modules | single file | two ca65 objects, `.import`/`.export` | `.INCLUDE` chain, one namespace (Decision 1) |
| Text data | PETSCII messages | **screen-code** menu/status strings via `.CHARMAP` macros | generated `.BYTE` include (Decision 2) |
| Compile-time guards | few / none | ~23 `.assert` layout invariants | host-side check script (Decision 3) |
| Emitted storage | ≤ 208 B `.RES` | 2 × 960 B `.RES`, **`.align 256`** | `.RES 960, 0` + `.ALIGN 256`; verify padding at `$3400` |
| Version/banner | generated `*ver.s` | `.define` strings + `.include "build_conway.inc"` + `exitBanner` PETSCII | `gen_conway_version.py` emits `conwayver.s` incl. `EXITBANNER` (Decision 7) |
| `.word` expressions | minimal | `menuDescriptors` / `menuArrow*` use `SCREEN + n*GRID_W + k` | CASM parens + `*`/`+` (Phase 12) — verify `.WORD a, b` multi-operand; split to one per line if needed |
| Exit | `RTS` / `DOS_EXIT` | `pla / pla / rts` after `JMP exitToShell` from dispatch | keep verbatim |
| Relocation | 61–159 entries | ≈ 182 entries | larger ledger to reconcile; same method |

### Label conversion

Every routine-internal branch target becomes `@local`. **Global (stay as
plain labels):** `start`, `mainLoop`, `handleKeys`, `handleSimulationKey`,
`handleMenuKey`, `handleMenuEditKey`, `exitToShell`, `enterMenu`,
`startSimulation`, `resetGeneration`, `incrementGeneration`, `drawMenu`,
`clearMenuArea`, `copyMenuString`, `drawMenuDynamics`, `drawPresetArrow`,
`drawBirthSummary`, `drawSurvivalSummary`, `drawMenuPrompt`, `waitDelay`,
`swapBufs`, `printString`, and every `conway_grid.s` `.export` target
(`randomizeGrid`, `drawGrid`, `drawSimulationStatus`, `drawGenerationCounter`,
`drawPauseColor`, `computeNext`, `clearGrid`, `clearScreen`, `loadPreset`,
`toggleBirth`, `toggleSurvival`, `getBirthRule`, `getSurvivalRule`,
`setThreeRowPtrs`, `setDstRowPtr`, `getCurrBase`, `getNextBase`, `lfsrStep`,
`convertGeneration`) plus every routine reached only by `JMP` from a
dispatcher (`hskExit`/`hskMenu`/… and `hmk*`/`hme*` are `@local` to their
`handle*` routine **only if** no cross-routine `JMP` targets them — audit
each; the `jmp cnColLoop` / `jmp cnRowLoop` back-edges inside `computeNext`
stay `@local`). Watch the local-label global-scope-boundary rule
(`reference-casm-local-label-global-scope-boundary`): a `@ref` whose `@def`
is separated by an intervening global label fails to assemble.

### CASM syntax gotchas (from prior migrations)

- Uppercase the whole of both files outside comments (CASM requires
  uppercase-ASCII source); `check_casm_source_bytes.py` gate.
- `lsr` / `asl` / `rol` on the accumulator need explicit `A`
  (`conway_grid.s:391,408,416,431,439`).
- `.res N, fill` → `.RES N, 0`; `.align 256` → `.ALIGN 256`.
- Constants that resolve to zero page (`JIFFY_CLK = $A2`, the `$70`–`$82`
  zero-page block) **must be inline in `conway.s`**, never in an `.INCLUDE`
  (`project-casm-included-constant-zp-absolute`) — so `conway_grid.s` must
  not define or re-declare them; they are visible to it by textual order.
- Char-literal addends are illegal; the sources already use `#$3A` / `#$39`
  / `#$30` explicit hex at the key-range checks — keep as hex. `#GRID_W - 1`,
  `#RULE_COUNT - 1`, `#GRID_H - 1` are constant-expression operands (fine;
  no parens, per the `VOL_NAME_LEN-1` precedent).
- `.define VERSION_* "…"` and `.include "build_conway.inc"` are removed;
  the banner + `exitBanner` come from `gen_conway_version.py`.
- Confirm `.WORD sym1, sym2` multi-operand support and paren expressions in
  `.WORD`/`.BYTE` data early (Increment 2 probe); fall back to one operand
  per line if CASM rejects it.

### Screen-code transform (Decision 2)

`gen_conway_menu.py`: for each byte `b` of an ASCII source string —
`0x20 ≤ b ≤ 0x3F` → `b`; `0x61 ≤ b ≤ 0x7A` → `b - 0x60`; anything else →
hard error. Emits `LABEL: .BYTE $xx,$xx,…` then `LABELEND:` (the current
`…End` symbols, uppercased) then `; "original ascii"`. `menuVersion` and
`exitBanner` are **not** screen-code (version digits drawn into screen RAM
*are* — `menuVersion` currently sits in a `screencode_mixed` block; audit:
digits `$30`–`$39` are identity so it is transform-invariant, but keep it
in the generated screen-code include for provenance). The generated
`STATUS_TEXT_LEN` / `MENU_NONE_LEN` / `MENU_VERSION_LEN` constants become
plain inline equates in `conway.s` computed by `check_conway_layout.py` and
asserted there.

## Atomic Increments

### Increment 1 — Freeze baseline, confirm loader, define layout

- (a) Read `src/command64/shell.asm` `sdExt`: confirm
  `relocateExternalCommand` runs for a dispatched CONWAY (stop condition if
  not).
- (b) Build + hash the current ca65 `conway.prg` from the
  implementation-start commit; record size, code/data extent, grid-buffer
  addresses, alignment padding, symbol list, and all ≈ 182 relocation
  entries. Determine whether ld65 truncates trailing grid zero-fill.
- (c) Enumerate the inline constant block (from `common.inc` + the used
  `command64.inc` symbols: `SCREEN`, `COLORRAM`, `VIC_BORD`, `VIC_BGND`,
  `JIFFY_CLK`, `KernalGetIn`, `KernalChROUT`, `PetCr`, …), each hand-derived
  and cited per `project-casm-trusted-reference-rule`, then cross-checked
  against the includes (not copied).
- (d) Freeze the exact native image order: header word, main code, `@`
  data, `conwayver.s` data, `conwaymenu.s` data, `conway_grid.s` code +
  read-only tables + emitted mutable state, `.ALIGN 256`, `grid0`,
  `.ALIGN 256`, `grid1`, then R6 table/footer. Predict the loaded end and
  prove it stays inside the external-app memory envelope.
- (e) Freeze the functional matrix (menu, 9 presets, B/S edit, run, pause,
  clear, random, exit ×2) as the migration regression contract.
- (f) Write `scripts/gen_conway_version.py` (twin; `APP_NAME="CONWAY"`,
  emits `CONWAYVERMSG` banner + `EXITBANNER`); create `CONWAY_VERSION`
  = `0.4.1`; trim `BUILD_CONWAY` to the plain counter.

**Gate:** user approves the address/storage/order ledger before conversion.

### Increment 2 — Native source conversion

- Rename `conway_main.s` → `conway.s`. Strip ca65 machinery from both
  files (`.include`, `.import`, `.export`, `.segment`, `.define`,
  `.assert`, the `HEADER` segment + `__MAIN_START__`, `screencode.inc`
  use). Add the two-byte load-address header the CASM-native way (as
  LABEL/FORMAT).
- Add the inline constant block (Increment 1c) at the top of `conway.s`;
  delete `common.inc` and `build_conway.inc`.
- Uppercase both files outside comments; collision-audit identifiers.
- Convert routine-internal labels to `@local` per Technical Notes; keep the
  enumerated globals.
- `.res` → `.RES … , 0`; `.align` → `.ALIGN`; `lsr/asl/rol` → `… A`.
- Add `.INCLUDE "CONWAYVER.S"`, `.INCLUDE "CONWAYMENU.S"`,
  `.INCLUDE "CONWAY_GRID.S"` at the tail of `conway.s` in that order.
- Write `scripts/gen_conway_menu.py` + generate `conwaymenu.s`; write
  `scripts/check_conway_layout.py`.
- Probe `.WORD` multi-operand + paren expressions; adjust `menuDescriptors`
  / `menuArrow*` if rejected.
- Run `check_casm_source_bytes.py` + `check_conway_layout.py`.

**Gate:** static source review + source-size/symbol-capacity check pass.

### Increment 3 — Independent derivation + native assembly

- Write `src/external/conway/conway-derivation.md`: every instruction/data
  range, the screen-code transform + full menu-byte enumeration, the two
  960-byte zero-fill ranges + alignment padding at `$3400`, every branch
  displacement, the relocation-eligibility ledger reconciled to CASM's
  entry count. Derived from the 6502 spec + documented CASM semantics + PRG
  framing + R6 rules — not from CASM output.
- Independent reviewer sign-off before `CANONICAL-INDEPENDENT`.
- Package `command64_conway_test.d64` (command64 + casm + comp +
  `conway.s` + `conway_grid.s` + generated `conwayver.s` + `conwaymenu.s`
  as SEQ + the manifest-derived `conway.ref`).
- `CASM CONWAY.S /O:CNW.PRG` → require `CASM: INPUT VALIDATED`. Extract,
  byte-compare against the derivation; classify any mismatch before
  editing either side.
- `casm_r6_verify.py` at `$3400` + two other bases; verify `grid0`/`grid1`
  land page-aligned after relocation.
- Optional: one-time non-committed ca65 build of the frozen source as
  structural differential evidence (Decision 4).

**Gate:** reviewed derivation and native artifact agree exactly.

### Increment 4 — Manifest + live COMP

- `scripts/build_conway_manifest.py` (twin; `source_sha256` over
  `conway.s`, `conway_grid.s`, `CONWAY_VERSION`, `BUILD_CONWAY`).
- Generate `src/external/conway/conway.ref.hex`; round-trip via
  `hex_manifest_to_bin.py --source-dir` → byte-identical to CASM output.
- Live `COMP CNW.PRG CONWAY.REF` on the C64 → `FILES COMPARE OK`; fire
  overlay `test`/`pass` events.
- Add `conway.ref.hex` to `scripts/casm_oracle_inventory.py`
  `NATIVE_MANIFESTS`; add the audit-register row (pending reviewer
  sign-off).

**Gate:** manifest reconciles; live COMP OK.

### Increment 5 — CMake rewire

- Remove `add_ca65_app(conway …)` + the `Ca65_FOUND` fatal branch +
  `CONWAY_SRCS` / `CONWAY_ENTRY`; update the `find_package(Ca65)` comment
  (line 32) to drop CONWAY.
- Add the manifest-derived `conway` target (`C64_PRG_PATH` set,
  `set(CONWAY_TARGET conway)` preserved).
- Add `conway_version_src` (runs `gen_conway_version.py` →
  `${CMAKE_BINARY_DIR}/conwayver.s`) and `conway_menu_src` (runs
  `gen_conway_menu.py` → `${CMAKE_BINARY_DIR}/conwaymenu.s`).
- Add `command64_conway_test_d64` (command64 + casm + comp; PRE_BUILD
  `check_casm_source_bytes.py` + `check_conway_layout.py`; POST_BUILD packs
  the two `.s` sources + both generated `.s` + `conway.ref`).
- `conwayver.s` / `conwaymenu.s` are build products, not checked in;
  `common.inc` / `build_conway.inc` deleted.

**Gate:** configure + every `${CONWAY_TARGET}` image dependency graph
succeeds.

### Increment 6 — Full-rebuild verification

- Fresh `rm -rf build && cmake -B build` + full `cmake --build build` — no
  warnings/errors.
- `build/conway.prg` SHA-256 == manifest; deterministic; no-change rebuild
  byte-identical (`conway.prg`, `image.d64`, test disk).
- `image.d64` carries `CONWAY`; `test_image_d64` builds.
- Stale-source gate fires on a `conway.s` **and** a `conway_grid.s` edit;
  `check_conway_layout.py` fails on a deliberately over-long menu string
  then passes on revert.
- `casm_oracle_inventory` reconciliation OK; `casm_r6_verify` green.
- No `add_ca65_app` / `__MAIN_START__` / `command64.inc` / `common.inc` /
  `build_conway.inc` / `screencode.inc` reference to CONWAY remains.

**Gate:** all of the above green.

### Increment 7 — Docs + walkthrough + trackers

- `wiki/conway-utility.md` — Artifact Provenance section (manifest, R6
  ledger summary, the screen-code-transform note, the `.assert`→script
  note); synced to `docs/` via `sync_docs`.
- `wiki/tasks/conway-multiverse.md`; `CHANGELOG.md`; `brain/KNOWLEDGE.md`
  ("CONWAY → CASM-native" section); `brain/task.md` CONWAY checklist;
  byte-oracle audit register row finalised.
- `brain/walkthroughs/2026-09-03-conway-casm-native-migration.md` — live
  evidence only.
- Taskwarrior done; memory `project-conway-casm-native-migration`.

## Expected Files

| File | Planned action |
| --- | --- |
| `src/external/conway/conway_main.s` | Rename → `conway.s`, rewrite (Increment 2) |
| `src/external/conway/conway.s` | Result of the rename + rewrite |
| `src/external/conway/conway_grid.s` | Modify — strip ca65 machinery, `@local`, uppercase (Increment 2) |
| `src/external/conway/common.inc` | Delete — folded inline (Increment 2) |
| `src/external/conway/build_conway.inc` | Delete (Increment 2) |
| `src/external/conway/CONWAY_VERSION` | Create (Increment 1) |
| `src/external/conway/BUILD_CONWAY` | Modify — trim to plain counter (Increment 1) |
| `src/external/conway/conwayver.s` | Build product — `${CMAKE_BINARY_DIR}`, not checked in |
| `src/external/conway/conwaymenu.s` | Build product — `${CMAKE_BINARY_DIR}`, not checked in |
| `src/external/conway/conway.ref.hex` | Create (Increment 4) |
| `src/external/conway/conway-derivation.md` | Create (Increment 3) |
| `scripts/gen_conway_version.py` | Create (Increment 1) |
| `scripts/gen_conway_menu.py` | Create (Increment 2) |
| `scripts/check_conway_layout.py` | Create (Increment 2) |
| `scripts/build_conway_manifest.py` | Create (Increment 4) |
| `scripts/casm_oracle_inventory.py` | Modify (Increment 4) |
| `CMakeLists.txt` | Modify (Increment 5) |
| `include/ca65/screencode.inc` | Leave — still used by pacman; no CONWAY reference |
| `wiki/conway-utility.md`, `docs/conway-utility.md` | Modify (Increment 7) |
| `wiki/tasks/conway-multiverse.md` | Modify (Increment 7) |
| `CHANGELOG.md`, `brain/KNOWLEDGE.md`, `brain/task.md` | Modify (Increment 7) |
| `brain/reviews/2026-09-01-casm-byte-oracle-audit.md` | Modify (Increment 4/7) |
| `brain/walkthroughs/2026-09-03-conway-casm-native-migration.md` | Create (Completion Gate) |

## Stop Conditions

- Increment 1(a): `sdExt` does **not** relocate a dispatched CONWAY — halt,
  disclose, defer (no loader change here).
- Any live CASM assembly reports a diagnostic instead of
  `CASM: INPUT VALIDATED`.
- CASM rejects `.WORD` multi-operand / paren expressions **and** the
  one-operand-per-line fallback changes byte layout unexpectedly — halt,
  classify.
- Increment 3 byte differences not fully explained by the enumerated
  transform — halt; classify before touching either side
  (`.agents/workflows/canonical-byte-oracles.md`).
- `grid0` / `grid1` do not land page-aligned at `$3400` or after
  relocation — halt; the layout/alignment derivation is wrong.
- The functional matrix regresses versus the frozen ca65 baseline (menu
  glyphs wrong, a preset misbehaves, counter wrong, exit doesn't return
  cleanly) — halt.
- Symbol or R6 count approaches a CASM cap (512 / 4096) — not expected
  (≈ 182 each).
- No-change rebuild alters `conway.prg` / `conway.ref.hex`, or
  `image_d64` / `test_image_d64` fails.
- A genuinely new defect outside this plan's scope (in CASM, the loader,
  the manifest tooling): disclose and defer as a separate follow-up; do not
  fix inline without explicit direction, and record any authorised
  deviation in Progress + the walkthrough.

## Documentation, Task, and DOX Updates

- **At approval:** create the Taskwarrior task (project `conway`); set
  frontmatter `taskwarrior:`; status → approved.
- **At completion:** `wiki/conway-utility.md` (+ `docs/` via `sync_docs`),
  `wiki/tasks/conway-multiverse.md`, byte-oracle audit register row,
  `CHANGELOG.md`, `brain/KNOWLEDGE.md`, `brain/task.md`, Taskwarrior done,
  new memory `project-conway-casm-native-migration`.

## Completion Gate

All true before CONWAY is marked migrated:

- Live VICE: `CASM: INPUT VALIDATED` on the final `conway.s`; the full
  functional matrix exercised with screenshot / register evidence per
  `.agents/workflows/vice-mcp-testing.md`; overlay `test` events fired.
- Byte comparison vs `conway-derivation.md` — empty diff, or every
  difference enumerated and traced.
- Grid buffers verified page-aligned at `$3400` and after relocation to two
  other bases.
- Oracle: `conway.ref.hex` source-hash-bound; `conway-derivation.md`
  peer-reviewed; `casm_r6_verify.py` PASS at `$3400` + two bases; live
  `COMP CNW.PRG CONWAY.REF` → `FILES COMPARE OK`; provenance state in the
  audit register.
- Build: fresh `cmake -B build` + `image_d64` + `test_image_d64` clean;
  no-change rebuild identical; both stale-source gates verified;
  `check_conway_layout.py` proven to fail-then-pass; no ca65 / `.inc`
  reference to CONWAY anywhere.
- `brain/walkthroughs/2026-09-03-conway-casm-native-migration.md` with live
  evidence.
- Trackers synchronized.
- Explicit user approval of the walkthrough + reviewer sign-off on
  `conway-derivation.md`.

## Progress

- 2026-09-03: Plan drafted. Scoping Decisions 1, 3, 4 confirmed via
  AskUserQuestion; Decision 2 chosen by the planner (generated `.BYTE`
  include) at the user's request for a recommendation; Decisions 5–8
  carried from the LABEL/FORMAT/COMP precedent. Key differentiators from
  prior migrations surfaced up front: multi-module `.INCLUDE` flatten,
  screen-code text data, `.align 256` emitted grid buffers, ~23
  unexpressible `.assert` guards.
- 2026-09-03: **Plan approved.** Taskwarrior task 44
  (`ec0342bc-650e-4f17-9650-772e21a037eb`, project `conway`); status →
  approved.
- 2026-09-03: **Increment 1 — completion candidate; gate open for user
  approval of the ledger.**
  - (a) **Loader confirmed.** `src/command64/shell.asm:319-333` — `sdExt`
    calls `jsr relocateExternalCommand` between `shellLoadPrg` and
    `jsr UserProgStart`. CONWAY-as-R6-at-`$3400` relocates like
    LABEL/FORMAT. No stop condition.
  - (b) **Frozen ca65 baseline** (implementation-start commit `c6f7b11`,
    clean `cmake --build build --target conway`):
    - `build/conway.prg`: 4916 bytes on disk, SHA-256
      `43fc6960347000dbf1d7f465c7250d0b6c2282cd316dd621fb0448136f0213fc`.
    - Load `$3800`; base image `$3800..$49BF` = **4544 bytes** (`$11C0`);
      `__MAIN_LAST__ = $49C0`. Then reloc.py appends `2*N` table bytes +
      a 6-byte footer (`<base $3800><count N>` + `"R6"`): `4916 = 2 +
      4544 + 2N + 6` → **N = 182 relocation entries** (matches the
      viability review; well under CASM's 4096 cap). Symbol count ≈ 182,
      under the 512 cap.
    - **No RODATA/DATA/BSS segments** materialise — the whole artifact is
      the `CODE` segment. The two grid buffers are already emitted
      (`.res` in `CODE`), so there is **no unemitted BSS beyond the
      image** (unlike COMP). `casm_r6_verify` should accept the native
      output directly.
    - ca65 `CODE` layout at base `$3800` (from a `-g` relink label file):
      | Range | Contents |
      | --- | --- |
      | `$3800`–`$3D44` | `conway_main` code + `exitBanner` (`$3AE7`) + menu descriptor/pointer data + menu screen-code strings + `menuVersion` (`$3D37`–`$3D40`, 10 B) |
      | `$3D45`–`$3DFF` | **187 B ca65 object-boundary `.align 256` padding** (`conway_grid.o` starts on a page) |
      | `$3E00`–`$4161` | `conway_grid` code (`randomizeGrid`=`$3E00` … `statusText`=`$4132`) |
      | `$4162`–`$4185` | `presetBirthMasks` / `presetSurvivalMasks` (36 B) |
      | `$4186`–`$418E` | `ruleBirth` (`.res 9`) |
      | `$418F`–`$4197` | `ruleSurvival` (`.res 9`) |
      | `$4198` | `ruleMaskScratch` |
      | `$4199`/`$419A` | `tempValLo`/`tempValHi` |
      | `$419B`–`$419F` | `digitBuf` (`.res 5`) |
      | `$41A0`–`$41FF` | 96 B source-level `.align 256` padding |
      | `$4200`–`$45BF` | **`grid0`** (`.res 960`) — page-aligned |
      | `$45C0`–`$45FF` | 64 B source-level `.align 256` padding |
      | `$4600`–`$49BF` | **`grid1`** (`.res 960`) — page-aligned |
  - (c) **Inline constant block** (all hand-derived from the 6502/C64
    references, then cross-checked against `common.inc` +
    `command64.inc`, not copied — `project-casm-trusted-reference-rule`):
    - From `command64.inc`: `KERNALCHROUT=$FFD2`, `KERNALGETIN=$FFE4`,
      `PETCR=$0D`.
    - Grid/screen geometry: `GRID_W=40`, `GRID_H=24`, `GRID_SIZE=960`,
      `STATUS_ROW_OFFSET=960`, `MENU_PROMPT_OFFSET=920`,
      `MENU_BIRTH_FIELD_OFFSET=612`, `MENU_SURV_FIELD_OFFSET=652`,
      `GEN_LABEL_OFFSET=991`, `GEN_DIGITS_OFFSET=995`,
      `PAUSE_TEXT_OFFSET=963`, `PAUSE_TEXT_LEN=5`. (These are computed
      `n*GRID_W+k` in `common.inc`; CASM named-constant RHS must be a
      bare literal, so they are pre-computed to literals here — the
      arithmetic is recorded for review and re-checked by
      `check_conway_layout.py`.)
    - Hardware: `VIC_BORD=$D020`, `VIC_BGND=$D021`, `SCREEN=$0400`,
      `COLORRAM=$D800`, `JIFFY_CLK=$A2`.
    - Display: `CHAR_LIVE=$A0`, `CHAR_DEAD=$20`, `CLR_LIVE=5`,
      `CLR_PAUSED=3`.
    - Timing: `GEN_DELAY=3`.
    - UI state: `MENU_STATE_NORMAL=0`, `MENU_STATE_BIRTH=1`,
      `MENU_STATE_SURVIVAL=2`, `PRESET_CUSTOM=$FF`, `PRESET_COUNT=9`,
      `RULE_COUNT=9`.
    - Zero page (`$70`–`$82`, app-private external area — **inline in
      `conway.s`, never via `.INCLUDE`**): `ZPPREVLO=$70` `ZPPREVHI=$71`
      `ZPCURRLO=$72` `ZPCURRHI=$73` `ZPNEXTLO=$74` `ZPNEXTHI=$75`
      `ZPDSTLO=$76` `ZPDSTHI=$77` `ZPROW=$78` `ZPCOL=$79` `ZPCOUNT=$7A`
      `ZPLFSR=$7B` `ZPPAUSED=$7C` `ZPBUFSEL=$7D` `ZPINMENU=$7E`
      `ZPMENUSTATE=$7F` `ZPPRESETIDX=$80` `ZPGENLO=$81` `ZPGENHI=$82`.
    - Deferred to Increment 2: `STATUS_TEXT_LEN` (=40),
      `MENU_NONE_LEN` (=4), `MENU_VERSION_LEN` (=10),
      `MENU_VERSION_COL` (=30) are currently `labelEnd - label` — the
      generators emit them as literal equates (`MENU_VERSION_LEN` is
      already in `conwayver.s`; `STATUS_TEXT_LEN`/`MENU_NONE_LEN` come
      from `gen_conway_menu.py`).
  - (d) **Native image order + loaded-end prediction** (CASM always emits
    at `$3400`, exactly −4 pages / −`$400` from the ca65 base — page
    alignment preserved):
    1. 2-byte load-address header (`$3400`)
    2. `conway.s` main code + `@` data + menu descriptor/pointer tables
    3. `.INCLUDE "CONWAYVER.S"` data (`EXITBANNER`, `MENUVERSION`)
    4. `.INCLUDE "CONWAYMENU.S"` data (screen-code strings)
    5. `.INCLUDE "CONWAY_GRID.S"` code + `presetBirthMasks`/… + read-only
       tables + emitted mutable state (`ruleBirth` … `digitBuf`)
    6. `.ALIGN 256` → `grid0` (`.RES 960, 0`)
    7. `.ALIGN 256` → `grid1` (`.RES 960, 0`)
    8. R6 relocation table + `52 36` footer
    - The 187-byte ca65 object-boundary gap **disappears** (no object
      boundary after a textual `.INCLUDE`; the grid *code* has no
      alignment requirement — only `grid0`/`grid1` do, and their explicit
      `.ALIGN 256` guarantees it regardless of preceding size). The two
      source-level align pads recompute to new (still page-aligned)
      values.
    - **Predicted native image ≈ `$3400`–`$44BF` (~4.3 KB)**; grid0/grid1
      land page-aligned around `$3D00`/`$4100` (exact addresses pinned in
      the Increment 3 derivation). Loaded end well below the current ca65
      end (`$49BF`) and comfortably inside the external-app memory
      envelope. Total payload with the ~182-entry R6 table ≈ 4.65 KB.
  - (e) **Frozen functional matrix** (migration regression contract —
    verified live in Increment 3 / Completion Gate):
    M1 dispatch `conway` → menu renders (title "conway multiverse", rule
    underline, 9 presets w/ B/S columns, "current rule" birth/survival
    summary, 3 control lines, prompt "q:exit to shell", version
    "0.4.1.1063" right-aligned on row 23); M2 preset arrow ">" at preset
    1; M3 keys `1`–`9` move the arrow + update the birth/survival summary
    (e.g. `7` → survival "012345678"); M4 `B` → prompt "birth: press 0-8
    to toggle", digit toggles a birth count + marks rule custom (arrow
    clears), non-digit cancels; M5 `S` → survival edit, same; M6 `RETURN`
    → simulation starts, grid drawn, status row "sp:pause r:rnd c:clear
    q:menu  gen:00000", generation counter advances; M7 `R` in menu →
    randomize + start; M8 `SPACE` in sim → pause toggles, "pause" word
    recolours cyan, unpause resumes; M9 `R` in sim → re-randomize, gen→0;
    M10 `C` in sim → clear, paused, gen→0; M11 `Q` in sim → back to menu;
    M12 `Q` in menu → exit (screen cleared, border/bg black, "CONWAY
    v0.4.1.1063" printed, clean return to `C64[8]:>`); M13 RUN/STOP
    (`$03`) in sim or menu → exit to shell.
  - (f) **Version tooling.** `scripts/gen_conway_version.py` written (twin
    of `gen_format_version.py`; emits `EXITBANNER` PETSCII + `MENUVERSION`
    screen-code + `MENU_VERSION_LEN = 10`). `CONWAY_VERSION` = `0.4.1`;
    `BUILD_CONWAY` trimmed from the 2-line counter+hash form to the plain
    counter `1063` (the ca65 auto-bump is retired, as for FORMAT —
    version bumps become deliberate manifest regens). Generated
    `conwayver.s` reproduces the frozen ca65 bytes **exactly**:
    `C3 CF CE D7 C1 D9 20 56` + `"0.4.1.1063"` + `0D 00` for `EXITBANNER`
    (frozen `build/conway.prg` offset `$3AE7`); `30 2E 34 2E 31 2E 31 30
    36 33` for `MENUVERSION` (offset `$3D37`). No visual change.
  - **Open:** user approval of this address/storage/order ledger before
    source conversion (Increment 2).
- 2026-09-03: **Increment 1 ledger approved by the user.**
- 2026-09-03: **Increment 2 — completion candidate; static gate open.**
  - **Source generators written and self-verified against the frozen ca65
    bytes:**
    - `scripts/gen_conway_menu.py` — 23-entry `STRINGS` table → generated
      `conwaymenu.s`: screen-code `.BYTE` data + `STATUS_TEXT_LEN`/
      `MENU_NONE_LEN` bare-literal equates. Transform (identity `$20-$3F`,
      `c-$60` for `a-z`, hard-error otherwise) matches
      `include/ca65/screencode.inc`'s `.CHARMAP` exactly — spot-checked
      against `build/conway.prg`: `MENUTITLE` `03 0F 0E 17 01 19 20 0D 15
      0C 14 09 16 05 12 13 05` == ca65 `$3B5A`; `STATUSTEXT` `13 10 3A 10
      01 15 13 05 …` == ca65 `$4132`; `MENUPRESET7`, `MENUNONETEXT` also
      match. Whole file emitted uppercase (comment annotations included)
      so `check_casm_source_bytes.py` passes.
    - `scripts/check_conway_layout.py` — imports `STRINGS`, recomputes all
      ~23 `.assert` invariants (20 menu row-crossing checks, `STATUS_TEXT_LEN
      = 40`, `GEN_DIGITS_OFFSET + 5 = 1000`, birth/survival field bounds,
      pause-colour bound, menu-version column/overlap/screen checks). **PASS.**
  - **`conway_main.s` → `conway.s`** (rename via `git rm` + new file):
    ca65 machinery stripped (`.include` ×3, `.import` ×13, `.export`,
    `.segment`, `HEADER`/`__MAIN_START__`, `.define` ×3,
    `.include "build_conway.inc"`, all 22 `.assert`s,
    `screencode_mixed`/`petscii_mixed`). Inline constant block added (the
    Increment-1c list, `common.inc`'s computed offsets pre-resolved to
    literals with the arithmetic in a comment). Whole file uppercased.
    Every routine-internal branch target → `@LOCAL`; the 22 globals
    enumerated in Technical Notes kept global (routine entries + the
    cross-`JMP` targets `MAINLOOP`, `HANDLESIMULATIONKEY`,
    `HANDLEMENUKEY`, `HANDLEMENUEDITKEY`, `EXITTOSHELL`, `ENTERMENU`,
    `STARTSIMULATION`, `DRAWMENUDYNAMICS`, `DRAWMENUPROMPT`). Messages →
    references into `CONWAYMENU.S`/`CONWAYVER.S`. `.INCLUDE "CONWAYVER.S"`
    / `"CONWAYMENU.S"` / `"CONWAY_GRID.S"` appended in that order.
    `menuDescriptors`/`menuArrow*` tables kept, now `.WORD LABEL, SCREEN +
    n * GRID_W + k` form.
  - **`conway_grid.s`** rewritten: `.include`/`.export`/`.segment` gone,
    uppercased, every routine-internal label → `@LOCAL` (`@INVALID`,
    `@PAGE`, `@TAIL`, … reused per-routine — safe, `@` namespace resets at
    each global label), `getCurrBase`/`getNextBase`'s local renamed
    `@USEG1` to avoid visual clash with the `GRID1` buffer global. `lsr`/
    `asl`/`rol` on A → `LSR A`/`ASL A`/`ROL A`. `.res N, 0` → `.RES N, 0`;
    `.align 256` → `.ALIGN 256`. `statusText` → `STATUSTEXT` (from
    `CONWAYMENU.S`). Data tables + emitted mutable state + the two
    page-aligned `.RES 960, 0` grid buffers preserved.
  - **Deleted:** `src/external/conway/common.inc`,
    `src/external/conway/conway_main.s` (renamed), `build/build_conway.inc`.
  - **Gates:** `check_casm_source_bytes.py` — 4 sources OK (conway.s,
    conway_grid.s, generated conwayver.s + conwaymenu.s; uppercase, no
    case-colliding identifiers). `check_conway_layout.py` — OK. Combined
    source ≈ 36 KB (< 64 KB cap). Rough symbol count ≈ 250 (< 512); R6
    ≈ 182 (< 4096).
  - **Not done in Increment 2 (no host CASM assembler — moves to
    Increment 3's first live action):** the `.WORD LABEL, EXPR`
    multi-operand probe, paren/`<`/`>` expression acceptance in `.BYTE`/
    `.WORD` data (`MENUARROWLO`/`HI`, `DECIMALDIVLO`/`HI`),
    `PRESETBIRTHMASKS + 1, X` / `RULEBIRTH + 8` operand expressions,
    `.RES N, 0` two-arg form, forward `.INCLUDE` label resolution across
    the include chain. All are Increment-3 stop-condition items if CASM
    rejects them.
  - **Open:** static source review sign-off, then Increment 3 (live CASM
    assembly + derivation).
- 2026-09-03: **Increment 2 static conversion approved by the user.**
- 2026-09-03: **Increment 3 — live CASM assembly reached
  `CASM: INPUT VALIDATED` after three source fixes; R6 clean after a
  fourth. Byte comparison + derivation still open.** Native CASM `0.6.2`
  build `1419` under VICE 3.10, `CASM CONWAY.S /O:CNW.PRG` from SEQ sources
  on `build/command64_conway_test.d64` (command64 + casm + comp + the 4
  sources).
  - **Fix 1 — `conwaymenu.s` line length.** First run: `CASM: SOURCE
    LOCATION OVERFLOW` (`$16`, the 8-bit `CasmSourceColumn` counter) at a
    long `.BYTE` line. `gen_conway_menu.py` now wraps data at 12 bytes per
    line and puts the `; "text"` annotation on its own line. (New
    reference fact for memory.)
  - **Fix 2 — include filename underscore.** Second run: `CASM: CANNOT
    OPEN INPUT` on `.INCLUDE "CONWAY_GRID.S"`. Disk directory (cc1541 `-f
    "conway_grid.s"`) stored the `_` as PETSCII `$A4`, but the source
    string has ASCII `$5F` — no match. `conway_grid.s` **renamed to
    `conwaygrid.s`** (no underscore, matching the DASH precedent for
    `.INCLUDE`d SEQ names); `.INCLUDE "CONWAYGRID.S"`.
  - **Fix 3 — `.INCLUDE`d named constants are relocatable.** Third run:
    `CASM: INPUT VALIDATED`, `04668 BYTES`, `1143` statements, image
    `$3400..$44BF` (**4288 bytes — exactly the Increment-1 prediction**) +
    186-entry R6 table + `52 36` footer. But `casm_r6_verify.py` **FAIL**:
    4 spurious entries. Disassembly traced all 4 to operands referencing a
    named constant **defined in an `.INCLUDE'd file`**:
    `CPX #MENU_NONE_LEN` (×2, `$36 45`/`$36 77`), `CPX #MENU_VERSION_LEN`
    (`$36 B9`), and `STA SCREEN + MENU_PROMPT_OFFSET + GRID_W -
    MENU_VERSION_LEN, X` (`$36 B7`). Same defect family as
    `project-casm-included-constant-zp-absolute` (Taskwarrior 42) — an
    `.INCLUDE'd` equate is treated as a relocatable symbol, so every
    referencing operand (immediates included) gets a spurious R6 entry.
    **This is a plan-conformance fix, not a CASM change or a deviation:**
    the plan's Technical Notes already require constants inline in
    `conway.s`. `MENU_NONE_LEN=4` / `STATUS_TEXT_LEN=40` /
    `MENU_VERSION_LEN=10` moved to `conway.s`'s inline block; the
    generators emit them only as `;` comments;
    `check_conway_layout.py` now also verifies `conway.s`'s inline values
    match the generated string lengths.
  - **Fix 4 run — `CASM: INPUT VALIDATED`, `04668 BYTES`, `1143`
    statements** (unchanged size). R6 re-verify pending a clean extract
    (a `vice_disk_detach` after the write did not flush `CNW.PRG` to the
    host file on one attempt — re-running with a shell `FLUSH` before
    detach).
  - **Answered probes (all OK):** `.WORD LABEL, EXPR` multi-operand,
    paren + `<`/`>` expressions in `.BYTE`/`.WORD` data,
    `PRESETBIRTHMASKS + 1, X` / `RULEBIRTH + 8` operand expressions,
    `.RES N, 0`, forward label resolution across the 3-file `.INCLUDE`
    chain — CASM accepted every one (the `INPUT VALIDATED` run exercises
    them all).
  - **Fix 4 verified — R6 PASS.** After a clean reboot + fresh disk, the
    Fix-3 source assembled to **04660 bytes** (8 bytes smaller = the 4
    removed spurious entries), image `$3400..$44BF` (4288 bytes,
    unchanged), **182**-entry R6 table, footer `base $3400 count 182 'R6'`.
    `CNW.PRG` SHA-256 `2fc65181…`. `casm_r6_verify.py` **PASS** — all 182
    entries in-image (pages `$34..$3D`, `$41`), relocates cleanly to
    `$3800` / `$5000` / `$9000`; `GRID0` (`$3D00`) / `GRID1` (`$4100`)
    stay page-aligned. **182 == the retired ca65 build's relocation
    count.**
  - **Independent corroboration — 0 diff.** ca65/ld65 build of the same
    four sources (includes inlined, `LSR A`→`lsr a`, `$3400` cfg), linked
    at `$3400`: image body **byte-identical to `CNW.PRG` across all 4288
    bytes**. ca65 and CASM select opcodes / addressing / displacements
    independently — genuine codegen corroboration (Scoping Decision 4's
    one-time non-committed reference).
  - **`src/external/conway/conway-derivation.md` written** (pending
    reviewer sign-off): artifact + 6 source hashes, full layout ledger
    (verified against a `-g` label file), the screen-code transform +
    byte spot-checks vs the retired ca65 build, the version-data byte
    match, the 182-entry R6 ledger (≈159 absolute + ≈23 `#>` immediates)
    reconciled to the ca65 count, and the live functional evidence.
  - **Live functional matrix (VICE, `conway` dispatched from the shell,
    relocated by `sdExt`):** full menu renders with every screen-code
    string correct + arrow at preset 1 + birth `3` / survival `23`;
    key `7` → arrow to preset 7, survival summary `012345678`; `RETURN` →
    simulation runs, grid drawn, status row correct, generation counter
    advancing (`00433`); `Q` sim→menu; `Q` menu→exit prints
    "CONWAY v0.4.1.1063" and returns clean to `c64[8]:>`. B/S edit,
    R-start, SPACE pause, in-sim R/C, RUN-STOP deferred to the
    completion-gate sweep (byte-identical to the corroborated reference).
  - **Note (user tip, 2026-09-03):** use `/O:@:CNW.PRG` (DOS replace
    prefix) so a re-run overwrites a pre-existing output instead of
    `CASM: OUTPUT WRITE FAILED` (`project-casm-filecreateoutput-no-replace`).
    Applies to the Increment-5 `command64_conway_test_d64` doc / any
    re-run guidance.
  - **Open:** reviewer sign-off on `conway-derivation.md`; then
    Increment 4 (manifest + live `COMP`).
- 2026-09-03: **Increment 3 gate approved by the user.**
- 2026-09-03: **Increment 4 — completion candidate.**
  - `scripts/build_conway_manifest.py` written (twin of
    `build_format_manifest.py`; 4 `source_sha256` — `conway.s`,
    `conwaygrid.s`, `CONWAY_VERSION`, `BUILD_CONWAY`).
  - `src/external/conway/conway.ref.hex` generated from the reviewed
    `CNW.PRG` (4660 bytes, load `$3400`, sha256 `2fc65181…`).
    `hex_manifest_to_bin.py --source-dir src/external/conway` round-trips
    **byte-identical** (same sha256).
  - **Live `COMP CNW.PRG CONWAY.REF` on the C64 → `FILES COMPARE OK`**
    (CASM 0.6.2 b1419; disk `build/conway_comp.d64` = command64 + comp +
    `CNW.PRG` + the manifest round-trip as `CONWAY.REF`), clean return to
    `c64[8]:>`. Overlay `test`/`pass` event fired.
  - `scripts/casm_oracle_inventory.py` `NATIVE_MANIFESTS` += `conway.ref.hex`
    → `reconciliation: OK`, 6 native manifests, 67/67 refs, 73/73.
  - Audit-register rows added (Ledger A + summary table) in
    `brain/reviews/2026-09-01-casm-byte-oracle-audit.md` — provenance
    `CANONICAL-INDEPENDENT` **pending reviewer sign-off** on
    `conway-derivation.md`.
  - **Open:** reviewer sign-off on `conway-derivation.md`; then
    Increment 5 (CMake rewire — retire `add_ca65_app(conway …)`).
- 2026-09-03: **Increment 4 gate approved by the user.**
- 2026-09-03: **Increments 5 + 6 — completion candidate.**
  - **Increment 5 (CMake):** removed `add_ca65_app(conway …)` + its
    `Ca65_FOUND` fatal branch + the `CONWAY_SRCS`/`CONWAY_ENTRY` globs; the
    `find_package(Ca65)` comment now reads "…LABEL/FORMAT/COMP/CONWAY are
    CASM-native". Added the manifest-derived `conway` target
    (`hex_manifest_to_bin.py … --source-dir`, `C64_PRG_PATH` set,
    `set(CONWAY_TARGET conway)` preserved — `IMAGE_BASE_PRG_TARGETS`
    unchanged), `conway_generated_src` (runs `gen_conway_version.py` →
    `${CMAKE_BINARY_DIR}/conwayver.s` and `gen_conway_menu.py` →
    `conwaymenu.s`), and `command64_conway_test_d64` (command64 + casm +
    comp; PRE_BUILD `check_casm_source_bytes.py` **and**
    `check_conway_layout.py`; POST_BUILD packs `conway.s` + `conwaygrid.s`
    + generated `conwayver.s` + `conwaymenu.s` as SEQ + `conway.ref` PRG).
    `conwayver.s`/`conwaymenu.s` are build products, not checked in.
  - **Increment 6 (verify):** fresh `rm -rf build && cmake -B build` +
    full `cmake --build build` — **0 errors, 0 warnings**.
    `build/conway.prg` sha256 `2fc65181…` == the manifest.
    `image.d64` carries `conway` (19 blocks / 4660 B); `test_image_d64`
    builds. No-change rebuild: `conway.prg` / `image.d64` byte-identical.
    Stale-source gate **fires** on a `conway.s` edit
    (`hex_manifest_to_bin.py` `--source-dir` hard-fail: "source file
    'conway.s' has changed since the manifest was generated"); reverting →
    clean. `casm_oracle_inventory` `reconciliation: OK` (6 native
    manifests, 67/67, 73/73). `casm_r6_verify` PASS on the
    manifest→binary. No `add_ca65_app(conway` / `conway_main` /
    `conway_grid` / `build_conway.inc` / `__MAIN_START__` reference
    remains (`conwaygrid.s` and `.INCLUDE` prose are the only matches).
  - **Open:** reviewer sign-off on `conway-derivation.md`; then
    Increment 7 (docs + walkthrough + trackers + completion gate).
- 2026-09-03: **Increments 5+6 gate approved by the user.**
- 2026-09-03: **Increment 7 — completion candidate. All seven increments
  implemented.**
  - **Consolidated functional re-verification (M1–M13) on the
    manifest-derived `build/conway.prg`** (fresh build, sha `2fc65181…`):
    menu render + preset arrow + preset switch (M1–M3, re-confirmed); `B`
    edit → prompt change, `4` toggle → birth summary `34` + arrow cleared
    + prompt returns to normal (M4); `RETURN` → sim, status row, counter
    (M6); `SPACE` → pause word cyan (`$DBC3` = `03×5`) + counter frozen
    (M8); `C` → grid cleared + `00000` + paused (M10); `R` at menu →
    randomize+start (M7); `R` in sim → re-randomize + counter reset (M9);
    `Q` sim→menu (M11); RUN/STOP → banner + `c64[8]:>` (M13); `Q` menu →
    banner + `c64[8]:>` (M12). M5 (`S` edit) is the same code path as M4
    and its summary update was already shown in M3. Overlay `test`/`pass`
    fired.
  - **Docs:** `wiki/conway-utility.md` — new *Artifact Provenance*
    section, `Assembler:` header line, stale `1058`→`1063` build refs
    fixed; synced to `docs/conway-utility.md` via `sync_docs` (diff
    clean). `CHANGELOG.md` — CONWAY entry (first multi-module migration).
    `brain/KNOWLEDGE.md` — "CONWAY → CASM-native" section (module flatten,
    screen-code, `.assert`→script, `.INCLUDE`d-constant R6 symptom,
    `/O:@:`). Audit register — Ledger A + summary rows (added a missing
    `format.ref.hex` Ledger A row while there). `brain/task.md` — Stage 4
    checklist + task-42 note extended with the CONWAY symptom.
  - **Walkthrough:** `brain/walkthroughs/2026-09-03-conway-casm-native-migration.md`
    (live evidence only).
  - **Memory:** `project-conway-casm-native-migration`,
    `reference-casm-include-filename-and-line-limits`;
    `project-casm-included-constant-zp-absolute` extended.
  - **Final build:** fresh `cmake -B build` + full `cmake --build build` +
    `sync_docs` — **0 errors / 0 warnings**.
  - **Open (Completion Gate):** (1) independent reviewer sign-off on
    `src/external/conway/conway-derivation.md`; (2) user approval to close
    Taskwarrior task 44. No self-declared completion.
