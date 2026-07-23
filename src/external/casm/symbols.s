; src/external/casm/symbols.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; CASM Phase 6B WP27 symbol table: VMM-backed symbol records (Phase 6A
; storage) plus a bounded RAM hash-bucket index over them. Provides
; symbolsInit/symbolsInsert/symbolsLookup. Built and fixture-tested in
; complete isolation -- no casm.s, parser.s, or opcodes.s call site exists
; yet; WP28 (Pass 1) is what wires this module into real assembly.
;
; Ownership: symbolsInit makes exactly one vmmStoreAlloc call (32768 bytes:
; CASM_SYMBOL_MAX * CASM_SYMBOL_REC_SIZE) and keeps the returned registry
; slot for the process lifetime. This module registers no cleanup owner of
; its own: resourcesCleanup's existing VMM loop already calls vmmStoreFree
; against every registered slot regardless of which module registered it.
;
; What this module does NOT do: no label/expression grammar (that is
; parser.s's job), no binding into exprEvaluate's resolver slot (that is
; WP28's job, though symbolsLookup's calling convention is deliberately
; identical to that resolver ABI so no adapter code will be needed), and no
; "look up symbol by record index" accessor (deferred; see the WP27 plan's
; Dependency Review item 12).
;
; Scratch discipline: CasmValue0Lo/CasmValue0Hi are vwPrepareTransfer's own
; clobbered scratch (documented in vmm_store.s), and this exact class of bug
; -- stashing state that must survive a call in a cell the callee also uses
; -- bit vmm_store.s three separate times during its own development. Nothing
; in this module stashes state across a vmmWindowRead/vmmWindowWrite call in
; CasmValue0Lo/Hi; everything that must survive such a call lives in this
; module's own private BSS cells, or in CasmPtr0Lo/Hi and CasmPtr1Lo/Hi (the
; general-purpose pointer pair already used this way by parser.s and others).

.include "command64.inc"
.include "common.inc"

.import vmmStoreAlloc
.import vmmWindowRead
.import vmmWindowWrite
.import CasmVmmBuffer

.export symbolsInit
.export symbolsInsert
.export symbolsLookup
.export CasmSymbolVmmSlot

.segment "BSS"

CasmSymbolVmmSlot:      .res 1   ; registry slot from symbolsInit's vmmStoreAlloc
CasmSymbolCount:        .res 2   ; bump allocator (Lo/Hi), 0..CASM_SYMBOL_MAX
CasmSymbolBuckets:      .res CASM_SYMBOL_BUCKET_COUNT * 2  ; head-record-index per bucket, $FFFF = empty

; Private transient scratch for symbolsFindChain/symbolsInsert/symbolsLookup.
; Plain values, not pointers -- none of these need zero-page indirect
; addressing, so none of this lives in the zero-page scratch groups.
CasmSymScratchLen:      .res 1   ; nameLen, persisted across the vmmWindowRead calls
CasmSymScratchValLo:    .res 1
CasmSymScratchValHi:    .res 1
CasmSymScratchCursorLo: .res 1   ; chain-walk record-index cursor
CasmSymScratchCursorHi: .res 1
CasmSymScratchBucket:   .res 1   ; bucket index, 0-127
CasmSymScratchHeadLo:   .res 1   ; the bucket's ORIGINAL head (for prepend-on-insert)
CasmSymScratchHeadHi:   .res 1

.assert CASM_SYMBOL_BUCKET_COUNT * 2 = 256, error, "CASM symbol bucket table size changed"

.segment "CODE"

; ---------------------------------------------------------------------------
; symbolsInit
; Allocate the VMM-backed symbol store and reset all local index state.
;
; Inputs:  none
; Outputs: C clear on success
;          C set + A = CASM_DIAG_VMM_UNAVAILABLE or CASM_DIAG_VMM_ALLOC_FAILED
;              (propagated unchanged from vmmStoreAlloc)
; Clobbers: A, X, Y and OS API-defined volatile registers
; ---------------------------------------------------------------------------
symbolsInit:
    ldx #<(CASM_SYMBOL_MAX * CASM_SYMBOL_REC_SIZE)
    ldy #>(CASM_SYMBOL_MAX * CASM_SYMBOL_REC_SIZE)
    jsr vmmStoreAlloc
    bcs siFail
    stx CasmSymbolVmmSlot

    lda #0
    sta CasmSymbolCount
    sta CasmSymbolCount + 1

    ; Every bucket head starts at CASM_SYMBOL_CHAIN_END ($FFFF, "empty").
    ; X counts buckets (0..127, fits an 8-bit compare); Y is the byte offset
    ; (0, 2, 4, ..., wrapping back to 0 exactly as X reaches 128, since 128
    ; iterations of +2 sum to 256).
    ldx #0
    ldy #0
siBucketLoop:
    lda #<CASM_SYMBOL_CHAIN_END
    sta CasmSymbolBuckets, y
    lda #>CASM_SYMBOL_CHAIN_END
    sta CasmSymbolBuckets + 1, y
    iny
    iny
    inx
    cpx #CASM_SYMBOL_BUCKET_COUNT
    bne siBucketLoop

    clc
    rts

siFail:
    rts                      ; vmmStoreAlloc already set A/C for failure

; ---------------------------------------------------------------------------
; symbolsFindChain (private)
; Hash a name, then walk its bucket's collision chain looking for an exact
; case-sensitive match. Shared by symbolsInsert and symbolsLookup.
;
; Discriminant (callers must check in this order):
;   C clear             -> not found (walked to CASM_SYMBOL_CHAIN_END); A = 0
;   C set, A = 1         -> found; X/Y = matching record index (Lo/Hi);
;                            CasmVmmBuffer holds that matched record
;   C set, A = CASM_DIAG_VMM_TRANSFER_FAILED
;                        -> internal error (a vmmWindowRead call failed);
;                            this is NOT a resolution outcome and must be
;                            checked for (cmp against this value) before a
;                            caller may otherwise assume "found"
;
; As a side effect useful to symbolsInsert, CasmSymScratchBucket holds the
; hashed bucket index and CasmSymScratchHeadLo/Hi holds that bucket's
; ORIGINAL head (before any walking), on every return path.
;
; Inputs:  CasmPtr0Lo/CasmPtr0Hi = namePtr; A = nameLen (1..31)
; Outputs: see Discriminant above
; Clobbers: A, X, Y, CasmSymScratchLen/Bucket/HeadLo/HeadHi/CursorLo/CursorHi,
;           CasmVmmOffLo/OffHi, CasmIoLenLo/Hi, CasmVmmBuffer, and OS
;           API-defined volatile registers (via vmmWindowRead)
; ---------------------------------------------------------------------------
symbolsFindChain:
    sta CasmSymScratchLen

    ; Hash: rotate-left-1-XOR fold over the name's exact bytes, masked to 7
    ; bits (128 buckets).
    lda #0
    ldy #0
sfcHashLoop:
    cpy CasmSymScratchLen
    beq sfcHashDone
    asl a
    bcc sfcHashNoCarry
    ora #1
sfcHashNoCarry:
    eor (CasmPtr0Lo), y
    iny
    jmp sfcHashLoop
sfcHashDone:
    and #CASM_SYMBOL_BUCKET_MASK
    sta CasmSymScratchBucket

    ; Load the bucket's head cursor; keep a separate copy as the ORIGINAL
    ; head for symbolsInsert's later prepend.
    asl a                    ; bucket * 2; bucket is 0-127 so this fits in A
    tay
    lda CasmSymbolBuckets, y
    sta CasmSymScratchCursorLo
    sta CasmSymScratchHeadLo
    lda CasmSymbolBuckets + 1, y
    sta CasmSymScratchCursorHi
    sta CasmSymScratchHeadHi

sfcLoop:
    ; Cursor == CASM_SYMBOL_CHAIN_END ($FFFF) -> end of chain, not found.
    lda CasmSymScratchCursorLo
    cmp #<CASM_SYMBOL_CHAIN_END
    bne sfcHaveCursor
    lda CasmSymScratchCursorHi
    cmp #>CASM_SYMBOL_CHAIN_END
    bne sfcHaveCursor
    lda #0
    clc
    rts

sfcHaveCursor:
    ; VMM offset = cursor * CASM_SYMBOL_REC_SIZE (64): a single 16-bit
    ; left-shift-by-6, unrolled.
    lda CasmSymScratchCursorLo
    sta CasmVmmOffLo
    lda CasmSymScratchCursorHi
    sta CasmVmmOffHi
    asl CasmVmmOffLo
    rol CasmVmmOffHi
    asl CasmVmmOffLo
    rol CasmVmmOffHi
    asl CasmVmmOffLo
    rol CasmVmmOffHi
    asl CasmVmmOffLo
    rol CasmVmmOffHi
    asl CasmVmmOffLo
    rol CasmVmmOffHi
    asl CasmVmmOffLo
    rol CasmVmmOffHi

    lda #CASM_SYMBOL_REC_SIZE
    sta CasmIoLenLo
    lda #0
    sta CasmIoLenHi
    ldx CasmSymbolVmmSlot
    jsr vmmWindowRead
    bcc sfcReadOk
    rts                      ; A = CASM_DIAG_VMM_TRANSFER_FAILED, C set: internal error
sfcReadOk:

    ; NameLen mismatch -> this record cannot match; advance the chain.
    lda CasmVmmBuffer + CASM_SYMBOL_REC_NAMELEN
    cmp CasmSymScratchLen
    bne sfcAdvance

    ; Exact byte-for-byte comparison over exactly nameLen bytes (never the
    ; full 31-byte Name slot -- padding past NameLen is zero-filled but not
    ; relied on here).
    ldy #0
sfcCmpLoop:
    cpy CasmSymScratchLen
    beq sfcMatch
    lda CasmVmmBuffer + CASM_SYMBOL_REC_NAME, y
    cmp (CasmPtr0Lo), y
    bne sfcAdvance
    iny
    jmp sfcCmpLoop

sfcMatch:
    ldx CasmSymScratchCursorLo
    ldy CasmSymScratchCursorHi
    lda #1
    sec
    rts

sfcAdvance:
    lda CasmVmmBuffer + CASM_SYMBOL_REC_NEXT_LO
    sta CasmSymScratchCursorLo
    lda CasmVmmBuffer + CASM_SYMBOL_REC_NEXT_HI
    sta CasmSymScratchCursorHi
    jmp sfcLoop

; ---------------------------------------------------------------------------
; symbolsInsert
; Insert a new symbol, rejecting an exact case-sensitive duplicate name
; already DEFINED. New records are appended array-wise at record index
; CasmSymbolCount and prepended to their bucket's collision chain (the
; chain's new head's Next points at the bucket's ORIGINAL head, not the last
; cursor visited during the lookup walk).
;
; Never leaves partial state on failure: CasmSymbolBuckets and CasmSymbolCount
; are only updated after a successful vmmWindowWrite of the new record.
;
; Inputs:  CasmPtr0Lo/CasmPtr0Hi = namePtr; A = nameLen (1..31);
;          X/Y = value (Lo/Hi)
; Outputs: C clear, X/Y = new record index (Lo/Hi)
;          C set, A = CASM_DIAG_DUPLICATE_SYMBOL (exact case-sensitive name
;              already DEFINED), CASM_DIAG_SYMBOL_TABLE_FULL (CasmSymbolCount
;              already at CASM_SYMBOL_MAX), or CASM_DIAG_VMM_TRANSFER_FAILED
;              (internal: a vmmWindowRead/vmmWindowWrite call failed)
; Clobbers: A, X, Y, CasmSym* scratch, CasmVmmOffLo/OffHi, CasmIoLenLo/Hi,
;           CasmVmmBuffer, and OS API-defined volatile registers
; ---------------------------------------------------------------------------
symbolsInsert:
    stx CasmSymScratchValLo
    sty CasmSymScratchValHi

    jsr symbolsFindChain
    bcc siNotFound
    cmp #CASM_DIAG_VMM_TRANSFER_FAILED
    beq siPropagate
    lda #CASM_DIAG_DUPLICATE_SYMBOL
    sec
    rts
siPropagate:
    rts                      ; A/C already set for the internal-error case
siNotFound:

    ; Reject once the table is already at capacity.
    lda CasmSymbolCount + 1
    cmp #>CASM_SYMBOL_MAX
    bne siNotFull
    lda CasmSymbolCount
    cmp #<CASM_SYMBOL_MAX
    bne siNotFull
    lda #CASM_DIAG_SYMBOL_TABLE_FULL
    sec
    rts
siNotFull:

    ; Zero-fill the entire 64-byte staging record first; the 27 reserved
    ; padding bytes (offsets 37-63) are never left undefined.
    ldy #0
siZeroLoop:
    lda #0
    sta CasmVmmBuffer, y
    iny
    cpy #CASM_SYMBOL_REC_SIZE
    bne siZeroLoop

    lda CasmSymScratchLen
    sta CasmVmmBuffer + CASM_SYMBOL_REC_NAMELEN
    ldy #0
siNameLoop:
    cpy CasmSymScratchLen
    beq siNameDone
    lda (CasmPtr0Lo), y
    sta CasmVmmBuffer + CASM_SYMBOL_REC_NAME, y
    iny
    jmp siNameLoop
siNameDone:

    lda CasmSymScratchValLo
    sta CasmVmmBuffer + CASM_SYMBOL_REC_VAL_LO
    lda CasmSymScratchValHi
    sta CasmVmmBuffer + CASM_SYMBOL_REC_VAL_HI
    lda #CASM_SYMBOL_FLAG_DEFINED
    sta CasmVmmBuffer + CASM_SYMBOL_REC_FLAGS

    ; Prepend: Next = the bucket's ORIGINAL head (captured by
    ; symbolsFindChain before it walked anything).
    lda CasmSymScratchHeadLo
    sta CasmVmmBuffer + CASM_SYMBOL_REC_NEXT_LO
    lda CasmSymScratchHeadHi
    sta CasmVmmBuffer + CASM_SYMBOL_REC_NEXT_HI

    ; New record index = current CasmSymbolCount. Compute its VMM offset
    ; (index * CASM_SYMBOL_REC_SIZE, single 16-bit left-shift-by-6) and write.
    lda CasmSymbolCount
    sta CasmVmmOffLo
    lda CasmSymbolCount + 1
    sta CasmVmmOffHi
    asl CasmVmmOffLo
    rol CasmVmmOffHi
    asl CasmVmmOffLo
    rol CasmVmmOffHi
    asl CasmVmmOffLo
    rol CasmVmmOffHi
    asl CasmVmmOffLo
    rol CasmVmmOffHi
    asl CasmVmmOffLo
    rol CasmVmmOffHi
    asl CasmVmmOffLo
    rol CasmVmmOffHi

    lda #CASM_SYMBOL_REC_SIZE
    sta CasmIoLenLo
    lda #0
    sta CasmIoLenHi
    ldx CasmSymbolVmmSlot
    jsr vmmWindowWrite
    bcc siWriteOk
    rts                      ; A = CASM_DIAG_VMM_TRANSFER_FAILED, C set: internal error
siWriteOk:

    ; This new record becomes its bucket's new chain head.
    lda CasmSymScratchBucket
    asl a
    tay
    lda CasmSymbolCount
    sta CasmSymbolBuckets, y
    lda CasmSymbolCount + 1
    sta CasmSymbolBuckets + 1, y

    ; Capture the new record index (the pre-increment count) as the output,
    ; then bump the bump allocator.
    ldx CasmSymbolCount
    ldy CasmSymbolCount + 1
    inc CasmSymbolCount
    bne siCountDone
    inc CasmSymbolCount + 1
siCountDone:
    clc
    rts

; ---------------------------------------------------------------------------
; symbolsLookup
; Look up a name and report the outcome through a caller-supplied
; CASM_RESOLVE_* view. Calling convention matches exprEvaluate's resolver
; callback ABI (expr.s) exactly, so a later work package can bind this
; routine directly as the resolver with zero adapter code.
;
; Inputs:  CasmPtr0Lo/CasmPtr0Hi = namePtr; A = nameLen (1..31);
;          X/Y = pointer to a caller-owned 5-byte CASM_RESOLVE_* view to fill
; Outputs: C clear on any normal resolution outcome (found or not found is
;              reported through the view, never through carry): view's
;              CASM_RESOLVE_FLAGS byte has CASM_EXPR_FLAG_RESOLVED set (only
;              that bit -- symbols are always absolute, never RELOCATABLE)
;              and CASM_RESOLVE_ID_LO/HI + CASM_RESOLVE_VAL_LO/HI populated
;              on a match; CASM_RESOLVE_FLAGS clear (RESOLVED clear) and the
;              remaining view bytes unspecified on no match
;          C set + A = CASM_DIAG_VMM_TRANSFER_FAILED is the ONE exception:
;              an internal VMM failure during the chain walk, which is not a
;              resolution outcome at all
; Clobbers: A, X, Y, CasmSym* scratch, CasmVmmOffLo/OffHi, CasmIoLenLo/Hi,
;           CasmVmmBuffer, and OS API-defined volatile registers
; ---------------------------------------------------------------------------
symbolsLookup:
    stx CasmPtr1Lo
    sty CasmPtr1Hi

    jsr symbolsFindChain
    bcc slNotFound
    cmp #CASM_DIAG_VMM_TRANSFER_FAILED
    beq slPropagate

    ; Found: CasmVmmBuffer holds the matched record; CasmSymScratchCursorLo/Hi
    ; holds the same record index symbolsFindChain also returned in X/Y (read
    ; from memory here rather than juggling X/Y, since Y is needed as the
    ; (CasmPtr1Lo),y index into the caller's view).
    ldy #CASM_RESOLVE_FLAGS
    lda #CASM_EXPR_FLAG_RESOLVED
    sta (CasmPtr1Lo), y
    ldy #CASM_RESOLVE_ID_LO
    lda CasmSymScratchCursorLo
    sta (CasmPtr1Lo), y
    ldy #CASM_RESOLVE_ID_HI
    lda CasmSymScratchCursorHi
    sta (CasmPtr1Lo), y
    ldy #CASM_RESOLVE_VAL_LO
    lda CasmVmmBuffer + CASM_SYMBOL_REC_VAL_LO
    sta (CasmPtr1Lo), y
    ldy #CASM_RESOLVE_VAL_HI
    lda CasmVmmBuffer + CASM_SYMBOL_REC_VAL_HI
    sta (CasmPtr1Lo), y
    clc
    rts

slNotFound:
    ldy #CASM_RESOLVE_FLAGS
    lda #0
    sta (CasmPtr1Lo), y
    clc
    rts

slPropagate:
    rts                      ; A/C already set for the internal-error case
