; =============================================================================
; kernel.asm - TeHo68K Unified Kernel (Boot + HAL)
; Location: $00E00000 (Top 2MB of 16MB Address Space)
; Free RAM: $00000000 - $00DFFFFF (14 MB)
; Assemble with: vasm68k_mot -Fbin -o kernel.bin kernel.asm
; =============================================================================
        INCLUDE "HAL.i"

        ORG     $00E00000

; ===== RESET VECTOR STUB =====
; The emulator maps $00000000 to this address on reset.
ResetVector:
        DC.L    $00080000       ; Initial Stack Pointer
        DC.L    COLD_BOOT       ; Initial PC

; ===== COLD BOOT =====
COLD_BOOT:
        ; 1. Setup Stack
        MOVE.L  #$00080000, SP

        ; 2. Initialize TRAP Vectors
        MOVE.L  #HAL_MEM, $00000080
        MOVE.L  #HAL_IO, $00000084
        MOVE.L  #HAL_TIMER, $00000088
        MOVE.L  #HAL_DATA, $0000008C
        MOVE.L  #HAL_CONTEXT, $00000090
        MOVE.L  #HAL_SYSTEM, $00000094
        MOVE.L  #HAL_MOUSE, $00000098
        MOVE.L  #HAL_FRAMEBUFFER, $0000009C
        MOVE.L  #HAL_BLOCKDEV, $000000A0

        MOVE.L  #CRASH_BUS_ERROR, $00000008     ; Bus Error (Vektori 2)
        MOVE.L  #CRASH_ADDRESS_ERROR, $0000000C ; Address Error (Vektori 3)
        MOVE.L  #CRASH_ILLEGAL_INSN, $00000010  ; Illegal Instruction (Vektori 4)
        MOVE.L  #CRASH_ZERO_DIVIDE, $00000014   ; Zero Divide (Vektori 5)
        MOVE.L  #CRASH_PRIVILEGE_ERR, $00000020 ; Privilege Violation (Vektori 8)
     
        ; 3. Init Memory Manager
        LEA     $00046000, A0
        MOVE.L  #0, (A0)

        ; 4. Init Timer
        MOVE.L  #0, TIMER_PERIOD_REG
        MOVE.L  #0, TIMER_COUNT_REG
        MOVE.B  #0, TIMER_EN_REG

        ; 5. Init Framebuffer (800x600)
        MOVE.W  #800, $00FF0002
        MOVE.W  #600, $00FF0004
        MOVE.B  #8, $00FF0006

        ; 6. Init Palette
        LEA     VGA_PALETTE_DATA, A0
        LEA     PALETTE_BASE, A1
        MOVE.W  #47, D0
PAL_INIT_LOOP:
        MOVE.B  (A0)+, (A1)+
        DBRA    D0, PAL_INIT_LOOP

        ; 7. Init HDD & Load Boot Sector
        MOVE.B  #$01, HDD_CMD_REG
HDD_WAIT:
        BTST    #0, HDD_STATUS_REG
        BEQ     HDD_WAIT

        MOVE.W  #0, HDD_SECTOR_LO
        MOVE.B  #$20, HDD_CMD_REG
BOOT_WAIT:
        BTST    #0, HDD_STATUS_REG
        BEQ     BOOT_WAIT

        ; 8. The Magic Switch: Hide ROM, Enable RAM
        MOVE.B  #0, ROM_BANK_REG

        ; 9. Copy OS to RAM ($00000000)
        LEA     $00E00100, A0
        LEA     $00000000, A1
        MOVE.L  #2048, D0
BOOT_COPY:
        MOVE.B  (A0)+, (A1)+
        DBRA    D0, BOOT_COPY

        ; 10. Jump to OS
        JMP     $00000000


;--- Part 2

; =============================================================================
; HAL ROUTINES
; =============================================================================

; ----- MEMORY MANAGEMENT (TRAP #0) -----
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
        LEA     $00040000, A0
        MOVE.L  D1, D3
        ADD.L   #8, D3
MEM_ALOOP:
        MOVE.L  (A0), D4
        BEQ     MEM_AFAIL
        MOVE.L  4(A0), D5
        CMP.L   D3, D5
        BCC     MEM_AFAIL
        OR.L    #1, D5
        MOVE.L  D5, 4(A0)
        MOVE.L  A0, D0
        MOVE.L  D4, -8(A0)
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
        MOVE.L  D0, A1
MEM_CLOOP:
        MOVE.B  #0, (A1)+
        DBRA    D3, MEM_CLOOP
        MOVE.L  D1, D0
        RTS

MEM_DESTROY:
        BSR     MEM_FREE
        RTS

MEM_ORGANIZE:
        RTS

; ----- I/O (TRAP #1) -----
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

; ----- TIMER (TRAP #2) -----
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

; ----- DATA OPERATIONS (TRAP #3) -----
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

;--- Part 3

; ----- CONTEXT SWITCHING (TRAP #4) -----
; Oletukset kutsuttaessa:
;   D0 = Toimintokoodi (HAL_CTX_...)
;   A0 = Nykyisen tehtävän TCB-osoite (Save / Switch)
;   A1 = Uuden tehtävän TCB-osoite (Restore / Switch)

HAL_CONTEXT:
        CMP.L   #HAL_CTX_SWITCH, D0
        BEQ     C_SWITCH
        CMP.L   #HAL_CTX_SAVE, D0
        BEQ     C_SAVE
        CMP.L   #HAL_CTX_RESTORE, D0
        BEQ     C_RESTORE
        CMP.L   #HAL_CTX_CREATE_TASK, D0
        BEQ     C_CREATE
        CMP.L   #HAL_CTX_DELETE_TASK, D0
        BEQ     C_DELETE
        BRA     HAL_CTX_INVALID    ; Vaihdettu uniikki label

; =========================================================================
; C_SAVE: Tallentaa rekisterit A0-osoittamaan muistilohkoon (TCB)
; =========================================================================
C_SAVE:
        ; Tallennetaan kaikki yleiskäyttöiset rekisterit (D0-D7 ja A0-A6)
        ; m68k:ssa rekistereiden tallennus muistiin vaatii pelkän (A0) osoituksen
        MOVEM.L D0-D7/A0-A6, (A0)
        
        ; TRAP-kutsun tekemä alkuperäinen SR ja PC ovat pinossa (A7)
        ; Kopioidaan ne sieltä osaksi tehtävän kontekstia kiinteillä siirtymillä
        ; (15 rekisteriä * 4 tavua = 60 tavua)
        MOVE.W  (A7), 60(A0)         ; Tallenna Status Register
        MOVE.L  2(A7), 62(A0)        ; Tallenna PC (2 tavua SR:n jälkeen)
        RTS

; =========================================================================
; C_RESTORE: Palauttaa rekisterit A1-osoittamasta muistilohkosta (TCB)
; =========================================================================
C_RESTORE:
        ; Haetaan ensin tallennetut SR ja PC ja asetetaan ne pinoon,
        ; jotta tuleva RTE-käsky osaa palata oikeaan paikkaan.
        MOVE.W  60(A1), (A7)         ; Korvaa pinon SR tallennetulla arvolla
        MOVE.L  62(A1), 2(A7)        ; Korvaa pinon PC tallennetulla arvolla
        
        ; Palautetaan kaikki yleiset rekisterit TCB:stä.
        ; (A1) osoitustila (muistista rekistereihin) on m68k:ssa täysin sallittu.
        MOVEM.L (A1), D0-D7/A0-A6
        RTE                         

; =========================================================================
; C_SWITCH: Vaihtaa lennosta kontekstin vanhasta (A0) uuteen (A1)
; =========================================================================
C_SWITCH:
        ; 1. Tallennetaan nykyinen tilanne
        MOVEM.L D0-D7/A0-A6, (A0)
        MOVE.W  (A7), 60(A0)         
        MOVE.L  2(A7), 62(A0)        
        
        ; 2. Valmistellaan pino uutta tehtävää varten
        MOVE.W  60(A1), (A7)         
        MOVE.L  62(A1), 2(A7)        
        
        ; 3. Palautetaan uuden tehtävän rekisterit ja käynnistetään se
        MOVEM.L (A1), D0-D7/A0-A6
        RTE                         

; =========================================================================
; C_CREATE: Alustaa uuden tehtävän TCB-lohkon aloitusvalmiiksi
; Input: A0 = TCB osoite, A1 = Koodin aloitusosoite, A2 = Pinon loppuosoite
; =========================================================================
C_CREATE:
        ; 1. Nollataan kaikki yleiskäyttöiset datarekisterit TCB-lohkosta
        ;    (Yhteensä 8 datarekisteriä = 32 tavua)
        CLR.L   (A0)         ; D0 = 0
        CLR.L   4(A0)        ; D1 = 0
        CLR.L   8(A0)        ; D2 = 0
        CLR.L   12(A0)       ; D3 = 0
        CLR.L   16(A0)       ; D4 = 0
        CLR.L   20(A0)       ; D5 = 0
        CLR.L   24(A0)       ; D6 = 0
        CLR.L   28(A0)       ; D7 = 0

        ; 2. Alustetaan osoitinrekisterit (A0-A5 nolliksi)
        CLR.L   32(A0)       ; A0
        CLR.L   36(A0)       ; A1
        CLR.L   40(A0)       ; A2
        CLR.L   44(A0)       ; A3
        CLR.L   48(A0)       ; A4
        CLR.L   52(A0)       ; A5
        CLR.L   56(A0)       ; A6

        ; 3. Asetetaan tehtävän oma pino (A7) paikoilleen TCB-lohkoon.
        ;    Koska m68k:ssa MOVEM palauttaa myös A6:n jälkeisen muistipaikan A7:ään,
        ;    jos se olisi listassa, mutta meillä MOVEM.L (A1), D0-D7/A0-A6 ei palauta A7:ää.
        ;    HUOM: Jos haluat hallinnoida tehtäväkohtaista pinoa TCB:n kautta,
        ;    se kannattaa tallentaa TCB:n loppuun tai hoitaa käyttöjärjestelmän schedulerissa.
        ;    Laitetaan se tässä vaiheessa talteen pinon osoitteeksi, jos scheduler sitä vaatii.

        ; 4. Alustetaan valepinoon ajonaikainen SR (Status Register)
        ;    $2000 = Supervisor mode päällä, kaikki keskeytystasot sallittu.
        MOVE.W  #$2000, 60(A0)

        ; 5. Alustetaan valepinoon tehtävän koodin aloitusosoite (PC)
        MOVE.L  A1, 62(A0)
        
        RTS

; =========================================================================
; C_DELETE: Tehtävän tuhoaminen ja resurssien vapautus
; Input: A0 = TCB osoite
; =========================================================================
C_DELETE:
        ; Tässä kohtaa kutsutaan yleensä HAL_MEM_FREE (TRAP #0) -toimintoa
        ; vapauttamaan tehtävän TCB:n ja pinon viemä muisti.
        ; Esimerkki toteutuksesta, jos järjestelmä tukee dynaamista vapautusta:
        
        ; 1. Vapauta tehtävän pino (jos osoite tallennettu TCB:hen)
        ; 2. Vapauta tehtävän TCB-lohko
        
        RTS

HAL_CTX_INVALID:
        RTE                         ; Virhetilanteessa palataan keskeytyksestä


; ----- SYSTEM CONTROL (TRAP #5) -----
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

; ----- MOUSE/GFX (TRAP #6) -----
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
        MOVE.W  D4, GFX_BDY_REG
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

; ----- FRAMEBUFFER (TRAP #7) -----
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
        LSL.L   #2, D1
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
        ADD.L  D1, D5
        LEA     FB_BASE, A1
        ADD.L  D5, A1
        MOVEQ   #7, D6
F_PROW:
        MOVE.B  (A0)+, D7
        MOVEQ   #7, D5
F_PCOL:
        LSL.B   #1, D7
        BCC     F_SKIP
        MOVE.B  D4, (A1)
F_SKIP:
        ADDQ.L  #1, A1
        DBRA    D5, F_PCOL
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
        ADD.L  D1, D4
        LEA     FB_BASE, A0
        ADD.L  D4, A0
        MOVE.B  D3, (A0)
        RTS

F_GPIXEL:
        MOVE.L  D2, D3
        MULU    #800, D3
        ADD.L  D1, D3
        LEA     FB_BASE, A0
        ADD.L  D3, A0
        MOVE.B  (A0), D0
        RTS

F_PBITMAP:
        RTS

;--- Part 4

; ----- BLOCK DEVICE (TRAP #8) -----
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

; ----- ERROR HANDLERS -----
HAL_INVALID:
        MOVEQ   #-1, D0
        RTS

HAL_RESERVED:
        STOP    #$2700

CRASH_BUS_ERROR:
        MOVE.W  #2, D0
        BRA     GURU_CORE

CRASH_ADDRESS_ERROR:
        MOVE.W  #3, D0
        BRA     GURU_CORE

CRASH_ILLEGAL_INSN:
        MOVE.W  #4, D0
        BRA     GURU_CORE

CRASH_ZERO_DIVIDE:
        MOVE.W  #5, D0
        BRA     GURU_CORE

CRASH_PRIVILEGE_ERR:
        MOVE.W  #8, D0
        BRA     GURU_CORE

GURU_CORE:
        ; 1. Estetään kaikki muut keskeytykset heti
        MOVE.W  #$2700, SR

        ; 2. Otetaan kaikki talteen pinoon ennen kuin mikään rekisteri muuttuu
        MOVEM.L D0-D7/A0-A6, -(A7)

        ; 3. Värjätään tausta punaiseksi HAL_FB_SET_COLOR kautta
        MOVE.L  #HAL_FB_SET_COLOR, D0
        MOVE.L  #$00FF0000, D1          ; RGB Punainen
        TRAP    #7
        
        MOVE.L  #HAL_FB_CLEAR, D0       ; Tyhjennetään ruutu valitulla värillä
        TRAP    #7

        ; 4. Tulostetaan virheilmoitus ruudulle (rivi 2, sarake 2)
        MOVE.L  #HAL_FB_SET_CURSOR, D0
        MOVE.L  #2, D1                  ; Y-koordinaatti
        MOVE.L  #2, D2                  ; X-koordinaatti
        TRAP    #7

        ; Tulostetaan virheen tyyppi
        MOVE.L  56(A7), D1
        BSR     PRINT_HEX_BYTE          

        ; 5. Haetaan kaatunut PC osoite pinosta
        MOVE.L  62(A7), D1              ; D1 = Alkuperäinen PC
        BSR     PRINT_HEX_LONG          

        ; 6. Vilkutetaan ruutua ikuisessa silmukassa
GURU_BLINK:
        MOVE.L  #HAL_FB_SET_COLOR, D0
        MOVE.L  #$00000000, D1          ; Musta
        TRAP    #7
        MOVE.L  #HAL_FB_CLEAR, D0
        TRAP    #7
        BSR     GURU_DELAY

        MOVE.L  #HAL_FB_SET_COLOR, D0
        MOVE.L  #$00FF0000, D1          ; Punainen
        TRAP    #7
        MOVE.L  #HAL_FB_CLEAR, D0
        TRAP    #7
        BSR     GURU_DELAY

        BRA     GURU_BLINK

GURU_DELAY:
        MOVE.L  #$00080000, D7
GURU_D_LOOP:
        SUBQ.L  #1, D7
        BNE     GURU_D_LOOP
        RTS

; ----- APUOHJELMAT: Rekisterien muunnos tekstiksi -----
PRINT_HEX_LONG:
        SWAP    D1
        BSR     PRINT_HEX_WORD
        SWAP    D1
PRINT_HEX_WORD:
        ROR.W   #8, D1
        BSR     PRINT_HEX_BYTE
        ROL.W   #8, D1
PRINT_HEX_BYTE:
        ROR.B   #4, D1
        BSR     PRINT_HEX_NIBBLE
        ROL.B   #4, D1
PRINT_HEX_NIBBLE:
        MOVEM.L D0-D2, -(A7)            ; Korjattu MOVEM syntaksi
        AND.B   #$0F, D1                
        CMP.B   #10, D1
        BCS     HEX_DIGIT
        ADD.B   #7, D1                  
HEX_DIGIT:
        ADD.B   #'0', D1                
        
        MOVE.L  #HAL_FB_PLOT_CHAR, D0
        TRAP    #7
        
        MOVEM.L (A7)+, D0-D2
        RTS

; =============================================================================
; PALETTE DATA
; =============================================================================
        ALIGN   2
VGA_PALETTE_DATA:
        ; Perusvärit (Musta, Valkoinen, Punainen, Vihreä, Sininen...)
        DC.B    $00,$00,$00, $FF,$FF,$FF, $FF,$00,$00, $00,$FF,$00
        DC.B    $00,$00,$FF, $FF,$FF,$00, $FF,$00,$FF, $00,$FF,$FF
        ; Loput 40 väriä täytetään nollilla, jotta COLD_BOOT:in 48 värin silmukka on turvallinen
        DS.B    120, $00
