// =============================================================================
// Smart ControlSoC - SoC Configuration Class: soc_config.sv
// Encapsulates virtual interfaces and active/passive modes for the 6 peripherals:
// UART, Timer, GPIO, SPI, Seven-Segment Display (SEG7), and PWM.
// No I2C or DMA dependencies.
// =============================================================================

`ifndef SOC_CONFIG_SV
`define SOC_CONFIG_SV

class soc_config extends uvm_object;
    `uvm_object_utils(soc_config)

    // Virtual Interface Handles for the 5 External Pin Interfaces
    virtual uart_vip_if uart_vif;
    virtual gpio_vip_if gpio_vif;
    virtual spi_vip_if  spi_vif;
    virtual pwm_vip_if  pwm_vif;
    virtual seg7_vip_if seg7_vif;

    // CPU BFM interface handle (accesses CPU LSU AXI Master Port S00)
    virtual cpu_bfm_if  cpu_vif;

    // Active / Passive configuration modes
    uvm_active_passive_enum uart_is_active = UVM_ACTIVE;
    uvm_active_passive_enum gpio_is_active = UVM_ACTIVE;
    uvm_active_passive_enum spi_is_active  = UVM_ACTIVE;
    uvm_active_passive_enum pwm_is_active  = UVM_PASSIVE;
    uvm_active_passive_enum seg7_is_active = UVM_PASSIVE;

    function new(string name = "soc_config");
        super.new(name);
    endfunction

    // Validate that required external virtual interfaces are configured
    function bit validate();
        bit valid = 1'b1;
        if (uart_vif == null) begin
            `uvm_error("SOC_CFG", "UART external virtual interface (uart_vif) is not configured!")
            valid = 1'b0;
        end
        if (gpio_vif == null) begin
            `uvm_error("SOC_CFG", "GPIO external virtual interface (gpio_vif) is not configured!")
            valid = 1'b0;
        end
        if (spi_vif == null) begin
            `uvm_error("SOC_CFG", "SPI external virtual interface (spi_vif) is not configured!")
            valid = 1'b0;
        end
        if (pwm_vif == null) begin
            `uvm_error("SOC_CFG", "PWM external virtual interface (pwm_vif) is not configured!")
            valid = 1'b0;
        end
        if (seg7_vif == null) begin
            `uvm_error("SOC_CFG", "SEG7 external virtual interface (seg7_vif) is not configured!")
            valid = 1'b0;
        end
        if (cpu_vif == null) begin
            `uvm_error("SOC_CFG", "CPU BFM virtual interface (cpu_vif) is not configured!")
            valid = 1'b0;
        end
        return valid;
    endfunction

    function void print_config();
        `uvm_info("SOC_CFG", "--------------------------------------------------", UVM_LOW)
        `uvm_info("SOC_CFG", "SoC External Interfaces Configuration Summary:", UVM_LOW)
        `uvm_info("SOC_CFG", $sformatf("  UART External VIP Agent Mode: %s", uart_is_active.name()), UVM_LOW)
        `uvm_info("SOC_CFG", $sformatf("  GPIO External VIP Agent Mode: %s", gpio_is_active.name()), UVM_LOW)
        `uvm_info("SOC_CFG", $sformatf("  SPI  External VIP Agent Mode: %s", spi_is_active.name()), UVM_LOW)
        `uvm_info("SOC_CFG", $sformatf("  PWM  External VIP Agent Mode: %s", pwm_is_active.name()), UVM_LOW)
        `uvm_info("SOC_CFG", $sformatf("  SEG7 External VIP Agent Mode: %s", seg7_is_active.name()), UVM_LOW)
        `uvm_info("SOC_CFG", $sformatf("  CPU  BFM Interface Bound    : %s", (cpu_vif != null) ? "YES" : "NO"), UVM_LOW)
        `uvm_info("SOC_CFG", "--------------------------------------------------", UVM_LOW)
    endfunction

endclass : soc_config

`endif // SOC_CONFIG_SV

