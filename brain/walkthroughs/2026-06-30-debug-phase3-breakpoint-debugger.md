---
feature: debug-phase3-debugger
completed: 2026-06-30
status: completed
---

# Walkthrough: DEBUG Phase 3 - Software Breakpoint Debugger & BASIC ROM Banking

## Summary
Implemented single-step instruction tracing (`T` for step-into) and proceed (`P` for step-over) for the interactive `DEBUG` utility using software breakpoints (`BRK`). To maximize program space, C64 BASIC ROM is banked out on boot (exposing RAM under `$A000-$BFFF`) and restored when exiting to the BASIC prompt. 

Additionally, developed and documented a full test suite of automated verification binaries (`banktest.prg`, `devtest.prg`, and `handletest.prg`) and manual test procedures to ensure system safety, banking correctness, and API reliability. All 9 test programs under `tests/src/` have been integrated with the OS version/build tracking system (`add_external_app`), dynamically checking and incrementing build counters at compile time and displaying their version headers upon execution.

## Files Changed/Created
| File | Change | Notes |
|------|--------|-------|
| [include/command64.inc](file:///home/morgan/development/c64/command64-os/include/command64.inc) | Modified | Extended `UserProgEnd` constant from `$9FFF` to `$CFFF` to reflect the newly available RAM space. |
| [src/command64.asm](file:///home/morgan/development/c64/command64-os/src/command64.asm) | Modified | Relocated `VmmData` segment start address to `$1FA0` to prevent memory link overlap. |
| [src/command64/vmm.asm](file:///home/morgan/development/c64/command64-os/src/command64/vmm.asm) | Modified | Reduced `fileScratch` from 96 to 90 bytes to fit segment constraints. |
| [src/command64/shell.asm](file:///home/morgan/development/c64/command64-os/src/command64/shell.asm) | Modified | Banked out BASIC ROM in `start:` via clearing bit 0 of `$0001` and restored it in `cmdExit:` via setting bits 0-2 of `$0001`. |
| [src/external/debug/debug.asm](file:///home/morgan/development/c64/command64-os/src/external/debug/debug.asm) | Modified | Implemented `cmdTrace`, `cmdProceed`, `decodeTargets` (relative branch target calculations, JSR step-into/step-over, JMP absolute/indirect, RTS/RTI decoding), `setBreakpoints`/`removeBreakpoints` safety guards, stack framing `launchProgram`, and vector hijacking `myBrkHandler`. Integrated virtual PC display (`PC=xxxx`) and register editing (`R PC`). Registered `T`/`P` commands in parser and help message. |
| [CHANGELOG.md](file:///home/morgan/development/c64/command64-os/CHANGELOG.md) | Modified | Added changelog entries for `DEBUG` Phase 3 tracer, BASIC ROM banking, and segment relocation. |
| [tests/src/banktest.asm](file:///home/morgan/development/c64/command64-os/tests/src/banktest.asm) | [NEW] | Automated RAM accessibility verification test for the `$A000-$BFFF` space. |
| [tests/src/devtest.asm](file:///home/morgan/development/c64/command64-os/tests/src/devtest.asm) | [NEW] | Automated device routing parsing verification test for the `DOS_PARSE_PREFIX` ($57) API call. |
| [tests/src/handletest.asm](file:///home/morgan/development/c64/command64-os/tests/src/handletest.asm) | [NEW] | Automated file handle allocation stress and limits boundary test. |
| [CMakeLists.txt](file:///home/morgan/development/c64/command64-os/CMakeLists.txt) | Modified | Updated comment to trigger re-scan for test files globbing. |
| [wiki/debug-test-plan.md](file:///home/morgan/development/c64/command64-os/wiki/debug-test-plan.md) | Modified | Documented manual Test Suites 10, 11, 12, and 13 for Phase 3 breakpoint tracing. |

## Testing Results

### 1. Build Compilation
Ran `make` and verified the project compiles cleanly with zero warnings/errors. The new test targets (`test_banktest`, `test_devtest`, `test_handletest`) compile successfully and are appended to the `test.d64` disk image.

### 2. Automated Test Executions
* **`banktest.prg`**: Verifies that memory banking works during shell execution. Successfully writes a sequential pattern to `$A000-$A0FF` and `$B000-$B0FF`, reads it back, validates matches, and prints:
  ```text
  MEM EXPANSION & ROM BANKING: PASS
  ```
* **`devtest.prg`**: Verifies `DOS_PARSE_PREFIX` ($57) behavior. Parses `"8:testfile"`, `"10:data"`, and `"myfile"` (no prefix). Validates resolved devices (8, 10, and active drive), carry flags, and pointer adjustments. Prints:
  ```text
  DOS_PARSE_PREFIX API: PASS
  ```
* **`handletest.prg`**: Verifies file handle bounds. Deletes old test files, opens 8 concurrent files (`t0.prg` to `t7.prg`), attempts to open a 9th (confirming it fails with error), closes all 8 handles, and cleans up the files. Prints:
  ```text
  FILE HANDLE STRESS & API: PASS
  ```

### 3. Manual Verification Checklist
Verified via Commodore 64 environment simulation:
* **Single-Step Loop Test**: Verified assembly of a loop at `$2000` and execution of `T` step-into (correctly disassembling and updating registers for `LDA`, `INX`, `CPX`). Verified that calling `P` on the `BNE` conditional branch proceeds through the loop and breaks on the `RTS` at `$2007` with the expected register state (`X=03`).
* **ROM Target Safety**: Verified that step-into (`T`) on a `JSR $FFD2` (KERNAL CHROUT) acts as a step-over and breaks at `$2003`. Verified that stepping into `JMP $FFD2` (ROM) is safely blocked, displaying `error: cannot trace target in ROM` and returning to prompt.
* **Exit Banking Restoration**: Verified that typing `Q` and then `EXIT` exits to the BASIC warm prompt `READY.` without hanging and restores BASIC ROM mapping.

## Lessons Learned & Gotchas
* **Memory Management limits**: Extending resident program segments (like `CommandShell`) can cause Linker Memory Overlaps with subsequent segments (like `VmmData`). Shifting non-execution data segments (`VmmData` start to `$1FA0`) and slightly reducing non-critical buffers (like `fileScratch` to 90 bytes) resolves these overlaps while maintaining code integrity.
* **RTI Stack Context**: When preparing stack frames for `RTI` execution launcher, it is vital to backup the debugger stack pointer (`TSX; STX dbgS`) so the hijacked interrupt handler can restore the stack context cleanly via `LDX dbgS; TXS` and return control to the main command loop via standard `RTS` propagation.
