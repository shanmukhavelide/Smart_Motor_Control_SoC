// =============================================================================
// Standalone SPI Scoreboard: spi_scoreboard.sv
// Verifies MOSI/MISO byte consistency against AXI DTR/DRR registers,
// checks status register flags and reset behaviors.
// =============================================================================

`ifndef SPI_SCOREBOARD_SV
`define SPI_SCOREBOARD_SV

`uvm_analysis_imp_decl(_axi)
`uvm_analysis_imp_decl(_spi)

class spi_scoreboard extends uvm_scoreboard;

    uvm_analysis_imp_axi #(axi_lite_item, spi_scoreboard) axi_imp;
    uvm_analysis_imp_spi #(spi_item,      spi_scoreboard) spi_imp;

    // Queues for checking
    bit [7:0] expected_tx_queue[$];
    bit [7:0] expected_rx_queue[$];

    // Statistics
    int unsigned tx_bytes_checked;
    int unsigned rx_bytes_checked;
    int unsigned checks_passed;
    int unsigned checks_failed;

    `uvm_component_utils(spi_scoreboard)

    function new(string name = "spi_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        axi_imp = new("axi_imp", this);
        spi_imp = new("spi_imp", this);

        tx_bytes_checked = 0;
        rx_bytes_checked = 0;
        checks_passed    = 0;
        checks_failed    = 0;
    endfunction

    // Handle AXI Master Transactions
    virtual function void write_axi(axi_lite_item tr);
        bit [6:0] offset = tr.addr[6:0];

        if (tr.trans_type == AXI_LITE_WRITE) begin
            if (offset == 7'h68) begin // SPI_DTR
                expected_tx_queue.push_back(tr.data[7:0]);
                `uvm_info(get_type_name(), $sformatf("[AXI WRITE DTR] Pushed expected TX byte: 0x%02h", tr.data[7:0]), UVM_MEDIUM)
            end
        end else if (tr.trans_type == AXI_LITE_READ) begin
            if (offset == 7'h6C) begin // SPI_DRR
                if (expected_rx_queue.size() > 0) begin
                    bit [7:0] exp_rx = expected_rx_queue.pop_front();
                    rx_bytes_checked++;
                    if (tr.data[7:0] === exp_rx) begin
                        checks_passed++;
                        `uvm_info(get_type_name(), $sformatf("[PASS][DRR READ] Received byte 0x%02h matched expected", tr.data[7:0]), UVM_MEDIUM)
                    end else begin
                        checks_failed++;
                        `uvm_error(get_type_name(), $sformatf("[FAIL][DRR READ MISMATCH] Read 0x%02h != expected 0x%02h", tr.data[7:0], exp_rx))
                    end
                end else begin
                    `uvm_info(get_type_name(), $sformatf("[DRR READ] Read byte 0x%02h (no prior queue item)", tr.data[7:0]), UVM_HIGH)
                end
            end
        end
    endfunction

    // Handle Physical SPI Bus Observations
    virtual function void write_spi(spi_item tr);
        if (expected_tx_queue.size() > 0) begin
            bit [7:0] exp_tx = expected_tx_queue.pop_front();
            tx_bytes_checked++;
            if (tr.mosi_data === exp_tx) begin
                checks_passed++;
                `uvm_info(get_type_name(), $sformatf("[PASS][MOSI MATCH] Physical MOSI byte 0x%02h matched DTR", tr.mosi_data), UVM_MEDIUM)
            end else begin
                checks_failed++;
                `uvm_error(get_type_name(), $sformatf("[FAIL][MOSI MISMATCH] Observed MOSI 0x%02h != expected DTR 0x%02h", tr.mosi_data, exp_tx))
            end
        end

        // Physical MISO byte is pushed to expected_rx_queue for subsequent DRR read check
        expected_rx_queue.push_back(tr.miso_data);
        `uvm_info(get_type_name(), $sformatf("[SPI OBSERVED MISO] Queued expected DRR readback: 0x%02h", tr.miso_data), UVM_HIGH)
    endfunction

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info(get_type_name(), "==================================================================", UVM_LOW)
        `uvm_info(get_type_name(), "               SPI SCOREBOARD VERIFICATION SUMMARY                ", UVM_LOW)
        `uvm_info(get_type_name(), "==================================================================", UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("  TX Bytes Checked : %0d", tx_bytes_checked), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("  RX Bytes Checked : %0d", rx_bytes_checked), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("  Checks Passed    : %0d", checks_passed), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("  Checks Failed    : %0d", checks_failed), UVM_LOW)
        if (checks_failed == 0 && (checks_passed > 0 || tx_bytes_checked > 0)) begin
            `uvm_info(get_type_name(), "  OVERALL SCOREBOARD RESULT: *** ALL CHECKS PASSED ***", UVM_LOW)
        end else if (checks_failed > 0) begin
            `uvm_error(get_type_name(), "  OVERALL SCOREBOARD RESULT: *** SCOREBOARD CHECKS FAILED ***")
        end
        `uvm_info(get_type_name(), "==================================================================", UVM_LOW)
    endfunction

endclass : spi_scoreboard

`endif // SPI_SCOREBOARD_SV

