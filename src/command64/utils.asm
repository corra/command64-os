// src/command64/utils.asm
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Command64 project contributors
// KickAssembler v5.25 - MS-DOS 4.0 to C64 Port Utility Routines
// Hex string to 16-bit integer conversion.

.segment Utils

// --- parseHex ---
// Parses a hex string in CommandBuffer starting at Y.
// Result stored in HexValLo ($66) and HexValHi ($67).
// Input:  Y = starting index in CommandBuffer
// Output: C=0 on success, C=1 on invalid char or overflow.
//         HexValLo/Hi updated.
// Clobbers: A, X, Y
parseHex:
    lda #0
    sta HexValLo
    sta HexValHi
phLoop:
    lda CommandBuffer, y
    beq phDone
    cmp #' '
    beq phDone
    
    jsr hexDigitToVal
    bcs phError             // Invalid hex digit
    
    // Shift HexValLo/Hi left 4 bits: (HexValHi:HexValLo) << 4
    // We only support up to 4 digits (16-bit)
    pha                     // Save nibble value
    ldx #4
phShift:
    asl HexValLo
    rol HexValHi
    dex
    bne phShift
    
    pla                     // Restore nibble value
    ora HexValLo            // HexValLo was cleared by shift? No, ASL clears bit 0.
    sta HexValLo
    
    iny
    jmp phLoop
phDone:
    clc
    rts
phError:
    sec
    rts

// --- hexDigitToVal ---
// Convert PETSCII hex char in A to value 0-15 in A.
// Handles '0'-'9' and 'a'-'f' (lowercase PETSCII $41-$46).
// Output: A = value 0-15. C=0 on success, C=1 on failure.
hexDigitToVal:
    cmp #'0'
    bcc hdvError
    cmp #':'                // '9' + 1
    bcc hdvNum
    
    // Check for a-f (petscii_mixed unshifted)
    cmp #'a'
    bcc hdvError
    cmp #'g'                // 'f' + 1
    bcs hdvError
    sec
    sbc #('a'-10)           // 'a'-10 = $41 - 10 = $37
    clc
    rts
hdvNum:
    sec
    sbc #'0'
    clc
    rts
hdvError:
    sec
    rts

// --- normalizeName ---
// Converts a string to lowercase PETSCII ($41-$5A).
// Input:  A = low byte of string pointer
//         Y = high byte of string pointer
//         X = string length
// Output: Y = string length (loop exits when Y == TempLo == input X)
//         X = preserved (unchanged — callers rely on this after the call)
// Clobbers: A, TempLo, PrintPtrLo/Hi
normalizeName:
    sta PrintPtrLo
    sty PrintPtrHi
    stx TempLo
    ldy #0
nnLoop:
    cpy TempLo
    beq nnDone
    lda (PrintPtrLo), y
    
    // 1. Convert shifted characters (A-Z) to unshifted
    // In petscii_mixed, unshifted is lowercase, shifted is uppercase.
    // Disk entries are unshifted. So we normalize everything to unshifted.
    cmp #$C1                // PETSCII Shifted 'A'
    bcc nnNext
    cmp #$DB                // PETSCII Shifted 'Z' + 1
    bcs nnNext
    and #$7F                // Convert shifted to unshifted
    sta (PrintPtrLo), y
nnNext:
    iny
    jmp nnLoop
nnDone:
    rts

// --- printDecimal16 ---
// Prints a 16-bit value in decimal to standard output.
// Input:  X = Low byte, Y = High byte
// Clobbers: A, X, Y, HexValLo/Hi (used as temporary)
printDecimal16:
    stx HexValLo
    sty HexValHi
    
    lda #0
    sta TempHi              // Initialize leading-zero suppression flag
    
    // Check for zero
    lda HexValLo
    ora HexValHi
    bne pdStart
    lda #'0'
    jsr KernalChROUT
    rts

pdStart:
    // We use a simple subtraction loop for powers of 10
    // 10000, 1000, 100, 10, 1
    
    // 10000s
    ldx #0
pd10000:
    lda HexValLo
    sec
    sbc #<10000
    tay
    lda HexValHi
    sbc #>10000
    bcc pdDone10000
    sta HexValHi
    sty HexValLo
    inx
    jmp pd10000
pdDone10000:
    jsr pdPrintDigit
    
    // 1000s
    ldx #0
pd1000:
    lda HexValLo
    sec
    sbc #<1000
    tay
    lda HexValHi
    sbc #>1000
    bcc pdDone1000
    sta HexValHi
    sty HexValLo
    inx
    jmp pd1000
pdDone1000:
    jsr pdPrintDigit

    // 100s
    ldx #0
pd100:
    lda HexValLo
    sec
    sbc #100
    tay
    lda HexValHi
    sbc #0
    bcc pdDone100
    sta HexValHi
    sty HexValLo
    inx
    jmp pd100
pdDone100:
    jsr pdPrintDigit

    // 10s
    ldx #0
pd10:
    lda HexValLo
    sec
    sbc #10
    tay
    lda HexValHi
    sbc #0
    bcc pdDone10
    sta HexValHi
    sty HexValLo
    inx
    jmp pd10
pdDone10:
    jsr pdPrintDigit

    // 1s
    lda HexValLo
    clc
    adc #'0'
    jsr KernalChROUT
    rts

// Helper to print digit in X and suppress leading zeros
pdPrintDigit:
    txa
    beq pdZero
    clc
    adc #'0'
    jsr KernalChROUT
    lda #1                  // Mark that we've printed a non-zero
    sta TempHi
    rts
pdZero:
    lda TempHi              // Have we printed a non-zero yet?
    beq pdNoPrint
    lda #'0'
    jsr KernalChROUT
pdNoPrint:
    rts

// --- parsePointerDevice ---
// Parses a device prefix (8:, 9:, 10:, 11:) from the filename pointer stored
// at ZP offset X.
// Input:  X = ZP offset of the pointer (e.g. $FD for NamePtrLo)
// Output: A = resolved device number (8-11, or CurrentDevice if not found)
//         Carry: 1 = prefix found (pointer advanced), 0 = no prefix (pointer unchanged)
// Clobbers: A, Y, TempLo, TempHi
parsePointerDevice:
    // Copy the pointer at ZP offset X to TempLo/Hi
    lda $00, x
    sta TempLo
    lda $01, x
    sta TempHi
    
    ldy #0
    lda (TempLo), y
    cmp #'8'
    beq ppdCheck8
    cmp #'9'
    beq ppdCheck9
    cmp #'1'
    beq ppdCheck10or11
    
ppdNoMatch:
    lda CurrentDevice
    clc                     // Carry=0: no prefix
    rts

ppdCheck8:
    iny
    lda (TempLo), y
    cmp #':'
    beq ppdFound8
    jmp ppdNoMatch

ppdFound8:
    // Advance pointer in ZP by 2 bytes (skip '8:')
    lda $00, x
    clc
    adc #2
    sta $00, x
    lda $01, x
    adc #0
    sta $01, x
    lda #8
    sec                     // Carry=1: prefix found
    rts

ppdCheck9:
    iny
    lda (TempLo), y
    cmp #':'
    beq ppdFound9
    jmp ppdNoMatch

ppdFound9:
    // Advance pointer in ZP by 2 bytes (skip '9:')
    lda $00, x
    clc
    adc #2
    sta $00, x
    lda $01, x
    adc #0
    sta $01, x
    lda #9
    sec                     // Carry=1: prefix found
    rts

ppdCheck10or11:
    iny
    lda (TempLo), y
    cmp #'0'
    beq ppdCheck10
    cmp #'1'
    beq ppdCheck11
    jmp ppdNoMatch

ppdCheck10:
    iny
    lda (TempLo), y
    cmp #':'
    beq ppdFound10
    jmp ppdNoMatch

ppdFound10:
    // Advance pointer in ZP by 3 bytes (skip '10:')
    lda $00, x
    clc
    adc #3
    sta $00, x
    lda $01, x
    adc #0
    sta $01, x
    lda #10
    sec                     // Carry=1: prefix found
    rts

ppdCheck11:
    iny
    lda (TempLo), y
    cmp #':'
    beq ppdFound11
    jmp ppdNoMatch

ppdFound11:
    // Advance pointer in ZP by 3 bytes (skip '11:')
    lda $00, x
    clc
    adc #3
    sta $00, x
    lda $01, x
    adc #0
    sta $01, x
    lda #11
    sec                     // Carry=1: prefix found
    rts

