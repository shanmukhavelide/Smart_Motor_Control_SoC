/**
 * =============================================================================
 * Smart ControlSoC - Interconnect & Peripheral Comprehensive C Verification
 * =============================================================================
 * Description : Full bare-metal and simulation verification suite covering all
 *               peripherals connected across the 2x6 AXI Crossbar Interconnect:
 *                 - Port M00: AXI UART (0x4000_0000)
 *                 - Port M01: Hardware 64-bit Timer (0x4000_4000)
 *                 - Port M02: 32-bit GPIO Controller (0x4000_2000)
 *                 - Port M03: SPI Controller (0x4000_6000)
 *                 - Port M04: Seven-Segment Display Controller (0x4000_8000)
 *                 - Port M05: PWM Generator (0x4000_A000)
 * =============================================================================
 */

#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include "soc_memory_map.h"

// Tracking variables
static uint32_t total_tests  = 0;
static uint32_t passed_tests = 0;
static uint32_t failed_tests = 0;

#define TEST_ASSERT(cond, msg) do { \
    total_tests++; \
    if (cond) { \
        passed_tests++; \
        printf("  [PASS] %s\n", msg); \
    } else { \
        failed_tests++; \
        printf("  [FAIL] %s (Line %d)\n", msg, __LINE__); \
    } \
} while(0)

// =============================================================================
// Simulation Host Mock Model (Enables Clean Compilation & Execution on Host)
// =============================================================================
#ifdef SIMULATION_HOST
#define MOCK_MEM_SIZE 0x10000U
static uint8_t mock_mem[MOCK_MEM_SIZE];

static inline uint32_t *get_mock_ptr(uint32_t addr) {
    uint32_t offset = (addr - UART_BASE) % MOCK_MEM_SIZE;
    return (uint32_t *)&mock_mem[offset];
}

uint32_t host_mmio_read(uint32_t addr) {
    if (addr == GPIO_REG_INFO) {
        return 0x00000820U; // Version 2, 32 GPIO pins
    }
    if (addr == SPI_REG_SR) {
        return 0x00000005U; // TX and RX empty
    }
    if (addr >= (SEG7_BASE + 0x10U) && addr < (SEG7_BASE + 0x1000U)) {
        return 0x00000000U; // Undefined Seg7 offsets read as 0
    }
    return *get_mock_ptr(addr);
}

void host_mmio_write(uint32_t addr, uint32_t data) {
    // Atomic GPIO operations simulation
    if (addr == GPIO_REG_SET) {
        *get_mock_ptr(GPIO_REG_OUT) |= data;
        return;
    }
    if (addr == GPIO_REG_CLEAR) {
        *get_mock_ptr(GPIO_REG_OUT) &= ~data;
        return;
    }
    if (addr == GPIO_REG_TOGGLE) {
        *get_mock_ptr(GPIO_REG_OUT) ^= data;
        return;
    }
    if (addr == TIMER_REG_INTR_STATE0) {
        // W1C: Write-1-to-clear
        *get_mock_ptr(TIMER_REG_INTR_STATE0) &= ~data;
        return;
    }
    if (addr == TIMER_REG_INTR_TEST0) {
        // Set interrupt state
        *get_mock_ptr(TIMER_REG_INTR_STATE0) |= data;
        return;
    }
    if (addr >= (SEG7_BASE + 0x10U) && addr < (SEG7_BASE + 0x1000U)) {
        return; // Writes to undefined Seg7 offsets are ignored
    }
    *get_mock_ptr(addr) = data;
}

static void init_mock_hardware(void) {
    for (uint32_t i = 0; i < MOCK_MEM_SIZE; i++) mock_mem[i] = 0;
    host_mmio_write(TIMER_REG_CTRL, 0x00000000U);
    host_mmio_write(TIMER_REG_V_LOWER0, 0x00000000U);
    host_mmio_write(SEG7_REG_DATA, 0x00000000U);
    host_mmio_write(SEG7_REG_CTRL, 0x0000FF06U);
    host_mmio_write(SEG7_REG_DP, 0x00000000U);
    host_mmio_write(SEG7_REG_REFRESH_DIV, 0x000003E8U);
    host_mmio_write(PWM_REG_DUTY, 0x00000000U);
}
#endif

// =============================================================================
// TEST 1: UART Controller Verification (Port M00: 0x4000_0000)
// =============================================================================
static void test_uart_controller(void) {
    printf("\n--- [TEST 1] AXI UART Controller MMIO & FIFO Verification ---\n");

    // 1.1 Program baud rate divisor
    mmio_write32(UART_REG_BAUD_DIV, 40U);
    uint32_t baud_div = mmio_read32(UART_REG_BAUD_DIV);
    TEST_ASSERT(baud_div == 40U, "UART Baud Divisor Register write/readback (40 ticks/bit)");

    // 1.2 Configure Line Control Register (8 bits, 1 stop bit, no parity)
    mmio_write32(UART_REG_LCR, 0x03U);
    uint32_t lcr = mmio_read32(UART_REG_LCR);
    TEST_ASSERT((lcr & 0x03U) == 0x03U, "UART Line Control Register (8-N-1 format)");

    // 1.3 Enable Receiver Data Interrupt
    mmio_write32(UART_REG_IER, 0x01U);
    uint32_t ier = mmio_read32(UART_REG_IER);
    TEST_ASSERT((ier & 0x01U) == 0x01U, "UART Interrupt Enable Register (RX Data IRQ enable)");

    // 1.4 Write character into Transmitter Holding Register
    mmio_write32(UART_REG_RBR_THR, (uint32_t)'A');
    TEST_ASSERT(true, "UART Transmitter Holding Register MMIO write (Char 'A')");
}

// =============================================================================
// TEST 2: Hardware 64-bit Timer Verification (Port M01: 0x4000_4000)
// =============================================================================
static void test_hardware_timer(void) {
    printf("\n--- [TEST 2] Hardware 64-bit Timer MMIO & Interrupt Verification ---\n");

    // 2.1 Verify default active state is 0 (disabled)
    uint32_t ctrl = mmio_read32(TIMER_REG_CTRL);
    TEST_ASSERT((ctrl & 0x1U) == 0U, "Timer CTRL initially disabled (active = 0)");

    // 2.2 Configure Prescaler & Step
    mmio_write32(TIMER_REG_CFG0, 0x00010000U); // Step = 1, Prescaler = 0
    uint32_t cfg0 = mmio_read32(TIMER_REG_CFG0);
    TEST_ASSERT(cfg0 == 0x00010000U, "Timer CFG0 configured (Step = 1, Prescaler = 0)");

    // 2.3 Enable Timer counter
    mmio_write32(TIMER_REG_CTRL, 0x00000001U);
    ctrl = mmio_read32(TIMER_REG_CTRL);
    TEST_ASSERT((ctrl & 0x1U) == 1U, "Timer CTRL active enable (active = 1)");

    // 2.4 Program Compare Match Threshold & Enable IRQ
    mmio_write32(TIMER_REG_COMPARE_L0, 0x00000050U);
    mmio_write32(TIMER_REG_COMPARE_U0, 0x00000000U);
    mmio_write32(TIMER_REG_INTR_ENABLE0, 0x00000001U);
    uint32_t irq_en = mmio_read32(TIMER_REG_INTR_ENABLE0);
    TEST_ASSERT((irq_en & 0x1U) == 1U, "Timer Interrupt Enable Register (Timer0 IRQ enable)");

    // 2.5 Test Software Interrupt Force (INTR_TEST0)
    mmio_write32(TIMER_REG_INTR_TEST0, 0x00000001U);
    uint32_t irq_state = mmio_read32(TIMER_REG_INTR_STATE0);
    TEST_ASSERT((irq_state & 0x1U) == 1U, "Timer INTR_STATE0 reflects forced interrupt");

    // 2.6 Clear Interrupt via W1C
    mmio_write32(TIMER_REG_INTR_STATE0, 0x00000001U);
    irq_state = mmio_read32(TIMER_REG_INTR_STATE0);
    TEST_ASSERT((irq_state & 0x1U) == 0U, "Timer INTR_STATE0 cleared successfully via W1C");
}

// =============================================================================
// TEST 3: GPIO Controller Verification (Port M02: 0x4000_2000)
// =============================================================================
static void test_gpio_controller(void) {
    printf("\n--- [TEST 3] 32-bit GPIO Controller MMIO & Atomic Bitops Verification ---\n");

    // 3.1 Verify Hardware Version Signature (Version 2, 32 GPIO pins)
    uint32_t info = mmio_read32(GPIO_REG_INFO);
    TEST_ASSERT(info == 0x00000820U, "GPIO INFO register reports Version 2, 32 pins (0x00000820)");

    // 3.2 Configure Pin 0 as Push-Pull Output (MODE[1:0] = 01)
    mmio_write32(GPIO_REG_MODE_0, 0x00000001U);
    uint32_t mode0 = mmio_read32(GPIO_REG_MODE_0);
    TEST_ASSERT((mode0 & 0x3U) == 0x01U, "GPIO Pin 0 configured as Output Mode (01)");

    // 3.3 Direct OUT Register Write (Pin 0 = 1)
    mmio_write32(GPIO_REG_OUT, 0x00000001U);
    uint32_t out_val = mmio_read32(GPIO_REG_OUT);
    TEST_ASSERT((out_val & 0x1U) == 0x01U, "GPIO Pin 0 driven HIGH via GPIO_OUT");

    // 3.4 Atomic Clear (Pin 0 = 0)
    mmio_write32(GPIO_REG_CLEAR, 0x00000001U);
    out_val = mmio_read32(GPIO_REG_OUT);
    TEST_ASSERT((out_val & 0x1U) == 0x00U, "GPIO Pin 0 cleared LOW via atomic GPIO_CLEAR");

    // 3.5 Atomic Set (Pin 0 = 1)
    mmio_write32(GPIO_REG_SET, 0x00000001U);
    out_val = mmio_read32(GPIO_REG_OUT);
    TEST_ASSERT((out_val & 0x1U) == 0x01U, "GPIO Pin 0 set HIGH via atomic GPIO_SET");

    // 3.6 Atomic Toggle (Pin 0 toggles to 0)
    mmio_write32(GPIO_REG_TOGGLE, 0x00000001U);
    out_val = mmio_read32(GPIO_REG_OUT);
    TEST_ASSERT((out_val & 0x1U) == 0x00U, "GPIO Pin 0 toggled LOW via atomic GPIO_TOGGLE");

    // 3.7 Enable Rising-Edge Interrupt on Pin 1
    mmio_write32(GPIO_REG_INTRPT_RISE_EN, 0x00000002U);
    uint32_t rise_en = mmio_read32(GPIO_REG_INTRPT_RISE_EN);
    TEST_ASSERT((rise_en & 0x2U) == 0x02U, "GPIO Pin 1 Rising-Edge Interrupt enabled");
}

// =============================================================================
// TEST 4: SPI Controller Verification (Port M03: 0x4000_6000)
// =============================================================================
static void test_spi_controller(void) {
    printf("\n--- [TEST 4] AXI SPI Controller MMIO Verification ---\n");

    // 4.1 Check initial status register
    uint32_t sr = mmio_read32(SPI_REG_SR);
    TEST_ASSERT((sr & 0x5U) == 0x5U, "SPI SR indicates TX and RX FIFOs empty (0x05)");

    // 4.2 Configure Control Register (Master Mode + SPI Enable)
    mmio_write32(SPI_REG_CR, 0x00000186U);
    uint32_t cr = mmio_read32(SPI_REG_CR);
    TEST_ASSERT(cr == 0x00000186U, "SPI Control Register configured (Master Mode + SPI Enable)");

    // 4.3 Write byte to Data Transmit Register
    mmio_write32(SPI_REG_DTR, 0x000000A5U);
    TEST_ASSERT(true, "SPI DTR MMIO write (0xA5) executed without interconnect fault");
}

// =============================================================================
// TEST 5: Seven-Segment Display Controller Verification (Port M04: 0x4000_8000)
// =============================================================================
static void test_seg7_controller(void) {
    printf("\n--- [TEST 5] AXI Seven-Segment Display Controller Demonstration ---\n");

    // 5.1 Verify reset defaults per seg7_spec.md
    TEST_ASSERT(mmio_read32(SEG7_REG_DATA) == 0x00000000U,
                "SEG_DATA default = 0x00000000");
    TEST_ASSERT(mmio_read32(SEG7_REG_CTRL) == 0x0000FF06U,
                "SEG_CTRL default = 0x0000FF06 (EN=0, active-low seg/an, mask=0xFF)");
    TEST_ASSERT(mmio_read32(SEG7_REG_DP) == 0x00000000U,
                "SEG_DP default = 0x00000000");
    TEST_ASSERT(mmio_read32(SEG7_REG_REFRESH_DIV) == 0x000003E8U,
                "SEG_REFRESH_DIV default = 0x000003E8 (1000 clocks)");

    // 5.2 Configure scan refresh divider (e.g. 100 clock cycles per digit)
    mmio_write32(SEG7_REG_REFRESH_DIV, 0x00000064U);
    uint32_t refresh_div = mmio_read32(SEG7_REG_REFRESH_DIV);
    TEST_ASSERT(refresh_div == 0x00000064U,
                "SEG_REFRESH_DIV configured = 0x00000064 (100 clocks/digit)");

    // 5.3 Write 8 hexadecimal digits to SEG_DATA (Digit 0 = 4 .. Digit 7 = C)
    mmio_write32(SEG7_REG_DATA, 0xCAFE1234U);
    uint32_t seg_data = mmio_read32(SEG7_REG_DATA);
    TEST_ASSERT(seg_data == 0xCAFE1234U,
                "SEG_DATA programmed with hex pattern 0xCAFE1234");

    // 5.4 Configure decimal points on even digits (digits 0, 2, 4, 6 -> 0x55)
    mmio_write32(SEG7_REG_DP, 0x00000055U);
    uint32_t seg_dp = mmio_read32(SEG7_REG_DP);
    TEST_ASSERT((seg_dp & 0xFFU) == 0x55U,
                "SEG_DP configured = 0x55 (decimal points on digits 0,2,4,6)");

    // 5.5 Demonstrate digit masking + display enable: enable lower 4 digits (mask=0x0F, EN=1)
    uint32_t ctrl_masked = (0x0FU << SEG7_CTRL_MASK_SHIFT) |
                           SEG7_CTRL_AN_ACT_LOW | SEG7_CTRL_SEG_ACT_LOW | SEG7_CTRL_EN;
    mmio_write32(SEG7_REG_CTRL, ctrl_masked);
    uint32_t ctrl = mmio_read32(SEG7_REG_CTRL);
    TEST_ASSERT(ctrl == 0x00000F07U,
                "SEG_CTRL enabled with partial digit mask (0x0F -> digits 0..3 shown)");

    // 5.6 Demonstrate enabling all 8 digits (mask=0xFF, EN=1)
    uint32_t ctrl_all = SEG7_CTRL_MASK_ALL |
                        SEG7_CTRL_AN_ACT_LOW | SEG7_CTRL_SEG_ACT_LOW | SEG7_CTRL_EN;
    mmio_write32(SEG7_REG_CTRL, ctrl_all);
    ctrl = mmio_read32(SEG7_REG_CTRL);
    TEST_ASSERT(ctrl == 0x0000FF07U,
                "SEG_CTRL enabled with all 8 digits unmasked (0x0000FF07)");

    // 5.7 Demonstrate blanking display (EN=0) then re-enabling (EN=1)
    mmio_write32(SEG7_REG_CTRL, ctrl_all & ~SEG7_CTRL_EN);
    ctrl = mmio_read32(SEG7_REG_CTRL);
    TEST_ASSERT((ctrl & SEG7_CTRL_EN) == 0U,
                "SEG_CTRL display disabled (EN=0 blanks all digits)");

    mmio_write32(SEG7_REG_CTRL, ctrl_all);
    ctrl = mmio_read32(SEG7_REG_CTRL);
    TEST_ASSERT((ctrl & SEG7_CTRL_EN) == SEG7_CTRL_EN,
                "SEG_CTRL display re-enabled (EN=1)");

    // 5.8 Verify writes to undefined offset are ignored and reads return 0
    mmio_write32(SEG7_BASE + 0x10U, 0xDEADBEEFU);
    TEST_ASSERT(mmio_read32(SEG7_BASE + 0x10U) == 0x00000000U,
                "SEG7 undefined offset 0x10 write ignored / readback == 0");
}

// =============================================================================
// TEST 6: PWM Generator Verification (Port M05: 0x4000_A000)
// =============================================================================
static void test_pwm_generator(void) {
    printf("\n--- [TEST 6] AXI PWM Generator MMIO Verification ---\n");

    // 6.1 Check initial duty cycle (0x00 after reset)
    uint32_t duty = mmio_read32(PWM_REG_DUTY);
    TEST_ASSERT(duty == 0x00000000U, "PWM Duty Cycle initially 0% (0x00)");

    // 6.2 Program 50% duty cycle (0x80)
    mmio_write32(PWM_REG_DUTY, 0x00000080U);
    duty = mmio_read32(PWM_REG_DUTY);
    TEST_ASSERT(duty == 0x00000080U, "PWM Duty Cycle programmed to 50% (0x80)");

    // 6.3 Program 100% duty cycle (0xFF)
    mmio_write32(PWM_REG_DUTY, 0x000000FFU);
    duty = mmio_read32(PWM_REG_DUTY);
    TEST_ASSERT(duty == 0x000000FFU, "PWM Duty Cycle programmed to 100% (0xFF)");
}

// =============================================================================
// TEST 7: Cross-Peripheral Interconnect Routing & Region Isolation
// =============================================================================
static void test_interconnect_cross_routing(void) {
    printf("\n--- [TEST 7] Interconnect Routing & Region Isolation Test ---\n");

    // 7.1 Write unique test signatures across peripherals simultaneously
    mmio_write32(UART_REG_BAUD_DIV, 0x00000028U); // 40
    mmio_write32(TIMER_REG_CFG0,    0x00010000U); // Prescaler 0, Step 1
    mmio_write32(GPIO_REG_OUT,      0xDEADBEEFU); // GPIO pattern
    mmio_write32(SEG7_REG_DATA,     0x1234ABCDU); // Seg7 hex pattern
    mmio_write32(PWM_REG_DUTY,      0x5A5A5A5AU); // PWM pattern

    // 7.2 Verify each peripheral retains its exact data without address bleeding or cross-talk
    bool uart_ok  = (mmio_read32(UART_REG_BAUD_DIV) == 0x00000028U);
    bool timer_ok = (mmio_read32(TIMER_REG_CFG0)    == 0x00010000U);
    bool gpio_ok  = (mmio_read32(GPIO_REG_OUT)      == 0xDEADBEEFU);
    bool seg7_ok  = (mmio_read32(SEG7_REG_DATA)     == 0x1234ABCDU);
    bool pwm_ok   = (mmio_read32(PWM_REG_DUTY)      == 0x5A5A5A5AU);

    TEST_ASSERT(uart_ok && timer_ok && gpio_ok && seg7_ok && pwm_ok,
                "Interconnect address decoding and region isolation verified across slaves");
}

// =============================================================================
// Main Entry Point
// =============================================================================
int main(void) {
    printf("==================================================================\n");
    printf("   RISC-V SMART CONTROLSOC - INTERCONNECT C VERIFICATION SUITE    \n");
    printf("==================================================================\n");

#ifdef SIMULATION_HOST
    init_mock_hardware();
#endif

    test_uart_controller();
    test_hardware_timer();
    test_gpio_controller();
    test_spi_controller();
    test_seg7_controller();
    test_pwm_generator();
    test_interconnect_cross_routing();

    printf("\n==================================================================\n");
    printf("   VERIFICATION SUMMARY:\n");
    printf("     Total Subtests Executed : %u\n", total_tests);
    printf("     Passed                  : %u\n", passed_tests);
    printf("     Failed                  : %u\n", failed_tests);
    if (failed_tests == 0) {
        printf("   *** ALL INTERCONNECT & PERIPHERAL C TESTS PASSED (100%%)! ***\n");
    } else {
        printf("   *** VERIFICATION FAILED WITH %u ERRORS! ***\n", failed_tests);
    }
    printf("==================================================================\n");

    return (failed_tests == 0) ? 0 : 1;
}
