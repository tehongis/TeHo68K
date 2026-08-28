from PIL import Image, ImageDraw, ImageFont
import os

# Configuration
INPUT_FILE = "data/Bm437_ToshibaT300_8x8.otb"
OUTPUT_RAW = "font_8x8_raw.bin"
OUTPUT_PREVIEW = "font_preview.png"
FONT_SIZE = 8
CHARS_PER_ROW = 16
TOTAL_CHARS = 256

def convert_and_preview():
    # Check if input file exists
    if not os.path.exists(INPUT_FILE):
        print(f"Error: Input file '{INPUT_FILE}' not found.")
        return

    try:
        # Load the font (Pillow treats .otb as .ttf if the header is TTF)
        font = ImageFont.truetype(INPUT_FILE, FONT_SIZE)
        print(f"Loaded font: {INPUT_FILE}")
    except Exception as e:
        print(f"Error loading font: {e}")
        return

    # --- 1. Generate Raw Binary Data ---
    raw_data = bytearray()
    
    for char_code in range(TOTAL_CHARS):
        # Create a temporary 8x8 image for the character
        img = Image.new('1', (FONT_SIZE, FONT_SIZE), 0)
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
        for row in range(8):
            byte_val = 0
            for col in range(8):
                pixel_idx = row * 8 + col
                if pixels[pixel_idx] != 0:
                    byte_val |= (1 << (7 - col))
            raw_data.append(byte_val)

    # Write raw binary
    with open(OUTPUT_RAW, 'wb') as f:
        f.write(raw_data)
    print(f"✓ Saved raw binary to: {OUTPUT_RAW} ({len(raw_data)} bytes)")

    # --- 2. Generate PNG Preview ---
    # Grid size: 16 chars wide * 8 pixels = 128px wide
    #            16 chars high * 8 pixels = 128px high
    preview_width = CHARS_PER_ROW * FONT_SIZE
    preview_height = (TOTAL_CHARS // CHARS_PER_ROW) * FONT_SIZE
    
    preview_img = Image.new('1', (preview_width, preview_height), 0)
    draw_preview = ImageDraw.Draw(preview_img)
    
    # Draw grid lines (optional, for readability)
    # We draw them in '1' mode (black) but since background is 0, we draw white lines?
    # Actually, '1' mode is black(0) and white(1). Let's keep it simple: black text on white bg?
    # Pillow '1' mode: 0 is black, 1 is white.
    # Let's make the preview white background (1) and black text (0) for better visibility?
    # Or standard: Black background (0), White text (1).
    
    # Let's do Black Background (0), White Text (1)
    preview_img = Image.new('1', (preview_width, preview_height), 0)
    draw_preview = ImageDraw.Draw(preview_img)
    
    # Draw grid lines (dashed or just borders)
    # Actually, let's just draw the chars.
    
    for char_code in range(TOTAL_CHARS):
        col = char_code % CHARS_PER_ROW
        row = char_code // CHARS_PER_ROW
        
        x = col * FONT_SIZE
        y = row * FONT_SIZE
        
        # Draw character
        try:
            draw_preview.text((x, y), chr(char_code), font=font, fill=1)
        except:
            pass

    # Save PNG
    preview_img.save(OUTPUT_PREVIEW)
    print(f"✓ Saved preview image to: {OUTPUT_PREVIEW}")

    # --- 3. Console Text Preview (ASCII Art style) ---
    print("\n--- Console Preview (First 32 chars) ---")
    print("Char | Hex  | ASCII View")
    print("-" * 30)
    
    for i in range(32):
        char_code = i
        # Get the 8 bytes for this char from raw_data
        start_idx = char_code * 8
        char_bytes = raw_data[start_idx:start_idx+8]
        
        # Convert bytes to binary string for visual check
        binary_str = "".join(f"{b:08b}" for b in char_bytes)
        
        # ASCII representation
        try:
            char_display = chr(char_code) if char_code >= 32 else "."
            if char_code == 32: char_display = "SP"
        except:
            char_display = "?"
            
        hex_str = " ".join(f"{b:02X}" for b in char_bytes)
        print(f"{char_code:02X}  | {char_display:3}  | {hex_str}")

    print("\n... (Full preview saved to PNG)")

if __name__ == "__main__":
    convert_and_preview()