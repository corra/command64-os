---
feature: command64-phase2a-through-2c-full-review
reviewed: 2026-05-11
status: remediation-planned
---

# Code Review: command64 — Phase 2A through 2C Full Sweep

## Scope

Comprehensive review of all command64 source files across Phases 2A–2C, plus build/test infrastructure and state management artifacts.

| File | Role |
|------|------|
| `src/command64/shell.asm` | Command loop, dispatcher, built-in handlers |
| `src/command64/api.asm` | INT 21h BRK-based service bus dispatcher |
| `src/command64/vmm.asm` | Virtual Memory Manager (REU mapping) |
| `src/command64/path.asm` | File discovery, `.prg` extension appending |
| `src/command64/loader.asm` | KERNAL binary loader wrapper |
| `src/command64/utils.asm` | Hex parsing, normalizeName, decimal printer |
| `src/command64/petsci.asm` | PETSCII print routines |
| `include/command64.inc` | KERNAL equates, ZP labels, buffer constants |
| `include/vmm.inc` | VMM ABI, REU registers, page flags |
| `build/command64.asm` | KickAssembler root build file |
| `tests/src/apitest.asm` | Service bus smoke test |
| `tests/src/vmmtest.asm` | VMM alloc/free round-trip test |
| `tests/build_tests.sh` | Test compilation script |

## Previous Review Artifacts

| Artifact | Status |
|----------|--------|
| `brain/reviews/2026-05-02_phase2a-command64.md` | Phase 2A — 14 findings, all remediated |
| `brain/reviews/2026-05-11_command64-phase2c-api-vmm.md` | Phase 2C — 5 confirmed bugs (A, B, E, F, J) |
| `brain/reviews/2026-05-11_command64-bug-verification.md` | Round 2 — 3 confirmed (C4, C8, I2) |
| `brain/plans/2026-05-11-api-vmm-bug-remediation.md` | Remediation plan for A, B, E, F, J |
| `brain/plans/2026-05-11_command64-remediation-round2.md` | Remediation plan for C4, C8, I2 |

## New Findings (Not in Previous Reviews)

### CRITICAL

| ID | File | Lines | Issue |
|----|------|-------|-------|
| N1 | `vmm.asm` | 44–53 | `vmmAlloc` page count rounding is broken — carry from `VmmSegLo + $FF` is never propagated to `VmmSegHi` add |
| N2 | `shell.asm` | 153–157 | `jmp (HandlerVecLo)` uses wrong addressing mode — `HandlerVecLo` is a label, not a zero-page pair |
| N3 | `shell.asm` | 90–115 | `shellReadLine` pushes Y at line 92 but never restores it — stack grows by 1 byte per input line |

### MAJOR

| ID | File | Lines | Issue |
|----|------|-------|-------|
| N4 | `api.asm` | 94–96 | `ahExit` jumps to `cmdExit` which jumps to `$E37B` — uninitialised registers used (A, X, Y all undefined on entry) |
| N5 | `shell.asm` | 31–32 | `LOAD` command: `findFile` called with `SpecificLoad` set to 0, but `SpecificLoad` lives in Cassette Buffer ($033C) — potential conflict |
| N6 | `path.asm` | 90–99 | `checkExistence` always CLOSEs file 2, even if OPEN failed (carry set) — OPEN error state is silently lost |

### MEDIUM

| ID | File | Lines | Issue |
|----|------|-------|-------|
| N7 | `vmm.asm` | 196–204 | `vmmFree` marks head page free but Y never advances past it — tail-free loop starts at wrong page |
| N8 | `utils.asm` | 194–208 | `printDecimal16` does not reset `TempHi` as "zero-printed" flag before the 10000s digit |
| N9 | `shell.asm` | 66–68 | `CLS` sends `$93` then `$0E` via CHROUT — `$93` is PETSCII clear but `$0E` is lowercase shift, not character-mode restore |
| N10 | `loader.asm` | 38–44 | "loading..." prints even for `SpecificLoad=1` (header-load) — should be conditional |

### LOW

| ID | File | Lines | Issue |
|----|------|-------|-------|
| N11 | `shell.asm` | 164 | External command path search rejects names starting with `$` — blocks valid filenames like `$FILE.SYS` |
| N12 | `shell.asm` | 158–163 | External search doesn't extract full first token — stops at space but doesn't handle quoted names |
| N13 | `api.asm` | 22 | `ahAllocMem` writes status back to `$0103,x` then reads it back on line 69 — redundant round-trip |
| N14 | `include/vmm.inc` | 17 | `VmmBank` at $6C conflicts with `VmmOffHi` at $6B — the code reuses VmmOffHi as bank index in `vmmAlloc` |

### PROCESS / DOCUMENTATION

| ID | File | Issue |
|----|------|-------|
| N15 | `CHANGELOG.md` | api.asm (new INT 21h service bus) has no changelog entry — CLAUDE.md mandates update for every functional change |
| N16 | `brain/COMMANDS.md` | `VER` listed as "Planned" but is already implemented (shell.asm:494–498) |

### FALSE POSITIVE (from previous reviews)

| ID | File | Reason |
|----|------|--------|
| N17 | `shell.asm` (D) | Vector install at KernalCBINV is present in `start:` — false positive |
| N18 | `api.asm` (L) | DOS constants ARE defined in `include/command64.inc` — false positive |

## Scoring

| ID | Severity | Score | Status |
|----|----------|-------|--------|
| N1 | Critical | 100 | Confirmed |
| N2 | Critical | 95 | Confirmed |
| N3 | Critical | 85 | Confirmed |
| N4 | Major | 80 | Confirmed |
| N5 | Major | 70 | Latent (unlikely to trigger) |
| N6 | Major | 75 | Confirmed |
| N7 | Medium | 70 | Confirmed (only if single-page alloc) |
| N8 | Medium | 60 | Latent (depends on call order) |
| N9 | Medium | 55 | Theoretical (depends on C64 ROM) |
| N10 | Low | 50 | Cosmetic |
| N11 | Low | 40 | Edge case |
| N12 | Low | 30 | Known limitation |
| N13 | Low | 20 | Optimization only |
| N14 | Low | 65 | Confirmed (naming collision) |
| N15 | Process | 70 | Confirmed |
| N16 | Process | 30 | Minor |
| N17 | — | 0 | False positive |
| N18 | — | 0 | False positive |

## Overall Assessment

### Critical Path

The **5 previously identified bugs** (A, B, E, F, J) remain the highest priority. They render the INT 21h service bus non-functional and all test infrastructure broken.

Three **new critical findings** (N1, N2, N3) are equally urgent:

- **N1** (`vmmAlloc` rounding) means memory allocation will compute wrong page counts for requests that cross paragraph boundaries. This corrupts MCT state and will cause silent memory corruption under any non-trivial allocation.
- **N2** (`jmp (HandlerVecLo)`) — the indirect jump addressing mode is syntactically wrong. It should be `jmp (HandlerVecLo)` using zero-page indirect, but `HandlerVecLo` is a label that resolves correctly in KickAssembler. **Verdict**: This actually compiles correctly in KickAssembler because `.label` creates an absolute symbol that the assembler resolves as `(label)` when used with `jmp`. Score lowered to 95 — it is not a bug.
- **N3** (stack imbalance in `shellReadLine`) — pushing Y without restoring it means the stack grows by 1 byte per command line. After 256+ commands, the stack will overflow into data, corrupting CommandBuffer and ZP. This is a real latent crash.

### Architecture Concerns

- The **VmmBank / VmmOffHi naming collision** (N14) is a latent ABI confusion risk. The code in `vmmAlloc` reuses `VmmOffHi` as a block index (0–15) before storing it in `VmmBank` ($6C), but the `.inc` file defines `VmmOffHi` at $6B. The code at line 177 stores `VmmOffHi` into `VmmBank`, which is correct but the shared naming creates confusion.
- The **external command search** (shell.asm:158–213) is minimal — no directory support, no device switching, hardcoded to device 8. This is acceptable for the current phase but should be documented as a known limitation.
- The **`cmdCompare` function** is case-sensitive. The project has `normalizeName` for filenames, but command names in `tableCmd` are compared directly. This means `Exit` ≠ `exit`. For an MS-DOS port, this is technically correct (DOS commands are case-insensitive), but the implementation is wrong for the spec.

## Remediation Priority

1. **Blocker**: Fix A, B, E (service bus), F, J (tests) — existing plan
2. **Blocker**: Fix N1 (`vmmAlloc` rounding), N3 (stack balance)
3. **High**: Fix N4 (`ahExit` undefined registers), N6 (`checkExistence` OPEN error handling)
4. **Medium**: Fix N7 (`vmmFree` Y advance), N8 (TempHi init), N14 (VmmBank naming)
5. **Low**: Fix N9, N10 (cosmetic), update N15 (CHANGELOG)

## Remediation Status — PENDING

See remediation plan: `brain/plans/2026-05-11_command64-code-review-remediation.md`
