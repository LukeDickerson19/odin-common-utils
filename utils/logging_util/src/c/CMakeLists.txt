cmake_minimum_required(VERSION 3.20)
project(current_time_info C)

add_library(current_time_info STATIC
    current_time_info.c
)

set_target_properties(current_time_info PROPERTIES
    LINKER_LANGUAGE C
)

target_include_directories(current_time_info PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}
)
