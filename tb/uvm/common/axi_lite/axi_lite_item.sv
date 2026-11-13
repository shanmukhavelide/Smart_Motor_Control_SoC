// =============================================================================
// Reusable AXI4-Lite Sequence Item: axi_lite_item
// Models read and write transactions with full channel attribute visibility
// =============================================================================

`ifndef AXI_LITE_ITEM_SV
`define AXI_LITE_ITEM_SV

class axi_lite_item extends uvm_sequence_item;

    // Transaction parameters
    rand axi_lite_trans_type_e trans_type;
    rand bit [31:0]            addr;
    rand bit [31:0]            data;
    rand bit [3:0]             strb;
    rand bit [2:0]             prot;

    // Response and status
    axi_lite_resp_e            resp;
    bit [31:0]                 rdata;
    bit                        is_error;
    int                        timeout_cycles;

    // Soft constraints
    constraint default_trans_type {
        soft trans_type == AXI_LITE_WRITE;
    }

    constraint default_strb {
        soft strb == 4'hF;
    }

    constraint default_prot {
        soft prot == 3'b000;
    }

    constraint default_addr_align {
        soft addr[1:0] == 2'b00; // 32-bit word aligned
    }

    `uvm_object_utils_begin(axi_lite_item)
        `uvm_field_enum(axi_lite_trans_type_e, trans_type, UVM_ALL_ON)
        `uvm_field_int(addr,            UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(data,            UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(strb,            UVM_ALL_ON | UVM_BIN)
        `uvm_field_int(prot,            UVM_ALL_ON | UVM_BIN)
        `uvm_field_enum(axi_lite_resp_e, resp,             UVM_ALL_ON)
        `uvm_field_int(rdata,           UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(is_error,        UVM_ALL_ON | UVM_BIN)
        `uvm_field_int(timeout_cycles,  UVM_ALL_ON | UVM_DEC)
    `uvm_object_utils_end

    function new(string name = "axi_lite_item");
        super.new(name);
        trans_type     = AXI_LITE_WRITE;
        addr           = 32'h0;
        data           = 32'h0;
        strb           = 4'hF;
        prot           = 3'b000;
        resp           = AXI_LITE_RESP_OKAY;
        rdata          = 32'h0;
        is_error       = 1'b0;
        timeout_cycles = 1000;
    endfunction

    // Helper functions for sequence readability
    virtual function string convert2string();
        if (trans_type == AXI_LITE_WRITE) begin
            return $sformatf("WRITE addr=0x%08h data=0x%08h strb=0x%1h prot=3'b%03b resp=%s err=%0d",
                            addr, data, strb, prot, resp.name(), is_error);
        end else begin
            return $sformatf("READ  addr=0x%08h rdata=0x%08h prot=3'b%03b resp=%s err=%0d",
                            addr, rdata, prot, resp.name(), is_error);
        end
    endfunction

endclass : axi_lite_item

`endif // AXI_LITE_ITEM_SV

