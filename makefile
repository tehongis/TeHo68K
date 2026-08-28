CC      = gcc
CFLAGS  = -Wall -Wextra -O2 $(shell sdl2-config --cflags)
# KORJATTU: Poistettu -lSDL2_image, koska käytetään raakabinäärifonttia
LIBS    = $(shell sdl2-config --libs) -lm

# Polku Musashi-kansioon (isolla M-kirjaimella)
MUSASHI_DIR = ../Musashi
CFLAGS += -I$(MUSASHI_DIR)

SRC_DIR     = src
ASM_DIR     = asm
ROM_DIR     = ROM
HDD_DIR     = HDD

SRC         = $(SRC_DIR)/main_emulator.c

# Musashi-lähdekoodit mukaan lukien m68kdasm.c
MUSASHI_SRC = $(MUSASHI_DIR)/m68kcpu.c \
              $(MUSASHI_DIR)/m68kops.c \
              $(MUSASHI_DIR)/m68kdasm.c \
              $(MUSASHI_DIR)/softfloat/softfloat.c

OBJ = $(SRC:.c=.o) $(MUSASHI_SRC:.c=.o)

TARGET   = emulator
FONT_BIN = font_8x16_raw.bin

ASM = vasmm68k_mot
ASM_FLAGS = -Fbin

.PHONY: default all clean directories musashi_gen run

default: run

# all-kohde varmistaa nyt myös fontin ja molempien assemblerkoodien kääntymisen
all: directories $(FONT_BIN) $(ROM_DIR)/rom.bin $(TARGET)

run: all
	./$(TARGET)

# AUTOMAATTINEN FONTIGENEROINTI: Jos raakafonttia ei ole, ajetaan python-skripti lennosta
$(FONT_BIN):
	@if [ -f convert_font.py ]; then \
		echo "Generoidaan raakafontti Python-skriptillä..."; \
		python3 convert_font.py; \
	else \
		echo "VIRHE: $(FONT_BIN) puuttuu, eikä convert_font.py-skriptiä löytynyt!"; \
		exit 1; \
	fi

$(TARGET): $(OBJ)
	$(CC) $(OBJ) -o $(TARGET) $(LIBS)

$(ROM_DIR)/rom.bin: $(ASM_DIR)/rom_monitor.asm $(ASM_DIR)/tinybasic.asm $(ASM_DIR)/HAL.i
	$(ASM) $(ASM_FLAGS) -I$(ASM_DIR) -L rom.lst -o $(ROM_DIR)/rom.bin $(ASM_DIR)/rom_monitor.asm

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

directories:
	@mkdir -p $(SRC_DIR)
	@mkdir -p $(ASM_DIR)
	@mkdir -p $(ROM_DIR)
	@mkdir -p $(HDD_DIR)

musashi_gen:
	cd $(MUSASHI_DIR) && ./m68kmake

clean:
	rm -f $(SRC_DIR)/*.o $(TARGET) $(ROM_DIR)/rom.bin
	rm -f $(MUSASHI_DIR)/*.o
	rm -f $(MUSASHI_DIR)/softfloat/*.o
