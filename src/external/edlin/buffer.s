; src/external/edlin/buffer.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; Phase 1 buffer core: a VMM-backed flat text buffer with a windowed scan
; (findLine) standing in for DOS EDLIN's byte-at-a-time FINDLIN, since VMM
; access here is block-oriented (DOS_VMM_READ/DOS_VMM_WRITE), not
; single-byte. See brain/plans/2026-07-09-edlin-implementation-phases.md
; Phase 1 for the full design rationale. Falls back to a fixed base-RAM
; buffer (fallbackBuf) when no REU is present.

.include "command64.inc"
.include "common.inc"

.export bufInit
.export bufLoadFile
.export findLine

.segment "CODE"

; ---------------------------------------------------------------------------
; bufInit — allocate the text buffer (VMM, falling back to base RAM).
; Output: BufIsVmm set; BufBaseSegHi/BufBaseBank set if VMM; BufEndLo/Hi = 0.
; ---------------------------------------------------------------------------
bufInit:
    lda #0
    sta BufEndLo
    sta BufEndHi

    ldx #<BUF_ALLOC_PARAGRAPHS
    ldy #>BUF_ALLOC_PARAGRAPHS
    lda #DOS_ALLOC_MEM
    jsr OS_API
    bcc biVmmOk

    lda #0
    sta BufIsVmm
    ldx #<msgNoReu
    ldy #>msgNoReu
    lda #DOS_PRINT_STR
    jsr OS_API
    rts

biVmmOk:
    lda #1
    sta BufIsVmm
    stx BufBaseSegHi
    sty BufBaseBank
    rts

; ---------------------------------------------------------------------------
; bufLoadFile — open and stream a file into the buffer from offset 0.
; Input:  X/Y = pointer to null-terminated filename
; Output: Carry = 0 on success (including a 0-byte file); Carry = 1 if the
;         file could not be opened. BufEndLo/Hi = total bytes loaded.
; ---------------------------------------------------------------------------
bufLoadFile:
    lda #0
    sta HexValLo            ; mode = 0 (read)
    lda #DOS_OPEN_FILE
    jsr OS_API
    bcc blfOpened
    rts                      ; Carry already 1 — propagate open failure

blfOpened:
    sta FileHandle
    lda #0
    sta BufEndLo
    sta BufEndHi

blfLoop:
    lda #WINDOW_SIZE
    sta HexValLo
    lda #0
    sta HexValHi
    ldx #<scanWindow
    ldy #>scanWindow
    lda #DOS_READ_FILE
    jsr OS_API

    lda HexValLo
    ora HexValHi
    beq blfEof               ; 0 bytes read — nothing left, nothing to write

    lda BufIsVmm
    beq blfRamWrite

    ; --- VMM write: chunk -> buffer at current BufEnd offset ---
    lda #0
    sta VmmSegLo
    lda BufBaseSegHi
    sta VmmSegHi
    lda BufBaseBank
    sta VmmBank
    lda BufEndLo
    sta VmmOffLo
    lda BufEndHi
    sta VmmOffHi
    ldx #<scanWindow
    ldy #>scanWindow
    lda #DOS_VMM_WRITE
    jsr OS_API
    jmp blfAdvance

blfRamWrite:
    ; --- RAM fallback write: chunk -> fallbackBuf + BufEnd ---
    lda #<fallbackBuf
    clc
    adc BufEndLo
    sta ScanPtrLo
    lda #>fallbackBuf
    adc BufEndHi
    sta ScanPtrHi
    ldy #0
blfCopyLoop:
    cpy HexValLo
    beq blfAdvance
    lda scanWindow, y
    sta (ScanPtrLo), y
    iny
    jmp blfCopyLoop

blfAdvance:
    lda BufEndLo
    clc
    adc HexValLo
    sta BufEndLo
    lda BufEndHi
    adc HexValHi
    sta BufEndHi

    lda HexValHi
    bne blfLoop               ; actual >= 256, definitely a full chunk
    lda HexValLo
    cmp #WINDOW_SIZE
    bcc blfEof                ; actual < WINDOW_SIZE — that was the last chunk
    jmp blfLoop

blfEof:
    lda #DOS_CLOSE_FILE
    jsr OS_API
    clc
    rts

; ---------------------------------------------------------------------------
; bufReadWindow — refill scanWindow from WindowBaseOffLo/Hi (VMM path only).
; Output: scanWindow filled, WindowValidLen = bytes actually loaded
;         (min(WINDOW_SIZE, BufEnd - WindowBaseOff)).
; ---------------------------------------------------------------------------
bufReadWindow:
    lda BufEndLo
    sec
    sbc WindowBaseOffLo
    sta TmpLenLo
    lda BufEndHi
    sbc WindowBaseOffHi
    sta TmpLenHi

    lda TmpLenHi
    bne brwFull
    lda TmpLenLo
    cmp #(WINDOW_SIZE + 1)
    bcc brwPartial
brwFull:
    lda #WINDOW_SIZE
    jmp brwSetLen
brwPartial:
    lda TmpLenLo
brwSetLen:
    sta WindowValidLen
    beq brwSkipRead

    lda #0
    sta VmmSegLo
    lda BufBaseSegHi
    sta VmmSegHi
    lda BufBaseBank
    sta VmmBank
    lda WindowBaseOffLo
    sta VmmOffLo
    lda WindowBaseOffHi
    sta VmmOffHi
    ldx #<scanWindow
    ldy #>scanWindow
    lda WindowValidLen
    sta HexValLo
    lda #0
    sta HexValHi
    lda #DOS_VMM_READ
    jsr OS_API
brwSkipRead:
    rts

; ---------------------------------------------------------------------------
; findLine — locate the byte offset where a given (1-based) line starts.
; Input:  FindTargetLo/Hi = target line number ($FFFF scans the whole
;         buffer, i.e. "give me the total line count").
; Output: CurPtrLo/Hi = byte offset where the target line begins (or
;         BufEnd if the target is beyond the last line).
;         CurLineLo/Hi = line number actually reached: equals the target
;         if found, otherwise (total complete lines + 1) at EOF.
; Not yet optimized to scan from the nearest of {0, CurLine} the way DOS
; EDLIN's FINDLIN does — this always scans from offset 0. Fine for Phase 1;
; revisit if Phase 2/3 interactive performance needs it.
; ---------------------------------------------------------------------------
findLine:
    lda #1
    sta CurLineLo
    lda #0
    sta CurLineHi
    sta CurPtrLo
    sta CurPtrHi

    lda FindTargetHi
    bne flScan
    lda FindTargetLo
    cmp #2
    bcs flScan                ; target >= 2 -- needs a real scan
    jmp flDone                 ; target < 2 -- line 1 already starts at offset 0

flScan:
    lda BufIsVmm
    bne flVmmScan
    jmp flRamScan

flVmmScan:
    lda #0
    sta WindowBaseOffLo
    sta WindowBaseOffHi
flVmmWinLoop:
    lda WindowBaseOffHi
    cmp BufEndHi
    bcc flHaveMore
    bne flVmmEof
    lda WindowBaseOffLo
    cmp BufEndLo
    bcs flVmmEof
flHaveMore:
    jsr bufReadWindow
    ldy #0
flVmmByteLoop:
    cpy WindowValidLen
    beq flVmmWinAdvance
    lda scanWindow, y
    cmp #$0A
    bne flVmmNotLf
    inc CurLineLo
    bne flVmmSetPtr
    inc CurLineHi
flVmmSetPtr:
    tya
    clc
    adc #1
    clc
    adc WindowBaseOffLo
    sta CurPtrLo
    lda WindowBaseOffHi
    adc #0
    sta CurPtrHi
    lda CurLineLo
    cmp FindTargetLo
    bne flVmmNotLf
    lda CurLineHi
    cmp FindTargetHi
    bne flVmmNotLf
    rts                       ; found exactly
flVmmNotLf:
    iny
    jmp flVmmByteLoop
flVmmWinAdvance:
    lda WindowBaseOffLo
    clc
    adc WindowValidLen
    sta WindowBaseOffLo
    lda WindowBaseOffHi
    adc #0
    sta WindowBaseOffHi
    jmp flVmmWinLoop
flVmmEof:
    jmp flSetEof

flRamScan:
    lda #<fallbackBuf
    sta ScanPtrLo
    lda #>fallbackBuf
    sta ScanPtrHi
    lda #<fallbackBuf
    clc
    adc BufEndLo
    sta EndPtrLo
    lda #>fallbackBuf
    adc BufEndHi
    sta EndPtrHi
flRamLoop:
    lda ScanPtrLo
    cmp EndPtrLo
    bne flRamCont
    lda ScanPtrHi
    cmp EndPtrHi
    beq flSetEof
flRamCont:
    ldy #0
    lda (ScanPtrLo), y
    cmp #$0A
    bne flRamNotLf
    inc CurLineLo
    bne flRamSetPtr
    inc CurLineHi
flRamSetPtr:
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
    lda CurLineLo
    cmp FindTargetLo
    bne flRamNotLf
    lda CurLineHi
    cmp FindTargetHi
    bne flRamNotLf
    rts
flRamNotLf:
    inc ScanPtrLo
    bne flRamLoop
    inc ScanPtrHi
    jmp flRamLoop

flSetEof:
    ; Only count a trailing partial line if CurPtr (the offset right after
    ; the last LF found) is short of BufEnd -- if they're already equal,
    ; the file ended exactly on a line-feed and there's no partial line to
    ; add. Without this check, a file whose last byte is LF (the common
    ; case) gets double-counted: once for the LF itself, once more here.
    lda CurPtrLo
    cmp BufEndLo
    bne flPartialLine
    lda CurPtrHi
    cmp BufEndHi
    beq flSetEofPtr
flPartialLine:
    inc CurLineLo
    bne flSetEofPtr
    inc CurLineHi
flSetEofPtr:
    lda BufEndLo
    sta CurPtrLo
    lda BufEndHi
    sta CurPtrHi
flDone:
    rts

.segment "RODATA"
; "WARNING: NO REU DETECTED - USING LIMITED BASE-RAM BUFFER."
msgNoReu:
    .byte $57, $41, $52, $4E, $49, $4E, $47, $3A, $20, $4E, $4F, $20, $52
    .byte $45, $55, $20, $44, $45, $54, $45, $43, $54, $45, $44, $20, $2D
    .byte $20, $55, $53, $49, $4E, $47, $20, $4C, $49, $4D, $49, $54, $45
    .byte $44, $20, $42, $41, $53, $45, $2D, $52, $41, $4D, $20, $42, $55
    .byte $46, $46, $45, $52, $2E, $0D, $00

.segment "BSS"
scanWindow:  .res WINDOW_SIZE
fallbackBuf: .res FALLBACK_BUF_SIZE
