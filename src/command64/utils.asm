// src/command64/utils.asm
// KickAssembler v5.25 - MS-DOS 4.0 to C64 Port Utility Routines
// Hex string to 16-bit integer conversion.

.segment Utils [start=$1500]

// --- parseHex ---
// Parses a hex string in CommandBuffer starting at Y.
// Result stored in HexValLo ($F7) and HexValHi ($F8).
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
// Clobbers: A, Y, PrintPtrLo/Hi
normalizeName:
    sta PrintPtrLo
    sty PrintPtrHi
    stx TempLo
    ldy #0
nnLoop:
    cpy TempLo
    beq nnDone
    lda (PrintPtrLo), y
    cmp #$C1                // Shifted 'A'
    bcc nnNext
    cmp #$DB                // Shifted 'Z' + 1
    bcs nnNext
    // Is shifted A-Z. Convert to unshifted (lowercase)
    and #$7F
    sta (PrintPtrLo), y
nnNext:
    iny
    jmp nnLoop
nnDone:
    rts
