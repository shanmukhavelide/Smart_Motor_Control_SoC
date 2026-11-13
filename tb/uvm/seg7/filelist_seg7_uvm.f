// =============================================================================
// Standalone SEG7 UVM Verification Filelist for Synopsys VCS / QuestaSim
// Target Testbench Top: tb_seg7_top
// =============================================================================

// Include Directories
+incdir+tb/uvm/common/axi_lite
+incdir+tb/seg7.vip_uvm_tb
+incdir+tb/uvm/seg7

// Design Under Test (DUT) Sources
rtl/seg7_directory/rtl/seg7_core.sv
rtl/seg7_directory/rtl/axi_seg7_slave.v
rtl/seg7_directory/rtl/axi_seg7_top.sv

// Common AXI4-Lite VIP (Master Interface & Package)
tb/uvm/common/axi_lite/axi_lite_if.sv
tb/uvm/common/axi_lite/axi_lite_pkg.sv

// Passive SEG7 Display VIP (Pin Interface & Package)
tb/seg7.vip_uvm_tb/seg7_vip_if.sv
tb/seg7.vip_uvm_tb/seg7_vip_pkg.sv

// SEG7 UVM Verification Package (Sequences, Coverage, Env, Tests)
tb/uvm/seg7/seg7_pkg.sv

// Standalone UVM Top-Level Testbench
tb/uvm/seg7/tb_seg7_top.sv

