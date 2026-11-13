// =============================================================================
// SEG7 Integrated UVM Environment: seg7_env
// Integrates active AXI4-Lite master agent, passive SEG7 display monitor agent,
// and SEG7 display & dwell scoreboard.
// =============================================================================

`ifndef SEG7_ENV_SV
`define SEG7_ENV_SV

class seg7_env extends uvm_env;

    // Active AXI4-Lite Master Agent (12-bit address for SEG7 peripheral, 32-bit data)
    axi_lite_agent #(12, 32) axi_agent;

    // Passive SEG7 Display Monitor Agent
    seg7_vip_agent           seg7_agent;

    // SEG7 Display Image & Timing Scoreboard
    seg7_vip_scoreboard      sb;

    // Functional Coverage Subscriber
    seg7_coverage            cov;

    // Exposed sequencer handle for sequence execution
    axi_lite_sequencer       axi_sqr;

    `uvm_component_utils(seg7_env)

    function new(string name = "seg7_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        virtual seg7_vip_if seg7_vif;
        super.build_phase(phase);

        // Propagate SEG7 virtual interface if configured at the seg7_agent scope
        if (uvm_config_db#(virtual seg7_vip_if)::get(this, "seg7_agent", "vif", seg7_vif)) begin
            uvm_config_db#(virtual seg7_vip_if)::set(this, "seg7_agent.mon", "vif", seg7_vif);
        end

        // Instantiate sub-components
        axi_agent  = axi_lite_agent#(12, 32)::type_id::create("axi_agent", this);
        seg7_agent = seg7_vip_agent::type_id::create("seg7_agent", this);
        sb         = seg7_vip_scoreboard::type_id::create("sb", this);
        cov        = seg7_coverage::type_id::create("cov", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // Connect SEG7 monitor analysis port to scoreboard analysis imp
        seg7_agent.mon.ap.connect(sb.mon_imp);

        // Connect analysis ports to functional coverage subscriber
        axi_agent.ap.connect(cov.axi_export);
        seg7_agent.mon.ap.connect(cov.display_export);

        // Expose AXI sequencer handle for sequence execution
        axi_sqr = axi_agent.sqr;
    endfunction

endclass : seg7_env

`endif // SEG7_ENV_SV

