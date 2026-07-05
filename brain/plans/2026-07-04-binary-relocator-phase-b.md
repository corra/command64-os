# Implementation Plan — Phase 6B: Binary Relocator

This plan outlines the design and step-by-step implementation tasks for Phase 6B (**Binary Relocator**) of the command64 Operating System. The binary relocator enables compiled external utilities to be loaded and run at arbitrary page boundaries in C64 main memory (e.g. `LOAD debug $4000`, `RUN debug`).

---

## User Review Required

> [!IMPORTANT]
> **Page-Relocation Architecture (High-Byte Diffing)**
> We use a **page-relocation** scheme. Under this model, all relocatable binaries must be loaded on a **256-byte page boundary** (e.g., `$2600`, `$3000`, `$4000`).
> *   **Advantage:** Since the low byte of the load offset is always `$00`, absolute low bytes of internal addresses in the code never change, and no carries are generated.
> *   **Impact:** Only the high bytes of absolute addresses (and 8-bit high-byte load instructions like `ldy #>label`) need to be modified.
> *   **reloc.py Diff Build Tool:** A Python script in `tools/` will compile each external app twice (with base addresses `$2600` and `$2700`), compare them byte-by-byte, extract the high-byte offsets that differ by exactly `$01`, and append them as a relocation table at the end of the binary.
> *   **Known limitation:** the byte+1 diffing heuristic cannot distinguish a genuine high-byte address reference from a coincidental data byte that happens to be one less between the two builds (e.g. an unrelated lookup table or literal constant). This is an accepted trade-off of the chosen architecture, not a defect to fix — `reloc.py` should still validate that all *other* bytes are identical, but false-positive relocation points from data bytes remain a theoretical risk.

---

## Review Findings (pre-implementation verification against current code)

Verified against the current codebase before implementation:

1.  **`$03F4–$03F9` are not free scratch — they are already live labels.** `apptable.asm:9-14` declares `AptTempLoadLo/Hi`, `AptTempSizeLo/Hi`, `AptTempEndLo/Hi` at those exact addresses, and `aptRegister` (`apptable.asm:299-336`) actively uses them for overlap-check math. Reusing them in `aptRelocate` is safe *only* because `aptRelocate` must run to completion before `aptRegister` is called next in `cmdLoad` (per the `shell.asm` diff in section 3). **Implementation note: `aptRelocate` must reference the existing labels, not redeclare them** — a duplicate `.label` directive for the same name will likely be rejected by KickAssembler.
2.  **The per-target `build_config.inc` override (Section 2) depends on an unverified assumption about `-libdir` search order.** Every module (`command64.inc:107`) does `#import "build_config.inc"`, currently satisfied by a single file written once at the top level (`CMAKE_BINARY_DIR/build_config.inc`, default `UserProgStart = $2600`). The plan's double-compile scheme requires that a per-target `-libdir` entry (e.g. `build_debug_2700/`) can shadow that global file on a first-match-wins basis. **This should be spiked/tested directly against KickAssembler before building out the full CMake plumbing** — if it doesn't support first-match-wins `-libdir` shadowing, the whole double-compile approach needs a different mechanism (e.g. a distinct include name per config, or `-define`).

Everything else checked out: the ZP addresses in Inputs/Outputs (`HexValLo/Hi=$66/$67`, `TempLo/Hi=$64/$65`, `PrintPtrLo/Hi=$FB/$FC`, `NamePtrLo/Hi=$FD/$FE`) match `include/command64.inc` exactly, and the `shell.asm` diff snippet matches the real `cmdLoad` code verbatim at the correct insertion point.

---

## Proposed Changes

### 1. Build Tools

#### [NEW] [reloc.py](file:///home/morgan/development/c64/command64-os/tools/reloc.py)
A Python helper script that generates a relocatable binary from two builds of the same app (compiled at a 1-page offset, e.g. `$2600` and `$2700`).

*   **Logic:**
    *   Compares the compiled code segments byte-by-byte.
    *   Any index `i` where `code_2700[i] == code_2600[i] + 1` is recorded as a high-byte relocation point.
    *   Validates that all other bytes are identical (reporting errors if unexpected diffs occur).
    *   Appends the 16-bit offset list to the first binary, followed by a 6-byte footer:
        *   `BaseAddr` (2 bytes): Compile-time base address of the first binary (`$2600`).
        *   `TableSize` (2 bytes): Number of 16-bit entries in the relocation table.
        *   `Magic` (2 bytes): ASCII signature `'R'`, `'6'` (`$52`, `$36`).

### 2. Build System

#### [MODIFY] [KickAssembler.cmake](file:///home/morgan/development/c64/command64-os/cmake/KickAssembler.cmake)
Update `add_external_app` to compile the target twice and post-process it:
*   Write `UserProgStart = $2600` into `build_${TARGET_NAME}_2600/build_config.inc`.
*   Write `UserProgStart = $2700` into `build_${TARGET_NAME}_2700/build_config.inc`.
*   Invoke KickAssembler for both configs, directing the library search path (`-libdir`) to the respective config subdirectories first.
*   Run `tools/reloc.py` to produce the final relocatable `.prg` in `${CMAKE_CURRENT_BINARY_DIR}`.

### 3. OS Kernel & Shell

#### [MODIFY] [loader.asm](file:///home/morgan/development/c64/command64-os/src/command64/loader.asm)
Add the `aptRelocate` routine. It reads the footer from the end of the loaded data, patches all high-bytes if `PageOffset > 0`, and truncates the program's size in the registry pointers so that the relocation table is stripped from the active program bounds.

*   **Inputs:**
    *   `HexValLo/Hi` (`$66-$67`): Target load address.
    *   `TempLo/Hi` (`$64-$65`): End address + 1 (returned by KERNAL LOAD).
*   **Outputs:**
    *   `TempLo/Hi` (`$64-$65`): Truncated end address + 1 (representing the clean code size).
    *   Carry flag: Clear on success, Set if an error occurs.
*   **ZP/Cassette Buffer Workspace usage:**
    *   `PrintPtrLo/Hi` (`$FB-$FC`): Table pointer.
    *   `NamePtrLo/Hi` (`$FD-$FE`): Patch pointer.
    *   `$03F4-$03F5`: `AptTempLoadLo/Hi` (Scratch/TableEnd pointer) — **existing labels already declared in `apptable.asm`; reuse them, do not redeclare.**
    *   `$03F6-$03F7`: `AptTempSizeLo/Hi` (TableSize / Final Temp storage) — same existing labels, reused as scratch.
    *   `$03F8`: `AptTempEndLo` (PageOffset) — same existing label, reused as scratch.
    *   Safe only because `aptRelocate` completes before `aptRegister` (which also uses these bytes, for overlap-check math) runs next.

#### [MODIFY] [shell.asm](file:///home/morgan/development/c64/command64-os/src/command64/shell.asm)
Integrate the relocation check into the `LOAD` command handler:
```diff
    // For header loads, LoadAddr is not in HexValLo/Hi — use UserProgStart
    lda SpecificLoad
    beq clGotAddr
    lda #<UserProgStart
    sta HexValLo
    lda #>UserProgStart
    sta HexValHi
 clGotAddr:
    stx TempLo              // end_addr+1 lo (X/Y from KernalLOAD return)
    sty TempHi              // end_addr+1 hi
+   jsr aptRelocate         // run the binary relocator to patch in-place
    jsr aptRegister         // register the patched application
```

### 4. Verification & Testing

#### [NEW] [test_reloc.asm](file:///home/morgan/development/c64/command64-os/tests/src/reloc.asm)
Create an integration test utility that:
*   References internal functions and variables (generating absolute references).
*   Prints a test message and exits.
*   The test framework will build this relocatable binary, load it at a non-standard page address (e.g. `$4000`), run it, and verify successful return to the shell.

---

## Verification Plan

### Automated Tests
1.  Configure CMake and build the disk image:
    ```bash
    cmake -B build .
    cmake --build build
    ```
2.  Verify that all external applications (`debug`, `label`, `conway`) build successfully using the double-compilation and diffing pipeline.
3.  Run the tests on VICE using the test runner (or ask the user to load the generated `test.d64` in the emulator):
    *   Verify that `test_reloc` runs successfully when loaded at a non-standard address.

### Manual Verification
1.  Boot the OS in VICE.
2.  Load `debug` at its default address:
    ```
    LOAD debug
    APPS
    ```
    Verify it registers at `$2600` and executes cleanly.
3.  Load `debug` at a non-standard address:
    ```
    LOAD debug $4000
    APPS
    ```
    Verify it registers at `$4000`. Run the debugger:
    ```
    RUN debug
    ```
    Verify the debugger runs and works flawlessly at `$4000`.
