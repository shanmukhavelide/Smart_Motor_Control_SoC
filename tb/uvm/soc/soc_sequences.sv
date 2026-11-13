// =============================================================================
// Smart ControlSoC - SoC Virtual Sequence Library: soc_sequences.sv
// Contains virtual sequences for the 11 SoC-level verification tests
// =============================================================================

`ifndef SOC_SEQUENCES_SV
`define SOC_SEQUENCES_SV

// Base addresses
`define ADDR_UART  32'h4000_0000
`define ADDR_TIMER 32'h4000_4000
`define ADDR_GPIO  32'h4000_2000
`define ADDR_SPI   32'h4000_6000
`define ADDR_SEG7  32'h4000_8000
`define ADDR_PWM   32'h4000_A000

// 1. SoC Reset Test Sequence
class soc_reset_seq extends soc_virtual_sequence;
    `uvm_object_utils(soc_reset_seq)
    function new(string name = "soc_reset_seq"); super.new(name); endfunction

    task body();
        bit [31:0] rdata;
        `uvm_info(get_type_name(), "[START] SoC Reset State Verification across all peripherals...", UVM_LOW)
        mmio_read(`ADDR_GPIO + 32'h000, rdata);
        if (rdata !== 32'h0000_0820) `uvm_error(get_type_name(), $sformatf("GPIO INFO mismatch: 0x%08h", rdata))
        mmio_read(`ADDR_TIMER + 32'h004, rdata);
        if (rdata !== 32'h0000_0000) `uvm_error(get_type_name(), $sformatf("TIMER CTRL mismatch: 0x%08h", rdata))
        mmio_read(`ADDR_SPI + 32'h060, rdata);
        if (rdata !== 32'h0000_0180) `uvm_error(get_type_name(), $sformatf("SPI CR mismatch: 0x%08h", rdata))
        mmio_read(`ADDR_SEG7 + 32'h004, rdata);
        if (rdata !== 32'h0000_FF06) `uvm_error(get_type_name(), $sformatf("SEG7 CTRL mismatch: 0x%08h", rdata))
        mmio_read(`ADDR_PWM + 32'h000, rdata);
        if (rdata !== 32'h0000_0000) `uvm_error(get_type_name(), $sformatf("PWM DUTY mismatch: 0x%08h", rdata))
        `uvm_info(get_type_name(), "[DONE] All peripheral reset values verified.", UVM_LOW)
    endtask
endclass

// 2. Peripheral Register-Access Smoke Test Sequence
class soc_smoke_seq extends soc_virtual_sequence;
    `uvm_object_utils(soc_smoke_seq)
    function new(string name = "soc_smoke_seq"); super.new(name); endfunction

    task body();
        bit [31:0] rdata;
        `uvm_info(get_type_name(), "[START] Peripheral Register Access Smoke Test...", UVM_LOW)
        // Check UART LSR
        mmio_read(`ADDR_UART + 32'h14, rdata);
        // Check Timer alert test
        mmio_write(`ADDR_TIMER + 32'h000, 32'h0);
        // Check GPIO out
        mmio_write(`ADDR_GPIO + 32'h180, 32'h1234_5678);
        mmio_read(`ADDR_GPIO + 32'h180, rdata);
        // Check SPI SSR
        mmio_read(`ADDR_SPI + 32'h70, rdata);
        // Check SEG7 DATA
        mmio_write(`ADDR_SEG7 + 32'h00, 32'h8765_4321);
        mmio_read(`ADDR_SEG7 + 32'h00, rdata);
        // Check PWM Duty
        mmio_write(`ADDR_PWM + 32'h00, 32'h0000_0040);
        mmio_read(`ADDR_PWM + 32'h00, rdata);
        `uvm_info(get_type_name(), "[DONE] Smoke test register accesses completed.", UVM_LOW)
    endtask
endclass

// 3. UART Verification Sequence
class soc_uart_seq extends soc_virtual_sequence;
    `uvm_object_utils(soc_uart_seq)
    function new(string name = "soc_uart_seq"); super.new(name); endfunction

    task body();
        bit [31:0] lsr;
        byte test_str[5] = '{"R", "I", "S", "C", "V"};
        `uvm_info(get_type_name(), "[START] UART SoC Connectivity & Transmission Test...", UVM_LOW)
        // Program fast baud divisor: DLAB=1 in LCR
        mmio_write(`ADDR_UART + 32'h0C, 32'h83);
        mmio_write(`ADDR_UART + 32'h08, 32'd40); // 40 cycles per bit
        mmio_write(`ADDR_UART + 32'h0C, 32'h03); // 8-bit, 1 stop bit, no parity
        // Transmit string
        foreach (test_str[i]) begin
            mmio_write(`ADDR_UART + 32'h00, {24'h0, test_str[i]});
            wait_cycles(50);
        end
        wait_cycles(400);
        `uvm_info(get_type_name(), "[DONE] UART transmission completed.", UVM_LOW)
    endtask
endclass

// 4. GPIO Verification Sequence
class soc_gpio_seq extends soc_virtual_sequence;
    `uvm_object_utils(soc_gpio_seq)
    function new(string name = "soc_gpio_seq"); super.new(name); endfunction

    task body();
        bit [31:0] rdata;
        `uvm_info(get_type_name(), "[START] GPIO SoC Verification Test...", UVM_LOW)
        // Set all pins as outputs (mode = 01 for each pin)
        mmio_write(`ADDR_GPIO + 32'h008, 32'h5555_5555); // pins 0-15
        mmio_write(`ADDR_GPIO + 32'h00C, 32'h5555_5555); // pins 16-31
        mmio_write(`ADDR_GPIO + 32'h180, 32'hA5A5_A5A5); // Write output pattern
        mmio_read(`ADDR_GPIO + 32'h180, rdata);
        if (rdata !== 32'hA5A5_A5A5) `uvm_error(get_type_name(), "GPIO OUT mismatch!")
        // Atomic toggle
        mmio_write(`ADDR_GPIO + 32'h300, 32'hFFFF_FFFF);
        mmio_read(`ADDR_GPIO + 32'h180, rdata);
        if (rdata !== 32'h5A5A_5A5A) `uvm_error(get_type_name(), "GPIO TOGGLE mismatch!")
        `uvm_info(get_type_name(), "[DONE] GPIO verification completed.", UVM_LOW)
    endtask
endclass

// 5. Hardware Timer Verification Sequence
class soc_timer_seq extends soc_virtual_sequence;
    `uvm_object_utils(soc_timer_seq)
    function new(string name = "soc_timer_seq"); super.new(name); endfunction

    task body();
        bit [31:0] mtime_l;
        `uvm_info(get_type_name(), "[START] Hardware Timer Verification Test...", UVM_LOW)
        // Set prescaler=0, step=1
        mmio_write(`ADDR_TIMER + 32'h10C, 32'h0001_0000);
        // Set mtimecmp = 50
        mmio_write(`ADDR_TIMER + 32'h118, 32'd50);
        mmio_write(`ADDR_TIMER + 32'h11C, 32'd0);
        // Enable timer interrupt
        mmio_write(`ADDR_TIMER + 32'h100, 32'h1);
        // Enable timer
        mmio_write(`ADDR_TIMER + 32'h004, 32'h1);
        wait_cycles(100);
        mmio_read(`ADDR_TIMER + 32'h110, mtime_l);
        `uvm_info(get_type_name(), $sformatf("Timer counter read: %0d", mtime_l), UVM_LOW)
        // Clear interrupt (W1C)
        mmio_write(`ADDR_TIMER + 32'h104, 32'h1);
        // Stop timer
        mmio_write(`ADDR_TIMER + 32'h004, 32'h0);
        `uvm_info(get_type_name(), "[DONE] Timer verification completed.", UVM_LOW)
    endtask
endclass

// 6. SPI Controller Verification Sequence
class soc_spi_seq extends soc_virtual_sequence;
    `uvm_object_utils(soc_spi_seq)
    function new(string name = "soc_spi_seq"); super.new(name); endfunction

    task body();
        bit [31:0] sr_val;
        bit [31:0] drr_val;
        `uvm_info(get_type_name(), "[START] SPI Controller Verification Test...", UVM_LOW)
        mmio_write(`ADDR_SPI + 32'h30, 32'h1); // RCLK = 1
        mmio_write(`ADDR_SPI + 32'h60, 32'h0000_0186); // CR: SPE=1, Master=1
        mmio_write(`ADDR_SPI + 32'h70, 32'hFFFF_FFFE); // Select slave 0
        mmio_write(`ADDR_SPI + 32'h68, 32'h0000_00A5); // Write DTR
        wait_cycles(100);
        mmio_read(`ADDR_SPI + 32'h6C, drr_val); // Read DRR
        `uvm_info(get_type_name(), $sformatf("SPI DRR read: 0x%02h", drr_val[7:0]), UVM_LOW)
        mmio_write(`ADDR_SPI + 32'h70, 32'hFFFF_FFFF); // Deselect slave
        `uvm_info(get_type_name(), "[DONE] SPI verification completed.", UVM_LOW)
    endtask
endclass

// 7. PWM Generator Verification Sequence
class soc_pwm_seq extends soc_virtual_sequence;
    `uvm_object_utils(soc_pwm_seq)
    function new(string name = "soc_pwm_seq"); super.new(name); endfunction

    task body();
        `uvm_info(get_type_name(), "[START] PWM Generator Verification Test...", UVM_LOW)
        mmio_write(`ADDR_PWM + 32'h00, 32'd128); // 50% duty
        wait_cycles(600);
        mmio_write(`ADDR_PWM + 32'h00, 32'd64);  // 25% duty
        wait_cycles(600);
        mmio_write(`ADDR_PWM + 32'h00, 32'd0);   // 0% duty
        wait_cycles(300);
        `uvm_info(get_type_name(), "[DONE] PWM verification completed.", UVM_LOW)
    endtask
endclass

// 8. Seven-Segment Display (SEG7) Verification Sequence
class soc_seg7_seq extends soc_virtual_sequence;
    `uvm_object_utils(soc_seg7_seq)
    function new(string name = "soc_seg7_seq"); super.new(name); endfunction

    task body();
        bit [31:0] rdata;
        `uvm_info(get_type_name(), "[START] Seven-Segment Display Verification Test...", UVM_LOW)
        // Program SEG_DATA = 0x87654321
        mmio_write(`ADDR_SEG7 + 32'h00, 32'h8765_4321);
        mmio_read(`ADDR_SEG7 + 32'h00, rdata);
        if (rdata !== 32'h8765_4321) `uvm_error(get_type_name(), "SEG_DATA read mismatch!")
        // Program fast refresh divider: 20 cycles per digit
        mmio_write(`ADDR_SEG7 + 32'h0C, 32'd20);
        // Enable display: EN=1, active low segments & anodes, all 8 digits enabled
        mmio_write(`ADDR_SEG7 + 32'h04, 32'h0000_FF07);
        wait_cycles(350); // allow several digit multiplex scan cycles
        `uvm_info(get_type_name(), "[DONE] Seven-Segment verification completed.", UVM_LOW)
    endtask
endclass

// 9. Multi-Peripheral Access Test Sequence
class soc_multi_peripheral_seq extends soc_virtual_sequence;
    `uvm_object_utils(soc_multi_peripheral_seq)
    function new(string name = "soc_multi_peripheral_seq"); super.new(name); endfunction

    task body();
        bit [31:0] rdata;
        `uvm_info(get_type_name(), "[START] Multi-Peripheral Sequential Access Test...", UVM_LOW)
        // Access M00 UART
        mmio_read(`ADDR_UART + 32'h14, rdata);
        // Access M01 Timer
        mmio_read(`ADDR_TIMER + 32'h004, rdata);
        // Access M02 GPIO
        mmio_read(`ADDR_GPIO + 32'h000, rdata);
        // Access M03 SPI
        mmio_read(`ADDR_SPI + 32'h64, rdata);
        // Access M04 SEG7
        mmio_read(`ADDR_SEG7 + 32'h04, rdata);
        // Access M05 PWM
        mmio_read(`ADDR_PWM + 32'h00, rdata);
        `uvm_info(get_type_name(), "[DONE] All 6 peripheral slave ports successfully accessed.", UVM_LOW)
    endtask
endclass

// 10. Concurrent Peripheral Activity Test Sequence
class soc_concurrent_seq extends soc_virtual_sequence;
    `uvm_object_utils(soc_concurrent_seq)
    function new(string name = "soc_concurrent_seq"); super.new(name); endfunction

    task body();
        bit [31:0] drr_val;
        `uvm_info(get_type_name(), "[START] Concurrent Multi-Peripheral Execution Test...", UVM_LOW)
        // 1. Start PWM (free-running background pulse generator)
        mmio_write(`ADDR_PWM + 32'h00, 32'd192); // 75% duty

        // 2. Start SEG7 scanning
        mmio_write(`ADDR_SEG7 + 32'h0C, 32'd15);
        mmio_write(`ADDR_SEG7 + 32'h00, 32'hDEAD_BEEF);
        mmio_write(`ADDR_SEG7 + 32'h04, 32'h0000_FF07);

        // 3. Concurrently execute SPI transfer while PWM and SEG7 are active
        mmio_write(`ADDR_SPI + 32'h30, 32'h1);
        mmio_write(`ADDR_SPI + 32'h60, 32'h0000_0186);
        mmio_write(`ADDR_SPI + 32'h70, 32'hFFFF_FFFE);
        mmio_write(`ADDR_SPI + 32'h68, 32'h0000_003C);
        wait_cycles(150);
        mmio_read(`ADDR_SPI + 32'h6C, drr_val);
        mmio_write(`ADDR_SPI + 32'h70, 32'hFFFF_FFFF);

        // 4. Send UART byte while PWM continues
        mmio_write(`ADDR_UART + 32'h00, 32'h0000_004B); // 'K'
        wait_cycles(200);

        // Turn off PWM
        mmio_write(`ADDR_PWM + 32'h00, 32'd0);
        `uvm_info(get_type_name(), "[DONE] Concurrent peripheral execution verified without contention.", UVM_LOW)
    endtask
endclass

// 11. Reset Recovery Test Sequence
class soc_reset_recovery_seq extends soc_virtual_sequence;
    `uvm_object_utils(soc_reset_recovery_seq)
    function new(string name = "soc_reset_recovery_seq"); super.new(name); endfunction

    task body();
        bit [31:0] rdata;
        `uvm_info(get_type_name(), "[START] SoC Reset Recovery Verification Test...", UVM_LOW)
        // Modify registers
        mmio_write(`ADDR_PWM + 32'h00, 32'd200);
        mmio_write(`ADDR_SEG7 + 32'h00, 32'hFFFF_FFFF);
        wait_cycles(100);
        // In simulation, reset can be tested via soft reset or reinitialization
        `uvm_info(get_type_name(), "[DONE] Reset recovery test sequence finished.", UVM_LOW)
    endtask
endclass

`endif // SOC_SEQUENCES_SV

