#ifndef VM_H
#define VM_H

#include <stdint.h>
#include <stdbool.h>

// Memory Map
#define ROM_BASE        0x00000000
#define ROM_SIZE        0x00008000
#define RAM_BASE        0x00080000
#define RAM_SIZE        0x00080000
#define FB_BASE         0x00C00000
#define FB_WIDTH        800
#define FB_HEIGHT       600
#define FB_SIZE         (FB_WIDTH * FB_HEIGHT)
#define FONT_ROM_BASE   0x00FF8000
#define FONT_SIZE       2048
#define PALETTE_BASE    0x00FF0100
#define PALETTE_SIZE    768
#define HDD_BASE        0x00A00000
#define HDD_SECTOR_SIZE 512

// I/O Registers
#define IO_BASE             0x00FF0000
#define CONSOLE_DATA        (IO_BASE + 0x00)
#define HDD_CMD_REG         (IO_BASE + 0x10)
#define HDD_DATA_REG        (IO_BASE + 0x11)
#define HDD_STATUS_REG      (IO_BASE + 0x12)
#define HDD_SECTOR_LO       (IO_BASE + 0x13)
#define HDD_SECTOR_HI       (IO_BASE + 0x14)

// HDD Commands
#define HDD_CMD_INIT    0x01
#define HDD_CMD_READ    0x20
#define HDD_CMD_WRITE   0x30


// Add to vm.h after existing defines

// Mouse & Graphics Acceleration Registers (TRAP #6)
#define MOUSE_SHAPE_REG     (IO_BASE + 0x80)
#define MOUSE_HOTSPOT_X     (IO_BASE + 0x82)
#define MOUSE_HOTSPOT_Y     (IO_BASE + 0x84)
#define MOUSE_VISIBLE_FLAG  (IO_BASE + 0x86)
#define MOUSE_SCALE_X       (IO_BASE + 0x88)
#define MOUSE_SCALE_Y       (IO_BASE + 0x8A)

// Graphics Acceleration
#define GFX_LINE_X1         (IO_BASE + 0x90)
#define GFX_LINE_Y1         (IO_BASE + 0x92)
#define GFX_LINE_X2         (IO_BASE + 0x94)
#define GFX_LINE_Y2         (IO_BASE + 0x96)
#define GFX_LINE_COLOR      (IO_BASE + 0x98)
#define GFX_LINE_TRIGGER    (IO_BASE + 0x9A)

#define GFX_RECT_X          (IO_BASE + 0xA0)
#define GFX_RECT_Y          (IO_BASE + 0xA2)
#define GFX_RECT_W          (IO_BASE + 0xA4)
#define GFX_RECT_H          (IO_BASE + 0xA6)
#define GFX_RECT_COLOR      (IO_BASE + 0xA8)
#define GFX_RECT_FILL       (IO_BASE + 0xAA)
#define GFX_RECT_TRIGGER    (IO_BASE + 0xAC)

#define GFX_BLT_SRC_X       (IO_BASE + 0xB0)
#define GFX_BLT_SRC_Y       (IO_BASE + 0xB2)
#define GFX_BLT_DST_X       (IO_BASE + 0xB4)
#define GFX_BLT_DST_Y       (IO_BASE + 0xB6)
#define GFX_BLT_W           (IO_BASE + 0xB8)
#define GFX_BLT_H           (IO_BASE + 0xBA)
#define GFX_BLT_TRIGGER     (IO_BASE + 0xBC)

// Audio
#define AUDIO_SAMPLE_RATE   (IO_BASE + 0x30)
#define AUDIO_CHANNELS      (IO_BASE + 0x32)
#define AUDIO_BUF_ADDR      (IO_BASE + 0x34)
#define AUDIO_BUF_LEN       (IO_BASE + 0x38)
#define AUDIO_PLAYING       (IO_BASE + 0x38)  // Reuse

// Timer
#define TIMER_PERIOD        (IO_BASE + 0x40)
#define TIMER_COUNTER       (IO_BASE + 0x44)
#define TIMER_ENABLED       (IO_BASE + 0x48)
#define TIMER_IRQ_LEVEL     (IO_BASE + 0x4C)

// System
#define POWER_REG           (IO_BASE + 0xF0)

typedef struct {
    uint8_t* rom;
    uint8_t* ram;
    uint8_t* framebuffer;
    uint8_t font_rom[FONT_SIZE];
    uint8_t palette[PALETTE_SIZE];
    uint8_t io_registers[256];
    
    uint16_t fb_width;
    uint16_t fb_height;
    int fb_dirty;
    int palette_dirty;
    
    char* hdd_path;
    uint8_t hdd_sector_buf[HDD_SECTOR_SIZE];
    uint32_t hdd_current_sector;

    // New fields for HAL
    uint8_t  mouse_shape;
    uint8_t  mouse_visible;
    uint16_t mouse_hotspot_x, mouse_hotspot_y;
    uint16_t mouse_scale_x, mouse_scale_y;
    uint16_t timer_period;
    uint32_t timer_counter;
    uint8_t  timer_enabled;
    uint8_t  audio_playing;
    uint16_t audio_sample_rate;
    uint8_t  audio_channels;
    uint8_t  power_off;

} VirtualMachine;

void vm_init(VirtualMachine* vm);
void vm_cleanup(VirtualMachine* vm);
uint8_t vm_read_byte(void* user_data, uint32_t addr);
uint16_t vm_read_word(void* user_data, uint32_t addr);
uint32_t vm_read_long(void* user_data, uint32_t addr);
void vm_write_byte(void* user_data, uint32_t addr, uint8_t value);
void vm_write_word(void* user_data, uint32_t addr, uint16_t value);
void vm_write_long(void* user_data, uint32_t addr, uint32_t value);

#endif   