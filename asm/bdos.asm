; =============================================================================
; CP/M 68K BDOS - Laiteriippumaton Ydin (Korjattu versio)
; =============================================================================
    org     $0000E000           ; BDOS sijaitsee muistissa CCP:n ja BIOS:n välissä

    xdef    BDOS_ENTRY
BDOS_ENTRY:
    ; Kutsuttava funktion numero on D0-rekisterissä
    cmpi.l  #1,d0
    beq     BDOS_FUNC_CONIN     ; Funktio 1: Lue merkki näppäimistöltä
    cmpi.l  #2,d0
    beq     BDOS_FUNC_CONOUT    ; Funktio 2: Tulosta merkki näytölle
    cmpi.l  #9,d0
    beq     BDOS_FUNC_PRINTSTR  ; Funktio 9: Tulosta merkkijono päättyen '$'
    
    ; Tähän väliin tulisi tiedostojärjestelmän luku (Open, Read, Write)
    move.l  #0,d0
    rts

BDOS_FUNC_CONIN:
    jsr     $0000FA0C           ; Kutsutaan BIOS CONIN (+12)
    rts

BDOS_FUNC_CONOUT:
    ; Standardissa merkki on D1:ssä, siirretään se BIOS:n odottamaan D0:aan
    move.l  d1,d0
    jsr     $0000FA10           ; Kutsutaan BIOS CONOUT (+16)
    rts

BDOS_FUNC_PRINTSTR:
    ; Säästetään a0 ja d2 rekisterit pinoon heti alussa, jotta silmukka on turvallinen
    movem.l a0/d2,-(sp)         
    
    ; Merkkijonon osoite on A0-rekisterissä (omassa CCP:ssäsi)
    ; Jos haluat CP/M-standardin, muuta tähän: move.l d1,a0
.loop:
    move.b  (a0)+,d0            ; Luetaan merkki D0:aan (valmiina BIOS CONOUTille)
    cmpi.b  #'$',d0             ; Koettiinko lopetusmerkki?
    beq     .done
    
    ; Koska BIOS CONOUT saattaa ylikirjoittaa osoiterekistereitä,
    ; säästetään a0 rekisteriin D2 (jota BIOS ei standardin mukaan saa tuhota)
    move.l  a0,d2
    jsr     $0000FA10           ; Kutsutaan BIOS CONOUT (+16), merkki on jo D0:ssa
    move.l  d2,a0               ; Palautetaan merkkijonon osoite takaisin a0:aan
    bra     .loop

.done:
    movem.l (sp)+,a0/d2         ; Palautetaan alkuperäiset rekisterit pinosta
    rts
