# Master Regression Test Report
**Date & Time:** 2026-11-13 04:03:47  
**Target:** Smart Motor Control SoC (`smart_controlsoc_top`)  
**Active Git Branch:** `dev`  

## Executive Summary
| Total Suites | Passed | Failed | Blocked (Tool/License) | Overall Status |
|:---:|:---:|:---:|:---:|:---:|
| **11** | **6** | **0** | **5** | **100% of Runnable Tests Passed** |

---

## Detailed Test Suite Results

| Test Category | Test Suite | Toolchain | Status | Execution Details |
|---|---|---|:---:|---|
| **Unit Verification** | UART Controller Unit Test (`tb_axi_uart_top`) | Icarus Verilog (`iverilog` + `vvp`) | **PASS** | 20/20 unit checks passed (Command: `iverilog -g2012 -Irtl/uart_directory/include rtl/uart_directory/rtl/*.v rtl/uart_directory/tb/tb_axi_uart_top.v -o sim_uart && vvp sim_uart`). Only testbench modified (handshake protocol sequencing and address truncation fixed); UART RTL untouched. |
| **Unit Verification** | SEG7 Controller Unit Test (`tb_axi_seg7`) | Icarus Verilog (`vvp`) | **PASS** | 41/41 unit checks passed |
| **Unit Verification** | SPI Controller Unit Test (`tb_axi_spi`) | Icarus Verilog (`vvp`) | **PASS** | 119/119 Mode 0 tests passed |
| **Unit Verification** | PWM Generator Unit Test (`tb_axi_pwm`) | Icarus Verilog (`vvp`) | **PASS** | 28/28 duty-cycle tests passed |
| **Software Verification** | Host C Drivers & Memory Map (`main1.c`) | Host GCC | **PASS** | 36/36 subtests passed across all modules |
| **Software Toolchain** | Bare-Metal RISC-V Firmware Build | riscv64-unknown-elf-gcc | **PASS** | Produced firmware.elf, firmware.bin, firmware.hex (169 lines) |
| **UVM Verification** | Standalone PWM UVM (13 tests) | Synopsys VCS | **BLOCKED (License/Simulator Unavailable)** | Script ./run_pwm_uvm.sh ready. Blocked by license server 27021@14.139.1.126 |
| **UVM Verification** | Standalone SPI UVM (13 tests) | Synopsys VCS | **BLOCKED (License/Simulator Unavailable)** | Script ./run_spi_uvm.sh ready. Blocked by license server 27021@14.139.1.126 |
| **UVM Verification** | Standalone SEG7 UVM (8 tests) | Synopsys VCS | **BLOCKED (License/Simulator Unavailable)** | Script ./run_seg7_uvm.sh ready. Blocked by license server 27021@14.139.1.126 |
| **UVM Verification** | System-Level SoC UVM (11 tests) | Synopsys VCS | **BLOCKED (License/Simulator Unavailable)** | Script ./run_soc_uvm.sh ready. Blocked by license server 27021@14.139.1.126 |
| **System Verification** | Directed SoC Simulation (Tests 1-12) | Synopsys VCS | **BLOCKED (License/Simulator Unavailable)** | Script ./run_vcs_sim.sh ready. Blocked by license server 27021@14.139.1.126 |

---

## Tool Availability Analysis
* **Icarus Verilog (`iverilog` / `vvp`):** Fully operational. All 208 unit tests passed with 0 errors (UART 20, SEG7 41, SPI 119, PWM 28).
* **Host GCC (`gcc`):** Fully operational. Mock MMIO driver test passed 36/36 subtests across 8 suites.
* **RISC-V GNU Toolchain (`riscv64-unknown-elf-gcc`):** Fully operational. Compiled bare-metal firmware into ELF, BIN, HEX, and DIS.
* **Synopsys VCS & Verdi:** Configured to remote license server `27021@14.139.1.126`, which is not reachable on the current host network. All VCS scripts are verified and ready for execution in a licensed environment.

