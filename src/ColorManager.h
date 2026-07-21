#pragma once

#include <array>
#include <cstdint>
#include <string>

using namespace std;

//API
array<uint8_t, 4> colorMandelbrot(int colorMode, int iteration, int maxIterations);
string getColorModeName(int colorMode);
int getTotalColorModes();

//--- COLOR MODES ---
//switch-case
array<uint8_t, 4> calcPixelColor_rainbow(int iteration, int maxIterations);
array<uint8_t, 4> calcPixelColor_bw(int iteration, int maxIterations);

//interpolation
array<uint8_t, 4> calcPixelColorInterpolation_bw(int iteration, int maxIterations);

//special
array<uint8_t, 4> calcPixelColorLCH(int iteration, int maxIterations);

