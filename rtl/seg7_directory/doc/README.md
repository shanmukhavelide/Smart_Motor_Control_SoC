# Seven-Segment Display Controller IP (axi_seg7_top)

## 1. Overview
The `axi_seg7_top` module is an AXI4-Lite slave peripheral designed for driving multi-digit multiplexed seven-segment displays. In the Smart Motor Control SoC, it is connected to interconnect master port `M04` with a base address of `0x4000_8000`.

It drives up to 8 hexadecimal digits (0–F) by time-multiplexing one shared 8-bit segment bus (`seg_o[7:0]`) across 8 active digit-enable anode lines (`an_o[7:0]`). Digit 0 corresponds to the rightmost (least significant) digit.

## 2. Interface Signals
| Port Name | Direction | Width | Description |
|---|---|---|---|
| `clk` | Input | 1 | System clock |
| `rst_n` | Input | 1 | Active-low asynchronous reset |
| `s_axi_awaddr` | Input | 32 | AXI4-Lite Write address |
| `s_axi_awprot` | Input | 3 | AXI4-Lite Write protection |
| `s_axi_awvalid` | Input | 1 | AXI4-Lite Write address valid |
| `s_axi_awready` | Output | 1 | AXI4-Lite Write address ready |
| `s_axi_wdata` | Input | 32 | AXI4-Lite Write data |
| `s_axi_wstrb` | Input | 4 | AXI4-Lite Write strobes |
| `s_axi_wvalid` | Input | 1 | AXI4-Lite Write valid |
| `s_axi_wready` | Output | 1 | AXI4-Lite Write ready |
| `s_axi_bresp` | Output | 2 | AXI4-Lite Write response (OKAY: 2'b00) |
| `s_axi_bvalid` | Output | 1 | AXI4-Lite Write response valid |
| `s_axi_bready` | Input | 1 | AXI4-Lite Write response ready |
| `s_axi_araddr` | Input | 32 | AXI4-Lite Read address |
| `s_axi_arprot` | Input | 3 | AXI4-Lite Read protection |
| `s_axi_arvalid` | Input | 1 | AXI4-Lite Read address valid |
| `s_axi_arready` | Output | 1 | AXI4-Lite Read address ready |
| `s_axi_rdata` | Output | 32 | AXI4-Lite Read data |
| `s_axi_rresp` | Output | 2 | AXI4-Lite Read response (OKAY: 2'b00) |
| `s_axi_rvalid` | Output | 1 | AXI4-Lite Read response valid |
| `s_axi_rready` | Input | 1 | AXI4-Lite Read response ready |
| `seg_o` | Output | 8 | Seven-segment cathodes: `{dp, g, f, e, d, c, b, a}` |
| `an_o` | Output | 8 | Anode digit-enable lines: bit `n` enables digit `n` |

## 3. Register Map (Base: `0x4000_8000`)
| Offset | Register Name | Access | Reset Value | Description |
|---|---|---|---|---|
| `0x00` | `SEG_DATA` | R/W | `0x0000_0000` | 8 nibbles. Digit $n$ is stored in bits $[4n+3:4n]$. Digit 0 = $[3:0]$, Digit 7 = $[31:28]$. |
| `0x04` | `SEG_CTRL` | R/W | `0x0000_FF06` | Display control register:<br>• Bit 0: `EN` (1 = display enabled, 0 = all blanked)<br>• Bit 1: `SEG_ACTIVE_LOW` (1 = active-low segment pins)<br>• Bit 2: `AN_ACTIVE_LOW` (1 = active-low anode pins)<br>• Bits [15:8]: `DIGIT_MASK` (8-bit mask, 1 = digit enabled) |
| `0x08` | `SEG_DP` | R/W | `0x0000_0000` | Decimal point enable per digit: bit $n$ enables DP for digit $n$ |
| `0x0C` | `SEG_REFRESH_DIV` | R/W | `0x0000_03E8` | 16-bit clock divisor for digit multiplex scan rate (default: 1000 clock cycles) |

## 4. Theory of Operation
- **Digit Multiplexing:** When `EN = 1`, the internal counter scans round-robin through digits 0 to 7, advancing every `SEG_REFRESH_DIV` clock cycles.
- **Masking:** Only digits enabled by `DIGIT_MASK[n]` are driven. Unmasked/disabled digits are blanked during their scan timeslot.
- **Segment Decoding (Active-High):**
  - 0: `0x3F`, 1: `0x06`, 2: `0x5B`, 3: `0x4F`, 4: `0x66`, 5: `0x6D`, 6: `0x7D`, 7: `0x07`
  - 8: `0x7F`, 9: `0x6F`, A: `0x77`, B: `0x7C`, C: `0x39`, D: `0x5E`, E: `0x79`, F: `0x71`
  - `seg_o[7]` corresponds to decimal point (`dp`).
- **Polarity Control:** The `SEG_ACTIVE_LOW` and `AN_ACTIVE_LOW` bits allow direct interfacing to both common-anode and common-cathode hardware displays.

