---
feature: conway-multiverse-implementation
created: 2026-07-14
status: planned
---

# Conway Multiverse Detailed Implementation Plan

## 1. Goal

Extend the existing ca65/ld65 Conway external utility with:

- a startup and returnable main menu;
- nine selectable Life-like rule presets;
- custom Birth and Survival neighbor-count toggles;
- a 16-bit generation counter on the simulation status row;
- preservation of the current toroidal 40x24 solver, relocatable buffers,
  pause/randomize/clear behavior, and clean shell-return contract.

This plan refines `brain/plans/conway-multiverse-rules-and-menu.md` against the
production source and build pipeline. Taskwarrior task: #26
(`f4eba87e-a46d-47d2-986e-a707c57af1fd`).

## 2. Confirmed Baseline

- Branch: `feature/conway-multiverse`, based on `main` at `94b5d2e`.
- Toolchain: ca65/ld65 through `add_ca65_app`.
- Entry/control module: `src/external/conway/conway_main.s`.
- Solver/render module: `src/external/conway/conway_grid.s`.
- Shared constants/ZP: `src/external/conway/common.inc`.
- Current linked base image: 3010 bytes including the two-byte load header;
  `MAIN` payload is 3008 bytes.
- Current CMake link region: `$0C00` (3072 bytes), leaving 64 bytes.
- Grid buffers: two emitted, relocatable, 960-byte buffers, each `.align 256`.
- Current ZP use: `$70-$7D`; app-private contract permits `$70-$8F`.
- Runtime testing must be performed by the user. `c64-testing` is prohibited
  as broken, and a web emulator is not an acceptable fallback.

The codebase graph returned no indexed Conway symbols during recon, so the
source files were read directly as the repository-approved fallback.

## 3. Scope

### Included

- Menu screen and menu/simulation state dispatch.
- Preset selection and active-rule display.
- Custom rule editing for neighbor counts 0-8.
- Generic RAM-table B/S rule evaluation.
- Fixed-width `gen:00000` counter with 16-bit wraparound.
- Status-line and control-text updates.
- Link-capacity increase with relocation/memory verification.
- User documentation, codebase reference, changelog, brain/task records,
  Taskwarrior annotation, and final walkthrough.

### Excluded

- Changes to the 40x24 toroidal neighborhood topology.
- Pattern loading/saving or an interactive cell editor.
- Rules beyond two-state Moore-neighborhood Life-like B/S rules.
- Generation counts wider than 16 bits; `$FFFF + 1` wraps to `00000`.
- Changes to the OS API, app relocator, or allocator unless verification finds
  a real incompatibility and a separately approved remediation plan is made.
- Restoring or maintaining a Kick Assembler Conway implementation.

## 4. Files and Ownership

| File | Action | Responsibility |
| --- | --- | --- |
| `src/external/conway/common.inc` | Modify | New ZP/state/display constants |
| `src/external/conway/conway_main.s` | Modify | Startup, menu, key dispatch, generation lifecycle |
| `src/external/conway/conway_grid.s` | Modify | Rule storage/loading, generic solver, status/counter drawing |
| `CMakeLists.txt` | Modify | Increase Conway `PRG_SIZE_HEX` after size review; retain alignment 256 |
| `wiki/conway-utility.md` | Modify | User controls, menu, rules, counter |
| `docs/codebase-reference.md` | Modify | Module behavior, ZP allocation, memory/build facts |
| `wiki/tasks/conway-multiverse.md` | Create | Measurable task state and manual checklist |
| `brain/task.md` | Modify | Synchronize phase/subtask state and Taskwarrior ID |
| `brain/MEMORY.md` | Modify at handoff/closeout | Current implementation state |
| `brain/KNOWLEDGE.md` | Modify if decision is durable | Compact rules/menu and memory-layout rationale |
| `CHANGELOG.md` | Modify after implementation | Functional change summary |
| `brain/walkthroughs/conway-multiverse.md` | Create after verification | Evidence and manual walkthrough |

`AGENTS.md` files change only if implementation alters a durable subtree
contract. The current feature design does not require such a change.

## 5. State and Memory Contracts

### 5.1 Zero Page

Add contiguous assignments in `common.inc`:

| Address | Symbol | Meaning |
| --- | --- | --- |
| `$7E` | `zpInMenu` | nonzero in menu; zero in simulation |
| `$7F` | `zpMenuState` | 0 normal, 1 awaiting Birth digit, 2 awaiting Survival digit |
| `$80` | `zpPresetIdx` | 0-8 preset, `$FF` custom |
| `$81` | `zpGenLo` | generation low byte |
| `$82` | `zpGenHi` | generation high byte |

This leaves `$83-$8F` unused. All additions are module-shared equates in
`common.inc`; they are not linker exports and require no `.exportzp`.

### 5.2 Emitted Mutable Storage

Keep mutable state inside emitted relocatable storage so the app-manager's
reserved extent covers it:

- `ruleBirth[9]` and `ruleSurvival[9]`: expanded active lookup tables.
- `digitBuf[5]`: decimal screen digits.
- `tempValLo/tempValHi`: counter conversion scratch if ZP registers cannot be
  safely reused.
- Existing mutable bytes (`dgPageCnt`, `stpBLo`, `stpBHi`) remain emitted.

Do not move the grids or new runtime storage into `BSS` merely to reduce the
file: the current relocation/registration contract is based on emitted app
extent and must not leave writable memory unreserved.

### 5.3 Capacity

The feature cannot fit the remaining 64 bytes. Set Conway's CMake link-region
limit to `$1400` (5120 bytes) for implementation, retaining `CODE_ALIGN=256`.
This is a ceiling, not forced padding; the emitted PRG remains its actual size.

Verification gates:

1. Capture pre/post base-image and final relocatable PRG sizes.
2. Confirm linked `MAIN` use stays below `$1400` with at least 256 bytes spare.
3. Confirm both grid labels are page-aligned in both base and +$0100 links.
4. Confirm relocation footer generation succeeds and includes new absolute
   references that require patching.
5. Confirm preflight allocation accounts for the complete on-disk relocatable
   payload, while post-relocation registration records the clean emitted
   payload, and rejects candidate ranges ending above `$C000` (`$C000-$FFFF`
   is protected).

If less than 256 bytes remain, stop and review data/code layout rather than
increasing the ceiling again tactically.

## 6. Compact Rule Representation

The solver keeps 9-byte RAM lookup tables for its per-cell hot path, avoiding
bit-test overhead inside the 960-cell generation loop. Presets are stored more
compactly as two 9-bit masks per preset:

- Birth mask low byte: counts 0-7; high byte bit 0: count 8.
- Survival mask uses the same layout.
- Nine presets require 36 bytes instead of 162 bytes of expanded ROM tables.
- `loadPreset(A=0..8)` expands both masks into the active 9-byte tables once
  per selection, then returns with `zpPresetIdx` set by the caller.

Preset masks represent:

| Index/key | Name | Rule |
| --- | --- | --- |
| 0 / `1` | Conway's Life | B3/S23 |
| 1 / `2` | Ant Colony | B3/S234 |
| 2 / `3` | World on Fire | B34/S23 |
| 3 / `4` | Blinkers | B345/S2 |
| 4 / `5` | Mazectric | B3/S1234 |
| 5 / `6` | Maze | B3/S12345 |
| 6 / `7` | Life without Death | B3/S012345678 |
| 7 / `8` | Coral | B3/S45678 |
| 8 / `9` | Assimilation | B3/S4567 |

`toggleBirth` and `toggleSurvival` take `X=0..8`, XOR the corresponding
expanded table byte with 1, and set `zpPresetIdx=$FF`.

## 7. Module Interfaces

### `conway_grid.s` exports

Retain existing exports and add:

- `loadPreset`: input A=0..8; clobbers A/X/Y and flags.
- `toggleBirth`: input X=0..8; clobbers A and flags.
- `toggleSurvival`: input X=0..8; clobbers A and flags.
- `drawSimulationStatus`: draws shortened controls plus `gen:` label/digits.
- `drawGenerationCounter`: redraws only five digits.
- `drawRuleSummary`: optional only if menu dynamic rule output remains in the
  grid module; otherwise keep all menu drawing private to `conway_main.s`.

Preferred ownership is to keep menu screen addressing in `conway_main.s` and
export only rule operations from `conway_grid.s`. If menu code needs rule-table
reads, export accessor routines rather than raw data symbols.

### `conway_main.s` private routines

- `enterMenu`, `drawMenu`, `drawMenuDynamics`, `drawMenuPrompt`.
- `handleMenuKey`, `handleSimulationKey`.
- `startSimulation`, `resetGeneration`, `incrementGeneration`.
- `exitToShell`, preserving the existing two-byte stack unwind.

Every routine receives a header comment documenting inputs, outputs, flags,
register clobbers, and memory side effects.

## 8. Startup and State Machine

### Startup

1. Seed LFSR and initialize colors as today.
2. Clear pause/buffer/menu state and generation counter.
3. Load preset 0 (B3/S23).
4. Randomize the active grid once so plain RETURN has a valid initial field.
5. Enter and draw the menu; do not draw the grid first.

### Main loop

`mainLoop` always calls `handleKeys`, then checks `zpInMenu` before pause or
generation work. Menu mode loops without `waitDelay`, solver, swap, or counter
increment. Simulation mode retains the current timing order:

1. Handle key.
2. If key moved to menu or paused, loop.
3. Wait delay.
4. Compute next buffer.
5. Swap buffers.
6. Increment 16-bit generation counter.
7. Draw grid.
8. Draw generation digits.

### Menu keys

- `1`-`9`: load preset, update selection and rule summary.
- `B`: set Birth-edit state and prompt.
- `S`: set Survival-edit state and prompt.
- In edit state, `0`-`8`: toggle exactly one count, mark custom, restore normal
  menu state, redraw dynamics.
- Any non-digit in edit state cancels the edit and restores the normal prompt;
  it is not re-dispatched as a normal-menu command.
- RETURN (`$0D`): reset counter, unpause, draw grid/status, run current field.
- `R`: randomize current buffer, reset counter, unpause, start simulation.
- `Q` or RUN/STOP (`$03`): clear screen, print version banner, unwind and
  return to shell.

### Simulation keys

- SPACE: toggle pause.
- `R`: randomize current buffer, reset counter, redraw grid/counter.
- `C`: clear current buffer, reset counter, force paused, redraw.
- `Q`: enter menu without shell exit; keep current grid and active rule.
- RUN/STOP: exit directly to shell.

RETURN after returning to the menu resumes the retained field with generation
reset to zero. `R` explicitly starts a fresh random field.

## 9. Menu and Screen Rendering

Avoid a literal 960-byte menu image. Clear only the first 960 screen cells,
then copy compact, null-terminated screen-code strings to fixed offsets.

- Store only nonblank menu lines.
- Use `screencode_mixed`/`petscii_mixed` around screen data.
- Use a small fixed-position writer taking source pointer plus screen offset.
- Keep zero-based row 23 (offset 920) as the menu prompt.
- Clear dynamic rule fields before rewriting to prevent stale digits/`none`.
- Draw preset arrow at column 2 on rows 4-12; suppress it for custom rules.
- Keep all strings within 40 columns and all screen writes within `$0400-$07E7`.

Simulation row 24 (offset 960) reserves columns 31-39 for `gen:00000`:

- columns 0-29: shortened control reminder;
- column 30: space;
- columns 31-34: `gen:`;
- columns 35-39: five digits.

Color RAM is initialized once for all 1000 cells as in the existing startup.

## 10. Generation Counter

- `resetGeneration`: store zero to `$81/$82`, then draw digits when visible.
- `incrementGeneration`: `INC zpGenLo`; if it wraps, `INC zpGenHi`.
- Increment only after a completed compute/swap.
- Pause/menu loops never increment.
- Randomize and clear reset to zero.
- A 16-bit value converts to five decimal digits using repeated subtraction by
  10000, 1000, 100, and 10; maximum per-power loop count is 9.
- The converter copies the counter before subtraction and never mutates it.
- `$FFFF` displays `65535`; the next completed generation wraps to `00000`.

## 11. Generic Solver Change

Do not change neighbor counting, row-pointer construction, toroidal wrapping,
destination selection, or buffer swap semantics. Replace only the hardcoded
B3/S23 decision block:

1. Load current cell at `(zpCurrLo),Y`.
2. Move `zpCount` (guaranteed 0-8) to X.
3. Select `ruleBirth,X` for dead or `ruleSurvival,X` for live.
4. Normalize destination to exactly 0 or 1.
5. Restore `Y=zpCol` before `(zpDstLo),Y` store.

Carry is irrelevant across table loads, but every ADC in neighbor accumulation
must retain its explicit `CLC`. Do not allow menu/rule helpers to run inside
the per-cell loop.

## 12. Atomic Implementation Phases

### Phase 1 — Contracts and build headroom

- Update `common.inc` ZP/display constants.
- Change Conway CMake capacity to `$1400`, preserving alignment 256.
- Build `conway`; record baseline/post-change sizes and alignment.
- No runtime behavior change.

Gate: clean link/relocation and at least 256 bytes verified headroom.

### Phase 2 — Rule engine

- Add compact preset masks and active RAM tables.
- Implement preset expansion and custom toggles.
- Replace solver decision block only.
- Default startup remains B3/S23 and current UI remains temporarily intact.

Gate: build; user verifies default Conway behavior before menu integration.

### Phase 3 — Generation counter

- Add reset/increment/conversion/drawing routines.
- Shorten simulation status text and reserve counter columns.
- Integrate counter lifecycle with compute, randomize, and clear.

Gate: build; user verifies increment, pause, reset, `65535`, and wrap behavior.

### Phase 4 — Menu rendering

- Add compact menu strings and fixed-position screen writer.
- Add preset arrow, rule summaries, and edit prompts.
- Initialize menu on startup without altering shell exit yet.

Gate: build; user visually verifies all 24 menu rows and dynamic field cleanup.

### Phase 5 — State-machine integration

- Split menu/simulation key dispatch.
- Add start/resume/random start, simulation-to-menu, and dual exit paths.
- Audit stack depth and the `PLA/PLA/RTS` shell-return sequence.

Gate: build; user performs complete keyboard/state transition matrix.

### Phase 6 — Documentation and closeout

- Update manual, codebase reference, changelog, brain state, task records, and
  Taskwarrior annotation.
- Create walkthrough with exact build results and user verification evidence.
- Perform DOX audit and ask the user whether the task is done.

The task and Taskwarrior item remain in progress until the user explicitly
confirms manual verification and completion.

## 13. Verification Matrix

### Automated/read-only

- `cmake -B build`
- `cmake --build build --target conway`
- `cmake --build build --target image_d64`
- `cmake --build build --target test_image_d64`
- `git diff --check`
- Inspect base/+page linked images and final PRG sizes.
- Inspect symbols/bytes to confirm both grid buffers are page-aligned.
- Inspect relocation footer and registered program extent.

### User-run C64/VICE

1. Menu appears on launch with preset 1 and B3/S23.
2. Keys 1-9 update arrow and exact rule summary.
3. B/S edit prompts accept 0-8, cancel on other keys, and mark custom.
4. Empty Birth or Survival table renders `none` without stale text.
5. RETURN starts/resumes retained grid; R starts a new random grid.
6. Each preset visibly runs and does not crash/corrupt the screen.
7. Counter starts at 00000 and increments once per completed generation.
8. Pause stops both generation changes and counter changes.
9. Randomize and clear reset the counter; clear forces pause.
10. Q from simulation returns to menu without exiting or losing rules.
11. Q and RUN/STOP exit correctly from the menu; RUN/STOP exits correctly
    from simulation; shell prompt and stack remain healthy after repeated runs.
12. Relocate Conway to at least one non-default page through the app manager
    and repeat launch/menu/run/exit smoke checks.

## 14. Risks and Stop Conditions

- **Memory growth:** stop if `$1400` leaves less than 256 bytes or a candidate
  range would end above `$C000`; review compression/layout first.
- **Branch range:** ca65 relative branches are limited to -128..+127; use a
  conditional skip plus absolute JMP when state handlers grow.
- **Stack exit corruption:** do not duplicate ad hoc `PLA/PLA`; funnel both UI
  modes through one audited `exitToShell` path called from `handleKeys`.
- **Stale screen data:** every dynamic field must clear its full width first.
- **Rule-table corruption:** validate digit range before indexing; `zpCount`
  must remain bounded 0-8 by unchanged neighbor logic.
- **Relocation gap:** if emitted data or symbol references are not represented
  in the relocation footer, stop and perform RCA before runtime testing.

## 15. Progress

- [x] High-level rules/menu plan updated for current ca65 tools.
- [x] Feature branch created from updated `main`.
- [x] Production source/build recon completed.
- [x] Taskwarrior task #26 created.
- [x] Detailed implementation plan drafted.
- [x] User approval for phased implementation.
- [x] Phase 1 contracts/capacity implemented, independently audited, and
  confirmed by the user.
- [x] Phase 2 rule engine implemented, independently audited, and manually
  confirmed by the user.
- [x] Phase 3 generation counter implemented, independently audited, and
  manually confirmed by the user.
- [ ] Phases 1-6 implemented and verified.

### Phase 1 evidence (2026-07-14)

- `cmake -B build` and `cmake --build build --target conway` succeeded.
- Build counter advanced to 1048 from the intentional source dependency
  change.
- Linked payload remains 3008 bytes (`$0BC0`); `$1400` leaves 2112 bytes
  (`$0840`) before later feature phases.
- Raw base/+page files are 3010 bytes including their two-byte headers.
- Final relocatable PRG is 3140 bytes with 62 relocation points.
- Base grid labels: `$3800`/`$3C00`; +page labels: `$3900`/`$3D00`.
- Debug-assisted verification links were byte-identical to production links.
- Independent contract review confirmed `$7E-$82` and the new screen offsets
  are inside their documented app-private/screen ranges.

### Phase 2 evidence (2026-07-14)

- Added validated preset loading, custom toggles, private accessors, compact
  mask data, emitted 9-byte active tables, and preset-0 startup initialization.
- Replaced only the solver's hardcoded B3/S23 decision block; neighbor counting,
  toroidal pointers, buffer selection, and swap logic are unchanged.
- `conway`, `image_d64`, and `test_image_d64` builds succeeded as build 1050.
- Linked payload is 3264 bytes (`$0CC0`), leaving 1856 bytes (`$0740`).
- Final relocatable PRG is 3434 bytes with 81 relocation points.
- Base grids are `$3900`/`$3D00`; +page grids are `$3A00`/`$3E00`.
- Debug-assisted links remain byte-identical to production links.
- Two independent reviews verified all preset masks, atomic publication,
  invalid-index behavior, 0/1 normalization, Y restoration, and branch safety.
- User confirmed default B3/S23 behavior, pause, randomize, clear, and shell
  exit work correctly.

### Phase 3 evidence (2026-07-14)

- Added pure reset/modulo-increment lifecycle routines, copied-value 16-bit
  decimal conversion, five-digit drawing, and an exact 40-column status row.
- Counter increments only after compute/swap, does not advance while paused,
  and resets on randomize/clear; clear now forces pause as specified.
- Added assembly-time assertions for 40-column status width and screen bounds.
- `conway`, `image_d64`, and `test_image_d64` builds succeeded as build 1053.
- Linked payload is 3520 bytes (`$0DC0`), leaving 1600 bytes (`$0640`).
- Final relocatable PRG is 3746 bytes with 109 relocation points.
- Base grids are `$3A00`/`$3E00`; +page grids are `$3B00`/`$3F00`.
- Debug-assisted links remain byte-identical to production links.
- First assembly exposed an illegal NMOS 6502 `INC abs,Y`; RCA replaced it
  with explicit `LDA`/`CLC`/`ADC`/`STA`, after which all builds passed.
- Two independent reviews verified carry/borrow behavior, edge vectors,
  wraparound, lifecycle order, status layout, and future menu compatibility.
- User confirmed Phase 3 appears complete after runtime verification.
