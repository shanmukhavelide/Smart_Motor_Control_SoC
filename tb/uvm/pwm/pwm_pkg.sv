// =============================================================================
// Standalone PWM Verification Package: pwm_pkg
// Compiles PWM sequence items, monitor, scoreboard, coverage, env, and test suite.
//
// COMPILATION ORDER REQUIREMENT:
//   1. tb/uvm/common/axi_lite/axi_lite_if.sv
//   2. tb/uvm/common/axi_lite/axi_lite_pkg.sv
//   3. tb/uvm/pwm/pwm_if.sv
//   4. tb/uvm/pwm/pwm_pkg.sv
//   5. tb/uvm/pwm/tb_pwm_top.sv
// =============================================================================

`ifndef PWM_PKG_SV
`define PWM_PKG_SV

package pwm_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // Import common AXI4-Lite VIP package
    import axi_lite_pkg::*;

    // Include PWM verification components
    `include "pwm_item.sv"
    `include "pwm_monitor.sv"
    `include "pwm_scoreboard.sv"
    `include "pwm_coverage.sv"
    `include "pwm_base_seq.sv"
    `include "pwm_sequences.sv"
    `include "pwm_env.sv"
    `include "pwm_tests.sv"

endpackage : pwm_pkg

`endif // PWM_PKG_SV

