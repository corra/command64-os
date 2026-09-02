; src/external/casm/cond.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; Phase 15 (Conditional Assembly): the conditional-nesting stack state
; machine and the Pass-1 branch-decision bitmap.
;
; This module never parses or evaluates -- every entry point that cares
; about a `.IF`/`.ELSEIF` condition is handed a 1/0 `decision` in A by the
; caller (WP96's pass driver, which owns the truthiness / `.IFDEF` lookup).
; cond.s only maintains the stack: emit state, branch-taken and
; seen-else bookkeeping, the four structural diagnostics, the EOF check,
; and the record/replay decision bitmap that keeps Pass 1 and Pass 2
; taking identical branches.
;
; Storage (WP93) + routines (WP95). Design:
; brain/plans/2026-09-01-casm-phase15-wp93-design-freeze.md (D3, D4),
; brain/plans/2026-09-01-casm-phase15-wp95-cond-state-machine.md.
;
; Convention: every routine returns C clear on success; C set + A =
; CASM_DIAG_* on a structural error. `d` = CasmCondDepth - 1 is the
; current top level's index into the per-level arrays.

.include "common.inc"

.export CasmCondDepth
.export CasmCondEmitting
.export CasmCondBranchTaken
.export CasmCondSeenElse
.export CasmCondParentEmitting
.export CasmCondOpenLineLo
.export CasmCondOpenLineHi
.export CasmCondOpenColumn
.export CasmCondOpenFileId
.export CasmCondSiteCounterLo
.export CasmCondSiteCounterHi
.export CasmCondDecisionBitmap
.export CasmCondOpenLocLineLo
.export CasmCondOpenLocLineHi
.export CasmCondOpenLocColumn
.export CasmCondOpenLocFileId

.export condResetForPass
.export condOpenIf
.export condElseif
.export condElse
.export condEndif
.export condCurrentlyEmitting
.export condTopParentEmitting
.export condAtEof
.export condSiteDecision

.segment "BSS"

CasmCondStateStart:

; Current conditional nesting depth. 0 = no open `.IF` (assembly proceeds
; exactly as pre-Phase-15). 1..CASM_COND_MAX_DEPTH index the per-level
; arrays below (index d-1). Reset to 0 at the start of each pass.
CasmCondDepth: .res 1

; Per-level parallel arrays (index = depth - 1), mirroring source.s's
; frame-stack layout convention.
;
;  CasmCondEmitting        1 = this level's current branch emits; 0 = suppressed.
;  CasmCondBranchTaken     1 = some branch at this level has already been taken,
;                          so every later `.ELSEIF`/`.ELSE` here stays suppressed.
;  CasmCondSeenElse        1 = `.ELSE` already seen at this level -- a following
;                          `.ELSEIF`/`.ELSE` is CASM_DIAG_CONDITIONAL_ELSE_AFTER_ELSE.
;  CasmCondParentEmitting  snapshot of the enclosing level's emit state at the
;                          `.IF` that opened this level. A level nested inside a
;                          suppressed outer level never emits regardless of its
;                          own condition.
;  CasmCondOpenLineLo/Hi   the opening `.IF`/`.IFDEF`/`.IFNDEF`'s source line and
;  CasmCondOpenColumn      column and
;  CasmCondOpenFileId      packed file id, for CASM_DIAG_UNTERMINATED_CONDITIONAL.
CasmCondEmitting:       .res CASM_COND_MAX_DEPTH
CasmCondBranchTaken:    .res CASM_COND_MAX_DEPTH
CasmCondSeenElse:       .res CASM_COND_MAX_DEPTH
CasmCondParentEmitting: .res CASM_COND_MAX_DEPTH
CasmCondOpenLineLo:     .res CASM_COND_MAX_DEPTH
CasmCondOpenLineHi:     .res CASM_COND_MAX_DEPTH
CasmCondOpenColumn:     .res CASM_COND_MAX_DEPTH
CasmCondOpenFileId:     .res CASM_COND_MAX_DEPTH

; Pass-1 branch-decision record. Each `.IF`/`.ELSEIF`/`.IFDEF`/`.IFNDEF`
; that is *reached while its enclosing level is emitting* bumps
; CasmCondSiteCounter and, in Pass 1, writes its taken/not-taken result
; as one bit here (site N -> byte N>>3, bit N&7). Pass 2 replays bit N for
; the Nth reached site instead of re-evaluating the condition -- the
; `.INCLUDE` catalogLoad -> catalogLookup pattern -- so Pass 1 and Pass 2
; are guaranteed to take identical branches regardless of forward
; references or `.INCLUDE` source-offset ordering. Counter reset to 0 per
; pass; overflow past CASM_COND_MAX_SITES -> CASM_DIAG_CONDITIONAL_SITE_OVERFLOW.
CasmCondSiteCounterLo: .res 1
CasmCondSiteCounterHi: .res 1
CasmCondDecisionBitmap: .res CASM_COND_BITMAP_BYTES

CasmCondStateEnd:

; Caller-set staging for the opening location, copied into the per-level
; arrays by condOpenIf (the CasmSymbolInsert* WP65 pattern -- keeps the
; entry point to one register argument).
CasmCondOpenLocLineLo: .res 1
CasmCondOpenLocLineHi: .res 1
CasmCondOpenLocColumn: .res 1
CasmCondOpenLocFileId: .res 1

; condOpenIf/condSiteDecision internal scratch.
condScratch:  .res 1

.assert CasmCondEmitting - CasmCondDepth = 1, error, "CASM conditional stack layout changed"
.assert CasmCondOpenFileId - CasmCondEmitting = 7 * CASM_COND_MAX_DEPTH, error, "CASM conditional per-level array layout changed"
.assert CasmCondDecisionBitmap - CasmCondSiteCounterLo = 2, error, "CASM conditional site-counter layout changed"
.assert CasmCondStateEnd - CasmCondStateStart = 1 + 8 * CASM_COND_MAX_DEPTH + 2 + CASM_COND_BITMAP_BYTES, error, "CASM conditional state size changed"

.segment "CODE"

; ---------------------------------------------------------------------------
; condResetForPass
; Zero the depth and the site counter. The decision bitmap is deliberately
; NOT cleared: Pass 1 writes every bit index it will later read, and the
; site counter bounds both passes identically.
; Clobbers: A.
; ---------------------------------------------------------------------------
condResetForPass:
    lda #0
    sta CasmCondDepth
    sta CasmCondSiteCounterLo
    sta CasmCondSiteCounterHi
    rts

; ---------------------------------------------------------------------------
; condCurrentlyEmitting
; A = 1 if assembly is currently emitting (depth 0, or the top level's
; CasmCondEmitting is set), else A = 0. C clear always. The pass driver's
; per-statement gate.
; Clobbers: A, X.
; ---------------------------------------------------------------------------
condCurrentlyEmitting:
    ldx CasmCondDepth
    beq @yes
    lda CasmCondEmitting - 1, x
    clc
    rts
@yes:
    lda #1
    clc
    rts

; ---------------------------------------------------------------------------
; condTopParentEmitting
; A = 1 if the current top level's enclosing level was emitting when the
; top level was opened (or depth 0), else A = 0. WP96's suppression
; scanner reads this to decide whether a top-level `.ELSEIF` could
; possibly re-enable emitting (and so must be evaluated) or is inert.
; Clobbers: A, X.
; ---------------------------------------------------------------------------
condTopParentEmitting:
    ldx CasmCondDepth
    beq @yes
    lda CasmCondParentEmitting - 1, x
    clc
    rts
@yes:
    lda #1
    clc
    rts

; ---------------------------------------------------------------------------
; condOpenIf   (A = decision: 1 = condition true / branch taken, 0 = false)
; Handles `.IF` / `.IFDEF` / `.IFNDEF`. Pushes a new nesting level.
; Inputs:  A = decision; CasmCondOpenLoc{LineLo,LineHi,Column,FileId} = the
;          opening directive's source location.
; Outputs: C clear on success. C set + A = CASM_DIAG_CONDITIONAL_NESTING_
;          OVERFLOW when the stack is full.
; Clobbers: A, X, Y, condScratch.
; ---------------------------------------------------------------------------
condOpenIf:
    sta condScratch                 ; decision
    lda CasmCondDepth
    cmp #CASM_COND_MAX_DEPTH
    bcc @room
    lda #CASM_DIAG_CONDITIONAL_NESTING_OVERFLOW
    sec
    rts
@room:
    ; parentEmitting: 1 if depth 0, else CasmCondEmitting[depth-1].
    tax                             ; X = old depth (also the new level's index)
    beq @parentYes
    lda CasmCondEmitting - 1, x
    jmp @haveParent
@parentYes:
    lda #1
@haveParent:
    ; X = new level index; A = parentEmitting.
    sta CasmCondParentEmitting, x
    ; emitting = parentEmitting AND decision
    and condScratch
    sta CasmCondEmitting, x
    lda condScratch
    sta CasmCondBranchTaken, x
    lda #0
    sta CasmCondSeenElse, x
    lda CasmCondOpenLocLineLo
    sta CasmCondOpenLineLo, x
    lda CasmCondOpenLocLineHi
    sta CasmCondOpenLineHi, x
    lda CasmCondOpenLocColumn
    sta CasmCondOpenColumn, x
    lda CasmCondOpenLocFileId
    sta CasmCondOpenFileId, x
    inc CasmCondDepth
    clc
    rts

; ---------------------------------------------------------------------------
; condElseif   (A = decision)
; Outputs: C clear on success; C set + A = CASM_DIAG_CONDITIONAL_WITHOUT_IF
;          (depth 0) or CASM_DIAG_CONDITIONAL_ELSE_AFTER_ELSE (`.ELSE` seen).
; Clobbers: A, X, condScratch.
; ---------------------------------------------------------------------------
condElseif:
    sta condScratch
    jsr condElseCommonCheck
    bcs @err
    ; emitting = parentEmitting AND (NOT priorBranchTaken) AND decision
    lda CasmCondParentEmitting - 1, x
    beq @noEmit
    lda CasmCondBranchTaken - 1, x
    bne @noEmit
    lda condScratch                 ; decision
    beq @noEmit
    lda #1
    bne @store
@noEmit:
    lda #0
@store:
    sta CasmCondEmitting - 1, x
    lda condScratch
    beq @done                       ; decision 0: leave branchTaken as-is
    lda #1
    sta CasmCondBranchTaken - 1, x
@done:
    clc
    rts
@err:
    rts

; ---------------------------------------------------------------------------
; condElse
; Outputs: as condElseif's error set.
; Clobbers: A, X.
; ---------------------------------------------------------------------------
condElse:
    jsr condElseCommonCheck
    bcs @err
    ; emitting = parentEmitting AND (NOT branchTaken)
    lda CasmCondParentEmitting - 1, x
    beq @noEmit
    lda CasmCondBranchTaken - 1, x
    bne @noEmit
    lda #1
    bne @store
@noEmit:
    lda #0
@store:
    sta CasmCondEmitting - 1, x
    lda #1
    sta CasmCondBranchTaken - 1, x
    sta CasmCondSeenElse - 1, x
    clc
    rts
@err:
    rts

; condElseCommonCheck (private)
; X = CasmCondDepth on return; C set + A = diag on a structural error.
condElseCommonCheck:
    ldx CasmCondDepth
    bne @haveIf
    lda #CASM_DIAG_CONDITIONAL_WITHOUT_IF
    sec
    rts
@haveIf:
    lda CasmCondSeenElse - 1, x
    beq @ok
    lda #CASM_DIAG_CONDITIONAL_ELSE_AFTER_ELSE
    sec
    rts
@ok:
    clc
    rts

; ---------------------------------------------------------------------------
; condEndif
; Outputs: C clear on success; C set + A = CASM_DIAG_CONDITIONAL_WITHOUT_IF
;          at depth 0.
; Clobbers: A.
; ---------------------------------------------------------------------------
condEndif:
    lda CasmCondDepth
    bne @pop
    lda #CASM_DIAG_CONDITIONAL_WITHOUT_IF
    sec
    rts
@pop:
    dec CasmCondDepth
    clc
    rts

; ---------------------------------------------------------------------------
; condAtEof
; Outputs: C clear if the stack is balanced. C set + A = CASM_DIAG_
;          UNTERMINATED_CONDITIONAL if a level is still open; the unclosed
;          `.IF`'s location is in CasmCondOpenLine*/Column/FileId[depth-1].
; Clobbers: A.
; ---------------------------------------------------------------------------
condAtEof:
    lda CasmCondDepth
    beq @ok
    lda #CASM_DIAG_UNTERMINATED_CONDITIONAL
    sec
    rts
@ok:
    clc
    rts

; ---------------------------------------------------------------------------
; condSiteDecision   (A = freshly-computed decision, X = pass number 1|2)
; The Pass-1-record / Pass-2-replay decision bitmap. Call once per
; `.IF`/`.ELSEIF`/`.IFDEF`/`.IFNDEF` reached while its enclosing level is
; emitting -- never for a conditional inside a suppressed region.
; Outputs: C clear, A = the decision to use (Pass 1: the passed-in value;
;          Pass 2: the replayed bit). C set + A = CASM_DIAG_CONDITIONAL_
;          SITE_OVERFLOW past CASM_COND_MAX_SITES.
; Clobbers: A, X, Y, condScratch.
; ---------------------------------------------------------------------------
condSiteDecision:
    sta condScratch                 ; decision (Pass 1 records this)
    stx condPassScratch             ; pass number
    ; overflow: counter >= 512  <=>  counterHi >= 2
    lda CasmCondSiteCounterHi
    cmp #2
    bcc @room
    lda #CASM_DIAG_CONDITIONAL_SITE_OVERFLOW
    sec
    rts
@room:
    ; Y = byte index = (counterLo >> 3) | (counterHi ? $20 : 0)
    lda CasmCondSiteCounterLo
    lsr
    lsr
    lsr
    ldx CasmCondSiteCounterHi
    beq @noHigh
    ora #$20
@noHigh:
    tay
    ; condMaskScratch = 1 << (counterLo & 7)
    lda CasmCondSiteCounterLo
    and #$07
    tax
    lda #$01
@shift:
    dex
    bmi @haveMask
    asl
    jmp @shift
@haveMask:
    sta condMaskScratch
    lda condPassScratch
    cmp #2
    beq @replay
    ; Pass 1: set or clear bit Y per condScratch, leave condScratch as
    ; the decision to return.
    lda condScratch
    beq @recordClear
    lda CasmCondDecisionBitmap, y
    ora condMaskScratch
    sta CasmCondDecisionBitmap, y
    jmp @bump
@recordClear:
    lda condMaskScratch
    eor #$FF
    and CasmCondDecisionBitmap, y
    sta CasmCondDecisionBitmap, y
    jmp @bump
@replay:
    lda CasmCondDecisionBitmap, y
    and condMaskScratch
    beq @replayZero
    lda #1
    sta condScratch
    jmp @bump
@replayZero:
    lda #0
    sta condScratch
@bump:
    inc CasmCondSiteCounterLo
    bne @noCarry
    inc CasmCondSiteCounterHi
@noCarry:
    lda condScratch
    clc
    rts

.segment "BSS"
condMaskScratch: .res 1
condPassScratch: .res 1
.segment "CODE"
