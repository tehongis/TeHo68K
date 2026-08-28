; =============================================================================
; CP/M 68K BIOS - Laiteriippuvaiset Ajurit TeHo68K-emulaattorille
; =============================================================================
    org     $0000FA00           ; BIOS sijaitsee RAM-muistin yläosassa

    jmp     BIOS_INIT           ; +0: Cold Boot
    jmp     BIOS_WBOOT          ; +4: Warm Boot
    jmp     BIOS_CONST          ; +8: Console Status
    jmp     BIOS_CONIN          ; +12: Console Input
    jmp     BIOS_CONOUT         ; +16: Console Output
    jmp     BIOS_SELDSK         ; +20: Select Drive
    jmp     BIOS_SETTRK         ; +24: Set Track
    jmp     BIOS_SETSEC         ; +28: Set Sector
    jmp     BIOS_SETDMA         ; +32: Set DMA Address
    jmp     BIOS_READ           ; +36: Read Sector
    jmp     BIOS_WRITE          ; +40: Write Sector

; --- MMIO Rekisterit ---
IO_STATUS     equ     $00F00000   
IO_DATA       equ     $00F00004   
HDD_COMMAND   equ     $00F00100   
HDD_STATUS    equ     $00F00101   
HDD_SECTOR    equ     $00F00102   
HDD_DMA_ADDR  equ     $00F00108   

; --- Sisäiset muuttujat ---
    align   2
CURRENT_SEC:  dc.l    0
CURRENT_DMA:  dc.l    0

BIOS_INIT:
    ; 1. Alustetaan pino käyttöjärjestelmää varten varmuuden vuoksi
    lea     $0000BF00,sp

    ; 2. Kerrotaan CP/M:lle, mikä on oletusajuri (A: = 0)
    move.l  #0,d3               ; CP/M-68K odottaa bootissa oletusajuria D3:ssa

    ; 3. Hypätään suoraan CCP:n alkuun, ei palata enää monitoriin!
    jmp     $0000C000           ; CCP_START osoitteessa $C000

BIOS_WBOOT:
    jmp     $0000C000           ; Warm Boot hyppää suoraan takaisin CCP:hen

BIOS_CONST:
    move.b  IO_STATUS,d0       
    andi.b  #$01,d0             ; Onko merkkiä puskurissa (Rx)?
    beq     .no_char            
    move.l  #$FFFFFFFF,d0       ; CP/M: $FF / $FFFFFFFF = Merkki valmiina
    rts
.no_char:
    move.l  #0,d0
    rts

BIOS_CONIN:
    move.b  IO_STATUS,d0       
    andi.b  #$01,d0             ; Tarkistetaan onko Rx-bitti (1 = merkki valmiina)
    beq     BIOS_CONIN          ; Jos 0, hypätään takaisin ja odotetaan!
    
    move.l  #0,d0
    move.b  IO_DATA,d0          ; Luetaan merkki vasta kun Rx oli 1
    andi.b  #$7F,d0             
    rts


BIOS_CONOUT:
    move.b  IO_STATUS,d1       
    andi.b  #$02,d1             ; Onko lähetin valmis (Tx)?
    beq     BIOS_CONOUT         
    move.b  d0,IO_DATA          ; Tulostetaan merkki D0:sta näytölle
    rts

BIOS_SELDSK:
    ; Emulaattori tukee vain yhtä asemaa (A:). Palautetaan 0 = OK.
    move.l  #0,d0
    rts

BIOS_SETTRK:
    ; TeHo68K käyttää suoria suuria sektoreita radioiden sijaan, ohitetaan Track
    rts

BIOS_SETSEC:
    move.l  d1,CURRENT_SEC      ; CP/M-68K standardi käyttää D1-rekisteriä
    rts
BIOS_SETDMA:
    move.l  d1,CURRENT_DMA      ; CP/M-68K standardi käyttää D1-rekisteriä
    rts

BIOS_READ:
    move.l  CURRENT_SEC,HDD_SECTOR      
    move.l  CURRENT_DMA,HDD_DMA_ADDR    
    move.b  #2,HDD_COMMAND      ; Komento 2: Lue sektori
    move.l  #0,d0
    move.b  HDD_STATUS,d0       ; Palautetaan status (0 = OK)
    rts

BIOS_WRITE:
    move.l  CURRENT_SEC,HDD_SECTOR      
    move.l  CURRENT_DMA,HDD_DMA_ADDR    
    move.b  #3,HDD_COMMAND      ; Komento 3: Kirjoita sektori
    move.l  #0,d0
    move.b  HDD_STATUS,d0       ; Palautetaan status (0 = OK)
    rts
