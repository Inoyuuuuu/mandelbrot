cmake_minimum_required(VERSION 3.10)
project(mandelbrot LANGUAGES CUDA CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CUDA_STANDARD 23)

set(CMAKE_CUDA_ARCHITECTURES 86)

add_subdirectory(external/SDL)

add_executable(mandelbrot src/main.cu)
target_link_libraries(mandelbrot PRIVATE SDL3::SDL3)