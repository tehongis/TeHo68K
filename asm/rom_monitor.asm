* =================================================================
* VAKIOT JA MUISTIOSOITTEET
* =================================================================

    include "HAL.i"

* =================================================================
* VEKTORITAULUKKO (Alkaa osoitteesta $00000000)
* =================================================================
    ORG     $00000000
    DC.L    $0000fffe           * Alustus: Pinon huippu (Stack Pointer)
    DC.L    Main                * Alustus: Ohjelman aloitusosoite (PC)

    ORG     $00000064           * IRQ 1 Autovector (Näppäimistö sisään)
    DC.L    Keyboard_ISR

    ORG     $00000068           * IRQ 2 Autovector (Tulostus ulos)
    DC.L    Output_ISR

* =================================================================
* PÄÄOHJELMA
* =================================================================
              ORG   $00001000   * Ohjelmakoodin paikka RAM-muistissa
Main:

; --- Init_Palette
    LEA     VGA_Palette_Data,A0  * Osoitin tämän taulukon alkuun
    LEA     PALETTE_START,A1           * Osoitin emuloituun palettimuistiin
    MOVE.W  #256,D0              * Looppi pyörii 256 kertaa (kaikki värit)
.paletteLoop
    MOVE.L  (A0)+,(A1)+          * Kopioidaan väri ($00RRGGBB) palettiin
    SUBQ.W  #1,D0
    BNE     .paletteLoop

    * 1. Alustetaan muuttujat nollaksi
    CLR.L   StringPtr

    * 3. KUTSUTAAN TULOSTUSRUTIINIA: Tulostetaan haluttu viesti
    LEA     MyMessage,A0        * Ladataan viestin osoite A0-rekisteriin
    BSR     PrintString         * Kutsutaan tulostuksen käynnistystä

    * 2. Sallitaan keskeytykset tasoilla 1 ja 2 (SR interrupt mask = 0)
    ANDI.W  #$F8FF,SR

    * 3. KUTSUTAAN TULOSTUSRUTIINIA: Tulostetaan haluttu viesti
    CLR.L   StringPtr
    LEA     MyMessage,A0        * Ladataan viestin osoite A0-rekisteriin
    move.l  #$2,d3
    BSR     PrintStringFB         * Kutsutaan tulostuksen käynnistystä

Loop:
    JMP     Loop

* =================================================================
* PALETIN LATAUSRUTIINI
* =================================================================

* =================================================================
* ALIOHJELMA: PrintString (Käynnistää tulostusketjun)
* Sisääntulo: A0 = Tulostettavan merkkijonon osoite
* =================================================================
PrintString:
    MOVEM.L D0/A0,-(SP)         * Tallenna käytettävät rekisterit

    * Tarkistetaan heti, onko jono tyhjä (ensimmäinen merkki nolla)
    MOVE.B  (A0),D0
    BEQ     Print_Done          * Jos on nolla, älä tee mitään

    * Asetetaan osoitin valmiiksi seuraavaa merkkiä varten (A0 + 1)
    ADDQ.L  #1,A0
    MOVE.L  A0,StringPtr

    * Kirjoitetaan ensimmäinen merkki suoraan UART:iin.
    * Tämä saa C-koodin tulostamaan sen ja herättämään ensimmäisen IRQ 2:n.
    MOVE.B  D0,UART_OUT_ADDR

Print_Done:
    MOVEM.L (SP)+,D0/A0         * Palauta rekisterit
    RTS

* =================================================================
* IRQ 2: TULOSTUKSEN KESKEYTYSRUTIINI (MC68000-YHTEENSOPIVA)
* =================================================================
Output_ISR:
    MOVEM.L D0/A0,-(SP)         * Tallenna rekisterit suojaukseen

    MOVE.L  StringPtr,A0        * Ladataan nykyinen teksti-osoitin
    
    * KORJAUS: Alkuperäinen 68000 ei tue TST.L A0 -käskyä.
    * Verrataan osoiterekisteriä arvoon 0 CMPA-käskyllä (asettaa Z-lipun, jos NULL).
    CMPA.W  #0,A0               
    BEQ     ISR_Done            * Jos on nolla, ei aktiivista viestiä -> poistu

    MOVE.B  (A0)+,D0            * Luetaan merkki ja siirretään osoitinta eteenpäin
    BEQ     Message_Finished    * Jos merkki on $00, viesti loppui

    * Päivitetään uusi osoitin muistiin seuraavaa keskeytystä varten
    MOVE.L  A0,StringPtr        
    
    * Lähetetään merkki laitteelle (C-puoli tulostace ja nostaa uuden IRQ 2:n)
    MOVE.B  D0,UART_OUT_ADDR
    BRA     ISR_Done

Message_Finished:
    CLR.L   StringPtr           * Nollataan osoitin merkiksi siitä, että viesti päättyi

ISR_Done:
    MOVEM.L (SP)+,D0/A0         * Palauta rekisterit
    RTE                         * Paluu keskeytyksestä

* =================================================================
* IRQ 1: NÄPPÄIMISTÖN KESKEYTYSRUTIINI (MUOKATTU HEKSATULOSTUKSELLE)
* =================================================================
Keyboard_ISR:
    MOVEM.L D0-D2/A0,-(SP)      * Tallenna kaikki käytettävät rekisterit

    MOVE.B  (UART_IN_ADDR),D0        * 1. Luetaan saapunut näppäinkoodi D0-rekisteriin
    LEA     HexBuffer,A0        * 2. Otetaan puskurin osoite A0-rekisteriin

    * --- YLEMPI HEX-MERKKI (Ylemmät 4 bittiä) ---
    MOVE.B  D0,D1               * Otetaan kopio koodista D1-rekisteriin
    LSR.B   #4,D1               * Siirretään yläbitit alabiteiksi (esim. $41 -> $04)
    BSR     ConvertNibble       * Muutetaan numeroksi/kirjaimeksi ASCII-muotoon
    MOVE.B  D1,(A0)+            * Tallennetaan puskurin ensimmäiseksi merkiksi

    * --- ALEMPI HEX-MERKKI (Alemmat 4 bittiä) ---
    MOVE.B  D0,D1               * Otetaan uusi kopio koodista D1-rekisteriin
    ANDI.B  #$0F,D1             * Maskataan yläbitit pois (esim. $41 -> $01)
    BSR     ConvertNibble       * Muutetaan ASCII-muotoon
    MOVE.B  D1,(A0)+            * Tallennetaan puskurin toiseksi merkiksi

    * --- LOPPUMERKIT ---
    MOVE.B  #32,(A0)+           * Lisätään välilyönti (ASCII 32) heksalukujen väliin
    MOVE.B  #0,(A0)             * Lisätään nollaterminaattori merkkijonon loppuun ($00)

    * --- TULOSTUS ---
    LEA     HexBuffer,A0        * Ladataan puskurin alkuosoite takaisin A0:aan
    BSR     PrintString         * Kutsutaan valmista tulostusrutiinia!

    MOVEM.L (SP)+,D0-D2/A0      * Palautetaan rekisterit
    RTE                         * Paluu keskeytyksestä

* =================================================================
* APURUTIINI: ConvertNibble (Muuntaa 4 bittiä ASCII-heksamerkiksi)
* Sisääntulo: D1 = Alimmat 4 bittiä sisältävät muunnettavan arvon (0-15)
* Ulostulo:   D1 = Valmis ASCII-merkki ('0'-'9' tai 'A'-'F')
* =================================================================
ConvertNibble:
    CMPI.B  #10,D1              * Onko arvo alle 10 (0-9)?
    BLT     IsDigit             * Jos on, hypätään suoraan numeron käsittelyyn
    
    * Jos arvo on 10-15 (A-F):
    ADDQ.B  #7,D1               * Lisätään erotus numeroiden ja kirjainten välillä ASCII-taulukossa
IsDigit:
    ADDI.B  #$30,D1             * Lisätään '0'-merkin ASCII-arvo ($30)
    RTS

; --------- Framebuffer printString
* =================================================================
* ALIOHJELMA: PrintStringFB (Framebuffer/VRAM-versio)
* Sisääntulo: A0 = Null-terminoidun merkkijonon osoite
*             D3.B = Tekstin väri (VGA-paletin indeksi)
* =================================================================
PrintStringFB:
    MOVEM.L D0-D2/A0,-(SP)      * Tallenna käytettävät rekisterit

Print_Char_Loop:
    MOVE.B  (A0)+,D0            * Lue merkki ja siirrä osoitinta eteenpäin
    BEQ     Print_DoneFB         * Jos merkki on 0 (loppumerkki), lopeta

    * TARKISTETAAN RIVINVAIHTO (ASCII 10 / Newline)
    CMPI.B  #10,D0
    BEQ     Handle_Newline

    * TAVALLISEN MERKIN TULOSTUS
    * Ladataan kursorin nykyiset koordinaatit DrawChar-aliohjelmalle
    MOVE.W  (CursorX),D1
    MOVE.W  (CursorY),D2
    
    BSR     DrawChar            * Piirretään merkki ruudulle!

    * Siirretään kursorikohdistinta 8 pikseliä oikealle seuraavaa merkkiä varten
    ADDQ.W  #8,D1
    CMPI.W  #320,D1             * Saavutettiinko ruudun oikea reuna?
    BLT     Save_Cursor_X
    
    * Jos reuna saavutettiin, tehdään automaattinen rivinvaihto
    CLR.W  D1                  * X = 0
    ADDQ.W  #8,D2               * Y = Y + 8

Save_Cursor_X:
    MOVE.W  D1,(CursorX)
    MOVE.W  D2,(CursorY)
    BRA     Print_Char_Loop     * Siirrytään seuraavaan merkkiin

Handle_Newline:
    * Siirretään kursori seuraavan rivin alkuun (X=0, Y=Y+8)
    CLR.W   (CursorX)
    MOVE.W  (CursorY),D2
    ADDQ.W  #8,D2
    
    * Valinnainen: Tähän voi lisätä tarkistuksen jos Y > 592 (ruudun rullaus/scroll),
    * mutta pidetään se aluksi yksinkertaisena.
    MOVE.W  D2,(CursorY)
    BRA     Print_Char_Loop     * Jatgetaan merkkijonon läpikäyntiä

Print_DoneFB:
    MOVEM.L (SP)+,D0-D2/A0      * Palauta rekisterit
    RTS

; ------ Framebuffer Draw char 

DrawChar:
    MOVEM.L D0-D5/A0-A1,-(SP)   * Tallenna kaikki käytettävät rekisterit

    * 1. LASKETAAN MERKIN OSOITE FONT_ROM-ALUEELLA
    ANDI.L  #$000000FF,D0       * Varmistetaan, että D0:ssa on vain tavu
    LSL.L   #3,D0               * Kerrotaan ASCII-koodi 8:lla (D0 = koodi * 8)
    LEA     FONT_ROM,A0
    ADDA.L  D0,A0               * A0 osoittaa nyt halutun merkin 8 tavun alkuun

    * 2. LASKETAAN KOHDEOSOITE FRAMEBUFFERISSA (VRAM)
    * Kaava: VRAM_START + (Y * 800) + X
    LEA     VRAM_START,A1
    MULU.W  #800,D2             * D2 = Y * 800
    ADDA.L  D2,A1               * A1 = VRAM + (Y * 800)
    ANDI.L  #$0000FFFF,D1       * Varmistetaan X:n puhtaus
    ADDA.L  D1,A1               * A1 osoittaa nyt pikseliin (X, Y)

    * 3. PIIRTOSILMUKKA (8 riviä)
    MOVE.W  #8,D4               * Rivimäärä = 8

Char_Row_Loop:
    MOVE.B  (A0)+,D0            * Luetaan fontin yksi rivitavu (8 bittiä)
    MOVE.W  #8,D5               * Sarakemäärä = 8 bittiä

Char_Bit_Loop:
    ROL.B   #1,D0               * Pyöräytetään ylin bitti Carry-lippuun
    BCC     Pixel_Off           * Jos Carry on 0, hypätään yli (tausta säilyy)

    * Jos bitti oli 1, piirretään pikseli halutulla värillä
    MOVE.B  D3,(A1)

Pixel_Off:
    ADDQ.L  #1,A1               * Siirrytään seuraavaan pikseliin oikealle (X + 1)
    SUBQ.W  #1,D5
    BNE     Char_Bit_Loop       * Toistetaan rivin kaikille 8 bitille

    * Siirrytään seuraavan rivin alkuun framebufferissa
    * Piirrettiin 8 pikseliä, joten pitää hypätä yli: 800 - 8 = 792 pikseliä
    LEA     792(A1),A1

    SUBQ.W  #1,D4
    BNE     Char_Row_Loop       * Toistetaan kaikille 8 riville

    MOVEM.L (SP)+,D0-D5/A0-A1   * Palautetaan rekisterit
    RTS

* =================================================================
* TULOSTETTAVA DATA
* =================================================================
            EVEN

StringPtr:    DS.L  1           * Osoitin tulostettavan merkkijonon nykyiseen merkkiin

HexBuffer:    DS.B  4           

CursorX:      DS.W  1           * UUSI: Nykyinen X-koordinaatti (0-799)
CursorY:      DS.W  1           * UUSI: Nykyinen Y-koordinaatti (0-599)

MyMessage:
    DC.B    "M68k Musashi keskeytystulostus toimii!",10,13,0
    * 10 = Newline (\n), 13 = Carriage Return (\r), 0 = Null-terminaattori

            EVEN

VGA_Palette_Data:
* --- 16 VGA PERUSVÄRIÄ ---
    DC.L    $00000000    * 0: Musta
    DC.L    $000000AA    * 1: Sininen
    DC.L    $0000AA00    * 2: Vihreä
    DC.L    $0000AAAA    * 3: Syaani
    DC.L    $00AA0000    * 4: Punainen
    DC.L    $00AA00AA    * 5: Magenta
    DC.L    $00AA5500    * 6: Ruskea
    DC.L    $00AAAAAA    * 7: Vaaleanharmaa
    DC.L    $00555555    * 8: Tummanharmaa
    DC.L    $005555FF    * 9: Kirkas sininen
    DC.L    $0055FF55    * 10: Kirkas vihreä
    DC.L    $0055FFFF    * 11: Kirkas syaani
    DC.L    $00FF5555    * 12: Kirkas punainen
    DC.L    $00FF55FF    * 13: Kirkas magenta
    DC.L    $00FFFF55    * 14: Keltainen
    DC.L    $00FFFFFF    * 15: Valkoinen

* --- SATEENKAARI JA VÄRISKAALAT (Värit 16-231) ---
    DC.L    $00000000,$00000040,$00000080,$000000C0,$000000FF,$00004000
    DC.L    $00004040,$00004080,$000040C0,$000040FF,$00008000,$00008040
    DC.L    $00008080,$000080C0,$000080FF,$0000C000,$0000C040,$0000C080
    DC.L    $0000C0C0,$0000C0FF,$0000FF00,$0000FF40,$0000FF80,$0000FFC0
    DC.L    $0000FFFF,$00400000,$00400040,$00400080,$004000C0,$004000FF
    DC.L    $00404000,$00404040,$00404080,$004040C0,$004040FF,$00408000
    DC.L    $00408040,$00408080,$004080C0,$004080FF,$0040C000,$0040C040
    DC.L    $0040C080,$0040C0C0,$0040C0FF,$0040FF00,$0040FF40,$0040FF80
    DC.L    $0040FFC0,$0040FFFF,$00800000,$00800040,$00800080,$008000C0
    DC.L    $008000FF,$00804000,$00804040,$00804080,$008040C0,$008040FF
    DC.L    $00808000,$00808040,$00808080,$008080C0,$008080FF,$0080C000
    DC.L    $0080C040,$0080C080,$0080C0C0,$0080C0FF,$0080FF00,$0080FF40
    DC.L    $0080FF80,$0080FFC0,$0080FFFF,$00C00000,$00C00040,$00C00080
    DC.L    $00C000C0,$00C000FF,$00C04000,$00C04040,$00C04080,$00C040C0
    DC.L    $00C040FF,$00C08000,$00C08040,$00C08080,$00C080C0,$004080FF
    DC.L    $00C0C000,$00C0C040,$00C0C080,$00C0C0C0,$00C0C0FF,$00C0FF00
    DC.L    $00C0FF40,$00C0FF80,$00C0FFC0,$00C0FFFF,$00FF0000,$00FF0040
    DC.L    $00FF0080,$00FF00C0,$00FF00FF,$00FF4000,$00FF4040,$00FF4080
    DC.L    $00FF40C0,$00FF40FF,$00FF8000,$00FF8040,$00FF8080,$00FF80C0
    DC.L    $00FF80FF,$00FFC000,$00FFC040,$00FFC080,$00FFC0C0,$00FFC0FF
    DC.L    $00FFFF00,$00FFFF40,$00FFFF80,$00FFFFC0,$00FFFFFF,$00200000
    DC.L    $00400000,$00600000,$00800000,$00A00000,$00C00000,$00E00000
    DC.L    $00002000,$00004000,$00006000,$00008000,$0000A000,$0000C000
    DC.L    $0000E000,$00000020,$00000040,$00000060,$00000080,$000000A0
    DC.L    $000000C0,$000000E0,$00202000,$00404000,$00606000,$00808000
    DC.L    $00A0A000,$00C0C000,$00E0E000,$00200020,$00400040,$00600060
    DC.L    $00800080,$00A000A0,$00C000C0,$00E000E0,$00002020,$00004040
    DC.L    $00006060,$00008080,$0000A0A0,$0000C0C0,$0000E0E0,$00202020
    DC.L    $00404040,$00606060,$00808080,$00A0A0A0,$00C0C0C0,$00E0E0E0
    DC.L    $00102030,$00203040,$00304050,$00405060,$00506070,$00607080
    DC.L    $00708090,$008090A0,$0090A0B0,$00A0B0C0,$00B0C0D0,$00C0D0E0
    DC.L    $00D0E0F0,$00400020,$00800040,$00C00060,$00FF0080,$00004020
    DC.L    $00008040,$0000C060,$0000FF80,$00200040,$00400080,$006000C0
    DC.L    $008000FF,$00204000,$00408000,$0060C000,$0080FF00,$00402000
    DC.L    $00804000,$00C06000,$00FF8000,$00002040,$00004080,$000060C0
    DC.L    $000080FF,$00404020,$00808040,$00C0C060,$00FFFF80,$00204040
    DC.L    $00408080,$0060C0C0,$0080FFFF,$00402040,$00804080,$00C060C0
    DC.L    $00FF80FF,$00112233,$00223344,$00334455,$00445566,$00556677

* --- 24 HARMAASÄVYÄ (Värit 232-255) ---
    DC.L    $00080808,$00101010,$00181818,$00202020,$00282828,$00303030
    DC.L    $00383838,$00404040,$00484848,$00505050,$00585858,$00606060
    DC.L    $00686868,$00707070,$00787878,$00808080,$00888888,$00909090
    DC.L    $00989898,$00A0A0A0,$00A8A8A8,$00B0B0B0,$00B8B8B8,$00C0C0C0
