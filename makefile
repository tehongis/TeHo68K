# ============================================================================
# 68000 Virtual Computer - Makefile (ROM Boot Only - External Shared Core)
# ============================================================================

# --- Tools ---
CC          = gcc
VASM        = vasmm68k_mot

# CFLAGS: Hakupolut osoittavat nyt projektin ulkopuolelle ../rocket68 kansioon
CFLAGS      = -Wall -Wextra -O2 -std=c11 -Iinclude -I../rocket68/include -I../rocket68/src
LDFLAGS     = -lSDL2 -lm
LDLIBS      = ../rocket68/lib/librocket68.a

# --- Directories (Korjattu SRC_DIR vastaamaan projektisi srcs/ kansiota) ---
SRC_DIR     = srcs
ROM_DIR     = rom
OBJ_DIR     = build
TARGET      = m68k_vm

# --- Sources ---
SRCS        = $(SRC_DIR)/main.c \
              $(SRC_DIR)/vm.c \
              $(SRC_DIR)/display.c
OBJS        = $(patsubst $(SRC_DIR)/%.c,$(OBJ_DIR)/%.o,$(SRCS))

# --- ROM Files ---
KERNEL_BIN  = $(ROM_DIR)/kernel.bin

# ============================================================================
# Targets
# ============================================================================

.PHONY: all rom clean run help

# Poistettu kokonaan vanha install-rocket68 riippuvuus
all: rom $(TARGET)
	@echo "=== Build complete: ./$(TARGET) ==="

# --- ROM: Unified Kernel Bootstrap ---
rom: $(KERNEL_BIN)

$(KERNEL_BIN): $(ROM_DIR)/kernel.asm
	@mkdir -p $(ROM_DIR)
	$(VASM) -spaces -Fbin -o $@ $<
	@echo "  [ROM] $@ ($(shell stat -c%s $@ 2>/dev/null || wc -c < $@) bytes)"

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
	rm -f $(ROM_DIR)/*.bin
	@echo "  Cleaned build artifacts"
