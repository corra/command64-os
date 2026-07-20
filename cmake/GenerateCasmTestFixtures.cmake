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
