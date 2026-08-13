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
;
; WP41: reloc.s now also references CasmRelocatableMode (emit.s) and
; fileWrite (fileio.s) via relocFinalize -- unreachable from this harness's
; own fixtures (none of which call relocFinalize; the real proof of its
; correctness is the end-to-end fixture matrix per the WP41 plan, since it
; needs a real open output file), but must still resolve at link time.
; CasmRelocatableMode gets its own small stand-in, matching CasmPc/
; CasmPassMode above; fileWrite is a trivial stub, matching diagPrintFatal's
; own precedent below.

.include "command64.inc"
.include "../../../src/external/casm/common.inc"

.define VERSION_MAJOR "0"
.define VERSION_MINOR "1"
.define VERSION_STAGE "0"
.include "build_test_casm_reloc.inc"

.import __MAIN_START__
.import resourcesInit
.import resourcesCleanup
.import relocInit
.import relocRecord
.import relocFinalize
.import CasmRelocVmmSlot
.import vmmWindowRead
.import CasmVmmBuffer

.export diagPrintFatal
.export CasmPc
.export CasmPassMode
.export CasmRelocatableMode
.export fileWrite

; WP60 Increment 7: fileWrite stub's source pointer, needed as a real
; zero-page location for (zp),y indirect-indexed addressing -- nothing else
; in this harness uses zero page (no parser/lexer linked), so this pair is
; free.
CasmFwSrcLo = $72
CasmFwSrcHi = $73

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

    ; WP60 Increment 7: each allocates its own fresh VMM slot via relocInit.
    jsr relocempty1
    jsr reportCase
    jsr relocoffmax1
    jsr reportCase
    jsr relocfinalize4096_1
    jsr reportCase

    ; WP41 fix: relocinit1/relocfull1 each allocate their own VMM slot via
    ; relocInit (relocinit1's shared by relocrecord1/relocmeasure1;
    ; relocfull1's own fresh one) and neither is ever freed within this
    ; harness's own fixtures, unlike casm_vmm.s's self-contained
    ; alloc-then-free-within-one-fixture pattern. Without this call, both
    ; leak permanently at the OS/REU level (DOS_ALLOC_MEM's tracked
    ; capacity, not just this program's own 8-slot registry, which a fresh
    ; DOS_EXIT does not implicitly release) -- a real defect a later WP41
    ; runtime verification pass caught: a subsequent, unrelated test
    ; harness run in the same VICE session failed every one of its own
    ; VMM allocations after this harness ran without freeing first.
    ; resourcesCleanup frees every registered VMM slot generically, exactly
    ; the mechanism casm.s's own exitSuccess/exitFatal already rely on.
    jsr resourcesCleanup

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
; relocempty1
; WP60 Increment 7: R6 footer at the empty-table extreme (0 entries).
; Fresh allocation, no relocRecord calls at all, then relocFinalize under
; CasmRelocatableMode=1 (the no-op EARLY OUT is for mode=0, not entry
; count -- an empty *relocatable* table must still finalize and write a
; real 6-byte footer with count=0, not skip output entirely). fileWrite's
; stub below always captures its most recent call's bytes into
; LastWriteBuf/LastWriteLen; relocFinalize's own table-copy loop is
; skipped entirely when CasmRelocCount=0 (Remaining=0*2=0 on entry), so
; the footer write is this call's ONLY fileWrite, making LastWriteBuf
; unambiguously the footer here.
; ---------------------------------------------------------------------------
relocempty1:
    jsr relocInit
    bcc :+
    jmp re1Fail
:
    lda #1
    sta CasmRelocatableMode
    jsr relocFinalize
    bcc :+
    jmp re1Fail
:
    lda LastWriteLen
    cmp #6
    beq :+
    jmp re1Fail
:
    lda LastWriteBuf + 0
    cmp #<CASM_DEFAULT_ORIGIN
    beq :+
    jmp re1Fail
:
    lda LastWriteBuf + 1
    cmp #>CASM_DEFAULT_ORIGIN
    beq :+
    jmp re1Fail
:
    lda LastWriteBuf + 2         ; count lo -- must be 0
    bne re1Fail
    lda LastWriteBuf + 3         ; count hi -- must be 0
    bne re1Fail
    lda LastWriteBuf + 4
    cmp #CASM_R6_MAGIC_0
    beq :+
    jmp re1Fail
:
    lda LastWriteBuf + 5
    cmp #CASM_R6_MAGIC_1
    beq :+
    jmp re1Fail
:
    clc
    rts
re1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; relocoffmax1
; WP60 Increment 7: offset $FFFF (relocRecord's own unsigned
; CasmPc-CASM_DEFAULT_ORIGIN subtraction wraps to $FFFF when
; CasmPc = CASM_DEFAULT_ORIGIN-1, the one CasmPc value below the default
; origin that is still a valid 16-bit address). Fresh allocation.
; ---------------------------------------------------------------------------
relocoffmax1:
    jsr relocInit
    bcc :+
    jmp rom1Fail
:
    lda #CASM_PASS_MODE_EMIT
    sta CasmPassMode
    lda #<(CASM_DEFAULT_ORIGIN - 1)
    sta CasmPc
    lda #>(CASM_DEFAULT_ORIGIN - 1)
    sta CasmPc + 1
    jsr relocRecord
    bcc :+
    jmp rom1Fail
:
    ldx CasmRelocVmmSlot
    lda #0
    sta CasmVmmOffLo
    sta CasmVmmOffHi
    lda #2
    sta CasmIoLenLo
    lda #0
    sta CasmIoLenHi
    jsr vmmWindowRead
    bcc :+
    jmp rom1Fail
:
    lda CasmVmmBuffer + 0
    cmp #$FF
    beq :+
    jmp rom1Fail
:
    lda CasmVmmBuffer + 1
    cmp #$FF
    beq :+
    jmp rom1Fail
:
    clc
    rts
rom1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; relocfinalize4096_1
; WP60 Increment 7: R6 footer at the full-table extreme (4096 entries,
; distinct from relocfull1's own fill -- that fixture's loop never
; advances CasmPc, so every one of its 4096 entries records the same $0000
; offset, which cannot prove anything about distinct per-entry content)
; AND replay/re-read bounds near the table's real 8,192-byte extent
; (relocrecord1/relocmeasure1 only ever re-read at VMM offsets 0/6).
; Fresh allocation; CasmPc = CASM_DEFAULT_ORIGIN+i for i=0..4095, so
; entry i's recorded offset is i itself. After filling, vmmWindowRead the
; table's LAST 6 bytes (VMM offset 8186, entries 4093/4094/4095) and
; confirm each little-endian value matches its own index -- direct
; evidence the near-full-extent region holds real, distinct, correctly
; addressed content, not stale/aliased bytes from an earlier iteration.
; Then relocFinalize and confirm the footer's count field reads 4096.
; ---------------------------------------------------------------------------
relocfinalize4096_1:
    jsr relocInit
    bcc :+
    jmp rfz1Fail
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
rfz1Loop:
    jsr relocRecord
    bcc rfz1Continue
    jmp rfz1Fail
rfz1Continue:
    inc CasmPc
    bne :+
    inc CasmPc + 1
:
    lda LoopLo
    bne rfz1DecLo
    dec LoopHi
rfz1DecLo:
    dec LoopLo
    lda LoopLo
    ora LoopHi
    bne rfz1Loop

    ; Read the last 6 bytes of the 8192-byte table (entries 4093/4094/4095,
    ; VMM byte offset 4093*2 = 8186).
    ldx CasmRelocVmmSlot
    lda #<8186
    sta CasmVmmOffLo
    lda #>8186
    sta CasmVmmOffHi
    lda #6
    sta CasmIoLenLo
    lda #0
    sta CasmIoLenHi
    jsr vmmWindowRead
    bcc :+
    jmp rfz1Fail
:
    lda CasmVmmBuffer + 0        ; entry 4093 lo = <4093
    cmp #<4093
    beq :+
    jmp rfz1Fail
:
    lda CasmVmmBuffer + 1        ; entry 4093 hi = >4093
    cmp #>4093
    beq :+
    jmp rfz1Fail
:
    lda CasmVmmBuffer + 2        ; entry 4094 lo = <4094
    cmp #<4094
    beq :+
    jmp rfz1Fail
:
    lda CasmVmmBuffer + 3        ; entry 4094 hi = >4094
    cmp #>4094
    beq :+
    jmp rfz1Fail
:
    lda CasmVmmBuffer + 4        ; entry 4095 lo = <4095
    cmp #<4095
    beq :+
    jmp rfz1Fail
:
    lda CasmVmmBuffer + 5        ; entry 4095 hi = >4095
    cmp #>4095
    beq :+
    jmp rfz1Fail
:

    lda #1
    sta CasmRelocatableMode
    jsr relocFinalize
    bcc :+
    jmp rfz1Fail
:
    lda LastWriteLen
    cmp #6
    beq :+
    jmp rfz1Fail
:
    lda LastWriteBuf + 2         ; count lo = <4096 = 0
    bne rfz1Fail
    lda LastWriteBuf + 3         ; count hi = >4096 = 16 ($10)
    cmp #>CASM_RELOC_MAX
    beq :+
    jmp rfz1Fail
:
    clc
    rts
rfz1Fail:
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

; ---------------------------------------------------------------------------
; fileWrite (stub)
; reloc.s's relocFinalize references this. WP60 Increment 7: now captures
; every call's bytes into LastWriteBuf/LastWriteLen (overwriting the
; previous call each time), rather than the old discard-everything stub --
; relocFinalize's footer write is always its LAST fileWrite call
; regardless of table size (0 or CASM_RELOC_MAX), so by the time
; relocFinalize returns, LastWriteBuf unambiguously holds the 6-byte
; footer for relocempty1/relocfinalize4096_1 to inspect. CASM_VMM_BUFFER_SIZE
; (64) bounds every possible chunk length relocFinalize ever passes,
; matching LastWriteBuf's own size.
; ---------------------------------------------------------------------------
fileWrite:
    stx CasmFwSrcLo
    sty CasmFwSrcHi
    lda CasmIoLenLo
    sta LastWriteLen
    ldy #0
fwCopyLoop:
    cpy LastWriteLen
    beq fwCopyDone
    lda (CasmFwSrcLo), y
    sta LastWriteBuf, y
    iny
    jmp fwCopyLoop
fwCopyDone:
    clc
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
CasmRelocatableMode: .res 1

; WP60 Increment 7: fileWrite stub's capture state (see its own header).
LastWriteBuf: .res CASM_VMM_BUFFER_SIZE
LastWriteLen: .res 1
