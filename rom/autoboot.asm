; autoboot.asm - Minimal bootstrap, loads system.rom from HDD
; Assembles to: rom/autoboot.bin (loaded at 0x00000000)

        ORG     0x00000000

; Vector Table - all point to bootstrap (safe)
        DC.L    0x00080000      ; 0x00: Initial SP
        DC.L    BOOT_START      ; 0x04: Reset
        DC.L    BOOT_START      ; 0x08: Bus Error
        DC.L    BOOT_START      ; 0x0C: Address Error
        DC.L    BOOT_START      ; 0x10: Illegal Instr
        DC.L    BOOT_START      ; 0x14: Divide by Zero
        DC.L    BOOT_START      ; 0x18: CHK
        DC.L    BOOT_START      ; 0x1C: TRAPV
        DC.L    BOOT_START      ; 0x20: Priv Viol
        DC.L    BOOT_START      ; 0x24: Trace
        DC.L    BOOT_START      ; 0x28: Line A
        DC.L    BOOT_START      ; 0x2C: Line F
        DC.L    BOOT_START      ; 0x30-0x7C: Unused
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

        ORG     0x00000080

BOOT_START:
        MOVE.L  #0x00080000, SP

        ; 1. Initialize HDD
        MOVE.B  #0x01, 0x00FF0010      ; HDD_CMD_INIT
WAIT_HDD:
        BTST    #0, 0x00FF0012         ; Check ready
        BEQ     WAIT_HDD

        ; 2. Load sector 0 (system.rom)
        MOVE.W  #0, 0x00FF0013         ; Sector 0
        MOVE.B  #0x20, 0x00FF0010      ; HDD_CMD_READ
WAIT_READ:
        BTST    #0, 0x00FF0012
        BEQ     WAIT_READ

        ; 3. Copy 512 bytes from HDD buffer to RAM (0x00040000)
        LEA     0x00FF0011, A0         ; HDD data buffer
        LEA     0x00040000, A1         ; Destination in RAM
        MOVEQ   #0, D0
COPY_LOOP:
        MOVE.B  (A0)+, (A1)+
        ADDQ.L  #1, D0
        CMPI    #512, D0
        BLT     COPY_LOOP

        ; 4. Jump to system.rom in RAM
        JMP     0x00040000

        END   