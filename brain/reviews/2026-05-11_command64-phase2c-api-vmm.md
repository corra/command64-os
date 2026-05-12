---
feature: command64-phase2c-api-vmm
reviewed: 2026-05-11
status: remediation-pending
---

# Code Review: Phase 2C — VMM, Service Bus (api.asm), and Test Infrastructure

## Scope

Branch `command64` reviewed against the current `main` branch. Review covers all
assembly source files added or modified as part of Phase 2C and the new INT 21h
service bus work.

| File | Role |
|------|------|
| `src/command64/api.asm` | INT 21h BRK-based service bus dispatcher (NEW) |
| `src/command64/vmm.asm` | Virtual Memory Manager — alloc/free/read/write |
| `src/command64/shell.asm` | Command loop, dispatcher, built-in handlers |
| `src/command64/utils.asm` | `parseHex`, `normalizeName`, `printDecimal16` |
| `src/command64/loader.asm` | KERNAL LOAD wrapper |
| `src/command64/path.asm` | File discovery, `.prg` extension appending |
| `include/command64.inc` | KERNAL equates, ZP labels, buffer constants |
| `include/vmm.inc` | VMM ABI constants and ZP labels |
| `build/command64.asm` | KickAssembler root build file and segment layout |
| `tests/src/apitest.asm` | Service bus smoke test (NEW) |
| `tests/src/vmmtest.asm` | VMM alloc/free round-trip test (NEW) |
| `tests/build_tests.sh` | Test compilation script |

## Review Method

5 independent Sonnet agents reviewed the branch in parallel, each from a different
angle (CLAUDE.md compliance, shallow bug scan, git history context, code-comments
compliance, cross-module ABI consistency). Each finding was then scored 0–100 by an
independent Haiku agent using a defined confidence rubric. Only findings scoring ≥ 80
are classified as confirmed.

## Findings Scorecard

| ID | File | Lines | Severity | Issue | Score |
|----|------|-------|----------|-------|-------|
| A  | `src/command64/api.asm` | 108–120 | Critical | `ahSetCarry`/`ahClearCarry` call `tsx` after `jsr` pushes 2-byte return addr; `$0104,x` addresses saved X, not saved P — carry never set/cleared, saved X corrupted on every call | 100 |
| B  | `src/command64/vmm.asm` | 107–116, 122–132 | Critical | `vaSearchReset` and `vaCommitAlloc` restore `PrintPtrHi` from raw block index (0–15) instead of `$C0 + index`; MCT writes corrupt zero page on any backtracking alloc | 100 |
| E  | `src/command64/api.asm` | 83–91 | Critical | `ahFreeMem`: `beq _afOk` tests Z from `tsx` (SP ≈ $FF, never zero); `sta` does not set flags; `vmmFree` always appears to fail regardless of result | 100 |
| F  | `tests/build_tests.sh` | 1, 10–14 | High | Broken shebang (`tests/bin/bash`); paths use `src/*.asm` instead of `tests/src/*.asm`; `apitest.asm` and `vmmtest.asm` are never compiled | 100 |
| J  | `tests/src/vmmtest.asm` | 27–37 | High | `DOS_PRINT_STR` BRK between alloc and free loads X/Y with message pointer; subsequent `DOS_FREE_MEM` receives garbage page/bank — test always fails at free step | 100 |
| G  | `CHANGELOG.md` | — | Medium | `api.asm` (new INT 21h service bus) has no changelog entry; CLAUDE.md mandates update for every functional change | 75 |
| I  | `src/command64/vmm.asm` | 305–312 | Low | `vmmComputeAddress` uses `plp` before `adc` — restores full P including Decimal flag; BCD mode would corrupt address if caller had D=1 | 50 |
| D  | `src/command64/shell.asm` | 50–53 | — | **False positive** — `apiHandler` IS installed at `KernalCBINV` ($0316/$0317) in `start:`. Issue did not survive verification. | 0 |
| L  | `src/command64/api.asm` | 23–31 | — | **False positive** — DOS constants (`DOS_PRINT_CHAR` etc.) ARE defined in `include/command64.inc`; KickAssembler resolves them via the build import chain. | 0 |

### Summary

- **5 confirmed bugs** (score ≥ 80): A, B, E, F, J
- **1 process gap** (score 75, below threshold): G — CHANGELOG not updated
- **2 low/latent issues** (score ≤ 50): I (Decimal flag risk), plus stale loader.asm comments
- **2 false positives**: D (vector install present), L (constants defined in .inc)

## Key Findings Detail

### A — `ahSetCarry`/`ahClearCarry` wrong stack offset (Critical)

The helpers call their own `tsx` after being entered via `jsr`. The JSR pushes a 2-byte
return address, so `X_helper = SP_original − 2`. `$0104,x` inside the helper addresses
`$0102 + SP_original` = the saved **X register**, not saved P. Carry is never
modified; the saved X register is corrupted on every API call. Correct offset: `$0106,x`.

### B — `vmmAlloc` pointer restoration corrupts ZP (Critical)

`vaFoundPotential` saves `TempLo` (block counter, 0–15) into `VmmOffHi`. Both
`vaSearchReset` and `vaCommitAlloc` restore `PrintPtrHi` from `VmmOffHi`, setting it
to 0–15 instead of `$C0–$CF`. Any `vmmAlloc` that requires backtracking will read/write
MCT state from zero page, corrupting all ZP variables. Fix: reconstruct as
`#>VmmMctBase + VmmOffHi` (same pattern as `vmmFree`).

### E — `ahFreeMem` branch never taken (Critical)

After `jsr vmmFree`, the sequence `tsx : sta $0103,x : beq _afOk` always falls through
because `sta` does not set flags and `tsx` sets Z from the stack pointer (~$FF, never
zero). `ahSetCarry` is called unconditionally. Fix: add `lda $0103,x` after the `sta`
to reload A and set Z from the status value (the pattern already correct in `ahAllocMem`).

### F — `build_tests.sh` broken paths and shebang (High)

Shebang line reads `tests/bin/bash` instead of `#!/bin/bash`. All five assembly source
paths use `src/*.asm` instead of `tests/src/*.asm`. No `set -e`, so KickAss failures
are silently swallowed. The two new test programs (`apitest`, `vmmtest`) have never
been compiled.

### J — vmmtest.asm clobbers alloc result with print args (High)

After `DOS_ALLOC_MEM` returns page/bank in X/Y, the test issues a `DOS_PRINT_STR` BRK
with new X/Y values (message pointer). The KERNAL exit restores registers from the
pushed frame, so X/Y after the print BRK hold the message pointer, not the alloc
result. The `DOS_FREE_MEM` call at line 35 uses garbage values and always returns
`VMM_ERR_INVALID`. Fix: save X/Y to ZP (`$64`/`$65`) before the print call, restore
before the free call.

## Overall Assessment

The INT 21h service bus (`api.asm`) is **non-functional as written** due to bugs A
and E: carry flags are never propagated to callers, and `DOS_FREE_MEM` always reports
failure. Bug B means `vmmAlloc` will silently corrupt zero page on any non-trivial
allocation (one where the first pages checked are not immediately sufficient). The test
infrastructure (F, J) would also fail to validate any of these fixes even if they were
applied.

The non-service-bus code (shell, loader, path, utils, VMM read/write) appears sound.
The `vmmComputeAddress` Decimal flag risk (I) is theoretical in the current call graph.

## Remediation Status — PENDING

See remediation plan: `brain/plans/2026-05-11-api-vmm-bug-remediation.md`

- [ ] A — Fix `ahSetCarry`/`ahClearCarry`: `$0104,x` → `$0106,x`
- [ ] B — Fix `vaSearchReset`/`vaCommitAlloc`: `lda VmmOffHi` → `lda #>VmmMctBase : clc : adc VmmOffHi` before `sta PrintPtrHi`
- [ ] E — Fix `ahFreeMem` branch: add `lda $0103,x` after `sta $0103,x` before `beq _afOk`
- [ ] F — Fix `build_tests.sh`: shebang, paths `src/` → `tests/src/`, add `set -e`
- [ ] J — Fix `vmmtest.asm`: `stx $64 : sty $65` before print BRK; `ldx $64 : ldy $65` before free BRK
