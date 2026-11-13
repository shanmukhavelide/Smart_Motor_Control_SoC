// =============================================================================
// Reusable AXI4-Lite Base Sequence for SEG7: seg7_base_seq
// Provides register write, read, and read-check tasks for SEG7 sequences.
// Compatible with axi_lite_item and axi_lite_sequencer.
// =============================================================================

`ifndef SEG7_BASE_SEQ_SV
`define SEG7_BASE_SEQ_SV

class seg7_base_seq extends uvm_sequence #(axi_lite_item);

    // -------------------------------------------------------------------------
    // SEG7 Memory-Mapped Register Offsets (Local 12-bit address space)
    // -------------------------------------------------------------------------
    localparam bit [31:0] REG_SEG_DATA        = 32'h000;
    localparam bit [31:0] REG_SEG_CTRL        = 32'h004;
    localparam bit [31:0] REG_SEG_DP          = 32'h008;
    localparam bit [31:0] REG_SEG_REFRESH_DIV = 32'h00C;

    // SEG_CTRL Bitfields
    localparam bit [31:0] SEG_CTRL_EN         = 32'h0000_0001; // [0]   Display enable
    localparam bit [31:0] SEG_CTRL_SEG_ACT_LO = 32'h0000_0002; // [1]   Cathode/segment active-low
    localparam bit [31:0] SEG_CTRL_AN_ACT_LO  = 32'h0000_0004; // [2]   Anode active-low
    localparam int        SEG_CTRL_MASK_SHIFT = 8;             // [15:8] Digit enable mask

    `uvm_object_utils(seg7_base_seq)
    `uvm_declare_p_sequencer(axi_lite_sequencer)

    function new(string name = "seg7_base_seq");
        super.new(name);
    endfunction

    // -------------------------------------------------------------------------
    // Write Tasks
    // -------------------------------------------------------------------------
    // Executes write transaction and returns response status (for error testing)
    virtual task write_reg_status(
        input  bit [31:0]       addr,
        input  bit [31:0]       data,
        input  bit [3:0]        strb,
        output axi_lite_resp_e  resp,
        output bit              is_error
    );
        axi_lite_item item;
        item = axi_lite_item::type_id::create("axi_write_item");
        start_item(item);
        item.trans_type = AXI_LITE_WRITE;
        item.addr       = addr;
        item.data       = data;
        item.strb       = strb; // Preserves 4'h0 if explicitly requested
        item.prot       = 3'b000;
        finish_item(item);

        resp     = item.resp;
        is_error = item.is_error;
    endtask

    // Standard write: checks for OKAY response and logs uvm_error on failure
    virtual task write_reg(
        input bit [31:0] addr,
        input bit [31:0] data,
        input bit [3:0]  strb = 4'hF
    );
        axi_lite_resp_e resp;
        bit             is_error;

        write_reg_status(addr, data, strb, resp, is_error);

        if (is_error || resp != AXI_LITE_RESP_OKAY) begin
            `uvm_error(get_type_name(),
                $sformatf("AXI WRITE failed: addr=0x%03h, data=0x%08h, strb=0x%1h -> resp=%s (error=%0d)",
                          addr, data, strb, resp.name(), is_error))
        end else begin
            `uvm_info(get_type_name(),
                $sformatf("AXI WRITE success: addr=0x%03h, data=0x%08h, strb=0x%1h -> OKAY",
                          addr, data, strb),
                UVM_HIGH)
        end
    endtask

    // -------------------------------------------------------------------------
    // Read Tasks
    // -------------------------------------------------------------------------
    // Executes read transaction and returns raw data and response status
    virtual task read_reg_status(
        input  bit [31:0]       addr,
        output bit [31:0]       data,
        output axi_lite_resp_e  resp,
        output bit              is_error
    );
        axi_lite_item item;
        item = axi_lite_item::type_id::create("axi_read_item");
        start_item(item);
        item.trans_type = AXI_LITE_READ;
        item.addr       = addr;
        item.prot       = 3'b000;
        finish_item(item);

        data     = item.data;
        resp     = item.resp;
        is_error = item.is_error;
    endtask

    // Standard read: returns data and verifies OKAY response
    virtual task read_reg(
        input  bit [31:0] addr,
        output bit [31:0] data
    );
        axi_lite_resp_e resp;
        bit             is_error;

        read_reg_status(addr, data, resp, is_error);

        if (is_error || resp != AXI_LITE_RESP_OKAY) begin
            `uvm_error(get_type_name(),
                $sformatf("AXI READ failed: addr=0x%03h -> resp=%s (error=%0d)",
                          addr, resp.name(), is_error))
        end else begin
            `uvm_info(get_type_name(),
                $sformatf("AXI READ success: addr=0x%03h -> data=0x%08h",
                          addr, data),
                UVM_HIGH)
        end
    endtask

    // Read and verify data against expected value with optional bitmask
    virtual task read_check(
        input bit [31:0]      addr,
        input bit [31:0]      exp_data,
        input bit [31:0]      mask = 32'hFFFF_FFFF,
        input axi_lite_resp_e exp_resp = AXI_LITE_RESP_OKAY
    );
        bit [31:0]      act_data;
        axi_lite_resp_e act_resp;
        bit             is_error;

        read_reg_status(addr, act_data, act_resp, is_error);

        if (act_resp != exp_resp) begin
            `uvm_error(get_type_name(),
                $sformatf("AXI READ response mismatch at addr=0x%03h: expected=%s, actual=%s (error=%0d)",
                          addr, exp_resp.name(), act_resp.name(), is_error))
        end else if ((act_data & mask) !== (exp_data & mask)) begin
            `uvm_error(get_type_name(),
                $sformatf("AXI READ data mismatch at addr=0x%03h: expected=0x%08h, actual=0x%08h (mask=0x%08h)",
                          addr, (exp_data & mask), (act_data & mask), mask))
        end else begin
            `uvm_info(get_type_name(),
                $sformatf("AXI READ check passed: addr=0x%03h, data=0x%08h matches expected 0x%08h (mask=0x%08h)",
                          addr, act_data, exp_data, mask),
                UVM_HIGH)
        end
    endtask

endclass : seg7_base_seq

`endif // SEG7_BASE_SEQ_SV

