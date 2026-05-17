# Mandelbrot Set Visualization
A mandelbrot visualization project written in C/C++ and CUDA to implement GPU parallelization for increased calculation speeds. 
This project uses the [SDL3 library](https://www.libsdl.org/) as git submodule in order to display the mandelbrot set.

<div id="imgs">
  <img src="example_renders\mandel.png" width="30%">
  <img src="example_renders\mandel4.png" width="30%">
  <img src="example_renders\mandel5.png" width="30%">
</div>

### About Mandelbrot And This Project 
The mandelbrot set is calculated by exploring the complex series  <b>z<sub>n</sub> =  z<sub>n-1</sub><sup>2</sup> + c </b>  with different complex numbers.\
A complex number can be represented by a point on the complex plane, using the x axis for the real part and the y axis for the imaginary part. Here this plane is being mapped to the SDL window, so each pixel can represent a point on there.\
My algorithm is a simple escape time algorithm which determines how quickly a given number grows (if it grows at all). This is done by looking at which iteration the series exceeds a certain threshold. If color is applied to each point based on their iteration value, the mandelbrot appears.\
In my code, the gpu stores these calculated iteration values on shared memory so the cpu can access them afterwards, apply the color and draw the pixels to the active window.

### Features
- Zoom in and out with mousescroll
- "P" to print the current screen to an image (in ppm format)
- "F" to flip the zoomfactor (effectively the image on x axis)
- "R" to reset
- Adjust window size using the commanline arguments (e.g. `./mandelbrot 900 700`)
- "Esc" or close window to close program

### How do I build and run this project? (tested with CUDA on Linux)
Linux (recommended)
- install c++ compiler and build tools
- install [Cuda Toolkit](https://developer.nvidia.com/cuda/toolkit) (version compatible with your gpu)
- clone this repo with submodules via `git clone --recurse-submodules https://github.com/Inoyuuuuu/mandelbrot.git`
- open with e.g. visual studio code and choose your c++ compiler
- type `cmake .` in a terminal and afterwards `make` to build the executable
- navigate into the folder containing the executable and type `./mandelbrot` to execute the program (you can adjust the window size by typing x and y afterwards, e.g. `./mandelbrot 900 700`)

Windows
- install [microsoft build tools](https://visualstudio.microsoft.com/de/visual-cpp-build-tools/) (make sure to select "Desktop development with C++")
- install [Cuda Toolkit](https://developer.nvidia.com/cuda/toolkit) (version compatible with your gpu)
- clone this repo with submodules via `git clone --recurse-submodules https://github.com/Inoyuuuuu/mandelbrot.git`
- open with e.g. visual studio code and choose your c++ compiler
- type `cmake -S . -B build -G "Visual Studio 18 2026" -A x64` in a terminal and afterwards `cmake -G "Visual Studio 18 2026" -A x64` to build the executable
- navigate into the folder containing the executable and type `./mandelbrot` to execute the program (you can adjust the window size by typing x and y afterwards, e.g. `./mandelbrot 900 700`)

A CPU-only version can be found on [this branch](https://github.com/Inoyuuuuu/mandelbrot/tree/without-cuda).
