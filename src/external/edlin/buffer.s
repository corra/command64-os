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
.export bufReadWindow
.export scanWindow
.export fallbackBuf
.export bufWriteBytes
.export bufOpenHole
.export bufCloseHole
.export HoleSizeLo
.export HoleSizeHi

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
    bne flRamCont
    jmp flSetEof
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

; ---------------------------------------------------------------------------
; bufWriteBytes — write A bytes from a C64-RAM source into the buffer at
; CurPtrLo/Hi (VMM or RAM fallback). Does NOT touch BufEnd/CurPtr -- callers
; (Insert/edit-line) manage those themselves.
; Input:  A = byte count (<=128); X/Y = pointer to source bytes.
; ---------------------------------------------------------------------------
bufWriteBytes:
    sta HexValLo
    lda #0
    sta HexValHi
    stx ScanPtrLo
    sty ScanPtrHi

    lda BufIsVmm
    bne bwbVmm
    lda #<fallbackBuf
    clc
    adc CurPtrLo
    sta EndPtrLo
    lda #>fallbackBuf
    adc CurPtrHi
    sta EndPtrHi
    ldy #0
bwbRamLoop:
    cpy HexValLo
    beq bwbDone
    lda (ScanPtrLo), y
    sta (EndPtrLo), y
    iny
    jmp bwbRamLoop
bwbVmm:
    lda #0
    sta VmmSegLo
    lda BufBaseSegHi
    sta VmmSegHi
    lda BufBaseBank
    sta VmmBank
    lda CurPtrLo
    sta VmmOffLo
    lda CurPtrHi
    sta VmmOffHi
    ldx ScanPtrLo
    ldy ScanPtrHi
    lda #DOS_VMM_WRITE
    jsr OS_API
bwbDone:
    rts

; ---------------------------------------------------------------------------
; bufReadChunkRaw / bufWriteChunkRaw — internal to bufOpenHole/bufCloseHole.
; Move exactly WindowValidLen bytes (<=WINDOW_SIZE) between scanWindow and
; the buffer at WindowBaseOffLo/Hi -- no BufEnd-relative clamping (unlike
; bufReadWindow), since bufOpenHole/bufCloseHole always compute the exact
; chunk length themselves.
; ---------------------------------------------------------------------------
bufReadChunkRaw:
    lda BufIsVmm
    bne brcVmm
    lda #<fallbackBuf
    clc
    adc WindowBaseOffLo
    sta EndPtrLo
    lda #>fallbackBuf
    adc WindowBaseOffHi
    sta EndPtrHi
    ldy #0
brcRamLoop:
    cpy WindowValidLen
    beq brcDone
    lda (EndPtrLo), y
    sta scanWindow, y
    iny
    jmp brcRamLoop
brcVmm:
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
brcDone:
    rts

bufWriteChunkRaw:
    lda BufIsVmm
    bne bwcVmm
    lda #<fallbackBuf
    clc
    adc WindowBaseOffLo
    sta EndPtrLo
    lda #>fallbackBuf
    adc WindowBaseOffHi
    sta EndPtrHi
    ldy #0
bwcRamLoop:
    cpy WindowValidLen
    beq bwcDone
    lda scanWindow, y
    sta (EndPtrLo), y
    iny
    jmp bwcRamLoop
bwcVmm:
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
    lda #DOS_VMM_WRITE
    jsr OS_API
bwcDone:
    rts

; ---------------------------------------------------------------------------
; bufOpenHole — shift [CurPtr, BufEnd) up to [CurPtr+HoleSize, BufEnd+
; HoleSize), working from the end backward in WINDOW_SIZE chunks so a chunk
; is always read before the (higher, not-yet-relocated) memory it will be
; written into is touched. BufEnd += HoleSize on success.
; Input:  CurPtrLo/Hi = offset to open the hole at; HoleSizeLo/Hi = size.
; Output: Carry=0 on success; Carry=1 (no changes made) if BufEnd+HoleSize
;         would exceed the buffer's allocation ceiling ("buffer full").
;         CurPtrLo/Hi unchanged.
; ---------------------------------------------------------------------------
bufOpenHole:
    lda BufEndLo
    clc
    adc HoleSizeLo
    sta TmpLenLo
    lda BufEndHi
    adc HoleSizeHi
    sta TmpLenHi

    lda BufIsVmm
    bne bohVmmCeil
    lda TmpLenLo
    cmp #<FALLBACK_BUF_SIZE
    lda TmpLenHi
    sbc #>FALLBACK_BUF_SIZE
    bcc bohProceed
    jmp bohFull
bohVmmCeil:
    lda TmpLenLo
    cmp #<BUF_ALLOC_BYTES
    lda TmpLenHi
    sbc #>BUF_ALLOC_BYTES
    bcc bohProceed
    jmp bohFull

bohProceed:
    lda BufEndLo
    sec
    sbc CurPtrLo
    sta ShiftRemainLo
    lda BufEndHi
    sbc CurPtrHi
    sta ShiftRemainHi

    lda BufEndLo
    sta ShiftSrcLo
    lda BufEndHi
    sta ShiftSrcHi

bohLoop:
    lda ShiftRemainLo
    ora ShiftRemainHi
    bne bohChunk
    lda TmpLenLo
    sta BufEndLo
    lda TmpLenHi
    sta BufEndHi
    clc
    rts

bohChunk:
    lda ShiftRemainHi
    bne bohChunkFull
    lda ShiftRemainLo
    cmp #(WINDOW_SIZE+1)
    bcc bohChunkPartial
bohChunkFull:
    lda #WINDOW_SIZE
    jmp bohChunkSet
bohChunkPartial:
    lda ShiftRemainLo
bohChunkSet:
    sta WindowValidLen

    lda ShiftSrcLo
    sec
    sbc WindowValidLen
    sta ShiftSrcLo
    lda ShiftSrcHi
    sbc #0
    sta ShiftSrcHi

    lda ShiftSrcLo
    sta WindowBaseOffLo
    lda ShiftSrcHi
    sta WindowBaseOffHi
    jsr bufReadChunkRaw

    lda ShiftSrcLo
    clc
    adc HoleSizeLo
    sta WindowBaseOffLo
    lda ShiftSrcHi
    adc HoleSizeHi
    sta WindowBaseOffHi
    jsr bufWriteChunkRaw

    lda ShiftRemainLo
    sec
    sbc WindowValidLen
    sta ShiftRemainLo
    lda ShiftRemainHi
    sbc #0
    sta ShiftRemainHi

    jmp bohLoop

bohFull:
    sec
    rts

; ---------------------------------------------------------------------------
; bufCloseHole — shift [CurPtr+HoleSize, BufEnd) down to [CurPtr, BufEnd-
; HoleSize), working forward (low to high), since the destination is always
; lower than the source here (no overlap risk copying in that order).
; BufEnd -= HoleSize. No failure mode -- callers must have already
; validated CurPtr+HoleSize <= BufEnd via findLine.
; Input:  CurPtrLo/Hi = hole start offset; HoleSizeLo/Hi = size to remove.
; ---------------------------------------------------------------------------
bufCloseHole:
    lda CurPtrLo
    clc
    adc HoleSizeLo
    sta ShiftSrcLo
    lda CurPtrHi
    adc HoleSizeHi
    sta ShiftSrcHi

    lda BufEndLo
    sec
    sbc ShiftSrcLo
    sta ShiftRemainLo
    lda BufEndHi
    sbc ShiftSrcHi
    sta ShiftRemainHi

bchLoop:
    lda ShiftRemainLo
    ora ShiftRemainHi
    bne bchChunk
    lda BufEndLo
    sec
    sbc HoleSizeLo
    sta BufEndLo
    lda BufEndHi
    sbc HoleSizeHi
    sta BufEndHi
    rts

bchChunk:
    lda ShiftRemainHi
    bne bchChunkFull
    lda ShiftRemainLo
    cmp #(WINDOW_SIZE+1)
    bcc bchChunkPartial
bchChunkFull:
    lda #WINDOW_SIZE
    jmp bchChunkSet
bchChunkPartial:
    lda ShiftRemainLo
bchChunkSet:
    sta WindowValidLen

    lda ShiftSrcLo
    sta WindowBaseOffLo
    lda ShiftSrcHi
    sta WindowBaseOffHi
    jsr bufReadChunkRaw

    lda ShiftSrcLo
    sec
    sbc HoleSizeLo
    sta WindowBaseOffLo
    lda ShiftSrcHi
    sbc HoleSizeHi
    sta WindowBaseOffHi
    jsr bufWriteChunkRaw

    lda ShiftSrcLo
    clc
    adc WindowValidLen
    sta ShiftSrcLo
    lda ShiftSrcHi
    adc #0
    sta ShiftSrcHi

    lda ShiftRemainLo
    sec
    sbc WindowValidLen
    sta ShiftRemainLo
    lda ShiftRemainHi
    sbc #0
    sta ShiftRemainHi

    jmp bchLoop

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

; Phase 3 hole-shift scratch. Plain BSS, not zero page -- the app-private
; ZP range ($70-$8F, see common.inc) is exhausted after Phase 2, and none
; of this needs (zp),Y indirect addressing (only direct compare/add), so
; there's no reason to fight over the last ZP byte.
ShiftSrcLo:    .res 1
ShiftSrcHi:    .res 1
ShiftRemainLo: .res 1
ShiftRemainHi: .res 1
HoleSizeLo:    .res 1  ; set by callers (cmds.s) before bufOpenHole/bufCloseHole
HoleSizeHi:    .res 1
