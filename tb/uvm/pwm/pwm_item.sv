// =============================================================================
// Standalone PWM Sequence Item / Transaction: pwm_item
// Represents measured output waveform cycle parameters
// =============================================================================

`ifndef PWM_ITEM_SV
`define PWM_ITEM_SV

class pwm_item extends uvm_sequence_item;

    int unsigned high_cycles;
    int unsigned low_cycles;
    int unsigned period_cycles;
    real         duty_cycle_pct;
    int unsigned duty_reg_val;
    bit          is_constant_low;
    bit          is_constant_high;
    bit          glitch_detected;
    time         sample_time;

    `uvm_object_utils_begin(pwm_item)
        `uvm_field_int(high_cycles,      UVM_ALL_ON | UVM_DEC)
        `uvm_field_int(low_cycles,       UVM_ALL_ON | UVM_DEC)
        `uvm_field_int(period_cycles,    UVM_ALL_ON | UVM_DEC)
        `uvm_field_real(duty_cycle_pct,  UVM_ALL_ON)
        `uvm_field_int(duty_reg_val,     UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(is_constant_low,  UVM_ALL_ON | UVM_BIN)
        `uvm_field_int(is_constant_high, UVM_ALL_ON | UVM_BIN)
        `uvm_field_int(glitch_detected,  UVM_ALL_ON | UVM_BIN)
        `uvm_field_time(sample_time,     UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "pwm_item");
        super.new(name);
        high_cycles      = 0;
        low_cycles       = 0;
        period_cycles    = 0;
        duty_cycle_pct   = 0.0;
        duty_reg_val     = 0;
        is_constant_low  = 0;
        is_constant_high = 0;
        glitch_detected  = 0;
        sample_time      = 0;
    endfunction

    virtual function string convert2string();
        if (is_constant_low) begin
            return $sformatf("[PWM CONSTANT LOW (0%%)] Sampled at %0t ps over %0d cycles (Duty: 0.00%%)", 
                             sample_time, period_cycles);
        end else if (is_constant_high) begin
            return $sformatf("[PWM CONSTANT HIGH (100%%)] Sampled at %0t ps over %0d cycles (Duty: 100.00%%)", 
                             sample_time, period_cycles);
        end else begin
            return $sformatf("[PWM CYCLE] Period=%0d clks, High=%0d clks, Low=%0d clks (Duty: %0.2f%%, RegVal: 0x%02h) at %0t ps",
                             period_cycles, high_cycles, low_cycles, duty_cycle_pct, duty_reg_val, sample_time);
        end
    endfunction

endclass : pwm_item

`endif // PWM_ITEM_SV

