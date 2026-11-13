# RISC-V VeeR EL2 Based Smart Peripheral Control SoC

![SoC Architecture](doc/AXI4-Lite%20Smart%20Peripheral%20SoC%20Block%20Diagram.png)

[![ISA](https://img.shields.io/badge/ISA-RISC--V%20RV32IMC-blue.svg)](#)
[![Interconnect](https://img.shields.io/badge/Interconnect-AXI4--Lite%20(2x6)-orange.svg)](#)
[![Verification](https://img.shields.io/badge/Simulation-Synopsys%20VCS%20%2F%20Verdi%20%2F%20Icarus-purple.svg)](#)
[![Status](https://img.shields.io/badge/Project%20Status-Verified%20Integration-brightgreen.svg)](#)

---

## 1. Executive Summary & Project Overview

The **RISC-V VeeR EL2 Based Smart Peripheral Control SoC** (`smart_controlsoc_top`) is a modular, high-performance, peripheral-oriented System-on-Chip (SoC) designed for real-time motor control, embedded monitoring, and multi-protocol industrial hardware interfacing.

At the core of the SoC is the Western Digital / CHIPS Alliance **VeeR EL2**, a dual-issue, 4-stage pipelined 32-bit RISC-V processor supporting the **RV32IMC** instruction set architecture. Instruction and data memory accesses execute deterministically via tightly-coupled memories (ICCM for instructions and DCCM for data), while peripheral memory-mapped I/O (MMIO) is serviced across a high-speed **AXI4-Lite 2x6 Shared Interconnect**.

### Key Architectural Highlights
* **Processing Core:** 32-bit RISC-V VeeR EL2 (RV32IMC) core with Load-Store Unit (LSU) driving AXI4-Lite master port `S00`. Interconnect slave master port `S01` is cleanly tied off.
* **Bus Interconnect:** 2-Master $\times$ 6-Slave AXI4-Lite Crossbar Interconnect (`axi_interconnect_wrap_2x6`) featuring round-robin arbitration, independent address decoders, and strict slave isolation.
* **Integrated Peripherals (6 Slaves):**
  1. **UART (`M00`, `0x4000_0000`):** 16550-compatible serial UART with programmable baud rate generator and FIFO buffering.
  2. **Hardware Timer (`M01`, `0x4000_4000`):** 64-bit real-time counter (`mtime`) with 64-bit comparator (`mtimecmp`), configurable prescaler, and interrupt generation.
  3. **GPIO Controller (`M02`, `0x4000_2000`):** 32-bit bidirectional I/O based on OpenTitan with 2-stage input synchronizers, atomic bit operations (`SET`, `CLEAR`, `TOGGLE`), and edge/level interrupt generation.
  4. **SPI Controller (`M03`, `0x4000_6000`):** Master-mode SPI controller supporting Mode 0 (CPOL=0, CPHA=0), 32-deep TX/RX FIFOs, and programmable clock ratio dividers.
  5. **Seven-Segment Display Controller (`M04`, `0x4000_8000`):** 8-digit multiplexed hexadecimal display driver with programmable scan refresh divider, blanking mask, and decimal point support.
  6. **PWM Generator (`M05`, `0x4000_A000`):** 8-bit duty-cycle motor drive generator with 256-cycle base period for precision speed and power regulation.
* **Architectural Simplification:** Direct Memory Access (DMA) and I2C controllers have been completely excised from the SoC RTL, interconnect decoders, and active filelists, with M04 dedicated to the Seven-Segment Controller (`axi_seg7_top`).
* **Multi-Tiered Verification:** Standalone unit testbenches (Icarus Verilog), standalone IEEE 1800.2 UVM test environments for PWM, SPI, and SEG7, SoC-level UVM integration environment, directed AXI SV testbench (`tb_smart_controlsoc_top.sv`), host-compiled firmware verification, and bare-metal RISC-V GCC firmware compilation.

---

## 2. System Architecture & Interconnect Topology

```
+---------------------------------------------------------------------------------------------------------------+
|                                             SMART CONTROLSOC TOP                                              |
|                                                                                                               |
|  +--------------------+         +--------------------------------------------------------------------------+  |
|  |  RISC-V VeeR EL2   |  (S00)  |                                AXI4-Lite                                 |  |
|  |     CPU (LSU)      | =======>|                            Interconnect (2x6)                            |  |
|  +--------------------+         +--------------------------------------------------------------------------+  |
|                                        ||          ||          ||          ||          ||          ||         |
|  +--------------------+  (S01)         || (M00)    || (M01)    || (M02)    || (M03)    || (M04)    || (M05)   |
|  |     [Tied Off]     | =======>       \/          \/          \/          \/          \/          \/         |
|  |   (Zero Driven)    |         +----------++----------++----------++----------++----------++----------+      |
|  +--------------------+         | AXI UART || AXI Timer|| AXI GPIO || AXI SPI  || AXI SEG7 || AXI PWM  |      |
|                                 +----------++----------++----------++----------++----------++----------+      |
|                                      ||          ||          ||          ||          ||          ||           |
+--------------------------------------||----------||----------||----------||----------||----------||-----------+
                                       \/          \/          \/          \/          \/          \/
                                    [Serial]   [Timer IRQ] [32x GPIO]   [SPI Bus]  [7-Seg Bus]  [PWM Pin]
```

### Interconnect Port Mapping & Decoding

| Master Port | Source Master | Functional Role |
| :---: | :--- | :--- |
| `S00` | RISC-V VeeR EL2 LSU | Primary CPU MMIO master interface |
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
| Offset | Register Name | Access | Description |
| :---: | :--- | :---: | :--- |
| `0x00` | `UART_RBR` / `UART_THR` | R / W | Receiver Buffer Register / Transmitter Holding Register |
| `0x04` | `UART_IER` | R/W | Interrupt Enable Register |
| `0x08` | `UART_BAUD_DIV` | R/W | Baud Rate Divisor Generator Register (e.g., 40 cycles/bit) |
| `0x0C` | `UART_LCR` | R/W | Line Control Register (DLAB, Parity, Stop Bits, Word Length) |
| `0x14` | `UART_LSR` | R | Line Status Register (Bit 0: Data Ready, Bit 5: TX Empty) |

### 3.2 Hardware Timer (Base: `0x4000_4000`)
| Offset | Register Name | Access | Description |
| :---: | :--- | :---: | :--- |
| `0x000` | `ALERT_TEST` | WO | Alert test register (Write 1 to trigger alert test event) |
| `0x004` | `TIMER_CTRL` | R/W | Timer Control (Bit 0: `active` counter enable) |
| `0x100` | `TIMER_INTR_ENABLE0` | R/W | Timer Interrupt Enable Mask (Bit 0: Enable interrupt on compare match) |
| `0x104` | `TIMER_INTR_STATE0` | W1C | Timer Interrupt Status (Bit 0: Interrupt pending flag; write 1 to clear) |
| `0x108` | `TIMER_INTR_TEST0` | WO | Software Interrupt Test Force (Bit 0: Force interrupt for testing) |
| `0x10C` | `TIMER_CFG0` | R/W | Timer Configuration (Bits [11:0]: Prescaler, Bits [23:16]: Step Value) |
| `0x110` | `TIMER_V_LOWER0` | R/W | 64-bit Real-Time Counter `mtime` [31:0] |
| `0x114` | `TIMER_V_UPPER0` | R/W | 64-bit Real-Time Counter `mtime` [63:32] |
| `0x118` | `TIMER_COMPARE_LOWER0`| R/W | 64-bit Compare Threshold `mtimecmp` [31:0] |
| `0x11C` | `TIMER_COMPARE_UPPER0`| R/W | 64-bit Compare Threshold `mtimecmp` [63:32] |

### 3.3 GPIO Controller (Base: `0x4000_2000`)
| Offset | Register Name | Access | Description |
| :---: | :--- | :---: | :--- |
| `0x000` | `GPIO_INFO` | RO | Hardware Version (Bits 19:10 = 2) & Pin Count (Bits 9:0 = 32) -> `0x0000_0820` |
| `0x004` | `GPIO_CFG` | R/W | Global Configuration (Bit 0: Global Interrupt Mode, Bit 1: Pin Sticky Mode) |
| `0x008` | `GPIO_MODE_0` | R/W | IO Mode for Pins 0–15 (2 bits/pin: 0=Input, 1=Push-Pull, 2=OpenDrain0, 3=OpenDrain1) |
| `0x00C` | `GPIO_MODE_1` | R/W | IO Mode for Pins 16–31 (2 bits/pin) |
| `0x080` | `GPIO_EN` | R/W | Input Sampling Enable Mask for Pins 0–31 (1 = Sample Enabled) |
| `0x100` | `GPIO_IN` | RO | Synchronized Pin Input State Read Register |
| `0x180` | `GPIO_OUT` | R/W | Direct Output State Register |
| `0x200` | `GPIO_SET` | WO | Atomic Output Bit Set Register (Write 1 to set corresponding pin) |
| `0x280` | `GPIO_CLEAR` | WO | Atomic Output Bit Clear Register (Write 1 to clear corresponding pin) |
| `0x300` | `GPIO_TOGGLE` | WO | Atomic Output Bit Toggle Register (Write 1 to invert corresponding pin) |
| `0x380` | `GPIO_INTRPT_RISE_EN` | R/W | Rising Edge Interrupt Enable Mask |
| `0x400` | `GPIO_INTRPT_FALL_EN` | R/W | Falling Edge Interrupt Enable Mask |
| `0x480` | `GPIO_INTRPT_LVL_HIGH_EN` | R/W | Level-Sensitive High Interrupt Enable Mask |
| `0x500` | `GPIO_INTRPT_LVL_LOW_EN` | R/W | Level-Sensitive Low Interrupt Enable Mask |
| `0x580` | `GPIO_INTRPT_STATUS` | W1C | Aggregated Interrupt Status Register (Write 1 to clear) |

### 3.4 SPI Controller (Base: `0x4000_6000`)
| Offset | Register Name | Access | Reset Value | Description |
| :---: | :--- | :---: | :---: | :--- |
| `0x1C` | `SPI_GIER` | R/W | `0x0000_0000` | Global Interrupt Enable Register (Bit 31: Global Enable) |
| `0x20` | `SPI_ISR` | R/W1C | `0x0000_0000` | Interrupt Status Register |
| `0x28` | `SPI_IER` | R/W | `0x0000_0000` | Interrupt Enable Register |
| `0x30` | `SPI_RCLK` | R/W | `0x0000_0004` | Clock ratio register (divider between system clock and SPI SCK) |
| `0x40` | `SPI_SRR` | WO | `0x0000_0000` | Software Reset Register (write `0x0000_000A` to reset core) |
| `0x60` | `SPI_CR` | R/W | `0x0000_0180` | Control Register (Master Mode, Enable, Mode 0: CPOL=0, CPHA=0) |
| `0x64` | `SPI_SR` | RO | `0x0000_00A5` | Status Register (TX/RX FIFO Empty and Full Flags) |
| `0x68` | `SPI_DTR` | WO | `0x0000_0000` | Data Transmit Register (Pushes byte into TX FIFO) |
| `0x6C` | `SPI_DRR` | RO | `0x0000_0000` | Data Receive Register (Pops byte from RX FIFO) |
| `0x70` | `SPI_SSR` | R/W | `0xFFFF_FFFF` | Slave Select Register (active-low chip select) |

### 3.5 Seven-Segment Controller (Base: `0x4000_8000`)
| Offset | Register Name | Access | Reset Value | Description |
| :---: | :--- | :---: | :---: | :--- |
| `0x00` | `SEG_DATA` | R/W | `0x0000_0000` | 8 nibbles. Digit $n$ is stored in bits $[4n+3:4n]$. Digit 0 = $[3:0]$ |
| `0x04` | `SEG_CTRL` | R/W | `0x0000_FF06` | Display control: [0] EN, [1] SEG_ACTIVE_LOW, [2] AN_ACTIVE_LOW, [15:8] DIGIT_MASK |
| `0x08` | `SEG_DP` | R/W | `0x0000_0000` | Decimal point enable mask per digit (1 = DP active) |
| `0x0C` | `SEG_REFRESH_DIV` | R/W | `0x0000_03E8` | 16-bit clock divisor for digit multiplex scan rate (default: 1000 clocks) |

### 3.6 PWM Generator (Base: `0x4000_A000`)
| Offset | Register Name | Access | Reset Value | Description |
| :---: | :--- | :---: | :---: | :--- |
| `0x00` | `PWM_DUTY_REG` | R/W | `0x0000_0000` | 8-bit duty cycle register (`pwm_counter < duty_cycle`). `0x00` = 0%, `0x80` = 50%, `0xFF` = 255/256 (99.6%) |

---

## 4. Directory Structure

```
Smart_Motor_Control_SoC/
├── doc/                                   # Specifications, test plans, and architectural status
│   ├── spec/                              # Peripheral and memory map specifications
│   │   ├── memory_map_final.md            # Final authoritative memory map
│   │   └── seg7_spec.md                   # Seven-Segment controller specification
│   ├── Smart_ControlSoC_Testplan.csv      # Complete 29-test verification test plan
│   ├── PROJECT_EXECUTION_STATUS.md        # Autonomous phase execution status
│   └── FINAL_PROJECT_STATUS.md            # Final comprehensive project report
├── rtl/
│   ├── Cores-VeeR-EL2/                    # RISC-V VeeR EL2 core repository & BFM wrapper
│   ├── interconnect/                      # AXI4-Lite 2x6 Crossbar Interconnect
│   ├── uart_directory/                    # AXI4-Lite UART IP Core (Port M00)
│   ├── timer_directory/                   # 64-bit Hardware Timer IP Core (Port M01)
│   ├── gpio_directory/                    # OpenTitan Bidirectional GPIO IP Core (Port M02)
│   ├── spi_directory/                     # AXI4-Lite SPI Master IP Core (Port M03)
│   ├── seg7_directory/                    # Seven-Segment Display Controller IP Core (Port M04)
│   ├── pwm_directory/                     # AXI4-Lite PWM Generator IP Core (Port M05)
│   └── smart_controlsoc_top.v             # Top-Level SoC Integration Module
├── sw/                                    # Bare-metal C software stack and drivers
│   ├── app/
│   │   └── main.c                         # Top-level SoC firmware application
│   ├── bsp/
│   │   ├── link.ld                        # RISC-V bare-metal linker script
│   │   └── startup.S                      # Boot assembly, trap vectors, stack setup
│   ├── drivers/                           # Modular peripheral drivers
│   │   ├── gpio.h / gpio.c
│   │   ├── pwm.h / pwm.c
│   │   ├── seg7.h / seg7.c
│   │   ├── spi.h / spi.c
│   │   ├── timer.h / timer.c
│   │   └── uart.h / uart.c
│   ├── Makefile                           # Automated GCC compilation pipeline
│   ├── soc_memory_map.h                   # C MMIO header definitions
│   └── main1.c                            # 8-suite host & simulation verification test
├── tb/
│   ├── uvm/                               # UVM Verification Environments
│   │   ├── common/axi_lite/               # Common reusable AXI4-Lite Master VIP
│   │   ├── pwm/                           # Standalone PWM UVM environment (13 tests)
│   │   ├── spi/                           # Standalone SPI UVM environment (13 tests)
│   │   ├── seg7/                          # Standalone SEG7 UVM environment (8 tests)
│   │   └── soc/                           # System-Level SoC UVM environment (11 tests)
│   ├── seg7.vip_uvm_tb/                   # Original SEG7 UVM testbench
│   └── tb_smart_controlsoc_top.sv         # System-Level Directed Verification Testbench (Tests 1–12)
├── main1.hex                              # 6-peripheral MMIO simulation trace file
├── filelist.f                             # Unified RTL simulation filelist
├── run_regression.sh                      # Master regression test runner
├── run_soc_uvm.sh                         # SoC UVM runner
├── run_seg7_uvm.sh                        # SEG7 UVM runner
├── run_pwm_uvm.sh                         # PWM UVM runner
├── run_spi_uvm.sh                         # SPI UVM runner
└── README.md                              # This file
```

---

## 5. Verification Framework & Methodology

The verification strategy follows a hierarchical multi-tier approach:

```
[Tier 1: Standalone Unit RTL]  ==>  Icarus Verilog testbenches (sim_seg7, sim_spi, sim_pwm: 188 PASS)
[Tier 2: Standalone UVM VIP]   ==>  IEEE 1800.2 UVM environments for PWM, SPI, and SEG7
[Tier 3: SoC-Level UVM]        ==>  Virtual sequences orchestrating multi-peripheral scenarios
[Tier 4: Directed SoC SV]      ==>  tb_smart_controlsoc_top.sv streaming main1.hex and Tests 1–12
[Tier 5: Bare-Metal Firmware]  ==>  RISC-V GCC compiled ELF/HEX executed on VeeR EL2
```

### 5.1 Directed SoC Testbench Tests (`tb_smart_controlsoc_top.sv`)
* **TEST 1:** Reset and default pin state verification across all peripherals.
* **TEST 2:** UART Baud rate divisor and Line Control Register configuration.
* **TEST 3:** UART single character transmission and baud timing capture.
* **TEST 4:** UART multi-byte burst transmission (`"RISCV"` string).
* **TEST 5:** UART external RX injection and interrupt assertion / clearing.
* **TEST 6:** UART full-duplex simultaneous transmit and receive operation.
* **TEST 7:** SPI Controller reset, Mode 0 configuration, and transmission verification.
* **TEST 8:** PWM Generator duty cycle programming (50%) and pin toggle verification.
* **TEST 9:** Seven-Segment Display Controller MMIO read/write and scan multiplex verification.
* **TEST 10:** GPIO direct output, atomic set/clear/toggle, input sampling, and edge interrupt test.
* **TEST 11:** 64-bit Hardware Timer prescaler, counter progression, compare interrupt, and W1C test.
* **TEST 12:** Concurrent Multi-Peripheral Stress Test (interleaved access across all 6 peripherals).

---

## 6. Simulation & Build Commands

### 6.1 Building the Bare-Metal RISC-V Firmware
```bash
# Build firmware ELF, BIN, HEX, and assembly disassembly
make -C sw

# Clean firmware artifacts
make -C sw clean
```

### 6.2 Running Standalone Unit Tests (Icarus Verilog)
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

### 6.3 Running Host-Native C Firmware Check
```bash
gcc -DSIMULATION_HOST -Isw sw/main1.c -o sim_main1
./sim_main1
```

### 6.4 Running Master Regression Suite
```bash
# Execute full automated regression suite across all available tools
chmod +x ./run_regression.sh
./run_regression.sh
```

### 6.5 Running UVM Simulations (Synopsys VCS / Questa)
```bash
# Standalone PWM UVM Environment (13 tests available)
./run_pwm_uvm.sh pwm_random_test

# Standalone SPI UVM Environment (13 tests available)
./run_spi_uvm.sh spi_random_test

# Standalone SEG7 UVM Environment (8 tests available)
./run_seg7_uvm.sh seg7_random_test

# SoC-Level System UVM Environment (11 tests available)
./run_soc_uvm.sh soc_all_periph_test
```

### 6.6 Experimental VeeR EL2 Core Integration Branch (Deferred / Not Dynamically Verified)
> [!NOTE]
> The authoritative project implementation is the BFM-based SoC (`smart_controlsoc_top`). Full synthesizable core integration is an exploratory branch (`smart_controlsoc_veer_top`) deferred from the current milestone and classified as **EXPERIMENTAL / IMPLEMENTED / NOT DYNAMICALLY VERIFIED**. All peripheral verification remains anchored to `smart_controlsoc_top`.

```bash
# Compile bare-metal firmware targeting VeeR EL2 reset vector 0xEE00_0000 (Experimental)
make -C sw veer

# Run Verilator lint check on synthesizable LSU width adapter
verilator --lint-only -Wall rtl/interconnect/axi_lsu_dwidth_adapter.v
```

