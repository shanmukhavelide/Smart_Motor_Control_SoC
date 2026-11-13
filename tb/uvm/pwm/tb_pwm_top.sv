// =============================================================================
// Standalone PWM Top Testbench: tb_pwm_top.sv
// Instantiates PWM DUT (myip_v1_0), AXI-Lite VIP master interface, and PWM pin interface
// =============================================================================

`timescale 1ns/1ps

`include "uvm_macros.svh"

module tb_pwm_top;

    import uvm_pkg::*;
    import axi_lite_pkg::*;
    import pwm_pkg::*;

    localparam CLK_PERIOD = 10; // 100 MHz clock
    localparam ADDR_WIDTH = 4;
    localparam DATA_WIDTH = 32;

    logic clk;
    logic rst_n;

    // Clock Generation
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // Reset Generation
    initial begin
        rst_n = 1'b0;
        #(CLK_PERIOD * 10);
        rst_n = 1'b1;
        $display("[%0t ns] [TB_PWM_TOP] Asynchronous Reset Released.", $time);
    end

    // -------------------------------------------------------------------------
    // Virtual Interfaces
    // -------------------------------------------------------------------------
    axi_lite_if #(ADDR_WIDTH, DATA_WIDTH) axi_if (.clk(clk), .rst_n(rst_n));
    pwm_if pwm_vif (.clk(clk), .rst_n(rst_n));

    // -------------------------------------------------------------------------
    // DUT Instantiation: myip_v1_0
    // -------------------------------------------------------------------------
    myip_v1_0 #(
        .C_S00_AXI_DATA_WIDTH (DATA_WIDTH),
        .C_S00_AXI_ADDR_WIDTH (ADDR_WIDTH)
    ) dut (
        .s00_axi_aclk    (clk),
        .s00_axi_aresetn (rst_n),

        // AW Channel
        .s00_axi_awaddr  (axi_if.awaddr[ADDR_WIDTH-1:0]),
        .s00_axi_awprot  (axi_if.awprot),
        .s00_axi_awvalid (axi_if.awvalid),
        .s00_axi_awready (axi_if.awready),

        // W Channel
        .s00_axi_wdata   (axi_if.wdata),
        .s00_axi_wstrb   (axi_if.wstrb),
        .s00_axi_wvalid  (axi_if.wvalid),
        .s00_axi_wready  (axi_if.wready),

        // B Channel
        .s00_axi_bresp   (axi_if.bresp),
        .s00_axi_bvalid  (axi_if.bvalid),
        .s00_axi_bready  (axi_if.bready),

        // AR Channel
        .s00_axi_araddr  (axi_if.araddr[ADDR_WIDTH-1:0]),
        .s00_axi_arprot  (axi_if.arprot),
        .s00_axi_arvalid (axi_if.arvalid),
        .s00_axi_arready (axi_if.arready),

        // R Channel
        .s00_axi_rdata   (axi_if.rdata),
        .s00_axi_rresp   (axi_if.rresp),
        .s00_axi_rvalid  (axi_if.rvalid),
        .s00_axi_rready  (axi_if.rready),

        // Output Pin
        .PWM_OUT         (pwm_vif.pwm_out)
    );

    // -------------------------------------------------------------------------
    // Waveform Dumping
    // -------------------------------------------------------------------------
    initial begin
        `ifdef FSDB
            $fsdbDumpfile("tb_pwm_top.fsdb");
            $fsdbDumpvars(0, tb_pwm_top);
            $display("[%0t ns] [VCS/VERDI] FSDB waveform dumping enabled -> tb_pwm_top.fsdb", $time);
        `endif
        `ifdef VCD
            $dumpfile("tb_pwm_top.vcd");
            $dumpvars(0, tb_pwm_top);
        `endif
    end

    // -------------------------------------------------------------------------
    // UVM Config DB Setup and Test Launch
    // -------------------------------------------------------------------------
    initial begin
        // Set virtual interfaces
        uvm_config_db#(virtual axi_lite_if#(ADDR_WIDTH, DATA_WIDTH))::set(null, "*env.axi_agent*", "vif", axi_if);
        uvm_config_db#(virtual pwm_if)::set(null, "*env.pwm_mon*", "vif", pwm_vif);
        uvm_config_db#(virtual pwm_if)::set(null, "*", "pwm_vif", pwm_vif);

        // Run test (command line +UVM_TESTNAME=<test> or default)
        run_test("pwm_duty_50_test");
    end

endmodule : tb_pwm_top

