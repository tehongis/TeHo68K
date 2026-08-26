; autoboot.asm - Minimal bootstrap, loads system.rom from HDD
; Assembles to: rom/autoboot.bin (loaded at $00000000)

        ORG     $00000000

; Vector Table - all point to bootstrap (safe)
        DC.L    $00080000 ; $00 Initial SP
        DC.L    BOOT_START ; $04 Reset
        DC.L    BOOT_START ; $08 Bus Error
        DC.L    BOOT_START ; $0C Address Error
        DC.L    BOOT_START ; $10 Illegal Instr
        DC.L    BOOT_START ; $14 Divide by Zero
        DC.L    BOOT_START ; $18 CHK
        DC.L    BOOT_START ; $1C TRAPV
        DC.L    BOOT_START ; $20 Priv Viol
        DC.L    BOOT_START ; $24 Trace
        DC.L    BOOT_START ; $28 Line A
        DC.L    BOOT_START ; $2C Line F
        DC.L    BOOT_START ; $30-$7C: Unused
        DC.L    BOOT_START
        DC.L    BOOT_START
        DC.L    BOOT_START
        DC.L    BOOT_START
        DC.L    BOOT_START
        DC.L    BOOT_START
        DC.L    BOOT_START
        DC.L    BOOT_START
        DC.L    BOOT_START
        DC.L    BOOT_START
        DC.L    BOOT_START
        DC.L    BOOT_START
        DC.L    BOOT_START
        DC.L    BOOT_START
        DC.L    BOOT_START
        DC.L    BOOT_START
        DC.L    BOOT_START
        DC.L    BOOT_START
        DC.L    BOOT_START
        DC.L    BOOT_START
        DC.L    BOOT_START
        DC.L    BOOT_START
        DC.L    BOOT_START
        DC.L    BOOT_START
        DC.L    BOOT_START
        DC.L    BOOT_START
        DC.L    BOOT_START
        DC.L    BOOT_START
        DC.L    BOOT_START
        DC.L    BOOT_START
        DC.L    BOOT_START
        DC.L    BOOT_START
        DC.L    BOOT_START
        DC.L    BOOT_START
        DC.L    BOOT_START
        DC.L    BOOT_START
        DC.L    BOOT_START
        DC.L    BOOT_START
        DC.L    BOOT_START
        DC.L    BOOT_START
        DC.L    BOOT_START
        DC.L    BOOT_START
        DC.L    BOOT_START
        DC.L    BOOT_START
        DC.L    BOOT_START
        DC.L    BOOT_START
        DC.L    BOOT_START
        DC.L    BOOT_START

        ORG     $00001000

BOOT_START:
        MOVE.L  #$00080000, SP

        ; 1. Initialize HDD
        MOVE.B  #$01, $00FF0010      ; HDD_CMD_INIT
WAIT_HDD:
        BTST    #0, $00FF0012         ; Check ready
        BEQ     WAIT_HDD

        ; 2. Load sector 0 (system.rom)
        MOVE.W  #0, $00FF0013         ; Sector 0
        MOVE.B  #$20, $00FF0010      ; HDD_CMD_READ
WAIT_READ:
        BTST    #0, $00FF0012
        BEQ     WAIT_READ

        ; 3. Copy 512 bytes from HDD buffer to RAM ($00040000)
        LEA     $00FF0011, A0         ; HDD data buffer
        LEA     $00040000, A1         ; Destination in RAM
        MOVEQ   #0, D0
COPY_LOOP:
        MOVE.B  (A0)+, (A1)+
        ADDQ.L  #1, D0
        CMPI    #512, D0
        BLT     COPY_LOOP

        ; 4. Jump to system.rom in RAM
        JMP     $00040000

        END   