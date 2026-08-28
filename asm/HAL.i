; =============================================================================
; MINITIETOKONEEN HAL (HARDWARE ABSTRACTION LAYER) MÄÄRITTELYT
; Kääntäjäyhteensopivuus: vasm68k_mot (Motorola Syntax)
; Syntaksisäännöt: LABELIT ISROLLA, käskyt ja rekisterit pienellä.
; =============================================================================

SYSTEM_MEM_SIZE equ $100000

VRAM_START    equ   $00080000
VRAM_X        equ   320
VRAM_Y        equ   256
VRAM_SIZE     equ   (VRAM_X*VRAM_Y)
PALETTE_START equ   $00088000
PALETTE_SIZE  equ   (256*4)
FONT_ROM      EQU   $0008c000

; Virtuaalisen UART:n rekisterit
UART_IN_ADDR  equ   $0008F000
UART_OUT_ADDR equ   $0008F004
