#include "gpio.h"
#include "soc_memory_map.h"

void gpio_init(void) {
    // Configure global interrupt mode
    mmio_write32(GPIO_REG_CFG, 0x00000001U);
}

void gpio_set_output_mask(uint32_t pin_mask) {
    // Each pin takes 2 bits: 01 = Output Active
    uint32_t mode0 = 0;
    uint32_t mode1 = 0;
    for (int i = 0; i < 16; i++) {
        if (pin_mask & (1U << i)) mode0 |= (1U << (i * 2));
    }
    for (int i = 0; i < 16; i++) {
        if (pin_mask & (1U << (i + 16))) mode1 |= (1U << (i * 2));
    }
    mmio_write32(GPIO_REG_MODE_0, mode0);
    mmio_write32(GPIO_REG_MODE_1, mode1);
}

void gpio_write_pins(uint32_t val) {
    mmio_write32(GPIO_REG_OUT, val);
}

uint32_t gpio_read_pins(void) {
    return mmio_read32(GPIO_REG_IN);
}

void gpio_set_pin(uint8_t pin) {
    mmio_write32(GPIO_REG_SET, (1U << pin));
}

void gpio_clear_pin(uint8_t pin) {
    mmio_write32(GPIO_REG_CLEAR, (1U << pin));
}

void gpio_toggle_pin(uint8_t pin) {
    mmio_write32(GPIO_REG_TOGGLE, (1U << pin));
}

