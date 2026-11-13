// =============================================================================
// Smart ControlSoC - Top-Level SoC UVM Testbench: tb_soc_uvm_top.sv
// Instantiates DUT (smart_controlsoc_top) and connects external interfaces:
// UART, GPIO, SPI, PWM, Seven-Segment Display (SEG7), and CPU BFM.
// =============================================================================

`timescale 1ns/1ps

`include "uvm_macros.svh"

module tb_soc_uvm_top;

    import uvm_pkg::*;
    import soc_uvm_pkg::*;

    // System Clock & Reset Generation
    localparam CLK_PERIOD = 10; // 100 MHz System Clock (10ns period)
    localparam DATA_WIDTH = 32;
    localparam ADDR_WIDTH = 32;
    localparam STRB_WIDTH = DATA_WIDTH / 8;
    localparam ID_WIDTH   = 12;

    logic sys_clk;
    logic sys_rst_n;

    initial begin
        sys_clk = 1'b0;
        forever #(CLK_PERIOD / 2) sys_clk = ~sys_clk;
    end

    initial begin
        sys_rst_n = 1'b0;
        #(CLK_PERIOD * 10);
        sys_rst_n = 1'b1;
        $display("[%0t ns] [TB_SOC_TOP] System Reset De-asserted.", $time);
    end

    // -------------------------------------------------------------------------
    // External VIP Interface Instantiations
    // -------------------------------------------------------------------------
    uart_vip_if uart_vif (.clk(sys_clk), .rst_n(sys_rst_n));
    gpio_vip_if gpio_vif (.clk(sys_clk), .rst_n(sys_rst_n));
    spi_vip_if  spi_vif  (.clk(sys_clk), .rst_n(sys_rst_n));
    pwm_vip_if  pwm_vif  (.clk(sys_clk), .rst_n(sys_rst_n));
    seg7_vip_if seg7_vif (.clk(sys_clk), .rst_n(sys_rst_n));

    // CPU Bus Functional Model (BFM) Interface
    cpu_bfm_if  cpu_vif  (.clk(sys_clk), .rst_n(sys_rst_n));

    // Top-Level Interrupt Lines
    wire uart_interrupt_o;
    wire gpio_interrupt_o;
    wire timer_interrupt_o;

    assign uart_interrupt_o = uart_vif.uart_interrupt_o;

    // -------------------------------------------------------------------------
    // Actual SoC DUT Instantiation
    // -------------------------------------------------------------------------
    smart_controlsoc_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .STRB_WIDTH(STRB_WIDTH),
        .ID_WIDTH(ID_WIDTH)
    ) soc_dut (
        .sys_clk             (sys_clk),
        .sys_rst_n           (sys_rst_n),

        // UART External Pins
        .uart_rx_i           (uart_vif.uart_rx_i),
        .uart_tx_o           (uart_vif.uart_tx_o),
        .uart_interrupt_o    (uart_vif.uart_interrupt_o),

        // SPI External Pins
        .spi_clk_o           (spi_vif.spi_clk_o),
        .spi_cs_n_o          (spi_vif.spi_cs_n_o),
        .spi_mosi_o          (spi_vif.spi_mosi_o),
        .spi_miso_i          (spi_vif.spi_miso_i),

        // Seven-Segment Display External Pins (Port M04: 0x4000_8000)
        .seg7_seg_o          (seg7_vif.seg_o),
        .seg7_an_o           (seg7_vif.an_o),

        // PWM External Pin
        .pwm_out_o           (pwm_vif.pwm_out_o),

        // GPIO External Pins
        .gpio_io             (gpio_vif.gpio_io),
        .gpio_interrupt_o    (gpio_interrupt_o),

        // Timer External Interrupt Pin
        .timer_interrupt_o   (timer_interrupt_o)
    );

    // -------------------------------------------------------------------------
    // Waveform Dumping for Synopsys VCS / Verdi
    // -------------------------------------------------------------------------
    initial begin
        `ifdef FSDB
            $fsdbDumpfile("tb_soc_uvm_top.fsdb");
            $fsdbDumpvars(0, tb_soc_uvm_top);
            $display("[%0t ns] [VCS/VERDI] FSDB waveform dumping enabled -> tb_soc_uvm_top.fsdb", $time);
        `endif
        `ifdef VCD
            $dumpfile("tb_soc_uvm_top.vcd");
            $dumpvars(0, tb_soc_uvm_top);
        `endif
    end

    // -------------------------------------------------------------------------
    // UVM Configuration DB Setup & Test Launch
    // -------------------------------------------------------------------------
    initial begin
        soc_config cfg = soc_config::type_id::create("soc_cfg");

        // Assign virtual interface handles to soc_config
        cfg.uart_vif = uart_vif;
        cfg.gpio_vif = gpio_vif;
        cfg.spi_vif  = spi_vif;
        cfg.pwm_vif  = pwm_vif;
        cfg.seg7_vif = seg7_vif;
        cfg.cpu_vif  = cpu_vif;

        // Configure Active / Passive modes
        cfg.uart_is_active = UVM_ACTIVE;
        cfg.gpio_is_active = UVM_ACTIVE;
        cfg.spi_is_active  = UVM_ACTIVE;
        cfg.pwm_is_active  = UVM_PASSIVE;
        cfg.seg7_is_active = UVM_PASSIVE;

        // Publish soc_config to UVM config database
        uvm_config_db#(soc_config)::set(null, "*", "soc_cfg", cfg);

        // Also publish virtual interfaces individually as backup/direct queries
        uvm_config_db#(virtual uart_vip_if)::set(null, "*", "uart_vif", uart_vif);
        uvm_config_db#(virtual gpio_vip_if)::set(null, "*", "gpio_vif", gpio_vif);
        uvm_config_db#(virtual spi_vip_if)::set(null, "*", "spi_vif",   spi_vif);
        uvm_config_db#(virtual pwm_vip_if)::set(null, "*", "pwm_vif",   pwm_vif);
        uvm_config_db#(virtual seg7_vip_if)::set(null, "*", "seg7_vif", seg7_vif);
        uvm_config_db#(virtual cpu_bfm_if)::set(null, "*", "cpu_bfm_vif", cpu_vif);

        // Run the UVM test specified on command line (defaults to soc_multi_peripheral_test)
        run_test("soc_multi_peripheral_test");
    end

endmodule : tb_soc_uvm_top

