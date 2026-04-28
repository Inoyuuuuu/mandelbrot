cmake_minimum_required(VERSION 3.10)
project(mandelbrot LANGUAGES CUDA CXX)

include(CheckLanguage)
check_language(CUDA)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CUDA_ARCHITECTURES 86)
set(CMAKE_CUDA_STANDARD 23)

add_subdirectory(external/SDL)

add_executable(mandelbrot src/main.cu)
set_target_properties(mandelbrot PROPERTIES LINKER_LANGUAGE CXX)
target_link_libraries(mandelbrot PRIVATE SDL3::SDL3)