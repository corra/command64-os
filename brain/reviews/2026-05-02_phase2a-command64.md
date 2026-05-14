---
feature: phase2a-command64
reviewed: 2026-05-02
status: remediation-pending
---

# Code Review: Phase 2A — command64 Core Dispatcher

## Scope

Files reviewed against Kick Assembler v5.25 syntax, 6502/6510 architecture constraints,
and the Phase 2A plan at `brain/plans/command64_phase2a.md`.

| File | Role |
|------|------|
| `include/command64.inc` | KERNAL addresses, buffer constants |
| `src/command64/petsci.asm` | PETSCII print layer |
| `src/command64/shell.asm` | Command loop + dispatcher |
| `src/command8/petsci.asm` | Alternate/abandoned PETSCII stub |
| `build/command64.asm` | Kick Assembler root build file |

## Findings Scorecard

| ID | File | Severity | Issue | Score |
|----|------|----------|-------|-------|
| C1 | `include/command64.inc:3` | Critical | `KernalCLALL = $E548` — wrong; should be `$FFE7` (KERNAL jump table) | 100 |
| C2 | `include/command64.inc:2` | Critical | `KernalChRIN = $FFE4` — this is GETIN, not CHRIN; CHRIN is `$FFCF` | 100 |
| C3 | `src/command64/petsci.asm:22–28` | Critical | `petPrintString` never dereferences the pointer; uses absolute-X instead of `(zp),y` indirect; string data is never read | 100 |
| C4 | `src/command64/petsci.asm` | Critical | `printPtrLo`/`printPtrHi` declared in `Petsci` segment (~$1000); indirect addressing `(zp),y` requires zero-page location ($00–$FF) | 100 |
| C5 | `src/command64/petsci.asm:31` | Critical | `jsr petPrintChar` — macros are inlined, not callable via JSR; no subroutine exists at that label | 100 |
| C6 | `src/command64/shell.asm:47–49` | Critical | Null terminator written as `$0D` (PetCr) not `$00`; all downstream consumers will overrun the buffer | 100 |
| C7 | `src/command64/shell.asm:55` | Critical | `ldx #tableCmd` — `ldx` is 8-bit; 16-bit address truncated to low byte ($00); table walk starts at wrong offset | 100 |
| C8 | `src/command64/shell.asm:8–13` | Critical | Command table uses variable-length name strings with a fixed-3-byte stride (`inx/inx/inx`); entries are 6, 5, and 6 bytes — walker misaligns immediately after first entry | 100 |
| C9 | `src/command64/shell.asm:71–76` | Critical | `pla/pha/pla` corrupts the stack; `jmp (CommandBuffer)` jumps into raw user input instead of the resolved handler address | 100 |
| C10 | `src/command64/shell.asm:97–102` | Critical | `rts` inside `.macro cmdCompare` returns from the outer caller's subroutine context, not from `cmdCompare`; must be a `.proc` | 100 |
| C11 | `src/command64/shell.asm:44–48` | Major | Off-by-one: at Y=79 a char is stored, Y incremented to 80, `bne` falls through; null written at `CommandBuffer+80`, one past the 80-byte boundary | 90 |
| C12 | `src/command64/shell.asm:114` | Major | `cmdEcho` skips first 5 bytes (hardcoded); wrong if multiple spaces precede argument or command is shorter/longer | 85 |
| C13 | `src/command8/petsci.asm:10–16` | Critical | `petPrintChar` reads from ZP $FF via broken indexed-indirect; CHROUT never called; entire macro non-functional | 100 |
| C14 | `src/command8/petsci.asm:20–29` | Critical | `petPrintString` uses assembler `.var y` as runtime loop index; assembles to `lda ptr+0` (fixed); loop reads same byte forever | 100 |

## Overall Assessment

**None of the source files will assemble into working code in their current state.**
The two highest-risk areas are the completely broken dispatch mechanism in `shell.asm`
(C7–C10) and the pointer dereference failure in `petPrintString` (C3–C4).
`src/command8/petsci.asm` appears to be an abandoned stub and should be removed.

## Remediation Status — COMPLETE (2026-05-02)

See `brain/plans/2026-05-02_phase2a-command64-code-review-remediation.md`.

- [x] C1 — Fixed `KernalCLALL`: `$E548` → `$FFE7`
- [x] C2 — Fixed `KernalChRIN`: `$FFE4` (GETIN) → `$FFCF` (CHRIN)
- [x] C3/C4 — Rewrote `petPrintString` with ZP equates `$FB/$FC` and `lda (PrintPtrLo),y`
- [x] C5 — All `jsr <macro>` calls replaced with bare inline invocations + `()` syntax
- [x] C6 — Fixed null terminator: `lda #0 / sta CommandBuffer,y`
- [x] C7/C8 — Command table rewritten as 8-byte fixed-width entries; walk uses `adc #TABLE_ENTRY_SIZE`
- [x] C9 — `shellDispatch` rewritten: handler addr copied to ZP vector `HandlerVecLo/Hi`, `jmp (HandlerVecLo)`
- [x] C10 — `cmdCompare` converted from `.macro` to real subroutine with `rts`
- [x] C11 — Fixed off-by-one: `cpy #79` (was `#80`); null at index 79 max
- [x] C12 — `cmdEcho` uses `ParsePos` (set by `cmdCompare`) instead of hardcoded offset
- [x] C13/C14 — Deleted `src/command8/petsci.asm` and empty `src/command8/` directory
- [x] Bonus — Added bare `name = value` → `.label` fix (KA syntax requirement discovered during build)
- [x] Bonus — Added PETSCII lowercase mode init (`lda #$0E`) at startup and in `cmdCls`

**Round 2 — Real Hardware Bugs (2026-05-02):**
- [x] R1 — cmdCompare X-register bug: X walked with Y during comparison; on match X landed at `entry_base + chars_matched` not `entry_base + TABLE_NAME_LEN`; every dispatch jumped to wrong address. Fixed by redesigning cmdCompare to preserve X as immutable entry base (`stx CmpBase`); table bytes read as `tableCmd[CmpBase + Y]`; X set to `CmpBase + TABLE_NAME_LEN` on all match paths.
- [x] R2 — cmdCompare X corrupted on partial mismatch: `inx` during compare left X mid-entry on failure; next entry walk computed wrong base. Fixed by `ldx CmpBase` in ccCmpFail.
- [x] R3 — shellReadLine double echo: CHRIN (C64 screen editor) already echoes to screen; manual CHROUT printed each char again at the wrong cursor position. Fixed by removing the echo CHROUT from shellReadLine.
- [x] R4 — Spurious newline: `lda #PetCr : jsr KernalChROUT` in mainLoop after shellReadLine was redundant (screen editor moves cursor on RETURN). Removed.

**Final build result:** `build/command64.prg` — 0 errors, 0 warnings. All three dispatch paths verified by hand-trace.
