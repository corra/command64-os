# Implementation Plan — Staged Modular OS Rewrite to ca65/ld65

This plan details a phased, modular strategy to migrate the command64 Operating System from KickAssembler to the industry-standard **`ca65` assembler** and **`ld65` linker** (from the `cc65` suite). 

Rather than a risky "stop-the-world" rewrite, this plan allows smaller, encapsulated modules to be rewritten in `ca65` and linked in tandem with the existing KickAssembler codebase, ensuring the OS remains buildable and testable at every stage.

---

## User Review Required

> [!WARNING]
> **Coexistence Mechanism (The Binary Bridge)**
> KickAssembler cannot link `.o` object files directly. To link them in tandem:
> 1.  We compile the migrated module in `ca65` to a raw binary file (e.g. `vmm.bin`) at a fixed memory segment address.
> 2.  We generate a symbol definition file (`vmm_symbols.inc`) from the `ld65` map.
> 3.  We import `vmm.bin` into the main KickAssembler build using `.import binary`, and include `vmm_symbols.inc` for compile-time references.
> *   **Impact:** This maintains strict backward compatibility during migration, but requires keeping segment start addresses fixed until the entire OS is migrated to `ld65`.

### Compatibility with the Python Relocator
During the modular rewrite, we **can still compile and run relocatable external apps using the Python-diff relocator solution (`reloc.py`)**. 
Because the final linked OS binary is still output by KickAssembler during the intermediate stages, all external apps can continue to compile against the OS definitions as usual. Furthermore, once an app is rewritten in `ca65`, we can still compile it twice (using ca65) and diff it using `reloc.py` to create the relocatable footer, keeping the OS loader simple and lightweight.

---

## Proposed Migration Stages

```mermaid
graph TD
    A[Stage 1: CMake & cc65 Toolchain Setup] --> B[Stage 2: Migrate Leaf Modules (petsci, utils)]
    B --> C[Stage 3: Migrate Core Services (vmm, loader, file)]
    C --> D[Stage 4: Migrate Shell & Entry (shell, api)]
    D --> E[Stage 5: Pure ld65 Linker Native Build]
```

### Stage 1: Toolchain & Segment Definitions
*   **cc65 Discovery:** Add `Findcc65.cmake` to CMake to locate `ca65` and `ld65` on the developer's system.
*   **Template Linker Configuration (`cmake/command64-module.cfg`):** Define a standard linker file mapping target segments to memory blocks.
*   **Strict Memory Alignment:** Hardcode segment sizes in `include/command64.inc` to enforce boundaries and prevent accidental overlap clobbering.

### Stage 2: Migrate Leaf Modules (e.g., `utils.asm`, `petsci.asm`)
Migrate independent libraries first to test the toolchain integration.
*   Rewrite `utils.asm` to `utils.s` (ca65 syntax).
*   Add a CMake build target to assemble `utils.s` to `utils.bin` and extract its exports to `utils_symbols.inc`.
*   Import `utils.bin` and `#import "utils_symbols.inc"` inside KickAssembler.

### Stage 3: Migrate Core Services (e.g., `vmm.asm`, `loader.asm`, `file.asm`)
Migrate larger core components. This stage allows us to break down large files:
*   **Virtual Memory Manager (`vmm.asm`):** Break down into `vmm_core.s` (paging mechanism), `vmm_dma.s` (REU drivers), and `vmm_api.s` (Service Bus handlers).
*   **File I/O (`file.asm`):** Split into `file_channel.s` (disk command channel wrappers) and `file_buffer.s` (byte-stream reader/writer).

### Stage 4: Migrate Shell & Entry (e.g., `shell.asm`, `api.asm`)
*   Migrate the stable Service Bus dispatcher (`api.asm`).
*   Migrate the main loop and CLI built-ins (`shell.asm`). Since `shell.asm` is very large (~55KB), we will split it into sub-modules:
    *   `shell_core.s` (initialization, main command loop, line reader)
    *   `shell_cmds.s` (built-in command implementations: DIR, TYPE, COPY, etc.)
    *   `shell_env.s` (environment variables, PATH lookup)

### Stage 5: Pure Native Build
*   Remove the remaining KickAssembler wrapper (`src/command64.asm`).
*   Migrate the SYS launcher/basic header to `ca65` using `.org $0801` and a standard BASIC header macro.
*   `ld65` becomes the sole linker. Segments are now packed dynamically by `ld65` without hardcoded address spacing.

---

## Technical Specifications

### 1. Linker Configuration for ca65 Modules (`cmake/command64-module.cfg`)
Every module compiled by `ca65` will use a configuration file configured for its segment. For example, for the `Vmm` module at `$0B00`:

```ld65
MEMORY {
    ZP:       start = $0061, size = $000C, type = rw, define = yes; # Map OS zero page FAC1 area
    RAM_VMM:  start = $0B00, size = $0200, file = %O, fill = yes;
}
SEGMENTS {
    ZEROPAGE: load = ZP, type = zp;
    CODE:     load = RAM_VMM, type = ro;
    RODATA:   load = RAM_VMM, type = ro;
    DATA:     load = RAM_VMM, type = rw;
}
```

### 2. Automated Symbol Bridge (`tools/lbl2inc.py`)
To map `ca65` exports to KickAssembler, `ld65` will dump symbols in VICE format using `-Ln <file>`. A new python script `tools/lbl2inc.py` will automatically parse and convert them.

**VICE label file format (`vmm.lbl`):**
```text
al 000B00 .vmmAlloc
al 000B2A .vmmFree
```

**Generated KickAssembler include file (`vmm_symbols.inc`):**
```kickass
// Generated automatically from vmm.lbl - DO NOT EDIT
.label vmmAlloc = $0b00
.label vmmFree  = $0b2a
```

### 3. API & Zero-Page Conventions for ca65 Modules
*   **Imports:** `ca65` modules will import zero-page variables (like `TempLo` at `$64`) and kernel functions (like the API stub `apiHandler` at `$1000` or C64 KERNAL routines at `$FFxx`) using `.importzp` or `.global`.
*   **Calling Convention:** Modules will retain standard 6502 assembly registers for parameter passing (e.g., `A/Y` for pointers, `X` for indexes) to match the current stable OS specifications.

---

## Safety & Risk Mitigation Guidelines

To ensure the staged migration proceeds smoothly and does not introduce regressions or memory overlaps:

### 1. Build-Time Segment Size Guarding
During the intermediate stages, `ca65` modules are compiled into binary blobs of fixed sizes. 
*   **Safety Rule:** We will implement an automated build-time check in `CMakeLists.txt` using `math(EXPR ...)` and file size commands.
*   **Enforcement:** If a compiled module (`module.bin`) exceeds the maximum size allocated to its segment in KickAssembler, the build must fail immediately with a descriptive overlap error.

### 2. Automated Symbol Generation in the Build DAG
To prevent address drifts where KickAssembler references outdated function locations:
*   **Safety Rule:** The generation of `<module>_symbols.inc` must be declared as a hard dependency of the KickAssembler compilation step.
*   **Enforcement:** Any change to a `ca65` source file will automatically trigger re-compilation, re-linking, VICE label dumping, and symbol translation *before* KickAssembler compiles the main OS binary.

### 3. Call-Boundary Unit Tests (Regression Testing)
Before migrating any module (e.g., `vmm.asm`):
*   **Safety Rule:** Run the existing automated test suite (e.g., `build_test_vmmtest`) and document the exact expected output/registers.
*   **Enforcement:** After translating to `ca65`, compile and re-run the exact same test target. The test suite must pass with no functional deviations or side effects.

### 4. Zero-Page Area Segmentation & Clobber Protection
Zero-page memory is shared across all modules and the C64 KERNAL.
*   **Safety Rule:** All zero-page variables compiled in `ca65` must be referenced using strict symbol imports (`.importzp`) matching `include/command64.inc`. 
*   **Enforcement:** No raw hex addresses (e.g., `sta $64`) may be used for zero-page variables in the new `ca65` source files. This prevents clobbering and ensures that any future ZP relocations will only need to be modified in `include/command64.inc`.

### 5. CPU Register & Stack Discipline Preservation
*   **Safety Rule:** Every sub-routine rewritten in `ca65` must match the register preservation behavior of its original KickAssembler counterpart.
*   **Enforcement:** If the original routine preserved the `Y` or `X` register using `phy/ply` or zero-page scratch, the `ca65` version must do the same. If a routine changes its register clobber profile, any calling shell/API code must be updated concurrently.
