#include "seg7.h"
#include "soc_memory_map.h"

void seg7_init(uint16_t refresh_cycles) {
    mmio_write32(SEG7_REG_REFRESH_DIV, (uint32_t)refresh_cycles);
    seg7_disable();
}

void seg7_set_data(uint32_t hex_nibbles) {
    mmio_write32(SEG7_REG_DATA, hex_nibbles);
}

void seg7_set_dp(uint8_t dp_mask) {
    mmio_write32(SEG7_REG_DP, (uint32_t)dp_mask);
}

void seg7_enable(uint8_t digit_mask) {
    uint32_t ctrl = ((uint32_t)digit_mask << SEG7_CTRL_MASK_SHIFT) |
                    SEG7_CTRL_AN_ACT_LOW | SEG7_CTRL_SEG_ACT_LOW | SEG7_CTRL_EN;
    mmio_write32(SEG7_REG_CTRL, ctrl);
}

void seg7_disable(void) {
    uint32_t ctrl = (0xFFU << SEG7_CTRL_MASK_SHIFT) |
                    SEG7_CTRL_AN_ACT_LOW | SEG7_CTRL_SEG_ACT_LOW; // EN = 0
    mmio_write32(SEG7_REG_CTRL, ctrl);
}

