// =============================================================================
// Standalone PWM Base Sequence: pwm_base_seq
// Provides reusable tasks for reading, writing, and configuring the PWM core
// =============================================================================

`ifndef PWM_BASE_SEQ_SV
`define PWM_BASE_SEQ_SV

class pwm_base_seq extends uvm_sequence #(axi_lite_item);

    `uvm_object_utils(pwm_base_seq)

    function new(string name = "pwm_base_seq");
        super.new(name);
    endfunction

    // -------------------------------------------------------------------------
    // AXI-Lite Write Task
    // -------------------------------------------------------------------------
    virtual task axi_write(
        input bit [3:0]  addr,
        input bit [31:0] data,
        input bit [3:0]  wstrb = 4'hF,
        input bit [2:0]  prot  = 3'b000
    );
        axi_lite_item req = axi_lite_item::type_id::create("req");
        start_item(req);
        req.trans_type = AXI_LITE_WRITE;
        req.addr       = {28'h0, addr};
        req.data       = data;
        req.wstrb      = wstrb;
        req.prot       = prot;
        finish_item(req);
    endtask

    // -------------------------------------------------------------------------
    // AXI-Lite Read Task
    // -------------------------------------------------------------------------
    virtual task axi_read(
        input  bit [3:0]  addr,
        output bit [31:0] rdata,
        output bit [1:0]  resp,
        input  bit [2:0]  prot = 3'b000
    );
        axi_lite_item req = axi_lite_item::type_id::create("req");
        start_item(req);
        req.trans_type = AXI_LITE_READ;
        req.addr       = {28'h0, addr};
        req.prot       = prot;
        finish_item(req);
        rdata = req.data;
        resp  = req.resp;
    endtask

    // -------------------------------------------------------------------------
    // Set Duty Cycle Helper Task
    // -------------------------------------------------------------------------
    virtual task set_duty(input bit [7:0] duty);
        `uvm_info(get_type_name(), $sformatf("Setting PWM duty cycle to 0x%02h (%0d/256 = %0.2f%%)",
                  duty, duty, (duty * 100.0) / 256.0), UVM_MEDIUM)
        axi_write(4'h0, {24'h0, duty}, 4'hF);
    endtask

    // -------------------------------------------------------------------------
    // Wait for Clock Cycles
    // -------------------------------------------------------------------------
    virtual task wait_cycles(int unsigned n);
        repeat (n) #10ns;
    endtask

endclass : pwm_base_seq

`endif // PWM_BASE_SEQ_SV

