; =============================================================================
; Gordon Brandly's 68000 Tiny BASIC - Sisällytetty versio
; =============================================================================

    ; KORJATTU: Ei org-määritystä tässä,jatketaan suoraan monitorin perään!

START_BASIC:
    move.l  #$00100000,sp      ; Varmistetaan pinon paikka
    
    ; Alustetaan BASIC-koodialueen osoittimet
    lea     TXT_START,a0
    move.l  a0,tx_start_ptr
    lea     TXT_START,a1
    move.l  a1,tx_end_ptr      

    ; Tulostetaan käynnistysviesti
    lea     INIT_MSG,a0
    bsr     print_string_tb

.prompt_loop:
    lea     READY_MSG,a0
    bsr     print_string_tb

    ; Luetaan käyttäjän syöte puskuriin
    lea     INPUT_BUFFER,a0
    bsr     get_line_tb

    ; Jäsennetään syöte
    lea     INPUT_BUFFER,a0
    bsr     skip_spaces
    move.b  (a0),d0
    beq     .prompt_loop        

    cmp.b   #'0',d0
    blt     .handle_command
    cmp.b   #'9',d0
    ble     .handle_line_number

.handle_command:
    lea     CMD_HELP,a1
    bsr     compare_string
    beq     .do_help

    lea     CMD_LIST,a1
    bsr     compare_string
    beq     .do_list

    lea     CMD_SAVE,a1
    bsr     compare_string
    beq     .do_save

    lea     CMD_LOAD,a1
    bsr     compare_string
    beq     .do_load

    lea     CMD_NEW,a1
    bsr     compare_string
    beq     .do_new

    lea     SYNTAX_ERR,a0
    bsr     print_string_tb
    bra     .prompt_loop

.do_help:
    lea     HELP_TEXT,a0
    bsr     print_string_tb
    bra     .prompt_loop

.do_new:
    move.l  tx_start_ptr,d0
    move.l  d0,tx_end_ptr      
    move.l  d0,a0
    move.b  #0,(a0)            
    bra     .prompt_loop

.do_save:
    lea     SAVE_MSG,a0
    bsr     print_string_tb
    moveq   #0,d0              
    move.l  tx_start_ptr,a0    
    bsr     HDD_WRITE_SECTOR    
    tst.b   d0                  
    bne     .disk_error
    lea     OK_MSG,a0
    bsr     print_string_tb
    bra     .prompt_loop

.do_load:
    lea     LOAD_MSG,a0
    bsr     print_string_tb
    moveq   #0,d0              
    move.l  tx_start_ptr,a0    
    bsr     HDD_READ_SECTOR     
    tst.b   d0                  
    bne     .disk_error

    move.l  tx_start_ptr,a0
    move.w  #511,d1
.find_end:
    tst.b   (a0)+
    beq     .end_found
    dbra    d1,.find_end
.end_found:
    subq.l  #1,a0
    move.l  a0,tx_end_ptr      
    lea     OK_MSG,a0
    bsr     print_string_tb
    bra     .prompt_loop

.disk_error:
    lea     DISK_ERR_MSG,a0
    bsr     print_string_tb
    bra     .prompt_loop

.do_list:
    move.l  tx_start_ptr,a0
    move.l  tx_end_ptr,a1
    cmp.l   a0,a1
    beq     .list_empty         
.list_loop:
    cmp.l   a1,a0
    bge     .prompt_loop
    move.b  (a0)+,d0
    beq     .prompt_loop        
    bsr     OUTCH
    bra     .list_loop
.list_empty:
    bra     .prompt_loop

.handle_line_number:
    move.l  tx_end_ptr,a1
    lea     INPUT_BUFFER,a0
.copy_line:
    move.b  (a0)+,d0
    move.b  d0,(a1)+
    cmp.b   #13,d0
    bne     .copy_line
    
    subq.l  #1,a1
    move.b  #13,(a1)+
    move.b  #10,(a1)+
    move.b  #0,(a1)            
    move.l  a1,tx_end_ptr      
    bra     .prompt_loop

print_string_tb:
    move.b  (a0)+,d0
    beq     .msg_done
    bsr     OUTCH
    bra     print_string_tb
.msg_done:
    rts

get_line_tb:
    move.l  a0,a2              
.get_char:
    bsr     INCH
    cmp.b   #8,d0              
    beq     .backspace
    cmp.b   #13,d0             
    beq     .line_end
    move.b  d0,(a2)+
    bsr     OUTCH               
    bra     .get_char
.backspace:
    cmp.l   a0,a2              
    beq     .get_char
    subq.l  #1,a2
    move.b  #8,d0
    bsr     OUTCH               
    bra     .get_char
.line_end:
    move.b  #13,(a2)+          
    move.b  #10,(a2)+          
    move.b  #0,(a2)            
    move.b  #13,d0
    bsr     OUTCH
    move.b  #10,d0
    bsr     OUTCH               
    rts

skip_spaces:
    cmp.b   #' ',(a0)
    bne     .skip_done
    addq.l  #1,a0
    bra     skip_spaces
.skip_done:
    rts

compare_string:
    move.l  a0,a2
.comp_loop:
    move.b  (a1)+,d1
    beq     .comp_match         
    move.b  (a2)+,d2
    cmp.b   d1,d2
    beq     .comp_loop
    moveq   #1,d0
    rts
.comp_match:
    moveq   #0,d0              
    rts

INIT_MSG:   dc.b    13,10,"68000 TINY BASIC v1.1 (Lohkolevyllinen)",13,10
            dc.b    "Kirjoita HELP listataksesi komennot.",13,10,0
READY_MSG:  dc.b    "Ready",13,10,0
SYNTAX_ERR: dc.b    "Syntax Error!",13,10,0
DISK_ERR_MSG: dc.b  "Kiintolevyvirhe sektorilla 0!",13,10,0
SAVE_MSG:   dc.b    "Tallennetaan ohjelmaa lohkolle 0... ",0
LOAD_MSG:   dc.b    "Ladataan ohjelmaa lohkolta 0... ",0
OK_MSG:     dc.b    "OK.",13,10,0

HELP_TEXT:  dc.b    13,10,"Tuetut komennot:",13,10
            dc.b    "  HELP - Nayttaa taman listan",13,10
            dc.b    "  LIST - Tulostaa BASIC-ohjelman",13,10
            dc.b    "  NEW  - Tyhjentaa muistin",13,10
            dc.b    "  SAVE - Tallentaa ohjelman lohkolle 0",13,10
            dc.b    "  LOAD - Lataa ohjelman lohkolta 0",13,10,0

CMD_HELP:   dc.b    "HELP",0
CMD_LIST:   dc.b    "LIST",0
CMD_SAVE:   dc.b    "SAVE",0
CMD_LOAD:   dc.b    "LOAD",0
CMD_NEW:    dc.b    "NEW",0

            align   2
tx_start_ptr: dc.l  0
tx_end_ptr:   dc.l  0

INPUT_BUFFER: equ   $00003000   
TXT_START:    equ   $00004000   
