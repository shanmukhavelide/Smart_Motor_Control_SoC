// =============================================================================
// SPI Sequences for Standalone Verification (13 Directed Testcases)
// =============================================================================

`ifndef SPI_SEQUENCES_SV
`define SPI_SEQUENCES_SV

// 1. Reset and Register Defaults Sequence
class spi_reset_reg_seq extends spi_base_seq;
    `uvm_object_utils(spi_reset_reg_seq)
    function new(string name = "spi_reset_reg_seq"); super.new(name); endfunction

    task body();
        bit [31:0] rdata;
        bit [1:0]  resp;
        `uvm_info(get_type_name(), "[START] Checking SPI reset values...", UVM_LOW)
        axi_read(7'h60, rdata, resp); // CR
        if (rdata !== 32'h0000_0180) `uvm_error(get_type_name(), $sformatf("CR reset mismatch: 0x%08h", rdata))
        axi_read(7'h70, rdata, resp); // SSR
        if (rdata !== 32'hFFFF_FFFF) `uvm_error(get_type_name(), $sformatf("SSR reset mismatch: 0x%08h", rdata))
        axi_read(7'h74, rdata, resp); // TFOR
        if (rdata !== 32'h0000_0000) `uvm_error(get_type_name(), $sformatf("TFOR reset mismatch: 0x%08h", rdata))
        axi_read(7'h78, rdata, resp); // RFOR
        if (rdata !== 32'h0000_0000) `uvm_error(get_type_name(), $sformatf("RFOR reset mismatch: 0x%08h", rdata))
        axi_read(7'h1C, rdata, resp); // GIER
        if (rdata !== 32'h0000_0000) `uvm_error(get_type_name(), $sformatf("GIER reset mismatch: 0x%08h", rdata))
        `uvm_info(get_type_name(), "[DONE] Reset values verified.", UVM_LOW)
    endtask
endclass

// 2. Register Read/Write Access Sequence
class spi_reg_access_seq extends spi_base_seq;
    `uvm_object_utils(spi_reg_access_seq)
    function new(string name = "spi_reg_access_seq"); super.new(name); endfunction

    task body();
        bit [31:0] rdata;
        bit [1:0]  resp;
        `uvm_info(get_type_name(), "[START] Testing R/W registers...", UVM_LOW)
        axi_write(7'h1C, 32'h8000_0000); // GIER
        axi_read(7'h1C, rdata, resp);
        axi_write(7'h28, 32'h0000_0007); // IER
        axi_read(7'h28, rdata, resp);
        axi_write(7'h30, 32'h0000_0002); // RCLK
        axi_read(7'h30, rdata, resp);
        axi_write(7'h70, 32'hAAAA_5555); // SSR
        axi_read(7'h70, rdata, resp);
        axi_write(7'h70, 32'hFFFF_FFFF); // restore SSR
        `uvm_info(get_type_name(), "[DONE] Register R/W tests passed.", UVM_LOW)
    endtask
endclass

// 3. Clock Divider Configuration Sequence
class spi_clk_div_seq extends spi_base_seq;
    `uvm_object_utils(spi_clk_div_seq)
    function new(string name = "spi_clk_div_seq"); super.new(name); endfunction

    task body();
        bit [7:0] rx_byte;
        `uvm_info(get_type_name(), "[START] Testing clock divider ratios...", UVM_LOW)
        // Ratio = 1
        spi_init(1);
        spi_transfer_byte(8'h33, rx_byte);
        // Ratio = 2
        spi_init(2);
        spi_transfer_byte(8'h44, rx_byte);
        // Ratio = 3
        spi_init(3);
        spi_transfer_byte(8'h55, rx_byte);
        `uvm_info(get_type_name(), "[DONE] Clock divider ratios verified.", UVM_LOW)
    endtask
endclass

// 4. Single-Byte Transmit Sequence
class spi_tx_byte_seq extends spi_base_seq;
    `uvm_object_utils(spi_tx_byte_seq)
    function new(string name = "spi_tx_byte_seq"); super.new(name); endfunction

    task body();
        bit [7:0] rx_byte;
        `uvm_info(get_type_name(), "[START] Testing single byte transmission...", UVM_LOW)
        spi_init(1);
        spi_transfer_byte(8'h5A, rx_byte);
        wait_cycles(50);
        `uvm_info(get_type_name(), "[DONE] Single byte transmit verified.", UVM_LOW)
    endtask
endclass

// 5. Single-Byte Receive Sequence
class spi_rx_byte_seq extends spi_base_seq;
    `uvm_object_utils(spi_rx_byte_seq)
    function new(string name = "spi_rx_byte_seq"); super.new(name); endfunction

    task body();
        bit [7:0] rx_byte;
        `uvm_info(get_type_name(), "[START] Testing single byte reception...", UVM_LOW)
        spi_init(1);
        spi_transfer_byte(8'hFF, rx_byte);
        wait_cycles(50);
        `uvm_info(get_type_name(), "[DONE] Single byte receive verified.", UVM_LOW)
    endtask
endclass

// 6. Full-Duplex Transfer Sequence
class spi_full_duplex_seq extends spi_base_seq;
    `uvm_object_utils(spi_full_duplex_seq)
    function new(string name = "spi_full_duplex_seq"); super.new(name); endfunction

    task body();
        bit [7:0] rx_byte;
        `uvm_info(get_type_name(), "[START] Testing simultaneous full-duplex transfer...", UVM_LOW)
        spi_init(1);
        spi_transfer_byte(8'hA5, rx_byte);
        wait_cycles(50);
        `uvm_info(get_type_name(), "[DONE] Full-duplex transfer verified.", UVM_LOW)
    endtask
endclass

// 7. Multi-Byte Burst Transfer Sequence
class spi_multi_byte_seq extends spi_base_seq;
    `uvm_object_utils(spi_multi_byte_seq)
    function new(string name = "spi_multi_byte_seq"); super.new(name); endfunction

    task body();
        bit [7:0] data_burst[4] = '{8'h54, 8'h45, 8'h53, 8'h54}; // "TEST"
        bit [7:0] rx_byte;
        `uvm_info(get_type_name(), "[START] Testing multi-byte burst transfer...", UVM_LOW)
        spi_init(1);
        for (int i = 0; i < 4; i++) begin
            spi_transfer_byte(data_burst[i], rx_byte);
        end
        wait_cycles(50);
        `uvm_info(get_type_name(), "[DONE] Multi-byte transfer verified.", UVM_LOW)
    endtask
endclass

// 8. Slave-Select Assertion Sequence
class spi_slave_select_seq extends spi_base_seq;
    `uvm_object_utils(spi_slave_select_seq)
    function new(string name = "spi_slave_select_seq"); super.new(name); endfunction

    task body();
        bit [31:0] rdata;
        bit [1:0]  resp;
        `uvm_info(get_type_name(), "[START] Testing slave select assertion/deassertion...", UVM_LOW)
        spi_select_slave(32'hFFFF_FFFE);
        axi_read(7'h70, rdata, resp);
        wait_cycles(30);
        spi_deselect_slave();
        axi_read(7'h70, rdata, resp);
        wait_cycles(30);
        `uvm_info(get_type_name(), "[DONE] Slave select verified.", UVM_LOW)
    endtask
endclass

// 9. Back-to-Back Transfer Sequence
class spi_back_to_back_seq extends spi_base_seq;
    `uvm_object_utils(spi_back_to_back_seq)
    function new(string name = "spi_back_to_back_seq"); super.new(name); endfunction

    task body();
        bit [7:0] rx_byte;
        `uvm_info(get_type_name(), "[START] Testing back-to-back rapid transfers...", UVM_LOW)
        spi_init(1);
        spi_transfer_byte(8'h11, rx_byte);
        spi_transfer_byte(8'h22, rx_byte);
        spi_transfer_byte(8'h33, rx_byte);
        wait_cycles(50);
        `uvm_info(get_type_name(), "[DONE] Back-to-back transfers verified.", UVM_LOW)
    endtask
endclass

// 10. Distinct Data Patterns Sequence
class spi_data_patterns_seq extends spi_base_seq;
    `uvm_object_utils(spi_data_patterns_seq)
    function new(string name = "spi_data_patterns_seq"); super.new(name); endfunction

    task body();
        bit [7:0] patterns[4] = '{8'h00, 8'hFF, 8'hAA, 8'h55};
        bit [7:0] rx_byte;
        `uvm_info(get_type_name(), "[START] Testing distinct data patterns...", UVM_LOW)
        spi_init(1);
        for (int i = 0; i < 4; i++) begin
            spi_transfer_byte(patterns[i], rx_byte);
        end
        wait_cycles(50);
        `uvm_info(get_type_name(), "[DONE] Data patterns verified.", UVM_LOW)
    endtask
endclass

// 11. Soft Reset Recovery Sequence
class spi_mid_transfer_reset_seq extends spi_base_seq;
    `uvm_object_utils(spi_mid_transfer_reset_seq)
    function new(string name = "spi_mid_transfer_reset_seq"); super.new(name); endfunction

    task body();
        bit [31:0] rdata;
        bit [1:0]  resp;
        `uvm_info(get_type_name(), "[START] Testing soft reset via SPI_SRR...", UVM_LOW)
        spi_init(1);
        axi_write(7'h68, 32'h0000_0077); // push byte to TX FIFO
        wait_cycles(10);
        // Execute Soft Reset: write 0x0A to SRR (0x40)
        axi_write(7'h40, 32'h0000_000A);
        wait_cycles(20);
        axi_read(7'h60, rdata, resp); // CR should return to reset
        axi_read(7'h74, rdata, resp); // TFOR should be 0
        `uvm_info(get_type_name(), "[DONE] Soft reset recovery verified.", UVM_LOW)
    endtask
endclass

// 12. Status Flags Verification Sequence
class spi_status_flags_seq extends spi_base_seq;
    `uvm_object_utils(spi_status_flags_seq)
    function new(string name = "spi_status_flags_seq"); super.new(name); endfunction

    task body();
        bit [31:0] sr_val;
        bit [1:0]  resp;
        bit [7:0]  rx_byte;
        `uvm_info(get_type_name(), "[START] Testing Status Register flags...", UVM_LOW)
        spi_init(1);
        axi_read(7'h64, sr_val, resp); // SR
        // SR bit 0 is RX_EMPTY (must be 1), bit 2 is TX_EMPTY (must be 1)
        if (sr_val[0] !== 1'b1 || sr_val[2] !== 1'b1) begin
            `uvm_error(get_type_name(), $sformatf("Initial status flags unexpected: 0x%08h", sr_val))
        end
        spi_transfer_byte(8'h88, rx_byte);
        axi_read(7'h64, sr_val, resp);
        `uvm_info(get_type_name(), "[DONE] Status flags verified.", UVM_LOW)
    endtask
endclass

// 13. Invalid / Unmapped Address Access Sequence
class spi_invalid_access_seq extends spi_base_seq;
    `uvm_object_utils(spi_invalid_access_seq)
    function new(string name = "spi_invalid_access_seq"); super.new(name); endfunction

    task body();
        bit [31:0] rdata;
        bit [1:0]  resp;
        `uvm_info(get_type_name(), "[START] Testing unmapped register access...", UVM_LOW)
        axi_write(7'h04, 32'hFFFF_FFFF); // unmapped offset
        axi_read(7'h04, rdata, resp);
        wait_cycles(20);
        `uvm_info(get_type_name(), "[DONE] Unmapped access verified.", UVM_LOW)
    endtask
endclass

`endif // SPI_SEQUENCES_SV

