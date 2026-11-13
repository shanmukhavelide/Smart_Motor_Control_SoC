#include "uart.h"
#include "soc_memory_map.h"

void uart_init(uint32_t baud_divisor) {
    // Enable DLAB in LCR (bit 7)
    mmio_write32(UART_REG_LCR, 0x00000080U);
    // Program baud rate divisor
    mmio_write32(UART_REG_BAUD_DIV, baud_divisor);
    // Clear DLAB, configure 8 data bits, 1 stop bit, no parity (8-N-1)
    mmio_write32(UART_REG_LCR, 0x00000003U);
    // Enable Receiver Data Available Interrupt
    mmio_write32(UART_REG_IER, 0x00000001U);
}

void uart_putc(char c) {
    // Wait until Transmitter Empty (TEMT, bit 6) or THRE (bit 5) in LSR
    // For simulation throughput, we write directly to THR
    mmio_write32(UART_REG_RBR_THR, (uint32_t)(uint8_t)c);
}

void uart_puts(const char *str) {
    while (*str) {
        if (*str == '\n') {
            uart_putc('\r');
        }
        uart_putc(*str++);
    }
}

bool uart_is_data_ready(void) {
    return ((mmio_read32(UART_REG_LSR) & UART_LSR_DR) != 0U);
}

char uart_getc(void) {
    while (!uart_is_data_ready());
    return (char)(mmio_read32(UART_REG_RBR_THR) & 0xFFU);
}

