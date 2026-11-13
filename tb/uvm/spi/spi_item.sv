// =============================================================================
// Standalone SPI Sequence Item / Transaction: spi_item.sv
// Represents an 8-bit SPI physical transfer observed on the bus
// =============================================================================

`ifndef SPI_ITEM_SV
`define SPI_ITEM_SV

class spi_item extends uvm_sequence_item;

    bit [7:0]    mosi_data;
    bit [7:0]    miso_data;
    bit          cpol;
    bit          cpha;
    bit          lsb_first;
    int unsigned bit_count;
    time         start_time;
    time         end_time;
    bit          cs_n_asserted;

    `uvm_object_utils_begin(spi_item)
        `uvm_field_int(mosi_data,     UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(miso_data,     UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(cpol,          UVM_ALL_ON | UVM_BIN)
        `uvm_field_int(cpha,          UVM_ALL_ON | UVM_BIN)
        `uvm_field_int(lsb_first,     UVM_ALL_ON | UVM_BIN)
        `uvm_field_int(bit_count,     UVM_ALL_ON | UVM_DEC)
        `uvm_field_time(start_time,   UVM_ALL_ON)
        `uvm_field_time(end_time,     UVM_ALL_ON)
        `uvm_field_int(cs_n_asserted, UVM_ALL_ON | UVM_BIN)
    `uvm_object_utils_end

    function new(string name = "spi_item");
        super.new(name);
        mosi_data     = 8'h00;
        miso_data     = 8'h00;
        cpol          = 1'b0;
        cpha          = 1'b0;
        lsb_first     = 1'b0;
        bit_count     = 0;
        start_time    = 0;
        end_time      = 0;
        cs_n_asserted = 1'b1;
    endfunction

    virtual function string convert2string();
        return $sformatf("[SPI ITEM] MOSI=0x%02h, MISO=0x%02h (Bits=%0d, CPOL=%b, CPHA=%b, LSB=%b) at [%0t - %0t ps]",
                         mosi_data, miso_data, bit_count, cpol, cpha, lsb_first, start_time, end_time);
    endfunction

endclass : spi_item

`endif // SPI_ITEM_SV

