// =============================================================================
// SEG7 Verification IP Package: seg7_pkg
// Integrates AXI4-Lite master stimulus and passive SEG7 display monitoring
//
// COMPILATION ORDER REQUIREMENT:
//   1. tb/uvm/common/axi_lite/axi_lite_if.sv
//   2. tb/uvm/common/axi_lite/axi_lite_pkg.sv
//   3. tb/seg7.vip_uvm_tb/seg7_vip_if.sv
//   4. tb/seg7.vip_uvm_tb/seg7_vip_pkg.sv
//   5. tb/uvm/seg7/seg7_pkg.sv (includes sequences, env, and tests)
//   6. tb/uvm/seg7/tb_seg7_top.sv
// =============================================================================

`ifndef SEG7_PKG_SV
`define SEG7_PKG_SV

package seg7_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // Import common AXI4-Lite Master VIP package
    import axi_lite_pkg::*;

    // Import passive SEG7 display VIP package
    import seg7_vip_pkg::*;

    // Include reusable AXI-Lite base sequence for SEG7
    `include "seg7_base_seq.sv"

    // Include basic register sequence (extends seg7_base_seq)
    `include "seg7_basic_reg_seq.sv"

    // Include hexadecimal display sequence (extends seg7_base_seq)
    `include "seg7_hex_display_seq.sv"

    // Include eight-digit scanning and digit-mask sequence (extends seg7_base_seq)
    `include "seg7_scan_mask_seq.sv"

    // Include decimal point control sequence (extends seg7_base_seq)
    `include "seg7_dp_control_seq.sv"

    // Include segment and anode polarity sequence (extends seg7_base_seq)
    `include "seg7_polarity_seq.sv"

    // Include full hexadecimal sweep sequence (extends seg7_base_seq)
    `include "seg7_full_hex_sweep_seq.sv"

    // Include refresh divider boundary sequence (extends seg7_base_seq)
    `include "seg7_refresh_boundary_seq.sv"

    // Include asynchronous reset sequence (extends seg7_base_seq)
    `include "seg7_async_reset_seq.sv"

    // Include functional coverage subscriber
    `include "seg7_coverage.sv"

    // Include integrated SEG7 environment
    `include "seg7_env.sv"

    // Include directed register tests
    `include "seg7_basic_reg_test.sv"

    // Include directed display tests
    `include "seg7_hex_display_test.sv"
    `include "seg7_scan_mask_test.sv"
    `include "seg7_dp_control_test.sv"
    `include "seg7_polarity_test.sv"
    `include "seg7_full_hex_sweep_test.sv"
    `include "seg7_refresh_boundary_test.sv"
    `include "seg7_async_reset_test.sv"

endpackage : seg7_pkg

`endif // SEG7_PKG_SV
