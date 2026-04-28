#include <SDL3/SDL.h>
#include <iostream>
#include <fstream>
#include <array>
#include <filesystem>
#include "ComplexNumber.cpp"

using namespace std;

void setColorValues(array<uint8_t, 4> &c, uint8_t r, uint8_t g, uint8_t b, uint8_t a);
void drawToSDLWindow(SDL_Renderer* renderer, int pixelAmount, int* colorInfo);
void drawToPPMImage(int pixelAmount, int* colorInfo);
void renderMandelbrot(int pixelAmount, int* colorInfo);
ofstream createPPM(int width, int height);
array<uint8_t, 4> calcPixelColor(int iteration);

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
int* colorInfo;
size_t pixelAmount;

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

    colorInfo = new int[pixelAmount * 4];
    renderMandelbrot(pixelAmount, colorInfo);
    cout << "Mandelbrot done! Starting Render/PPM\n";

    drawToSDLWindow(renderer, pixelAmount, colorInfo);

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
                    drawToPPMImage(pixelAmount, colorInfo);
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

                renderMandelbrot(pixelAmount, colorInfo);
                drawToSDLWindow(renderer, pixelAmount, colorInfo);
                SDL_RenderPresent(renderer);
            }
        }
    }

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
void renderMandelbrot(int pixelAmount, int* colorInfo) {
    isBusy = true;
    for (size_t i = 0; i < pixelAmount; i++)
    {
        int x = i % width;        
        int y = i / width;

        double cartesianX = x - (width / 2);
        double cartesianY = -(y - (height / 2));

        double mX = cartesianX / (baseZoom * zoomfactor) + xOffset;
        double mY = cartesianY / (baseZoom * zoomfactor) + yOffset;

        ComplexNumber c = ComplexNumber(mX, mY);
        ComplexNumber z = ComplexNumber(0, 0);

        int iteration = 0;
        while (z.absoluteValueSquared() <= 4 && iteration < maxIterations)
        {
            z = (z * z) + c;
            iteration++;            
        }
        
        array<uint8_t, 4U> color = calcPixelColor(iteration);
        for (size_t k = 0; k < 4; k++)
        {
            colorInfo[i*4 + k] = color[k];
        }
    }
    isBusy = false;
}

void drawToSDLWindow(SDL_Renderer* renderer, int pixelAmount, int* colorInfo) {
    isBusy = true;
    for (size_t i = 0; i < pixelAmount; i++)
    {
        SDL_SetRenderDrawColor(renderer, colorInfo[i*4], colorInfo[i*4+1], colorInfo[i*4+2], colorInfo[i*4+3]);
        int x = i % width;        
        int y = i / width;
        SDL_RenderPoint(renderer, x, y);
    }
    isBusy = false;
}

void drawToPPMImage(int pixelAmount, int* colorInfo) {
    isBusy = true;

    ofstream image = createPPM(width, height);

    for (size_t i = 0; i < pixelAmount; i++)
    {
        image << (int)colorInfo[i*4] << " " << (int)colorInfo[i*4+1] << " " << (int)colorInfo[i*4+2] << "\n";
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

array<uint8_t, 4> calcPixelColor(int iteration) {
    array<uint8_t, 4> color = {0, 0, 0, 255};

    int gradientSteps = 30;
    int mappedIteration = (int)(((double)iteration / maxIterations) * (gradientSteps - 1));
    
    switch (mappedIteration)
    {
    case 0:
        setColorValues(color, 17, 32, 45, 255);
        return color;
    case 1:
        setColorValues(color, 45, 70, 37, 255);
        return color;
    case 2:
        setColorValues(color, 73, 109, 29, 255);
        return color;
    case 3:
        setColorValues(color, 101, 147, 22, 255);
        return color;
    case 4:
        setColorValues(color, 129, 186, 14, 255);
        return color;
    case 5:
        setColorValues(color, 157, 224, 6, 255);
        return color;
    case 6:
        setColorValues(color, 173, 255, 4, 255);
        return color;
    case 7:
        setColorValues(color, 142, 255, 24, 255);
        return color;
    case 8:
        setColorValues(color, 111, 255, 44, 255);
        return color;
    case 9:
        setColorValues(color, 80, 255, 63, 255);
        return color;
    case 10:
        setColorValues(color, 49, 255, 83, 255);
        return color;
    case 11:
        setColorValues(color, 19, 255, 103, 255);
        return color;
    case 12:
        setColorValues(color, 0, 254, 125, 255);
        return color;
    case 13:
        setColorValues(color, 0, 250, 149, 255);
        return color;
    case 14:
        setColorValues(color, 0, 247, 173, 255);
        return color;
    case 15:
        setColorValues(color, 0, 244, 197, 255);
        return color;
    case 16:
        setColorValues(color, 0, 241, 221, 255);
        return color;
    case 17:
        setColorValues(color, 0, 237, 245, 255);
        return color;
    case 18:
        setColorValues(color, 11, 212, 255, 255);
        return color;
    case 19:
        setColorValues(color, 30, 171, 254, 255);
        return color;
    case 20:
        setColorValues(color, 48, 130, 254, 255);
        return color;
    case 21:
        setColorValues(color, 66, 90, 254, 255);
        return color;
    case 22:
        setColorValues(color, 85, 49, 253, 255);
        return color;
    case 23:
        setColorValues(color, 103, 8, 253, 255);
        return color;
    case 24:
        setColorValues(color, 92, 0, 218, 255);
        return color;
    case 25:
        setColorValues(color, 74, 0, 174, 255);
        return color;
    case 26:
        setColorValues(color, 55, 0, 131, 255);
        return color;
    case 27:
        setColorValues(color, 37, 0, 87, 255);
        return color;
    case 28:
        setColorValues(color, 18, 0, 44, 255);
        return color;
    case 29:
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