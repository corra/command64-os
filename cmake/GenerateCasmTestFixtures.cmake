# cmake/GenerateCasmTestFixtures.cmake
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Command64 project contributors

if(NOT DEFINED OUTPUT_DIR)
    message(FATAL_ERROR "OUTPUT_DIR is required")
endif()

file(MAKE_DIRECTORY "${OUTPUT_DIR}")

file(WRITE "${OUTPUT_DIR}/casmempty.seq" "")
file(WRITE "${OUTPUT_DIR}/casmshort.seq"
    ".ORG \$2000\n"
    "    LDA #10\n"
    "    STA \$0400,X\n"
    "    LDA %10101010\n"
    "    ; COMMENT\n"
    "    JMP START_LABEL\n"
)

string(REPEAT "A" 256 CASM_EXACT_BLOCK)
file(WRITE "${OUTPUT_DIR}/casm256.seq" "${CASM_EXACT_BLOCK}")

string(REPEAT "B" 513 CASM_MULTI_BLOCK)
file(WRITE "${OUTPUT_DIR}/casmmulti.seq" "${CASM_MULTI_BLOCK}")

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
