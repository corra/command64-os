# Project Tasks

- [x] Taskwarrior UUID `13a45324`: CASM Phase 1 native application scaffold
  - [x] `ef6a001e` Create synchronized task records and CASM-local DOX contract
  - [x] `7b318ab7` Declare approved zero-page, base-RAM, and module ABI
  - [x] `05e59de2` Implement central resource ownership and exit paths
  - [x] `8891fe27` Implement minimal diagnostics
  - [x] `eb83b449` Implement entry point and version banner
  - [x] `c6c3b55e` Integrate ca65 target and release disk
  - [x] `5a0e36c5` Verify configure, target, R6 artifact, and disk image
  - [x] `161ed5a9` Record walkthrough and obtain user runtime confirmation
  - [x] Confirm the Phase 0 contracts required by the Phase 1 plan before
        source implementation

- [x] Taskwarrior #29 (`df2f766c`): CASM Phase 2 CLI and native file-service
      foundation
  - [x] `ba51bd58` Synchronize task records and record approved Phase 0B
        contracts
  - [x] `79d7f6aa` Declare shared CLI, file, and stream ABI
  - [x] `5d997dfd` Implement bounded command-line parser
  - [x] `8e0711ad` Implement managed native file wrappers
  - [x] `b7d0e543` Implement real central file-handle cleanup
  - [x] `3bc11e77` Extend CLI and file-service diagnostics
  - [x] `1d2c1761` Integrate Phase 2 entry-point orchestration
  - [x] `0870f804` Correct EOF carry propagation and preserve the registered
        resource slot across `DOS_CLOSE_FILE`; build 1011 runtime verified
  - [x] `9e4d8175` Verify artifacts and obtain user runtime confirmation

- [x] Taskwarrior #29 (`099257cc`): CASM Phase 3 source stream and minimal
      lexer
      (corrected from `[/]` during WP15 increment 2: Taskwarrior has recorded
      this Completed since 2026-07-17 and all eleven subtasks were ticked, so
      the in-progress marker was stale. This is a record-truth correction to a
      long-approved phase, not a Phase 4 acceptance tick.)
  - [x] `65832339` Synchronize task records, dependency corrections, and
        approved Phase 0C.1 contracts
  - [x] `9ab8caf3` Investigate DEBUG assembler reuse feasibility
  - [x] `9e0c03f3` Declare shared source/lexer ABI and bounded state
  - [x] `fcb0e164` Implement the rewindable source backend; user runtime matrix
        confirmed and completion approved 2026-07-16; build 1020 advanced CASM
        to `0.1.6`
  - [x] `9c733c1a` Implement newline normalization and provenance; user runtime
        matrix confirmed and completion approved 2026-07-16; build 1022 advanced
        CASM to `0.1.7`
  - [x] `cda20f5b` Implement deterministic rewind and bounded line API (Option A
        partitioned buffer, envelope raised to `$2000`); user runtime matrix
        confirmed and completion approved 2026-07-17; build 1025 advanced CASM to
        `0.1.8`
  - [x] `7196a56f` Implement the minimal lexer core (Option 1 static-only);
        `lexer.s` with lookahead, token primitives, whitespace/comment skipping,
        and punctuation tokens; user non-regression confirmed and completion
        approved 2026-07-17; build 1028, CASM at `0.1.9`
  - [x] `9e1a1a12` Implement textual and numeric token scanning
  - [x] `3367d36d` Implement mnemonic classification
  - [x] `a68d3603` Integrate diagnostics and temporary token dump
  - [x] `178b0884` Verify artifacts and obtain user runtime confirmation

- [x] Taskwarrior (`4796b60c-5f4a-43c7-8270-436075bb3f7b`): CASM Phase 4
      statement parser, opcode table, and numeric static assembly
      **COMPLETE — user approved 2026-07-21 at CASM `0.1.17` build 1079.**
  - Parent milestone created 2026-07-21 during WP15 increment 2. Phases 1-3 each
    had a parent record; Phase 4 had none, so WP11-WP15 were orphaned. The
    completed Phase 3 UUID `099257cc` was deliberately not reused.
  - [x] `82a11475` WP11: implement statement parser and syntax validation;
        build 1042, CASM `0.1.13`
  - [x] `a3f90f05` WP12: implement opcode table and addressing mode matcher;
        build 1047, CASM `0.1.14`
  - [x] `ded1cfd9` WP13: implement numeric directives and byte/word emission
  - [x] `3e4eab43` WP14: orchestration and end-to-end binary validation;
        build 1078, CASM `0.1.16`
  - [x] `8612c2a2` WP15: verification and phase closeout; build 1079,
        CASM `0.1.17`
  - Phase 4 approved done by the user on 2026-07-21. Phase 5 is now unblocked.
  - Carried forward to Phase 11: `CasmOutputCreated` conflates "created" with
    "opened an existing file"; no `CLD` at entry; no CASM Phase 4 contract
    section in `brain/KNOWLEDGE.md`.

- [x] Taskwarrior (`3e4eab43-0f48-4db5-843f-c749bcb79d8a`): CASM Phase 4 WP14: execute orchestration and end-to-end binary validation
  - [x] Create detailed implementation plan
  - [x] Obtain phased implementation approval
  - [x] Increment 1: reconcile DSC1 documentation and capture baselines
  - [x] Increment 2: strict hex-manifest conversion tooling and `casmemit1.ref`
  - [x] Increment 3: `casmhello.ref` integrated and verified
  - [x] Increment 4: compiler loop driver audit and module decision
  - [x] Increment 5: production orchestration documented
  - [x] Increment 6: syntax, addressing, range, PC, and cleanup fixtures added
  - [x] Fix `.ORG` operand defect and verify regression safety
  - [x] Increment 7: host-side verification and manual walkthrough setup
  - [x] Add `casmmodes.ref` per-addressing-mode byte certification
  - [x] Fix unreachable `CASM_MODE_ZEROPAGE_Y` and add build-breaking guard
  - [x] Increment 8: user runtime matrix verification — all groups pass
  - [x] Increment 9: advance to `0.1.16` build 1078 and synchronize records
  - Completed 2026-07-21. Two defects found and fixed; WP14 does not complete
    Phase 4 — it unblocks WP15.
  - Outstanding for the record only: observed values for G4.2 (`casmzpi2`
    diagnostic) and G7.1–G7.3 (assembling over an existing output file).

- [x] Taskwarrior (`8612c2a2-afdd-4c8f-bf42-4947bc486f97`): CASM Phase 4 WP15: verify artifacts and obtain user runtime confirmation
  - Plan: `brain/plans/2026-07-20-casm-phase4-wp15-phase-verification-closeout.md`
  - Activated 2026-07-21 on `feature/casm-phase4-wp15` from clean tree `55fe474`.
  - [x] Increment 1: confirm WP14 complete and its records agree
  - [x] Increment 2: reconcile records (Phase 4 parent milestone `4796b60c`
        created; phantom wiki UUIDs `31bb2198`/`501bc58c`/`83ab4f2d` replaced
        with the real `82a11475`/`a3f90f05`/`ded1cfd9`; stale Phase 3 milestone
        text replaced in `wiki/tasks/casm.md` and here)
  - [x] Increment 3: clean baseline captured at `d75adca`
  - [x] Increment 4: both link configs fit `$2800` with 408 bytes headroom;
        R6 artifact cross-checked (11057 B, base `$3400`, 1172 relocations)
  - [x] Increment 5: both disks verified; 3 trusted refs match end to end by
        independent transcription; non-circular provenance confirmed
  - [x] Increment 6: static audit — 52/52 carry sites clean, no `SED`, stack
        balanced, output lifecycle and diagnostic preservation sound
  - [x] Increment 7: advanced to `0.1.17`, `BUILD_CASM` 1078 -> 1079 exactly
        once and stable on no-change rebuild; banner `CASM V0.1.17.1079`
  - [x] Increment 8: walkthrough written with pending manual steps
  - [x] Increment 9: user executed the smoke set, shell-integrity checks, and
        both WP14 gap captures — all pass. G4.2 confirmed
        `OPERAND OUT OF RANGE`; G7 falsified the predicted deletion hazard
        (no clobber; `fileDelete`'s `checkDeviceReady` preflight bails on the
        latched `63,FILE EXISTS`, so the delete never runs)
  - [x] Increment 10: user approved Phase 4 done on 2026-07-21
  - Walkthrough: `brain/walkthroughs/2026-07-20-casm-phase4-wp15-phase-verification-closeout.md`

- [/] Taskwarrior #24 (`a45d0395`): Implement external `COMP` utility
  - [x] Create active Taskwarrior task
  - [x] Write detailed implementation plan for approval
  - [x] Review external app, `MORE`, and `DEBUG` reuse candidates
  - [x] Implement after explicit approval
  - [x] Build `image_d64` and `test_image_d64`
  - [ ] Manually verify

- [ ] Taskwarrior #25 (`57d2cf4e`): Future external app return-code support
  - [x] Confirm current `DOS_EXIT` has no meaningful app return-code channel
  - [ ] Design ERRORLEVEL-style status support outside `COMP` scope

- [x] Task #25: Fix EDLIN physical hardware save truncation
  - [x] Preserve final EOI byte in `DOS_READ_FILE`
  - [x] Check KERNAL write status after `CHROUT`
  - [x] Read EDLIN target drive post-close status after `W`
  - [x] Verify with `make all`
  - [x] Manual physical-hardware verification

- [x] Workspace initialization & state management setup
- [x] Project infrastructure setup: Taskwarrior & Codebase Memory initialized, Code Wiki created (2026-06-25)

- [x] Phase 2A: Core Dispatcher Proof-of-Concept (`CLS`, `ECHO`, `EXIT`, Command Loop)
  - [x] Kick Assembler toolchain setup and verification
  - [x] PETSCII API layer (`src/command64/petsci.asm`)
  - [x] Command loop, dispatcher, built-in handlers (`src/command64/shell.asm`)
  - [x] Build entry point and segment layout (`build/command64.asm`)
  - [x] Constants and KERNAL equates (`include/command64.inc`)
  - [x] `build/command64.prg` assembles — 0 errors, 0 warnings

- [x] Phase 2A Code Review & Remediation (2026-05-02)
  - [x] Static review: 14 findings (11 Critical, 3 Major) — `brain/reviews/2026-05-02_phase2a-command64.md`
  - [x] All findings remediated — `brain/plans/2026-05-02_phase2a-command64-code-review-remediation.md`
  - [x] Real-hardware test: `CLS` works, `ECHO` crashes fixed, `EXIT` hang fixed
  - [x] CommandBuffer relocated from $0300 (KERNAL vectors!) to $1400
  - [x] cmdCompare X-register dispatch bug fixed (all 3 commands verified)
  - [x] EXIT: `jmp ($0338)` → `jmp $E37B` (BASIC warm start ROM)

- [x] Phase 2A Follow-on
  - [x] Raw GETIN input loop — fixes `"` quote-mode control code injection
  - [x] Fix Y-register clobbering in PETSCII/Shell routines
  - [x] Fix PETSCII string encoding bug (block graphics in badCmdMsg)
  - [x] Improve parser robustness (ignore empty lines, trim spaces)
  - [x] VMM API specification (`include/vmm.inc`)

- [x] Phase 2B: External command support / PATH search
  - [x] Define loader memory map ($2000+)
  - [x] Implement directory search (`path.asm`) with auto-.prg extension
  - [x] Implement binary loader (`loader.asm`) with custom address support
  - [x] Integrate with `shellDispatch` (auto-run if no internal match)
  - [x] Case-insensitive matching (`normalizeName`)
  - [x] Create test environment (`tests/testcmds.d64`)

- [x] Phase 2B Verification
  - [x] Verify `HELLO` from shell (string output)
  - [x] Verify `COLOR` from shell (visual check)
  - [x] Verify `EXTCLS` from shell (functionality check)
  - [x] Verify case-insensitivity (e.g., `hello` vs `HELLO`)
  - [x] Verify custom load address (e.g., `load hello 3000`)

- [x] Phase 2C: Virtual Memory Manager (VMM)
  - [x] Define VMM ABI and REU hardware registers
  - [x] Relocate MCT to safe RAM ($C000) for 16MB support
  - [x] Remap ZP pointers to safe/FAC1 workspace to prevent BASIC corruption
  - [x] Implement `vmmInit` (MCT clearing and REU detection)
  - [x] Implement `vmmAlloc` / `vmmFree` with 4KB Page Byte-Map strategy
  - [x] Implement `vmmReadByte` / `vmmWriteByte` (REU DMA primitives)
  - [x] Stabilize shell: move `CommandBuffer` to Cassette Buffer ($033C)
  - [x] Add version tracking (0.2.3 Build 2301) and startup banner
  - [x] Implement `HELP` internal command
  - [x] Implement `DIR` internal command (non-destructive)

- [x] Phase 2C Code Review Round 1 — Service Bus & VMM Backtracking (2026-05-11)
  - [x] Review conducted (5-agent parallel review) — `brain/reviews/2026-05-11_command64-phase2c-api-vmm.md`
  - [x] Remediation plan written — `brain/plans/2026-05-11-api-vmm-bug-remediation.md`
  - [x] A — Fixed `ahSetCarry`/`ahClearCarry`: `$0104,x` → `$0106,x` + updated comment
  - [x] B — Fixed `vaSearchReset`/`vaCommitAlloc`: reconstruct MCT ptr as `#>VmmMctBase + VmmOffHi`
  - [x] E — Fixed `ahFreeMem` branch: added `lda $0103,x` after `sta` to set Z from status
  - [x] F — Fixed `build_tests.sh` shebang, paths, and OUTDIR (covered in Round 3 + OUTDIR absolute path)
  - [x] J — Fixed `vmmtest.asm`: save X/Y to $64/$65 after alloc, restore before free

- [x] Phase 2C Code Review Round 2 — Residual Bugs (2026-05-11)
  - [x] Bug verification conducted — `brain/reviews/2026-05-11_command64-bug-verification.md`
  - [x] Remediation plan written — `brain/plans/2026-05-11_command64-remediation-round2.md`
  - [x] Implement C4: Correct `SpecificLoad` comments
  - [x] Implement C8: Clear `TempHi` in `printDecimal16`
  - [x] Implement I2: Add VMM initialization safety check

- [x] Phase 2C Code Review Round 3 — Safety Hardening (2026-05-11)
  - [x] Review conducted — `brain/reviews/2026-05-11_command64-round3-gemini-review.md`
  - [x] Remediation plan written — `brain/plans/2026-05-11_command64-remediation-round3.md`
  - [x] Task 1: Secure `vmmFree`
  - [x] Task 2: Secure `vmmReadByte`

- [x] Phase 3: File System Integration (Handle-based I/O)
  - [x] Architecture design and planning — `brain/plans/phase3-filesystem.md`
  - [x] Define FCB structure and Handle Table layout
  - [x] Extend DOS API with file primitives ($3D, $3E, $3F, $40)
  - [x] Implement `TYPE` internal command
  - [x] Implement `COPY` internal command
  - [x] Create file integration test program — `tests/src/filetest.asm`

- [x] Phase 3 Remediation & Shell Polish (2026-05-12)
  - [x] Resolve Load Error / Register Mismatches — `brain/plans/filesystem-remediation.md`
  - [x] Fix DIR block reporting (16-bit) — `brain/walkthroughs/dir-report-fix.md`
  - [x] Implement `DEL` / `ERASE` commands — `brain/plans/filesystem-extended-cmds.md`
  - [x] Implement `REN` / `RENAME` commands
  - [x] Add destructive backspace (INST/DEL) handling in shell input loop

- [x] Phase 4: External System Utilities
  - [x] Develop `DEBUG` utility (Dump, Enter, Fill, Move, Compare, Search, Hex Math, Regs, Go, Quit)
  - [x] Refine `DEBUG` UI for 40-column display (8-byte rows, midpoint separator)
  - [x] Remediate `DEBUG` bugs (case sensitivity, register safety, inclusive ranges) — `brain/plans/debug-utility.md`
  - [x] Verify `DEBUG` via formal test plan — `brain/walkthroughs/debug-test-plan.md`
  - [x] Implement `RUN` / `G` internal commands for program execution at [address]
  - [x] Remediate `DEBUG` range and dump bugs (uppercase L parsing, dump range support) — `brain/plans/debug-range-remediation.md`
  - [x] Refactor range checks to eliminate redundancy in `debug.asm` — `brain/plans/debug-refactor-ranges.md`
  - [x] Fix hex letter parsing in `parseHexArg` (`debug.asm`) — `brain/plans/debug-hex-parsing-fix.md`
  - [x] Fix Y-register clobbering in `prLength` (`debug.asm`) — `brain/plans/debug-prlength-y-preservation.md`
  - [x] Add build tracking to `LABEL` external utility — `brain/plans/label-build-tracking.md`
  - [x] Remediate Phase 1 Peer Review findings (interactive registers, load tracking, global range check) and complete Phase 1 I/O (N/L/W) type prefixes and SEQ/USR custom loaders — `brain/reviews/2026-06-28_debug-phase1-peer-review.md`
  - [x] Implement Phase 3 software breakpoint debugger (T/P commands, instruction decoder, CBINV intercept, and stack launch) — `brain/walkthroughs/2026-06-30-debug-phase3-breakpoint-debugger.md`

- [ ] Phase 5: Environment & Multi-Device Support
  - [x] Implement `DRIVE` command (with `DEVICE`/`DEV` aliases)
  - [x] Add support for multiple devices (8, 9, 10, 11)
  - [x] CLI: Generalize device targeting syntax for commands like DIR, TYPE, VOL, LABEL (Task #24)
  - [x] Refactor device routing into filesystem and API layer
  - [ ] Support subdirectories (1581 / SD2IEC)
  - [x] Environment variable storage (`SET`, `PATH`) in REU
  - [x] Remediate environment hang and PATH bugs (2026-05-14) — `brain/plans/2026-05-14-env-var-remediation.md`

- [ ] Phase 6: Advanced OS Features
  - [x] Phase 6A: App Manager Phase A (Program registry APPS/PS/FREE) (Completed 2026-07-04)
  - [x] Implement Binary Relocator (to support `RUN` at arbitrary addresses) (Completed 2026-07-05)
  - [x] Conway & conwayca memory Safety & Relocation Crash Remediation (Completed 2026-07-08)
  - [/] Taskwarrior #26 (`f4eba87e`): Conway Multiverse Generalization, Menu and Counter
    - [x] Gather transcript research and document Conway Multiverse rules
    - [x] Update high-level plan for production ca65/ld65 tools
    - [x] Write detailed implementation plan
    - [x] Obtain phased implementation approval
    - [x] Phase 1: extend contracts and verify build/memory headroom
    - [x] Implement Main Menu screen with preset selections
    - [x] Implement Custom Rule editing mode (one Birth/Survival toggle per
      edit command)
    - [x] Phase 3: 16-bit generation counter implemented and manually verified
    - [x] Phase 2: compact presets and RAM-table solver implemented and
      manually verified
    - [x] Phase 4: compact menu renderer implemented and approved
    - [x] Phase 5: menu/simulation state machine, cyan/green pause indicator,
      and stack-safe exits implemented and functionally confirmed by the user
    - [/] Phase 6: update documentation, project records, and walkthrough
    - [x] Increment Conway to `0.4.1.1057` and synchronize current-version
      documentation
    - [x] Display the full `0.4.1.1058` patch/build version at the bottom-right
      of the main menu without overlapping dynamic prompts; visually confirmed
      by the user
    - [ ] Phase 7.1: replace one-digit B/S editing with persistent full-set
      entry, clearing the selected set and finishing on RETURN
    - [ ] Phase 7.2: update documentation, verification evidence, walkthrough,
      and task records for the full-set editor
    - [ ] Build and inspect size/alignment/relocation artifacts
    - [ ] Complete user-run C64/VICE verification
  - [ ] Add Oscar64 C-Language runtime support
  - [ ] Phase 6D: Cooperative VMM Swapping & Memory Safety


- [ ] Time, Date & Disk Label Support
  - [x] VOL / LABEL Command Implementation (Task #17)
    - [x] Implement `cmdVol` routine in `shell.asm` to read and print the disk header name/ID
    - [x] Implement `cmdLabel` routine in `shell.asm` to write a new name to the disk header using the floppy disk command channel
    - [x] Register `VOL` and `LABEL` in the command table and the `HELP` output
    - [x] Verify functionality on standard D64 disk images
    - [x] LABEL: Fix interaction inconsistencies (Task #21)
    - [x] LABEL: Implement syntax updates for quotes and spaces (Task #22)
    - [x] LABEL: Support target device parameter like 9:NEWLABEL (Task #23)
  - [x] TIME Command Implementation (Taskwarrior #15)
    - [x] Implement TOD clock initialization routine at system boot
    - [x] Implement `cmdTime` handler in `shell.asm` to format and print time
    - [x] Implement CIA 1 TOD register write routines to allow user clock adjustments
    - [x] Register `TIME` in the command table and the `HELP` output
    - [x] Verify direct and interactive setting/display round-trips
    - [x] Verify midnight rollover advances the software date
  - [x] DATE Command Implementation (Taskwarrior #16)
    - [x] Define system date storage structures in resident kernel RAM
    - [x] Implement `cmdDate` handler in `shell.asm` to print and parse date inputs
    - [x] Register `DATE` in the command table and the `HELP` output
    - [x] Verify direct and interactive setting/display round-trips
    - [x] Verify leap-year validation
    - [x] Verify midnight and month rollover

- [x] MORE Command Implementation (Taskwarrior #24)
  - [x] Add `MORE` to the internal command table and help text
  - [x] Stream file contents through existing DOS open/read/close API calls
  - [x] Add C64 screen pagination with `-- More --` prompt
  - [x] Document `MORE` and target-device prefix support
  - [x] Verify clean build with `make all`
  - [x] Complete manual C64/VICE workflow verification

- [ ] Pac-Man ca65 Rewrite
  - [x] Phase 1: Core Setup & Build Pipeline
    - [x] Create `BUILD_PACMAN` file
    - [x] Create `src/external/pacman/common.inc` with zero-page definitions and constants
    - [x] Create skeleton `src/external/pacman/pacman_main.s`
    - [x] Delete old Kick Assembler `pacman.asm`
    - [x] Update `CMakeLists.txt` with ca65 build rules for `pacman`
    - [x] Compile skeleton successfully

  - [x] Phase 2: Maze Layout, Draw Engine, and Pac-Man Movement
    - [x] Define 28x24 maze Walls and Items arrays in `pacman_game.s`
    - [x] Implement fast screen/color block rendering in `pacman_game.s`
    - [x] Implement keyboard poll and direction buffering in `pacman_main.s`
    - [x] Implement Pac-Man move timers, level speed scaling, and dot/pellet eating slowdown

  - [x] Phase 3.1: Blinky AI Integration and Code Review Remediation
    - [x] Review Phase 2 regressions and the active Blinky integration
    - [x] Synchronize `wiki/tasks/pacman-ca65-rewrite.md` and Taskwarrior
    - [x] Correct actor redraw ordering and manually verify actor visibility
    - [x] Repair and harden `autotile.py`
    - [x] Integrate `autotile.py` into the Pac-Man CMake target
    - [x] Synchronize Pac-Man documentation with current behavior
    - [x] Implement and manually verify Pac-Man/Blinky collision and life-loss handling
    - [x] Classify Blinky corner loops and verify the invisible-target symptom
      is resolved by collision handling
    - [x] Complete build verification and user-run C64/VICE walkthrough
    - [ ] Deferred: restore the exact 240-dot maze after visual revisions
    - [ ] Deferred: implement ghost warp-tunnel behavior
