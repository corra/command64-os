# cmake/PackRelease.cmake
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Command64 project contributors
# Cross-platform release packager executed at build time via cmake -P
#
# Arguments expected via -D command line arguments:
#   VERSION      - The project version string (e.g., 0.2.21)
#   SOURCE_DIR   - The repository source root directory
#   BINARY_DIR   - The CMake binary build directory
#   RELEASE_DIR  - The output release directory (usually SOURCE_DIR/release)
#   PRG_PATHS    - Semicolon-separated list of absolute paths to compiled PRG files

if(NOT DEFINED VERSION)
    message(FATAL_ERROR "VERSION is not defined")
endif()
if(NOT DEFINED SOURCE_DIR)
    message(FATAL_ERROR "SOURCE_DIR is not defined")
endif()
if(NOT DEFINED BINARY_DIR)
    message(FATAL_ERROR "BINARY_DIR is not defined")
endif()
if(NOT DEFINED RELEASE_DIR)
    message(FATAL_ERROR "RELEASE_DIR is not defined")
endif()

# Reconstruct list from comma-separated string
string(REPLACE "," ";" PRG_PATHS "${PRG_PATHS}")

set(RELEASE_NAME "command64-os-${VERSION}")

# Ensure release directory exists
file(MAKE_DIRECTORY "${RELEASE_DIR}")

# Clean and recreate release/docs
file(REMOVE_RECURSE "${RELEASE_DIR}/docs")

# Copy the release quickstart as the archive's top-level README
set(FILES_TO_ARCHIVE "")
if(EXISTS "${SOURCE_DIR}/packaging/RELEASE_README.md")
    file(COPY "${SOURCE_DIR}/packaging/RELEASE_README.md" DESTINATION "${RELEASE_DIR}")
    file(RENAME "${RELEASE_DIR}/RELEASE_README.md" "${RELEASE_DIR}/README.md")
    list(APPEND FILES_TO_ARCHIVE "README.md")
endif()

# Copy docs
if(EXISTS "${SOURCE_DIR}/docs")
    file(COPY "${SOURCE_DIR}/docs" DESTINATION "${RELEASE_DIR}")
    # Remove superpowers directory (planning, brainstorms, etc.)
    file(REMOVE_RECURSE "${RELEASE_DIR}/docs/superpowers")
endif()

# Copy compiled files and add them to the archive list
foreach(PRG_PATH ${PRG_PATHS})
    get_filename_component(PRG_NAME "${PRG_PATH}" NAME)
    file(COPY "${PRG_PATH}" DESTINATION "${RELEASE_DIR}")
    list(APPEND FILES_TO_ARCHIVE "${PRG_NAME}")
endforeach()

# Copy disk images
if(EXISTS "${BINARY_DIR}/image.d64")
    file(COPY "${BINARY_DIR}/image.d64" DESTINATION "${RELEASE_DIR}")
    list(APPEND FILES_TO_ARCHIVE "image.d64")
endif()
if(EXISTS "${BINARY_DIR}/command64_casm_utils.d64")
    file(COPY "${BINARY_DIR}/command64_casm_utils.d64" DESTINATION "${RELEASE_DIR}")
    list(APPEND FILES_TO_ARCHIVE "command64_casm_utils.d64")
endif()

# test.d64 and debug.prg are not packaged in the public release archive root.
# Remove any stale copies left in release/ by a prior version of this script.
file(REMOVE "${RELEASE_DIR}/test.d64")
file(REMOVE "${RELEASE_DIR}/debug.prg")

# Add docs to the archive list
list(APPEND FILES_TO_ARCHIVE "docs")

message(STATUS "Packaging release ${RELEASE_NAME} in ${RELEASE_DIR}...")

# Create ZIP archive (runs inside release/ so paths are relative)
execute_process(
    COMMAND "${CMAKE_COMMAND}" -E tar cf "${RELEASE_NAME}.zip" --format=zip ${FILES_TO_ARCHIVE}
    WORKING_DIRECTORY "${RELEASE_DIR}"
    RESULT_VARIABLE ZIP_RESULT
)
if(NOT ZIP_RESULT EQUAL 0)
    message(FATAL_ERROR "Failed to create ZIP archive")
endif()

# Create tar.gz archive (the 'z' mode flag is required for actual gzip
# compression -- plain "cf" silently wrote an uncompressed tar named
# .tar.gz, which "tar xzf" then failed to extract)
execute_process(
    COMMAND "${CMAKE_COMMAND}" -E tar czf "${RELEASE_NAME}.tar.gz" --format=gnutar ${FILES_TO_ARCHIVE}
    WORKING_DIRECTORY "${RELEASE_DIR}"
    RESULT_VARIABLE TAR_RESULT
)
if(NOT TAR_RESULT EQUAL 0)
    message(FATAL_ERROR "Failed to create tar.gz archive")
endif()

message(STATUS "Release ${VERSION} packaged successfully in ${RELEASE_DIR}/")
