# Seven-Segment Display Controller (AXI4-Lite slave, M04, base 0x4000_8000)

## Function
Displays up to 8 hexadecimal digits by time-multiplexing one shared segment bus
across 8 digit-enable lines. Digit 0 is the rightmost digit.

## Ports
| Port | Dir | Width | Description |
|---|---|---|---|
| seg_o | out | 8 | {dp,g,f,e,d,c,b,a} |
| an_o  | out | 8 | digit enable, bit n selects digit n |
| plus the standard AXI4-Lite slave signals and clk/rst_n |

## Registers
| Offset | Name | Access | Reset | Description |
|---|---|---|---|---|
| 0x00 | SEG_DATA | R/W | 0x0000_0000 | 8 nibbles. Digit n = bits [4n+3:4n] |
| 0x04 | SEG_CTRL | R/W | 0x0000_FF06 | [0] EN, [1] SEG_ACTIVE_LOW, [2] AN_ACTIVE_LOW, [15:8] DIGIT_MASK (1 = digit shown) |
| 0x08 | SEG_DP | R/W | 0x0000_0000 | [7:0] decimal point per digit (1 = on) |
| 0x0C | SEG_REFRESH_DIV | R/W | 0x0000_03E8 | [15:0] clock cycles each digit stays enabled |

## Behaviour
- EN = 0: all digits blanked.
- Digit scan: one digit at a time, advancing every SEG_REFRESH_DIV clocks, round-robin 0..7.
- Masked digits (DIGIT_MASK bit = 0) are skipped/blanked.
- Segment encoding (active-high form, before polarity): 0=3F 1=06 2=5B 3=4F 4=66 5=6D 6=7D 7=07
  8=7F 9=6F A=77 B=7C C=39 D=5E E=79 F=71 (bit0=a ... bit6=g).
- Polarity bits invert seg_o / an_o at the output.
- Writes to undefined offsets are ignored; reads return 0. Reads/writes respond with OKAY.
