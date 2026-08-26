; autoboot.asm - Simple autoboot bootstrap for 68000
; Assembles to binary and loads at ROM_BASE (0x00000000)

        ORG     0x00000000

; Vector Table
        DC.L    0x00080000      ; Initial Stack Pointer (top of RAM)
        DC.L    BOOT_START      ; Initial PC (reset vector)
        DC.L    BOOT_START      ; Bus error
        DC.L    BOOT_START      ; Address error
        DC.L    BOOT_START      ; Illegal instruction
        DC.L    BOOT_START      ; Divide by zero
        DC.L    BOOT_START      ; TRAP vector (reserved for shell)
        DC.L    BOOT_START      ; Other exceptions...

        ORG     0x00000080

BOOT_START:
        ; Initialize stack pointer
        MOVE.L  #0x00080000, SP
        
        ; Initialize virtual HDD
        MOVE.B  #HDD_CMD_INIT, HDD_CMD_REG
        WAIT_HDD:
            BTST    #0, HDD_STATUS_REG
            BEQ     WAIT_HDD
        
        ; Load boot sector (sector 0) from HDD to RAM
        MOVE.W  #0, HDD_SECTOR_LO       ; Sector 0
        MOVE.B  #HDD_CMD_READ, HDD_CMD_REG
        WAIT_READ:
            BTST    #0, HDD_STATUS_REG
            BEQ     WAIT_READ
        
        ; Copy sector buffer to RAM at 0x00040000
        LEA     HDD_DATA_REG, A0
        LEA     0x00040000, A1
        MOVEQ   #0, D0
        COPY_LOOP:
            MOVE.B  (A0), (A1)+
            ADDQ.L  #1, D0
            CMPI    #512, D0
            BLT     COPY_LOOP
        
        ; Jump to loaded shell code
        MOVE.L  #0x00040000, A0
        JMP     (A0)

; I/O Register Addresses
HDD_CMD_REG     EQU     0x00FF0010
HDD_DATA_REG    EQU     0x00FF0011
HDD_STATUS_REG  EQU     0x00FF0012
HDD_SECTOR_LO   EQU     0x00FF0013
HDD_SECTOR_HI   EQU     0x00FF0014

; HDD Commands
HDD_CMD_INIT    EQU     0x01
HDD_CMD_READ    EQU     0x20
HDD_CMD_WRITE   EQU     0x30

        END   