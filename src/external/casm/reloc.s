; src/external/casm/reloc.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; CASM Phase 8 WP40 relocation table. A flat, VMM-backed, append-only list
; of 16-bit little-endian code offsets (CasmPc - CASM_DEFAULT_ORIGIN),
; capped at CASM_RELOC_MAX entries (Phase 0C.14 freeze). Allocated once per
; Pass 2, unconditionally regardless of static/relocatable mode -- a static
; assembly simply never appends any entry, since CASM_PARSER_STMT_RELOCATABLE
; is never set outside relocatable mode (WP39); the unused allocation costs
; VMM/REU space only, not the MAIN envelope.
;
; relocRecord is the single gate every emission-site hook (emit.s) calls
; through; it no-ops under CASM_PASS_MODE_MEASURE, mirroring emitRawByte's
; own single-gate design (Phase 0C.5) -- the table does not even exist yet
; during Pass 1. Entries write immediately, one vmmWindowWrite per call, not
; staged: the only available transfer window (CasmVmmBuffer) is also used
; transiently by symbolsLookup between a statement's relocatable operands,
; so holding state in it across calls would risk the same shared-scratch-
; clobber bug class this codebase has hit before (WP23-25).

.include "command64.inc"
.include "common.inc"

.import vmmStoreAlloc
.import vmmWindowWrite
.import CasmVmmBuffer
.import CasmPc
.import CasmPassMode

.export relocInit
.export relocRecord
.export CasmRelocVmmSlot

.segment "BSS"

CasmRelocVmmSlot: .res 1   ; registry slot from relocInit's vmmStoreAlloc
CasmRelocCount:   .res 2   ; entries written so far (0..CASM_RELOC_MAX)

.segment "CODE"

; ---------------------------------------------------------------------------
; relocInit
; Allocate the relocation table's VMM storage and reset the entry count.
; Called once per Pass 2, unconditionally.
; Outputs: C clear on success; C set with A = CASM_DIAG_* on failure
; Clobbers: A, X, Y
; ---------------------------------------------------------------------------
relocInit:
    ldx #<CASM_RELOC_TABLE_BYTES
    ldy #>CASM_RELOC_TABLE_BYTES
    jsr vmmStoreAlloc
    bcs riFail
    stx CasmRelocVmmSlot
    lda #0
    sta CasmRelocCount
    sta CasmRelocCount + 1
    clc
    rts
riFail:
    rts

; ---------------------------------------------------------------------------
; relocRecord
; Append CasmPc - CASM_DEFAULT_ORIGIN as a new relocation table entry.
; No-ops under CASM_PASS_MODE_MEASURE (the table does not exist during
; Pass 1). Fails once CasmRelocCount already equals CASM_RELOC_MAX.
;
; Inputs:  CasmPc = the address of the byte about to be emitted (the caller
;          has not yet advanced it past this byte)
; Outputs: C clear on success (including the Pass 1 no-op); C set with
;          A = CASM_DIAG_RELOC_TABLE_FULL or CASM_DIAG_VMM_TRANSFER_FAILED
;          on failure
; Clobbers: A, X, Y, CasmVmmOffLo/OffHi, CasmIoLenLo/Hi, CasmVmmBuffer
; ---------------------------------------------------------------------------
relocRecord:
    lda CasmPassMode
    cmp #CASM_PASS_MODE_MEASURE
    bne rrEmit
    clc
    rts
rrEmit:
    lda CasmRelocCount + 1
    cmp #>CASM_RELOC_MAX
    bne rrNotFull
    lda CasmRelocCount
    cmp #<CASM_RELOC_MAX
    bne rrNotFull
    lda #CASM_DIAG_RELOC_TABLE_FULL
    sec
    rts
rrNotFull:
    ; CasmVmmBuffer[0..1] = CasmPc - CASM_DEFAULT_ORIGIN, little-endian.
    lda CasmPc
    sec
    sbc #<CASM_DEFAULT_ORIGIN
    sta CasmVmmBuffer
    lda CasmPc + 1
    sbc #>CASM_DEFAULT_ORIGIN
    sta CasmVmmBuffer + 1

    ; VMM offset = CasmRelocCount * 2 (single 16-bit left-shift-by-1).
    lda CasmRelocCount
    sta CasmVmmOffLo
    lda CasmRelocCount + 1
    sta CasmVmmOffHi
    asl CasmVmmOffLo
    rol CasmVmmOffHi

    lda #2
    sta CasmIoLenLo
    lda #0
    sta CasmIoLenHi
    ldx CasmRelocVmmSlot
    jsr vmmWindowWrite
    bcs rrRet

    inc CasmRelocCount
    bne rrDone
    inc CasmRelocCount + 1
rrDone:
    clc
rrRet:
    rts
