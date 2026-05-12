---
feature: command64-code-review-remediation
created: 2026-05-11
status: in-progress
---

# Remediation Plan: command64 Code Review Findings

## Goal

Address all confirmed bugs and issues from the full code review (`brain/reviews/2026-05-11_command64-full-code-review.md`).

## Files Modified

| File | Changes |
|------|---------|
| `src/command64/api.asm` | Fix `ahSetCarry`/`ahClearCarry` offset (A), `ahFreeMem` branch (E), `ahExit` registers (N4) |
| `src/command64/vmm.asm` | Fix `vmmAlloc` rounding (N1), `vmmFree` Y advance (N7), `VmmBank` naming (N14) |
| `src/command64/shell.asm` | Fix `shellReadLine` stack balance (N3) |
| `src/command64/path.asm` | Fix `checkExistence` OPEN error handling (N6) |
| `tests/build_tests.sh` | Fix shebang and paths (F) |
| `tests/src/vmmtest.asm` | Fix register preservation (J) |
| `CHANGELOG.md` | Add Phase 2C service bus entry (N15) |
| `brain/COMMANDS.md` | Mark VER as implemented (N16) |

## Implementation Steps

### Round 1: Critical Blockers (A, B, E, N1, N3, F, J)

**Step 1: Fix `ahSetCarry`/`ahClearCarry` (api.asm:108–120)**
- Change `$0104,x` → `$0106,x` in both helpers
- Rationale: After JSR pushes 2-byte return addr, the saved P is at offset +6 from TSX result

**Step 2: Fix `vmmAlloc` MCT pointer reconstruction (vmm.asm:107–132)**
- `vaSearchReset`: Replace `lda VmmOffHi : sta PrintPtrHi` with `lda #>VmmMctBase : clc : adc VmmOffHi : sta PrintPtrHi`
- `vaCommitAlloc`: Same fix
- Rationale: `VmmOffHi` is a block offset (0–15), needs base `$C0` added

**Step 3: Fix `ahFreeMem` branch (api.asm:83–91)**
- After `sta $0103,x`, add `lda $0103,x` before `beq _afOk`
- Also save/restore X/Y around `jsr vmmFree` since it clobbers them
- Rationale: `sta` doesn't set flags; need `lda` to check Z

**Step 4: Fix `vmmAlloc` page count rounding (vmm.asm:44–53)**
- Add `clc` before `adc #0` on line 51 to propagate carry from line 49
- Rationale: `(SegLo + $FF)` always produces `$FF` with carry=1; that carry must propagate to SegHi

**Step 5: Fix `shellReadLine` stack balance (shell.asm:88–115)**
- After `rlDoneRead` label, add `tya : pha` before null terminator, then `pla : tay` after `CommandBuffer, y` store
- Or simpler: push Y once at entry, pop before `rts`

**Step 6: Fix `build_tests.sh` (F)**
- Line 1: `tests/bin/bash` → `#!/bin/bash`
- Lines 10–14: `src/` → `tests/src/`
- Add `set -e` after shebang

**Step 7: Fix `vmmtest.asm` register preservation (J)**
- Before each `DOS_PRINT_STR` BRK: `stx $64 : sty $65`
- After each `DOS_PRINT_STR` BRK: `ldx $64 : ldy $65`

### Round 2: High Priority (N4, N6)

**Step 8: Fix `ahExit` undefined registers (api.asm:94–96)**
- Initialize A, X, Y before jumping to `cmdExit`, or change to a clean exit via BASIC warm start directly

**Step 9: Fix `checkExistence` OPEN error handling (path.asm:90–99)**
- After `jsr KernalOPEN`, check carry before closing
- Only CLOSE if OPEN succeeded (carry clear)

### Round 3: Medium Priority (N7, N8, N14)

**Step 10: Fix `vmmFree` Y advance (vmm.asm:196–204)**
- After marking head page free, `iny` before the `bne vfCheckNext` loop

**Step 11: Fix `printDecimal16` TempHi init (utils.asm:110–112)**
- Add `lda #0 : sta TempHi` at function entry

**Step 12: Fix VmmBank naming (vmm.inc + vmm.asm)**
- Add comment clarifying that `VmmBank` ($6C) is separate from `VmmOffHi` ($6B)
- Or rename intermediate variable in `vmmAlloc` to avoid confusion

### Round 4: Process (N15, N16)

**Step 13: Update CHANGELOG.md with Phase 2C service bus entry**
**Step 14: Update brain/COMMANDS.md — mark VER as done**

## Verification Plan

1. `bash tests/build_tests.sh` — verify all tests assemble without errors
2. Verify `command64.prg` assembles cleanly
3. Runtime verify on VICE:
   - Service bus string output works
   - VMM alloc/free round-trip works
   - Shell handles 256+ command lines without crash (N3 fix)
   - LOAD with custom address works (N1 fix)
