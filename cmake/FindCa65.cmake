# cmake/FindCa65.cmake
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Command64 project contributors
# Find the ca65 assembler and ld65 linker (cc65 suite)

find_program(CA65_EXECUTABLE ca65)
find_program(LD65_EXECUTABLE ld65)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(Ca65
    REQUIRED_VARS CA65_EXECUTABLE LD65_EXECUTABLE
)
