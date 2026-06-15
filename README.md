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


#### How do I build and run this project? (tested on Windows 11 and Linux)
You'll need c++ compiler, make and cmake (for windows MinGW installed over Msys2 or similar)
1. clone this repo with\
  `git clone --recurse-submodules https://github.com/Inoyuuuuu/mandelbrot.git`\
  and navigate into the folder
2. switch to this branch with\
   `git checkout cpu-escape-time-algorithm`
3. in the terminal type\
  `cmake .` `cmake -G "MinGW Makefiles"`\
  and afterwards\
  `mingw32-make`\
  to build the executable
4. type\
   `./mandelbrot`\
   to execute the program (you can adjust the window size by typing x and y afterwards, e.g. `./mandelbrot 900 700`)
