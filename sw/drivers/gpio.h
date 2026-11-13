#ifndef DRIVERS_GPIO_H
#define DRIVERS_GPIO_H

#include <stdint.h>

void gpio_init(void);
void gpio_set_output_mask(uint32_t pin_mask);
void gpio_write_pins(uint32_t val);
uint32_t gpio_read_pins(void);
void gpio_set_pin(uint8_t pin);
void gpio_clear_pin(uint8_t pin);
void gpio_toggle_pin(uint8_t pin);

#endif // DRIVERS_GPIO_H

