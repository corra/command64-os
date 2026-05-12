# Project Tasks

- [x] Workspace initialization & state management setup

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
- [/] Phase 3: File System Integration (Handle-based I/O)
  - [x] Architecture design and planning — `brain/plans/phase3-filesystem.md`
  - [ ] Define FCB structure and Handle Table layout
  - [ ] Extend DOS API with file primitives ($3D, $3E, $3F)
  - [ ] Implement `TYPE` internal command
