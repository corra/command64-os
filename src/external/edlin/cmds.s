; src/external/edlin/cmds.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; Phase 2: List/Page commands, line-number/range argument parsing, and the
; shared line-display routine. Design rationale, ZP layout, and the exact
; List/Page default-range semantics (ported from the real MS-DOS EDLIN
; source's LIST/PAGER routines) are documented in
; brain/plans/2026-07-09-edlin-implementation-phases.md, Phase 2 detail.

.include "command64.inc"
.include "common.inc"

.import findLine
.import bufReadWindow
.import scanWindow
.import fallbackBuf
.import bufWriteBytes
.import bufOpenHole
.import bufCloseHole
.import HoleSizeLo
.import HoleSizeHi
.import EditBuf
.import ownLineInput

.export cmdList
.export cmdPage
.export cmdDelete
.export cmdInsert
.export cmdEditLine
.export cmdQuit
.export printDec16

.segment "CODE"

; ---------------------------------------------------------------------------
; parseLineNum — parse one line-number token: a decimal run, '.' (current
; line), or '#' (last+1, via a full-buffer findLine scan).
; Input:  Y = index into EditBuf to start at.
; Output: A = 1 if a value was parsed (0 if not present), FindTargetLo/Hi =
;         the value (only meaningful if A=1), Y = advanced past the token.
; ---------------------------------------------------------------------------
parseLineNum:
    lda EditBuf, y
    cmp #'.'
    beq plnDot
    cmp #'#'
    beq plnHash
    cmp #'0'
    bcc plnNone
    cmp #'9'+1
    bcs plnNone

    lda #0
    sta FindTargetLo
    sta FindTargetHi
plnDigitLoop:
    lda EditBuf, y
    cmp #'0'
    bcc plnDigitsDone
    cmp #'9'+1
    bcs plnDigitsDone
    sec
    sbc #'0'
    pha                     ; save digit value

    ; FindTarget = FindTarget*10 + digit, via x*10 = x*8 + x*2
    lda FindTargetLo
    asl
    sta TmpLenLo            ; TmpLen = x*2 (lo)
    lda FindTargetHi
    rol
    sta TmpLenHi            ; TmpLen = x*2 (hi)
    lda TmpLenLo
    sta EndPtrLo            ; stash x*2
    lda TmpLenHi
    sta EndPtrHi
    asl TmpLenLo
    rol TmpLenHi            ; TmpLen = x*4
    asl TmpLenLo
    rol TmpLenHi            ; TmpLen = x*8
    lda TmpLenLo
    clc
    adc EndPtrLo
    sta FindTargetLo        ; FindTarget = x*8 + x*2
    lda TmpLenHi
    adc EndPtrHi
    sta FindTargetHi

    pla                     ; restore digit
    clc
    adc FindTargetLo
    sta FindTargetLo
    bcc plnNoCarry
    inc FindTargetHi
plnNoCarry:
    iny
    jmp plnDigitLoop
plnDigitsDone:
    lda #1
    rts

plnDot:
    iny
    lda EdCurrentLineLo
    sta FindTargetLo
    lda EdCurrentLineHi
    sta FindTargetHi
    lda #1
    rts

plnHash:
    iny
    tya
    pha                     ; preserve EditBuf index across the findLine call
    lda #$FF
    sta FindTargetLo
    sta FindTargetHi
    jsr findLine            ; full-buffer scan -> CurLineLo/Hi = last+1
    lda CurLineLo
    sta FindTargetLo
    lda CurLineHi
    sta FindTargetHi
    pla
    tay
    lda #1
    rts

plnNone:
    lda #0
    rts

; ---------------------------------------------------------------------------
; parseRange — parse "[line1][,line2]" starting at EditBuf index Y (spaces
; before/around the number(s)/comma are skipped).
; Output: Line1Lo/Hi + Line1Given, Line2Given (line2's value, if given, is
;         left in FindTargetLo/Hi -- see Phase 2 detail on why callers must
;         consume it before making another findLine call). Y = index of the
;         first non-space byte after the range (the command letter).
; ---------------------------------------------------------------------------
parseRange:
    jsr prSkipSpaces
    jsr parseLineNum
    cmp #0
    beq prNoLine1
    lda FindTargetLo
    sta Line1Lo
    lda FindTargetHi
    sta Line1Hi
    lda #1
    sta Line1Given
    jmp prCheckComma
prNoLine1:
    lda #0
    sta Line1Given
prCheckComma:
    jsr prSkipSpaces
    lda EditBuf, y
    cmp #','
    bne prNoLine2           ; no comma at all -> line2 not given (must still
                             ; clear Line2Given -- it's stale ZP scratch left
                             ; over from whatever command ran before this one)
    iny
    jsr prSkipSpaces
    jsr parseLineNum
    cmp #0
    beq prNoLine2
    lda #1
    sta Line2Given
    jmp prSkipSpaces2
prNoLine2:
    lda #0
    sta Line2Given
prSkipSpaces2:
    jsr prSkipSpaces
    rts

prSkipSpaces:
    lda EditBuf, y
    cmp #' '
    bne prSkipSpacesDone
    iny
    jmp prSkipSpaces
prSkipSpacesDone:
    rts

; ---------------------------------------------------------------------------
; cmdList — "L" command. Read-only: never touches EdCurrentLine*.
; ---------------------------------------------------------------------------
cmdList:
    ldy #0                  ; parseRange always re-parses from EditBuf's start
    jsr parseRange

    ; Resolve line1: given value, or max(1, EdCurrentLine - 11).
    lda Line1Given
    bne clHaveLine1
    lda EdCurrentLineLo
    sec
    sbc #11
    sta Line1Lo
    lda EdCurrentLineHi
    sbc #0
    sta Line1Hi
    bcc clClampLine1        ; borrow -> negative -> clamp to 1
    lda Line1Lo
    ora Line1Hi
    bne clHaveLine1         ; nonzero and no borrow -> keep it
clClampLine1:
    lda #1
    sta Line1Lo
    lda #0
    sta Line1Hi
clHaveLine1:

    ; Resolve count: line2 given -> (line2 - line1 + 1); else a full screen.
    ; Must read FindTargetLo/Hi (line2, if given) before any findLine call
    ; below clobbers it -- see parseRange's output contract.
    lda Line2Given
    beq clDefaultCount
    ; count = FindTarget - Line1 + 1. Check the subtraction's own borrow
    ; (not the sign of the result after +1, which isn't reliable) to
    ; detect line2 < line1.
    lda FindTargetLo
    sec
    sbc Line1Lo
    sta LineCountLo
    lda FindTargetHi
    sbc Line1Hi
    sta LineCountHi
    bcc clBadRange          ; borrow -> line2 < line1 -> bad range
    lda LineCountLo
    clc
    adc #1
    sta LineCountLo
    bcc clHaveCount
    inc LineCountHi
    jmp clHaveCount
clDefaultCount:
    lda #<(SCREEN_LINES - 1)
    sta LineCountLo
    lda #0
    sta LineCountHi
clHaveCount:

    lda Line1Lo
    sta FindTargetLo
    lda Line1Hi
    sta FindTargetHi
    jsr findLine
    lda CurLineLo
    cmp FindTargetLo
    bne clOutOfRange
    lda CurLineHi
    cmp FindTargetHi
    bne clOutOfRange

    jsr displayLines
    rts

clBadRange:
clOutOfRange:
    rts

; ---------------------------------------------------------------------------
; cmdPage — "P" command. Like List, but repositions EdCurrentLine to the
; end of the displayed range.
; ---------------------------------------------------------------------------
cmdPage:
    ldy #0                  ; parseRange always re-parses from EditBuf's start
    jsr parseRange

    ; Resolve line1: given value, or EdCurrentLine+1 (or 1 if EdCurrentLine=1).
    lda Line1Given
    bne cpHaveLine1
    lda EdCurrentLineLo
    cmp #1
    bne cpNotOne
    lda EdCurrentLineHi
    bne cpNotOne
    lda #1
    sta Line1Lo
    lda #0
    sta Line1Hi
    jmp cpHaveLine1
cpNotOne:
    lda EdCurrentLineLo
    clc
    adc #1
    sta Line1Lo
    lda EdCurrentLineHi
    adc #0
    sta Line1Hi
cpHaveLine1:

    ; Resolve line2: given value (left in FindTargetLo/Hi by parseRange,
    ; not clamped against EOF -- an out-of-range explicit line2 is treated
    ; the same as List's out-of-range case, not silently clamped like the
    ; original PAGER; see Phase 2 detail), or line1 + (SCREEN_LINES - 2).
    lda Line2Given
    bne cpHaveLine2Value
    lda Line1Lo
    clc
    adc #(SCREEN_LINES - 2)
    sta FindTargetLo
    lda Line1Hi
    adc #0
    sta FindTargetHi
cpHaveLine2Value:
    lda FindTargetLo
    sta Line2ValLo
    lda FindTargetHi
    sta Line2ValHi

    ; count = line2 - line1 + 1; bail if line2 < line1.
    lda Line2ValLo
    sec
    sbc Line1Lo
    sta LineCountLo
    lda Line2ValHi
    sbc Line1Hi
    sta LineCountHi
    bmi cpBadRange
    lda LineCountLo
    clc
    adc #1
    sta LineCountLo
    bcc cpCountOk
    inc LineCountHi
cpCountOk:

    lda Line1Lo
    sta FindTargetLo
    lda Line1Hi
    sta FindTargetHi
    jsr findLine
    lda CurLineLo
    cmp FindTargetLo
    bne cpOutOfRange
    lda CurLineHi
    cmp FindTargetHi
    bne cpOutOfRange

    jsr displayLines

    ; Reposition EdCurrentLine to line2 (clamped to whatever findLine
    ; actually reaches, e.g. EOF, rather than trusting the unclamped
    ; requested value).
    lda Line2ValLo
    sta FindTargetLo
    lda Line2ValHi
    sta FindTargetHi
    jsr findLine
    lda CurLineLo
    sta EdCurrentLineLo
    lda CurLineHi
    sta EdCurrentLineHi
    rts

cpBadRange:
cpOutOfRange:
    rts

; ---------------------------------------------------------------------------
; displayLines — print LineCountLo/Hi lines starting at byte offset
; CurPtrLo/Hi, whose first line is numbered CurLineLo/Hi. Stops early if
; the buffer runs out, or if the user answers anything but Y/y to a
; "Continue (Y/N)?" prompt shown every (SCREEN_LINES-1) printed lines.
; ---------------------------------------------------------------------------
displayLines:
    lda #0
    sta PageRowCount
dlLoop:
    lda CurPtrHi
    cmp BufEndHi
    bcc dlHaveData
    bne dlStop
    lda CurPtrLo
    cmp BufEndLo
    bcs dlStop
dlHaveData:
    lda LineCountLo
    ora LineCountHi
    beq dlStop

    lda CurLineLo
    sta ScanPtrLo
    lda CurLineHi
    sta ScanPtrHi
    jsr printDec16
    ldx #':'
    lda #DOS_PRINT_CHAR
    jsr OS_API
    ldx #' '
    lda #DOS_PRINT_CHAR
    jsr OS_API

    jsr displayLineText     ; prints line text, advances CurPtrLo/Hi

    lda #PetCr
    jsr KernalChROUT

    inc CurLineLo
    bne dlNoLineCarry
    inc CurLineHi
dlNoLineCarry:

    lda LineCountLo
    bne dlDecLo
    dec LineCountHi
dlDecLo:
    dec LineCountLo

    inc PageRowCount
    lda PageRowCount
    cmp #(SCREEN_LINES - 1)
    bne dlLoop
    ldx #<msgContinue
    ldy #>msgContinue
    jsr promptYN
    cmp #0
    beq dlStop
    lda #0
    sta PageRowCount
    jmp dlLoop
dlStop:
    rts

; ---------------------------------------------------------------------------
; displayLineText — print bytes from CurPtrLo/Hi up to (not including) the
; next $0A or BufEnd, then advance CurPtrLo/Hi past the terminator (or to
; BufEnd, for an unterminated final line).
; ---------------------------------------------------------------------------
displayLineText:
    lda BufIsVmm
    bne dltVmm
    jmp dltRam

dltVmm:
    lda CurPtrLo
    sta WindowBaseOffLo
    lda CurPtrHi
    sta WindowBaseOffHi
dltVmmRefill:
    jsr bufReadWindow
    lda WindowValidLen
    beq dltVmmDone
    ldy #0
dltVmmByteLoop:
    cpy WindowValidLen
    beq dltVmmWindowExhausted
    lda scanWindow, y
    cmp #$0A
    beq dltVmmFoundLf
    tax
    lda #DOS_PRINT_CHAR
    jsr OS_API
    iny
    jmp dltVmmByteLoop
dltVmmFoundLf:
    tya
    clc
    adc #1
    clc
    adc WindowBaseOffLo
    sta CurPtrLo
    lda WindowBaseOffHi
    adc #0
    sta CurPtrHi
    rts
dltVmmWindowExhausted:
    lda WindowBaseOffLo
    clc
    adc WindowValidLen
    sta WindowBaseOffLo
    lda WindowBaseOffHi
    adc #0
    sta WindowBaseOffHi
    lda WindowBaseOffHi
    cmp BufEndHi
    bcc dltVmmRefill
    bne dltVmmDone
    lda WindowBaseOffLo
    cmp BufEndLo
    bcc dltVmmRefill
dltVmmDone:
    lda BufEndLo
    sta CurPtrLo
    lda BufEndHi
    sta CurPtrHi
    rts

dltRam:
    lda #<fallbackBuf
    clc
    adc CurPtrLo
    sta ScanPtrLo
    lda #>fallbackBuf
    adc CurPtrHi
    sta ScanPtrHi
    lda #<fallbackBuf
    clc
    adc BufEndLo
    sta EndPtrLo
    lda #>fallbackBuf
    adc BufEndHi
    sta EndPtrHi
dltRamLoop:
    lda ScanPtrLo
    cmp EndPtrLo
    bne dltRamCont
    lda ScanPtrHi
    cmp EndPtrHi
    beq dltRamEof
dltRamCont:
    ldy #0
    lda (ScanPtrLo), y
    cmp #$0A
    beq dltRamFoundLf
    tax
    lda #DOS_PRINT_CHAR
    jsr OS_API
    inc ScanPtrLo
    bne dltRamLoop
    inc ScanPtrHi
    jmp dltRamLoop
dltRamFoundLf:
    lda ScanPtrLo
    clc
    adc #1
    sta TmpLenLo
    lda ScanPtrHi
    adc #0
    sta TmpLenHi
    sec
    lda TmpLenLo
    sbc #<fallbackBuf
    sta CurPtrLo
    lda TmpLenHi
    sbc #>fallbackBuf
    sta CurPtrHi
    rts
dltRamEof:
    lda BufEndLo
    sta CurPtrLo
    lda BufEndHi
    sta CurPtrHi
    rts

; ---------------------------------------------------------------------------
; promptYN — print the message at X/Y, then poll for a Y/N keypress.
; Output: A = 1 for yes, 0 for no. Checks both $59 and $79 for 'y' --
; mirrors format.s's confirmDestructive (some keyboard mapping modes
; deliver the shifted byte instead). Generalized from Phase 2's
; promptContinue (which only ever printed msgContinue) so Phase 3's Quit
; can reuse the same poll logic with its own prompt string.
; ---------------------------------------------------------------------------
promptYN:
    lda #DOS_PRINT_STR
    jsr OS_API
pcPoll:
    jsr KernalGetIn
    beq pcPoll
    pha
    jsr KernalChROUT
    lda #PetCr
    jsr KernalChROUT
    pla
    cmp #$59
    beq pcYes
    cmp #$79
    beq pcYes
    lda #0
    rts
pcYes:
    lda #1
    rts

; ---------------------------------------------------------------------------
; printDec16 — print a 16-bit value as fixed 5-digit decimal (leading
; zeros included). Input: ScanPtrLo/Hi = value (destroyed). Also destroys
; TmpLenLo/Hi, PdTableIdx, PdDigit. Promoted from Phase 1's temporary
; debug-dump helper -- List/Page need it permanently for line-number
; prefixes, so it lives here now rather than being deleted.
; ---------------------------------------------------------------------------
printDec16:
    lda #0
    sta PdTableIdx
pd16Digit:
    lda #0
    sta PdDigit
    ldx PdTableIdx
pd16SubLoop:
    lda placeValues+1, x
    sta TmpLenHi
    lda placeValues, x
    sta TmpLenLo

    lda ScanPtrHi
    cmp TmpLenHi
    bcc pd16NoSub
    bne pd16DoSub
    lda ScanPtrLo
    cmp TmpLenLo
    bcc pd16NoSub
pd16DoSub:
    lda ScanPtrLo
    sec
    sbc TmpLenLo
    sta ScanPtrLo
    lda ScanPtrHi
    sbc TmpLenHi
    sta ScanPtrHi
    inc PdDigit
    jmp pd16SubLoop
pd16NoSub:
    lda PdDigit
    clc
    adc #'0'
    tax
    lda #DOS_PRINT_CHAR
    jsr OS_API

    lda PdTableIdx
    clc
    adc #2
    sta PdTableIdx
    cmp #10
    bne pd16Digit
    rts

; ---------------------------------------------------------------------------
; cmdDelete — "D" command. [line1][,line2]D, defaults to current line.
; Ground truth: EDLCMD1.ASM DELETE (line 448) -- Current becomes line1
; after deletion (POP Current in the original).
; ---------------------------------------------------------------------------
cmdDelete:
    ldy #0
    jsr parseRange

    lda Line1Given
    bne cdHaveLine1
    lda EdCurrentLineLo
    sta Line1Lo
    lda EdCurrentLineHi
    sta Line1Hi
cdHaveLine1:

    lda Line2Given
    bne cdHaveLine2
    lda Line1Lo
    sta Line2ValLo
    lda Line1Hi
    sta Line2ValHi
    jmp cdRangeCheck
cdHaveLine2:
    lda FindTargetLo
    sta Line2ValLo
    lda FindTargetHi
    sta Line2ValHi
cdRangeCheck:
    lda Line2ValLo
    sec
    sbc Line1Lo
    lda Line2ValHi
    sbc Line1Hi
    bcc cdBadRange

    lda Line1Lo
    sta FindTargetLo
    lda Line1Hi
    sta FindTargetHi
    jsr findLine
    lda CurLineLo
    cmp FindTargetLo
    bne cdOutOfRange
    lda CurLineHi
    cmp FindTargetHi
    bne cdOutOfRange

    lda CurPtrLo
    sta DelStartLo
    lda CurPtrHi
    sta DelStartHi
    lda Line1Lo
    sta DelLineLo
    lda Line1Hi
    sta DelLineHi

    lda Line2ValLo
    clc
    adc #1
    sta FindTargetLo
    lda Line2ValHi
    adc #0
    sta FindTargetHi
    jsr findLine            ; CurPtrLo/Hi = one past the deleted range

    lda CurPtrLo
    sec
    sbc DelStartLo
    sta HoleSizeLo
    lda CurPtrHi
    sbc DelStartHi
    sta HoleSizeHi

    lda DelStartLo
    sta CurPtrLo
    lda DelStartHi
    sta CurPtrHi
    jsr bufCloseHole

    lda DelLineLo
    sta EdCurrentLineLo
    lda DelLineHi
    sta EdCurrentLineHi
    rts

cdBadRange:
cdOutOfRange:
    rts

; ---------------------------------------------------------------------------
; cmdInsert — "I" command. [line]I, opens a hole per typed line, reads
; lines until a blank line is entered. Ground truth: EDLIN.ASM INSERT
; (line 1366) -- blank-line-terminates is a deliberate scope cut from the
; original's Ctrl-Z/EOF termination (see Phase 3 detail in the phases plan).
; ---------------------------------------------------------------------------
cmdInsert:
    ldy #0
    jsr parseRange
    lda Line2Given
    beq ciOk
    rts
ciOk:
    lda Line1Given
    bne ciHaveLine1
    lda EdCurrentLineLo
    sta Line1Lo
    lda EdCurrentLineHi
    sta Line1Hi
ciHaveLine1:
    lda Line1Lo
    sta FindTargetLo
    lda Line1Hi
    sta FindTargetHi
    jsr findLine
    lda CurLineLo
    cmp FindTargetLo
    beq ciRangeOk
    jmp ciOutOfRange
ciRangeOk:
    lda CurLineHi
    cmp FindTargetHi
    beq ciLoop
    jmp ciOutOfRange

ciLoop:
    lda Line1Lo
    sta ScanPtrLo
    lda Line1Hi
    sta ScanPtrHi
    jsr printDec16
    ldx #':'
    lda #DOS_PRINT_CHAR
    jsr OS_API
    ldx #' '
    lda #DOS_PRINT_CHAR
    jsr OS_API

    jsr ownLineInput

    ldy #0
ciLenLoop:
    lda EditBuf, y
    beq ciLenDone
    iny
    jmp ciLenLoop
ciLenDone:
    sty InsLineLen
    lda InsLineLen
    bne ciHaveText
    jmp ciEnd

ciHaveText:
    ldy InsLineLen
    lda #$0A
    sta EditBuf, y
    lda InsLineLen
    clc
    adc #1
    sta HoleSizeLo
    lda #0
    adc #0
    sta HoleSizeHi

    jsr bufOpenHole
    bcc ciWriteOk
    ldx #<msgBufferFull
    ldy #>msgBufferFull
    lda #DOS_PRINT_STR
    jsr OS_API
    jmp ciEnd

ciWriteOk:
    ldx #<EditBuf
    ldy #>EditBuf
    lda HoleSizeLo
    jsr bufWriteBytes

    lda CurPtrLo
    clc
    adc HoleSizeLo
    sta CurPtrLo
    lda CurPtrHi
    adc #0
    sta CurPtrHi

    inc Line1Lo
    bne ciLoop
    inc Line1Hi
    jmp ciLoop

ciEnd:
    lda Line1Lo
    sta EdCurrentLineLo
    lda Line1Hi
    sta EdCurrentLineHi
    rts

ciOutOfRange:
    rts

; ---------------------------------------------------------------------------
; cmdEditLine — blank command letter (DOS EDLIN's NOCOM). Positions the
; current line and, if a non-blank replacement is typed, replaces it via
; close-hole/open-hole. Ground truth: EDLCMD1.ASM NOCOM (line 618).
; ---------------------------------------------------------------------------
cmdEditLine:
    ldy #0
    jsr parseRange
    lda Line2Given
    beq ceParamsOk
    rts
ceParamsOk:
    lda Line1Given
    bne ceUseLine1
    lda EdCurrentLineLo
    clc
    adc #1
    sta Line1Lo
    lda EdCurrentLineHi
    adc #0
    sta Line1Hi
ceUseLine1:
    lda Line1Lo
    sta FindTargetLo
    lda Line1Hi
    sta FindTargetHi
    jsr findLine

    lda CurLineLo
    sta EdCurrentLineLo
    lda CurLineHi
    sta EdCurrentLineHi

    lda CurPtrHi
    cmp BufEndHi
    bne ceHaveData
    lda CurPtrLo
    cmp BufEndLo
    bne ceHaveData
    rts                      ; target is at/past EOF -- nothing to show/edit

ceHaveData:
    lda CurPtrLo
    sta SavedOffsetLo
    lda CurPtrHi
    sta SavedOffsetHi

    lda CurLineLo
    sta ScanPtrLo
    lda CurLineHi
    sta ScanPtrHi
    jsr printDec16
    ldx #':'
    lda #DOS_PRINT_CHAR
    jsr OS_API
    ldx #' '
    lda #DOS_PRINT_CHAR
    jsr OS_API

    jsr displayLineText      ; echoes old text, advances CurPtrLo/Hi
    lda #PetCr
    jsr KernalChROUT

    lda CurPtrLo
    sec
    sbc SavedOffsetLo
    sta OldLineLenLo
    lda CurPtrHi
    sbc SavedOffsetHi
    sta OldLineLenHi

    ; if displayLineText stopped at BufEnd (unterminated last line, no LF
    ; consumed), OldLineLen is already correct as-is -- only subtract 1
    ; when it actually stopped on an LF.
    lda CurPtrLo
    cmp BufEndLo
    bne ceHadLf
    lda CurPtrHi
    cmp BufEndHi
    beq ceLenDone
ceHadLf:
    lda OldLineLenLo
    sec
    sbc #1
    sta OldLineLenLo
    lda OldLineLenHi
    sbc #0
    sta OldLineLenHi
ceLenDone:

    jsr ownLineInput
    ldy #0
ceLenLoop:
    lda EditBuf, y
    beq ceLenLoopDone
    iny
    jmp ceLenLoop
ceLenLoopDone:
    sty InsLineLen
    lda InsLineLen
    bne ceReplace
    rts                      ; blank -- no change, EdCurrentLine already set

ceReplace:
    lda SavedOffsetLo
    sta CurPtrLo
    lda SavedOffsetHi
    sta CurPtrHi
    lda OldLineLenLo
    clc
    adc #1
    sta HoleSizeLo
    lda OldLineLenHi
    adc #0
    sta HoleSizeHi
    jsr bufCloseHole

    ldy InsLineLen
    lda #$0A
    sta EditBuf, y
    lda SavedOffsetLo
    sta CurPtrLo
    lda SavedOffsetHi
    sta CurPtrHi
    lda InsLineLen
    clc
    adc #1
    sta HoleSizeLo
    lda #0
    adc #0
    sta HoleSizeHi
    jsr bufOpenHole
    bcc ceWriteOk
    ldx #<msgBufferFull
    ldy #>msgBufferFull
    lda #DOS_PRINT_STR
    jsr OS_API
    rts                      ; old line already removed -- see Phase 3 detail
ceWriteOk:
    ldx #<EditBuf
    ldy #>EditBuf
    lda HoleSizeLo
    jsr bufWriteBytes
    rts

; ---------------------------------------------------------------------------
; cmdQuit — "Q" command. Prompts "Abort edit (Y/N)?"; the caller (edlin.s)
; decides whether to exit based on the returned A (1 = yes, 0 = no), same
; convention promptYN already uses. Ground truth: EDLCMD2.ASM QUIT (line
; 876) -- simplified to one prompt/one answer rather than DOS's
; reprompt-forever loop, matching promptYN's existing convention.
; ---------------------------------------------------------------------------
cmdQuit:
    ldx #<msgAbortEdit
    ldy #>msgAbortEdit
    jsr promptYN
    rts

.segment "RODATA"

placeValues:
    .word 10000, 1000, 100, 10, 1

; "CONTINUE (Y/N)? "
msgContinue:
    .byte $43, $4F, $4E, $54, $49, $4E, $55, $45, $20, $28, $59, $2F, $4E
    .byte $29, $3F, $20, $00

; "ABORT EDIT (Y/N)? "
msgAbortEdit:
    .byte $41, $42, $4F, $52, $54, $20, $45, $44, $49, $54, $20, $28, $59
    .byte $2F, $4E, $29, $3F, $20, $00

; "ERROR: BUFFER FULL."
msgBufferFull:
    .byte $45, $52, $52, $4F, $52, $3A, $20, $42, $55, $46, $46, $45, $52
    .byte $20, $46, $55, $4C, $4C, $2E, $0D, $00

.segment "BSS"
Line2ValLo:    .res 1
Line2ValHi:    .res 1
DelStartLo:    .res 1
DelStartHi:    .res 1
DelLineLo:     .res 1
DelLineHi:     .res 1
InsLineLen:    .res 1
OldLineLenLo:  .res 1
OldLineLenHi:  .res 1
SavedOffsetLo: .res 1
SavedOffsetHi: .res 1
