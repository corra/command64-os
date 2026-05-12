---
feature: command64-bug-verification
reviewed: 2026-05-11
status: remediation-planned
---

# Code Review: command64 Bug Verification

## Scope
Verification of bugs identified during the analysis of Phase 2A/2C remediation.

| File | Role |
|------|------|
| `include/command64.inc` | Core definitions |
| `src/command64/loader.asm` | Program loader |
| `src/command64/utils.asm` | Utility routines |
| `src/command64/vmm.asm` | Virtual Memory Manager |

## Findings Scorecard

| ID | File | Severity | Issue | Findings |
|----|------|----------|-------|----------|
| C4 | `loader.asm` / `command64.inc` | Major | `SpecificLoad` comment inversion | Code is functionally correct (`0=HexVal`, `1=Header`), but comments state the opposite. |
| C8 | `src/command64/utils.asm` | Major | `printDecimal16` uninitialized `TempHi` | `TempHi` is not cleared in the subroutine, potentially causing garbage leading zeros. |
| C5 | `src/command64/path.asm` | Minor | Case normalization completeness | **FALSE POSITIVE.** Normalization is correct for the project's lowercase-first mixed-mode. |
| I2 | `src/command64/vmm.asm` | Major | Missing VMM init safety check | `vmmAlloc` proceeds even if REU detection failed, risking memory corruption. |

## Detailed Analysis

### C4: `SpecificLoad` Inversion
The KERNAL `SETLFS` routine expects `Y=0` for relocated loads and `Y=1` for absolute header loads. The `shell.asm` code correctly sets `SpecificLoad=0` for hex address loads and `SpecificLoad=1` for header loads. However, the comments in both the header and loader files are swapped, leading to confusion.

### C8: `printDecimal16`
The routine suppresses leading zeros by checking `TempHi`. If `TempHi` is non-zero from a previous operation (e.g., `vmmAlloc` or `loader`), the printer will treat the first digit as if a non-zero was already printed, leading to incorrect formatting.

### I2: VMM Safety
If `vmmInit` fails (e.g., no REU), `vmmAlloc` will still attempt to search the MCT. Since the MCT shares memory with BASIC ($C000 area is safe but uninitialized), this could lead to false-success allocations and subsequent writes to random memory.

## Overall Assessment
The project is functional, but these "residual" bugs pose risks for future stability and developer clarity.

## Remediation Status — COMPLETE (2026-05-11)
See `brain/plans/2026-05-11_command64-remediation-round2.md`.

- [x] C4 — Fixed `SpecificLoad` comments in `.inc` and `loader.asm`
- [x] C8 — Added `TempHi` initialization to `printDecimal16`
- [x] I2 — Added `vmmInitialized` flag and safety check to `vmmAlloc`
