# cmake/IncrementBuildNumber.cmake
# Cross-platform build number increment script executed at build time via cmake -P
#
# Arguments expected via -D command line arguments:
#   BUILD_FILE      - Path to the persistent build counter file (e.g., BUILD_OS)
#   INC_FILE        - Path to the output assembly include file (e.g., build_os.inc)
#   DEFAULT_VERSION - Default build number if the counter file doesn't exist
#   VAR_NAME        - Name of the assembly constant to define (default: BUILD_NUMBER)

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

set(OLD_VAL "${DEFAULT_VERSION}")
if(EXISTS "${BUILD_FILE}")
    file(READ "${BUILD_FILE}" CONTENT)
    string(STRIP "${CONTENT}" CONTENT)
    if(CONTENT MATCHES "^[0-9]+$")
        set(OLD_VAL "${CONTENT}")
    endif()
endif()

math(EXPR NEW_VAL "${OLD_VAL} + 1")

# Write the new build number back to the persistent file
file(WRITE "${BUILD_FILE}" "${NEW_VAL}\n")
message(STATUS "Incrementing build number to ${NEW_VAL} in ${BUILD_FILE}")

# Write the assembly include file
file(WRITE "${INC_FILE}" ".const ${VAR_NAME} = \"${NEW_VAL}\"\n")
