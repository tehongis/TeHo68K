; =============================================================================
; CP/M 68K CCP - Konsolikomentotulkki
; =============================================================================
    org     $0000C000           ; CCP alkaa osoitteesta $C000

    xdef    CCP_START
CCP_START:
    ; Alustetaan pino CCP:lle varmuuden vuoksi
;    lea     $0000BF00,sp

.prompt_loop:
    ; 1. Tulostetaan CP/M komentokehote "A>"
    move.l  #9,d0               ; BDOS Funktio 9 (Print String)
    lea     PROMPT_STR,a0
    jsr     $0000E000           ; Kutsutaan BDOS_ENTRY
    
    ; 2. Luetaan käyttäjän syöte puskuriin
    lea     CMD_BUFFER,a1
    move.l  #0,d2               ; Merkkilaskuri = 0

.read_loop:
    move.l  #1,d0               ; BDOS Funktio 1 (Console Input)
    jsr     $0000E000           ; Luetaan merkki D0:aan
    
    cmpi.b  #13,d0              ; Enter / Carriage Return?
    beq     .execute_cmd
    
    cmpi.b  #8,d0               ; Backspace?
    beq     .handle_backspace

    ; Tallennetaan merkki puskuriin jos se mahtuu (max 32 merkkiä)
    cmpi.l  #31,d2
    bge     .read_loop
    move.b  d0,(a1)+
    addq.l  #1,d2
    bra     .read_loop

.handle_backspace:
    tst.l   d2
    beq     .read_loop          ; Puskuri tyhjä, ei voi poistaa
    subq.l  #1,d2
    subq.l  #1,a1
    bra     .read_loop

.execute_cmd:
    move.b  #'$',(a1)+          ; BDOS 9:ää varten
    move.b  #0,(a1)             ; strcmp:tä varten
    
    move.l  #2,d0               ; Rivinvaihto
    move.l  #10,d1              
    jsr     $0000E000

    tst.l   d2
    beq     .prompt_loop  

    ; --- Komentovertailut ---
    lea     CMD_BUFFER,a0
    lea     CMD_CLS,a1
    bsr     strcmp
    beq     .do_cls

    lea     CMD_BUFFER,a0
    lea     CMD_DIR,a1
    bsr     strcmp
    beq     .do_dir

    lea     CMD_BUFFER,a0
    lea     CMD_HELP,a1
    bsr     strcmp
    beq     .do_help

    ; Tuntematon komento, tulostetaan "Tuntematon komento" -viesti
    move.l  #9,d0
    lea     CMD_BUFFER,a0       ; Tulostetaan virheellinen komento pohjalle
    jsr     $0000E000
    move.l  #9,d0
    lea     ERR_STR,a0
    jsr     $0000E000
    bra     .prompt_loop

.do_cls:
    ; Tyhjennetään ruutu tulostamalla tarpeeksi rivinvaihtoja emulaattorille
    move.l  #0,d3
.cls_loop:
    move.l  #2,d0
    move.l  #10,d1
    jsr     $0000E000
    addq.l  #1,d3
    cmpi.l  #40,d3              ; GRID_ROWS verran rivinvaihtoja
    blt     .cls_loop
    bra     .prompt_loop

.do_dir:
    move.l  #9,d0
    lea     DIR_STR,a0
    jsr     $0000E000
    bra     .prompt_loop

.do_help:
    move.l  #9,d0
    lea     HELP_STR,a0
    jsr     $0000E000
    bra     .prompt_loop

; --- Apualirutiini merkkijonojen vertailuun ---
strcmp:
.loop:
    move.b  (a0)+,d0
    move.b  (a1)+,d1
    cmp.b   d0,d1
    bne     .diff
    tst.b   d0
    bne     .loop
    move.l  #0,d0               ; Samoissa päädyttiin nollaan = täsmää (Z=1)
    rts
.diff:
    move.l  #1,d0               ; Eroavaisuus löydetty (Z=0)
    rts

; --- Data-alue ---
    align   2
PROMPT_STR:  dc.b    13,10,"A>$"         ; KORJATTU: Päättyy dollariin!
ERR_STR:     dc.b    "?",13,10,"$"       ; KORJATTU: Päättyy dollariin!
CMD_CLS:     dc.b    "cls","$"
CMD_DIR:     dc.b    "dir","$"
CMD_HELP:    dc.b    "help","$"

DIR_STR:
    dc.b    "A: CCP      SYS : BDOS     SYS : BIOS     SYS",13,10,"$"
    dc.b    "A: TINYBASICCOM : M68KBOOT COM",13,10,"$"

HELP_STR:
    dc.b    "TEHO68K CP/M EMULAATTORI KOMENNOT:",13,10,"$"
    dc.b    "  help - Nayta tama viesti",13,10,"$"
    dc.b    "  cls  - Tyhjenna ruutu",13,10,"$"
    dc.b    "  dir  - Listaa levykkeen sisalto",13,10,"$"

    align   2
CMD_BUFFER:  ds.b    34         ; 32 tavua komentopuskuria + nollatavu
