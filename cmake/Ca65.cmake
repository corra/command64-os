# cmake/Ca65.cmake
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Command64 project contributors
#
# ca65/ld65 build functions for this project. Tool discovery lives in
# cmake/FindCa65.cmake (find_package(Ca65), called from the root
# CMakeLists.txt before this file is include()'d) -- mirrors Oscar64's
# "inert if the tool isn't present" pattern, so absence of cc65 must not
# break the real Kick build.
#
# Hosts one function, add_ca65_app: the production ca65/ld65 build path
# (Phase 3), mirroring cmake/KickAssembler.cmake's add_external_app --
# versioned, -t c64/include/ca65-aware, .cfg-templated. Every external
# app and test uses this. The original exploratory-spike function,
# add_ca65_spike_app, was retired in Phase 5 of
# brain/plans/2026-07-08-ca65-adoption-and-spike-migration.md once its
# last caller (the spike/ca65-tests/*.s test loop) was migrated.

# Production ca65/ld65 external-app target, mirroring
# cmake/KickAssembler.cmake's add_external_app: enforces a persistent
# BUILD_<NAME> counter file, hash-gates the build-number bump via
# cmake/IncrementBuildNumber.cmake (ASM_DIALECT=ca65), and produces a
# relocatable .prg via the same base/next-page + tools/reloc.py diff
# mechanism as every other app-defining function in this project.
#
# Design notes:
#   - Versioned (BUILD_<NAME> file + generated build_<name>.inc, same
#     contract external apps already follow for Kick builds).
#   - Passes -I include/ca65 (Phase 2's shared support library) and
#     -t c64 (PETSCII target character translation) to every ca65 call.
#   - Generates its own per-config .cfg pair from PRG_SIZE_HEX instead of
#     requiring two static checked-in .cfg files per app -- the MEMORY/
#     SEGMENTS structure is identical across every existing spike .cfg
#     pair; only `start` (USER_PROG_START_HEX/_NEXT, already a global
#     cache var) and `size` (this function's PRG_SIZE_HEX arg) vary.
#
# Optional 6th positional argument (via ARGN, not a named param, so the
# existing 5-arg call sites need no change): CODE_ALIGN. If given, adds
# ", align = <value>" to the generated .cfg's CODE segment line -- needed
# by apps (e.g. conway) that embed page-aligned data buffers directly in
# CODE via a source-level ".align" directive.
function(add_ca65_app TARGET_NAME ENTRY_FILE SOURCES_VAR DEFAULT_VERSION PRG_SIZE_HEX)
    set(CODE_ALIGN "")
    if(ARGC GREATER 5)
        list(GET ARGN 0 CODE_ALIGN)
    endif()
    string(TOUPPER "${TARGET_NAME}" TARGET_NAME_UPPER)
    get_filename_component(ENTRY_FILE_ABS "${ENTRY_FILE}" ABSOLUTE)
    get_filename_component(ENTRY_FILE_DIR "${ENTRY_FILE_ABS}" DIRECTORY)
    get_filename_component(ENTRY_FILE_NAME "${ENTRY_FILE_ABS}" NAME_WE)
    set(BUILD_FILE "${ENTRY_FILE_DIR}/BUILD_${TARGET_NAME_UPPER}")
    set(INC_FILE "${CMAKE_BINARY_DIR}/build_${TARGET_NAME}.inc")
    get_filename_component(INC_DIR "${INC_FILE}" DIRECTORY)

    # Enforce that the BUILD_<APP> file exists in the source directory --
    # same contract as add_external_app.
    if(NOT EXISTS "${BUILD_FILE}")
        message(FATAL_ERROR
            "\n"
            "========================================================================\n"
            " VERSIONING VIOLATION:\n"
            " External application target '${TARGET_NAME}' requires a persistent build\n"
            " counter file at: '${BUILD_FILE}'.\n"
            " Please create this file (alongside the target's entry source file)\n"
            " containing the starting build number (e.g. 1000) before configuring.\n"
            "========================================================================"
        )
    endif()

    # Manifest file for the content-hash gate -- same rationale as
    # add_external_app (an unescaped CMake list in a COMMAND argument gets
    # silently split by its semicolons).
    set(HASH_SOURCES "${ENTRY_FILE_ABS}" ${${SOURCES_VAR}})
    list(REMOVE_DUPLICATES HASH_SOURCES)
    list(SORT HASH_SOURCES)
    set(HASH_SOURCES_FILE "${CMAKE_BINARY_DIR}/build_${TARGET_NAME}_sources.txt")
    string(REPLACE ";" "\n" HASH_SOURCES_CONTENT "${HASH_SOURCES}")
    file(WRITE "${HASH_SOURCES_FILE}" "${HASH_SOURCES_CONTENT}\n")

    add_custom_command(
        OUTPUT "${INC_FILE}"
        COMMAND "${CMAKE_COMMAND}"
            -DBUILD_FILE="${BUILD_FILE}"
            -DINC_FILE="${INC_FILE}"
            -DDEFAULT_VERSION=${DEFAULT_VERSION}
            -DVAR_NAME="BUILD_NUMBER"
            -DSOURCES_LIST_FILE="${HASH_SOURCES_FILE}"
            -DASM_DIALECT=ca65
            -P "${CMAKE_SOURCE_DIR}/cmake/IncrementBuildNumber.cmake"
        DEPENDS ${${SOURCES_VAR}} "${ENTRY_FILE_ABS}"
        COMMENT "Checking/Incrementing ${TARGET_NAME_UPPER} build counter"
    )

    # Templated per-config .cfg pair -- MEMORY/SEGMENTS structure copied
    # from the existing static spike .cfg files (verified byte-identical
    # across all 6 checked-in pairs apart from `start`/`size`).
    set(CFG_DIR "${CMAKE_BINARY_DIR}/build_${TARGET_NAME}_cfg")
    file(MAKE_DIRECTORY "${CFG_DIR}")
    set(CFG_BASE "${CFG_DIR}/${TARGET_NAME}_${USER_PROG_START_HEX}.cfg")
    set(CFG_NEXT "${CFG_DIR}/${TARGET_NAME}_${USER_PROG_START_HEX_NEXT}.cfg")
    set(CODE_SEGMENT_LINE "    CODE:   load = MAIN,   type = ro;")
    if(CODE_ALIGN)
        set(CODE_SEGMENT_LINE "    CODE:   load = MAIN,   type = ro, align = ${CODE_ALIGN};")
    endif()
    set(CFG_TEMPLATE
"MEMORY {
    HEADER: start = $9000, size = $2,    file = %O;
    MAIN:   start = $@START@, size = $@SIZE@, file = %O, define = yes;
}

SEGMENTS {
    HEADER: load = HEADER, type = ro;
@CODE_SEGMENT@
    RODATA: load = MAIN,   type = ro;
    DATA:   load = MAIN,   type = rw;
    BSS:    load = MAIN,   type = bss;
}
")
    string(REPLACE "@CODE_SEGMENT@" "${CODE_SEGMENT_LINE}" CFG_TEMPLATE "${CFG_TEMPLATE}")
    string(REPLACE "@START@" "${USER_PROG_START_HEX}" CFG_BASE_CONTENT "${CFG_TEMPLATE}")
    string(REPLACE "@SIZE@" "${PRG_SIZE_HEX}" CFG_BASE_CONTENT "${CFG_BASE_CONTENT}")
    string(REPLACE "@START@" "${USER_PROG_START_HEX_NEXT}" CFG_NEXT_CONTENT "${CFG_TEMPLATE}")
    string(REPLACE "@SIZE@" "${PRG_SIZE_HEX}" CFG_NEXT_CONTENT "${CFG_NEXT_CONTENT}")
    file(WRITE "${CFG_BASE}" "${CFG_BASE_CONTENT}")
    file(WRITE "${CFG_NEXT}" "${CFG_NEXT_CONTENT}")

    # Assemble once (shared object set), link twice (base/next page).
    # ca65 has no #import-style flattening (unlike Kick), so every .s
    # source -- including the entry file -- is its own translation unit;
    # dedupe before compiling in case a caller lists the entry file in
    # both ENTRY_FILE and SOURCES_VAR (matching HASH_SOURCES's existing
    # dedupe above). SOURCES_VAR may also carry non-source dependency
    # files (app-local/shared .inc headers, tracked for the hash gate and
    # rebuild-on-change via HASH_SOURCES/DEPENDS above) -- filter to only
    # .s files here, since those aren't independently assemblable.
    set(ALL_SOURCES "${ENTRY_FILE_ABS}" ${${SOURCES_VAR}})
    list(REMOVE_DUPLICATES ALL_SOURCES)
    list(FILTER ALL_SOURCES INCLUDE REGEX "\\.s$")
    set(OUT_DIR "${CMAKE_BINARY_DIR}/out_${TARGET_NAME}")
    file(MAKE_DIRECTORY "${OUT_DIR}")
    set(OBJS "")
    foreach(SRC ${ALL_SOURCES})
        get_filename_component(SRC_ABS "${SRC}" ABSOLUTE)
        get_filename_component(SRC_DIR "${SRC_ABS}" DIRECTORY)
        get_filename_component(SRC_NAME "${SRC_ABS}" NAME_WE)
        set(OBJ "${OUT_DIR}/${SRC_NAME}.o")
        add_custom_command(
            OUTPUT "${OBJ}"
            COMMAND "${CA65_EXECUTABLE}" "${SRC_ABS}"
                -I "${SRC_DIR}" -I "${CMAKE_SOURCE_DIR}/include/ca65" -I "${INC_DIR}"
                -t c64 -o "${OBJ}"
            # DEPENDS the full source/include set (via HASH_SOURCES, which
            # -- like add_external_app's SOURCES_VAR convention -- should
            # glob any app-local .inc files alongside the .s sources), not
            # just this one translation unit: unlike Kick's single-pass
            # assembly, each source here gets its own object file, so a
            # change to a shared .include'd file (app-local common.inc or
            # include/ca65/*.inc) must invalidate every object, not just
            # whichever one happens to .include it directly.
            DEPENDS "${SRC_ABS}" "${INC_FILE}" ${HASH_SOURCES}
            COMMENT "ca65: assembling ${SRC_NAME}.s"
            VERBATIM
        )
        list(APPEND OBJS "${OBJ}")
    endforeach()

    set(PRG_BASE "${OUT_DIR}/${ENTRY_FILE_NAME}_base.prg")
    set(PRG_NEXT "${OUT_DIR}/${ENTRY_FILE_NAME}_next.prg")
    add_custom_command(
        OUTPUT "${PRG_BASE}"
        COMMAND "${LD65_EXECUTABLE}" -C "${CFG_BASE}" -o "${PRG_BASE}" ${OBJS}
        DEPENDS ${OBJS} "${CFG_BASE}"
        COMMENT "ld65: linking ${TARGET_NAME_UPPER} at $${USER_PROG_START_HEX} (relocation base build)"
        VERBATIM
    )
    add_custom_command(
        OUTPUT "${PRG_NEXT}"
        COMMAND "${LD65_EXECUTABLE}" -C "${CFG_NEXT}" -o "${PRG_NEXT}" ${OBJS}
        DEPENDS ${OBJS} "${CFG_NEXT}"
        COMMENT "ld65: linking ${TARGET_NAME_UPPER} at $${USER_PROG_START_HEX_NEXT} (relocation +1 page build)"
        VERBATIM
    )

    # Named after TARGET_NAME, not ENTRY_FILE_NAME: this file lands directly
    # in the shared CMAKE_BINARY_DIR (unlike the per-target OUT_DIR above),
    # and TARGET_NAME is the only one of the two CMake guarantees is unique
    # across the whole build -- ENTRY_FILE_NAME can collide with an
    # unrelated target that happens to reuse the same source basename (e.g.
    # a smoke-test target reusing an existing test's entry file).
    set(OUTPUT_PRG "${CMAKE_BINARY_DIR}/${TARGET_NAME}.prg")
    add_custom_command(
        OUTPUT "${OUTPUT_PRG}"
        COMMAND "${Python3_EXECUTABLE}" "${CMAKE_SOURCE_DIR}/tools/reloc.py" "${PRG_BASE}" "${PRG_NEXT}" "${OUTPUT_PRG}"
        DEPENDS "${PRG_BASE}" "${PRG_NEXT}" "${CMAKE_SOURCE_DIR}/tools/reloc.py"
        COMMENT "Building relocatable ${TARGET_NAME_UPPER}.prg"
        VERBATIM
    )

    add_custom_target(${TARGET_NAME} ALL DEPENDS "${OUTPUT_PRG}")
    set_target_properties(${TARGET_NAME} PROPERTIES C64_PRG_PATH "${OUTPUT_PRG}")
endfunction()
