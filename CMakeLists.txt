cmake_minimum_required(VERSION 3.10)
project(mandelbrot)

set(CMAKE_CXX_STANDARD 23)

find_package(SDL3 REQUIRED)

add_executable(mandelbrot src/main.cpp)
target_link_libraries(mandelbrot SDL3::SDL3)