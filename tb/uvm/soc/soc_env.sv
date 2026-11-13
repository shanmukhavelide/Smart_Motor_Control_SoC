// =============================================================================
// Smart ControlSoC - Top-Level SoC UVM Environment: soc_env.sv
// Integrates UART, GPIO, SPI, PWM, and SEG7 VIP agents and the virtual sequencer.
// =============================================================================

`ifndef SOC_ENV_SV
`define SOC_ENV_SV

class soc_env extends uvm_env;
    `uvm_component_utils(soc_env)

    // Configuration object handle
    soc_config cfg;

    // External VIP Agents (for the 5 physical peripheral pin interfaces)
    uart_vip_agent  uart_agent;
    gpio_vip_agent  gpio_agent;
    spi_vip_agent   spi_agent;
    pwm_vip_agent   pwm_agent;
    seg7_vip_agent  seg7_agent;

    // SoC Virtual Sequencer
    soc_virtual_sequencer v_sqr;

    function new(string name = "soc_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(soc_config)::get(this, "", "soc_cfg", cfg)) begin
            `uvm_info(get_type_name(), "soc_config not found under 'soc_cfg'; creating default config...", UVM_MEDIUM)
            cfg = soc_config::type_id::create("cfg");
        end

        // Pass virtual interfaces to sub-agents
        if (cfg.uart_vif != null)
            uvm_config_db#(virtual uart_vip_if)::set(this, "uart_agent", "vif", cfg.uart_vif);
        if (cfg.gpio_vif != null)
            uvm_config_db#(virtual gpio_vip_if)::set(this, "gpio_agent", "vif", cfg.gpio_vif);
        if (cfg.spi_vif != null)
            uvm_config_db#(virtual spi_vip_if)::set(this, "spi_agent", "vif", cfg.spi_vif);
        if (cfg.pwm_vif != null)
            uvm_config_db#(virtual pwm_vip_if)::set(this, "pwm_agent", "vif", cfg.pwm_vif);
        if (cfg.seg7_vif != null)
            uvm_config_db#(virtual seg7_vip_if)::set(this, "seg7_agent", "vif", cfg.seg7_vif);

        // Instantiate peripheral VIP agents
        uart_agent = uart_vip_agent::type_id::create("uart_agent", this);
        gpio_agent = gpio_vip_agent::type_id::create("gpio_agent", this);
        spi_agent  = spi_vip_agent::type_id::create("spi_agent", this);
        pwm_agent  = pwm_vip_agent::type_id::create("pwm_agent", this);
        seg7_agent = seg7_vip_agent::type_id::create("seg7_agent", this);

        // Instantiate Virtual Sequencer
        v_sqr = soc_virtual_sequencer::type_id::create("v_sqr", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // Connect sub-sequencers to virtual sequencer
        v_sqr.uart_sqr = uart_agent.sqr;
        v_sqr.gpio_sqr = gpio_agent.sqr;
        v_sqr.spi_sqr  = spi_agent.sqr;
        v_sqr.cpu_vif  = cfg.cpu_vif;
    endfunction

endclass : soc_env

`endif // SOC_ENV_SV

