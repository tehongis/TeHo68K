#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <SDL2/SDL.h>
#include "rocket68.h"
#include "vm.h"
#include "display.h"

// Luodaan täysi 16MB muistiavaruus emulaattorille
#define SYSTEM_MEM_SIZE (16 * 1024 * 1024)
uint8_t system_memory[SYSTEM_MEM_SIZE];

int load_rom_to_correct_address(const char* filename) {
    FILE* f = fopen(filename, "rb");
    if (!f) {
        perror("Failed to load ROM");
        return -1;
    }
    
    // Ladataan ydin osoitteeseen $00E00000
    size_t bytes_read = fread(&system_memory[0x00E00000], 1, 2 * 1024 * 1024, f);
    fclose(f);
    
    if (bytes_read == 0) {
        printf("Warning: ROM file is empty or too small.\n");
        return -1;
    }
    
    // Pakotetaan käynnistysvektorit osoitteeseen 0 ja 4 Big-Endian muodossa
    // Alustusvektori 1: Alkuperäinen pino ($00080000)
    system_memory[0] = 0x00;
    system_memory[1] = 0x08;
    system_memory[2] = 0x00;
    system_memory[3] = 0x00;
    
    // Alustusvektori 2: COLD_BOOT aloitusosoite ($00E00008)
    // kernel.asm:ssa COLD_BOOT alkaa heti ResetVectorin (8 tavua) jälkeen
    system_memory[4] = 0x00;
    system_memory[5] = 0xE0;
    system_memory[6] = 0x00;
    system_memory[7] = 0x08;
    
    printf("Loaded kernel: %d bytes. Vectors forced: SP=$00080000, PC=$00E00008\n", (int)bytes_read);
    return 0;
}


int main(int argc, char** argv) {
    (void)argc;
    (void)argv;

    VirtualMachine vm;
    vm_init(&vm);
    
    // ===== SYSTEM MEMORY POISONING =====
    // Täytetään koko 16MB muisti arvolla 0x4A (Illegal Instruction) karkureita varten
    memset(system_memory, 0x4A, SYSTEM_MEM_SIZE);
    
    // Ladataan koodi oikeaan osoitteeseen
    if (load_rom_to_correct_address("rom/kernel.bin") != 0) {
        return 1;
    }    

    // Alustetaan graafinen näkymä (Käyttää korjattua nimeä display.h:sta)
    if (display_init() != 0) {
        return 1;
    }
    
    // Linkitetään VirtualMachinen framebuffer muistiavaruuden FB_BASE ($00C00000) kohdalle
    free(vm.framebuffer); 
    vm.framebuffer = &system_memory[FB_BASE];
        
    M68kCpu cpu;
    m68k_init(&cpu, system_memory, SYSTEM_MEM_SIZE);
    m68k_reset(&cpu);
        
    printf("=== 68000 Virtual Computer ===\n");
    printf(" Järjestelmämuisti: 16 MB mapped (Poisoned with 0x4A)\n");
    printf(" Display: %dx%d 8-bit indexed\n\n", FB_WIDTH, FB_HEIGHT);
    
    uint32_t last_frame = 0;
    int running = 1;

    for (int y = 200; y < 400; y++) {
        for (int x = 200; x < 600; x++) {
            system_memory[FB_BASE + (y * FB_WIDTH) + x] = 1; // 1 = Valkoinen/Valoisa
        }
    }


    while (running) {
        m68k_execute(&cpu, 1000);
        
        uint32_t now = SDL_GetTicks();
        if (now - last_frame >= 16) {
            vm.fb_dirty = 1;
            vm.palette_dirty = 1;            
            display_update(&vm);
            last_frame = now;
        }
        
        running = display_poll_events();
        
        // Seurataan rocket68:n virallista stopped-lippua
        if (cpu.stopped) {
            printf("CPU STOP/HALT osoitteessa: 0x%08X (Guru Meditation aktiivinen)\n", (unsigned int)cpu.pc);
            vm.fb_dirty = 1;
            display_update(&vm);
            break;
        }
    }

    // =========================================================================
    // ISO CPU DEBUG STATUS PRINT (Sulkemisen tai kaatumisen yhteydessä)
    // =========================================================================
    printf("\n=================================================================\n");
    printf("                  TEHO68K CPU DEBUG STATUS PRINT                 \n");
    printf("=================================================================\n");
    printf(" PC : 0x%08X   PPC: 0x%08X   SR: 0x%04X\n", cpu.pc, cpu.ppc, cpu.sr);
    printf(" Status: %s | Mode: %s\n", 
           cpu.stopped ? "STOPPED/HALTED" : "RUNNING/IDLE",
           (cpu.sr & 0x2000) ? "SUPERVISOR" : "USER");
    printf(" Vector Base (VBR): 0x%08X\n", cpu.vbr);
    printf("-----------------------------------------------------------------\n");
    
    // Tulostetaan Data-rekisterit D0-D7
    printf(" DATA REGISTERS:\n");
    for (int i = 0; i < 8; i++) {
        printf("  D%d: 0x%08X", i, cpu.d_regs[i].l);
        if (i == 3 || i == 7) printf("\n");
    }
    
    // Tulostetaan Osoitinrekisterit A0-A7
    printf(" ADDRESS REGISTERS:\n");
    for (int i = 0; i < 8; i++) {
        // A7 on m68k:ssa pino. Katsotaan kumpi pino on aktiivinen SR:n mukaan
        if (i == 7) {
            printf("  A7(SP): 0x%08X [SSP: 0x%08X, USP: 0x%08X]\n", 
                   cpu.a_regs[7].l, cpu.ssp, cpu.usp);
        } else {
            printf("  A%d: 0x%08X", i, cpu.a_regs[i].l);
            if (i == 3) printf("\n");
        }
    }
    printf("-----------------------------------------------------------------\n");
    printf(" Remaining Cycles: %d | Pending NMI: %s\n", 
           cpu.cycles_remaining, cpu.nmi_pending ? "YES" : "NO");
    printf("=================================================================\n\n");


    // Estetään vm_cleanupia vapauttamasta framebufferia, koska se osoittaa system_memoryyn
    vm.framebuffer = NULL; 
    
    display_cleanup();
    vm_cleanup(&vm);
    
    return 0;
}
