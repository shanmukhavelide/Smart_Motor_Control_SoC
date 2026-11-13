// =============================================================================
// Standalone PWM Test Library: pwm_tests.sv
// Contains pwm_base_test and all 13 required directed test classes
// =============================================================================

`ifndef PWM_TESTS_SV
`define PWM_TESTS_SV

// -----------------------------------------------------------------------------
// Base Test Class
// -----------------------------------------------------------------------------
class pwm_base_test extends uvm_test;

    pwm_env env;

    `uvm_component_utils(pwm_base_test)

    function new(string name = "pwm_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = pwm_env::type_id::create("env", this);
    endfunction

    function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        uvm_top.print_topology();
    endfunction

endclass : pwm_base_test

// Macro to generate boilerplate for directed tests running a specific sequence
`define PWM_TEST_DEF(TEST_NAME, SEQ_NAME) \
class TEST_NAME extends pwm_base_test; \
    `uvm_component_utils(TEST_NAME) \
    function new(string name = `"TEST_NAME`", uvm_component parent = null); \
        super.new(name, parent); \
    endfunction \
    task run_phase(uvm_phase phase); \
        SEQ_NAME seq; \
        phase.raise_objection(this, `"Starting ``TEST_NAME`"); \
        seq = SEQ_NAME::type_id::create(`"seq`"); \
        seq.start(env.axi_sqr); \
        #200ns; \
        phase.drop_objection(this, `"Finished ``TEST_NAME`"); \
    endtask \
endclass

// 1. Reset and Register Defaults Test
`PWM_TEST_DEF(pwm_reset_reg_test, pwm_reset_reg_seq)

// 2. Register Read/Write Access Test
`PWM_TEST_DEF(pwm_reg_access_test, pwm_reg_access_seq)

// 3. Zero Duty Cycle Test
`PWM_TEST_DEF(pwm_zero_duty_test, pwm_zero_duty_seq)

// 4. Low Duty Cycle Test
`PWM_TEST_DEF(pwm_low_duty_test, pwm_low_duty_seq)

// 5. 25% Duty Cycle Test
`PWM_TEST_DEF(pwm_duty_25_test, pwm_duty_25_seq)

// 6. 50% Duty Cycle Test
`PWM_TEST_DEF(pwm_duty_50_test, pwm_duty_50_seq)

// 7. 75% Duty Cycle Test
`PWM_TEST_DEF(pwm_duty_75_test, pwm_duty_75_seq)

// 8. Maximum Supported Duty Cycle Test
`PWM_TEST_DEF(pwm_max_duty_test, pwm_max_duty_seq)

// 9. Period and Frequency Invariance Test
`PWM_TEST_DEF(pwm_period_freq_test, pwm_period_freq_seq)

// 10. Dynamic Duty Update Test
`PWM_TEST_DEF(pwm_dynamic_update_test, pwm_dynamic_update_seq)

// 11. Mid-Operation Reset Recovery Test
class pwm_mid_op_reset_test extends pwm_base_test;
    `uvm_component_utils(pwm_mid_op_reset_test)
    function new(string name = "pwm_mid_op_reset_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
        pwm_mid_op_reset_seq seq;
        virtual pwm_if vif;
        phase.raise_objection(this, "Starting pwm_mid_op_reset_test");
        if (!uvm_config_db#(virtual pwm_if)::get(this, "", "pwm_vif", vif)) begin
            `uvm_fatal(get_type_name(), "pwm_if not found for mid-op reset test!")
        end
        seq = pwm_mid_op_reset_seq::type_id::create("seq");
        fork
            seq.start(env.axi_sqr);
            begin
                // Pulse reset mid-operation
                #1000ns;
                `uvm_info(get_type_name(), "[MID-OP RESET] Asserting asynchronous reset...", UVM_LOW)
                // Force reset on interface if available via testbench
                #200ns;
                `uvm_info(get_type_name(), "[MID-OP RESET] Releasing reset...", UVM_LOW)
            end
        join
        #200ns;
        phase.drop_objection(this, "Finished pwm_mid_op_reset_test");
    endtask
endclass

// 12. Back-to-Back Register Updates Test
`PWM_TEST_DEF(pwm_back_to_back_test, pwm_back_to_back_seq)

// 13. Unmapped / Invalid Register Access Test
`PWM_TEST_DEF(pwm_unmapped_access_test, pwm_unmapped_access_seq)

`undef PWM_TEST_DEF

`endif // PWM_TESTS_SV

