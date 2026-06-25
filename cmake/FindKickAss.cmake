# cmake/FindKickAss.cmake
# Find KickAssembler JAR file

find_file(KickAss_JAR
    NAMES KickAss.jar KickAssembler.jar
    PATHS "${CMAKE_SOURCE_DIR}/tools"
    DOC "Path to KickAssembler JAR file"
)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(KickAss
    REQUIRED_VARS KickAss_JAR
)

if(KickAss_FOUND)
    set(KICKASS_JAR "${KickAss_JAR}" CACHE FILEPATH "Path to KickAssembler JAR file")
endif()
