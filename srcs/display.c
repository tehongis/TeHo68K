#include "display.h"
#include "vm.h"
#include <SDL2/SDL.h>

static SDL_Window* window = NULL;
static SDL_Renderer* renderer = NULL;
static SDL_Surface* fb_surface = NULL;
static SDL_Texture* texture = NULL;

int display_init() {
    if (SDL_Init(SDL_INIT_VIDEO) < 0) {
        fprintf(stderr, "SDL init failed: %s\n", SDL_GetError());
        return -1;
    }
    
    window = SDL_CreateWindow("68000 Virtual Computer",
                              SDL_WINDOWPOS_CENTERED,
                              SDL_WINDOWPOS_CENTERED,
                              FB_WIDTH, FB_HEIGHT,
                              SDL_WINDOW_SHOWN);
    
    renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);
    fb_surface = SDL_CreateRGBSurfaceWithFormat(0, FB_WIDTH, FB_HEIGHT, 8, 
                                                 SDL_PIXELFORMAT_INDEX8);
    texture = SDL_CreateTextureFromSurface(renderer, fb_surface);
    
    return 0;
}

void display_update_palette(VirtualMachine* vm) {
    if (!vm->palette_dirty) return;
    
    SDL_Color colors[256];
    for (int i = 0; i < 256; i++) {
        colors[i].r = vm->palette[i * 3];
        colors[i].g = vm->palette[i * 3 + 1];
        colors[i].b = vm->palette[i * 3 + 2];
        colors[i].a = 255;
    }
    
    SDL_SetPaletteColors(fb_surface->format->palette, colors, 0, 256);
    SDL_DestroyTexture(texture);
    texture = SDL_CreateTextureFromSurface(renderer, fb_surface);
    vm->palette_dirty = 0;
}

void display_update(VirtualMachine* vm) {
    if (vm->palette_dirty) display_update_palette(vm);
    if (!vm->fb_dirty) return;
    
    memcpy(fb_surface->pixels, vm->framebuffer, FB_SIZE);
    SDL_UpdateTexture(texture, NULL, fb_surface->pixels, fb_surface->pitch);
    
    SDL_RenderClear(renderer);
    SDL_RenderCopy(renderer, texture, NULL, NULL);
    SDL_RenderPresent(renderer);
    
    vm->fb_dirty = 0;
}

void display_cleanup() {
    SDL_DestroyTexture(texture);
    SDL_FreeSurface(fb_surface);
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();
}

int display_poll_events() {
    SDL_Event event;
    while (SDL_PollEvent(&event)) {
        if (event.type == SDL_QUIT) return 0;
    }
    return 1;
}   