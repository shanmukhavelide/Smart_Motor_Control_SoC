// =============================================================================
// Standalone PWM Functional Coverage Subscriber: pwm_coverage
// Samples AXI register transactions and physical PWM waveform observations
// =============================================================================

`ifndef PWM_COVERAGE_SV
`define PWM_COVERAGE_SV

class pwm_coverage extends uvm_subscriber #(pwm_item);

    // Analysis imp for AXI register transactions
    uvm_analysis_imp #(axi_lite_item, pwm_coverage) axi_export;

    // Internal sampled values
    bit [3:0]  cov_addr;
    bit [1:0]  cov_trans_type;
    bit [3:0]  cov_wstrb;
    bit [31:0] cov_wdata;
    bit [7:0]  cov_duty_val;
    int unsigned cov_period;
    real       cov_duty_pct;
    bit        cov_is_zero;
    bit        cov_is_max;

    // -------------------------------------------------------------------------
    // Covergroup 1: AXI Register Interface Coverage
    // -------------------------------------------------------------------------
    covergroup cg_axi_reg;
        option.per_instance = 1;
        option.name = "cg_axi_reg";

        cp_addr: coverpoint cov_addr {
            bins reg_duty   = {4'h0}; // slv_reg0 (PWM_DUTY)
            bins reg_slv1   = {4'h4}; // slv_reg1
            bins reg_slv2   = {4'h8}; // slv_reg2
            bins reg_slv3   = {4'hC}; // slv_reg3
        }

        cp_trans_type: coverpoint cov_trans_type {
            bins write = {1'b1};
            bins read  = {1'b0};
        }

        cp_wstrb: coverpoint cov_wstrb {
            bins full_word  = {4'b1111};
            bins byte0_only = {4'b0001};
            bins byte1_only = {4'b0010};
            bins byte2_only = {4'b0100};
            bins byte3_only = {4'b1000};
            bins half_word0 = {4'b0011};
            bins half_word1 = {4'b1100};
        }

        cp_duty_val: coverpoint cov_duty_val {
            bins zero        = {8'd0};
            bins low_range   = {[8'd1  : 8'd63]};
            bins duty_25     = {8'd64};
            bins mid_low     = {[8'd65 : 8'd127]};
            bins duty_50     = {8'd128};
            bins mid_high    = {[8'd129: 8'd191]};
            bins duty_75     = {8'd192};
            bins high_range  = {[8'd193: 8'd254]};
            bins max_duty    = {8'd255};
        }

        cross_addr_type: cross cp_addr, cp_trans_type;
        cross_reg0_duty: cross cp_addr, cp_duty_val {
            ignore_bins non_duty_regs = binsof(cp_addr) intersect {4'h4, 4'h8, 4'hC};
        }
    endgroup

    // -------------------------------------------------------------------------
    // Covergroup 2: PWM Output Waveform & Pin Activity Coverage
    // -------------------------------------------------------------------------
    covergroup cg_pwm_waveform;
        option.per_instance = 1;
        option.name = "cg_pwm_waveform";

        cp_period: coverpoint cov_period {
            bins std_256_cycles = {256};
            bins other_cycles   = default;
        }

        cp_duty_pct: coverpoint cov_duty_pct {
            bins zero_pct    = {0.0};
            bins low_pct     = {[0.1  : 24.9]};
            bins pct_25      = {25.0};
            bins mid_low_pct = {[25.1 : 49.9]};
            bins pct_50      = {50.0};
            bins mid_hi_pct  = {[50.1 : 74.9]};
            bins pct_75      = {75.0};
            bins high_pct    = {[75.1 : 99.5]};
            bins max_pct     = {[99.6 : 100.0]}; // 255/256 = 99.61%
        }

        cp_boundary: coverpoint cov_is_zero {
            bins zero_duty = {1'b1};
            bins non_zero  = {1'b0};
        }

        cp_max_boundary: coverpoint cov_is_max {
            bins max_duty = {1'b1};
            bins non_max  = {1'b0};
        }

        cross_period_duty: cross cp_period, cp_duty_pct;
    endgroup

    `uvm_component_utils(pwm_coverage)

    function new(string name = "pwm_coverage", uvm_component parent = null);
        super.new(name, parent);
        axi_export = new("axi_export", this);
        cg_axi_reg      = new();
        cg_pwm_waveform = new();
    endfunction

    // Called on incoming AXI transactions
    virtual function void write_axi(axi_lite_item tr);
        cov_addr       = tr.addr[3:0];
        cov_trans_type = (tr.trans_type == AXI_LITE_WRITE) ? 1'b1 : 1'b0;
        cov_wstrb      = tr.wstrb;
        cov_wdata      = tr.data;
        if (cov_addr == 4'h0 && cov_trans_type == 1'b1) begin
            cov_duty_val = tr.data[7:0];
        end
        cg_axi_reg.sample();
    endfunction

    // Called on incoming PWM waveform observations (via uvm_subscriber base)
    virtual function void write(pwm_item t);
        cov_period   = t.period_cycles;
        cov_duty_pct = t.duty_cycle_pct;
        cov_is_zero  = (t.high_cycles == 0 || t.is_constant_low);
        cov_is_max   = (t.high_cycles == 255 || t.is_constant_high);
        cg_pwm_waveform.sample();
    endfunction

endclass : pwm_coverage

`endif // PWM_COVERAGE_SV

