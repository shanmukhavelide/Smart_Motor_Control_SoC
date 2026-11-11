`timescale 1ns/1ps

module axi_seg7_top #(
    parameter integer DATA_WIDTH = 32,
    parameter integer ADDR_WIDTH = 12
)(
    input  logic                      clk,
    input  logic                      rst_n,

    // AXI4-Lite Slave Interface
    input  logic [ADDR_WIDTH-1:0]     s_axi_awaddr,
    input  logic [2:0]                s_axi_awprot,
    input  logic                      s_axi_awvalid,
    output logic                      s_axi_awready,
    input  logic [DATA_WIDTH-1:0]     s_axi_wdata,
    input  logic [(DATA_WIDTH/8)-1:0] s_axi_wstrb,
    input  logic                      s_axi_wvalid,
    output logic                      s_axi_wready,
    output logic [1:0]                s_axi_bresp,
    output logic                      s_axi_bvalid,
    input  logic                      s_axi_bready,
    input  logic [ADDR_WIDTH-1:0]     s_axi_araddr,
    input  logic [2:0]                s_axi_arprot,
    input  logic                      s_axi_arvalid,
    output logic                      s_axi_arready,
    output logic [DATA_WIDTH-1:0]     s_axi_rdata,
    output logic [1:0]                s_axi_rresp,
    output logic                      s_axi_rvalid,
    input  logic                      s_axi_rready,

    // Seven-Segment Display Outputs
    output logic [7:0]                seg_o,
    output logic [7:0]                an_o
);

    logic [31:0] seg_data;
    logic [31:0] seg_ctrl;
    logic [31:0] seg_dp;
    logic [31:0] seg_refresh_div;

    axi_seg7_slave #(
        .C_S_AXI_DATA_WIDTH (DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH (ADDR_WIDTH)
    ) u_axi_seg7_slave (
        .seg_data_o        (seg_data),
        .seg_ctrl_o        (seg_ctrl),
        .seg_dp_o          (seg_dp),
        .seg_refresh_div_o (seg_refresh_div),

        .S_AXI_ACLK        (clk),
        .S_AXI_ARESETN     (rst_n),
        .S_AXI_AWADDR      (s_axi_awaddr),
        .S_AXI_AWPROT      (s_axi_awprot),
        .S_AXI_AWVALID     (s_axi_awvalid),
        .S_AXI_AWREADY     (s_axi_awready),
        .S_AXI_WDATA       (s_axi_wdata),
        .S_AXI_WSTRB       (s_axi_wstrb),
        .S_AXI_WVALID      (s_axi_wvalid),
        .S_AXI_WREADY      (s_axi_wready),
        .S_AXI_BRESP       (s_axi_bresp),
        .S_AXI_BVALID      (s_axi_bvalid),
        .S_AXI_BREADY      (s_axi_bready),
        .S_AXI_ARADDR      (s_axi_araddr),
        .S_AXI_ARPROT      (s_axi_arprot),
        .S_AXI_ARVALID     (s_axi_arvalid),
        .S_AXI_ARREADY     (s_axi_arready),
        .S_AXI_RDATA       (s_axi_rdata),
        .S_AXI_RRESP       (s_axi_rresp),
        .S_AXI_RVALID      (s_axi_rvalid),
        .S_AXI_RREADY      (s_axi_rready)
    );

    seg7_core u_seg7_core (
        .clk_i            (clk),
        .rst_ni           (rst_n),
        .seg_data_i       (seg_data),
        .en_i             (seg_ctrl[0]),
        .seg_active_low_i (seg_ctrl[1]),
        .an_active_low_i  (seg_ctrl[2]),
        .digit_mask_i     (seg_ctrl[15:8]),
        .dp_i             (seg_dp[7:0]),
        .refresh_div_i    (seg_refresh_div[15:0]),
        .seg_o            (seg_o),
        .an_o             (an_o)
    );

endmodule
