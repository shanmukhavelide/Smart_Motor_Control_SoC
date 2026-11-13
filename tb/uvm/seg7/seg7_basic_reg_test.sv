// =============================================================================
// SEG7 Basic Register UVM Test: seg7_basic_reg_test
// Instantiates seg7_env under name "env", creates seg7_basic_reg_seq,
// and executes it on env.axi_sqr.
// Invocation: +UVM_TESTNAME=seg7_basic_reg_test
// =============================================================================

`ifndef SEG7_BASIC_REG_TEST_SV
`define SEG7_BASIC_REG_TEST_SV

class seg7_basic_reg_test extends uvm_test;

    // Test environment handle (instance name strictly "env")
    seg7_env env;

    `uvm_component_utils(seg7_basic_reg_test)

    function new(string name = "seg7_basic_reg_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = seg7_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        seg7_basic_reg_seq seq;
        seq = seg7_basic_reg_seq::type_id::create("seq");

        phase.raise_objection(this, "Starting SEG7 basic register test");
        `uvm_info(get_type_name(), "--- Starting seg7_basic_reg_test on env.axi_sqr ---", UVM_LOW)

        seq.start(env.axi_sqr);

        `uvm_info(get_type_name(), "--- Completed seg7_basic_reg_test successfully ---", UVM_LOW)
        phase.drop_objection(this, "Finished SEG7 basic register test");
    endtask

endclass : seg7_basic_reg_test

`endif // SEG7_BASIC_REG_TEST_SV

