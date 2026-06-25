# cmake/Findcc1541.cmake
# Find cc1541 compiler tool

find_program(cc1541_EXECUTABLE
    NAMES cc1541
    PATHS "${CMAKE_SOURCE_DIR}/tools"
    DOC "Path to cc1541 disk imaging tool"
)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(cc1541
    REQUIRED_VARS cc1541_EXECUTABLE
)

if(cc1541_FOUND)
    set(CC1541_EXECUTABLE "${cc1541_EXECUTABLE}" CACHE FILEPATH "Path to cc1541 disk imaging tool")
endif()
