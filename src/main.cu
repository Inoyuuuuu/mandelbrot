#include <SDL3/SDL.h>
#include <iostream>
#include <fstream>
#include <array>
#include <filesystem>
#include "ComplexNumber.cpp"

using namespace std;

void setColorValues(array<uint8_t, 4> &c, uint8_t r, uint8_t g, uint8_t b, uint8_t a);
void drawToSDLWindow(SDL_Renderer* renderer, int pixelAmount);
void drawToPPMImage(int pixelAmount);
__global__ void renderMandelbrot(int pixelAmount, int* iterationInfo, int width, int height,
     double baseZoom, double zoomfactor, double xOffset, double yOffset);
ofstream createPPM(int width, int height);
array<uint8_t, 4> calcPixelColor(int iteration);
array<uint8_t, 4> calcPixelColorSmooth(int iteration);

//mandelbrot
const int maxIterations = 1000;
double baseZoom = 100;
double zoomfactor = 1.0;
double xOffset = -0.42;
double yOffset = 0;

//window and program
int width;
int height;
bool isBusy = false;
int* iterationInfo;
size_t pixelAmount;

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
    SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
    SDL_RenderClear(renderer);
    cout << "Setup done! Starting Mandelbrot...\n";

    cudaMallocManaged(&iterationInfo, sizeof(int) * pixelAmount);
    dim3 tmp_blocks((width-1)/threads_per_block.x + 1, (height-1)/threads_per_block.y + 1);
    blocks = tmp_blocks;
    cout << "launching with " << blocks.x << "x" << blocks.y << " blocks and " << threads_per_block.x << "x" << threads_per_block.y << " threads!\n";
    renderMandelbrot<<<blocks, threads_per_block>>>(pixelAmount, iterationInfo, width, height, baseZoom, zoomfactor, xOffset, yOffset);
    cudaDeviceSynchronize();

    cout << "Mandelbrot done! Starting Render\n";

    drawToSDLWindow(renderer, pixelAmount);

    cout << "Finished painting " << pixelAmount << " pixels!\n";
    SDL_RenderPresent(renderer);    

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
                }
            }

            if ((event.type == SDL_EVENT_MOUSE_WHEEL || event.type == SDL_EVENT_KEY_DOWN)&& !isBusy) {
                float x, y;
                Uint32 buttons = SDL_GetMouseState(&x, &y);
                bool isPositiveZoom = (event.type == SDL_EVENT_MOUSE_WHEEL && event.wheel.y > 0) || (event.type == SDL_EVENT_KEY_DOWN && event.key.key == SDLK_PLUS);
                bool isNegativeZoom = (event.type == SDL_EVENT_MOUSE_WHEEL && event.wheel.y < 0) || (event.type == SDL_EVENT_KEY_DOWN && event.key.key == SDLK_MINUS);
                
                x = x - width / 2;    //translate to cartesian position
                y = -(y - height / 2);
                
                if (isPositiveZoom)
                {
                    x /= (baseZoom * zoomfactor);
                    y /= (baseZoom * zoomfactor);
                    zoomfactor *= 2;
                } else if (isNegativeZoom){
                    x /= (baseZoom * zoomfactor);
                    y /= (baseZoom * zoomfactor);
                    x = -x;
                    y = -y;
                    zoomfactor /= 2;
                } else {
                    continue;
                }

                xOffset += x;
                yOffset += y;
               

                cout << "zoom: " << zoomfactor << "\n";

                SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
                SDL_RenderClear(renderer);

                renderMandelbrot<<<blocks, threads_per_block>>>(pixelAmount, iterationInfo, width, height, baseZoom, zoomfactor, xOffset, yOffset);
                cudaDeviceSynchronize();
                drawToSDLWindow(renderer, pixelAmount);
                SDL_RenderPresent(renderer);
            }
        }
    }

    cudaFree(iterationInfo);
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();

    return 0;
}

/*
Calculate Mandelbrot Set

mapping x and y value of img to lie on mandelbrot x scale (typical mandelbrot scale: x: -2.0 to 0.47; y: -1.12 to 1.12), 
by multiplying the relative position of img x and y with the the range we want to look at and adding back on
mandelbrot formular: z_n = (z_n-1)^2 + C
colors are applied based on how fast/slow this sequence grows
*/
__global__ void renderMandelbrot(int pixelAmount, int* iterationInfo, int width, int height, 
    double baseZoom, double zoomfactor, double xOffset, double yOffset) {
    int x = blockDim.x * blockIdx.x + threadIdx.x;        
    int y = blockDim.y * blockIdx.y + threadIdx.y;

    if (x >= width || y >= height) return;

    double cartesianX = x - (width / 2);
    double cartesianY = -(y - (height / 2));

    double cr = cartesianX / (baseZoom * zoomfactor) + xOffset;
    double ci = cartesianY / (baseZoom * zoomfactor) + yOffset;

    double zr = 0.0;
    double zi = 0.0;

    int iteration = 0;

    while ((zr * zr + zi * zi) <= 4 && iteration < maxIterations)
    {
        double temp_zr = zr * zr - zi * zi;
        zi = zr * zi + zi * zr;
        zr = temp_zr;

        zr += cr;
        zi += ci;

        iteration++;            
    }
    iterationInfo[width * y + x] = iteration;
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

array<uint8_t, 4> calcPixelColorSmooth(int iteration) {
    array<uint8_t, 4> color = {0, 0, 0, 255};
    double percentMaxIt = maxIterations / iteration;
    int val = 255 * percentMaxIt;
    setColorValues(color, val, val, val, 255);

    return color;
}

array<uint8_t, 4> calcPixelColor(int iteration) {
    array<uint8_t, 4> color = {0, 0, 0, 255};

    int gradientSteps = 50;
    int mappedIteration = (int)(((double)iteration / maxIterations) * (gradientSteps - 1));
    
    switch (mappedIteration)
    {
    case 0:
        setColorValues(color, 11, 11, 11, 255);
        return color;
    case 1:
        setColorValues(color, 20, 15, 23, 255);
        return color;
    case 2:
        setColorValues(color, 29, 20, 35, 255);
        return color;
    case 3:
        setColorValues(color, 37, 24, 48, 255);
        return color;
    case 4:
        setColorValues(color, 46, 28, 60, 255);
        return color;
    case 5:
        setColorValues(color, 55, 32, 72, 255);
        return color;
    case 6:
        setColorValues(color, 64, 37, 84, 255);
        return color;
    case 7:
        setColorValues(color, 72, 41, 97, 255);
        return color;
    case 8:
        setColorValues(color, 81, 45, 109, 255);
        return color;
    case 9:
        setColorValues(color, 90, 50, 121, 255);
        return color;
    case 10:
        setColorValues(color, 99, 54, 132, 255);
        return color;
    case 11:
        setColorValues(color, 109, 58, 140, 255);
        return color;
    case 12:
        setColorValues(color, 118, 63, 147, 255);
        return color;
    case 13:
        setColorValues(color, 128, 67, 155, 255);
        return color;
    case 14:
        setColorValues(color, 138, 72, 162, 255);
        return color;
    case 15:
        setColorValues(color, 147, 76, 169, 255);
        return color;
    case 16:
        setColorValues(color, 157, 81, 177, 255);
        return color;
    case 17:
        setColorValues(color, 167, 85, 184, 255);
        return color;
    case 18:
        setColorValues(color, 176, 90, 191, 255);
        return color;
    case 19:
        setColorValues(color, 186, 94, 199, 255);
        return color;
    case 20:
        setColorValues(color, 194, 97, 198, 255);
        return color;
    case 21:
        setColorValues(color, 200, 97, 186, 255);
        return color;
    case 22:
        setColorValues(color, 205, 97, 173, 255);
        return color;
    case 23:
        setColorValues(color, 211, 97, 161, 255);
        return color;
    case 24:
        setColorValues(color, 216, 97, 148, 255);
        return color;
    case 25:
        setColorValues(color, 222, 97, 136, 255);
        return color;
    case 26:
        setColorValues(color, 227, 97, 123, 255);
        return color;
    case 27:
        setColorValues(color, 233, 97, 111, 255);
        return color;
    case 28:
        setColorValues(color, 238, 97, 98, 255);
        return color;
    case 29:
        setColorValues(color, 244, 97, 86, 255);
        return color;
    case 30:
        setColorValues(color, 245, 93, 78, 255);
        return color;
    case 31:
        setColorValues(color, 242, 86, 74, 255);
        return color;
    case 32:
        setColorValues(color, 240, 78, 69, 255);
        return color;
    case 33:
        setColorValues(color, 238, 71, 64, 255);
        return color;
    case 34:
        setColorValues(color, 236, 64, 60, 255);
        return color;
    case 35:
        setColorValues(color, 233, 57, 55, 255);
        return color;
    case 36:
        setColorValues(color, 231, 50, 51, 255);
        return color;
    case 37:
        setColorValues(color, 229, 43, 46, 255);
        return color;
    case 38:
        setColorValues(color, 227, 36, 42, 255);
        return color;
    case 39:
        setColorValues(color, 224, 28, 37, 255);
        return color;
    case 40:
        setColorValues(color, 206, 25, 33, 255);
        return color;
    case 41:
        setColorValues(color, 183, 22, 29, 255);
        return color;
    case 42:
        setColorValues(color, 160, 19, 26, 255);
        return color;
    case 43:
        setColorValues(color, 137, 17, 22, 255);
        return color;
    case 44:
        setColorValues(color, 114, 14, 18, 255);
        return color;
    case 45:
        setColorValues(color, 91, 11, 15, 255);
        return color;
    case 46:
        setColorValues(color, 69, 8, 11, 255);
        return color;
    case 47:
        setColorValues(color, 46, 6, 7, 255);
        return color;
    case 48:
        setColorValues(color, 23, 3, 4, 255);
        return color;
    case 49:
        setColorValues(color, 0, 0, 0, 255);
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