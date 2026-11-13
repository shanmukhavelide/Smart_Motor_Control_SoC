// =============================================================================
// Standalone SPI Master Interface: spi_if.sv
// Connects to SPI physical pins: SCLK, CS_N, MOSI, MISO
// Provides synchronous sampling clocking blocks for monitor and slave model
// =============================================================================

`ifndef SPI_IF_SV
`define SPI_IF_SV

interface spi_if (
    input logic clk,
    input logic rst_n
);
    timeunit 1ns;
    timeprecision 1ps;

    // Physical SPI Bus Signals
    logic sclk;
    logic cs_n;
    logic mosi;
    logic miso;

    // Passive Monitor Clocking Block
    clocking cb_mon @(posedge clk);
        default input #1step;
        input sclk;
        input cs_n;
        input mosi;
        input miso;
    endclocking

    // Reactive Slave Clocking Block
    clocking cb_slave @(posedge clk);
        default input #1step output #100ps;
        input  sclk;
        input  cs_n;
        input  mosi;
        output miso;
    endclocking

endinterface : spi_if

`endif // SPI_IF_SV

