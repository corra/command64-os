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
