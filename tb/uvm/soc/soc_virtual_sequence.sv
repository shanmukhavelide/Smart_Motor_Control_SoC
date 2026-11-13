// =============================================================================
// Smart ControlSoC - Base Virtual Sequence: soc_virtual_sequence.sv
// Provides MMIO read/write tasks driving VeeR CPU LSU AXI Master Port S00
// =============================================================================

`ifndef SOC_VIRTUAL_SEQUENCE_SV
`define SOC_VIRTUAL_SEQUENCE_SV

class soc_virtual_sequence extends uvm_sequence;
    `uvm_object_utils(soc_virtual_sequence)
    `uvm_declare_p_sequencer(soc_virtual_sequencer)

    function new(string name = "soc_virtual_sequence");
        super.new(name);
    endfunction

    // MMIO 32-bit Write via CPU BFM
    task mmio_write(input [31:0] addr, input [31:0] data, input [3:0] strb = 4'hF);
        p_sequencer.cpu_vif.cpu_write(addr, data, strb);
    endtask

    // MMIO 32-bit Read via CPU BFM
    task mmio_read(input [31:0] addr, output [31:0] data);
        p_sequencer.cpu_vif.cpu_read(addr, data);
    endtask

    // Delay helper
    task wait_cycles(int unsigned n);
        repeat (n) @(posedge p_sequencer.cpu_vif.clk);
    endtask

endclass : soc_virtual_sequence

`endif // SOC_VIRTUAL_SEQUENCE_SV

