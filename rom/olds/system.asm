; =============================================================================
; system.asm - HAL System ROM for 68000 Virtual Computer
; Assemble with: vasm68k_mot -Fbin system.asm -o system.bin
; Load at RAM_BASE ($00040000)
; =============================================================================
        INCLUDE "HAL.i"

        ORG     $00040000

; ===== COLD BOOT =====
COLD_BOOT:
        MOVE.L  #$00080000,SP

        ; Alustetaan TRAP-vektorit dynaamisesti muistin alkuun ($00000080 eteenpäin)
        MOVE.L  #HAL_MEM,$00000080          ; TRAP #0
        MOVE.L  #HAL_IO,$00000084           ; TRAP #1
        MOVE.L  #HAL_TIMER,$00000088        ; TRAP #2
        MOVE.L  #HAL_DATA,$0000008C         ; TRAP #3
        MOVE.L  #HAL_CONTEXT,$00000090      ; TRAP #4
        MOVE.L  #HAL_SYSTEM,$00000094       ; TRAP #5
        MOVE.L  #HAL_MOUSE,$00000098        ; TRAP #6
        MOVE.L  #HAL_FRAMEBUFFER,$0000009C  ; TRAP #7
        MOVE.L  #HAL_BLOCKDEV,$000000A0     ; TRAP #8

        ; Alustetaan muistinhallinnan vapaa lista ($00046000), koodin jälkeen
        LEA     $00046000,A0
        MOVE.L  #0,(A0)
        
        ; Init timer
        MOVE.L  #0, TIMER_PERIOD_REG
        MOVE.L  #0, TIMER_COUNT_REG
        MOVE.B  #0, TIMER_EN_REG
        
        ; Init framebuffer
        MOVE.W  #800, $00FF0002
        MOVE.W  #600, $00FF0004
        MOVE.B  #8, $00FF0006
        
        ; Init palette
PAL_INIT:
        ; Init palette (16-color VGA default color set)
        LEA     VGA_PALETTE_DATA,A0         ; Osoitin lähdedataan
        LEA     PALETTE_BASE,A1             ; Osoitin videopalettiin
        MOVE.W  #47,D0                      ; 16 väriä * 3 tavua = 48 tavua
PAL_INIT_LOOP:
        MOVE.B  (A0)+,(A1)+                 ; Kopioidaan väriarvot
        DBRA    D0,PAL_INIT_LOOP

        
        ; Init HDD
        MOVE.B  #$01, HDD_CMD_REG
HDD_WAIT:
        BTST    #0, HDD_STATUS_REG
        BEQ     HDD_WAIT
        
        ; Load boot sector 0
        MOVE.W  #0, HDD_SECTOR_LO
        MOVE.B  #$20, HDD_CMD_REG
BOOT_WAIT:
        BTST    #0, HDD_STATUS_REG
        BEQ     BOOT_WAIT
        
        ; Copy to RAM and jump
        LEA     HDD_DATA_REG, A0
        LEA     $00040000, A1
        MOVEQ   #0, D0
BOOT_COPY:
        MOVE.B  (A0), (A1)+
        ADDQ.L  #1, D0
        CMPI    #512, D0
        BLT     BOOT_COPY
        
        JMP     $00040000

HAL_MEM:
        MOVE.L  D0, D1
        CMP.L   #HAL_MEM_ALLOC, D1
        BEQ     MEM_ALLOC
        CMP.L   #HAL_MEM_FREE, D1
        BEQ     MEM_FREE
        CMP.L   #HAL_MEM_CREATE, D1
        BEQ     MEM_CREATE
        CMP.L   #HAL_MEM_DESTROY, D1
        BEQ     MEM_DESTROY
        CMP.L   #HAL_MEM_ORGANIZE, D1
        BEQ     MEM_ORGANIZE
        BRA     HAL_INVALID

MEM_ALLOC:
        ; D1=size, D2=alignment → D0=ptr or -1
        LEA     $00040000, A0
        MOVE.L  D1, D3
        ADD.L   #8, D3
MEM_ALOOP:
        MOVE.L  (A0), D4
        BEQ     MEM_AFAIL
        MOVE.L  4(a0), d5
        CMP.L   D3, D5
        BCC     MEM_AFAIL
        OR.L    #1, D5
        MOVE.L  D5, 4(a0)
        MOVE.L  A0, D0
        MOVE.L  D4, (a0)-8
        RTS
MEM_AFAIL:
        MOVEQ   #-1, D0
        RTS

MEM_FREE:
        LEA     $00040000, A0
        MOVE.L  D1, (A0)
        RTS

MEM_CREATE:
        MOVE.L  D2, D1
        BSR     MEM_ALLOC
        MOVE.L  D0, D1
        MOVE.L  D2, D3
        MOVE.l  D0, A1
MEM_CLOOP:
        MOVE    #0, (A1)+
        DBRA    D3, MEM_CLOOP
        MOVE.L  D1, D0
        RTS

MEM_DESTROY:
        BSR     MEM_FREE
        RTS

MEM_ORGANIZE:
        RTS

HAL_IO:
        MOVE.L  D0, D1
        CMP.L   #HAL_IO_KBD_READ, D1
        BEQ     IO_KBD_READ
        CMP.L   #HAL_IO_KBD_STATUS, D1
        BEQ     IO_KBD_STATUS
        CMP.L   #HAL_IO_MOUSE_READ, D1
        BEQ     IO_MOUSE_READ
        CMP.L   #HAL_IO_MOUSE_STATUS, D1
        BEQ     IO_MOUSE_STATUS
        CMP.L   #HAL_IO_AUDIO_INIT, D1
        BEQ     IO_AUDIO_INIT
        CMP.L   #HAL_IO_AUDIO_PLAY, D1
        BEQ     IO_AUDIO_PLAY
        CMP.L   #HAL_IO_AUDIO_STOP, D1
        BEQ     IO_AUDIO_STOP
        BRA     HAL_INVALID

IO_KBD_READ:
        MOVE.B  CONSOLE_DATA, D0
        RTS

IO_KBD_STATUS:
        MOVE.B  CONSOLE_STATUS, D0
        RTS

IO_MOUSE_READ:
        MOVE.W  MOUSE_X_REG, D0
        MOVE.W  MOUSE_Y_REG, D1
        MOVE.B  MOUSE_BTN_REG, D2
        RTS

IO_MOUSE_STATUS:
        MOVE.B  $00FF0024, D0
        RTS

IO_AUDIO_INIT:
        MOVE.W  D1, AUDIO_RATE_REG
        MOVE.B  D2, AUDIO_CH_REG
        RTS

IO_AUDIO_PLAY:
        MOVE.L  D1, AUDIO_BUF_REG
        MOVE.L  D2, (AUDIO_BUF_REG)+4
        MOVE.B  #1, AUDIO_PLAY_REG
        RTS

IO_AUDIO_STOP:
        MOVE.B  #0, AUDIO_PLAY_REG
        RTS

HAL_TIMER:
        MOVE.L  D0, D1
        CMP.L   #HAL_TIMER_INIT, D1
        BEQ     T_INIT
        CMP.L   #HAL_TIMER_START, D1
        BEQ     T_START
        CMP.L   #HAL_TIMER_STOP, D1
        BEQ     T_STOP
        CMP.L   #HAL_TIMER_READ, D1
        BEQ     T_READ
        CMP.L   #HAL_TIMER_IRQ_SET, D1
        BEQ     T_IRQ_SET
        CMP.L   #HAL_TIMER_IRQ_CLR, D1
        BEQ     T_IRQ_CLR
        BRA     HAL_INVALID

T_INIT:
        MOVE.L  D1, TIMER_PERIOD_REG
        MOVE.L  #0, TIMER_COUNT_REG
        RTS
T_START:
        MOVE.B  #1, TIMER_EN_REG
        RTS
T_STOP:
        MOVE.B  #0, TIMER_EN_REG
        RTS
T_READ:
        MOVE.L  TIMER_COUNT_REG, D0
        RTS
T_IRQ_SET:
        MOVE.B  D1, TIMER_IRQ_REG
        RTS
T_IRQ_CLR:
        MOVE.B  #0, TIMER_IRQ_REG
        RTS

HAL_DATA:
        MOVE.L  D0, D1
        CMP.L   #HAL_DATA_READ_MEM, D1
        BEQ     D_READ
        CMP.L   #HAL_DATA_WRITE_MEM, D1
        BEQ     D_WRITE
        CMP.L   #HAL_DATA_COPY, D1
        BEQ     D_COPY
        CMP.L   #HAL_DATA_CONVERT, D1
        BEQ     D_CONVERT
        BRA     HAL_INVALID

D_READ:
        MOVE.L  D1, A0
        MOVE.L  D2, A1
        MOVE.L  D3, D4
D_RLOOP:
        MOVE.B  (A0)+, (A1)+
        DBRA    D4, D_RLOOP
        RTS

D_WRITE:
        MOVE.L  D1, A0
        MOVE.L  D2, A1
        MOVE.L  D3, D4
D_WLOOP:
        MOVE.B  (A0)+, (A1)+
        DBRA    D4, D_WLOOP
        RTS

D_COPY:
        MOVE.L  D1, A0
        MOVE.L  D2, A1
        MOVE.L  D3, D4
        CMP.L   A0, A1
        BCS     D_CFWD
D_CBWD:
        ADD.L   D3, A0
        ADD.L   D3, A1
D_CBWD_L:
        MOVE.B  -(A0), -(A1)
        DBRA    D4, D_CBWD_L
        RTS
D_CFWD:
D_CFWD_L:
        MOVE.B  (A0)+, (A1)+
        DBRA    D4, D_CFWD_L
        RTS

D_CONVERT:
        RTS

HAL_CONTEXT:
        MOVE.L  D0, D1
        CMP.L   #HAL_CTX_SWITCH, D1
        BEQ     C_SWITCH
        CMP.L   #HAL_CTX_SAVE, D1
        BEQ     C_SAVE
        CMP.L   #HAL_CTX_RESTORE, D1
        BEQ     C_RESTORE
        CMP.L   #HAL_CTX_CREATE_TASK, D1
        BEQ     C_CREATE
        CMP.L   #HAL_CTX_DELETE_TASK, D1
        BEQ     C_DELETE
        BRA     HAL_INVALID

C_SAVE:
        MOVE.L  A0, (D1)
        MOVE.L  A1, (D1)+4
        MOVE.L  A2, (D1)+8
        MOVE.L  A3, (D1)+12
        MOVE.L  A4, (D1)+16
        MOVE.L  A5, (D1)+20
        MOVE.L  A6, (D1)+24
        MOVE.L  D0, (D1)+28
        MOVE.L  D2, (D1)+32
        MOVE.L  D3, (D1)+36
        MOVE.L  D4, (D1)+40
        MOVE.L  D5, (D1)+44
        MOVE.L  D6, (D1)+48
        MOVE.L  D7, (D1)+52
        MOVE    SR, (D1)+56
        MOVE.L  PC, (D1)+58
        RTS

C_RESTORE:
        MOVE.L  (D1), A0
        MOVE.L  (D1)+4, A1
        MOVE.L  (D1)+8, A2
        MOVE.L  (D1)+12, A3
        MOVE.L  (D1)+16, A4
        MOVE.L  (D1)+20, A5
        MOVE.L  (D1)+24, A6
        MOVE.L  (D1)+28, D0
        MOVE.L  (D1)+32, D2
        MOVE.L  (D1)+36, D3
        MOVE.L  (D1)+40, D4
        MOVE.L  (D1)+44, D5
        MOVE.L  (D1)+48, D6
        MOVE.L  (D1)+52, D7
        MOVE    (D1)+56, SR
        JMP     (D1)+58

C_SWITCH:
        BSR     C_SAVE
        MOVE.L  D2, D1
        BSR     C_RESTORE
        RTS

C_CREATE:
        RTS
C_DELETE:
        RTS

HAL_SYSTEM:
        MOVE.L  D0, D1
        CMP.L   #HAL_SYS_RESET, D1
        BEQ     S_RESET
        CMP.L   #HAL_SYS_POWER_OFF, D1
        BEQ     S_POWEROFF
        CMP.L   #HAL_SYS_POWER_ON, D1
        BEQ     S_POWERON
        CMP.L   #HAL_SYS_HALT, D1
        BEQ     S_HALT
        BRA     HAL_INVALID

S_RESET:
        MOVE.L  #$00080000, SP
        LEA     $00080000, A0
        MOVE.L  #$00080000/4, D0
S_CLR:
        MOVE.L  #0, (A0)+
        DBRA    D0, S_CLR
        JMP     $00000080

S_POWEROFF:
        MOVE.B  #1, POWER_REG
        RTS
S_POWERON:
        MOVE.B  #0, POWER_REG
        RTS
S_HALT:
        STOP    #$2700

HAL_MOUSE:
        MOVE.L  D0, D1
        CMP.L   #HAL_MOUSE_SET_SHAPE, D1
        BEQ     M_SHAPE
        CMP.L   #HAL_MOUSE_SET_HOTSPOT, D1
        BEQ     M_HOTSPOT
        CMP.L   #HAL_MOUSE_SHOW, D1
        BEQ     M_SHOW
        CMP.L   #HAL_MOUSE_HIDE, D1
        BEQ     M_HIDE
        CMP.L   #HAL_MOUSE_WARP, D1
        BEQ     M_WARP
        CMP.L   #HAL_MOUSE_DRAW_LINE, D1
        BEQ     M_LINE
        CMP.L   #HAL_MOUSE_DRAW_RECT, D1
        BEQ     M_RECT
        CMP.L   #HAL_MOUSE_DRAW_COPY, D1
        BEQ     M_COPY
        CMP.L   #HAL_MOUSE_GET_POS, D1
        BEQ     M_GETPOS
        CMP.L   #HAL_MOUSE_SET_SCALE, D1
        BEQ     M_SCALE
        BRA     HAL_INVALID

M_SHAPE:
        MOVE.B  D1, MOUSE_SHAPE_REG
        RTS
M_HOTSPOT:
        MOVE.W  D1, MOUSE_HOT_X_REG
        MOVE.W  D2, MOUSE_HOT_Y_REG
        RTS
M_SHOW:
        MOVE.B  #1, MOUSE_VIS_REG
        RTS
M_HIDE:
        MOVE.B  #0, MOUSE_VIS_REG
        RTS
M_WARP:
        MOVE.W  D1, MOUSE_X_REG
        MOVE.W  D2, MOUSE_Y_REG
        RTS
M_LINE:
        MOVE.W  D1, GFX_LX1_REG
        MOVE.W  D2, GFX_LY1_REG
        MOVE.W  D3, GFX_LX2_REG
        MOVE.W  D4, GFX_LY2_REG
        MOVE.B  D5, GFX_LC_REG
        MOVE.B  #1, GFX_LT_REG
        RTS
M_RECT:
        MOVE.W  D1, GFX_RX_REG
        MOVE.W  D2, GFX_RY_REG
        MOVE.W  D3, GFX_RW_REG
        MOVE.W  D4, GFX_RH_REG
        MOVE.B  D5, GFX_RC_REG
        MOVE.B  D6, GFX_RF_REG
        MOVE.B  #1, GFX_RT_REG
        RTS
M_COPY:
        MOVE.W  D1, GFX_BX_REG
        MOVE.W  D2, GFX_BY_REG
        MOVE.W  D3, GFX_BDX_REG
        MOVE.W  D4, GDK_BDY_REG
        MOVE.W  D5, GFX_BW_REG
        MOVE.W  D6, GFX_BH_REG
        MOVE.B  #1, GFX_BT_REG
        RTS
M_GETPOS:
        MOVE.W  MOUSE_X_REG, D0
        MOVE.W  MOUSE_Y_REG, D1
        MOVE.B  MOUSE_BTN_REG, D2
        RTS
M_SCALE:
        MOVE.W  D1, MOUSE_SC_X_REG
        MOVE.W  D2, MOUSE_SC_Y_REG
        RTS

HAL_FRAMEBUFFER:
        MOVE.L  D0, D1
        CMP.L   #HAL_FB_CLEAR, D1
        BEQ     F_CLEAR
        CMP.L   #HAL_FB_SET_COLOR, D1
        BEQ     F_COLOR
        CMP.L   #HAL_FB_PLOT_CHAR, D1
        BEQ     F_PCHAR
        CMP.L   #HAL_FB_SET_CURSOR, D1
        BEQ     F_CURSOR
        CMP.L   #HAL_FB_SCROLL, D1
        BEQ     F_SCROLL
        CMP.L   #HAL_FB_PLOT_PIXEL, D1
        BEQ     F_PPIXEL
        CMP.L   #HAL_FB_GET_PIXEL, D1
        BEQ     F_GPIXEL
        CMP.L   #HAL_FB_PLOT_BITMAP, D1
        BEQ     F_PBITMAP
        BRA     HAL_INVALID

F_CLEAR:
        LEA     FB_BASE, A0
        MOVE.L  #480000, D2
F_CLOOP:
        MOVE.B  D1, (A0)+
        DBRA    D2, F_CLOOP
        RTS

F_COLOR:
        LEA     PALETTE_BASE, A0
        ADD.L   D1, A0
        ADD.L   D1, A0
        ADD.L   D1, A0
        MOVE.B  D2, (A0)+
        MOVE.B  D3, (A0)+
        MOVE.B  D4, (A0)
        RTS

F_PCHAR:
        MOVE.L  D3, D5
        LSL.L   #3, D5
        LEA     FONT_ROM_BASE, A0
        ADD.L   D5, A0
        MOVE.L  D2, D5
        MULU    #800, D5
        ADD.L   D1, D5
        LEA     FB_BASE, A1
        MOVEQ   #7, D6   ; Row loop counter
F_PROW:
        MOVE.B  (A0)+, D7
        MOVEQ   #7, D5   ; Column loop counter (Use D5 instead of D8)
F_PCOL:
        LSL.B   #1, D7
        BCC     F_SKIP
        MOVE.B  D4, (A1)
F_SKIP:
        ADDQ.L  #1, A1
        DBRA    D5, F_PCOL ; Use D5
        ADD.L   #792, A1
        DBRA    D6, F_PROW
        RTS

F_CURSOR:
        MOVE.W  D1, $00FF0070
        MOVE.W  D2, $00FF0072
        MOVE.B  D3, $00FF0074
        RTS

F_SCROLL:
        RTS

F_PPIXEL:
        MOVE.L  D2, D4
        MULU    #800, D4
        ADD.L   D1, D4
        LEA     FB_BASE, A0
        ADD.L   D4, A0
        MOVE.B  D3, (A0)
        RTS

F_GPIXEL:
        MOVE.L  D2, D3
        MULU    #800, D3
        ADD.L   D1, D3
        LEA     FB_BASE, A0
        ADD.L   D3, A0
        MOVE.B  (A0), D0
        RTS

F_PBITMAP:
        RTS

HAL_BLOCKDEV:
        MOVE.L  D0, D1
        CMP.L   #HAL_BLK_READ, D1
        BEQ     B_READ
        CMP.L   #HAL_BLK_WRITE, D1
        BEQ     B_WRITE
        CMP.L   #HAL_BLK_INIT, D1
        BEQ     B_INIT
        CMP.L   #HAL_BLK_STATUS, D1
        BEQ     B_STATUS
        CMP.L   #HAL_BLK_SEEK, D1
        BEQ     B_SEEK
        BRA     HAL_INVALID

B_INIT:
        MOVE.B  #$01, HDD_CMD_REG
B_IWAIT:
        BTST    #0, HDD_STATUS_REG
        BEQ     B_IWAIT
        RTS

B_READ:
        MOVE.W  D1, HDD_SECTOR_LO
        MOVE.B  #$20, HDD_CMD_REG
B_RWAIT:
        BTST    #0, HDD_STATUS_REG
        BEQ     B_RWAIT
        LEA     HDD_DATA_REG, A0
        MOVE.L  D2, A1
        MOVEQ   #0, D3
B_RCOPY:
        MOVE.B  (A0), (A1)+
        ADDQ.L  #1, D3
        CMPI    #512, D3
        BLT     B_RCOPY
        RTS

B_WRITE:
        MOVE.W  D1, HDD_SECTOR_LO
        LEA     HDD_DATA_REG, A0
        MOVE.L  D2, A1
        MOVEQ   #0, D3
B_WCOPY:
        MOVE.B  (A1)+, (A0)
        ADDQ.L  #1, D3
        CMPI    #512, D3
        BLT     B_WCOPY
        MOVE.B  #$30, HDD_CMD_REG
B_WWAIT:
        BTST    #0, HDD_STATUS_REG
        BEQ     B_WWAIT
        RTS

B_STATUS:
        MOVE.B  HDD_STATUS_REG, D0
        RTS

B_SEEK:
        MOVE.W  D1, HDD_SECTOR_LO
        RTS

HAL_INVALID:
        MOVEQ   #-1, D0
        RTS

HAL_RESERVED:
        STOP    #$2700

        END   

; ===== PALETTE DATA TABLE =====
VGA_PALETTE_DATA:
        DC.B    $00,$00,$00, $00,$00,$AA, $00,$AA,$00, $00,$AA,$AA ; 0-3
        DC.B    $AA,$00,$00, $AA,$00,$AA, $AA,$55,$00, $AA,$AA,$AA ; 4-7
        DC.B    $55,$55,$55, $55,$55,$FF, $55,$FF,$55, $55,$FF,$FF ; 8-11
        DC.B    $FF,$55,$55, $FF,$55,$FF, $FF,$FF,$55, $FF,$FF,$FF ; 12-15

        END        