// =============================================================================
// Standalone SPI Slave Model: spi_slave_model.sv
// Emulates an SPI peripheral responder for Mode 0 (CPOL=0, CPHA=0) transfers.
// Provides configurable MISO response queue and captures received MOSI bytes.
// =============================================================================

`ifndef SPI_SLAVE_MODEL_SV
`define SPI_SLAVE_MODEL_SV

class spi_slave_model extends uvm_component;

    virtual spi_if vif;
    uvm_analysis_port #(spi_item) ap;

    // Response queue for data to drive onto MISO
    bit [7:0] miso_tx_queue[$];
    bit [7:0] default_miso_byte = 8'hA5;

    // Mode configuration
    bit cpol      = 1'b0;
    bit cpha      = 1'b0;
    bit lsb_first = 1'b0;

    `uvm_component_utils_begin(spi_slave_model)
        `uvm_field_int(default_miso_byte, UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(cpol,              UVM_ALL_ON | UVM_BIN)
        `uvm_field_int(cpha,              UVM_ALL_ON | UVM_BIN)
        `uvm_field_int(lsb_first,         UVM_ALL_ON | UVM_BIN)
    `uvm_component_utils_end

    function new(string name = "spi_slave_model", uvm_component parent = null);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual spi_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal(get_type_name(), "Virtual interface spi_if not found in uvm_config_db under 'vif'!")
        end
    endfunction

    function void add_response_byte(bit [7:0] b);
        miso_tx_queue.push_back(b);
    endfunction

    function void clear_response_queue();
        miso_tx_queue.delete();
    endfunction

    task run_phase(uvm_phase phase);
        bit [7:0] current_tx_byte;
        bit [7:0] current_rx_byte;
        int bit_idx;
        bit prev_sclk;

        vif.miso <= 1'b0;
        wait (vif.rst_n === 1'b1);
        `uvm_info(get_type_name(), "SPI Slave Model active (Mode 0: CPOL=0, CPHA=0)...", UVM_MEDIUM)

        forever begin
            // Wait for Chip Select assertion (active LOW)
            @(posedge vif.clk);
            if (vif.cs_n === 1'b0) begin
                // Select response byte from queue or default
                if (miso_tx_queue.size() > 0) begin
                    current_tx_byte = miso_tx_queue.pop_front();
                end else begin
                    current_tx_byte = default_miso_byte;
                end

                current_rx_byte = 8'h00;
                bit_idx = 0;

                // For Mode 0 (CPHA=0), drive MSB/LSB before the first rising SCLK edge
                vif.miso <= lsb_first ? current_tx_byte[0] : current_tx_byte[7];
                prev_sclk = vif.sclk;

                while (vif.cs_n === 1'b0 && bit_idx < 8) begin
                    @(posedge vif.clk);
                    if (!vif.rst_n) break;

                    // Detect SCLK Rising Edge: Sample MOSI
                    if (prev_sclk === 1'b0 && vif.sclk === 1'b1) begin
                        if (lsb_first) begin
                            current_rx_byte[bit_idx] = vif.mosi;
                        end else begin
                            current_rx_byte[7 - bit_idx] = vif.mosi;
                        end
                        bit_idx++;
                    end
                    // Detect SCLK Falling Edge: Shift next MISO bit
                    else if (prev_sclk === 1'b1 && vif.sclk === 1'b0) begin
                        if (bit_idx < 8) begin
                            vif.miso <= lsb_first ? current_tx_byte[bit_idx] : current_tx_byte[7 - bit_idx];
                        end
                    end

                    prev_sclk = vif.sclk;
                end

                // Wait until CS_N de-asserts or next transfer
                while (vif.cs_n === 1'b0) begin
                    @(posedge vif.clk);
                    if (!vif.rst_n) break;
                end
                vif.miso <= 1'b0;
            end
        end
    endtask

endclass : spi_slave_model

`endif // SPI_SLAVE_MODEL_SV

