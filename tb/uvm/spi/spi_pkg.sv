// =============================================================================
// Standalone SPI Verification Package: spi_pkg.sv
// Compiles SPI sequence items, slave model, monitor, scoreboard, coverage,
// sequences, environment, and 13 directed tests.
//
// COMPILATION ORDER REQUIREMENT:
//   1. tb/uvm/common/axi_lite/axi_lite_if.sv
//   2. tb/uvm/common/axi_lite/axi_lite_pkg.sv
//   3. tb/uvm/spi/spi_if.sv
//   4. tb/uvm/spi/spi_pkg.sv
//   5. tb/uvm/spi/tb_spi_top.sv
// =============================================================================

`ifndef SPI_PKG_SV
`define SPI_PKG_SV

package spi_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // Import common AXI4-Lite VIP package
    import axi_lite_pkg::*;

    // Include SPI verification components
    `include "spi_item.sv"
    `include "spi_slave_model.sv"
    `include "spi_monitor.sv"
    `include "spi_scoreboard.sv"
    `include "spi_coverage.sv"
    `include "spi_base_seq.sv"
    `include "spi_sequences.sv"
    `include "spi_env.sv"
    `include "spi_tests.sv"

endpackage : spi_pkg

`endif // SPI_PKG_SV

