// src/command64/utils.asm
// KickAssembler v5.25 - MS-DOS 4.0 to C64 Port Utility Routines
// Hex string to 16-bit integer conversion.

.segment Utils [start=$0C00]

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
    
    // 1. Convert lowercase $61-$7A to $41-$5A
    cmp #$61
    bcc nnShifted
    cmp #$7B
    bcs nnShifted
    sec
    sbc #$20
    sta (PrintPtrLo), y
    jmp nnNext

nnShifted:
    // 2. Convert shifted $C1-$DB to $41-$5A
    cmp #$C1                // Shifted 'A'
    bcc nnNext
    cmp #$DB                // Shifted 'Z' + 1
    bcs nnNext
    // Is shifted A-Z. Convert to unshifted (Uppercase in standard mode)
    and #$7F
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
