// =============================================================================
// Module: axi_lsu_dwidth_adapter
// Description: AXI4 64-bit to 32-bit Data Width Downconverter / Bridge
// Connects the VeeR EL2 64-bit Load-Store Unit (LSU) AXI4 Master to a 32-bit
// AXI4/AXI4-Lite crossbar interconnect master port (S00).
// =============================================================================

`timescale 1ns/1ps

module axi_lsu_dwidth_adapter #(
    parameter TAG_WIDTH = 3,
    parameter ID_WIDTH  = 12,
    parameter ADDR_WIDTH = 32
)(
/* verilator lint_off UNUSED */
    input  wire                   clk,
    input  wire                   rst_n,
/* verilator lint_on UNUSED */

    // -------------------------------------------------------------------------
    // Slave Interface: VeeR EL2 LSU Master (64-bit AXI4)
    // -------------------------------------------------------------------------
    // Write Address
    input  wire                   s_lsu_awvalid,
    output wire                   s_lsu_awready,
    input  wire [TAG_WIDTH-1:0]   s_lsu_awid,
    input  wire [ADDR_WIDTH-1:0]  s_lsu_awaddr,
    input  wire [7:0]             s_lsu_awlen,
/* verilator lint_off UNUSED */
    input  wire [2:0]             s_lsu_awsize,
/* verilator lint_on UNUSED */
    input  wire [1:0]             s_lsu_awburst,
    input  wire                   s_lsu_awlock,
    input  wire [3:0]             s_lsu_awcache,
    input  wire [2:0]             s_lsu_awprot,
    input  wire [3:0]             s_lsu_awregion,
    input  wire [3:0]             s_lsu_awqos,

    // Write Data
    input  wire                   s_lsu_wvalid,
    output wire                   s_lsu_wready,
    input  wire [63:0]            s_lsu_wdata,
    input  wire [7:0]             s_lsu_wstrb,
    input  wire                   s_lsu_wlast,

    // Write Response
    output wire                   s_lsu_bvalid,
    input  wire                   s_lsu_bready,
    output wire [1:0]             s_lsu_bresp,
    output wire [TAG_WIDTH-1:0]   s_lsu_bid,

    // Read Address
    input  wire                   s_lsu_arvalid,
    output wire                   s_lsu_arready,
    input  wire [TAG_WIDTH-1:0]   s_lsu_arid,
    input  wire [ADDR_WIDTH-1:0]  s_lsu_araddr,
    input  wire [7:0]             s_lsu_arlen,
/* verilator lint_off UNUSED */
    input  wire [2:0]             s_lsu_arsize,
/* verilator lint_on UNUSED */
    input  wire [1:0]             s_lsu_arburst,
    input  wire                   s_lsu_arlock,
    input  wire [3:0]             s_lsu_arcache,
    input  wire [2:0]             s_lsu_arprot,
    input  wire [3:0]             s_lsu_arregion,
    input  wire [3:0]             s_lsu_arqos,

    // Read Data
    output wire                   s_lsu_rvalid,
    input  wire                   s_lsu_rready,
    output wire [63:0]            s_lsu_rdata,
    output wire [1:0]             s_lsu_rresp,
    output wire [TAG_WIDTH-1:0]   s_lsu_rid,
    output wire                   s_lsu_rlast,

    // -------------------------------------------------------------------------
    // Master Interface: Interconnect Port S00 (32-bit AXI4)
    // -------------------------------------------------------------------------
    // Write Address
    output wire                   m_axi_awvalid,
    input  wire                   m_axi_awready,
    output wire [ID_WIDTH-1:0]    m_axi_awid,
    output wire [ADDR_WIDTH-1:0]  m_axi_awaddr,
    output wire [7:0]             m_axi_awlen,
    output wire [2:0]             m_axi_awsize,
    output wire [1:0]             m_axi_awburst,
    output wire                   m_axi_awlock,
    output wire [3:0]             m_axi_awcache,
    output wire [2:0]             m_axi_awprot,
    output wire [3:0]             m_axi_awregion,
    output wire [3:0]             m_axi_awqos,

    // Write Data
    output wire                   m_axi_wvalid,
    input  wire                   m_axi_wready,
    output wire [31:0]            m_axi_wdata,
    output wire [3:0]             m_axi_wstrb,
    output wire                   m_axi_wlast,

    // Write Response
    input  wire                   m_axi_bvalid,
    output wire                   m_axi_bready,
    input  wire [1:0]             m_axi_bresp,
/* verilator lint_off UNUSED */
    input  wire [ID_WIDTH-1:0]    m_axi_bid,
/* verilator lint_on UNUSED */

    // Read Address
    output wire                   m_axi_arvalid,
    input  wire                   m_axi_arready,
    output wire [ID_WIDTH-1:0]    m_axi_arid,
    output wire [ADDR_WIDTH-1:0]  m_axi_araddr,
    output wire [7:0]             m_axi_arlen,
    output wire [2:0]             m_axi_arsize,
    output wire [1:0]             m_axi_arburst,
    output wire                   m_axi_arlock,
    output wire [3:0]             m_axi_arcache,
    output wire [2:0]             m_axi_arprot,
    output wire [3:0]             m_axi_arregion,
    output wire [3:0]             m_axi_arqos,

    // Read Data
    input  wire                   m_axi_rvalid,
    output wire                   m_axi_rready,
    input  wire [31:0]            m_axi_rdata,
    input  wire [1:0]             m_axi_rresp,
/* verilator lint_off UNUSED */
    input  wire [ID_WIDTH-1:0]    m_axi_rid,
/* verilator lint_on UNUSED */
    input  wire                   m_axi_rlast
);

    // -------------------------------------------------------------------------
    // Write Address Channel
    // -------------------------------------------------------------------------
    assign m_axi_awvalid  = s_lsu_awvalid;
    assign s_lsu_awready  = m_axi_awready;
    assign m_axi_awaddr   = s_lsu_awaddr;
    assign m_axi_awlen    = s_lsu_awlen;
    assign m_axi_awsize   = 3'b010; // Fixed 32-bit bus transfer size
    assign m_axi_awburst  = s_lsu_awburst;
    assign m_axi_awlock   = s_lsu_awlock;
    assign m_axi_awcache  = s_lsu_awcache;
    assign m_axi_awprot   = s_lsu_awprot;
    assign m_axi_awregion = s_lsu_awregion;
    assign m_axi_awqos    = s_lsu_awqos;

    // Zero-extend ID from TAG_WIDTH to ID_WIDTH
    generate
        if (ID_WIDTH > TAG_WIDTH) begin : gen_awid_ext
            assign m_axi_awid = {{(ID_WIDTH-TAG_WIDTH){1'b0}}, s_lsu_awid};
        end else begin : gen_awid_direct
            assign m_axi_awid = s_lsu_awid[ID_WIDTH-1:0];
        end
    endgenerate

    // -------------------------------------------------------------------------
    // Write Data Channel (Lane Steering)
    // If upper strobes [7:4] are asserted and lower [3:0] are zero, steer upper lane [63:32].
    // Otherwise steer lower lane [31:0].
    // -------------------------------------------------------------------------
    wire steer_upper = (s_lsu_wstrb[7:4] != 4'b0000) && (s_lsu_wstrb[3:0] == 4'b0000);

    assign m_axi_wvalid = s_lsu_wvalid;
    assign s_lsu_wready = m_axi_wready;
    assign m_axi_wdata  = steer_upper ? s_lsu_wdata[63:32] : s_lsu_wdata[31:0];
    assign m_axi_wstrb  = steer_upper ? s_lsu_wstrb[7:4]   : s_lsu_wstrb[3:0];
    assign m_axi_wlast  = s_lsu_wlast;

    // -------------------------------------------------------------------------
    // Write Response Channel
    // -------------------------------------------------------------------------
    assign s_lsu_bvalid = m_axi_bvalid;
    assign m_axi_bready = s_lsu_bready;
    assign s_lsu_bresp  = m_axi_bresp;
    assign s_lsu_bid    = m_axi_bid[TAG_WIDTH-1:0];

    // -------------------------------------------------------------------------
    // Read Address Channel
    // -------------------------------------------------------------------------
    assign m_axi_arvalid  = s_lsu_arvalid;
    assign s_lsu_arready  = m_axi_arready;
    assign m_axi_araddr   = s_lsu_araddr;
    assign m_axi_arlen    = s_lsu_arlen;
    assign m_axi_arsize   = 3'b010; // Fixed 32-bit bus transfer size
    assign m_axi_arburst  = s_lsu_arburst;
    assign m_axi_arlock   = s_lsu_arlock;
    assign m_axi_arcache  = s_lsu_arcache;
    assign m_axi_arprot   = s_lsu_arprot;
    assign m_axi_arregion = s_lsu_arregion;
    assign m_axi_arqos    = s_lsu_arqos;

    generate
        if (ID_WIDTH > TAG_WIDTH) begin : gen_arid_ext
            assign m_axi_arid = {{(ID_WIDTH-TAG_WIDTH){1'b0}}, s_lsu_arid};
        end else begin : gen_arid_direct
            assign m_axi_arid = s_lsu_arid[ID_WIDTH-1:0];
        end
    endgenerate

    // -------------------------------------------------------------------------
    // Read Data Channel
    // Duplicate 32-bit read data across both upper and lower lanes:
    // {m_axi_rdata, m_axi_rdata}.
    // The core's internal LSU rotator automatically extracts the target word/half/byte
    // based on instruction address addr[2:0], ensuring single-cycle deterministic readback.
    // -------------------------------------------------------------------------
    assign s_lsu_rvalid = m_axi_rvalid;
    assign m_axi_rready = s_lsu_rready;
    assign s_lsu_rdata  = {m_axi_rdata, m_axi_rdata};
    assign s_lsu_rresp  = m_axi_rresp;
    assign s_lsu_rid    = m_axi_rid[TAG_WIDTH-1:0];
    assign s_lsu_rlast  = m_axi_rlast;

endmodule
