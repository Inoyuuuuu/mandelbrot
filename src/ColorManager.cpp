#include <stdio.h>
#include <array>
#include <algorithm>
#include <math.h>
#include <iostream>
#include <cstdint>

#include "ColorManager.h"

using namespace std;

int totalColorModes = 4;

array<uint8_t, 4> calcPixelColorLCH(int iteration, int maxIterations);
array<uint8_t, 4> calcPixelColor_rainbow(int iteration, int maxIterations);
array<uint8_t, 4> calcPixelColor_bw(int iteration, int maxIterations);
array<uint8_t, 4> calcPixelColorInterpolation_bw(int iteration, int maxIterations);

//API
array<uint8_t, 4> colorMandelbrot(int colorMode, int iteration, int maxIterations) {
    switch (colorMode) {
        case 0: return calcPixelColorLCH(iteration, maxIterations);
        case 1: return calcPixelColor_rainbow(iteration, maxIterations);
        case 2: return calcPixelColor_bw(iteration, maxIterations);
        case 3: return calcPixelColorInterpolation_bw(iteration, maxIterations);
        default: return calcPixelColorLCH(iteration, maxIterations);
    }
}

//--- conversions
array<double, 3> lchToLab(double L, double C, double h) {
    const double pi = 3.141592;
    double lab_a = C * cos(h * pi / 180);
    double lab_b = C * sin(h * pi / 180);
    array<double, 3> lab = {L, lab_a, lab_b};

    return lab;
}

array<double, 3> labToXYZ_D65(double L, double a, double b) {

    double fy = (L + 16) / 116;
    double fx = a / 500 + fy;
    double fz = fy - b / 200;

    double X = 0.0;
    double Y = 0.0;
    double Z = 0.0;

    auto ifs = [](double fxyz) {
        if (pow(fxyz, 3) > 0.008856) {
            return pow(fxyz, 3);
        }
        else {
            return (fxyz - 16.0/116.0) / 7.787;
        }
    };
    X = ifs(fx);
    Y = ifs(fy);
    Z = ifs(fz);
    X *= 95.047;
    Y *= 100.000;
    Z *= 108.883;
    X /= 100;
    Y /= 100;
    Z /= 100;
    array<double, 3> xyz = {X, Y, Z};

    return xyz;
}

array<double, 3> lchToRgb(double L, double C, double h) {

    array<double, 3> lab = lchToLab(L, C, h);
    array<double, 3> xyz = labToXYZ_D65(lab[0], lab[1], lab[2]);
    double r =  3.2406*xyz[0] - 1.5372*xyz[1] - 0.4986*xyz[2] ;
    double g = -0.9689*xyz[0] + 1.8758*xyz[1] + 0.0415*xyz[2] ;
    double b =  0.0557*xyz[0] - 0.2040*xyz[1] + 1.0570*xyz[2] ;

    auto gammaCorrection = [](double color) {
        if (color <= 0.0031308) {
            return 12.92 * color;
        }
        else {
            return 1.055 * std::pow(color, 1.0 / 2.4) - 0.055;
        }
    };

    r = clamp(r, 0.0, 1.0);
    g = clamp(g, 0.0, 1.0);
    b = clamp(b, 0.0, 1.0);
    r = gammaCorrection(r);
    g = gammaCorrection(g);
    b = gammaCorrection(b);
    array<double, 3> rgb = {r*255, g*255, b*255};

    return rgb;
}

void setColorValues(array<uint8_t, 4> &c, uint8_t r, uint8_t g, uint8_t b, uint8_t a) {
    c[0] = r;
    c[1] = g;
    c[2] = b;
    c[3] = a;
}

int getTotalColorModes() {
    return totalColorModes;
}

//--- iterations based coloring
array<uint8_t, 4> calcPixelColorLCH(int iteration, int maxIterations) {
    array<uint8_t, 4> color = {0, 0, 0, 255};
    if (iteration == maxIterations || iteration == maxIterations - 1) return color;

    const double pi = 3.141592;
    double s = (double)iteration/maxIterations;
    double v = 1.0 - powf(cos(pi * s), 2.0);
    double L = 75 - (75 * v);
    double C = 28 + (75 - (75 * v));
    double h = fmod(powf(360 * s, 1.5f), 360);
    array<double, 3> rgb = lchToRgb(L, C, h);

    setColorValues(color, rgb[0], rgb[1], rgb[2], 255);

    return color;
}

array<uint8_t, 4> calcPixelColor_rainbow(int iteration, int maxIterations) {
    array<uint8_t, 4> color = {0, 0, 0, 255};

    if (iteration == maxIterations || iteration == maxIterations - 1) return color;

    int gradientSteps = 32;
    int value = round(((double)iteration / maxIterations) * (gradientSteps - 1));

    switch (value) {
        case 0: setColorValues(color, 255, 0, 0, 255); return color;
        case 1: setColorValues(color, 214, 0, 41, 255); return color;
        case 2: setColorValues(color, 173, 0, 82, 255); return color;
        case 3: setColorValues(color, 132, 0, 123, 255); return color;
        case 4: setColorValues(color, 90, 0, 165, 255); return color;
        case 5: setColorValues(color, 49, 0, 206, 255); return color;
        case 6: setColorValues(color, 8, 0, 247, 255); return color;
        case 7: setColorValues(color, 0, 33, 222, 255); return color;
        case 8: setColorValues(color, 0, 74, 181, 255); return color;
        case 9: setColorValues(color, 0, 115, 140, 255); return color;
        case 10: setColorValues(color, 0, 156, 99, 255); return color;
        case 11: setColorValues(color, 0, 197, 58, 255); return color;
        case 12: setColorValues(color, 0, 239, 16, 255); return color;
        case 13: setColorValues(color, 25, 255, 0, 255); return color;
        case 14: setColorValues(color, 66, 255, 0, 255); return color;
        case 15: setColorValues(color, 107, 255, 0, 255); return color;
        case 16: setColorValues(color, 148, 255, 0, 255); return color;
        case 17: setColorValues(color, 189, 255, 0, 255); return color;
        case 18: setColorValues(color, 230, 255, 0, 255); return color;
        case 19: setColorValues(color, 255, 239, 16, 255); return color;
        case 20: setColorValues(color, 255, 197, 58, 255); return color;
        case 21: setColorValues(color, 255, 156, 99, 255); return color;
        case 22: setColorValues(color, 255, 115, 140, 255); return color;
        case 23: setColorValues(color, 255, 74, 181, 255); return color;
        case 24: setColorValues(color, 255, 33, 222, 255); return color;
        case 25: setColorValues(color, 247, 8, 255, 255); return color;
        case 26: setColorValues(color, 206, 49, 255, 255); return color;
        case 27: setColorValues(color, 165, 90, 255, 255); return color;
        case 28: setColorValues(color, 123, 132, 255, 255); return color;
        case 29: setColorValues(color, 82, 173, 255, 255); return color;
        case 30: setColorValues(color, 41, 214, 255, 255); return color;
        case 31: setColorValues(color, 0, 255, 255, 255); return color;
        default: setColorValues(color, 0, 0, 0, 255); return color;
    }
}

array<uint8_t, 4> calcPixelColor_bw(int iteration, int maxIterations) {
    array<uint8_t, 4> color = {0, 0, 0, 255};

    if (iteration == maxIterations || iteration == maxIterations - 1) return color;

    int gradientSteps = 32;
    int value = round(((double)iteration / maxIterations) * (gradientSteps - 1));

    switch (value) {
        case 0: setColorValues(color, 0, 0, 0, 255); return color;
        case 1: setColorValues(color, 5, 5, 5, 255); return color;
        case 2: setColorValues(color, 11, 11, 11, 255); return color;
        case 3: setColorValues(color, 16, 16, 16, 255); return color;
        case 4: setColorValues(color, 21, 21, 21, 255); return color;
        case 5: setColorValues(color, 27, 27, 27, 255); return color;
        case 6: setColorValues(color, 32, 32, 32, 255); return color;
        case 7: setColorValues(color, 41, 41, 41, 255); return color;
        case 8: setColorValues(color, 51, 51, 51, 255); return color;
        case 9: setColorValues(color, 61, 61, 61, 255); return color;
        case 10: setColorValues(color, 72, 72, 72, 255); return color;
        case 11: setColorValues(color, 82, 82, 82, 255); return color;
        case 12: setColorValues(color, 92, 92, 92, 255); return color;
        case 13: setColorValues(color, 102, 102, 102, 255); return color;
        case 14: setColorValues(color, 112, 112, 112, 255); return color;
        case 15: setColorValues(color, 122, 122, 122, 255); return color;
        case 16: setColorValues(color, 133, 133, 133, 255); return color;
        case 17: setColorValues(color, 143, 143, 143, 255); return color;
        case 18: setColorValues(color, 153, 153, 153, 255); return color;
        case 19: setColorValues(color, 163, 163, 163, 255); return color;
        case 20: setColorValues(color, 173, 173, 173, 255); return color;
        case 21: setColorValues(color, 183, 183, 183, 255); return color;
        case 22: setColorValues(color, 194, 194, 194, 255); return color;
        case 23: setColorValues(color, 204, 204, 204, 255); return color;
        case 24: setColorValues(color, 214, 214, 214, 255); return color;
        case 25: setColorValues(color, 223, 223, 223, 255); return color;
        case 26: setColorValues(color, 228, 228, 228, 255); return color;
        case 27: setColorValues(color, 234, 234, 234, 255); return color;
        case 28: setColorValues(color, 239, 239, 239, 255); return color;
        case 29: setColorValues(color, 244, 244, 244, 255); return color;
        case 30: setColorValues(color, 250, 250, 250, 255); return color;
        case 31: setColorValues(color, 255, 255, 255, 255); return color;
        default: setColorValues(color, 0, 0, 0, 255); return color;
    }
}

array<uint8_t, 4> calcPixelColorInterpolation_bw(int iteration, int maxIterations) {
    array<uint8_t, 4> color = {0, 0, 0, 255};

    if (iteration == maxIterations) return color;

    // Normalize iteration to 0-1 range using global maxIterations
    float t = (float)iteration / (float)maxIterations;

    // Define gradient keypoints
    float keypoints[] = {0.0000, 0.0323, 0.0645, 0.0968, 0.1290, 0.1613, 0.1935, 0.2258, 0.2581, 0.2903, 0.3226, 0.3548, 0.3871, 0.4194, 0.4516, 0.4839, 0.5161, 0.5484, 0.5806, 0.6129, 0.6452, 0.6774, 0.7097, 0.7419, 0.7742, 0.8065, 0.8387, 0.8710, 0.9032, 0.9355, 0.9677, 1.0000};

    int colorR[] = {0, 5, 11, 16, 21, 27, 32, 41, 51, 61, 72, 82, 92, 102, 112, 122, 133, 143, 153, 163, 173, 183, 194, 204, 214, 223, 228, 234, 239, 244, 250, 255};
    int colorG[] = {0, 5, 11, 16, 21, 27, 32, 41, 51, 61, 72, 82, 92, 102, 112, 122, 133, 143, 153, 163, 173, 183, 194, 204, 214, 223, 228, 234, 239, 244, 250, 255};
    int colorB[] = {0, 5, 11, 16, 21, 27, 32, 41, 51, 61, 72, 82, 92, 102, 112, 122, 133, 143, 153, 163, 173, 183, 194, 204, 214, 223, 228, 234, 239, 244, 250, 255};

    // Find the segment
    int segment = 0;
    for (int i = 0; i < 31; i++) {
        if (t >= keypoints[i] && t <= keypoints[i + 1]) {
            segment = i;
            break;
        }
    }

    // Interpolate within segment
    float segmentStart = keypoints[segment];
    float segmentEnd = keypoints[segment + 1];
    float localT = (t - segmentStart) / (segmentEnd - segmentStart);

    // Linear interpolation
    int r = (int)(colorR[segment] + (colorR[segment + 1] - colorR[segment]) * localT);
    int g = (int)(colorG[segment] + (colorG[segment + 1] - colorG[segment]) * localT);
    int b = (int)(colorB[segment] + (colorB[segment + 1] - colorB[segment]) * localT);

    setColorValues(color, r, g, b, 255);
    return color;
}


