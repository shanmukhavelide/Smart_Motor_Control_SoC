// =============================================================================
// Standalone PWM Verification Environment: pwm_env
// Integrates active AXI-Lite master agent, passive PWM pin monitor,
// scoreboard, and functional coverage subscriber.
// =============================================================================

`ifndef PWM_ENV_SV
`define PWM_ENV_SV

class pwm_env extends uvm_env;

    // Active AXI4-Lite Master Agent (4-bit address for PWM slave, 32-bit data)
    axi_lite_agent #(4, 32) axi_agent;

    // Passive PWM Pin Monitor
    pwm_monitor             pwm_mon;

    // PWM Scoreboard
    pwm_scoreboard          sb;

    // Functional Coverage Subscriber
    pwm_coverage            cov;

    // Exposed sequencer handle
    axi_lite_sequencer      axi_sqr;

    `uvm_component_utils(pwm_env)

    function new(string name = "pwm_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        virtual pwm_if pwm_vif;
        super.build_phase(phase);

        // Propagate PWM virtual interface if configured at env scope
        if (uvm_config_db#(virtual pwm_if)::get(this, "", "pwm_vif", pwm_vif)) begin
            uvm_config_db#(virtual pwm_if)::set(this, "pwm_mon", "vif", pwm_vif);
        end

        axi_agent = axi_lite_agent#(4, 32)::type_id::create("axi_agent", this);
        pwm_mon   = pwm_monitor::type_id::create("pwm_mon", this);
        sb        = pwm_scoreboard::type_id::create("sb", this);
        cov       = pwm_coverage::type_id::create("cov", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // Connect AXI transactions to scoreboard and coverage
        axi_agent.ap.connect(sb.axi_imp);
        axi_agent.ap.connect(cov.axi_export);

        // Connect PWM monitor transactions to scoreboard and coverage
        pwm_mon.ap.connect(sb.pwm_imp);
        pwm_mon.ap.connect(cov.analysis_export);

        // Expose sequencer
        axi_sqr = axi_agent.sqr;
    endfunction

endclass : pwm_env

`endif // PWM_ENV_SV

