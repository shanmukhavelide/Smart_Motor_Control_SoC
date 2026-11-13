// =============================================================================
// Reusable AXI4-Lite Master Interface: axi_lite_if
// Supports 5 standard AXI4-Lite channels: AW, W, B, AR, R
// Parameterized address and data widths (default ADDR=32, DATA=32, STRB=4)
// Includes race-safe clocking blocks for driver and passive monitor
// =============================================================================

`ifndef AXI_LITE_IF_SV
`define AXI_LITE_IF_SV

interface axi_lite_if #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter int STRB_WIDTH = (DATA_WIDTH / 8)
)(
    input logic clk,
    input logic rst_n
);

    timeunit 1ns;
    timeprecision 1ps;

    // -------------------------------------------------------------------------
    // AXI4-Lite Channel Signals
    // -------------------------------------------------------------------------
    // Write Address Channel (AW)
    logic [ADDR_WIDTH-1:0] awaddr;
    logic [2:0]            awprot;
    logic                  awvalid;
    logic                  awready;

    // Write Data Channel (W)
    logic [DATA_WIDTH-1:0] wdata;
    logic [STRB_WIDTH-1:0] wstrb;
    logic                  wvalid;
    logic                  wready;

    // Write Response Channel (B)
    logic [1:0]            bresp;
    logic                  bvalid;
    logic                  bready;

    // Read Address Channel (AR)
    logic [ADDR_WIDTH-1:0] araddr;
    logic [2:0]            arprot;
    logic                  arvalid;
    logic                  arready;

    // Read Data Channel (R)
    logic [DATA_WIDTH-1:0] rdata;
    logic [1:0]            rresp;
    logic                  rvalid;
    logic                  rready;

    // -------------------------------------------------------------------------
    // Master Driver Clocking Block (Race-safe synchronous drive)
    // -------------------------------------------------------------------------
    clocking cb_drv @(posedge clk);
        default input #1step output #100ps;
        output awaddr, awprot, awvalid;
        input  awready;
        output wdata, wstrb, wvalid;
        input  wready;
        input  bresp, bvalid;
        output bready;
        output araddr, arprot, arvalid;
        input  arready;
        input  rdata, rresp, rvalid;
        output rready;
    endclocking

    // -------------------------------------------------------------------------
    // Passive Monitor Clocking Block (Sample-only)
    // -------------------------------------------------------------------------
    clocking cb_mon @(posedge clk);
        default input #1step;
        input awaddr, awprot, awvalid, awready;
        input wdata, wstrb, wvalid, wready;
        input bresp, bvalid, bready;
        input araddr, arprot, arvalid, arready;
        input rdata, rresp, rvalid, rready;
    endclocking

    // -------------------------------------------------------------------------
    // Modports
    // -------------------------------------------------------------------------
    modport master (
        input  clk, rst_n,
        output awaddr, awprot, awvalid,
        input  awready,
        output wdata, wstrb, wvalid,
        input  wready,
        input  bresp, bvalid,
        output bready,
        output araddr, arprot, arvalid,
        input  arready,
        input  rdata, rresp, rvalid,
        output rready
    );

    modport slave (
        input  clk, rst_n,
        input  awaddr, awprot, awvalid,
        output awready,
        input  wdata, wstrb, wvalid,
        output wready,
        output bresp, bvalid,
        input  bready,
        input  araddr, arprot, arvalid,
        output arready,
        output rdata, rresp, rvalid,
        input  rready
    );

    modport drv_mp (
        clocking cb_drv,
        input clk, rst_n
    );

    modport mon_mp (
        clocking cb_mon,
        input clk, rst_n
    );

endinterface : axi_lite_if

`endif // AXI_LITE_IF_SV
