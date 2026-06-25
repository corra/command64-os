# cmake/FindOscar64.cmake
# Find Oscar64 C compiler

find_program(Oscar64_EXECUTABLE
    NAMES oscar64
    PATHS "${CMAKE_SOURCE_DIR}/tools/oscar64/bin"
    DOC "Path to Oscar64 C compiler"
)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(Oscar64
    REQUIRED_VARS Oscar64_EXECUTABLE
)

if(Oscar64_FOUND)
    set(OSCAR64_EXECUTABLE "${Oscar64_EXECUTABLE}" CACHE FILEPATH "Path to Oscar64 C compiler")
endif()
