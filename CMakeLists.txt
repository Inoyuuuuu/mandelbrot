cmake_minimum_required(VERSION 3.10)
project(mandelbrot LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)

add_subdirectory(external/SDL)

add_executable(mandelbrot
    src/main.cpp
    src/ColorManager.cpp
)

set_target_properties(mandelbrot PROPERTIES LINKER_LANGUAGE CXX)
target_link_libraries(mandelbrot PRIVATE SDL3::SDL3)