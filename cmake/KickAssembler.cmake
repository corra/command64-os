# cmake/KickAssembler.cmake
# Helper function to assemble 6502/6510 source files via KickAssembler

function(add_kickass_target TARGET_NAME)
    cmake_parse_arguments(KICKASS "" "ENTRY_FILE;OUTPUT_DIR" "SOURCES;DEPENDS;INCLUDE_DIRS" ${ARGN})
    
    if(NOT KICKASS_ENTRY_FILE)
        message(FATAL_ERROR "ENTRY_FILE is required for add_kickass_target")
    endif()
    
    if(NOT KICKASS_OUTPUT_DIR)
        set(KICKASS_OUTPUT_DIR "${CMAKE_BINARY_DIR}")
    endif()
    
    # Get absolute path for entry file
    get_filename_component(ENTRY_FILE_ABS "${KICKASS_ENTRY_FILE}" ABSOLUTE)
    get_filename_component(ENTRY_FILE_NAME "${ENTRY_FILE_ABS}" NAME_WE)
    
    set(OUTPUT_PRG "${KICKASS_OUTPUT_DIR}/${ENTRY_FILE_NAME}.prg")
    
    # Set search paths (-libdir)
    set(LIBDIR_ARGS "")
    foreach(INC_DIR ${KICKASS_INCLUDE_DIRS})
        get_filename_component(INC_DIR_ABS "${INC_DIR}" ABSOLUTE)
        list(APPEND LIBDIR_ARGS -libdir "${INC_DIR_ABS}")
    endforeach()
    
    # Get absolute path for output dir
    get_filename_component(OUTPUT_DIR_ABS "${KICKASS_OUTPUT_DIR}" ABSOLUTE)
    
    add_custom_command(
        OUTPUT "${OUTPUT_PRG}"
        COMMAND "${Java_JAVA_EXECUTABLE}" -jar "${KICKASS_JAR}" "${ENTRY_FILE_ABS}" ${LIBDIR_ARGS} -odir "${OUTPUT_DIR_ABS}"
        DEPENDS "${ENTRY_FILE_ABS}" ${KICKASS_SOURCES} ${KICKASS_DEPENDS}
        COMMENT "Assembling C64 binary: ${ENTRY_FILE_NAME}.prg"
        VERBATIM
    )
    
    # Create the custom target to be built by default
    add_custom_target(${TARGET_NAME} ALL DEPENDS "${OUTPUT_PRG}")
    
    # Expose the generated PRG file path as a property
    set_target_properties(${TARGET_NAME} PROPERTIES C64_PRG_PATH "${OUTPUT_PRG}")
endfunction()
