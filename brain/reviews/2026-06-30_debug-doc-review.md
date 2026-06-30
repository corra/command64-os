# Peer Review: DEBUG Documentation Expansion

- **Date**: 2026-06-30
- **Reviewer**: Claude Sonnet 4.6 (Multi-agent, Medium Effort — 8 finder angles, 1-vote verify)
- **Target**: Unstaged working-tree changes — `docs/apps/debug.md`, `wiki/debug-utility.md`, `brain/plans/debug-phase3-debugger.md`
- **Plan Reference**: `brain/plans/debug-phase3-debugger.md`
- **Full Raw Analysis**: `brain/research/debug_doc_review_raw_findings.md`
- **Analysis Summary**: `brain/analysis/claude_debug_doc_review.md`

---

## 1. Overview of Reviewed Changes

The diff expands the DEBUG utility documentation in three main areas:

1. **`docs/apps/debug.md`**: Major expansion from a minimal overview to a full user guide. Adds exhaustive syntax and example sections for every command, a new Processor Status Register reference (bit table + common P values), an Error Messages table, and an MS-DOS Parity & Platform Notes section.
2. **`wiki/debug-utility.md`**: Parity table updated to reflect Phase 1/2 completion; key behavioral deviations from MS-DOS DEBUG documented.
3. **`brain/plans/debug-phase3-debugger.md`**: Phase 3 plan rewritten with significantly more implementation detail — virtual PC tracking, RTI stack frame design, CBINV hijacking, `myBrkHandler` register extraction offsets, and updated ROM safety logic.

The changes are documentation-only. No source code was modified.

---

## 2. Key Findings

### Finding 1: Phase 3 ROM Safety Threshold Assumes an Undocumented, Not-Yet-Landed Bank-Switching Update (Critical)

- **File**: `brain/plans/debug-phase3-debugger.md`, §4 (ROM Safety Guards)
- **Status**: **Premature / Undocumented Dependency** (not a standalone factual error — see author clarification below)

The new plan replaced the safe-address check `A < $A000` with `A < $D000`, asserting: *"BASIC ROM (`$A000–$BFFF`) is banked out on startup (exposing the underlying RAM)."*

A full grep of all source files finds **zero writes to CPU I/O port `$01`** (`STA $01`). On a stock C64, `$01` defaults to `$37` (HIRAM=LORAM=CHAREN=1), meaning BASIC ROM remains mapped at `$A000–$BFFF` **as of the current codebase**. No bank-out occurs at startup today.

**Author clarification (2026-06-30)**: This is intentional forward-reference to a planned bank-switching update (CPU I/O port `$01` reconfiguration to bank out BASIC ROM at startup) that has **not yet been implemented or documented elsewhere**. The Phase 3 plan's `A < $D000` threshold is written against that future state, not the current one. The plan text does not currently disclose this dependency, which is the actual defect — not the threshold value itself.

**Failure scenario (current codebase)**: If Phase 3 were implemented today, against the as-is memory map, a user setting a breakpoint via `T` at `$A000` would be considered safe (`A < $D000`). The `BRK` write would land in ROM, be silently discarded, and the debugger would RTI expecting to trap on `BRK` but instead execute live BASIC ROM — hang or crash. This risk is real **until the bank-switching update lands**.

**Remediation**: Do not revert the threshold — leave it as-is per author direction, since it anticipates planned work. Instead, the plan must explicitly document the dependency: add a note in §4 stating that `A < $D000` is only safe once the (currently unimplemented, undocumented) startup bank-switching change banks out BASIC ROM via CPU I/O port `$01`, and that Phase 3 implementation must not proceed ahead of that prerequisite landing. Until then, the threshold is aspirational, not actionable.

---

### Finding 2: `$F0` P-Register Table Entry Incorrectly Claims Decimal Flag Is Set (High)

- **File**: `docs/apps/debug.md`, Common P Values table (~line 499)
- **Status**: **Factual Error**

The table entry for `$F0` reads: *"Negative, Overflow, B, Decimal all set."*

`$F0 = 1111 0000`. Bit 3 (D = Decimal mode) = **0**. Only bits 7 (N), 6 (V), 5 (unused/always-1), and 4 (B) are set.

**Failure scenario**: A user sets `P = $F0` expecting BCD arithmetic. BCD does not activate. ADC/SBC operate in binary with no diagnostic signal — the `R` display shows `$F0` exactly as entered.

**Remediation**: Change description to: *"Negative, Overflow, B set (N, V, unused bit, B — bits 7–4)."*

---

### Finding 3: `C` Command Example Uses Mnemonic Where Hex Byte Should Appear (High)

- **File**: `docs/apps/debug.md`, §6 Compare examples (~line 221)
- **Status**: **Incorrect Example**

The example output shows:
```
1005 60 RTS 2005  ; Mismatch at offset $05: source has $60, dest has $FF
```

The `C` command format is `[src_addr] [src_byte] [dest_byte] [dest_addr]`. The dest byte position shows the mnemonic `RTS` instead of a hex value. The comment says dest has `$FF`, but `RTS` = `$60` (same as source), so neither the mnemonic nor the comment agrees with the other.

**Remediation**: Change to: `1005 60 FF 2005  ; Mismatch at offset $05: source has $60, dest has $FF`.

---

### Finding 4: UI Behavior ROM Safeguard Text Contradicts Phase 3 Plan (Medium)

- **File**: `docs/apps/debug.md`, UI Behavior & Quirks section (~line 580)
- **Status**: **Inconsistency** (dependent on Finding 1)

The UI doc reads: *"The `T` and `P` commands cannot set breakpoints in ROM (`$A000-$BFFF`, `$D000-$FFFF`)."* The updated Phase 3 plan claims `$A000–$BFFF` is writable RAM and defines safe as `A < $D000`. The two documents contradict each other.

Given Finding 1, the UI doc is currently the more accurate of the two. Once Finding 1 is resolved this bullet must be kept in sync with whatever threshold the plan settles on.

**Remediation**: No action until Finding 1 is resolved. Then verify this text matches the final safe-address definition.

---

### Finding 5: B Flag Description Implies It Is a Live User-Settable Bit (Medium)

- **File**: `docs/apps/debug.md`, Processor Status Register Bits table, B flag row (~line 483)
- **Status**: **Misleading**

The description reads: *"Only meaningful when read off the stack after an interrupt."*

DEBUG captures `P` exclusively from the `BRK` interrupt frame. The 6502 forces bit 4 = 1 in every `BRK`-pushed status byte. As a result, B will always appear set in DEBUG's register display regardless of what the user writes with `R P`.

**Remediation**: Add: *"In DEBUG's `R` display, B always appears set because P is captured from the BRK frame where the CPU forces bit 4 to 1. A value written via `R P` with B=0 will return to 1 after the next `T`/`P` cycle."*

---

### Finding 6: `traceMode` Variable Has No Specified Reset Path in `myBrkHandler` (Medium)

- **File**: `brain/plans/debug-phase3-debugger.md`, §2 variable layout / §7 `myBrkHandler`
- **Status**: **Implementation Gap**

The plan introduces `traceMode: .byte 0` (0=Trace, 1=Proceed) to route JSR behavior in `decodeTargets`. The `myBrkHandler` description in §7 does not include a step to reset `traceMode` before returning to `mainLoop`. If `cmdTrace` fails to write `traceMode = 0` before calling `decodeTargets`, a stale `traceMode = 1` from a prior `P` invocation will cause `T` to step over a JSR instead of stepping into it.

**Remediation**: Add to the implementation checklist: *"In `cmdTrace`, write `$00` to `traceMode`. In `cmdProceed`, write `$01`. Both must occur before calling `decodeTargets`."*

---

### Finding 7: T/P Documented with Full Examples but Marked "Planned" in Wiki (Medium)

- **File**: `wiki/debug-utility.md`, T and P rows (~lines 125, 129)
- **Status**: **Inconsistency**

`docs/apps/debug.md` §15 presents four complete interactive T/P examples with register output, treating the commands as available. The wiki parity table reads `*Planned (Phase 3)*` for both. All Phase 3 checklist items remain unchecked.

Per CLAUDE.md, documentation-driven spec-ahead examples are expected practice. However the wiki table should distinguish *specified* from *implemented* to prevent user confusion.

**Remediation**: Change T/P wiki status to `*Specified — Planned (Phase 3)*` or add a note column distinguishing documented spec from working implementation.

---

### Finding 8: JSR-to-ROM vs JMP/Branch-to-ROM Abort Logic Underdocumented (Low)

- **File**: `brain/plans/debug-phase3-debugger.md`, §4 (ROM Safety Guards)
- **Status**: **Ambiguity**

The plan describes two distinct behaviors: JSR to ROM → auto step-over (breakpoint at `regPC+3`); branch/JMP to ROM → abort. The plan does not explicitly state that the safety check must be applied per-computed-target inside `decodeTargets` (not at the command-handler level). An implementor could plausibly apply a single up-front check, misrouting all ROM-destination instructions to step-over rather than abort.

**Remediation**: Add a note to the `decodeTargets` section: *"For each computed target: if the target is unsafe and the instruction is not JSR, set no breakpoints and abort. If the instruction is JSR and the target is unsafe, reroute to the step-over target (`regPC+3`) instead."*

---

## 3. Verified Correct Claims (No Action Required)

- **RTI stack frame layout**: Math verified correct. SP set to `regS-3`; RTI reads P, PCL, PCH from `$0100+regS-2`, `-1`, `+0` respectively. ✓
- **`myBrkHandler` register offsets**: KERNAL pushes Y, X, A after CPU pushes PCH, PCL, P. Offsets `$0101,x`–`$0106,x` are correct. `regS = X + 6` is correct. ✓
- **PC recovery math**: BRK pushes PC+2; subtracting 2 recovers the BRK instruction address. ✓
- **Disk error codes**: 1541 error 62 = FILE NOT FOUND, 63 = FILE EXISTS. Both correct per CBM DOS spec. ✓
- **P register bit layout**: 7=N, 6=V, 5=unused/always-1, 4=B, 3=D, 2=I, 1=Z, 0=C is correct. ✓
- **`$30` power-on default**: `0011 0000` = bits 5 and 4 (unused + B) set, all flags clear. ✓

---

## 4. Action Priority Summary

| # | Severity | File | Required Action |
|---|----------|------|-----------------|
| 1 | **Critical** | `brain/plans/debug-phase3-debugger.md` | Document that `A < $D000` assumes a planned, not-yet-implemented bank-switching update; do not implement Phase 3 against this threshold until that prerequisite lands |
| 2 | **High** | `docs/apps/debug.md` | Fix `$F0` row — remove "Decimal" from description |
| 3 | **High** | `docs/apps/debug.md` | Fix `C` example line ~221: `RTS` → `FF` in dest column |
| 4 | **Medium** | `docs/apps/debug.md` | Sync UI Behavior ROM guard text after #1 is resolved |
| 5 | **Medium** | `docs/apps/debug.md` | Clarify B flag is always set in DEBUG's BRK-capture display |
| 6 | **Medium** | `brain/plans/debug-phase3-debugger.md` | Add explicit `traceMode` reset step before `decodeTargets` |
| 7 | **Medium** | `wiki/debug-utility.md` | Distinguish T/P as specified-but-not-implemented vs. Planned |
| 8 | **Low** | `brain/plans/debug-phase3-debugger.md` | Clarify per-target safety check logic in `decodeTargets` narrative |
