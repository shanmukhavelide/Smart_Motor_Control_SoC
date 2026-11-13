// =============================================================================
// Standalone PWM Scoreboard: pwm_scoreboard
// Verifies register read/write operations against shadow registers and checks
// observed waveform periods, duty cycles, and boundary behaviors against expected.
// =============================================================================

`ifndef PWM_SCOREBOARD_SV
`define PWM_SCOREBOARD_SV

`uvm_analysis_imp_decl(_axi)
`uvm_analysis_imp_decl(_pwm)

class pwm_scoreboard extends uvm_scoreboard;

    uvm_analysis_imp_axi #(axi_lite_item, pwm_scoreboard) axi_imp;
    uvm_analysis_imp_pwm #(pwm_item,      pwm_scoreboard) pwm_imp;

    // Shadow Registers
    bit [31:0] shadow_regs[4];
    bit [7:0]  current_expected_duty;
    bit [7:0]  prev_expected_duty;
    bit        duty_updated;

    // Verification Statistics
    int unsigned reg_checks_passed;
    int unsigned reg_checks_failed;
    int unsigned waveform_checks_passed;
    int unsigned waveform_checks_failed;

    `uvm_component_utils(pwm_scoreboard)

    function new(string name = "pwm_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        axi_imp = new("axi_imp", this);
        pwm_imp = new("pwm_imp", this);

        for (int i = 0; i < 4; i++) shadow_regs[i] = 32'h0;
        current_expected_duty = 8'h00;
        prev_expected_duty    = 8'h00;
        duty_updated          = 0;

        reg_checks_passed      = 0;
        reg_checks_failed      = 0;
        waveform_checks_passed = 0;
        waveform_checks_failed = 0;
    endfunction

    // Handle AXI Register Transactions
    virtual function void write_axi(axi_lite_item tr);
        bit [1:0] reg_idx = tr.addr[3:2];

        if (tr.trans_type == AXI_LITE_WRITE) begin
            bit [31:0] updated_val = shadow_regs[reg_idx];
            for (int b = 0; b < 4; b++) begin
                if (tr.wstrb[b]) begin
                    updated_val[(b*8) +: 8] = tr.data[(b*8) +: 8];
                end
            end
            shadow_regs[reg_idx] = updated_val;

            if (reg_idx == 2'h0) begin
                prev_expected_duty    = current_expected_duty;
                current_expected_duty = updated_val[7:0];
                duty_updated          = 1;
                `uvm_info(get_type_name(), $sformatf("[AXI WRITE slv_reg0] Programmed duty_cycle = 0x%02h (%0d/256 = %0.2f%%)",
                          current_expected_duty, current_expected_duty, (current_expected_duty * 100.0) / 256.0), UVM_MEDIUM)
            end else begin
                `uvm_info(get_type_name(), $sformatf("[AXI WRITE slv_reg%0d] Data = 0x%08h (wstrb=0x%1h)",
                          reg_idx, tr.data, tr.wstrb), UVM_HIGH)
            end
        end else if (tr.trans_type == AXI_LITE_READ) begin
            bit [31:0] expected_data = shadow_regs[reg_idx];
            if (tr.data === expected_data) begin
                reg_checks_passed++;
                `uvm_info(get_type_name(), $sformatf("[PASS][REG READ slv_reg%0d] Read data 0x%08h matched expected", reg_idx, tr.data), UVM_HIGH)
            end else begin
                reg_checks_failed++;
                `uvm_error(get_type_name(), $sformatf("[FAIL][REG READ slv_reg%0d] Read data 0x%08h != expected 0x%08h", reg_idx, tr.data, expected_data))
            end
        end
    endfunction

    // Handle Measured PWM Pin Transactions
    virtual function void write_pwm(pwm_item tr);
        bit match = 0;

        // Check if measured duty matches current or previous (due to pipeline latency across update boundary)
        if (tr.is_constant_low) begin
            if (current_expected_duty == 8'h00 || (duty_updated && prev_expected_duty == 8'h00)) begin
                match = 1;
            end
        end else begin
            if (tr.high_cycles == current_expected_duty) begin
                match = 1;
                duty_updated = 0;
            end else if (duty_updated && tr.high_cycles == prev_expected_duty) begin
                match = 1; // Prior period finishing after register update
            end
        end

        if (match) begin
            waveform_checks_passed++;
            `uvm_info(get_type_name(), $sformatf("[PASS][PWM WAVEFORM] Verified duty: %0.2f%% (High=%0d, Low=%0d, Period=%0d clks)",
                      tr.duty_cycle_pct, tr.high_cycles, tr.low_cycles, tr.period_cycles), UVM_MEDIUM)
        end else begin
            waveform_checks_failed++;
            `uvm_error(get_type_name(), $sformatf("[FAIL][PWM WAVEFORM MISMATCH] Observed High=%0d clks (Duty: %0.2f%%), expected High=%0d clks (Expected: %0.2f%%) Period=%0d",
                       tr.high_cycles, tr.duty_cycle_pct, current_expected_duty, (current_expected_duty * 100.0) / 256.0, tr.period_cycles))
        end

        // Period correctness check
        if (!tr.is_constant_low && !tr.is_constant_high && tr.period_cycles != 256) begin
            // If transition occurred mid-cycle, document as transition period, otherwise fail
            if (!duty_updated) begin
                `uvm_error(get_type_name(), $sformatf("[FAIL][PERIOD MISMATCH] Period=%0d cycles != 256 expected", tr.period_cycles))
            end
        end
    endfunction

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info(get_type_name(), "==================================================================", UVM_LOW)
        `uvm_info(get_type_name(), "               PWM SCOREBOARD VERIFICATION SUMMARY                ", UVM_LOW)
        `uvm_info(get_type_name(), "==================================================================", UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("  Register Access Checks : Passed=%0d, Failed=%0d", reg_checks_passed, reg_checks_failed), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("  Waveform Cycle Checks  : Passed=%0d, Failed=%0d", waveform_checks_passed, waveform_checks_failed), UVM_LOW)
        if (reg_checks_failed == 0 && waveform_checks_failed == 0 && (reg_checks_passed + waveform_checks_passed > 0)) begin
            `uvm_info(get_type_name(), "  OVERALL SCOREBOARD RESULT: *** ALL CHECKS PASSED ***", UVM_LOW)
        end else begin
            `uvm_error(get_type_name(), "  OVERALL SCOREBOARD RESULT: *** SCOREBOARD CHECKS FAILED ***")
        end
        `uvm_info(get_type_name(), "==================================================================", UVM_LOW)
    endfunction

endclass : pwm_scoreboard

`endif // PWM_SCOREBOARD_SV

