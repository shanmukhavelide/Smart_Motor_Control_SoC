#include "pwm.h"
#include "soc_memory_map.h"

void pwm_set_duty(uint8_t duty_256) {
    mmio_write32(PWM_REG_DUTY, (uint32_t)duty_256);
}

uint8_t pwm_get_duty(void) {
    return (uint8_t)(mmio_read32(PWM_REG_DUTY) & 0xFFU);
}

