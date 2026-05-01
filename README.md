# Mandelbrot Set Visualization
A mandelbrot visualization project written in C/C++ using CUDA to implement GPU parallelization for massively speeding up the calculations for each image rendered. 
This project uses the [SDL3 library](https://www.libsdl.org/) as git submodule in order to display the mandelbrot set.

#### Features
- Zoom in and out with mousescroll
- "P" to print the current screen to an image (in ppm format)
- "F" to flip the zoomfactor (effectively the image on x axis)
- "R" to reset
- Adjust window size using the commanline arguments (e.g. `./mandelbrot 900 700`)
- "Esc" or close window to close program

#### How do I build and run this project? (only tested on Linux)
- use [Cuda Toolkit](https://developer.nvidia.com/cuda/toolkit) (choose the version that fits your gpu)
- clone this repo with `git clone --recurse-submodules https://github.com/Inoyuuuuu/mandelbrot.git`
- open with visual studio code and choose your c++ compiler
- type `cmake .` in the terminal and afterwards `make` to build the executable
- type `./mandelbrot` to execute the program (you can adjust the window size by typing x and y afterwards, e.g. `./mandelbrot 900 700`)

A older version without CUDA (runs only on the CPU) is on [this branch](https://github.com/Inoyuuuuu/mandelbrot/tree/without-cuda).\
The CPU version also runs on Windows when using mingw.
