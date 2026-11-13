// =============================================================================
// Smart ControlSoC - Virtual Sequencer: soc_virtual_sequencer.sv
// Coordinates peripheral VIP sequencers and CPU BFM interface
// =============================================================================

`ifndef SOC_VIRTUAL_SEQUENCER_SV
`define SOC_VIRTUAL_SEQUENCER_SV

class soc_virtual_sequencer extends uvm_sequencer;
    `uvm_component_utils(soc_virtual_sequencer)

    // Sub-sequencer handles
    uart_vip_sequencer uart_sqr;
    gpio_vip_sequencer gpio_sqr;
    spi_vip_sequencer  spi_sqr;

    // CPU BFM interface handle for driving LSU AXI transactions
    virtual cpu_bfm_if cpu_vif;

    function new(string name = "soc_virtual_sequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction

endclass : soc_virtual_sequencer

`endif // SOC_VIRTUAL_SEQUENCER_SV

