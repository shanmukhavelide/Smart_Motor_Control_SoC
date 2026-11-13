// =============================================================================
// Smart ControlSoC Testbench with Synthesizable VeeR EL2 Processor Core
// Module: tb_smart_controlsoc_veer_top
// Description: System-level verification bench for smart_controlsoc_veer_top.
// Loads firmware into ICCM with real-time ECC synd calculation, observes
// CPU instruction execution trace, monitors UART transmission output,
// and verifies peripheral exercise through GPIO 0x900D completion signature.
// =============================================================================

`timescale 1ns/1ps

`include "common_defines.vh"

module tb_smart_controlsoc_veer_top;
    import el2_pkg::*;

    // -------------------------------------------------------------------------
    // Clock & Reset Parameters
    // -------------------------------------------------------------------------
    localparam CLK_PERIOD = 10; // 100 MHz clock (10 ns period)

    reg sys_clk;
    reg sys_rst_n;

    // Peripheral I/O Wires
    reg         uart_rx_i;
    wire        uart_tx_o;
    wire        uart_interrupt_o;

    wire        spi_clk_o;
    wire        spi_cs_n_o;
    wire        spi_mosi_o;
    reg         spi_miso_i;
    wire        spi_interrupt_o;

    wire [7:0]  seg7_seg_o;
    wire [7:0]  seg7_an_o;

    wire        pwm_out_o;

    wire [31:0] gpio_io;
    wire        gpio_interrupt_o;

    wire        timer_interrupt_o;

    // Core Trace Observability Wires
    wire        trace_rv_i_valid_ip;
    wire [31:0] trace_rv_i_address_ip;
    wire [31:0] trace_rv_i_insn_ip;
    wire        trace_rv_i_exception_ip;
    wire        trace_rv_i_interrupt_ip;

    // Testbench Control Variables
    string      hex_file = "sw/build/firmware_veer.hex";
    int         max_cycles = 200000;
    int         cycle_count = 0;
    int         insn_count = 0;
    bit         pass_detected = 0;
    int         trace_log_fd;

    // -------------------------------------------------------------------------
    // DUT Instantiation
    // -------------------------------------------------------------------------
    smart_controlsoc_veer_top dut (
        .sys_clk                 (sys_clk),
        .sys_rst_n               (sys_rst_n),

        // UART Interface
        .uart_rx_i               (uart_rx_i),
        .uart_tx_o               (uart_tx_o),
        .uart_interrupt_o        (uart_interrupt_o),

        // SPI Interface
        .spi_clk_o               (spi_clk_o),
        .spi_cs_n_o              (spi_cs_n_o),
        .spi_mosi_o              (spi_mosi_o),
        .spi_miso_i              (spi_miso_i),
        .spi_interrupt_o         (spi_interrupt_o),

        // Seven-Segment Display Interface
        .seg7_seg_o              (seg7_seg_o),
        .seg7_an_o               (seg7_an_o),

        // PWM Interface
        .pwm_out_o               (pwm_out_o),

        // GPIO Interface
        .gpio_io                 (gpio_io),
        .gpio_interrupt_o        (gpio_interrupt_o),

        // Timer Interface
        .timer_interrupt_o       (timer_interrupt_o),

        // Core Trace Observability
        .trace_rv_i_valid_ip     (trace_rv_i_valid_ip),
        .trace_rv_i_address_ip   (trace_rv_i_address_ip),
        .trace_rv_i_insn_ip      (trace_rv_i_insn_ip),
        .trace_rv_i_exception_ip (trace_rv_i_exception_ip),
        .trace_rv_i_interrupt_ip (trace_rv_i_interrupt_ip)
    );

    // -------------------------------------------------------------------------
    // Clock Generation
    // -------------------------------------------------------------------------
    initial begin
        sys_clk = 1'b0;
        forever #(CLK_PERIOD / 2) sys_clk = ~sys_clk;
    end

    // -------------------------------------------------------------------------
    // VeeR EL2 ECC-32 Generator Function
    // -------------------------------------------------------------------------
    function automatic [6:0] riscv_ecc32(input [31:0] data);
        reg [6:0] synd;
        synd[0] = ^(data & 32'h56aa_ad5b);
        synd[1] = ^(data & 32'h9b33_366d);
        synd[2] = ^(data & 32'he3c3_c78e);
        synd[3] = ^(data & 32'h03fc_07f0);
        synd[4] = ^(data & 32'h03ff_f800);
        synd[5] = ^(data & 32'hfc00_0000);
        synd[6] = ^{data, synd[5:0]};
        return synd;
    endfunction

    // -------------------------------------------------------------------------
    // ICCM / DCCM Memory Preload Task
    // -------------------------------------------------------------------------
    task automatic preload_iccm(input string hex_path);
        int fd;
        string token;
        logic [31:0] cur_addr;
        logic [31:0] word_val;
        logic [6:0]  ecc;
        int bank, idx;
        int count;

        // Zero-initialize ICCM and DCCM banks with valid ECC
        for (int b = 0; b < pt.ICCM_NUM_BANKS; b++) begin
            for (int i = 0; i < 4096; i++) begin
                dut.mem_subsys.gen_iccm_banks[b].iccm_bank_inst.ram_core[i] = {riscv_ecc32(32'h0), 32'h0};
            end
        end
        for (int b = 0; b < pt.DCCM_NUM_BANKS; b++) begin
            for (int i = 0; i < 4096; i++) begin
                dut.mem_subsys.gen_dccm_banks[b].dccm_bank_inst.ram_core[i] = {riscv_ecc32(32'h0), 32'h0};
            end
        end

        fd = $fopen(hex_path, "r");
        if (!fd) begin
            $display("[%0t ns] [TB ERROR] Could not open hex file: %s", $time, hex_path);
            $finish;
        end

        cur_addr = 32'h0;
        count = 0;
        while ($fscanf(fd, "%s", token) == 1) begin
            if (token.substr(0, 0) == "@") begin
                void'($sscanf(token, "@%h", cur_addr));
                // If absolute address, map ICCM 0xEE00_0000 to offset 0
                if (cur_addr >= 32'hEE00_0000 && cur_addr <= 32'hEE00_FFFF) begin
                    cur_addr = cur_addr - 32'hEE00_0000;
                end
            end else begin
                if ($sscanf(token, "%h", word_val) == 1) begin
                    if (cur_addr < 32'h10000) begin
                        bank = cur_addr[3:2];
                        idx  = cur_addr[15:4];
                        ecc  = riscv_ecc32(word_val);
                        dut.mem_subsys.gen_iccm_banks[bank].iccm_bank_inst.ram_core[idx] = {ecc, word_val};
                        count++;
                        cur_addr = cur_addr + 4;
                    end
                end
            end
        end
        $fclose(fd);
        $display("[%0t ns] [TB] Preloaded %0d instruction words into VeeR ICCM from %s", $time, count, hex_path);
    endtask

    // -------------------------------------------------------------------------
    // Main Test Stimulus
    // -------------------------------------------------------------------------
    initial begin
        // Waveform dumping
`ifdef VCS_DEBUG
        $fsdbDumpfile("smart_controlsoc_veer.fsdb");
        $fsdbDumpvars(0, tb_smart_controlsoc_veer_top);
        $fsdbDumpMDA();
`elsif DUMP_VCD
        $dumpfile("smart_controlsoc_veer.vcd");
        $dumpvars(0, tb_smart_controlsoc_veer_top);
`endif

        if ($value$plusargs("HEX=%s", hex_file)) begin
            $display("[%0t ns] [TB] Overriding firmware hex path: %s", $time, hex_file);
        end
        if ($value$plusargs("TIMEOUT=%d", max_cycles)) begin
            $display("[%0t ns] [TB] Overriding max simulation cycles: %0d", $time, max_cycles);
        end

        // Default tie-offs
        uart_rx_i  = 1'b1;
        spi_miso_i = 1'b0;

        trace_log_fd = $fopen("trace_execution.log", "w");
        $fwrite(trace_log_fd, "Cycle,CommitIndex,PC,Insn\n");

        $display("==================================================================");
        $display("   Smart ControlSoC Synthesizable VeeR EL2 Simulation Starting    ");
        $display("   Firmware Image : %s", hex_file);
        $display("   Target Clock   : 100 MHz (Period: %0d ns)", CLK_PERIOD);
        $display("==================================================================");

        // Preload ICCM firmware before releasing reset
        preload_iccm(hex_file);

        // Reset Sequencing
        sys_rst_n = 1'b0;
        #(CLK_PERIOD * 10);
        sys_rst_n = 1'b1;
        $display("[%0t ns] [TB] CPU Core System Reset Released. VeeR EL2 running...", $time);
    end

    // -------------------------------------------------------------------------
    // Cycle Counter & Timeout Watchdog
    // -------------------------------------------------------------------------
    always @(posedge sys_clk) begin
        cycle_count <= cycle_count + 1;
        if (cycle_count >= max_cycles) begin
            $display("==================================================================");
            $display("[%0t ns] [TB ERROR] Simulation Watchdog Timeout reached (%0d cycles)!", $time, max_cycles);
            $display("   Total Instructions Committed : %0d", insn_count);
            $display("   GPIO Output Value            : 0x%08h", gpio_io);
            $display("==================================================================");
            if (trace_log_fd) $fclose(trace_log_fd);
            $finish;
        end
    end

    // -------------------------------------------------------------------------
    // Instruction Commit Trace Logger
    // -------------------------------------------------------------------------
    always @(posedge sys_clk) begin
        if (sys_rst_n && trace_rv_i_valid_ip) begin
            insn_count <= insn_count + 1;
            if (trace_log_fd) begin
                $fwrite(trace_log_fd, "%0d,%0d,0x%08h,0x%08h\n",
                        cycle_count, insn_count, trace_rv_i_address_ip, trace_rv_i_insn_ip);
            end

            // Print milestone trace entries every 100 instructions
            if ((insn_count % 100) == 0 || insn_count < 10) begin
                $display("[%0t ns] [CPU TRACE #%0d] PC: 0x%08h | INSN: 0x%08h",
                         $time, insn_count, trace_rv_i_address_ip, trace_rv_i_insn_ip);
            end
        end
    end

    // -------------------------------------------------------------------------
    // GPIO Magic Signature Monitor (0x900D)
    // -------------------------------------------------------------------------
    always @(posedge sys_clk) begin
        if (sys_rst_n) begin
            if (gpio_io[15:0] == 16'h900D && !pass_detected) begin
                pass_detected <= 1'b1;
                $display("\n==================================================================");
                $display("   *** SMART MOTOR CONTROLSOC VEER EXECUTION PASSED! ***");
                $display("   Magic Signature 0x900D Detected on GPIO[15:0]");
                $display("   Simulation Time           : %0t ns", $time);
                $display("   Elapsed Clock Cycles      : %0d", cycle_count);
                $display("   Instructions Committed    : %0d", insn_count);
                $display("==================================================================\n");

                // Allow 500 more cycles for final UART drain and flush
                repeat (500) @(posedge sys_clk);
                if (trace_log_fd) $fclose(trace_log_fd);
                $finish;
            end
        end
    end

    // -------------------------------------------------------------------------
    // UART TX Output Monitor (Baud divisor = 40 clock cycles per bit)
    // -------------------------------------------------------------------------
    localparam BAUD_CYCLES = 40;
    string uart_line_buf = "";

    initial begin
        @(posedge sys_rst_n);
        forever begin
            reg [7:0] rx_char;
            // Wait for start bit (falling edge on uart_tx_o)
            @(negedge uart_tx_o);
            #(CLK_PERIOD * (BAUD_CYCLES + BAUD_CYCLES/2)); // Halfway into bit 0

            // Sample 8 data bits
            for (int i = 0; i < 8; i++) begin
                rx_char[i] = uart_tx_o;
                #(CLK_PERIOD * BAUD_CYCLES);
            end

            // Process received byte
            if (rx_char == 8'h0A) begin // Newline '\n'
                $display("[%0t ns] [UART CONSOLE] %s", $time, uart_line_buf);
                uart_line_buf = "";
            end else if (rx_char != 8'h0D) begin // Ignore '\r'
                uart_line_buf = {uart_line_buf, string'(rx_char)};
            end
        end
    end

endmodule

