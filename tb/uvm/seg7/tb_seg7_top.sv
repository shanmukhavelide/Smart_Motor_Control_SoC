// =============================================================================
// Standalone SEG7 UVM Testbench Top: tb_seg7_top
// Instantiates:
//   - Clock (100 MHz) and active-low reset generator
//   - DUT: axi_seg7_top (ADDR_WIDTH=12, DATA_WIDTH=32)
//   - AXI4-Lite Master Interface: axi_lite_if #(12, 32)
//   - Passive SEG7 Display Interface: seg7_vip_if
// Registers virtual interfaces into uvm_config_db and invokes run_test().
//
// COMPILATION ORDER REQUIREMENT:
//   1. tb/uvm/common/axi_lite/axi_lite_if.sv
//   2. tb/uvm/common/axi_lite/axi_lite_pkg.sv
//   3. tb/seg7.vip_uvm_tb/seg7_vip_if.sv
//   4. tb/seg7.vip_uvm_tb/seg7_vip_pkg.sv
//   5. tb/uvm/seg7/seg7_pkg.sv
//   6. tb/uvm/seg7/tb_seg7_top.sv
// =============================================================================

`timescale 1ns/1ps

module tb_seg7_top;

    timeunit 1ns;
    timeprecision 1ps;

    // -------------------------------------------------------------------------
    // Packages & Macros
    // -------------------------------------------------------------------------
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    import axi_lite_pkg::*;
    import seg7_vip_pkg::*;
    import seg7_pkg::*;

    // -------------------------------------------------------------------------
    // Clock and Reset Generation
    // -------------------------------------------------------------------------
    logic clk;
    logic rst_n;

    // 100 MHz System Clock (10 ns period, 50% duty cycle)
    initial begin
        clk = 1'b0;
        forever #5ns clk = ~clk;
    end

    // Active-Low Reset (held asserted for 10 clock cycles, released cleanly)
    initial begin
        rst_n = 1'b0;
        repeat (10) @(posedge clk);
        #1ps;
        rst_n = 1'b1;
    end

    // -------------------------------------------------------------------------
    // Virtual Interfaces
    // -------------------------------------------------------------------------
    // AXI4-Lite Master Interface (12-bit address for SEG7 IP, 32-bit data)
    axi_lite_if #(
        .ADDR_WIDTH (12),
        .DATA_WIDTH (32)
    ) axi_vif (
        .clk   (clk),
        .rst_n (rst_n)
    );

    // Passive Seven-Segment Display Pin Interface
    seg7_vip_if seg7_vif (
        .clk   (clk),
        .rst_n (rst_n)
    );

    // -------------------------------------------------------------------------
    // Design Under Test (DUT): axi_seg7_top
    // -------------------------------------------------------------------------
    axi_seg7_top #(
        .DATA_WIDTH (32),
        .ADDR_WIDTH (12)
    ) dut (
        .clk           (clk),
        .rst_n         (rst_n),

        // AXI4-Lite Slave Write Address Channel (AW)
        .s_axi_awaddr  (axi_vif.awaddr),
        .s_axi_awprot  (axi_vif.awprot),
        .s_axi_awvalid (axi_vif.awvalid),
        .s_axi_awready (axi_vif.awready),

        // AXI4-Lite Slave Write Data Channel (W)
        .s_axi_wdata   (axi_vif.wdata),
        .s_axi_wstrb   (axi_vif.wstrb),
        .s_axi_wvalid  (axi_vif.wvalid),
        .s_axi_wready  (axi_vif.wready),

        // AXI4-Lite Slave Write Response Channel (B)
        .s_axi_bresp   (axi_vif.bresp),
        .s_axi_bvalid  (axi_vif.bvalid),
        .s_axi_bready  (axi_vif.bready),

        // AXI4-Lite Slave Read Address Channel (AR)
        .s_axi_araddr  (axi_vif.araddr),
        .s_axi_arprot  (axi_vif.arprot),
        .s_axi_arvalid (axi_vif.arvalid),
        .s_axi_arready (axi_vif.arready),

        // AXI4-Lite Slave Read Data Channel (R)
        .s_axi_rdata   (axi_vif.rdata),
        .s_axi_rresp   (axi_vif.rresp),
        .s_axi_rvalid  (axi_vif.rvalid),
        .s_axi_rready  (axi_vif.rready),

        // External Seven-Segment Display Pins
        .seg_o         (seg7_vif.seg_o),
        .an_o          (seg7_vif.an_o)
    );

    // -------------------------------------------------------------------------
    // UVM Configuration & Startup
    // -------------------------------------------------------------------------
    initial begin
        // Configure virtual interfaces into uvm_config_db
        // AXI agent scope: matches uvm_test_top.env.axi_agent
        uvm_config_db#(virtual axi_lite_if #(12, 32))::set(null, "*.axi_agent", "vif", axi_vif);

        // SEG7 agent scope: matches uvm_test_top.env.seg7_agent (propagated to seg7_agent.mon by seg7_env)
        uvm_config_db#(virtual seg7_vip_if)::set(null, "*.seg7_agent", "vif", seg7_vif);

        // Invoke UVM test specified via +UVM_TESTNAME
        run_test();
    end

    // -------------------------------------------------------------------------
    // Optional Waveform Dumping (Enabled via compile flag or plusarg)
    // -------------------------------------------------------------------------
    initial begin
        `ifdef FSDB
        $fsdbDumpfile("tb_seg7_top.fsdb");
        $fsdbDumpvars(0, tb_seg7_top);
        `endif
    end

endmodule : tb_seg7_top

