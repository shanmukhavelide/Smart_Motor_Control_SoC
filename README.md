# Smart Motor Control SoC (Smart ControlSoC)

![SoC Architecture](doc/AXI4-Lite%20Smart%20Peripheral%20SoC%20Block%20Diagram.png)

[![Architecture](https://img.shields.io/badge/Architecture-CPU%20BFM%20%2B%206%20Peripherals-blue.svg)](#)
[![Interconnect](https://img.shields.io/badge/Interconnect-AXI4--Lite%20(2x6)-orange.svg)](#)
[![Simulation](https://img.shields.io/badge/Simulation-Icarus%20%7C%20VCS%20%7C%20Questa-purple.svg)](#)
[![Status](https://img.shields.io/badge/Status-Front--End%20Integration%20Complete-brightgreen.svg)](#)

---

## 1. Executive Summary & Architecture Overview

The **Smart Motor Control SoC** (`smart_controlsoc_top` in `rtl/smart_controlsoc_top.v`) is a 32-bit peripheral-oriented System-on-Chip designed for real-time motor control, precision pulse-width modulation, embedded multiplexed display driving, and multi-protocol industrial communication.

### 1.1 CPU Architecture & Memory Reality
* **Authoritative Implementation:** The active SoC design uses a **Behavioral Bus Functional Model (BFM)** for the CPU master (`rtl/Cores-VeeR-EL2/el2_veer_wrapper.v`).
* **CPU Memory Model:** The wrapper contains **zero internal memory** (0 bytes ICCM, 0 bytes DCCM, no cache, and no internal SRAM).
* **Bus Transaction Generation:** Bus activity is driven through behavioral Verilog tasks `cpu_write(addr, data, strb)` and `cpu_read(addr, data)` that directly exercise the 64/32-bit Load-Store Unit master interface (`lsu_axi_*`) on interconnect slave port `S00`.
* **Tie-Offs:** The secondary interconnect master port `S01` is tied off (`0`/idle). The CPU instruction-fetch bus (`ifu_axi_*`), system bus (`sb_axi_*`), DMA slave bus (`dma_axi_*`), and CPU interrupt lines are cleanly tied off.
* **Synthesizable Core Status:** A synthesizable VeeR EL2 core top (`smart_controlsoc_veer_top` with `filelist_veer.f`) is preserved in the repository as a separate experimental branch and classified as **EXPERIMENTAL / IMPLEMENTED / NOT DYNAMICALLY VERIFIED**.

### 1.2 Peripheral Integration & IP Scope
* **Interconnect:** 2-Master $\times$ 6-Slave AXI4-Lite Crossbar Interconnect (`axi_interconnect_wrap_2x6`) with round-robin arbitration, independent address decoding per port, and slave isolation.
* **Six Active Peripherals:**
  1. **UART (`M00`, `0x4000_0000`):** Full-duplex serial UART with 32-deep FIFOs, programmable baud divisor, and interrupts.
  2. **Hardware Timer (`M01`, `0x4000_4000`):** 64-bit real-time counter (`mtime`) and comparator (`mtimecmp`) with prescaler.
  3. **GPIO (`M02`, `0x4000_2000`):** 32-bit bidirectional I/O with OpenTitan register bus, atomic SET/CLEAR/TOGGLE, and edge/level interrupts.
  4. **SPI Master (`M03`, `0x4000_6000`):** Mode 0 SPI master controller with 32-deep FIFOs and clock ratio divider.
  5. **Seven-Segment Display (`M04`, `0x4000_8000`):** 8-digit multiplexed 7-segment display driver replacing legacy I2C.
  6. **PWM Generator (`M05`, `0x4000_A000`):** 8-bit duty-cycle motor drive generator with 256-cycle base period.
* **Excised Legacy IPs:** Direct Memory Access (DMA), I2C, and AES peripherals have been completely excised from the SoC interconnect, top RTL, and active filelists.

---

## 2. System Architecture & Interconnect Topology

```
+---------------------------------------------------------------------------------------------------------------+
|                                             SMART CONTROLSOC TOP                                              |
|                                                                                                               |
|  +--------------------+         +--------------------------------------------------------------------------+  |
|  |    CPU BFM Tasks   |  (S00)  |                                AXI4-Lite                                 |  |
|  | (el2_veer_wrapper) | =======>|                            Interconnect (2x6)                            |  |
|  +--------------------+         +--------------------------------------------------------------------------+  |
|                                        ||          ||          ||          ||          ||          ||         |
|  +--------------------+  (S01)         || (M00)    || (M01)    || (M02)    || (M03)    || (M04)    || (M05)   |
|  |     [Tied Off]     | =======>       \/          \/          \/          \/          \/          \/         |
|  |   (Zero Driven)    |         +----------++----------++----------++----------++----------++----------+      |
|  +--------------------+         | AXI UART || AXI Timer|| AXI GPIO || AXI SPI  || AXI Seg7 || AXI PWM  |      |
|                                 +----------++----------++----------++----------++----------++----------+      |
|                                      ||          ||          ||          ||          ||          ||           |
+--------------------------------------||----------||----------||----------||----------||----------||-----------+
                                       \/          \/          \/          \/          \/          \/
                                    [Serial]   [Timer IRQ] [32x GPIO]   [SPI Bus]  [7-Seg Bus]  [PWM Pin]
```

### 2.1 Authoritative Interconnect Decode Table

| Port | Peripheral Subsystem | Top RTL Module | Base Address | Address Range | Decoded Size |
| :---: | :--- | :--- | :---: | :---: | :---: |
| `S00` | CPU BFM Master | `el2_veer_wrapper` | — | — | Master Port |
| `S01` | Tied Off Master | — | — | — | Tied Off (`0`/idle) |
| `M00` | UART Controller | `axi_uart_top` | `0x4000_0000` | `0x4000_0000` – `0x4000_0FFF` | 4 KB |
| `M01` | 64-bit Hardware Timer | `axi_timer_top` | `0x4000_4000` | `0x4000_4000` – `0x4000_4FFF` | 4 KB |
| `M02` | 32-bit OpenTitan GPIO | `axi_gpio_top` | `0x4000_2000` | `0x4000_2000` – `0x4000_2FFF` | 4 KB |
| `M03` | SPI Master Controller | `axi_spi_top` | `0x4000_6000` | `0x4000_6000` – `0x4000_6FFF` | 4 KB |
| `M04` | Seven-Segment Display (SEG7) | `axi_seg7_top` | `0x4000_8000` | `0x4000_8000` – `0x4000_8FFF` | 4 KB |
| `M05` | 8-bit PWM Generator | `myip_v1_0` | `0x4000_A000` | `0x4000_A000` – `0x4000_AFFF` | 4 KB |

---

## 3. Peripheral Subsystems & Register Maps

### 3.1 UART Controller (Port `M00`, Base: `0x4000_0000`)
* **Module:** `axi_uart_top` (`rtl/uart_directory/rtl/axi_uart_top.v`)
* **Description:** Full-duplex asynchronous serial communication controller with 32-entry TX/RX FIFOs, programmable line configuration, and baud rate divisor logic.
* **Internal Addressing:** Decoded by `axi_*addr[4:2]`.

| Offset | Register Name | Width | Access | Reset Value | Description |
| :---: | :--- | :---: | :---: | :---: | :--- |
| `0x00` | `UART_RBR` | 8-bit | RO | `0x00` | Receiver Buffer Register: reads next received byte from RX FIFO (when DLAB=0) |
| `0x00` | `UART_THR` | 8-bit | WO | `0x00` | Transmitter Holding Register: writes byte to transmit FIFO (when DLAB=0) |
| `0x04` | `UART_IER` | 1-bit (`[0]`) | RW | `0x00` | Interrupt Enable Register (`uart_irq_en_int`, bit 0: RX Data Ready interrupt) |
| `0x08` | `UART_BAUD_DIVISOR` | 32-bit | RW | `0x0000_0364` | Baud Rate Divisor: clock divider ratio (100 MHz / 115200 baud = 868) |
| `0x0C` | `UART_LCR` | 8-bit (`[7:0]`) | RW | `0x00` | Line Control Register: DLAB `[7]`, Parity Mode `[4]`, Parity En `[3]`, Stop Bits `[2]`, Word Length `[1:0]` |
| `0x14` | `UART_LSR` | 7-bit (`[6:0]`) | RO | Dynamic | Line Status Register: TEMT (bit 6), THRE (bit 5), Data Ready (bit 0) |

---

### 3.2 64-bit Hardware Timer (Port `M01`, Base: `0x4000_4000`)
* **Module:** `axi_timer_top` (`rtl/timer_directory/rtl/axi_timer_top.sv`)
* **Description:** OpenTitan-compatible 64-bit real-time counter (`mtime`) with 64-bit comparison threshold (`mtimecmp`), configurable clock prescaler, and interrupt generation.
* **Internal Addressing:** Decoded by `axi_*addr[8:0]`.

| Offset | Register Name | Width | Access | Reset Value | Description |
| :---: | :--- | :---: | :---: | :---: | :--- |
| `0x000` | `REG_ALERT_TEST` | 32-bit | WO | `0x0000_0000` | Alert test register (reads 0) |
| `0x004` | `REG_CTRL` | 1-bit (`[0]`) | RW | `0x0000_0000` | Timer Control Register: bit 0 = `ctrl_active` counter enable |
| `0x100` | `REG_INTR_ENABLE0` | 1-bit (`[0]`) | RW | `0x0000_0000` | Interrupt Enable Register: bit 0 = `intr_enable` (enables timer interrupt output) |
| `0x104` | `REG_INTR_STATE0` | 1-bit (`[0]`) | W1C | `0x0000_0000` | Interrupt State Register: bit 0 = `intr_state` (pending flag, write 1 to clear) |
| `0x108` | `REG_INTR_TEST0` | 1-bit (`[0]`) | WO | `0x0000_0000` | Software Interrupt Force Test: write 1 to assert `intr_state` (reads 0) |
| `0x10C` | `REG_CFG0` | 24-bit (`[23:0]`) | RW | `0x0001_0000` | Configuration: Prescaler `[11:0]` = 0, Step `[23:16]` = 1 |
| `0x110` | `REG_TIMER_V_LOWER0` | 32-bit | RW | `0x0000_0000` | Real-Time Counter `mtime` Lower 32 bits `[31:0]` |
| `0x114` | `REG_TIMER_V_UPPER0` | 32-bit | RW | `0x0000_0000` | Real-Time Counter `mtime` Upper 32 bits `[63:32]` |
| `0x118` | `REG_COMPARE_LOWER0_0`| 32-bit | RW | `0xFFFF_FFFF` | Compare Threshold `mtimecmp` Lower 32 bits `[31:0]` (write clears interrupt) |
| `0x11C` | `REG_COMPARE_UPPER0_0`| 32-bit | RW | `0xFFFF_FFFF` | Compare Threshold `mtimecmp` Upper 32 bits `[63:32]` (write clears interrupt) |

---

### 3.3 32-bit OpenTitan GPIO Controller (Port `M02`, Base: `0x4000_2000`)
* **Module:** `axi_gpio_top` (`rtl/gpio_directory/rtl/axi_gpio_top.sv`)
* **Description:** 32-bit bidirectional GPIO controller based on OpenTitan `reg_bus` with 2-stage input synchronizers, atomic operations (`SET`, `CLEAR`, `TOGGLE`), and programmable interrupts.
* **Internal Addressing:** Decoded by `axi_*addr[10:0]`.

| Offset | Register Name | Width | Access | Reset Value | Description |
| :---: | :--- | :---: | :---: | :---: | :--- |
| `0x000` | `GPIO_INFO` | 20-bit | RO | `0x0000_0820` | Version `[19:10]` = 2, Pin Count `[9:0]` = 32 |
| `0x004` | `GPIO_CFG` | 2-bit | RW | `0x0000_0000` | Configuration: `pin_lvl_intrpt_mode` `[0]`, `glbl_intrpt_mode` `[1]` |
| `0x008` | `GPIO_GPIO_MODE_0` | 32-bit | RW | `0x0000_0000` | Pin modes for GPIO 0–15 (2 bits/pin: 0=Input, 1=PushPull, 2=OpenDrain0, 3=OpenDrain1) |
| `0x00C` | `GPIO_GPIO_MODE_1` | 32-bit | RW | `0x0000_0000` | Pin modes for GPIO 16–31 (2 bits/pin) |
| `0x080` | `GPIO_GPIO_EN` | 32-bit | RW | `0x0000_0000` | Pad input sampling enable mask `[31:0]` |
| `0x100` | `GPIO_GPIO_IN` | 32-bit | RO | Live pins | Synchronized input state of GPIO pads `[31:0]` |
| `0x180` | `GPIO_GPIO_OUT` | 32-bit | RW | `0x0000_0000` | Direct output register for GPIO pads `[31:0]` |
| `0x200` | `GPIO_GPIO_SET` | 32-bit | WO | `0x0000_0000` | Atomic Bit Set: write 1 to set corresponding bits in `GPIO_OUT` (reads 0) |
| `0x280` | `GPIO_GPIO_CLEAR` | 32-bit | WO | `0x0000_0000` | Atomic Bit Clear: write 1 to clear corresponding bits in `GPIO_OUT` (reads 0) |
| `0x300` | `GPIO_GPIO_TOGGLE` | 32-bit | WO | `0x0000_0000` | Atomic Bit Toggle: write 1 to invert corresponding bits in `GPIO_OUT` (reads 0) |
| `0x380` | `GPIO_INTRPT_RISE_EN` | 32-bit | RW | `0x0000_0000` | Rising edge interrupt enable mask `[31:0]` |
| `0x400` | `GPIO_INTRPT_FALL_EN` | 32-bit | RW | `0x0000_0000` | Falling edge interrupt enable mask `[31:0]` |
| `0x480` | `GPIO_INTRPT_LVL_HIGH_EN` | 32-bit | RW | `0x0000_0000` | High level interrupt enable mask `[31:0]` |
| `0x500` | `GPIO_INTRPT_LVL_LOW_EN` | 32-bit | RW | `0x0000_0000` | Low level interrupt enable mask `[31:0]` |
| `0x580` | `GPIO_INTRPT_STATUS` | 32-bit | W1C | `0x0000_0000` | Aggregated interrupt status `[31:0]` (write 1 to clear) |
| `0x600` | `GPIO_INTRPT_RISE_STATUS` | 32-bit | W1C | `0x0000_0000` | Rising edge interrupt status `[31:0]` (write 1 to clear) |
| `0x680` | `GPIO_INTRPT_FALL_STATUS` | 32-bit | W1C | `0x0000_0000` | Falling edge interrupt status `[31:0]` (write 1 to clear) |
| `0x700` | `GPIO_INTRPT_LVL_HIGH_STATUS`| 32-bit | W1C | `0x0000_0000` | High level interrupt status `[31:0]` (write 1 to clear) |
| `0x780` | `GPIO_INTRPT_LVL_LOW_STATUS` | 32-bit | W1C | `0x0000_0000` | Low level interrupt status `[31:0]` (write 1 to clear) |

---

### 3.4 SPI Master Controller (Port `M03`, Base: `0x4000_6000`)
* **Module:** `axi_spi_top` (`rtl/spi_directory/rtl/axi_spi_top.v`)
* **Description:** Full-featured master-mode SPI controller supporting Mode 0 (`CPOL=0`, `CPHA=0`), 32-deep TX/RX FIFOs, software reset, and clock ratio prescaler.
* **Internal Addressing:** Decoded by `axi_*addr[6:2]`.

| Offset | Register Name | Width | Access | Reset Value | Description |
| :---: | :--- | :---: | :---: | :---: | :--- |
| `0x1C` | `SPI_GIER` | 32-bit | RW | `0x0000_0000` | Global Interrupt Enable Register (bit 31: Global Interrupt Enable) |
| `0x20` | `SPI_ISR` | 32-bit | W1C/toggle | `0x0000_0000` | Interrupt Status Register |
| `0x28` | `SPI_IER` | 32-bit | RW | `0x0000_0000` | Interrupt Enable Register |
| `0x30` | `SPI_RCLK` | 3-bit (`[2:0]`) | RW | `0x0000_0004` | Ratio Clock Prescaler Register: system clock to SCK divider ratio |
| `0x40` | `SPI_SRR` | 32-bit | WO | `0x0000_0000` | Software Reset Register: write `0x0000_000A` to soft-reset core |
| `0x60` | `SPI_CR` | 32-bit | RW | `0x0000_0180` | Control: LSB 1st `[9]`, RX FIFO rst `[6]`, TX FIFO rst `[5]`, CPHA `[4]`, CPOL `[3]`, Master `[2]`, Enable `[1]` |
| `0x64` | `SPI_SR` | 32-bit | RO | `0x0000_00A5` | Status: SMOD `[5]`, MODF `[4]`, TX Full `[3]`, TX Empty `[2]`, RX Full `[1]`, RX Empty `[0]` |
| `0x68` | `SPI_DTR` | 8-bit (`[7:0]`) | WO | `0x0000_0000` | Data Transmit Register: pushes byte into TX FIFO |
| `0x6C` | `SPI_DRR` | 8-bit (`[7:0]`) | RO | `0x0000_0000` | Data Receive Register: pops byte from RX FIFO |
| `0x70` | `SPI_SSR` | 32-bit | RW | `0xFFFF_FFFF` | Slave Select Register (bit 0: active-low slave 0 select) |
| `0x74` | `SPI_TFOR` | 32-bit | RO | `0x0000_0000` | TX FIFO Occupancy Register |
| `0x78` | `SPI_RFOR` | 32-bit | RO | `0x0000_0000` | RX FIFO Occupancy Register |

---

### 3.5 Seven-Segment Display Controller (Port `M04`, Base: `0x4000_8000`)
* **Module:** `axi_seg7_top` (`rtl/seg7_directory/rtl/axi_seg7_top.sv`)
* **Description:** 8-digit multiplexed Seven-Segment Display Controller (replaces legacy I2C IP on M04). Features internal hex-to-7-segment glyph decoders, programmable scan refresh clock divider, dynamic blanking digit mask, and decimal point control.
* **Internal Addressing:** Decoded by `axi_*addr[3:2]`.

| Offset | Register Name | Width | Access | Reset Value | Description |
| :---: | :--- | :---: | :---: | :---: | :--- |
| `0x00` | `SEG_DATA` | 32-bit | RW | `0x0000_0000` | 8 nibbles: digit $n$ stored in bits `[4n+3:4n]`. Digit 0 = `[3:0]` |
| `0x04` | `SEG_CTRL` | 16-bit | RW | `0x0000_FF06` | Display control: Enable `[0]`, SEG active-low `[1]`, AN active-low `[2]`, Digit mask `[15:8]` (FF = all 8 active) |
| `0x08` | `SEG_DP` | 8-bit (`[7:0]`) | RW | `0x0000_0000` | Decimal point mask: bit $n$ controls decimal point on digit $n$ |
| `0x0C` | `SEG_REFRESH_DIV` | 16-bit | RW | `0x0000_03E8` | 16-bit clock divisor for digit scan rate (default: 1000 clock cycles/digit) |

---

### 3.6 8-bit PWM Generator (Port `M05`, Base: `0x4000_A000`)
* **Module:** `myip_v1_0` (`rtl/pwm_directory/rtl/myip_v1_0.v`)
* **Description:** 8-bit pulse-width modulation generator designed for motor speed and power regulation. Compares a free-running 8-bit counter (0..255) against the duty register (`pwm_counter < duty_cycle`).
* **Duty Cycle Encoding:** Base period = 256 cycles. `0x00` = 0% (constant low), `0x80` = 50%, `0xFF` = 255/256 (99.61%).
* **Internal Addressing:** Decoded by `axi_*addr[3:2]`.

| Offset | Register Name | Width | Access | Reset Value | Description |
| :---: | :--- | :---: | :---: | :---: | :--- |
| `0x00` | `slv_reg0` / `PWM_DUTY` | 32-bit (`[7:0]` duty) | RW | `0x0000_0000` | 8-bit duty cycle (`pwm_counter < duty_cycle`). Base period = 256 cycles. |
| `0x04` | `slv_reg1` | 32-bit | RW | `0x0000_0000` | General-purpose read/write scratch register |
| `0x08` | `slv_reg2` | 32-bit | RW | `0x0000_0000` | General-purpose read/write scratch register |
| `0x0C` | `slv_reg3` | 32-bit | RW | `0x0000_0000` | General-purpose read/write scratch register |

---

## 4. Repository Structure

```
Smart_Motor_Control_SoC/
├── doc/                                   # Specifications, test plans, execution status
│   ├── PROJECT_EXECUTION_STATUS.md        # Autonomous phase execution tracking
│   ├── FINAL_PROJECT_STATUS.md            # Comprehensive project verification report
│   └── Smart_ControlSoC_Testplan.csv      # Verification test plan
├── rtl/
│   ├── Cores-VeeR-EL2/                    # VeeR EL2 core repository & active BFM wrapper
│   │   ├── el2_veer_wrapper.v             # Authoritative CPU BFM wrapper (cpu_write/cpu_read)
│   │   └── design/                        # Synthesizable VeeR RTL (deferred/experimental)
│   ├── interconnect/                      # AXI4-Lite 2x6 Crossbar Interconnect
│   ├── uart_directory/                    # AXI4-Lite UART IP Core (Port M00)
│   ├── timer_directory/                   # 64-bit Hardware Timer IP Core (Port M01)
│   ├── gpio_directory/                    # OpenTitan Bidirectional GPIO IP Core (Port M02)
│   ├── spi_directory/                     # AXI4-Lite SPI Master IP Core (Port M03)
│   ├── seg7_directory/                    # Seven-Segment Display IP Core (Port M04)
│   ├── pwm_directory/                     # AXI4-Lite PWM Generator IP Core (Port M05)
│   └── smart_controlsoc_top.v             # Top-Level SoC Integration Module
├── sw/                                    # Bare-metal C verification and MMIO headers
│   ├── soc_memory_map.h                   # Authoritative C MMIO definitions
│   └── main1.c                            # 8-suite MMIO verification program
├── tb/
│   ├── tb_smart_controlsoc_top.sv         # System-Level Directed SoC Testbench (Tests 1–12 & main1.hex)
│   ├── tb_smart_controlsoc_veer_top.sv    # Experimental synthesizable VeeR testbench
│   ├── soc_uvm/                           # SoC-Level UVM Environment (filelist_soc_uvm.f, tb_soc_uvm_top.sv)
│   ├── uvm/                               # Modular Standalone UVM Testbenches
│   │   ├── seg7/                          # Standalone SEG7 UVM (tb_seg7_top.sv, 7 tests)
│   │   ├── pwm/                           # Standalone PWM UVM (tb_pwm_top.sv, 4 tests)
│   │   ├── spi/                           # Standalone SPI UVM (tb_spi_top.sv, 6 tests)
│   │   └── soc/                           # Alternative SoC UVM suite (3 tests)
│   └── *.vip_uvm_tb/                      # Peripheral VIP directories (gpio, pwm, spi, uart, i2c legacy)
├── main1.hex                              # 6-peripheral MMIO simulation trace file (59 transactions)
├── filelist.f                             # Unified RTL simulation filelist
└── README.md                              # This file
```

---

## 5. Verification Status & Test Suites

### 5.1 Current Verification Status Summary

* **Locally Reproduced & Passing:**
  - **UART Standalone Unit Test:** **20/20 PASS** (`tb_axi_uart_top.v` via Icarus Verilog `vvp`).
  - **Host C Driver Test:** **36/36 PASS** (`sw/main1.c` with `-DSIMULATION_HOST` via GCC; exercises mock MMIO model).
* **Reported in Logs (Not Yet Reproduced Locally):**
  - **Seven-Segment Display Unit Test (`sim_seg7`):** 41/41 reported passed in prior logs.
  - **SPI Master Controller Unit Test (`sim_spi`):** 119/119 reported passed in prior logs.
  - **PWM Generator Unit Test (`sim_pwm`):** 28/28 reported passed in prior logs.
* **Not Verified / Not Run:**
  - **GPIO Standalone Testbench (`tb_gpio.sv`):** Not verified (OpenTitan assignment pattern syntax unsupported in local Icarus Verilog).
  - **Hardware Timer Standalone Testbench (`tb_timer.sv`):** Not verified (unpacked array port syntax requires full SV simulator).
  - **Full-SoC Directed Testbench (`tb_smart_controlsoc_top.sv`):** Not run (needs full-SoC commercial simulator like VCS or QuestaSim).
  - **Full-SoC UVM Suites (`tb/soc_uvm/`):** Blocked by remote Synopsys VCS license server unavailability.
  - **Legacy I2C VIP:** Excluded from active SoC; legacy VIP code retained in `tb/i2c.vip_uvm_tb/`.

---

### 5.2 System-Level Directed Testbench (`tb/tb_smart_controlsoc_top.sv`)
Executes `main1.hex` MMIO trace by default (59 transactions across all 6 peripherals), and directed tests 1–12 via `+RUN_ALL_TESTS`:
* **Test 1:** Default reset state verification across all 6 peripherals.
* **Test 2:** UART Baud rate divisor and Line Control Register configuration.
* **Test 3:** UART single character transmission and baud timing capture.
* **Test 4:** UART multi-byte burst transmission (`"RISCV"` string).
* **Test 5:** UART external RX injection and interrupt assertion / clearing.
* **Test 6:** UART full-duplex simultaneous transmit and receive operation.
* **Test 7:** SPI Controller reset, Mode 0 configuration, and transmission verification.
* **Test 8:** PWM Generator duty cycle programming (50%) and pin toggle verification.
* **Test 9:** Seven-Segment Display Controller MMIO read/write and scan multiplex verification.
* **Test 10:** GPIO direct output, atomic set/clear/toggle, input sampling, and edge interrupt test.
* **Test 11:** 64-bit Hardware Timer prescaler, counter progression, compare interrupt, and W1C test.
* **Test 12:** Concurrent Multi-Peripheral Stress Test (interleaved access across all 6 peripherals).

---

### 5.3 Standalone UVM Environments (`tb/uvm/`)
* **Seven-Segment Controller (`tb/uvm/seg7/`):** 7 tests (`seg7_base_test`, `seg7_hex_display_test`, `seg7_scan_mask_test`, `seg7_polarity_test`, `seg7_dp_control_test`, `seg7_refresh_boundary_test`, `seg7_full_hex_sweep_test`).
* **PWM Generator (`tb/uvm/pwm/`):** 4 tests (`pwm_base_test`, `pwm_duty_cycle_test`, `pwm_period_test`, `pwm_random_test`).
* **SPI Master Controller (`tb/uvm/spi/`):** 6 tests (`spi_base_test`, `spi_loopback_test`, `spi_fifo_threshold_test`, `spi_mode_transfer_test`, `spi_interrupt_test`, `spi_random_test`).
* **SoC UVM Suite (`tb/uvm/soc/`):** 3 tests (`soc_base_test`, `soc_reg_access_test`, `soc_peripheral_concurrent_test`).

---

## 6. How to Build & Simulate

### 6.1 Run Standalone UART Unit Test (Icarus Verilog)
```bash
iverilog -g2012 -Irtl/uart_directory/include rtl/uart_directory/rtl/*.v rtl/uart_directory/tb/tb_axi_uart_top.v -o sim_uart
vvp ./sim_uart
```

### 6.2 Run Host-Native C Driver Test (GCC)
```bash
gcc -DSIMULATION_HOST -Isw sw/main1.c -o sim_main1
./sim_main1
```

### 6.3 Run Standalone Unit Tests (Prior Compiled Binaries)
```bash
vvp ./sim_seg7    # 41 tests
vvp ./sim_spi     # 119 tests
vvp ./sim_pwm     # 28 tests
```

### 6.4 Run UVM Simulations (Synopsys VCS / QuestaSim)
```bash
./run_seg7_uvm.sh seg7_hex_display_test
./run_pwm_uvm.sh  pwm_duty_cycle_test
./run_spi_uvm.sh  spi_loopback_test
./run_soc_uvm.sh  soc_test
```

### 6.5 Experimental Synthesizable VeeR EL2 Branch
> [!NOTE]
> The authoritative project implementation is the BFM-based SoC (`smart_controlsoc_top`). Full synthesizable core integration is an exploratory branch (`smart_controlsoc_veer_top`) deferred from the current milestone and classified as **EXPERIMENTAL / IMPLEMENTED / NOT DYNAMICALLY VERIFIED**.
