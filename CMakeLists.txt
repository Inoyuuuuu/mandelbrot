cmake_minimum_required(VERSION 3.10)
project(mandelbrot LANGUAGES CUDA CXX)
include(CheckLanguage)
check_language(CUDA)
set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CUDA_ARCHITECTURES 86)
set(CMAKE_CUDA_STANDARD 23)

include(FetchContent)
FetchContent_Declare(
    zlib
    GIT_REPOSITORY https://github.com/madler/zlib.git
    GIT_TAG        v1.3.1
)
FetchContent_MakeAvailable(zlib)

add_subdirectory(external/SDL)

add_executable(mandelbrot
    src/main.cu
    src/ColorManager.cpp
    src/PPMtoPNGConverter.cpp
)
set_target_properties(mandelbrot PROPERTIES LINKER_LANGUAGE CXX)
target_link_libraries(mandelbrot PRIVATE SDL3::SDL3 zlibstatic)   # ← zlibstatic, not ZLIB::ZLIB