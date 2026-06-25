# cmake/cc1541.cmake
# Helper function to generate C64 D64 disk images using cc1541

function(add_c64_disk_image TARGET_NAME)
    cmake_parse_arguments(DISK "" "OUTPUT_FILE;DISK_LABEL;DISK_ID" "PRGS" ${ARGN})
    
    if(NOT DISK_OUTPUT_FILE)
        message(FATAL_ERROR "OUTPUT_FILE is required for add_c64_disk_image")
    endif()
    
    if(NOT DISK_DISK_LABEL)
        set(DISK_DISK_LABEL "ms-dos 64")
    endif()
    
    if(NOT DISK_DISK_ID)
        set(DISK_DISK_ID "2a")
    endif()
    
    set(CC1541_COMMAND_ARGS -n "${DISK_DISK_LABEL}" -i "${DISK_DISK_ID}")
    set(DEPENDS_LIST "")
    
    # Process target programs
    foreach(PRG ${DISK_PRGS})
        # If it is a CMake target, fetch its compiled PRG path
        if(TARGET ${PRG})
            get_target_property(PRG_PATH ${PRG} C64_PRG_PATH)
            if(NOT PRG_PATH)
                message(FATAL_ERROR "Target ${PRG} does not have C64_PRG_PATH property defined")
            endif()
            list(APPEND DEPENDS_LIST ${PRG})
        else()
            # Direct file path
            set(PRG_PATH "${PRG}")
        endif()
        
        get_filename_component(PRG_NAME "${PRG_PATH}" NAME_WE)
        get_filename_component(PRG_PATH_ABS "${PRG_PATH}" ABSOLUTE)
        
        # cc1541 arguments: -f <disk_filename> -w <host_filepath>
        list(APPEND CC1541_COMMAND_ARGS -f "${PRG_NAME}" -w "${PRG_PATH_ABS}")
        list(APPEND DEPENDS_LIST "${PRG_PATH_ABS}")
    endforeach()
    
    get_filename_component(OUTPUT_FILE_ABS "${DISK_OUTPUT_FILE}" ABSOLUTE)
    list(APPEND CC1541_COMMAND_ARGS "${OUTPUT_FILE_ABS}")
    
    add_custom_command(
        OUTPUT "${OUTPUT_FILE_ABS}"
        COMMAND ${CMAKE_COMMAND} -E remove -f "${OUTPUT_FILE_ABS}"
        COMMAND "${CC1541_EXECUTABLE}" ${CC1541_COMMAND_ARGS}
        DEPENDS ${DEPENDS_LIST}
        COMMENT "Generating D64 disk image: ${TARGET_NAME}"
        VERBATIM
    )
    
    # Create the custom target to be built by default
    add_custom_target(${TARGET_NAME} ALL DEPENDS "${OUTPUT_FILE_ABS}")
    set_target_properties(${TARGET_NAME} PROPERTIES C64_DISK_IMAGE "${OUTPUT_FILE_ABS}")
endfunction()
