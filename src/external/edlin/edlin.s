; src/external/edlin/edlin.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; EDLIN line-oriented text editor, ported from MS-DOS 4.00's EDLIN
; (ms-dos/v4.0/src/CMD/EDLIN/). Design/scope:
; brain/plans/2026-07-09-edlin-port-feasibility.md; phased build-out:
; brain/plans/2026-07-09-edlin-implementation-phases.md. Calls into
; Command64's own jump table (OS_API = $1000, function-selector-in-A
; convention, include/ca65/command64.inc).
;
; Phase 2: loads a filename given on the command line into the buffer
; (buffer.s, Phase 1), then runs an interactive command loop (own
; GETIN-poll line-input, mirroring src/command64/shell.asm's
; shellReadLine) dispatching to List/Page (cmds.s). "Q" is a bare-exit
; placeholder only -- real Quit-with-confirmation is Phase 3.
;
; PETSCII note: mirrors src/external/label/label.s -- ca65 has no
; equivalent to Kick's ".encoding petscii_mixed" auto-translation, so
; message strings are precomputed uppercase-ASCII/PETSCII hex bytes
; rather than quoted string literals.

.include "command64.inc"
.include "common.inc"

.import bufInit
.import bufLoadFile
.import cmdList
.import cmdPage
.import cmdDelete
.import cmdInsert
.import cmdEditLine
.import cmdQuit

.export EditBuf
.export ownLineInput

VERSION_MAJOR = '0'
VERSION_MINOR = '1'
VERSION_STAGE = '3'  ; Phase 3 verified in VICE (test section 10 deferred, task 22)
.include "build_edlin.inc"

.import __MAIN_START__

.segment "HEADER"
    .word __MAIN_START__

.segment "CODE"

; ---------------------------------------------------------------------------
; Entry point
; ---------------------------------------------------------------------------
start:
    ldx #<verMsg
    ldy #>verMsg
    lda #DOS_PRINT_STR
    jsr OS_API

    ; --- Parse filename argument out of CommandBuffer ---
    ldy ParsePos
skipToken:
    lda CommandBuffer, y
    bne skipTokenNotNull
    jmp noArgErr
skipTokenNotNull:
    iny
    cmp #' '
    bne skipToken
skipSpaces:
    lda CommandBuffer, y
    cmp #' '
    bne endSpaces
    iny
    jmp skipSpaces
endSpaces:
    cmp #0
    bne haveArg
    jmp noArgErr
haveArg:

    ; Null-terminate the filename token in place at the first trailing space.
    tya
    tax                       ; X = filename start index into CommandBuffer
    stx FilenameIdx
trimLoop:
    lda CommandBuffer, y
    beq startLoad
    cmp #' '
    bne trimNext
    lda #0
    sta CommandBuffer, y
    jmp startLoad
trimNext:
    iny
    jmp trimLoop

startLoad:
    jsr bufInit

    lda FilenameIdx
    clc
    adc #<CommandBuffer
    sta FilenamePtrLo
    lda #>CommandBuffer
    adc #0
    sta FilenamePtrHi

    ldx FilenamePtrLo
    ldy FilenamePtrHi
    jsr bufLoadFile
    bcc loadOk
    cmp #$FE
    beq loadTooLarge
    cmp #1                    ; 1/2/3 = no device / no disk / other drive
    beq loadDeviceErr         ; error -- a real device-level problem, fatal.
    cmp #2
    beq loadDeviceErr
    cmp #3
    beq loadDeviceErr
    ; Any other failure code (in practice $FF) is a generic KERNAL open
    ; failure -- almost always "file not found." Treat it as a new file:
    ; bufInit already left BufEndLo/Hi at 0, so there's nothing more to
    ; set up, just proceed with an empty buffer (per the feasibility
    ; plan's "edlin newfile.txt" create-a-new-file workflow, which Phases
    ; 1-3 never actually exercised since every test used a fixture that
    ; already existed).
    ldx #<msgNewFile
    ldy #>msgNewFile
    lda #DOS_PRINT_STR
    jsr OS_API
    jmp loadOk
loadDeviceErr:
    ldx #<msgOpenErr
    ldy #>msgOpenErr
    lda #DOS_PRINT_STR
    jsr OS_API
    jmp exit
loadTooLarge:
    ldx #<msgFileTooLarge
    ldy #>msgFileTooLarge
    lda #DOS_PRINT_STR
    jsr OS_API
    jmp exit

loadOk:
    lda #1
    sta EdCurrentLineLo
    lda #0
    sta EdCurrentLineHi

; ---------------------------------------------------------------------------
; commandLoop — prompt "*", read a command line, dispatch on the command
; letter following an optional [line1][,line2] range.
; ---------------------------------------------------------------------------
commandLoop:
    lda #'*'
    jsr KernalChROUT
    jsr ownLineInput

    ldy #0
clSkipSpaces:
    lda EditBuf, y
    cmp #' '
    bne clHaveCmdOrRange
    iny
    jmp clSkipSpaces
clHaveCmdOrRange:

    ; List/Page each call parseRange themselves (they need the range
    ; parsed fresh against their own defaults), so here we only need to
    ; peek at the eventual command letter to dispatch -- but parseRange
    ; is the only routine that knows how to skip past a range to find it,
    ; so cmdList/cmdPage each re-parse from the same start index. To
    ; decide *which* command to call in the first place, scan forward
    ; past any range ourselves using the same skip rules (digits, '.',
    ; '#', comma, spaces) without touching Line1/Line2 state.
    jsr peekCommandByte
    tax

    cpx #'L'
    bne clNotList
    jsr cmdList
    jmp commandLoop
clNotList:
    cpx #'P'
    bne clNotPage
    jsr cmdPage
    jmp commandLoop
clNotPage:
    cpx #'D'
    bne clNotDelete
    jsr cmdDelete
    jmp commandLoop
clNotDelete:
    cpx #'I'
    bne clNotInsert
    jsr cmdInsert
    jmp commandLoop
clNotInsert:
    cpx #'Q'
    bne clNotQuit
    jsr cmdQuit
    cmp #1
    beq exit
    jmp commandLoop
clNotQuit:
    cpx #0
    bne clNotBlank
    jsr cmdEditLine           ; blank command letter -- edit-line (Phase 3)
    jmp commandLoop
clNotBlank:
    ldx #<msgUnknownCmd
    ldy #>msgUnknownCmd
    lda #DOS_PRINT_STR
    jsr OS_API
    jmp commandLoop

noArgErr:
    ldx #<msgNoArg
    ldy #>msgNoArg
    lda #DOS_PRINT_STR
    jsr OS_API

exit:
    lda #DOS_EXIT
    jsr OS_API

; ---------------------------------------------------------------------------
; peekCommandByte — scan past an optional [line1][,line2] range in EditBuf
; starting at index Y (same token shapes parseLineNum accepts: a digit
; run, '.', or '#'), without touching Line1/Line2/FindTarget state, and
; return the command-letter byte found after it.
; Output: A = the command byte (0 if the line is empty at that point).
; ---------------------------------------------------------------------------
peekCommandByte:
    jsr pcbSkipNumber
    jsr pcbSkipSpaces
    lda EditBuf, y
    cmp #','
    bne pcbDone
    iny
    jsr pcbSkipSpaces
    jsr pcbSkipNumber
    jsr pcbSkipSpaces
pcbDone:
    lda EditBuf, y
    rts

pcbSkipNumber:
    lda EditBuf, y
    cmp #'.'
    beq pcbConsumeOne
    cmp #'#'
    beq pcbConsumeOne
    cmp #'0'
    bcc pcbSkipNumberDone
    cmp #'9'+1
    bcs pcbSkipNumberDone
pcbDigitLoop:
    lda EditBuf, y
    cmp #'0'
    bcc pcbSkipNumberDone
    cmp #'9'+1
    bcs pcbSkipNumberDone
    iny
    jmp pcbDigitLoop
pcbConsumeOne:
    iny
pcbSkipNumberDone:
    rts

pcbSkipSpaces:
    lda EditBuf, y
    cmp #' '
    bne pcbSkipSpacesDone
    iny
    jmp pcbSkipSpaces
pcbSkipSpacesDone:
    rts

; ---------------------------------------------------------------------------
; ownLineInput — read one CR-terminated line into EditBuf. Copies
; src/command64/shell.asm's shellReadLine pattern verbatim in structure
; (that routine is shell-internal, not reachable via OS_API, so this is a
; deliberate duplicate, not a call-out): KernalGetIn poll, PetDel
; destructive backspace, null-terminated (not CR) on completion.
; ---------------------------------------------------------------------------
ownLineInput:
    ldy #0
oliReadLoop:
    tya
    pha
oliPoll:
    jsr KernalGetIn
    beq oliPoll

    tax
    pla
    tay
    txa

    cmp #PetCr
    beq oliDoneRead

    cmp #PetDel
    bne oliStoreChar
    tya
    beq oliReadLoop
    dey
    lda #PetDel
    jsr KernalChROUT
    jmp oliReadLoop

oliStoreChar:
    jsr KernalChROUT
    txa
    sta EditBuf, y
    iny
    cpy #79
    bne oliReadLoop
oliDoneRead:
    lda #0
    sta EditBuf, y
    lda #PetCr
    jsr KernalChROUT
    rts

.segment "RODATA"

; "EDLIN V" + VERSION_MAJOR + "." + VERSION_MINOR + "." + VERSION_STAGE
; + "." + BUILD_NUMBER, same banner format as label.s/format.s.
verMsg:
    .byte $45, $44, $4C, $49, $4E, $20, $56
    .byte VERSION_MAJOR, $2E, VERSION_MINOR, $2E, VERSION_STAGE, $2E
    .byte BUILD_NUMBER
    .byte $0D, $00
; "USAGE: EDLIN <FILENAME>"
msgNoArg:
    .byte $55, $53, $41, $47, $45, $3A, $20, $45, $44, $4C, $49, $4E, $20
    .byte $3C, $46, $49, $4C, $45, $4E, $41, $4D, $45, $3E, $0D, $00
; "ERROR: COULD NOT OPEN FILE."
msgOpenErr:
    .byte $45, $52, $52, $4F, $52, $3A, $20, $43, $4F, $55, $4C, $44, $20
    .byte $4E, $4F, $54, $20, $4F, $50, $45, $4E, $20, $46, $49, $4C, $45
    .byte $2E, $0D, $00
; "ERROR: FILE TOO LARGE FOR BUFFER."
msgFileTooLarge:
    .byte $45, $52, $52, $4F, $52, $3A, $20, $46, $49, $4C, $45, $20, $54
    .byte $4F, $4F, $20, $4C, $41, $52, $47, $45, $20, $46, $4F, $52, $20
    .byte $42, $55, $46, $46, $45, $52, $2E, $0D, $00
; "NEW FILE."
msgNewFile:
    .byte $4E, $45, $57, $20, $46, $49, $4C, $45, $2E, $0D, $00
; "?"
msgUnknownCmd:
    .byte $3F, $0D, $00

.segment "BSS"
FilenameIdx:   .res 1
FilenamePtrLo: .res 1
FilenamePtrHi: .res 1
EditBuf:       .res 80
