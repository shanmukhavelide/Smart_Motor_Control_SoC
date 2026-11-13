#ifndef DRIVERS_TIMER_H
#define DRIVERS_TIMER_H

#include <stdint.h>

void timer_init(uint16_t prescaler, uint8_t step);
void timer_start(void);
void timer_stop(void);
uint64_t timer_get_count(void);
void timer_set_compare(uint64_t threshold);
void timer_delay_ticks(uint32_t ticks);

#endif // DRIVERS_TIMER_H

