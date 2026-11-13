#ifndef DRIVERS_SEG7_H
#define DRIVERS_SEG7_H

#include <stdint.h>

void seg7_init(uint16_t refresh_cycles);
void seg7_set_data(uint32_t hex_nibbles);
void seg7_set_dp(uint8_t dp_mask);
void seg7_enable(uint8_t digit_mask);
void seg7_disable(void);

#endif // DRIVERS_SEG7_H

