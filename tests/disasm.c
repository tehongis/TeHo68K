#include "disasm.h"

char disasm_buf[256];
m68k_disassemble(&cpu, cpu.pc, disasm_buf, sizeof(disasm_buf));
printf("PC 0x%08X: %s\n", cpu.pc, disasm_buf);   