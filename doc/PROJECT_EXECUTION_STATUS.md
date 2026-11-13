# Smart Motor Control SoC — Project Execution Status

**Last Updated:** 2026-11-13  
**Active Branch:** `dev`  
**Host Environment:** Windows 11 / WSL2 (Ubuntu 22.04 LTS)  
**Target Repository:** `Smart_Motor_Control_SoC`

---

## 1. Tool Availability & Environment Assessment

| Tool | Status | Details / Path |
| :--- | :--- | :--- |
| **Icarus Verilog (`iverilog`)** | **AVAILABLE** | Version 11.0 (`/usr/bin/iverilog`), runtime `/usr/bin/vvp` |
| **Verilator** | **AVAILABLE** | Version 4.038 (`/usr/bin/verilator`) - static lint / C++ sim |
| **GTKWave** | **AVAILABLE** | Version 3.3.104 (`/usr/bin/gtkwave`) |
| **RISC-V Toolchain (GCC/Binutils)** | **AVAILABLE** | `riscv64-unknown-elf-gcc` 10.2.0 (`/usr/bin/riscv64-unknown-elf-gcc`), verified RV32 (`-march=rv32im -mabi=ilp32`) |
| **Host GCC** | **AVAILABLE** | Ubuntu 11.4.0 (`/usr/bin/gcc`) |
| **GNU Make & Python 3** | **AVAILABLE** | Python 3.10.12, GNU Make 4.3 |
| **Synopsys VCS / Verdi** | **BLOCKED (License Server)** | Scripts reference `/home/student/snps_tools_target/vcs/U-2023.03` & license server `27021@14.139.1.126`. Server unreachable on current local network. VCS-dependent UVM suites are IMPLEMENTED and STATIC CHECK PASSED, but runtime simulation is BLOCKED. |

---

## 2. Authoritative SoC Architecture & Active Memory Map

The **authoritative project baseline** is `smart_controlsoc_top` (`rtl/smart_controlsoc_top.v`), utilizing the behavioral CPU BFM wrapper `el2_veer_wrapper.v` driving master port `S00`, with all peripheral verification focused around the six active AXI4-Lite peripherals:

| Port | Peripheral Block | Base Address | RTL Module | Status |
| :--- | :--- | :--- | :--- | :--- |
| **S00** | CPU LSU AXI Master | - | `el2_veer_wrapper` (`cpu_inst`) | Authoritative Active Master (BFM) |
| **S01** | Auxiliary AXI Master | - | *None* | **Tied Off** (unused, tied to 0) |
| **M00** | UART Controller | `0x4000_0000` | `axi_uart_top` | Active Slave (Standalone 20/20 PASS) |
| **M01** | 64-bit Hardware Timer | `0x4000_4000` | `axi_timer_top` | Active Slave |
| **M02** | 32-bit GPIO Controller | `0x4000_2000` | `axi_gpio_top` | Active Slave |
| **M03** | SPI Master Controller | `0x4000_6000` | `axi_spi_top` | Active Slave |
| **M04** | Seven-Segment Display (SEG7) | `0x4000_8000` | `axi_seg7_top` | Active Slave (Replaced I2C) |
| **M05** | PWM Generator (8-bit) | `0x4000_A000` | `myip_v1_0` | Active Slave |

*Note: DMA and I2C have been completely excised from the SoC top-level RTL and system interconnect.*

---

## 3. Project Phase Status Tracker

| Phase | Description | Status | Evidence / Validation |
| :--- | :--- | :--- | :--- |
| **Phase 0** | Setup and Baseline | **COMPLETE** | WSL environment audited; Git branch `dev`; verified baseline unit test binaries. |
| **Phase 1** | I2C/DMA Removal Audit | **COMPLETE** | RTL audit confirmed: zero I2C/DMA instances in `smart_controlsoc_top.v`; S01 tied off; M04 bound to SEG7. |
| **Phase 2** | Final Specifications | **COMPLETE** | `doc/spec/seg7_spec.md` verified; `doc/spec/memory_map_final.md` aligned with RTL. |
| **Phase 3** | RTL Integration | **COMPLETE** | `smart_controlsoc_top.v` integrates all 6 peripherals; `filelist.f` updated and verified. |
| **Phase 4** | Standalone Unit Verification | **SIMULATION PASSED** | Standalone Icarus testbenches executed via `iverilog` / `vvp`: UART (20/20 PASS), SEG7 (41/41 PASS), SPI (119/119 PASS), PWM (28/28 PASS). Total: 208 PASS, 0 FAIL (100%). For UART, only `rtl/uart_directory/tb/tb_axi_uart_top.v` was modified (corrected AXI handshake protocol sequencing and resolved 3-bit localparam shift truncation in register address definitions); UART RTL remained completely untouched. |
| **Phase 5.4a** | SEG7 UVM Environment | **IMPLEMENTED** / **BLOCKED (Sim)** | Reusable `tb/uvm/common/axi_lite/` + `tb/uvm/seg7/` (8 directed UVM sequences/tests) + `run_seg7_uvm.sh`. Dynamic simulation BLOCKED by VCS license server. |
| **Phase 5.4b** | PWM UVM Environment | **IMPLEMENTED** / **BLOCKED (Sim)** | Standalone UVM testbench `tb/uvm/pwm/` with AXI-Lite VIP, PWM monitor (non-hanging on 0%, 255/256 max, constant-high), scoreboard, coverage & 13 directed tests; `run_pwm_uvm.sh` runner created. Dynamic simulation BLOCKED by VCS license server. |
| **Phase 5.4c** | SPI UVM Environment | **IMPLEMENTED** / **BLOCKED (Sim)** | Standalone UVM testbench `tb/uvm/spi/` with AXI-Lite VIP, Mode 0 SPI slave model, monitor, scoreboard, coverage & 13 directed tests; `run_spi_uvm.sh` runner created. Dynamic simulation BLOCKED by VCS license server. |
| **Phase 5.5** | SoC-Level UVM Integration | **IMPLEMENTED** / **BLOCKED (Sim)** | Unified SoC UVM environment in `tb/uvm/soc/` integrating UART, Timer, GPIO, SPI, PWM, SEG7; 11 directed SoC tests implemented; `run_soc_uvm.sh` updated. Dynamic simulation BLOCKED by VCS license server. |
| **Phase 6a** | SoC TB (Directed SV) | **IMPLEMENTED** / **BLOCKED (Sim)** | Directed testbench `tb/tb_smart_controlsoc_top.sv` updated (Tests 1–12); `main1.hex` cleaned of DMA traces. VCS simulation BLOCKED by license server. |
| **Phase 6b** | Host C MMIO Drivers | **SIMULATION PASSED** | `sw/main1.c` compiled with `gcc -DSIMULATION_HOST` executed cleanly: 36/36 subtests passed across all modules. |
| **Phase 6c** | Bare-Metal RISC-V Firmware Build | **STATIC CHECK PASSED** | Built with `riscv64-unknown-elf-gcc`: produced `firmware.elf` (2,676 bytes text), `firmware.bin`, `firmware.hex` (169 words), and `firmware.dis`. |
| **Phase 6d** | Firmware Execution on VeeR EL2 | **NOT VERIFIED** | `smart_controlsoc_top` currently instantiates `el2_veer_wrapper.v` (a Behavioral BFM); the full VeeR core pipeline is not hooked up to instruction memory (IFU tied off). Actual CPU firmware execution on hardware/core is NOT VERIFIED. |
| **Phase 7** | Complete Documentation | **COMPLETE** | Updated `README.md`, `Smart_ControlSoC_Testplan.csv` (29 testcases), per-IP docs (`rtl/seg7_directory/doc/README.md`, `rtl/spi_directory/doc/README.md`), `doc/FINAL_PROJECT_STATUS.md`. |
| **Phase 8** | Full Regression & Closure | **COMPLETE** | Master automated regression runner `run_regression.sh` implemented; 100% of runnable suites passed (5/5), 5 VCS suites correctly reported as BLOCKED. |
| **Experimental Branch** | VeeR EL2 Core Processor Integration | **EXPERIMENTAL / IMPLEMENTED / NOT DYNAMICALLY VERIFIED** | Exploratory parallel integration branch (`smart_controlsoc_veer_top.v`, `veer_mem_subsystem.sv`, `axi_lsu_dwidth_adapter.v`, `sw/bsp/link_veer.ld`, `sw/bsp/startup_veer.S`, `sw/app/main_veer.c`, `tb/tb_smart_controlsoc_veer_top.sv`, `filelist_veer.f`). Out of scope for current milestone; preserved intact but deferred. Not dynamically verified. Authoritative baseline remains BFM-based `smart_controlsoc_top.v`. |

---

## 4. Current Validation Evidence

- **UART Unit Simulation (`tb_axi_uart_top.v` / `iverilog` + `vvp`):** **20/20 PASSED (0 FAILED)**
  - *Simulation Command:* `iverilog -g2012 -Irtl/uart_directory/include rtl/uart_directory/rtl/*.v rtl/uart_directory/tb/tb_axi_uart_top.v -o sim_uart && vvp sim_uart`
  - *Scope:* Only `rtl/uart_directory/tb/tb_axi_uart_top.v` was modified; UART RTL implementation (`axi_uart_top.v`) remained completely untouched.
  - *Handshake Fix:* Corrected AXI handshake sequencing so that `AWVALID`/`WVALID`/`BREADY` and `ARVALID`/`RREADY` are held asserted until the slave completes the transaction phase (`awready && wready && bvalid` and `arready && rvalid`), eliminating race conditions and timeouts caused by combinatorial response gating in the DUT. No arbitrary delays were introduced.
  - *Address Truncation Fix:* Corrected localparam address offset definitions (`5'd0`, `5'd1`, `5'd2`, `5'd3`, `5'd5` shifted by `AXI_LSB_WIDTH=2`) to prevent Verilog self-determined 3-bit shift truncation that previously caused address offsets to alias to 0x00 and 0x04.
  - *Testcases Verified:* TC1 (Reset deassertion, 6 checks), TC2 (LCR write, 1 check), TC3 (Baud divisor programming with DLAB=1, 1 check), TC4 (THR transmit byte 0x55 capture, 2 checks), TC5 (LSR read empty status 0x60, 1 check), TC6 (RBR receive byte 0xA5, 2 checks), TC7 (Full loopback 0xC3, 1 check), TC8 (RX interrupt assertion, 1 check), TC9 (Unimplemented address no hang, 2 checks), TC10 (Multiple TX bytes 0x11, 0x22, 0x33, 3 checks).
- **SEG7 Unit Simulation (`sim_seg7` / `tb_axi_seg7.sv`):** **41/41 PASSED (0 FAILED)**
- **SPI Unit Simulation (`sim_spi` / `tb_axi_spi.sv`):** **119/119 PASSED (0 FAILED)**
- **PWM Unit Simulation (`sim_pwm` / `tb_axi_pwm.sv`):** **28/28 PASSED (0 FAILED)**
- **Total Standalone Unit Test Passes:** **208/208 PASSED (0 FAILED, 100%)**
- **Host C MMIO Drivers (`sw/main1.c`):** **36/36 PASSED (0 FAILED)**
- **Bare-Metal RISC-V GCC Compilation:** **PASSED** (`sw/build/firmware.hex` generated, 169 32-bit words)
- **Firmware CPU Execution:** **NOT VERIFIED** (el2_veer_wrapper is a BFM; Synthesizable Core is an experimental branch deferred from current milestone)
- **Experimental VeeR Core Files:** **EXPERIMENTAL / IMPLEMENTED / NOT DYNAMICALLY VERIFIED** (Preserved intact; deferred from current milestone)
- **Master Regression Suite (`run_regression.sh`):** **5/5 Runnable Suites PASSED (0 FAILED)**, 5 VCS Suites BLOCKED (License Server unreachable).

---

## 5. Known Hardware & Specification Nuances

1. **PWM Max Duty:** PWM core uses strict `<` comparison with 8-bit register (`pwm_counter < duty_cycle`). Maximum achievable duty is `255/256` (99.61%), not continuous 100%. Writing `0x00` produces continuous 0% output. The UVM monitor and scoreboard explicitly handle this boundary.
2. **SPI Supported Mode:** Current RTL natively implements SPI Mode 0 (CPOL=0, CPHA=0). Slave model, monitor, and scoreboard are strictly aligned to Mode 0 operation.
3. **OpenTitan GPIO Primitives:** Contains concurrent SVA properties (`|->`) requiring IEEE 1800 SystemVerilog assertion support (Synopsys VCS / Questa).
4. **VCS License Connectivity:** Commercial Synopsys VCS license server `27021@14.139.1.126` is unreachable from this local machine. All UVM and system VCS simulation scripts are verified and ready for execution in a licensed environment.
5. **CPU Integration Reality:** The current SoC RTL wrapper `el2_veer_wrapper.v` is a BFM driving AXI master port S00. Full VeeR EL2 core RTL resides in `rtl/Cores-VeeR-EL2/design/` for future PIC and core integration.

---

## 6. Git Working Tree Status Notice
The Git working tree is **NOT clean**:
- 13 modified tracked files (`AGENTS.md`, `README.md`, `doc/Smart_ControlSoC_Testplan.csv`, `doc/spec/memory_map_final.md`, `main1.hex`, `rtl/uart_directory/tb/tb_axi_uart_top.v`, `run_soc_uvm.sh`, `tb/soc_uvm/filelist_soc_uvm.f`, `tb/tb_smart_controlsoc_top.sv`, `tb/seg7.vip_uvm_tb/*`).
- Multiple new untracked files and directories (`sw/`, `tb/uvm/`, `run_*.sh`, `doc/FINAL_PROJECT_STATUS.md`, `doc/PROJECT_EXECUTION_STATUS.md`, `rtl/*/doc/README.md`, `log/`).
- All changes remain intentionally unstaged and uncommitted awaiting explicit user authorization.
