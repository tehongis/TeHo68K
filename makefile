CC      = gcc
CFLAGS  = -Wall -Wextra -O2 $(shell sdl2-config --cflags)
LIBS    = $(shell sdl2-config --libs) -lm

# Polku Musashi-kansioon (isolla M-kirjaimella)
MUSASHI_DIR = ../Musashi
CFLAGS += -I$(MUSASHI_DIR)

SRC_DIR     = src
ASM_DIR     = asm
ROM_DIR     = ROM
HDD_DIR     = HDD

# KORJATTU: Poistettu ylimääräinen $ merkki kommentin edestä
SRC = $(SRC_DIR)/main_emulator.c #(SRC_DIR)/memory_bus.c

# LISÄTTY: m68kdasm.c mukaan disassembleria varten
MUSASHI_SRC = $(MUSASHI_DIR)/m68kcpu.c \
              $(MUSASHI_DIR)/m68kops.c \
              $(MUSASHI_DIR)/m68kdasm.c \
              $(MUSASHI_DIR)/softfloat/softfloat.c

OBJ = $(SRC:.c=.o) $(MUSASHI_SRC:.c=.o)

TARGET = emulator

ASM = vasmm68k_mot
ASM_FLAGS = -Fbin

# UUSI: Lisätty 'run' PHONY-listalle
.PHONY: default all clean directories musashi_gen run

# UUSI: Asetetaan oletusmaaliksi 'run', joka ajaa emulaattorin käännöksen jälkeen
default: run

all: directories $(ROM_DIR)/rom.bin $(TARGET)
	@if [ ! -f $(ROM_DIR)/font_8x8_raw.bin ]; then \
		echo "HUOMAUTUS: Muista sijoittaa font_8x8_raw.bin kansioon $(ROM_DIR)/ ennen ajoa!"; \
	fi

# UUSI: 'make run' kääntää tarvittaessa kaiken ja käynnistää binäärin
run: all
	./$(TARGET)

$(TARGET): $(OBJ)
	$(CC) $(OBJ) -o $(TARGET) $(LIBS)

$(ROM_DIR)/rom.bin: $(ASM_DIR)/rom_monitor.asm $(ASM_DIR)/HAL.i
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
