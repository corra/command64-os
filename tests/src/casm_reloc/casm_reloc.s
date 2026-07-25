; tests/src/casm_reloc/casm_reloc.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; Standalone CASM Phase 8 WP40 relocation-table fixture harness. Exercises
; reloc.s's relocInit/relocRecord directly against real DOS_ALLOC_MEM/
; DOS_VMM_READ/DOS_VMM_WRITE calls -- no R6 footer exists yet (WP41) for
; any end-to-end fixture to observe the table's contents, so this harness
; is the only real proof of relocRecord's offset arithmetic, sequential
; append, and capacity behavior, mirroring the casm_symbols.s/casm_vmm.s
; isolated-module-first precedent named in the WP40 plan.
;
; reloc.s imports CasmPc/CasmPassMode from emit.s, which this harness
; deliberately does not link (matching casm_symbols.s/casm_vmm.s's own
; isolation from lexer.s/source.s/parser.s) -- this file provides its own
; small stand-in copies, exported, which its own test logic pokes directly
; to drive relocRecord's inputs. This is not just a link-satisfying stub:
; directly controlling CasmPc lets each fixture assert relocRecord's exact
; offset arithmetic (CasmPc - CASM_DEFAULT_ORIGIN) precisely.
;
; Stubs diagPrintFatal locally rather than importing the real diagnostics.s,
; for the same reason casm_vmm.s/casm_symbols.s already do: resources.s's
; exitSuccess/exitFatal reference it, and ld65 links whole object files, so
; it must resolve even though this harness never calls exitSuccess/exitFatal.

.include "command64.inc"
.include "../../../src/external/casm/common.inc"

.define VERSION_MAJOR "0"
.define VERSION_MINOR "1"
.define VERSION_STAGE "0"
.include "build_test_casm_reloc.inc"

.import __MAIN_START__
.import resourcesInit
.import relocInit
.import relocRecord
.import CasmRelocVmmSlot
.import vmmWindowRead
.import CasmVmmBuffer

.export diagPrintFatal
.export CasmPc
.export CasmPassMode

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

    jsr relocinit1
    jsr reportCase
    jsr relocrecord1
    jsr reportCase
    jsr relocmeasure1
    jsr reportCase
    jsr relocfull1
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
; FailCount. Called immediately after each fixture; JSR/RTS do not disturb
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
; relocinit1
; Allocate the table; confirm success. Leaves the allocation in place for
; relocrecord1/relocmeasure1 to share (matching casm_vmm.s's vmmreplay1
; precedent of chaining related checks against one allocation).
; ---------------------------------------------------------------------------
relocinit1:
    jsr relocInit
    bcc :+
    jmp ri1Fail
:
    clc
    rts
ri1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; relocrecord1
; Append three entries at distinct CasmPc values under EMIT mode, then read
; the table back through vmmWindowRead and confirm each entry equals
; CasmPc - CASM_DEFAULT_ORIGIN, little-endian, in the order recorded.
; ---------------------------------------------------------------------------
relocrecord1:
    lda #CASM_PASS_MODE_EMIT
    sta CasmPassMode

    ; Entry 0: CasmPc = CASM_DEFAULT_ORIGIN -> offset 0.
    lda #<CASM_DEFAULT_ORIGIN
    sta CasmPc
    lda #>CASM_DEFAULT_ORIGIN
    sta CasmPc + 1
    jsr relocRecord
    bcc :+
    jmp rr1Fail
:
    ; Entry 1: CasmPc = CASM_DEFAULT_ORIGIN + 5 -> offset 5.
    lda #<(CASM_DEFAULT_ORIGIN + 5)
    sta CasmPc
    lda #>(CASM_DEFAULT_ORIGIN + 5)
    sta CasmPc + 1
    jsr relocRecord
    bcc :+
    jmp rr1Fail
:
    ; Entry 2: CasmPc = CASM_DEFAULT_ORIGIN + $FF -> offset $FF.
    lda #<(CASM_DEFAULT_ORIGIN + $FF)
    sta CasmPc
    lda #>(CASM_DEFAULT_ORIGIN + $FF)
    sta CasmPc + 1
    jsr relocRecord
    bcc :+
    jmp rr1Fail
:
    ; Read the 6 written bytes back and check each little-endian entry.
    ldx CasmRelocVmmSlot
    lda #0
    sta CasmVmmOffLo
    sta CasmVmmOffHi
    lda #6
    sta CasmIoLenLo
    lda #0
    sta CasmIoLenHi
    jsr vmmWindowRead
    bcc :+
    jmp rr1Fail
:
    lda CasmVmmBuffer + 0
    cmp #0
    bne rr1Fail
    lda CasmVmmBuffer + 1
    cmp #0
    bne rr1Fail
    lda CasmVmmBuffer + 2
    cmp #5
    bne rr1Fail
    lda CasmVmmBuffer + 3
    cmp #0
    bne rr1Fail
    lda CasmVmmBuffer + 4
    cmp #$FF
    bne rr1Fail
    lda CasmVmmBuffer + 5
    cmp #0
    bne rr1Fail
    clc
    rts
rr1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; relocmeasure1
; Confirm relocRecord no-ops under CASM_PASS_MODE_MEASURE: call it once in
; MEASURE mode (must succeed but append nothing), then switch back to EMIT
; and record one more real entry. If MEASURE had incorrectly advanced the
; entry count, this real entry would land at byte offset 8 instead of 6;
; reading offset 6 back and confirming it holds the new value (not
; relocrecord1's untouched trailing garbage) proves MEASURE mode appended
; nothing.
; ---------------------------------------------------------------------------
relocmeasure1:
    lda #CASM_PASS_MODE_MEASURE
    sta CasmPassMode
    lda #<(CASM_DEFAULT_ORIGIN + $22)
    sta CasmPc
    lda #>(CASM_DEFAULT_ORIGIN + $22)
    sta CasmPc + 1
    jsr relocRecord
    bcc :+
    jmp rm1Fail
:
    lda #CASM_PASS_MODE_EMIT
    sta CasmPassMode
    lda #<(CASM_DEFAULT_ORIGIN + $77)
    sta CasmPc
    lda #>(CASM_DEFAULT_ORIGIN + $77)
    sta CasmPc + 1
    jsr relocRecord
    bcc :+
    jmp rm1Fail
:
    ldx CasmRelocVmmSlot
    lda #6
    sta CasmVmmOffLo
    lda #0
    sta CasmVmmOffHi
    lda #2
    sta CasmIoLenLo
    lda #0
    sta CasmIoLenHi
    jsr vmmWindowRead
    bcc :+
    jmp rm1Fail
:
    lda CasmVmmBuffer + 0
    cmp #$77
    bne rm1Fail
    lda CasmVmmBuffer + 1
    cmp #0
    bne rm1Fail
    clc
    rts
rm1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; relocfull1
; Fresh allocation (its own relocInit, independent of relocinit1's), filled
; to exactly CASM_RELOC_MAX entries under EMIT mode; confirm every one of
; those succeeds, then confirm the next call fails with
; CASM_DIAG_RELOC_TABLE_FULL. A real fill, not a poked shortcut, matching
; casm_vmm.s's vmmalloc3 precedent (actually filling all 8 registry slots
; rather than asserting the boundary indirectly).
; ---------------------------------------------------------------------------
relocfull1:
    jsr relocInit
    bcc :+
    jmp rf1Fail
:
    lda #CASM_PASS_MODE_EMIT
    sta CasmPassMode
    lda #<CASM_DEFAULT_ORIGIN
    sta CasmPc
    lda #>CASM_DEFAULT_ORIGIN
    sta CasmPc + 1

    lda #<CASM_RELOC_MAX
    sta LoopLo
    lda #>CASM_RELOC_MAX
    sta LoopHi
rf1Loop:
    jsr relocRecord
    bcc rf1Continue
    jmp rf1Fail
rf1Continue:
    lda LoopLo
    bne rf1DecLo
    dec LoopHi
rf1DecLo:
    dec LoopLo
    lda LoopLo
    ora LoopHi
    bne rf1Loop

    ; Table is now exactly full; one more call must fail with
    ; CASM_DIAG_RELOC_TABLE_FULL specifically, not merely "some" failure.
    jsr relocRecord
    bcs :+
    jmp rf1Fail
:
    cmp #CASM_DIAG_RELOC_TABLE_FULL
    beq :+
    jmp rf1Fail
:
    clc
    rts
rf1Fail:
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
    .byte "CASM RELOC: PASS", PetCr, 0
failMsg:
    .byte "CASM RELOC: FAIL", PetCr, 0

.segment "BSS"

FailCount: .res 1
LoopLo:    .res 1
LoopHi:    .res 1
CasmPc:         .res 2
CasmPassMode:   .res 1
