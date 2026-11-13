// =============================================================================
// Standalone PWM Output Monitor: pwm_monitor
// Passively measures waveform period, high time, low time, and duty cycle.
// Explicitly handles constant-low (0% duty) and constant-high cases without hanging.
// =============================================================================

`ifndef PWM_MONITOR_SV
`define PWM_MONITOR_SV

class pwm_monitor extends uvm_monitor;

    virtual pwm_if vif;
    uvm_analysis_port #(pwm_item) ap;

    // Configuration parameters
    int unsigned expected_period = 256;

    `uvm_component_utils_begin(pwm_monitor)
        `uvm_field_int(expected_period, UVM_ALL_ON | UVM_DEC)
    `uvm_component_utils_end

    function new(string name = "pwm_monitor", uvm_component parent = null);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual pwm_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal(get_type_name(), "Virtual interface pwm_if not found in uvm_config_db under 'vif'!")
        end
    endfunction

    task run_phase(uvm_phase phase);
        int unsigned h_count = 0;
        int unsigned l_count = 0;
        int unsigned flat_zero_count = 0;
        int unsigned flat_one_count  = 0;
        bit prev_val = 0;
        bit measuring = 0;
        pwm_item item;

        // Reset check
        @(posedge vif.clk);
        if (!vif.rst_n) begin
            if (vif.pwm_out !== 1'b0) begin
                `uvm_error(get_type_name(), $sformatf("PWM output violated reset: expected 0 while rst_n=0, observed %b", vif.pwm_out))
            end
        end

        wait (vif.rst_n === 1'b1);
        `uvm_info(get_type_name(), "PWM Monitor active and tracking output waveform...", UVM_MEDIUM)

        forever begin
            @(posedge vif.clk);
            #1ps; // Sample after synchronous NBA updates

            // If reset asserted mid-run
            if (!vif.rst_n) begin
                h_count = 0;
                l_count = 0;
                flat_zero_count = 0;
                flat_one_count  = 0;
                measuring = 0;
                prev_val = vif.pwm_out;
                if (vif.pwm_out !== 1'b0) begin
                    `uvm_error(get_type_name(), "PWM output must be 0 while reset is active!")
                end
                continue;
            end

            // Check for edge transitions
            if (prev_val === 1'b0 && vif.pwm_out === 1'b1) begin
                // Rising Edge detected
                flat_zero_count = 0;
                if (measuring && (h_count > 0 || l_count > 0)) begin
                    // Completed a period
                    item = pwm_item::type_id::create("item");
                    item.high_cycles      = h_count;
                    item.low_cycles       = l_count;
                    item.period_cycles    = h_count + l_count;
                    item.duty_cycle_pct   = (real'(h_count) * 100.0) / real'(item.period_cycles);
                    item.duty_reg_val     = h_count;
                    item.is_constant_low  = 0;
                    item.is_constant_high = 0;
                    item.sample_time      = $time;
                    item.glitch_detected  = (item.period_cycles != expected_period);

                    `uvm_info(get_type_name(), item.convert2string(), UVM_HIGH)
                    ap.write(item);
                end
                h_count   = 1;
                l_count   = 0;
                measuring = 1;
            end else if (prev_val === 1'b1 && vif.pwm_out === 1'b0) begin
                // Falling Edge detected
                flat_one_count = 0;
                if (measuring) begin
                    l_count = 1;
                end
            end else if (vif.pwm_out === 1'b1) begin
                // Continuously High
                if (measuring) begin
                    h_count++;
                    if (h_count >= expected_period) begin
                        item = pwm_item::type_id::create("item");
                        item.high_cycles      = expected_period;
                        item.low_cycles       = 0;
                        item.period_cycles    = expected_period;
                        item.duty_cycle_pct   = 100.0;
                        item.duty_reg_val     = expected_period;
                        item.is_constant_high = 1;
                        item.sample_time      = $time;
                        `uvm_info(get_type_name(), item.convert2string(), UVM_HIGH)
                        ap.write(item);
                        measuring = 0;
                        h_count = 0;
                        l_count = 0;
                        flat_one_count = 0;
                    end
                end else begin
                    flat_one_count++;
                    if (flat_one_count >= expected_period) begin
                        item = pwm_item::type_id::create("item");
                        item.high_cycles      = expected_period;
                        item.low_cycles       = 0;
                        item.period_cycles    = expected_period;
                        item.duty_cycle_pct   = 100.0;
                        item.duty_reg_val     = expected_period;
                        item.is_constant_high = 1;
                        item.sample_time      = $time;
                        `uvm_info(get_type_name(), item.convert2string(), UVM_HIGH)
                        ap.write(item);
                        flat_one_count = 0;
                    end
                end
            end else begin
                // Continuously Low (0% Duty Case)
                if (measuring && l_count > 0) begin
                    l_count++;
                    // If low cycles reach full period without a rising edge, duty transitioned to 0%
                    if (l_count >= expected_period) begin
                        item = pwm_item::type_id::create("item");
                        item.high_cycles     = 0;
                        item.low_cycles      = expected_period;
                        item.period_cycles   = expected_period;
                        item.duty_cycle_pct  = 0.0;
                        item.duty_reg_val    = 0;
                        item.is_constant_low = 1;
                        item.sample_time     = $time;
                        `uvm_info(get_type_name(), item.convert2string(), UVM_HIGH)
                        ap.write(item);
                        measuring = 0;
                        h_count = 0;
                        l_count = 0;
                        flat_zero_count = 0;
                    end
                end else begin
                    flat_zero_count++;
                    if (flat_zero_count >= expected_period) begin
                        // 0% constant duty cycle confirmed over full 256 cycle period
                        item = pwm_item::type_id::create("item");
                        item.high_cycles     = 0;
                        item.low_cycles      = expected_period;
                        item.period_cycles   = expected_period;
                        item.duty_cycle_pct  = 0.0;
                        item.duty_reg_val    = 0;
                        item.is_constant_low = 1;
                        item.sample_time     = $time;
                        `uvm_info(get_type_name(), item.convert2string(), UVM_HIGH)
                        ap.write(item);
                        flat_zero_count = 0;
                    end
                end
            end

            prev_val = vif.pwm_out;
        end
    endtask

endclass : pwm_monitor

`endif // PWM_MONITOR_SV

