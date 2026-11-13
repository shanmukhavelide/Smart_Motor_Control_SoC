// =============================================================================
// Module: veer_mem_subsystem
// Description: Instantiates behavioral dual-port SRAM banks for VeeR EL2:
// - ICCM: 4 banks of ram_4096x39 (64 KB, 32-bit data + 7-bit ECC)
// - DCCM: 4 banks of ram_4096x39 (64 KB, 32-bit data + 7-bit ECC)
// - ICACHE: 2 ways x 2 banks of ram_512x71 (16 KB) + 2 ways of ram_64x26
// Binds directly to el2_mem_export and el2_icache_export interface handles.
// =============================================================================

`timescale 1ns/1ps

`include "common_defines.vh"

module veer_mem_subsystem
import el2_pkg::*;
#(
`include "el2_param.vh"
)(
    input  wire        clk,
    input  wire        rst_n,

    // SRAM Interfaces exported from el2_veer_wrapper
    el2_mem_if.veer_sram_sink   mem_export,
    el2_mem_if.veer_icache_src  icache_export
);

    // -------------------------------------------------------------------------
    // 1. DCCM SRAM Arrays (4 Banks x 4096 x 39 bits = 64 KB)
    // -------------------------------------------------------------------------
    wire [38:0] dccm_bank_fdout [pt.DCCM_NUM_BANKS-1:0];

    genvar d;
    generate
        for (d = 0; d < pt.DCCM_NUM_BANKS; d = d + 1) begin : gen_dccm_banks
            wire [38:0] dccm_wr_data = {mem_export.dccm_wr_ecc_bank[d], mem_export.dccm_wr_data_bank[d]};

            ram_4096x39 dccm_bank_inst (
                .CLK      (mem_export.clk),
                .ME       (mem_export.dccm_clken[d]),
                .WE       (mem_export.dccm_wren_bank[d]),
                .ADR      (mem_export.dccm_addr_bank[d]),
                .D        (dccm_wr_data),
                .Q        (dccm_bank_fdout[d]),
                .ROP      (),
                .TEST1    (1'b0),
                .RME      (1'b0),
                .RM       (4'b0000),
                .LS       (1'b0),
                .DS       (1'b0),
                .SD       (1'b0),
                .TEST_RNM (1'b0),
                .BC1      (1'b0),
                .BC2      (1'b0)
            );

            assign mem_export.dccm_bank_dout[d] = dccm_bank_fdout[d][31:0];
            assign mem_export.dccm_bank_ecc[d]  = dccm_bank_fdout[d][38:32];
        end
    endgenerate

    // -------------------------------------------------------------------------
    // 2. ICCM SRAM Arrays (4 Banks x 4096 x 39 bits = 64 KB)
    // -------------------------------------------------------------------------
    wire [38:0] iccm_bank_fdout [pt.ICCM_NUM_BANKS-1:0];

    genvar c;
    generate
        for (c = 0; c < pt.ICCM_NUM_BANKS; c = c + 1) begin : gen_iccm_banks
            wire [38:0] iccm_wr_data = {mem_export.iccm_bank_wr_ecc[c], mem_export.iccm_bank_wr_data[c]};

            ram_4096x39 iccm_bank_inst (
                .CLK      (mem_export.clk),
                .ME       (mem_export.iccm_clken[c]),
                .WE       (mem_export.iccm_wren_bank[c]),
                .ADR      (mem_export.iccm_addr_bank[c]),
                .D        (iccm_wr_data),
                .Q        (iccm_bank_fdout[c]),
                .ROP      (),
                .TEST1    (1'b0),
                .RME      (1'b0),
                .RM       (4'b0000),
                .LS       (1'b0),
                .DS       (1'b0),
                .SD       (1'b0),
                .TEST_RNM (1'b0),
                .BC1      (1'b0),
                .BC2      (1'b0)
            );

            assign mem_export.iccm_bank_dout[c] = iccm_bank_fdout[c][31:0];
            assign mem_export.iccm_bank_ecc[c]  = iccm_bank_fdout[c][38:32];
        end
    endgenerate

    // -------------------------------------------------------------------------
    // 3. ICache Data SRAM Arrays (Ways=2, Banks_Way=2, Depth=512, Width=71)
    // -------------------------------------------------------------------------
    genvar w, b;
    generate
        for (w = 0; w < pt.ICACHE_NUM_WAYS; w = w + 1) begin : gen_icache_ways
            for (b = 0; b < pt.ICACHE_BANKS_WAY; b = b + 1) begin : gen_icache_banks
                wire [70:0] ic_data_dout;

                ram_512x71 ic_data_bank_inst (
                    .CLK      (mem_export.clk),
                    .ME       (icache_export.ic_bank_way_clken_final_up[w][b]),
                    .WE       (icache_export.ic_b_sb_wren[b][w]),
                    .ADR      (icache_export.ic_rw_addr_bank_q[b]),
                    .D        (icache_export.ic_sb_wr_data[b]),
                    .Q        (ic_data_dout),
                    .ROP      (),
                    .TEST1    (1'b0),
                    .RME      (1'b0),
                    .RM       (4'b0000),
                    .LS       (1'b0),
                    .DS       (1'b0),
                    .SD       (1'b0),
                    .TEST_RNM (1'b0),
                    .BC1      (1'b0),
                    .BC2      (1'b0)
                );

                assign icache_export.wb_dout_pre_up[w][b] = ic_data_dout;
            end
        end
    endgenerate

    // Packed data tie-off when waypack == 1
    assign icache_export.wb_packeddout_pre = '0;

    // -------------------------------------------------------------------------
    // 4. ICache Tag Arrays (Ways=2, Depth=64, Width=26)
    // -------------------------------------------------------------------------
    genvar tw;
    generate
        for (tw = 0; tw < pt.ICACHE_NUM_WAYS; tw = tw + 1) begin : gen_icache_tag_ways
            wire [25:0] ic_tag_dout;

            ram_64x26 ic_tag_bank_inst (
                .CLK      (mem_export.clk),
                .ME       (icache_export.ic_tag_clken_final[tw]),
                .WE       (icache_export.ic_tag_wren_q[tw]),
                .ADR      (icache_export.ic_rw_addr_q),
                .D        (icache_export.ic_tag_wr_data),
                .Q        (ic_tag_dout),
                .ROP      (),
                .TEST1    (1'b0),
                .RME      (1'b0),
                .RM       (4'b0000),
                .LS       (1'b0),
                .DS       (1'b0),
                .SD       (1'b0),
                .TEST_RNM (1'b0),
                .BC1      (1'b0),
                .BC2      (1'b0)
            );

            assign icache_export.ic_tag_data_raw_pre[tw] = ic_tag_dout;
        end
    endgenerate

    assign icache_export.ic_tag_data_raw_packed_pre = '0;

endmodule

