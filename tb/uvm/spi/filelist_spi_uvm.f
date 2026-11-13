// =============================================================================
// Standalone SPI UVM Verification Filelist for Synopsys VCS / QuestaSim
// Target Testbench Top: tb_spi_top
// =============================================================================

// Include Directories
+incdir+rtl/spi_directory/include
+incdir+tb/uvm/common/axi_lite
+incdir+tb/uvm/spi

// Design Under Test (DUT) Sources
rtl/spi_directory/rtl/ratio_clk.v
rtl/spi_directory/rtl/spi_clk_gen.v
rtl/spi_directory/rtl/spi_ctrl.v
rtl/spi_directory/rtl/spi_exch_byte.v
rtl/spi_directory/rtl/spi_fifo.v
rtl/spi_directory/rtl/spi_valid_logic.v
rtl/spi_directory/rtl/axi_spi_ctrl.v
rtl/spi_directory/rtl/axi_spi_top.v

// Common AXI4-Lite VIP (Master Interface & Package)
tb/uvm/common/axi_lite/axi_lite_if.sv
tb/uvm/common/axi_lite/axi_lite_pkg.sv

// Passive SPI Pin Interface
tb/uvm/spi/spi_if.sv

// SPI UVM Verification Package (Items, Slave Model, Monitor, Scoreboard, Coverage, Sequences, Env, Tests)
tb/uvm/spi/spi_pkg.sv

// Standalone UVM Top-Level Testbench
tb/uvm/spi/tb_spi_top.sv

