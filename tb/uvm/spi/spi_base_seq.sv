// =============================================================================
// Standalone SPI Base Sequence: spi_base_seq.sv
// Provides reusable tasks for reading/writing registers, configuring SPI,
// managing slave-select lines, and executing polled byte transfers.
// =============================================================================

`ifndef SPI_BASE_SEQ_SV
`define SPI_BASE_SEQ_SV

class spi_base_seq extends uvm_sequence #(axi_lite_item);

    `uvm_object_utils(spi_base_seq)

    function new(string name = "spi_base_seq");
        super.new(name);
    endfunction

    // AXI-Lite Write Task
    virtual task axi_write(
        input bit [6:0]  addr,
        input bit [31:0] data,
        input bit [3:0]  wstrb = 4'hF
    );
        axi_lite_item req = axi_lite_item::type_id::create("req");
        start_item(req);
        req.trans_type = AXI_LITE_WRITE;
        req.addr       = {25'h0, addr};
        req.data       = data;
        req.wstrb      = wstrb;
        finish_item(req);
    endtask

    // AXI-Lite Read Task
    virtual task axi_read(
        input  bit [6:0]  addr,
        output bit [31:0] rdata,
        output bit [1:0]  resp
    );
        axi_lite_item req = axi_lite_item::type_id::create("req");
        start_item(req);
        req.trans_type = AXI_LITE_READ;
        req.addr       = {25'h0, addr};
        finish_item(req);
        rdata = req.data;
        resp  = req.resp;
    endtask

    // Wait Cycles
    virtual task wait_cycles(int unsigned n);
        repeat (n) #10ns;
    endtask

    // Initialize SPI Controller
    virtual task spi_init(input bit [3:0] rclk_ratio = 4, input bit lsb_first = 0);
        bit [31:0] cr_val;
        `uvm_info(get_type_name(), $sformatf("Initializing SPI Controller (RCLK=%0d, LSB_FIRST=%b)...", rclk_ratio, lsb_first), UVM_MEDIUM)
        
        // 1. Program clock divider ratio
        axi_write(7'h30, {28'h0, rclk_ratio});

        // 2. Clear FIFOs and configure control register: SPE=1, Master=1, FIFO resets=0
        cr_val = 32'h0000_0186; // bits: [8:7]=3, Master(bit 2)=1, SPE(bit 1)=1
        if (lsb_first) cr_val[9] = 1'b1;
        axi_write(7'h60, cr_val);

        // 3. Select Slave 0 (active LOW)
        axi_write(7'h70, 32'hFFFF_FFFE);
    endtask

    // Slave Select Tasks
    virtual task spi_select_slave(bit [31:0] ssr = 32'hFFFF_FFFE);
        axi_write(7'h70, ssr);
    endtask

    virtual task spi_deselect_slave();
        axi_write(7'h70, 32'hFFFF_FFFF);
    endtask

    // Polled Byte Transfer
    virtual task spi_transfer_byte(
        input  bit [7:0] tx_byte,
        output bit [7:0] rx_byte
    );
        bit [31:0] sr_val;
        bit [31:0] drr_val;
        bit [1:0]  resp;
        int timeout_cnt = 0;

        // Write byte to TX FIFO (DTR)
        axi_write(7'h68, {24'h0, tx_byte});

        // Poll Status Register until RX_EMPTY (bit 0) clears
        do begin
            wait_cycles(10);
            axi_read(7'h64, sr_val, resp);
            timeout_cnt++;
            if (timeout_cnt > 200) begin
                `uvm_error(get_type_name(), "SPI Transfer Timeout waiting for SR.RX_EMPTY to clear!")
                break;
            end
        end while (sr_val[0] == 1'b1); // while RX is empty

        // Read received byte from RX FIFO (DRR)
        axi_read(7'h6C, drr_val, resp);
        rx_byte = drr_val[7:0];
    endtask

endclass : spi_base_seq

`endif // SPI_BASE_SEQ_SV

