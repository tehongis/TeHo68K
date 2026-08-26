# ============================================================
# 68000 Virtual Computer - Makefile
# ============================================================

# --- Tools ---
CC          = gcc
VASM        = vasmm68k_mot
CFLAGS      = -Wall -Wextra -O2 -std=c11 -Iinclude -Irocket68/include
LDFLAGS     = -lSDL2 -lm
LDLIBS      = rocket68/lib/librocket68.a

# --- Directories ---
SRC_DIR     = src
ROM_DIR     = rom
HDD_DIR     = HDD
OBJ_DIR     = build
TARGET      = m68k_vm

# --- Sources ---
SRCS        = $(SRC_DIR)/main.c \
              $(SRC_DIR)/vm.c \
              $(SRC_DIR)/display.c
OBJS        = $(patsubst $(SRC_DIR)/%.c,$(OBJ_DIR)/%.o,$(SRCS))

# --- ROM Files ---
AUTOBOOT_BIN  = $(ROM_DIR)/autoboot.bin
SYSTEM_BIN    = $(HDD_DIR)/sector_0000.bin

# ============================================================
# Targets
# ============================================================

.PHONY: all rom hdd clean run install-rocket68 help

all: install-rocket68 rom hdd $(TARGET)
	@echo "=== Build complete: ./$(TARGET) ==="

# --- Rocket 68 Library ---
install-rocket68:
	@if [ ! -f rocket68/lib/librocket68.a ]; then \
		echo "Building Rocket 68..."; \
		git clone https://github.com/habedi/rocket68 rocket68 2>/dev/null || true; \
		cd rocket68 && BUILD_TYPE=release make all; \
	fi

# --- ROM: Minimal Bootstrap (loaded at 0x00000000) ---
rom: $(AUTOBOOT_BIN)

$(AUTOBOOT_BIN): $(ROM_DIR)/autoboot.asm
	@mkdir -p $(ROM_DIR)
	$(VASM) -spaces -Fbin -o $@ $<
	@echo "  [ROM] $@ ($(shell stat -c%s $@ 2>/dev/null || wc -c < $@) bytes)"

# --- HDD: System ROM (HAL, loaded from sector 0) ---
hdd: $(SYSTEM_BIN)

$(SYSTEM_BIN): $(ROM_DIR)/system.asm
	@mkdir -p $(HDD_DIR)
	$(VASM) -spaces -Fbin -o $@ $<
	@echo "  [HDD] $@ ($(shell stat -c%s $@ 2>/dev/null || wc -c < $@) bytes)"

# --- Emulator Binary ---
$(TARGET): $(OBJS) $(LDLIBS)
	@mkdir -p $(OBJ_DIR)
	$(CC) $(OBJS) $(LDLIBS) $(LDFLAGS) -o $@
	@echo "  [BIN] $@"

# --- Object Files ---
$(OBJ_DIR)/%.o: $(SRC_DIR)/%.c | $(OBJ_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(OBJ_DIR):
	mkdir -p $(OBJ_DIR)

# --- Run ---
run: all
	./$(TARGET)

# --- Clean ---
clean:
	rm -rf $(OBJ_DIR) $(TARGET)
	rm -f $(ROM_DIR)/*.bin $(HDD_DIR)/*.bin
	@echo "  Cleaned build artifacts"

deep-clean: clean
	rm -rf rocket68
	rm -rf $(HDD_DIR)
	@echo "  Deep cleaned (including rocket68 and HDD)"

# --- Help ---
help:
	@echo "Usage:"
	@echo "  make            - Build everything (rocket68 + ROMs + emulator)"
	@echo "  make rom        - Assemble autoboot ROM only"
	@echo "  make hdd        - Assemble system.rom (HAL) only"
	@echo "  make run        - Build and run the emulator"
	@echo "  make clean      - Remove build artifacts"
	@echo "  make deep-clean - Remove all including rocket68 and HDD"
	@echo ""
	@echo "Prerequisites:"
	@echo "  - gcc, make"
	@echo "  - SDL2 dev libs (libSDL2-dev / SDL2-devel)"
	@echo "  - VASM assembler (vasmm68k_mot)"
	@echo "  - git (to clone rocket68)"   