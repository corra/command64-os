# cmake/Ca65.cmake
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Command64 project contributors
#
# Optional ca65/ld65 toolchain support for the exploratory relocation spike
# in spike/ca65-conway/. Mirrors Oscar64.cmake's "inert if the tool isn't
# present" pattern -- absence of cc65 must not break the real Kick build.

find_program(CA65_EXECUTABLE ca65)
find_program(LD65_EXECUTABLE ld65)

if(CA65_EXECUTABLE AND LD65_EXECUTABLE)
    set(Ca65_FOUND TRUE)
else()
    set(Ca65_FOUND FALSE)
endif()

# Assembles SOURCES with ca65 (once each) and links them with ld65 against
# CONFIG into OUTPUT_NAME.prg, exposing it the same way add_kickass_target/
# add_external_app do (a target with a C64_PRG_PATH property) so it can be
# passed straight into add_c64_disk_image's PRGS list.
function(add_ca65_spike_app TARGET_NAME)
    cmake_parse_arguments(CA65APP "" "CONFIG;OUTPUT_NAME" "SOURCES" ${ARGN})

    if(NOT CA65APP_CONFIG)
        message(FATAL_ERROR "CONFIG is required for add_ca65_spike_app")
    endif()
    if(NOT CA65APP_OUTPUT_NAME)
        set(CA65APP_OUTPUT_NAME "${TARGET_NAME}")
    endif()

    set(SPIKE_OUT_DIR "${CMAKE_BINARY_DIR}/spike_ca65")
    file(MAKE_DIRECTORY "${SPIKE_OUT_DIR}")
    set(OBJS "")
    foreach(SRC ${CA65APP_SOURCES})
        get_filename_component(SRC_ABS "${SRC}" ABSOLUTE)
        get_filename_component(SRC_DIR "${SRC_ABS}" DIRECTORY)
        get_filename_component(SRC_NAME "${SRC}" NAME_WE)
        set(OBJ "${SPIKE_OUT_DIR}/${SRC_NAME}.o")
        add_custom_command(
            OUTPUT "${OBJ}"
            COMMAND "${CA65_EXECUTABLE}" "${SRC_ABS}" -I "${SRC_DIR}" -o "${OBJ}"
            DEPENDS "${SRC_ABS}"
            COMMENT "ca65 (spike): assembling ${SRC_NAME}.s"
            VERBATIM
        )
        list(APPEND OBJS "${OBJ}")
    endforeach()

    get_filename_component(CFG_ABS "${CA65APP_CONFIG}" ABSOLUTE)
    set(OUTPUT_PRG "${SPIKE_OUT_DIR}/${CA65APP_OUTPUT_NAME}.prg")
    add_custom_command(
        OUTPUT "${OUTPUT_PRG}"
        COMMAND "${LD65_EXECUTABLE}" -C "${CFG_ABS}" -o "${OUTPUT_PRG}" ${OBJS}
        DEPENDS ${OBJS} "${CFG_ABS}"
        COMMENT "ld65 (spike): linking ${CA65APP_OUTPUT_NAME}.prg"
        VERBATIM
    )

    add_custom_target(${TARGET_NAME} ALL DEPENDS "${OUTPUT_PRG}")
    set_target_properties(${TARGET_NAME} PROPERTIES C64_PRG_PATH "${OUTPUT_PRG}")
endfunction()
