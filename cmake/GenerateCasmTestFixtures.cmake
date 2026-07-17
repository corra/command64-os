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
