// =============================================================================
// Standalone SPI Functional Coverage Subscriber: spi_coverage.sv
// Samples AXI register transactions and physical SPI bus observations
// =============================================================================

`ifndef SPI_COVERAGE_SV
`define SPI_COVERAGE_SV

class spi_coverage extends uvm_subscriber #(spi_item);

    // Analysis imp for AXI register transactions
    uvm_analysis_imp #(axi_lite_item, spi_coverage) axi_export;

    // Internal sampled values
    bit [6:0]  cov_reg_addr;
    bit        cov_trans_type;
    bit [31:0] cov_wdata;
    bit [7:0]  cov_mosi_byte;
    bit [7:0]  cov_miso_byte;
    bit [3:0]  cov_rclk_ratio;
    bit        cov_cs_n;

    // Covergroup 1: AXI Register Interface Coverage
    covergroup cg_spi_reg;
        option.per_instance = 1;
        option.name = "cg_spi_reg";

        cp_reg_addr: coverpoint cov_reg_addr {
            bins reg_gier = {7'h1c};
            bins reg_isr  = {7'h20};
            bins reg_ier  = {7'h28};
            bins reg_rclk = {7'h30};
            bins reg_srr  = {7'h40};
            bins reg_cr   = {7'h60};
            bins reg_sr   = {7'h64};
            bins reg_dtr  = {7'h68};
            bins reg_drr  = {7'h6c};
            bins reg_ssr  = {7'h70};
            bins reg_tfor = {7'h74};
            bins reg_rfor = {7'h78};
        }

        cp_trans_type: coverpoint cov_trans_type {
            bins write = {1'b1};
            bins read  = {1'b0};
        }

        cp_rclk_ratio: coverpoint cov_rclk_ratio {
            bins ratio_1 = {4'd1};
            bins ratio_2 = {4'd2};
            bins ratio_3 = {4'd3};
            bins ratio_4 = {4'd4};
        }

        cross_reg_rw: cross cp_reg_addr, cp_trans_type;
    endgroup

    // Covergroup 2: SPI Physical Bus & Data Pattern Coverage
    covergroup cg_spi_bus;
        option.per_instance = 1;
        option.name = "cg_spi_bus";

        cp_mosi: coverpoint cov_mosi_byte {
            bins all_zeros   = {8'h00};
            bins all_ones    = {8'hFF};
            bins alt_55      = {8'h55};
            bins alt_aa      = {8'hAA};
            bins walking_1s  = {8'h01, 8'h02, 8'h04, 8'h08, 8'h10, 8'h20, 8'h40, 8'h80};
            bins other_bytes = default;
        }

        cp_miso: coverpoint cov_miso_byte {
            bins all_zeros   = {8'h00};
            bins all_ones    = {8'hFF};
            bins alt_55      = {8'h55};
            bins alt_aa      = {8'hAA};
            bins other_bytes = default;
        }

        cp_cs_n: coverpoint cov_cs_n {
            bins asserted   = {1'b0};
            bins deasserted = {1'b1};
        }

        cross_data: cross cp_mosi, cp_miso;
    endgroup

    `uvm_component_utils(spi_coverage)

    function new(string name = "spi_coverage", uvm_component parent = null);
        super.new(name, parent);
        axi_export  = new("axi_export", this);
        cg_spi_reg  = new();
        cg_spi_bus  = new();
    endfunction

    virtual function void write_axi(axi_lite_item tr);
        cov_reg_addr   = tr.addr[6:0];
        cov_trans_type = (tr.trans_type == AXI_LITE_WRITE) ? 1'b1 : 1'b0;
        cov_wdata      = tr.data;
        if (cov_reg_addr == 7'h30 && cov_trans_type == 1'b1) begin
            cov_rclk_ratio = tr.data[3:0];
        end
        cg_spi_reg.sample();
    endfunction

    virtual function void write(spi_item t);
        cov_mosi_byte = t.mosi_data;
        cov_miso_byte = t.miso_data;
        cov_cs_n      = !t.cs_n_asserted;
        cg_spi_bus.sample();
    endfunction

endclass : spi_coverage

`endif // SPI_COVERAGE_SV

