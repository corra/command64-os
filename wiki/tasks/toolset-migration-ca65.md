# Task Spec: Staged Toolset Migration to ca65/ld65

## Description
Perform a staged modular migration of the operating system's assembly codebase from KickAssembler to `ca65` and `ld65`. This is an *In Tandem* task designed to proceed incrementally after Phase 6B (Binary Relocator) is complete, maintaining system stability and build integrity at each step.

---

## Core Directives & Constraints

*   **Primary C Compiler:** **Oscar64** remains the primary compiler for C programs. Its optimizations produce superior binaries for C64 code. The `cc65` compiler (`cc65` executable) will NOT be used for C files; only the assembler (`ca65`) and linker (`ld65`) will be used to compile/convert assembly source code.
*   **Assembler Coexistence:** 
    *   `ca65`/`ld65` is the assembler/linker of choice for all rewritten and newly added assembly files.
    *   **KickAssembler** is maintained for all legacy, unconverted assembly files.
*   **Header Comments Cue:** To prevent compilation errors due to differing syntaxes, every assembly source file in the project must begin with a clear header comment indicating the assembler target style (e.g. `// Target Assembler: KickAssembler` or `; Target Assembler: ca65`).
*   **Active Build Chain:** Keep all build tools and scripts fully up to date.

---

## Scope & Stages

### Stage 1: Infrastructure & Verification Tests
*   Add `Findcc65.cmake` to CMake.
*   Define fixed memory segments in `include/command64.inc` for binary bridging.
*   Write `tools/lbl2inc.py` to bridge `ld65` maps to KickAssembler symbol includes.
*   Add automated CMake checks to guard and error out if any `ca65` binary block exceeds its segment size constraint.

### Stage 2: Leaf Module Migration
*   Convert `petsci.asm` to `petsci.s` (ca65 syntax) and verify console prints.
*   Convert `utils.asm` to `utils.s` and verify hex/string helper functions.

### Stage 3: Core Service Migration (Monolith Deconstruction)
*   Deconstruct `vmm.asm` into `vmm_core.s`, `vmm_dma.s`, and `vmm_api.s`.
*   Deconstruct `file.asm` into `file_channel.s` and `file_buffer.s`.
*   Convert `loader.asm` to `loader.s`.

### Stage 4: Entry & Shell Migration
*   Convert `api.asm` (Service Bus entry).
*   Deconstruct `shell.asm` into `shell_core.s`, `shell_cmds.s`, and `shell_env.s`.

### Stage 5: Pure Native Build Conversion
*   Remove the remaining KickAssembler wrapper (`command64.asm`).
*   Migrate the BASIC SYS entry header to `ca65` and make `ld65` the sole system linker.

---

## Sub-tasks
- [ ] Add `cc65` CMake discovery and initial module configuration template.
- [ ] Implement size-guard checks in `CMakeLists.txt` for binary modules.
- [ ] Implement `tools/lbl2inc.py` symbol-mapping bridge script.
- [ ] Add target assembler header comments to all existing `.asm` files.
- [ ] Migrate leaf module `petsci.asm` -> `petsci.s`.
- [ ] Migrate leaf module `utils.asm` -> `utils.s`.
- [ ] Migrate core module `vmm.asm` -> `vmm/*.s`.
- [ ] Migrate core module `file.asm` -> `file/*.s`.
- [ ] Migrate core module `loader.asm` -> `loader.s`.
- [ ] Migrate api module `api.asm` -> `api.s`.
- [ ] Migrate shell module `shell.asm` -> `shell/*.s`.
- [ ] Convert build system to pure native `ld65` linking.
