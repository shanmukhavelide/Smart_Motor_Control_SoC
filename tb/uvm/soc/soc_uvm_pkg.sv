// =============================================================================
// Smart ControlSoC - Top-Level SoC UVM Verification Package: soc_uvm_pkg.sv
// Integrates UART, GPIO, SPI, PWM, and SEG7 VIPs without obsolete I2C or DMA.
// =============================================================================

`ifndef SOC_UVM_PKG_SV
`define SOC_UVM_PKG_SV

`include "uvm_macros.svh"

package soc_uvm_pkg;
    import uvm_pkg::*;

    // Reusable Peripheral VIP Packages
    import uart_vip_pkg::*;
    import gpio_vip_pkg::*;
    import spi_vip_pkg::*;
    import pwm_vip_pkg::*;
    import seg7_vip_pkg::*;

    // SoC Components
    `include "soc_config.sv"
    `include "soc_virtual_sequencer.sv"
    `include "soc_virtual_sequence.sv"
    `include "soc_sequences.sv"
    `include "soc_env.sv"
    `include "soc_tests.sv"

endpackage : soc_uvm_pkg

`endif // SOC_UVM_PKG_SV

