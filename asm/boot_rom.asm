; =============================================================================
; M68K COLD START ROM MONITOR & CP/M BOOTLOADER
; =============================================================================

    org     $00000000           ; ROM alkaa absoluuttisesta nollasta

    dc.l    $00100000           ; Osoite 0: Initial SP (1MB RAM loppu)
    dc.l    cold_start          ; Osoite 4: Initial PC (Hyppy käynnistykseen)

; =============================================================================
; Laitteistomääritykset (MMIO Rekisterit C-emulaattorilta)
; =============================================================================
IO_STATUS     equ     $00F00000   
IO_DATA       equ     $00F00004   
HDD_COMMAND   equ     $00F00100   
HDD_STATUS    equ     $00F00101   
HDD_SECTOR    equ     $00F00102   
HDD_DMA_ADDR  equ     $00F00108   

; CP/M 68K Moduulien kohdeosoitteet RAM-muistissa
CCP_ADDR      equ     $0000C000   
BDOS_ADDR     equ     $0000E000   
BIOS_ADDR     equ     $0000FA00   

; BIOS-hyppytaulukon sisäiset etäisyydet (Varmistetaan yhteensopivuus)
BIOS_READ     equ     $0000FA24   ; BIOS hyppytaulukon paikka +36
BIOS_WRITE    equ     $0000FA28   ; BIOS hyppytaulukon paikka +40

; =============================================================================
; Cold Boot -Käynnistyspiste
; =============================================================================
    org     $00001000           ; Pakotetaan monitorikoodi osoitteeseen $1000
cold_start:
    ; 1. Tulostetaan käynnistysilmoitus ruudulle
    lea     INIT_MSG,a0
    bsr     print_string

    ; 2. Avataan virtuaalinen kiintolevy (HDD_COMMAND = 1)
    move.b  #1,HDD_COMMAND
    tst.b   HDD_STATUS
    bne     .hdd_error          ; Jos status ei ole 0, levyä ei löydy

    ; 3. Ladataan komentotulkki CCP (Sektorit 0-2 -> osoitteeseen $C000)
    lea     LOAD_CCP_MSG,a0
    bsr     print_string
    
    move.l  #0,d0               ; Aloitetaan kiintolevyn sektorista 0
    lea     CCP_ADDR,a0         ; Kohdeosoite RAM-muistissa
    move.l  #3,d1               ; Luetaan 3 sektoria (1536 tavua)
    bsr     read_multiple_sectors
    tst.b   d0
    bne     .read_error

    ; 4. Ladataan ydin BDOS (Sektorit 3-6 -> osoitteeseen $E000)
    lea     LOAD_BDOS_MSG,a0
    bsr     print_string
    
    move.l  #3,d0               ; Aloitetaan kiintolevyn sektorista 3
    lea     BDOS_ADDR,a0        ; Kohdeosoite RAM-muistissa
    move.l  #4,d1               ; Luetaan 4 sektoria (2048 tavua)
    bsr     read_multiple_sectors
    tst.b   d0
    bne     .read_error

    ; 5. Ladataan ajurit BIOS (Sektorit 7-9 -> osoitteeseen $FA00)
    lea     LOAD_BIOS_MSG,a0
    bsr     print_string
    
    move.l  #7,d0               ; Aloitetaan kiintolevyn sektorista 7
    lea     BIOS_ADDR,a0        ; Kohdeosoite RAM-muistissa
    move.l  #3,d1               ; Luetaan 3 sektoria (1536 tavua)
    bsr     read_multiple_sectors
    tst.b   d0
    bne     .read_error

    ; 6. Ketjutus (Bootstrapping): Hyppy suoraan CP/M BIOS-alustukseen!
    lea     JUMP_MSG,a0
    bsr     print_string
    
    jmp     BIOS_ADDR           ; Luovutetaan kontrolli lopullisesti CP/M:lle

; --- Virheenkäsittely ---
.hdd_error:
    lea     ERR_NO_HDD,a0
    bsr     print_string
    bra     .halt

.read_error:
    lea     ERR_READ_FAIL,a0
    bsr     print_string
    bra     .halt

.halt:
    lea     HALT_MSG,a0
    bsr     print_string
.loop:
    bra     .loop               ; Jäädään ikuiseen silmukkaan, jos käynnistys epäonnistui

; =============================================================================
; Kiintolevyn matalan tason I/O-alirutiinit
; =============================================================================
read_multiple_sectors:
    movem.l d0-d1/a0,-(sp)      ; Suojataan muuttuvat rekisterit pinoon talteen
.sector_loop:
    move.l  d0,HDD_SECTOR       ; Kerrotaan ohjaimelle haettava sektori
    move.l  a0,HDD_DMA_ADDR     ; Kerrotaan kohdeosoite RAM-muistissa
    move.b  #2,HDD_COMMAND      ; Komento 2: LUE SEKTORI
    
    tst.b   HDD_STATUS          ; Tarkistetaan onnistuiko luku (0 = OK)
    bne     .done_read_err
    
    addq.l  #1,d0               ; Siirrytään seuraavaan sektoriin
    lea     512(a0),a0          ; Siirretään RAM-osoitepuskuria 512 tavua eteenpäin
    subq.l  #1,d1               ; Vähennetään jäljellä olevien sektorien määrää
    bne     .sector_loop
    
    movem.l (sp)+,d0-d1/a0      ; Palautetaan alkuperäiset rekisterit pinosta
    move.l  #0,d0               ; Palautetaan 0 (Luku onnistui)
    rts
.done_read_err:
    movem.l (sp)+,d0-d1/a0      ; Siivotaan pino virhetilanteessa
    move.l  #1,d0               ; Palautetaan 1 (Luku epäonnistui)
    rts

HDD_READ_SECTOR:
    move.l  d0,HDD_SECTOR      
    move.l  a0,HDD_DMA_ADDR    
    move.b  #2,HDD_COMMAND     
    move.b  HDD_STATUS,d0      
    rts

print_string:
    move.b  (a0)+,d0
    beq     .done
    bsr     OUTCH
    bra     print_string
.done:
    rts

OUTCH:
    move.b  d1,-(sp)
.wait_tx:
    move.b  IO_STATUS,d1       
    andi.b  #$02,d1            
    beq     .wait_tx            
    move.b  d0,IO_DATA         
    move.b  (sp)+,d1
    rts

; =============================================================================
; Merkkijonot (Puhtaana ASCII-datana ilman skandeja)
; =============================================================================
INIT_MSG:
    dc.b    13,10,"--- TEHO68K COLD START MONITOR v2.5 ---",13,10
    dc.b    "ALUSTETAAN LAITTEISTO... VALMIS.",13,10,0
LOAD_CCP_MSG:
    dc.b    "LUETAAN CCP... ",0
LOAD_BDOS_MSG:
    dc.b    "OK.",13,10,"LUETAAN BDOS... ",0
LOAD_BIOS_MSG:
    dc.b    "OK.",13,10,"LUETAAN BIOS... ",0
JUMP_MSG:
    dc.b    "OK.",13,10,"SIIRRYTAAN CP/M KAYTTOJARJESTELMAAN...",13,10,13,10,0
ERR_NO_HDD:
    dc.b    "VIRHE: VIRTUAALILEVYA EI LOYDY KANSIOSTA HDD/!",13,10,0
ERR_READ_FAIL:
    dc.b    "VIRHE: SEKTORIN LUKEMINEN EPAONNISTUI!",13,10,0
HALT_MSG:
    dc.b    "JARJESTELMA PYSAYTETTY.",13,10,0

    align   2
