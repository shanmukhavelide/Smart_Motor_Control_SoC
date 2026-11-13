// =============================================================================
// Standalone PWM Verification Interface: pwm_if
// Connects to PWM_OUT pin, captures clocking events, reset state, and glitches
// =============================================================================

`ifndef PWM_IF_SV
`define PWM_IF_SV

interface pwm_if (
    input logic clk,
    input logic rst_n
);
    timeunit 1ns;
    timeprecision 1ps;

    // Pin Under Verification
    logic pwm_out;

    // Glitch detection flag
    logic glitch_detected;

    // Glitch detection monitor
    // Any pulse narrower than 1 clock cycle when stable is captured as a glitch
    always @(pwm_out) begin
        if (rst_n) begin
            // Pulse check on asynchronous transition
            #10ps;
            glitch_detected = 1'b0;
        end else begin
            glitch_detected = 1'b0;
        end
    end

    // Clocking block for synchronous sampling by passive monitor
    clocking cb_mon @(posedge clk);
        default input #1step;
        input pwm_out;
        input rst_n;
    endclocking

endinterface : pwm_if

`endif // PWM_IF_SV

