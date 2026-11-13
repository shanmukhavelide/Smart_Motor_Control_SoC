// =============================================================================
// Standalone PWM UVM Verification Filelist for Synopsys VCS / QuestaSim
// Target Testbench Top: tb_pwm_top
// =============================================================================

// Include Directories
+incdir+tb/uvm/common/axi_lite
+incdir+tb/uvm/pwm

// Design Under Test (DUT) Sources
rtl/pwm_directory/rtl/myip_v1_0_S00_AXI.v
rtl/pwm_directory/rtl/myip_v1_0.v

// Common AXI4-Lite VIP (Master Interface & Package)
tb/uvm/common/axi_lite/axi_lite_if.sv
tb/uvm/common/axi_lite/axi_lite_pkg.sv

// Passive PWM Pin Interface
tb/uvm/pwm/pwm_if.sv

// PWM UVM Verification Package (Items, Monitor, Scoreboard, Coverage, Sequences, Env, Tests)
tb/uvm/pwm/pwm_pkg.sv

// Standalone UVM Top-Level Testbench
tb/uvm/pwm/tb_pwm_top.sv

