# AGENTS.md

Guidance for coding agents working in `Smart_Motor_Control_SoC`.

## 1. Project Overview

This repository contains **Smart ControlSoC** (`smart_controlsoc_top` in `rtl/smart_controlsoc_top.v`), a 32-bit RISC-V peripheral/motor control SoC integrating:
- **CPU Master (`S00`)**: `el2_veer_wrapper` (`rtl/Cores-VeeR-EL2/el2_veer_wrapper.v`)
- **DMA Master (`S01`)**: `axi_dma_top` (`rtl/dma_directory/rtl/axi_dma_top.sv`)
- **Crossbar Interconnect (2x6)**: `axi_interconnect_wrap_2x6` (`rtl/interconnect/axi_interconnect_wrap_2x6.v`)
- **Six AXI4-Lite Slaves (`M00`–`M05`)**: UART, Hardware Timer, GPIO, SPI, I2C, and PWM

### Current Integration Reality
- **CPU is currently a Behavioral BFM**: `rtl/Cores-VeeR-EL2/el2_veer_wrapper.v` does not instantiate the full VeeR EL2 RTL core; it implements `cpu_write` and `cpu_read` tasks that drive `lsu_axi_*` directly. In `rtl/smart_controlsoc_top.v`, the IFU/SB/DMA slave interfaces on `cpu_inst` and all CPU interrupt pins (`timer_int`, `soft_int`, `extintsrc_req`) are tied off (`0`/`idle`). Full VeeR EL2 RTL lives under `rtl/Cores-VeeR-EL2/design/` for future core/PIC hookup.
- **Interrupts are top-level outputs**: Peripheral interrupts (`uart_interrupt_o`, `i2c_interrupt_o`, `gpio_interrupt_o`, `timer_interrupt_o`, `dma_done_interrupt_o`, `dma_error_interrupt_o`) are exposed at `smart_controlsoc_top` and are not yet routed into VeeR EL2's PIC.
- **AES IP is out of scope**: `rtl/aes_dire/` is standalone/legacy material. `tb/soc_uvm/filelist_soc_uvm.f` explicitly excludes all AES components—do not integrate AES into `smart_controlsoc_top` or SoC filelists unless asked.

---

## 2. Repository Structure

| Path | Purpose |
| :--- | :--- |
| `rtl/smart_controlsoc_top.v` | Top-level SoC RTL (`DATA_WIDTH=32`, `ADDR_WIDTH=32`, `STRB_WIDTH=4`, `ID_WIDTH=12`) |
| `rtl/Cores-VeeR-EL2/` | VeeR EL2 core sources (`design/`) and active BFM wrapper (`el2_veer_wrapper.v`) |
| `rtl/interconnect/` | 2x6 AXI crossbar (`axi_interconnect_wrap_2x6.v`, `axi_interconnect.v`, `arbiter.v`, `priority_encoder.v`) |
| `rtl/uart_directory/` | UART slave IP (`rtl/axi_uart_top.v`) |
| `rtl/timer_directory/` | 64-bit Hardware Timer slave IP (`rtl/axi_timer_top.sv`, `rtl/timer_core.sv`) |
| `rtl/gpio_directory/` | 32-bit Bidirectional GPIO IP (`rtl/axi_gpio_top.sv`) + OpenTitan `reg_bus.sv` / `prim_subreg*.sv` |
| `rtl/spi_directory/` | SPI Master controller IP (`rtl/axi_spi_top.v`) |
| `rtl/i2c_directory/` | OpenCores I2C Master + AXI bridge (`rtl/axi_i2c_top.v`) + `tb/i2c_slave_model.v` |
| `rtl/pwm_directory/` | 8-bit duty-cycle PWM generator (`rtl/myip_v1_0.v`, `rtl/myip_v1_0_S00_AXI.v`, 256-cycle period) |
| `rtl/dma_directory/` | AXI4 DMA Master (`rtl/axi_dma_top.sv`), rggen CSRs (`rtl/csr_dma.v`), docs (`doc/registers.md`) |
| `sw/` | `soc_memory_map.h` (MMIO definitions) and `main1.c` (8-suite C verification program) |
| `main1.hex` | 73-transaction (`W`/`R <addr> <data>`) MMIO trace executed by `tb_smart_controlsoc_top` |
| `tb/tb_smart_controlsoc_top.sv` | Directed SV SoC testbench (streams `main1.hex`; optional Tests 1–12 via `+RUN_ALL_TESTS`) |
| `tb/soc_uvm/` | Active SoC UVM bench (`tb_soc_uvm_top.sv`, `filelist_soc_uvm.f`, `soc_uvm_pkg.sv`, `interfaces/`) |
| `tb/tb_top.sv`, `tb/soc_top_pkg.sv` | Earlier VIP integration smoke UVM bench (`soc_top_test`) |
| `tb/*.vip_uvm_tb/` | Peripheral VIPs (UART, GPIO, I2C, SPI, PWM) |
| `script/` | Python generators (`axi_interconnect_wrap.py`, `generate_clean_vips.py`, `uvm_full_tb_generator.py`) |
| `doc/` | `Smart_ControlSoC_Testplan.csv` (26 testcases), `interfaces/*.csv`, architecture docs/diagrams |
| `filelist.f` | RTL filelist for `tb_smart_controlsoc_top` |

---

## 3. Memory Map & Hardware Gotchas

Authoritative interconnect decode is set in `rtl/smart_controlsoc_top.v` (`ADDR_WIDTH=12`, 4 KB per peripheral):

| Port | Peripheral | Top Module | Base Address | Notes |
| :--- | :--- | :--- | :--- | :--- |
| `M00` | UART | `axi_uart_top` | `0x4000_0000` | Uses `m00_axi_*addr[4:0]` |
| `M01` | Timer | `axi_timer_top` | `0x4000_4000` | 64-bit `mtime`/`mtimecmp` |
| `M02` | GPIO | `axi_gpio_top` | `0x4000_2000` | 32 bidirectional pads (`gpio_io[31:0]`) |
| `M03` | SPI | `axi_spi_top` | `0x4000_6000` | Uses `m03_axi_*addr[6:0]` |
| `M04` | I2C | `axi_i2c_top` | `0x4000_8000` | Open-drain `i2c_scl_io`/`i2c_sda_io` require TB `pullup` |
| `M05` | PWM | `myip_v1_0` | `0x4000_A000` | Uses `m05_axi_*addr[3:0]`; `bid`/`rid` tied 0, `rlast=1` |
| Ext CSR | DMA CSRs | `axi_dma_top` | `0x4000_C000` (SW alias) | Exposed as dedicated `dma_csr_*` port on `smart_controlsoc_top`, **not** on `system_interconnect` |

### Critical Traps to Avoid
1. **Stale comments in `filelist.f`**: Comments in `filelist.f` list `0x2000_0000`–`0x2000_5000`; the real interconnect base addresses are `0x4000_0000`–`0x4000_A000`.
2. **DMA `DMA_DESC*_CFG` bitfield order (`0x50` / `0x58`)**: `README.md` reverses bits `[0]` and `[2]`. Per `rtl/dma_directory/doc/registers.md`, `sw/main1.c`, and `tb/tb_smart_controlsoc_top.sv`:
   - `[0]` = `write_mode` (`0` = INCR, `1` = FIXED)
   - `[1]` = `read_mode` (`0` = INCR, `1` = FIXED)
   - `[2]` = `enable` (`1` = enabled; e.g., `0x7` = FIXED->FIXED enabled)
3. **DMA CSR visibility in testbenches**: Because `dma_csr_*` is an external slave port on `smart_controlsoc_top`:
   - `tb/tb_smart_controlsoc_top.sv` drives `dma_csr_*` directly (subtracting `0x4000_C000` from hex addresses).
   - `tb/soc_uvm/tb_soc_uvm_top.sv` and `tb/tb_top.sv` currently tie `dma_csr_*` idle (`awvalid=0`, `wvalid=0`, `arvalid=0`).
4. **Reset polarity**: `smart_controlsoc_top` and all peripherals use active-low `sys_rst_n`, while `axi_interconnect_wrap_2x6` expects active-high `rst` (`.rst(~sys_rst_n)`).
5. **VIP file naming duplicates**: Under `tb/*.vip_uvm_tb/`, both `*_vip_*.sv` (underscore) and `*.vip_*.sv` (dot) exist. Both `tb/soc_uvm/filelist_soc_uvm.f` and `tb/tb_top.sv` compile the **underscore** files (`uart_vip_pkg.sv`, `gpio_vip_pkg.sv`, etc.). Edit those rather than the dotted files.
6. **Filelist compilation order**: Keep OpenTitan common cells (`reg_bus.sv`, `prim_subreg*.sv`), `gpio_reg_pkg.sv`, and `amba_axi_pkg.sv`/`dma_utils_pkg.sv` ahead of modules that import them in `filelist.f` and `tb/soc_uvm/filelist_soc_uvm.f`.

---

## 4. Build, Simulation & Verification Commands

Shell scripts target Linux with Synopsys VCS and Verdi (`VCS_HOME`, `VERDI_HOME`, `SNPSLMD_LICENSE_FILE` are set inside each `.sh` script):

- **Directed + Hex C-Trace SoC Simulation (`tb_smart_controlsoc_top`)**:
  ```bash
  ./run_vcs_sim.sh                  # Runs main1.hex by default -> simv, smart_controlsoc.fsdb
  ./run_vcs_sim.sh +HEX=custom.hex  # Override hex trace file
  ./run_vcs_sim.sh +RUN_ALL_TESTS   # Also runs directed Tests 1-12
  ```
- **SoC-Level UVM Verification (`tb_soc_uvm_top`)**:
  ```bash
  ./run_soc_uvm.sh                  # Default: soc_test -> simv_soc_uvm, tb_soc_uvm_top.fsdb
  ./run_soc_uvm.sh uart_connectivity_test
  ./run_soc_uvm.sh gpio_test
  ./run_soc_uvm.sh i2c_test
  ./run_soc_uvm.sh pwm_test
  ./run_soc_uvm.sh spi_test
  ```
- **Unified VIP Smoke UVM Bench (`tb_top`)**:
  ```bash
  ./run_uvm_tb_top.sh               # Runs soc_top_test -> simv_uvm_top, tb_top.fsdb
  ```
- **Verdi Waveforms (UART UVM)**:
  ```bash
  ./view_verdi_uart.sh              # Opens tb_soc_uvm_top.fsdb with uart_waves.rc
  ```
- **Host-Native C Check (`sw/main1.c`)**:
  Compile with `-DSIMULATION_HOST` (uses the mock MMIO model in `sw/main1.c` instead of bare-metal pointer dereferences).

---

## 5. Conventions & Hygiene

- **Line endings**: `.gitattributes` enforces LF (`eol=lf`) for text files, `*.sh`, and `*.hex`. Keep LF endings when editing from Windows.
- **Sync across layers**: When changing RTL files/directories, update both `filelist.f` and `tb/soc_uvm/filelist_soc_uvm.f`. When changing MMIO addresses or bitfields, update `rtl/smart_controlsoc_top.v`, `sw/soc_memory_map.h`, `sw/main1.c`, `main1.hex`, `tb/tb_smart_controlsoc_top.sv`, and `tb/soc_uvm/*` together.
- **Tracked vs. ignored outputs**: Do not commit VCS/Verdi build artifacts (`simv*`, `*.daidir/`, `csrc/`, `*.fsdb*`, `*.vcd`, `work/`, `*.log` except tracked subdirectories under `log/`).
