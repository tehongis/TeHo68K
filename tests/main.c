#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include "rocket68.h"

// Define memory map for your virtual computer
#define ROM_BASE    0x00000000
#define ROM_SIZE    0x00008000    // 32KB ROM
#define RAM_BASE    0x00080000
#define RAM_SIZE    0x00080000    // 512KB RAM
#define IO_BASE     0x00FF0000    // I/O region

typedef struct {
    uint8_t* rom;
    uint8_t* ram;
    uint8_t io_registers[256];    // Simple I/O space
} VirtualMachine;

// Memory read callback for Rocket 68
static uint8_t vm_read_byte(void* user_data, uint32_t addr) {
    VirtualMachine* vm = (VirtualMachine*)user_data;
    
    if (addr < ROM_SIZE) {
        return vm->rom[addr];
    } else if (addr >= RAM_BASE && addr < RAM_BASE + RAM_SIZE) {
        return vm->ram[addr - RAM_BASE];
    } else if (addr >= IO_BASE && addr < IO_BASE + 256) {
        // Handle I/O reads (e.g., console status)
        return vm->io_registers[addr - IO_BASE];
    }
    
    return 0x00;    // Unmapped memory returns 0
}

static uint16_t vm_read_word(void* user_data, uint32_t addr) {
    if (addr & 1) {
        // Handle unaligned access (optional: trigger address error)
        return (vm_read_byte(user_data, addr) << 8) | 
               vm_read_byte(user_data, addr + 1);
    }
    
    VirtualMachine* vm = (VirtualMachine*)user_data;
    
    if (addr < ROM_SIZE - 1) {
        return (vm->rom[addr] << 8) | vm->rom[addr + 1];
    } else if (addr >= RAM_BASE && addr < RAM_BASE + RAM_SIZE - 1) {
        uint32_t offset = addr - RAM_BASE;
        return (vm->ram[offset] << 8) | vm->ram[offset + 1];
    }
    
    return 0x0000;
}

static uint32_t vm_read_long(void* user_data, uint32_t addr) {
    return (vm_read_word(user_data, addr) << 16) | 
           vm_read_word(user_data, addr + 2);
}

// Memory write callbacks
static void vm_write_byte(void* user_data, uint32_t addr, uint8_t value) {
    VirtualMachine* vm = (VirtualMachine*)user_data;
    
    if (addr >= RAM_BASE && addr < RAM_BASE + RAM_SIZE) {
        vm->ram[addr - RAM_BASE] = value;
    } else if (addr >= IO_BASE && addr < IO_BASE + 256) {
        // Handle I/O writes (e.g., console output)
        vm->io_registers[addr - IO_BASE] = value;
        
        // Example: Write to address IO_BASE sends byte to console
        if (addr == IO_BASE) {
            putchar(value);
            fflush(stdout);
        }
    }
    // ROM writes are ignored
}

static void vm_write_word(void* user_data, uint32_t addr, uint16_t value) {
    vm_write_byte(user_data, addr, (value >> 8) & 0xFF);
    vm_write_byte(user_data, addr + 1, value & 0xFF);
}

static void vm_write_long(void* user_data, uint32_t addr, uint32_t value) {
    vm_write_word(user_data, addr, (value >> 16) & 0xFFFF);
    vm_write_word(user_data, addr + 2, value & 0xFFFF);
}   