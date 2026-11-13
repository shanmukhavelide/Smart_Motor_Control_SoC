// =============================================================================
// AXI4-Lite Verification IP Package: axi_lite_pkg
// Compiles types, sequence item, sequencer, driver, and agent.
//
// COMPILATION ORDER REQUIREMENT:
//   1. axi_lite_if.sv   (Interface MUST be compiled before package/classes)
//   2. axi_lite_pkg.sv  (Package includes classes referencing virtual interface)
// =============================================================================

`ifndef AXI_LITE_PKG_SV
`define AXI_LITE_PKG_SV

package axi_lite_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // Protocol enumerations
    typedef enum bit [1:0] {
        AXI_LITE_RESP_OKAY   = 2'b00,
        AXI_LITE_RESP_EXOKAY = 2'b01,
        AXI_LITE_RESP_SLVERR = 2'b10,
        AXI_LITE_RESP_DECERR = 2'b11
    } axi_lite_resp_e;

    typedef enum bit {
        AXI_LITE_READ  = 1'b0,
        AXI_LITE_WRITE = 1'b1
    } axi_lite_trans_type_e;

    // Include component classes
    `include "axi_lite_item.sv"
    `include "axi_lite_sequencer.sv"
    `include "axi_lite_driver.sv"
    `include "axi_lite_agent.sv"

    // Convenience typedefs for standard specializations
    typedef axi_lite_driver#(32, 32) axi_lite_driver_32;
    typedef axi_lite_agent#(32, 32)  axi_lite_agent_32;

    typedef axi_lite_driver#(12, 32) axi_lite_driver_12;
    typedef axi_lite_agent#(12, 32)  axi_lite_agent_12;

endpackage : axi_lite_pkg

`endif // AXI_LITE_PKG_SV
