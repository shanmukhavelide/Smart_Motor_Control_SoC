// =============================================================================
// Smart ControlSoC - SoC-Level UVM Verification Filelist
// Dedicated filelist for VCS compilation of tb_soc_uvm_top
// Excludes all AES, I2C, and DMA components
// Integrates 6 peripherals: UART, Timer, GPIO, SPI, Seven-Segment (SEG7), PWM
// =============================================================================

// Include Directories
+incdir+rtl/interconnect
+incdir+rtl/uart_directory/include
+incdir+rtl/spi_directory/include
+incdir+rtl/gpio_directory/include
+incdir+tb/uart.vip_uvm_tb
+incdir+tb/gpio.vip_uvm_tb
+incdir+tb/spi.vip_uvm_tb
+incdir+tb/pwm.vip_uvm_tb
+incdir+tb/seg7.vip_uvm_tb
+incdir+tb/uvm/soc
+incdir+tb/soc_uvm/interfaces

// OpenTitan Primitives & Common Cells
rtl/gpio_directory/include/reg_bus.sv
rtl/gpio_directory/include/common_cells/prim_subreg.sv
rtl/gpio_directory/include/common_cells/prim_subreg_ext.sv

// RISC-V VeeR EL2 Core Wrapper (Behavioral BFM)
rtl/Cores-VeeR-EL2/el2_veer_wrapper.v

// Interconnect Subsystem (2x6 Crossbar)
rtl/interconnect/arbiter.v
rtl/interconnect/priority_encoder.v
rtl/interconnect/axi_interconnect.v
rtl/interconnect/axi_interconnect_wrap_2x6.v

// UART Peripheral (Port M00: 0x4000_0000)
rtl/uart_directory/rtl/axi_internal_fifo.v
rtl/uart_directory/rtl/uart_parity_bit_compute.v
rtl/uart_directory/rtl/uart_receiver.v
rtl/uart_directory/rtl/uart_transmitter.v
rtl/uart_directory/rtl/uart_controller.v
rtl/uart_directory/rtl/axi_uart_top.v

// Hardware Timer Peripheral (Port M01: 0x4000_4000)
rtl/timer_directory/rtl/timer_core.sv
rtl/timer_directory/rtl/axi_timer_top.sv

// SPI Controller Peripheral (Port M03: 0x4000_6000)
rtl/spi_directory/rtl/ratio_clk.v
rtl/spi_directory/rtl/spi_clk_gen.v
rtl/spi_directory/rtl/spi_ctrl.v
rtl/spi_directory/rtl/spi_exch_byte.v
rtl/spi_directory/rtl/spi_fifo.v
rtl/spi_directory/rtl/spi_valid_logic.v
rtl/spi_directory/rtl/axi_spi_ctrl.v
rtl/spi_directory/rtl/axi_spi_top.v

// Seven-Segment Display Controller Peripheral (Port M04: 0x4000_8000)
rtl/seg7_directory/rtl/axi_seg7_slave.v
rtl/seg7_directory/rtl/seg7_core.sv
rtl/seg7_directory/rtl/axi_seg7_top.sv

// PWM Generator Peripheral (Port M05: 0x4000_A000)
rtl/pwm_directory/rtl/myip_v1_0_S00_AXI.v
rtl/pwm_directory/rtl/myip_v1_0.v

// GPIO Peripheral (Port M02: 0x4000_2000)
rtl/gpio_directory/rtl/gpio_reg_pkg.sv
rtl/gpio_directory/rtl/gpio_reg_top.sv
rtl/gpio_directory/rtl/gpio_input_stage.sv
rtl/gpio_directory/rtl/gpio.sv
rtl/gpio_directory/rtl/axi_gpio_top.sv

// Top-Level SoC RTL (Module: smart_controlsoc_top)
rtl/smart_controlsoc_top.v

// CPU BFM Interface
tb/soc_uvm/interfaces/cpu_bfm_if.sv

// Reused Peripheral VIP Interfaces & Packages (5 External Interfaces)
tb/uart.vip_uvm_tb/uart_vip_if.sv
tb/uart.vip_uvm_tb/uart_vip_pkg.sv
tb/gpio.vip_uvm_tb/gpio_vip_if.sv
tb/gpio.vip_uvm_tb/gpio_vip_pkg.sv
tb/spi.vip_uvm_tb/spi_vip_if.sv
tb/spi.vip_uvm_tb/spi_vip_pkg.sv
tb/pwm.vip_uvm_tb/pwm_vip_if.sv
tb/pwm.vip_uvm_tb/pwm_vip_pkg.sv
tb/seg7.vip_uvm_tb/seg7_vip_if.sv
tb/seg7.vip_uvm_tb/seg7_vip_pkg.sv

// SoC-Level UVM Verification Package
tb/uvm/soc/soc_uvm_pkg.sv

// SoC-Level UVM Top Testbench
tb/uvm/soc/tb_soc_uvm_top.sv
