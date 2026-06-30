# Raw Multi-Agent Findings: DEBUG Documentation Expansion Review

**Date**: 2026-06-30
**Method**: 8 independent finder angles (A–H) via parallel sub-agents, 1-vote verify phase
**Effort**: Medium (3+5 angles × 6 candidates → 1-vote verify → ≤8 findings)
**Peer review**: `brain/reviews/2026-06-30_debug-doc-review.md`
**Analysis summary**: `brain/analysis/claude_debug_doc_review.md`

---

## Phase 0 — Diff Scope

Changes reviewed (working-tree, uncommitted):

| File | Nature of Change |
|------|-----------------|
| `docs/apps/debug.md` | Major expansion: full command reference, P-register table, error messages, MS-DOS parity notes, exhaustive examples |
| `wiki/debug-utility.md` | Parity table updated to Phase 1/2 complete; deviations from MS-DOS documented |
| `brain/plans/debug-phase3-debugger.md` | Plan rewritten: virtual PC, RTI frame, CBINV hijacking, `myBrkHandler` detail, ROM safety updated |
| `CHANGELOG.md` | Conway + DEBUG Phase 2 entries added |
| `CMakeLists.txt` | Conway app added |
| `.gitignore` | `node_modules/` added |

Source code: zero lines changed.

---

## Phase 1 — Finder Agent Raw Output

### Angle A — Line-by-Line Diff Scan

**Claim 1: P register bit table** — `docs/apps/debug.md`, new Processor Status Register section.
- Layout 7=N, 6=V, 5=unused/always-1, 4=B, 3=D, 2=I, 1=Z, 0=C: **CORRECT** per MOS 6502 datasheet.
- "Bit 5 is always read as 1. Writing 0 has no effect." **CORRECT** — the unused bit is hardwired.
- Power-on default `$30 = 0011 0000`: **CORRECT** — bits 5 (unused) and 4 (B) set, all others 0.
- B flag: "Only meaningful when read off the stack after an interrupt." **APPROXIMATELY CORRECT** but misleading in DEBUG context — see Angle D.

**Claim 2: $F0 row in Common P Values table** — `docs/apps/debug.md`.
- `$F0 = 1111 0000`. Bits: 7=1(N), 6=1(V), 5=1(unused), 4=1(B), 3=0(D), 2=0(I), 1=0(Z), 0=0(C).
- Table description: "Negative, Overflow, B, Decimal all set."
- Bit 3 (D = Decimal) = **0**. Decimal is **NOT** set.
- **CANDIDATE**: Factual error. Severity: High.

**Claim 3: RTI stack frame layout** — `brain/plans/debug-phase3-debugger.md` §6.
- Plan: `$0100+regS` = PCH, `$0100+regS-1` = PCL, `$0100+regS-2` = P.
- Launcher sets SP to `regS-3` then RTI.
- RTI reads: P from `$0101+(regS-3)` = `$0100+regS-2` ✓, PCL from `$0102+(regS-3)` = `$0100+regS-1` ✓, PCH from `$0103+(regS-3)` = `$0100+regS` ✓.
- **CONFIRMED CORRECT**.

**Claim 4: `myBrkHandler` register extraction offsets** — `brain/plans/debug-phase3-debugger.md` §7.
- KERNAL IRQ handler pushes Y, X, A (in that order). CPU pushes PCH, PCL, P.
- After `tsx`, stack layout from `$0101,x`: Y, X, A, P, PCL, PCH.
- Plan says: `$0101,x`=regY, `$0102,x`=regX, `$0103,x`=regA, `$0104,x`=regP, `$0105,x`=PCL, `$0106,x`=PCH. **CONFIRMED CORRECT**.
- `regS = X + 6` (3 CPU pushes + 3 KERNAL pushes). **CONFIRMED CORRECT**.

**Claim 5: PC recovery math** (`$0105,x minus 2`).
- BRK pushes PC+2 (address after the BRK + its mandatory padding byte). Subtracting 2 recovers the BRK address. **CONFIRMED CORRECT**.
- Note: This assumes the BRK is assembled with a following padding byte (standard practice). If a single-byte `$00` is written without padding, BRK pushes PC+1 and the −2 correction places `regPC` one byte before the BRK. Low risk in practice since the assembler always emits the padding.

**Claim 6: 1541 disk error codes** — `docs/apps/debug.md` error table.
- Error 62 = FILE NOT FOUND, Error 63 = FILE EXISTS. **CONFIRMED CORRECT** per CBM DOS spec.

---

### Angle B — Removed Behavior Audit

**Removed invariant: Safe-address check `A < $A000`** (old plan) → replaced with `A < $D000` (new plan).

New plan justification: *"BASIC ROM ($A000–$BFFF) is banked out on startup (exposing the underlying RAM) and restored only upon system EXIT."*

Verification — grep for `STA $01` across all source:
```
$ grep -rn "STA \$01\b" src/
(no output)
```
Result: **Zero matches**. No `STA $01` instruction exists anywhere in the codebase.

On a stock C64, the CPU I/O port `$01` resets to `$37` = `0011 0111`:
- Bit 0 (LORAM): 1 → BASIC ROM at `$A000–$BFFF` mapped **in**
- Bit 1 (HIRAM): 1 → KERNAL ROM at `$E000–$FFFF` mapped **in**
- Bit 2 (CHAREN): 1 → I/O at `$D000–$DFFF` mapped **in** (Character ROM mapped out)

BASIC ROM is live at startup **in the current codebase**. The premise, as a claim about present-day behavior, is false. **CANDIDATE: Critical.**

Additional context: `cmdExit` in `shell.asm` jumps to `$E37B` (KERNAL warm start). If BASIC were actually banked out today, `EXIT` would crash. The codebase implicitly assumes BASIC is always present, as of now.

**Author clarification (2026-06-30, post-review)**: This is intentional — the plan's `A < $D000` threshold is written against a *planned* CPU I/O port `$01` bank-switching update (to bank out BASIC ROM at startup) that has not yet been implemented or documented anywhere else in the project. The finding is reclassified from "false premise / factual error" to "undocumented forward dependency": the threshold itself is not necessarily wrong for the system's intended future state, but the plan currently presents it as already-true present-tense fact with no pointer to the prerequisite work. Implementing Phase 3 against `A < $D000` before that bank-switching update lands would reproduce the exact failure scenario below.

**Removed flag behavior: unconditional restore** (old plan) → conditional on `bp1Active`/`bp2Active` (new plan).

Old plan: restore always writes `bpByte1`/`2` back unconditionally. New plan: restore only if active flag is set. Risk: if `bp2Active` is uninitialized or stale from a prior aborted trace, the restore writes a garbage byte to `bpAddr2`. **CANDIDATE: Medium.**

**New variable `traceMode` has no specified reset in handler return path.**

Old plan had no `traceMode` flag — mode was implicit in calling command. New plan's §7 handler does not reset `traceMode` before jumping to `mainLoop`. Stale `traceMode=1` after `P` causes next `T` to step over JSR instead of into it. **CANDIDATE: Medium.**

---

### Angle C — Cross-File Consistency

**Contradiction 1: ROM range in UI Behavior section vs. Phase 3 plan.**

`docs/apps/debug.md` (~line 580):
> "The `T` and `P` commands cannot set breakpoints in ROM (`$A000-$BFFF`, `$D000-$FFFF`)."

`brain/plans/debug-phase3-debugger.md` §4:
> "BASIC ROM (`$A000-$BFFF`) is banked out on startup... safe if `A < $D000`"

Directly contradictory. The UI doc lists `$A000–$BFFF` as unsafe ROM; the plan treats it as safe RAM. Given Angle B, the UI doc is more accurate. **CANDIDATE: Medium** (dependent on Finding B1 resolution).

**Contradiction 2: `C` command example output.**

`docs/apps/debug.md` (~line 221):
```
1005 60 RTS 2005  ; Mismatch at offset $05: source has $60, dest has $FF
```

Format is `[src_addr] [src_byte] [dest_byte] [dest_addr]`. Three inconsistencies:
1. Dest byte shows `RTS` (mnemonic) instead of a hex value.
2. `RTS` = `$60` (same as source), contradicting the premise of a mismatch.
3. Comment says dest has `$FF`, which matches neither `RTS` nor `$60`.

Correct line: `1005 60 FF 2005  ; source has $60, dest has $FF`. **CANDIDATE: High.**

**Contradiction 3: T/P status in wiki vs. docs.**

`wiki/debug-utility.md` marks T and P as `*Planned (Phase 3)*`. `docs/apps/debug.md` §15 presents four complete interactive T/P examples with register output. All Phase 3 checklist items in the plan are unchecked (`- [ ]`). **CANDIDATE: Medium.**

---

### Angle D — Cleanup / Conventions

**B flag description subtly misleading.**

`docs/apps/debug.md` B flag row: *"Only meaningful when read off the stack after an interrupt."*

In DEBUG's specific context: `P` is always captured from the BRK interrupt frame, where the 6502 forces bit 4 = 1. The B flag will always appear set in the `R` display. A user who attempts to clear B with `R P` will see it return to 1 on the next `T`/`P` cycle. The current description doesn't warn of this behavior. **CANDIDATE: Medium.**

**JSR/non-JSR ROM-target split underdocumented.**

`brain/plans/debug-phase3-debugger.md` §4 describes two distinct outcomes for ROM targets (step-over for JSR, abort for branch/JMP) but does not state the check must occur per-computed-target inside `decodeTargets`. An implementor applying a single up-front check would misroute all ROM-target instructions to step-over. **CANDIDATE: Low.**

---

### Angles E/F/G/H — Reuse, Efficiency, Altitude, CLAUDE.md

No candidates in reuse, efficiency, or altitude angles — the diff is documentation-only.

CLAUDE.md conventions:
- "Documentation-Driven: Updates to spec must precede or accompany implementation." — satisfied; T/P are documented as spec-ahead, not as shipped code.
- "Code must be heavily annotated to explain logic." — applies to source code only; not applicable here.

No CLAUDE.md violations found.

---

## Phase 2 — Verification

| Candidate | Agent Vote | Evidence |
|-----------|------------|---------|
| A6: `$F0` Decimal flag | **CONFIRMED** | `$F0 = 1111 0000`; bit 3 = 0. Mathematical proof. Confirmed by 3 independent angles. |
| B1: BASIC ROM not banked out (currently) | **CONFIRMED, reclassified** | `grep -rn "STA \$01\b" src/` → 0 results. `$01` defaults to `$37` at reset. Author confirmed (2026-06-30) this anticipates a planned, undocumented bank-switching update — finding reclassified from "false premise" to "undocumented forward dependency"; plan must disclose the prerequisite rather than presenting it as already-true. |
| C1: UI Behavior ROM range contradiction | **CONFIRMED** | File read confirmed line 580 text. Contradicts plan §4 directly. |
| C2: `C` example mnemonic vs. hex | **CONFIRMED** | File read confirmed line 221: `RTS` where `FF` belongs; comment says `$FF`. |
| D1: B flag always-set in DEBUG display | **PLAUSIBLE** | Mechanism confirmed (BRK frame forces bit 4=1). User confusion risk is real. |
| B3: `traceMode` no reset path | **PLAUSIBLE** | Handler §7 has no reset step. Risk is real if dispatcher doesn't set flag before each call. |
| C3: T/P wiki vs. docs inconsistency | **CONFIRMED** | Both files read. Wiki: `Planned`. Docs: full examples. Checklist: all unchecked. |
| D2: JSR/non-JSR abort underdocumented | **PLAUSIBLE** | Ambiguity is real; implementor could misread. Narrow risk. |

---

## Final Ranked Findings

```json
[
  {
    "file": "brain/plans/debug-phase3-debugger.md",
    "line": 99,
    "summary": "Safe-address threshold A<$D000 assumes a planned, not-yet-implemented/undocumented BASIC-ROM bank-switching update; the plan does not disclose this dependency",
    "failure_scenario": "No STA $01 exists in source today. $01 defaults to $37 at reset; BASIC ROM mapped at $A000-$BFFF. If Phase 3 is implemented against A<$D000 before the bank-switching update lands, a breakpoint write at $A000 lands in ROM, is discarded, and the debugger RTIs into live BASIC — hang or crash. Author confirmed (2026-06-30) the threshold anticipates future work; remediation is to document the prerequisite, not revert the value."
  },
  {
    "file": "docs/apps/debug.md",
    "line": 580,
    "summary": "UI Behavior ROM safeguard lists $A000-$BFFF as unsafe, contradicting the (incorrect) Phase 3 plan threshold",
    "failure_scenario": "One doc says T/P will error on $A000; the other says it will succeed. Correct behavior is undefined for implementors until the ROM safety question is settled."
  },
  {
    "file": "docs/apps/debug.md",
    "line": 499,
    "summary": "$F0 P-register row incorrectly claims the Decimal flag is set",
    "failure_scenario": "User sets P=$F0 expecting BCD arithmetic; BCD does not activate (D bit = 0). ADC/SBC operate in binary with no diagnostic signal."
  },
  {
    "file": "docs/apps/debug.md",
    "line": 221,
    "summary": "C command example substitutes mnemonic RTS for the hex dest byte; comment also disagrees",
    "failure_scenario": "Correct line is '1005 60 FF 2005'. As written, format column shows RTS (=$60, same as source), contradicting both the mismatch premise and the comment saying dest=$FF."
  },
  {
    "file": "docs/apps/debug.md",
    "line": 483,
    "summary": "B flag described as user-settable; DEBUG display always shows B=1 due to BRK frame capture",
    "failure_scenario": "User sets R P with B=0; B returns to 1 on next T/P cycle. No warning in documentation."
  },
  {
    "file": "brain/plans/debug-phase3-debugger.md",
    "line": 54,
    "summary": "traceMode variable has no specified reset in myBrkHandler, risking stale-flag T-behaves-as-P",
    "failure_scenario": "P run sets traceMode=1. Handler returns to prompt. User types T. If cmdTrace does not write traceMode=0 before decodeTargets, T steps over JSR instead of into it."
  },
  {
    "file": "wiki/debug-utility.md",
    "line": 125,
    "summary": "T and P listed as Planned in wiki while docs present full worked examples as if implemented",
    "failure_scenario": "User reading wiki thinks T/P unavailable; user reading docs thinks they are available. Typing -T gives syntax error, contradicting the examples."
  },
  {
    "file": "brain/plans/debug-phase3-debugger.md",
    "line": 106,
    "summary": "JSR-to-ROM step-over vs JMP/branch-to-ROM abort distinction is underdocumented in decodeTargets",
    "failure_scenario": "Implementor applies single up-front ROM check at command level rather than per-target inside decodeTargets, causing branch/JMP-to-ROM to silently step over instead of abort."
  }
]
```
