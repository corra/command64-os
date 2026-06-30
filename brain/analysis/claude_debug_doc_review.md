# Analysis: DEBUG Documentation Expansion — Findings by Angle

**Date**: 2026-06-30
**Full peer review**: `brain/reviews/2026-06-30_debug-doc-review.md`
**Raw multi-agent findings**: `brain/research/debug_doc_review_raw_findings.md`

---

## TL;DR

Two factual errors and one undocumented dependency require correction before the documentation is committed:

1. **CRITICAL** — Phase 3 plan's ROM safety threshold `A < $D000` assumes BASIC ROM is banked out via a planned CPU I/O port `$01` update that has **not yet been implemented or documented anywhere**. Against the current codebase, the premise is false (zero `STA $01` writes exist; BASIC ROM is live at `$A000–$BFFF`). Author confirmed (2026-06-30) this is intentional forward-reference to future work — the defect is that the plan doesn't disclose the dependency, not the threshold value itself. Do not implement Phase 3 against this threshold until the bank-switching update lands; the plan should state this prerequisite explicitly.
2. **HIGH** — `$F0` in the P-register table is described as "Decimal all set" — bit 3 (D) is 0 in `1111 0000`. Decimal is not set.
3. **HIGH** — `C` command example shows `RTS` (a mnemonic) where the destination hex byte belongs; the comment disagrees with it too.

Five additional medium/low findings are documentation inconsistencies or implementation gaps in the plan, not errors in shipped material.

---

## Angle A — Line-by-Line Correctness

### Confirmed Correct
- **RTI stack frame**: SP set to `regS-3`; RTI reads P, PCL, PCH from `$0100+regS-2/−1/+0`. ✓
- **`myBrkHandler` register offsets**: KERNAL pushes Y, X, A; CPU pushes PCH, PCL, P. Offsets `$0101,x`–`$0106,x` match. `regS = X + 6` is correct. ✓
- **PC recovery `−2` correction**: BRK pushes PC+2; subtracting 2 recovers BRK address. ✓
- **1541 disk error codes 62/63**: FILE NOT FOUND / FILE EXISTS. Correct per CBM DOS spec. ✓
- **P register bit layout (7=N…0=C)**: Correct. `$30` power-on default correct. ✓

### Confirmed Error
- **`$F0` Decimal flag** (`docs/apps/debug.md` ~499): `$F0 = 1111 0000` — bit 3 (D) = 0. Table reads "Decimal all set." Wrong.

---

## Angle B — Removed Behavior Audit

### Confirmed Issue — Undocumented Forward Dependency (not a standalone error)
- **BASIC ROM bank-out claim** (`brain/plans/debug-phase3-debugger.md` §4): Old plan used `A < $A000` OR (`$C000 ≤ A < $D000`). New plan uses `A < $D000`, asserting BASIC ROM is "banked out on startup." Full source grep finds **zero `STA $01` instructions** — against the *current* codebase, BASIC ROM is mapped (`$01 = $37` at reset). Author confirmed (2026-06-30) this anticipates a planned, not-yet-implemented CPU I/O port `$01` bank-switching update; the threshold is intentional but the plan fails to disclose that dependency. Until that update lands, the threshold silently permits breakpoints in `$A000–$BFFF`, which write to ROM (silently discarded), causing the debugger to lose control. Phase 3 must not be implemented against this threshold ahead of the prerequisite update.

### Implementation Gaps Introduced
- **`bp1Active`/`bp2Active` stale-flag risk**: New flags must be cleared before each trace invocation; uninitialized or stale `bp2Active` would write a garbage byte back to `bpAddr2` on restore.
- **`traceMode` not reset in `myBrkHandler`**: A stale `traceMode=1` after `P` causes the next `T` invocation to step over JSR instead of into it.

---

## Angle C — Cross-File Consistency

### Confirmed Contradictions
- **ROM range in UI Behavior section** (`docs/apps/debug.md` ~580) says `$A000–$BFFF` is unsafe ROM. Phase 3 plan says it's safe RAM. Contradictory. Given Angle B, the UI doc is currently more accurate.
- **`C` example output** (~line 221): `1005 60 RTS 2005` — `RTS` appears where the dest hex byte (`$FF` per the comment) should be. The mnemonic `RTS = $60` also contradicts the comment "dest has $FF".
- **T/P wiki vs. docs**: `wiki/debug-utility.md` says T/P are `*Planned (Phase 3)*`. `docs/apps/debug.md` §15 has four complete interactive examples presenting them as working commands. All Phase 3 checklist items are unchecked.

---

## Angles D/E — Cleanup and Conventions

- **B flag description** (~line 483): Says B is "only meaningful when read off the stack." In DEBUG, P is always captured from the BRK frame where bit 4 is forced to 1. The display will always show B=1 regardless of what the user writes with `R P`.
- **JSR/non-JSR ROM-abort split underdocumented** (§4): The plan describes step-over for JSR-to-ROM and abort for branch/JMP-to-ROM but doesn't specify the check must happen per-target inside `decodeTargets`. A single up-front check would misroute all ROM-destination instructions to step-over.

---

## Summary Table

| Severity | File | Finding |
|----------|------|---------|
| **Critical** | `brain/plans/debug-phase3-debugger.md` §4 | `A < $D000` threshold assumes a planned, undocumented BASIC-ROM-bank-out update; plan must disclose this dependency and Phase 3 must not implement ahead of it |
| **High** | `docs/apps/debug.md` ~580 | UI Behavior ROM range contradicts the (incorrect) Phase 3 plan threshold |
| **High** | `docs/apps/debug.md` ~499 | `$F0` P-value table claims Decimal set; bit 3 = 0 in `1111 0000` |
| **High** | `docs/apps/debug.md` ~221 | `C` example shows `RTS` mnemonic where hex dest byte belongs; comment also wrong |
| **Medium** | `docs/apps/debug.md` ~483 | B flag description implies user-settable; DEBUG display always shows B=1 |
| **Medium** | `brain/plans/debug-phase3-debugger.md` §7 | `traceMode` not reset in handler — stale flag causes T to behave as P |
| **Medium** | `wiki/debug-utility.md` ~125,129 | T/P shown as implemented in docs; wiki says Planned; checklist all unchecked |
| **Low** | `brain/plans/debug-phase3-debugger.md` §4 | JSR/non-JSR ROM-target abort distinction ambiguous in `decodeTargets` narrative |
