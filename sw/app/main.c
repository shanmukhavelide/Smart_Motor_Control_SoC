/**
 * =============================================================================
 * Smart ControlSoC - Bare-Metal Embedded Application: main.c
 * Architecture : RISC-V 32-bit (VeeR EL2 Core / RV32IM / ilp32)
 * Demonstrates interaction with all 6 peripherals:
 *   1. UART: Initialization and banner print
 *   2. GPIO: Pin mode configuration & LED pattern output
 *   3. Timer: Precise hardware tick delays
 *   4. SPI: Master-slave full-duplex transfer
 *   5. PWM: Motor speed / duty cycle profile generation
 *   6. SEG7: 8-digit multiplexed counter display
 *   7. UART: Telemetry and execution status report
 * =============================================================================
 */

#include <stdint.h>
#include <stdbool.h>
#include "soc_memory_map.h"
#include "../drivers/uart.h"
#include "../drivers/timer.h"
#include "../drivers/gpio.h"
#include "../drivers/spi.h"
#include "../drivers/pwm.h"
#include "../drivers/seg7.h"

// Convert integer to hex string for UART printing
static void print_hex32(uint32_t val) {
    const char hex_chars[] = "0123456789ABCDEF";
    uart_puts("0x");
    for (int i = 7; i >= 0; i--) {
        uart_putc(hex_chars[(val >> (i * 4)) & 0x0F]);
    }
}

int main(void) {
    // -------------------------------------------------------------------------
    // 1. Initialize UART & Print Startup Banner
    // -------------------------------------------------------------------------
    // Baud divisor = 40 clock cycles per bit (fast simulation baud)
    uart_init(40);
    uart_puts("\n\r==================================================================");
    uart_puts("\n\r   *** SMART MOTOR CONTROL RISC-V SOC FIRMWARE STARTED ***        ");
    uart_puts("\n\r   CPU Core: RISC-V VeeR EL2 (RV32IM) | Interconnect: AXI 2x6     ");
    uart_puts("\n\r==================================================================\n\r");

    // -------------------------------------------------------------------------
    // 2. Initialize Hardware 64-bit Timer
    // -------------------------------------------------------------------------
    uart_puts("[BOOT] Initializing 64-bit Hardware Timer...\n\r");
    timer_init(0, 1); // Prescaler = 0 (every clock), step = 1
    timer_start();
    uart_puts("[PASS] Hardware Timer running.\n\r");

    // -------------------------------------------------------------------------
    // 3. Initialize & Configure GPIO
    // -------------------------------------------------------------------------
    uart_puts("[BOOT] Configuring 32-bit GPIO Controller...\n\r");
    gpio_init();
    // Configure lower 8 pins (pins 0-7) as Push-Pull Outputs
    gpio_set_output_mask(0x000000FFU);
    gpio_write_pins(0x000000A5U);
    uart_puts("[PASS] GPIO output initialized with test pattern: 0xA5\n\r");

    // -------------------------------------------------------------------------
    // 4. Initialize & Test SPI Master Controller
    // -------------------------------------------------------------------------
    uart_puts("[BOOT] Configuring SPI Master Controller (Mode 0)...\n\r");
    spi_init(1); // Clock divider ratio = 1
    spi_select_slave(0);
    uint8_t spi_tx = 0x5A;
    uint8_t spi_rx = spi_transfer(spi_tx);
    spi_deselect_slave();
    uart_puts("[PASS] SPI Full-Duplex Transfer Complete. TX: 0x5A, RX: ");
    print_hex32(spi_rx);
    uart_puts("\n\r");

    // -------------------------------------------------------------------------
    // 5. Initialize PWM Motor Speed Profile
    // -------------------------------------------------------------------------
    uart_puts("[BOOT] Initializing PWM Motor Controller...\n\r");
    pwm_set_duty(128); // 50% duty cycle (128/256)
    uart_puts("[PASS] PWM Duty Cycle set to 50% (0x80 = 128/256).\n\r");

    // -------------------------------------------------------------------------
    // 6. Initialize Seven-Segment Display (SEG7)
    // -------------------------------------------------------------------------
    uart_puts("[BOOT] Initializing 8-digit Seven-Segment Display...\n\r");
    seg7_init(50); // 50 clock cycles per digit refresh
    seg7_set_data(0x20261113U); // Display date code 2026-11-13
    seg7_set_dp(0x55U);         // Decimal points on alternate digits
    seg7_enable(0xFFU);         // Enable all 8 digits
    uart_puts("[PASS] Seven-Segment Display active with pattern: 0x20261113\n\r");

    // -------------------------------------------------------------------------
    // 7. Interactive Motor Control & Counter Loop Demonstration
    // -------------------------------------------------------------------------
    uart_puts("\n\r--- Starting Motor Control & SEG7 Telemetry Loop ---\n\r");

    uint32_t counter = 0;
    for (int step = 1; step <= 5; step++) {
        // Update PWM duty cycle: 25%, 50%, 75%, 90%, 0%
        uint8_t duty_table[5] = {64, 128, 192, 230, 0};
        pwm_set_duty(duty_table[step - 1]);

        // Toggle GPIO pin 0 heartbeat LED
        gpio_toggle_pin(0);

        // Update SEG7 with advancing counter
        counter += 0x1111;
        seg7_set_data(counter);

        // Delay using hardware timer
        timer_delay_ticks(200);

        // Print Telemetry Step
        uart_puts("  Step ");
        uart_putc('0' + step);
        uart_puts(": PWM Duty = ");
        print_hex32(duty_table[step - 1]);
        uart_puts(", SEG7 = ");
        print_hex32(counter);
        uart_puts("\n\r");
    }

    uart_puts("\n\r==================================================================");
    uart_puts("\n\r   *** SOC FIRMWARE DEMONSTRATION SUCCESSFULLY COMPLETED ***      ");
    uart_puts("\n\r==================================================================\n\r");

    // Idle loop
    while (1) {
        gpio_toggle_pin(0);
        timer_delay_ticks(500);
    }

    return 0;
}

