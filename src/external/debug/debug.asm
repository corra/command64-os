// src/external/debug/debug.asm
// C64 port of MS-DOS DEBUG.COM
// Interactive memory editor, monitor, and debugger.

#import "../../../include/command64.inc"

.encoding "petscii_mixed"

// --- Version Information ---
.const VERSION_MAJOR = "0"
.const VERSION_MINOR = "1"
.const VERSION_STAGE = "2" // Remediation pass
.const BUILD_NUMBER  = "1007"

// --- Zero Page Pointers ($70-$7F) ---
.label currentAddr = $70
.label rangeStart  = $72
.label rangeEnd    = $74
.label val1        = $76
.label val2        = $78
.label DebugTemp   = $7A  // ZP Scratch for External Utility

* = $2000 "DebugEntry"

// --- Entry Point ---
start:
    // 1. Capture registers
    php                     // Save P
    sta regA
    stx regX
    sty regY
    pla
    sta regP
    tsx
    stx regS
    
    // 2. Initialize pointers
    lda #0
    sta currentAddr
    sta currentAddr + 1
    
    // 3. Welcome message
    lda #<startupMsg
    ldy #>startupMsg
    jsr API_PRINT_STR
    
mainLoop:
    // 4. Prompt
    lda #'-'
    jsr KernalChROUT
    
    // 5. Read Line
    jsr readLine
    
    // 6. Dispatch
    jsr dispatch
    jmp mainLoop

// ---------------------------------------------------------------------------
// readLine
// Reads input into inputBuf until CR. Handles backspace.
// ---------------------------------------------------------------------------
readLine:
    ldy #0
rlLoop:
    tya                     // KernalGetIn may clobber Y; preserve it
    pha
rlPoll:
    jsr KernalGetIn
    beq rlPoll

    tax                     // save char in X (KernalChROUT preserves X)
    pla
    tay                     // restore Y
    txa                     // restore char to A

    cmp #PetCr
    beq rlDone

    cmp #PetDel
    beq rlHandleDel

    // Check buffer limit (63 chars)
    cpy #63
    beq rlLoop

    // Store and echo
    sta inputBuf, y
    jsr KernalChROUT
    iny
    jmp rlLoop

rlHandleDel:
    tya
    beq rlLoop              // Start of buffer, ignore
    dey
    lda #PetDel
    jsr KernalChROUT        // Destructive backspace
    jmp rlLoop

rlDone:
    lda #0
    sta inputBuf, y         // Null terminate
    sty inputLen
    lda #PetCr
    jsr KernalChROUT        // Echo CR
    rts

// ---------------------------------------------------------------------------
// dispatch
// Parses the first char of inputBuf and jumps to handler.
// ---------------------------------------------------------------------------
dispatch:
    ldy #0
dSkipSpaces:
    lda inputBuf, y
    beq dExit               // Empty line
    cmp #' '
    bne dFoundCmd
    iny
    jmp dSkipSpaces

dFoundCmd:
    sty parsePos            // Save index of command
    iny                     // Prepare Y for handlers
    
    // Convert shifted to unshifted for comparison
    cmp #'A'
    bcc dNotLetter
    cmp #'Z' + 1
    bcs dNotLetter
    and #$7F                // Shifted ($C1) -> Unshifted ($41)
dNotLetter:
    
    // --- Command Registry ---
    cmp #'q'
    bne _d1
    jmp cmdQuit
_d1:
    cmp #'d'
    bne _d2
    jmp cmdDump
_d2:
    cmp #'e'
    bne _d3
    jmp cmdEnter
_d3:
    cmp #'f'
    bne _d4
    jmp cmdFill
_d4:
    cmp #'m'
    bne _d5
    jmp cmdMove
_d5:
    cmp #'c'
    bne _d6
    jmp cmdCompare
_d6:
    cmp #'s'
    bne _d7
    jmp cmdSearch
_d7:
    cmp #'h'
    bne _d8
    jmp cmdHexMath
_d8:
    cmp #'g'
    bne _d9
    jmp cmdGo
_d9:
    cmp #'r'
    bne _d10
    jmp cmdRegs
_d10:
    cmp #'v'
    bne _d11
    jmp cmdVer
_d11:
    
    // Unknown command
    lda #<errUnknown
    ldy #>errUnknown
    jsr API_PRINT_STR
dExit:
    rts

// ---------------------------------------------------------------------------
// API Wrappers
// ---------------------------------------------------------------------------
API_PRINT_STR:
    tax                     // X = Lo, Y = Hi
    lda #DOS_PRINT_STR
    jsr $1000
    rts

API_EXIT:
    lda #DOS_EXIT
    jsr $1000
    rts

// ---------------------------------------------------------------------------
// Command Handlers
// ---------------------------------------------------------------------------
cmdQuit:
    jmp API_EXIT

cmdDump:
    jsr skipSpaces
    
    // Check if address provided
    lda inputBuf, y
    beq cdUseDefault
    
    jsr parseHexArg
    bcc *+5
    jmp cdErr
    lda HexValLo
    sta currentAddr
    lda HexValHi
    sta currentAddr + 1
    
cdUseDefault:
    // For now, dump 128 bytes (16 rows of 8)
    lda #16
    sta DebugTemp           // Row counter
    
cdRowLoop:
    // Print address
    lda currentAddr + 1
    jsr printHex8
    lda currentAddr
    jsr printHex8
    lda #':'
    jsr KernalChROUT
    lda #' '
    jsr KernalChROUT
    
    // Print 8 bytes (Hex)
    ldy #0
cdHexLoop:
    lda (currentAddr), y
    jsr printHex8
    
    iny
    cpy #8
    beq cdNoSep             // No separator after last byte
    
    lda #' '
    cpy #4
    bne cdSkipColon
    lda #':'
cdSkipColon:
    jsr KernalChROUT
cdNoSep:
    cpy #8
    bne cdHexLoop
    
    // Print PETSCII
    lda #' '
    jsr KernalChROUT
    ldy #0
cdCharLoop:
    lda (currentAddr), y
    // Filter non-printable for PETSCII mixed mode
    cmp #32
    bcc cdDot
    cmp #127
    bcc cdPrintChar
    cmp #160
    bcc cdDot
cdPrintChar:
    jsr KernalChROUT
    jmp cdNextChar
cdDot:
    lda #'.'
    jsr KernalChROUT
cdNextChar:
    iny
    cpy #8
    bne cdCharLoop
    
    lda #PetCr
    jsr KernalChROUT
    
    // Advance currentAddr
    lda currentAddr
    clc
    adc #8
    sta currentAddr
    lda currentAddr + 1
    adc #0
    sta currentAddr + 1
    
    dec DebugTemp
    bne cdRowLoop
    rts

cdErr:
    lda #<errUnknown
    ldy #>errUnknown
    jsr API_PRINT_STR
    rts

cmdHexMath:
    jsr skipSpaces
    jsr parseHexArg         // Get val1
    bcc *+5
    jmp cdErr
    lda HexValLo
    sta val1
    lda HexValHi
    sta val1 + 1
    
    jsr skipSpaces
    jsr parseHexArg         // Get val2
    bcc *+5
    jmp cdErr
    
    // Sum
    lda val1
    clc
    adc HexValLo
    tax                     // save sum Lo
    lda val1 + 1
    adc HexValHi
    pha                     // save sum Hi
    
    // Difference
    lda val1
    sec
    sbc HexValLo
    sta val2                // use val2 for diff Lo
    lda val1 + 1
    sbc HexValHi
    sta val2 + 1            // diff Hi
    
    // Print sum
    pla                     // sum Hi
    jsr printHex8
    txa                     // sum Lo
    jsr printHex8
    lda #' '
    jsr KernalChROUT
    lda #' '
    jsr KernalChROUT
    
    // Print diff
    lda val2 + 1
    jsr printHex8
    lda val2
    jsr printHex8
    lda #PetCr
    jsr KernalChROUT
    rts

cmdRegs:
    // Print A=.. X=.. Y=.. P=.. S=..
    lda #'A'
    jsr KernalChROUT
    lda #'='
    jsr KernalChROUT
    lda regA
    jsr printHex8
    
    lda #' '
    jsr KernalChROUT
    lda #'X'
    jsr KernalChROUT
    lda #'='
    jsr KernalChROUT
    lda regX
    jsr printHex8

    lda #' '
    jsr KernalChROUT
    lda #'Y'
    jsr KernalChROUT
    lda #'='
    jsr KernalChROUT
    lda regY
    jsr printHex8

    lda #' '
    jsr KernalChROUT
    lda #'P'
    jsr KernalChROUT
    lda #'='
    jsr KernalChROUT
    lda regP
    jsr printHex8

    lda #' '
    jsr KernalChROUT
    lda #'S'
    jsr KernalChROUT
    lda #'='
    jsr KernalChROUT
    lda regS
    jsr printHex8
    
    lda #PetCr
    jsr KernalChROUT
    rts

cmdVer:
    lda #<verMsg
    ldy #>verMsg
    jsr API_PRINT_STR
    rts

cmdEnter:
    jsr skipSpaces
    jsr parseHexArg
    bcc *+5
    jmp cdErr
    lda HexValLo
    sta rangeStart
    lda HexValHi
    sta rangeStart + 1
    
ceLoop:
    jsr skipSpaces
    lda inputBuf, y
    beq ceDone
    jsr parseHexArg
    bcc *+5
    jmp cdErr
    
    // Write byte to memory, preserving parsing index Y
    tya
    pha
    ldy #0
    lda HexValLo
    sta (rangeStart), y
    pla
    tay
    
    inc rangeStart
    bne ceLoop
    inc rangeStart + 1
    jmp ceLoop
ceDone:
    rts

cmdFill:
    jsr parseRange          // Sets rangeStart, rangeEnd
    bcc *+5
    jmp cdErr
    jsr skipSpaces
    jsr parseHexArg         // Get fill byte
    bcc *+5
    jmp cdErr
    
    ldy #0
cfLoop:
    lda HexValLo
    sta (rangeStart), y     // fill byte first; exit check after (inclusive end)
    lda rangeStart
    cmp rangeEnd
    bne cfIncrement
    lda rangeStart + 1
    cmp rangeEnd + 1
    beq cfDone
cfIncrement:
    inc rangeStart
    bne cfLoop
    inc rangeStart + 1
    jmp cfLoop
cfDone:
    rts

cmdMove:
    jsr parseRange
    bcc *+5
    jmp cdErr
    jsr skipSpaces
    jsr parseHexArg         // Get dest
    bcc *+5
    jmp cdErr
    lda HexValLo
    sta val1
    lda HexValHi
    sta val1 + 1

    // If dest > src, copy backwards to prevent overlap corruption.
    lda val1 + 1
    cmp rangeStart + 1
    bcc cmForward           // dest hi < src hi: no overlap risk
    bne cmBackSetup         // dest hi > src hi: must copy backwards
    lda val1                // hi bytes equal; compare lo
    cmp rangeStart
    bcc cmForward           // dest lo < src lo: no overlap risk
    beq cmForward           // dest == src: no-op, forward is harmless

cmBackSetup:
    // dest_end = val1 + (rangeEnd - rangeStart)
    lda rangeEnd
    sec
    sbc rangeStart
    sta DebugTemp           // size lo
    lda rangeEnd + 1
    sbc rangeStart + 1
    sta DebugTemp + 1       // size hi
    lda val1
    clc
    adc DebugTemp
    sta val2                // dest_end lo
    lda val1 + 1
    adc DebugTemp + 1
    sta val2 + 1            // dest_end hi

cmBackLoop:
    ldy #0
    lda (rangeEnd), y       // read from tail of source
    sta (val2), y           // write to tail of dest
    lda rangeEnd
    cmp rangeStart
    bne cmBackDec
    lda rangeEnd + 1
    cmp rangeStart + 1
    beq cmDone              // processed the first (last remaining) byte
cmBackDec:
    lda rangeEnd            // dec src pointer
    bne cmBackDecLo
    dec rangeEnd + 1
cmBackDecLo:
    dec rangeEnd
    lda val2                // dec dest pointer
    bne cmBackDecDst
    dec val2 + 1
cmBackDecDst:
    dec val2
    jmp cmBackLoop

cmForward:
    ldy #0
cmFwdLoop:
    lda (rangeStart), y
    sta (val1), y
    lda rangeStart          // exit check after copy (inclusive end)
    cmp rangeEnd
    bne cmFwdInc
    lda rangeStart + 1
    cmp rangeEnd + 1
    beq cmDone
cmFwdInc:
    inc rangeStart
    bne cmFwdIncDest
    inc rangeStart + 1
cmFwdIncDest:
    inc val1
    bne cmFwdLoop
    inc val1 + 1
    jmp cmFwdLoop

cmDone:
    rts

cmdCompare:
    jsr parseRange
    bcc *+5
    jmp cdErr
    jsr skipSpaces
    jsr parseHexArg         // Get dest
    bcc *+5
    jmp cdErr
    lda HexValLo
    sta val1
    lda HexValHi
    sta val1 + 1
    
    ldy #0
ccpLoop:
    lda (rangeStart), y     // compare this byte first (inclusive end)
    cmp (val1), y
    beq ccpNext

    // Print mismatch: ADDR1 B1 B2 ADDR2
    lda rangeStart + 1
    jsr printHex8
    lda rangeStart
    jsr printHex8
    lda #' '
    jsr KernalChROUT
    lda (rangeStart), y
    jsr printHex8
    lda #' '
    jsr KernalChROUT
    lda (val1), y
    jsr printHex8
    lda #' '
    jsr KernalChROUT
    lda val1 + 1
    jsr printHex8
    lda val1
    jsr printHex8
    lda #PetCr
    jsr KernalChROUT

ccpNext:
    lda rangeStart
    cmp rangeEnd
    bne ccpInc
    lda rangeStart + 1
    cmp rangeEnd + 1
    beq ccpDone
ccpInc:
    inc rangeStart
    bne ccpIncDest
    inc rangeStart + 1
ccpIncDest:
    inc val1
    bne ccpLoop
    inc val1 + 1
    jmp ccpLoop
ccpDone:
    rts

cmdSearch:
    jsr parseRange
    bcc *+5
    jmp cdErr
    jsr skipSpaces
    jsr parseHexArg         // For now, search 1 byte
    bcc *+5
    jmp cdErr
    
    ldy #0
csLoop:
    lda (rangeStart), y     // search this byte first (inclusive end)
    cmp HexValLo
    bne csNext

    // Found: print address
    lda rangeStart + 1
    jsr printHex8
    lda rangeStart
    jsr printHex8
    lda #PetCr
    jsr KernalChROUT

csNext:
    lda rangeStart
    cmp rangeEnd
    bne csInc
    lda rangeStart + 1
    cmp rangeEnd + 1
    beq csDone
csInc:
    inc rangeStart
    bne csLoop
    inc rangeStart + 1
    jmp csLoop
csDone:
    rts

cmdGo:
    jsr skipSpaces
    lda inputBuf, y
    beq cgUseDefault
    jsr parseHexArg
    bcc *+5
    jmp cdErr
    lda HexValLo
    sta val1
    lda HexValHi
    sta val1 + 1
    jmp cgDo
cgUseDefault:
    lda currentAddr
    sta val1
    lda currentAddr + 1
    sta val1 + 1
cgDo:
    // Capture state? No, Go usually just JSRs.
    jsr cgIndirect
    rts
cgIndirect:
    jmp (val1)

// ---------------------------------------------------------------------------
// Utilities
// ---------------------------------------------------------------------------

parseRange:
    jsr skipSpaces
    jsr parseHexArg
    bcs prErr
    lda HexValLo
    sta rangeStart
    lda HexValHi
    sta rangeStart + 1
    
    jsr skipSpaces
    jsr parseHexArg
    bcs prErr
    lda HexValLo
    sta rangeEnd
    lda HexValHi
    sta rangeEnd + 1
    clc
    rts
prErr:
    sec
    rts

skipSpaces:
ssLoop:
    lda inputBuf, y
    beq ssDone
    cmp #' '
    bne ssDone
    iny
    jmp ssLoop
ssDone:
    rts

// Parses hex starting at inputBuf,y
// Result in HexValLo/Hi. Returns C=0 on success.
parseHexArg:
    lda #0
    sta HexValLo
    sta HexValHi
    tax                     // X = digit counter
phLoop:
    lda inputBuf, y
    beq phDone
    cmp #' '
    beq phDone
    
    // Convert to value 0-15
    cmp #'0'
    bcc phInvalid
    cmp #'9' + 1
    bcc phDigit
    
    // Convert shifted to unshifted
    cmp #'A'
    bcc phInvalid
    cmp #'Z' + 1
    bcs phInvalid
    and #$7F                // To unshifted
    
    cmp #'a'
    bcc phInvalid
    cmp #'f' + 1
    bcs phInvalid
    sec
    sbc #('a' - 10)
    jmp phAdd
phDigit:
    sec
    sbc #'0'
    
phAdd:
    pha                     // Save digit
    // HexVal = HexVal * 16
    lda HexValLo
    asl
    rol HexValHi
    asl
    rol HexValHi
    asl
    rol HexValHi
    asl
    rol HexValHi
    sta HexValLo
    
    pla                     // Restore digit
    ora HexValLo
    sta HexValLo
    inx
    iny
    jmp phLoop

phInvalid:
    sec
    rts
phDone:
    cpx #0
    beq phInvalid
    clc
    rts

printHex8:
    pha
    lsr
    lsr
    lsr
    lsr
    jsr phNibble
    pla
    and #$0F
phNibble:
    cmp #10
    bcc phnDigit
    clc
    adc #7                  // '9'+1=10 -> 'A' (10+7+48 = 65)
phnDigit:
    adc #48                 // binary $00 -> '0'
    jsr KernalChROUT
    rts

// ---------------------------------------------------------------------------
// Data
// ---------------------------------------------------------------------------
startupMsg:
    .text "DEBUG v" + VERSION_MAJOR + "." + VERSION_MINOR + "." + VERSION_STAGE
    .text " (Build " + BUILD_NUMBER + ")"
    .byte $0D, 0

verMsg:
    .text "DEBUG v" + VERSION_MAJOR + "." + VERSION_MINOR + "." + VERSION_STAGE
    .text " (Build " + BUILD_NUMBER + ")"
    .byte $0D, 0

errUnknown:
    .text "error"
    .byte $0D, 0

msgStub:
    .text "not yet implemented"
    .byte $0D, 0

// Variables
regA: .byte 0
regX: .byte 0
regY: .byte 0
regP: .byte 0
regS: .byte 0

parsePos: .byte 0
inputLen: .byte 0
inputBuf: .fill 64, 0
