// =============================================================================
// SEG7 Refresh Divider Boundary UVM Test: seg7_refresh_boundary_test
// Instantiates seg7_env under instance name "env", creates seg7_refresh_boundary_seq,
// connects scoreboard handle, and executes sequence on env.axi_sqr.
// Invocation: +UVM_TESTNAME=seg7_refresh_boundary_test
// =============================================================================

`ifndef SEG7_REFRESH_BOUNDARY_TEST_SV
`define SEG7_REFRESH_BOUNDARY_TEST_SV

class seg7_refresh_boundary_test extends uvm_test;

    // Test environment handle (instance name strictly "env")
    seg7_env env;

    `uvm_component_utils(seg7_refresh_boundary_test)

    function new(string name = "seg7_refresh_boundary_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = seg7_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        seg7_refresh_boundary_seq seq;
        seq = seg7_refresh_boundary_seq::type_id::create("seq");

        // Pass scoreboard handle explicitly to sequence for observation window and checks
        seq.sb = env.sb;

        phase.raise_objection(this, "Starting SEG7 refresh boundary test");
        `uvm_info(get_type_name(), "--- Starting seg7_refresh_boundary_test on env.axi_sqr ---", UVM_LOW)

        seq.start(env.axi_sqr);

        `uvm_info(get_type_name(), "--- Completed seg7_refresh_boundary_test successfully ---", UVM_LOW)
        phase.drop_objection(this, "Finished SEG7 refresh boundary test");
    endtask

endclass : seg7_refresh_boundary_test

`endif // SEG7_REFRESH_BOUNDARY_TEST_SV

