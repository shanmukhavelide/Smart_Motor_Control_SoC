# Smart Motor Control SoC (Smart ControlSoC)

![SoC Architecture](doc/AXI4-Lite%20Smart%20Peripheral%20SoC%20Block%20Diagram.png)

[![Architecture](https://img.shields.io/badge/Architecture-CPU%20BFM%20%2B%206%20Peripherals-blue.svg)](#)
[![Interconnect](https://img.shields.io/badge/Interconnect-AXI4--Lite%20(2x6)-orange.svg)](#)
[![Verification](https://img.shields.io/badge/Simulation-VCS%20%7C%20Questa%20%7C%20Icarus%20(supported%20flows)-purple.svg)](#)
[![Status](https://img.shields.io/badge/Project%20Status-Integration%20Complete%2C%20Re--verification%20Pending-yellow.svg)](#)

---

## 1. Executive Summary & Project Overview

The **Smart Motor Control SoC** (`smart_controlsoc_top` in `rtl/smart_controlsoc_top.v`) is a peripheral-oriented System-on-Chip (SoC) designed for real-time motor control, embedded display driving, and multi-protocol industrial communication.

### CPU Architecture
* **CPU Implementation (`el2_veer_wrapper.v`):** The authoritative SoC architecture uses a **Behavioral Bus Functional Model (BFM)** for the CPU master (`rtl/Cores-VeeR-EL2/el2_veer_wrapper.v`). It is **not** an active synthesizable processor pipeline.
* **CPU Memory Reality:** The wrapper contains **zero internal memory** (0 bytes ICCM, 0 bytes DCCM, no cache, and no internal SRAM).
* **Bus Transactions:** Transactions are generated behaviorally using `cpu_write(addr, data, strb)` and `cpu_read(addr, data)` tasks that directly drive the AXI4-Lite Load-Store Unit (`lsu_axi_*`) master interface on interconnect port `S00`. The instruction-fetch (`ifu_axi_*`), system bus (`sb_axi_*`), DMA slave (`dma_axi_*`), and CPU interrupt lines are tied off (`0`/`idle`).
* **Synthesizable VeeR Integration Status:** A synthesizable VeeR EL2 core top (`smart_controlsoc_veer_top`) exists in this repo (`filelist_veer.f`, `tb/tb_smart_controlsoc_veer_top.sv`) and is classified as **EXPERIMENTAL / IMPLEMENTED / NOT DYNAMICALLY VERIFIED**.

### Key Architectural Highlights
* **Bus Interconnect:** 2-Master $\times$ 6-Slave AXI4-Lite Crossbar Interconnect (`axi_interconnect_wrap_2x6`):
  - Master Port `S00`: Driven by CPU BFM (`el2_veer_wrapper`).
  - Master Port `S01`: Tied off (`0` / idle).
* **Integrated Peripherals (6 Slaves):**
  1. **UART (`M00`, `0x4000_0000`):** Serial UART with TX/RX FIFOs, baud divisor, and interrupt support.
  2. **Hardware Timer (`M01`, `0x4000_4000`):** 64-bit `mtime` counter and `mtimecmp` comparator with prescaler.
  3. **GPIO Controller (`M02`, `0x4000_2000`):** 32-bit bidirectional GPIO with OpenTitan register bus and atomic SET/CLEAR/TOGGLE.
  4. **SPI Controller (`M03`, `0x4000_6000`):** Master-mode SPI controller with 32-deep FIFOs and clock ratio divider.
  5. **Seven-Segment Controller (`M04`, `0x4000_8000`):** 8-digit multiplexed 7-segment display driver (replaces legacy I2C).
  6. **PWM Generator (`M05`, `0x4000_A000`):** 8-bit duty-cycle generator with 256-cycle base period.
* **IP Scope:** DMA, I2C, and AES peripherals are completely excised from the SoC interconnect, top RTL, and active filelists.

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

### Interconnect Port Mapping & Decoding

| Master Port | Source Master | Functional Role |
| :---: | :--- | :--- |
| `S00` | CPU BFM (`el2_veer_wrapper`) | Primary CPU MMIO master interface (drives `lsu_axi_*`) |
| `S01` | Tied off (`0` / idle) | Unused secondary master port |

| Slave Port | Peripheral | RTL Top Module | Base Address | Address Range | Decoded Size |
| :---: | :--- | :--- | :---: | :---: | :---: |
| `M00` | UART Controller | `axi_uart_top` | `0x4000_0000` | `0x4000_0000` – `0x4000_0FFF` | 4 KB |
| `M01` | Hardware Timer | `axi_timer_top` | `0x4000_4000` | `0x4000_4000` – `0x4000_4FFF` | 4 KB |
| `M02` | GPIO Controller | `axi_gpio_top` | `0x4000_2000` | `0x4000_2000` – `0x4000_2FFF` | 4 KB |
| `M03` | SPI Master | `axi_spi_top` | `0x4000_6000` | `0x4000_6000` – `0x4000_6FFF` | 4 KB |
| `M04` | Seven-Segment (SEG7) | `axi_seg7_top` | `0x4000_8000` | `0x4000_8000` – `0x4000_8FFF` | 4 KB |
| `M05` | PWM Generator | `myip_v1_0` | `0x4000_A000` | `0x4000_A000` – `0x4000_AFFF` | 4 KB |

---

## 3. Peripheral Register Definitions

### 3.1 UART Controller (Base: `0x4000_0000`)
| Offset | Register Name | Width | Access | Reset Value | Description |
| :---: | :--- | :---: | :---: | :---: | :--- |
| `0x00` | `UART_RBR` | 8-bit | RO | `0x00` | Receiver Buffer Register (reads byte from RX FIFO when DLAB=0) |
| `0x00` | `UART_THR` | 8-bit | WO | `0x00` | Transmitter Holding Register (pushes byte to TX FIFO when DLAB=0) |
| `0x04` | `UART_IER` | 1-bit (`[0]`) | RW | `0x00` | Interrupt Enable Register (`uart_irq_en_int`, bit 0) |
| `0x08` | `UART_BAUD_DIVISOR` | 32-bit | RW | `0x0000_0364` | Baud Rate Divisor (default: 100 MHz / 115200 = 868) |
| `0x0C` | `UART_LCR` | 8-bit (`[7:0]`) | RW | `0x00` | Line Control Register: DLAB `[7]`, Parity Mode `[4]`, Parity En `[3]`, Stop Bits `[2]`, Word Length `[1:0]` |
| `0x14` | `UART_LSR` | 7-bit (`[6:0]`) | RO | Dynamic | Line Status Register: TEMT (bit 6), THRE (bit 5), Data Ready (bit 0) |

### 3.2 Hardware Timer (Base: `0x4000_4000`)
| Offset | Register Name | Width | Access | Reset Value | Description |
| :---: | :--- | :---: | :---: | :---: | :--- |
| `0x000` | `REG_ALERT_TEST` | 32-bit | WO | `0x0000_0000` | Alert test register (reads 0) |
| `0x004` | `REG_CTRL` | 1-bit (`[0]`) | RW | `0x0000_0000` | Timer Control (bit 0: `ctrl_active` counter enable) |
| `0x100` | `REG_INTR_ENABLE0` | 1-bit (`[0]`) | RW | `0x0000_0000` | Timer Interrupt Enable (bit 0: `intr_enable`) |
| `0x104` | `REG_INTR_STATE0` | 1-bit (`[0]`) | W1C | `0x0000_0000` | Timer Interrupt Status (bit 0: `intr_state`, write 1 to clear) |
| `0x108` | `REG_INTR_TEST0` | 1-bit (`[0]`) | WO | `0x0000_0000` | Software Interrupt Force (write 1 to force `intr_state`, reads 0) |
| `0x10C` | `REG_CFG0` | 24-bit (`[23:0]`) | RW | `0x0001_0000` | Timer Configuration (Prescaler `[11:0]` = 0, Step `[23:16]` = 1) |
| `0x110` | `REG_TIMER_V_LOWER0` | 32-bit | RW | `0x0000_0000` | 64-bit Real-Time Counter `mtime` Lower 32 bits `[31:0]` |
| `0x114` | `REG_TIMER_V_UPPER0` | 32-bit | RW | `0x0000_0000` | 64-bit Real-Time Counter `mtime` Upper 32 bits `[63:32]` |
| `0x118` | `REG_COMPARE_LOWER0_0`| 32-bit | RW | `0xFFFF_FFFF` | 64-bit Compare Threshold `mtimecmp` Lower 32 bits `[31:0]` (write clears IRQ) |
| `0x11C` | `REG_COMPARE_UPPER0_0`| 32-bit | RW | `0xFFFF_FFFF` | 64-bit Compare Threshold `mtimecmp` Upper 32 bits `[63:32]` (write clears IRQ) |

### 3.3 GPIO Controller (Base: `0x4000_2000`)
| Offset | Register Name | Width | Access | Reset Value | Description |
| :---: | :--- | :---: | :---: | :---: | :--- |
| `0x000` | `GPIO_INFO` | 20-bit | RO | `0x0000_0820` | Version `[19:10]` = 2, Pin Count `[9:0]` = 32 |
| `0x004` | `GPIO_CFG` | 2-bit | RW | `0x0000_0000` | Global Config (`pin_lvl_intrpt_mode` `[0]`, `glbl_intrpt_mode` `[1]`) |
| `0x008` | `GPIO_GPIO_MODE_0` | 32-bit | RW | `0x0000_0000` | Pin mode for GPIO 0–15 (2 bits/pin: 0=In, 1=PushPull, 2=OpenDrain0, 3=OpenDrain1) |
| `0x00C` | `GPIO_GPIO_MODE_1` | 32-bit | RW | `0x0000_0000` | Pin mode for GPIO 16–31 (2 bits/pin) |
| `0x080` | `GPIO_GPIO_EN` | 32-bit | RW | `0x0000_0000` | Input sampling enable mask for pads `[31:0]` |
| `0x100` | `GPIO_GPIO_IN` | 32-bit | RO | Live pins | Synchronized input state of GPIO pins `[31:0]` |
| `0x180` | `GPIO_GPIO_OUT` | 32-bit | RW | `0x0000_0000` | Direct output register for GPIO pins `[31:0]` |
| `0x200` | `GPIO_GPIO_SET` | 32-bit | WO | `0x0000_0000` | Atomic bit set: write 1 to set corresponding bits in `GPIO_OUT` (reads 0) |
| `0x280` | `GPIO_GPIO_CLEAR` | 32-bit | WO | `0x0000_0000` | Atomic bit clear: write 1 to clear corresponding bits in `GPIO_OUT` (reads 0) |
| `0x300` | `GPIO_GPIO_TOGGLE` | 32-bit | WO | `0x0000_0000` | Atomic bit toggle: write 1 to invert corresponding bits in `GPIO_OUT` (reads 0) |
| `0x380` | `GPIO_INTRPT_RISE_EN` | 32-bit | RW | `0x0000_0000` | Rising edge interrupt enable mask `[31:0]` |
| `0x400` | `GPIO_INTRPT_FALL_EN` | 32-bit | RW | `0x0000_0000` | Falling edge interrupt enable mask `[31:0]` |
| `0x480` | `GPIO_INTRPT_LVL_HIGH_EN` | 32-bit | RW | `0x0000_0000` | High level interrupt enable mask `[31:0]` |
| `0x500` | `GPIO_INTRPT_LVL_LOW_EN` | 32-bit | RW | `0x0000_0000` | Low level interrupt enable mask `[31:0]` |
| `0x580` | `GPIO_INTRPT_STATUS` | 32-bit | W1C | `0x0000_0000` | Aggregated interrupt status `[31:0]` (write 1 to clear) |
| `0x600` | `GPIO_INTRPT_RISE_STATUS` | 32-bit | W1C | `0x0000_0000` | Rising edge interrupt status `[31:0]` (write 1 to clear) |
| `0x680` | `GPIO_INTRPT_FALL_STATUS` | 32-bit | W1C | `0x0000_0000` | Falling edge interrupt status `[31:0]` (write 1 to clear) |
| `0x700` | `GPIO_INTRPT_LVL_HIGH_STATUS`| 32-bit | W1C | `0x0000_0000` | High level interrupt status `[31:0]` (write 1 to clear) |
| `0x780` | `GPIO_INTRPT_LVL_LOW_STATUS` | 32-bit | W1C | `0x0000_0000` | Low level interrupt status `[31:0]` (write 1 to clear) |

### 3.4 SPI Controller (Base: `0x4000_6000`)
| Offset | Register Name | Width | Access | Reset Value | Description |
| :---: | :--- | :---: | :---: | :---: | :--- |
| `0x1C` | `SPI_GIER` | 32-bit | RW | `0x0000_0000` | Global Interrupt Enable Register (bit 31: GIE) |
| `0x20` | `SPI_ISR` | 32-bit | W1C/toggle | `0x0000_0000` | Interrupt Status Register |
| `0x28` | `SPI_IER` | 32-bit | RW | `0x0000_0000` | Interrupt Enable Register |
| `0x30` | `SPI_RCLK` | 3-bit (`[2:0]`) | RW | `0x0000_0004` | Ratio Clock Prescaler Register (system clock to SCK divider ratio) |
| `0x40` | `SPI_SRR` | 32-bit | WO | `0x0000_0000` | Software Reset Register (write `0x0000_000A` to trigger soft reset) |
| `0x60` | `SPI_CR` | 32-bit | RW | `0x0000_0180` | Control: LSB 1st `[9]`, RX FIFO rst `[6]`, TX FIFO rst `[5]`, CPHA `[4]`, CPOL `[3]`, Master `[2]`, Enable `[1]` |
| `0x64` | `SPI_SR` | 32-bit | RO | `0x0000_00A5` | Status: SMOD `[5]`, MODF `[4]`, TX Full `[3]`, TX Empty `[2]`, RX Full `[1]`, RX Empty `[0]` |
| `0x68` | `SPI_DTR` | 8-bit (`[7:0]`) | WO | `0x0000_0000` | Data Transmit Register (pushes byte into TX FIFO) |
| `0x6C` | `SPI_DRR` | 8-bit (`[7:0]`) | RO | `0x0000_0000` | Data Receive Register (pops byte from RX FIFO) |
| `0x70` | `SPI_SSR` | 32-bit | RW | `0xFFFF_FFFF` | Slave Select Register (bit 0: active-low slave select) |
| `0x74` | `SPI_TFOR` | 32-bit | RO | `0x0000_0000` | TX FIFO Occupancy Register |
| `0x78` | `SPI_RFOR` | 32-bit | RO | `0x0000_0000` | RX FIFO Occupancy Register |

### 3.5 Seven-Segment Controller (Base: `0x4000_8000`)
| Offset | Register Name | Width | Access | Reset Value | Description |
| :---: | :--- | :---: | :---: | :---: | :--- |
| `0x00` | `SEG_DATA` | 32-bit | RW | `0x0000_0000` | 8 nibbles: digit $n$ in bits `[4n+3:4n]`. Digit 0 = bits `[3:0]` |
| `0x04` | `SEG_CTRL` | 16-bit | RW | `0x0000_FF06` | Enable `[0]`, SEG polarity `[1]`, AN polarity `[2]`, Digit mask `[15:8]` (FF = all 8 digits enabled) |
| `0x08` | `SEG_DP` | 8-bit (`[7:0]`) | RW | `0x0000_0000` | Decimal point enable mask per digit (bit $n$ controls DP on digit $n$) |
| `0x0C` | `SEG_REFRESH_DIV` | 16-bit | RW | `0x0000_03E8` | Clock divider for multiplexed digit scanning (default: 1000 cycles) |

### 3.6 PWM Generator (Base: `0x4000_A000`)
| Offset | Register Name | Width | Access | Reset Value | Description |
| :---: | :--- | :---: | :---: | :---: | :--- |
| `0x00` | `slv_reg0` / `PWM_DUTY` | 32-bit (`[7:0]` duty) | RW | `0x0000_0000` | 8-bit duty cycle (`pwm_counter < duty_cycle`). Base period = 256 cycles. |
| `0x04` | `slv_reg1` | 32-bit | RW | `0x0000_0000` | General-purpose read/write scratch register |
| `0x08` | `slv_reg2` | 32-bit | RW | `0x0000_0000` | General-purpose read/write scratch register |
| `0x0C` | `slv_reg3` | 32-bit | RW | `0x0000_0000` | General-purpose read/write scratch register |

---

## 4. Directory Structure

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
├── main1.hex                              # 6-peripheral MMIO simulation trace file
├── filelist.f                             # Unified RTL simulation filelist
└── README.md                              # This file
```

---

## Verification Status

The test suites below have **not been re-run since the IP integration** (Seven-Segment replaced I2C on M04; DMA removed).
No simulation results are claimed for this version. `tb/soc_uvm/` and the I2C VIP still contain legacy I2C code and are not yet ported.
Results will be added here with tool, date and log link once re-run.

## 5. Verification Suites in `tb/`

### 5.1 Directed SoC Testbench (`tb/tb_smart_controlsoc_top.sv`)
Executes the 73-transaction `main1.hex` trace by default, and optional directed tests 1–12 via `+RUN_ALL_TESTS`:
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

### 5.2 SoC-Level UVM Verification (`tb/soc_uvm/`)
* `soc_test`: Default integration smoke test.
* `uart_connectivity_test`: UART MMIO and loopback verification.
* `gpio_test`: GPIO MMIO and pin sampling verification.
* `spi_test`: SPI transfer and register verification.
* `pwm_test`: PWM duty cycle verification.

### 5.3 Standalone UVM Testbenches (`tb/uvm/`)
* **Seven-Segment Display (`tb/uvm/seg7/`):** `seg7_base_test`, `seg7_hex_display_test`, `seg7_scan_mask_test`, `seg7_polarity_test`, `seg7_dp_control_test`, `seg7_refresh_boundary_test`, `seg7_full_hex_sweep_test`.
* **PWM Generator (`tb/uvm/pwm/`):** `pwm_base_test`, `pwm_duty_cycle_test`, `pwm_period_test`, `pwm_random_test`.
* **SPI Controller (`tb/uvm/spi/`):** `spi_base_test`, `spi_loopback_test`, `spi_fifo_threshold_test`, `spi_mode_transfer_test`, `spi_interrupt_test`, `spi_random_test`.
* **Alternative SoC Suite (`tb/uvm/soc/`):** `soc_base_test`, `soc_reg_access_test`, `soc_peripheral_concurrent_test`.

---

## 6. Simulation Commands

### 6.1 Running Standalone Unit Tests (Icarus Verilog)
```bash
# Run UART Controller unit testbench (20 tests)
iverilog -g2012 -Irtl/uart_directory/include rtl/uart_directory/rtl/*.v rtl/uart_directory/tb/tb_axi_uart_top.v -o sim_uart && vvp ./sim_uart

# Run Seven-Segment unit testbench (41 tests)
vvp ./sim_seg7

# Run SPI Master unit testbench (119 tests)
vvp ./sim_spi

# Run PWM Generator unit testbench (28 tests)
vvp ./sim_pwm
```

### 6.2 Running Host-Native C Firmware Check
```bash
gcc -DSIMULATION_HOST -Isw sw/main1.c -o sim_main1
./sim_main1
```

### 6.3 Running UVM Simulations (Synopsys VCS / QuestaSim)
```bash
# Standalone PWM UVM Environment
./run_pwm_uvm.sh pwm_random_test

# Standalone SPI UVM Environment
./run_spi_uvm.sh spi_random_test

# Standalone SEG7 UVM Environment
./run_seg7_uvm.sh seg7_random_test

# SoC-Level System UVM Environment
./run_soc_uvm.sh soc_all_periph_test
```

### 6.4 Experimental VeeR EL2 Synthesizable Branch (Deferred / Not Dynamically Verified)
> [!NOTE]
> The authoritative project implementation is the BFM-based SoC (`smart_controlsoc_top`). Full synthesizable core integration is an exploratory branch (`smart_controlsoc_veer_top`) deferred from the current milestone and classified as **EXPERIMENTAL / IMPLEMENTED / NOT DYNAMICALLY VERIFIED**. All peripheral verification remains anchored to `smart_controlsoc_top`.
