cmake_minimum_required(VERSION 3.20)

# Disable in-source builds
if(CMAKE_BINARY_DIR EQUAL CMAKE_SOURCE_DIR)
    message(FATAL_ERROR "In-source builds are not allowed. Please create a separate build directory and run cmake from there.")
endif()

project(command64-os VERSION 0.2.21 LANGUAGES NONE)

# Include custom CMake modules
list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake")

# Find required tools
find_package(Java REQUIRED)
find_package(KickAss REQUIRED)
find_package(cc1541 REQUIRED)
find_package(Oscar64) # Optional compiler for C files

# Load helper functions
include(KickAssembler)
include(cc1541)
include(Oscar64)

# Set disk metadata
set(DISK_NAME "Command 64")
set(DISK_ID "2a")

# Read version file
if(EXISTS "${CMAKE_SOURCE_DIR}/VERSION")
    file(READ "${CMAKE_SOURCE_DIR}/VERSION" OS_VERSION)
    string(STRIP "${OS_VERSION}" OS_VERSION)
else()
    set(OS_VERSION "${PROJECT_VERSION}")
endif()

# Source file discovery
file(GLOB_RECURSE CMD64_SRCS "src/command64/*.asm" "include/*.inc")
set(CMD64_ENTRY "src/command64.asm")

file(GLOB_RECURSE DEBUG_SRCS "src/external/debug/*.asm" "include/*.inc")
set(DEBUG_ENTRY "src/external/debug/debug.asm")

file(GLOB_RECURSE LABEL_SRCS "src/external/label/*.asm" "include/*.inc")
set(LABEL_ENTRY "src/external/label/label.asm")

# Dynamic build numbers custom commands
# These trigger the increment script only when dependency files change
add_custom_command(
    OUTPUT "${CMAKE_BINARY_DIR}/build_os.inc"
    COMMAND "${CMAKE_COMMAND}"
        -DBUILD_FILE="${CMAKE_SOURCE_DIR}/BUILD_OS"
        -DINC_FILE="${CMAKE_BINARY_DIR}/build_os.inc"
        -DDEFAULT_VERSION=2417
        -DVAR_NAME="BUILD_NUMBER"
        -P "${CMAKE_SOURCE_DIR}/cmake/IncrementBuildNumber.cmake"
    DEPENDS ${CMD64_SRCS}
    COMMENT "Checking/Incrementing OS build counter"
)

add_custom_command(
    OUTPUT "${CMAKE_BINARY_DIR}/build_debug.inc"
    COMMAND "${CMAKE_COMMAND}"
        -DBUILD_FILE="${CMAKE_SOURCE_DIR}/BUILD_DEBUG"
        -DINC_FILE="${CMAKE_BINARY_DIR}/build_debug.inc"
        -DDEFAULT_VERSION=1012
        -DVAR_NAME="BUILD_NUMBER"
        -P "${CMAKE_SOURCE_DIR}/cmake/IncrementBuildNumber.cmake"
    DEPENDS ${DEBUG_SRCS}
    COMMENT "Checking/Incrementing DEBUG build counter"
)

# 1. OS PRG Target
add_kickass_target(command64
    ENTRY_FILE "${CMD64_ENTRY}"
    SOURCES ${CMD64_SRCS}
    DEPENDS "${CMAKE_BINARY_DIR}/build_os.inc"
    INCLUDE_DIRS "${CMAKE_BINARY_DIR}"
)

# 2. DEBUG Utility PRG Target
add_kickass_target(debug
    ENTRY_FILE "${DEBUG_ENTRY}"
    SOURCES ${DEBUG_SRCS}
    DEPENDS "${CMAKE_BINARY_DIR}/build_debug.inc"
    INCLUDE_DIRS "${CMAKE_BINARY_DIR}"
)

# 3. LABEL External Command PRG Target
add_kickass_target(label
    ENTRY_FILE "${LABEL_ENTRY}"
    SOURCES ${LABEL_SRCS}
)

# 4. Test PRGs (one per tests/src/*.asm)
file(GLOB TEST_SRCS "tests/src/*.asm")
set(TEST_TARGETS "")
foreach(TEST_SRC ${TEST_SRCS})
    get_filename_component(TEST_NAME "${TEST_SRC}" NAME_WE)
    set(TEST_TARGET "test_${TEST_NAME}")
    add_kickass_target(${TEST_TARGET}
        ENTRY_FILE "${TEST_SRC}"
        SOURCES "${TEST_SRC}"
        OUTPUT_DIR "${CMAKE_BINARY_DIR}/tests"
    )
    list(APPEND TEST_TARGETS ${TEST_TARGET})
endforeach()

# 5. Oscar64 C Targets (inert until C sources are added)
file(GLOB_RECURSE C_SRCS "src/*.c" "src/**/*.c")
set(C_TARGETS "")
if(Oscar64_FOUND AND C_SRCS)
    foreach(C_SRC ${C_SRCS})
        get_filename_component(C_NAME "${C_SRC}" NAME_WE)
        add_oscar64_target(${C_NAME}
            ENTRY_FILE "${C_SRC}"
        )
        list(APPEND C_TARGETS ${C_NAME})
    endforeach()
endif()

# 6. Disk images
set(IMAGE_PRG_TARGETS command64 debug label ${C_TARGETS})
set(TEST_IMAGE_PRG_TARGETS ${IMAGE_PRG_TARGETS} ${TEST_TARGETS})

add_c64_disk_image(image_d64
    OUTPUT_FILE "${CMAKE_BINARY_DIR}/image.d64"
    DISK_LABEL "${DISK_NAME}"
    DISK_ID "${DISK_ID}"
    PRGS ${IMAGE_PRG_TARGETS}
)

add_c64_disk_image(test_image_d64
    OUTPUT_FILE "${CMAKE_BINARY_DIR}/test.d64"
    DISK_LABEL "${DISK_NAME}"
    DISK_ID "${DISK_ID}"
    PRGS ${TEST_IMAGE_PRG_TARGETS}
)

# 6. Release Target
# Gather built binary paths to pass to release script
get_target_property(CMD64_PATH command64 C64_PRG_PATH)
get_target_property(DEBUG_PATH debug C64_PRG_PATH)
set(PRG_PATHS_LIST "${CMD64_PATH};${DEBUG_PATH}")

foreach(C_TARGET ${C_TARGETS})
    get_target_property(C_PATH ${C_TARGET} C64_PRG_PATH)
    list(APPEND PRG_PATHS_LIST "${C_PATH}")
endforeach()

string(REPLACE ";" "," PRG_PATHS_STR "${PRG_PATHS_LIST}")

add_custom_target(release
    COMMAND "${CMAKE_COMMAND}"
        -DVERSION="${OS_VERSION}"
        -DSOURCE_DIR="${CMAKE_SOURCE_DIR}"
        -DBINARY_DIR="${CMAKE_BINARY_DIR}"
        -DRELEASE_DIR="${CMAKE_SOURCE_DIR}/release"
        -DPRG_PATHS="${PRG_PATHS_STR}"
        -P "${CMAKE_SOURCE_DIR}/cmake/PackRelease.cmake"
    DEPENDS image_d64 test_image_d64
    COMMENT "Packaging command64 OS v${OS_VERSION} release archives"
)
