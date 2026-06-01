#include <SDL3/SDL.h>
#include <iostream>
#include <fstream>
#include <algorithm>
#include <array>
#include <filesystem>
#include <string>
#include "ColorConverter.cpp"

using namespace std;

void setColorValues(array<uint8_t, 4> &c, uint8_t r, uint8_t g, uint8_t b, uint8_t a);
void drawToSDLWindow(SDL_Renderer* renderer, int pixelAmount);
void drawToPPMImage(int pixelAmount);
void renderMandelbrotCPU_deepZoom(int* iterationInfo);
void calculateOrbit(double* x_n);
void cudaRenderImage(SDL_Renderer* renderer);
ofstream createPPM(int width, int height);
array<uint8_t, 4> calcPixelColor(int iteration);
array<uint8_t, 4> calcPixelColorLCH(int iteration);

//mandelbrot
__managed__ int maxIterations = 1000;
int baseZoom = 100;
double zoomfactor = 1.0;
long double xOffset = -0.42; //common mandelbrot renders start at range -2.00 to 0.42
long double yOffset = 0;

//arbitrary precision
double orbit_r;
double orbit_i;
double* x_orbit;
__managed__ int x_orbitIterations = 0;

//window and program
__managed__ int width;
__managed__ int height;
__managed__ size_t pixelAmount;
bool isBusy = false;
int* iterationInfo;

//cuda
dim3 threads_per_block(32, 32);
dim3 blocks(1, 1);

int main(int argc, char *argv[]) {
    try
    {
        width = stoi(argv[1]);
        height = stoi(argv[1]);
        if (argc >= 3) height = stoi(argv[2]);
    }
    catch(const exception& e)
    {
        cerr << e.what() << '\n';
        cout << "Using default values (300x300).\n";
        width = 300;
        height = 300;
    }

    //init
    if (!SDL_Init(SDL_INIT_VIDEO)) return -1;
    SDL_Window* window = SDL_CreateWindow("SDL3 Window", width, height, 0);
    if (!window) return -1;
    SDL_Renderer* renderer = SDL_CreateRenderer(window, nullptr);
    if (!renderer) return -1;
    pixelAmount = width * height;

    //cuda init
    cudaMallocManaged(&x_orbit, sizeof(long double) * maxIterations);

    cudaMallocManaged(&iterationInfo, sizeof(int) * pixelAmount);
    dim3 tmp_blocks((width-1)/threads_per_block.x + 1, (height-1)/threads_per_block.y + 1);
    blocks = tmp_blocks;

    cout << "Launching mandelbrot calculations with " << blocks.x << "x" << blocks.y << " blocks and " << threads_per_block.x << "x" << threads_per_block.y << " threads!\n";
    
    cudaRenderImage(renderer);

    cout << "Mandelbrot calculations & render done! Finished with " << pixelAmount << " pixels!\n";

    bool running = true;
    SDL_Event event;
    while (running) {

        while (SDL_PollEvent(&event)) {
            if (event.type == SDL_EVENT_QUIT) {
                running = false;
            }
            
            if (event.type == SDL_EVENT_KEY_DOWN) {
                if (event.key.key == SDLK_ESCAPE) {
                    running = false;
                } else if(event.key.key == SDLK_P && !isBusy) {
                    drawToPPMImage(pixelAmount);
                } else if (event.key.key == SDLK_F && !isBusy) {
                    zoomfactor = -zoomfactor;
                    cudaRenderImage(renderer);

                } else if (event.key.key == SDLK_R && !isBusy) {
                    xOffset = -0.42;
                    yOffset = 0.0;
                    zoomfactor = 1.0;
                    cudaRenderImage(renderer);
                }
            }

            if ((event.type == SDL_EVENT_MOUSE_WHEEL || event.type == SDL_EVENT_KEY_DOWN)&& !isBusy) {
                float x, y;
                double mandel_x, mandel_y;

                Uint32 buttons = SDL_GetMouseState(&x, &y);
                bool isPositiveZoom = (event.type == SDL_EVENT_MOUSE_WHEEL && event.wheel.y > 0) || (event.type == SDL_EVENT_KEY_DOWN && event.key.key == SDLK_PLUS);
                bool isNegativeZoom = (event.type == SDL_EVENT_MOUSE_WHEEL && event.wheel.y < 0) || (event.type == SDL_EVENT_KEY_DOWN && event.key.key == SDLK_MINUS);
                
                mandel_x = (x - width / 2);    //translate to cartesian position
                mandel_y = (y - height / 2);
                
                mandel_x /= (baseZoom * zoomfactor);
                mandel_y /= (baseZoom * zoomfactor);

                if (isPositiveZoom)
                {
                    zoomfactor *= 2;
                } else if (isNegativeZoom){
                    mandel_x = -mandel_x;
                    mandel_y = -mandel_y;
                    zoomfactor /= 2;
                } else {
                    continue;
                }

                xOffset += mandel_x;
                yOffset += mandel_y;
                
                cudaRenderImage(renderer);
                
                cout << "zoom: " << zoomfactor << "\n";
            }
        }
    }

    cudaFree(iterationInfo);
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();

    return 0;
}

void cudaRenderImage(SDL_Renderer* renderer) {
    SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
    SDL_RenderClear(renderer);

    calculateOrbit(x_orbit);
    
    //renderMandelbrot<<<blocks, threads_per_block>>>(iterationInfo);
    //cudaDeviceSynchronize();
    renderMandelbrotCPU_deepZoom(iterationInfo);
    
    drawToSDLWindow(renderer, pixelAmount);
    SDL_RenderPresent(renderer);
}

void renderMandelbrotCPU_deepZoom(int* iterationInfo) {

    for (size_t k = 0; k < pixelAmount; k++)
    {
        long double x = k % width;
        long double y = k / width;

        long double deltaCr = (x - width * 0.5) / (baseZoom * zoomfactor);
        long double deltaCi = (y - height * 0.5) / (baseZoom * zoomfactor);

        long double zr = 0;
        long double zi = 0;

        int i = 0;
        while (i < x_orbitIterations)
        {
            // δz(n+1) = 2·z₀(n)·δz(n) + δz(n)² + δc
            long double temp_zr = 2*(x_orbit[i*2]*zr - x_orbit[i*2+1]*zi)
                                + (zr*zr - zi*zi)
                                + deltaCr;
            zi = 2*(x_orbit[i*2]*zi + x_orbit[i*2+1]*zr)
               + (2*zr*zi)
               + deltaCi;
            zr = temp_zr;

            // Escape test on full point Z(n) + δz(n)
            long double full_zr = x_orbit[i*2] + zr;
            long double full_zi = x_orbit[i*2+1] + zi;
            if (full_zr*full_zr + full_zi*full_zi > 4.0) break;

            i++;
        }

        iterationInfo[k] = i;
    }
}


void calculateOrbit(double* x_n) {

    for (size_t i = 0; i < maxIterations; i++)
    {
        x_n[i * 2] = 0;
        x_n[i * 2 + 1] = 0;
    }

    long double cr = xOffset;
    long double ci = yOffset;

    long double zr = 0.0;
    long double zi = 0.0;

    int iteration = 0;

    while (iteration < maxIterations)
    {
        x_n[iteration * 2]     = zr;
        x_n[iteration * 2 + 1] = zi;

        // z(n+1) = z(n)^2 + c
        long double temp_zr = zr * zr - zi * zi + cr;
        zi = 2 * zr * zi + ci;
        zr = temp_zr;

        iteration++;

        if (zr*zr + zi*zi > 4.0) break;  // stop if reference escapes
    }
    x_orbitIterations = iteration;
}

void drawToSDLWindow(SDL_Renderer* renderer, int pixelAmount) {
    isBusy = true;
    array<uint8_t, 4> color;

    for (size_t i = 0; i < pixelAmount; i++)
    {
        int x = i % width;        
        int y = i / width;
        
        color = calcPixelColor(iterationInfo[i]);
        SDL_SetRenderDrawColor(renderer, color[0], color[1], color[2], color[3]);
        SDL_RenderPoint(renderer, x, y);
    }
    isBusy = false;
}

void drawToPPMImage(int pixelAmount) {
    isBusy = true;
    ofstream image = createPPM(width, height);
    array<uint8_t, 4> color;
    
    for (size_t i = 0; i < pixelAmount; i++)
    {
        color = calcPixelColor(iterationInfo[i]);
        image << (int)color[0] << " " << (int)color[1] << " " << (int)color[2] << "\n";
    }
    isBusy = false;

}

ofstream createPPM(int width, int height) {
    string path = "renders/mandelPic.ppm";
    int counter = 2;
    while (filesystem::exists(path)) {
        path = "renders/mandelPic" + to_string(counter) + ".ppm";
        counter++;
    }
    ofstream image(path);
    image << "P3\n" << width << " " << height << "\n" << "255\n";
    return image;
}

array<uint8_t, 4> calcPixelColorLCH(int iteration) {
    array<uint8_t, 4> color = {0, 0, 0, 255};
    if (iteration == maxIterations || iteration == maxIterations - 1) return color;

    const double pi = 3.141592;
    double s = (double)iteration/maxIterations;
    double v = 1.0 - powf(cos(pi * s), 2.0);
    double L = 75 - (75 * v);
    double C = 28 + (75 - (75 * v));
    double h = fmod(powf(360 * s, 1.5f), 360);
    array<double, 3> rgb = ColorConverter::lchToRgb(L, C, h);

    setColorValues(color, rgb[0], rgb[1], rgb[2], 255);

    return color;
}

array<uint8_t, 4> calcPixelColor(int iteration) {
    array<uint8_t, 4> color = {0, 0, 0, 255};

    if (iteration == maxIterations || iteration == maxIterations - 1) return color;

    int gradientSteps = 40;
    int mappedIteration = round(((double)iteration / maxIterations) * (gradientSteps - 1));
    
        switch (mappedIteration)
    {
    case 0:
        setColorValues(color, 255, 0, 110, 255);
        return color;
    case 1:
        setColorValues(color, 254, 11, 97, 255);
        return color;
    case 2:
        setColorValues(color, 254, 22, 84, 255);
        return color;
    case 3:
        setColorValues(color, 253, 33, 70, 255);
        return color;
    case 4:
        setColorValues(color, 253, 44, 57, 255);
        return color;
    case 5:
        setColorValues(color, 252, 55, 44, 255);
        return color;
    case 6:
        setColorValues(color, 252, 66, 31, 255);
        return color;
    case 7:
        setColorValues(color, 251, 77, 18, 255);
        return color;
    case 8:
        setColorValues(color, 251, 89, 7, 255);
        return color;
    case 9:
        setColorValues(color, 252, 102, 8, 255);
        return color;
    case 10:
        setColorValues(color, 252, 115, 8, 255);
        return color;
    case 11:
        setColorValues(color, 253, 129, 9, 255);
        return color;
    case 12:
        setColorValues(color, 253, 142, 9, 255);
        return color;
    case 13:
        setColorValues(color, 254, 155, 10, 255);
        return color;
    case 14:
        setColorValues(color, 254, 169, 10, 255);
        return color;
    case 15:
        setColorValues(color, 255, 182, 11, 255);
        return color;
    case 16:
        setColorValues(color, 249, 183, 23, 255);
        return color;
    case 17:
        setColorValues(color, 233, 166, 51, 255);
        return color;
    case 18:
        setColorValues(color, 217, 149, 80, 255);
        return color;
    case 19:
        setColorValues(color, 201, 132, 109, 255);
        return color;
    case 20:
        setColorValues(color, 185, 114, 138, 255);
        return color;
    case 21:
        setColorValues(color, 169, 97, 167, 255);
        return color;
    case 22:
        setColorValues(color, 153, 80, 196, 255);
        return color;
    case 23:
        setColorValues(color, 137, 63, 224, 255);
        return color;
    case 24:
        setColorValues(color, 125, 62, 237, 255);
        return color;
    case 25:
        setColorValues(color, 116, 72, 240, 255);
        return color;
    case 26:
        setColorValues(color, 107, 82, 242, 255);
        return color;
    case 27:
        setColorValues(color, 97, 92, 245, 255);
        return color;
    case 28:
        setColorValues(color, 88, 102, 247, 255);
        return color;
    case 29:
        setColorValues(color, 79, 112, 250, 255);
        return color;
    case 30:
        setColorValues(color, 69, 122, 252, 255);
        return color;
    case 31:
        setColorValues(color, 60, 132, 255, 255);
        return color;
    case 32:
        setColorValues(color, 53, 146, 246, 255);
        return color;
    case 33:
        setColorValues(color, 46, 162, 234, 255);
        return color;
    case 34:
        setColorValues(color, 39, 177, 223, 255);
        return color;
    case 35:
        setColorValues(color, 33, 193, 211, 255);
        return color;
    case 36:
        setColorValues(color, 26, 208, 200, 255);
        return color;
    case 37:
        setColorValues(color, 19, 224, 188, 255);
        return color;
    case 38:
        setColorValues(color, 13, 239, 177, 255);
        return color;
    case 39:
        setColorValues(color, 6, 255, 165, 255);
        return color;
    default:
        setColorValues(color, 0, 0, 0, 255);
        return color;
    }
}

void setColorValues(array<uint8_t, 4> &c, uint8_t r, uint8_t g, uint8_t b, uint8_t a) {
    c[0] = r;
    c[1] = g;
    c[2] = b;
    c[3] = a;
}