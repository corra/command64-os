// src/external/dvorak/dvorak.asm
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Command64 project contributors
// C64 port of a classic BASIC "Dvorak matrix" type-in listing.
//
// Original BASIC V2 listing (paraphrased):
//   10 REM --- CLONE AND PATCH MATRIX ROUTINE ---
//   20 FOR I=49152 TO 49190:READ D:POKE I,D:NEXT I     (patch routine -> $C000)
//   30 POKE 56,192:CLR                                 (shrink BASIC's RAM ceiling)
//   50 FOR I=0 TO 127:POKE 49216+I,PEEK(60289+I):NEXT I(backup default table -> $C040)
//   70 FOR I=0 TO 63:READ D:POKE 49216+I,D:NEXT I       (overwrite w/ Dvorak matrix)
//   90 SEI:POKE 808,0:POKE 809,192:CLI                  (repoint vector 808/809 at $C000)
//
// Invocation: DVORAK   (no arguments)
//
// Behaviour: installs a small resident patch + a 128-byte keyboard-table copy at a
// fixed high address, overwrites the first 64 bytes of that copy with the Dvorak
// matrix data, then repoints the $0328/$0329 KERNAL vector (decimal 808/809 in the
// original listing) at the resident routine and returns to the shell. Per the user's
// explicit choice, this mirrors the original's "install and stay resident" behaviour
// rather than restoring on exit — the patch remains active system-wide until the
// machine is reset or another program happens to load over the resident block.
//
// RESIDENCY CAVEAT: this OS's external-app loader treats the entire $2000-$CFFF
// range as free user space (see UserProgStart/UserProgEnd in command64.inc) — there
// is no OS-level mechanism to reserve memory across program loads. The resident
// block below is placed as high as possible (just under UserProgEnd) to minimise
// the chance of a later program overwriting it, but this is the same fragility the
// original BASIC hack had against a machine-code loader (its POKE 56,192 "RAM
// protect" only ever guarded against BASIC's own variable/array growth).
//
// LINE-20 RANGE BUG: the original listing's FOR loop (49152 TO 49190 = 39 bytes)
// does not match the 26 DATA values actually supplied for the patch routine (lines
// 130-150). Read literally, the second READ loop (line 70) would desync against the
// DATA pointer and eventually hit "OUT OF DATA". This port sidesteps the bug
// entirely: the 26 patch-routine bytes and the 64 matrix bytes are placed directly
// via assembler directives rather than replayed through a runtime READ loop, so
// there's no shared DATA pointer to desync in the first place.
//
// DECODE CAVEAT: bytes 22-25 of the patch routine as given ("D0 0A ... 4C 87 EA")
// branch into the *operand bytes* of the trailing JMP $EA87 (i.e. mid-instruction)
// rather than to a clean instruction boundary. That is preserved byte-for-byte below
// (see dvorakRoutine) since this port's job is to transliterate the listing exactly,
// bugs and all — not to silently redesign a hack whose exact intent is unclear from
// the source alone.

#import "../../../include/command64.inc"

.const VERSION_MAJOR = "0"
.const VERSION_MINOR = "1"
.const VERSION_STAGE = "0"
#import "build_dvorak.inc"

.encoding "petscii_mixed"

// ---------------------------------------------------------------------------
// KERNAL vector patched by the original listing (decimal 808/809).
// ---------------------------------------------------------------------------
.const KeyVecLo = $0328
.const KeyVecHi = $0329

// Source of the default keyboard decode table (60289 decimal in the original).
.const KeyTabSrc = $EB81
.const KeyTabLen = 128    // full backup copy (matches line 50's loop bound)
.const MatrixLen = 64     // Dvorak overwrite length (matches line 70's loop bound)

// ---------------------------------------------------------------------------
// Zero-page scratch ($70-$71 — documented safe area for external programs)
// ---------------------------------------------------------------------------
.label zpSrcLo = $70
.label zpSrcHi = $71

// ---------------------------------------------------------------------------
// Resident block: placed high in user space so it survives this program's own
// exit back to the shell. Layout mirrors the original's $C000 (routine) /
// $C040 (table) split, just relocated and packed contiguously.
// ---------------------------------------------------------------------------
.const DvorakResident = $CE00
.label dvorakRoutine  = DvorakResident        // 26 bytes — resident patch code
.label dvorakTable    = DvorakResident + 26   // 128 bytes — backed-up + patched keytab

* = UserProgStart "DvorakEntry"

// ---------------------------------------------------------------------------
// Entry point (installer — runs once, does not stay resident itself)
// ---------------------------------------------------------------------------
start:
    ldx #<verMsg
    ldy #>verMsg
    lda #DOS_PRINT_STR
    jsr $1000

    // -----------------------------------------------------------------------
    // Line 50: back up 128 bytes of the default keyboard table into the
    // resident table area.
    // -----------------------------------------------------------------------
    lda #<KeyTabSrc
    sta zpSrcLo
    lda #>KeyTabSrc
    sta zpSrcHi
    ldx #0
backupLoop:
    ldy #0
    lda (zpSrcLo), y
    sta dvorakTable, x
    inc zpSrcLo
    bne backupNoCarry
    inc zpSrcHi
backupNoCarry:
    inx
    cpx #KeyTabLen
    bne backupLoop

    // -----------------------------------------------------------------------
    // Line 70: overwrite the first 64 bytes of the resident table with the
    // Dvorak matrix data baked into this program.
    // -----------------------------------------------------------------------
    ldx #0
patchLoop:
    lda dvorakMatrixData, x
    sta dvorakTable, x
    inx
    cpx #MatrixLen
    bne patchLoop

    // -----------------------------------------------------------------------
    // Line 20: copy the 26-byte patch routine into its resident home.
    // -----------------------------------------------------------------------
    ldx #0
copyRoutineLoop:
    lda dvorakRoutineSrc, x
    sta dvorakRoutine, x
    inx
    cpx #26
    bne copyRoutineLoop

    // -----------------------------------------------------------------------
    // Line 90: SEI:POKE 808,0:POKE 809,192:CLI — repoint the vector at the
    // resident routine and re-enable interrupts.
    // -----------------------------------------------------------------------
    sei
    lda #<dvorakRoutine
    sta KeyVecLo
    lda #>dvorakRoutine
    sta KeyVecHi
    cli

    ldx #<activeMsg
    ldy #>activeMsg
    lda #DOS_PRINT_STR
    jsr $1000
    rts

// ---------------------------------------------------------------------------
// Data (loaded at $2000, only needed during install — not resident)
// ---------------------------------------------------------------------------

// The 26-byte hardware scan patch (lines 130-150), transliterated byte-for-
// byte. Decoded for reference (see DECODE CAVEAT above for the branch-target
// oddity in the last two instructions):
//   SEI
//   LDA #$40
//   EOR $91,X
//   BNE +$12        ; -> lands mid-instruction, see caveat
//   LDA $DC01
//   AND #$10
//   BNE +$0A        ; -> lands mid-instruction, see caveat
//   LDA $91
//   EOR #$01
//   STA $91
//   JMP $FDEA
//   JMP $EA87
dvorakRoutineSrc:
    .byte $78, $A9, $40, $55, $91, $D0, $12, $AD, $01, $DC, $29
    .byte $10, $D0, $0A, $A5, $91, $49, $01, $85, $91, $4C, $EA
    .byte $FD, $4C, $87, $EA

// Custom Dvorak matrix data (lines 170-240), 8 rows of 8 bytes each.
dvorakMatrixData:
    .byte 20, 13, 157, 140, 137, 138, 139, 145   // row 0 (INST/RET/CRSR/F-keys)
    .byte 51, 46, 65, 52, 90, 83, 69, 1           // row 1
    .byte 53, 82, 68, 54, 67, 70, 84, 88          // row 2
    .byte 55, 89, 71, 56, 66, 72, 85, 86          // row 3
    .byte 57, 73, 74, 48, 77, 75, 79, 78          // row 4
    .byte 43, 80, 76, 45, 46, 58, 64, 44          // row 5
    .byte 156, 42, 59, 19, 2, 61, 94, 47          // row 6
    .byte 49, 95, 3, 32, 143, 81, 131, 132        // row 7

verMsg:
    .text "DVORAK v" + VERSION_MAJOR + "." + VERSION_MINOR + "." + VERSION_STAGE
    .text "." + BUILD_NUMBER
    .byte $0D, $00

activeMsg:
    .text "DVORAK MATRIX MANIPULATION ACTIVE!"
    .byte $0D, $00

// ---------------------------------------------------------------------------
// Resident block — survives past this program's own exit (see RESIDENCY
// CAVEAT above). Reserved here purely to keep the assembler's address map
// honest; actual bytes are written by the installer above at runtime.
// ---------------------------------------------------------------------------
* = DvorakResident "DvorakResident"
    .fill 26 + KeyTabLen, 0
