// =============================================================================
// Standalone SPI Top Testbench: tb_spi_top.sv
// Instantiates SPI DUT (axi_spi_top), AXI-Lite VIP master interface, and SPI pin interface
// =============================================================================

`timescale 1ns/1ps

`include "uvm_macros.svh"

module tb_spi_top;

    import uvm_pkg::*;
    import axi_lite_pkg::*;
    import spi_pkg::*;

    localparam CLK_PERIOD = 10; // 100 MHz clock
    localparam ADDR_WIDTH = 7;
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
        $display("[%0t ns] [TB_SPI_TOP] Asynchronous Reset Released.", $time);
    end

    // -------------------------------------------------------------------------
    // Virtual Interfaces
    // -------------------------------------------------------------------------
    axi_lite_if #(ADDR_WIDTH, DATA_WIDTH) axi_if (.clk(clk), .rst_n(rst_n));
    spi_if spi_vif (.clk(clk), .rst_n(rst_n));

    // -------------------------------------------------------------------------
    // DUT Instantiation: axi_spi_top
    // -------------------------------------------------------------------------
    axi_spi_top dut (
        .fixed_clk_i   (clk),
        .axi_aclk_i    (clk),
        .axi_aresetn_i (rst_n),

        // AR Channel
        .axi_arid_i    (12'h101),
        .axi_araddr_i  (axi_if.araddr[ADDR_WIDTH-1:0]),
        .axi_arvalid_i (axi_if.arvalid),
        .axi_arready_o (axi_if.arready),

        // R Channel
        .axi_rid_o     (),
        .axi_rdata_o   (axi_if.rdata),
        .axi_rresp_o   (axi_if.rresp),
        .axi_rvalid_o  (axi_if.rvalid),
        .axi_rready_i  (axi_if.rready),

        // AW Channel
        .axi_awid_i    (12'h101),
        .axi_awaddr_i  (axi_if.awaddr[ADDR_WIDTH-1:0]),
        .axi_awvalid_i (axi_if.awvalid),
        .axi_awready_o (axi_if.awready),

        // W Channel
        .axi_wdata_i   (axi_if.wdata),
        .axi_wstrb_i   (axi_if.wstrb),
        .axi_wvalid_i  (axi_if.wvalid),
        .axi_wready_o  (axi_if.wready),

        // B Channel
        .axi_bid_o     (),
        .axi_bresp_o   (axi_if.bresp),
        .axi_bvalid_o  (axi_if.bvalid),
        .axi_bready_i  (axi_if.bready),

        // SPI Physical Ports
        .spi_clk_o     (spi_vif.sclk),
        .spi_cs_n_o    (spi_vif.cs_n),
        .spi_mosi_o    (spi_vif.mosi),
        .spi_miso_i    (spi_vif.miso)
    );

    // -------------------------------------------------------------------------
    // Waveform Dumping
    // -------------------------------------------------------------------------
    initial begin
        `ifdef FSDB
            $fsdbDumpfile("tb_spi_top.fsdb");
            $fsdbDumpvars(0, tb_spi_top);
            $display("[%0t ns] [VCS/VERDI] FSDB waveform dumping enabled -> tb_spi_top.fsdb", $time);
        `endif
        `ifdef VCD
            $dumpfile("tb_spi_top.vcd");
            $dumpvars(0, tb_spi_top);
        `endif
    end

    // -------------------------------------------------------------------------
    // UVM Config DB Setup and Test Launch
    // -------------------------------------------------------------------------
    initial begin
        // Set virtual interfaces
        uvm_config_db#(virtual axi_lite_if#(ADDR_WIDTH, DATA_WIDTH))::set(null, "*env.axi_agent*", "vif", axi_if);
        uvm_config_db#(virtual spi_if)::set(null, "*env.slave_mdl*", "vif", spi_vif);
        uvm_config_db#(virtual spi_if)::set(null, "*env.spi_mon*",   "vif", spi_vif);
        uvm_config_db#(virtual spi_if)::set(null, "*", "spi_vif", spi_vif);

        // Run test (command line +UVM_TESTNAME=<test> or default)
        run_test("spi_full_duplex_test");
    end

endmodule : tb_spi_top

