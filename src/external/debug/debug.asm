// src/external/debug/debug.asm
// C64 port of MS-DOS DEBUG.COM
// Interactive memory editor, monitor, and debugger.

#import "../../../include/command64.inc"

.encoding "petscii_mixed"

// --- Version Information ---
.const VERSION_MAJOR = "0"
.const VERSION_MINOR = "1"
.const VERSION_STAGE = "8" // Build 1027 Y-register fix
#import "build_debug.inc"

// --- Zero Page Pointers ($70-$7F) ---
.label currentAddr = $70
.label rangeStart  = $72
.label rangeEnd    = $74
.label val1        = $76
.label val2        = $78
.label DebugTemp   = $7A  // ZP Scratch for External Utility
.label disasmTemp  = $7B  // Row/Count scratch for disassembler

// --- Addressing Modes ---
.const MODE_INV = 0  // Invalid
.const MODE_IMP = 1  // Implied
.const MODE_ACC = 2  // Accumulator
.const MODE_IMM = 3  // Immediate
.const MODE_ZP  = 4  // Zero Page
.const MODE_ZPX = 5  // Zero Page,X
.const MODE_ZPY = 6  // Zero Page,Y
.const MODE_REL = 7  // Relative
.const MODE_ABS = 8  // Absolute
.const MODE_ABX = 9  // Absolute,X
.const MODE_ABY = 10 // Absolute,Y
.const MODE_IND = 11 // Indirect
.const MODE_IZX = 12 // Indirect,X
.const MODE_IZY = 13 // Indirect,Y

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
    bne dSkipCheck
    rts                     // Empty line — inline return; dExit is now out of branch range
dSkipCheck:
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
    and #$7F                // Shifted ($C1-$DA) → Unshifted ($41-$5A)
dNotLetter:
    
    // --- Command Registry ---
    // MAINTENANCE: Every command added below MUST be added to cmdHelp (debugHelpMsg)
    cmp #'?'
    bne _d0
    jmp cmdHelp
_d0:
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
    cmp #'u'
    bne _d7u
    jmp cmdUnassemble
_d7u:
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
    bne _d10n
    jmp cmdVer
_d10n:
    cmp #'n'
    bne _d10l
    jmp cmdName
_d10l:
    cmp #'l'
    bne _d10w
    jmp cmdLoad
_d10w:
    cmp #'w'
    bne _d11
    jmp cmdWrite
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
    lda inputBuf, y
    bne cdHasArgs
    
    // No args: default to currentAddr, dump 128 bytes (16 rows of 8)
    lda #16
    sta DebugTemp           // Row counter
    lda #$FF
    sta rangeEnd
    sta rangeEnd + 1        // effectively no range end
    jmp cdRowLoop
    
cdHasArgs:
    // Try parsing as range first
    jsr parseRange
    bcc cdRangeOk
    
    // Check error type returned in A:
    // A = 0: no second argument -> try single address fallback
    // A = 1: invalid range specified -> abort immediately
    cmp #0
    beq cdTrySingle
    jmp cdErr
cdTrySingle:
    // Not a range? Reset Y and try single address
    ldy parsePos
    iny                     // skip command char
    jsr skipSpaces
    jsr parseHexArg
    bcc cdSingleAddr
    jmp cdErr
    
cdSingleAddr:
    lda HexValLo
    sta currentAddr
    lda HexValHi
    sta currentAddr + 1
    lda #16
    sta DebugTemp
    lda #$FF
    sta rangeEnd
    sta rangeEnd + 1
    jmp cdRowLoop
    
cdRangeOk:
    lda rangeStart
    sta currentAddr
    lda rangeStart + 1
    sta currentAddr + 1
    lda #$FF
    sta DebugTemp           // Use range check instead of count
    // rangeEnd is already set by parseRange
    jmp cdRowLoop
    
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
    
    // Check if we use count or range
    lda DebugTemp
    cmp #$FF
    beq cdCheckRange
    
    dec DebugTemp
    bne cdRowLoop
    rts

cdCheckRange:
    lda rangeEnd + 1
    cmp currentAddr + 1
    bne cdSkipLo
    lda rangeEnd
    cmp currentAddr
cdSkipLo:
    bcs cdRowLoop_jmp
    rts

cdRowLoop_jmp:
    jmp cdRowLoop

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
    jsr skipSpaces
    lda inputBuf, y
    bne dHasRegArg
    jmp printAllRegs
dHasRegArg:
    
    // Save register name char, then check that it's exactly 1 character
    tax                 // X = char
    iny
    lda inputBuf, y
    beq regNameOk
    cmp #' '
    beq regNameOk
    jmp cdErr           // invalid register name if extra characters follow
regNameOk:
    txa
    and #$7F            // normalize shifted to unshifted PETSCII (lowercase)
    cmp #'a'
    beq modifyA
    cmp #'x'
    beq modifyX
    cmp #'y'
    beq modifyY
    cmp #'p'
    beq modifyP
    cmp #'s'
    beq modifyS
    jmp cdErr

modifyA:
    lda #'A'
    ldx #<regA
    ldy #>regA
    jmp modifyReg
modifyX:
    lda #'X'
    ldx #<regX
    ldy #>regX
    jmp modifyReg
modifyY:
    lda #'Y'
    ldx #<regY
    ldy #>regY
    jmp modifyReg
modifyP:
    lda #'P'
    ldx #<regP
    ldy #>regP
    jmp modifyReg
modifyS:
    lda #'S'
    ldx #<regS
    ldy #>regS
    jmp modifyReg

modifyReg:
    stx val1
    sty val1 + 1
    
    // Print register name and current value, e.g. "A xx"
    jsr KernalChROUT
    lda #' '
    jsr KernalChROUT
    ldy #0
    lda (val1), y
    jsr printHex8
    lda #PetCr
    jsr KernalChROUT
    
    // Print prompt and read line
    lda #':'
    jsr KernalChROUT
    jsr readLine
    
    // If empty input, leave unmodified
    ldy #0
    jsr skipSpaces
    lda inputBuf, y
    beq mrDone
    
    // Parse hex byte (must fit in 8 bits)
    jsr parseHexArg
    bcs mrErr
    lda HexValHi
    bne mrErr           // must be 8-bit
    jsr skipSpaces
    lda inputBuf, y
    bne mrErr           // extra trailing characters -> error
    
    lda HexValLo
    ldy #0
    sta (val1), y
mrDone:
    rts
mrErr:
    jmp cdErr

printAllRegs:
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

// ---------------------------------------------------------------------------
// cmdName - Set or display the current filename for L/W commands.
// Syntax: N [filename]
//   N filename → store up to 32 chars in fileNameBuf
//   N (none)   → display current filename if one is set
// ---------------------------------------------------------------------------
cmdName:
    jsr skipSpaces
    lda inputBuf, y
    bne cnSet
    // No argument: display current filename if set
    lda fileNameLen
    beq cnSilent
    ldx #0
cnShowLoop:
    cpx fileNameLen
    beq cnShowDone
    lda fileNameBuf, x
    jsr KernalChROUT
    inx
    jmp cnShowLoop
cnShowDone:
    lda #PetCr
    jsr KernalChROUT
cnSilent:
    rts
cnSet:
    ldx #0
cnCopyLoop:
    lda inputBuf, y
    beq cnCopyDone
    cmp #' '
    beq cnCopyDone
    cpx #32
    beq cnTooLong
    sta fileNameBuf, x
    inx
    iny
    jmp cnCopyLoop
cnCopyDone:
    stx fileNameLen
    rts
cnTooLong:
    lda #<errUnknown
    ldy #>errUnknown
    jsr API_PRINT_STR
    rts

// ---------------------------------------------------------------------------
// cmdLoad - Load the named file into memory.
// Syntax: L [addr]
//   addr (none) → load to PRG header address (SA=1)
//   addr        → relocate load to specified address (SA=0)
// Requires N to have been set.
// ---------------------------------------------------------------------------
cmdLoad:
    lda fileNameLen
    bne clHaveName
    jmp cdErr
clHaveName:
    jsr skipSpaces
    lda inputBuf, y
    beq clFromHeader
    jsr parseHexArg
    bcc clRelocate
    jmp cdErr
clRelocate:
    // Relocating load: save target address then SETNAM/SETLFS/LOAD
    lda HexValLo
    sta val1
    lda HexValHi
    sta val1 + 1
    lda fileNameLen
    ldx #<fileNameBuf
    ldy #>fileNameBuf
    jsr KernalSETNAM
    lda #1              // LFN=1
    ldx CurrentDevice
    ldy #0              // SA=0: use address from X/Y in LOAD call
    jsr KernalSETLFS
    lda #0              // 0=load (not verify)
    ldx val1
    ldy val1 + 1
    jsr KernalLOAD
    bcs clErr
    
    // Update currentAddr to the load address
    lda val1
    sta currentAddr
    lda val1 + 1
    sta currentAddr + 1
    rts
clFromHeader:
    lda fileNameLen
    ldx #<fileNameBuf
    ldy #>fileNameBuf
    jsr KernalSETNAM
    lda #1              // LFN=1
    ldx CurrentDevice
    ldy #1              // SA=1: use PRG header address
    jsr KernalSETLFS
    lda #0              // 0=load
    ldx #0
    ldy #0
    jsr KernalLOAD
    bcs clErr
    
    // Update currentAddr to start address stored in MEMUSS ($C1/$C2) by KERNAL
    lda $C1
    sta currentAddr
    lda $C2
    sta currentAddr + 1
    rts
clErr:
    lda #<errUnknown
    ldy #>errUnknown
    jsr API_PRINT_STR
    rts

// ---------------------------------------------------------------------------
// cmdWrite - Write a range of memory to the named file.
// Syntax: W [type] start end|Llen
//   type → optional P (PRG, default), S (SEQ), or U (USR)
//   PRG prepends a 2-byte load address header; SEQ/USR write raw bytes.
// Requires N to have been set. Open string is built in listBuf at runtime.
// ---------------------------------------------------------------------------
cmdWrite:
    jsr skipSpaces
    lda inputBuf, y
    beq cwNoRange
    // Default type = P (PRG), stored as unshifted byte $50
    lda #$50
    sta fileType
    // P/S/U are not valid hex chars, so safe to check for type prefix first.
    // Normalize to unshifted PETSCII for comparison (and #$7F).
    lda inputBuf, y
    and #$7F
    cmp #'p'
    beq cwTypeP
    cmp #'s'
    beq cwTypeS
    cmp #'u'
    beq cwTypeU
    jmp cwParseRange
cwTypeP:
    lda #$50            // 'P'
    sta fileType
    jmp cwConsumeType
cwTypeS:
    lda #$53            // 'S'
    sta fileType
    jmp cwConsumeType
cwTypeU:
    lda #$55            // 'U'
    sta fileType
cwConsumeType:
    iny                 // skip type char
    jsr skipSpaces
cwParseRange:
    jsr parseRange
    bcc cwHaveRange
cwNoRange:
    jmp cdErr
cwHaveRange:
    lda fileNameLen
    bne cwHaveName
    jmp cdErr
cwHaveName:
    // Build open string in listBuf: copy fileNameBuf then append ",T,W"
    // Max total = 32 + 4 = 36 bytes; listBuf is 64 bytes — safe.
    ldx #0
    ldy #0
cwCopyName:
    cpx fileNameLen
    beq cwAppendSuffix
    lda fileNameBuf, x
    sta listBuf, y
    inx
    iny
    jmp cwCopyName
cwAppendSuffix:
    lda #$2C            // ','
    sta listBuf, y
    iny
    lda fileType        // 'P'=$50 / 'S'=$53 / 'U'=$55
    sta listBuf, y
    iny
    lda #$2C            // ','
    sta listBuf, y
    iny
    lda #$57            // 'W'
    sta listBuf, y
    iny
    sty DebugTemp       // save total open-string length
    lda DebugTemp
    ldx #<listBuf
    ldy #>listBuf
    jsr KernalSETNAM
    lda #1              // LFN=1
    ldx CurrentDevice
    ldy #2              // SA=2: data channel
    jsr KernalSETLFS
    jsr KernalOPEN
    ldx #1              // LFN=1
    jsr KernalCHKOUT
    bcs cwOpenErr
    // PRG only: prepend 2-byte load address header before data
    lda fileType
    cmp #$53            // 'S' → skip header
    beq cwWriteLoop
    cmp #$55            // 'U' → skip header
    beq cwWriteLoop
    lda rangeStart      // PRG header lo
    jsr KernalChROUT
    lda rangeStart + 1  // PRG header hi
    jsr KernalChROUT
cwWriteLoop:
    ldy #0              // reset Y each iteration; KernalChROUT may clobber it
    lda (rangeStart), y
    jsr KernalChROUT
    jsr checkRangeLimit
    beq cwWriteDone
    inc rangeStart
    bne cwWriteLoop
    inc rangeStart + 1
    jmp cwWriteLoop
cwWriteDone:
    jsr KernalCLRCHN
    lda #1
    jsr KernalCLOSE
    rts
cwOpenErr:
    jsr KernalCLRCHN
    lda #1
    jsr KernalCLOSE
    lda #<errUnknown
    ldy #>errUnknown
    jsr API_PRINT_STR
    rts

cmdHelp:
    lda #<debugHelpMsg
    ldy #>debugHelpMsg
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
    
    jsr parseList
    bcc *+5
    jmp cdErr
    
    lda #0
    sta listIndex
ceLoop:
    ldx listIndex
    cpx listLen
    beq ceDone
    
    lda listBuf, x
    ldy #0
    sta (rangeStart), y
    
    inc listIndex
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
    jsr parseList
    bcc *+5
    jmp cdErr
    lda listLen
    bne *+5
    jmp cdErr
    
    lda #0
    sta listIndex
cfLoop:
    ldx listIndex
    lda listBuf, x
    ldy #0
    sta (rangeStart), y     // fill byte first; exit check after (inclusive end)
    
    // Increment list index (modulo listLen)
    inc listIndex
    lda listIndex
    cmp listLen
    bne cfNoWrap
    lda #0
    sta listIndex
cfNoWrap:

    jsr checkRangeLimit
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
    jsr checkRangeLimit
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
    jsr checkRangeLimit
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
    jsr checkRangeLimit
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
    jsr parseList
    bcc *+5
    jmp cdErr
    lda listLen
    bne *+5
    jmp cdErr
    
csLoop:
    ldy #0
csCompLoop:
    lda (rangeStart), y
    cmp listBuf, y
    bne csNoMatch
    iny
    cpy listLen
    bne csCompLoop
    
    // Found: print address
    lda rangeStart + 1
    jsr printHex8
    lda rangeStart
    jsr printHex8
    lda #PetCr
    jsr KernalChROUT

csNoMatch:
    jsr checkRangeLimit
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
// cmdUnassemble
// Disassembles a range of memory.
// ---------------------------------------------------------------------------
cmdUnassemble:
    jsr skipSpaces
    lda inputBuf, y
    bne cuHasArgs
    
    // No args: default to currentAddr, count 16
    lda #16
    sta disasmTemp
    lda #$FF
    sta rangeEnd
    sta rangeEnd + 1        // effectively no range end
    jmp cuLoop

cuHasArgs:
    // Try parsing as range first
    jsr parseRange
    bcc cuRangeOk
    
    // Check error type returned in A:
    // A = 0: no second argument -> try single address fallback
    // A = 1: invalid range specified -> abort immediately
    cmp #0
    beq cuTrySingle
    jmp cuErr
cuTrySingle:
    // Not a range? Reset Y and try single address
    ldy parsePos
    iny                     // skip command char
    jsr skipSpaces
    jsr parseHexArg
    bcc cuSingleAddr
    jmp cuErr

cuSingleAddr:
    lda HexValLo
    sta currentAddr
    lda HexValHi
    sta currentAddr + 1
    lda #16
    sta disasmTemp
    lda #$FF
    sta rangeEnd
    sta rangeEnd + 1
    jmp cuLoop

cuRangeOk:
    lda rangeStart
    sta currentAddr
    lda rangeStart + 1
    sta currentAddr + 1
    lda #$FF
    sta disasmTemp          // Use range instead of count
    
cuLoop:
    // Print address
    lda currentAddr + 1
    jsr printHex8
    lda currentAddr
    jsr printHex8
    lda #':'
    jsr KernalChROUT
    lda #' '
    jsr KernalChROUT
    
    // Get opcode
    ldy #0
    lda (currentAddr), y
    tax                     // X = Opcode
    
    // Get mode and length
    lda opAddrMode, x
    sta DebugTemp           // Save mode
    tay
    lda modeLength, y
    sta val1                // val1 = length
    
    // Print hex bytes
    ldy #0
cuPrintBytes:
    lda (currentAddr), y
    jsr printHex8
    lda #' '
    jsr KernalChROUT
    iny
    cpy val1
    bne cuPrintBytes
    
    // Pad to 10 chars for bytes column (3 bytes * 3 chars = 9, +1 space)
    lda val1
    cmp #1
    bne cuPad2
    // Length 1: print 6 spaces
    ldy #6
    jmp cuDoPad
cuPad2:
    cmp #2
    bne cuPad3
    // Length 2: print 3 spaces
    ldy #3
    jmp cuDoPad
cuPad3:
    // Length 3: print 0 spaces
    ldy #0
cuDoPad:
    cpy #0
    beq cuMnemonic
    lda #' '
    jsr KernalChROUT
    dey
    jmp cuDoPad

cuMnemonic:
    // Print mnemonic
    ldy #0
    lda opMnemonicIndex, x
    // Offset = index * 3
    sta val2
    asl
    clc
    adc val2
    tay                     // Y = string offset
    
    ldx #0
cuPrMnem:
    lda opStringTable, y
    jsr KernalChROUT
    iny
    inx
    cpx #3
    bne cuPrMnem
    
    lda #' '
    jsr KernalChROUT
    
    // Print operand based on mode (stored in DebugTemp)
    lda DebugTemp
    asl                     // * 2 for jump table
    tax
    lda cuOperandTable, x
    sta val2
    lda cuOperandTable + 1, x
    sta val2 + 1
    jmp (val2)

cuOperandTable:
    .word cuOpInv, cuOpImp, cuOpAcc, cuOpImm, cuOpZp, cuOpZpx, cuOpZpy, cuOpRel, cuOpAbs, cuOpAbx, cuOpAby, cuOpInd, cuOpIzx, cuOpIzy

cuOpInv:
    jmp cuDoneLine

cuOpImp:
    jmp cuDoneLine

cuOpAcc:
    lda #'A'
    jsr KernalChROUT
    jmp cuDoneLine

cuOpImm:
    lda #'#'
    jsr KernalChROUT
    jsr cuPrintZpAddr
    jmp cuDoneLine

cuOpZp:
    jsr cuPrintZpAddr
    jmp cuDoneLine

cuOpZpx:
    jsr cuPrintZpAddr
    lda #','
    jsr KernalChROUT
    lda #'X'
    jsr KernalChROUT
    jmp cuDoneLine

cuOpZpy:
    jsr cuPrintZpAddr
    lda #','
    jsr KernalChROUT
    lda #'Y'
    jsr KernalChROUT
    jmp cuDoneLine

cuOpRel:
    lda #'$'
    jsr KernalChROUT
    // Target = currentAddr + 2 + signed_offset
    // Save offset on stack; compute base into val2 (avoids DebugTemp+1 = disasmTemp alias)
    ldy #1
    lda (currentAddr), y
    pha                     // push signed offset; restored after base is ready

    lda currentAddr
    clc
    adc #2
    sta val2                // base lo ($78)
    lda currentAddr + 1
    adc #0
    sta val2 + 1            // base hi ($79) — safe, no alias with disasmTemp ($7B)

    pla                     // restore offset → A; sign still intact
    bpl cuRelPos
    // Negative offset: target = base + sign-extended offset
    clc
    adc val2
    tax                     // target lo → X
    lda val2 + 1
    adc #$FF                // sign extend carry (offset was negative)
    tay                     // target hi → Y
    jmp cuRelPrint
cuRelPos:
    // Positive offset: target = base + offset
    clc
    adc val2
    tax                     // target lo → X
    lda val2 + 1
    adc #0
    tay                     // target hi → Y
cuRelPrint:
    tya
    jsr printHex8
    txa
    jsr printHex8
    jmp cuDoneLine

cuOpAbs:
    jsr cuPrintAbsAddr
    jmp cuDoneLine

cuOpAbx:
    jsr cuPrintAbsAddr
    lda #','
    jsr KernalChROUT
    lda #'X'
    jsr KernalChROUT
    jmp cuDoneLine

cuOpAby:
    jsr cuPrintAbsAddr
    lda #','
    jsr KernalChROUT
    lda #'Y'
    jsr KernalChROUT
    jmp cuDoneLine

cuOpInd:
    lda #'('
    jsr KernalChROUT
    jsr cuPrintAbsAddr
    lda #')'
    jsr KernalChROUT
    jmp cuDoneLine

cuOpIzx:
    lda #'('
    jsr KernalChROUT
    jsr cuPrintZpAddr
    lda #','
    jsr KernalChROUT
    lda #'X'
    jsr KernalChROUT
    lda #')'
    jsr KernalChROUT
    jmp cuDoneLine

cuOpIzy:
    lda #'('
    jsr KernalChROUT
    jsr cuPrintZpAddr
    lda #')'
    jsr KernalChROUT
    lda #','
    jsr KernalChROUT
    lda #'Y'
    jsr KernalChROUT
    jmp cuDoneLine

cuPrintZpAddr:
    lda #'$'
    jsr KernalChROUT
    ldy #1
    lda (currentAddr), y
    jsr printHex8
    rts

cuPrintAbsAddr:
    lda #'$'
    jsr KernalChROUT
    ldy #2
    lda (currentAddr), y
    jsr printHex8
    ldy #1
    lda (currentAddr), y
    jsr printHex8
    rts

cuDoneLine:
    lda #PetCr
    jsr KernalChROUT
    
    // Advance address
    lda currentAddr
    clc
    adc val1
    sta currentAddr
    lda currentAddr + 1
    adc #0
    sta currentAddr + 1
    
    // Check if we use count or range
    lda disasmTemp
    cmp #$FF
    beq cuCheckRange
    
    dec disasmTemp
    beq cuDoneCount
    jmp cuLoop
cuDoneCount:
    rts

cuCheckRange:
    lda rangeEnd + 1
    cmp currentAddr + 1
    bne cuSkipLo
    lda rangeEnd
    cmp currentAddr
cuSkipLo:
    bcs cuLoop_jmp
    rts

cuLoop_jmp:
    jmp cuLoop

cuErr:
    lda #<errUnknown
    ldy #>errUnknown
    jsr API_PRINT_STR
    rts

// ---------------------------------------------------------------------------
// Utilities
// ---------------------------------------------------------------------------

parseRange:
    jsr skipSpaces
    jsr parseHexArg
    bcs prNoArgsErr
    lda HexValLo
    sta rangeStart
    lda HexValHi
    sta rangeStart + 1
    
    jsr skipSpaces
    lda inputBuf, y
    beq prNoSecondArg
    
    // Check for 'L' or 'l'
    and #$7F
    cmp #'l'
    beq prLength

    // Standard END address
    jsr parseHexArg
    bcs prInvalidRangeErr
    lda HexValLo
    sta rangeEnd
    lda HexValHi
    sta rangeEnd + 1
    jmp prValidate

prLength:
    iny                     // skip 'L'
    jsr skipSpaces
    jsr parseHexArg
    bcs prInvalidRangeErr
    
    tya
    pha                     // Save parser index Y
    
    // rangeEnd = rangeStart + length - 1
    lda HexValLo
    sec
    sbc #1
    tax                     // save lo
    lda HexValHi
    sbc #0
    tay                     // save hi (clobbers Y)
    
    txa
    clc
    adc rangeStart
    sta rangeEnd
    tya
    adc rangeStart + 1
    sta rangeEnd + 1
    
    pla
    tay                     // Restore parser index Y
    
prValidate:
    // Verify rangeStart <= rangeEnd to prevent infinite wrapping loops/underflows
    lda rangeEnd + 1
    cmp rangeStart + 1
    bcc prInvalidRangeErr // end hi < start hi -> error
    bne prRangeOk       // end hi > start hi -> valid
    lda rangeEnd
    cmp rangeStart
    bcc prInvalidRangeErr // end lo < start lo -> error
prRangeOk:
    clc
    rts

prNoArgsErr:
    lda #1
    sec
    rts

prNoSecondArg:
    lda #0
    sec
    rts

prInvalidRangeErr:
    lda #1
    sec
    rts

// Parses a list of bytes/strings into listBuf
parseList:
    lda #0
    sta listLen
plLoop:
    jsr skipSpaces
    lda inputBuf, y
    beq plDone
    
    cmp #'"'
    beq plString
    cmp #'''
    beq plString
    
    // Parse Hex Byte
    jsr parseHexArg
    bcs plErr               // parseHexArg sets Carry on error/empty
    
    ldx listLen
    cpx #64             // listBuf is 64 bytes; index 64 would overflow into parsePos
    bcs plErr
    lda HexValLo
    sta listBuf, x
    inc listLen
    jmp plLoop

plString:
    sta DebugTemp           // save quote char
    iny
plStrLoop:
    lda inputBuf, y
    beq plDone              // unexpected end
    cmp DebugTemp
    beq plStrDone
    
    ldx listLen
    cpx #64             // listBuf is 64 bytes; index 64 would overflow into parsePos
    bcs plErr
    sta listBuf, x      // A still holds the character from lda inputBuf,y above
    inc listLen
    iny
    jmp plStrLoop
plStrDone:
    iny                     // skip closing quote
    jmp plLoop

plDone:
    clc
    rts
plErr:
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
    
    // Check A-F / a-f: unshifted $41-$46 or shifted $C1-$C6
    and #$7F
    cmp #$41            // 'a'
    bcc phInvalid
    cmp #$47            // 'g'
    bcs phInvalid
    sec
    sbc #$37            // Convert to 10-15
    jmp phAdd
phDigit:
    sec
    sbc #'0'

phAdd:
    cpx #4
    beq phInvalid           // 5th digit: reject before corrupting HexVal
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

checkRangeLimit:
    lda rangeStart
    cmp rangeEnd
    bne crlSkipLo
    lda rangeStart + 1
    cmp rangeEnd + 1
crlSkipLo:
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
verMsg:
    .text "DEBUG v" + VERSION_MAJOR + "." + VERSION_MINOR + "." + VERSION_STAGE
    .text "." + BUILD_NUMBER
    .byte $0D, 0

debugHelpMsg:
    .text "DEBUG COMMANDS:"
    .byte $0D
    .text "D [RANGE]   - DUMP MEMORY"
    .byte $0D
    .text "E ADDR LIST - ENTER DATA"
    .byte $0D
    .text "F RANGE LIST- FILL MEMORY"
    .byte $0D
    .text "M RANGE ADDR- MOVE MEMORY"
    .byte $0D
    .text "C RANGE ADDR- COMPARE MEMORY"
    .byte $0D
    .text "S RANGE LIST- SEARCH MEMORY"
    .byte $0D
    .text "U [RANGE]   - UNASSEMBLE"
    .byte $0D
    .text "H VAL1 VAL2 - HEX MATH"
    .byte $0D
    .text "R           - SHOW REGISTERS"
    .byte $0D
    .text "G [ADDR]    - GO (EXECUTE)"
    .byte $0D
    .text "N [FILE]    - NAME FILE"
    .byte $0D
    .text "L [ADDR]    - LOAD NAMED FILE"
    .byte $0D
    .text "W [P/S/U] RANGE - WRITE FILE"
    .byte $0D
    .text "V           - SHOW VERSION"
    .byte $0D
    .text "Q           - QUIT TO SHELL"
    .byte $0D, 0

errUnknown:
    .text "error"
    .byte $0D, 0

msgStub:
    .text "not yet implemented"
    .byte $0D, 0

// Mode Lengths (indexed by MODE_* constants)
modeLength:
    .byte 1, 1, 1, 2, 2, 2, 2, 2, 3, 3, 3, 3, 2, 2

// opStringTable: 3-letter mnemonics for all 56 standard 6502 instructions plus '???'
// Indices 0-56
opStringTable:
    .text "ADCANDASLBCCBCSBEQBITBMIBNEBPLBRKBVCBVSCLCCLDCLICLVCMPCPXCPY" // 00-19
    .text "DECDEXDEYEORINCINXINYJMPJSRLDALDXLDYLSRNOPORAPHAPHAPLAPLPROL" // 20-39
    .text "RORRTIRTSSBCSECSEDSEISTASTXSTYTAXTAYTSXTXATXSTY???"          // 40-56

// opMnemonicIndex: Maps opcode ($00-$FF) to index in opStringTable
opMnemonicIndex:
    .byte 10, 34, 56, 56, 56, 34, 02, 56, 36, 34, 02, 56, 56, 34, 02, 56 // $00-$0F
    .byte 09, 34, 56, 56, 56, 34, 02, 56, 13, 34, 56, 56, 56, 34, 02, 56 // $10-$1F
    .byte 28, 01, 56, 56, 06, 01, 39, 56, 38, 01, 39, 56, 06, 01, 39, 56 // $20-$2F
    .byte 07, 01, 56, 56, 56, 01, 39, 56, 44, 01, 56, 56, 56, 01, 39, 56 // $30-$3F
    .byte 41, 23, 56, 56, 56, 23, 32, 56, 35, 23, 32, 56, 27, 23, 32, 56 // $40-$4F
    .byte 11, 23, 56, 56, 56, 23, 32, 56, 15, 23, 56, 56, 56, 23, 32, 56 // $50-$5F
    .byte 42, 00, 56, 56, 56, 00, 40, 56, 37, 00, 40, 56, 27, 00, 40, 56 // $60-$6F
    .byte 12, 00, 56, 56, 56, 00, 40, 56, 46, 00, 56, 56, 56, 00, 40, 56 // $70-$7F
    .byte 56, 47, 56, 56, 49, 47, 48, 56, 22, 56, 53, 56, 49, 47, 48, 56 // $80-$8F
    .byte 03, 47, 56, 56, 49, 47, 48, 56, 55, 47, 54, 56, 56, 47, 56, 56 // $90-$9F
    .byte 31, 29, 30, 56, 31, 29, 30, 56, 51, 29, 50, 56, 31, 29, 30, 56 // $A0-$AF
    .byte 04, 29, 56, 56, 31, 29, 30, 56, 16, 29, 52, 56, 31, 29, 30, 56 // $B0-$BF
    .byte 19, 17, 56, 56, 19, 17, 20, 56, 26, 17, 21, 56, 19, 17, 20, 56 // $C0-$CF
    .byte 08, 17, 56, 56, 56, 17, 20, 56, 14, 17, 56, 56, 56, 17, 20, 56 // $D0-$DF
    .byte 18, 43, 56, 56, 18, 43, 24, 56, 25, 43, 33, 56, 18, 43, 24, 56 // $E0-$EF
    .byte 05, 43, 56, 56, 56, 43, 24, 56, 45, 43, 56, 56, 56, 43, 24, 56 // $F0-$FF

// opAddrMode: Maps opcode ($00-$FF) to Addressing Mode
opAddrMode:
    .byte MODE_IMP, MODE_IZX, MODE_INV, MODE_INV, MODE_INV, MODE_ZP,  MODE_ZP,  MODE_INV, MODE_IMP, MODE_IMM, MODE_ACC, MODE_INV, MODE_INV, MODE_ABS, MODE_ABS, MODE_INV // $00
    .byte MODE_REL, MODE_IZY, MODE_INV, MODE_INV, MODE_INV, MODE_ZPX, MODE_ZPX, MODE_INV, MODE_IMP, MODE_ABY, MODE_INV, MODE_INV, MODE_INV, MODE_ABX, MODE_ABX, MODE_INV // $10
    .byte MODE_ABS, MODE_IZX, MODE_INV, MODE_INV, MODE_ZP,  MODE_ZP,  MODE_ZP,  MODE_INV, MODE_IMP, MODE_IMM, MODE_ACC, MODE_INV, MODE_ABS, MODE_ABS, MODE_ABS, MODE_INV // $20
    .byte MODE_REL, MODE_IZY, MODE_INV, MODE_INV, MODE_INV, MODE_ZPX, MODE_ZPX, MODE_INV, MODE_IMP, MODE_ABY, MODE_INV, MODE_INV, MODE_INV, MODE_ABX, MODE_ABX, MODE_INV // $30
    .byte MODE_IMP, MODE_IZX, MODE_INV, MODE_INV, MODE_INV, MODE_ZP,  MODE_ZP,  MODE_INV, MODE_IMP, MODE_IMM, MODE_ACC, MODE_INV, MODE_ABS, MODE_ABS, MODE_ABS, MODE_INV // $40
    .byte MODE_REL, MODE_IZY, MODE_INV, MODE_INV, MODE_INV, MODE_ZPX, MODE_ZPX, MODE_INV, MODE_IMP, MODE_ABY, MODE_INV, MODE_INV, MODE_INV, MODE_ABX, MODE_ABX, MODE_INV // $50
    .byte MODE_IMP, MODE_IZX, MODE_INV, MODE_INV, MODE_INV, MODE_ZP,  MODE_ZP,  MODE_INV, MODE_IMP, MODE_IMM, MODE_ACC, MODE_INV, MODE_IND, MODE_ABS, MODE_ABS, MODE_INV // $60
    .byte MODE_REL, MODE_IZY, MODE_INV, MODE_INV, MODE_INV, MODE_ZPX, MODE_ZPX, MODE_INV, MODE_IMP, MODE_ABY, MODE_INV, MODE_INV, MODE_INV, MODE_ABX, MODE_ABX, MODE_INV // $70
    .byte MODE_INV, MODE_IZX, MODE_INV, MODE_INV, MODE_ZP,  MODE_ZP,  MODE_ZP,  MODE_INV, MODE_IMP, MODE_INV, MODE_IMP, MODE_INV, MODE_ABS, MODE_ABS, MODE_ABS, MODE_INV // $80
    .byte MODE_REL, MODE_IZY, MODE_INV, MODE_INV, MODE_ZPX, MODE_ZPX, MODE_ZPY, MODE_INV, MODE_IMP, MODE_ABY, MODE_IMP, MODE_INV, MODE_INV, MODE_ABX, MODE_INV, MODE_INV // $90
    .byte MODE_IMM, MODE_IZX, MODE_IMM, MODE_INV, MODE_ZP,  MODE_ZP,  MODE_ZP,  MODE_INV, MODE_IMP, MODE_IMM, MODE_IMP, MODE_INV, MODE_ABS, MODE_ABS, MODE_ABS, MODE_INV // $A0
    .byte MODE_REL, MODE_IZY, MODE_INV, MODE_INV, MODE_ZPX, MODE_ZPX, MODE_ZPY, MODE_INV, MODE_IMP, MODE_ABY, MODE_IMP, MODE_INV, MODE_ABX, MODE_ABX, MODE_ABY, MODE_INV // $B0
    .byte MODE_IMM, MODE_IZX, MODE_INV, MODE_INV, MODE_ZP,  MODE_ZP,  MODE_ZP,  MODE_INV, MODE_IMP, MODE_IMM, MODE_IMP, MODE_INV, MODE_ABS, MODE_ABS, MODE_ABS, MODE_INV // $C0
    .byte MODE_REL, MODE_IZY, MODE_INV, MODE_INV, MODE_INV, MODE_ZPX, MODE_ZPX, MODE_INV, MODE_IMP, MODE_ABY, MODE_INV, MODE_INV, MODE_INV, MODE_ABX, MODE_ABX, MODE_INV // $D0
    .byte MODE_IMM, MODE_IZX, MODE_INV, MODE_INV, MODE_ZP,  MODE_ZP,  MODE_ZP,  MODE_INV, MODE_IMP, MODE_IMM, MODE_IMP, MODE_INV, MODE_ABS, MODE_ABS, MODE_ABS, MODE_INV // $E0
    .byte MODE_REL, MODE_IZY, MODE_INV, MODE_INV, MODE_INV, MODE_ZPX, MODE_ZPX, MODE_INV, MODE_IMP, MODE_ABY, MODE_INV, MODE_INV, MODE_INV, MODE_ABX, MODE_ABX, MODE_INV // $F0

// Variables
regA: .byte 0
regX: .byte 0
regY: .byte 0
regP: .byte 0
regS: .byte 0

listLen:   .byte 0
listIndex: .byte 0
listBuf:   .fill 64, 0

parsePos: .byte 0
inputLen: .byte 0
inputBuf: .fill 64, 0

fileNameLen: .byte 0
fileType:    .byte $50    // Default: 'P' (PRG)
fileNameBuf: .fill 32, 0
