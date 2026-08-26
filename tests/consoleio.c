#define CONSOLE_DATA    (IO_BASE + 0x00)
#define CONSOLE_STATUS  (IO_BASE + 0x01)

// In your write handler:
if (addr == CONSOLE_DATA) {
    putchar(value);
    fflush(stdout);
}

// In your read handler:
if (addr == CONSOLE_STATUS) {
    // Return status: bit 0 = data ready, bit 1 = transmitter ready
    return 0x03;  // Both ready
}   