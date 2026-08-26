#include "vm.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <sys/stat.h>

void vm_init(VirtualMachine* vm) {
    memset(vm, 0, sizeof(VirtualMachine));
    
    vm->rom = calloc(ROM_SIZE, 1);
    vm->ram = calloc(RAM_SIZE, 1);
    vm->framebuffer = calloc(FB_SIZE, 1);
    vm->hdd_path = strdup("HDD");
    
    // Initialize grayscale palette
    for (int i = 0; i < 256; i++) {
        vm->palette[i * 3] = i;
        vm->palette[i * 3 + 1] = i;
        vm->palette[i * 3 + 2] = i;
    }
    
    // Load font
    memcpy(vm->font_rom, font_8x8, FONT_SIZE);
    
    // Create HDD folder
    mkdir("HDD", 0755);
    
    vm->fb_width = FB_WIDTH;
    vm->fb_height = FB_HEIGHT;
}

void vm_cleanup(VirtualMachine* vm) {
    free(vm->rom);
    free(vm->ram);
    free(vm->framebuffer);
    free(vm->hdd_path);
}

static void hdd_execute_command(VirtualMachine* vm, uint8_t cmd) {
    char filepath[512];
    
    switch (cmd) {
        case HDD_CMD_INIT:
            vm->io_registers[HDD_STATUS_REG - IO_BASE] = 0x01;
            break;
            
        case HDD_CMD_READ:
            snprintf(filepath, sizeof(filepath), "%s/sector_%04d.bin", 
                     vm->hdd_path, vm->hdd_current_sector);
            FILE* f = fopen(filepath, "rb");
            if (f) {
                fread(vm->hdd_sector_buf, 1, HDD_SECTOR_SIZE, f);
                fclose(f);
            } else {
                memset(vm->hdd_sector_buf, 0, HDD_SECTOR_SIZE);
            }
            vm->io_registers[HDD_STATUS_REG - IO_BASE] = 0x01;
            break;
            
        case HDD_CMD_WRITE:
            snprintf(filepath, sizeof(filepath), "%s/sector_%04d.bin", 
                     vm->hdd_path, vm->hdd_current_sector);
            f = fopen(filepath, "wb");
            if (f) {
                fwrite(vm->hdd_sector_buf, 1, HDD_SECTOR_SIZE, f);
                fclose(f);
                vm->io_registers[HDD_STATUS_REG - IO_BASE] = 0x01;
            } else {
                vm->io_registers[HDD_STATUS_REG - IO_BASE] = 0x00;
            }
            break;
    }
}

uint8_t vm_read_byte(void* user_data, uint32_t addr) {
    VirtualMachine* vm = (VirtualMachine*)user_data;
    
    if (addr < ROM_SIZE) return vm->rom[addr];
    if (addr >= RAM_BASE && addr < RAM_BASE + RAM_SIZE) 
        return vm->ram[addr - RAM_BASE];
    if (addr >= FB_BASE && addr < FB_BASE + FB_SIZE) 
        return vm->framebuffer[addr - FB_BASE];
    if (addr >= FONT_ROM_BASE && addr < FONT_ROM_BASE + FONT_SIZE) 
        return vm->font_rom[addr - FONT_ROM_BASE];
    if (addr >= PALETTE_BASE && addr < PALETTE_BASE + PALETTE_SIZE) 
        return vm->palette[addr - PALETTE_BASE];
    if (addr >= IO_BASE && addr < IO_BASE + 256) 
        return vm->io_registers[addr - IO_BASE];
    return 0x00;
}

uint16_t vm_read_word(void* user_data, uint32_t addr) {
    return (vm_read_byte(user_data, addr) << 8) | 
           vm_read_byte(user_data, addr + 1);
}

uint32_t vm_read_long(void* user_data, uint32_t addr) {
    return (vm_read_word(user_data, addr) << 16) | 
           vm_read_word(user_data, addr + 2);
}

void vm_write_byte(void* user_data, uint32_t addr, uint8_t value) {
    VirtualMachine* vm = (VirtualMachine*)user_data;
    
    if (addr >= RAM_BASE && addr < RAM_BASE + RAM_SIZE) {
        vm->ram[addr - RAM_BASE] = value;
    } else if (addr >= FB_BASE && addr < FB_BASE + FB_SIZE) {
        vm->framebuffer[addr - FB_BASE] = value;
        vm->fb_dirty = 1;
    } else if (addr >= PALETTE_BASE && addr < PALETTE_BASE + PALETTE_SIZE) {
        vm->palette[addr - PALETTE_BASE] = value;
        vm->palette_dirty = 1;
    } else if (addr >= IO_BASE && addr < IO_BASE + 256) {
        if (addr == HDD_SECTOR_LO) {
            vm->hdd_current_sector = (vm->hdd_current_sector & 0xFF00) | value;
        } else if (addr == HDD_SECTOR_HI) {
            vm->hdd_current_sector = (vm->hdd_current_sector & 0x00FF) | (value << 8);
        } else if (addr == HDD_CMD_REG) {
            hdd_execute_command(vm, value);
        } else if (addr == CONSOLE_DATA) {
            putchar(value);
            fflush(stdout);            
        } else if (addr >= MOUSE_SHAPE_REG && addr < MOUSE_SHAPE_REG + 0x10) {
            switch (addr - IO_BASE) {
                case 0x80: vm->mouse_shape = value; break;
                case 0x82: vm->mouse_hotspot_x = (vm->mouse_hotspot_x & 0xFF00) | value; break;
                case 0x83: vm->mouse_hotspot_x = (vm->mouse_hotspot_x & 0x00FF) | (value << 8); break;
                case 0x84: vm->mouse_hotspot_y = (vm->mouse_hotspot_y & 0xFF00) | value; break;
                case 0x85: vm->mouse_hotspot_y = (vm->mouse_hotspot_y & 0x00FF) | (value << 8); break;
                case 0x86: vm->mouse_visible = value; break;
                case 0x88: vm->mouse_scale_x = (vm->mouse_scale_x & 0xFF00) | value; break;
                case 0x89: vm->mouse_scale_x = (vm->mouse_scale_x & 0x00FF) | (value << 8); break;
                case 0x8A: vm->mouse_scale_y = (vm->mouse_scale_y & 0xFF00) | value; break;
                case 0x8B: vm->mouse_scale_y = (vm->mouse_scale_y & 0x00FF) | (value << 8); break;
            }
            
        } else if (addr >= GFX_LINE_X1 && addr < GFX_LINE_X1 + 0x10) {
            switch (addr - IO_BASE) {
                case 0x90: vm->io_registers[0x90] = value; break;
                case 0x9A: if (value == 1) gfx_draw_line(vm); break;
            }
            
        } else if (addr >= GFX_RECT_X && addr < GFX_RECT_X + 0x10) {
            switch (addr - IO_BASE) {
                case 0xAC: if (value == 1) gfx_draw_rect(vm); break;
            }
            
        } else if (addr >= GFX_BLT_SRC_X && addr < GFX_BLT_SRC_X + 0x10) {
            switch (addr - IO_BASE) {
                case 0xBC: if (value == 1) gfx_bitblt(vm); break;
            }
            
        } else if (addr >= AUDIO_SAMPLE_RATE && addr < AUDIO_SAMPLE_RATE + 0x10) {
            switch (addr - IO_BASE) {
                case 0x30: vm->audio_sample_rate = value; break;
                case 0x32: vm->audio_channels = value; break;
                case 0x38: vm->audio_playing = value; break;
            }
            
        } else if (addr >= TIMER_PERIOD && addr < TIMER_PERIOD + 0x10) {
            switch (addr - IO_BASE) {
                case 0x40: vm->timer_period = value; break;
                case 0x48: vm->timer_enabled = value; break;
                case 0x4C: vm->timer_irq_level = value; break;
            }
            
        } else if (addr == POWER_REG) {
            vm->power_off = value;
        } else {
            vm->io_registers[addr - IO_BASE] = value;
        }
    }
}

void vm_write_word(void* user_data, uint32_t addr, uint16_t value) {
    vm_write_byte(user_data, addr, (value >> 8) & 0xFF);
    vm_write_byte(user_data, addr + 1, value & 0xFF);
}

void vm_write_long(void* user_data, uint32_t addr, uint32_t value) {
    vm_write_word(user_data, addr, (value >> 16) & 0xFFFF);
    vm_write_word(user_data, addr + 2, value & 0xFFFF);
}   

// Add to vm.c

static void gfx_draw_line(VirtualMachine* vm) {
    // Read coordinates from io_registers
    int x1 = (vm->io_registers[0x90] << 8) | vm->io_registers[0x91];
    int y1 = (vm->io_registers[0x92] << 8) | vm->io_registers[0x93];
    int x2 = (vm->io_registers[0x94] << 8) | vm->io_registers[0x95];
    int y2 = (vm->io_registers[0x96] << 8) | vm->io_registers[0x97];
    uint8_t color = vm->io_registers[0x98];
    
    // Bresenham's line algorithm (simple version)
    int dx = abs(x2 - x1), dy = abs(y2 - y1);
    int sx = (x1 < x2) ? 1 : -1, sy = (y1 < y2) ? 1 : -1;
    int err = dx - dy;
    
    while (1) {
        if (x1 >= 0 && x1 < FB_WIDTH && y1 >= 0 && y1 < FB_HEIGHT)
            vm->framebuffer[y1 * FB_WIDTH + x1] = color;
        if (x1 == x2 && y1 == y2) break;
        int e2 = 2 * err;
        if (e2 > -dy) { err -= dy; x1 += sx; }
        if (e2 < dx) { err += dx; y1 += sy; }
    }
    vm->fb_dirty = 1;
}

static void gfx_draw_rect(VirtualMachine* vm) {
    int x = (vm->io_registers[0xA0] << 8) | vm->io_registers[0xA1];
    int y = (vm->io_registers[0xA2] << 8) | vm->io_registers[0xA3];
    int w = (vm->io_registers[0xA4] << 8) | vm->io_registers[0xA5];
    int h = (vm->io_registers[0xA6] << 8) | vm->io_registers[0xA7];
    uint8_t color = vm->io_registers[0xA8];
    int fill = vm->io_registers[0xAA];
    
    for (int i = 0; i < h; i++) {
        for (int j = 0; j < w; j++) {
            int px = x + j, py = y + i;
            if (px < 0 || px >= FB_WIDTH || py < 0 || py >= FB_HEIGHT) continue;
            if (fill || i == 0 || i == h-1 || j == 0 || j == w-1)
                vm->framebuffer[py * FB_WIDTH + px] = color;
        }
    }
    vm->fb_dirty = 1;
}

static void gfx_bitblt(VirtualMachine* vm) {
    int sx = (vm->io_registers[0xB0] << 8) | vm->io_registers[0xB1];
    int sy = (vm->io_registers[0xB2] << 8) | vm->io_registers[0xB3];
    int dx = (vm->io_registers[0xB4] << 8) | vm->io_registers[0xB5];
    int dy = (vm->io_registers[0xB6] << 8) | vm->io_registers[0xB7];
    int w  = (vm->io_registers[0xB8] << 8) | vm->io_registers[0xB9];
    int h  = (vm->io_registers[0xBA] << 8) | vm->io_registers[0xBB];
    
    for (int i = 0; i < h; i++) {
        for (int j = 0; j < w; j++) {
            if (sx+j >= FB_WIDTH || sy+i >= FB_HEIGHT) continue;
            if (dx+j >= FB_WIDTH || dy+i >= FB_HEIGHT) continue;
            vm->framebuffer[(dy+i)*FB_WIDTH + (dx+j)] = 
                vm->framebuffer[(sy+i)*FB_WIDTH + (sx+j)];
        }
    }
    vm->fb_dirty = 1;
}   