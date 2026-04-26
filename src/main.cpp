#include <SDL3/SDL.h>
#include <iostream>
#include "ComplexNumber.cpp"

void setColor(SDL_Renderer* renderer, int iteration);

int main(int argc, char *argv[]) {
    int width;
    int height;
    
    try
    {
        if (argc < 3)
        {
            width = std::stoi(argv[1]);
            height = std::stoi(argv[1]);
        } else {
            width = std::stoi(argv[1]);
            height = std::stoi(argv[2]);
        }
    }
    catch(const std::exception& e)
    {
        std::cerr << e.what() << '\n';
        std::cout << "Using default values (300x300).\n";
        width = 300;
        height = 300;
    }
    


    int pixelAmount = width * height;
    
    if (!SDL_Init(SDL_INIT_VIDEO)) {
        std::cerr << "SDL_Init fehlgeschlagen!" << std::endl;
        return 1;
    }

    SDL_Window* window = SDL_CreateWindow("SDL3 Window", width, height, 0);
    if (!window) {
        std::cerr << "Window-Erstellung fehlgeschlagen!" << std::endl;
        return 1;
    }

    SDL_Renderer* renderer = SDL_CreateRenderer(window, nullptr);
    if (!renderer) {
        std::cerr << "Renderer-Erstellung fehlgeschlagen!" << std::endl;
        return 1;
    }

    bool running = true;
    SDL_Event event;

    std::cout << "Starting Mandelbrot...\n";

    // Hintergrund schwarz
    SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
    SDL_RenderClear(renderer);

    //mandelbrot: z_n = (z_n-1)^2 + C
    int maxIteration = 1000;
    for (size_t i = 0; i < pixelAmount; i++)
    {
        int x = i % width;
        int y = i / width;
        double mX = (((double)x / (double)width) * 2.47) - 2; //mapping x value to lie on mandelbrot x scale (ca. -2.0 to 0.47)
        double mY = (((double)y / (double)height) * 2.24) - 1.12; //same with y axis (ca. -1.12 to 1.12)

        ComplexNumber c = ComplexNumber(mX, mY);
        ComplexNumber z = ComplexNumber(0, 0);

        int iteration = 0;
        while (z.absoluteValueSquared() <= 4 && iteration < maxIteration)
        {
            z = (z * z) + c;
            iteration++;            
        }
        setColor(renderer, iteration);
        SDL_RenderPoint(renderer, x, y);
    }
    
    std::cout << "Finished painting " << pixelAmount << " pixels!\n";
    std::cout << "Rendering...\n";


    SDL_RenderPresent(renderer);    

    //key events
    while (running) {

        while (SDL_PollEvent(&event)) {
            if (event.type == SDL_EVENT_QUIT) {
                running = false;
            }
            
            if (event.type == SDL_EVENT_KEY_DOWN) {
                if (event.key.key == SDLK_ESCAPE) {
                    running = false;
                }
            }
        }
    }

    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();

    return 0;
}

void setColor(SDL_Renderer* renderer, int iteration) {
    SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);

    int mappedIteration = iteration / 100; //adjust!!!

    switch (mappedIteration)
    {
    case 1:
        SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
        break;
    case 2:
        SDL_SetRenderDrawColor(renderer, 255, 0, 0, 255);
        break;
    case 3:
        SDL_SetRenderDrawColor(renderer, 0, 255, 0, 255);
        break;
    case 4:
        SDL_SetRenderDrawColor(renderer, 0, 0, 255, 255);
        break;
    case 5:
        SDL_SetRenderDrawColor(renderer, 255, 255, 0, 255);
        break;
    case 6:
        SDL_SetRenderDrawColor(renderer, 255, 0, 255, 255);
        break;
    case 7:
        SDL_SetRenderDrawColor(renderer, 0, 255, 255, 255);
        break;
    case 8:
        SDL_SetRenderDrawColor(renderer, 255, 255, 255, 255);
        break;
    case 9:
        SDL_SetRenderDrawColor(renderer, 128, 128, 128, 255);
        break;
    case 10:
        SDL_SetRenderDrawColor(renderer, 128, 0, 0, 255);
        break;
    default:
        SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
        break;
    }
}