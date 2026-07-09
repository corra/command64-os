# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Conway Multiverse Research**: Saved video transcript to `brain/research/conway_multiverse_transcript.txt` and completed implementation plan `brain/plans/conway-multiverse-rules-and-menu.md` for adding main menu, preset/custom rules, and generation counter.

### Documentation

- **Documentation Audit & Sync**: Brought `README.md`, `docs/programmers-reference.md`, `docs/codebase-reference.md`, `docs/user-manual.md` (and their `wiki/` mirrors) up to date with the shipped Binary Relocator, `LOAD` name/addr/size reporting, `DIR` byte-size reporting, global no-args `FREE`, dynamic memory allocation (auto-slotting), and memory-safe pre-flight `LOAD` validation. Corrected stale `UserProgStart` address references (`$2000`/`$2200`/`$2600`) to the current `$2C00` across all docs, and reconciled `wiki/tasks/memory-safe-loading.md`, `wiki/tasks/dynamic-memory-safety.md`, and `wiki/tasks/phase-6b-binary-relocator.md` checkboxes with shipped status. Fixed a `UserProgStart` shift-history inconsistency between `brain/MEMORY.md` and `brain/KNOWLEDGE.md`.

### Added

- **VI Alike External Editor**: Developed a user-space external editor (`vi.prg`) running in RAM from `UserProgStart` up to `$C000`. Features:
  - **Memory Management**: Utilizes an efficient O(1) Gap Buffer in RAM, supporting document sizes up to ~35KB.
  - **Editing Modes**: Implements Command Mode (movement, deletions, yanking, pasting), Insert Mode (interactive text insertion, carriage returns, destructive backspace/DEL), and Last-Line Mode (prompts on row 24 for file save/exit and editor configuration).
  - **Movement Features**: Character-based movement (`h`, `j`, `k`, `l` and arrow keys), word-based movement (`w`, `b`), and line boundary movement (`0`, `$`). Vertical movement preserves original target columns across different line lengths.
  - **Editing Features**: Supports single-character delete (`x`), word delete (`dw`), line delete (`dd`), line yanking (`yy`), and paste (`p`/`P` for character/word or whole line pasting).
  - **Line Number Mode**: Implements a togglable line number mode (`:set nu` / `:set nonu`) rendering a 5-column line number margin on the left with tilde (`~`) fillers past the end of the file.
  - **File I/O**: Loads file from command line argument (e.g. `VI test.txt`) on startup and saves file (with overwrite protection via early delete) using stable DOS API calls.
  - **Horizontal Scrolling**: Automatically scrolls text horizontally (`leftCol` tracking) and vertically (`topLine` tracking) to keep the cursor visible.
- **Fast Path for Protected Addresses**: Restored the early `aptProtectedCheck` check in `cmdLoad` for user-specified address loads, instantly rejecting explicitly protected destinations (like `LOAD "PROGRAM" $1000`) before accessing the disk.
- **Dynamic Memory Allocation (Auto-Slotting)**: Implemented `aptFindFreeRegion` in `apptable.asm`, a sliding-window page allocator that dynamically finds the first free, page-aligned region large enough to fit a candidate program between `UserProgStart` and `$C000`. Wired the allocator into `cmdLoad` to execute when no address is specified on `LOAD`. Reports `out of memory` if no fitting space is found.
- **Memory-Safe Loading (Pre-flight Validation)**: Implemented pre-flight range checks for relocated programs (`SpecificLoad=0`). Added `getFileSize` (using secondary address 0 filtered directory read to skip the header and parse file block counts) and `aptCheckRange` (checks memory collisions against protected OS space `$0000–$29FF`, `$C000–$FFFF` with 16-bit wrap-around detection and active app table registry slots). If any check fails, the KERNAL load is aborted before memory transfer and displays `protected address` or `address overlap`.
- **DIR byte-size reporting**: Added file size reporting in bytes to the directory listing (`DIR` command) using a highly optimized, loop-free 6502 math routine (`calcFileSize`) computing `Size = Blocks * 254 = (Blocks * 256) - (Blocks * 2)`. Added `printDecimal24` supporting 24-bit decimal printing with leading-zero suppression.
- **UserProgStart memory shift**: Shifted the user program origin (`UserProgStart`) from `$2600` to `$2C00` to accommodate resident OS memory growth (specifically the `ShellExt` segment growing to `$2A52`). Updated the CMake build scripts to dynamically pass program start and relocation base addresses (`$2C00` and `$2D00`) to KickAssembler builds.
- **Global free-all Command**: Added support for invoking the `free` command without arguments to deregister all loaded, inactive programs in the App Table. Prints the names of freed apps during the sweep.

### Fixed

- **Bounds Checking Code Refactor**: Factored out duplicate VMM slot boundary parsing and end-address calculations in `apptable.asm` into a shared `aptGetSlotRange` helper, reducing code size and saving 53 bytes of RAM in the `AppTable` segment.
- **Conway memory safety & relocation crash**: Modified both Kick Assembler `conway` and ca65 `conwayca` to define their double grid buffers as page-aligned, relocatable data tables inside the binary (`.align 256` in ca65 and `.align $100` in Kick). This increases the registered program size to 3008 bytes, allowing the OS memory manager to reserve the buffer space and prevent auto-allocation collisions, while allowing the relocator to patch the buffer pointers dynamically.
- **App Table Eviction Refactor**: Deleted the obsolete overlap-eviction check in `aptRegister` to prevent silent program deletion after memory clobbering, enforcing pre-flight validation rejection instead.
- **Directory Parser and Smoke Test Cleanup**: Reverted all temporary directory capture buffers, quote mirroring logic, and printout smoke tests left in `cmdDir` (`shell.asm`) during development.
- **Binary Relocator register restoration**: Fixed a bug in `aptRelocate` (`src/command64/loader.asm`) where `TempLo/Hi` (the end address + 1) was not restored when the relocation magic check failed. This previously caused standard non-relocatable programs loaded from the shell to be registered in the app table with a size 6 bytes smaller than their actual size.
- **CMake config rebuild dependency**: Added `build_config.inc` as an explicit dependency for `command64` so that changing `UserProgStart` or other cache variables triggers an automatic reassembly of the shell.
- **Directory size printing corruption**: Resolved a corruption issue where `fileInit` would overwrite the end of the `ShellExt` segment (where directory sizes are calculated/printed) at boot.

## [0.3.0] - 2026-07-04

### Added

- **App Manager Phase A — Program Registry (`APPS`, `PS`, `FREE`)**:
  - Implemented a resident program registry table supporting up to 16 concurrent loaded programs.
  - Implemented `aptInit` (idempotent VMM allocation), `aptFind` (bidirectional search by name or address), `aptRegister` (checks and evicts memory-address range overlaps, then registers name, address, and size), and `aptRemove` (evicts entry).
  - Integrated `aptList` and `aptPrintHex8` routines to display the registry table via the `APPS` / `PS` commands.
  - Integrated the program registry into `LOAD` and `RUN` commands in the command shell, requiring registered membership before execution, performing protected range checking against `UserProgStart`, and resolving name or address arguments dynamically.
  - Added the `FREE <name>` command to evict active applications from the registry.
- **DEBUG Status Flags Editing (`R P` / `R`)**: Extended the `R` command to display CPU status register flags on a second line in the format `P=XX: N=x V=x * B=x D=x I=x Z=x C=x` (with bit 5 reserved and displaying as `*`). Supported editing the status register `P` either as a whole 8-bit hex number or by modifying individual flags via case-insensitive, space-separated equations (e.g. `n=1 c=0`), with validation checking.
- **DEBUG Phase 3 - Software Breakpoint Debugger (`T`, `P`)**: Implemented single-step instruction tracing (`T`) and proceed step-over (`P`) using software breakpoints (`BRK`). Added context-restoring launcher (`launchProgram`) framing PC, registers, and flags onto the stack for launch via `RTI`, and interrupt hijack handler (`myBrkHandler`) intercepting the `CBINV` vector (`$0316/$0317`), restoring vectors/memory, printing virtual registers and disassembling the next instruction. Includes branch target calculations (taken/not-taken), indirect jumps with NMOS page-wrap emulation, call step-overs, and ROM safety guards.
- **BASIC ROM Banking**: Integrated memory banking on boot (`start:`) to disable BASIC ROM (`$A000-$BFFF`), exposing 8KB of RAM and expanding contiguous User Program Space to `$2000-$CFFF` (44KB). Restores BASIC ROM on `cmdExit` (`ora #$07` on `$0001`) before returning to BASIC prompt (`jmp $E37B`).
- **CONWAY External Command**: Implemented a full-screen Conway's Game of Life cellular automaton utility (`conway.asm`) for the C64. Features double-buffered computation at `$3000`/`$3400`, toroidal boundary wrapping on all edges, and a fast precomputed row-offset lookup table. Includes timing control based on the KERNAL jiffy clock, an 8-bit Galois LFSR pseudo-random generator, and interactive keyboard controls (SPACE to pause, R to re-randomize, C to clear, and Q/RUN-STOP to quit). Integrated the program into the CMake build system, the OS disk image (`conway.prg`), user manuals, and the codebase reference.
- **DEBUG Phase 2 - Interactive Inline 6502 Assembler**: Implemented the inline assembler command (`A [address]`) supporting direct line-by-line compilation of all 56 standard 6502 mnemonics and 13 addressing modes. Added a robust PETSCII case-normalization routine (`toUpper`) mapping all variations of user-typed letters (lowercase, uppercase, and shifted) to match the internal opcode and register symbol dictionaries. Added operand parser supporting optional `$` prefix, signed 8-bit branch relative target calculations, and automatic zero-page promotion fallback lookup. Integrated the command into help display.
- **DEBUG Full Feature Test Plan**: Created a comprehensive manual verification plan for the `DEBUG` utility, covering all existing interactive commands (Dump, Enter, Fill, Move, Compare, Search, Register display/edit, Hex math, Go, Version, Help), input buffer edge cases, and filename and disk I/O. Added placeholder test suites for the planned assembler and breakpoints. Updated CMakeLists.txt build-time documentation sync and the Code Wiki index.
- **DEBUG Load SEQ and USR Files**: Added support for loading sequential (`SEQ`) and user (`USR`) files into memory via custom byte-by-byte file streaming. Added optional type prefix parsing (`L [P/S/U] [addr]`) matching the `W` command syntax.
- **DEBUG Interactive Registers**: Added interactive register modification support (`R [register]`) to the `DEBUG` utility, enabling viewing and modifying individual CPU registers (`A`, `X`, `Y`, `P`, `S`) with 8-bit hex validation and far branch condition correction.
- **DEBUG Utility Feature Parity Plans**: Documented complete implementation roadmaps and blueprints for achieving parity with MS-DOS `DEBUG`: Phase 1 (Interactive registers `R` and File I/O `N`/`L`/`W`), Phase 2 (Interactive 6502 assembler `A`), and Phase 3 (Software breakpoint tracer `T`/`P`). Added individual phase plan documents to `brain/plans/`, registered a new meta-task and sub-tasks in Task Warrior, and updated the Code Wiki user guide.
- **Target Device Routing**: Added support for mapping prefixes `8:`, `9:`, `10:`, `11:` to devices for all disk access commands: `DIR`, `TYPE`, `COPY`, `DEL`/`ERASE`, `REN`/`RENAME`, `VOL`, and the external `LABEL` utility. Supports independent device routing for source and destination in `COPY` (e.g. `COPY 9:FILE 8:FILE`). Omitting device prefixes correctly defaults to the active device at command invocation.
- **Drive Switch Shortcut**: Added support for typing `<device_number>:` (e.g. `9:`) directly at the command prompt to permanently switch the active drive, equivalent to `drive <device_number>`.
- **COPY Command Improvements**: Enabled defaulting destination filename to the source filename when copying to a device prefix (e.g. `COPY 9:FILE 8:`).
- **LABEL Build Tracking**: Added build counter and automated build tracking to the external `LABEL` utility, matching the behavior of `COMMAND64` and `DEBUG`. The version header (e.g. `LABEL v0.1.0.1001`) is displayed on utility execution.
- **CMake Build System Migration**:
  - Replaced the legacy single GNU Makefile with a modular, cross-platform CMake build system configured via root `CMakeLists.txt`.
  - Implemented custom CMake Find modules (`FindKickAss.cmake`, `Findcc1541.cmake`, `FindOscar64.cmake`) and target helpers (`KickAssembler.cmake`, `cc1541.cmake`, `Oscar64.cmake`) to manage toolchain paths and discovery natively.
  - Created a cross-platform build-time counter script (`IncrementBuildNumber.cmake`) and release packager (`PackRelease.cmake`) executing via `cmake -P` to replace shell-dependent cat/tar/zip commands.
  - Configured a Makefile wrapper proxy to forward standard commands (`all`, `image`, `testimage`, `test`, `release`, `clean`) to CMake for backward compatibility.
  - Updated all build system documentation, including `README.md` and `CLAUDE.md`.
- **Project Infrastructure**:
  - Initialized Codebase Memory knowledge graph for `command64-os`.
  - Configured Taskwarrior with 5 active and pending milestones under the `command64-os` project.
  - Created a structured Code Wiki under the `wiki/` directory including Home, User Manual, Debug Utility, API Reference, Programmer's Reference, VMM Specs, PETSCII Library, and C64 Hardware Gotchas.
  - Added individual task spec files under `wiki/tasks/` to track milestone requirements.
  - Registered `VOL/LABEL` (Task #17), `TIME` (Task #18), and `DATE` (Task #19) commands in Taskwarrior and `brain/task.md`.
  - Corrected path mismatches in root `AGENTS.md` child DOX index and established missing child contracts (`src/AGENTS.md`, `tests/AGENTS.md`, `wiki/AGENTS.md`, `wiki/tasks/AGENTS.md`).
- **Phase 5: Environment Support**:
  - Implemented Master Environment Block (4KB) in the REU.
  - Added `SET` internal command to display environment variables.
  - Added `PATH` internal command placeholder for future executable search logic.
- **Program Execution**:
  - Implemented `RUN` and `GO` internal commands to execute programs at arbitrary memory addresses (defaults to `$2000`).
- **Multi-Device Support**:
  - Implemented `DRIVE` command (with `DEVICE` and `DEV` aliases) to switch active C64 device (8-11).
  - Replaced hardcoded device #8 references with dynamic `CurrentDevice` workspace variable.
  - Enhanced `DRIVE` command to report current device if called without arguments.

### Changed

- **Memory Layout & Program Relocation**:
  - Chained all pre-API OS segments (`Utils, Api, Loader, Path, Vmm, File`) consecutively using `startAfter` definitions to eliminate all unused padding gap bytes.
  - Defined a new segment `ShellExt` at `$2200` and moved long help/version string blocks (`verMsg`, `helpMsg`) there to free up contiguous space in `CommandShell`.
  - Shifted `USER_PROG_START_ADDR` to `$2600` in CMake and refactored the OS address checks (`aptProtectedCheck`) to dynamically use `>UserProgStart` to prevent runtime overlap collisions.
- **VmmData Segment Relocation**: Shifted `VmmData` segment start to `$1FA0` and reduced `fileScratch` to 90 bytes. This prevents memory link overlap with the expanded `CommandShell` segment.
- **Refactored Device Routing**: Centralized target device prefix routing (`8:`, `9:`, etc.) from individual shell commands and external utilities into the core filesystem primitives (`fileOpen`, `fileDelete`, `fileRename`) and a new API function `DOS_PARSE_PREFIX` ($57). This eliminates duplicate parsing code, reduces side-effect risks (no longer overriding `CurrentDevice` in shell commands), and reclaims resident shell memory.
- **Centralized Segment Packing**: Relocated the memory start addresses of all core OS segments (`Utils`, `Api`, `Loader`, `Path`, `Vmm`, `File`) in `src/command64.asm` to allow optimized packing and eliminate memory overlap issues as segments grow.
- **DEBUG Utility Range Refactoring**: Refactored the range-checking logic in `debug.asm` to reduce duplication. Extracted a centralized `checkRangeLimit` subroutine for single-byte step checks, simplified the length specifier case-masking check in `parseRange` to a single instruction, and optimized inclusive boundary address checks in `cmdUnassemble` and `cmdDump` by reversing comparisons.
- **Assembly Imports Refactoring**:
  - Removed hardcoded relative build directory prefixes from `src/command64/shell.asm` and `src/external/debug/debug.asm`.
  - Configured KickAssembler's `-libdir` search path to find build-time generated counters dynamically.
- **Memory Layout Consolidation**:
  - Relocated OS segments (`Api`, `Loader`, `Path`) to the `$0D00-$0FFF` range.
  - Realigned `CommandTable` ($1080) and `CommandShell` ($1180), providing over 2.5KB of growth space for the shell.
- **System Automation**:
  - Implemented persistent build number tracking (`BUILD_OS`, `BUILD_DEBUG`) in the Makefile.
  - Automated `.inc` generation for injecting build numbers into assembly without manual source edits.
- **Disk Image Format**:
  - Stripped `.prg` extensions from disk directory entries for cleaner command resolution.
  - Centralized PETSCII encoding and improved `normalizeName` to correctly map shifted characters for disk matching.

### Fixed

- **Device Presence Check Registry Bug**: Fixed a bug in `checkDeviceReady` (`src/command64/file.asm`) where `ldx CdrDevice` was called prior to `KernalSETNAM`. Because the KERNAL `SETNAM` routine can modify/clobber the `X` register, the device number was lost or corrupted before `KernalSETLFS` was called, causing disk presence status checks to fail or check wrong devices. Moved `ldx CdrDevice` to immediately after the `KernalSETNAM` call.
- **App Table Garbage Memory Bug**: Added a page-zeroing loop to `aptInit` (`src/command64/apptable.asm`) to clear the newly allocated 4KB App Table virtual memory segment in the REU. This prevents random power-on RAM/REU garbage data from corrupting active slots and the `UsedSlots` counter, which previously caused the shell commands to display phantom active programs and erroneously report `app table full` on `LOAD`.
- **VMM Bank Register Mapping (S1)**: Corrected `vmmComputeAddress` to combine `VmmBank` (the 1MB block index) with the bank offset `(VmmSegHi >> 4)` into the final `REU_REU_BANK` register, allowing memory reads/writes to span the full 16MB REU space without wrapping into Bank 0.
- **Shell Environment Bank Tracking (S2)**: Fixed `shell.asm` to preserve `VmmBank` into `EnvBank` on environment initialization and load it back before environment variable VMM read/write operations.
- **Segment Overlap & String Cleanup**: Removed the unused `notImplMsg` string from `shell.asm` to reclaim 36 bytes of memory and prevent `CommandShell` from overlapping `VmmData` at `$1FA0`.
- **DEBUG Parser Backtracking Bug**: Fixed a register name parsing bug where looking ahead for register `PC` (when `'p'` was typed) and backtracking via `dey` clobbered the register name character in accumulator `A`. Added logic to reload and normalize the character from `inputBuf, y` before parsing as a single-character register, allowing both `r p` and single-character register edits (`r a`, `r x`, etc.) to execute correctly.
- **DEBUG printBitA Calling Convention**: Standardized the `printBitA` helper subroutine to use clean subroutine returns (`jsr KernalChROUT` + `rts`) instead of tail-call jumps (`jmp KernalChROUT`).
- **DEBUG Filename Buffer Corruption**: Implemented length pre-scanning inside the name (`N`) command to reject too-long input strings ($>32$ characters) before modifying the internal filename buffer, preventing filename corruption.
- **DEBUG Load Custom Channel Secondary Address**: Corrected the KERNAL secondary address from `0` (which is reserved by Commodore DOS for `LOAD` operations) to `2` inside the custom byte-by-byte loader, restoring proper file reading for non-program file streams.
- **DEBUG Case Normalization**: Fixed register name case-normalization in `cmdRegs` (`R` command) to use `and #$7F` instead of `ora #$20`, ensuring compatibility with `petscii_mixed` character encoding and resolving `error` outputs for both uppercase and lowercase inputs.
- **DEBUG Command Fallback Logic**: Added strict validation to single-address command fallbacks in `cmdDump` (`D`) and `cmdUnassemble` (`U`), ensuring that range syntax errors (such as start address > end address) immediately return `error` instead of silently falling back to a single-address default print.
- **Device Detection & Switching Cleanup**: Resolved a critical issue where querying/accessing a non-existent device left the KERNAL's logical file tables corrupted with an orphaned open channel. Added explicit `KernalCLOSE` cleanup calls to error paths in `cmdDir`, `cmdVol`, `fileOpen`, and `label.asm`, restoring proper device routing and preventing subsequent accesses to valid devices (like device 8) from failing with "Device not present".
- **DEBUG Global Range Order Validation**: Implemented a global range verification check inside `parseRange` to enforce `rangeStart <= rangeEnd`, preventing infinite wrapping loops and memory corruption across `W` (Write), `F` (Fill), `S` (Search), and `M` (Move) commands.
- **DEBUG Load Command Address Tracking**: Corrected `cmdLoad` to update `currentAddr` to the program's starting address upon successful loads (supporting relocated addresses and reading KERNAL `$C1/$C2` for header loads). Also fixed `cmdLoad` to immediately reject invalid address arguments with `error` instead of silently falling back to header loading.
- **DEBUG Utility Range & Dump**:
  - Fixed uppercase `L` (Shift+L) length parameter parsing case-sensitivity bug in `parseRange` where it was compared to the compiled value of `'L'` after masking.
  - Implemented proper range and length parameter support in `cmdDump` (`D` command), preventing it from ignoring end address/length specifiers and defaulting to a fixed 128-byte dump.
  - Fixed a critical bug in `parseHexArg` where lowercase hex letters `a`–`f` (PETSCII `$41`–`$46`) were incorrectly rejected as invalid characters due to assembler encoding side effects.
  - Fixed a critical parser corruption bug in `prLength` where the `Y` register (which acts as the parser index `y`) was clobbered during 16-bit range calculations. This caused trailing command arguments (like fill bytes or copy destinations) to be parsed from the beginning of the buffer, producing syntax errors.
- **File System Primitives**: Fixed a critical bug in `file.asm` where drive suffixes `,S,W`, `S:`, and `R:` were compiled as shifted PETSCII due to `petscii_mixed` encoding, causing drive-side syntax errors. Replaced them with unshifted byte values (`$53`, `$57`, `$52`). Also, prepended the drive number `'0'` (e.g. `S0:`, `R0:`) to scratch and rename command strings to comply with the standard 1541 DOS syntax. Changed default file creation suffix from `,S,W` (Sequential Write) to `,P,W` (Program Write) to preserve the `PRG` file type on copied files.
- **Shell Command Table**: Restored the accidentally deleted `cmdPath` handler and corrected the `tableCmd` command table alignment to prevent crashes when executing commands.
- **LOAD Command Address Parsing**: Restructured `cmdLoad` to parse optional target addresses before parsing zero-page pointers, preventing `TempHi` from being clobbered by `parsePointerDevice`. This fixes a critical bug where `LOAD` either relocated programs to page zero ($000D) or corrupted hex arguments.
- **LOAD Command Filename Length Restoration**: Fixed register `X` (filename length) clobbering in `cmdLoad` by preserving the stripped length in `TempLo` and loading it back into `X` immediately before calling `findFile`.
- **External LABEL Utility**: Relocated the drive initialization command (`I`) to execute *before* the data channel is opened. This resolves the `"70,no channel"` error by avoiding resetting buffers after they have been allocated for the data channel. Updated the U1, B-P, and U2 command strings to use standard colons (`U1:`, `B-P:`, `U2:`) to ensure correct parsing across drive firmware. Also, implemented a BAM cache flush by sending the `"I"` command again *after* a successful block write, forcing the drive to synchronize its internal BAM cache with the disk so the new label takes effect immediately.
- **Parsing Robustness**: Centralized argument parsing via `shellSkipSpaces` to prevent label-reuse bugs.
- **Filename Match**: Resolved issue where lowercase disk entries failed to match normalized uppercase shell input.
- **Volume Name & Label**: Fixed the `31,syntax error` in `cmdLabel` by using raw binary parameters (`U1:`, `B-P:`, `U2:`) sent byte-by-byte instead of ASCII string representation. Fixed a data channel LFN clobbering bug by storing it in a persistent RAM variable `labelLfn` rather than zero-page `NamePtrLo`.

## [0.2.22] - 2026-05-14

### Fixed

- **Environment Management**: Resolved critical hang in `SET` command by zero-initializing the 4KB environment segment in the REU. This prevents infinite loops caused by searching for double-null terminators in uninitialized memory.
- **PATH Command**: Refactored `cmdPath` to correctly initialize the search variable name and update `ParsePos`, fixing bugs where it would skip characters and fail to set the search path correctly.

## [0.2.21] - 2026-05-13

### Fixed (DEBUG Build 1012)

- **`parseHexArg` uppercase A-F double-subtract**: `phUpperHex` fell through into `phDigit` instead of jumping to `phAdd`. After converting an uppercase letter with `sbc #('A'-10)`, the code then also applied `sbc #'0'` ($30), producing garbage (e.g. 'A'=$41 → 10 → 10−$30=$DA). Fixed by adding `jmp phAdd` after the uppercase conversion.
- **`parseHexArg` overflow check placement**: Moved `cpx #4; beq phInvalid` to the top of `phAdd` (before the 4× ASL/ROL shift) so the 5th digit is rejected without corrupting HexVal. Previously the digit was shifted in before the check, producing a truncated but dirty HexVal on the error path; the error (carry set) was still returned correctly to callers, but the pre-check position is cleaner.

**H command behaviour (reported bug):** `H 10444 51` now returns an error instead of silently truncating `10444` to `$0444` and computing `0495 03F3`. The `cpx #4` check was introduced in Build 1011 and did correctly set carry; the `0495 03F3` result was from a pre-1011 build where no digit limit existed.

## [0.2.20] - 2026-05-13

### Fixed (command64 Build 2414 / DEBUG Build 1011)

**command64 OS:**

- **C1 — COPY wrong handle closed on error**: `ccCloseSrcErr` loaded `TempLo` (scan index) instead of `SrcHandle` when closing the source file on error. Fixed: `lda TempLo` → `lda SrcHandle`.
- **C2 — DOS_EXIT stack accumulation**: Each `DOS_EXIT` call orphaned 4 bytes on the stack (2 bytes for `jsr UserProgStart` + 2 bytes for the program's `jsr $1000`), overflowing after ~63 runs. Fixed by resetting SP to `#$FF` before `jmp mainLoop` in `ahExit`.
- **C4 — file.asm defensive CLRCHN**: Added `jsr KernalCLRCHN` to `frError` and `fwError` paths as a defensive measure (both labels are only reachable before CHKIN/CHKOUT, but are guarded for future refactor safety).
- **C5 — LFN conflicts**: `cmdDir` and `checkExistence` both used hardcoded LFN 2, colliding with handle-table LFNs. Fixed: `cmdDir` now uses LFN 13, `checkExistence` uses LFN 14.
- **C6 — VMM zero-size alloc**: `vmmAlloc` did not reject a zero-size request (`VmmSegLo/Hi == 0`), causing a spurious PAGE_HEAD allocation. Added guard at top of `vaInitOk` that returns `VMM_ERR_INVALID` on zero input.
- **M1 — path.asm bounds overrun**: `ffAppendPrg` wrote `.PRG` suffix without a length check. Added `cpy #77` guard; `TempLo >= 77` branches to `ffNotFound` before overflow.
- **M2 — fileScratch undersized**: `fileScratch` was 64 bytes, too small for a 79-char filename plus write (`,S,W`) and rename (`R:new=old`) suffixes. Expanded to 96 bytes.

**DEBUG Utility:**

- **D1 — command dispatch case sensitivity**: `dispatch` used `and #$7F` which converted uppercase $41-$5A to shifted $01-$1A, not matching any lowercase command byte. Fixed: `and #$7F` → `ora #$20` to convert unshifted letters ($41-$5A) to lowercase ($61-$7A).
- **D2 — hex parsing uppercase A-F**: `parseHexArg` rejected unshifted A-F keys ($41-$46, sent by SHIFT+letter in lowercase PETSCII mode). Added explicit two-branch check: handles unshifted $41-$46 (`phUpperHex`) and lowercase $61-$66 (`phLowerHex`). Added 4-digit overflow guard (`cpx #4 → beq phInvalid`).
- **D3 — verMsg/startupMsg duplication**: Merged duplicate string definitions into a single block with dual labels (`startupMsg:` / `verMsg:`), saving 4 bytes.

### Changed

- **Shell help text**: Added `RENAME` and `ERASE` aliases to `helpMsg` display. Removed dead `dirStubMsg` data block.
- **loader.asm**: Removed spurious `PetLl` ($0A) linefeed after the "loading..." message.
- **utils.asm**: Corrected `normalizeName` header comment — output documents Y=string length and X=preserved.

## [0.2.19] - 2026-05-12

### Added

- **DEBUG Utility Unassemble (U)**: Implemented a full 6502 disassembler. Supports decoding of all standard opcodes and addressing modes with automatic target address calculation for relative branches. Includes support for default counts, specific start addresses, and inclusive memory ranges.
- **DEBUG Utility Help**: Added `?` command to display a summary of all internal `DEBUG` commands. Established a maintenance protocol in the source code to ensure documentation stays synchronized with new features.

### Fixed

- **Shell UI**: Fixed a bug in `shellReadLine` where the cursor would not advance to a new line after pressing RETURN. Explicitly added `PetCr` echo to the completion handler.

## [0.2.18] - 2026-05-12

### Added

- **DEBUG Parameter Alignment**:
  - Implemented `L` (Length) syntax for all range-based commands (e.g. `D 1000 L 40`).
  - Added support for quoted strings (`"..."` or `'...'`) in `E`, `F`, and `S` commands.
  - Enhanced `F` (Fill) and `S` (Search) to support multi-byte lists and repeating patterns.
  - Implemented `parseList` and `parseRange` refinements for MS-DOS parity.

### Fixed (DEBUG.PRG v0.1.3 Build 1005)

- **`parseHexArg` regression**: The Build 1004 `and #$7F` fix accepted shifted hex letters ($C1-$C6) but rejected unshifted ones ($41-$46). In `petscii_mixed`, the 'a'-'f' keys without Shift send $41-$46, which the new gate (`cmp #$C1; bcc phInvalid`) incorrectly rejected. Typing `f800` without Shift produced "error". Fixed with a two-branch check: unshifted $41-$46 handled first, shifted $C1-$C6 handled second (converted via `and #$7F` before the same subtraction).

## [0.2.17] - 2026-05-12

### Fixed

- **DEBUG.PRG Remediation** (Build 1004):
  - Fixed hex parsing case sensitivity (`H`, `F`, `M` commands now work with both shifted and unshifted letters).
  - Refactored `Dump` (D) command to use 8-byte rows for 40-column displays.
  - Fixed `Enter` (E) command; added `Y` register preservation to prevent buffer index corruption during multi-byte entry.
  - Fixed `readLine` UI; added explicit carriage return echo after RETURN is pressed.

## [0.2.16] - 2026-05-12

### Fixed (DEBUG.PRG v0.1.2 Build 1003)

- **`readLine` Y corruption**: `KernalGetIn` may clobber Y, which was the buffer index with no push-pop guard. Applied `tya/pha … pla/tay` pattern matching `shellReadLine`.
- **Range commands — inclusive end + wrap safety**: `cmdFill`, `cmdMove`, `cmdCompare`, `cmdSearch` checked `rangeStart == rangeEnd` before operating, silently skipping the final byte and risking a full-64KB wrap-around loop on reversed ranges. Restructured all four as do-while (operate first, exit-check after).
- **`cmdMove` overlap corruption**: Forward copy overwrote source data when dest overlapped source from above. Added 16-bit dest-vs-src comparison; copies backwards (tail-first via `rangeEnd`/`val2` decrement) when `dest > src`, preventing corruption in all overlap cases.
- **`TempLo` implicit dependency**: `cmdDump` used the shell's scratch ZP register `TempLo` ($64) as its row counter. Added `DebugTemp = $7A` to debug.asm's own ZP block and replaced both uses.

## [0.2.15] - 2026-05-12

### Fixed

- **DEBUG Utility**: Fixed critical pointer logic. Relocated pointers (`currentAddr`, `rangeStart`, etc.) to Zero Page ($70-$7F) to support indirect-indexed addressing. Hardened `parseHexArg` to correctly handle empty arguments.

## [0.2.14] - 2026-05-12

### Added

- **External Utilities**: Implemented `DEBUG.PRG` (v0.1.0 Build 1001). Supports `D`, `E`, `F`, `M`, `C`, `S`, `H`, `R`, `G`, `V`, and `Q` commands.

### Fixed

- **Shell Input**: `shellReadLine` now correctly handles the INST/DEL key (`$14`). Previously DEL was echoed (visually correct) but also stored as a literal `$14` byte in `CommandBuffer`, causing "Bad command" errors for any input that used backspace. DEL now decrements the buffer index (logically erasing the previous character) without storing anything; DEL at an empty buffer is silently ignored. Added `PetDel = $14` constant to `command64.inc`.

## [0.2.13] - 2026-05-12

### Fixed

- **Directory Reporting**: Resolved discrepancy where `DIR` reported 144 blocks free instead of 656.
- **Decimal Printer Bug**: Fixed 16-bit math error in `printDecimal16` that ignored the high byte for values between 100 and 999.
- **DIR Command Hardening**: Added stack-based register preservation in `cmdDir` to prevent block counts from being clobbered by the KERNAL `GETIN` routine.

## [0.2.12] - 2026-05-12

### Added

- **Internal Commands**: Added `REN` and `RENAME` commands.
- **Service Bus API**: Added `DOS_RENAME_FILE` ($56) supporting two filename pointers (`X/Y` and `PrintPtr`).

### Changed

- **Memory Optimization**: Moved `Utils` segment to `$0C00` to free up space in the `$1000-$1FFF` range.
- **Memory Map**: Realigned all core segments and shifted `VmmData` to `$1F90` to resolve persistent overlaps as the OS grows.

## [0.2.11] - 2026-05-12

### Added

- **Internal Commands**: Added `DEL` and `ERASE` commands for file deletion.
- **Service Bus API**: Added `DOS_DELETE_FILE` ($41) for external program file management.

### Changed

- **Memory Map**: Realigned `VmmData` and `FileScratch` to `$1FA0` to accommodate growing file module.

## [0.2.10] - 2026-05-12

### Fixed

- **Critical — KERNAL API Register Mismatches**: Resolved multiple bugs in `file.asm` where LFN and Device Number registers were swapped or incorrect for `SETLFS`, `CHKIN`, and `CHKOUT` calls.
- **Filename Normalization**: Enhanced `normalizeName` to handle lowercase PETSCII conversion, ensuring shell input matches standard uppercase disk filenames.
- **Memory Map**: Realigned segments (`Loader`, `Path`, `Vmm`, `File`, `VmmData`) to resolve overlaps caused by expanded utility code.

## [0.2.9] - 2026-05-12

### Fixed

- **Handle/Channel Conflict**: `fileOpen` now uses the Logical File Number (LFN) as the Secondary Address, ensuring unique channels for simultaneous files (fixing `COPY`).
- **Case Sensitivity**: Added `normalizeName` call to `fileOpen` to ensure filenames match the unshifted PETSCII expected by the disk drive (fixing `TYPE` and `COPY` "Load error").

## [0.2.8] - 2026-05-12

### Fixed

- **Critical — cmdCopy Handle Corruption**: `cmdCopy` was using `TempLo/Hi` for handles, which were clobbered by `fileRead/Write`. Added dedicated ZP registers `SrcHandle` ($6E) and `DstHandle` ($6F).
- **Documentation**: Corrected outdated Zero Page addresses in `utils.asm` comments ($F7/$F8 -> $66/$67).

### Changed

- **Performance — Buffered I/O**: `TYPE` and `COPY` commands now use 64-byte buffered I/O instead of 1-byte-at-a-time, significantly improving disk performance.

## [0.2.7] - 2026-05-12

### Fixed

- **C1 — FileScratch address** (`include/command64.inc`): `FileScratch` was `$1D80` (= File segment start), causing `fileOpen` to overwrite its own code when building filenames. Corrected to `$1F02` where `fileScratch` actually lives in VmmData.
- **C2 — Handle lost in API dispatch** (`api.asm`, `shell.asm`): `ahRead`/`ahWrite`/`ahClose` were entered with A = function code, not the handle; `fileRead`/`fileWrite`/`fileClose` received garbage. Added ZP register `FileHandle = $6D` (vmm.inc). `ahRead`/`ahWrite`/`ahClose` now load A from FileHandle before delegating. Callers in `cmdType`/`cmdCopy` now `sta FileHandle` after open and before each read/write/close API call. TYPE and COPY are now functional.
- **C3 — fileClose X clobber** (`file.asm`): `KernalCLOSE` does not preserve X; `sta HandleTable, x` after the call wrote to the wrong slot. Fixed by saving X to TempLo around the KERNAL call.
- **N8 — Spurious `asl` in fileClose** (`file.asm`): Dead code after `jsr KernalCLOSE` removed.
- **Dead `lda` lines in cmdType/cmdCopy** (`shell.asm`): Removed no-op handle loads that were immediately overwritten.

### Changed

- **Version**: 0.2.7 (Build 2400), Phase 2F (File I/O).
- **HELP text**: Added TYPE and COPY to the HELP command output.
- **ABI comments** (`api.asm`): Updated ahRead/ahWrite/ahClose comments to reflect FileHandle ZP convention.
- **Removed `KernalCBINV`** (`include/command64.inc`): Vestigial BRK vector label from pre-v0.2.6 removed.

## [0.2.6] - 2026-05-11

### Changed

- **Service Bus Architecture Pivot**: Transitioned from a `BRK`-based trap model to a **Jump Table** model (`JSR $1600`). This resolves infinite recursion crashes and stack corruption caused by conflicts between custom `BRK` handlers and the non-reentrant C64 KERNAL interrupt routines.
- **ABI Update**: The Service Bus now follows standard subroutine conventions:
  - Entry point: `$1600`
  - Calling convention: `JSR $1600`
  - Input: `A`=Function, `X/Y`=Args
  - Output: `A, X, Y` as per function, `Carry`=Status (0=Success, 1=Error)

### Fixed

- **Stability**: Removed all hardcoded `BRK` vector hooks (`$0316`), making the system 100% stable under emulator and real-hardware conditions.
- **Infinite Recursion**: Fixed the "stack drain" issue where nested interrupts caused the stack pointer to wrap around.

## [0.2.5] - 2026-05-11

## [0.2.4] - 2026-05-11

### Added

- **Phase 2D (Service Bus)**: Implemented INT 21h-style BRK service bus (`api.asm`, segment `$1600`). Handles DOS_PRINT_CHAR ($02), DOS_PRINT_STR ($09), DOS_ALLOC_MEM ($48), DOS_FREE_MEM ($49), DOS_EXIT ($4C).
- **BRK Vector Install**: Shell startup installs `apiHandler` to `KernalCBINV` ($0316/$0317) at boot.
- **VMM Safety Guard**: Added `vmmInitialized` flag; `vmmAlloc` returns `VMM_ERR_INVALID` if REU detection failed, preventing MCT corruption.
- **Test Scaffolding**: Added `tests/src/apitest.asm` and `tests/src/vmmtest.asm` integration test stubs.

### Fixed

- **printDecimal16**: Initialized `TempHi` to 0 at entry to prevent garbage leading zeros from prior callers.

### Changed

- **Segment Layout Cascade**: Inserted `Api` at $1600; relocated `Utils`→$1700, `Loader`→$1800, `Path`→$1880, `Vmm`→$1980, `VmmData`→$1C80.
- **Version**: 0.2.4 (Build 2303), Stage 4.

## [0.2.3] - 2026-05-09

### Added

- **Phase 2C (VMM) Core**: Implemented Virtual Memory Manager primitives (`vmmInit`, `vmmReadByte`, `vmmWriteByte`) mapping 1MB-16MB REU space.
- **Dynamic Allocation**: Implemented `vmmAlloc` and `vmmFree` using a 4KB Page Byte-Map strategy ($01 Head, $02 Tail).
- **Version Tracking**: Added startup version banner and internal `VER` command.
- **HELP Command**: Added internal `HELP` command with brief descriptions.
- **DIR Command**: Implemented non-destructive directory listing via KERNAL streaming.
- **LOAD Command Fix**: Resolved a critical register corruption bug and inverted secondary address mapping.
- **Dispatcher Hardening**: Added length-0 safety checks to external command searches.
- **Stability**: Relocated Command Buffer to Cassette Buffer ($033C) and isolated Memory Control Table (MCT) to $C000.
- **Zero Page Remapping**: Migrated all pointers to safe/FAC1 workspace ($FB-$FE, $61-$6C) to prevent BASIC/KERNAL corruption.

### Changed

- Reverted `UserProgStart` to $2000 for compatibility with existing pre-compiled programs.
- Refined versioning scheme to 0.x.x (Pre-Alpha) to better track project sub-stages.

## [0.1.4] - 2026-05-08
