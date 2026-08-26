#include <stdio.h>
#include <stdlib.h>
#include <SDL2/SDL.h>
#include "rocket68.h"
#include "vm.h"
#include "display.h"

int load_rom(VirtualMachine* vm, const char* filename) {
    FILE* f = fopen(filename, "rb");
    if (!f) {
        perror("Failed to load ROM");
        return -1;
    }
    
    // Load the entire kernel (Boot + HAL + OS)
    size_t bytes_read = fread(vm->rom, 1, ROM_SIZE, f);
    fclose(f);
    
    if (bytes_read == 0) {
        printf("Warning: ROM file is empty or too small.\n");
        return -1;
    }
    
    printf("Loaded kernel: %d bytes\n", (int)bytes_read);
    return 0;
}

int main(int argc, char** argv) {
    VirtualMachine vm;
    vm_init(&vm);
    
    // CHANGE: Load the unified kernel instead of just autoboot
    // Ensure kernel.bin is built from kernel.asm
    if (load_rom(&vm, "rom/kernel.bin") != 0) {
        return 1;
    }

    if (display_init() != 0) {
        return 1;
    }

    
    M68kCpu cpu;
    
    // rocket68 virallinen alustus ottaa osoittimen puskuriin ja sen koon
    m68k_init(&cpu, vm.ram, RAM_SIZE);
    m68k_reset(&cpu);    

    printf("=== 68000 Virtual Computer ===\n");
    printf("ROM: %d KB, RAM: %d KB\n", ROM_SIZE/1024, RAM_SIZE/1024);
    printf("Display: %dx%d 8-bit indexed\n", FB_WIDTH, FB_HEIGHT);
    printf("HDD: %s/\n\n", vm.hdd_path);
    
    Uint32 last_frame = 0;
    int running = 1;
    
    while (running) {
        m68k_execute(&cpu, 1000);
        
        Uint32 now = SDL_GetTicks();
        if (now - last_frame >= 16) {
            display_update(&vm);
            last_frame = now;
        }
        
        running = display_poll_events();

        // ===== TÄYDELLINEN HALT / STOP TUEN TOTEUTUS =====
        // Luetaan suoraan rocket68-ytimen virallista 'stopped'-lippua!
        if (cpu.stopped) {
            printf("CPU STOP/HALT detected at PC: 0x%08X (Amiga Guru Meditation Mode Active)\n", (unsigned int)cpu.pc);
            break;
        }

    }
    
    display_cleanup();
    vm_cleanup(&vm);
    
    return 0;
}   






