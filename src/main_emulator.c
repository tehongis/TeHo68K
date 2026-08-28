#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <SDL2/SDL.h>
#include <unistd.h>
#include <sys/select.h>

#include "HAL.h"
#include "m68k.h"

/* =============================================================================
 * GLOBAALIT EMULAATTORIMUUTTUJAT
 * =============================================================================
 */
uint8_t* system_ram = NULL;
bool is_running = true;

/* Muuttujien alustukset */
// uint8_t* system_ram = NULL;
volatile uint8_t uart_rx_char = 0;
volatile bool uart_rx_ready = false;
volatile int g_cpu_stopped = 0;

unsigned int cpu_type = SYSTEM_CPU_TYPE;
unsigned int current_pc = 0;

unsigned char uart_in_data = 0;  // Tänne tallennetaan PC:ltä saapunut näppäin

//unsigned char* vram_buffer = NULL;
//unsigned char* palette_buffer = NULL;

SDL_Window* window = NULL;
SDL_Renderer* renderer = NULL;
SDL_Texture* texture = NULL; // Sijaitsee muistissa heti puskuriosoittimien vieressä!
SDL_Palette* sdl_palette = NULL;

volatile bool vram_dirty = false; // Kertoo SDL:lle, että ruutu pitää piirtää uudestaan

void memory_bus_init(void) {
    system_ram = calloc(1, SYSTEM_MEM_SIZE);
    if (!system_ram) {
        fprintf(stderr, "Keskusmuistin varaus epäonnistui!\n");
        exit(EXIT_FAILURE);
    }
}

void memory_bus_cleanup(void) {
    if (system_ram) {
        free(system_ram);
        system_ram = NULL;
    }
}

void dump_cpu_status(void) {

    printf("\n=================== CPU REGISTERS DUMP ===================\n");
    printf("D0: 0x%08X  D1: 0x%08X  D2: 0x%08X  D3: 0x%08X\n",
           m68k_get_reg(NULL, M68K_REG_D0), m68k_get_reg(NULL, M68K_REG_D1),
           m68k_get_reg(NULL, M68K_REG_D2), m68k_get_reg(NULL, M68K_REG_D3));
    printf("D4: 0x%08X  D5: 0x%08X  D6: 0x%08X  D7: 0x%08X\n",
           m68k_get_reg(NULL, M68K_REG_D4), m68k_get_reg(NULL, M68K_REG_D5),
           m68k_get_reg(NULL, M68K_REG_D6), m68k_get_reg(NULL, M68K_REG_D7));
    printf("----------------------------------------------------------\n");
    printf("A0: 0x%08X  A1: 0x%08X  A2: 0x%08X  A3: 0x%08X\n",
           m68k_get_reg(NULL, M68K_REG_A0), m68k_get_reg(NULL, M68K_REG_A1),
           m68k_get_reg(NULL, M68K_REG_A2), m68k_get_reg(NULL, M68K_REG_A3));
    printf("A4: 0x%08X  A5: 0x%08X  A6: 0x%08X  A7: 0x%08X (SP)\n",
           m68k_get_reg(NULL, M68K_REG_A4), m68k_get_reg(NULL, M68K_REG_A5),
           m68k_get_reg(NULL, M68K_REG_A6), m68k_get_reg(NULL, M68K_REG_A7));
    printf("----------------------------------------------------------\n");
    printf("PC: 0x%08X  SR: 0x%04X\n", 
           m68k_get_reg(NULL, M68K_REG_PC), m68k_get_reg(NULL, M68K_REG_SR));
    printf("==========================================================\n\n");

    printf("\n--- DISASSEMBLY AROUND PC (0x%08X) ---\n", current_pc);
    unsigned int inspect_pc = current_pc;
    char disasm_buffer[128];

    for (int i = 0; i < 5; i++) {
        // m68k_disassemble palauttaa puretun komennon pituuden tavuina
        unsigned int bytes_consumed = m68k_disassemble(disasm_buffer, inspect_pc, cpu_type);
        
        // Tulostetaan nuoli nykyisen suorituskohdan kohdalle
        char marker = (inspect_pc == current_pc) ? '>' : ' ';
        
        printf("%c 0x%08X: %s\n", marker, inspect_pc, disasm_buffer);
        
        // Siirrytään seuraavan komennon osoitteeseen
        inspect_pc += bytes_consumed;
    }
    printf("---------------------------------------\n");
}

void dump_vram_start(int count) {
    // KORJAUS: Tarkistetaan system_ram, koska erillistä vram_bufferia ei enää ole
    if (system_ram == NULL) {
        printf("[VRAM DUMP] Virhe: system_ram on NULL!\n");
        return;
    }

    printf("\n--- VRAM-PUSKURIN ALKU (Ensimmäiset %d pikseliä osoitteesta 0x%08X) ---\n", count, VRAM_START);
    for (int i = 0; i < count; i++) {
        // Tulostetaan 16 heksalukua per rivi luettavuuden vuoksi
        if (i > 0 && i % 16 == 0) {
            printf("\n");
        }
        // KORJAUS: Luetaan data suoraan päämuistista VRAM-offsetin kohdalta
        printf("%02X ", system_ram[VRAM_START + i]);
    }
    printf("\n------------------------------------------------------\n\n");
}

/*
void handle_trap_file_system(unsigned int command_id) {
    // TRAP #10 - Passthrough to Host OS "HDD/" folder
    uint32_t name_len = m68k_read_memory_32(FS_NAME_LEN);
    char filename[65];
    
    if (name_len > 64) name_len = 64;
    for (uint32_t i = 0; i < name_len; i++) {
        filename[i] = m68k_read_memory_8(FS_NAME_BASE + i);
    }
    filename[name_len] = '\0';

    char full_path[256];
    snprintf(full_path, sizeof(full_path), "HDD/%s", filename);

    switch (command_id) {
        case 0x00000003: { // HAL_FS_LOAD_FILE
            // Haetaan kohdemuistiosoite Musashin A0-rekisteristä
            unsigned int target_addr = m68k_get_reg(NULL, M68K_REG_A0);
            
            FILE* f = fopen(full_path, "rb");
            if (!f) {
                m68k_set_reg(M68K_REG_D0, -1); // Virhekoodi d0-rekisteriin
                break;
            }
            
            // Luetaan tiedosto suoraan emuloituun keskusmuistiin
            size_t bytes_read = fread(&system_ram[target_addr], 1, SYSTEM_MEM_SIZE - target_addr, f);
            fclose(f);
            
            m68k_set_reg(M68K_REG_D0, 0); // Onnistui
            printf("[HOST HDD] Ladattu tiedosto %s osoitteeseen 0x%08X (%zu tavua)\n", filename, target_addr, bytes_read);
            break;
        }
        case 0x00000004: { // HAL_FS_SAVE_FILE
            // Tähän voi myöhemmin toteuttaa tiedoston tallennuksen host-koneelle
            break;
        }
        default:
            break;
    }
}
*/

unsigned int m68k_read_memory_8(unsigned int address) {
    if (address < SYSTEM_MEM_SIZE) {
        if (address == UART_IN_ADDR) {
            // 68k-ohjelma haki näppäinkoodin. Palautetaan se.
            return uart_in_data;
        }    

        if (address >= VRAM_START && address < VRAM_START + VRAM_SIZE) {
            system_ram[address];
        }

        if (address >= PALETTE_START && address < PALETTE_START + PALETTE_SIZE) {
            system_ram[address];
        }
        return system_ram[address];
    }
    printf("Memory read outside of memory range: $%08x\n",address);
    return 0;
}

unsigned int m68k_read_memory_16(unsigned int address) {
    if (address < SYSTEM_MEM_SIZE) {
        return (system_ram[address] << 8) | system_ram[address + 1];
    }
    return 0;
}

unsigned int m68k_read_memory_32(unsigned int address) {
    return (m68k_read_memory_16(address) << 16) | m68k_read_memory_16(address + 2);
}

void m68k_write_memory_8(unsigned int address, unsigned int value) {
    if (address < SYSTEM_MEM_SIZE) {

        if (address == UART_OUT_ADDR) {
            // 1. 68k kirjoitti merkkiporttiin -> Tulostetaan se isäntäkoneen konsoliin
            putchar((char)value);
            fflush(stdout); // Varmistetaan, että merkki tulostuu heti

            // 2. Nostetaan välittömästi IRQ 2. 
            // Tämä ilmoittaa 68k-ohjelmalle (keskeytyksellä), että UART on vapaa seuraavalle merkille.
            m68k_set_irq(2);
            return;        
        } 

        if (address >= VRAM_START && address < VRAM_START + VRAM_SIZE) {
            system_ram[address] = (unsigned char)value;
            vram_dirty = true; // MERKITÄÄN RUUTU DIRTYKSI!
            return;
        }
        if (address >= PALETTE_START && address < PALETTE_START + PALETTE_SIZE) {
            system_ram[address] = (unsigned char)value;
            unsigned int offset = address - PALETTE_START;
            // Etsitään, mihin väri-indeksiin (0-255) tämä tavu kuuluu
            int color_index = offset / 4;
           unsigned int base = PALETTE_START + (color_index * 4);
                                 
            // 5. Päivitetään SDL-paletti (jos se on olemassa)
            if (sdl_palette != NULL) {
                SDL_Color color;
                color.a = 255; // Alpha unohdetaan
                
                // Luetaan värit suoraan system_ramista 68k:n Big-Endian -offseteistä
                color.r = system_ram[base + 1]; // Red
                color.g = system_ram[base + 2]; // Green
                color.b = system_ram[base + 3]; // Blue
                
                SDL_SetPaletteColors(sdl_palette, &color, color_index, 1);
            }            
            // Päivitetään väri SDL-palettiin
            vram_dirty = true; // MERKITÄÄN RUUTU DIRTYKSI!
            return;
        }

        system_ram[address] = value & 0xFF;
        return;
    }
    printf("Memory write outside of memory range: $%08x\n",address);
}

void m68k_write_memory_16(unsigned int address, unsigned int value) {
    if (address < SYSTEM_MEM_SIZE) {
        system_ram[address] = (value >> 8) & 0xFF;
        system_ram[address + 1] = value & 0xFF;
    }
}

void m68k_write_memory_32(unsigned int address, unsigned int value) {
    m68k_write_memory_16(address, (value >> 16) & 0xFFFF);
    m68k_write_memory_16(address + 2, value & 0xFFFF);
}

/* Musashin vaatimat sisäiset luku-hookit */
unsigned int m68k_read_immediate_16(unsigned int address) { return m68k_read_memory_16(address); }
unsigned int m68k_read_immediate_32(unsigned int address) { return m68k_read_memory_32(address); }
unsigned int m68k_read_pcrelative_8(unsigned int address)  { return m68k_read_memory_8(address); }
unsigned int m68k_read_pcrelative_16(unsigned int address) { return m68k_read_memory_16(address); }
unsigned int m68k_read_pcrelative_32(unsigned int address) { return m68k_read_memory_32(address); }

unsigned int m68k_read_disassembler_8(unsigned int address)  { return m68k_read_memory_8(address); }
unsigned int m68k_read_disassembler_16(unsigned int address) { return m68k_read_memory_16(address); }
unsigned int m68k_read_disassembler_32(unsigned int address) { return m68k_read_memory_32(address); }

void cpu_instruction_callback(unsigned int pc) {
    unsigned int opcode = m68k_read_memory_16(pc);
    
    if ((opcode & 0xFFF0) == 0x4E40) {
        unsigned int trap_vector = opcode & 0x000F;
        unsigned int command_id = m68k_get_reg(NULL, M68K_REG_D0);

        if (trap_vector == 10) {
            printf("Trap 10 caught\n");
            //handle_trap_file_system(command_id);
        }
    }
    if (opcode == 0x4E72) { // STOP-käsky
        g_cpu_stopped = 1;
        is_running = false;

    }
}

// Alustusfunktio, jota kutsutaan ennen Musashin päälooppia
void init_video() {
    //vram_buffer = (unsigned char*)malloc(VRAM_SIZE);
    //palette_buffer = (unsigned char*)malloc(PALETTE_SIZE);
    //memset(vram_buffer, 0, VRAM_SIZE);
    //memset(palette_buffer, 0, PALETTE_SIZE);

    SDL_Init(SDL_INIT_VIDEO);
    window = SDL_CreateWindow("M68k Emulator Framebuffer", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, VRAM_X, VRAM_Y, 0);
    renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);
    
    // Luodaan 8-bittinen indeksoitu tekstuuri
    texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_RGBX8888, SDL_TEXTUREACCESS_STREAMING, VRAM_X, VRAM_Y);
    
    // Alustetaan SDL-paletti 256 värille
    sdl_palette = SDL_AllocPalette(256);
}

void render_frame(void) {
    // Luodaan staattinen puskuri, joka vastaa tismalleen 800x600 kokoisen ruudun 32-bit pikseleitä
    static uint32_t raw_pixels[ VRAM_X *  VRAM_Y];

    for (int i = 0; i <  VRAM_X *  VRAM_Y; i++) {
        uint8_t index = system_ram[VRAM_START + i];
        unsigned int base = PALETTE_START + (index * 4);
        
        // Luetaan värit emuloidusta 68k-muistista ($00RRGGBB)
        uint8_t r = system_ram[base + 1];
        uint8_t g = system_ram[base + 2];
        uint8_t b = system_ram[base + 3];
        
        // Tehdään tavuosoitin yksittäiseen pikseliin. 
        // Tämä takaa, että R, G ja B menevät muistiin tismalleen oikeassa järjestyksessä.
        uint8_t* pixel_bytes = (uint8_t*)&raw_pixels[i];
        
        // RGBX-formaatissa tavujärjestys muistissa Little-Endian -koneella (Intel/AMD) on:
        pixel_bytes[0] = b;     // Blue
        pixel_bytes[1] = g;     // Green
        pixel_bytes[2] = r;     // Red
        pixel_bytes[3] = 0;     // X (Tyhjä / ohitetaan)
    }

    // Päivitetään tekstuuri ja piirretään
    SDL_UpdateTexture(texture, NULL, raw_pixels, VRAM_X * sizeof(uint32_t));
    
    SDL_RenderClear(renderer);
    SDL_RenderCopy(renderer, texture, NULL, NULL);
    SDL_RenderPresent(renderer);

    vram_dirty = false;
}



void m68kSendKeyState(int state) {
    uart_in_data = (unsigned char)state; // Asetetaan merkki rekisteriin
    m68k_set_irq(1);                    // Nostetaan IRQ 1 (Keyboard ISR käynnistyy)
}

unsigned int m68kReadTerminal() {
    unsigned int charValue = m68k_read_memory_8(UART_IN_ADDR);
    return charValue;
}


int cpu_irq_ack_handler(int int_level) {
    // Lasketaan keskeytyslinja alas (nollataan se), koska CPU huomioi jo pyynnön
    m68k_set_irq(M68K_IRQ_NONE);

    // Käytetään standardeja M68k-autovektoreita (kuten assembly-koodissa määritettiin)
    return M68K_INT_ACK_AUTOVECTOR;
}


/* =============================================================================
 * PÄÄOHJELMA
 * =============================================================================
 */
int main(int argc, char* argv[]) {
    // Alustetaan muisti
    system_ram = malloc(SYSTEM_MEM_SIZE);
    if (!system_ram) {
        fprintf(stderr, "Virhe: Muistin varaus epäonnistui.\n");
        return -1;
    }
    memset(system_ram, 0, SYSTEM_MEM_SIZE);

    // SDL2 Alustus
    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO) < 0) {
        fprintf(stderr, "SDL alustus epäonnistui: %s\n", SDL_GetError());
        return -1;
    }

    init_video();

    // Alustetaan Musashi CPU
    m68k_init();
    m68k_set_cpu_type(SYSTEM_CPU_TYPE);
    m68k_set_instr_hook_callback(cpu_instruction_callback);

    printf("Ladataan ROM-monitoria (rom.bin)... ");
    FILE* rom_file = fopen("ROM/rom.bin", "rb");
    if (!rom_file) {
        fprintf(stderr, "\nVIRHE: rom.bin-tiedostoa ei voitu avata!\n");
        return -1;
    }
    fread(system_ram, 1, SYSTEM_MEM_SIZE, rom_file);
    fclose(rom_file);
    printf("Onnistui!\n");


    printf("Ladataan Fontti-ROMia (font_8x8_raw.bin)... ");
    FILE* font_file = fopen("ROM/font_8x8_raw.bin", "rb");
    if (!font_file) {
        fprintf(stderr, "\nVIRHE: font_8x8_raw.bin-tiedostoa ei löytynyt!\n");
        fprintf(stderr, "Varmista, että tiedosto on emulaattorin suorituspolussa.\n");
        return -1;
    }

    uint8_t* font_destination = &system_ram[FONT_ROM];

    // Luetaan fonttitiedosto suoraan Fontti-ROM-alueelle
    size_t font_bytes = fread(font_destination, 1, 2048, font_file); // 256 merkkiä * 8 tavua = 2048 tavua
    fclose(font_file);
    printf("Onnistui! (%zu tavua ladattu osoitteeseen $%08x.)\n", font_bytes,FONT_ROM);

    m68k_set_int_ack_callback(cpu_irq_ack_handler);

    m68k_pulse_reset();

    printf("Emulaattori käynnistetty. Suoritetaan CPU-sykliä...\n");

    // Päälooppi
    SDL_Event event;
    uint32_t last_tick = SDL_GetTicks();


    while (is_running) {
        // Käsitellään SDL-tapahtumat (Hiiri & Näppäimistö I/O)
        while (SDL_PollEvent(&event)) {
            if (event.type == SDL_QUIT) {
                is_running = false;
            }
            if (event.type == SDL_KEYDOWN) {      
                if (event.key.repeat == 0) {
                    SDL_Keycode key = event.key.keysym.sym;
                    m68kSendKeyState(key);
                }
            }
        }

        // Suoritetaan Musashi-CPU:ta pätkissä.
        m68k_execute(4096);
        current_pc = m68k_get_reg(NULL, M68K_REG_PC);

        render_frame(); // Tämä piirtää VAIN jos vram_dirty == true      

        SDL_Delay(5); 
    }

    dump_cpu_status();

    dump_vram_start(1024);

    // Siivous
    SDL_DestroyTexture(texture);
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();
    
    free(system_ram);
    return 0;
}
