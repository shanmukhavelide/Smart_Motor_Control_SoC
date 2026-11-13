// =============================================================================
// Smart ControlSoC Top-Level Module with Synthesizable VeeR EL2 Processor Core
// Module: smart_controlsoc_veer_top
// Description: Integrates Western Digital / CHIPS Alliance VeeR EL2 RISC-V Core
// (RV32IMC), 64-to-32 AXI LSU Width Adapter, 2x6 Crossbar Interconnect,
// closely-coupled memories (ICCM 64 KB, DCCM 64 KB), and 6 AXI4-Lite Peripherals:
// M00: UART        (0x4000_0000)
// M01: Timer       (0x4000_4000)
// M02: GPIO        (0x4000_2000)
// M03: SPI         (0x4000_6000)
// M04: SEG7        (0x4000_8000)
// M05: PWM         (0x4000_A000)
// =============================================================================

`timescale 1ns/1ps

`include "common_defines.vh"

module smart_controlsoc_veer_top
import el2_pkg::*;
#(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter STRB_WIDTH = DATA_WIDTH / 8,
    parameter ID_WIDTH   = 12,
`include "el2_param.vh"
)(
    input  wire                   sys_clk,
    input  wire                   sys_rst_n,

    // UART Interface
    input  wire                   uart_rx_i,
    output wire                   uart_tx_o,
    output wire                   uart_interrupt_o,

    // SPI Master Interface
    output wire                   spi_clk_o,
    output wire                   spi_cs_n_o,
    output wire                   spi_mosi_o,
    input  wire                   spi_miso_i,
    output wire                   spi_interrupt_o,

    // Seven-Segment Display Interface (Port M04: 0x4000_8000)
    output wire [7:0]             seg7_seg_o,
    output wire [7:0]             seg7_an_o,

    // PWM Generator Interface (Port M05: 0x4000_A000)
    output wire                   pwm_out_o,

    // GPIO Interface (Port M02: 0x4000_2000)
    inout  wire [31:0]            gpio_io,
    output wire                   gpio_interrupt_o,

    // Timer Interrupt Interface (Port M01: 0x4000_4000)
    output wire                   timer_interrupt_o,

    // Core Trace Observability Outputs (For Simulation & Verification)
    output wire                   trace_rv_i_valid_ip,
    output wire [31:0]            trace_rv_i_address_ip,
    output wire [31:0]            trace_rv_i_insn_ip,
    output wire                   trace_rv_i_exception_ip,
    output wire                   trace_rv_i_interrupt_ip
);

    // -------------------------------------------------------------------------
    // Reset Inversion for Interconnect
    // -------------------------------------------------------------------------
    wire sys_rst = ~sys_rst_n;

    // -------------------------------------------------------------------------
    // VeeR EL2 Memory Interfaces
    // -------------------------------------------------------------------------
    el2_mem_if #(.pt(pt)) el2_mem_export   ();
    el2_mem_if #(.pt(pt)) el2_icache_export();

    // Instantiate Memory Subsystem (ICCM, DCCM, ICache Arrays)
    veer_mem_subsystem #(.pt(pt)) mem_subsys (
        .clk           (sys_clk),
        .rst_n         (sys_rst_n),
        .mem_export    (el2_mem_export.veer_sram_sink),
        .icache_export (el2_icache_export.veer_icache_src)
    );

    // -------------------------------------------------------------------------
    // VeeR EL2 Core Signals
    // -------------------------------------------------------------------------
    // 64-bit LSU Master Wires
    wire                  lsu_axi_awvalid;
    wire                  lsu_axi_awready;
    wire [pt.LSU_BUS_TAG-1:0] lsu_axi_awid;
    wire [31:0]           lsu_axi_awaddr;
    wire [7:0]            lsu_axi_awlen;
    wire [2:0]            lsu_axi_awsize;
    wire [1:0]            lsu_axi_awburst;
    wire                  lsu_axi_awlock;
    wire [3:0]            lsu_axi_awcache;
    wire [2:0]            lsu_axi_awprot;
    wire [3:0]            lsu_axi_awregion;
    wire [3:0]            lsu_axi_awqos;

    wire                  lsu_axi_wvalid;
    wire                  lsu_axi_wready;
    wire [63:0]           lsu_axi_wdata;
    wire [7:0]            lsu_axi_wstrb;
    wire                  lsu_axi_wlast;

    wire                  lsu_axi_bvalid;
    wire                  lsu_axi_bready;
    wire [1:0]            lsu_axi_bresp;
    wire [pt.LSU_BUS_TAG-1:0] lsu_axi_bid;

    wire                  lsu_axi_arvalid;
    wire                  lsu_axi_arready;
    wire [pt.LSU_BUS_TAG-1:0] lsu_axi_arid;
    wire [31:0]           lsu_axi_araddr;
    wire [7:0]            lsu_axi_arlen;
    wire [2:0]            lsu_axi_arsize;
    wire [1:0]            lsu_axi_arburst;
    wire                  lsu_axi_arlock;
    wire [3:0]            lsu_axi_arcache;
    wire [2:0]            lsu_axi_arprot;
    wire [3:0]            lsu_axi_arregion;
    wire [3:0]            lsu_axi_arqos;

    wire                  lsu_axi_rvalid;
    wire                  lsu_axi_rready;
    wire [pt.LSU_BUS_TAG-1:0] lsu_axi_rid;
    wire [63:0]           lsu_axi_rdata;
    wire [1:0]            lsu_axi_rresp;
    wire                  lsu_axi_rlast;

    // IFU AXI Signals (Tied off since execution runs from internal ICCM)
    wire                  ifu_axi_awready = 1'b1;
    wire                  ifu_axi_wready  = 1'b1;
    wire                  ifu_axi_bvalid  = 1'b0;
    wire [1:0]            ifu_axi_bresp   = 2'b00;
    wire [pt.IFU_BUS_TAG-1:0] ifu_axi_bid = '0;
    wire                  ifu_axi_arready = 1'b1;
    wire                  ifu_axi_rvalid  = 1'b0;
    wire [pt.IFU_BUS_TAG-1:0] ifu_axi_rid = '0;
    wire [63:0]           ifu_axi_rdata   = 64'h0;
    wire [1:0]            ifu_axi_rresp   = 2'b00;
    wire                  ifu_axi_rlast   = 1'b1;

    // SB AXI Signals (Debug system bus, tied off)
    wire                  sb_axi_awready  = 1'b1;
    wire                  sb_axi_wready   = 1'b1;
    wire                  sb_axi_bvalid   = 1'b0;
    wire [1:0]            sb_axi_bresp    = 2'b00;
    wire [pt.SB_BUS_TAG-1:0] sb_axi_bid   = '0;
    wire                  sb_axi_arready  = 1'b1;
    wire                  sb_axi_rvalid   = 1'b0;
    wire [pt.SB_BUS_TAG-1:0] sb_axi_rid   = '0;
    wire [63:0]           sb_axi_rdata    = 64'h0;
    wire [1:0]            sb_axi_rresp    = 2'b00;
    wire                  sb_axi_rlast    = 1'b1;

    // Inbound DMA AXI Slave Signals (Tied idle)
    wire                  dma_axi_awvalid = 1'b0;
    wire [pt.DMA_BUS_TAG-1:0] dma_axi_awid = '0;
    wire [31:0]           dma_axi_awaddr  = 32'h0;
    wire [2:0]            dma_axi_awsize  = 3'b010;
    wire [2:0]            dma_axi_awprot  = 3'b000;
    wire [7:0]            dma_axi_awlen   = 8'h00;
    wire [1:0]            dma_axi_awburst = 2'b01;
    wire                  dma_axi_wvalid  = 1'b0;
    wire [63:0]           dma_axi_wdata   = 64'h0;
    wire [7:0]            dma_axi_wstrb   = 8'h00;
    wire                  dma_axi_wlast   = 1'b1;
    wire                  dma_axi_bready  = 1'b1;
    wire                  dma_axi_arvalid = 1'b0;
    wire [pt.DMA_BUS_TAG-1:0] dma_axi_arid = '0;
    wire [31:0]           dma_axi_araddr  = 32'h0;
    wire [2:0]            dma_axi_arsize  = 3'b010;
    wire [2:0]            dma_axi_arprot  = 3'b000;
    wire [7:0]            dma_axi_arlen   = 8'h00;
    wire [1:0]            dma_axi_arburst = 2'b01;
    wire                  dma_axi_rready  = 1'b1;

    // Interrupt aggregation to VeeR EL2 PIC
    wire [pt.PIC_TOTAL_INT:1] extintsrc_req;
    assign extintsrc_req[1] = uart_interrupt_o;
    assign extintsrc_req[2] = timer_interrupt_o;
    assign extintsrc_req[3] = gpio_interrupt_o;
    assign extintsrc_req[4] = spi_interrupt_o;
    generate
        if (pt.PIC_TOTAL_INT > 4) begin : gen_unused_ints
            assign extintsrc_req[pt.PIC_TOTAL_INT:5] = '0;
        end
    endgenerate

    // -------------------------------------------------------------------------
    // Synthesizable VeeR EL2 Core Instantiation
    // -------------------------------------------------------------------------
    el2_veer_wrapper #(.pt(pt)) veer_core (
        .clk             (sys_clk),
        .rst_l           (sys_rst_n),
        .dbg_rst_l       (sys_rst_n),
        .rst_vec         (31'h7700_0000), // Boot from ICCM (0xEE00_0000 >> 1)
        .nmi_int         (1'b0),
        .nmi_vec         (31'h0000_0000),
        .jtag_id         (31'h0000_0000),

        // Trace outputs
        .trace_rv_i_valid_ip     (trace_rv_i_valid_ip),
        .trace_rv_i_address_ip   (trace_rv_i_address_ip),
        .trace_rv_i_insn_ip      (trace_rv_i_insn_ip),
        .trace_rv_i_exception_ip (trace_rv_i_exception_ip),
        .trace_rv_i_ecause_ip    (),
        .trace_rv_i_interrupt_ip (trace_rv_i_interrupt_ip),
        .trace_rv_i_tval_ip      (),

        // LSU AXI Interface
        .lsu_axi_awvalid (lsu_axi_awvalid),
        .lsu_axi_awready (lsu_axi_awready),
        .lsu_axi_awid    (lsu_axi_awid),
        .lsu_axi_awaddr  (lsu_axi_awaddr),
        .lsu_axi_awregion(lsu_axi_awregion),
        .lsu_axi_awlen   (lsu_axi_awlen),
        .lsu_axi_awsize  (lsu_axi_awsize),
        .lsu_axi_awburst (lsu_axi_awburst),
        .lsu_axi_awlock  (lsu_axi_awlock),
        .lsu_axi_awcache (lsu_axi_awcache),
        .lsu_axi_awprot  (lsu_axi_awprot),
        .lsu_axi_awqos   (lsu_axi_awqos),

        .lsu_axi_wvalid  (lsu_axi_wvalid),
        .lsu_axi_wready  (lsu_axi_wready),
        .lsu_axi_wdata   (lsu_axi_wdata),
        .lsu_axi_wstrb   (lsu_axi_wstrb),
        .lsu_axi_wlast   (lsu_axi_wlast),

        .lsu_axi_bvalid  (lsu_axi_bvalid),
        .lsu_axi_bready  (lsu_axi_bready),
        .lsu_axi_bresp   (lsu_axi_bresp),
        .lsu_axi_bid     (lsu_axi_bid),

        .lsu_axi_arvalid (lsu_axi_arvalid),
        .lsu_axi_arready (lsu_axi_arready),
        .lsu_axi_arid    (lsu_axi_arid),
        .lsu_axi_araddr  (lsu_axi_araddr),
        .lsu_axi_arregion(lsu_axi_arregion),
        .lsu_axi_arlen   (lsu_axi_arlen),
        .lsu_axi_arsize  (lsu_axi_arsize),
        .lsu_axi_arburst (lsu_axi_arburst),
        .lsu_axi_arlock  (lsu_axi_arlock),
        .lsu_axi_arcache (lsu_axi_arcache),
        .lsu_axi_arprot  (lsu_axi_arprot),
        .lsu_axi_arqos   (lsu_axi_arqos),

        .lsu_axi_rvalid  (lsu_axi_rvalid),
        .lsu_axi_rready  (lsu_axi_rready),
        .lsu_axi_rid     (lsu_axi_rid),
        .lsu_axi_rdata   (lsu_axi_rdata),
        .lsu_axi_rresp   (lsu_axi_rresp),
        .lsu_axi_rlast   (lsu_axi_rlast),

        // IFU AXI Interface
        .ifu_axi_awvalid (),
        .ifu_axi_awready (ifu_axi_awready),
        .ifu_axi_awid    (),
        .ifu_axi_awaddr  (),
        .ifu_axi_awregion(),
        .ifu_axi_awlen   (),
        .ifu_axi_awsize  (),
        .ifu_axi_awburst (),
        .ifu_axi_awlock  (),
        .ifu_axi_awcache (),
        .ifu_axi_awprot  (),
        .ifu_axi_awqos   (),
        .ifu_axi_wvalid  (),
        .ifu_axi_wready  (ifu_axi_wready),
        .ifu_axi_wdata   (),
        .ifu_axi_wstrb   (),
        .ifu_axi_wlast   (),
        .ifu_axi_bvalid  (ifu_axi_bvalid),
        .ifu_axi_bready  (),
        .ifu_axi_bresp   (ifu_axi_bresp),
        .ifu_axi_bid     (ifu_axi_bid),
        .ifu_axi_arvalid (),
        .ifu_axi_arready (ifu_axi_arready),
        .ifu_axi_arid    (),
        .ifu_axi_araddr  (),
        .ifu_axi_arregion(),
        .ifu_axi_arlen   (),
        .ifu_axi_arsize  (),
        .ifu_axi_arburst (),
        .ifu_axi_arlock  (),
        .ifu_axi_arcache (),
        .ifu_axi_arprot  (),
        .ifu_axi_arqos   (),
        .ifu_axi_rvalid  (ifu_axi_rvalid),
        .ifu_axi_rready  (),
        .ifu_axi_rid     (ifu_axi_rid),
        .ifu_axi_rdata   (ifu_axi_rdata),
        .ifu_axi_rresp   (ifu_axi_rresp),
        .ifu_axi_rlast   (ifu_axi_rlast),

        // SB AXI Interface
        .sb_axi_awvalid  (),
        .sb_axi_awready  (sb_axi_awready),
        .sb_axi_awid     (),
        .sb_axi_awaddr   (),
        .sb_axi_awregion (),
        .sb_axi_awlen    (),
        .sb_axi_awsize   (),
        .sb_axi_awburst  (),
        .sb_axi_awlock   (),
        .sb_axi_awcache  (),
        .sb_axi_awprot   (),
        .sb_axi_awqos    (),
        .sb_axi_wvalid   (),
        .sb_axi_wready   (sb_axi_wready),
        .sb_axi_wdata    (),
        .sb_axi_wstrb    (),
        .sb_axi_wlast    (),
        .sb_axi_bvalid   (sb_axi_bvalid),
        .sb_axi_bready   (),
        .sb_axi_bresp    (sb_axi_bresp),
        .sb_axi_bid      (sb_axi_bid),
        .sb_axi_arvalid  (),
        .sb_axi_arready  (sb_axi_arready),
        .sb_axi_arid     (),
        .sb_axi_araddr   (),
        .sb_axi_arregion (),
        .sb_axi_arlen    (),
        .sb_axi_arsize   (),
        .sb_axi_arburst  (),
        .sb_axi_arlock   (),
        .sb_axi_arcache  (),
        .sb_axi_arprot   (),
        .sb_axi_arqos    (),
        .sb_axi_rvalid   (sb_axi_rvalid),
        .sb_axi_rready   (),
        .sb_axi_rid      (sb_axi_rid),
        .sb_axi_rdata    (sb_axi_rdata),
        .sb_axi_rresp    (sb_axi_rresp),
        .sb_axi_rlast    (sb_axi_rlast),

        // Inbound DMA AXI Slave
        .dma_axi_awvalid (dma_axi_awvalid),
        .dma_axi_awready (),
        .dma_axi_awid    (dma_axi_awid),
        .dma_axi_awaddr  (dma_axi_awaddr),
        .dma_axi_awsize  (dma_axi_awsize),
        .dma_axi_awprot  (dma_axi_awprot),
        .dma_axi_awlen   (dma_axi_awlen),
        .dma_axi_awburst (dma_axi_awburst),
        .dma_axi_wvalid  (dma_axi_wvalid),
        .dma_axi_wready  (),
        .dma_axi_wdata   (dma_axi_wdata),
        .dma_axi_wstrb   (dma_axi_wstrb),
        .dma_axi_wlast   (dma_axi_wlast),
        .dma_axi_bvalid  (),
        .dma_axi_bready  (dma_axi_bready),
        .dma_axi_bresp   (),
        .dma_axi_bid     (),
        .dma_axi_arvalid (dma_axi_arvalid),
        .dma_axi_arready (),
        .dma_axi_arid    (dma_axi_arid),
        .dma_axi_araddr  (dma_axi_araddr),
        .dma_axi_arsize  (dma_axi_arsize),
        .dma_axi_arprot  (dma_axi_arprot),
        .dma_axi_arlen   (dma_axi_arlen),
        .dma_axi_arburst (dma_axi_arburst),
        .dma_axi_rvalid  (),
        .dma_axi_rready  (dma_axi_rready),
        .dma_axi_rid     (),
        .dma_axi_rdata   (),
        .dma_axi_rresp   (),
        .dma_axi_rlast   (),

        // Memory interfaces
        .el2_mem_export  (el2_mem_export.veer_sram_src),
        .el2_icache_export(el2_icache_export.veer_icache_src),

        // Clocks & Interrupts
        .lsu_bus_clk_en  (1'b1),
        .ifu_bus_clk_en  (1'b1),
        .dbg_bus_clk_en  (1'b1),
        .dma_bus_clk_en  (1'b1),
        .timer_int       (1'b0),
        .soft_int        (1'b0),
        .extintsrc_req   (extintsrc_req),

        // JTAG (tied idle)
        .jtag_tck        (1'b0),
        .jtag_tms        (1'b0),
        .jtag_tdi        (1'b0),
        .jtag_trst_n     (1'b1),
        .jtag_tdo        (),
        .jtag_tdoEn      (),
        .core_id         (28'h0)
    );

    // -------------------------------------------------------------------------
    // 32-bit Interconnect Master Port S00 Signals
    // -------------------------------------------------------------------------
    wire                  s00_axi_awvalid;
    wire                  s00_axi_awready;
    wire [ID_WIDTH-1:0]   s00_axi_awid;
    wire [ADDR_WIDTH-1:0] s00_axi_awaddr;
    wire [7:0]            s00_axi_awlen;
    wire [2:0]            s00_axi_awsize;
    wire [1:0]            s00_axi_awburst;
    wire                  s00_axi_awlock;
    wire [3:0]            s00_axi_awcache;
    wire [2:0]            s00_axi_awprot;
    wire [3:0]            s00_axi_awregion;
    wire [3:0]            s00_axi_awqos;

    wire                  s00_axi_wvalid;
    wire                  s00_axi_wready;
    wire [DATA_WIDTH-1:0] s00_axi_wdata;
    wire [STRB_WIDTH-1:0] s00_axi_wstrb;
    wire                  s00_axi_wlast;

    wire                  s00_axi_bvalid;
    wire                  s00_axi_bready;
    wire [1:0]            s00_axi_bresp;
    wire [ID_WIDTH-1:0]   s00_axi_bid;

    wire                  s00_axi_arvalid;
    wire                  s00_axi_arready;
    wire [ID_WIDTH-1:0]   s00_axi_arid;
    wire [ADDR_WIDTH-1:0] s00_axi_araddr;
    wire [7:0]            s00_axi_arlen;
    wire [2:0]            s00_axi_arsize;
    wire [1:0]            s00_axi_arburst;
    wire                  s00_axi_arlock;
    wire [3:0]            s00_axi_arcache;
    wire [2:0]            s00_axi_arprot;
    wire [3:0]            s00_axi_arregion;
    wire [3:0]            s00_axi_arqos;

    wire                  s00_axi_rvalid;
    wire                  s00_axi_rready;
    wire [DATA_WIDTH-1:0] s00_axi_rdata;
    wire [1:0]            s00_axi_rresp;
    wire [ID_WIDTH-1:0]   s00_axi_rid;
    wire                  s00_axi_rlast;

    // -------------------------------------------------------------------------
    // AXI 64-to-32 Width Adapter Bridge
    // -------------------------------------------------------------------------
    axi_lsu_dwidth_adapter #(
        .TAG_WIDTH  (pt.LSU_BUS_TAG),
        .ID_WIDTH   (ID_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) lsu_dwidth_conv (
        .clk             (sys_clk),
        .rst_n           (sys_rst_n),

        // VeeR 64-bit LSU side
        .s_lsu_awvalid   (lsu_axi_awvalid),
        .s_lsu_awready   (lsu_axi_awready),
        .s_lsu_awid      (lsu_axi_awid),
        .s_lsu_awaddr    (lsu_axi_awaddr),
        .s_lsu_awlen     (lsu_axi_awlen),
        .s_lsu_awsize    (lsu_axi_awsize),
        .s_lsu_awburst   (lsu_axi_awburst),
        .s_lsu_awlock    (lsu_axi_awlock),
        .s_lsu_awcache   (lsu_axi_awcache),
        .s_lsu_awprot    (lsu_axi_awprot),
        .s_lsu_awregion  (lsu_axi_awregion),
        .s_lsu_awqos     (lsu_axi_awqos),

        .s_lsu_wvalid    (lsu_axi_wvalid),
        .s_lsu_wready    (lsu_axi_wready),
        .s_lsu_wdata     (lsu_axi_wdata),
        .s_lsu_wstrb     (lsu_axi_wstrb),
        .s_lsu_wlast     (lsu_axi_wlast),

        .s_lsu_bvalid    (lsu_axi_bvalid),
        .s_lsu_bready    (lsu_axi_bready),
        .s_lsu_bresp     (lsu_axi_bresp),
        .s_lsu_bid       (lsu_axi_bid),

        .s_lsu_arvalid   (lsu_axi_arvalid),
        .s_lsu_arready   (lsu_axi_arready),
        .s_lsu_arid      (lsu_axi_arid),
        .s_lsu_araddr    (lsu_axi_araddr),
        .s_lsu_arlen     (lsu_axi_arlen),
        .s_lsu_arsize    (lsu_axi_arsize),
        .s_lsu_arburst   (lsu_axi_arburst),
        .s_lsu_arlock    (lsu_axi_arlock),
        .s_lsu_arcache   (lsu_axi_arcache),
        .s_lsu_arprot    (lsu_axi_arprot),
        .s_lsu_arregion  (lsu_axi_arregion),
        .s_lsu_arqos     (lsu_axi_arqos),

        .s_lsu_rvalid    (lsu_axi_rvalid),
        .s_lsu_rready    (lsu_axi_rready),
        .s_lsu_rdata     (lsu_axi_rdata),
        .s_lsu_rresp     (lsu_axi_rresp),
        .s_lsu_rid       (lsu_axi_rid),
        .s_lsu_rlast     (lsu_axi_rlast),

        // 32-bit Interconnect side (S00)
        .m_axi_awvalid   (s00_axi_awvalid),
        .m_axi_awready   (s00_axi_awready),
        .m_axi_awid      (s00_axi_awid),
        .m_axi_awaddr    (s00_axi_awaddr),
        .m_axi_awlen     (s00_axi_awlen),
        .m_axi_awsize    (s00_axi_awsize),
        .m_axi_awburst   (s00_axi_awburst),
        .m_axi_awlock    (s00_axi_awlock),
        .m_axi_awcache   (s00_axi_awcache),
        .m_axi_awprot    (s00_axi_awprot),
        .m_axi_awregion  (s00_axi_awregion),
        .m_axi_awqos     (s00_axi_awqos),

        .m_axi_wvalid    (s00_axi_wvalid),
        .m_axi_wready    (s00_axi_wready),
        .m_axi_wdata     (s00_axi_wdata),
        .m_axi_wstrb     (s00_axi_wstrb),
        .m_axi_wlast     (s00_axi_wlast),

        .m_axi_bvalid    (s00_axi_bvalid),
        .m_axi_bready    (s00_axi_bready),
        .m_axi_bresp     (s00_axi_bresp),
        .m_axi_bid       (s00_axi_bid),

        .m_axi_arvalid   (s00_axi_arvalid),
        .m_axi_arready   (s00_axi_arready),
        .m_axi_arid      (s00_axi_arid),
        .m_axi_araddr    (s00_axi_araddr),
        .m_axi_arlen     (s00_axi_arlen),
        .m_axi_arsize    (s00_axi_arsize),
        .m_axi_arburst   (s00_axi_arburst),
        .m_axi_arlock    (s00_axi_arlock),
        .m_axi_arcache   (s00_axi_arcache),
        .m_axi_arprot    (s00_axi_arprot),
        .m_axi_arregion  (s00_axi_arregion),
        .m_axi_arqos     (s00_axi_arqos),

        .m_axi_rvalid    (s00_axi_rvalid),
        .m_axi_rready    (s00_axi_rready),
        .m_axi_rdata     (s00_axi_rdata),
        .m_axi_rresp     (s00_axi_rresp),
        .m_axi_rid       (s00_axi_rid),
        .m_axi_rlast     (s00_axi_rlast)
    );

    // -------------------------------------------------------------------------
    // Peripheral Slave Interconnect Master Ports M00 - M05
    // -------------------------------------------------------------------------
    // M00: UART
    wire [ADDR_WIDTH-1:0] m00_axi_awaddr, m00_axi_araddr;
    wire [2:0]            m00_axi_awprot, m00_axi_arprot;
    wire                  m00_axi_awvalid, m00_axi_awready;
    wire [DATA_WIDTH-1:0] m00_axi_wdata, m00_axi_rdata;
    wire [STRB_WIDTH-1:0] m00_axi_wstrb;
    wire                  m00_axi_wvalid, m00_axi_wready;
    wire [1:0]            m00_axi_bresp, m00_axi_rresp;
    wire                  m00_axi_bvalid, m00_axi_bready;
    wire                  m00_axi_arvalid, m00_axi_arready;
    wire                  m00_axi_rvalid, m00_axi_rready;

    // M01: Timer
    wire [ADDR_WIDTH-1:0] m01_axi_awaddr, m01_axi_araddr;
    wire [2:0]            m01_axi_awprot, m01_axi_arprot;
    wire                  m01_axi_awvalid, m01_axi_awready;
    wire [DATA_WIDTH-1:0] m01_axi_wdata, m01_axi_rdata;
    wire [STRB_WIDTH-1:0] m01_axi_wstrb;
    wire                  m01_axi_wvalid, m01_axi_wready;
    wire [1:0]            m01_axi_bresp, m01_axi_rresp;
    wire                  m01_axi_bvalid, m01_axi_bready;
    wire                  m01_axi_arvalid, m01_axi_arready;
    wire                  m01_axi_rvalid, m01_axi_rready;

    // M02: GPIO
    wire [ADDR_WIDTH-1:0] m02_axi_awaddr, m02_axi_araddr;
    wire [2:0]            m02_axi_awprot, m02_axi_arprot;
    wire                  m02_axi_awvalid, m02_axi_awready;
    wire [DATA_WIDTH-1:0] m02_axi_wdata, m02_axi_rdata;
    wire [STRB_WIDTH-1:0] m02_axi_wstrb;
    wire                  m02_axi_wvalid, m02_axi_wready;
    wire [1:0]            m02_axi_bresp, m02_axi_rresp;
    wire                  m02_axi_bvalid, m02_axi_bready;
    wire                  m02_axi_arvalid, m02_axi_arready;
    wire                  m02_axi_rvalid, m02_axi_rready;

    // M03: SPI
    wire [ADDR_WIDTH-1:0] m03_axi_awaddr, m03_axi_araddr;
    wire [2:0]            m03_axi_awprot, m03_axi_arprot;
    wire                  m03_axi_awvalid, m03_axi_awready;
    wire [DATA_WIDTH-1:0] m03_axi_wdata, m03_axi_rdata;
    wire [STRB_WIDTH-1:0] m03_axi_wstrb;
    wire                  m03_axi_wvalid, m03_axi_wready;
    wire [1:0]            m03_axi_bresp, m03_axi_rresp;
    wire                  m03_axi_bvalid, m03_axi_bready;
    wire                  m03_axi_arvalid, m03_axi_arready;
    wire                  m03_axi_rvalid, m03_axi_rready;

    // M04: SEG7
    wire [ADDR_WIDTH-1:0] m04_axi_awaddr, m04_axi_araddr;
    wire [2:0]            m04_axi_awprot, m04_axi_arprot;
    wire                  m04_axi_awvalid, m04_axi_awready;
    wire [DATA_WIDTH-1:0] m04_axi_wdata, m04_axi_rdata;
    wire [STRB_WIDTH-1:0] m04_axi_wstrb;
    wire                  m04_axi_wvalid, m04_axi_wready;
    wire [1:0]            m04_axi_bresp, m04_axi_rresp;
    wire                  m04_axi_bvalid, m04_axi_bready;
    wire                  m04_axi_arvalid, m04_axi_arready;
    wire                  m04_axi_rvalid, m04_axi_rready;

    // M05: PWM
    wire [ADDR_WIDTH-1:0] m05_axi_awaddr, m05_axi_araddr;
    wire [2:0]            m05_axi_awprot, m05_axi_arprot;
    wire                  m05_axi_awvalid, m05_axi_awready;
    wire [DATA_WIDTH-1:0] m05_axi_wdata, m05_axi_rdata;
    wire [STRB_WIDTH-1:0] m05_axi_wstrb;
    wire                  m05_axi_wvalid, m05_axi_wready;
    wire [1:0]            m05_axi_bresp, m05_axi_rresp;
    wire                  m05_axi_bvalid, m05_axi_bready;
    wire                  m05_axi_arvalid, m05_axi_arready;
    wire                  m05_axi_rvalid, m05_axi_rready;

    // -------------------------------------------------------------------------
    // 2x6 Crossbar Interconnect
    // S00: VeeR LSU, S01: Tied off
    // M00-M05: UART, Timer, GPIO, SPI, SEG7, PWM
    // -------------------------------------------------------------------------
    axi_interconnect_wrap_2x6 #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH),
        .STRB_WIDTH (STRB_WIDTH),
        .ID_WIDTH   (ID_WIDTH)
    ) system_interconnect (
        .clk              (sys_clk),
        .rst              (sys_rst),

        // S00: VeeR CPU Master
        .s00_axi_awid     (s00_axi_awid),
        .s00_axi_awaddr   (s00_axi_awaddr),
        .s00_axi_awlen    (s00_axi_awlen),
        .s00_axi_awsize   (s00_axi_awsize),
        .s00_axi_awburst  (s00_axi_awburst),
        .s00_axi_awlock   (s00_axi_awlock),
        .s00_axi_awcache  (s00_axi_awcache),
        .s00_axi_awprot   (s00_axi_awprot),
        .s00_axi_awqos    (s00_axi_awqos),
        .s00_axi_awuser   (1'b0),
        .s00_axi_awvalid  (s00_axi_awvalid),
        .s00_axi_awready  (s00_axi_awready),
        .s00_axi_wdata    (s00_axi_wdata),
        .s00_axi_wstrb    (s00_axi_wstrb),
        .s00_axi_wlast    (s00_axi_wlast),
        .s00_axi_wuser    (1'b0),
        .s00_axi_wvalid   (s00_axi_wvalid),
        .s00_axi_wready   (s00_axi_wready),
        .s00_axi_bid      (s00_axi_bid),
        .s00_axi_bresp    (s00_axi_bresp),
        .s00_axi_buser    (),
        .s00_axi_bvalid   (s00_axi_bvalid),
        .s00_axi_bready   (s00_axi_bready),
        .s00_axi_arid     (s00_axi_arid),
        .s00_axi_araddr   (s00_axi_araddr),
        .s00_axi_arlen    (s00_axi_arlen),
        .s00_axi_arsize   (s00_axi_arsize),
        .s00_axi_arburst  (s00_axi_arburst),
        .s00_axi_arlock   (s00_axi_arlock),
        .s00_axi_arcache  (s00_axi_arcache),
        .s00_axi_arprot   (s00_axi_arprot),
        .s00_axi_arqos    (s00_axi_arqos),
        .s00_axi_aruser   (1'b0),
        .s00_axi_arvalid  (s00_axi_arvalid),
        .s00_axi_arready  (s00_axi_arready),
        .s00_axi_rid      (s00_axi_rid),
        .s00_axi_rdata    (s00_axi_rdata),
        .s00_axi_rresp    (s00_axi_rresp),
        .s00_axi_rlast    (s00_axi_rlast),
        .s00_axi_ruser    (),
        .s00_axi_rvalid   (s00_axi_rvalid),
        .s00_axi_rready   (s00_axi_rready),

        // S01: Tied Off Master
        .s01_axi_awid     ({ID_WIDTH{1'b0}}),
        .s01_axi_awaddr   ({ADDR_WIDTH{1'b0}}),
        .s01_axi_awlen    (8'h00),
        .s01_axi_awsize   (3'b010),
        .s01_axi_awburst  (2'b01),
        .s01_axi_awlock   (1'b0),
        .s01_axi_awcache  (4'b0000),
        .s01_axi_awprot   (3'b000),
        .s01_axi_awqos    (4'b0000),
        .s01_axi_awuser   (1'b0),
        .s01_axi_awvalid  (1'b0),
        .s01_axi_awready  (),
        .s01_axi_wdata    ({DATA_WIDTH{1'b0}}),
        .s01_axi_wstrb    ({STRB_WIDTH{1'b0}}),
        .s01_axi_wlast    (1'b0),
        .s01_axi_wuser    (1'b0),
        .s01_axi_wvalid   (1'b0),
        .s01_axi_wready   (),
        .s01_axi_bid      (),
        .s01_axi_bresp    (),
        .s01_axi_buser    (),
        .s01_axi_bvalid   (),
        .s01_axi_bready   (1'b1),
        .s01_axi_arid     ({ID_WIDTH{1'b0}}),
        .s01_axi_araddr   ({ADDR_WIDTH{1'b0}}),
        .s01_axi_arlen    (8'h00),
        .s01_axi_arsize   (3'b010),
        .s01_axi_arburst  (2'b01),
        .s01_axi_arlock   (1'b0),
        .s01_axi_arcache  (4'b0000),
        .s01_axi_arprot   (3'b000),
        .s01_axi_arqos    (4'b0000),
        .s01_axi_aruser   (1'b0),
        .s01_axi_arvalid  (1'b0),
        .s01_axi_arready  (),
        .s01_axi_rid      (),
        .s01_axi_rdata    (),
        .s01_axi_rresp    (),
        .s01_axi_rlast    (),
        .s01_axi_ruser    (),
        .s01_axi_rvalid   (),
        .s01_axi_rready   (1'b1),

        // M00: UART
        .m00_axi_awaddr   (m00_axi_awaddr),
        .m00_axi_awprot   (m00_axi_awprot),
        .m00_axi_awvalid  (m00_axi_awvalid),
        .m00_axi_awready  (m00_axi_awready),
        .m00_axi_wdata    (m00_axi_wdata),
        .m00_axi_wstrb    (m00_axi_wstrb),
        .m00_axi_wvalid   (m00_axi_wvalid),
        .m00_axi_wready   (m00_axi_wready),
        .m00_axi_bresp    (m00_axi_bresp),
        .m00_axi_bvalid   (m00_axi_bvalid),
        .m00_axi_bready   (m00_axi_bready),
        .m00_axi_araddr   (m00_axi_araddr),
        .m00_axi_arprot   (m00_axi_arprot),
        .m00_axi_arvalid  (m00_axi_arvalid),
        .m00_axi_arready  (m00_axi_arready),
        .m00_axi_rdata    (m00_axi_rdata),
        .m00_axi_rresp    (m00_axi_rresp),
        .m00_axi_rvalid   (m00_axi_rvalid),
        .m00_axi_rready   (m00_axi_rready),

        // M01: Timer
        .m01_axi_awaddr   (m01_axi_awaddr),
        .m01_axi_awprot   (m01_axi_awprot),
        .m01_axi_awvalid  (m01_axi_awvalid),
        .m01_axi_awready  (m01_axi_awready),
        .m01_axi_wdata    (m01_axi_wdata),
        .m01_axi_wstrb    (m01_axi_wstrb),
        .m01_axi_wvalid   (m01_axi_wvalid),
        .m01_axi_wready   (m01_axi_wready),
        .m01_axi_bresp    (m01_axi_bresp),
        .m01_axi_bvalid   (m01_axi_bvalid),
        .m01_axi_bready   (m01_axi_bready),
        .m01_axi_araddr   (m01_axi_araddr),
        .m01_axi_arprot   (m01_axi_arprot),
        .m01_axi_arvalid  (m01_axi_arvalid),
        .m01_axi_arready  (m01_axi_arready),
        .m01_axi_rdata    (m01_axi_rdata),
        .m01_axi_rresp    (m01_axi_rresp),
        .m01_axi_rvalid   (m01_axi_rvalid),
        .m01_axi_rready   (m01_axi_rready),

        // M02: GPIO
        .m02_axi_awaddr   (m02_axi_awaddr),
        .m02_axi_awprot   (m02_axi_awprot),
        .m02_axi_awvalid  (m02_axi_awvalid),
        .m02_axi_awready  (m02_axi_awready),
        .m02_axi_wdata    (m02_axi_wdata),
        .m02_axi_wstrb    (m02_axi_wstrb),
        .m02_axi_wvalid   (m02_axi_wvalid),
        .m02_axi_wready   (m02_axi_wready),
        .m02_axi_bresp    (m02_axi_bresp),
        .m02_axi_bvalid   (m02_axi_bvalid),
        .m02_axi_bready   (m02_axi_bready),
        .m02_axi_araddr   (m02_axi_araddr),
        .m02_axi_arprot   (m02_axi_arprot),
        .m02_axi_arvalid  (m02_axi_arvalid),
        .m02_axi_arready  (m02_axi_arready),
        .m02_axi_rdata    (m02_axi_rdata),
        .m02_axi_rresp    (m02_axi_rresp),
        .m02_axi_rvalid   (m02_axi_rvalid),
        .m02_axi_rready   (m02_axi_rready),

        // M03: SPI
        .m03_axi_awaddr   (m03_axi_awaddr),
        .m03_axi_awprot   (m03_axi_awprot),
        .m03_axi_awvalid  (m03_axi_awvalid),
        .m03_axi_awready  (m03_axi_awready),
        .m03_axi_wdata    (m03_axi_wdata),
        .m03_axi_wstrb    (m03_axi_wstrb),
        .m03_axi_wvalid   (m03_axi_wvalid),
        .m03_axi_wready   (m03_axi_wready),
        .m03_axi_bresp    (m03_axi_bresp),
        .m03_axi_bvalid   (m03_axi_bvalid),
        .m03_axi_bready   (m03_axi_bready),
        .m03_axi_araddr   (m03_axi_araddr),
        .m03_axi_arprot   (m03_axi_arprot),
        .m03_axi_arvalid  (m03_axi_arvalid),
        .m03_axi_arready  (m03_axi_arready),
        .m03_axi_rdata    (m03_axi_rdata),
        .m03_axi_rresp    (m03_axi_rresp),
        .m03_axi_rvalid   (m03_axi_rvalid),
        .m03_axi_rready   (m03_axi_rready),

        // M04: SEG7
        .m04_axi_awaddr   (m04_axi_awaddr),
        .m04_axi_awprot   (m04_axi_awprot),
        .m04_axi_awvalid  (m04_axi_awvalid),
        .m04_axi_awready  (m04_axi_awready),
        .m04_axi_wdata    (m04_axi_wdata),
        .m04_axi_wstrb    (m04_axi_wstrb),
        .m04_axi_wvalid   (m04_axi_wvalid),
        .m04_axi_wready   (m04_axi_wready),
        .m04_axi_bresp    (m04_axi_bresp),
        .m04_axi_bvalid   (m04_axi_bvalid),
        .m04_axi_bready   (m04_axi_bready),
        .m04_axi_araddr   (m04_axi_araddr),
        .m04_axi_arprot   (m04_axi_arprot),
        .m04_axi_arvalid  (m04_axi_arvalid),
        .m04_axi_arready  (m04_axi_arready),
        .m04_axi_rdata    (m04_axi_rdata),
        .m04_axi_rresp    (m04_axi_rresp),
        .m04_axi_rvalid   (m04_axi_rvalid),
        .m04_axi_rready   (m04_axi_rready),

        // M05: PWM
        .m05_axi_awaddr   (m05_axi_awaddr),
        .m05_axi_awprot   (m05_axi_awprot),
        .m05_axi_awvalid  (m05_axi_awvalid),
        .m05_axi_awready  (m05_axi_awready),
        .m05_axi_wdata    (m05_axi_wdata),
        .m05_axi_wstrb    (m05_axi_wstrb),
        .m05_axi_wvalid   (m05_axi_wvalid),
        .m05_axi_wready   (m05_axi_wready),
        .m05_axi_bresp    (m05_axi_bresp),
        .m05_axi_bvalid   (m05_axi_bvalid),
        .m05_axi_bready   (m05_axi_bready),
        .m05_axi_araddr   (m05_axi_araddr),
        .m05_axi_arprot   (m05_axi_arprot),
        .m05_axi_arvalid  (m05_axi_arvalid),
        .m05_axi_arready  (m05_axi_arready),
        .m05_axi_rdata    (m05_axi_rdata),
        .m05_axi_rresp    (m05_axi_rresp),
        .m05_axi_rvalid   (m05_axi_rvalid),
        .m05_axi_rready   (m05_axi_rready)
    );

    // -------------------------------------------------------------------------
    // Peripheral Subsystems Instantiations
    // -------------------------------------------------------------------------
    // M00: UART
    axi_uart_top uart_inst (
        .s_axi_aclk    (sys_clk),
        .s_axi_aresetn (sys_rst_n),
        .s_axi_awaddr  (m00_axi_awaddr[4:0]),
        .s_axi_awvalid (m00_axi_awvalid),
        .s_axi_awready (m00_axi_awready),
        .s_axi_wdata   (m00_axi_wdata),
        .s_axi_wstrb   (m00_axi_wstrb),
        .s_axi_wvalid  (m00_axi_wvalid),
        .s_axi_wready  (m00_axi_wready),
        .s_axi_bresp   (m00_axi_bresp),
        .s_axi_bvalid  (m00_axi_bvalid),
        .s_axi_bready  (m00_axi_bready),
        .s_axi_araddr  (m00_axi_araddr[4:0]),
        .s_axi_arvalid (m00_axi_arvalid),
        .s_axi_arready (m00_axi_arready),
        .s_axi_rdata   (m00_axi_rdata),
        .s_axi_rresp   (m00_axi_rresp),
        .s_axi_rvalid  (m00_axi_rvalid),
        .s_axi_rready  (m00_axi_rready),
        .uart_rx_i     (uart_rx_i),
        .uart_tx_o     (uart_tx_o),
        .interrupt_o   (uart_interrupt_o)
    );

    // M01: Hardware Timer
    axi_timer_top timer_inst (
        .clk           (sys_clk),
        .rst_n         (sys_rst_n),
        .s_axi_awaddr  (m01_axi_awaddr),
        .s_axi_awvalid (m01_axi_awvalid),
        .s_axi_awready (m01_axi_awready),
        .s_axi_wdata   (m01_axi_wdata),
        .s_axi_wstrb   (m01_axi_wstrb),
        .s_axi_wvalid  (m01_axi_wvalid),
        .s_axi_wready  (m01_axi_wready),
        .s_axi_bresp   (m01_axi_bresp),
        .s_axi_bvalid  (m01_axi_bvalid),
        .s_axi_bready  (m01_axi_bready),
        .s_axi_araddr  (m01_axi_araddr),
        .s_axi_arvalid (m01_axi_arvalid),
        .s_axi_arready (m01_axi_arready),
        .s_axi_rdata   (m01_axi_rdata),
        .s_axi_rresp   (m01_axi_rresp),
        .s_axi_rvalid  (m01_axi_rvalid),
        .s_axi_rready  (m01_axi_rready),
        .intr_timer    (timer_interrupt_o)
    );

    // M02: GPIO
    axi_gpio_top gpio_inst (
        .clk_i         (sys_clk),
        .rst_ni        (sys_rst_n),
        .s_axi_awaddr  (m02_axi_awaddr),
        .s_axi_awprot  (m02_axi_awprot),
        .s_axi_awvalid (m02_axi_awvalid),
        .s_axi_awready (m02_axi_awready),
        .s_axi_wdata   (m02_axi_wdata),
        .s_axi_wstrb   (m02_axi_wstrb),
        .s_axi_wvalid  (m02_axi_wvalid),
        .s_axi_wready  (m02_axi_wready),
        .s_axi_bresp   (m02_axi_bresp),
        .s_axi_bvalid  (m02_axi_bvalid),
        .s_axi_bready  (m02_axi_bready),
        .s_axi_araddr  (m02_axi_araddr),
        .s_axi_arprot  (m02_axi_arprot),
        .s_axi_arvalid (m02_axi_arvalid),
        .s_axi_arready (m02_axi_arready),
        .s_axi_rdata   (m02_axi_rdata),
        .s_axi_rresp   (m02_axi_rresp),
        .s_axi_rvalid  (m02_axi_rvalid),
        .s_axi_rready  (m02_axi_rready),
        .gpio_io       (gpio_io),
        .intr_gpio_o   (gpio_interrupt_o)
    );

    // M03: SPI Master
    axi_spi_top spi_inst (
        .s_axi_aclk    (sys_clk),
        .s_axi_aresetn (sys_rst_n),
        .s_axi_awaddr  (m03_axi_awaddr[6:0]),
        .s_axi_awvalid (m03_axi_awvalid),
        .s_axi_awready (m03_axi_awready),
        .s_axi_wdata   (m03_axi_wdata),
        .s_axi_wstrb   (m03_axi_wstrb),
        .s_axi_wvalid  (m03_axi_wvalid),
        .s_axi_wready  (m03_axi_wready),
        .s_axi_bresp   (m03_axi_bresp),
        .s_axi_bvalid  (m03_axi_bvalid),
        .s_axi_bready  (m03_axi_bready),
        .s_axi_araddr  (m03_axi_araddr[6:0]),
        .s_axi_arvalid (m03_axi_arvalid),
        .s_axi_arready (m03_axi_arready),
        .s_axi_rdata   (m03_axi_rdata),
        .s_axi_rresp   (m03_axi_rresp),
        .s_axi_rvalid  (m03_axi_rvalid),
        .s_axi_rready  (m03_axi_rready),
        .spi_clk_o     (spi_clk_o),
        .spi_mosi_o    (spi_mosi_o),
        .spi_miso_i    (spi_miso_i),
        .spi_cs_n_o    (spi_cs_n_o),
        .ip2intc_irpt  (spi_interrupt_o)
    );

    // M04: Seven-Segment Display Controller
    axi_seg7_top seg7_inst (
        .clk           (sys_clk),
        .rst_n         (sys_rst_n),
        .s_axi_awaddr  (m04_axi_awaddr),
        .s_axi_awprot  (m04_axi_awprot),
        .s_axi_awvalid (m04_axi_awvalid),
        .s_axi_awready (m04_axi_awready),
        .s_axi_wdata   (m04_axi_wdata),
        .s_axi_wstrb   (m04_axi_wstrb),
        .s_axi_wvalid  (m04_axi_wvalid),
        .s_axi_wready  (m04_axi_wready),
        .s_axi_bresp   (m04_axi_bresp),
        .s_axi_bvalid  (m04_axi_bvalid),
        .s_axi_bready  (m04_axi_bready),
        .s_axi_araddr  (m04_axi_araddr),
        .s_axi_arprot  (m04_axi_arprot),
        .s_axi_arvalid (m04_axi_arvalid),
        .s_axi_arready (m04_axi_arready),
        .s_axi_rdata   (m04_axi_rdata),
        .s_axi_rresp   (m04_axi_rresp),
        .s_axi_rvalid  (m04_axi_rvalid),
        .s_axi_rready  (m04_axi_rready),
        .seg_o         (seg7_seg_o),
        .an_o          (seg7_an_o)
    );

    // M05: PWM Generator
    myip_v1_0 #(
        .C_S00_AXI_DATA_WIDTH (DATA_WIDTH),
        .C_S00_AXI_ADDR_WIDTH (4)
    ) pwm_inst (
        .pwm_out       (pwm_out_o),
        .s00_axi_aclk   (sys_clk),
        .s00_axi_aresetn(sys_rst_n),
        .s00_axi_awaddr (m05_axi_awaddr[3:0]),
        .s00_axi_awprot (m05_axi_awprot),
        .s00_axi_awvalid(m05_axi_awvalid),
        .s00_axi_awready(m05_axi_awready),
        .s00_axi_wdata  (m05_axi_wdata),
        .s00_axi_wstrb  (m05_axi_wstrb),
        .s00_axi_wvalid (m05_axi_wvalid),
        .s00_axi_wready (m05_axi_wready),
        .s00_axi_bresp  (m05_axi_bresp),
        .s00_axi_bvalid (m05_axi_bvalid),
        .s00_axi_bready (m05_axi_bready),
        .s00_axi_araddr (m05_axi_araddr[3:0]),
        .s00_axi_arprot (m05_axi_arprot),
        .s00_axi_arvalid(m05_axi_arvalid),
        .s00_axi_arready(m05_axi_arready),
        .s00_axi_rdata  (m05_axi_rdata),
        .s00_axi_rresp  (m05_axi_rresp),
        .s00_axi_rvalid (m05_axi_rvalid),
        .s00_axi_rready (m05_axi_rready)
    );

endmodule

