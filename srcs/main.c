#include <stdio.h>
#include <stdlib.h>
#include "rocket68.h"
#include "vm.h"
#include "display.h"

int load_rom(VirtualMachine* vm, const char* filename) {
    FILE* f = fopen(filename, "rb");
    if (!f) {
        perror("Failed to load ROM");
        return -1;
    }
    fread(vm->rom, 1, ROM_SIZE, f);
    fclose(f);
    return 0;
}

int main(int argc, char** argv) {
    VirtualMachine vm;
    vm_init(&vm);
    
    // Only load the small autoboot into ROM
    load_rom(&vm, "rom/autoboot.bin");
        
    init_display();
    
    M68kCpu cpu;
    M68kConfig config = {0};
    config.user_data = &vm;
    config.read_byte = vm_read_byte;
    config.read_word = vm_read_word;
    config.read_long = vm_read_long;
    config.write_byte = vm_write_byte;
    config.write_word = vm_write_word;
    config.write_long = vm_write_long;
    
    m68k_init(&cpu, &config);
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
        
        if (cpu.status & M68K_STATUS_HALTED) {
            printf("CPU halted at PC: 0x%08X\n", cpu.pc);
            break;
        }
    }
    
    display_cleanup();
    vm_cleanup(&vm);
    
    return 0;
}   






