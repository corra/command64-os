# cmake/IncrementBuildNumber.cmake
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Command64 project contributors
# Cross-platform build number increment script executed at build time via cmake -P
#
# Arguments expected via -D command line arguments:
#   BUILD_FILE        - Path to the persistent build counter file (e.g., BUILD_OS).
#                        Format: line 1 = build number, line 2 = content hash of
#                        the last build that bumped the number.
#   INC_FILE           - Path to the output assembly include file (e.g., build_os.inc)
#   DEFAULT_VERSION    - Default build number if the counter file doesn't exist
#   VAR_NAME           - Name of the assembly constant to define (default: BUILD_NUMBER)
#   SOURCES_LIST_FILE  - Path to a manifest file (one source path per line) whose
#                        combined content hash decides whether the build number
#                        actually needs to bump. The custom command that invokes
#                        this script still re-runs on any dependency mtime change
#                        (that's normal build-system behavior); the hash check is
#                        what stops a no-op touch/reformat from burning a number.

if(NOT DEFINED BUILD_FILE)
    message(FATAL_ERROR "BUILD_FILE is not defined")
endif()
if(NOT DEFINED INC_FILE)
    message(FATAL_ERROR "INC_FILE is not defined")
endif()
if(NOT DEFINED DEFAULT_VERSION)
    set(DEFAULT_VERSION 1000)
endif()
if(NOT DEFINED VAR_NAME)
    set(VAR_NAME "BUILD_NUMBER")
endif()
if(NOT DEFINED SOURCES_LIST_FILE)
    message(FATAL_ERROR "SOURCES_LIST_FILE is not defined")
endif()

# Compute a combined content hash across every tracked source file.
set(COMBINED_HASH_INPUT "")
if(EXISTS "${SOURCES_LIST_FILE}")
    file(STRINGS "${SOURCES_LIST_FILE}" SOURCE_PATHS)
    foreach(SRC_PATH ${SOURCE_PATHS})
        if(EXISTS "${SRC_PATH}")
            file(SHA256 "${SRC_PATH}" SRC_HASH)
            string(APPEND COMBINED_HASH_INPUT "${SRC_HASH}")
        endif()
    endforeach()
endif()
string(SHA256 NEW_HASH "${COMBINED_HASH_INPUT}")

# Read the previously recorded counter and hash.
set(OLD_VAL "${DEFAULT_VERSION}")
set(OLD_HASH "")
if(EXISTS "${BUILD_FILE}")
    file(STRINGS "${BUILD_FILE}" BUILD_FILE_LINES)
    list(LENGTH BUILD_FILE_LINES NUM_LINES)
    if(NUM_LINES GREATER_EQUAL 1)
        list(GET BUILD_FILE_LINES 0 FIRST_LINE)
        string(STRIP "${FIRST_LINE}" FIRST_LINE)
        if(FIRST_LINE MATCHES "^[0-9]+$")
            set(OLD_VAL "${FIRST_LINE}")
        endif()
    endif()
    if(NUM_LINES GREATER_EQUAL 2)
        list(GET BUILD_FILE_LINES 1 SECOND_LINE)
        string(STRIP "${SECOND_LINE}" SECOND_LINE)
        set(OLD_HASH "${SECOND_LINE}")
    endif()
endif()

if(OLD_HASH STREQUAL "")
    # Legacy file (counter only, no recorded hash) or first run: adopt the
    # current hash as the baseline without bumping, so migrating an existing
    # counter onto hash tracking doesn't itself burn a build number.
    set(NEW_VAL "${OLD_VAL}")
    message(STATUS "Establishing content-hash baseline for ${BUILD_FILE} (build number unchanged: ${NEW_VAL})")
elseif(NOT NEW_HASH STREQUAL OLD_HASH)
    math(EXPR NEW_VAL "${OLD_VAL} + 1")
    message(STATUS "Content change detected -- incrementing build number to ${NEW_VAL} in ${BUILD_FILE}")
else()
    set(NEW_VAL "${OLD_VAL}")
    message(STATUS "No content change detected for ${BUILD_FILE}; build number remains ${NEW_VAL}")
endif()

# Rewritten unconditionally so the recorded hash always reflects the sources
# as of this configure/build; when nothing changed the bytes written are
# identical to what's already on disk, so git sees no diff.
file(WRITE "${BUILD_FILE}" "${NEW_VAL}\n${NEW_HASH}\n")

# Write the assembly include file
file(WRITE "${INC_FILE}" ".const ${VAR_NAME} = \"${NEW_VAL}\"\n")
