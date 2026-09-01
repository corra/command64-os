; tests/src/casm_scope/casm_scope.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; CASM Phase 14 WP88 standalone symbol-layer scope harness. Exercises
; symbols.s's WP88 scope-filtered matching (symbolsInsert/symbolsFindChain/
; symbolsLookup) directly, the same way test_casm_symbols.s (WP27/WP60)
; exercises the unscoped Phase 6B behavior directly -- there is no
; parser/pass-driver call site for CASM_SYMBOL_FLAG_LOCAL yet (WP89 is what
; wires it into real assembly), so this cannot be a real .s source fixture
; either. One shared table, sequential fixtures, matching casm_symbols.s's
; own convention exactly (including its inverted-short-branch-over-JMP
; pattern for every Fail check, and its diagPrintFatal stub for the same
; whole-object-file link reason).
;
; "Scope" here is always a record index (symbolsInsert's own return value
; for the global label that opened it), not a name -- these fixtures use
; MainScopeLo/Hi and DrawScopeLo/Hi captured directly from the two global
; inserts below, never a hardcoded index, so the fixture stays correct
; regardless of where in record-index space the harness happens to run.

.include "command64.inc"
.include "../../../src/external/casm/common.inc"

.define VERSION_MAJOR "0"
.define VERSION_MINOR "1"
.define VERSION_STAGE "0"
.include "build_test_casm_scope.inc"

.import __MAIN_START__
.import resourcesInit
.import resourcesCleanup
.import symbolsInit
.import symbolsInsert
.import symbolsLookup
.import CasmSymbolInsertFlags
.import CasmSymbolInsertScopeLo
.import CasmSymbolInsertScopeHi
.import CasmSymbolLookupScopeLo
.import CasmSymbolLookupScopeHi
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

    jsr scpInit1
    jsr reportCase
    jsr scpGlobalMain1
    jsr reportCase
    jsr scpGlobalDraw1
    jsr reportCase
    jsr scpLocalUnderMain1
    jsr reportCase
    jsr scpLocalUnderDraw1
    jsr reportCase
    jsr scpDuplicateSameScope1
    jsr reportCase
    jsr scpLookupMainScope1
    jsr reportCase
    jsr scpLookupDrawScope1
    jsr reportCase
    jsr scpLookupWrongScope1
    jsr reportCase
    jsr scpGlobalLookupScopeIndependent1
    jsr reportCase
    jsr scpLocalNeverMatchesGlobal1
    jsr reportCase
    jsr scpRawRecordFields1
    jsr reportCase

    ; Frees the one VMM slot scpInit1's symbolsInit allocated, same
    ; obligation casm_symbols.s's own WP41 fix documents.
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
; scpInit1
; Fresh table. A local-shaped lookup ("@NEVER", any scope) before anything
; has been inserted must report "not found" (C clear, RESOLVED clear),
; exactly like an unscoped lookup would -- proves the scope-filter wiring
; introduces no new failure mode on an empty table.
; ---------------------------------------------------------------------------
scpInit1:
    jsr symbolsInit
    bcc :+
    jmp in1Fail
:
    lda #<nameAtNever
    sta CasmPtr0Lo
    lda #>nameAtNever
    sta CasmPtr0Hi
    lda #0
    sta CasmSymbolLookupScopeLo
    sta CasmSymbolLookupScopeHi
    lda #6                   ; "@NEVER" length
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
; scpGlobalMain1
; Insert the first global label, "MAIN" -- LOCAL clear, ordinary Phase 6B
; insert. Its own returned record index becomes MainScopeLo/Hi, the scope
; every "under MAIN" fixture below uses -- never a hardcoded index.
; ---------------------------------------------------------------------------
scpGlobalMain1:
    lda #<nameMain
    sta CasmPtr0Lo
    lda #>nameMain
    sta CasmPtr0Hi
    lda #CASM_SYMBOL_FLAG_DEFINED
    sta CasmSymbolInsertFlags
    lda #4
    ldx #$00
    ldy #$10                 ; MAIN's own value, $1000 -- distinct from any local's
    jsr symbolsInsert
    bcc :+
    jmp gm1Fail
:
    stx MainScopeLo
    sty MainScopeHi
    clc
    rts
gm1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; scpGlobalDraw1
; Second global label, "DRAW". Its record index becomes DrawScopeLo/Hi.
; ---------------------------------------------------------------------------
scpGlobalDraw1:
    lda #<nameDraw
    sta CasmPtr0Lo
    lda #>nameDraw
    sta CasmPtr0Hi
    lda #CASM_SYMBOL_FLAG_DEFINED
    sta CasmSymbolInsertFlags
    lda #4
    ldx #$00
    ldy #$20                 ; DRAW's own value, $2000
    jsr symbolsInsert
    bcc :+
    jmp gd1Fail
:
    stx DrawScopeLo
    sty DrawScopeHi
    clc
    rts
gd1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; scpLocalUnderMain1
; Insert local "@LOOP" scoped to MAIN. Record index captured as
; LoopUnderMainIdxLo/Hi for later fixtures.
; ---------------------------------------------------------------------------
scpLocalUnderMain1:
    lda #<nameAtLoop
    sta CasmPtr0Lo
    lda #>nameAtLoop
    sta CasmPtr0Hi
    lda #(CASM_SYMBOL_FLAG_DEFINED | CASM_SYMBOL_FLAG_LOCAL)
    sta CasmSymbolInsertFlags
    lda MainScopeLo
    sta CasmSymbolInsertScopeLo
    lda MainScopeHi
    sta CasmSymbolInsertScopeHi
    lda #5                   ; "@LOOP" length
    ldx #$11
    ldy #$11                 ; the MAIN-scoped @LOOP's own value, $1111
    jsr symbolsInsert
    bcc :+
    jmp lum1Fail
:
    stx LoopUnderMainIdxLo
    sty LoopUnderMainIdxHi
    clc
    rts
lum1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; scpLocalUnderDraw1
; Insert local "@LOOP" -- the SAME name text -- scoped to DRAW instead of
; MAIN. Must succeed (NOT CASM_DIAG_DUPLICATE_SYMBOL) and land at a
; DIFFERENT record index than scpLocalUnderMain1's own: this is the core
; WP88 proof that two different scopes are two different symbol spaces.
; ---------------------------------------------------------------------------
scpLocalUnderDraw1:
    lda #<nameAtLoop
    sta CasmPtr0Lo
    lda #>nameAtLoop
    sta CasmPtr0Hi
    lda #(CASM_SYMBOL_FLAG_DEFINED | CASM_SYMBOL_FLAG_LOCAL)
    sta CasmSymbolInsertFlags
    lda DrawScopeLo
    sta CasmSymbolInsertScopeLo
    lda DrawScopeHi
    sta CasmSymbolInsertScopeHi
    lda #5                   ; "@LOOP" length
    ldx #$22
    ldy #$22                 ; the DRAW-scoped @LOOP's own value, $2222
    jsr symbolsInsert
    bcc :+
    jmp lud1Fail
:
    stx LoopUnderDrawIdxLo
    sty LoopUnderDrawIdxHi
    cpx LoopUnderMainIdxLo
    bne :+
    cpy LoopUnderMainIdxHi
    bne :+
    jmp lud1Fail             ; same record index as the MAIN-scoped one: bug
:
    clc
    rts
lud1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; scpDuplicateSameScope1
; Insert "@LOOP" scoped to MAIN a second time. Must be rejected with
; CASM_DIAG_DUPLICATE_SYMBOL -- proves the scope filter does not weaken
; same-scope duplicate detection (only cross-scope reuse is exempt).
; ---------------------------------------------------------------------------
scpDuplicateSameScope1:
    lda #<nameAtLoop
    sta CasmPtr0Lo
    lda #>nameAtLoop
    sta CasmPtr0Hi
    lda #(CASM_SYMBOL_FLAG_DEFINED | CASM_SYMBOL_FLAG_LOCAL)
    sta CasmSymbolInsertFlags
    lda MainScopeLo
    sta CasmSymbolInsertScopeLo
    lda MainScopeHi
    sta CasmSymbolInsertScopeHi
    lda #5
    ldx #$99
    ldy #$99
    jsr symbolsInsert
    bcs :+
    jmp dss1Fail
:
    cmp #CASM_DIAG_DUPLICATE_SYMBOL
    beq :+
    jmp dss1Fail
:
    clc
    rts
dss1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; scpLookupMainScope1
; Look up "@LOOP" with the lookup scope set to MAIN. Must resolve to the
; MAIN-scoped record's own value ($1111) and record index
; (LoopUnderMainIdxLo/Hi), not the DRAW-scoped one.
; ---------------------------------------------------------------------------
scpLookupMainScope1:
    lda #<nameAtLoop
    sta CasmPtr0Lo
    lda #>nameAtLoop
    sta CasmPtr0Hi
    lda MainScopeLo
    sta CasmSymbolLookupScopeLo
    lda MainScopeHi
    sta CasmSymbolLookupScopeHi
    lda #5
    ldx #<ResolveView
    ldy #>ResolveView
    jsr symbolsLookup
    bcc :+
    jmp lms1Fail
:
    lda ResolveView + CASM_RESOLVE_FLAGS
    and #CASM_EXPR_FLAG_RESOLVED
    bne :+
    jmp lms1Fail
:
    lda ResolveView + CASM_RESOLVE_VAL_LO
    cmp #$11
    beq :+
    jmp lms1Fail
:
    lda ResolveView + CASM_RESOLVE_VAL_HI
    cmp #$11
    beq :+
    jmp lms1Fail
:
    lda ResolveView + CASM_RESOLVE_ID_LO
    cmp LoopUnderMainIdxLo
    beq :+
    jmp lms1Fail
:
    lda ResolveView + CASM_RESOLVE_ID_HI
    cmp LoopUnderMainIdxHi
    beq :+
    jmp lms1Fail
:
    clc
    rts
lms1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; scpLookupDrawScope1
; Mirror of scpLookupMainScope1 for DRAW's own "@LOOP" ($2222).
; ---------------------------------------------------------------------------
scpLookupDrawScope1:
    lda #<nameAtLoop
    sta CasmPtr0Lo
    lda #>nameAtLoop
    sta CasmPtr0Hi
    lda DrawScopeLo
    sta CasmSymbolLookupScopeLo
    lda DrawScopeHi
    sta CasmSymbolLookupScopeHi
    lda #5
    ldx #<ResolveView
    ldy #>ResolveView
    jsr symbolsLookup
    bcc :+
    jmp lds1Fail
:
    lda ResolveView + CASM_RESOLVE_FLAGS
    and #CASM_EXPR_FLAG_RESOLVED
    bne :+
    jmp lds1Fail
:
    lda ResolveView + CASM_RESOLVE_VAL_LO
    cmp #$22
    beq :+
    jmp lds1Fail
:
    lda ResolveView + CASM_RESOLVE_VAL_HI
    cmp #$22
    beq :+
    jmp lds1Fail
:
    lda ResolveView + CASM_RESOLVE_ID_LO
    cmp LoopUnderDrawIdxLo
    beq :+
    jmp lds1Fail
:
    lda ResolveView + CASM_RESOLVE_ID_HI
    cmp LoopUnderDrawIdxHi
    beq :+
    jmp lds1Fail
:
    clc
    rts
lds1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; scpLookupWrongScope1
; Look up "@LOOP" with a scope that owns no "@LOOP" at all (a bogus index
; guaranteed never to be MAIN's or DRAW's own -- one past DRAW's, which by
; record-index ordering cannot equal anything inserted before it since
; indices are assigned strictly increasing from a bump allocator). Must
; report "not found" even though "@LOOP" genuinely exists under two OTHER
; scopes -- the wrong-scope-misses proof the plan calls for explicitly.
; ---------------------------------------------------------------------------
scpLookupWrongScope1:
    lda #<nameAtLoop
    sta CasmPtr0Lo
    lda #>nameAtLoop
    sta CasmPtr0Hi
    lda DrawScopeLo
    clc
    adc #10
    sta CasmSymbolLookupScopeLo
    lda DrawScopeHi
    adc #0
    sta CasmSymbolLookupScopeHi
    lda #5
    ldx #<ResolveView
    ldy #>ResolveView
    jsr symbolsLookup
    bcc :+
    jmp lws1Fail
:
    lda ResolveView + CASM_RESOLVE_FLAGS
    and #CASM_EXPR_FLAG_RESOLVED
    beq :+
    jmp lws1Fail
:
    clc
    rts
lws1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; scpGlobalLookupScopeIndependent1
; Look up the GLOBAL "MAIN" with the lookup scope deliberately set to a
; value that matches neither MAIN's own index nor anything meaningful
; (DRAW's index + 10, same bogus value scpLookupWrongScope1 used). A global
; record is never scope-checked (symbolsFindChain's own sfcMatch: the LOCAL
; flag test short-circuits before the scope compare), so this must still
; resolve correctly to MAIN's own value/id regardless of the filter.
; ---------------------------------------------------------------------------
scpGlobalLookupScopeIndependent1:
    lda #<nameMain
    sta CasmPtr0Lo
    lda #>nameMain
    sta CasmPtr0Hi
    lda DrawScopeLo
    clc
    adc #10
    sta CasmSymbolLookupScopeLo
    lda DrawScopeHi
    adc #0
    sta CasmSymbolLookupScopeHi
    lda #4
    ldx #<ResolveView
    ldy #>ResolveView
    jsr symbolsLookup
    bcc :+
    jmp gli1Fail
:
    lda ResolveView + CASM_RESOLVE_FLAGS
    and #CASM_EXPR_FLAG_RESOLVED
    bne :+
    jmp gli1Fail
:
    lda ResolveView + CASM_RESOLVE_VAL_LO
    cmp #$00
    beq :+
    jmp gli1Fail
:
    lda ResolveView + CASM_RESOLVE_VAL_HI
    cmp #$10
    beq :+
    jmp gli1Fail
:
    lda ResolveView + CASM_RESOLVE_ID_LO
    cmp MainScopeLo
    beq :+
    jmp gli1Fail
:
    lda ResolveView + CASM_RESOLVE_ID_HI
    cmp MainScopeHi
    beq :+
    jmp gli1Fail
:
    clc
    rts
gli1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; scpLocalNeverMatchesGlobal1
; Insert a local literally named "@MAIN" (same letters as the global
; "MAIN", '@'-prefixed) scoped to MAIN, then confirm looking up the GLOBAL
; "MAIN" still returns the global record's own id/value -- the name text
; itself ("MAIN" vs "@MAIN") already keeps them apart, and this proves it
; end to end rather than by construction alone.
; ---------------------------------------------------------------------------
scpLocalNeverMatchesGlobal1:
    lda #<nameAtMain
    sta CasmPtr0Lo
    lda #>nameAtMain
    sta CasmPtr0Hi
    lda #(CASM_SYMBOL_FLAG_DEFINED | CASM_SYMBOL_FLAG_LOCAL)
    sta CasmSymbolInsertFlags
    lda MainScopeLo
    sta CasmSymbolInsertScopeLo
    lda MainScopeHi
    sta CasmSymbolInsertScopeHi
    lda #5                   ; "@MAIN" length
    ldx #$33
    ldy #$33
    jsr symbolsInsert
    bcc :+
    jmp lnmg1Fail
:
    lda #<nameMain
    sta CasmPtr0Lo
    lda #>nameMain
    sta CasmPtr0Hi
    lda #0
    sta CasmSymbolLookupScopeLo
    sta CasmSymbolLookupScopeHi
    lda #4
    ldx #<ResolveView
    ldy #>ResolveView
    jsr symbolsLookup
    bcc :+
    jmp lnmg1Fail
:
    lda ResolveView + CASM_RESOLVE_ID_LO
    cmp MainScopeLo
    beq :+
    jmp lnmg1Fail
:
    lda ResolveView + CASM_RESOLVE_ID_HI
    cmp MainScopeHi
    beq :+
    jmp lnmg1Fail
:
    lda ResolveView + CASM_RESOLVE_VAL_LO
    cmp #$00
    beq :+
    jmp lnmg1Fail
:
    lda ResolveView + CASM_RESOLVE_VAL_HI
    cmp #$10
    beq :+
    jmp lnmg1Fail
:
    clc
    rts
lnmg1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; scpRawRecordFields1
; Direct VMM read of the MAIN-scoped "@LOOP" record (LoopUnderMainIdxLo/Hi),
; addressed through symbols.s's exported CasmSymbolVmmSlot -- confirms
; CASM_SYMBOL_FLAG_LOCAL is actually set in the on-disk FLAGS byte and
; CASM_SYMBOL_REC_SCOPE_LO/HI actually holds MainScopeLo/Hi, rather than
; only inferring correctness indirectly through symbolsLookup's own view.
; ---------------------------------------------------------------------------
scpRawRecordFields1:
    lda LoopUnderMainIdxLo
    sta CasmVmmOffLo
    lda LoopUnderMainIdxHi
    sta CasmVmmOffHi
    ; VMM offset = index * CASM_SYMBOL_REC_SIZE (64): matches symbols.s's
    ; own unrolled shift-by-6 exactly.
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
    bcc :+
    jmp rrf1Fail
:
    lda CasmVmmBuffer + CASM_SYMBOL_REC_FLAGS
    and #CASM_SYMBOL_FLAG_LOCAL
    bne :+
    jmp rrf1Fail
:
    lda CasmVmmBuffer + CASM_SYMBOL_REC_SCOPE_LO
    cmp MainScopeLo
    beq :+
    jmp rrf1Fail
:
    lda CasmVmmBuffer + CASM_SYMBOL_REC_SCOPE_HI
    cmp MainScopeHi
    beq :+
    jmp rrf1Fail
:
    clc
    rts
rrf1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; diagPrintFatal (stub)
; resources.s's exitSuccess/exitFatal reference this; this harness never
; calls either, so a trivial stub satisfies the link without pulling in the
; real diagnostics.s (and transitively lexer.s/source.s). Matches
; casm_symbols.s's own precedent exactly.
; ---------------------------------------------------------------------------
diagPrintFatal:
    rts

.segment "RODATA"

passMsg:
    .byte "CASM SCOPE: PASS", PetCr, 0
failMsg:
    .byte "CASM SCOPE: FAIL", PetCr, 0

; Link-check table only: forces ld65 to resolve these by exact name against
; symbols.s as soon as that module lands, without any fixture here having
; to call them (correctly or otherwise) yet. Never read or executed at
; runtime. Matches casm_symbols.s's own symbolsLinkTable precedent.
symbolsLinkTable:
    .word symbolsInit
    .word symbolsInsert
    .word symbolsLookup

nameMain:
    .byte "MAIN"
nameDraw:
    .byte "DRAW"
nameAtLoop:
    .byte "@LOOP"
nameAtMain:
    .byte "@MAIN"
nameAtNever:
    .byte "@NEVER"

.segment "BSS"

FailCount:  .res 1

; Shared symbolsLookup output view (CASM_RESOLVE_* layout), matching
; casm_symbols.s's own ResolveView precedent.
ResolveView: .res CASM_RESOLVE_SIZE

; The two global labels' own record indices, captured from their own
; symbolsInsert return values -- never hardcoded, per this file's header.
MainScopeLo: .res 1
MainScopeHi: .res 1
DrawScopeLo: .res 1
DrawScopeHi: .res 1

; The two "@LOOP" locals' own record indices, one per scope.
LoopUnderMainIdxLo: .res 1
LoopUnderMainIdxHi: .res 1
LoopUnderDrawIdxLo: .res 1
LoopUnderDrawIdxHi: .res 1
