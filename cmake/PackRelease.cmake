# cmake/PackRelease.cmake
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

# Copy docs
if(EXISTS "${SOURCE_DIR}/docs")
    file(COPY "${SOURCE_DIR}/docs" DESTINATION "${RELEASE_DIR}")
    # Remove superpowers directory (planning, brainstorms, etc.)
    file(REMOVE_RECURSE "${RELEASE_DIR}/docs/superpowers")
endif()

# Copy compiled files and build list of items to archive
set(FILES_TO_ARCHIVE "")

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

if(EXISTS "${BINARY_DIR}/test.d64")
    file(COPY "${BINARY_DIR}/test.d64" DESTINATION "${RELEASE_DIR}")
    list(APPEND FILES_TO_ARCHIVE "test.d64")
endif()

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

# Create tar.gz archive
execute_process(
    COMMAND "${CMAKE_COMMAND}" -E tar cf "${RELEASE_NAME}.tar.gz" --format=gnutar ${FILES_TO_ARCHIVE}
    WORKING_DIRECTORY "${RELEASE_DIR}"
    RESULT_VARIABLE TAR_RESULT
)
if(NOT TAR_RESULT EQUAL 0)
    message(FATAL_ERROR "Failed to create tar.gz archive")
endif()

message(STATUS "Release ${VERSION} packaged successfully in ${RELEASE_DIR}/")
