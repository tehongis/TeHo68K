// Example: Loading BASIC interpreter into ROM
int load_basic_rom(VirtualMachine* vm, const char* basic_rom_file) {
    FILE* f = fopen(basic_rom_file, "rb");
    if (!f) {
        perror("Failed to load BASIC ROM");
        return -1;
    }
    
    fread(vm->rom, 1, ROM_SIZE, f);
    fclose(f);
    
    printf("BASIC interpreter loaded: %d bytes\n", ROM_SIZE);
    return 0;
}

// Alternative: Load from S-record file (Rocket 68 supports this)
#include "loader.h"

int load_basic_srecord(VirtualMachine* vm, const char* srec_file) {
    M68kBinary bin;
    if (m68k_load_srec(&bin, srec_file) != 0) {
        return -1;
    }
    
    // Copy loaded binary to appropriate memory locations
    memcpy(vm->rom + bin.start_addr, bin.data, bin.size);
    m68k_binary_free(&bin);
    
    return 0;
}   