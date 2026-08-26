import os
from fontTools.ttLib import TTFont

def generate_font_asm(input_font_path, output_asm_path):
    if not os.path.exists(input_font_path):
        print(f"[VIRHE] Fonttitiedostoa ei löytynyt: {input_font_path}")
        return

    try:
        font = TTFont(input_font_path)
    except Exception as e:
        print(f"[VIRHE] Ei voitu avata fonttia: {e}")
        return

    # Haetaan glyfikokoelma ja hahmontamistaulukko
    glyph_set = font.getGlyphSet()
    cmap = font.getBestCmap()
    
    # Käänteinen haku: haetaan unicode-arvo glyfin nimen perusteella
    # (Monissa int10h-fonteissa glyfit on nimetty "uni0030" tai "char48")
    glyph_to_ascii = {}
    if cmap:
        for ascii_code, glyph_name in cmap.items():
            if ascii_code < 256: # Otetaan vain standardi 256 merkin taulukko
                glyph_to_ascii[glyph_name] = ascii_code

    # Luodaan tyhjä 256 merkin fonttitaulukko (8 tavua per merkki)
    font_matrix = [[0] * 8 for _ in range(256)]

    # Puretaan bittikartat oikeaoppisesti OpenType 'EBDT' (Embedded Bitmap Data) taulukosta
    if 'EBDT' in font:
        ebdt = font['EBDT']
        for strike in ebdt.strikeData:
            for glyph_name, bitmap_data in strike.items():
                # Selvitetään mikä ASCII-merkki on kyseessä
                ascii_code = None
                if glyph_name in glyph_to_ascii:
                    ascii_code = glyph_to_ascii[glyph_name]
                elif glyph_name.startswith('char'):
                    try: ascii_code = int(glyph_name[4:])
                    except: pass
                elif glyph_name.startswith('uni') and len(glyph_name) == 7:
                    try: ascii_code = int(glyph_name[3:], 16)
                    except: pass
                
                if ascii_code is None or ascii_code >= 256:
                    continue

                # Luetaan raa'at bittikarttatavut
                try:
                    # EBDT-formaatista riippuen data voi olla suoraan bittikarttana
                    raw_data = bitmap_data.imageData
                    # Varmistetaan, että luetaan tasan 8 riviä
                    for row_idx in range(min(8, len(raw_data))):
                        font_matrix[ascii_code][row_idx] = raw_data[row_idx]
                except:
                    pass

    # Kirjoitetaan kaunis vasm-yhteensopiva ASM-tiedosto
    with open(output_asm_path, 'w', encoding='utf-8') as f:
        f.write(";=============================================================================\n")
        f.write("; Automaattisesti generoitu FONT.ASM - 8x8 Raakabittikartta (256 merkkiä)\n")
        f.write(";=============================================================================\n\n")
        f.write("            section font_rom,code\n\n")
        f.write("FONT_START:\n")

        for ascii_code in range(256):
            rows = font_matrix[ascii_code]
            hex_strings = [f"${row:02X}" for row in rows]
            tavut_str = ", ".join(hex_strings)
            
            # Tehdään kommentti, jotta koodia on helppo lukea ihmisenkin
            char_repr = chr(ascii_code) if 32 <= ascii_code <= 126 else "Määrittelemätön"
            f.write(f"            dc.b    {tavut_str} ; Indeksi {ascii_code:3d} (0x{ascii_code:02X}) '{char_repr}'\n")

        f.write("\nFONT_END:\n")
        
    print(f"[OK] Generoitu täydellinen vasm-lähdekoodi: {output_asm_path}")

# Suoritus
generate_font_asm("Bm437_ToshibaT300_8x8.otb", "font.asm")
