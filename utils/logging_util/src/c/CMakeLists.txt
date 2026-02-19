cmake_minimum_required(VERSION 3.20)
project(c_bindings C)

# Create a static library from c_bindings.c
add_library(c_bindings STATIC
    c_bindings.c
)

# Make sure the library uses the C compiler
set_target_properties(c_bindings PROPERTIES
    LINKER_LANGUAGE C
)

# Include directory for consumers of the library
target_include_directories(c_bindings PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}
)