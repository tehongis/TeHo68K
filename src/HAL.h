#ifndef HAL_H
#define HAL_H

#define SYSTEM_CPU_TYPE     M68K_CPU_TYPE_68000

#define SYSTEM_MEM_SIZE     (0x100000)


#define VRAM_START    0x00080000
#define VRAM_SIZE     (800 * 600) // 480,000 tavua
#define PALETTE_START 0x00088000
#define PALETTE_SIZE  (256 * 4)   // 1024 tavua (32-bit ARGB per väri)

#define FONT_ROM     (0x0008c000)

// Virtuaalisen UART:n rekisterit
#define UART_IN_ADDR  0x0008F000
#define UART_OUT_ADDR 0x0008F004

#endif // HAL_H

