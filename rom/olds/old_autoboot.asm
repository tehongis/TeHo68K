        ORG     0x00000000
        DC.L    0x00080000      ; Initial SP
        DC.L    BOOT_START      ; Initial PC

        ORG     0x00000080
BOOT_START:
        MOVE.L  #0x00080000, SP
        
        ; Initialize HDD
        MOVE.B  #0x01, 0x00FF0010
WAIT_INIT:
        BTST    #0, 0x00FF0012
        BEQ     WAIT_INIT
        
        ; Load sector 0 to RAM
        MOVE.W  #0, 0x00FF0013
        MOVE.B  #0x20, 0x00FF0010
WAIT_READ:
        BTST    #0, 0x00FF0012
        BEQ     WAIT_READ
        
        ; Copy to RAM and jump
        LEA     0x00FF0011, A0
        LEA     0x00040000, A1
        MOVEQ   #0, D0
COPY_LOOP:
        MOVE.B  (A0), (A1)+
        ADDQ.L  #1, D0
        CMPI    #512, D0
        BLT     COPY_LOOP
        
        JMP     0x00040000
        END   