; src/external/casm/progress.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; CASM progress and processing indication (Increment 3: progress core).
; Owns bounded progress state and its own rendering only -- no parser,
; source, include, emitter, file, or diagnostic state. Every public routine,
; the BSS byte map, the screen protocol, and the two new diagnostic IDs are
; frozen by the Increment 2 design/ABI review
; (brain/reviews/2026-08-24-casm-progress-design-abi-review.md); this file
; is that frozen design, written in-tree, not yet wired into casm.s's
; orchestration (Increment 4 onward does that).
;
; Imports nothing from diagnostics.s, listing.s, or map.s -- own private
; progressPrintStr/progressPrintChar duplicate diagnostics.s's trivial
; DOS_PRINT_STR/DOS_PRINT_CHAR wrappers rather than importing them, and
; progressPrintDec is a fixed-width sibling of diagnostics.s's private,
; non-exported printDec16 (a different routine, since printDec16 cannot be
; imported and its variable-width zero-suppression is the wrong shape for
; this module's fixed-width fields anyway). diagnostics.s will import only
; progressClearTransient (one-way edge; Increment 7).
;
; A caller-supplied filename pointer was tried first for the transient
; line's 8-character name field and rejected: reading it needs (ptr),Y
; indirect-indexed addressing, which is a 6502 hardware requirement, not a
; ca65 limitation, and that addressing mode requires the pointer to live in
; zero page -- forbidden by the ABI. CasmProgArgNameBuf below is the
; resolution: the caller copies the already-truncated 8-byte field in
; before calling progressRenderTransient. This is "bounded rendering
; scratch," explicitly allowed; it is not "mirroring a whole filename"
; (CASM_FILENAME_MAX is 63 bytes) -- only the display width the screen
; protocol already truncates to.

.include "command64.inc"
.include "common.inc"

.export progressInit
.export progressBeginPass
.export progressStatement
.export progressRenderTransient
.export progressCompletePass
.export progressSourceLoadBytes
.export progressAccumulateOutputBytes
.export progressClearTransient
.export progressSuspend
.export progressFinalSummary
.export progressCheckPassTotals

; Caller-populated argument staging (ordinary BSS, not zero page -- the ABI
; authorizes no new zero-page byte). Set by the caller immediately before
; the corresponding JSR; progress.s treats these as read-only inputs.
.export CasmProgArgDepth
.export CasmProgArgFileId
.export CasmProgArgLineLo
.export CasmProgArgLineHi
.export CasmProgArgNameBuf

; Test-only visibility, not part of the frozen call ABI above: exported
; solely so tests/src/casm_progress/casm_progress.s can set up exact
; boundary states (e.g. priming the overflow/mismatch checks) without
; thousands of real progressStatement calls, matching this codebase's own
; precedent (e.g. casm_directives.s exporting emit.s's normally-private
; CasmParserStmt for direct harness setup).
.export CasmProgActiveLo
.export CasmProgActiveHi
.export CasmProgPass1TotalLo
.export CasmProgPass1TotalHi

; CASM_DIAG_PROGRESS_COUNTER_OVERFLOW/PASS_TOTAL_MISMATCH now live in
; common.inc (Increment 4), alongside every other CASM_DIAG_* constant,
; not here -- diagnostics.s needs them for its own message-dispatch table,
; which cannot .include this file (progress.s must not be a dependency of
; diagnostics.s beyond the one-way progressClearTransient import).

.segment "BSS"

; Two 16-bit statement totals collapse to one: Pass 1's final total is
; latched into CasmProgPass1TotalLo/Hi at progressCompletePass; Pass 2's
; own total IS CasmProgActiveLo/Hi at the moment progressCompletePass/
; progressCheckPassTotals run, so no separate Pass2Total byte is needed
; ("reuse ... where safe", per the ABI section).
CasmProgPass1TotalLo:  .res 1
CasmProgPass1TotalHi:  .res 1
CasmProgActiveLo:      .res 1
CasmProgActiveHi:      .res 1
CasmProgDivider:       .res 1   ; redraw throttle, wraps mod 64
CasmProgFlags:         .res 1   ; bit0=visible bit1=pass2 bit2=suspended
CasmProgByteLo:        .res 1   ; output-byte accumulator (final summary only;
CasmProgByteHi:        .res 1   ; the mid-write transient display was dropped
                                 ; in the Increment 2 scope trim)

CasmProgArgDepth:      .res 1
CasmProgArgFileId:     .res 1
CasmProgArgLineLo:     .res 1
CasmProgArgLineHi:     .res 1
CasmProgArgNameBuf:    .res 8

CasmProgDecScratchLo:  .res 1   ; private to progressPrintDec
CasmProgDecScratchHi:  .res 1
CasmProgBeginPassArg:  .res 1   ; private to progressBeginPass
CasmProgLoadLo:        .res 1   ; private to progressSourceLoadBytes (display
CasmProgLoadHi:        .res 1   ; value only -- never an accumulator)

CASM_PROG_FLAG_VISIBLE   = $01
CASM_PROG_FLAG_PASS2     = $02
CASM_PROG_FLAG_SUSPENDED = $04

.segment "CODE"

; ---------------------------------------------------------------------------
; progressPrintStr (private)
; Prints one null-terminated PETSCII string through the Command 64 API. Its
; own copy, not diagnostics.s's diagPrintString -- see the file header for
; why importing that would create a module cycle.
; In: X/Y = string address low/high byte
; Clobbers: A
; ---------------------------------------------------------------------------
progressPrintStr:
    lda #DOS_PRINT_STR
    jsr OS_API
    rts

; ---------------------------------------------------------------------------
; progressPrintChar (private)
; Prints one PETSCII byte through the Command 64 API.
; In: A = PETSCII byte
; Clobbers: A, X
; ---------------------------------------------------------------------------
progressPrintChar:
    pha
    tax
    lda #DOS_PRINT_CHAR
    jsr OS_API
    pla
    rts

; ---------------------------------------------------------------------------
; progressPrintDec (private)
; Fixed-width, zero-padded unsigned decimal, 2 or 5 digits. Deliberately
; simpler than diagnostics.s's printDec16: no zero-suppression flag/branch,
; since every field in the parent plan's screen protocol is fixed-width
; (matching its own d03/f07/l00128/t00412 examples exactly). Any 16-bit
; value 0-65535 fits a 5-digit field with no overrun.
; In:  A/X = value low/high byte, Y = field width (2 or 5)
; Clobbers: A, X, Y
; ---------------------------------------------------------------------------
.macro PROG_DIGIT divisor
    ldy #0
:   lda CasmProgDecScratchLo
    sec
    sbc #<(divisor)
    tax
    lda CasmProgDecScratchHi
    sbc #>(divisor)
    bcc :+
    stx CasmProgDecScratchLo
    sta CasmProgDecScratchHi
    iny
    jmp :-
:   tya
    clc
    adc #'0'
    jsr progressPrintChar
.endmacro

progressPrintDec:
    sta CasmProgDecScratchLo
    stx CasmProgDecScratchHi
    cpy #5
    beq @full
    jmp @narrow
@full:
    PROG_DIGIT 10000
    PROG_DIGIT 1000
    PROG_DIGIT 100
@narrow:
    PROG_DIGIT 10
    PROG_DIGIT 1
    rts

; ---------------------------------------------------------------------------
; progressReturnToStart (private)
; Returns the cursor to column 0 of the current, unadvanced transient line
; via CASM_PROG_LINE_WIDTH PetLeft (cursor-left) bytes. The transient line
; never emits its own trailing PetCr, so it never scrolls and this never
; needs to compensate with a cursor-up.
;
; Loop counter is Y, not X: progressPrintChar's own OS_API call takes the
; character in X (ahPrintChar's documented input register) and does not
; preserve it, so an X-held counter here would be destroyed on every
; iteration -- caught live by tests/src/casm_progress/casm_progress.s
; (Increment 3), which hung in exactly this loop before the fix. Y survives
; because ahPrintChar/KernalChROUT never touch it.
; Clobbers: A, Y
; ---------------------------------------------------------------------------
; Every transient line MUST print exactly this many characters, so the
; cursor-left return below lands on column 0 and the space-fill in
; progressClearTransient erases exactly what was drawn. Increment 5 found
; this the hard way: the status line printed 27 characters against a
; width of 38, so each redraw walked 11 columns further left and shredded
; the scrollback above it. Both builders below are commented with their
; own character budget; change one and you must change this.
CASM_PROG_LINE_WIDTH = 34
progressReturnToStart:
    ldy #CASM_PROG_LINE_WIDTH
@loop:
    lda #PetLeft
    jsr progressPrintChar
    dey
    bne @loop
    rts

; ---------------------------------------------------------------------------
; progressInit
; Zeroes all progress state. Call once before Pass 1 begins.
; Clobbers: A
; ---------------------------------------------------------------------------
progressInit:
    lda #0
    sta CasmProgPass1TotalLo
    sta CasmProgPass1TotalHi
    sta CasmProgActiveLo
    sta CasmProgActiveHi
    sta CasmProgDivider
    sta CasmProgFlags
    sta CasmProgByteLo
    sta CasmProgByteHi
    rts

; ---------------------------------------------------------------------------
; progressBeginPass
; Resets the active statement counter and redraw divider, prints the
; "p1: start" / "p2: start" persistent line. Bypasses the throttle
; entirely, as every immediate-transition call must.
;
; CasmProgActiveLo is reset via an explicit lda #0, not by storing the
; still-live pass-number argument -- an earlier draft did exactly that
; (stored A, still holding 1 or 2, straight into ActiveLo), silently
; starting every pass's statement count off by the pass number itself.
; Caught live by tests/src/casm_progress/casm_progress.s (Increment 3,
; case R, caseDecimalBoundaryZero) reporting "P1: DONE 00001 STATEMENTS"
; instead of 00000.
; In: A = pass number (1 or 2)
; Clobbers: A, X, Y
; ---------------------------------------------------------------------------
progressBeginPass:
    sta CasmProgBeginPassArg
    lda #0
    sta CasmProgActiveLo
    sta CasmProgActiveHi
    sta CasmProgDivider
    lda CasmProgFlags
    and #(255 - CASM_PROG_FLAG_VISIBLE - CASM_PROG_FLAG_PASS2)
    sta CasmProgFlags
    lda CasmProgBeginPassArg
    cmp #2
    bne @p1
    lda CasmProgFlags
    ora #CASM_PROG_FLAG_PASS2
    sta CasmProgFlags
    ldx #<msgP2Start
    ldy #>msgP2Start
    jmp progressPrintStr
@p1:
    ldx #<msgP1Start
    ldy #>msgP1Start
    jmp progressPrintStr

; ---------------------------------------------------------------------------
; progressStatement
; Records one dispatched statement (label, instruction, or directive --
; the caller is responsible for calling this only for statements the parent
; plan's Statement Counting section says to count) and reports whether a
; throttled redraw is due. Fires at exact counts 64, 128, 192, ... via a
; mod-64 divider.
; Out: C=0, A=1 if a redraw is due (A=0 if not);
;      C=1, A=CASM_DIAG_PROGRESS_COUNTER_OVERFLOW if the counter would wrap
; Clobbers: A. Preserves X, Y (parser/emitter-visible state).
; ---------------------------------------------------------------------------
progressStatement:
    lda CasmProgActiveLo
    cmp #$FF
    bne @incr
    lda CasmProgActiveHi
    cmp #$FF
    bne @incr
    lda #CASM_DIAG_PROGRESS_COUNTER_OVERFLOW
    sec
    rts
@incr:
    inc CasmProgActiveLo
    bne @noCarry
    inc CasmProgActiveHi
@noCarry:
    inc CasmProgDivider
    lda CasmProgDivider
    and #$3F
    sta CasmProgDivider
    bne @notDue
    lda #1
    clc
    rts
@notDue:
    lda #0
    clc
    rts

; ---------------------------------------------------------------------------
; progressRenderTransient
; Redraws the in-place transient status line: "p1: dNN fNN NAME lNNNNN
; tNNNNN" (or "p2: ..."). Reads CasmProgArgDepth/ArgFileId/ArgLineLo/Hi/
; ArgNameBuf, all caller-populated immediately before this call, plus its
; own CasmProgActiveLo/Hi for the statement-count field. Also serves a
; frame-transition redraw: the caller updates ArgDepth/ArgFileId and calls
; this directly, with no separate routine (the Increment 2 review dropped
; progressFrameTransition as its own entry point for exactly this reason).
; Clobbers: A, X, Y. Sets the visible flag.
; ---------------------------------------------------------------------------
progressRenderTransient:
    ; Only rewind when a transient line is already on screen. On the FIRST
    ; render after a persistent line (which ends in PetCr, leaving the
    ; cursor at column 0 of a fresh row) there is nothing to rewind over,
    ; and rewinding anyway walks 34 columns LEFT off the start of the row
    ; -- straight into the tail of the persistent line above, which it then
    ; overwrites. Increment 5 caught this live: "P1: START" was being
    ; chewed down to "P1: ST" by the first status redraw.
    lda CasmProgFlags
    and #CASM_PROG_FLAG_VISIBLE
    beq :+
    jsr progressReturnToStart
    :
    lda CasmProgFlags
    and #CASM_PROG_FLAG_PASS2
    beq @p1c
    ldx #<msgP2Prefix
    ldy #>msgP2Prefix
    jmp @gotPrefix
@p1c:
    ldx #<msgP1Prefix
    ldy #>msgP1Prefix
@gotPrefix:
    jsr progressPrintStr         ; "p1: d" / "p2: d"          5
    lda CasmProgArgDepth
    ldx #0
    ldy #2
    jsr progressPrintDec         ; depth                      2  = 7
    lda #' '
    jsr progressPrintChar        ;                            1  = 8
    lda #'F'
    jsr progressPrintChar        ; 'f' marker                 1  = 9
    lda CasmProgArgFileId
    ldx #0
    ldy #2
    jsr progressPrintDec         ; file id                    2  = 11
    lda #' '
    jsr progressPrintChar        ;                            1  = 12
    ldy #0
@nameLoop:
    lda CasmProgArgNameBuf, y
    jsr progressPrintChar        ; name                       8  = 20
    iny
    cpy #8
    bne @nameLoop
    lda #' '
    jsr progressPrintChar        ;                            1  = 21
    lda #'L'
    jsr progressPrintChar        ; 'l' marker                 1  = 22
    lda CasmProgArgLineLo
    ldx CasmProgArgLineHi
    ldy #5
    jsr progressPrintDec         ; line                       5  = 27
    lda #' '
    jsr progressPrintChar        ;                            1  = 28
    lda #'T'
    jsr progressPrintChar        ; 't' marker                 1  = 29
    lda CasmProgActiveLo
    ldx CasmProgActiveHi
    ldy #5
    jsr progressPrintDec         ; statement count            5  = 34
    lda CasmProgFlags
    ora #CASM_PROG_FLAG_VISIBLE
    sta CasmProgFlags
    rts

; ---------------------------------------------------------------------------
; progressCompletePass
; Clears the transient line and prints the "p1: done NNNNN statements" /
; "p2: done ..." persistent line. Latches CasmProgActiveLo/Hi into
; CasmProgPass1TotalLo/Hi when completing Pass 1, for
; progressCheckPassTotals to compare against later.
; Clobbers: A, X, Y
; ---------------------------------------------------------------------------
progressCompletePass:
    jsr progressClearTransient
    lda CasmProgFlags
    and #CASM_PROG_FLAG_PASS2
    beq @p1done
    ldx #<msgP2Done
    ldy #>msgP2Done
    jmp @gotMsg
@p1done:
    lda CasmProgActiveLo
    sta CasmProgPass1TotalLo
    lda CasmProgActiveHi
    sta CasmProgPass1TotalHi
    ldx #<msgP1Done
    ldy #>msgP1Done
@gotMsg:
    jsr progressPrintStr
    lda CasmProgActiveLo
    ldx CasmProgActiveHi
    ldy #5
    jsr progressPrintDec
    ldx #<msgStatementsTail
    ldy #>msgStatementsTail
    jmp progressPrintStr

; ---------------------------------------------------------------------------
; progressAccumulateOutputBytes
; Pure accumulation, no transient render -- the mid-write byte-cadence
; display, and the separate .RES/.FILL/.ALIGN/.INCBIN directive-byte
; cadence, were dropped in the Increment 2 scope trim (neither fed
; anything else). This running total exists only to supply
; progressFinalSummary's final byte count.
; In: A/X = bytes-just-written low/high byte
; Clobbers: A, X
; ---------------------------------------------------------------------------
progressAccumulateOutputBytes:
    clc
    adc CasmProgByteLo
    sta CasmProgByteLo
    txa
    adc CasmProgByteHi
    sta CasmProgByteHi
    rts

; ---------------------------------------------------------------------------
; progressSourceLoadBytes
; Transient load line: "load fNN NAME NNNNN" -- numeric physical-file
; identity, the first eight filename characters, and cumulative bytes
; committed so far for the file being loaded.
;
; Restored in Increment 5 (the Increment 2 scope trim had dropped it; the
; user reinstated it for the source/include load case only -- the
; .INCBIN/.RES/.FILL/.ALIGN directive byte cadence stays dropped).
;
; Takes the CUMULATIVE committed cursor directly rather than a per-block
; delta to accumulate: source.s's CasmSourceStreamCursor is advanced only
; after vmmWindowWrite succeeds, so it is already exactly the "cumulative
; committed cursor, not final 64-byte chunk" the Hook Contract asks for.
; Passing it whole means progress.s needs no load accumulator of its own
; and cannot drift out of step with the real committed total.
;
; The caller populates CasmProgArgFileId and CasmProgArgNameBuf for the
; file being loaded before the first call -- progress.s resolves no
; filename itself (it imports neither cli.s nor include.s, by its module
; boundary).
; In: A/X = cumulative committed bytes lo/hi
; Clobbers: A, X, Y
; ---------------------------------------------------------------------------
progressSourceLoadBytes:
    sta CasmProgLoadLo
    stx CasmProgLoadHi
    lda CasmProgFlags            ; same first-render guard as
    and #CASM_PROG_FLAG_VISIBLE  ; progressRenderTransient below
    beq :+
    jsr progressReturnToStart
    :
    ldx #<msgLoadPrefix
    ldy #>msgLoadPrefix
    jsr progressPrintStr
    lda CasmProgArgFileId
    ldx #0
    ldy #2
    jsr progressPrintDec
    ldy #0
@nameLoop:
    lda CasmProgArgNameBuf, y
    jsr progressPrintChar
    iny
    cpy #8
    bne @nameLoop
    lda CasmProgLoadLo
    ldx CasmProgLoadHi
    ldy #5
    jsr progressPrintDec         ; "load f" 6 + id 2 + name 8 + bytes 5 = 21
    ldy #CASM_PROG_LINE_WIDTH - 21
@pad:
    lda #' '
    jsr progressPrintChar        ; pad to the shared width       = 34
    dey
    bne @pad
    lda CasmProgFlags
    ora #CASM_PROG_FLAG_VISIBLE
    sta CasmProgFlags
    rts

; ---------------------------------------------------------------------------
; progressClearTransient
; Erases the transient line in place (space-fills it, returns cursor to
; column 0) and clears the visible flag. Idempotent: a no-op when the line
; is not currently visible. Owns no file handle, VMM allocation, keyboard,
; timer, parser, emitter, or diagnostic state.
;
; Loop counter is Y, not X -- same progressPrintChar/X-clobber reason as
; progressReturnToStart above.
; Clobbers: A, Y
; ---------------------------------------------------------------------------
progressClearTransient:
    lda CasmProgFlags
    and #CASM_PROG_FLAG_VISIBLE
    beq @notVisible
    jsr progressReturnToStart
    ldy #CASM_PROG_LINE_WIDTH
@spaces:
    lda #' '
    jsr progressPrintChar
    dey
    bne @spaces
    jsr progressReturnToStart
    lda CasmProgFlags
    and #(255 - CASM_PROG_FLAG_VISIBLE)
    sta CasmProgFlags
@notVisible:
    rts

; ---------------------------------------------------------------------------
; progressSuspend
; Clears the transient line and marks progress suspended, for `/L`/`/M`
; screen-ownership boundaries. Idempotent, like progressClearTransient.
; Clobbers: A, X
; ---------------------------------------------------------------------------
progressSuspend:
    jsr progressClearTransient
    lda CasmProgFlags
    ora #CASM_PROG_FLAG_SUSPENDED
    sta CasmProgFlags
    rts

; ---------------------------------------------------------------------------
; progressFinalSummary
; Clears the transient line and prints the final persistent summary:
; "done: p1 NNNNN, p2 NNNNN, NNNNN bytes".
; Clobbers: A, X, Y
; ---------------------------------------------------------------------------
progressFinalSummary:
    jsr progressClearTransient
    ldx #<msgDonePrefix
    ldy #>msgDonePrefix
    jsr progressPrintStr
    lda CasmProgPass1TotalLo
    ldx CasmProgPass1TotalHi
    ldy #5
    jsr progressPrintDec
    ldx #<msgP2Mid
    ldy #>msgP2Mid
    jsr progressPrintStr
    lda CasmProgActiveLo
    ldx CasmProgActiveHi
    ldy #5
    jsr progressPrintDec
    ldx #<msgBytesMid
    ldy #>msgBytesMid
    jsr progressPrintStr
    lda CasmProgByteLo
    ldx CasmProgByteHi
    ldy #5
    jsr progressPrintDec
    ldx #<msgBytesTail
    ldy #>msgBytesTail
    jmp progressPrintStr

; ---------------------------------------------------------------------------
; progressCheckPassTotals
; Compares the live active count (Pass 2's total, at the point this is
; called) against the latched Pass 1 total. An additional deterministic-
; replay check -- not a replacement for emitCheckPassAgreement's final-PC
; comparison or includeReplayFinalCheck's event-count comparison.
; Out: C=0 if equal; C=1, A=CASM_DIAG_PROGRESS_PASS_TOTAL_MISMATCH if not
; Clobbers: A
; ---------------------------------------------------------------------------
progressCheckPassTotals:
    lda CasmProgActiveLo
    cmp CasmProgPass1TotalLo
    bne @mismatch
    lda CasmProgActiveHi
    cmp CasmProgPass1TotalHi
    bne @mismatch
    clc
    rts
@mismatch:
    lda #CASM_DIAG_PROGRESS_PASS_TOTAL_MISMATCH
    sec
    rts

; ---------------------------------------------------------------------------
; Message table
; ---------------------------------------------------------------------------
msgP1Start:    .byte "P1: START", PetCr, 0
msgP2Start:    .byte "P2: START", PetCr, 0
msgP1Prefix:   .byte "P1: D", 0
msgP2Prefix:   .byte "P2: D", 0
msgP1Done:     .byte "P1: DONE ", 0
msgP2Done:     .byte "P2: DONE ", 0
msgStatementsTail: .byte " STATEMENTS", PetCr, 0
msgDonePrefix: .byte "DONE: P1 ", 0
msgP2Mid:      .byte ", P2 ", 0
msgBytesMid:   .byte ", ", 0
msgBytesTail:  .byte " BYTES", PetCr, 0
msgLoadPrefix: .byte "LOAD F", 0
