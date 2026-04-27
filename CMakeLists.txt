cmake_minimum_required(VERSION 3.10)
project(mandelbrot)

set(CMAKE_CXX_STANDARD 23)

add_subdirectory(external/SDL)

add_executable(mandelbrot src/main.cpp)
target_link_libraries(mandelbrot PRIVATE SDL3::SDL3)