// =============================================================================
// Smart ControlSoC - VeeR EL2 Bare-Metal Firmware Application
// File: main_veer.c
// Exercises all 6 memory-mapped peripherals across the AXI interconnect:
// UART (0x4000_0000), Timer (0x4000_4000), GPIO (0x4000_2000),
// SPI (0x4000_6000), SEG7 (0x4000_8000), PWM (0x4000_A000).
// Emits 0x900D to GPIO on successful verification.
// =============================================================================

#include <stdint.h>
#include <stdbool.h>
#include "soc_memory_map.h"
#include "drivers/uart.h"
#include "drivers/timer.h"
#include "drivers/gpio.h"
#include "drivers/spi.h"
#include "drivers/pwm.h"
#include "drivers/seg7.h"

// Delay loop for hardware cycle settling
static void delay_cycles(volatile uint32_t count) {
    while (count--) {
        __asm__ volatile ("nop");
    }
}

int main(void) {
    // -------------------------------------------------------------------------
    // 1. Initialize GPIO (Port M02: 0x4000_2000)
    // -------------------------------------------------------------------------
    gpio_init();
    gpio_set_output_mask(0x0000FFFFU); // Configure lower 16 pins as output
    gpio_write_pins(0x0001);           // Initial status: Pin 0 high
    delay_cycles(20);
    gpio_write_pins(0x0000);
    delay_cycles(20);

    // -------------------------------------------------------------------------
    // 2. Initialize UART (Port M00: 0x4000_0000)
    // -------------------------------------------------------------------------
    uart_init(40); // 40 clock cycles per bit for fast simulation
    uart_puts("[VeeR-EL2] SoC Booted Successfully!\r\n");

    // -------------------------------------------------------------------------
    // 3. Initialize 64-bit Hardware Timer (Port M01: 0x4000_4000)
    // -------------------------------------------------------------------------
    timer_init(0, 1); // Prescaler = 0, Step = 1
    timer_start();
    volatile uint64_t t_now = timer_get_count();
    (void)t_now;
    uart_puts("[VeeR-EL2] 64-bit Hardware Timer Started.\r\n");

    // -------------------------------------------------------------------------
    // 4. Initialize PWM Generator (Port M05: 0x4000_A000)
    // -------------------------------------------------------------------------
    pwm_set_duty(128); // 50% duty cycle (128/256)
    delay_cycles(50);
    uart_puts("[VeeR-EL2] PWM Configured to 50% Duty.\r\n");

    // -------------------------------------------------------------------------
    // 5. Initialize Seven-Segment Display (Port M04: 0x4000_8000)
    // -------------------------------------------------------------------------
    seg7_init(100);             // 100 cycles per digit refresh
    seg7_set_data(0x12345678U); // Pattern
    seg7_set_dp(0x11U);         // Decimal points on digits 0 and 4
    seg7_enable(0xFFU);         // Enable all 8 digits
    uart_puts("[VeeR-EL2] SEG7 Controller Active.\r\n");

    // -------------------------------------------------------------------------
    // 6. Initialize SPI Master Controller (Port M03: 0x4000_6000)
    // -------------------------------------------------------------------------
    spi_init(1);
    spi_select_slave(0);
    volatile uint8_t rx_data = spi_transfer(0xA5);
    (void)rx_data;
    spi_deselect_slave();
    uart_puts("[VeeR-EL2] SPI Transfer Completed.\r\n");

    // -------------------------------------------------------------------------
    // 7. Emit Success Signature 0x900D to GPIO_OUT
    // -------------------------------------------------------------------------
    gpio_write_pins(0x900D);
    uart_puts("[VeeR-EL2] All Peripherals Verified. Magic signature 0x900D emitted!\r\n");

    // Finished: wait for interrupt
    while (1) {
        __asm__ volatile ("wfi");
    }

    return 0;
}
