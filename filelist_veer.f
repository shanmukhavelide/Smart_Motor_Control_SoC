// =============================================================================
// Smart ControlSoC Filelist for Synthesizable VeeR EL2 Core Simulation
// Target: Synopsys VCS / Verilator / QuestaSim
// Top Module: tb_smart_controlsoc_veer_top
// =============================================================================

// Preprocessor Flags
+define+RV_OPENSOURCE

// Include Directories
+incdir+rtl/veer_snapshot/snapshots/default
+incdir+rtl/Cores-VeeR-EL2/design/include
+incdir+rtl/interconnect
+incdir+rtl/uart_directory/include
+incdir+rtl/spi_directory/include
+incdir+rtl/gpio_directory/include
+incdir+rtl/veer_wrapper

// OpenTitan Primitives & Common Cells
rtl/gpio_directory/include/reg_bus.sv
rtl/gpio_directory/include/common_cells/prim_subreg.sv
rtl/gpio_directory/include/common_cells/prim_subreg_ext.sv

// Western Digital / CHIPS Alliance VeeR EL2 Core RTL Sources
rtl/Cores-VeeR-EL2/design/include/el2_def.sv
rtl/Cores-VeeR-EL2/design/lib/el2_assert.sv
rtl/Cores-VeeR-EL2/design/el2_mubi_pkg.sv
rtl/Cores-VeeR-EL2/design/el2_lockstep_pkg.sv
rtl/Cores-VeeR-EL2/design/el2_mem.sv
rtl/Cores-VeeR-EL2/design/el2_pic_ctrl.sv
rtl/Cores-VeeR-EL2/design/el2_veer.sv
rtl/Cores-VeeR-EL2/design/el2_dma_ctrl.sv
rtl/Cores-VeeR-EL2/design/el2_pmp.sv
rtl/Cores-VeeR-EL2/design/ifu/el2_ifu_aln_ctl.sv
rtl/Cores-VeeR-EL2/design/ifu/el2_ifu_compress_ctl.sv
rtl/Cores-VeeR-EL2/design/ifu/el2_ifu_ifc_ctl.sv
rtl/Cores-VeeR-EL2/design/ifu/el2_ifu_bp_ctl.sv
rtl/Cores-VeeR-EL2/design/ifu/el2_ifu_ic_mem.sv
rtl/Cores-VeeR-EL2/design/ifu/el2_ifu_mem_ctl.sv
rtl/Cores-VeeR-EL2/design/ifu/el2_ifu_iccm_mem.sv
rtl/Cores-VeeR-EL2/design/ifu/el2_ifu.sv
rtl/Cores-VeeR-EL2/design/dec/el2_dec_decode_ctl.sv
rtl/Cores-VeeR-EL2/design/dec/el2_dec_gpr_ctl.sv
rtl/Cores-VeeR-EL2/design/dec/el2_dec_ib_ctl.sv
rtl/Cores-VeeR-EL2/design/dec/el2_dec_pmp_ctl.sv
rtl/Cores-VeeR-EL2/design/dec/el2_dec_tlu_ctl.sv
rtl/Cores-VeeR-EL2/design/dec/el2_dec_trigger.sv
rtl/Cores-VeeR-EL2/design/dec/el2_dec.sv
rtl/Cores-VeeR-EL2/design/exu/el2_exu_alu_ctl.sv
rtl/Cores-VeeR-EL2/design/exu/el2_exu_mul_ctl.sv
rtl/Cores-VeeR-EL2/design/exu/el2_exu_div_ctl.sv
rtl/Cores-VeeR-EL2/design/exu/el2_exu.sv
rtl/Cores-VeeR-EL2/design/lsu/el2_lsu.sv
rtl/Cores-VeeR-EL2/design/lsu/el2_lsu_clkdomain.sv
rtl/Cores-VeeR-EL2/design/lsu/el2_lsu_addrcheck.sv
rtl/Cores-VeeR-EL2/design/lsu/el2_lsu_lsc_ctl.sv
rtl/Cores-VeeR-EL2/design/lsu/el2_lsu_stbuf.sv
rtl/Cores-VeeR-EL2/design/lsu/el2_lsu_bus_buffer.sv
rtl/Cores-VeeR-EL2/design/lsu/el2_lsu_bus_intf.sv
rtl/Cores-VeeR-EL2/design/lsu/el2_lsu_ecc.sv
rtl/Cores-VeeR-EL2/design/lsu/el2_lsu_dccm_mem.sv
rtl/Cores-VeeR-EL2/design/lsu/el2_lsu_dccm_ctl.sv
rtl/Cores-VeeR-EL2/design/lsu/el2_lsu_trigger.sv
rtl/Cores-VeeR-EL2/design/dbg/el2_dbg.sv
rtl/Cores-VeeR-EL2/design/dmi/dmi_mux.v
rtl/Cores-VeeR-EL2/design/dmi/dmi_wrapper.v
rtl/Cores-VeeR-EL2/design/dmi/dmi_jtag_to_core_sync.v
rtl/Cores-VeeR-EL2/design/dmi/rvjtag_tap.v
rtl/Cores-VeeR-EL2/design/lib/el2_lib.sv
rtl/Cores-VeeR-EL2/design/lib/el2_mem_if.sv
rtl/Cores-VeeR-EL2/design/lib/el2_prim_generic_buf.sv
rtl/Cores-VeeR-EL2/design/lib/el2_prim_buf.sv
rtl/Cores-VeeR-EL2/design/lib/beh_lib.sv
rtl/Cores-VeeR-EL2/design/lib/mem_lib.sv
rtl/Cores-VeeR-EL2/design/el2_veer_wrapper.sv

// AXI LSU Width Adapter & Memory Subsystem
rtl/interconnect/axi_lsu_dwidth_adapter.v
rtl/veer_wrapper/veer_mem_subsystem.sv

// 2x6 Interconnect
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

// Top-Level SoC & Testbench
rtl/smart_controlsoc_veer_top.v
tb/tb_smart_controlsoc_veer_top.sv

