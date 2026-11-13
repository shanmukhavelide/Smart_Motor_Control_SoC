#ifndef DRIVERS_PWM_H
#define DRIVERS_PWM_H

#include <stdint.h>

void pwm_set_duty(uint8_t duty_256);
uint8_t pwm_get_duty(void);

#endif // DRIVERS_PWM_H

