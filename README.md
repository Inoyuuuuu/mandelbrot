# Mandelbrot Set Visualization (CPU only/without CUDA)
A mandelbrot visualization project written in C/C++.\
This project uses the [SDL3 library](https://www.libsdl.org/) as git submodule in order to display the mandelbrot set.

#### Features
- Zoom in and out with mousescroll
- "P" to print the current screen to an image (in ppm format)
- "F" to flip the zoomfactor (effectively the image on x axis)
- "R" to reset
- Adjust window size using the commanline arguments (e.g. `./mandelbrot 900 700`)
- "Esc" or close window to close the application

#### How do I build and run this project? (only tested on Linux)
- c++ compiler, make and cmake (e.g. using MinGW installed over Msys2)
- clone this repo with `git clone --recurse-submodules https://github.com/Inoyuuuuu/mandelbrot.git`
- switch to this branch with `git switch without-cuda`
- open with visual studio code and choose your c++ compiler
- type `cmake -G "MinGW Makefiles"` in the terminal and afterwards `mingw32-make` to build the executable
- type `./mandelbrot` to execute the program (you can adjust the window size by typing x and y afterwards, e.g. `./mandelbrot 900 700`)
