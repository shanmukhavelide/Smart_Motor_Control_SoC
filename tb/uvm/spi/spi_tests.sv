// =============================================================================
// Standalone SPI Test Library: spi_tests.sv
// Contains spi_base_test and all 13 required directed test classes
// =============================================================================

`ifndef SPI_TESTS_SV
`define SPI_TESTS_SV

// -----------------------------------------------------------------------------
// Base Test Class
// -----------------------------------------------------------------------------
class spi_base_test extends uvm_test;

    spi_env env;

    `uvm_component_utils(spi_base_test)

    function new(string name = "spi_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = spi_env::type_id::create("env", this);
    endfunction

    function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        uvm_top.print_topology();
    endfunction

endclass : spi_base_test

// Macro to generate boilerplate for directed tests running a specific sequence
`define SPI_TEST_DEF(TEST_NAME, SEQ_NAME) \
class TEST_NAME extends spi_base_test; \
    `uvm_component_utils(TEST_NAME) \
    function new(string name = `"TEST_NAME`", uvm_component parent = null); \
        super.new(name, parent); \
    endfunction \
    task run_phase(uvm_phase phase); \
        SEQ_NAME seq; \
        phase.raise_objection(this, `"Starting ``TEST_NAME`"); \
        seq = SEQ_NAME::type_id::create(`"seq`"); \
        seq.start(env.axi_sqr); \
        #200ns; \
        phase.drop_objection(this, `"Finished ``TEST_NAME`"); \
    endtask \
endclass

// 1. Reset and Register Defaults Test
`SPI_TEST_DEF(spi_reset_reg_test, spi_reset_reg_seq)

// 2. Register Read/Write Access Test
`SPI_TEST_DEF(spi_reg_access_test, spi_reg_access_seq)

// 3. Clock Divider Configuration Test
`SPI_TEST_DEF(spi_clk_div_test, spi_clk_div_seq)

// 4. Single-Byte Transmit Test
`SPI_TEST_DEF(spi_tx_byte_test, spi_tx_byte_seq)

// 5. Single-Byte Receive Test
`SPI_TEST_DEF(spi_rx_byte_test, spi_rx_byte_seq)

// 6. Full-Duplex Transfer Test
`SPI_TEST_DEF(spi_full_duplex_test, spi_full_duplex_seq)

// 7. Multi-Byte Burst Transfer Test
`SPI_TEST_DEF(spi_multi_byte_test, spi_multi_byte_seq)

// 8. Slave-Select Assertion Test
`SPI_TEST_DEF(spi_slave_select_test, spi_slave_select_seq)

// 9. Back-to-Back Transfer Test
`SPI_TEST_DEF(spi_back_to_back_test, spi_back_to_back_seq)

// 10. Distinct Data Patterns Test
`SPI_TEST_DEF(spi_data_patterns_test, spi_data_patterns_seq)

// 11. Soft Reset Recovery Test
`SPI_TEST_DEF(spi_mid_transfer_reset_test, spi_mid_transfer_reset_seq)

// 12. Status Flags Verification Test
`SPI_TEST_DEF(spi_status_flags_test, spi_status_flags_seq)

// 13. Invalid / Unmapped Address Access Test
`SPI_TEST_DEF(spi_invalid_access_test, spi_invalid_access_seq)

`undef SPI_TEST_DEF

`endif // SPI_TESTS_SV

