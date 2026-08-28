#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>
#include <SDL3/SDL.h>
#include "m68k.h"

// Hardware-konfiguraatio
#define RAM_SIZE       (1024 * 1024)           // 1 MB RAM
#define GRID_COLS      80
#define GRID_ROWS      25
#define VRAM_SIZE      (GRID_COLS * GRID_ROWS) // 3200 tavua tekstipuskuria
#define SECTOR_SIZE    512                     // 512 tavun kiintolevysektori

// Fontin ja ikkunan mitat
#define CHAR_WIDTH     8
#define CHAR_HEIGHT    16
// Emulaattorin sisäinen "looginen" koko (720 x 480)
#define VIRTUAL_WIDTH   (GRID_COLS * CHAR_WIDTH)
#define VIRTUAL_HEIGHT  (GRID_ROWS * CHAR_HEIGHT)

// Fyysisen ikkunan koko työpöydällä (1440 x 960) -> TUPLATTU KOOSSA
#define WINDOW_WIDTH    (VIRTUAL_WIDTH * 2)
#define WINDOW_HEIGHT   (VIRTUAL_HEIGHT * 2)


// Muistikartan osoitteet (KORJATTU: Ei duplikaatteja tai VSTART-virheitä)
#define RAM_START      0x00000000
#define RAM_END        (RAM_START + RAM_SIZE - 1)
#define VRAM_START     0x00800000
#define VRAM_END       (VRAM_START + VRAM_SIZE - 1)

// MMIO-rekisterit (Memory-Mapped I/O)
#define IO_STATUS      0x00F00000
#define IO_DATA        0x00F00004
#define HDD_COMMAND    0x00F00100
#define HDD_STATUS     0x00F00101
#define HDD_SECTOR     0x00F00102  // 32-bit paikka
#define HDD_DMA_ADDR   0x00F00108  // 32-bit paikka

#define IO_TIMER       0x00F00200  // UUSI: 32-bittinen millisekuntiajastin

#define fontname        "Fonts/Bm437_ATI_8x16_8x16_raw.bin"

// Tämä on emulaattorin oma "näytönohjaimen muisti"
uint32_t g_pixel_vram[WINDOW_WIDTH * WINDOW_HEIGHT];
unsigned char* g_ram = NULL;
unsigned char* g_vram = NULL;

// KORJATTU FONTTIMÄÄRITTELY: Kaksiulotteinen 256 merkin ja 16 rivin taulukko
unsigned char g_font_bitmap[256][16]; 

// Virtuaalisen päätteen tilamuuttujat
int g_cursor_x = 0;
int g_cursor_y = 0;
unsigned char g_keyboard_char = 0;
int g_keyboard_ready = 0;

// Virtuaalisen HDD-ohjaimen sisäiset tilat
FILE* g_hdd_file = NULL;
unsigned char g_hdd_status = 0;
unsigned int  g_hdd_sector = 0;
unsigned int  g_hdd_dma_addr = 0;


// SDL-rajapinnan muuttujat
SDL_Window* g_window = NULL;
SDL_Renderer* g_renderer = NULL;
SDL_Texture* g_vram_texture = NULL; 
SDL_Texture* g_crt_texture = NULL;  
SDL_Texture* g_font_texture = NULL; // VGA-tekstitilaa varten


// --------------- IO_DATA


// Päätteen tekstirullaus (Scroll), kun saavutetaan ruudun alareuna
void scroll_vram() {
    memmove(g_vram, g_vram + GRID_COLS, GRID_COLS * (GRID_ROWS - 1));
    memset(g_vram + GRID_COLS * (GRID_ROWS - 1), ' ', GRID_COLS);
    g_cursor_y = GRID_ROWS - 1;
}

// Käsittelee Tiny BASICin lähettämät ASCII-merkit ja ohjaa ne VRAM-puskuriin
void handle_terminal_write(unsigned char ch) {
    if (ch == 10) { // Line Feed (\n)
        g_cursor_y++;
        if (g_cursor_y >= GRID_ROWS) scroll_vram();
        return;
    }
    if (ch == 13) { // Carriage Return (\r)
        g_cursor_x = 0;
        return;
    }
    if (ch == 8 || ch == 127) { // Backspace
        if (g_cursor_x > 0) g_cursor_x--;
        g_vram[g_cursor_y * GRID_COLS + g_cursor_x] = ' ';
        return;
    }

    // Tavallisen tulostettavan merkin sijoitus
    g_vram[g_cursor_y * GRID_COLS + g_cursor_x] = ch;
    g_cursor_x++;
    
    if (g_cursor_x >= GRID_COLS) {
        g_cursor_x = 0;
        g_cursor_y++;
        if (g_cursor_y >= GRID_ROWS) scroll_vram();
    }
}

void handle_hdd_command(unsigned char cmd) {
    if (cmd == 1) { // AVAA LEVY
        if (!g_hdd_file) {
            // Yritetään vain avata olemassa oleva tiedosto luku- ja kirjoitustilassa
            g_hdd_file = fopen("HDD/virtual_disk.img", "r+b");
        }
        
        // Jos tiedostoa ei ole, g_hdd_file on NULL ja tilaksi tulee 0xFF (virhe)
        g_hdd_status = (g_hdd_file) ? 0 : 0xFF;
        
        if (g_hdd_status == 0xFF) {
            printf("HDD: Open failed! File 'HDD/virtual_disk.img' not found.\n");
        } else {
            printf("HDD: Open status:%d\n", g_hdd_status);
        }
        return;
    }

    // Jos levyä ei ole avattu onnistuneesti, kaikki muut komennot palauttavat suoraan virheen
    if (!g_hdd_file) {
        g_hdd_status = 0xFF; // Ei avattua levykuvaa käytettävissä
        return;
    }

    // Lasketaan 512 tavun lohkon siirtymä tiedostossa
    long offset = (long)g_hdd_sector * SECTOR_SIZE;
    if (fseek(g_hdd_file, offset, SEEK_SET) != 0) {
        g_hdd_status = 0xFF;
        return;
    }

    if (cmd == 2) { // LUE SEKTORI (Siirto levyltä RAMiin DMA-osoitteeseen)
        if (g_hdd_dma_addr + SECTOR_SIZE <= RAM_SIZE) {
            size_t read = fread(&g_ram[g_hdd_dma_addr], 1, SECTOR_SIZE, g_hdd_file);
            g_hdd_status = (read == SECTOR_SIZE) ? 0 : 0xFF;
            printf("HDD: Read dma addr: %u status:%d\n", g_hdd_dma_addr, g_hdd_status);
        } else {
            g_hdd_status = 0xFF; // Muistin ylitysvirhe
        }
    } 
    else if (cmd == 3) { // KIRJOITA SEKTORI (Siirto RAMista levylle)
        if (g_hdd_dma_addr + SECTOR_SIZE <= RAM_SIZE) {
            size_t written = fwrite(&g_ram[g_hdd_dma_addr], 1, SECTOR_SIZE, g_hdd_file);
            fflush(g_hdd_file);
            g_hdd_status = (written == SECTOR_SIZE) ? 0 : 0xFF;
            printf("HDD: Write dma addr: %u status:%d\n", g_hdd_dma_addr, g_hdd_status);
        } else {
            g_hdd_status = 0xFF; // Muistin ylitysvirhe
        }
    }
    else if (cmd == 4) { // SULJE LEVY
        fclose(g_hdd_file);
        g_hdd_file = NULL;
        g_hdd_status = 0;
        printf("HDD: Close status:%d\n", g_hdd_status);
    }
}

// ---------- Musashi hooks


// --- Musashin muistikoukut (8, 16 ja 32-bittiset luvut ja kirjoitukset) ---
unsigned int m68k_read_memory_8(unsigned int address) {
    if (address <= RAM_END) return g_ram[address];
    if (address >= VRAM_START && address <= VRAM_END) return g_vram[address - VRAM_START];
    
    if (address == IO_STATUS) {
        unsigned int status = 0x02; // Lähetin valmis (Tx)
        if (g_keyboard_ready) status |= 0x01; // Vastaanotin valmis (Rx)
        return status;
    }
    if (address == IO_DATA) {
        g_keyboard_ready = 0;
        return g_keyboard_char;
    }
    if (address == HDD_STATUS) return g_hdd_status;
    return 0xFF;
}

unsigned int m68k_read_memory_16(unsigned int address) {
    if (address == HDD_SECTOR) return (g_hdd_sector >> 16) & 0xFFFF;
    if (address == HDD_SECTOR + 2) return g_hdd_sector & 0xFFFF;
    unsigned int val = m68k_read_memory_8(address) << 8;
    val |= m68k_read_memory_8(address + 1);
    return val;
}

unsigned int m68k_read_memory_32(unsigned int address) {
    if (address == HDD_SECTOR) return g_hdd_sector;
    if (address == HDD_DMA_ADDR) return g_hdd_dma_addr;
    if (address == IO_TIMER) return SDL_GetTicks(); // UUSI: Palauttaa millisekunnit käynnistyksestä
    
    unsigned int val = m68k_read_memory_16(address) << 16;
    val |= m68k_read_memory_16(address + 2);
    return val;
}


void m68k_write_memory_8(unsigned int address, unsigned int value) {
    if (address <= RAM_END) { g_ram[address] = (unsigned char)value; return; }
    if (address >= VRAM_START && address <= VRAM_END) { g_vram[address - VRAM_START] = (unsigned char)value; return; }
    
    if (address == IO_DATA) {
        //printf("[DEBUG CONOUT] Char: %d (%c)\n", value, (value >= 32 && value <= 126) ? value : '.');
        handle_terminal_write((unsigned char)value);
    }
    else if (address == HDD_COMMAND) handle_hdd_command((unsigned char)value);
}

void m68k_write_memory_16(unsigned int address, unsigned int value) {
    if (address == HDD_SECTOR) {
        g_hdd_sector = (g_hdd_sector & 0x0000FFFF) | ((value & 0xFFFF) << 16);
    } else if (address == HDD_SECTOR + 2) {
        g_hdd_sector = (g_hdd_sector & 0xFFFF0000) | (value & 0xFFFF);
    } else {
        m68k_write_memory_8(address, (value >> 8) & 0xFF);
        m68k_write_memory_8(address + 1, value & 0xFF);
    }
}

void m68k_write_memory_32(unsigned int address, unsigned int value) {
    if (address == HDD_SECTOR) g_hdd_sector = value;
    else if (address == HDD_DMA_ADDR) g_hdd_dma_addr = value;
    else {
        m68k_write_memory_16(address, (value >> 16) & 0xFFFF);
        m68k_write_memory_16(address + 2, value & 0xFFFF);
    }
}

unsigned int m68k_read_disassembler_16(unsigned int address) { return m68k_read_memory_16(address); }
unsigned int m68k_read_disassembler_32(unsigned int address) { return m68k_read_memory_32(address); }

int init_font_texture() {
    // Luodaan pintamuisti (Surface), johon fontti puretaan pikseleinä käynnistyksessä
    // Järjestetään 256 merkkiä 16 sarakkeeseen ja 16 riviin.
    int surf_w = 16 * CHAR_WIDTH;  // 16 * 8 = 128 pikseliä laajaksi
    int surf_h = 16 * CHAR_HEIGHT; // 16 * 16 = 256 pikseliä korkeaksi
    
    SDL_Surface* surf = SDL_CreateSurface(surf_w, surf_h, SDL_PIXELFORMAT_RGBA8888);
    if (!surf) return 0;

    // Täytetään pinta aluksi täysin läpinäkyvällä mustalla
    SDL_FillSurfaceRect(surf, NULL, SDL_MapRGBA(SDL_GetPixelFormatDetails(surf->format), NULL, 0, 0, 0, 0));
    uint32_t* pixels = (uint32_t*)surf->pixels;

    for (int ch = 0; ch < 256; ch++) {
        // Lasketaan missä kohdassa isoa 16x16-ruudukkoa tämä merkki sijaitsee
        int font_grid_x = (ch % 16) * CHAR_WIDTH;
        int font_grid_y = (ch / 16) * CHAR_HEIGHT;

        // Käydään läpi tarkalleen KAIKKI 16 pikseliriviä alusta loppuun
        for (int y = 0; y < CHAR_HEIGHT; y++) {
            unsigned char byte = g_font_bitmap[ch][y];
            
            // Käydään läpi merkin 8 vaakapikseliä (bittiä)
            for (int x = 0; x < CHAR_WIDTH; x++) {
                int px = font_grid_x + x;
                int py = font_grid_y + y;
                
                if (byte & (0x80 >> x)) {
                    // Merkitään fontin bitti puhtaaksi valkoiseksi (SDL värjää sen lennosta vihreäksi)
                    pixels[py * surf_w + px] = 0xFFFFFFFF; 
                } else {
                    // Tausta jätetään kokonaan läpinäkyväksi
                    pixels[py * surf_w + px] = 0x00000000;
                }
            }
        }
    }

    // Tehdään valmiista pinnasta näytönohjaimen tekstuuri ja vapautetaan CPU-muisti
    g_font_texture = SDL_CreateTextureFromSurface(g_renderer, surf);
    SDL_DestroySurface(surf);
    
    return g_font_texture != NULL;
}



void render_vram() {
    // 1. Tyhjennetään päänäyttö (ikkuna) suoraan mustaksi
    SDL_SetRenderTarget(g_renderer, NULL);
    SDL_SetRenderDrawColor(g_renderer, 0, 0, 0, 255);
    SDL_RenderClear(g_renderer);

    int show_cursor = (SDL_GetTicks() / 500) % 2;

    // 2. Piirretään VGA-tekstiruudukko SUORAAN ikkunaan näytönohjaimen rautakiihdytyksellä
    for (int row = 0; row < GRID_ROWS; row++) {
        for (int col = 0; col < GRID_COLS; col++) {
            unsigned char ch = g_vram[row * GRID_COLS + col];
            
            if (row == g_cursor_y && col == g_cursor_x && show_cursor) {
                ch = 219; // Kursori (█)
            }

            // Lasketaan mistä kohtaa isoa fonttitekstuuria tämä merkki löytyy
            SDL_FRect src_rect;
            src_rect.x = (float)((ch % 16) * CHAR_WIDTH);
            src_rect.y = (float)((ch / 16) * CHAR_HEIGHT);
            src_rect.w = (float)CHAR_WIDTH;
            src_rect.h = (float)CHAR_HEIGHT;

            // Lasketaan mihin kohtaan emulaattorin ikkunaa merkki asetetaan
            SDL_FRect dst_rect;
            dst_rect.x = (float)(col * CHAR_WIDTH);
            dst_rect.y = (float)(row * CHAR_HEIGHT);
            dst_rect.w = (float)CHAR_WIDTH;
            dst_rect.h = (float)CHAR_HEIGHT;

            // Asetetaan perinteinen ja kirkas retro-vihreä väri tekstille
            SDL_SetTextureColorMod(g_font_texture, 34, 255, 34);

            // Piirretään merkki ruudulle
            SDL_RenderTexture(g_renderer, g_font_texture, &src_rect, &dst_rect);
        }
    }

    // 3. Heitetään kuva suoraan näkyviin ilman mitään maskeja
    SDL_RenderPresent(g_renderer);
}



int load_raw_font(const char* filepath) {
    FILE* file = fopen(filepath, "rb");
    if (!file) return 0;
    size_t read = fread(g_font_bitmap, 1, sizeof(g_font_bitmap), file);
    fclose(file);
    return read == sizeof(g_font_bitmap);
}

int load_rom_image(const char* filepath, unsigned int target_address) {
    FILE* file = fopen(filepath, "rb");
    if (!file) return 0;
    fseek(file, 0, SEEK_END);
    long size = ftell(file);
    fseek(file, 0, SEEK_SET);
    size_t read = fread(&g_ram[target_address], 1, size, file);
    fclose(file);
    return (long)read == size;
}


void print_cpu_debug_dump(void) {
    printf("\n=================== TEHO68K CPU DEBUG DUMP ===================\n");
    
    // Luetaan rekisterit Musashin API:sta
    unsigned int pc = m68k_get_reg(NULL, M68K_REG_PC);
    unsigned int sp = m68k_get_reg(NULL, M68K_REG_SP);
    unsigned int sr = m68k_get_reg(NULL, M68K_REG_SR);
    
    // Tulostetaan tärkeimmät tilarekisterit ja osoittimet
    printf("PC (Program Counter) : 0x%08X\n", pc);
    printf("SP (Stack Pointer)   : 0x%08X\n", sp);
    printf("SR (Status Register) : 0x%04X\n\n", sr);
    
    // Tulostetaan Datarekisterit (D0-D7)
    printf("Datarekisterit:\n");
    for(int i = 0; i < 8; i++) {
        printf("  D%d: 0x%08X", i, m68k_get_reg(NULL, M68K_REG_D0 + i));
        if (i == 3 || i == 7) printf("\n");
    }
    
    // Tulostetaan Osoiterekisterit (A0-A7)
    printf("Osoiterekisterit:\n");
    for(int i = 0; i < 8; i++) {
        printf("  A%d: 0x%08X", i, m68k_get_reg(NULL, M68K_REG_A0 + i));
        if (i == 3 || i == 7) printf("\n");
    }
    
    // Viimeisimmän suoritetun käskyn (Disassembly) selvittäminen PC-osoitteesta
    printf("\nViimeisin suoritettu käsky (PC:n kohdalla):\n");
    char disasm_buffer[100];
    // Musashin sisäinen disassembler purkaa käskyn tekstiksi muistista
    m68k_disassemble(disasm_buffer, pc, M68K_CPU_TYPE_68000);
    printf("  --> 0x%08X: %s\n", pc, disasm_buffer);
    
    printf("==============================================================\n\n");
}


int main(int argc, char* argv[]) {
    (void)argc; (void)argv;

    g_ram = (unsigned char*)calloc(RAM_SIZE, 1);
    g_vram = (unsigned char*)calloc(VRAM_SIZE, 1);
    if (!g_ram || !g_vram) return -1;
    memset(g_vram, ' ', VRAM_SIZE);

    // Alustetaan SDL3 videojärjestelmä
    if (!SDL_Init(SDL_INIT_VIDEO)) return -1;

    // Luodaan ikkuna ja renderöijä
    g_window = SDL_CreateWindow("Tiny M68K VGA Text Emulator", WINDOW_WIDTH, WINDOW_HEIGHT, 0);
    g_renderer = SDL_CreateRenderer(g_window, NULL);
    if (!g_window || !g_renderer) return -1;

    // 1. Asetetaan looginen resoluutio (Skaalataan emulaattorin oma kuva isompaan ikkunaan)
    SDL_SetRenderLogicalPresentation(g_renderer, VIRTUAL_WIDTH, VIRTUAL_HEIGHT, SDL_LOGICAL_PRESENTATION_LETTERBOX);

    // 2. KORJATTU JA VIRALLINEN SDL3 RIVI: 
    // Lukitaan tekstuurin skaalaus retrohenkisen teräväksi (Nearest Neighbor)
    if (g_font_texture) {
        SDL_SetTextureScaleMode(g_font_texture, SDL_SCALEMODE_NEAREST);
    }

    // Ladataan IBM VGA-raakafontti ja rakennetaan siitä GPU-tekstuuri
    if (!load_raw_font(fontname) || !init_font_texture()) {
        fprintf(stderr, "Fontin lataus epäonnistui.\n");
        return -1;
    }
    printf("Fontin lataus onnistui.\n");

    // Ladataan 68000-ohjelmakoodi ROM-alueelle
    if (!load_rom_image("ROM/boot_rom.bin", 0x00000000)) {
        fprintf(stderr, "ROM-lataus epäonnistui!\n");
        return -1;
    }

    SDL_StartTextInput(g_window);

    m68k_init();
    m68k_set_cpu_type(M68K_CPU_TYPE_68000);

    // Haetaan käynnistysvektorit
    unsigned int initial_sp = (g_ram[0] << 24) | (g_ram[1] << 16) | (g_ram[2] << 8) | g_ram[3];
    unsigned int initial_pc = (g_ram[4] << 24) | (g_ram[5] << 16) | (g_ram[6] << 8) | g_ram[7];

    m68k_write_memory_32(0, initial_sp); 
    m68k_write_memory_32(4, initial_pc);   
    m68k_pulse_reset();

    int running = 1;
    SDL_Event event;



    while(running) {
        while (SDL_PollEvent(&event)) {
            if (event.type == SDL_EVENT_QUIT) {            
                running = 0;
            }
            else if (event.type == SDL_EVENT_TEXT_INPUT) {
                unsigned char ch = (unsigned char)event.text.text[0];
                if (ch >= 32 && ch <= 126) {
                    g_keyboard_char = ch;
                    g_keyboard_ready = 1;
                }
            }
            else if (event.type == SDL_EVENT_KEY_DOWN) {
                SDL_Keycode key = event.key.key;
                if (key == SDLK_RETURN) {
                    g_keyboard_char = 13;
                    g_keyboard_ready = 1;
                } else if (key == SDLK_BACKSPACE) {
                    g_keyboard_char = 8;
                    g_keyboard_ready = 1;
                }
            }
        }

        m68k_execute(4096);

        
        render_vram();
        SDL_Delay(16); 
    }

    print_cpu_debug_dump();


    if (g_hdd_file) fclose(g_hdd_file);
    if (g_font_texture) SDL_DestroyTexture(g_font_texture);
    SDL_DestroyRenderer(g_renderer);
    SDL_DestroyWindow(g_window);
    SDL_Quit();
    free(g_ram); free(g_vram);
    return 0;
}
