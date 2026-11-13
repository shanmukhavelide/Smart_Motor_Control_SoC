# Design and Verification of a Complete RTL-Based RISC-V System-on-Chip (SoC)
### *Smart Peripheral & Motor Control System-on-Chip (Smart ControlSoC)*

![SoC Architecture](doc/AXI4-Lite%20Smart%20Peripheral%20SoC%20Block%20Diagram.png)

[![ISA](https://img.shields.io/badge/ISA-RISC--V%20RV32IM-blue.svg)](#)
[![Interconnect](https://img.shields.io/badge/Interconnect-AXI4--Lite%20(2x6)-orange.svg)](#)
[![Simulation](https://img.shields.io/badge/Simulation-Icarus%20%7C%20VCS%20%7C%20Questa-purple.svg)](#)
[![Firmware](https://img.shields.io/badge/Firmware-Bare--Metal%20C%20(GCC)-green.svg)](#)
[![Status](https://img.shields.io/badge/Project%20Status-Front--End%20Integration%20Complete-brightgreen.svg)](#)

---

## 1. Project Abstract & Problem Statement

### 1.1 Problem Statement
Modern embedded systems increasingly require the integration of processing, memory, communication, timing, and control functionalities within a single System-on-Chip (SoC). Designing such a system provides an understanding of processor integration, RTL design, memory interfacing, bus communication, peripheral control, and hardware-software interaction. 

The primary objective of this project is to **design and verify a complete RTL-based System-on-Chip using the provided RISC-V processor as the central processing unit**.

### 1.2 Proposed SoC Architecture
The SoC integrates the provided RISC-V processor core with **instruction memory**, **data memory**, a **2-Master $\times$ 6-Slave AXI4-Lite bus interconnect**, and a complete set of mandatory and additional peripheral IP blocks. A structured memory map allows the processor to access memories and peripherals through defined 32-bit address locations.

The complete system incorporates a bare-metal software application stack that executes on the RISC-V processor, initializing, controlling, and coordinating all integrated peripheral IP blocks under a unified clock and reset domain.

### 1.3 Selected IP Inventory

| Classification | IP Block | Functionality & Role |
| :--- | :--- | :--- |
| **Mandatory** | **RISC-V Processor** | Western Digital / CHIPS Alliance **VeeR EL2** 32-bit core (RV32IM, dual-issue 4-stage pipeline, provided by faculty) |
| **Mandatory** | **Instruction Memory (ICCM)** | Closely coupled instruction memory storing firmware executed by the processor (`0xEE00_0000`, 64 KB, 7-bit ECC) |
| **Mandatory** | **Data Memory (DCCM)** | Closely coupled data memory for stack, heap, and application data during execution (`0xF004_0000`, 64 KB, 7-bit ECC) |
| **Mandatory** | **Bus Interconnect** | 2-Master $\times$ 6-Slave AXI4-Lite crossbar (`axi_interconnect_wrap_2x6`) with round-robin arbitration and address decoding |
| **Mandatory** | **UART Controller** | 16550-style serial communication interface with 32-deep FIFOs for system telemetry and console output |
| **Mandatory** | **Hardware Timer** | 64-bit real-time counter (`mtime`) and comparator (`mtimecmp`) with programmable prescaler and interrupt generation |
| **Mandatory** | **GPIO Controller** | 32-bit bidirectional digital I/O based on OpenTitan `reg_bus` with atomic bit manipulation (`SET`, `CLEAR`, `TOGGLE`) |
| **Additional** | **SPI Master Controller** | Full-duplex synchronous serial peripheral communication interface (Mode 0) with 32-deep TX/RX FIFOs |
| **Additional** | **PWM Generator** | 8-bit precision motor drive generator with 256-cycle base period for digital speed, torque, and power control |
| **Additional** | **Seven-Segment Controller** | 8-digit multiplexed 7-segment display driver with glyph decoding, scan rate divider, blanking, and decimal point support |

> [!NOTE]
> **Excised Legacy IPs:** Direct Memory Access (DMA), legacy I2C, and standalone AES controllers have been completely excised from the active SoC interconnect, top-level RTL, and simulation filelists. Port `M04` (`0x4000_8000`) is dedicated to the Seven-Segment Display Controller.

---

## 2. System Architecture & Interconnect Topology

```
+-----------------------------------------------------------------------------------------------------------------------+
|                                                 SMART CONTROLSOC TOP                                                  |
|                                                                                                                       |
|  +--------------------------+         +----------------------------------------------------------------------------+  |
|  |     RISC-V VeeR EL2      |  (S00)  |                                 AXI4-Lite                                  |  |
|  |    CPU Subsystem (LSU)   | =======>|                             Interconnect (2x6)                             |  |
|  +--------------------------+         +----------------------------------------------------------------------------+  |
|   | ICCM (64KB) | DCCM (64KB)                ||          ||          ||          ||          ||          ||           |
|                                (S01)         || (M00)    || (M01)    || (M02)    || (M03)    || (M04)    || (M05)     |
|  +--------------------------+  =====>        \/          \/          \/          \/          \/          \/           |
|  |   [Tied Off Master S01]  | (Zero)  +----------++----------++----------++----------++----------++----------+        |
|  +--------------------------+         | AXI UART || AXI Timer|| AXI GPIO || AXI SPI  || AXI Seg7 || AXI PWM  |        |
|                                       +----------++----------++----------++----------++----------++----------+        |
|                                            ||          ||          ||          ||          ||          ||             |
+--------------------------------------------||----------||----------||----------||----------||----------||-------------+
                                             \/          \/          \/          \/          \/          \/
                                          [Serial]   [Timer IRQ] [32x GPIO]   [SPI Bus]  [7-Seg Bus]  [PWM Pin]
```

### 2.1 Implementation Methodology
To ensure rigorous validation and engineering modularity, the project provides two synchronized top-level implementations:
1. **Authoritative Verification SoC (`smart_controlsoc_top.v`):** Integrates the 6 peripherals and AXI crossbar with the CPU BFM wrapper (`el2_veer_wrapper.v`). This environment allows deterministic bus-level verification, corner-case MMIO testing, and standalone testbench compatibility without processor pipeline nondeterminism.
2. **Synthesizable Full-Processor SoC (`smart_controlsoc_veer_top.v`):** Directly instantiates the synthesizable RISC-V VeeR EL2 core (`el2_veer`), 64 KB ICCM instruction memory, 64 KB DCCM data memory (`veer_mem_subsystem.sv`), 64-to-32 bit LSU bus width adapter (`axi_lsu_dwidth_adapter.v`), 2x6 crossbar interconnect, and all 6 peripherals.

### 2.2 Complete SoC Memory Map

| Subsystem | Port | Top Module | Base Address | Address Range | Decoded Size | Access |
| :--- | :---: | :--- | :---: | :---: | :---: | :---: |
| **Instruction Memory (ICCM)** | Internal | `veer_mem_subsystem` | `0xEE00_0000` | `0xEE00_0000` – `0xEE00_FFFF` | 64 KB | R/X |
| **Data Memory (DCCM)** | Internal | `veer_mem_subsystem` | `0xF004_0000` | `0xF004_0000` – `0xF004_FFFF` | 64 KB | R/W |
| **UART Controller** | `M00` | `axi_uart_top` | `0x4000_0000` | `0x4000_0000` – `0x4000_0FFF` | 4 KB | R/W |
| **Hardware Timer** | `M01` | `axi_timer_top` | `0x4000_4000` | `0x4000_4000` – `0x4000_4FFF` | 4 KB | R/W |
| **GPIO Controller** | `M02` | `axi_gpio_top` | `0x4000_2000` | `0x4000_2000` – `0x4000_2FFF` | 4 KB | R/W |
| **SPI Master Controller** | `M03` | `axi_spi_top` | `0x4000_6000` | `0x4000_6000` – `0x4000_6FFF` | 4 KB | R/W |
| **Seven-Segment Display** | `M04` | `axi_seg7_top` | `0x4000_8000` | `0x4000_8000` – `0x4000_8FFF` | 4 KB | R/W |
| **PWM Generator** | `M05` | `myip_v1_0` | `0x4000_A000` | `0x4000_A000` – `0x4000_AFFF` | 4 KB | R/W |

---

## 3. Peripheral Register Specifications

### 3.1 UART Controller (Port `M00`, Base: `0x4000_0000`)
* **Module:** `axi_uart_top` (`rtl/uart_directory/rtl/axi_uart_top.v`)
* **Features:** 32-byte TX/RX FIFOs, baud divisor generator, parity generation/checking, Line Control & Status registers.

| Offset | Register Name | Width | Access | Reset Value | Description |
| :---: | :--- | :---: | :---: | :---: | :--- |
| `0x00` | `UART_RBR` | 8-bit | RO | `0x00` | Receiver Buffer: reads next received byte from RX FIFO (when DLAB=0) |
| `0x00` | `UART_THR` | 8-bit | WO | `0x00` | Transmitter Holding: writes byte to transmit FIFO (when DLAB=0) |
| `0x04` | `UART_IER` | 1-bit (`[0]`) | RW | `0x00` | Interrupt Enable Register (`uart_irq_en_int`, bit 0: RX Data Ready) |
| `0x08` | `UART_BAUD_DIVISOR` | 32-bit | RW | `0x0000_0364` | Baud Rate Divisor (default: 100 MHz / 115200 baud = 868) |
| `0x0C` | `UART_LCR` | 8-bit (`[7:0]`) | RW | `0x00` | Line Control: DLAB `[7]`, Parity Mode `[4]`, Parity En `[3]`, Stop Bits `[2]`, Word Length `[1:0]` |
| `0x14` | `UART_LSR` | 7-bit (`[6:0]`) | RO | Dynamic | Line Status: TEMT (bit 6), THRE (bit 5), Data Ready (bit 0) |

---

### 3.2 64-bit Hardware Timer (Port `M01`, Base: `0x4000_4000`)
* **Module:** `axi_timer_top` (`rtl/timer_directory/rtl/axi_timer_top.sv`)
* **Features:** 64-bit real-time counter (`mtime`), 64-bit comparator (`mtimecmp`), 12-bit prescaler, 8-bit step value, level interrupt output.

| Offset | Register Name | Width | Access | Reset Value | Description |
| :---: | :--- | :---: | :---: | :---: | :--- |
| `0x000` | `REG_ALERT_TEST` | 32-bit | WO | `0x0000_0000` | Alert test event register (reads 0) |
| `0x004` | `REG_CTRL` | 1-bit (`[0]`) | RW | `0x0000_0000` | Timer Control: bit 0 = `ctrl_active` counter enable |
| `0x100` | `REG_INTR_ENABLE0` | 1-bit (`[0]`) | RW | `0x0000_0000` | Interrupt Enable: bit 0 = `intr_enable` |
| `0x104` | `REG_INTR_STATE0` | 1-bit (`[0]`) | W1C | `0x0000_0000` | Interrupt Status: bit 0 = `intr_state` (pending flag, write 1 to clear) |
| `0x108` | `REG_INTR_TEST0` | 1-bit (`[0]`) | WO | `0x0000_0000` | Software Interrupt Force: write 1 to assert `intr_state` (reads 0) |
| `0x10C` | `REG_CFG0` | 24-bit (`[23:0]`) | RW | `0x0001_0000` | Configuration: Prescaler `[11:0]` = 0, Step `[23:16]` = 1 |
| `0x110` | `REG_TIMER_V_LOWER0` | 32-bit | RW | `0x0000_0000` | Counter `mtime` Lower 32 bits `[31:0]` |
| `0x114` | `REG_TIMER_V_UPPER0` | 32-bit | RW | `0x0000_0000` | Counter `mtime` Upper 32 bits `[63:32]` |
| `0x118` | `REG_COMPARE_LOWER0_0`| 32-bit | RW | `0xFFFF_FFFF` | Threshold `mtimecmp` Lower 32 bits `[31:0]` (write clears IRQ) |
| `0x11C` | `REG_COMPARE_UPPER0_0`| 32-bit | RW | `0xFFFF_FFFF` | Threshold `mtimecmp` Upper 32 bits `[63:32]` (write clears IRQ) |

---

### 3.3 32-bit OpenTitan GPIO Controller (Port `M02`, Base: `0x4000_2000`)
* **Module:** `axi_gpio_top` (`rtl/gpio_directory/rtl/axi_gpio_top.sv`)
* **Features:** 32 bidirectional pads, 2-stage input synchronizers, atomic bit manipulation (`SET`, `CLEAR`, `TOGGLE`), 4 pin modes, edge and level interrupts.

| Offset | Register Name | Width | Access | Reset Value | Description |
| :---: | :--- | :---: | :---: | :---: | :--- |
| `0x000` | `GPIO_INFO` | 20-bit | RO | `0x0000_0820` | Version `[19:10]` = 2, Pin Count `[9:0]` = 32 |
| `0x004` | `GPIO_CFG` | 2-bit | RW | `0x0000_0000` | Configuration: `pin_lvl_intrpt_mode` `[0]`, `glbl_intrpt_mode` `[1]` |
| `0x008` | `GPIO_GPIO_MODE_0` | 32-bit | RW | `0x0000_0000` | Pin modes for GPIO 0–15 (2 bits/pin: 0=In, 1=PushPull, 2=OD0, 3=OD1) |
| `0x00C` | `GPIO_GPIO_MODE_1` | 32-bit | RW | `0x0000_0000` | Pin modes for GPIO 16–31 (2 bits/pin) |
| `0x080` | `GPIO_GPIO_EN` | 32-bit | RW | `0x0000_0000` | Input sampling enable mask `[31:0]` |
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
* **Features:** Mode 0 (`CPOL=0`, `CPHA=0`) full-duplex transfers, 32-deep TX/RX FIFOs, ratio clock prescaler, software reset, and FIFO occupancy monitoring.

| Offset | Register Name | Width | Access | Reset Value | Description |
| :---: | :--- | :---: | :---: | :---: | :--- |
| `0x1C` | `SPI_GIER` | 32-bit | RW | `0x0000_0000` | Global Interrupt Enable Register (bit 31: Global Interrupt Enable) |
| `0x20` | `SPI_ISR` | 32-bit | W1C/toggle | `0x0000_0000` | Interrupt Status Register |
| `0x28` | `SPI_IER` | 32-bit | RW | `0x0000_0000` | Interrupt Enable Register |
| `0x30` | `SPI_RCLK` | 3-bit (`[2:0]`) | RW | `0x0000_0004` | Ratio Clock Prescaler: system clock to SCK frequency divider ratio |
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
* **Features:** 8-digit multiplexed Seven-Segment Display Controller (replaces legacy I2C on M04). Internal glyph decoders (0–F), scan refresh clock divider, dynamic blanking digit mask, and decimal point control.

| Offset | Register Name | Width | Access | Reset Value | Description |
| :---: | :--- | :---: | :---: | :---: | :--- |
| `0x00` | `SEG_DATA` | 32-bit | RW | `0x0000_0000` | 8 nibbles: digit $n$ stored in bits `[4n+3:4n]`. Digit 0 = `[3:0]` |
| `0x04` | `SEG_CTRL` | 16-bit | RW | `0x0000_FF06` | Control: Enable `[0]`, SEG active-low `[1]`, AN active-low `[2]`, Digit mask `[15:8]` (FF = all 8 active) |
| `0x08` | `SEG_DP` | 8-bit (`[7:0]`) | RW | `0x0000_0000` | Decimal point mask: bit $n$ controls decimal point on digit $n$ |
| `0x0C` | `SEG_REFRESH_DIV` | 16-bit | RW | `0x0000_03E8` | 16-bit clock divisor for digit scan rate (default: 1000 clock cycles/digit) |

---

### 3.6 8-bit PWM Generator (Port `M05`, Base: `0x4000_A000`)
* **Module:** `myip_v1_0` (`rtl/pwm_directory/rtl/myip_v1_0.v`)
* **Features:** 8-bit pulse-width modulation generator for precision motor speed and torque regulation. Free-running 8-bit counter (0..255) compared strictly (`pwm_counter < duty_cycle`) against duty register. Base period = 256 clock cycles.

| Offset | Register Name | Width | Access | Reset Value | Description |
| :---: | :--- | :---: | :---: | :---: | :--- |
| `0x00` | `slv_reg0` / `PWM_DUTY` | 32-bit (`[7:0]` duty) | RW | `0x0000_0000` | 8-bit duty cycle (`pwm_counter < duty_cycle`). `0x00` = 0%, `0x80` = 50%, `0xFF` = 99.61%. |
| `0x04` | `slv_reg1` | 32-bit | RW | `0x0000_0000` | General-purpose read/write scratch register |
| `0x08` | `slv_reg2` | 32-bit | RW | `0x0000_0000` | General-purpose read/write scratch register |
| `0x0C` | `slv_reg3` | 32-bit | RW | `0x0000_0000` | General-purpose read/write scratch register |

---

## 4. Bare-Metal Software Application

As specified in the project abstract, a complete bare-metal C software application stack is developed to execute on the RISC-V processor and demonstrate the operation of all integrated peripherals.

### 4.1 Application Execution Flow (`sw/app/main.c`)
The firmware application systematically interacts with all six peripherals in a structured sequence:
1. **UART Initialization & Telemetry:** Configures the baud divisor and outputs the startup banner and system diagnostics over serial.
2. **Hardware Timer Activation:** Programs the prescaler and step values, initiating continuous hardware tick tracking.
3. **GPIO Pin Configuration:** Sets up direction masks and outputs initial test patterns to drive connected indicators/actuators.
4. **SPI Communication Test:** Initializes Mode 0 SPI master, asserts chip select, and executes full-duplex byte transfers.
5. **PWM Motor Speed Setup:** Sets initial duty cycle (50%) to demonstrate digital motor speed control.
6. **Seven-Segment Display Setup:** Initializes refresh dividers, unmasks all 8 digits, and writes diagnostic glyph patterns with decimal points.
7. **Coordinated Motor Control & Telemetry Loop:** Continuously modulates PWM motor duty cycles, updates the 7-segment display counter, toggles GPIO status lines, and reports real-time telemetry over UART.

### 4.2 Firmware Compilation Pipeline
The firmware is built using the standard GNU RISC-V bare-metal toolchain (`riscv64-unknown-elf-gcc`):
```bash
# Build firmware ELF, BIN, HEX, and assembly disassembly
make -C sw

# Build firmware targeting synthesizable VeeR EL2 core (ICCM/DCCM)
make -C sw veer
```
* **Output Artifacts:** `sw/build/firmware.elf`, `sw/build/firmware.hex` (Verilog memory hex for `$readmemh`), and `sw/build/firmware.dis` (complete assembly disassembly).

---

## 5. Verification Framework & Status

### 5.1 Verification Status Summary

| Verification Target | Scope & Framework | Status | Evidence & Notes |
| :--- | :--- | :---: | :--- |
| **UART Unit Test** | Standalone Icarus Verilog (`tb_axi_uart_top.v`) | **20/20 PASS** | Full AXI handshake, baud divisor, FIFO streaming, loopback |
| **Host C Driver Test** | Native GCC Test (`sw/main1.c` with `-DSIMULATION_HOST`) | **36/36 PASS** | Exercises modular drivers against complete mock MMIO model |
| **Seven-Segment Unit Test** | Standalone Testbench (`sim_seg7`) | **41/41 Reported** | Glyph decoders, polarities, refresh divider, blanking mask |
| **SPI Master Unit Test** | Standalone Testbench (`sim_spi`) | **119/119 Reported** | Mode 0 transfers, FIFO depths, clock ratio, reset recovery |
| **PWM Generator Unit Test** | Standalone Testbench (`sim_pwm`) | **28/28 Reported** | Duty cycles (0%–99.6%), dynamic sweeps, counter rollover |
| **GPIO Unit Test** | Standalone Testbench (`tb_gpio.sv`) | **Not Verified** | OpenTitan parameter syntax unsupported in local Icarus Verilog |
| **Hardware Timer Unit Test**| Standalone Testbench (`tb_timer.sv`) | **Not Verified** | Unpacked array port elaboration requires commercial SV simulator |
| **Full-SoC Directed Test** | System Testbench (`tb_smart_controlsoc_top.sv`) | **Not Run** | 59-transaction `main1.hex` trace & Tests 1–12; needs full-SoC sim |
| **UVM Test Suites** | Modular UVM (`tb/uvm/`, `tb/soc_uvm/`) | **Blocked** | Syntactically verified; dynamic sim blocked by VCS license server |

### 5.2 System-Level Directed Verification (`tb/tb_smart_controlsoc_top.sv`)
Exercises the full SoC by executing the 59-transaction `main1.hex` trace and optional directed tests 1–12 via `+RUN_ALL_TESTS`:
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
vvp ./sim_seg7    # 41 tests (Seven-Segment)
vvp ./sim_spi     # 119 tests (SPI Master)
vvp ./sim_pwm     # 28 tests (PWM Generator)
```

### 6.4 Compile Bare-Metal RISC-V Firmware
```bash
make -C sw        # Standard build
make -C sw veer   # Build for synthesizable VeeR EL2 core
```

### 6.5 Run UVM Simulations (Synopsys VCS / QuestaSim)
```bash
./run_seg7_uvm.sh seg7_hex_display_test
./run_pwm_uvm.sh  pwm_duty_cycle_test
./run_spi_uvm.sh  spi_loopback_test
./run_soc_uvm.sh  soc_test
```

---

## 7. Repository Structure

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
│   ├── app/
│   │   ├── main.c                         # Top-level firmware application demonstrating all IPs
│   │   └── main_veer.c                    # Firmware for synthesizable VeeR EL2 core
│   ├── bsp/                               # Board Support Package (link.ld, startup.S)
│   ├── drivers/                           # Modular peripheral drivers (UART, Timer, GPIO, SPI, PWM, Seg7)
│   ├── soc_memory_map.h                   # Authoritative C MMIO definitions
│   ├── main1.c                            # 8-suite MMIO verification program
│   └── Makefile                           # Automated GCC compilation pipeline
├── tb/
│   ├── tb_smart_controlsoc_top.sv         # System-Level Directed SoC Testbench (Tests 1–12 & main1.hex)
│   ├── tb_smart_controlsoc_veer_top.sv    # Synthesizable VeeR EL2 core SoC testbench
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
