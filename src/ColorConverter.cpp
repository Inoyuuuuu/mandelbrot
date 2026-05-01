#include <stdio.h>
#include <array>
#include <algorithm>
#include <math.h>

using namespace std;

class ColorConverter {
    public:
        static array<double, 3> lchToRgb(double L, double C, double h) {

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

        static array<double, 3> lchToLab(double L, double C, double h) {
            double lab_a = C * cos(h * M_PI / 180);
            double lab_b = C * sin(h * M_PI / 180);
            array<double, 3> lab = {L, lab_a, lab_b};

            return lab;
        }

        static array<double, 3> labToXYZ_D65(double L, double a, double b) {

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
};