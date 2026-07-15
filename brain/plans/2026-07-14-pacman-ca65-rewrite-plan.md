# Pac-Man (Pac64) Rewrite Detailed Implementation Plan

This plan outlines a complete rewrite of the Pac-Man external application using **ca65/ld65**, discarding all previous code and design documents in favor of the definitive specification [pac-man-spec.md](file:///home/morgan/development/c64/command64-os/src/external/pacman/pac-man-spec.md).

## 1. Goal

Implement a modular, cycle-efficient, and authentic 6502 Pac-Man game (`pacman.prg`) from scratch:
- Use **ca65/ld65** via the unified `add_ca65_app` CMake builder.
- Design a centered **28x24 playfield** on the 40x25 character grid (columns 6 to 33, rows 0 to 23), leaving row 24 for the score status.
- Implement exactly **240 small dots** and **4 power pellets** to achieve the spec's 2,600 base points.
- Implement authentic ghost pathfinding algorithms (Blinky, Pinky, Inky, Clyde) and behavioral cycles (scatter, chase, frightened, eaten).
- Implement level progression parameters, speed scaling, dot slowdown, fruit spawning, and the Level 256 Kill Screen.

---

## 2. Visual Mock-ups

Below are the premium retro design mock-ups illustrating the layout and behaviors.

### Gameplay Mock-up
The playfield is centered horizontally, utilizing a 28x24 maze boundary with margin padding on columns 0-5 and 34-39. The bottom row serves as a status line displaying the current score, lives remaining, and level:

![Definitive centered 28x24 Pac-Man playfield on the C64 text screen.](/home/morgan/.gemini/antigravity/brain/161a37ec-eb12-462e-8fbd-353a1dfdfdd9/pacman_gameplay_mockup_1784081946656.jpg)

### Level 256 Kill Screen Mock-up
Upon reaching Level 256, an integer overflow simulation corrupts the right half of the display (columns 20-39) with randomized PETSCII data, and locks progression on that side, rendering the game unplayable on the right:

![Level 256 Kill Screen showing visual corruption on the right half of the screen.](/home/morgan/.gemini/antigravity/brain/161a37ec-eb12-462e-8fbd-353a1dfdfdd9/pacman_killscreen_mockup_1784081959732.jpg)

---

## 3. Playfield & Coordinate Map

Centering a 28x24 grid inside C64's 40x25 screen:
- **Grid X (col)**: 0 to 27 map to screen columns 6 to 33.
- **Grid Y (row)**: 0 to 23 map to screen rows 0 to 23.
- **Status Row**: Row 24 displays `score:000000  lives:3  level:01`.
- **Warp Tunnels**: Tunnel row is 10. Columns 0-4 (left) and 23-27 (right) slow down ghosts. Grid col 0 wraps to col 27; grid col 27 wraps to col 0.

---

## 4. Proposed Phased Implementation

### Phase 1: Core Setup & Build Pipeline
- **Task 1.1**: Create `BUILD_PACMAN` initialized to `1000\n`.
- **Task 1.2**: Create `src/external/pacman/common.inc` containing ZP registers and constants:
  - `zpPacRow`/`zpPacCol`/`zpPacDir`/`zpPacNextDir`
  - `zpGhostRow`/`zpGhostCol`/`zpGhostDir`/`zpGhostMode` (4-byte arrays)
  - `zpGameState` (0=menu, 1=playing, 2=life lost, 3=level clear, 4=game over)
- **Task 1.3**: Create entry module `src/external/pacman/pacman_main.s`.
- **Task 1.4**: Update `CMakeLists.txt`:
  - Remove old Kick Assembler target.
  - Add: `add_ca65_app(pacman "${PACMAN_ENTRY}" PACMAN_SRCS 1000 "2800")`
  - Verify that the skeleton compiles and runs a blank screen with a version banner on exit.

### Phase 2: Maze Layout, Draw Engine, and Pac-Man Movement
- **Task 2.1**: Author the definitive 28x24 maze structure in `pacman_game.s`:
  - `mazeWalls`: 672 bytes (0=open, 1=wall, 2=ghost gate).
  - `mazeItems`: 672 bytes (0=none, 1=dot, 2=pellet, 3=fruit).
  - Verify layout contains exactly 240 open tiles with dots and 4 corner pellets.
- **Task 2.2**: Implement screen rendering:
  - Fast screen/color RAM block copy using row offset tables (`row * 40`).
- **Task 2.3**: Implement keyboard poll (W/A/S/D) and joystick read:
  - Direction buffer: queue inputs and resolve turns at the next valid grid intersection.
- **Task 2.4**: Implement movement ticks:
  - Scale base Pac-Man speed: Level 1 (6 ticks/move), Level 2-4 (5 ticks/move), Level 5+ (4 ticks/move).
  - Slowdown penalty: Eating dot adds +1 tick delay, pellet adds +3 ticks delay.

### Phase 3: Ghost Personalities & AI Target Math
- **Task 3.1**: Create `pacman_ai.s` to compute targets each move tick:
  - **Blinky**: Target = Pac-Man tile.
  - **Pinky**: Target = Pac-Man + 4 tiles in facing direction.
  - **Inky**: Target = Double the vector from Blinky to (Pac-Man + 2 tiles).
  - **Clyde**: Target = Pac-Man if distance >= 8, else Clyde's scatter corner (bottom-left).
- **Task 3.2**: Implement candidate tile evaluator:
  - Exclude reverse direction.
  - Calculate straight-line squared distance to target (avoiding multiply via square-table lookup).
  - Tie-break directions in strict order: UP > LEFT > DOWN > RIGHT.
- **Task 3.3**: Timed scatter/chase scheduler:
  - Alternate modes according to jiffy timer counts: scatter (7s) -> chase (20s) -> scatter (7s)...

### Phase 4: Frightened, Eaten, & Spawn Mechanics
- **Task 4.1**: Power Pellet ingestion:
  - Reverse all active ghosts' directions immediately.
  - Frightened duration lookup (Level 1: 360 ticks down to Level 9+: 0 ticks/immediate reverse only).
  - Randomized direction selection via 8-bit LFSR step.
- **Task 4.2**: Consumption & Score logic:
  - Ghost-eating points sequence: 200 -> 400 -> 800 -> 1600.
  - Convert eaten ghost to `MODE_EATEN` (eyes only).
  - Speed up eaten ghost (2 ticks/move) and route to house door (row 10, col 13).
  - Revive ghost upon entering house.
- **Task 4.3**: Warp Tunnel check:
  - Check if normal/frightened ghost is in tunnel region; apply a +3 tick delay penalty.

### Phase 5: Fruit Bonanza & Progression
- **Task 5.1**: Track dots remaining:
  - Spawn current level's fruit below the house at 70 and 170 dots eaten.
  - Set active timer for 600 ticks (~10s).
- **Task 5.2**: Fruit collection:
  - Detect collision, clear item, award level-based bonus score (100 to 5000 points).
- **Task 5.3**: Level increment:
  - Re-generate items on level clear, display level-end flash.

### Phase 6: Kill Screen & Verification
- **Task 6.1**: Level 256 check:
  - If `level == 256`, corrupt the right half of the screen RAM and color RAM with random PETSCII bytes.
  - Lock dot consumption for columns >= 20.
- **Task 6.2**: Comprehensive manual test matrix.
- **Task 6.3**: Write documentation: utility manual (`wiki/pacman-utility.md`) and codebase reference.

---

## 5. Files and Action Plan

- **[NEW]** `src/external/pacman/BUILD_PACMAN`
- **[NEW]** `src/external/pacman/common.inc`
- **[NEW]** `src/external/pacman/pacman_main.s`
- **[NEW]** `src/external/pacman/pacman_game.s`
- **[NEW]** `src/external/pacman/pacman_ai.s`
- **[DELETE]** [pacman.asm](file:///home/morgan/development/c64/command64-os/src/external/pacman/pacman.asm)
- **[MODIFY]** [CMakeLists.txt](file:///home/morgan/development/c64/command64-os/CMakeLists.txt)
- **[MODIFY]** [CHANGELOG.md](file:///home/morgan/development/c64/command64-os/CHANGELOG.md)

---

## 6. Verification Plan

### Automated
- Execute `cmake --build build --target pacman` to ensure compilation.
- Ensure version and build numbers compile correctly.

### Manual
- **Playfield verification**: Ensure maze centers on screen with margin columns black.
- **Ghost behavior check**: Verify Blinky is aggressive, Pinky ambushes, Inky coordinates, Clyde retreats when close.
- **Speed checks**: Validate dot eating slowdown and tunnel speed drop.
- **Kill Screen**: Jump directly to level 256 (via a test compile offset or debugger) and check screen corruption.
