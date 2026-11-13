# AXI4-Lite SPI Master Controller IP (axi_spi_top)

## 1. Overview
The `axi_spi_top` module is an AXI4-Lite slave peripheral implementing a serial peripheral interface (SPI) master controller. In the Smart Motor Control SoC, it is connected to interconnect master port `M03` with a base address of `0x4000_6000`.

The core supports configurable clock ratio generation, FIFO buffering (32 entries deep) for transmit and receive paths, configurable slave select outputs, and Mode 0 (CPOL=0, CPHA=0) operation.

## 2. Interface Signals
| Port Name | Direction | Width | Description |
|---|---|---|---|
| `s_axi_aclk` | Input | 1 | AXI system clock |
| `s_axi_aresetn` | Input | 1 | Active-low asynchronous reset |
| `s_axi_awaddr` | Input | 7 | AXI4-Lite Write address (`awaddr[6:0]`) |
| `s_axi_awvalid` | Input | 1 | AXI4-Lite Write address valid |
| `s_axi_awready` | Output | 1 | AXI4-Lite Write address ready |
| `s_axi_wdata` | Input | 32 | AXI4-Lite Write data |
| `s_axi_wstrb` | Input | 4 | AXI4-Lite Write strobes |
| `s_axi_wvalid` | Input | 1 | AXI4-Lite Write valid |
| `s_axi_wready` | Output | 1 | AXI4-Lite Write ready |
| `s_axi_bresp` | Output | 2 | AXI4-Lite Write response |
| `s_axi_bvalid` | Output | 1 | AXI4-Lite Write response valid |
| `s_axi_bready` | Input | 1 | AXI4-Lite Write response ready |
| `s_axi_araddr` | Input | 7 | AXI4-Lite Read address (`araddr[6:0]`) |
| `s_axi_arvalid` | Input | 1 | AXI4-Lite Read address valid |
| `s_axi_arready` | Output | 1 | AXI4-Lite Read address ready |
| `s_axi_rdata` | Output | 32 | AXI4-Lite Read data |
| `s_axi_rresp` | Output | 2 | AXI4-Lite Read response |
| `s_axi_rvalid` | Output | 1 | AXI4-Lite Read response valid |
| `s_axi_rready` | Input | 1 | AXI4-Lite Read response ready |
| `spi_clk_o` | Output | 1 | Serial SPI clock output |
| `spi_mosi_o` | Output | 1 | Master Out Slave In serial data |
| `spi_miso_i` | Input | 1 | Master In Slave Out serial data |
| `spi_cs_n_o` | Output | 1 | Active-low slave select |
| `ip2intc_irpt` | Output | 1 | SPI interrupt request output |

## 3. Register Map (Base: `0x4000_6000`)
| Offset | Name | Access | Reset Value | Description |
|---|---|---|---|---|
| `0x1C` | `SPI_GIER` | R/W | `0x0000_0000` | Global Interrupt Enable Register (Bit 31: Global Enable) |
| `0x20` | `SPI_ISR` | R/W1C | `0x0000_0000` | Interrupt Status Register |
| `0x28` | `SPI_IER` | R/W | `0x0000_0000` | Interrupt Enable Register |
| `0x30` | `SPI_RCLK` | R/W | `0x0000_0004` | Clock ratio register (divider between system clock and SPI SCK) |
| `0x40` | `SPI_SRR` | WO | `0x0000_0000` | Software Reset Register (write `0x0000_000A` to reset core) |
| `0x60` | `SPI_CR` | R/W | `0x0000_0180` | Control Register:<br>• Bit 1: `SPI_ENABLE`<br>• Bit 2: `MASTER_BIT`<br>• Bit 3: `CPOL`<br>• Bit 4: `CPHA`<br>• Bit 5: `TX_FIFO_RESET`<br>• Bit 6: `RX_FIFO_RESET`<br>• Bit 9: `LSB_FIRST` |
| `0x64` | `SPI_SR` | RO | `0x0000_00A5` | Status Register:<br>• Bit 0: `RX_EMPTY`<br>• Bit 1: `RX_FULL`<br>• Bit 2: `TX_EMPTY`<br>• Bit 3: `TX_FULL`<br>• Bit 4: `MODF` (Mode Fault)<br>• Bit 5: `SLAVE_MODE_SELECT` |
| `0x68` | `SPI_DTR` | WO | `0x0000_0000` | Data Transmit Register (pushes 8-bit byte into TX FIFO) |
| `0x6C` | `SPI_DRR` | RO | `0x0000_0000` | Data Receive Register (pops 8-bit byte from RX FIFO) |
| `0x70` | `SPI_SSR` | R/W | `0xFFFF_FFFF` | Slave Select Register (active-low slave select mask) |

## 4. Operational Notes
- **Default Baseline:** Mode 0 (`CPOL=0`, `CPHA=0`) is the natively supported operational mode.
- **Clock Ratio:** `SPI_RCLK` configures the SPI clock period in terms of system clock multiples.
- **Transmission Flow:**
  1. Initialize `SPI_SSR` to assert target chip select (e.g. write `~0x1`).
  2. Configure `SPI_CR` enabling Master Mode and asserting SPI Enable (`0x06` or `0x186`).
  3. Write data byte to `SPI_DTR` (`0x68`).
  4. Wait for transmission to complete by monitoring `SPI_SR` (`TX_EMPTY` bit) or interrupt.
  5. Read received byte from `SPI_DRR` (`0x6C`).

