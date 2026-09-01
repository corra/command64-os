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
; parser.s's job), and no binding into exprEvaluate's resolver slot (that is
; WP28's job, though symbolsLookup's calling convention is deliberately
; identical to that resolver ABI so no adapter code will be needed).
; symbolsReadByIndex (WP52) is the "look up symbol by record index"
; accessor once deferred here (see the WP27 plan's Dependency Review item
; 12) -- stateless, definition-order iteration for map.s, not a hash lookup.
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
.export symbolsReadByIndex
.export symbolsUpdateByIndex
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

; WP65: symbolsInsert caller-set inputs, read instead of a hardcoded
; CASM_SYMBOL_FLAG_DEFINED. Every caller (including crpLabel, formalizing
; its previously-implicit behavior) must set CasmSymbolInsertFlags
; explicitly before JSR symbolsInsert. The Ref* fields are copied into the
; new record only when CasmSymbolInsertFlags has CASM_SYMBOL_FLAG_CONSTANT
; set (a label caller may leave them unset; the zero-fill already in
; symbolsInsert covers that case for CONSTANT callers with a resolved
; numeric RHS too, since those simply never populate them).
; WP76: the constant's own defining statement's source position (copied
; from CasmLabelDefinedAtOffsetLo/Hi, parser.s, which ppsLabel stamps from
; CasmTokenStartOffsetLo/Hi before consuming any further tokens). Copied
; into the new record unconditionally alongside the Ref* fields, same
; CONSTANT-flag gate -- a label caller doesn't need it (labels stay
; unconditionally force-abs regardless, WP39).
.export CasmSymbolInsertFlags
.export CasmSymbolInsertRefVmmLo
.export CasmSymbolInsertRefVmmHi
.export CasmSymbolInsertRefLen
.export CasmSymbolInsertRefAddendLo
.export CasmSymbolInsertRefAddendHi
.export CasmSymbolInsertRefSign
.export CasmSymbolInsertRefExtract
.export CasmSymbolInsertDefinedAtOffsetLo
.export CasmSymbolInsertDefinedAtOffsetHi

; Phase 14 WP86: the local's owning-scope record index, read by
; symbolsInsert (WP88) only when CasmSymbolInsertFlags has
; CASM_SYMBOL_FLAG_LOCAL set, and copied into the new record's
; CASM_SYMBOL_REC_SCOPE_LO/HI (see common.inc). Storage declared here in
; WP86; symbolsInsert does not read these yet -- that wiring is WP88. The
; pass driver (casm.s) sets them from its own CasmCurrentScopeLo/Hi
; immediately before every local-label symbolsInsert call.
.export CasmSymbolInsertScopeLo
.export CasmSymbolInsertScopeHi
CasmSymbolInsertScopeLo:      .res 1
CasmSymbolInsertScopeHi:      .res 1

; Phase 14 WP86: the scope filter symbolsFindChain/symbolsLookup (WP88)
; consult for a `@`-led queried name -- the CURRENT scope, i.e. the record
; index of the most recently committed global label. Not consulted for a
; queried name that does not start with '@' (global lookups are always
; scope-independent, unchanged from Phase 6B). Set by the pass driver
; before each statement's expression evaluation, from its own
; CasmCurrentScopeLo/Hi. Storage declared here in WP86; symbolsFindChain
; does not read this yet -- that wiring is WP88.
.export CasmSymbolLookupScopeLo
.export CasmSymbolLookupScopeHi
CasmSymbolLookupScopeLo:      .res 1
CasmSymbolLookupScopeHi:      .res 1

CasmSymbolInsertFlags:        .res 1
CasmSymbolInsertRefVmmLo:     .res 1
CasmSymbolInsertRefVmmHi:     .res 1
CasmSymbolInsertRefLen:       .res 1
CasmSymbolInsertRefAddendLo:  .res 1
CasmSymbolInsertRefAddendHi:  .res 1
CasmSymbolInsertRefSign:      .res 1
CasmSymbolInsertDefinedAtOffsetLo: .res 1
CasmSymbolInsertDefinedAtOffsetHi: .res 1
CasmSymbolInsertRefExtract:   .res 1

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
; WP65: the record's Flags byte is no longer hardcoded to
; CASM_SYMBOL_FLAG_DEFINED -- every caller must set CasmSymbolInsertFlags
; explicitly first. When that value has CASM_SYMBOL_FLAG_CONSTANT set, the
; six CasmSymbolInsertRef* scratch bytes are also copied into the new
; record's REF_* fields (meaningful only until CASM_SYMBOL_FLAG_RESOLVED is
; later set by the resolution sweep); a label caller (CONSTANT clear)
; leaves them at whatever they last held, since the record's own zero-fill
; already covers that case. WP76: CasmSymbolInsertDefinedAtOffsetLo/Hi is
; copied the same way, alongside the Ref* fields -- unlike them it stays
; meaningful for the constant's entire lifetime, not just pre-resolution.
;
; Inputs:  CasmPtr0Lo/CasmPtr0Hi = namePtr; A = nameLen (1..31);
;          X/Y = value (Lo/Hi); CasmSymbolInsertFlags = record flags;
;          CasmSymbolInsertRef* = deferred-reference bookmark, meaningful
;              only when CasmSymbolInsertFlags has CASM_SYMBOL_FLAG_CONSTANT set
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
    lda CasmSymbolInsertFlags
    sta CasmVmmBuffer + CASM_SYMBOL_REC_FLAGS
    and #CASM_SYMBOL_FLAG_CONSTANT
    beq siRefDone
    lda CasmSymbolInsertRefVmmLo
    sta CasmVmmBuffer + CASM_SYMBOL_REC_REF_VMM_LO
    lda CasmSymbolInsertRefVmmHi
    sta CasmVmmBuffer + CASM_SYMBOL_REC_REF_VMM_HI
    lda CasmSymbolInsertRefLen
    sta CasmVmmBuffer + CASM_SYMBOL_REC_REF_LEN
    lda CasmSymbolInsertRefAddendLo
    sta CasmVmmBuffer + CASM_SYMBOL_REC_REF_ADDEND_LO
    lda CasmSymbolInsertRefAddendHi
    sta CasmVmmBuffer + CASM_SYMBOL_REC_REF_ADDEND_HI
    lda CasmSymbolInsertRefSign
    sta CasmVmmBuffer + CASM_SYMBOL_REC_REF_SIGN
    lda CasmSymbolInsertRefExtract
    sta CasmVmmBuffer + CASM_SYMBOL_REC_REF_EXTRACT
    lda CasmSymbolInsertDefinedAtOffsetLo
    sta CasmVmmBuffer + CASM_SYMBOL_REC_DEFINED_AT_OFFSET_LO
    lda CasmSymbolInsertDefinedAtOffsetHi
    sta CasmVmmBuffer + CASM_SYMBOL_REC_DEFINED_AT_OFFSET_HI
siRefDone:

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
;              on a match; CASM_RESOLVE_SYM_FLAGS (WP65) is also populated
;              on a match with the matched record's own CASM_SYMBOL_REC_
;              FLAGS byte (DEFINED/CONSTANT/RESOLVED/LABEL_DERIVED),
;              distinct from CASM_RESOLVE_FLAGS' CASM_EXPR_FLAG_* meaning;
;              CASM_RESOLVE_DEFINED_AT_OFFSET_LO/HI (WP76) is also
;              populated on a match from the record's own field; CASM_
;              RESOLVE_FLAGS clear (RESOLVED clear) and the remaining view
;              bytes (including CASM_RESOLVE_SYM_FLAGS and
;              CASM_RESOLVE_DEFINED_AT_OFFSET_LO/HI) unspecified on no
;              match
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
    ldy #CASM_RESOLVE_SYM_FLAGS
    lda CasmVmmBuffer + CASM_SYMBOL_REC_FLAGS
    sta (CasmPtr1Lo), y
    ldy #CASM_RESOLVE_DEFINED_AT_OFFSET_LO
    lda CasmVmmBuffer + CASM_SYMBOL_REC_DEFINED_AT_OFFSET_LO
    sta (CasmPtr1Lo), y
    ldy #CASM_RESOLVE_DEFINED_AT_OFFSET_HI
    lda CasmVmmBuffer + CASM_SYMBOL_REC_DEFINED_AT_OFFSET_HI
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

; ---------------------------------------------------------------------------
; symbolsReadByIndex
; WP52: stateless read of one symbol record by its record index, for
; deterministic definition-order reporting (map.s's mapPrint). Unlike
; symbolsFindChain's hash-bucket chain walk, this never inspects
; CasmSymbolBuckets or any Next field -- the index is the caller's own
; iteration cursor, not a chain position.
;
; Inputs:  X/Y = record index (Lo/Hi)
; Outputs: C clear, A = CASM_STREAM_DATA, CasmVmmBuffer holds the 64-byte
;              record at that index
;          C clear, A = CASM_STREAM_EOF (index >= CasmSymbolCount; no VMM
;              transfer; repeat-stable -- calling again with the same or a
;              larger index returns CASM_STREAM_EOF again)
;          C set, A = CASM_DIAG_VMM_TRANSFER_FAILED (rejected vmmWindowRead)
; Clobbers: A, X, Y, CasmVmmOffLo/OffHi, CasmIoLenLo/Hi, CasmVmmBuffer, and
;           OS API-defined volatile registers
; ---------------------------------------------------------------------------
symbolsReadByIndex:
    stx CasmVmmOffLo
    sty CasmVmmOffHi

    ; 16-bit unsigned compare: index >= CasmSymbolCount -> EOF. Computes
    ; index - count and tests the final carry (set = no borrow = index >=
    ; count), without disturbing CasmVmmOffLo/OffHi (still needed below).
    txa
    sec
    sbc CasmSymbolCount
    tya
    sbc CasmSymbolCount + 1
    bcs srbiEof

    ; VMM offset = index * CASM_SYMBOL_REC_SIZE (64): a single 16-bit
    ; left-shift-by-6, unrolled (matches symbolsFindChain's cursor offset
    ; math exactly).
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
    bcs srbiFail

    lda #CASM_STREAM_DATA
    clc
    rts

srbiEof:
    lda #CASM_STREAM_EOF
    clc
    rts

srbiFail:
    lda #CASM_DIAG_VMM_TRANSFER_FAILED
    sec
    rts

; ---------------------------------------------------------------------------
; symbolsUpdateByIndex
; WP65: write CasmVmmBuffer back to the symbol table at the given record
; index. The caller is expected to have obtained CasmVmmBuffer's current
; content from a symbolsReadByIndex call at this same index made
; immediately before (no intervening VMM-touching call in between, since
; any of those -- another symbolsReadByIndex/Insert/Lookup call, or a raw
; vmmWindowRead/Write -- clobbers the shared CasmVmmBuffer staging area),
; patched the fields that changed (typically VAL_LO/HI and FLAGS), and left
; everything else in the record untouched. Used by the Pass1->Pass2
; constant-resolution sweep (casm.s) to persist a deferred named constant's
; final value and CASM_SYMBOL_FLAG_RESOLVED once resolved.
;
; Inputs:  X/Y = record index (Lo/Hi); CasmVmmBuffer = the full 64-byte
;              record to write
; Outputs: C clear on success
;          C set, A = CASM_DIAG_VMM_TRANSFER_FAILED (rejected vmmWindowWrite)
; Clobbers: A, X, Y, CasmVmmOffLo/OffHi, CasmIoLenLo/Hi, and OS API-defined
;           volatile registers
; ---------------------------------------------------------------------------
symbolsUpdateByIndex:
    stx CasmVmmOffLo
    sty CasmVmmOffHi

    ; VMM offset = index * CASM_SYMBOL_REC_SIZE (64): matches
    ; symbolsReadByIndex's own offset math exactly.
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
    bcc suiOk
    lda #CASM_DIAG_VMM_TRANSFER_FAILED
    sec
    rts
suiOk:
    clc
    rts
