#include "timer.h"
#include "soc_memory_map.h"

void timer_init(uint16_t prescaler, uint8_t step) {
    // Stop timer
    mmio_write32(TIMER_REG_CTRL, 0x00000000U);
    // Program prescaler [11:0] and step [23:16]
    uint32_t cfg = ((uint32_t)step << 16) | ((uint32_t)prescaler & 0xFFFU);
    mmio_write32(TIMER_REG_CFG0, cfg);
    // Reset counter
    mmio_write32(TIMER_REG_V_LOWER0, 0x00000000U);
    mmio_write32(TIMER_REG_V_UPPER0, 0x00000000U);
}

void timer_start(void) {
    mmio_write32(TIMER_REG_CTRL, 0x00000001U);
}

void timer_stop(void) {
    mmio_write32(TIMER_REG_CTRL, 0x00000000U);
}

uint64_t timer_get_count(void) {
    uint32_t lower = mmio_read32(TIMER_REG_V_LOWER0);
    uint32_t upper = mmio_read32(TIMER_REG_V_UPPER0);
    return (((uint64_t)upper << 32) | (uint64_t)lower);
}

void timer_set_compare(uint64_t threshold) {
    mmio_write32(TIMER_REG_COMPARE_L0, (uint32_t)(threshold & 0xFFFFFFFFU));
    mmio_write32(TIMER_REG_COMPARE_U0, (uint32_t)(threshold >> 32));
    mmio_write32(TIMER_REG_INTR_ENABLE0, 0x00000001U);
}

void timer_delay_ticks(uint32_t ticks) {
    uint32_t start = mmio_read32(TIMER_REG_V_LOWER0);
    while ((mmio_read32(TIMER_REG_V_LOWER0) - start) < ticks);
}

