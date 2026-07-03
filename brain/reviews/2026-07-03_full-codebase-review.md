---
feature: command64-codebase-review-july3
reviewed: 2026-07-03
status: remediation-in-progress
---

# Code Review: Command64 OS — Supplemental Codebase Review

## Scope

Supplemental codebase review focusing on:

1. Virtual Memory Manager (VMM) and zero-page bank parameter processing.
2. Shell environment and file system edge cases.
3. Client-side SPA website implementation and documentation parsing.
4. Residual test-harness cleanup issues.

---

## Findings

### HIGH / CRITICAL

| ID | File | Lines | Issue |
|----|------|-------|-------|
| S1 | `vmm.asm` | 318–372 | `vmmComputeAddress` completely ignores the `VmmBank` (ZP `$6C`) register. REU banks are computed purely via `VmmSegHi >> 4`, forcing all read/write operations to Bank 0 of the current 1MB block. Allocations >1MB will overwrite bank 0 memory and corrupt existing data. |
| S2 | `shell.asm` | 1527–1850 | Environment helper routines (e.g. `cmdSetPrint`, `envAppend`, `envSearch`) load `EnvSegmentLo/Hi` into `VmmSegLo/Hi` before VMM calls but never initialize or restore `VmmBank` (ZP `$6C`). If S1 is fixed, environment lookups/writes will access random memory banks depending on garbage in `$6C`. |
| S3 | `shell.asm` | 1059–1067 | `ccCopyDest` copies the destination filename into the 40-byte `DestBuf` with no bounds check. Long destination paths (>40 chars) will overflow the buffer into adjacent Cassette Buffer fields, and paths >54 chars will write to Screen RAM (`$0400`), causing display corruption/crashes. |

### LOW / CLEANUP

| ID | File | Lines | Issue |
|----|------|-------|-------|
| S4 | `app.js` | 325–327 | The documentation fetch function contains a comment `// Process GitHub markdown alerts into HTML blockquotes`, but has no implementation (just `let processedMarkdown = markdown;`). Raw `[!NOTE]`, `[!WARNING]` markers are shown on the website instead of styled alert divs. |
| S5 | `filetest.asm` | 50–53 | Leftover dead pointer load instructions `ldy #>fname` and `ldx #<writeData` are immediately overwritten by the correct write setup. Harmless as-written but represents dead/confusing code. |
| S6 | `path.asm` | 9–19 | `findFile` header documentation still claims it appends `.prg` on failure, but this functionality was removed since disk entries no longer contain file extensions. |
| S7 | `petsci.asm` | 20 | `petPrintString` header comment states it uses zero page `$22` and `$23`. However, the labels `PrintPtrLo/Hi` actually map to `$FB` and `$FC` per `include/command64.inc`. |

---

## Remediation Priority

1. **Critical**: S1 (`vmmComputeAddress` ignoring bank) + S2 (missing bank setup in environment helpers) — must be fixed together to avoid breaking environment operations.
2. **High**: S3 (destination filename overflow bounds check).
3. **Low/Cleanup**: S4 (markdown alert rendering on site), S5 (test cleanup), S6/S7 (outdated comments).

---

## Remediation Status

- **S1 (VMM Bank Register Mapping)**: FIXED in `src/command64/vmm.asm`. Added support for calculating the physical REU bank byte by combining `VmmBank` and `VmmSegHi >> 4` while preserving carry.
- **S2 (Shell Environment Bank Tracking)**: FIXED in `src/command64/shell.asm`. Added code to save `VmmBank` to `EnvBank` on init and reload it before env VMM operations.
- **Segment Overlap Blocker**: FIXED by removing the unused `notImplMsg` from `shell.asm` to free 36 bytes.
