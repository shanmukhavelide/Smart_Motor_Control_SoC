// =============================================================================
// Reusable AXI4-Lite Master Agent: axi_lite_agent
// Houses sequencer and driver for active AXI4-Lite master stimulus
// Parameterized address and data widths (default ADDR=32, DATA=32)
// =============================================================================

`ifndef AXI_LITE_AGENT_SV
`define AXI_LITE_AGENT_SV

class axi_lite_agent #(
    int ADDR_WIDTH = 32,
    int DATA_WIDTH = 32
) extends uvm_agent;

    typedef virtual axi_lite_if #(ADDR_WIDTH, DATA_WIDTH) vif_t;
    vif_t vif;

    axi_lite_sequencer                        sqr;
    axi_lite_driver #(ADDR_WIDTH, DATA_WIDTH) drv;

    // Analysis port forwarding driver's transaction stream
    uvm_analysis_port #(axi_lite_item) ap;

    `uvm_component_param_utils(axi_lite_agent#(ADDR_WIDTH, DATA_WIDTH))

    function new(string name = "axi_lite_agent", uvm_component parent = null);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (get_is_active() == UVM_ACTIVE) begin
            if (!uvm_config_db#(vif_t)::get(this, "", "vif", vif)) begin
                `uvm_fatal(get_type_name(),
                    $sformatf("Virtual interface axi_lite_if#(%0d,%0d) not found in uvm_config_db at %s!",
                              ADDR_WIDTH, DATA_WIDTH, get_full_name()))
            end
            sqr = axi_lite_sequencer::type_id::create("sqr", this);
            drv = axi_lite_driver#(ADDR_WIDTH, DATA_WIDTH)::type_id::create("drv", this);
            uvm_config_db#(vif_t)::set(this, "drv", "vif", vif);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (get_is_active() == UVM_ACTIVE) begin
            drv.vif = this.vif;
            drv.seq_item_port.connect(sqr.seq_item_export);
            drv.drv_ap.connect(this.ap);
        end
    endfunction

endclass : axi_lite_agent

`endif // AXI_LITE_AGENT_SV
