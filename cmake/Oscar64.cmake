# cmake/Oscar64.cmake
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Command64 project contributors
# Helper function to compile C source files via Oscar64 compiler

function(add_oscar64_target TARGET_NAME)
    cmake_parse_arguments(OSCAR64 "" "ENTRY_FILE;OUTPUT_DIR" "SOURCES;DEPENDS" ${ARGN})
    
    if(NOT OSCAR64_ENTRY_FILE)
        message(FATAL_ERROR "ENTRY_FILE is required for add_oscar64_target")
    endif()
    
    if(NOT OSCAR64_OUTPUT_DIR)
        set(OSCAR64_OUTPUT_DIR "${CMAKE_BINARY_DIR}")
    endif()
    
    # Get absolute path for entry file
    get_filename_component(ENTRY_FILE_ABS "${OSCAR64_ENTRY_FILE}" ABSOLUTE)
    get_filename_component(ENTRY_FILE_NAME "${ENTRY_FILE_ABS}" NAME_WE)
    
    set(OUTPUT_PRG "${OSCAR64_OUTPUT_DIR}/${ENTRY_FILE_NAME}.prg")
    get_filename_component(OUTPUT_PRG_ABS "${OUTPUT_PRG}" ABSOLUTE)
    
    add_custom_command(
        OUTPUT "${OUTPUT_PRG_ABS}"
        COMMAND "${OSCAR64_EXECUTABLE}" -o "${OUTPUT_PRG_ABS}" "${ENTRY_FILE_ABS}"
        DEPENDS "${ENTRY_FILE_ABS}" ${OSCAR64_SOURCES} ${OSCAR64_DEPENDS}
        COMMENT "Compiling C target ${ENTRY_FILE_NAME}.prg via Oscar64"
        VERBATIM
    )
    
    add_custom_target(${TARGET_NAME} ALL DEPENDS "${OUTPUT_PRG_ABS}")
    set_target_properties(${TARGET_NAME} PROPERTIES C64_PRG_PATH "${OUTPUT_PRG_ABS}")
endfunction()
