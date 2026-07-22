; src/external/casm/vmm_store.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; CASM Phase 6A VMM allocation core (WP23) and windowed transfer (WP24).
; Wires DOS_ALLOC_MEM/DOS_FREE_MEM/DOS_VMM_READ/DOS_VMM_WRITE behind the
; existing central resource registry. Owns no persistent registry storage of
; its own: a slot's SegHi/Bank/Pages identity lives in resources.s's
; CasmVmmRegistry and is read here by slot index, never written except
; through resourceRegisterVmm/resourceReleaseVmm.

.include "command64.inc"
.include "common.inc"

.import resourceRegisterVmm
.import resourceReleaseVmm
.import CasmVmmRegistry

.export vmmStoreAlloc
.export vmmStoreFree
.export vmmWindowRead
.export vmmWindowWrite
.export vmmReplay
.export CasmVmmBuffer

.segment "BSS"

CasmVmmBuffer: .res CASM_VMM_BUFFER_SIZE

.segment "CODE"

; ---------------------------------------------------------------------------
; vmmStoreAlloc
; Allocate REU-backed storage through DOS_ALLOC_MEM and register ownership.
;
; A zero byte count is rejected locally, before any OS call: this is what
; lets a later VMM_ERR_INVALID be trusted to mean "no REU / not initialized"
; rather than "zero-paragraph request" (Phase 0C.4, WP22 finding). No 16-bit
; byte count can otherwise exceed the 65536-byte single-allocation cap after
; rounding up to whole paragraphs (65535 bytes rounds up to exactly 4096
; paragraphs = 65536 bytes = 16 pages), so there is no separate "too large"
; rejection: the carry out of the rounding add is used only to recognize
; that exact boundary case and clamp to it, never to reject a request.
;
; Inputs:  X/Y = requested byte count (Lo/Hi); must not both be zero
; Outputs: C clear and X = registry slot (0..7) on success
;          C set and A = CASM_DIAG_VMM_ALLOC_FAILED (zero-size request, or
;              DOS_ALLOC_MEM reported VMM_ERR_NOMEM, or the registry was
;              full and the completed OS allocation was released again),
;              or CASM_DIAG_VMM_UNAVAILABLE (DOS_ALLOC_MEM reported
;              VMM_ERR_INVALID) on failure
; Clobbers: A, X, Y and OS API-defined volatile registers
; ---------------------------------------------------------------------------
vmmStoreAlloc:
    stx CasmValue0Lo
    sty CasmValue0Hi
    txa
    ora CasmValue0Hi
    bne vsaSized
    lda #CASM_DIAG_VMM_ALLOC_FAILED
    sec
    rts

vsaSized:
    ; Round the byte count up to whole 16-byte paragraphs: (count + 15) / 16.
    ; A carry out of the 16-bit add means count was in 65521..65535, the only
    ; range where the true result is exactly 4096 paragraphs (65536 bytes) --
    ; the addressing cap boundary, not an overflow to reject.
    lda CasmValue0Lo
    clc
    adc #15
    sta CasmValue0Lo
    lda CasmValue0Hi
    adc #0
    sta CasmValue0Hi
    bcs vsaClampMax

    ; 16-bit shift right by 4 (divide by 16), Hi:Lo in place.
    ldx #4
vsaShift:
    lsr CasmValue0Hi
    ror CasmValue0Lo
    dex
    bne vsaShift
    jmp vsaCallAlloc

vsaClampMax:
    lda #$00
    sta CasmValue0Lo
    lda #$10
    sta CasmValue0Hi

vsaCallAlloc:
    lda #DOS_ALLOC_MEM
    ldx CasmValue0Lo
    ldy CasmValue0Hi
    jsr OS_API
    bcs vsaAllocFailed

    ; Success: X = SegHi, Y = Bank. CasmValue0Lo/Hi still hold the exact
    ; paragraph count just requested (untouched by the OS call); derive the
    ; granted page count from it before resourceRegisterVmm's own use of
    ; CasmValue0Lo/Hi as scratch overwrites them. PageCount = ceil(paragraphs
    ; / 256), which is simply the high byte of (paragraphs + 255) -- mirrors
    ; vmmAlloc's own rounding (WP22 finding) exactly.
    lda CasmValue0Lo
    clc
    adc #255
    lda CasmValue0Hi
    adc #0
    sta CasmValue1Lo        ; granted page count (1-16), resourceRegisterVmm's 3rd input

    ; Stage SegHi/Bank (the ZP pair reserved for OS-call argument staging) so
    ; they survive resourceRegisterVmm's own use of CasmValue0Lo/Hi as scratch.
    stx CasmVmmSegHi
    sty CasmVmmBank
    jsr resourceRegisterVmm
    bcc vsaRegistered

    ; Registry full: the OS grant succeeded but has no owner. Free it again
    ; rather than leak REU space, then report the registry failure.
    lda #DOS_FREE_MEM
    ldx CasmVmmSegHi
    ldy CasmVmmBank
    jsr OS_API
    lda #CASM_DIAG_VMM_ALLOC_FAILED
    sec
    rts

vsaRegistered:
    clc
    rts

vsaAllocFailed:
    cmp #VMM_ERR_INVALID
    beq vsaUnavailable
    lda #CASM_DIAG_VMM_ALLOC_FAILED
    sec
    rts
vsaUnavailable:
    lda #CASM_DIAG_VMM_UNAVAILABLE
    sec
    rts

; ---------------------------------------------------------------------------
; vmmStoreFree
; Free a registry slot's REU allocation through DOS_FREE_MEM.
;
; An already-free slot is a no-op success, matching resourceReleaseHandle's
; idempotent precedent. A rejected DOS_FREE_MEM leaves the registry slot
; owned so a later cleanup pass can retry it (cleanupFileRecord's existing
; retry-on-failure precedent) -- resourceReleaseVmm is not called in that
; case.
;
; Inputs:  X = registry slot (0..7)
; Outputs: C clear on success (including an already-free slot)
;          C set and A = CASM_DIAG_VMM_FREE_FAILED on a rejected
;              DOS_FREE_MEM call, or on an out-of-range slot
; Clobbers: A, X, Y and OS API-defined volatile registers
; ---------------------------------------------------------------------------
vmmStoreFree:
    cpx #CASM_VMM_CAPACITY
    bcs vsfFreeFailed
    stx CasmValue0Lo        ; preserve the slot number across the OS call
    txa
    asl
    asl
    tay                      ; Y = byte offset (slot * CASM_VMM_REC_SIZE)
    lda CasmVmmRegistry + CASM_VMM_REC_FLAG, y
    beq vsfAlreadyFree

    lda CasmVmmRegistry + CASM_VMM_REC_SEGHI, y
    sta CasmVmmSegHi
    lda CasmVmmRegistry + CASM_VMM_REC_BANK, y
    sta CasmVmmBank

    lda #DOS_FREE_MEM
    ldx CasmVmmSegHi
    ldy CasmVmmBank
    jsr OS_API
    bcs vsfFreeFailed

    ldx CasmValue0Lo         ; restore the slot number
    jmp resourceReleaseVmm

vsfAlreadyFree:
    clc
    rts

vsfFreeFailed:
    lda #CASM_DIAG_VMM_FREE_FAILED
    sec
    rts

; ---------------------------------------------------------------------------
; vwPrepareTransfer (private)
; Validate a windowed transfer request and stage the OS's Vmm*/HexVal* cells.
; Shared by vmmWindowRead/vmmWindowWrite; does not itself call DOS_VMM_READ/
; DOS_VMM_WRITE. Bounds-checks, in order: the slot is in range and owned (a
; freed/unregistered slot has nothing to transfer against -- matches
; vmmfree1's fixture intent of rejecting stale handles via CASM's own
; registry state, not chance REU contents); the byte count fits the fixed
; CasmVmmBuffer; offset+count does not overflow 16 bits; and the transfer
; fits within the slot's granted page count. All four are CASM-internal
; rejections, never forwarded to DOS_VMM_READ/DOS_VMM_WRITE.
;
; The offset+count -> page-count comparison avoids ever representing 65536
; (the addressing cap) as a 16-bit value, the same hazard vmmStoreAlloc's
; rounding worked around: NeededPages = ceil((offset+count) / 4096) is
; computed as (top nibble of the 16-bit sum) + (1 if the low 12 bits are
; nonzero), which stays in 0-16 for any 16-bit sum and never needs to add a
; rounding constant that could itself overflow.
;
; Inputs:  X = registry slot; CasmVmmOffLo/OffHi = offset; CasmIoLenLo/Hi =
;          byte count
; Outputs: C clear on success, with VmmSegLo/Hi, VmmOffLo/Hi, VmmBank, and
;          HexValLo/Hi all staged and X/Y = CasmVmmBuffer's pointer, ready
;          for the caller to set A = DOS_VMM_READ/DOS_VMM_WRITE and
;          jsr OS_API; C set and A = CASM_DIAG_VMM_TRANSFER_FAILED on any
;          rejection
; Clobbers: A, X, Y, CasmValue0Lo/CasmValue0Hi
; ---------------------------------------------------------------------------
vwPrepareTransfer:
    cpx #CASM_VMM_CAPACITY
    bcs vwRejected

    ; The byte count must fit the fixed staging buffer.
    lda CasmIoLenHi
    bne vwRejected
    lda CasmIoLenLo
    cmp #CASM_VMM_BUFFER_SIZE + 1
    bcs vwRejected

    ; Locate the slot's record; Y stays this byte offset through vwStage.
    txa
    asl
    asl
    tay
    lda CasmVmmRegistry + CASM_VMM_REC_FLAG, y
    beq vwRejected

    ; offset + count must not overflow 16 bits.
    lda CasmVmmOffLo
    clc
    adc CasmIoLenLo
    sta CasmValue0Lo
    lda CasmVmmOffHi
    adc CasmIoLenHi
    sta CasmValue0Hi
    bcs vwRejected

    ; NeededPages = ceil((offset+count) / 4096).
    lda CasmValue0Hi
    and #$0F
    ora CasmValue0Lo
    beq vwNoRoundUp
    lda CasmValue0Hi
    lsr
    lsr
    lsr
    lsr
    clc
    adc #1
    jmp vwPagesReady
vwNoRoundUp:
    lda CasmValue0Hi
    lsr
    lsr
    lsr
    lsr
vwPagesReady:
    cmp CasmVmmRegistry + CASM_VMM_REC_PAGES, y
    beq vwStage
    bcc vwStage

vwRejected:
    lda #CASM_DIAG_VMM_TRANSFER_FAILED
    sec
    rts

vwStage:
    lda #0
    sta VmmSegLo
    lda CasmVmmRegistry + CASM_VMM_REC_SEGHI, y
    sta VmmSegHi
    lda CasmVmmRegistry + CASM_VMM_REC_BANK, y
    sta VmmBank
    lda CasmVmmOffLo
    sta VmmOffLo
    lda CasmVmmOffHi
    sta VmmOffHi
    lda CasmIoLenLo
    sta HexValLo
    lda CasmIoLenHi
    sta HexValHi
    ldx #<CasmVmmBuffer
    ldy #>CasmVmmBuffer
    clc
    rts

; ---------------------------------------------------------------------------
; vmmWindowRead
; Read a bounds-checked window of a VMM allocation into CasmVmmBuffer.
;
; Inputs:  X = registry slot; CasmVmmOffLo/OffHi = offset; CasmIoLenLo/Hi =
;          byte count (0..CASM_VMM_BUFFER_SIZE)
; Outputs: C clear on success (CasmVmmBuffer filled with the read data);
;          C set and A = CASM_DIAG_VMM_TRANSFER_FAILED on a local bounds
;              rejection or a rejected DOS_VMM_READ call
; Clobbers: A, X, Y and OS API-defined volatile registers
; ---------------------------------------------------------------------------
vmmWindowRead:
    jsr vwPrepareTransfer
    bcs vwPropagateFail
    lda #DOS_VMM_READ
    jsr OS_API
    bcs vwOsFailed
    clc
    rts

; ---------------------------------------------------------------------------
; vmmWindowWrite
; Write CasmVmmBuffer through a bounds-checked window of a VMM allocation.
;
; Inputs:  X = registry slot; CasmVmmOffLo/OffHi = offset; CasmIoLenLo/Hi =
;          byte count (0..CASM_VMM_BUFFER_SIZE); CasmVmmBuffer holds the
;          data to write
; Outputs: C clear on success; C set and A = CASM_DIAG_VMM_TRANSFER_FAILED
;              on a local bounds rejection or a rejected DOS_VMM_WRITE call
; Clobbers: A, X, Y and OS API-defined volatile registers
; ---------------------------------------------------------------------------
vmmWindowWrite:
    jsr vwPrepareTransfer
    bcs vwPropagateFail
    lda #DOS_VMM_WRITE
    jsr OS_API
    bcs vwOsFailed
    clc
    rts

vwPropagateFail:
    rts                      ; vwPrepareTransfer already set A/C for failure

vwOsFailed:
    lda #CASM_DIAG_VMM_TRANSFER_FAILED
    sec
    rts

; ---------------------------------------------------------------------------
; vmmReplay
; Write the pattern currently in CasmVmmBuffer through vmmWindowWrite,
; discard the RAM copy (zero-fill CasmVmmBuffer), then read it back through
; vmmWindowRead -- the mechanical write/discard/read steps of Phase 6A's
; completion-gate wording ("written, read, and replayed"). The caller keeps
; its own copy of the original pattern and compares it against
; CasmVmmBuffer's contents after this routine returns; the comparison
; itself belongs to WP25's fixtures, not this routine.
;
; Inputs:  X = registry slot; CasmVmmOffLo/OffHi = offset; CasmIoLenLo/Hi =
;          byte count; CasmVmmBuffer already holds the pattern to write
; Outputs: C clear on success (CasmVmmBuffer holds the round-tripped read);
;          C set and A = CASM_DIAG_VMM_TRANSFER_FAILED if either the write
;              or the read-back was rejected
; Clobbers: A, X, Y and OS API-defined volatile registers
; ---------------------------------------------------------------------------
vmmReplay:
    stx CasmValue0Lo            ; preserve the slot across both calls
    jsr vmmWindowWrite
    bcs vrDone

    ; Zero-fill CasmVmmBuffer for CasmIoLenLo bytes ("discard the RAM copy").
    ; vwPrepareTransfer already proved CasmIoLenHi = 0 for any request that
    ; reaches this point, so an 8-bit loop counter is sufficient.
    ldy #0
vrZeroLoop:
    cpy CasmIoLenLo
    beq vrZeroDone
    lda #0
    sta CasmVmmBuffer, y
    iny
    jmp vrZeroLoop
vrZeroDone:

    ldx CasmValue0Lo            ; restore the slot
    jsr vmmWindowRead
vrDone:
    rts
