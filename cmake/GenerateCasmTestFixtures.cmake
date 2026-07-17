# cmake/GenerateCasmTestFixtures.cmake
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Command64 project contributors

if(NOT DEFINED OUTPUT_DIR)
    message(FATAL_ERROR "OUTPUT_DIR is required")
endif()

file(MAKE_DIRECTORY "${OUTPUT_DIR}")

file(WRITE "${OUTPUT_DIR}/casmempty.seq" "")
file(WRITE "${OUTPUT_DIR}/casmshort.seq" "CASM SHORT INPUT\n")

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
