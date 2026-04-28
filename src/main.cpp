#include <SDL3/SDL.h>
#include <iostream>
#include <fstream>
#include <array>
#include "ComplexNumber.cpp"

using namespace std;

void writeColorToPPM(SDL_Renderer* renderer, int iteration, int pixel, ofstream &image);
void setColorValues(array<uint8_t, 4> &c, uint8_t r, uint8_t g, uint8_t b, uint8_t a);
void renderMandelbrot(int pixelAmount, SDL_Renderer *renderer, ofstream &image);
void setRendererColor(SDL_Renderer* renderer, int iteration);
ofstream createPPM(int width, int height, string name);
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
bool isPPMDisabled = false;
bool isSDLDisabled = false;

bool isCalculatingNextFrame = false;

int main(int argc, char *argv[]) {
    try
    {
        width = stoi(argv[1]);
        height = stoi(argv[1]);
        if (argc >= 3) height = stoi(argv[2]);
        if (argc >= 4) {
            for (size_t i = 2; i < argc; i++)
            {
                if (string(argv[i]) == "noppm") {
                    isPPMDisabled = true;
                } else if (string(argv[i]) == "nosdl") {
                    isSDLDisabled = true;
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

    //init
    if (!SDL_Init(SDL_INIT_VIDEO)) return -1;
    
    SDL_Window* window = SDL_CreateWindow("SDL3 Window", width, height, 0);
    if (!window) return -1;

    SDL_Renderer* renderer = SDL_CreateRenderer(window, nullptr);
    if (!renderer) return -1;

    if (isSDLDisabled) SDL_Quit();
    
    ofstream image;
    if (!isPPMDisabled) image = createPPM(width, height, "mandelPic.ppm");

    SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
    SDL_RenderClear(renderer);
    cout << "Setup done! Starting Mandelbrot...\n";

    renderMandelbrot(width * height, renderer, image);
    
    cout << "Finished painting " << width * height << " pixels!\n";
    SDL_RenderPresent(renderer);    

    bool running = true;
    SDL_Event event;
    while (running && !isSDLDisabled) {

        while (SDL_PollEvent(&event)) {
            if (event.type == SDL_EVENT_QUIT) {
                running = false;
            }
            
            if (event.type == SDL_EVENT_KEY_DOWN) {
                if (event.key.key == SDLK_ESCAPE) {
                    running = false;
                }
            }

            if (event.type == SDL_EVENT_MOUSE_WHEEL && !isCalculatingNextFrame) {
                if (event.wheel.y > 0)
                {
                    zoomfactor *= 2;

                    float x, y;
                    Uint32 buttons = SDL_GetMouseState(&x, &y);
                    x = x - width / 2;
                    y = -(y - height / 2);
                    x = x / (baseZoom * zoomfactor);
                    y = y / (baseZoom * zoomfactor);

                    xOffset += x;
                    yOffset += y;
                } else {
                    zoomfactor /= 2;

                    float x, y;
                    Uint32 buttons = SDL_GetMouseState(&x, &y);
                    x = x - width / 2;
                    y = -(y - height / 2);
                    x = x / (baseZoom * zoomfactor);
                    y = y / (baseZoom * zoomfactor);

                    xOffset -= x;
                    yOffset -= y;
                }

                cout << "zoom: " << zoomfactor << "\n";

                SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
                SDL_RenderClear(renderer);

                renderMandelbrot(width * height, renderer, image);
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
void renderMandelbrot(int pixelAmount, SDL_Renderer *renderer, ofstream &image) {
    isCalculatingNextFrame = true;
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
        if (!isPPMDisabled) writeColorToPPM(renderer, iteration, i, image);
        if (!isSDLDisabled) {
            setRendererColor(renderer, iteration);
            SDL_RenderPoint(renderer, x, y);
        }
    }
    isCalculatingNextFrame = false;
}

ofstream createPPM(int width, int height, string name) {
    ofstream image("mandelPic.ppm");
    image << "P3\n" << width << " " << height << "\n" << "255\n";
    return image;
}

void writeColorToPPM(SDL_Renderer* renderer, int iteration, int pixel, ofstream &image) {
    if (!image) return;
    array<uint8_t, 4> color = calcPixelColor(iteration);
    image << (int)color[0] << " " << (int)color[1] << " " << (int)color[2] << "\n";
}

void setRendererColor(SDL_Renderer* renderer, int iteration) {
    array<uint8_t, 4> color = calcPixelColor(iteration);
    SDL_SetRenderDrawColor(renderer, color[0], color[1], color[2], color[3]);
}

array<uint8_t, 4> calcPixelColor(int iteration) {
    array<uint8_t, 4> color = {0, 0, 0, 255};

    int gradientSteps = 10;
    int mappedIteration = (int)(((double)iteration / maxIterations) * (gradientSteps - 1));
    
    switch (mappedIteration)
    {
    case 0:
        setColorValues(color, 103, 1, 241, 255);
        return color;
    case 1:
        setColorValues(color, 185, 48, 111, 255);
        return color;
    case 2:
        setColorValues(color, 251, 105, 6, 255);
        return color;
    case 3:
        setColorValues(color, 254, 199, 2, 255);
        return color;
    case 4:
        setColorValues(color, 198, 255, 0, 255);
        return color;
    case 5:
        setColorValues(color, 57, 255, 0, 255);
        return color;
    case 6:
        setColorValues(color, 77, 195, 20, 255);
        return color;
    case 7:
        setColorValues(color, 205, 96, 53, 255);
        return color;
    case 8:
        setColorValues(color, 128, 42, 33, 255);
        return color;
    case 9:
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