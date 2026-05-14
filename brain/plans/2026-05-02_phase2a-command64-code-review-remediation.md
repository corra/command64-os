---
feature: phase2a-command64-code-review-remediation
created: 2026-05-02
status: completed
---

# Plan: Phase 2A Code Review Remediation

## Goal & Rationale

Fix all Critical and Major findings from the 2026-05-02 code review
(`brain/reviews/2026-05-02_phase2a-command64.md`) so that the Phase 2A source
files assemble without errors and produce correct runtime behavior on C64 hardware.

## Scope

**Included:**
- All 14 findings from the code review (11 Critical, 3 Major)
- Deletion of the abandoned `src/command8/petsci.asm`

**Out of Scope:**
- VMM API specification (Phase 2B concern)
- External command support
- Any feature not already planned in `brain/plans/command64_phase2a.md`

## Files to Create/Modify

| File | Action | Notes |
|------|--------|-------|
| `include/command64.inc` | Modify | Fix `KernalCLALL` ($E548→$FFE7) and `KernalChRIN` ($FFE4→$FFCF); add zero-page pointer equates |
| `src/command64/petsci.asm` | Modify | Rewrite `petPrintString` with `(zp),y` indirect; move `printPtrLo`/`printPtrHi` to zero page; fix all `jsr <macro>` → bare invocations |
| `src/command64/shell.asm` | Modify | Fix null terminator; rewrite command table (fixed-width entries); rewrite dispatch; convert `cmdCompare` to `.proc`; fix buffer off-by-one; fix echo offset |
| `src/command8/petsci.asm` | Delete | Abandoned stub — both macros are non-functional |

## Key Design Decisions

### Zero-page pointer allocation for `petPrintString`
`printPtrLo`/`printPtrHi` must live in zero page for `lda (zp),y` to work.
Allocate at `$FB`/`$FC` (two bytes in the standard C64 user zero-page area `$FB–$FE`).
Add equates to `include/command64.inc`:
```
PrintPtrLo = $FB
PrintPtrHi = $FC
```

### Fixed-width command table format
Each entry = 8 bytes: 6-byte null-padded name + 2-byte handler address.
This gives a clean fixed stride and allows simple indexed access.
```
tableCmd:
   .text "EXIT  "    ; 6 bytes, space-padded
   .word cmdExit     ; 2 bytes handler
   .text "CLS   "
   .word cmdCls
   .text "ECHO  "
   .word cmdEcho
tableEnd:
```
Table stride = 8. Command name comparison checks up to first space or null.

### `cmdCompare` as `.proc`
Convert from `.macro` to a real labeled subroutine so `rts` returns correctly.
Signature: X = offset into table for current entry; sets Z flag on match.

### Handler dispatch via zero-page vector
After a match, copy the 2-byte handler address from the table into a zero-page
vector (`HandlerVecLo`/`HandlerVecHi`) and `jmp (HandlerVecLo)`.
Add equates: `HandlerVecLo = $FD`, `HandlerVecHi = $FE`.

### Macro invocation discipline
Kick Assembler macros are inlined. Call convention throughout:
- Bare name to inline: `petPrintChar`, `shellReadLine`, etc.
- `jsr label` only for real `.proc` subroutines.

### `shellReadLine` null terminator and buffer bound
```asm
readLoop:
    jsr KernalChRIN
    cmp #PetCr
    beq doneRead
    sta CommandBuffer, y
    jsr petPrintChar
    iny
    cpy #79          ; leave room for null at index 79
    bne readLoop
doneRead:
    lda #0
    sta CommandBuffer, y
    sty CommandLen
```

### `cmdEcho` dynamic offset
After dispatch, X holds the offset past the matched command name in the table.
Use `CommandLen` minus remaining bytes, or track the parse position during
`cmdCompare` and store it in a zero-page variable `ParsePos`.

## Remediation Order

Fix in this sequence to minimize rework:

1. `include/command64.inc` — KERNAL addresses + zero-page equates (unblocks everything else)
2. `src/command64/petsci.asm` — correct `petPrintString`; fix macro calls
3. `src/command64/shell.asm` — in order:
   a. Fix null terminator + buffer bound (`shellReadLine`)
   b. Rewrite command table to fixed-width
   c. Convert `cmdCompare` to `.proc`
   d. Rewrite `shellDispatch` table walk + handler jump
   e. Fix `cmdEcho` offset
4. Delete `src/command8/petsci.asm`
5. Attempt `build/command64.asm` with Kick Assembler; resolve any assembly errors

## Verification Plan

- **Assembly:** `java -jar tools/KickAss.jar build/command64.asm` — must produce `command64.prg` with zero errors
- **Emulator:** Load `command64.prg` in VICE C64 emulator and verify:
  1. Prompt `C64:>` appears on screen
  2. Typing `CLS` + RETURN clears the screen and re-displays the prompt
  3. `ECHO Hello World` prints `Hello World`
  4. `EXIT` returns to BASIC
  5. An unknown command prints `Bad command or file name`
- **Edge cases:** Input of exactly 79 characters does not overflow; empty input loops cleanly

## Progress

- [x] Step 1: Fix `include/command64.inc` — also discovered bare `name = value` is invalid KA syntax; all equates converted to `.label`
- [x] Step 2: Rewrite `src/command64/petsci.asm` — also fixed macro definition requires `()` syntax in KA
- [x] Step 3a: Fix `shellReadLine` — null terminator and off-by-one both fixed
- [x] Step 3b: Rewrite command table (8-byte fixed-width: 6-char name + 2-byte word)
- [x] Step 3c: Convert `cmdCompare` to real subroutine
- [x] Step 3d: Rewrite `shellDispatch` (ZP handler vector, `jmp (HandlerVecLo)`)
- [x] Step 3e: Fix `cmdEcho` offset (uses `ParsePos` set by `cmdCompare`)
- [x] Step 4: Delete `src/command8/petsci.asm`
- [x] Step 5: `java -jar tools/KickAss.jar build/command64.asm` → `command64.prg` (2.8KB, 0 errors, 0 warnings)
- [ ] VICE emulator verification (pending — requires VICE installation)
