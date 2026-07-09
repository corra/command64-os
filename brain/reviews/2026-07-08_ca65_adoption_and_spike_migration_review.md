# Peer Review: Staged ca65 Adoption and Spike Migration

This review documents the peer evaluation of Claude's proposed plan ([2026-07-08-ca65-adoption-and-spike-migration.md](file:///home/morgan/development/c64/command64-os/brain/plans/2026-07-08-ca65-adoption-and-spike-migration.md)). As the Primary Owner of the `src/external/` scope (defined in [src/external/AGENTS.md](file:///home/morgan/development/c64/command64-os/src/external/AGENTS.md)), the Companion Agent (Gemini) performed this analysis to ensure technical compatibility, toolchain correctness, and build system optimization.

---

## Scope

The following files and systems were reviewed:
1. **`brain/plans/2026-07-08-ca65-adoption-and-spike-migration.md`** — The migration plan.
2. **`spike/ca65-conway/`** — Spike source files, zero-page usage, and linker configs.
3. **`spike/ca65-label/`** — Spike assembly routines, KERNAL calls, and PETSCII encoding.
4. **`spike/ca65-tests/`** — Automated validation tests.
5. **`cmake/Ca65.cmake`** — Spike CMake functions.
6. **`cmake/IncrementBuildNumber.cmake`** — Build counter increments.
7. **`tools/reloc.py`** — Relocation table generation via binary diffs.

---

## Technical Findings & Vulnerability Analysis

### 1. Build Number Integration Syntax Collision (`.const` vs `.define`)
* **File:** [cmake/IncrementBuildNumber.cmake](file:///home/morgan/development/c64/command64-os/cmake/IncrementBuildNumber.cmake) (line 89)
* **Vulnerability:** The script currently writes Kick-Assembler syntax:
  ```cmake
  file(WRITE "${INC_FILE}" ".const ${VAR_NAME} = \"${NEW_VAL}\"\n")
  ```
  If included in `ca65` assembly, this fails immediately. Furthermore, `ca65` does not support string symbols defined with `=`.
* **Remediation:** Modify the CMake build-counter script to support a `CA65` boolean variable. If true, emit `.define` instead of `.const`:
  ```cmake
  if(CA65)
      file(WRITE "${INC_FILE}" ".define ${VAR_NAME} \"${NEW_VAL}\"\n")
  else()
      file(WRITE "${INC_FILE}" ".const ${VAR_NAME} = \"${NEW_VAL}\"\n")
  endif()
  ```

### 2. Zero-Page Imports/Exports Linker Addressing Modes
* **Vulnerability:** In `ca65`, when compiling separate modules independently (e.g. `conway_main.s` and `conway_grid.s`), any symbols imported via `.import` are assumed by the assembler to be 16-bit absolute addresses at compile time. If a zero-page variable is imported this way, `ca65` generates a 3-byte absolute instruction (e.g. `LDA $0070`) instead of a 2-byte zero-page instruction (e.g. `LDA $70`), causing size mismatches and performance degradation.
* **Analysis:** Conway and Label avoid this because they directly `.include "common.inc"`, defining zero-page locations as direct numeric constants (e.g. `zpPrevLo = $70`). Thus, the assembler sees the numeric address during compilation and generates correct zero-page instructions.
* **Remediation:** Update [src/external/AGENTS.md](file:///home/morgan/development/c64/command64-os/src/external/AGENTS.md) to mandate that any future external apps importing zero-page symbols across separate modules must declare them using `.importzp` / `.exportzp` instead of `.import` / `.export`.

### 3. Linker Config File Redundancy and Dynamic Generation
* **Issue:** The spike currently maintains duplicate static linker configurations for every app and address (e.g., `conway_2c00.cfg`, `conway_2d00.cfg`, `label_2c00.cfg`, `label_2d00.cfg`, `test_2c00.cfg`, `test_2d00.cfg`).
* **Remediation:** Eliminate static `.cfg` files from the repository. Modify the `add_ca65_app` CMake function in [cmake/Ca65.cmake](file:///home/morgan/development/c64/command64-os/cmake/Ca65.cmake) to dynamically generate the `.cfg` files at build time using the project's configured `USER_PROG_START_HEX` and `USER_PROG_START_HEX_NEXT` values.
  
  *Template for Generation:*
  ```cmake
  set(CFG_CONTENT "
  MEMORY {
      HEADER: start = $9000, size = $2,    file = %O;
      MAIN:   start = \$${START_ADDR}, size = \$7E00, file = %O, define = yes;
  }
  SEGMENTS {
      HEADER: load = HEADER, type = ro;
      CODE:   load = MAIN,   type = ro, align = 256;
      RODATA: load = MAIN,   type = ro;
      DATA:   load = MAIN,   type = rw;
      BSS:    load = MAIN,   type = bss;
  }
  ")
  file(WRITE "${CMAKE_BINARY_DIR}/${TARGET_NAME}_${START_HEX}.cfg" "${CFG_CONTENT}")
  ```

### 4. Inline Screencode Conversion for Visual Text
* **Issue:** Conway's status line in [conway_grid.s](file:///home/morgan/development/c64/command64-os/spike/ca65-conway/conway_grid.s) is written using hand-calculated screen-code byte tables (`.byte $13, $10, ...`) because `ca65` lacks Kick's `.encoding "screencode_mixed"` directive.
* **Remediation:** Create `include/ca65/screencode.inc` containing local `.pushcharmap` overrides and C64 screen code translation maps. External apps can then define visual strings inline and pop the map safely:
  ```asm
  .include "screencode.inc"
  statusText:
      .byte "space=pause  r=random  c=clear  q=quit"
  .popcharmap
  ```

### 5. Consolidating Test Equates
* **Issue:** [spike/ca65-tests/common.inc](file:///home/morgan/development/c64/command64-os/spike/ca65-tests/common.inc) duplicates OS equates.
* **Remediation:** Remove the test-specific `common.inc`. Ported tests must include the new `include/ca65/command64.inc` directly by passing `-I include/ca65` to the assembler invocation in CMake.

---

## Relocation Safety Verification
We verified that:
1. `reloc.py` relies on the base and next-page binaries having exactly the same size.
2. Because branch instructions in 6502 utilize relative offsets and user program space is located entirely above the zero page, shifts in memory addresses do not alter instruction size or layout. Therefore, the compiled binary lengths will remain identical across the page shift, guaranteeing that the relocation table construction works safely.
