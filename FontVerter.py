# Save this in your project root as: convert_font.py
import os
import glob
import shutil
import freetype
from PIL import Image

FONTS_DIR = "Fonts"

def extract_otb_to_raw_and_png(otb_path, output_bin, output_png):
    """
    Dynamically discovers font sizing metrics and extracts any size .otb file 
    directly into a raw binary layout and a matching PNG grid preview.
    """
    try:
        face = freetype.Face(otb_path)
    except Exception as e:
        print(f" -> ERROR: Failed to open font file: {e}")
        return False

    # Check available bitmap sizes embedded in the OTB container
    if not face.available_sizes:
        print(f" -> ERROR: No embedded bitmap strikes found in {otb_path}")
        return False

    # Grab the target resolution metrics from the font strike
    strike = face.available_sizes[0]
    char_width = strike.width
    char_height = strike.height
    
    # Calculate bytes needed to store one horizontal row of pixels
    # (e.g., 1-8 pixels = 1 byte, 9-16 pixels = 2 bytes)
    row_pitch = (char_width + 7) // 8
    char_size_bytes = row_pitch * char_height
    
    print(f"Detected internal font size: {char_width}x{char_height} pixels ({char_size_bytes} bytes per character)")

    # Dynamically allocate buffer (256 characters * variable bytes per character)
    raw_font = bytearray(256 * char_size_bytes)
    
    try:
        face.select_size(0)
    except Exception:
        # Fallback if select_size is unavailable in older freetype-py bindings
        face.set_pixel_sizes(0, char_height)


    for ch in range(256):
        try:
            # Force FreeType to render straight to a monochromatic raw pixel buffer array
            face.load_char(chr(ch), freetype.FT_LOAD_RENDER | freetype.FT_LOAD_TARGET_MONO)
            bitmap = face.glyph.bitmap
            
            rows = bitmap.rows
            pitch = bitmap.pitch
            buffer = bitmap.buffer

            # Write individual bit rows directly from index 0 downward
            for r in range(min(rows, char_height)):
                target_row_start = (ch * char_size_bytes) + (r * row_pitch)
                
                for p in range(min(pitch, row_pitch)):
                    src_byte = buffer[r * pitch + p]
                    raw_font[target_row_start + p] = src_byte & 0xFF
                    
        except Exception:
            # Missing map indices fall back to clean 0x00 spaces safely
            pass

    # 1. Output the compiled binary file
    with open(output_bin, "wb") as f:
        f.write(raw_font)
    print(f" -> Generated raw binary: {output_bin} ({len(raw_font)} bytes)")

    # 2. Render a 16x16 character matrix layout directly onto a dynamic PNG canvas
    img_w = 16 * char_width
    img_h = 16 * char_height
    img = Image.new("L", (img_w, img_h), color=0)
    pixels = img.load()
    
    for ch in range(256):
        grid_x = (ch % 16) * char_width
        grid_y = (ch // 16) * char_height
        
        for y in range(char_height):
            char_block_offset = ch * char_size_bytes
            row_offset = y * row_pitch
            
            for x in range(char_width):
                byte_index = x // 8
                bit_index = x % 8
                
                byte_val = raw_font[char_block_offset + row_offset + byte_index]
                if byte_val & (0x80 >> bit_index):
                    pixels[grid_x + x, grid_y + y] = 255 # Pure retro white filament
                    
    img.save(output_png)
    print(f" -> Generated PNG grid preview: {output_png}")
    return True

if __name__ == "__main__":
    if not os.path.exists(FONTS_DIR):
        os.makedirs(FONTS_DIR)
        print(f"Created empty directory: '{FONTS_DIR}'. Drop any size .otb files there.")
        exit(0)

    otb_files = glob.glob(os.path.join(FONTS_DIR, "*.otb"))
    
    if not otb_files:
        print(f"ERROR: The '{FONTS_DIR}' directory does not contain any .otb files!")
        exit(1)
        
    print(f"Found {len(otb_files)} .otb files in '{FONTS_DIR}'.")
    
    success_count = 0
    for otb in otb_files:
        base_path = os.path.splitext(otb)[0]
        out_bin = f"{base_path}_raw.bin"
        out_png = f"{base_path}_preview.png"
        
        if extract_otb_to_raw_and_png(otb, out_bin, out_png):
            success_count += 1
            # Copy the latest successfully parsed asset to the default emulator filename
            shutil.copyfile(out_bin, "font_8x16_raw.bin")
            
    print(f"\nDone! Successfully processed {success_count} variable font strikes.")
