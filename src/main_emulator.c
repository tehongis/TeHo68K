#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <SDL.h>
#include "m68k.h"

// Hardware-konfiguraatio
#define RAM_SIZE       (1024 * 1024)           // 1 MB RAM
#define GRID_COLS      80
#define GRID_ROWS      40
#define VRAM_SIZE      (GRID_COLS * GRID_ROWS) // 3200 tavua tekstipuskuria
#define SECTOR_SIZE    512                     // 512 tavun kiintolevysektori

// Fontin ja ikkunan mitat
#define CHAR_WIDTH     8
#define CHAR_HEIGHT    16
#define WINDOW_WIDTH   (GRID_COLS * CHAR_WIDTH)   // 640 px
#define WINDOW_HEIGHT  (GRID_ROWS * CHAR_HEIGHT)  // 640 px

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


// Globaalit muistipuskurit
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

// Käsittelee HDD_COMMAND-rekisteriin tehdyt kirjoitukset isäntäkoneen puolella
void handle_hdd_command(unsigned char cmd) {
    if (cmd == 1) { // AVAA LEVY
        if (!g_hdd_file) {
            g_hdd_file = fopen("HDD/virtual_disk.img", "r+b");
            if (!g_hdd_file) {
                // Jos image puuttuu, luodaan automaattisesti tyhjä 1MB testi-image
                g_hdd_file = fopen("HDD/virtual_disk.img", "w+b");
                if (g_hdd_file) {
                    unsigned char* dummy = calloc(1024 * 1024, 1);
                    fwrite(dummy, 1, 1024 * 1024, g_hdd_file);
                    free(dummy);
                    fseek(g_hdd_file, 0, SEEK_SET);
                }
            }
        }
        g_hdd_status = (g_hdd_file) ? 0 : 0xFF;
        return;
    }

    if (!g_hdd_file) {
        g_hdd_status = 0xFF; // Ei avattua levykuvaa käytettävissä
        return;
    }

    // Lasketaan 512 tavun lohkon siirtymä tiedostossa
    long offset = (long)g_hdd_sector * SECTOR_SIZE;
    fseek(g_hdd_file, offset, SEEK_SET);

    if (cmd == 2) { // LUE SEKTORI (Siirto levyltä RAMiin DMA-osoitteeseen)
        if (g_hdd_dma_addr + SECTOR_SIZE <= RAM_SIZE) {
            size_t read = fread(&g_ram[g_hdd_dma_addr], 1, SECTOR_SIZE, g_hdd_file);
            g_hdd_status = (read == SECTOR_SIZE) ? 0 : 0xFF;
        } else {
            g_hdd_status = 0xFF; // Muistin ylitysvirhe
        }
    } 
    else if (cmd == 3) { // KIRJOITA SEKTORI (Siirto RAMista levylle)
        if (g_hdd_dma_addr + SECTOR_SIZE <= RAM_SIZE) {
            size_t written = fwrite(&g_ram[g_hdd_dma_addr], 1, SECTOR_SIZE, g_hdd_file);
            fflush(g_hdd_file);
            g_hdd_status = (written == SECTOR_SIZE) ? 0 : 0xFF;
        } else {
            g_hdd_status = 0xFF;
        }
    }
    else if (cmd == 4) { // SULJE LEVY
        fclose(g_hdd_file);
        g_hdd_file = NULL;
        g_hdd_status = 0;
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
    
    if (address == IO_DATA) handle_terminal_write((unsigned char)value);
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

void render_vram() {
    SDL_SetRenderDrawColor(g_renderer, 0, 0, 0, 255);
    SDL_RenderClear(g_renderer);

    // Lasketaan vilkuntavaihe SDL-millisekunneista (vaihtuu 500ms välein)
    int show_cursor = (SDL_GetTicks() / 500) % 2;

    for (int row = 0; row < GRID_ROWS; row++) {
        for (int col = 0; col < GRID_COLS; col++) {
            unsigned char ch = g_vram[row * GRID_COLS + col];
            
            // Jos ollaan kursorin kohdalla ja vilkuntavaihe on aktiivinen,
            // korvataan taustamerkki CP437 täydellä laatikolla (219 = █)
            if (row == g_cursor_y && col == g_cursor_x && show_cursor) {
                ch = 219; 
            }

            for (int y = 0; y < CHAR_HEIGHT; y++) {
                unsigned char byte = g_font_bitmap[ch][y];
                for (int x = 0; x < CHAR_WIDTH; x++) {
                    if (byte & (0x80 >> x)) {
                        SDL_SetRenderDrawColor(g_renderer, 0, 255, 0, 255); 
                        SDL_RenderDrawPoint(g_renderer, (col * CHAR_WIDTH) + x, (row * CHAR_HEIGHT) + y);
                    }
                }
            }
        }
    }
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

int main(int argc, char* argv[]) {
    g_ram = (unsigned char*)calloc(RAM_SIZE, 1);
    g_vram = (unsigned char*)calloc(VRAM_SIZE, 1);
    memset(g_vram, ' ', VRAM_SIZE);

    if (SDL_Init(SDL_INIT_VIDEO) < 0 || !g_ram || !g_vram) return -1;

    g_window = SDL_CreateWindow("M68K Tiny BASIC Emulator", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, WINDOW_WIDTH, WINDOW_HEIGHT, SDL_WINDOW_SHOWN);
    g_renderer = SDL_CreateRenderer(g_window, -1, SDL_RENDERER_ACCELERATED);

    SDL_StartTextInput();

    // KORJATTU OSOITE: ladataan rom.bin suoraan muistin alkuun (0x00000000)
    if (!load_raw_font("font_8x16_raw.bin") || !load_rom_image("ROM/rom.bin", 0x00000000)) {
        fprintf(stderr, "Tiedostojen lataus epäonnistui!\n");
        return -1;
    }

    m68k_init();
    m68k_set_cpu_type(M68K_CPU_TYPE_68000);

    // KORJATTU VEKTORILUKU: Luetaan käynnistysvektorit sieltä minne ne kuuluu eli rom.bin:in alusta.
    // Koska vasm luo Big-Endian-tavuja ja x86-koneesi on Little-Endian, poimitaan tavut oikeassa järjestyksessä:
    unsigned int initial_sp = (g_ram[0] << 24) | (g_ram[1] << 16) | (g_ram[2] << 8) | g_ram[3];
    unsigned int initial_pc = (g_ram[4] << 24) | (g_ram[5] << 16) | (g_ram[6] << 8) | g_ram[7];

    // Syötetään poimitut ja korjatut Big-Endian-osoitteet suorittimelle
    m68k_write_memory_32(0, initial_sp); 
    m68k_write_memory_32(4, initial_pc);   
    m68k_pulse_reset();


    int running = 1;
    SDL_Event event;

    while(running) {
        while (SDL_PollEvent(&event)) {
            if (event.type == SDL_QUIT) {
                running = 0;
            }
            // UUSI: Hoitaa kaikki tavalliset merkit ja Shift-yhdistelmät (kuten Shift+2 = ")
            else if (event.type == SDL_TEXTINPUT) {
                // SDL_TEXTINPUT palauttaa UTF-8 merkkijonon, poimitaan ensimmäinen tavu (ASCII)
                unsigned char ch = (unsigned char)event.text.text[0];
                
                // Varmistetaan, että merkki on emulaattorille sopiva tulostettava ASCII
                if (ch >= 32 && ch <= 126) {
                    g_keyboard_char = ch;
                    g_keyboard_ready = 1;
                }
            }
            // MUUTETTU: Hoitaa vain ohjausnäppäimet, joita tekstinsyöttö ei poimi
            else if (event.type == SDL_KEYDOWN) {
                SDL_Keycode key = event.key.keysym.sym;
                
                if (key == SDLK_RETURN) {
                    g_keyboard_char = 13; // Carriage Return Tiny BASICille
                    g_keyboard_ready = 1;
                } else if (key == SDLK_BACKSPACE) {
                    g_keyboard_char = 8;  // Backspace
                    g_keyboard_ready = 1;
                }
            }
        }

    m68k_execute(50000);
    render_vram();
    SDL_Delay(16); 
    }

    if (g_hdd_file) fclose(g_hdd_file);
    SDL_DestroyRenderer(g_renderer); SDL_DestroyWindow(g_window); SDL_Quit();
    free(g_ram); free(g_vram);
    return 0;
}
