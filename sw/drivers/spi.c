#include "spi.h"
#include "soc_memory_map.h"

void spi_init(uint8_t clk_ratio) {
    // Set clock ratio
    mmio_write32(SPI_BASE + 0x30U, (uint32_t)clk_ratio);
    // Control Register: SPE=1, Master=1, FIFO resets=0
    mmio_write32(SPI_REG_CR, 0x00000186U);
    // Deselect all slaves
    spi_deselect_slave();
}

void spi_select_slave(uint8_t slave_idx) {
    uint32_t mask = ~(1U << slave_idx);
    mmio_write32(SPI_REG_SSR, mask);
}

void spi_deselect_slave(void) {
    mmio_write32(SPI_REG_SSR, 0xFFFFFFFFU);
}

uint8_t spi_transfer(uint8_t tx_byte) {
    // Write byte to TX FIFO
    mmio_write32(SPI_REG_DTR, (uint32_t)tx_byte);
    // Wait until RX FIFO has data (SR bit 0 RX_EMPTY == 0)
    while ((mmio_read32(SPI_REG_SR) & 0x1U) != 0U);
    // Read received byte from DRR
    return (uint8_t)(mmio_read32(SPI_REG_DRR) & 0xFFU);
}

