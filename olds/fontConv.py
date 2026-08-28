from PIL import Image, ImageDraw, ImageFont
import os

# Configuration
INPUT_FILE = "data/Bm437_ACM_VGA_8x16.otb"  # Päivitetty 8x16 fonttitiedosto
OUTPUT_RAW = "font_8x16_raw.bin"           # Päivitetty ulostulonimi
OUTPUT_PREVIEW = "font_preview_8x16.png"
FONT_WIDTH = 8
FONT_HEIGHT = 16                           # Päivitetty korkeus 16 pikseliin
CHARS_PER_ROW = 16
TOTAL_CHARS = 256

def convert_and_preview():
    # Check if input file exists
    if not os.path.exists(INPUT_FILE):
        print(f"Error: Input file '{INPUT_FILE}' not found.")
        return

    try:
        # Load the font (Pillow treats .otb as .ttf if the header is TTF)
        # Huom: Jotkut .otb-fontit vaativat kooksi tarkan pikselikorkeuden (16)
        font = ImageFont.truetype(INPUT_FILE, FONT_HEIGHT)
        print(f"Loaded font: {INPUT_FILE}")
    except Exception as e:
        print(f"Error loading font: {e}")
        return

    # --- 1. Generate Raw Binary Data (8x16 format) ---
    raw_data = bytearray()
    
    for char_code in range(TOTAL_CHARS):
        # Create a temporary 8x16 image for the character
        img = Image.new('1', (FONT_WIDTH, FONT_HEIGHT), 0)
        draw = ImageDraw.Draw(img)
        
        # Draw character at top-left (0,0)
        try:
            draw.text((0, 0), chr(char_code), font=font, fill=1)
        except:
            # Fallback for characters that might cause errors
            pass
        
        # Extract pixels and pack into bytes
        # Standard BIOS format: MSB first (bit 7 = leftmost pixel)
        pixels = list(img.getdata())
        for row in range(FONT_HEIGHT):  # Käydään läpi kaikki 16 riviä
            byte_val = 0
            for col in range(FONT_WIDTH):
                pixel_idx = row * FONT_WIDTH + col
                if pixels[pixel_idx] != 0:
                    byte_val |= (1 << (7 - col))
            raw_data.append(byte_val)

    # Write raw binary
    with open(OUTPUT_RAW, 'wb') as f:
        f.write(raw_data)
    print(f"✓ Saved raw binary to: {OUTPUT_RAW} ({len(raw_data)} bytes - 16 bytes per char)")

    # --- 2. Generate PNG Preview from Generated Raw Data ---
    # Grid size: 16 chars wide * 8 pixels = 128px wide
    #            16 chars high * 16 pixels = 256px high
    preview_width = CHARS_PER_ROW * FONT_WIDTH
    preview_height = (TOTAL_CHARS // CHARS_PER_ROW) * FONT_HEIGHT
    
    # Luodaan mustavalkoinen ('1') kuva, tausta 0 (musta)
    preview_img = Image.new('1', (preview_width, preview_height), 0)
    
    for char_code in range(TOTAL_CHARS):
        col = char_code % CHARS_PER_ROW
        row = char_code // CHARS_PER_ROW
        
        char_x_offset = col * FONT_WIDTH
        char_y_offset = row * FONT_HEIGHT
        
        # Jokainen merkki ottaa nyt 16 tavua raakadatasta (1 tavi per rivi)
        start_idx = char_code * FONT_HEIGHT
        char_bytes = raw_data[start_idx : start_idx + FONT_HEIGHT]
        
        # Puretaan bitit takaisin pikseleiksi kuvaan
        for y in range(FONT_HEIGHT):
            byte_val = char_bytes[y]
            for x in range(FONT_WIDTH):
                # Tarkistetaan bitin tila (MSB on vasemmanpuoleisin pikseli)
                pixel_active = (byte_val & (0x80 >> x)) != 0
                if pixel_active:
                    preview_img.putpixel((char_x_offset + x, char_y_offset + y), 1)

    # Save PNG
    preview_img.save(OUTPUT_PREVIEW)
    print(f"✓ Saved preview image from raw binary to: {OUTPUT_PREVIEW}")

    # --- 3. Console Text Preview (ASCII Art style) ---
    print("\n--- Console Preview (First 32 chars) ---")
    print("Char | Hex (First 8 of 16 bytes)")
    print("-" * 40)
    
    for i in range(32):
        char_code = i
        start_idx = char_code * FONT_HEIGHT
        # Otetaan esikatseluun vain ensimmäiset 8 tavua, jotta konsolituloste pysyy siistinä
        char_bytes = raw_data[start_idx : start_idx + 8]
        
        try:
            char_display = chr(char_code) if char_code >= 32 else "."
            if char_code == 32: char_display = "SP"
        except:
            char_display = "?"
            
        hex_str = " ".join(f"{b:02X}" for b in char_bytes)
        print(f"{char_code:02X}  | {char_display:3}  | {hex_str} ...")

    print("\n... (Full 8x16 preview saved to PNG)")

if __name__ == "__main__":
    convert_and_preview()
