; =============================================================================
; autoboot.asm - Minimal bootstrap, loads system.rom from HDD
; Assembles to: rom/autoboot.bin (loaded at $00000000)
; =============================================================================
        ORG     $00000000

; Vector Table - points to bootstrap
        DC.L    $00080000       ; $00 Initial SP
        DC.L    BOOT_START      ; $04 Reset
        
        REPT    62
        DC.L    BOOT_START      ; Fill rest of vectors safely
        ENDR

        ORG     $00001000

BOOT_START:
        MOVE.L  #$00080000,SP

; 1. Initialize HDD
        MOVE.B  #$01,$00FF0010   ; HDD_CMD_REG
WAIT_HDD:
        BTST    #0,$00FF0012     ; HDD_STATUS_REG
        BEQ     WAIT_HDD

; 2. Load 32 sectors (16 KB) from HDD to RAM $00040000
        LEA     $00FF0011,A0     ; HDD_DATA_REG (Fixed IO port)
        LEA     $00040000,A1     ; Destination RAM
        MOVE.W  #0,D1            ; Start sector 0
        MOVE.W  #32,D2           ; Number of sectors to load

SECTOR_LOOP:
        MOVE.W  D1,$00FF0013     ; HDD_SECTOR_LO
        MOVE.B  #$20,$00FF0010   ; HDD_CMD_REG (Read command)

WAIT_READ:
        BTST    #0,$00FF0012     ; HDD_STATUS_REG
        BEQ     WAIT_READ

; 3. Copy 512 bytes from HDD buffer to RAM using efficient DBRA
        MOVE.W  #511,D0          ; 512 loop iterations (N-1)
COPY_LOOP:
        MOVE.B  (A0),(A1)+       ; Read from static port, post-increment RAM
        DBRA    D0,COPY_LOOP

        ADDQ.W  #1,D1            ; Next sector
        SUBQ.W  #1,D2            ; Decrement remaining sectors
        BNE     SECTOR_LOOP

; 4. Jump to system.rom entry point in RAM
        JMP     $00040000

        END
