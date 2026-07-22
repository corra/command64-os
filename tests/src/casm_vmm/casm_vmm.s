; tests/src/casm_vmm/casm_vmm.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; Standalone CASM Phase 6A VMM fixture harness (WP25). Exercises
; vmm_store.s's vmmStoreAlloc/vmmStoreFree/vmmWindowRead/vmmWindowWrite/
; vmmReplay directly against real DOS_ALLOC_MEM/DOS_FREE_MEM/DOS_VMM_READ/
; DOS_VMM_WRITE calls -- CASM's parser has no directive that reaches these
; routines, so this cannot be an ordinary .seq source fixture. Each case is
; a sequential real operation (not an independent data-driven table, since
; VMM operations have real side effects on shared registry/REU state across
; one PRG execution), returning C clear for pass / C set for fail, matching
; every other CASM public routine's convention.
;
; Stubs diagPrintFatal locally rather than importing the real diagnostics.s:
; resources.s's exitSuccess/exitFatal reference it, and since ld65 links
; whole object files, importing resourceRegisterVmm alone would otherwise
; drag in diagnostics.s's own lexer.s/source.s dependencies even though this
; harness never calls exitSuccess/exitFatal. Matches WP20's casm_expr.s,
; which stubbed lexer/diagnostic symbols expr.s needed for the same reason.
;
; vmmalloc4 (REU/allocation exhaustion) and vmmnoreu are not implemented
; here: CASM's own registry caps total usage at 512KB (128 pages) against
; the OS's 16MB-tracked MCT, so no normal allocation sequence can mark it
; full, and the supported harness has no per-run REU toggle. Both are
; recorded as manually deferred in the WP25 walkthrough, per WP22's own
; allowance for vmmnoreu and the WP25 plan's reconciliation of vmmalloc4.
;
; Every check against a same-routine Fail label uses an inverted short
; branch over an inline JMP (ca65 unnamed labels, :/:+) rather than a direct
; branch to Fail: several fixtures are long enough that a direct BCS/BCC/BNE
; to their own trailing Fail label would exceed the 6502's +/-127-byte
; branch range.

.include "command64.inc"
.include "../../../src/external/casm/common.inc"

.define VERSION_MAJOR "0"
.define VERSION_MINOR "1"
.define VERSION_STAGE "0"
.include "build_test_casm_vmm.inc"

.import __MAIN_START__
.import resourcesInit
.import vmmStoreAlloc
.import vmmStoreFree
.import vmmWindowRead
.import vmmWindowWrite
.import vmmReplay
.import CasmVmmBuffer
.import CasmVmmRegistry

.export diagPrintFatal

.segment "HEADER"
    .word __MAIN_START__

.segment "CODE"

start:
    cld
    lda #$0E
    jsr KernalChROUT
    jsr resourcesInit
    lda #0
    sta FailCount

    jsr vmmalloc1
    jsr reportCase
    jsr vmmalloc2
    jsr reportCase
    jsr vmmalloc3
    jsr reportCase
    jsr vmmreplay1
    jsr reportCase
    jsr vmmoffset1
    jsr reportCase
    jsr vmmbounds1
    jsr reportCase
    jsr vmmfree1
    jsr reportCase

    lda #$0D
    jsr KernalChROUT
    lda FailCount
    beq allPass
    lda #<failMsg
    ldy #>failMsg
    jmp printResult
allPass:
    lda #<passMsg
    ldy #>passMsg
printResult:
    tax
    lda #DOS_PRINT_STR
    jsr OS_API
    lda #DOS_EXIT
    jsr OS_API

; ---------------------------------------------------------------------------
; reportCase
; Print '.' for a pass (carry clear) or 'F' for a fail (carry set), tallying
; FailCount. Called immediately after each vmmalloc*/vmmwrite*/vmmread*/
; vmmreplay*/vmmoffset*/vmmbounds*/vmmfree* fixture; JSR/RTS do not disturb
; the carry the fixture just set.
; ---------------------------------------------------------------------------
reportCase:
    bcs rcFail
    lda #$2E
    jsr KernalChROUT
    rts
rcFail:
    inc FailCount
    lda #$46
    jsr KernalChROUT
    rts

; ---------------------------------------------------------------------------
; vmmalloc1
; Allocate, verify the registry slot's SegHi/Bank/Pages fields and OWNED
; flag, remember SegHi/Bank for vmmalloc2's reuse check, free, verify the
; slot clears.
; ---------------------------------------------------------------------------
vmmalloc1:
    ldx #32
    ldy #0
    jsr vmmStoreAlloc
    bcc :+
    jmp va1Fail
:
    stx SavedSlot

    txa
    asl
    asl
    tay
    lda CasmVmmRegistry + CASM_VMM_REC_FLAG, y
    cmp #CASM_RESOURCE_OWNED
    beq :+
    jmp va1Fail
:
    lda CasmVmmRegistry + CASM_VMM_REC_PAGES, y
    cmp #1
    beq :+
    jmp va1Fail
:
    lda CasmVmmRegistry + CASM_VMM_REC_SEGHI, y
    sta PrevSegHi
    lda CasmVmmRegistry + CASM_VMM_REC_BANK, y
    sta PrevBank

    ldx SavedSlot
    jsr vmmStoreFree
    bcc :+
    jmp va1Fail
:
    lda SavedSlot
    asl
    asl
    tay
    lda CasmVmmRegistry + CASM_VMM_REC_FLAG, y
    beq :+
    jmp va1Fail
:
    clc
    rts
va1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; vmmalloc2
; Allocate the same size again; confirm SegHi/Bank match the page vmmalloc1
; just freed (proves DOS_FREE_MEM actually marked the MCT free, not just
; cleared CASM's registry). Free again.
; ---------------------------------------------------------------------------
vmmalloc2:
    ldx #32
    ldy #0
    jsr vmmStoreAlloc
    bcc :+
    jmp va2Fail
:
    stx SavedSlot

    txa
    asl
    asl
    tay
    lda CasmVmmRegistry + CASM_VMM_REC_SEGHI, y
    cmp PrevSegHi
    beq :+
    jmp va2Fail
:
    lda CasmVmmRegistry + CASM_VMM_REC_BANK, y
    cmp PrevBank
    beq :+
    jmp va2Fail
:
    ldx SavedSlot
    jsr vmmStoreFree
    bcc :+
    jmp va2Fail
:
    clc
    rts
va2Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; vmmalloc3
; Fill all 8 registry slots; confirm a 9th allocation is rejected; free all
; 8, restoring a clean registry for the remaining fixtures.
;
; The 9th allocation returns CASM_DIAG_VMM_ALLOC_FAILED, not
; CASM_DIAG_REGISTRY_FULL: vmmStoreAlloc deliberately collapses a
; registry-full resourceRegisterVmm rejection into the same diagnostic as
; an OS-level allocation failure (freeing the just-granted OS memory again
; first, per its own documented ABI from WP23) -- CASM_DIAG_REGISTRY_FULL
; is resourceRegisterVmm's internal-boundary code, not vmmStoreAlloc's
; public one. An earlier draft of this fixture expected the wrong
; diagnostic here, which made it bail out before reaching the free loop
; below and left all 8 slots permanently occupied for every fixture after
; this one -- exactly the cascading failure a first real run caught.
; ---------------------------------------------------------------------------
vmmalloc3:
    lda #0
    sta SlotCount
va3FillLoop:
    ldx #32
    ldy #0
    jsr vmmStoreAlloc
    bcc :+
    jmp va3Fail
:
    txa
    ldy SlotCount
    sta SlotTable, y
    inc SlotCount
    lda SlotCount
    cmp #8
    bne va3FillLoop

    ldx #32
    ldy #0
    jsr vmmStoreAlloc
    bcs :+
    jmp va3Fail
:
    cmp #CASM_DIAG_VMM_ALLOC_FAILED
    beq :+
    jmp va3Fail
:
    lda #0
    sta SlotCount
va3FreeLoop:
    ldy SlotCount
    ldx SlotTable, y
    jsr vmmStoreFree
    bcc :+
    jmp va3Fail
:
    inc SlotCount
    lda SlotCount
    cmp #8
    bne va3FreeLoop
    clc
    rts
va3Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; vmmreplay1
; Covers vmmwrite1/vmmread1/vmmreplay1 together: allocate, write a known
; pattern (kept in RefPattern, outside CasmVmmBuffer) via vmmWindowWrite,
; zero-discard CasmVmmBuffer, read it back via vmmWindowRead and compare
; against RefPattern, then refill CasmVmmBuffer and exercise vmmReplay
; directly, comparing again. Free the allocation.
; ---------------------------------------------------------------------------
vmmreplay1:
    ldx #32
    ldy #0
    jsr vmmStoreAlloc
    bcc :+
    jmp vr1Fail
:
    stx SavedSlot

    ldy #0
vr1Fill:
    tya
    sta CasmVmmBuffer, y
    sta RefPattern, y
    iny
    cpy #16
    bne vr1Fill

    ldx SavedSlot
    lda #0
    sta CasmVmmOffLo
    sta CasmVmmOffHi
    lda #16
    sta CasmIoLenLo
    lda #0
    sta CasmIoLenHi
    jsr vmmWindowWrite
    bcc :+
    jmp vr1Fail
:
    ldy #0
vr1Zero:
    lda #0
    sta CasmVmmBuffer, y
    iny
    cpy #16
    bne vr1Zero

    ldx SavedSlot
    lda #0
    sta CasmVmmOffLo
    sta CasmVmmOffHi
    lda #16
    sta CasmIoLenLo
    lda #0
    sta CasmIoLenHi
    jsr vmmWindowRead
    bcc :+
    jmp vr1Fail
:
    ldy #0
vr1Cmp1:
    lda CasmVmmBuffer, y
    cmp RefPattern, y
    beq :+
    jmp vr1Fail
:
    iny
    cpy #16
    bne vr1Cmp1

    ldy #0
vr1Refill:
    lda RefPattern, y
    sta CasmVmmBuffer, y
    iny
    cpy #16
    bne vr1Refill

    ldx SavedSlot
    lda #0
    sta CasmVmmOffLo
    sta CasmVmmOffHi
    lda #16
    sta CasmIoLenLo
    lda #0
    sta CasmIoLenHi
    jsr vmmReplay
    bcc :+
    jmp vr1Fail
:
    ldy #0
vr1Cmp2:
    lda CasmVmmBuffer, y
    cmp RefPattern, y
    beq :+
    jmp vr1Fail
:
    iny
    cpy #16
    bne vr1Cmp2

    ldx SavedSlot
    jsr vmmStoreFree
    bcc :+
    jmp vr1Fail
:
    clc
    rts
vr1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; vmmoffset1
; Allocate the full 65536-byte (16-page) cap; confirm a window ending
; exactly at the last valid byte succeeds and a window one step further
; (which cannot avoid a 16-bit offset+count overflow at this exact
; boundary) is rejected.
; ---------------------------------------------------------------------------
vmmoffset1:
    ldx #$FF
    ldy #$FF
    jsr vmmStoreAlloc
    bcc :+
    jmp vo1Fail
:
    stx SavedSlot

    ldx SavedSlot
    lda #<65504
    sta CasmVmmOffLo
    lda #>65504
    sta CasmVmmOffHi
    lda #32
    sta CasmIoLenLo
    lda #0
    sta CasmIoLenHi
    jsr vmmWindowRead
    bcc :+
    jmp vo1Fail
:
    ldx SavedSlot
    lda #<65505
    sta CasmVmmOffLo
    lda #>65505
    sta CasmVmmOffHi
    lda #32
    sta CasmIoLenLo
    lda #0
    sta CasmIoLenHi
    jsr vmmWindowRead
    bcs :+
    jmp vo1Fail
:
    ldx SavedSlot
    jsr vmmStoreFree
    bcc :+
    jmp vo1Fail
:
    clc
    rts
vo1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; vmmbounds1
; Allocate a single page (4096 granted bytes); confirm a deliberately
; oversized offset+count within 16-bit range but beyond the granted page
; count is rejected locally, before any OS call.
; ---------------------------------------------------------------------------
vmmbounds1:
    ldx #32
    ldy #0
    jsr vmmStoreAlloc
    bcc :+
    jmp vb1Fail
:
    stx SavedSlot

    ldx SavedSlot
    lda #<4090
    sta CasmVmmOffLo
    lda #>4090
    sta CasmVmmOffHi
    lda #32
    sta CasmIoLenLo
    lda #0
    sta CasmIoLenHi
    jsr vmmWindowRead
    bcs :+
    jmp vb1Fail
:
    ldx SavedSlot
    jsr vmmStoreFree
    bcc :+
    jmp vb1Fail
:
    clc
    rts
vb1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; vmmfree1
; Allocate, free, then confirm a transfer against the now-freed slot is
; rejected by CASM's own registry state, not chance REU contents.
; ---------------------------------------------------------------------------
vmmfree1:
    ldx #32
    ldy #0
    jsr vmmStoreAlloc
    bcc :+
    jmp vf1Fail
:
    stx SavedSlot

    ldx SavedSlot
    jsr vmmStoreFree
    bcc :+
    jmp vf1Fail
:
    ldx SavedSlot
    lda #0
    sta CasmVmmOffLo
    sta CasmVmmOffHi
    lda #16
    sta CasmIoLenLo
    lda #0
    sta CasmIoLenHi
    jsr vmmWindowRead
    bcs :+
    jmp vf1Fail
:
    clc
    rts
vf1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; diagPrintFatal (stub)
; resources.s's exitSuccess/exitFatal reference this; this harness never
; calls either, so a trivial stub satisfies the link without pulling in the
; real diagnostics.s (and transitively lexer.s/source.s). See the file
; header for the full rationale.
; ---------------------------------------------------------------------------
diagPrintFatal:
    rts

.segment "RODATA"

passMsg:
    .byte "CASM VMM: PASS", PetCr, 0
failMsg:
    .byte "CASM VMM: FAIL", PetCr, 0

.segment "BSS"

FailCount:  .res 1
SavedSlot:  .res 1
PrevSegHi:  .res 1
PrevBank:   .res 1
SlotCount:  .res 1
SlotTable:  .res 8
RefPattern: .res 16
