; tests/src/casm_cliderive/casm_cliderive.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; Standalone CASM Phase 10 WP53 increment 1 fixture harness. Exercises
; cli.s's real cliDeriveListingName directly, following the WP52 casm_map.s
; precedent of driving a module's real routine against real state rather
; than a stand-in. cliDeriveOutputName is exercised too, since
; cliDeriveListingName always derives from its output (CasmOutputName is
; never poked directly except to stand in for an already-completed `/O`
; parse, matching cliDeriveOutputName's own cdonDerive-vs-explicit split).
;
; No fixture in this repo pokes CommandBuffer/ParsePos to drive cliParse
; directly (confirmed by search before writing this harness) -- production
; CLI parsing is only exercised by typing at the real shell. This harness
; keeps that precedent: it populates CasmSourceNames[0]/CasmSourceLens[0]/
; CasmSourceCount (cliCopySource's own targets) or CasmOutputName/
; CasmOutputLen/CasmCliOptions directly (cliParseOption's own targets after
; a successful `/O:` parse), then calls the real derivation routines.
.include "command64.inc"
.include "../../../src/external/casm/common.inc"

.define VERSION_MAJOR "0"
.define VERSION_MINOR "1"
.define VERSION_STAGE "0"
.include "build_test_casm_cliderive.inc"

.import __MAIN_START__
.import cliInit
.import cliDeriveOutputName
.import cliDeriveListingName
.import CasmSourceNames
.import CasmSourceLens
.import CasmSourceCount
.import CasmOutputName
.import CasmOutputLen
.import CasmListingName
.import CasmListingLen
.import CasmCliOptions

.segment "HEADER"
    .word __MAIN_START__

.segment "CODE"

start:
    cld
    lda #$0E
    jsr KernalChROUT
    lda #0
    sta FailCount

    jsr cderreplace1
    jsr reportCase
    jsr cdernocolon1
    jsr reportCase
    jsr cderexplicit1
    jsr reportCase
    jsr cdercollide1
    jsr reportCase
    jsr cdermalformed1
    jsr reportCase
    jsr cderoverflow1
    jsr reportCase
    jsr cderboundary1
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
; FailCount.
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
; cderCheckListing
; Compares CasmListingName (null-terminated) against the literal string
; whose pointer is in CasmPtr1Lo/Hi, and CasmListingLen against A on entry.
; Outputs: C clear if both match; C set otherwise
; Clobbers: A, X, Y
; ---------------------------------------------------------------------------
cderCheckListing:
    cmp CasmListingLen
    bne cclNotEqual
    ldy #0
cclLoop:
    lda CasmListingName, y
    cmp (CasmPtr1Lo), y
    bne cclNotEqual
    lda CasmListingName, y
    beq cclEqual
    iny
    jmp cclLoop
cclNotEqual:
    sec
    rts
cclEqual:
    clc
    rts

; ---------------------------------------------------------------------------
; cderreplace1
; Source "8:FOO.S" derives output "8:FOO.PRG"; the listing name must replace
; the suffix after the last device-prefix colon: "8:FOO.LST".
; ---------------------------------------------------------------------------
cderreplace1:
    jsr cliInit
    ldx #0
cr1CopyLoop:
    lda cr1Source, x
    sta CasmSourceNames, x
    beq cr1Copied
    inx
    jmp cr1CopyLoop
cr1Copied:
    stx CasmSourceLens + 0
    lda #1
    sta CasmSourceCount
    jsr cliDeriveOutputName
    bcc :+
    jmp cr1Fail
:
    jsr cliDeriveListingName
    bcc :+
    jmp cr1Fail
:
    lda #<cr1Expect
    sta CasmPtr1Lo
    lda #>cr1Expect
    sta CasmPtr1Hi
    lda #9
    jmp cderCheckListing
cr1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; cdernocolon1
; Source "BAR.S" (no device prefix) derives output "BAR.PRG"; the dot scan
; must still find the extension without any colon ever resetting it.
; ---------------------------------------------------------------------------
cdernocolon1:
    jsr cliInit
    ldx #0
cn1CopyLoop:
    lda cn1Source, x
    sta CasmSourceNames, x
    beq cn1Copied
    inx
    jmp cn1CopyLoop
cn1Copied:
    stx CasmSourceLens + 0
    lda #1
    sta CasmSourceCount
    jsr cliDeriveOutputName
    bcc :+
    jmp cn1Fail
:
    jsr cliDeriveListingName
    bcc :+
    jmp cn1Fail
:
    lda #<cn1Expect
    sta CasmPtr1Lo
    lda #>cn1Expect
    sta CasmPtr1Hi
    lda #7
    jmp cderCheckListing
cn1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; cderexplicit1
; An explicit `/O:8:PROGRAM` output (no dot at all) must append ".LST"
; rather than truncate at a nonexistent extension.
; ---------------------------------------------------------------------------
cderexplicit1:
    jsr cliInit
    lda #CASM_OPT_OUTPUT
    sta CasmCliOptions
    ldx #0
ce1CopyLoop:
    lda ce1Output, x
    sta CasmOutputName, x
    beq ce1Copied
    inx
    jmp ce1CopyLoop
ce1Copied:
    stx CasmOutputLen
    jsr cliDeriveOutputName
    bcc :+
    jmp ce1Fail
:
    jsr cliDeriveListingName
    bcc :+
    jmp ce1Fail
:
    lda #<ce1Expect
    sta CasmPtr1Lo
    lda #>ce1Expect
    sta CasmPtr1Hi
    lda #13
    jmp cderCheckListing
ce1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; cdercollide1
; An explicit `/O:8:PROG.LST` output is byte-identical to its own derived
; listing name -- must raise CASM_DIAG_LISTING_NAME_COLLISION before any
; listing resource is touched.
; ---------------------------------------------------------------------------
cdercollide1:
    jsr cliInit
    lda #CASM_OPT_OUTPUT
    sta CasmCliOptions
    ldx #0
cc1CopyLoop:
    lda cc1Output, x
    sta CasmOutputName, x
    beq cc1Copied
    inx
    jmp cc1CopyLoop
cc1Copied:
    stx CasmOutputLen
    jsr cliDeriveOutputName
    bcc :+
    jmp cc1Fail
:
    jsr cliDeriveListingName
    bcs :+
    jmp cc1Fail                  ; must fail -- success is the bug here
:
    cmp #CASM_DIAG_LISTING_NAME_COLLISION
    beq cc1Pass
cc1Fail:
    sec
    rts
cc1Pass:
    clc
    rts

; ---------------------------------------------------------------------------
; cdermalformed1
; cliDeriveListingName called before any output has ever been derived
; (CasmOutputLen still zero after cliInit) must raise
; CASM_DIAG_MALFORMED_OUTPUT_OPTION, matching cliDeriveOutputName's own
; malformed-state diagnostic.
; ---------------------------------------------------------------------------
cdermalformed1:
    jsr cliInit
    jsr cliDeriveListingName
    bcs :+
    jmp cm1Fail
:
    cmp #CASM_DIAG_MALFORMED_OUTPUT_OPTION
    beq cm1Pass
cm1Fail:
    sec
    rts
cm1Pass:
    clc
    rts

; ---------------------------------------------------------------------------
; cderoverflow1
; An explicit 60-byte dotless/colonless output name is one byte past the
; largest name cliDeriveListingName can extend with ".LST" and fit in the
; 64-byte buffer -- must raise CASM_DIAG_FILENAME_TOO_LONG.
; ---------------------------------------------------------------------------
cderoverflow1:
    jsr cliInit
    lda #CASM_OPT_OUTPUT
    sta CasmCliOptions
    ldx #0
co1Fill:
    lda #$41                     ; PETSCII 'A'
    sta CasmOutputName, x
    inx
    cpx #60
    bne co1Fill
    lda #0
    sta CasmOutputName, x
    lda #60
    sta CasmOutputLen
    jsr cliDeriveOutputName
    bcc :+
    jmp co1Fail
:
    jsr cliDeriveListingName
    bcs :+
    jmp co1Fail                  ; must fail -- success is the bug here
:
    cmp #CASM_DIAG_FILENAME_TOO_LONG
    beq co1Pass
co1Fail:
    sec
    rts
co1Pass:
    clc
    rts

; ---------------------------------------------------------------------------
; cderboundary1
; The complementary boundary: a 59-byte dotless/colonless output name must
; succeed, producing a 63-byte (CASM_FILENAME_MAX) listing name that fits
; exactly.
; ---------------------------------------------------------------------------
cderboundary1:
    jsr cliInit
    lda #CASM_OPT_OUTPUT
    sta CasmCliOptions
    ldx #0
cb1Fill:
    lda #$41                     ; PETSCII 'A'
    sta CasmOutputName, x
    inx
    cpx #59
    bne cb1Fill
    lda #0
    sta CasmOutputName, x
    lda #59
    sta CasmOutputLen
    jsr cliDeriveOutputName
    bcc :+
    jmp cb1Fail
:
    jsr cliDeriveListingName
    bcc :+
    jmp cb1Fail
:
    cmp #CASM_PARSE_OK
    bne cb1Fail
    lda CasmListingLen
    cmp #CASM_FILENAME_MAX
    beq cb1Pass
cb1Fail:
    sec
    rts
cb1Pass:
    clc
    rts

.segment "RODATA"

; Lowercase source letters, not uppercase: ca65's -t c64 charmap maps
; lowercase source letters to unshifted PETSCII ($41-$5A) and uppercase
; source letters to shifted PETSCII (+$80) -- see reference-casm-petscii-
; identifier-case. cliDeriveOutputName/cliDeriveListingName copy source
; bytes verbatim and append CASM_PETSCII_P/R/G/L/S/T, which are unshifted
; numeric constants, so these fixtures must assemble to unshifted bytes to
; match.
cr1Source: .byte "8:foo.s", 0
cr1Expect: .byte "8:foo.lst", 0
cn1Source: .byte "bar.s", 0
cn1Expect: .byte "bar.lst", 0
ce1Output: .byte "8:program", 0
ce1Expect: .byte "8:program.lst", 0
cc1Output: .byte "8:prog.lst", 0

passMsg: .byte "CASM CLIDERIVE: PASS", $0D, 0
failMsg: .byte "CASM CLIDERIVE: FAIL", $0D, 0

.segment "BSS"

FailCount: .res 1
