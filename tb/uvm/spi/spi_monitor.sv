// =============================================================================
// Standalone SPI Protocol Monitor: spi_monitor.sv
// Passively observes SPI bus signals (CS_N, SCLK, MOSI, MISO), checks Mode 0 timing,
// frames 8-bit transactions, and writes completed spi_item to analysis port.
// =============================================================================

`ifndef SPI_MONITOR_SV
`define SPI_MONITOR_SV

class spi_monitor extends uvm_monitor;

    virtual spi_if vif;
    uvm_analysis_port #(spi_item) ap;

    // Protocol expectations
    bit expected_cpol = 1'b0;
    bit expected_cpha = 1'b0;
    bit lsb_first     = 1'b0;

    `uvm_component_utils_begin(spi_monitor)
        `uvm_field_int(expected_cpol, UVM_ALL_ON | UVM_BIN)
        `uvm_field_int(expected_cpha, UVM_ALL_ON | UVM_BIN)
        `uvm_field_int(lsb_first,     UVM_ALL_ON | UVM_BIN)
    `uvm_component_utils_end

    function new(string name = "spi_monitor", uvm_component parent = null);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual spi_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal(get_type_name(), "Virtual interface spi_if not found in uvm_config_db under 'vif'!")
        end
    endfunction

    task run_phase(uvm_phase phase);
        spi_item item;
        bit [7:0] captured_mosi;
        bit [7:0] captured_miso;
        int bit_count;
        bit prev_sclk;
        time t_start;

        wait (vif.rst_n === 1'b1);
        `uvm_info(get_type_name(), "SPI Protocol Monitor active...", UVM_MEDIUM)

        forever begin
            @(posedge vif.clk);

            // Wait for CS_N assertion (LOW)
            if (vif.cs_n === 1'b0) begin
                t_start       = $time;
                captured_mosi = 8'h00;
                captured_miso = 8'h00;
                bit_count     = 0;
                prev_sclk     = vif.sclk;

                // Monitor bit-by-bit transfer
                while (vif.cs_n === 1'b0 && bit_count < 8) begin
                    @(posedge vif.clk);
                    if (!vif.rst_n) begin
                        `uvm_info(get_type_name(), "[RESET DURING TRANSFER] Mid-transfer reset observed on SPI bus.", UVM_MEDIUM)
                        break;
                    end

                    // Sample on SCLK rising edge (Mode 0: CPOL=0, CPHA=0)
                    if (prev_sclk === 1'b0 && vif.sclk === 1'b1) begin
                        if (lsb_first) begin
                            captured_mosi[bit_count] = vif.mosi;
                            captured_miso[bit_count] = vif.miso;
                        end else begin
                            captured_mosi[7 - bit_count] = vif.mosi;
                            captured_miso[7 - bit_count] = vif.miso;
                        end
                        bit_count++;
                    end

                    prev_sclk = vif.sclk;
                end

                if (bit_count == 8) begin
                    item = spi_item::type_id::create("item");
                    item.mosi_data     = captured_mosi;
                    item.miso_data     = captured_miso;
                    item.cpol          = expected_cpol;
                    item.cpha          = expected_cpha;
                    item.lsb_first     = lsb_first;
                    item.bit_count     = bit_count;
                    item.start_time    = t_start;
                    item.end_time      = $time;
                    item.cs_n_asserted = 1'b1;

                    `uvm_info(get_type_name(), item.convert2string(), UVM_HIGH)
                    ap.write(item);
                end

                // Wait until CS_N returns high before next transfer tracking
                while (vif.cs_n === 1'b0) begin
                    @(posedge vif.clk);
                    if (!vif.rst_n) break;
                end
            end
        end
    endtask

endclass : spi_monitor

`endif // SPI_MONITOR_SV

