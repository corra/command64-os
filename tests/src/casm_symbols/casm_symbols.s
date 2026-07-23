; tests/src/casm_symbols/casm_symbols.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; Standalone CASM Phase 6B symbol-table fixture harness (WP27). Exercises
; symbols.s's symbolsInit/symbolsInsert/symbolsLookup directly, the same way
; test_casm_vmm.s (WP25) exercises vmm_store.s's routines directly --
; symbols.s has no parser/emit call site yet (WP28 is what wires it into
; real assembly), so this cannot be an ordinary .seq source fixture either.
; Each case is a sequential real operation against ONE shared symbol table
; (not an independent data-driven table), matching test_casm_vmm.s's own
; sequential-fixture precedent: later fixtures rely on state earlier ones
; left behind (symlook1 looks up the name symins1 inserted; symfull1 counts
; on the exact number of symbols every earlier fixture already inserted).
;
; Stubs diagPrintFatal locally rather than importing the real diagnostics.s:
; resources.s's exitSuccess/exitFatal reference it, and since ld65 links
; whole object files, importing resourcesInit alone would otherwise drag in
; diagnostics.s's own lexer.s/source.s dependencies even though this harness
; never calls exitSuccess/exitFatal. Matches WP25's casm_vmm.s (and WP20's
; casm_expr.s before it), which stubbed the same symbol for the same reason.
;
; Every check against a same-routine Fail label uses an inverted short
; branch over an inline JMP (ca65 unnamed labels, :/:+) rather than a direct
; branch to Fail, matching casm_vmm.s's own convention -- several fixtures
; below (symchain1, symfull1) are long enough that a direct branch to their
; own trailing Fail label would exceed the 6502's +/-127-byte range.
;
; sympad1 needed symbols.s to export CasmSymbolVmmSlot so a fixture could
; address the symbol table's VMM allocation directly with vmmWindowRead;
; that export has been added (a one-line addition to symbols.s -- the BSS
; storage already existed) and this fixture is now fully implemented.

.include "command64.inc"
.include "../../../src/external/casm/common.inc"

.define VERSION_MAJOR "0"
.define VERSION_MINOR "1"
.define VERSION_STAGE "0"
.include "build_test_casm_symbols.inc"

.import __MAIN_START__
.import resourcesInit
.import symbolsInit
.import symbolsInsert
.import symbolsLookup
.import CasmSymbolVmmSlot
.import vmmWindowRead
.import CasmVmmBuffer

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

    jsr syminit1
    jsr reportCase
    jsr symins1
    jsr reportCase
    jsr symlook1
    jsr reportCase
    jsr symlookmiss1
    jsr reportCase
    jsr symdup1
    jsr reportCase
    jsr symcase1
    jsr reportCase
    jsr symchain1
    jsr reportCase
    jsr symlen1
    jsr reportCase
    jsr sympad1
    jsr reportCase
    jsr symfull1
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
; FailCount. Called immediately after each fixture below; JSR/RTS do not
; disturb the carry the fixture just set.
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
; syminit1
; symbolsInit must reset all local index state (VMM slot, bump count, and
; the 128-entry bucket array) on a fresh table. Neither CasmSymbolCount nor
; CasmSymbolBuckets is exported by symbols.s (only symbolsInit/Insert/Lookup
; are), so this fixture verifies the bucket reset indirectly: a
; symbolsLookup for a name that has never been inserted must report "not
; found" immediately after symbolsInit. If the bucket array had been left
; as garbage rather than reset to CASM_SYMBOL_CHAIN_END ($FFFF), a stray
; nonzero cursor could make symbolsFindChain misread an arbitrary VMM record
; as a false match.
; ---------------------------------------------------------------------------
syminit1:
    jsr symbolsInit
    bcc :+
    jmp in1Fail
:
    lda #<nameInitCheck
    sta CasmPtr0Lo
    lda #>nameInitCheck
    sta CasmPtr0Hi
    lda #9                   ; "INITCHECK" length
    ldx #<ResolveView
    ldy #>ResolveView
    jsr symbolsLookup
    bcc :+
    jmp in1Fail
:
    lda ResolveView + CASM_RESOLVE_FLAGS
    beq :+
    jmp in1Fail
:
    clc
    rts
in1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; symins1
; Insert one symbol into the fresh table syminit1 just reset. Assert C
; clear and that the returned record index is 0 (X/Y both zero): the very
; first insert after a fresh symbolsInit must land at array offset 0.
; ---------------------------------------------------------------------------
symins1:
    lda #<nameLoop
    sta CasmPtr0Lo
    lda #>nameLoop
    sta CasmPtr0Hi
    lda #4
    ldx #$34
    ldy #$12
    jsr symbolsInsert
    bcc :+
    jmp ins1Fail
:
    cpx #0
    beq :+
    jmp ins1Fail
:
    cpy #0
    beq :+
    jmp ins1Fail
:
    clc
    rts
ins1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; symlook1
; Look up the name symins1 just inserted (same shared table state). Assert
; RESOLVED is set, the value round-trips, and the reported record index is
; the 0 symins1 received.
; ---------------------------------------------------------------------------
symlook1:
    lda #<nameLoop
    sta CasmPtr0Lo
    lda #>nameLoop
    sta CasmPtr0Hi
    lda #4
    ldx #<ResolveView
    ldy #>ResolveView
    jsr symbolsLookup
    bcc :+
    jmp lk1Fail
:
    lda ResolveView + CASM_RESOLVE_FLAGS
    and #CASM_EXPR_FLAG_RESOLVED
    bne :+
    jmp lk1Fail
:
    lda ResolveView + CASM_RESOLVE_VAL_LO
    cmp #$34
    beq :+
    jmp lk1Fail
:
    lda ResolveView + CASM_RESOLVE_VAL_HI
    cmp #$12
    beq :+
    jmp lk1Fail
:
    lda ResolveView + CASM_RESOLVE_ID_LO
    bne lk1Fail
    lda ResolveView + CASM_RESOLVE_ID_HI
    bne lk1Fail
    clc
    rts
lk1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; symlookmiss1
; Look up a name that was never inserted, distinct from every name used
; anywhere else in this sequential run. Assert C clear (always, per the
; ABI -- "not found" is reported through the view, not through carry) and
; RESOLVED clear.
; ---------------------------------------------------------------------------
symlookmiss1:
    lda #<nameNever
    sta CasmPtr0Lo
    lda #>nameNever
    sta CasmPtr0Hi
    lda #12                  ; "NEVERDEFINED" length
    ldx #<ResolveView
    ldy #>ResolveView
    jsr symbolsLookup
    bcc :+
    jmp lkm1Fail
:
    lda ResolveView + CASM_RESOLVE_FLAGS
    beq :+
    jmp lkm1Fail
:
    clc
    rts
lkm1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; symdup1
; Insert the same name symins1 already defined. Assert C set and
; A = CASM_DIAG_DUPLICATE_SYMBOL; an unexpected success, or any other
; diagnostic, is a fixture failure.
; ---------------------------------------------------------------------------
symdup1:
    lda #<nameLoop
    sta CasmPtr0Lo
    lda #>nameLoop
    sta CasmPtr0Hi
    lda #4
    ldx #$99
    ldy #$88
    jsr symbolsInsert
    bcs :+
    jmp dup1Fail
:
    cmp #CASM_DIAG_DUPLICATE_SYMBOL
    beq :+
    jmp dup1Fail
:
    clc
    rts
dup1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; symcase1
; Insert two names differing only in letter case ("Case" vs. "CASE"; a
; fresh pair, since "LOOP" is already taken by symins1/symdup1 in this
; shared table). Assert BOTH inserts succeed with C clear and land at
; different record indices, proving the table compares names exactly
; case-sensitively rather than folding case (a case-folding bug would make
; the second insert wrongly report CASM_DIAG_DUPLICATE_SYMBOL, or -- if it
; folded but still let the duplicate through some other path -- reuse the
; first insert's record index).
; ---------------------------------------------------------------------------
symcase1:
    lda #<nameCaseLower
    sta CasmPtr0Lo
    lda #>nameCaseLower
    sta CasmPtr0Hi
    lda #4
    ldx #$01
    ldy #$00
    jsr symbolsInsert
    bcc :+
    jmp cs1Fail
:
    stx CaseIdxLoFirst
    sty CaseIdxHiFirst

    lda #<nameCaseUpper
    sta CasmPtr0Lo
    lda #>nameCaseUpper
    sta CasmPtr0Hi
    lda #4
    ldx #$02
    ldy #$00
    jsr symbolsInsert
    bcc :+
    jmp cs1Fail
:
    cpx CaseIdxLoFirst
    bne :+
    cpy CaseIdxHiFirst
    bne :+
    jmp cs1Fail
:
    clc
    rts
cs1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; symchain1
; Insert CASM_SYMBOL_BUCKET_COUNT + 1 (129) distinct names -- a guaranteed
; collision by pigeonhole against the 128 buckets, regardless of hash
; distribution -- then look up every one of them and assert each is found
; with its correct value. Names are generated programmatically (a fixed
; 2-byte "CH" prefix plus a 1-byte loop counter, 0..128) rather than as 129
; literal fixture lines; the counter also doubles as the stored value
; (Lo = counter, Hi = 0) so the verify pass has an independent expected
; value to check against, proving chain-walk correctness rather than just
; chain-walk termination.
; ---------------------------------------------------------------------------
symchain1:
    lda #$43                 ; 'C'
    sta ChainNameBuf
    lda #$48                 ; 'H'
    sta ChainNameBuf + 1

    lda #0
    sta ChainCounter
ch1FillLoop:
    lda ChainCounter
    sta ChainNameBuf + 2
    lda #<ChainNameBuf
    sta CasmPtr0Lo
    lda #>ChainNameBuf
    sta CasmPtr0Hi
    lda #3
    ldx ChainCounter
    ldy #0
    jsr symbolsInsert
    bcc :+
    jmp ch1Fail
:
    inc ChainCounter
    lda ChainCounter
    cmp #129
    bne ch1FillLoop

    lda #0
    sta ChainCounter
ch1VerifyLoop:
    lda ChainCounter
    sta ChainNameBuf + 2
    lda #<ChainNameBuf
    sta CasmPtr0Lo
    lda #>ChainNameBuf
    sta CasmPtr0Hi
    lda #3
    ldx #<ResolveView
    ldy #>ResolveView
    jsr symbolsLookup
    bcc :+
    jmp ch1Fail
:
    lda ResolveView + CASM_RESOLVE_FLAGS
    and #CASM_EXPR_FLAG_RESOLVED
    bne :+
    jmp ch1Fail
:
    lda ResolveView + CASM_RESOLVE_VAL_LO
    cmp ChainCounter
    beq :+
    jmp ch1Fail
:
    lda ResolveView + CASM_RESOLVE_VAL_HI
    beq :+
    jmp ch1Fail
:
    inc ChainCounter
    lda ChainCounter
    cmp #129
    bne ch1VerifyLoop

    clc
    rts
ch1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; symlen1
; Insert a name exactly 31 bytes long (the maximum symbolsInsert accepts),
; look it up, and assert it round-trips correctly with no truncation.
; ---------------------------------------------------------------------------
symlen1:
    lda #<nameLen31
    sta CasmPtr0Lo
    lda #>nameLen31
    sta CasmPtr0Hi
    lda #31
    ldx #$78
    ldy #$56
    jsr symbolsInsert
    bcc :+
    jmp ln1Fail
:
    lda #<nameLen31
    sta CasmPtr0Lo
    lda #>nameLen31
    sta CasmPtr0Hi
    lda #31
    ldx #<ResolveView
    ldy #>ResolveView
    jsr symbolsLookup
    bcc :+
    jmp ln1Fail
:
    lda ResolveView + CASM_RESOLVE_FLAGS
    and #CASM_EXPR_FLAG_RESOLVED
    bne :+
    jmp ln1Fail
:
    lda ResolveView + CASM_RESOLVE_VAL_LO
    cmp #$78
    beq :+
    jmp ln1Fail
:
    lda ResolveView + CASM_RESOLVE_VAL_HI
    cmp #$56
    beq :+
    jmp ln1Fail
:
    clc
    rts
ln1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; sympad1
; Directly read back record index 0's raw 64-byte VMM record (the "LOOP"
; symbol symins1 inserted -- still valid and unmutated; nothing in this
; harness ever overwrites an existing record) via vmmWindowRead, addressed
; through symbols.s's exported CasmSymbolVmmSlot, and confirm all 27 reserved
; padding bytes (offsets 37..63) are zero -- proving symbolsInsert's
; zero-fill-then-populate staging never leaves stale bytes in the reserved
; region.
; ---------------------------------------------------------------------------
sympad1:
    lda #0
    sta CasmVmmOffLo
    sta CasmVmmOffHi         ; record index 0 -> VMM offset 0
    lda #CASM_SYMBOL_REC_SIZE
    sta CasmIoLenLo
    lda #0
    sta CasmIoLenHi
    ldx CasmSymbolVmmSlot
    jsr vmmWindowRead
    bcc :+
    jmp pad1Fail
:
    ldy #37                  ; first reserved padding byte
pad1CheckLoop:
    lda CasmVmmBuffer, y
    beq pad1Next
    jmp pad1Fail
pad1Next:
    iny
    cpy #CASM_SYMBOL_REC_SIZE
    bne pad1CheckLoop

    clc
    rts
pad1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; symfull1
; Insert CASM_SYMBOL_MAX (512) distinct symbols total, then assert the next
; insert is rejected with CASM_DIAG_SYMBOL_TABLE_FULL.
;
; By this point in the sequential run the shared table already holds 133
; symbols: 1 from symins1 ("LOOP"; symdup1's duplicate attempt added
; nothing), 2 from symcase1 ("Case"/"CASE"), 129 from symchain1 (its "CH" +
; counter batch), and 1 from symlen1 (its 31-byte name) -- sympad1 performs
; no insert of its own. This fixture therefore only needs to insert
; 512 - 133 = 379 MORE distinct names (a fixed "SF" prefix plus a 16-bit
; loop counter, 0..378, generated programmatically rather than as 379
; literal fixture lines) to reach exactly 512, then attempt one further
; insert using a name still outside that generated range (counter 379,
; which the fill loop never used) and confirm it is rejected.
; ---------------------------------------------------------------------------
symfull1:
    lda #$53                 ; 'S'
    sta FullNameBuf
    lda #$46                 ; 'F'
    sta FullNameBuf + 1

    lda #0
    sta FullCounterLo
    sta FullCounterHi
fl1FillLoop:
    lda FullCounterLo
    sta FullNameBuf + 2
    lda FullCounterHi
    sta FullNameBuf + 3
    lda #<FullNameBuf
    sta CasmPtr0Lo
    lda #>FullNameBuf
    sta CasmPtr0Hi
    lda #4
    ldx FullCounterLo
    ldy FullCounterHi
    jsr symbolsInsert
    bcc :+
    jmp fl1Fail
:
    inc FullCounterLo
    bne :+
    inc FullCounterHi
:
    lda FullCounterLo
    cmp #<379
    bne fl1FillLoop
    lda FullCounterHi
    cmp #>379
    bne fl1FillLoop

    ; FullCounterLo/Hi now hold 379 (the fill loop's exclusive upper bound),
    ; a name the loop above never generated -- reuse it directly for the
    ; overflow attempt below.
    lda FullCounterLo
    sta FullNameBuf + 2
    lda FullCounterHi
    sta FullNameBuf + 3
    lda #<FullNameBuf
    sta CasmPtr0Lo
    lda #>FullNameBuf
    sta CasmPtr0Hi
    lda #4
    ldx #$AA
    ldy #$BB
    jsr symbolsInsert
    bcs :+
    jmp fl1Fail
:
    cmp #CASM_DIAG_SYMBOL_TABLE_FULL
    beq :+
    jmp fl1Fail
:
    clc
    rts
fl1Fail:
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
    .byte "CASM SYMBOLS: PASS", PetCr, 0
failMsg:
    .byte "CASM SYMBOLS: FAIL", PetCr, 0

; Link-check table only: forces ld65 to resolve symbolsInit/symbolsInsert/
; symbolsLookup by exact name against symbols.s as soon as that module
; lands, without any fixture here having to call them (correctly or
; otherwise) yet. Never read or executed at runtime.
symbolsLinkTable:
    .word symbolsInit
    .word symbolsInsert
    .word symbolsLookup

; Fixture name literals. Every name below is deliberately distinct from
; every other name used anywhere in this file's sequential run: symchain1's
; generated "CH"+counter names and symfull1's generated "SF"+counter names
; are distinct from these (and from each other) purely by their fixed
; 2-byte prefix, regardless of counter overlap.
nameInitCheck:
    .byte "INITCHECK"
nameLoop:
    .byte "LOOP"
nameNever:
    .byte "NEVERDEFINED"
nameCaseLower:
    .byte "Case"
nameCaseUpper:
    .byte "CASE"
nameLen31:
    .byte "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"    ; exactly 31 bytes

.segment "BSS"

FailCount:  .res 1

; Shared symbolsLookup output view (CASM_RESOLVE_* layout), reused across
; fixtures the same way SavedSlot/PrevSegHi are reused in test_casm_vmm.s.
ResolveView: .res CASM_RESOLVE_SIZE

; symcase1 scratch: the first insert's record index, checked against the
; second insert's to confirm they differ.
CaseIdxLoFirst: .res 1
CaseIdxHiFirst: .res 1

; symchain1 scratch: loop counter (0..128, doubles as name suffix and
; stored value) and the 3-byte generated name buffer ("CH" + counter).
ChainCounter:   .res 1
ChainNameBuf:   .res 3

; symfull1 scratch: 16-bit loop counter (0..379) and the 4-byte generated
; name buffer ("SF" + counter Lo/Hi).
FullCounterLo:  .res 1
FullCounterHi:  .res 1
FullNameBuf:    .res 4
