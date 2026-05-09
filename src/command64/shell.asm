// src/command64/shell.asm
// KickAssembler v5.25 - MS-DOS 4.0 shell for C64
// Core command loop: prompt, input, dispatch, built-in commands.

.encoding "petscii_mixed"

// ---------------------------------------------------------------------------
// Command Table  (loaded at $1100)
//
// Fixed-width entries: 6-byte space-padded name + 2-byte handler address.
// Stride = TABLE_ENTRY_SIZE = 8. Table walk steps X by 8 per entry.
// ---------------------------------------------------------------------------
.const TABLE_ENTRY_SIZE = 8
.const TABLE_NAME_LEN   = 6

.segment CommandTable [start=$1100]

tableCmd:
    .text "exit  "
    .word cmdExit
    .text "cls   "
    .word cmdCls
    .text "echo  "
    .word cmdEcho
    .text "load  "
    .word cmdLoad
    .text "dir   "
    .word cmdDir
tableEnd:

// ---------------------------------------------------------------------------
// Command Shell  (loaded at $1200)
// ---------------------------------------------------------------------------
.segment CommandShell [start=$1200]

// --- Entry point ---
start:
    jsr vmmInit             // Initialize VMM and check for REU
    cmp #VMM_SUCCESS
    beq siInitOk
    
    // VMM Init failed (No REU found)
    lda #<noReuMsg
    ldy #>noReuMsg
    jsr petPrintString
    // We proceed anyway for now, but external programs using VMM will fail.
    
siInitOk:
    lda #$93                // PETSCII clear-screen character
    jsr KernalChROUT
    lda #$0E                // switch C64 to lowercase/uppercase character mode
    jsr KernalChROUT        // required for .text lowercase strings to display correctly
mainLoop:
    lda #<promptMsg
    ldy #>promptMsg
    jsr petPrintString

    jsr shellReadLine       // screen editor echoes input and advances cursor on RETURN

    jsr shellDispatch
    jmp mainLoop

// ---------------------------------------------------------------------------
// shellReadLine
// Reads characters via CHRIN into CommandBuffer until CR or 79 chars.
// Echoes each character. Writes $00 null terminator. Sets CommandLen.
// Clobbers: A, Y
// ---------------------------------------------------------------------------
shellReadLine:
    ldy #0
rlReadLoop:
    tya                     // KernalGetIn may clobber Y; preserve it
    pha
rlPoll:
    jsr KernalGetIn         // wait for char without screen editor (raw input)
    beq rlPoll              // GETIN is non-blocking; loop until key pressed
    
    tax                     // save character to X (KernalChROUT preserves X)
    jsr KernalChROUT        // manually echo the character just read
    
    pla                     // pull Y to A
    tay                     // restore Y
    txa                     // restore character to A from X
    
    cmp #PetCr
    beq rlDoneRead
    
    sta CommandBuffer, y
    iny
    cpy #79                 // reserve index 79 for null terminator
    bne rlReadLoop
rlDoneRead:
    lda #0
    sta CommandBuffer, y    // write $00 null terminator (not $0D)
    sty CommandLen
    rts


// ---------------------------------------------------------------------------
// shellDispatch
// Walk command table for a match against CommandBuffer.
// Match: load handler address into zero-page vector, jump through it.
// No match: print error message.
// Clobbers: A, X, Y, HandlerVecLo, HandlerVecHi, ParsePos
// ---------------------------------------------------------------------------
shellDispatch:
    ldy #0
sdSkipLeading:
    lda CommandBuffer, y
    cmp #' '
    bne sdCheckEmpty
    iny
    jmp sdSkipLeading
sdCheckEmpty:
    cmp #0                  // if null, the line is empty or all spaces
    beq sdExitDispatch      // early exit (NOP)
    
    sty ParsePos            // save start of command name for cmdCompare
    ldx #0
sdSearchLoop:
    cpx #(tableEnd - tableCmd)
    bcs sdBadCmd

    jsr cmdCompare          // Z=1 on match; X advanced to handler word on match
    beq sdFoundCmd

    txa
    clc
    adc #TABLE_ENTRY_SIZE   // advance X to next table entry
    tax
    jmp sdSearchLoop

sdFoundCmd:
    lda tableCmd, x         // handler address low byte
    sta HandlerVecLo
    lda tableCmd+1, x       // handler address high byte
    sta HandlerVecHi
    jmp (HandlerVecLo)      // jump to handler; handler rts returns to mainLoop

sdBadCmd:
    // Try external command search
    // Extract first token from CommandBuffer starting at ParsePos
    ldy ParsePos
    lda CommandBuffer, y
    cmp #'$'                // Reject names starting with $ (avoids directory load crash)
    beq sdRealBadCmd
    
    sty TempLo
sdExtScan:
    lda CommandBuffer, y
    beq sdExtFoundEnd
    cmp #' '
    beq sdExtFoundEnd
    iny
    jmp sdExtScan
sdExtFoundEnd:
    tya
    sec
    sbc TempLo
    tax                     // X = length
    
    lda #<CommandBuffer
    clc
    adc TempLo
    sta NamePtrLo
    lda #>CommandBuffer
    adc #0
    sta NamePtrHi
    
    // Check if it exists as .prg
    lda NamePtrLo
    ldy NamePtrHi
    // X = length
    jsr findFile
    bcs sdRealBadCmd        // Not found, print error
    
    // Found it! Load to UserProgStart ($2000)
    lda #1
    sta SpecificLoad
    lda #<UserProgStart
    sta HexValLo
    lda #>UserProgStart
    sta HexValHi
    
    lda NamePtrLo
    ldy NamePtrHi
    // X = length from findFile
    jsr shellLoadPrg
    bcs sdRealBadCmd
    
    // EXECUTE
    jsr UserProgStart
    rts

sdRealBadCmd:
    lda #<badCmdMsg
    ldy #>badCmdMsg
    jsr petPrintString
    lda #PetCr
    jsr KernalChROUT
sdExitDispatch:
    rts

// ---------------------------------------------------------------------------
// cmdCompare  [subroutine]
// Compare CommandBuffer against the TABLE_NAME_LEN-byte name at tableCmd+X.
//
// Design: X is NEVER walked — it always holds the entry base offset.
//         CmpBase ($FA) saves X so it can be restored on mismatch.
//         Table bytes are addressed as tableCmd[CmpBase + Y] each iteration.
//         On match, X is set to CmpBase + TABLE_NAME_LEN (handler word offset).
//         On mismatch, X is restored to CmpBase so sdSearchLoop's stride is clean.
//
// Input:  X = byte offset of entry start in tableCmd
//         ParsePos = buffer index of command start
// Output: Z=1 on match; X = entry_base + TABLE_NAME_LEN (points to handler word).
//         Z=0 on mismatch; X = entry_base (restored).
//         ParsePos = CommandBuffer index of first argument char on match.
// Clobbers: A, Y, CmpBase ($FA)
// ---------------------------------------------------------------------------
cmdCompare:
    stx CmpBase             // save entry base; restored on fail, used on match
    ldy ParsePos            // start comparison from first non-space character
ccCmpLoop:
    // Compute table index for this position: X = CmpBase + (Y - StartPos)
    tya
    sec
    sbc ParsePos            // A = current offset from command start
    tax                     // save offset to X temporarily
    
    // Check if we've compared all TABLE_NAME_LEN characters
    cpx #TABLE_NAME_LEN
    beq ccSetMatch          // matched all fixed-width chars!

    // Compute table index: CmpBase + offset
    txa
    clc
    adc CmpBase
    tax                     // X = absolute index in tableCmd

    // Load and classify input character
    lda CommandBuffer, y
    cmp #' '
    beq ccInputSpace        // input token ended (space separator)
    cmp #0
    beq ccInputNull         // input token ended (null terminator)
    
    // Compare input char against tableCmd, x
    cmp tableCmd, x
    bne ccCmpFail
    
    iny
    jmp ccCmpLoop

ccInputSpace:
    // Input ended early (space). Table must be space-padded here.
    lda tableCmd, x
    cmp #' '
    bne ccCmpFail
    // Success - skip any more spaces and set match
    iny
ccSkipSpaces:
    lda CommandBuffer, y
    cmp #' '
    bne ccSetMatch
    iny
    jmp ccSkipSpaces

ccInputNull:
    // Input ended early (null). Table must be space-padded here.
    lda tableCmd, x
    cmp #' '
    bne ccCmpFail
    // Success - fall through to ccSetMatch

ccSetMatch:
    sty ParsePos            // save pointer to first arg char (or null)
    lda CmpBase
    clc
    adc #TABLE_NAME_LEN
    tax                     // X = index of handler address in tableCmd
    lda #0                  // Z=1 (Match)
    rts

ccCmpFail:
    ldx CmpBase
    lda #1                  // Z=0 (No Match)
    rts

// ---------------------------------------------------------------------------
// Built-in command handlers
// Each handler performs its action and returns via rts → mainLoop.
// ---------------------------------------------------------------------------

// EXIT — return to BASIC warm start
// $E37B is the BASIC warm-start entry in C64 ROM: clears state, prints READY., enters command mode.
// If BASIC ROM has been banked out or overwritten, this will crash — acceptable per project decision.
cmdExit:
    jmp $E37B

// CLS — clear screen and restore lowercase mode
cmdCls:
    lda #$93
    jsr KernalChROUT
    lda #$0E                // restore lowercase mode (clear resets character set)
    jsr KernalChROUT
    rts

// ECHO — print CommandBuffer from ParsePos onward
cmdEcho:
    ldy ParsePos
echoLoop:
    lda CommandBuffer, y
    beq echoDone
    jsr KernalChROUT
    iny
    jmp echoLoop
echoDone:
    lda #PetCr
    jsr KernalChROUT
    rts

// LOAD — load a .PRG from disk [address]
cmdLoad:
    ldy ParsePos
    lda CommandBuffer, y
    beq clNoArgs
    
    // Save start position of name
    sty TempLo
clScanName:
    lda CommandBuffer, y
    beq clDoneScan
    cmp #' '
    beq clDoneScan
    iny
    jmp clScanName
clDoneScan:
    sty TempHi              // Save end position
    
    // Calculate length
    tya
    sec
    sbc TempLo
    pha                     // Push length to stack
    
    // Calculate pointer: CommandBuffer + TempLo
    lda #<CommandBuffer
    clc
    adc TempLo
    sta NamePtrLo
    lda #>CommandBuffer
    adc #0
    sta NamePtrHi
    
    // Check for optional address
    ldy TempHi
clSkipSpaces:
    lda CommandBuffer, y
    beq clHeaderLoad
    cmp #' '
    bne clFoundAddr
    iny
    jmp clSkipSpaces
clFoundAddr:
    jsr parseHex
    bcs clHeaderLoad        // Invalid hex -> use header
    lda #1
    sta SpecificLoad
    jmp clDoLoad
clHeaderLoad:
    lda #0
    sta SpecificLoad
clDoLoad:
    lda NamePtrLo
    ldy NamePtrHi
    pla                     // Pull length to X
    tax
    jsr findFile            // Normalize, append .prg, check disk
    bcs clError             // Not found or error
    
    // findFile returns updated length in X
    lda NamePtrLo
    ldy NamePtrHi
    jsr shellLoadPrg
    bcs clError
    rts
clNoArgs:
    lda #<noFileMsg
    ldy #>noFileMsg
    jsr petPrintString
    rts
clError:
    lda #<loadErrMsg
    ldy #>loadErrMsg
    jsr petPrintString
    rts

// DIR — list directory contents (stub)
cmdDir:
    lda #<dirStubMsg
    ldy #>dirStubMsg
    jsr petPrintString
    rts

// ---------------------------------------------------------------------------
// String literals
// ---------------------------------------------------------------------------
promptMsg:
    .text "C64:> "
    .byte 0

badCmdMsg:
    .text "Bad command or file name"
    .byte 0

dirStubMsg:
    .text "Directory listing not yet implemented"
    .byte $0D, 0

noFileMsg:
    .text "File name required"
    .byte 0

loadErrMsg:
    .text "Load error"
    .byte 0

noReuMsg:
    .text "Warning: No REU detected. VMM disabled."
    .byte $0D, 0
