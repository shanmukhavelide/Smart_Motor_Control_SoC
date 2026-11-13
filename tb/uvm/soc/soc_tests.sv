// =============================================================================
// Smart ControlSoC - SoC Test Library: soc_tests.sv
// Contains soc_base_test and all 11 required SoC verification tests
// =============================================================================

`ifndef SOC_TESTS_SV
`define SOC_TESTS_SV

class soc_base_test extends uvm_test;
    soc_env env;
    soc_config cfg;

    `uvm_component_utils(soc_base_test)

    function new(string name = "soc_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = soc_env::type_id::create("env", this);
    endfunction

    function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        uvm_top.print_topology();
    endfunction
endclass : soc_base_test

// Macro for standard virtual sequence launch
`define SOC_TEST_DEF(TEST_NAME, SEQ_NAME) \
class TEST_NAME extends soc_base_test; \
    `uvm_component_utils(TEST_NAME) \
    function new(string name = `"TEST_NAME`", uvm_component parent = null); \
        super.new(name, parent); \
    endfunction \
    task run_phase(uvm_phase phase); \
        SEQ_NAME seq; \
        phase.raise_objection(this, `"Starting ``TEST_NAME`"); \
        seq = SEQ_NAME::type_id::create(`"seq`"); \
        seq.start(env.v_sqr); \
        #500ns; \
        phase.drop_objection(this, `"Finished ``TEST_NAME`"); \
    endtask \
endclass

// 1. SoC Reset Test
`SOC_TEST_DEF(soc_reset_test, soc_reset_seq)

// 2. Peripheral Register-Access Smoke Test
`SOC_TEST_DEF(soc_smoke_test, soc_smoke_seq)

// 3. UART Test
`SOC_TEST_DEF(soc_uart_test, soc_uart_seq)

// 4. GPIO Test
`SOC_TEST_DEF(soc_gpio_test, soc_gpio_seq)

// 5. Timer Test
`SOC_TEST_DEF(soc_timer_test, soc_timer_seq)

// 6. SPI Test
`SOC_TEST_DEF(soc_spi_test, soc_spi_seq)

// 7. PWM Test
`SOC_TEST_DEF(soc_pwm_test, soc_pwm_seq)

// 8. SEG7 Test
`SOC_TEST_DEF(soc_seg7_test, soc_seg7_seq)

// 9. Multi-Peripheral Access Test
`SOC_TEST_DEF(soc_multi_peripheral_test, soc_multi_peripheral_seq)

// 10. Concurrent Peripheral Activity Test
`SOC_TEST_DEF(soc_concurrent_test, soc_concurrent_seq)

// 11. Reset Recovery Test
`SOC_TEST_DEF(soc_reset_recovery_test, soc_reset_recovery_seq)

// Default / Legacy alias
`SOC_TEST_DEF(soc_test, soc_multi_peripheral_seq)

`undef SOC_TEST_DEF

`endif // SOC_TESTS_SV

