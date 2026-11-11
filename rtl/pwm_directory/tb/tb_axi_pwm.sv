`timescale 1ns/1ps

module tb_axi_pwm;

    localparam integer DATA_WIDTH = 32;
    localparam integer ADDR_WIDTH = 4;
    localparam integer STRB_WIDTH = DATA_WIDTH / 8;
    localparam integer CLK_PERIOD = 10; // 100 MHz
    localparam integer PWM_PERIOD = 256;
    localparam integer AXI_TIMEOUT_CYCLES = 100;
    localparam integer SIM_TIMEOUT_CYCLES = 20000;

    // Register Offsets (4-bit byte address)
    localparam [ADDR_WIDTH-1:0] REG_PWM_DUTY = 4'h0; // slv_reg0 ([7:0] = duty_cycle)
    localparam [ADDR_WIDTH-1:0] REG_SLV_1    = 4'h4; // slv_reg1
    localparam [ADDR_WIDTH-1:0] REG_SLV_2    = 4'h8; // slv_reg2
    localparam [ADDR_WIDTH-1:0] REG_SLV_3    = 4'hC; // slv_reg3

    // Clock & Reset
    logic s00_axi_aclk;
    logic s00_axi_aresetn;

    // AXI4-Lite Slave Signals
    logic [ADDR_WIDTH-1:0] s00_axi_awaddr;
    logic [2:0]            s00_axi_awprot;
    logic                  s00_axi_awvalid;
    logic                  s00_axi_awready;
    logic [DATA_WIDTH-1:0] s00_axi_wdata;
    logic [STRB_WIDTH-1:0] s00_axi_wstrb;
    logic                  s00_axi_wvalid;
    logic                  s00_axi_wready;
    logic [1:0]            s00_axi_bresp;
    logic                  s00_axi_bvalid;
    logic                  s00_axi_bready;
    logic [ADDR_WIDTH-1:0] s00_axi_araddr;
    logic [2:0]            s00_axi_arprot;
    logic                  s00_axi_arvalid;
    logic                  s00_axi_arready;
    logic [DATA_WIDTH-1:0] s00_axi_rdata;
    logic [1:0]            s00_axi_rresp;
    logic                  s00_axi_rvalid;
    logic                  s00_axi_rready;

    // PWM Output
    logic pwm_out;

    // Counters
    int pass_count = 0;
    int fail_count = 0;
    int cycle_count = 0;

    // DUT Instantiation
    myip_v1_0 #(
        .C_S00_AXI_DATA_WIDTH (DATA_WIDTH),
        .C_S00_AXI_ADDR_WIDTH (ADDR_WIDTH)
    ) dut (
        .PWM_OUT          (pwm_out),
        .s00_axi_aclk     (s00_axi_aclk),
        .s00_axi_aresetn  (s00_axi_aresetn),
        .s00_axi_awaddr   (s00_axi_awaddr),
        .s00_axi_awprot   (s00_axi_awprot),
        .s00_axi_awvalid  (s00_axi_awvalid),
        .s00_axi_awready  (s00_axi_awready),
        .s00_axi_wdata    (s00_axi_wdata),
        .s00_axi_wstrb    (s00_axi_wstrb),
        .s00_axi_wvalid   (s00_axi_wvalid),
        .s00_axi_wready   (s00_axi_wready),
        .s00_axi_bresp    (s00_axi_bresp),
        .s00_axi_bvalid   (s00_axi_bvalid),
        .s00_axi_bready   (s00_axi_bready),
        .s00_axi_araddr   (s00_axi_araddr),
        .s00_axi_arprot   (s00_axi_arprot),
        .s00_axi_arvalid  (s00_axi_arvalid),
        .s00_axi_arready  (s00_axi_arready),
        .s00_axi_rdata    (s00_axi_rdata),
        .s00_axi_rresp    (s00_axi_rresp),
        .s00_axi_rvalid   (s00_axi_rvalid),
        .s00_axi_rready   (s00_axi_rready)
    );

    // Clock Generator
    initial begin
        s00_axi_aclk = 1'b0;
        forever #(CLK_PERIOD / 2) s00_axi_aclk = ~s00_axi_aclk;
    end

    // Simulation Timeout Watchdog
    always @(posedge s00_axi_aclk) begin
        cycle_count <= cycle_count + 1;
        if (cycle_count >= SIM_TIMEOUT_CYCLES) begin
            $display("[TIMEOUT] Simulation exceeded %0d clock cycles!", SIM_TIMEOUT_CYCLES);
            $display("RESULT: FAIL (Simulation Timeout)");
            $fatal(1, "Simulation timeout reached in tb_axi_pwm");
        end
    end

    // Check Helper
    task automatic check_eq32(
        input logic [31:0] actual,
        input logic [31:0] expected,
        input string       label
    );
        if (actual === expected) begin
            $display("  [PASS] %s: actual=0x%08h == expected=0x%08h", label, actual, expected);
            pass_count++;
        end else begin
            $display("  [FAIL] %s: actual=0x%08h != expected=0x%08h", label, actual, expected);
            fail_count++;
        end
    endtask

    // AXI4-Lite Write Task
    task automatic axi_write(
        input logic [ADDR_WIDTH-1:0] addr,
        input logic [31:0]           data,
        input logic [3:0]            strb = 4'hF
    );
        bit aw_done;
        bit w_done;
        bit b_done;
        int wait_cycles;
        logic [1:0] resp;
        begin
            @(posedge s00_axi_aclk);
            s00_axi_awaddr  <= addr;
            s00_axi_awprot  <= 3'b000;
            s00_axi_awvalid <= 1'b1;
            s00_axi_wdata   <= data;
            s00_axi_wstrb   <= strb;
            s00_axi_wvalid  <= 1'b1;
            s00_axi_bready  <= 1'b1;

            aw_done = 1'b0;
            w_done  = 1'b0;
            b_done  = 1'b0;
            wait_cycles = 0;

            while (!(aw_done && w_done && b_done)) begin
                @(posedge s00_axi_aclk);
                wait_cycles++;
                if (wait_cycles > AXI_TIMEOUT_CYCLES) begin
                    $display("  [FAIL] AXI Write timeout at addr=0x%0h", addr);
                    fail_count++;
                    s00_axi_awvalid <= 1'b0;
                    s00_axi_wvalid  <= 1'b0;
                    s00_axi_bready  <= 1'b0;
                    resp = 2'b00;
                    aw_done = 1'b1;
                    w_done  = 1'b1;
                    b_done  = 1'b1;
                end else begin
                    if (s00_axi_awvalid && s00_axi_awready) begin
                        s00_axi_awvalid <= 1'b0;
                        aw_done = 1'b1;
                    end
                    if (s00_axi_wvalid && s00_axi_wready) begin
                        s00_axi_wvalid <= 1'b0;
                        w_done = 1'b1;
                    end
                    if (s00_axi_bvalid && s00_axi_bready) begin
                        resp = s00_axi_bresp;
                        b_done = 1'b1;
                        s00_axi_bready <= 1'b0;
                    end
                end
            end

            if (resp !== 2'b00) begin
                $display("  [FAIL] AXI Write BRESP != OKAY (0x%0h) at addr=0x%0h", resp, addr);
                fail_count++;
            end
        end
    endtask

    // AXI4-Lite Read Task
    task automatic axi_read(
        input  logic [ADDR_WIDTH-1:0] addr,
        output logic [31:0]           data
    );
        bit ar_done;
        bit r_done;
        int wait_cycles;
        logic [1:0] resp;
        begin
            @(posedge s00_axi_aclk);
            s00_axi_araddr  <= addr;
            s00_axi_arprot  <= 3'b000;
            s00_axi_arvalid <= 1'b1;
            s00_axi_rready  <= 1'b1;

            ar_done = 1'b0;
            r_done  = 1'b0;
            wait_cycles = 0;

            while (!(ar_done && r_done)) begin
                @(posedge s00_axi_aclk);
                wait_cycles++;
                if (wait_cycles > AXI_TIMEOUT_CYCLES) begin
                    $display("  [FAIL] AXI Read timeout at addr=0x%0h", addr);
                    fail_count++;
                    data = 32'hXXXX_XXXX;
                    resp = 2'b00;
                    s00_axi_arvalid <= 1'b0;
                    s00_axi_rready  <= 1'b0;
                    ar_done = 1'b1;
                    r_done  = 1'b1;
                end else begin
                    if (s00_axi_arvalid && s00_axi_arready) begin
                        s00_axi_arvalid <= 1'b0;
                        ar_done = 1'b1;
                    end
                    if (s00_axi_rvalid && s00_axi_rready) begin
                        data = s00_axi_rdata;
                        resp = s00_axi_rresp;
                        r_done = 1'b1;
                        s00_axi_rready <= 1'b0;
                    end
                end
            end

            if (resp !== 2'b00) begin
                $display("  [FAIL] AXI Read RRESP != OKAY (0x%0h) at addr=0x%0h", resp, addr);
                fail_count++;
            end
        end
    endtask

    // Measure and Verify PWM Period and Duty Cycle
    task automatic verify_pwm_waveform(
        input int    exp_high_cycles,
        input int    num_periods,
        input string test_name
    );
        int cyc;
        int high_cnt;
        int low_cnt;
        int p;
        int wait_cnt;
        bit prev_pwm;
        bit synced;
        bit period_err;
        int exp_low_cycles;
        begin
            exp_low_cycles = PWM_PERIOD - exp_high_cycles;

            // Allow 1 full PWM period to finish any in-flight cycle after register write
            repeat (PWM_PERIOD) @(posedge s00_axi_aclk);
            #1;

            if (exp_high_cycles == 0) begin
                // Static 0% case: no edges should occur
                high_cnt = 0;
                low_cnt  = 0;
                for (cyc = 0; cyc < num_periods * PWM_PERIOD; cyc++) begin
                    if (pwm_out === 1'b1)
                        high_cnt++;
                    else if (pwm_out === 1'b0)
                        low_cnt++;
                    else begin
                        $display("  [FAIL] %s: X/Z observed on pwm_out (%b)", test_name, pwm_out);
                        fail_count++;
                        cyc = num_periods * PWM_PERIOD;
                    end
                    @(posedge s00_axi_aclk);
                    #1;
                end
                if (high_cnt == 0 && low_cnt == num_periods * PWM_PERIOD) begin
                    $display("  [PASS] %s: 0%% duty verified (%0d high / %0d low over %0d cycles)",
                             test_name, high_cnt, low_cnt, num_periods * PWM_PERIOD);
                    pass_count++;
                end else begin
                    $display("  [FAIL] %s: expected 0 high / %0d low, got %0d high / %0d low",
                             test_name, num_periods * PWM_PERIOD, high_cnt, low_cnt);
                    fail_count++;
                end
            end else begin
                // Dynamic waveform (1 <= exp_high_cycles <= 255): synchronize on rising edge (0 -> 1)
                wait_cnt = 0;
                prev_pwm = pwm_out;
                synced = 1'b0;
                while (!synced && (wait_cnt < 2 * PWM_PERIOD + 10)) begin
                    @(posedge s00_axi_aclk);
                    #1;
                    wait_cnt++;
                    if (prev_pwm === 1'b0 && pwm_out === 1'b1) begin
                        synced = 1'b1;
                    end
                    prev_pwm = pwm_out;
                end

                if (!synced) begin
                    $display("  [FAIL] %s: failed to detect rising edge within %0d cycles (pwm_out=%b)",
                             test_name, 2 * PWM_PERIOD + 10, pwm_out);
                    fail_count++;
                end else begin
                    period_err = 1'b0;
                    for (p = 0; p < num_periods; p++) begin
                        // Currently at cycle 0 of HIGH phase
                        high_cnt = 1;
                        low_cnt  = 0;
                        prev_pwm = pwm_out;

                        for (cyc = 1; cyc < PWM_PERIOD; cyc++) begin
                            @(posedge s00_axi_aclk);
                            #1;
                            if (pwm_out === 1'b1) begin
                                if (low_cnt > 0) begin
                                    $display("  [FAIL] %s period %0d: unexpected rising edge at cycle %0d (early period=%0d)",
                                             test_name, p, cyc, high_cnt + low_cnt);
                                    period_err = 1'b1;
                                end
                                high_cnt++;
                            end else if (pwm_out === 1'b0) begin
                                low_cnt++;
                            end else begin
                                $display("  [FAIL] %s period %0d: X/Z on pwm_out", test_name, p);
                                period_err = 1'b1;
                            end
                            prev_pwm = pwm_out;
                        end

                        // Advance to cycle 0 of next period and verify rising edge boundary
                        @(posedge s00_axi_aclk);
                        #1;
                        if (!(prev_pwm === 1'b0 && pwm_out === 1'b1)) begin
                            $display("  [FAIL] %s period %0d: expected rising edge at cycle 256 boundary (prev=%b, cur=%b)",
                                     test_name, p, prev_pwm, pwm_out);
                            period_err = 1'b1;
                        end

                        if ((high_cnt != exp_high_cycles) || (low_cnt != exp_low_cycles)) begin
                            $display("  [FAIL] %s period %0d: high=%0d (exp %0d), low=%0d (exp %0d), total=%0d",
                                     test_name, p, high_cnt, exp_high_cycles, low_cnt, exp_low_cycles, high_cnt + low_cnt);
                            period_err = 1'b1;
                        end
                    end

                    if (!period_err) begin
                        $display("  [PASS] %s: verified %0d period(s), Period=%0d cycles, High=%0d, Low=%0d (%0.2f%%)",
                                 test_name, num_periods, PWM_PERIOD, exp_high_cycles, exp_low_cycles,
                                 (exp_high_cycles * 100.0) / PWM_PERIOD);
                        pass_count++;
                    end else begin
                        fail_count++;
                    end
                end
            end
        end
    endtask

    task automatic apply_reset(input int cycles);
        begin
            s00_axi_aresetn = 1'b0;
            s00_axi_awaddr  = '0;
            s00_axi_awprot  = 3'b000;
            s00_axi_awvalid = 1'b0;
            s00_axi_wdata   = '0;
            s00_axi_wstrb   = 4'h0;
            s00_axi_wvalid  = 1'b0;
            s00_axi_bready  = 1'b0;
            s00_axi_araddr  = '0;
            s00_axi_arprot  = 3'b000;
            s00_axi_arvalid = 1'b0;
            s00_axi_rready  = 1'b0;
            repeat (cycles) @(posedge s00_axi_aclk);
            #1;
            s00_axi_aresetn = 1'b1;
            repeat (2) @(posedge s00_axi_aclk);
            #1;
        end
    endtask

    // Main Test Sequence
    logic [31:0] rdata;
    initial begin
        $display("==================================================================");
        $display("  Starting PWM Generator Testbench (tb_axi_pwm)");
        $display("==================================================================");

        // ------------------------------------------------------------------
        // TEST 1: Reset State & Default Register Values
        // ------------------------------------------------------------------
        $display("\n[TEST 1] Reset State & Default Register Values");
        apply_reset(5);
        if (pwm_out === 1'b0) begin
            $display("  [PASS] Post-reset pwm_out is 0");
            pass_count++;
        end else begin
            $display("  [FAIL] Post-reset pwm_out=%b != 0", pwm_out);
            fail_count++;
        end

        axi_read(REG_PWM_DUTY, rdata); check_eq32(rdata, 32'h0000_0000, "Reset slv_reg0 (DUTY)");
        axi_read(REG_SLV_1,    rdata); check_eq32(rdata, 32'h0000_0000, "Reset slv_reg1");
        axi_read(REG_SLV_2,    rdata); check_eq32(rdata, 32'h0000_0000, "Reset slv_reg2");
        axi_read(REG_SLV_3,    rdata); check_eq32(rdata, 32'h0000_0000, "Reset slv_reg3");

        verify_pwm_waveform(0, 1, "Default Reset 0% Output");

        // ------------------------------------------------------------------
        // TEST 2: Register Access (slv_reg0..3), WSTRB & Upper-Bit Masking
        // ------------------------------------------------------------------
        $display("\n[TEST 2] Register R/W, Byte Strobes & Upper-Bit Behavior");
        axi_write(REG_PWM_DUTY, 32'hA5A5_5A80, 4'hF);
        axi_write(REG_SLV_1,    32'h1122_3344, 4'hF);
        axi_write(REG_SLV_2,    32'hDEAD_BEEF, 4'hF);
        axi_write(REG_SLV_3,    32'hCAFE_BABE, 4'hF);

        axi_read(REG_PWM_DUTY, rdata); check_eq32(rdata, 32'hA5A5_5A80, "slv_reg0 full write/readback");
        axi_read(REG_SLV_1,    rdata); check_eq32(rdata, 32'h1122_3344, "slv_reg1 write/readback");
        axi_read(REG_SLV_2,    rdata); check_eq32(rdata, 32'hDEAD_BEEF, "slv_reg2 write/readback");
        axi_read(REG_SLV_3,    rdata); check_eq32(rdata, 32'hCAFE_BABE, "slv_reg3 write/readback");

        // Verify upper bits [31:8] do not alter 50% duty cycle (slv_reg0[7:0] == 0x80)
        verify_pwm_waveform(128, 2, "50% Duty with upper bits [31:8] non-zero");

        // Byte-strobe partial write test on slv_reg0 and slv_reg1
        axi_write(REG_PWM_DUTY, 32'hFFFF_FF40, 4'b0001); // only byte 0 updated -> 0xA5A5_5A40
        axi_read(REG_PWM_DUTY, rdata); check_eq32(rdata, 32'hA5A5_5A40, "slv_reg0 WSTRB=4'b0001 partial write");

        axi_write(REG_SLV_1, 32'hAA00_BB00, 4'b1010); // bytes 3 and 1 -> 0xAA22_BB44
        axi_read(REG_SLV_1, rdata); check_eq32(rdata, 32'hAA22_BB44, "slv_reg1 WSTRB=4'b1010 partial write");

        // ------------------------------------------------------------------
        // TEST 3: 0% Duty Cycle (Disable from active state)
        // ------------------------------------------------------------------
        $display("\n[TEST 3] 0%% Duty Cycle Verification");
        axi_write(REG_PWM_DUTY, 32'h0000_0000, 4'hF);
        axi_read(REG_PWM_DUTY, rdata); check_eq32(rdata, 32'h0000_0000, "DUTY programmed to 0x00");
        verify_pwm_waveform(0, 2, "0% Duty Cycle (0/256)");

        // ------------------------------------------------------------------
        // TEST 4: 50% Duty Cycle & Period Verification
        // ------------------------------------------------------------------
        $display("\n[TEST 4] 50%% Duty Cycle (0x80 = 128/256) & Period Verification");
        axi_write(REG_PWM_DUTY, 32'h0000_0080, 4'hF);
        axi_read(REG_PWM_DUTY, rdata); check_eq32(rdata, 32'h0000_0080, "DUTY programmed to 0x80");
        verify_pwm_waveform(128, 2, "50% Duty Cycle (128/256)");

        // ------------------------------------------------------------------
        // TEST 5: Intermediate & Minimum Duty Cycles (1/256, 25%, 75%)
        // ------------------------------------------------------------------
        $display("\n[TEST 5] Fractional & Boundary Duty Cycles");
        axi_write(REG_PWM_DUTY, 32'h0000_0001, 4'hF);
        verify_pwm_waveform(1, 2, "Minimum Non-Zero Duty (1/256 = 0.39%)");

        axi_write(REG_PWM_DUTY, 32'h0000_0040, 4'hF);
        verify_pwm_waveform(64, 2, "25% Duty Cycle (64/256)");

        axi_write(REG_PWM_DUTY, 32'h0000_00C0, 4'hF);
        verify_pwm_waveform(192, 2, "75% Duty Cycle (192/256)");

        // ------------------------------------------------------------------
        // TEST 6: Maximum Supported Duty (0xFF = 255/256) & 100% Capability Check
        // ------------------------------------------------------------------
        $display("\n[TEST 6] Maximum Duty (0xFF = 255/256) & 100%% Capability Check");
        $display("  [INFO] RTL uses 8-bit duty_cycle = slv_reg0[7:0] and strict '<' (pwm_counter < duty_cycle);");
        $display("         true 100%% (256/256 continuous HIGH) is not supported, max achievable is 255/256 (99.61%%).");
        axi_write(REG_PWM_DUTY, 32'h0000_00FF, 4'hF);
        axi_read(REG_PWM_DUTY, rdata); check_eq32(rdata, 32'h0000_00FF, "DUTY programmed to 0xFF");
        verify_pwm_waveform(255, 2, "Max 8-bit Duty Cycle (255/256 = 99.61%)");

        // Writing 0x100 wraps 8-bit duty_cycle[7:0] to 0x00 (0%), confirming 256/256 is unsupported
        axi_write(REG_PWM_DUTY, 32'h0000_0100, 4'hF);
        axi_read(REG_PWM_DUTY, rdata); check_eq32(rdata, 32'h0000_0100, "DUTY readback 0x100 (duty[7:0]=0x00)");
        verify_pwm_waveform(0, 1, "DUTY=0x100 truncates to 8'h00 (0% output)");

        // ------------------------------------------------------------------
        // TEST 7: Mid-Operation Reset Recovery
        // ------------------------------------------------------------------
        $display("\n[TEST 7] Mid-Operation Reset Recovery");
        axi_write(REG_PWM_DUTY, 32'h0000_0080, 4'hF);
        axi_write(REG_SLV_1,    32'h1234_5678, 4'hF);
        // Wait until PWM_OUT is observed HIGH before resetting
        begin : wait_pwm_high_blk
            int rst_wait;
            rst_wait = 0;
            while ((pwm_out !== 1'b1) && (rst_wait < PWM_PERIOD + 10)) begin
                @(posedge s00_axi_aclk);
                #1;
                rst_wait++;
            end
        end
        apply_reset(5);
        if (pwm_out === 1'b0) begin
            $display("  [PASS] Mid-op reset cleared pwm_out to 0");
            pass_count++;
        end else begin
            $display("  [FAIL] Mid-op reset did not clear pwm_out (%b)", pwm_out);
            fail_count++;
        end
        axi_read(REG_PWM_DUTY, rdata); check_eq32(rdata, 32'h0000_0000, "Post-reset slv_reg0");
        axi_read(REG_SLV_1,    rdata); check_eq32(rdata, 32'h0000_0000, "Post-reset slv_reg1");
        verify_pwm_waveform(0, 1, "Post-reset 0% Output");

        // ------------------------------------------------------------------
        // Summary
        // ------------------------------------------------------------------
        $display("\n==================================================================");
        $display("  tb_axi_pwm Summary: PASS=%0d, FAIL=%0d", pass_count, fail_count);
        if (fail_count == 0) begin
            $display("  OVERALL RESULT: PASS");
            $display("==================================================================");
            $finish;
        end else begin
            $display("  OVERALL RESULT: FAIL");
            $display("==================================================================");
            $fatal(1, "tb_axi_pwm failed with %0d error(s)", fail_count);
        end
    end

endmodule
