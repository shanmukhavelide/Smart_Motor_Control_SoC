#ifndef DRIVERS_SPI_H
#define DRIVERS_SPI_H

#include <stdint.h>

void spi_init(uint8_t clk_ratio);
void spi_select_slave(uint8_t slave_idx);
void spi_deselect_slave(void);
uint8_t spi_transfer(uint8_t tx_byte);

#endif // DRIVERS_SPI_H

