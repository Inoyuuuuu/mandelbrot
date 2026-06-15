#include <SDL3/SDL.h>
#include <iostream>
#include <fstream>
#include <algorithm>
#include <array>
#include <filesystem>
#include <string>
#include "ColorManager.cpp"

using namespace std;

void drawToSDLWindow(SDL_Renderer* renderer, int pixelAmount);
void drawToPPMImage(int pixelAmount);
__global__ void renderMandelbrotGPU_deepZoom(double* refOrbit, int* iterationInfo, int windowWidth, int windowHeight, int maxRefOrbitIterations, int zoomBase, double zoomFactor);
void calculateOrbit(double* refOrbit);
void cudaRenderImage(SDL_Renderer* renderer);
std::ofstream createPPM(int width, int height);

//mandelbrot
int maxIterations = 1000;
int zoomBase = 100;
double zoomFactor = 1.0;
long double xOffset = -0.42; //common mandelbrot renders start at range -2.00 to 0.42
long double yOffset = 0;

//arbitrary precision
double orbit_r;
double orbit_i;
double* refOrbit;
int maxRefOrbitIterations = 0;

//window and program
int width;
int height;
size_t pixelAmount;
bool isBusy = false;
int* iterationInfo;
bool isDebugMode = true;
int colorMode = 3;

//cuda
dim3 threads_per_block(32, 32);
dim3 blocks(1, 1);

ColorManager* cm = new ColorManager();

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
    cudaMallocManaged(&refOrbit, sizeof(double) * 2 * (maxIterations + 1));
    cudaMallocManaged(&iterationInfo, sizeof(int) * pixelAmount);

    dim3 tmp_blocks((width-1)/threads_per_block.x + 1, (height-1)/threads_per_block.y + 1);
    blocks = tmp_blocks;

    cout << "Launching mandelbrot calculations with " << blocks.x << "x" << blocks.y << " blocks and " << threads_per_block.x << "x" << threads_per_block.y << " threads!\n";
    
    cudaRenderImage(renderer);

    cout << "Mandelbrot calculations & render done! Finished with " << pixelAmount << " pixels!\n";

    bool running = true;
    bool shiftPressed = false;

    bool isMouseEvent = false;
    bool isKeyDownEvent = false;
    bool isKeyUpEvent = false;

    SDL_Event event;
    while (running) {

        while (SDL_PollEvent(&event)) {
            isMouseEvent = event.type == SDL_EVENT_MOUSE_WHEEL;
            isKeyDownEvent = event.type == SDL_EVENT_KEY_DOWN;
            isKeyUpEvent = event.type == SDL_EVENT_KEY_UP;
            
            if (event.type == SDL_EVENT_QUIT) {
                running = false;
            }
            
            if (isKeyDownEvent) {
                if (event.key.key == SDLK_ESCAPE) {
                    running = false;
                } else if(event.key.key == SDLK_P && !isBusy) {
                    drawToPPMImage(pixelAmount);
                } else if (event.key.key == SDLK_F && !isBusy) {
                    zoomFactor = -zoomFactor;
                    cudaRenderImage(renderer);

                } else if (event.key.key == SDLK_R && !isBusy) {
                    xOffset = -0.42;
                    yOffset = 0.0;
                    zoomFactor = 1.0;
                    cudaRenderImage(renderer);
                } else if (event.key.key == SDLK_LSHIFT) {
                    shiftPressed = true;
                }
            }

            //vertical/horizontal movement via arrow keys
            if (isKeyDownEvent && !isBusy) {
                long double x = 0;
                long double y = 0;

                switch(event.key.key) {
                    case SDLK_LEFT: x += -50; break;
                    case SDLK_RIGHT: x += 50; break;
                    case SDLK_UP: y += -50; break; //winow y is top down
                    case SDLK_DOWN: y += 50; break;
                    default: continue;
                }

                x /= (zoomBase * zoomFactor);
                y /= (zoomBase * zoomFactor);
                xOffset += x;
                yOffset += y;

                cudaRenderImage(renderer);
                cout << "zoom: " << zoomFactor << " | x: " << xOffset << " | y: " << yOffset << "\n";
            }

            if (isKeyUpEvent) {
                if (event.key.key == SDLK_LSHIFT) {
                    shiftPressed = false;
                }
            }

            //zoom via mouse/plus and minus
            if ((isMouseEvent || isKeyDownEvent) && !isBusy) {
                float x, y;
                Uint32 buttons = SDL_GetMouseState(&x, &y);
                bool isPositiveZoom = (isMouseEvent && event.wheel.y > 0) || (isKeyDownEvent && event.key.key == SDLK_PLUS);
                bool isNegativeZoom = (isMouseEvent && event.wheel.y < 0) || (isKeyDownEvent && event.key.key == SDLK_MINUS);
                
                long double mandel_x, mandel_y;
                mandel_x = (x - width / 2);    //translate mouse x y to cartesian position in mandel coordinate system
                mandel_y = (y - height / 2);
                mandel_x /= (zoomBase * zoomFactor);
                mandel_y /= (zoomBase * zoomFactor);

                if (isPositiveZoom)
                {
                    zoomFactor *= 2;
                } else if (isNegativeZoom){
                    mandel_x = -mandel_x;
                    mandel_y = -mandel_y;
                    zoomFactor /= 2;
                } else {
                    continue;
                }

                if (!shiftPressed) {
                    xOffset += mandel_x;
                    yOffset += mandel_y;
                }

                cudaRenderImage(renderer);
                cout << "zoom: " << zoomFactor << " | x: " << xOffset << " | y: " << yOffset << "\n";
            }
        }
    }

    cudaFree(refOrbit);
    cudaFree(iterationInfo);
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();

    return 0;
}

void cudaRenderImage(SDL_Renderer* renderer) {
    SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
    SDL_RenderClear(renderer);

    calculateOrbit(refOrbit);
    
    renderMandelbrotGPU_deepZoom<<<blocks, threads_per_block>>>(refOrbit, iterationInfo, width, height, maxRefOrbitIterations, zoomBase, zoomFactor);
    cudaDeviceSynchronize();
    
    drawToSDLWindow(renderer, pixelAmount);
    SDL_RenderPresent(renderer);
}

__global__ void renderMandelbrotGPU_deepZoom(double* refOrbit, int* iterationInfo, int windowWidth, int windowHeight, int maxRefOrbitIterations, int zoomBase, double zoomFactor) {

    int x = blockDim.x * blockIdx.x + threadIdx.x;        
    int y = blockDim.y * blockIdx.y + threadIdx.y;

    if (x >= windowWidth || y >= windowHeight) return;

    double d_cr = (x - windowWidth * 0.5) / (zoomBase * zoomFactor);
    double d_ci = (y - windowHeight * 0.5) / (zoomBase * zoomFactor);

    double d_zr = 0;
    double d_zi = 0;

    int iteration = 0;
    int ref_iteration = 0;

    while (iteration < maxRefOrbitIterations) {
        
        double ref_zr = refOrbit[ref_iteration * 2];
        double ref_zi = refOrbit[ref_iteration * 2 + 1];

        //dz = 2 * dz * x_orbit[ref_iteration] + dz * dz + dc;
        double temp_zr = 2*(ref_zr*d_zr - ref_zi*d_zi) + (d_zr*d_zr - d_zi*d_zi) + d_cr;
        d_zi = 2*(ref_zr*d_zi + ref_zi*d_zr) + (2*d_zr*d_zi) + d_ci;
        d_zr = temp_zr;
        ref_iteration++;

        double zr = refOrbit[ref_iteration*2] + d_zr;
        double zi = refOrbit[ref_iteration*2+1] + d_zi;

        double z_squared = zr*zr + zi*zi;
        double dz_squared = d_zr*d_zr + d_zi*d_zi;

        if (z_squared > 4.0) break; // |z| > 2 == z² > 2²

        if (z_squared < dz_squared || ref_iteration == maxRefOrbitIterations) {
            
            d_zr = zr;
            d_zi = zi;
            ref_iteration = 0;
        }
        iteration++;
    }

    iterationInfo[windowWidth * y + x] = iteration;

}

void calculateOrbit(double* refOrbit) {

    for (size_t i = 0; i < maxIterations; i++)
    {
        refOrbit[i * 2] = 0;
        refOrbit[i * 2 + 1] = 0;
    }

    long double cr = xOffset;
    long double ci = yOffset;

    long double zr = 0.0;
    long double zi = 0.0;

    int iteration = 0;

    while (iteration < maxIterations)
    {
        refOrbit[iteration * 2] = (double)zr;
        refOrbit[iteration * 2 + 1] = (double)zi;

        // z(n+1) = z(n)^2 + c
        long double temp_zr = zr * zr - zi * zi + cr;
        zi = 2 * zr * zi + ci;
        zr = temp_zr;

        iteration++;
    }
    maxRefOrbitIterations = iteration;
}

void drawToSDLWindow(SDL_Renderer* renderer, int pixelAmount) {
    isBusy = true;
    array<uint8_t, 4> color;

    for (size_t i = 0; i < pixelAmount; i++)
    {
        int x = i % width;        
        int y = i / width;

        if (isDebugMode && std::abs(x - width/2) < 2 && std::abs(y - height/2) < 2) {
            SDL_SetRenderDrawColor(renderer, 255, 0, 0, 255);

        } else {
            color = (*cm).colorMandelbrot(colorMode, iterationInfo[i], maxIterations);
            SDL_SetRenderDrawColor(renderer, color[0], color[1], color[2], color[3]);
        }

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
        color = (*cm).colorMandelbrot(colorMode, iterationInfo[i], maxIterations);
        image << (int)color[0] << " " << (int)color[1] << " " << (int)color[2] << "\n";
    }
    isBusy = false;
}

std::ofstream createPPM(int width, int height) {
    std::filesystem::create_directories("renders");

    std::string outPath = "renders/mandelPic.ppm";
    int counter = 2;

    while (std::filesystem::exists(outPath)) {
        outPath = "renders/mandelPic" + std::to_string(counter++) + ".ppm";
    }

    std::ofstream image(outPath);
    if (!image.is_open()) {
        throw std::runtime_error("Failed to open file: " + outPath);
    }

    image << "P3\n" << width << " " << height << "\n255\n";
    return image;
}