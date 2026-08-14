# cmake/GenerateCasmTestFixtures.cmake
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Command64 project contributors

if(NOT DEFINED OUTPUT_DIR)
    message(FATAL_ERROR "OUTPUT_DIR is required")
endif()

file(MAKE_DIRECTORY "${OUTPUT_DIR}")

file(WRITE "${OUTPUT_DIR}/casmshort.seq"
    ".ORG \$2000\n"
    "    LDA #10\n"
    "    STA \$0400,X\n"
    "    LDA %10101010\n"
    "    ; COMMENT\n"
    "    JMP START_LABEL\n"
)

# WP60 Increment 7: Source domain boundary fixture. casmsrc1 is the
# minimum non-empty source, one byte with no terminator at all before EOF.
# A true zero-byte companion (casmsrc0) was attempted and dropped: cc1541
# refuses to write an empty SEQ entry at all ("Unexpected filesize when
# reading casmsrc0.seq"), so the empty-source-file boundary row remains
# unproven through this fixture pipeline -- deferred, not silently assumed
# equivalent to the one-byte case.
file(WRITE "${OUTPUT_DIR}/casmsrc1.seq" "Z")

string(REPEAT "A" 256 CASM_EXACT_BLOCK)
file(WRITE "${OUTPUT_DIR}/casm256.seq" "${CASM_EXACT_BLOCK}")

string(REPEAT "B" 513 CASM_MULTI_BLOCK)
file(WRITE "${OUTPUT_DIR}/casmmulti.seq" "${CASM_MULTI_BLOCK}")

# WP33 VMM-backed refill chunk-boundary fixtures. sourceRefill now transfers
# each up-to-256-byte OS block from the loaded VMM allocation through up to
# four 64-byte vmmWindowRead chunks -- an internal boundary casm256 (exactly
# 256 bytes, always four full chunks) does not exercise, since it never
# produces a partial final chunk. Neither fixture contains valid CASM syntax
# (like casm256/casmmulti, they exist to exercise traversal, not assembly);
# equivalence is proved by the same diagnostic/line/column those two already
# establish, not a trusted-reference PRG.
#
# 65 bytes: one full 64-byte chunk plus a 1-byte final partial chunk.
string(REPEAT "A" 65 CASM_VMM_CHUNK_65)
file(WRITE "${OUTPUT_DIR}/casmvmm65.seq" "${CASM_VMM_CHUNK_65}")

# 128 bytes: exactly two full 64-byte chunks and no partial remainder at
# all -- proves the chunk loop terminates cleanly on an exact multiple
# smaller than casm256's 256-byte (four-chunk) case.
string(REPEAT "A" 128 CASM_VMM_CHUNK_128)
file(WRITE "${OUTPUT_DIR}/casmvmm128.seq" "${CASM_VMM_CHUNK_128}")

# WP5 newline-normalization fixtures. Explicit CR ($0D) and LF ($0A) bytes are
# built with string(ASCII ...) so no host newline translation can distort them.
# Coordinate values are not runtime-observable until WP10's token dump; these
# exercise the CR/CRLF/pending-CR paths and the consumed-vs-fetched EOF count
# invariant at runtime now.
string(ASCII 13 CASM_CR)
string(ASCII 10 CASM_LF)
set(CASM_CRLF "${CASM_CR}${CASM_LF}")

# CR-only line endings (classic-Mac style).
file(WRITE "${OUTPUT_DIR}/casmcr.seq" "LINE1${CASM_CR}LINE2${CASM_CR}")

# CRLF line endings (DOS style).
file(WRITE "${OUTPUT_DIR}/casmcrlf.seq" "LINE1${CASM_CRLF}LINE2${CASM_CRLF}")

# CRLF straddling the 256-byte block boundary: 255 filler bytes place the CR at
# byte index 255 (last byte of block 1) and the LF at byte index 256 (first byte
# of block 2), proving the pending-CR latch survives a refill.
string(REPEAT "A" 255 CASM_SPLIT_HEAD)
file(WRITE "${OUTPUT_DIR}/casmsplit.seq" "${CASM_SPLIT_HEAD}${CASM_CRLF}END")

# Consecutive LF newlines produce consecutive empty lines.
file(WRITE "${OUTPUT_DIR}/casmblank.seq" "A${CASM_LF}${CASM_LF}${CASM_LF}B${CASM_LF}")

# File ending in a lone CR: the final CR resolves as a newline before EOF.
file(WRITE "${OUTPUT_DIR}/casmfincr.seq" "LINE${CASM_CR}")

# WP6 line-boundary fixtures. The line API bounds a logical line to 255 payload
# bytes; byte mode rejects the same overlong line via the checked 8-bit column.
# These exercise the boundary on the shipped byte path.
#
# No embedded-null fixture exists: CMake cannot emit a $00 byte in a string, and
# it would prove nothing anyway. Null rejection ($19) is line-mode only, and the
# shipped path never calls sourceNextLine, so a null fixture would only confirm
# byte mode passes nulls through. $19 is verified statically.

# Exactly 255 payload bytes plus a newline: the maximum accepted logical line,
# and the case that must survive a LINE-mode refill across the block boundary.
string(REPEAT "L " 127 CASM_LINE_255_BASE)
set(CASM_LINE_255 "${CASM_LINE_255_BASE}L")
file(WRITE "${OUTPUT_DIR}/casmln255.seq" "${CASM_LINE_255}${CASM_LF}SECOND${CASM_LF}")

# 256 payload bytes before a newline: rejected with location-overflow ($16) in
# byte mode, and line-too-long ($17) once a line-API caller exists.
string(REPEAT "L " 128 CASM_LINE_256)
file(WRITE "${OUTPUT_DIR}/casmln256.seq" "${CASM_LINE_256}${CASM_LF}")

# WP11 statement-parser fixtures. These exercise the restricted LL(1) grammar
# through the temporary parse driver in casm.s. The valid fixture parses to EOF
# and prints "CASM: INPUT VALIDATED"; each error fixture stops at its first
# malformed statement and prints one specific WP11 diagnostic, so every error
# case needs its own file (the parser exits fatally on the first failure).
#
# Grammar-only: WP11 validates statement structure, not opcode/operand-size
# legality (that is WP12). So structurally valid but semantically odd lines are
# accepted here by design.

# One statement per addressing-mode opkind, all valid: implied, immediate
# (decimal/hex/binary), absolute/ZP, absolute-X, absolute-Y, accumulator,
# indirect-indexed (Y), indexed-indirect (X), and indirect.
file(WRITE "${OUTPUT_DIR}/casmwp11.seq"
    "INX\n"
    "LDA #10\n"
    "LDA #\$FF\n"
    "LDX #%10101010\n"
    "LDA \$10\n"
    "STA \$0400,X\n"
    "STA \$0500,Y\n"
    "ASL A\n"
    "LDA (\$10),Y\n"
    "LDA (\$10,X)\n"
    "JMP (\$1234)\n"
)

# Immediate with no number after '#'          -> CASM_DIAG_SYNTAX_ERROR ($1C)
file(WRITE "${OUTPUT_DIR}/casmerr1.seq" "LDA #\n")
# Indexed with no register after the comma    -> CASM_DIAG_SYNTAX_ERROR ($1C)
file(WRITE "${OUTPUT_DIR}/casmerr2.seq" "STA \$0400,\n")
# Indexed-indirect requires X, not Y          -> CASM_DIAG_SYNTAX_ERROR ($1C)
file(WRITE "${OUTPUT_DIR}/casmerr3.seq" "LDA (\$10,Y)\n")
# Trailing token after a complete operand     -> CASM_DIAG_EXPECTED_NEWLINE ($1D)
file(WRITE "${OUTPUT_DIR}/casmerr4.seq" "LDA #10 20\n")
# Immediate value exceeds 65535           -> CASM_DIAG_OPERAND_OUT_OF_RANGE ($1E)
file(WRITE "${OUTPUT_DIR}/casmerr5.seq" "LDA #70000\n")

# WP12 addressing-mode matcher fixtures. Each parses cleanly (valid WP11
# grammar) but fails opcode resolution in the matcher, so it exercises a WP12
# diagnostic through the temporary driver.
#
# Accumulator mode on an instruction that has none -> INVALID ADDRESSING MODE ($1F)
file(WRITE "${OUTPUT_DIR}/casmam1.seq" "LDA A\n")
# Immediate mode on an implied-only instruction  -> INVALID ADDRESSING MODE ($1F)
file(WRITE "${OUTPUT_DIR}/casmam2.seq" "INX #5\n")
# Immediate operand exceeds 8 bits            -> OPERAND OUT OF RANGE ($1E)
file(WRITE "${OUTPUT_DIR}/casmrng1.seq" "LDA #\$1234\n")

# WP13 emission fixtures.
#
# Valid program exercising implied/immediate/absolute/relative modes and the
# .BYTE/.WORD directives. Assembles to a 20-byte PRG loading at $C000:
#   00 C0                      ; PRG header (load address $C000)
#   A9 01                      ; LDA #$01
#   8D 20 D0                   ; STA $D020
#   A2 10                      ; LDX #$10
#   E8                         ; INX
#   D0 FD                      ; BNE $C007   (displacement -3)
#   60                         ; RTS
#   01 02 FF                   ; .BYTE $01,$02,$FF
#   34 12 CD AB                ; .WORD $1234,$ABCD
file(WRITE "${OUTPUT_DIR}/casmemit1.seq"
    ".ORG \$C000\n"
    "LDA #\$01\n"
    "STA \$D020\n"
    "LDX #\$10\n"
    "INX\n"
    "BNE \$C007\n"
    "RTS\n"
    ".BYTE \$01, \$02, \$FF\n"
    ".WORD \$1234, \$ABCD\n"
)
# Code before any .ORG                        -> ORG REQUIRED ($21)
file(WRITE "${OUTPUT_DIR}/casmorg1.seq" "LDA #\$01\n")
# A second .ORG                               -> DUPLICATE ORG ($20)
file(WRITE "${OUTPUT_DIR}/casmorg2.seq" ".ORG \$C000\n.ORG \$C100\n")
# Branch target far outside -128..+127        -> BRANCH OUT OF RANGE ($23)
file(WRITE "${OUTPUT_DIR}/casmbr1.seq" ".ORG \$C000\nBNE \$D000\n")

# WP15 diagnostic source-context fixtures. Each triggers one source-position
# diagnostic and is checked for its rendered line, caret column, and byte
# offset -- not merely for the diagnostic identifier.

# Invalid byte mid-line, with text after it. '@' is neither punctuation, an
# identifier start, nor a number prefix, so the lexer rejects it. The trailing
# text is the point: it proves the forward drain recovers the part of the line
# the echo buffer had not yet seen when the error fired.
#   -> INVALID SOURCE BYTE ($19) at line 2, col 9, offset 8
file(WRITE "${OUTPUT_DIR}/casmbadb.seq"
    ".ORG \$C000\n"
    "LDA #\$0A@,X  ; TRAILING TEXT\n"
)

# Invalid byte at column 1: the caret must sit at the first rendered column
# with no left clip marker.
#   -> INVALID SOURCE BYTE ($19) at line 2, col 1, offset 0
file(WRITE "${OUTPUT_DIR}/casmcol1.seq"
    ".ORG \$C000\n"
    "@LDA #\$01\n"
)

# A raw $93 (PETSCII clear-screen) embedded in the source. Printing this byte
# unsanitized would erase the diagnostic being displayed, so this fixture
# verifies the substitution rather than any parsing behaviour.
#   -> INVALID SOURCE BYTE ($19), rendered as '.', reported as BYTE $93
string(ASCII 147 CASM_CLR)
file(WRITE "${OUTPUT_DIR}/casmctrl.seq"
    ".ORG \$C000\n"
    "LDA #\$01${CASM_CLR}\n"
)

# Error far along a line, forcing the display window to slide. A long .BYTE
# list is used because the filler must be valid source: a comment would be
# skipped by the lexer and never reach the offending byte.
# ".BYTE" spans columns 1-5, then 18 repeats of " $01," span columns 6-95,
# placing the '@' at column 96.
#   -> INVALID SOURCE BYTE ($19) at line 2, col 96, offset 95
string(REPEAT " \$01," 18 CASM_LONG_HEAD)
file(WRITE "${OUTPUT_DIR}/casmlong.seq"
    ".ORG \$C000\n"
    ".BYTE${CASM_LONG_HEAD}@ TRAILING\n"
)

# Error EARLY in a long line, so the window starts at the line start and stops
# short of the end: the only fixture that produces a right clip marker.
#
# NOTE: this cannot pass until the WP15 forward drain lands. Before the drain,
# the echo buffer ends at the offending byte, so the buffered line is 7 bytes
# and there is nothing to the right to clip. Right clipping is structurally
# unreachable without the drain, which is exactly why it needs its own fixture
# rather than being folded into casmlong.
#
# ".BYTE " spans columns 1-6, placing '@' at column 7. The trailing values make
# the drained line 97 bytes, well past the 38-column window.
#   -> INVALID SOURCE BYTE ($19) at line 2, col 7, offset 6, right clip set
string(REPEAT " \$01," 18 CASM_CLIP_TAIL)
file(WRITE "${OUTPUT_DIR}/casmclip.seq"
    ".ORG \$C000\n"
    ".BYTE @${CASM_CLIP_TAIL}\n"
)

# The same offending byte in a CRLF file. Newline normalization collapses CRLF
# to one newline and must not shift the reported column: a one-column caret
# drift on DOS-style sources is precisely the failure this feature would be
# embarrassed by, and no other fixture pairs an error with CRLF endings.
#   -> INVALID SOURCE BYTE ($19) at line 2, col 9, offset 8 (identical
#      geometry to casmbadb, which uses LF)
file(WRITE "${OUTPUT_DIR}/casmcrer.seq"
    ".ORG \$C000${CASM_CRLF}"
    "LDA #\$01@${CASM_CRLF}"
)

# End-to-end demo: a runnable program that prints a message and returns to the
# shell. It assembles to a plain PRG loading at $3400 (the current
# UserProgStart), so no labels are used -- the message address ($340E) and the
# OS_API entry ($1000) are literal. It calls DOS_PRINT_STR (A=$09, X/Y = string
# pointer) then DOS_EXIT (A=$4C). Assemble with `casm casmhello`, then on the
# C64: `LOAD CASMHELLO` and `GO 3400`. The message renders in the default
# uppercase charset: "YES IT BUILDS! -- CASM".
#
# Layout (load $3400):
#   3400 A2 0E        LDX #<msg
#   3402 A0 34        LDY #>msg
#   3404 A9 09        LDA #DOS_PRINT_STR
#   3406 20 00 10     JSR $1000            ; OS_API
#   3409 A9 4C        LDA #DOS_EXIT
#   340B 20 00 10     JSR $1000
#   340E ...          ; msg: "YES IT BUILDS! -- CASM", CR, NUL
file(WRITE "${OUTPUT_DIR}/casmhello.seq"
    ".ORG \$3400\n"
    "LDX #\$0E\n"
    "LDY #\$34\n"
    "LDA #\$09\n"
    "JSR \$1000\n"
    "LDA #\$4C\n"
    "JSR \$1000\n"
    ".BYTE \$59, \$45, \$53, \$20, \$49, \$54, \$20\n"
    ".BYTE \$42, \$55, \$49, \$4C, \$44, \$53, \$21, \$20\n"
    ".BYTE \$2D, \$2D, \$20, \$43, \$41, \$53, \$4D\n"
    ".BYTE \$0D, \$00\n"
)

# ---------------------------------------------------------------------------
# WP14 acceptance-matrix fixtures.
#
# Each expectation below was derived statically from parser.s/emit.s, not from
# running CASM; the WP14 runtime matrix confirms them. Unlike the WP11 error
# fixtures, most of these begin with a valid .ORG so the failure happens AFTER
# the output PRG has been created -- that is what exercises the outputAbort
# partial-output delete path.
#
# Note on .BYTE/.WORD: the parser defers their operand lists to the emission
# engine (emitByteList/emitWordList), so their delimiter diagnostics are raised
# in emit.s, not parser.s.

# -- Syntax and delimiter boundaries ----------------------------------------

# Empty .BYTE list: emitByteList reads a NEWLINE where a NUMBER must appear.
#   -> SYNTAX ERROR ($1C)
file(WRITE "${OUTPUT_DIR}/casmbyte0.seq" ".ORG \$C000\n.BYTE\n")
# Empty .WORD list, same path in emitWordList.       -> SYNTAX ERROR ($1C)
file(WRITE "${OUTPUT_DIR}/casmword0.seq" ".ORG \$C000\n.WORD\n")
# Leading comma: the first list token is a COMMA.    -> SYNTAX ERROR ($1C)
file(WRITE "${OUTPUT_DIR}/casmcma1.seq" ".ORG \$C000\n.BYTE ,\$01\n")
# Doubled comma. $01 is emitted BEFORE the failure, so this is also a
# partial-output case.                               -> SYNTAX ERROR ($1C)
file(WRITE "${OUTPUT_DIR}/casmcma2.seq" ".ORG \$C000\n.BYTE \$01,,\$02\n")
# Trailing comma: the comma is consumed, then a NEWLINE arrives where a NUMBER
# must be. $01 is emitted first.                     -> SYNTAX ERROR ($1C)
file(WRITE "${OUTPUT_DIR}/casmcma3.seq" ".ORG \$C000\n.BYTE \$01,\n")
# .BYTE element wider than 8 bits (VAL_HI nonzero).
#   -> OPERAND OUT OF RANGE ($1E)
file(WRITE "${OUTPUT_DIR}/casmbyrng.seq" ".ORG \$C000\n.BYTE \$100\n")

# .ORG with no operand. This exposed a WP14 defect: the bare directive parses as
# OPKIND_IMPLIED with value 0, and emitOrg did not inspect OpKind, so CASM
# silently assembled it as ".ORG $0000". Fixed in WP14 by requiring
# OPKIND_ABSOLUTE in emitOrg.                        -> SYNTAX ERROR ($1C)
file(WRITE "${OUTPUT_DIR}/casmorg3.seq" ".ORG\n")
# .ORG with a non-numeric operand. Parses as OPKIND_ACCUMULATOR, which the same
# emitOrg guard rejects; without the guard it would have silently set origin
# $0000 just like the bare form.                     -> SYNTAX ERROR ($1C)
file(WRITE "${OUTPUT_DIR}/casmorg5.seq" ".ORG A\n")
# Trailing token after a complete .ORG operand.  -> EXPECTED NEWLINE ($1D)
file(WRITE "${OUTPUT_DIR}/casmorg4.seq" ".ORG \$C000 \$D000\n")

# Blank lines and comments surrounding valid statements, including a leading
# comment before .ORG and a trailing comment at EOF.  -> assembles cleanly
file(WRITE "${OUTPUT_DIR}/casmcmnt.seq"
    "; leading comment before any code\n"
    "\n"
    ".ORG \$C000\n"
    "\n"
    "    ; indented comment-only line\n"
    "LDA #\$01\n"
    "\n"
    "INX          ; trailing comment after a statement\n"
    "; final comment at end of file\n"
)

# -- Addressing and numeric boundaries --------------------------------------

# Immediate at the 8-bit maximum.                     -> assembles cleanly
file(WRITE "${OUTPUT_DIR}/casmimm1.seq" ".ORG \$C000\nLDA #\$FF\n")
# Immediate one past the 8-bit maximum.
#   -> OPERAND OUT OF RANGE ($1E)
file(WRITE "${OUTPUT_DIR}/casmimm2.seq" ".ORG \$C000\nLDA #\$100\n")
# Zero-page / absolute promotion boundary: $FF must select a zero-page opcode
# (2 bytes) and $0100 an absolute one (3 bytes).      -> assembles cleanly
file(WRITE "${OUTPUT_DIR}/casmzp1.seq" ".ORG \$C000\nLDA \$FF\nLDA \$0100\n")
# Zero-page indirect forms at the $FF boundary.       -> assembles cleanly
file(WRITE "${OUTPUT_DIR}/casmzpi1.seq"
    ".ORG \$C000\n"
    "LDA (\$FF,X)\n"
    "LDA (\$FF),Y\n"
)
# Zero-page indirect one past the boundary: $100 cannot be a zero-page operand.
#   -> expected a range or addressing-mode diagnostic; confirm which at runtime
file(WRITE "${OUTPUT_DIR}/casmzpi2.seq" ".ORG \$C000\nLDA (\$100,X)\n")

# Branch displacement boundaries. The branch sits at $C000 and is 2 bytes, so
# nextPc = $C002 and displacement = target - $C002.
# +127: target $C002 + 127 = $C081.                   -> assembles cleanly
file(WRITE "${OUTPUT_DIR}/casmbrp1.seq" ".ORG \$C000\nBNE \$C081\n")
# +128: target $C082.                          -> BRANCH OUT OF RANGE ($23)
file(WRITE "${OUTPUT_DIR}/casmbrp2.seq" ".ORG \$C000\nBNE \$C082\n")
# -128: target $C002 - 128 = $BF82.                   -> assembles cleanly
file(WRITE "${OUTPUT_DIR}/casmbrn1.seq" ".ORG \$C000\nBNE \$BF82\n")
# -129: target $BF81.                          -> BRANCH OUT OF RANGE ($23)
file(WRITE "${OUTPUT_DIR}/casmbrn2.seq" ".ORG \$C000\nBNE \$BF81\n")

# Program counter ending exactly at $FFFF: the byte AT $FFFF is emitted, the PC
# then wraps and latches CasmPcOverflow, but nothing further is emitted.
#   -> assembles cleanly
file(WRITE "${OUTPUT_DIR}/casmpcend.seq" ".ORG \$FFFF\n.BYTE \$01\n")
# Advancing past $FFFF: the second byte hits the latched overflow.
#   -> ADDRESS OVERFLOW ($22)
file(WRITE "${OUTPUT_DIR}/casmpcovf.seq" ".ORG \$FFFF\n.BYTE \$01, \$02\n")

# Representative legal statement for every CASM_MODE_* value, in mode order, so
# a byte-for-byte comparison against casmmodes.ref certifies one opcode per
# addressing mode. This closes the gap left by casmemit1/casmhello, which
# between them only cover implied, immediate, absolute, relative, .BYTE/.WORD.
#
# ZEROPAGE_Y uses LDX because that mode exists only for LDX/STX. The zero-page
# vs absolute choice is driven by operand width ($10 vs $1234), which also
# re-exercises the promotion logic.
#
# DO NOT RUN the assembled output: it ends in a JMP through an uninitialised
# vector and a backward BNE. It exists only to be assembled and compared.
#
# Layout (load $C000), hand-assembled independently of CASM:
#   C000 E8        INX            ; IMPLIED
#   C001 0A        ASL A          ; ACCUMULATOR
#   C002 A9 01     LDA #$01       ; IMMEDIATE
#   C004 A5 10     LDA $10        ; ZEROPAGE
#   C006 B5 10     LDA $10,X      ; ZEROPAGE_X
#   C008 B6 10     LDX $10,Y      ; ZEROPAGE_Y
#   C00A AD 34 12  LDA $1234      ; ABSOLUTE
#   C00D BD 34 12  LDA $1234,X    ; ABSOLUTE_X
#   C010 B9 34 12  LDA $1234,Y    ; ABSOLUTE_Y
#   C013 6C 34 12  JMP ($1234)    ; INDIRECT
#   C016 A1 10     LDA ($10,X)    ; INDEXED_INDIRECT
#   C018 B1 10     LDA ($10),Y    ; INDIRECT_INDEXED
#   C01A D0 E4     BNE $C000      ; RELATIVE (nextPc $C01C, disp -28)
file(WRITE "${OUTPUT_DIR}/casmmodes.seq"
    ".ORG \$C000\n"
    "INX\n"
    "ASL A\n"
    "LDA #\$01\n"
    "LDA \$10\n"
    "LDA \$10,X\n"
    "LDX \$10,Y\n"
    "LDA \$1234\n"
    "LDA \$1234,X\n"
    "LDA \$1234,Y\n"
    "JMP (\$1234)\n"
    "LDA (\$10,X)\n"
    "LDA (\$10),Y\n"
    "BNE \$C000\n"
)

# -- Output and cleanup ------------------------------------------------------

# Several statements assemble and are written to the output PRG, and only then
# does a syntax error fire. The partial PRG must NOT survive: startFatal ->
# outputAbort deletes it. Verify with DIR that no output file remains.
#   -> SYNTAX ERROR ($1C), and no output file left on disk
file(WRITE "${OUTPUT_DIR}/casmpart.seq"
    ".ORG \$C000\n"
    "LDA #\$01\n"
    "STA \$D020\n"
    "INX\n"
    ".BYTE \$AA, \$BB, \$CC\n"
    "LDA #\n"
)

# -- Phase 5 WP18 numeric conversion fixtures -------------------------------
file(WRITE "${OUTPUT_DIR}/casmnum2.seq"
    ".ORG \$C000\n"
    ".WORD 25, 26, 255, 256, 6553, 6554, 65535\n"
    ".WORD \$00FF, \$FFFF, %11111111, %1111111111111111\n"
)
file(WRITE "${OUTPUT_DIR}/casmnumerrd.seq" ".ORG \$C000\n.WORD 65536\n")
file(WRITE "${OUTPUT_DIR}/casmnumerrh.seq" ".ORG \$C000\n.WORD \$10000\n")
file(WRITE "${OUTPUT_DIR}/casmnumerrb.seq" ".ORG \$C000\n.WORD %11111111111111111\n")

# Phase 5 WP20 production adapter fixtures. casmexprn exercises every parser and
# directive delimiter context with numeric extraction; casmexpru proves an
# identifier is routed to the production resolver and rejected before emission.
file(WRITE "${OUTPUT_DIR}/casmexprn.seq"
    ".ORG \$C000\n"
    "LDA #<\$1234\n"
    "LDA >\$1234\n"
    "LDA (<\$1234),Y\n"
    ".BYTE <\$1234, >\$1234\n"
    ".WORD <\$1234, >\$1234\n"
)
file(WRITE "${OUTPUT_DIR}/casmexpru.seq" ".ORG \$C000\nLDA ABSVAL\n")

# WP28 Pass 1 measure-engine fixtures. Each is opened directly via
# CasmSourceName by the standalone test_casm_pass1 harness, not through
# casm.s's own CLI — these are not meant to be assembled by the production
# casm.s entry point, only driven by casm_pass1.s's own Pass-1-only loop.

# Bare label definition; LOOP must resolve to $C000 with no bytes emitted.
file(WRITE "${OUTPUT_DIR}/p1label1.seq"
    ".ORG \$C000\n"
    "LOOP:\n"
)

# Label followed by an instruction on the same physical line (the label
# statement itself is colon-terminated and self-contained; the following
# instruction is a separate statement parsed by the next
# parserParseStatement call). LOOP resolves to $C000; final CasmPc = $C001
# (one byte for NOP).
file(WRITE "${OUTPUT_DIR}/p1labelinsn1.seq"
    ".ORG \$C000\n"
    "LOOP: NOP\n"
)

# Forward reference: LOOP is referenced before its own definition. When "LDA
# LOOP" is processed, LOOP is not yet in the symbol table, so it must be
# sized as absolute (3 bytes) regardless of its eventual value. Final CasmPc
# = $0014 (3 bytes LDA absolute + 1 byte NOP after LOOP resolves to $0013).
file(WRITE "${OUTPUT_DIR}/p1fwd1.seq"
    ".ORG \$0010\n"
    "LDA LOOP\n"
    "LOOP: NOP\n"
)

# Backward reference with a deliberately tiny .ORG so LOOP's resolved address
# ($0010) has a zero high byte -- the exact case that would incorrectly
# shrink to zero-page addressing if CASM_PARSER_STMT_FORCE_ABS were derived
# from CASM_EXPR_FLAG_FORCE_ABS (only set when unresolved) instead of
# CASM_EXPR_FLAG_SYMBOL_DERIVED (set whenever a symbol resolves at all). By
# the time "LDA LOOP" runs, LOOP is already resolved (defined one line
# earlier, value $0010) -- it must still size as absolute (3 bytes), not
# zero-page (2 bytes). Final CasmPc = $0014 (1 byte NOP + 3 bytes LDA
# absolute, starting from $0010).
file(WRITE "${OUTPUT_DIR}/p1back1.seq"
    ".ORG \$0010\n"
    "LOOP: NOP\n"
    "LDA LOOP\n"
)

# CASM Phase 11 WP61 Increment 4: FORCE_ABS end-to-end two-pass closure, the
# opposite direction from p1back1 above. p1back1's LOOP is already defined
# (backward reference) by the time "LDA LOOP" is measured, in one single
# measure-pass unit case. This fixture instead forward-references TARGET --
# undefined at the point "LDA TARGET" is first measured -- so Pass 1 must
# size it as 3-byte absolute purely from CASM_EXPR_FLAG_SYMBOL_DERIVED
# (parser.s:562-570), before TARGET's value is known at all, and Pass 2
# must independently re-derive the same FORCE_ABS classification and commit
# the same 3-byte absolute opcode to the real output file, even though
# TARGET's resolved value ($0013) would fit zero-page if it were a literal.
# Verified end-to-end via native COMP against casmfa2p.ref.hex, not a
# hand-built single-pass unit case.
file(WRITE "${OUTPUT_DIR}/casmfa2p.seq"
    ".ORG \$0010\n"
    "LDA TARGET\n"
    "TARGET: NOP\n"
)

# Genuinely undefined symbol (GHOST is never defined anywhere in this file).
# In CASM_PASS_MODE_MEASURE this must be tolerated, not a fixture failure:
# LDA GHOST sizes as absolute (3 bytes, FORCE_ABS forces it regardless of the
# zero placeholder value), and no diagnostic is raised. Final CasmPc =
# $0013.
file(WRITE "${OUTPUT_DIR}/p1undef1.seq"
    ".ORG \$0010\n"
    "LDA GHOST\n"
)

# Duplicate label definition. The harness's own p1dup1 driver (not the
# shared runMeasurePass helper) expects the second "LOOP:" statement's
# symbolsInsert call to return CASM_DIAG_DUPLICATE_SYMBOL and treats that as
# the fixture's success condition.
file(WRITE "${OUTPUT_DIR}/p1dup1.seq"
    ".ORG \$0010\n"
    "LOOP: NOP\n"
    "LOOP: NOP\n"
)

# Comprehensive Pass 1 sanity check: forward reference, backward-referenced
# labels, and .byte/.word directives together. Hand-verified final CasmPc =
# $C010; LOOP resolves to $C003, DATA to $C009, VALS to $C00C.
file(WRITE "${OUTPUT_DIR}/p1size1.seq"
    ".ORG \$C000\n"
    "JMP LOOP\n"
    "LOOP: LDA #\$01\n"
    "STA \$D020\n"
    "RTS\n"
    "DATA: .BYTE \$01, \$02, \$03\n"
    "VALS: .WORD \$ABCD, \$1234\n"
)

# WP30 relative-branch fixtures. No prior fixture (Phase 4's casmbrp1/brp2/
# brn1/brn2 included) has ever used a label as a branch target -- all four
# use raw literal addresses. brfwd1/brback1 prove real Pass 2 emission of a
# branch resolved from a real forward/backward label (trusted references in
# tests/fixtures/casm/); brrng1 proves CASM_DIAG_BRANCH_OUT_OF_RANGE still
# fires when the operand is a resolved label rather than a literal delta.

# Forward branch to a label. BNE is 2 bytes at $C000-$C001 (nextPc=$C002);
# two NOPs occupy $C002-$C003; LOOP resolves to $C004. Displacement = +2.
file(WRITE "${OUTPUT_DIR}/brfwd1.seq"
    ".ORG \$C000\n"
    "BNE LOOP\n"
    "NOP\n"
    "NOP\n"
    "LOOP: RTS\n"
)

# Backward branch to a label. LOOP is defined at $C000 (two NOPs occupy
# $C000-$C001); BNE is 2 bytes at $C002-$C003 (nextPc=$C004). Displacement =
# $C000 - $C004 = -4.
file(WRITE "${OUTPUT_DIR}/brback1.seq"
    ".ORG \$C000\n"
    "LOOP: NOP\n"
    "NOP\n"
    "BNE LOOP\n"
)

# Out-of-range branch to a label, reusing Phase 4's casmbrp2 boundary exactly
# ($C082, displacement +128, one past the +127 maximum) rather than deriving
# a new one: BNE is 2 bytes at $C000-$C001 (nextPc=$C002); 128 one-byte NOPs
# place LOOP at exactly $C002 + 128 = $C082.
#   -> BRANCH OUT OF RANGE ($23), same diagnostic casmbrp2 already proves for
#      a literal target
string(REPEAT "NOP\n" 128 CASM_BRRNG1_FILLER)
file(WRITE "${OUTPUT_DIR}/brrng1.seq"
    ".ORG \$C000\n"
    "BNE LOOP\n"
    "${CASM_BRRNG1_FILLER}"
    "LOOP: RTS\n"
)

# WP31 case-sensitivity fixture. CASM's lexer (isIdFirst/isIdCont) accepts
# only unshifted PETSCII A-Z ($41-$5A) or shifted PETSCII A-Z ($C1-$DA) as
# identifier bytes -- plain ASCII lowercase ($61-$7A) is rejected outright as
# CASM_DIAG_INVALID_SOURCE_BYTE. Unlike a ca65-assembled .s harness (whose
# quoted string literals go through ca65's -t c64 charmap automatically,
# confirmed empirically: uppercase source letters shift to $C1-$DA, lowercase
# source letters map to unshifted $41-$5A), this is a raw .seq text file
# read byte-for-byte by CASM's own lexer with no charmap conversion at all --
# a naive mixed-case ASCII fixture would fail immediately on the first
# lowercase byte, testing nothing. The second label below is therefore built
# directly from shifted-PETSCII byte values (unshifted L/O/O/P = $4C/$4F/
# $4F/$50; +$80 = $CC/$CF/$CF/$D0), giving two genuinely different,
# lexer-valid byte sequences for "the same" name.
string(ASCII 204 CASM_SHIFT_L)
string(ASCII 207 CASM_SHIFT_O)
string(ASCII 208 CASM_SHIFT_P)
set(CASM_SHIFTED_LOOP "${CASM_SHIFT_L}${CASM_SHIFT_O}${CASM_SHIFT_O}${CASM_SHIFT_P}")
# LOOP (unshifted) defines at $C000 (NOP, 1 byte); the shifted-byte-sequence
# label defines at $C001 (RTS, 1 byte). LDA LOOP resolves to $C000; LDA
# <shifted> resolves to $C001 -- both FORCE_ABS'd to 3-byte absolute. If case
# sensitivity were ever broken, this would surface as CASM_DIAG_DUPLICATE_SYMBOL
# at the second label statement, or as both LDAs resolving to the same address.
file(WRITE "${OUTPUT_DIR}/casmcase1.seq"
    ".ORG \$C000\n"
    "LOOP: NOP\n"
    "${CASM_SHIFTED_LOOP}: RTS\n"
    "LDA LOOP\n"
    "LDA ${CASM_SHIFTED_LOOP}\n"
)

# WP31 maximum-length identifier fixture (31 bytes, CASM_TOKEN_TEXT_MAX).
# The label defines at $C000 (RTS, 1 byte); LDA resolves it (FORCE_ABS'd to
# 3-byte absolute).
string(REPEAT "A" 31 CASM_MAXID_NAME)
file(WRITE "${OUTPUT_DIR}/casmmaxid1.seq"
    ".ORG \$C000\n"
    "${CASM_MAXID_NAME}: RTS\n"
    "LDA ${CASM_MAXID_NAME}\n"
)

# ---------------------------------------------------------------------------
# WP34 multi-file top-level input fixtures. Each pair/triple is opened
# together through real casm.s's CLI (e.g. "CASM CASMMFA.S CASMMFB.S
# /O:CASMMF1.PRG"), not the standalone test_casm_pass1 harness -- proving
# the multi-file CLI grammar itself, not just sourceLoad's internal loop.
# ---------------------------------------------------------------------------

# casmmf1: two files, file A already ends in a real newline (no synthetic
# newline needed). VALB is defined in file B and referenced (forward, across
# the file boundary) in file A -- proves cross-file symbol resolution.
# Expected (hand-derived, see casmmf1.ref.hex): LDA VALB forces absolute (3
# bytes, forward reference); VALB resolves to $C000+3=$C003.
file(WRITE "${OUTPUT_DIR}/casmmfa.seq"
    ".ORG \$C000\n"
    "LDA VALB\n"
)
file(WRITE "${OUTPUT_DIR}/casmmfb.seq"
    "VALB: RTS\n"
)

# casmmf2: same logical program as casmmf1, but file C has NO trailing
# newline -- proves the synthetic inter-file LF sourceLoad inserts keeps
# "LDA VALD" and "VALD: RTS" from silently concatenating onto one line.
# Expected bytes are identical to casmmf1's (see casmmf2.ref.hex).
file(WRITE "${OUTPUT_DIR}/casmmfc.seq"
    ".ORG \$C000\n"
    "LDA VALD"
)
file(WRITE "${OUTPUT_DIR}/casmmfd.seq"
    "VALD: RTS\n"
)

# casmmf3: three files, chained forward references across two boundaries --
# proves the file loop generalizes past exactly two files.
# Expected (see casmmf3.ref.hex): JMP FILEF (3 bytes) -> FILEF resolves to
# $C003; JMP FILEG (3 bytes) at $C003 -> FILEG resolves to $C006; RTS at
# $C006.
file(WRITE "${OUTPUT_DIR}/casmmfe.seq"
    ".ORG \$C000\n"
    "JMP FILEF\n"
)
file(WRITE "${OUTPUT_DIR}/casmmff.seq"
    "FILEF: JMP FILEG\n"
)
file(WRITE "${OUTPUT_DIR}/casmmfg.seq"
    "FILEG: RTS\n"
)

# casmmfcr1/casmmfcr2: cross-file pending-CR latch regression (WP34,
# user-confirmed fix). File 1 ends in a bare CR (no LF); file 2 begins with
# a bare LF (its own leading blank line) followed by an invalid byte. If the
# pending-CR latch ever leaked across the file boundary, that leading LF
# would be silently swallowed as the tail of a phantom CRLF spanning both
# files -- the blank line's own newline would never be counted, and the
# invalid byte on the next line would misreport as LINE 1 instead of LINE 2.
# Assembled PC/bytes cannot distinguish this (a swallowed blank-line newline
# is a no-op either way -- casmRunPass does nothing for a bare NEWLINE
# token); only the reported diagnostic location proves the fix.
#   -> INVALID SOURCE BYTE ($19) AT LINE 2, COL 1 (OFFSET 0)
string(ASCII 13 CASM_MF_CR)
string(ASCII 10 CASM_MF_LF)
file(WRITE "${OUTPUT_DIR}/casmmfcr1.seq"
    ".ORG \$C000${CASM_MF_CR}"
)
file(WRITE "${OUTPUT_DIR}/casmmfcr2.seq"
    "${CASM_MF_LF}@${CASM_MF_LF}"
)

# casmmfdiag1/casmmfdiag2: WP35 first-file diagnostic filename fixture.
# The invalid byte is in the FIRST file (CasmDiagLocFileId == 0), the
# complement of casmmfcr1/casmmfcr2's non-first-file case -- proves the
# filename prints correctly for file index 0 too, not just a nonzero index.
# File 2's content is never reached: the invalid byte fires while still
# lexing file 1, before file 2's own content is ever read.
#   -> IN FILE CASMMFDIAG1.S
#      INVALID SOURCE BYTE ($19) AT LINE 2, COL 1 (OFFSET 0)
file(WRITE "${OUTPUT_DIR}/casmmfdiag1.seq"
    ".ORG \$C000\n"
    "@\n"
)
file(WRITE "${OUTPUT_DIR}/casmmfdiag2.seq"
    "NOP\n"
)

# casmbiga/casmbigb: WP36 large, under-cap, two-file successful-assembly
# fixture. Closes a gap in the master plan's Phase 7 gate text ("large ...
# inputs assemble successfully") that no prior fixture actually proved --
# every earlier "large" fixture was either invalid syntax (pure
# sourceRefill traversal/chunk-boundary proof, e.g. casm256/casmvmm128) or
# deliberately over the 65535-byte combined cap (casmmfovf1/casmmfovf2, the
# failure path). 3000 NOP statements per file (6000 total, roughly 9% of
# the cap) -- file A opens .ORG $C000; file B has no .ORG, continuing the
# combined PC, matching casmmf1-3's convention. See
# tests/fixtures/casm/casmbig1.ref.hex for the hand-derived trusted
# reference (00 C0 header + EA x 6000, generated from one reviewed
# repetition rule rather than hand-typed).
string(REPEAT "NOP\n" 3000 CASM_BIG_BODY)
file(WRITE "${OUTPUT_DIR}/casmbiga.seq"
    ".ORG \$C000\n"
    "${CASM_BIG_BODY}"
)
file(WRITE "${OUTPUT_DIR}/casmbigb.seq" "${CASM_BIG_BODY}")

# casmmfovf1/casmmfovf2: combined multi-file source exceeding the
# 65535-byte cap (neither file alone does -- only their combined total
# does), firing during sourceLoad's own load phase, before any lexing.
#   -> SOURCE OFFSET OVERFLOW ($15), no location trailer (raised before any
#      diagSetLocFrom* call ever runs)
string(REPEAT "A" 40000 CASM_MF_OVF1)
string(REPEAT "A" 30000 CASM_MF_OVF2)
file(WRITE "${OUTPUT_DIR}/casmmfovf1.seq" "${CASM_MF_OVF1}")
file(WRITE "${OUTPUT_DIR}/casmmfovf2.seq" "${CASM_MF_OVF2}")

# CASM Phase 11 WP61 Increment 6: exact source-extent boundary fixtures.
# casmsrcmax.seq is valid CASM source (unlike casmmfovf1/2 above, which are
# deliberately non-syntactic since they only need to overflow before
# lexing) totaling exactly CASM_SOURCE_VMM_MAX_BYTES (65535) bytes, so it
# alone proves the exact accepted extent with a real successful assembly:
# ".ORG $C000\n" is 11 bytes; 16381 "NOP\n" lines (4 bytes each) is 65524
# bytes; 11 + 65524 = 65535 exactly. casmsrcbit.seq is a single trivial
# byte -- paired with casmsrcmax.seq as a second source file, the combined
# total is exactly 65536, one byte past the cap, proving the reject
# boundary via sourceLoad's combined-file slCheckCap (source.s:369-373)
# without needing a second ~259-block fixture.
string(REPEAT "NOP\n" 16381 CASM_SRCMAX_BODY)
file(WRITE "${OUTPUT_DIR}/casmsrcmax.seq"
    ".ORG \$C000\n"
    "${CASM_SRCMAX_BODY}"
)
file(WRITE "${OUTPUT_DIR}/casmsrcbit.seq" "\n")

# WP38 default relocatable origin fixtures. casmorg1.seq already exists
# (Phase 4 WP13: "LDA #$01", no .ORG) and is reused unmodified here as the
# primary positive case -- its expected outcome flips from the historical
# CASM_DIAG_ORG_REQUIRED (Phase 4, .ORG was mandatory) to a successful
# relocatable assembly at CASM_DEFAULT_ORIGIN ($3400). This is the intended
# effect of WP38, not a regression; see
# brain/plans/2026-07-24-casm-phase8-wp38-default-origin-and-static-override.md.
#
# casmorgexpl1: the same single instruction with an explicit .ORG $3400.
# Its trusted reference is byte-identical to casmorg1's, proving the
# implicit default and an explicit .ORG at the same address produce
# identical output through the same emitRawByte header-write path, not
# merely "it doesn't crash."
file(WRITE "${OUTPUT_DIR}/casmorgexpl1.seq"
    ".ORG \$3400\n"
    "LDA #\$01\n"
)

# casmnoorg1: no .ORG, with a forward-referenced label -- proves the full
# two-pass label-resolution pipeline (not just emitMarkStarted's own state
# machine) agrees with the implicit default origin in both passes.
# START: JMP TARGET / TARGET: NOP. START=$3400 (no bytes). JMP is 3 bytes at
# $3400-$3402, opcode $4C. TARGET=$3403 (JMP's operand, little-endian: 03
# 34). NOP ($EA) at $3403.
file(WRITE "${OUTPUT_DIR}/casmnoorg1.seq"
    "START:\n"
    "    JMP TARGET\n"
    "TARGET:\n"
    "    NOP\n"
)

# casmorglate1: a label (the implicit-default trigger) followed by a later
# .ORG. Closes the latent gap found during WP38 planning -- crpLabel never
# guarded against this before, so "a label before .ORG" was silently
# accepted rather than rejected. Now fails with CASM_DIAG_DUPLICATE_ORG
# (reused for the late-.ORG case per the user's confirmed WP38 decision --
# structurally ".ORG arrived after output had already started," whether the
# earlier event was itself an .ORG or not).
#   -> DUPLICATE ORG
file(WRITE "${OUTPUT_DIR}/casmorglate1.seq"
    "START:\n"
    ".ORG \$C000\n"
)

# WP39 ordering-hazard fixture: no .ORG, and unlike casmnoorg1 (which starts
# with a label), the very first statement here is a bare instruction with a
# forward symbol operand. parserParseStatement evaluates JMP's operand
# expression inline, before casmRunPass ever dispatches to emitInstruction
# -- the exact ordering hazard WP39 closes via a commit call inside
# parserParseExpressionValue itself. Byte-identical to casmnoorg1's output
# (same addresses, same opcode) -- the point is proving the first-statement
# shape assembles correctly, not a different result.
file(WRITE "${OUTPUT_DIR}/casmordhaz1.seq"
    "    JMP TARGET\n"
    "TARGET:\n"
    "    NOP\n"
)

# WP40 relocation emission-site fixtures. Program bytes only -- no R6 table
# or footer exists yet (WP41), so these prove the new emitMaybeRecordHi/Lo
# hooks do not corrupt normal emission, not the table's contents.
#
# casmrelop1: one instance of each site from the WP40 plan's Dependency
# Review items 1-4 that records a byte under the *normal* (non-extraction)
# shape -- JMP LABEL (absolute, VAL_HI relocatable), LDA #>DATA (immediate,
# VAL_LO relocatable), LDX #<DATA (immediate, LOW extraction -- negative
# case, never relocatable), .WORD DATA (VAL_HI relocatable), .BYTE >DATA
# (VAL_LO relocatable). DATA = $340A (MID's three instructions plus the
# .WORD/.BYTE bytes after JMP's 3 bytes at $3400): high byte $34, low byte
# $0A.
#   00 34        PRG load-address header ($3400)
#   4C 03 34     JMP MID              (MID = $3403)
#   A9 34        LDA #>DATA           (DATA's high byte, $34)
#   A2 0A        LDX #<DATA           (DATA's low byte, $0A -- never relocatable)
#   0A 34        .WORD DATA           (little-endian: $0A, $34)
#   34           .BYTE >DATA          (DATA's high byte, $34)
#   EA           NOP                  (at $340A, defines DATA)
file(WRITE "${OUTPUT_DIR}/casmrelop1.seq"
    "START:\n"
    "    JMP MID\n"
    "MID:\n"
    "    LDA #>DATA\n"
    "    LDX #<DATA\n"
    "    .WORD DATA\n"
    "    .BYTE >DATA\n"
    "DATA:\n"
    "    NOP\n"
)

# casmrelop2: the two-sided extraction cases found during this WP's own
# research (plan Dependency Review items 1-2) -- LDA >TARGET (absolute mode
# via FORCE_ABS promotion, not immediate) and .WORD >TARGET both put the
# real relocatable byte in the VAL_LO position with VAL_HI as
# applyExtraction's zero pad, the opposite of the normal case casmrelop1
# covers. TARGET = $3405 (LDA >TARGET's 3 bytes after START at $3400):
# high byte $34.
#   00 34        PRG load-address header ($3400)
#   AD 34 00     LDA >TARGET          (TARGET's high byte $34 in ValLo; $00 pad)
#   34 00        .WORD >TARGET        (same: $34 in ValLo, $00 pad in ValHi)
#   EA           NOP                  (at $3405, defines TARGET)
file(WRITE "${OUTPUT_DIR}/casmrelop2.seq"
    "START:\n"
    "    LDA >TARGET\n"
    "    .WORD >TARGET\n"
    "TARGET:\n"
    "    NOP\n"
)

# WP42 runtime relocation-loading proof. Unlike casmrelop1/casmrelop2 (which
# exist only to prove CASM's own classification/recording, verified
# exclusively via COMP against a byte reference), casmreloc1 exists to be
# loaded away from its assembled address and actually run, proving the OS's
# existing aptRelocate loader (src/command64/loader.asm) correctly consumes
# CASM's native R6 footer for the first time. Its one relocatable byte is
# the extracted high byte of a DOS_PRINT_STR message pointer (LDY #>MSG,
# the same immediate-extraction shape casmrelop2 already established is
# correctly recorded) -- if aptRelocate fails to patch it when loaded at a
# non-default page, the pointer targets stale, wrong-page memory and the
# program visibly prints garbage instead of the expected message; if it
# patches correctly, the same message prints regardless of load address.
# Message bytes are explicit hex, matching casmhello's own convention, to
# avoid any PETSCII/ASCII charmap ambiguity in raw output bytes.
#
# MSG = $340E (START's 14 bytes: two 2-byte immediate loads, LDA #DOS_PRINT_STR,
# JSR OS_API, LDA #DOS_EXIT, JSR OS_API): high byte $34, low byte $0E.
#   00 34              PRG load-address header ($3400)
#   A2 0E              LDX #<MSG            (MSG's low byte, $0E -- never relocatable)
#   A0 34              LDY #>MSG            (MSG's high byte, $34 -- RELOCATABLE)
#   A9 09              LDA #$09             (DOS_PRINT_STR)
#   20 00 10           JSR $1000            (OS_API, fixed -- never relocatable)
#   A9 4C              LDA #$4C             (DOS_EXIT)
#   20 00 10           JSR $1000
#   43 41 53 4D 20     MSG: "CASM "
#   52 45 4C 4F 43 20       "RELOC "
#   52 55 4E 53 20          "RUNS "
#   4F 4B                   "OK"
#   0D 00                   CR, NUL
file(WRITE "${OUTPUT_DIR}/casmreloc1.seq"
    "START:\n"
    "    LDX #<MSG\n"
    "    LDY #>MSG\n"
    "    LDA #\$09\n"
    "    JSR \$1000\n"
    "    LDA #\$4C\n"
    "    JSR \$1000\n"
    "MSG:\n"
    "    .BYTE \$43, \$41, \$53, \$4D, \$20\n"
    "    .BYTE \$52, \$45, \$4C, \$4F, \$43, \$20\n"
    "    .BYTE \$52, \$55, \$4E, \$53, \$20\n"
    "    .BYTE \$4F, \$4B\n"
    "    .BYTE \$0D, \$00\n"
)

# CASM Phase 9 WP45 test_casm_catalog fixtures. Plain raw byte content, not
# CASM source -- includeCatalogLoad/sourceAppendFile stream and append these
# unparsed, so exact distinct sizes (not their content) are what the harness
# asserts against. casmcat3 seeds the source store as the one top-level file
# (sourceLoad); casmcat1/casmcat2 are the first two distinct catalog entries;
# casmcat4 is a third distinct entry used right after a repeated-load/
# cache-hit case to prove no phantom append occurred; casmcat5 is the
# catalog's 32nd (capacity-boundary) real entry.
string(REPEAT "1" 10 CASM_CAT_BODY_1)
file(WRITE "${OUTPUT_DIR}/casmcat1.seq" "${CASM_CAT_BODY_1}")
string(REPEAT "2" 15 CASM_CAT_BODY_2)
file(WRITE "${OUTPUT_DIR}/casmcat2.seq" "${CASM_CAT_BODY_2}")
string(REPEAT "3" 8 CASM_CAT_BODY_3)
file(WRITE "${OUTPUT_DIR}/casmcat3.seq" "${CASM_CAT_BODY_3}")
string(REPEAT "4" 20 CASM_CAT_BODY_4)
file(WRITE "${OUTPUT_DIR}/casmcat4.seq" "${CASM_CAT_BODY_4}")
string(REPEAT "5" 12 CASM_CAT_BODY_5)
file(WRITE "${OUTPUT_DIR}/casmcat5.seq" "${CASM_CAT_BODY_5}")

# CASM Phase 9 WP46 test_casm_frame fixtures. Real CASM statement source
# (label-only lines plus one or more .INCLUDE directives), so the harness's
# own real lexer/parser drives traversal across genuine frame push/pop
# boundaries -- unlike WP45's raw-byte casmcat* fixtures above.
#
# casmfrp1/casmfrc1: single push/pop. Parent labels P1(line1)/P2(line2),
# .INCLUDE at line3, child labels C1(line1)/C2(line2) in the child's own
# numbering, then parent resumes at P3(line4)/P4(line5).
file(WRITE "${OUTPUT_DIR}/casmfrp1.seq"
    "P1:${CASM_LF}P2:${CASM_LF}.INCLUDE \"CASMFRC1\"${CASM_LF}P3:${CASM_LF}P4:${CASM_LF}"
)
file(WRITE "${OUTPUT_DIR}/casmfrc1.seq"
    "C1:${CASM_LF}C2:${CASM_LF}"
)

# casmfrp2/casmfrc2/casmfrc3: three-level nesting. N1(line1) ->
# .INCLUDE at line2 -> M1(line1 in casmfrc2) -> .INCLUDE at line2 ->
# G1(line1 in casmfrc3)/G2(line2) -> pop -> M2(line3 in casmfrc2) -> pop ->
# N2(line3 in casmfrp2).
file(WRITE "${OUTPUT_DIR}/casmfrp2.seq"
    "N1:${CASM_LF}.INCLUDE \"CASMFRC2\"${CASM_LF}N2:${CASM_LF}"
)
file(WRITE "${OUTPUT_DIR}/casmfrc2.seq"
    "M1:${CASM_LF}.INCLUDE \"CASMFRC3\"${CASM_LF}M2:${CASM_LF}"
)
file(WRITE "${OUTPUT_DIR}/casmfrc3.seq"
    "G1:${CASM_LF}G2:${CASM_LF}"
)

# casmfrp3: sequential reinclusion of the same physical file (casmfrc1)
# from two different .INCLUDE sites in the same parent, after the first
# frame has already popped -- must be legal (not a cycle) and must be a
# deduplicated cache hit the second time (Phase 0C.19).
file(WRITE "${OUTPUT_DIR}/casmfrp3.seq"
    "S1:${CASM_LF}.INCLUDE \"CASMFRC1\"${CASM_LF}S2:${CASM_LF}.INCLUDE \"CASMFRC1\"${CASM_LF}S3:${CASM_LF}"
)

# casmfrp4/casmfrcr1: pending-CR must never cross a frame boundary.
# casmfrcr1 ends in a bare CR (no trailing LF, matching casmfincr.seq's
# own existing bare-final-CR convention) as the child's very last byte;
# casmfrp4 resumes with a blank line (a lone LF) immediately after the
# .INCLUDE. If the child's trailing CR wrongly collapsed with that
# resumed LF as one CRLF pair, the blank line would be lost and P3 would
# be misnumbered line 3 instead of the correct line 4.
file(WRITE "${OUTPUT_DIR}/casmfrcr1.seq"
    "C1:${CASM_CR}"
)
file(WRITE "${OUTPUT_DIR}/casmfrp4.seq"
    "P1:${CASM_LF}.INCLUDE \"CASMFRCR1\"${CASM_LF}${CASM_LF}P3:${CASM_LF}"
)

# casmfrr1/casmfrr2: two top-level files (no includes at all) sharing a
# line number, proving the pre-existing WP34 echo-identity gap fix -- the
# root-transition boundary must reset the diagnostic echo bookkeeping the
# same way a frame push/pop does, not just line/column/pending-CR.
file(WRITE "${OUTPUT_DIR}/casmfrr1.seq"
    "R1:${CASM_LF}"
)
file(WRITE "${OUTPUT_DIR}/casmfrr2.seq"
    "R2:${CASM_LF}"
)

# WP48 end-to-end included-source diagnostic fixture. The failure originates
# in the grandchild, while both include sites begin at column 5. Production
# CASM must name CASMIDC2.S and render two INCLUDED FROM lines in
# innermost-to-root order, each reporting LINE 2 COLUMN 5.
file(WRITE "${OUTPUT_DIR}/casmidp1.seq"
    "ROOT:${CASM_LF}    .INCLUDE \"CASMIDC1.S\"${CASM_LF}AFTER:${CASM_LF}"
)
file(WRITE "${OUTPUT_DIR}/casmidc1.seq"
    "CHILD:${CASM_LF}    .INCLUDE \"CASMIDC2.S\"${CASM_LF}CHILDAFTER:${CASM_LF}"
)
file(WRITE "${OUTPUT_DIR}/casmidc2.seq"
    "GRAND:${CASM_LF}    LDA MISSING${CASM_LF}"
)

# WP48 amendment: same nested failure with no newline after the grandchild's
# failing statement. Fatal best-effort line draining must stop when child EOF
# pops to the parent, rather than appending the parent's CHILDAFTER text to the
# grandchild diagnostic line.
file(WRITE "${OUTPUT_DIR}/casmidup1.seq"
    "ROOT:${CASM_LF}    .INCLUDE \"CASMIDUC1.S\"${CASM_LF}ROOTAFTER:${CASM_LF}"
)
file(WRITE "${OUTPUT_DIR}/casmiduc1.seq"
    "CHILD:${CASM_LF}    .INCLUDE \"CASMIDUC2.S\"${CASM_LF}CHILDAFTER:${CASM_LF}"
)
file(WRITE "${OUTPUT_DIR}/casmiduc2.seq"
    "GRAND:${CASM_LF}    LDA MISSING"
)

# WP48 second amendment: invalid source byte before an unterminated child EOF.
# The diagnostic is raised while the child frame is still active, then fatal
# line-tail draining reaches EOF/pop. The packed-identity guard must stop before
# the resumed parent's DRAINAFTER text is appended to the child echo.
file(WRITE "${OUTPUT_DIR}/casmiddp1.seq"
    "ROOT:${CASM_LF}    .INCLUDE \"CASMIDDC1.S\"${CASM_LF}ROOTAFTER:${CASM_LF}"
)
file(WRITE "${OUTPUT_DIR}/casmiddc1.seq"
    "CHILD:${CASM_LF}    .INCLUDE \"CASMIDDC2.S\"${CASM_LF}DRAINAFTER:${CASM_LF}"
)
file(WRITE "${OUTPUT_DIR}/casmiddc2.seq"
    "GRAND:${CASM_LF}    .BYTE @"
)

# ---------------------------------------------------------------------------
# WP47 end-to-end `.INCLUDE` fixtures.
#
# Unlike every earlier Phase 9 fixture set, these are assembled by the real
# `casm` binary through the real casmRunPass dispatch -- WP47 is the work
# package that makes `.INCLUDE` actually assemble. Each case ships as a
# PAIR: an `.INCLUDE` version and a hand-flattened equivalent whose text is
# the literal textual expansion of that include. Assembling both and
# comparing the two output PRGs is the governing correctness property
# (Phase 9 verification matrix: "static and relocatable trusted-reference
# equivalence to flattened source"). The comparison is deliberately
# CASM-vs-CASM rather than against a hand-derived .ref: an opcode-table or
# expression defect would move both outputs identically, so any difference
# between them isolates an include-traversal defect specifically.
#
# Operands are spelled UPPERCASE with the ".S" suffix to pair with the
# lowercase cc1541 -f disk names these are written under (see CMakeLists.txt)
# -- cc1541 maps lowercase host bytes to unshifted PETSCII, which is exactly
# what uppercase ASCII in this source text becomes. Getting that pairing
# backwards makes DOS_OPEN_FILE silently miss the file.
#
# casmip1/casmic1/casmif1: single-level include with labels and a branch
# crossing the boundary in BOTH directions -- the parent's JMP targets a
# label defined inside the child (a reference backward across the include
# site), and the child's BNE targets a label defined in the parent AFTER
# the include site (a forward reference out of the child). Both directions
# must resolve identically to the flattened form, which is what proves the
# symbol table sees one continuous scope across a frame boundary.
file(WRITE "${OUTPUT_DIR}/casmip1.seq"
    ".ORG \$C000${CASM_LF}"
    "START:${CASM_LF}"
    "LDX #\$00${CASM_LF}"
    ".INCLUDE \"CASMIC1.S\"${CASM_LF}"
    "LDA #\$02${CASM_LF}"
    "JMP CHILDLBL${CASM_LF}"
    "BACKREF:${CASM_LF}"
    "NOP${CASM_LF}"
)
file(WRITE "${OUTPUT_DIR}/casmic1.seq"
    "CHILDLBL:${CASM_LF}"
    "LDA #\$01${CASM_LF}"
    "BNE BACKREF${CASM_LF}"
    "NOP${CASM_LF}"
)
file(WRITE "${OUTPUT_DIR}/casmif1.seq"
    ".ORG \$C000${CASM_LF}"
    "START:${CASM_LF}"
    "LDX #\$00${CASM_LF}"
    "CHILDLBL:${CASM_LF}"
    "LDA #\$01${CASM_LF}"
    "BNE BACKREF${CASM_LF}"
    "NOP${CASM_LF}"
    "LDA #\$02${CASM_LF}"
    "JMP CHILDLBL${CASM_LF}"
    "BACKREF:${CASM_LF}"
    "NOP${CASM_LF}"
)

# casmip2/casmic2/casmic3/casmif2: three-level nesting (parent -> child ->
# grandchild), with real statements before and after each include site so a
# mis-resumed parent shows up as wrong emitted bytes, not merely a wrong
# line number.
file(WRITE "${OUTPUT_DIR}/casmip2.seq"
    ".ORG \$C000${CASM_LF}"
    "LDX #\$01${CASM_LF}"
    ".INCLUDE \"CASMIC2.S\"${CASM_LF}"
    "LDY #\$04${CASM_LF}"
)
file(WRITE "${OUTPUT_DIR}/casmic2.seq"
    "LDA #\$02${CASM_LF}"
    ".INCLUDE \"CASMIC3.S\"${CASM_LF}"
    "NOP${CASM_LF}"
)
file(WRITE "${OUTPUT_DIR}/casmic3.seq"
    "INX${CASM_LF}"
    "INY${CASM_LF}"
)
file(WRITE "${OUTPUT_DIR}/casmif2.seq"
    ".ORG \$C000${CASM_LF}"
    "LDX #\$01${CASM_LF}"
    "LDA #\$02${CASM_LF}"
    "INX${CASM_LF}"
    "INY${CASM_LF}"
    "NOP${CASM_LF}"
    "LDY #\$04${CASM_LF}"
)

# casmip3/casmif3: sequential reinclusion of one physical file from two
# different sites in the same parent. Phase 0C.19 requires the bytes to be
# stored once but EXPANDED both times, so the flattened equivalent contains
# the child's statements twice. This is also the case that proves two
# separate events referencing the same child index replay in the correct
# order. Reuses casmic3.seq rather than adding another fixture.
file(WRITE "${OUTPUT_DIR}/casmip3.seq"
    ".ORG \$C000${CASM_LF}"
    ".INCLUDE \"CASMIC3.S\"${CASM_LF}"
    "NOP${CASM_LF}"
    ".INCLUDE \"CASMIC3.S\"${CASM_LF}"
)
file(WRITE "${OUTPUT_DIR}/casmif3.seq"
    ".ORG \$C000${CASM_LF}"
    "INX${CASM_LF}"
    "INY${CASM_LF}"
    "NOP${CASM_LF}"
    "INX${CASM_LF}"
    "INY${CASM_LF}"
)

# casmip4/casmic4/casmif4: the same equivalence property for a RELOCATABLE
# assembly (no .ORG, so the default $3400 origin and the R6 footer apply).
# The child's `JMP TARGET4` is an absolute reference to a label defined in
# the parent after the include site, so this pair also proves the
# relocation TABLE matches between included and flattened forms -- not just
# the code bytes. A pair with only implied/immediate instructions would
# emit an empty relocation table and prove nothing about relocation.
file(WRITE "${OUTPUT_DIR}/casmip4.seq"
    "LDX #\$01${CASM_LF}"
    ".INCLUDE \"CASMIC4.S\"${CASM_LF}"
    "TARGET4:${CASM_LF}"
    "NOP${CASM_LF}"
)
file(WRITE "${OUTPUT_DIR}/casmic4.seq"
    "JMP TARGET4${CASM_LF}"
    "INX${CASM_LF}"
)
file(WRITE "${OUTPUT_DIR}/casmif4.seq"
    "LDX #\$01${CASM_LF}"
    "JMP TARGET4${CASM_LF}"
    "INX${CASM_LF}"
    "TARGET4:${CASM_LF}"
    "NOP${CASM_LF}"
)

# WP51 Increment 6: test_casm_listcap real-path listing-capture fixtures.
# CASMLC01-CASMLC10 are top-level sources (loaded directly by sourceLoad,
# bare disk names -- casm_frame.s's own precedent, not the ".S"-suffixed
# convention); CASMLC7C.S/CASMLC7G.S are `.INCLUDE`-referenced children, so
# their disk names and operand spellings must match exactly.

# fixEmpty: the minimal non-empty SEQ file -- a bare CR, no other content.
# WP51 Increment 9 temp experiment: widened from a single CR (1 byte) to
# four (4 bytes) to test whether sourceLoad's phantom-byte over-read is
# specific to an exactly-1-byte file or a fixed-size artifact visible at
# any short length. Revert to a single "${CASM_CR}" once resolved.
file(WRITE "${OUTPUT_DIR}/casmlc01.seq" "${CASM_CR}${CASM_CR}${CASM_CR}${CASM_CR}")

# fixNewlineVariants: the same statement, CR/LF/CRLF terminated.
file(WRITE "${OUTPUT_DIR}/casmlc02.seq" ".BYTE 65${CASM_CR}")
file(WRITE "${OUTPUT_DIR}/casmlc03.seq" ".BYTE 65${CASM_LF}")
file(WRITE "${OUTPUT_DIR}/casmlc04.seq" ".BYTE 65${CASM_CRLF}")

# fixFinalUnterminated: no terminator at all before EOF.
file(WRITE "${OUTPUT_DIR}/casmlc05.seq" ".ORG \$2000${CASM_CR}.BYTE 1,2,3")

# fixDeferredData: .ORG / .BYTE list / .WORD list / a 255-character
# comment-only line (the Length field's byte-sized boundary), each properly
# terminated.
string(REPEAT "X" 254 CASM_LC06_COMMENT_BODY)
set(CASM_LC06_COMMENT ";${CASM_LC06_COMMENT_BODY}")
file(WRITE "${OUTPUT_DIR}/casmlc06.seq"
    ".ORG \$2000${CASM_CR}"
    ".BYTE 1,2,3,4,5${CASM_CR}"
    ".WORD \$1234,\$5678${CASM_CR}"
    "${CASM_LC06_COMMENT}${CASM_CR}"
)

# fixLabelsInclude: parent/child/grandchild, proving label + `.INCLUDE`
# zero-byte records, parent-before-child commit ordering, two levels of
# nesting, and the parent's own resume after both children pop.
file(WRITE "${OUTPUT_DIR}/casmlc07.seq"
    ".ORG \$2000${CASM_CR}"
    "START:${CASM_CR}"
    ".INCLUDE \"CASMLC7C\"${CASM_CR}"
    ".BYTE 9${CASM_CR}"
)
file(WRITE "${OUTPUT_DIR}/casmlc7c.seq"
    ".BYTE 1,2${CASM_CR}"
    ".INCLUDE \"CASMLC7G\"${CASM_CR}"
)
file(WRITE "${OUTPUT_DIR}/casmlc7g.seq"
    ".BYTE 3${CASM_CR}"
)

# fixRootsSynthetic: two top-level roots, the first with no terminator at
# all (forces sourceLoad's synthetic inter-root separator LF).
file(WRITE "${OUTPUT_DIR}/casmlc08.seq" "LBL1:")
file(WRITE "${OUTPUT_DIR}/casmlc09.seq" "LBL2:${CASM_CR}")

# fixPrgIdentity: assembled twice (capture off, then on) and byte-compared.
file(WRITE "${OUTPUT_DIR}/casmlc10.seq"
    ".ORG \$2000${CASM_CR}"
    ".BYTE 1,2,3,4,5${CASM_CR}"
)

# WP60 Increment 5: casmopall -- one legal statement for each of the 151
# NMOS 6502/6510 mnemonic/addressing-mode combinations frozen by Increment
# 1's independent oracle (brain/reviews/2026-08-12-casm-phase11-wp60-
# increment1-opcode-oracle.md). Statements appear in that oracle's own
# mnemonic-subtype/mode order (table rows 1-151), one CASM statement per
# row, using $12 for every 8-bit operand and $1234 for every 16-bit operand
# purely to instantiate syntax -- the same representative values the oracle
# document itself uses. All eight branch mnemonics (BCC/BCS/BEQ/BMI/BNE/
# BPL/BVC/BVS) target a same-numbered TGnn label placed immediately after
# their own 2-byte instruction, so every branch's displacement is
# mechanically 0 ($00) regardless of its position in the file -- boundary
# displacement values are Increment 6's concern, not this exhaustive
# per-combination sweep's.
#
# This source is a byte-identity fixture only: it is assembled and then
# byte-compared (native COMP) against the independently authored
# tests/fixtures/casm/casmopall.ref.hex reference. It contains BRK/JSR/RTS/
# JMP among its 151 statements and per the governing plan's Frozen
# Processor Contract is data-only and must never be executed.
file(WRITE "${OUTPUT_DIR}/casmopall.seq"
    ".ORG \$C000\n"
    "    ADC #\$12\n"
    "    ADC \$12\n"
    "    ADC \$12,X\n"
    "    ADC \$1234\n"
    "    ADC \$1234,X\n"
    "    ADC \$1234,Y\n"
    "    ADC (\$12,X)\n"
    "    ADC (\$12),Y\n"
    "    AND #\$12\n"
    "    AND \$12\n"
    "    AND \$12,X\n"
    "    AND \$1234\n"
    "    AND \$1234,X\n"
    "    AND \$1234,Y\n"
    "    AND (\$12,X)\n"
    "    AND (\$12),Y\n"
    "    ASL A\n"
    "    ASL \$12\n"
    "    ASL \$12,X\n"
    "    ASL \$1234\n"
    "    ASL \$1234,X\n"
    "    BCC TG22\n"
    "TG22:\n"
    "    BCS TG23\n"
    "TG23:\n"
    "    BEQ TG24\n"
    "TG24:\n"
    "    BIT \$12\n"
    "    BIT \$1234\n"
    "    BMI TG27\n"
    "TG27:\n"
    "    BNE TG28\n"
    "TG28:\n"
    "    BPL TG29\n"
    "TG29:\n"
    "    BRK\n"
    "    BVC TG31\n"
    "TG31:\n"
    "    BVS TG32\n"
    "TG32:\n"
    "    CLC\n"
    "    CLD\n"
    "    CLI\n"
    "    CLV\n"
    "    CMP #\$12\n"
    "    CMP \$12\n"
    "    CMP \$12,X\n"
    "    CMP \$1234\n"
    "    CMP \$1234,X\n"
    "    CMP \$1234,Y\n"
    "    CMP (\$12,X)\n"
    "    CMP (\$12),Y\n"
    "    CPX #\$12\n"
    "    CPX \$12\n"
    "    CPX \$1234\n"
    "    CPY #\$12\n"
    "    CPY \$12\n"
    "    CPY \$1234\n"
    "    DEC \$12\n"
    "    DEC \$12,X\n"
    "    DEC \$1234\n"
    "    DEC \$1234,X\n"
    "    DEX\n"
    "    DEY\n"
    "    EOR #\$12\n"
    "    EOR \$12\n"
    "    EOR \$12,X\n"
    "    EOR \$1234\n"
    "    EOR \$1234,X\n"
    "    EOR \$1234,Y\n"
    "    EOR (\$12,X)\n"
    "    EOR (\$12),Y\n"
    "    INC \$12\n"
    "    INC \$12,X\n"
    "    INC \$1234\n"
    "    INC \$1234,X\n"
    "    INX\n"
    "    INY\n"
    "    JMP \$1234\n"
    "    JMP (\$1234)\n"
    "    JSR \$1234\n"
    "    LDA #\$12\n"
    "    LDA \$12\n"
    "    LDA \$12,X\n"
    "    LDA \$1234\n"
    "    LDA \$1234,X\n"
    "    LDA \$1234,Y\n"
    "    LDA (\$12,X)\n"
    "    LDA (\$12),Y\n"
    "    LDX #\$12\n"
    "    LDX \$12\n"
    "    LDX \$12,Y\n"
    "    LDX \$1234\n"
    "    LDX \$1234,Y\n"
    "    LDY #\$12\n"
    "    LDY \$12\n"
    "    LDY \$12,X\n"
    "    LDY \$1234\n"
    "    LDY \$1234,X\n"
    "    LSR A\n"
    "    LSR \$12\n"
    "    LSR \$12,X\n"
    "    LSR \$1234\n"
    "    LSR \$1234,X\n"
    "    NOP\n"
    "    ORA #\$12\n"
    "    ORA \$12\n"
    "    ORA \$12,X\n"
    "    ORA \$1234\n"
    "    ORA \$1234,X\n"
    "    ORA \$1234,Y\n"
    "    ORA (\$12,X)\n"
    "    ORA (\$12),Y\n"
    "    PHA\n"
    "    PHP\n"
    "    PLA\n"
    "    PLP\n"
    "    ROL A\n"
    "    ROL \$12\n"
    "    ROL \$12,X\n"
    "    ROL \$1234\n"
    "    ROL \$1234,X\n"
    "    ROR A\n"
    "    ROR \$12\n"
    "    ROR \$12,X\n"
    "    ROR \$1234\n"
    "    ROR \$1234,X\n"
    "    RTI\n"
    "    RTS\n"
    "    SBC #\$12\n"
    "    SBC \$12\n"
    "    SBC \$12,X\n"
    "    SBC \$1234\n"
    "    SBC \$1234,X\n"
    "    SBC \$1234,Y\n"
    "    SBC (\$12,X)\n"
    "    SBC (\$12),Y\n"
    "    SEC\n"
    "    SED\n"
    "    SEI\n"
    "    STA \$12\n"
    "    STA \$12,X\n"
    "    STA \$1234\n"
    "    STA \$1234,X\n"
    "    STA \$1234,Y\n"
    "    STA (\$12,X)\n"
    "    STA (\$12),Y\n"
    "    STX \$12\n"
    "    STX \$12,Y\n"
    "    STX \$1234\n"
    "    STY \$12\n"
    "    STY \$12,X\n"
    "    STY \$1234\n"
    "    TAX\n"
    "    TAY\n"
    "    TSX\n"
    "    TXA\n"
    "    TXS\n"
    "    TYA\n")

# CASM Phase 12 WP65 Increment 10: named-constant end-to-end fixtures.
# Uppercase identifiers, matching every existing fixture's own convention in
# this file -- the lowercase-PETSCII convention (WP64's contract item 8,
# memory reference-c64-lowercase-petscii-convention) governs new shipped
# documentation/examples; a raw .seq fixture's lowercase bytes would need
# explicit PETSCII-shifted-range construction (CASM_PETSCII_SHIFTED_A =
# $C1, not ASCII 'a' = $61 -- see memory reference-casm-petscii-identifier-
# case), a real correctness risk unrelated to WP65's own feature under
# test, so this harness stays uppercase like its neighbors.
#
# casmconst1: a real end-to-end smoke test covering every WP65 resolution
# path in one assembly -- ENTRY = START forward-references a label not yet
# defined (deferred until the Pass1->Pass2 resolution sweep, since START's
# address isn't final until Pass 1 completes); SCREENW is an immediately-
# resolved numeric constant; BORDER = SCREENW + 10 is a constant
# referencing another constant, with an addend, itself immediately
# resolvable since SCREENW is already defined at that point. Expected
# emitted bytes (START lands at $C000, the first byte after .ORG, since no
# constant definition emits anything or advances CasmPc): A9 28 (LDA
# #$28) 8D 20 D0 (STA $D020) A9 32 (LDA #$32) 8D 21 D0 (STA $D021) 4C 00
# C0 (JMP $C000) -- 13 bytes.
file(WRITE "${OUTPUT_DIR}/casmconst1.seq"
    ".ORG \$C000\n"
    "ENTRY = START\n"
    "SCREENW = 40\n"
    "BORDER = SCREENW + 10\n"
    "START:\n"
    "LDA #SCREENW\n"
    "STA \$D020\n"
    "LDA #BORDER\n"
    "STA \$D021\n"
    "JMP ENTRY\n"
)

# casmconst2: genuine transitive circular constant definition (FOO -> BAR
# -> FOO), not just a direct self-reference -- proves crcResolveChain's
# cycle-detection bitmap catches a real multi-hop cycle, not only the
# trivial `SELF = SELF` case. Expects CASM_DIAG_EXPR_CIRCULAR ($43) and no
# output PRG. Deliberately not named A/B/X/Y: those single letters lex as
# CASM_TOKEN_REGISTER (the accumulator/index-register operand form, e.g.
# `ROL A`), not CASM_TOKEN_IDENTIFIER -- confirmed live (a genuine `A = B`
# fixture attempt produced SYNTAX ERROR, not CIRCULAR, since parserParse-
# Statement's dispatch never reaches ppsLabel/ppsConstant for a REGISTER-
# typed leading token at all).
file(WRITE "${OUTPUT_DIR}/casmconst2.seq"
    ".ORG \$C000\n"
    "FOO = BAR\n"
    "BAR = FOO\n"
    "NOP\n"
)

# casmconst3: direct self-reference (`SELF = SELF`), the degenerate
# single-node cycle -- distinct code path from casmconst2's two-node walk
# (the very first bitmap check on SELF's own record already catches it,
# before any symbolsLookup call even runs). Expects CASM_DIAG_EXPR_CIRCULAR
# ($43). Not named X (or Y): same CASM_TOKEN_REGISTER collision as
# casmconst2's own A/B avoidance above.
file(WRITE "${OUTPUT_DIR}/casmconst3.seq"
    ".ORG \$C000\n"
    "SELF = SELF\n"
    "NOP\n"
)

# casmconst4: a constant redefining an already-defined label's name.
# Expects CASM_DIAG_DUPLICATE_SYMBOL ($2C) -- symbolsFindChain's exact-name
# match is kind-agnostic (WP65 Increment 2 confirmed this, not assumed),
# so this needs no new code path of its own, only proof the existing one
# still fires correctly across the label/constant boundary.
file(WRITE "${OUTPUT_DIR}/casmconst4.seq"
    ".ORG \$C000\n"
    "START:\n"
    "NOP\n"
    "START = 5\n"
)
