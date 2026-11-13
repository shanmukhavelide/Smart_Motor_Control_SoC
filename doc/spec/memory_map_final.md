# Smart ControlSoC — Final System Memory Map & Interconnect Decode Specification

## 1. System Interconnect Overview

The Smart ControlSoC integrates a 2-Master x 6-Slave (`2x6`) AXI crossbar (`axi_interconnect_wrap_2x6.v`):
- **Master Port S00**: VeeR EL2 CPU LSU AXI Master (via 64-to-32 bit bus adaptor)
- **Master Port S01**: Auxiliary / Secondary Master — **Unused & Tied Off** (`0`/`idle`)
- **Address Space per Slave**: 4 KB (`ADDR_WIDTH = 12`)
- **System Base Decode Range**: `0x4000_0000` to `0x4000_AFFF`

---

## 2. Peripheral Memory Map

| Slave Port | Peripheral Module | Top Module Name | Base Address | Address Range | IRQ Line | Description |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **M00** | UART Controller | `axi_uart_top` | `0x4000_0000` | `0x4000_0000 - 0x4000_0FFF` | `uart_interrupt_o` | 16550-compatible UART with FIFO and programmable baud rate |
| **M01** | Hardware Timer | `axi_timer_top` | `0x4000_4000` | `0x4000_4000 - 0x4000_4FFF` | `timer_interrupt_o` | 64-bit `mtime` and `mtimecmp` RISC-V compliant timer |
| **M02** | GPIO Controller | `axi_gpio_top` | `0x4000_2000` | `0x4000_2000 - 0x4000_2FFF` | `gpio_interrupt_o` | 32-bit bidirectional GPIO with edge-triggered interrupts |
| **M03** | SPI Controller | `axi_spi_top` | `0x4000_6000` | `0x4000_6000 - 0x4000_6FFF` | - | SPI Master controller with FIFO and programmable clock divider |
| **M04** | Seven-Segment (SEG7) | `axi_seg7_top` | `0x4000_8000` | `0x4000_8000 - 0x4000_8FFF` | - | 8-digit multiplexed 7-segment display controller (replaces legacy I2C) |
| **M05** | PWM Generator | `myip_v1_0` | `0x4000_A000` | `0x4000_A000 - 0x4000_AFFF` | - | 8-bit resolution PWM generator (256-cycle period) |

*Note: Legacy DMA and I2C controllers are completely removed from the memory map and interconnect decoding.*

---

## 3. Register Summary by Peripheral

### 3.1 UART Registers (`0x4000_0000`)
- `0x00`: `RBR` (Receiver Buffer, RO) / `THR` (Transmitter Holding, WO) [when DLAB=0]
- `0x00`: `DLL` (Divisor Latch LSB, RW) [when DLAB=1]
- `0x04`: `IER` (Interrupt Enable Register, RW) [when DLAB=0]
- `0x04`: `DLM` (Divisor Latch MSB, RW) [when DLAB=1]
- `0x08`: `IIR` (Interrupt Identification, RO) / `FCR` (FIFO Control, WO)
- `0x0C`: `LCR` (Line Control Register, RW) — Bit 7 is DLAB
- `0x10`: `MCR` (Modem Control Register, RW)
- `0x14`: `LSR` (Line Status Register, RO) — Bit 0: DR (Data Ready), Bit 5: THRE, Bit 6: TEMT

### 3.2 64-Bit Timer Registers (`0x4000_4000`)
- `0x000`: `TIMER_ALERT_TEST` (Alert test register)
- `0x004`: `TIMER_CTRL` (Bit 0: timer active enable)
- `0x100`: `TIMER_INTR_ENABLE0` (Bit 0: timer0 interrupt enable)
- `0x104`: `TIMER_INTR_STATE0` (Bit 0: timer0 interrupt pending, W1C)
- `0x108`: `TIMER_INTR_TEST0` (Interrupt test force)
- `0x10C`: `TIMER_CFG0` (Bits [11:0]: prescaler, Bits [23:16]: step)
- `0x110`: `TIMER_V_LOWER0` (Counter `mtime` bits [31:0])
- `0x114`: `TIMER_V_UPPER0` (Counter `mtime` bits [63:32])
- `0x118`: `TIMER_COMPARE_LOWER0` (Threshold `mtimecmp` bits [31:0])
- `0x11C`: `TIMER_COMPARE_UPPER0` (Threshold `mtimecmp` bits [63:32])

### 3.3 GPIO Registers (`0x4000_2000`)
- `0x000`: `GPIO_INFO` (Hardware version / info, RO: `0x0000_0820`)
- `0x004`: `GPIO_CFG` (Global interrupt mode enable)
- `0x008`: `GPIO_MODE_0` (Pins 0–15 direction / mode: 2 bits per pin)
- `0x00C`: `GPIO_MODE_1` (Pins 16–31 direction / mode)
- `0x080`: `GPIO_EN` (Input sampling enable mask)
- `0x100`: `GPIO_IN` (Input pin sampling readback)
- `0x180`: `GPIO_OUT` (Output data write/read)
- `0x200`: `GPIO_SET` (Atomic bit set)
- `0x280`: `GPIO_CLEAR` (Atomic bit clear)
- `0x300`: `GPIO_TOGGLE` (Atomic bit toggle)
- `0x380`: `GPIO_INTRPT_RISE_EN` (Rising edge interrupt enable mask)
- `0x400`: `GPIO_INTRPT_FALL_EN` (Falling edge interrupt enable mask)
- `0x580`: `GPIO_INTRPT_STATUS` (Aggregated interrupt status, W1C)

### 3.4 SPI Master Registers (`0x4000_6000`)
- `0x30`: `SPI_RCLK` (Clock Ratio Register)
- `0x60`: `SPI_CR` (Control Register: SPE, Master, CPOL, CPHA)
- `0x64`: `SPI_SR` (Status Register: TX/RX Empty, Error flags)
- `0x68`: `SPI_DTR` (Data Transmit Register)
- `0x6C`: `SPI_DRR` (Data Receive Register)
- `0x70`: `SPI_SSR` (Slave Select Register)

### 3.5 Seven-Segment Display (SEG7) Registers (`0x4000_8000`)
- `0x00`: `SEG_DATA` (8 nibbles: Digit n = bits `[4n+3:4n]`, default `0x0000_0000`)
- `0x04`: `SEG_CTRL` (Bit 0: EN, Bit 1: SEG_ACTIVE_LOW, Bit 2: AN_ACTIVE_LOW, Bits [15:8]: DIGIT_MASK, default `0x0000_FF06`)
- `0x08`: `SEG_DP` (Bits [7:0]: Decimal points per digit, default `0x0000_0000`)
- `0x0C`: `SEG_REFRESH_DIV` (Bits [15:0]: Clock cycles each digit is enabled, default `0x0000_03E8` = 1000 cycles)

### 3.6 PWM Generator Registers (`0x4000_A000`)
- `0x00`: `PWM_DUTY` (`slv_reg0`: Bits [7:0] specify duty cycle `0..255` out of 256 clock cycles)
- `0x04`: `slv_reg1` (Reserved / read-write)
- `0x08`: `slv_reg2` (Reserved / read-write)
- `0x0C`: `slv_reg3` (Reserved / read-write)
