CC      = gcc
# Päivitetty käyttämään pkg-configia ja sdl3:a
CFLAGS  = -Wall -Wextra -O2 $(shell pkg-config --cflags sdl3)
# Päivitetty linkittämään sdl3:een sdl2-configin sijaan
LIBS    = $(shell pkg-config --libs sdl3) -lm

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
HDD_IMG  = $(HDD_DIR)/virtual_disk.img

ASM = vasmm68k_mot
ASM_FLAGS = -ldots -Fbin

.PHONY: default all clean directories musashi_gen run

default: run

# all-kohde varmistaa nyt myös fontin, ROMin, emulaattorin ja CP/M-kiintolevyn kääntymisen
all: directories $(ROM_DIR)/boot_rom.bin $(HDD_IMG) $(TARGET)

run: all
	./$(TARGET)

$(TARGET): $(OBJ)
	$(CC) $(OBJ) -o $(TARGET) $(LIBS)

# Käännetään Cold Start ROM -monitori
$(ROM_DIR)/boot_rom.bin: $(ASM_DIR)/boot_rom.asm
	$(ASM) $(ASM_FLAGS) -I$(ASM_DIR) -L $(ROM_DIR)/boot_rom.lst -o $(ROM_DIR)/boot_rom.bin $(ASM_DIR)/boot_rom.asm

# Käännetään CP/M-käyttöjärjestelmän osat ja pakataan ne kiintolevykuvaksi Python-skriptillä
$(HDD_IMG): make_disk.py $(ASM_DIR)/ccp.asm $(ASM_DIR)/bdos.asm $(ASM_DIR)/bios.asm
	@if [ -f make_disk.py ]; then \
		echo "Käännetään CP/M-moduulit ja luodaan virtuaalinen kiintolevy..."; \
		python3 make_disk.py; \
	else \
		echo "VIRHE: make_disk.py puuttuu juuresta!"; \
		exit 1; \
	fi

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
	rm -f $(SRC_DIR)/*.o $(TARGET)
	rm -f $(ROM_DIR)/boot_rom.bin $(ROM_DIR)/*.lst
	rm -f $(ROM_DIR)/ccp.bin $(ROM_DIR)/bdos.bin $(ROM_DIR)/bios.bin
	rm -f $(HDD_DIR)/virtual_disk.img
	rm -f $(MUSASHI_DIR)/*.o
	rm -f $(MUSASHI_DIR)/softfloat/*.o

