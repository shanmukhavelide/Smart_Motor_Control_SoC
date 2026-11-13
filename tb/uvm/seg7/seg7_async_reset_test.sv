// =============================================================================
// SEG7 Asynchronous Reset UVM Test: seg7_async_reset_test
// Instantiates seg7_env under instance name "env", creates seg7_async_reset_seq,
// binds scoreboard and virtual interface handles, and executes sequence on env.axi_sqr.
// Invocation: +UVM_TESTNAME=seg7_async_reset_test
// =============================================================================

`ifndef SEG7_ASYNC_RESET_TEST_SV
`define SEG7_ASYNC_RESET_TEST_SV

class seg7_async_reset_test extends uvm_test;

    // Test environment handle (instance name strictly "env")
    seg7_env env;

    `uvm_component_utils(seg7_async_reset_test)

    function new(string name = "seg7_async_reset_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = seg7_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        seg7_async_reset_seq seq;
        seq = seg7_async_reset_seq::type_id::create("seq");

        // Bind scoreboard handle
        seq.sb = env.sb;

        // Retrieve and bind SEG7 virtual interface via monitor handle or uvm_config_db
        if (env.seg7_agent != null && env.seg7_agent.mon != null) begin
            seq.vif = env.seg7_agent.mon.vif;
        end
        if (seq.vif == null) begin
            void'(uvm_config_db#(virtual seg7_vip_if)::get(this, "env.seg7_agent.mon", "vif", seq.vif));
        end
        if (seq.vif == null) begin
            void'(uvm_config_db#(virtual seg7_vip_if)::get(null, "*.seg7_agent*", "vif", seq.vif));
        end

        phase.raise_objection(this, "Starting SEG7 async reset test");
        `uvm_info(get_type_name(), "--- Starting seg7_async_reset_test on env.axi_sqr ---", UVM_LOW)

        seq.start(env.axi_sqr);

        `uvm_info(get_type_name(), "--- Completed seg7_async_reset_test successfully ---", UVM_LOW)
        phase.drop_objection(this, "Finished SEG7 async reset test");
    endtask

endclass : seg7_async_reset_test

`endif // SEG7_ASYNC_RESET_TEST_SV
