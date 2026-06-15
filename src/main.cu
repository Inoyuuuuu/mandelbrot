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
void drawToPPMImage(int ppmWidth, int ppmHeight);
void initCudaGridSize();
__global__ void renderMandelbrotGPU(int* iterationInfo, int windowWidth, int windowHeight, 
    int maxIterations, int zoomBase, double zoomFactor, double xOffset, double yOffset);
void cudaRenderImage(SDL_Renderer* renderer);

//mandelbrot
int maxIterations = 1000;
int zoomBase = 100;
double zoomFactor = 1.0;
double xOffset = -0.42; //common mandelbrot renders start at range -2.00 to 0.42
double yOffset = 0;

//window and program
int width;
int height;
size_t pixelAmount;
bool isBusy = false;
int* iterationInfo;

//programm settings
bool isDebugMode = false; //TODO: deactivate
int colorMode = 0;
bool isHighResExportActive = false;
float resolutionMultiplier = 1.0;

//cuda
dim3 block(16, 16);
dim3 grid(1, 1);

ColorManager* cm = new ColorManager();

int main(int argc, char *argv[]) {
    try
    {
        width = stoi(argv[1]);
        height = stoi(argv[2]);

        if (argc > 3) {
            for (size_t i = 3; i < argc; i++)
            {
                string arg = string(argv[i]);

                if (arg.starts_with("--cm:")) {
                    colorMode = stoi(arg.erase(0,5));
                } else if (arg.starts_with("--db"))
                {
                    isDebugMode = true;
                } else if (arg.starts_with("--eRes:"))
                {
                    resolutionMultiplier = stof(arg.erase(0,7));
                    isHighResExportActive = true;
                }
            }
        }
    }
    catch(const exception& e)
    {
        cerr << e.what() << '\n';
        cout << "Using default values (300x300).\n";
        width = 300;
        height = 300;
    }

    cout << width << " | " << height;

    //init
    if (!SDL_Init(SDL_INIT_VIDEO)) return -1;
    SDL_Window* window = SDL_CreateWindow("SDL3 Window", width, height, 0);
    if (!window) return -1;
    SDL_Renderer* renderer = SDL_CreateRenderer(window, nullptr);
    if (!renderer) return -1;
    pixelAmount = width * height;

    //cuda init
    cudaMallocManaged(&iterationInfo, sizeof(int) * pixelAmount);
    initCudaGridSize();

    cout << "Launching mandelbrot calculations with " << grid.x << "x" << grid.y << " blocks and " << block.x << "x" << block.y << " threads!\n";
    
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

                } else if(event.key.key == SDLK_P && !isBusy) { //"screenshot"
                    cout << "rendering screenshot [res: " << resolutionMultiplier << "]...\n";
                    drawToPPMImage(width, height);
                    cout << "done!\n";

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
                double x = 0;
                double y = 0;

                switch(event.key.key) {
                    case SDLK_LEFT: x += -100; break;
                    case SDLK_RIGHT: x += 100; break;
                    case SDLK_UP: y += -100; break; //winow y is top down
                    case SDLK_DOWN: y += 100; break;
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
                
                double mandel_x, mandel_y;
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

    cudaFree(iterationInfo);
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();

    return 0;
}

void initCudaGridSize() {
    grid = dim3((width  + block.x - 1) / block.x, (height + block.y - 1) / block.y);
}

void cudaRenderImage(SDL_Renderer* renderer) {
    SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
    SDL_RenderClear(renderer);

    if (isHighResExportActive) initCudaGridSize();

    renderMandelbrotGPU<<<grid, block>>>(iterationInfo, width, height, maxIterations, zoomBase, zoomFactor, xOffset, yOffset);
    cudaDeviceSynchronize();
    
    drawToSDLWindow(renderer, pixelAmount);
    SDL_RenderPresent(renderer);
}

__global__ void renderMandelbrotGPU(int* iterationInfo, int windowWidth, int windowHeight, 
    int maxIterations, int zoomBase, double zoomFactor, double xOffset, double yOffset) {

    int x = blockDim.x * blockIdx.x + threadIdx.x;        
    int y = blockDim.y * blockIdx.y + threadIdx.y;

    if (x >= windowWidth || y >= windowHeight) return;

    double cartesianX = (x - (windowWidth / 2));
    double cartesianY = (y - (windowHeight / 2));

    double cr = cartesianX / (zoomBase * zoomFactor) + xOffset;
    double ci = cartesianY / (zoomBase * zoomFactor) + yOffset;

    double zr = 0.0;
    double zi = 0.0;

    int iteration = 0;

    while ((zr * zr + zi * zi) < 4 && iteration < maxIterations)
    {
        //z = z^2 + c
        double temp_zr = zr * zr - zi * zi;
        zi = 2 * zr * zi;
        zr = temp_zr;
        zr += cr;
        zi += ci;

        iteration++;            
    }
    iterationInfo[windowWidth * y + x] = iteration;
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

void drawToPPMImage(int width, int height) {
    int ppmWidth = width;
    int ppmHeight = height;
    isBusy = true;

    if (isHighResExportActive) {
        ppmWidth = (int) width * resolutionMultiplier;
        ppmHeight = (int) height * resolutionMultiplier;
    }

    ofstream image = createPPM(ppmWidth, ppmHeight);
    array<uint8_t, 4> color;
    int ppmPixelAmount = ppmWidth * ppmHeight;

    if (isHighResExportActive) {
        int* ppmIterationInfo;
        cudaMallocManaged(&ppmIterationInfo, sizeof(int) * ppmPixelAmount);

        grid = dim3((ppmWidth  + block.x - 1) / block.x, (ppmHeight + block.y - 1) / block.y);
        double ppmZoomFactor = zoomFactor * resolutionMultiplier;
        renderMandelbrotGPU<<<grid, block>>>(ppmIterationInfo, ppmWidth, ppmHeight, maxIterations, zoomBase, ppmZoomFactor, xOffset, yOffset);
        cudaDeviceSynchronize();

        for (size_t i = 0; i < ppmPixelAmount; i++)
        {
            color = (*cm).colorMandelbrot(colorMode, ppmIterationInfo[i], maxIterations);
            image << (int)color[0] << " " << (int)color[1] << " " << (int)color[2] << "\n";
        }

        cudaFree(ppmIterationInfo);

    } else {
        for (size_t i = 0; i < ppmPixelAmount; i++)
        {
            color = (*cm).colorMandelbrot(colorMode, iterationInfo[i], maxIterations);
            image << (int)color[0] << " " << (int)color[1] << " " << (int)color[2] << "\n";
        }
    }

    isBusy = false;
}