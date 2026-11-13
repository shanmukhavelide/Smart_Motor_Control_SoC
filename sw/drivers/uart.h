#ifndef DRIVERS_UART_H
#define DRIVERS_UART_H

#include <stdint.h>
#include <stdbool.h>

void uart_init(uint32_t baud_divisor);
void uart_putc(char c);
void uart_puts(const char *str);
bool uart_is_data_ready(void);
char uart_getc(void);

#endif // DRIVERS_UART_H

