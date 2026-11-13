// =============================================================================
// Standalone SPI Verification Environment: spi_env.sv
// Integrates active AXI-Lite master agent, SPI slave responder model,
// passive SPI protocol monitor, scoreboard, and functional coverage subscriber.
// =============================================================================

`ifndef SPI_ENV_SV
`define SPI_ENV_SV

class spi_env extends uvm_env;

    // Active AXI4-Lite Master Agent (7-bit address for SPI slave, 32-bit data)
    axi_lite_agent #(7, 32) axi_agent;

    // Reactive SPI Slave Model
    spi_slave_model         slave_mdl;

    // Passive SPI Protocol Monitor
    spi_monitor             spi_mon;

    // SPI Scoreboard
    spi_scoreboard          sb;

    // Functional Coverage Subscriber
    spi_coverage            cov;

    // Exposed sequencer handle
    axi_lite_sequencer      axi_sqr;

    `uvm_component_utils(spi_env)

    function new(string name = "spi_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        virtual spi_if spi_vif;
        super.build_phase(phase);

        // Propagate SPI virtual interface if configured at env scope
        if (uvm_config_db#(virtual spi_if)::get(this, "", "spi_vif", spi_vif)) begin
            uvm_config_db#(virtual spi_if)::set(this, "slave_mdl", "vif", spi_vif);
            uvm_config_db#(virtual spi_if)::set(this, "spi_mon",   "vif", spi_vif);
        end

        axi_agent = axi_lite_agent#(7, 32)::type_id::create("axi_agent", this);
        slave_mdl = spi_slave_model::type_id::create("slave_mdl", this);
        spi_mon   = spi_monitor::type_id::create("spi_mon", this);
        sb        = spi_scoreboard::type_id::create("sb", this);
        cov       = spi_coverage::type_id::create("cov", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // Connect AXI transactions to scoreboard and coverage
        axi_agent.ap.connect(sb.axi_imp);
        axi_agent.ap.connect(cov.axi_export);

        // Connect SPI monitor transactions to scoreboard and coverage
        spi_mon.ap.connect(sb.spi_imp);
        spi_mon.ap.connect(cov.analysis_export);

        // Expose sequencer
        axi_sqr = axi_agent.sqr;
    endfunction

endclass : spi_env

`endif // SPI_ENV_SV

