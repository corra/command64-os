; src/external/casm/vmm_store.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; CASM Phase 6A VMM allocation core (WP23). Wires DOS_ALLOC_MEM/DOS_FREE_MEM
; behind the existing central resource registry. Owns no storage of its own:
; a slot's SegHi/Bank identity lives in resources.s's CasmVmmRegistry and is
; read here by slot index, never written except through resourceRegisterVmm/
; resourceReleaseVmm. Implements no windowed transfer (WP24 owns that).

.include "command64.inc"
.include "common.inc"

.import resourceRegisterVmm
.import resourceReleaseVmm
.import CasmVmmRegistry

.export vmmStoreAlloc
.export vmmStoreFree

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

    ; Success: X = SegHi, Y = Bank. Stage them (the ZP pair reserved for
    ; OS-call argument staging) so they survive resourceRegisterVmm's own
    ; use of CasmValue0Lo/Hi as scratch.
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
    clc
    adc CasmValue0Lo
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
