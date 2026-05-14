// src/command64/shell.asm
// KickAssembler v5.25 - MS-DOS 4.0 shell for C64
// Core command loop: prompt, input, dispatch, built-in commands.

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
    .text "EXIT  "
    .word cmdExit
    .text "CLS   "
    .word cmdCls
    .text "ECHO  "
    .word cmdEcho
tableEnd:

// ---------------------------------------------------------------------------
// Command Shell  (loaded at $1200)
// ---------------------------------------------------------------------------
.segment CommandShell [start=$1200]

// --- Entry point ---
start:
    lda #$93                // PETSCII clear-screen character
    jsr KernalChROUT
    lda #$0E                // switch C64 to lowercase/uppercase character mode
    jsr KernalChROUT        // required for .text lowercase strings to display correctly
mainLoop:
    lda #<promptMsg
    ldy #>promptMsg
    petPrintString()

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
    jsr KernalChRIN         // screen editor echoes to screen; we just store the byte
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
    lda #<badCmdMsg
    ldy #>badCmdMsg
    petPrintString()
    lda #PetCr
    jsr KernalChROUT
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
// Output: Z=1 on match; X = entry_base + TABLE_NAME_LEN (points to handler word).
//         Z=0 on mismatch; X = entry_base (restored).
//         ParsePos = CommandBuffer index of first argument char on match.
// Clobbers: A, Y, CmpBase ($FA)
// ---------------------------------------------------------------------------
cmdCompare:
    stx CmpBase             // save entry base; restored on fail, used on match
    ldy #0
ccCmpLoop:
    // Compute table index for this position: X = CmpBase + Y
    tya
    clc
    adc CmpBase
    tax
    // Load and classify input character
    lda CommandBuffer, y
    cmp #' '
    beq ccInputSpace        // input token ended (space separator)
    cmp #0
    beq ccInputNull         // input token ended (null terminator)
    // Compare input char against table[CmpBase + Y]
    cmp tableCmd, x
    bne ccCmpFail
    iny
    cpy #TABLE_NAME_LEN
    bne ccCmpLoop
    // All TABLE_NAME_LEN chars matched.
    // X = CmpBase + Y = CmpBase + TABLE_NAME_LEN — already at handler word. ✓
    sty ParsePos
    lda #0                  // Z=1 → match
    rts
ccInputSpace:
    // X = CmpBase + Y; table[X] must be space padding here for a match
    lda tableCmd, x
    cmp #' '
    bne ccCmpFail
    // Skip any additional spaces between command name and argument
    iny
ccSkipSpaces:
    lda CommandBuffer, y
    cmp #' '
    bne ccSetMatch
    iny
    jmp ccSkipSpaces
ccInputNull:
    // X = CmpBase + Y; table[X] must be space padding here for a match
    lda tableCmd, x
    cmp #' '
    bne ccCmpFail
    // No argument — fall through to ccSetMatch
ccSetMatch:
    sty ParsePos
    // Advance X to handler word: entry_base + TABLE_NAME_LEN
    lda CmpBase
    clc
    adc #TABLE_NAME_LEN
    tax
    lda #0                  // Z=1 → match
    rts
ccCmpFail:
    ldx CmpBase             // restore entry base for sdSearchLoop's stride
    lda #1                  // Z=0 → no match
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

// ---------------------------------------------------------------------------
// String literals
// ---------------------------------------------------------------------------
promptMsg:
    .text "C64:> "
    .byte 0

badCmdMsg:
    .text "Bad command or file name"
    .byte 0
