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
.import resourcesCleanup
.import symbolsInit
.import symbolsInsert
.import CasmSymbolInsertFlags
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

    ; WP60 Increment 7: these four each call symbolsInit themselves for a
    ; fresh, isolated table (symfull1 above leaves the shared table at
    ; exactly CASM_SYMBOL_MAX/full), matching casm_pass1.s's own per-fixture
    ; isolation precedent rather than this file's usual sequential-shared-
    ; table convention -- nothing after symfull1 depends on its full state,
    ; so this is safe. Each fresh symbolsInit allocates its own VMM slot;
    ; the shared resourcesCleanup below frees all of them (at most 5
    ; concurrent slots: the original plus these four), well under
    ; CASM_VMM_CAPACITY (8).
    jsr symlenmin1
    jsr reportCase
    jsr symvalzero1
    jsr reportCase
    jsr symvalmax1
    jsr reportCase
    jsr sym511boundary1
    jsr reportCase

    ; WP41 fix (same defect class found in casm_reloc.s): syminit1's
    ; symbolsInit allocates the symbol table's VMM storage and this harness
    ; never freed it before DOS_EXIT, leaking it permanently at the OS/REU
    ; level (DOS_ALLOC_MEM's tracked capacity, not just this program's own
    ; 8-slot registry, which a fresh DOS_EXIT does not implicitly release).
    ; resourcesCleanup frees every registered VMM slot generically.
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
    lda #CASM_SYMBOL_FLAG_DEFINED
    sta CasmSymbolInsertFlags
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
    lda #CASM_SYMBOL_FLAG_DEFINED
    sta CasmSymbolInsertFlags
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
    lda #CASM_SYMBOL_FLAG_DEFINED
    sta CasmSymbolInsertFlags
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
    lda #CASM_SYMBOL_FLAG_DEFINED
    sta CasmSymbolInsertFlags
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
    lda #CASM_SYMBOL_FLAG_DEFINED
    sta CasmSymbolInsertFlags
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
    lda #CASM_SYMBOL_FLAG_DEFINED
    sta CasmSymbolInsertFlags
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
    lda #CASM_SYMBOL_FLAG_DEFINED
    sta CasmSymbolInsertFlags
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
    lda #CASM_SYMBOL_FLAG_DEFINED
    sta CasmSymbolInsertFlags
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
; symlenmin1
; WP60 Increment 7: name length 1 (the minimum symbolsInsert accepts,
; mirroring symlen1's own maximum-length case at 31). Fresh table; insert,
; look up, and assert round-trip with no truncation.
; ---------------------------------------------------------------------------
symlenmin1:
    jsr symbolsInit
    bcc :+
    jmp lm1Fail
:
    lda #<nameLen1
    sta CasmPtr0Lo
    lda #>nameLen1
    sta CasmPtr0Hi
    lda #CASM_SYMBOL_FLAG_DEFINED
    sta CasmSymbolInsertFlags
    lda #1
    ldx #$34
    ldy #$12
    jsr symbolsInsert
    bcc :+
    jmp lm1Fail
:
    lda #<nameLen1
    sta CasmPtr0Lo
    lda #>nameLen1
    sta CasmPtr0Hi
    lda #1
    ldx #<ResolveView
    ldy #>ResolveView
    jsr symbolsLookup
    bcc :+
    jmp lm1Fail
:
    lda ResolveView + CASM_RESOLVE_FLAGS
    and #CASM_EXPR_FLAG_RESOLVED
    bne :+
    jmp lm1Fail
:
    lda ResolveView + CASM_RESOLVE_VAL_LO
    cmp #$34
    beq :+
    jmp lm1Fail
:
    lda ResolveView + CASM_RESOLVE_VAL_HI
    cmp #$12
    beq :+
    jmp lm1Fail
:
    clc
    rts
lm1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; symvalzero1
; WP60 Increment 7: a symbol's value is exactly $0000. Fresh table; proves
; $0000 is stored/round-tripped as a real resolved value, not confused with
; an unresolved/sentinel-zero state (CASM_RESOLVE_FLAGS' RESOLVED bit is
; checked explicitly, independent of the value bytes themselves).
; ---------------------------------------------------------------------------
symvalzero1:
    jsr symbolsInit
    bcc :+
    jmp vz1Fail
:
    lda #<nameValZero
    sta CasmPtr0Lo
    lda #>nameValZero
    sta CasmPtr0Hi
    lda #CASM_SYMBOL_FLAG_DEFINED
    sta CasmSymbolInsertFlags
    lda #6
    ldx #$00
    ldy #$00
    jsr symbolsInsert
    bcc :+
    jmp vz1Fail
:
    lda #<nameValZero
    sta CasmPtr0Lo
    lda #>nameValZero
    sta CasmPtr0Hi
    lda #6
    ldx #<ResolveView
    ldy #>ResolveView
    jsr symbolsLookup
    bcc :+
    jmp vz1Fail
:
    lda ResolveView + CASM_RESOLVE_FLAGS
    and #CASM_EXPR_FLAG_RESOLVED
    bne :+
    jmp vz1Fail
:
    lda ResolveView + CASM_RESOLVE_VAL_LO
    bne vz1Fail
    lda ResolveView + CASM_RESOLVE_VAL_HI
    bne vz1Fail
    clc
    rts
vz1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; symvalmax1
; WP60 Increment 7: a symbol's value is exactly $FFFF. Fresh table.
; ---------------------------------------------------------------------------
symvalmax1:
    jsr symbolsInit
    bcc :+
    jmp vm1Fail
:
    lda #<nameValMax
    sta CasmPtr0Lo
    lda #>nameValMax
    sta CasmPtr0Hi
    lda #CASM_SYMBOL_FLAG_DEFINED
    sta CasmSymbolInsertFlags
    lda #5
    ldx #$FF
    ldy #$FF
    jsr symbolsInsert
    bcc :+
    jmp vm1Fail
:
    lda #<nameValMax
    sta CasmPtr0Lo
    lda #>nameValMax
    sta CasmPtr0Hi
    lda #5
    ldx #<ResolveView
    ldy #>ResolveView
    jsr symbolsLookup
    bcc :+
    jmp vm1Fail
:
    lda ResolveView + CASM_RESOLVE_FLAGS
    and #CASM_EXPR_FLAG_RESOLVED
    bne :+
    jmp vm1Fail
:
    lda ResolveView + CASM_RESOLVE_VAL_LO
    cmp #$FF
    beq :+
    jmp vm1Fail
:
    lda ResolveView + CASM_RESOLVE_VAL_HI
    cmp #$FF
    beq :+
    jmp vm1Fail
:
    clc
    rts
vm1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; sym511boundary1
; WP60 Increment 7: 511 symbols (capacity-edge minus one), isolated as its
; own checkpoint -- symfull1 above reaches exactly 512 (and rejects the
; 513th) but never checks the 511-symbol point specifically. Fresh table;
; insert exactly 511 distinct generated names ("GL"+16-bit counter, 0..510)
; and assert the 511th insert's own returned record index is exactly 510
; (0-based: symbolsInsert returns the count *before* increment, so the
; 511th successful insert is the direct, positive proof that exactly 511
; real inserts succeeded, not an incidental byproduct of counting loop
; iterations) -- then look that symbol back up to confirm it round-trips.
; ---------------------------------------------------------------------------
sym511boundary1:
    jsr symbolsInit
    bcc :+
    jmp s511Fail
:
    lda #$47                 ; 'G'
    sta Sym511NameBuf
    lda #$4C                 ; 'L'
    sta Sym511NameBuf + 1

    lda #0
    sta Sym511CounterLo
    sta Sym511CounterHi
s511FillLoop:
    lda Sym511CounterLo
    sta Sym511NameBuf + 2
    lda Sym511CounterHi
    sta Sym511NameBuf + 3
    lda #<Sym511NameBuf
    sta CasmPtr0Lo
    lda #>Sym511NameBuf
    sta CasmPtr0Hi
    lda #CASM_SYMBOL_FLAG_DEFINED
    sta CasmSymbolInsertFlags
    lda #4
    ldx Sym511CounterLo
    ldy Sym511CounterHi
    jsr symbolsInsert
    bcc s511InsertOk
    jmp s511Fail
s511InsertOk:
    inc Sym511CounterLo
    bne :+
    inc Sym511CounterHi
:
    lda Sym511CounterLo
    cmp #<511
    bne s511FillLoop
    lda Sym511CounterHi
    cmp #>511
    bne s511FillLoop

    ; The 511th insert (0-based counter value 510) just returned; X/Y still
    ; hold its own return value (record index) from the loop's last
    ; symbolsInsert call above -- check it directly before it's clobbered.
    cpx #<510
    bne s511Fail
    cpy #>510
    bne s511Fail

    ; Look the last-inserted name (counter 510) back up to confirm it
    ; round-trips.
    lda #<Sym511NameBuf
    sta CasmPtr0Lo
    lda #>Sym511NameBuf
    sta CasmPtr0Hi
    lda #4
    ldx #<ResolveView
    ldy #>ResolveView
    jsr symbolsLookup
    bcc :+
    jmp s511Fail
:
    lda ResolveView + CASM_RESOLVE_FLAGS
    and #CASM_EXPR_FLAG_RESOLVED
    bne :+
    jmp s511Fail
:
    lda ResolveView + CASM_RESOLVE_VAL_LO
    cmp #<510
    beq :+
    jmp s511Fail
:
    lda ResolveView + CASM_RESOLVE_VAL_HI
    cmp #>510
    beq :+
    jmp s511Fail
:
    clc
    rts
s511Fail:
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

; WP60 Increment 7
nameLen1:
    .byte "Z"                ; exactly 1 byte
nameValZero:
    .byte "VZERO0"
nameValMax:
    .byte "VMAX1"

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

; sym511boundary1 scratch: 16-bit loop counter (0..510) and the 4-byte
; generated name buffer ("GL" + counter Lo/Hi).
Sym511CounterLo: .res 1
Sym511CounterHi: .res 1
Sym511NameBuf:   .res 4
