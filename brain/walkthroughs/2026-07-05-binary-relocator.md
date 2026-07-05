# Walkthrough: Phase 6B Binary Relocator

This walkthrough details the implementation, verification, and usage of the Phase 6B **Binary Relocator** for `command64-os`.

## Changes Made

### 1. OS Relocator Logic
*   [loader.asm](file:///home/morgan/development/c64/command64-os/src/command64/loader.asm#L94-L221):
    *   Implemented `aptRelocate` to parse the 6-byte footer appended by the relocator build tool.
    *   Verifies magic bytes `'R'`, `'6'`.
    *   If magic matches: computes the relocation offset (`HexValHi - BaseAddrHi`), reads the relocation table, patches all recorded high-byte absolute references in memory, and truncates the program's registered size in `TempLo/Hi` to exclude the table and footer.
    *   If magic does not match (a non-relocatable standard binary): immediately jumps to `aptRelocateFail`, which adds `6` back to restore `TempLo/Hi` to its original value, and returns with Carry set (success path fallback for standard binaries).
*   [shell.asm](file:///home/morgan/development/c64/command64-os/src/command64/shell.asm#L594-L598):
    *   Integrated `jsr aptRelocate` right after `shellLoadPrg` returns successfully and before calling `aptRegister`.

### 2. Build Pipeline Integration
*   [reloc.py](file:///home/morgan/development/c64/command64-os/tools/reloc.py):
    *   Added a Python script that takes two identical builds compiled one page apart (e.g. at `$2600` and `$2700`), diffs them, generates a sorted 16-bit offset table of all high bytes that shifted by exactly `+1` page, and appends this table and a 6-byte footer to the `$2600` base binary.
*   [KickAssembler.cmake](file:///home/morgan/development/c64/command64-os/cmake/KickAssembler.cmake#L87-L141):
    *   Updated the `add_external_app` CMake helper function to compile relocatable apps twice (generating `out_TARGET_2600` and `out_TARGET_2700` outputs), and invokes `tools/reloc.py` to produce the final relocatable `.prg` in the build directory.

### 3. Tests & Utilities
*   [reloc.asm](file:///home/morgan/development/c64/command64-os/tests/src/reloc.asm):
    *   Added a relocatable integration test target that references local subroutines and data blocks to verify absolute patching.
*   [CMakeLists.txt](file:///home/morgan/development/c64/command64-os/CMakeLists.txt#L77-L80):
    *   Updated default `USER_PROG_START_ADDR` to `$2600` and added `Python3` configuration.

---

## Verification Results

### Build Verification
Running `make` successfully executes the double-compile and relocation diffing pipeline:
```bash
$ make
cmake --build build
...
[ 74%] Built target test_handletest
[ 80%] Built target test_hello
[ 85%] Assembling TEST_RELOC at $2600 (relocation base build)
[ 89%] Assembling TEST_RELOC at $2700 (relocation +1 page build)
[ 94%] Building relocatable TEST_RELOC.prg
reloc.py: build/reloc.prg: base=0x2600, 78 code bytes, 2 relocation points
[ 94%] Built target test_reloc
...
[ 98%] Generating D64 disk image: test_image_d64
...
```
All targets assembled and relocated without errors or warnings.

### Manual Verification Instructions
To verify the relocator and the bug-fix:
1.  **Standard Binaries Size Check**:
    *   Boot `command64` in VICE.
    *   Load any non-relocatable program (e.g., standard games/utilities).
    *   Execute `APPS`.
    *   Verify the registered size matches the actual PRG file size exactly (proving that `TempLo/Hi` is restored correctly and not truncated by 6 bytes).
2.  **Relocatable Execution**:
    *   Load the `reloc` test program at a non-standard address:
        ```
        LOAD reloc $4000
        APPS
        ```
    *   Verify it registers at `$4000`.
    *   Run it:
        ```
        RUN reloc
        ```
    *   Verify that it outputs:
        `RELOCTEST v0.1.0.X - Relocated correctly!`
        and returns cleanly to the shell.
