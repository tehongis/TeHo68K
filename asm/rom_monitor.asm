; =============================================================================
; M68K ROM Monitori - Sarjaportti-I/O & Sektoripohjainen HDD Ohjain
; =============================================================================

    org     $00000000           ; Absoluuttinen alku muistissa

    dc.l    $00100000           ; osoite 0: Initial SP (1MB RAM loppu)
    dc.l    start               ; osoite 4: Initial PC (Hyppy start-kohtaan)

; =============================================================================
; Laitteistomääritykset (Memory-Mapped I/O Rekisterit)
; =============================================================================
IO_STATUS     equ     $00F00000   
IO_DATA       equ     $00F00004   
HDD_COMMAND   equ     $00F00100   
HDD_STATUS    equ     $00F00101   
HDD_SECTOR    equ     $00F00102   
HDD_DMA_ADDR  equ     $00F00108   

IO_TIMER      equ     $00F00200   ; 32-bit millisekunnit

; =============================================================================
; Monitorin käynnistyspiste
; =============================================================================
    org     $00001000           ; Pakotetaan monitorikoodi osoitteeseen $1000
start:
    ; 1. Avataan virtuaalinen kiintolevy
    move.b  #1,HDD_COMMAND
    tst.b   HDD_STATUS
    beq     .hdd_ok
    
    lea     HDD_ERR_MSG,a0
    bsr     print_string
    bra     .boot_basic

.hdd_ok:
    lea     WELCOME_MSG,a0
    bsr     print_string

.boot_basic:
    ; 2. Siirrytään Tiny BASICiin (joka alkaa nyt heti monitorin perään)
    jmp     START_BASIC           

; =============================================================================
; Sisäiset apuohjelmat
; =============================================================================
print_string:
    move.b  (a0)+,d0
    beq     .done
    bsr     OUTCH
    bra     print_string
.done:
    rts

; =============================================================================
; Kiintolevyn Alirutiinit
; =============================================================================
HDD_READ_SECTOR:
    move.l  d0,HDD_SECTOR      
    move.l  a0,HDD_DMA_ADDR    
    move.b  #2,HDD_COMMAND     
    move.b  HDD_STATUS,d0      
    rts

HDD_WRITE_SECTOR:
    move.l  d0,HDD_SECTOR      
    move.l  a0,HDD_DMA_ADDR    
    move.b  #3,HDD_COMMAND     
    move.b  HDD_STATUS,d0      
    rts

    xdef    GET_TICKS
GET_TICKS:
    move.l  IO_TIMER,d0        ; Luetaan 32-bittinen arvo suoraan C-emulaattorilta
    rts

; =============================================================================
; Päätefunktiot
; =============================================================================

OUTCH:
    move.b  d1,-(sp)
.wait_tx:
    move.b  IO_STATUS,d1       
    andi.b  #$02,d1            
    beq     .wait_tx            
    move.b  d0,IO_DATA         
    move.b  (sp)+,d1
    rts

INCH:
    move.b  IO_STATUS,d0       
    andi.b  #$01,d0            
    beq     INCH                
    move.b  IO_DATA,d0         
    rts

TSTAT:
    move.b  IO_STATUS,d0       
    andi.b  #$01,d0            
    beq     .no_char            
    move.b  #$FF,d0            
    rts
.no_char:
    move.b  #$00,d0            
    rts

; =============================================================================
; TINY BASICIN VAATIMAT APUOHJELMAT (Sillattu C-emulaattorille)
; =============================================================================
    xdef    AUXOUT
AUXOUT:
    move.b  d1,-(sp)
.wait:
    move.b  IO_STATUS,d1       ; Luetaan emulaattorin tilarekisteri
    andi.b  #$02,d1            ; Onko lähetin valmis (Tx)?
    beq     .wait
    move.b  d0,IO_DATA         ; Kirjoitetaan merkki näytölle
    move.b  (sp)+,d1
    rts

    xdef    AUXIN
AUXIN:
    move.b  IO_STATUS,d0       ; Luetaan emulaattorin tilarekisteri
    andi.b  #$01,d0            ; Onko näppäimistöltä merkkiä (Rx)?
    beq     .no_char           ; Jos ei, hypätään palauttamaan Zero status
    move.b  IO_DATA,d0         ; Luetaan raaka merkki
    andi.b  #$7F,d0            ; Nollataan ylin bitti (puhtaan ASCII:n varmistus)
    tst.b   d0                 ; Nollataan Zero-lippu, koska merkki löytyi (Z=0)
    rts
.no_char:
    move.w  #4,ccr             ; Asetetaan aito CPU Zero status -lippu (Z=1) kokonaisena
    rts

; =============================================================================
; Data-alue
; =============================================================================
WELCOME_MSG:
    dc.b    13,10,"M68K MBOOT v1.2 - SEKTORI-HDD VALMIS.",13,10
    dc.b    "KÄYNNISTETÄÄN TINY BASIC...",13,10,0
    
HDD_ERR_MSG:
    dc.b    13,10,"VIRHE: Virtuaalilevyn alustus epaonnistui!",13,10,0

    align   2                   

; =============================================================================
; SISÄLLYTETÄÄN TINY BASIC
; =============================================================================
START_BASIC:
    include "tinybasic.asm"
