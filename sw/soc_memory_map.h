#ifndef SOC_MEMORY_MAP_H
#define SOC_MEMORY_MAP_H

#include <stdint.h>
#include <stdbool.h>

// =============================================================================
// Smart ControlSoC 2x6 Interconnect Peripheral Base Addresses
// =============================================================================
#define UART_BASE               0x40000000U // Port M00: AXI UART (4KB)
#define TIMER_BASE              0x40004000U // Port M01: Hardware 64-bit Timer (4KB)
#define GPIO_BASE               0x40002000U // Port M02: 32-bit GPIO Controller (4KB)
#define SPI_BASE                0x40006000U // Port M03: SPI Controller (4KB)
#define SEG7_BASE               0x40008000U // Port M04: Seven-Segment Display Controller (4KB)
#define PWM_BASE                0x4000A000U // Port M05: PWM Generator (4KB)

// =============================================================================
// 1. UART Peripheral Register Offsets (Port M00)
// =============================================================================
#define UART_REG_RBR_THR        (UART_BASE + 0x00U) // Rx Buffer (R) / Tx Holding (W)
#define UART_REG_IER            (UART_BASE + 0x04U) // Interrupt Enable Register
#define UART_REG_BAUD_DIV       (UART_BASE + 0x08U) // Baud Rate Divisor Generator
#define UART_REG_LCR            (UART_BASE + 0x0CU) // Line Control Register
#define UART_REG_LSR            (UART_BASE + 0x14U) // Line Status Register

// Line Status Register (LSR) Bit Masks
#define UART_LSR_DR             (1U << 0) // Data Ready
#define UART_LSR_TEMT           (1U << 6) // Transmitter Empty

// =============================================================================
// 2. Hardware Timer Peripheral Register Offsets (Port M01)
// =============================================================================
#define TIMER_REG_ALERT_TEST    (TIMER_BASE + 0x000U) // Alert test register
#define TIMER_REG_CTRL          (TIMER_BASE + 0x004U) // Timer Control (bit 0: active)
#define TIMER_REG_INTR_ENABLE0  (TIMER_BASE + 0x100U) // Interrupt enable
#define TIMER_REG_INTR_STATE0   (TIMER_BASE + 0x104U) // Interrupt status / W1C
#define TIMER_REG_INTR_TEST0    (TIMER_BASE + 0x108U) // Interrupt test force
#define TIMER_REG_CFG0          (TIMER_BASE + 0x10CU) // Prescaler [11:0], Step [23:16]
#define TIMER_REG_V_LOWER0      (TIMER_BASE + 0x110U) // mtime counter [31:0]
#define TIMER_REG_V_UPPER0      (TIMER_BASE + 0x114U) // mtime counter [63:32]
#define TIMER_REG_COMPARE_L0    (TIMER_BASE + 0x118U) // mtimecmp threshold [31:0]
#define TIMER_REG_COMPARE_U0    (TIMER_BASE + 0x11CU) // mtimecmp threshold [63:32]

// =============================================================================
// 3. GPIO Controller Register Offsets (Port M02)
// =============================================================================
#define GPIO_REG_INFO           (GPIO_BASE + 0x000U) // Hardware Info (Expected: 0x00000820)
#define GPIO_REG_CFG            (GPIO_BASE + 0x004U) // Config (bit 0: glbl_intrpt_mode)
#define GPIO_REG_MODE_0         (GPIO_BASE + 0x008U) // Pins 0-15 Mode (2 bits per pin)
#define GPIO_REG_MODE_1         (GPIO_BASE + 0x00CU) // Pins 16-31 Mode
#define GPIO_REG_EN             (GPIO_BASE + 0x080U) // Input sampling enable mask
#define GPIO_REG_IN             (GPIO_BASE + 0x100U) // Input pin states
#define GPIO_REG_OUT            (GPIO_BASE + 0x180U) // Output data register
#define GPIO_REG_SET            (GPIO_BASE + 0x200U) // Atomic set bits
#define GPIO_REG_CLEAR          (GPIO_BASE + 0x280U) // Atomic clear bits
#define GPIO_REG_TOGGLE         (GPIO_BASE + 0x300U) // Atomic toggle bits
#define GPIO_REG_INTRPT_RISE_EN (GPIO_BASE + 0x380U) // Rising-edge interrupt enable
#define GPIO_REG_INTRPT_FALL_EN (GPIO_BASE + 0x400U) // Falling-edge interrupt enable
#define GPIO_REG_INTRPT_STATUS  (GPIO_BASE + 0x580U) // Interrupt status (W1C)

// =============================================================================
// 4. SPI Controller Register Offsets (Port M03)
// =============================================================================
#define SPI_REG_CR              (SPI_BASE + 0x60U) // Control Register (SPE, Master)
#define SPI_REG_SR              (SPI_BASE + 0x64U) // Status Register (TX/RX Empty)
#define SPI_REG_DTR             (SPI_BASE + 0x68U) // Data Transmit Register
#define SPI_REG_DRR             (SPI_BASE + 0x6CU) // Data Receive Register
#define SPI_REG_SSR             (SPI_BASE + 0x70U) // Slave Select Register

// =============================================================================
// 5. Seven-Segment Display Controller Register Offsets (Port M04)
// =============================================================================
#define SEG7_REG_DATA           (SEG7_BASE + 0x00U) // 8 nibbles; digit n = bits [4n+3:4n]
#define SEG7_REG_CTRL           (SEG7_BASE + 0x04U) // [0] EN, [1] SEG_ACTIVE_LOW, [2] AN_ACTIVE_LOW, [15:8] DIGIT_MASK
#define SEG7_REG_DP             (SEG7_BASE + 0x08U) // [7:0] Decimal point per digit (1 = on)
#define SEG7_REG_REFRESH_DIV    (SEG7_BASE + 0x0CU) // [15:0] Clock cycles each digit stays enabled

// SEG_CTRL Bitfield Masks
#define SEG7_CTRL_EN            (1U << 0)
#define SEG7_CTRL_SEG_ACT_LOW   (1U << 1)
#define SEG7_CTRL_AN_ACT_LOW    (1U << 2)
#define SEG7_CTRL_MASK_SHIFT    8U
#define SEG7_CTRL_MASK_ALL      (0xFFU << SEG7_CTRL_MASK_SHIFT)

// =============================================================================
// 6. PWM Generator Register Offsets (Port M05)
// =============================================================================
#define PWM_REG_DUTY            (PWM_BASE + 0x00U) // Duty cycle control register

// =============================================================================
// MMIO Low-Level Access Primitives
// =============================================================================
#ifdef SIMULATION_HOST
    // Mock MMIO access for host native testing
    uint32_t host_mmio_read(uint32_t addr);
    void host_mmio_write(uint32_t addr, uint32_t data);
    #define mmio_read32(addr)        host_mmio_read((uint32_t)(addr))
    #define mmio_write32(addr, val)  host_mmio_write((uint32_t)(addr), (uint32_t)(val))
#else
    // Hardware volatile access for bare-metal RISC-V execution
    static inline uint32_t mmio_read32(uintptr_t addr) {
        return *(volatile uint32_t *)addr;
    }
    static inline void mmio_write32(uintptr_t addr, uint32_t val) {
        *(volatile uint32_t *)addr = val;
    }
#endif

#endif // SOC_MEMORY_MAP_H
