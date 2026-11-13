`timescale 1ns/1ps

module tb_axi_seg7;

    localparam integer DATA_WIDTH = 32;
    localparam integer ADDR_WIDTH = 12;
    localparam integer STRB_WIDTH = DATA_WIDTH / 8;
    localparam integer CLK_PERIOD = 10; // 100 MHz
    localparam integer AXI_TIMEOUT_CYCLES = 100;
    localparam integer SIM_TIMEOUT_CYCLES = 20000;

    // Register Offsets
    localparam [ADDR_WIDTH-1:0] REG_SEG_DATA        = 12'h000;
    localparam [ADDR_WIDTH-1:0] REG_SEG_CTRL        = 12'h004;
    localparam [ADDR_WIDTH-1:0] REG_SEG_DP          = 12'h008;
    localparam [ADDR_WIDTH-1:0] REG_SEG_REFRESH_DIV = 12'h00C;
    localparam [ADDR_WIDTH-1:0] REG_UNDEF_0         = 12'h010;
    localparam [ADDR_WIDTH-1:0] REG_UNDEF_1         = 12'h014;
    localparam [ADDR_WIDTH-1:0] REG_UNDEF_2         = 12'hFFC;

    // Reset Defaults
    localparam [31:0] RST_SEG_DATA        = 32'h0000_0000;
    localparam [31:0] RST_SEG_CTRL        = 32'h0000_FF06;
    localparam [31:0] RST_SEG_DP          = 32'h0000_0000;
    localparam [31:0] RST_SEG_REFRESH_DIV = 32'h0000_03E8;

    // Clock & Reset
    logic clk;
    logic rst_n;

    // AXI4-Lite Interface Signals
    logic [ADDR_WIDTH-1:0] s_axi_awaddr;
    logic [2:0]            s_axi_awprot;
    logic                  s_axi_awvalid;
    logic                  s_axi_awready;
    logic [DATA_WIDTH-1:0] s_axi_wdata;
    logic [STRB_WIDTH-1:0] s_axi_wstrb;
    logic                  s_axi_wvalid;
    logic                  s_axi_wready;
    logic [1:0]            s_axi_bresp;
    logic                  s_axi_bvalid;
    logic                  s_axi_bready;
    logic [ADDR_WIDTH-1:0] s_axi_araddr;
    logic [2:0]            s_axi_arprot;
    logic                  s_axi_arvalid;
    logic                  s_axi_arready;
    logic [DATA_WIDTH-1:0] s_axi_rdata;
    logic [1:0]            s_axi_rresp;
    logic                  s_axi_rvalid;
    logic                  s_axi_rready;

    // Seven-Segment Outputs
    logic [7:0] seg_o;
    logic [7:0] an_o;

    // Counters
    int pass_count = 0;
    int fail_count = 0;
    int cycle_count = 0;

    // DUT Instantiation
    axi_seg7_top #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) dut (
        .clk           (clk),
        .rst_n         (rst_n),
        .s_axi_awaddr  (s_axi_awaddr),
        .s_axi_awprot  (s_axi_awprot),
        .s_axi_awvalid (s_axi_awvalid),
        .s_axi_awready (s_axi_awready),
        .s_axi_wdata   (s_axi_wdata),
        .s_axi_wstrb   (s_axi_wstrb),
        .s_axi_wvalid  (s_axi_wvalid),
        .s_axi_wready  (s_axi_wready),
        .s_axi_bresp   (s_axi_bresp),
        .s_axi_bvalid  (s_axi_bvalid),
        .s_axi_bready  (s_axi_bready),
        .s_axi_araddr  (s_axi_araddr),
        .s_axi_arprot  (s_axi_arprot),
        .s_axi_arvalid (s_axi_arvalid),
        .s_axi_arready (s_axi_arready),
        .s_axi_rdata   (s_axi_rdata),
        .s_axi_rresp   (s_axi_rresp),
        .s_axi_rvalid  (s_axi_rvalid),
        .s_axi_rready  (s_axi_rready),
        .seg_o         (seg_o),
        .an_o          (an_o)
    );

    // Clock Generator
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // Simulation Timeout Watchdog
    always @(posedge clk) begin
        cycle_count <= cycle_count + 1;
        if (cycle_count >= SIM_TIMEOUT_CYCLES) begin
            $display("[TIMEOUT] Simulation exceeded %0d clock cycles!", SIM_TIMEOUT_CYCLES);
            $display("RESULT: FAIL (Simulation Timeout)");
            $fatal(1, "Simulation timeout reached in tb_axi_seg7");
        end
    end

    // Golden 7-Segment Hex Lookup: {g,f,e,d,c,b,a}
    function automatic logic [6:0] expected_seg7(input logic [3:0] nibble);
        case (nibble)
            4'h0: expected_seg7 = 7'h3F;
            4'h1: expected_seg7 = 7'h06;
            4'h2: expected_seg7 = 7'h5B;
            4'h3: expected_seg7 = 7'h4F;
            4'h4: expected_seg7 = 7'h66;
            4'h5: expected_seg7 = 7'h6D;
            4'h6: expected_seg7 = 7'h7D;
            4'h7: expected_seg7 = 7'h07;
            4'h8: expected_seg7 = 7'h7F;
            4'h9: expected_seg7 = 7'h6F;
            4'hA: expected_seg7 = 7'h77;
            4'hB: expected_seg7 = 7'h7C;
            4'hC: expected_seg7 = 7'h39;
            4'hD: expected_seg7 = 7'h5E;
            4'hE: expected_seg7 = 7'h79;
            4'hF: expected_seg7 = 7'h71;
            default: expected_seg7 = 7'h00;
        endcase
    endfunction

    // Helper: Check Result
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

    task automatic check_eq8(
        input logic [7:0] actual,
        input logic [7:0] expected,
        input string      label
    );
        if (actual === expected) begin
            $display("  [PASS] %s: actual=0x%02h == expected=0x%02h", label, actual, expected);
            pass_count++;
        end else begin
            $display("  [FAIL] %s: actual=0x%02h != expected=0x%02h", label, actual, expected);
            fail_count++;
        end
    endtask

    // AXI4-Lite Write Task (supports simultaneous or independent AW/W handshakes)
    task automatic axi_write(
        input  logic [ADDR_WIDTH-1:0] addr,
        input  logic [31:0]           data,
        input  logic [3:0]            strb = 4'hF
    );
        bit aw_done;
        bit w_done;
        bit b_done;
        int wait_cycles;
        logic [1:0] resp;
        begin
            @(posedge clk);
            s_axi_awaddr  <= addr;
            s_axi_awprot  <= 3'b000;
            s_axi_awvalid <= 1'b1;
            s_axi_wdata   <= data;
            s_axi_wstrb   <= strb;
            s_axi_wvalid  <= 1'b1;
            s_axi_bready  <= 1'b1;

            aw_done = 1'b0;
            w_done  = 1'b0;
            b_done  = 1'b0;
            wait_cycles = 0;

            while (!(aw_done && w_done && b_done)) begin
                @(posedge clk);
                wait_cycles++;
                if (wait_cycles > AXI_TIMEOUT_CYCLES) begin
                    $display("  [FAIL] AXI Write timeout at addr=0x%03h", addr);
                    fail_count++;
                    s_axi_awvalid <= 1'b0;
                    s_axi_wvalid  <= 1'b0;
                    s_axi_bready  <= 1'b0;
                    resp = 2'b00;
                    aw_done = 1'b1;
                    w_done  = 1'b1;
                    b_done  = 1'b1;
                end else begin
                    if (s_axi_awvalid && s_axi_awready) begin
                        s_axi_awvalid <= 1'b0;
                        aw_done = 1'b1;
                    end
                    if (s_axi_wvalid && s_axi_wready) begin
                        s_axi_wvalid <= 1'b0;
                        w_done = 1'b1;
                    end
                    if (s_axi_bvalid && s_axi_bready) begin
                        resp = s_axi_bresp;
                        b_done = 1'b1;
                        s_axi_bready <= 1'b0;
                    end
                end
            end

            if (resp !== 2'b00) begin
                $display("  [FAIL] AXI Write BRESP != OKAY (0x%0h) at addr=0x%03h", resp, addr);
                fail_count++;
            end
        end
    endtask

    // AXI4-Lite Staggered Write Task (AWVALID asserted before WVALID)
    task automatic axi_write_staggered(
        input logic [ADDR_WIDTH-1:0] addr,
        input logic [31:0]           data
    );
        int wait_cycles;
        logic [1:0] resp;
        bit done;
        begin
            @(posedge clk);
            s_axi_awaddr  <= addr;
            s_axi_awprot  <= 3'b000;
            s_axi_awvalid <= 1'b1;
            s_axi_wvalid  <= 1'b0;
            s_axi_bready  <= 1'b1;

            // Hold AWVALID for 2 cycles before presenting WVALID
            repeat (2) @(posedge clk);
            s_axi_wdata   <= data;
            s_axi_wstrb   <= 4'hF;
            s_axi_wvalid  <= 1'b1;

            wait_cycles = 0;
            done = 1'b0;
            while (!done) begin
                @(posedge clk);
                wait_cycles++;
                if (wait_cycles > AXI_TIMEOUT_CYCLES) begin
                    $display("  [FAIL] Staggered AXI Write timeout at addr=0x%03h", addr);
                    fail_count++;
                    s_axi_awvalid <= 1'b0;
                    s_axi_wvalid  <= 1'b0;
                    s_axi_bready  <= 1'b0;
                    done = 1'b1;
                end else begin
                    if (s_axi_awvalid && s_axi_awready) s_axi_awvalid <= 1'b0;
                    if (s_axi_wvalid  && s_axi_wready)  s_axi_wvalid  <= 1'b0;
                    if (s_axi_bvalid  && s_axi_bready) begin
                        resp = s_axi_bresp;
                        s_axi_bready <= 1'b0;
                        done = 1'b1;
                    end
                end
            end

            if (resp !== 2'b00) begin
                $display("  [FAIL] Staggered AXI Write BRESP != OKAY at addr=0x%03h", addr);
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
            @(posedge clk);
            s_axi_araddr  <= addr;
            s_axi_arprot  <= 3'b000;
            s_axi_arvalid <= 1'b1;
            s_axi_rready  <= 1'b1;

            ar_done = 1'b0;
            r_done  = 1'b0;
            wait_cycles = 0;

            while (!(ar_done && r_done)) begin
                @(posedge clk);
                wait_cycles++;
                if (wait_cycles > AXI_TIMEOUT_CYCLES) begin
                    $display("  [FAIL] AXI Read timeout at addr=0x%03h", addr);
                    fail_count++;
                    data = 32'hXXXX_XXXX;
                    resp = 2'b00;
                    s_axi_arvalid <= 1'b0;
                    s_axi_rready  <= 1'b0;
                    ar_done = 1'b1;
                    r_done  = 1'b1;
                end else begin
                    if (s_axi_arvalid && s_axi_arready) begin
                        s_axi_arvalid <= 1'b0;
                        ar_done = 1'b1;
                    end
                    if (s_axi_rvalid && s_axi_rready) begin
                        data = s_axi_rdata;
                        resp = s_axi_rresp;
                        r_done = 1'b1;
                        s_axi_rready <= 1'b0;
                    end
                end
            end

            if (resp !== 2'b00) begin
                $display("  [FAIL] AXI Read RRESP != OKAY (0x%0h) at addr=0x%03h", resp, addr);
                fail_count++;
            end
        end
    endtask

    // Helper: Convert active an_o to expected active digit index (-1 if blank or invalid)
    function automatic int decode_active_digit(
        input logic [7:0] an_val,
        input logic       an_active_low
    );
        logic [7:0] norm_an;
        int d;
        int cnt;
        int idx;
        begin
            norm_an = an_active_low ? ~an_val : an_val;
            cnt = 0;
            idx = -1;
            for (d = 0; d < 8; d++) begin
                if (norm_an[d] === 1'b1) begin
                    cnt++;
                    idx = d;
                end
            end
            if (cnt == 1)
                decode_active_digit = idx;
            else if (cnt == 0)
                decode_active_digit = -1; // blanked
            else
                decode_active_digit = -2; // multiple digits active (error!)
        end
    endfunction

    // Verify scanning over active digits for a configured number of digit slots
    task automatic verify_scan_sequence(
        input logic [31:0] seg_data,
        input logic [7:0]  dp,
        input logic [7:0]  digit_mask,
        input logic        seg_active_low,
        input logic        an_active_low,
        input int          refresh_div,
        input int          num_scans,
        input string       test_name
    );
        int enabled_digits [8];
        int num_enabled;
        int d;
        int effective_div;
        int slot;
        int cyc;
        int expected_digit;
        int slot_errors;
        logic [3:0] exp_nibble;
        logic [7:0] exp_seg_int;
        logic [7:0] exp_seg_o;
        logic [7:0] exp_an_o;
        int wait_cnt;
        bit timed_out;
        begin
            effective_div = (refresh_div <= 1) ? 1 : refresh_div;
            num_enabled = 0;
            for (d = 0; d < 8; d++) begin
                if (digit_mask[d]) begin
                    enabled_digits[num_enabled] = d;
                    num_enabled++;
                end
            end

            if (num_enabled == 0) begin
                // Should remain completely blanked
                slot_errors = 0;
                for (cyc = 0; cyc < 16; cyc++) begin
                    @(posedge clk);
                    #1;
                    exp_seg_o = seg_active_low ? 8'hFF : 8'h00;
                    exp_an_o  = an_active_low  ? 8'hFF : 8'h00;
                    if (seg_o !== exp_seg_o || an_o !== exp_an_o) begin
                        $display("  [FAIL] %s (blanked cycle %0d): seg_o=0x%02h (exp 0x%02h), an_o=0x%02h (exp 0x%02h)",
                                 test_name, cyc, seg_o, exp_seg_o, an_o, exp_an_o);
                        slot_errors++;
                    end
                end
                if (slot_errors == 0) begin
                    $display("  [PASS] %s: display remained blanked across 16 cycles", test_name);
                    pass_count++;
                end else begin
                    fail_count++;
                end
            end else begin
                // Sync to post-NBA stable window (+1ns after posedge) before sampling outputs
                @(posedge clk);
                #1;
                // Wait until the first enabled digit (enabled_digits[0]) starts cleanly
                // First wait until we are NOT on enabled_digits[0] (or if refresh_div==1 just sync to it)
                wait_cnt = 0;
                if (num_enabled > 1 && effective_div > 1) begin
                    while ((decode_active_digit(an_o, an_active_low) == enabled_digits[0]) &&
                           (wait_cnt <= 8 * effective_div + 10)) begin
                        @(posedge clk);
                        #1;
                        wait_cnt++;
                    end
                end
                wait_cnt = 0;
                timed_out = 1'b0;
                while ((decode_active_digit(an_o, an_active_low) != enabled_digits[0]) && !timed_out) begin
                    @(posedge clk);
                    #1;
                    wait_cnt++;
                    if (wait_cnt > 16 * effective_div + 20) begin
                        $display("  [FAIL] %s: timed out waiting for digit %0d (an_o=0x%02h)",
                                 test_name, enabled_digits[0], an_o);
                        fail_count++;
                        timed_out = 1'b1;
                    end
                end

                if (!timed_out) begin
                    // Now we are at cycle 0 of enabled_digits[0]
                    slot_errors = 0;
                    for (slot = 0; slot < num_scans * num_enabled; slot++) begin
                        expected_digit = enabled_digits[slot % num_enabled];
                        exp_nibble     = seg_data[expected_digit*4 +: 4];
                        exp_seg_int    = {dp[expected_digit], expected_seg7(exp_nibble)};
                        exp_seg_o      = seg_active_low ? ~exp_seg_int : exp_seg_int;
                        exp_an_o       = an_active_low  ? ~(8'h01 << expected_digit) : (8'h01 << expected_digit);

                        for (cyc = 0; cyc < effective_div; cyc++) begin
                            if (an_o !== exp_an_o || seg_o !== exp_seg_o) begin
                                $display("  [FAIL] %s slot=%0d (digit=%0d, nibble=0x%0h, cyc=%0d/%0d): got an=0x%02h seg=0x%02h, exp an=0x%02h seg=0x%02h",
                                         test_name, slot, expected_digit, exp_nibble, cyc, effective_div,
                                         an_o, seg_o, exp_an_o, exp_seg_o);
                                slot_errors++;
                            end
                            @(posedge clk);
                            #1;
                        end
                    end

                    if (slot_errors == 0) begin
                        $display("  [PASS] %s: verified %0d scan(s) x %0d digit(s) x %0d clk(s) (seg_act_low=%0b, an_act_low=%0b, mask=0x%02h, dp=0x%02h)",
                                 test_name, num_scans, num_enabled, effective_div, seg_active_low, an_active_low, digit_mask, dp);
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
            rst_n         = 1'b0;
            s_axi_awaddr  = '0;
            s_axi_awprot  = 3'b000;
            s_axi_awvalid = 1'b0;
            s_axi_wdata   = '0;
            s_axi_wstrb   = 4'h0;
            s_axi_wvalid  = 1'b0;
            s_axi_bready  = 1'b0;
            s_axi_araddr  = '0;
            s_axi_arprot  = 3'b000;
            s_axi_arvalid = 1'b0;
            s_axi_rready  = 1'b0;
            repeat (cycles) @(posedge clk);
            #1;
            rst_n = 1'b1;
            repeat (2) @(posedge clk);
            #1;
        end
    endtask

    // Main Test Sequence
    logic [31:0] rdata;
    initial begin
        $display("==================================================================");
        $display("  Starting Seven-Segment Controller Testbench (tb_axi_seg7)");
        $display("==================================================================");

        // ------------------------------------------------------------------
        // TEST 1: Reset Values & Blanked Default Outputs
        // ------------------------------------------------------------------
        $display("\n[TEST 1] Reset Values & Default Outputs");
        apply_reset(5);
        check_eq8(seg_o, 8'hFF, "Reset seg_o (EN=0, active-low)");
        check_eq8(an_o,  8'hFF, "Reset an_o  (EN=0, active-low)");

        axi_read(REG_SEG_DATA,        rdata); check_eq32(rdata, RST_SEG_DATA,        "Reset SEG_DATA");
        axi_read(REG_SEG_CTRL,        rdata); check_eq32(rdata, RST_SEG_CTRL,        "Reset SEG_CTRL");
        axi_read(REG_SEG_DP,          rdata); check_eq32(rdata, RST_SEG_DP,          "Reset SEG_DP");
        axi_read(REG_SEG_REFRESH_DIV, rdata); check_eq32(rdata, RST_SEG_REFRESH_DIV, "Reset SEG_REFRESH_DIV");

        // ------------------------------------------------------------------
        // TEST 2: Register R/W, Byte Strobes, Staggered AXI, Undefined Offsets
        // ------------------------------------------------------------------
        $display("\n[TEST 2] Register R/W, Byte Strobes & Undefined Register Accesses");
        axi_write(REG_SEG_DATA, 32'hAABB_CCDD, 4'hF);
        axi_read (REG_SEG_DATA, rdata);
        check_eq32(rdata, 32'hAABB_CCDD, "SEG_DATA full write/readback");

        // Byte-strobe partial write
        axi_write(REG_SEG_DATA, 32'h1122_3344, 4'b0101);
        axi_read (REG_SEG_DATA, rdata);
        check_eq32(rdata, 32'hAA22_CC44, "SEG_DATA WSTRB=4'b0101 partial write");

        // Staggered AWVALID before WVALID write
        axi_write_staggered(REG_SEG_DP, 32'h0000_005A);
        axi_read(REG_SEG_DP, rdata);
        check_eq32(rdata, 32'h0000_005A, "SEG_DP staggered AW/W write/readback");

        axi_write(REG_SEG_REFRESH_DIV, 32'h0000_0004, 4'hF);
        axi_read (REG_SEG_REFRESH_DIV, rdata);
        check_eq32(rdata, 32'h0000_0004, "SEG_REFRESH_DIV write/readback");

        // Undefined register writes ignored, reads return 0, valid registers preserved
        axi_write(REG_UNDEF_0, 32'hDEAD_BEEF, 4'hF);
        axi_write(REG_UNDEF_1, 32'hCAFE_BABE, 4'hF);
        axi_write(REG_UNDEF_2, 32'h1234_5678, 4'hF);

        axi_read(REG_UNDEF_0, rdata); check_eq32(rdata, 32'h0000_0000, "Undefined offset 0x010 read");
        axi_read(REG_UNDEF_1, rdata); check_eq32(rdata, 32'h0000_0000, "Undefined offset 0x014 read");
        axi_read(REG_UNDEF_2, rdata); check_eq32(rdata, 32'h0000_0000, "Undefined offset 0xFFC read");

        axi_read(REG_SEG_DATA,        rdata); check_eq32(rdata, 32'hAA22_CC44, "SEG_DATA intact after undefined writes");
        axi_read(REG_SEG_CTRL,        rdata); check_eq32(rdata, RST_SEG_CTRL,  "SEG_CTRL intact after undefined writes");
        axi_read(REG_SEG_DP,          rdata); check_eq32(rdata, 32'h0000_005A, "SEG_DP intact after undefined writes");
        axi_read(REG_SEG_REFRESH_DIV, rdata); check_eq32(rdata, 32'h0000_0004, "SEG_REFRESH_DIV intact after undefined writes");

        // ------------------------------------------------------------------
        // TEST 3: All 16 Hex Decoder Patterns (0..F) & All 8 Digit Positions
        // ------------------------------------------------------------------
        $display("\n[TEST 3] All 16 Hex Patterns (0x0..0xF) & All 8 Digit Positions");
        axi_write(REG_SEG_DP,          32'h0000_0000, 4'hF);
        axi_write(REG_SEG_REFRESH_DIV, 32'h0000_0004, 4'hF);

        // Pass A: Digits 0..7 = 0..7 (active-high seg & an, mask=0xFF, EN=1)
        axi_write(REG_SEG_DATA, 32'h7654_3210, 4'hF);
        axi_write(REG_SEG_CTRL, 32'h0000_FF01, 4'hF);
        verify_scan_sequence(32'h7654_3210, 8'h00, 8'hFF, 1'b0, 1'b0, 4, 2, "Hex 0..7 across digits 0..7");

        // Pass B: Digits 0..7 = 8..F
        axi_write(REG_SEG_DATA, 32'hFEDC_BA98, 4'hF);
        verify_scan_sequence(32'hFEDC_BA98, 8'h00, 8'hFF, 1'b0, 1'b0, 4, 2, "Hex 8..F across digits 0..7");

        // Edge refresh divider values: REFRESH_DIV = 1 and REFRESH_DIV = 0
        axi_write(REG_SEG_REFRESH_DIV, 32'h0000_0001, 4'hF);
        verify_scan_sequence(32'hFEDC_BA98, 8'h00, 8'hFF, 1'b0, 1'b0, 1, 2, "REFRESH_DIV=1 (1 clk/digit)");

        axi_write(REG_SEG_REFRESH_DIV, 32'h0000_0000, 4'hF);
        verify_scan_sequence(32'hFEDC_BA98, 8'h00, 8'hFF, 1'b0, 1'b0, 0, 2, "REFRESH_DIV=0 (1 clk/digit)");

        // ------------------------------------------------------------------
        // TEST 4: Decimal-Point Control
        // ------------------------------------------------------------------
        $display("\n[TEST 4] Decimal-Point Control");
        axi_write(REG_SEG_REFRESH_DIV, 32'h0000_0003, 4'hF);
        axi_write(REG_SEG_DATA,        32'hCAFE_BABE, 4'hF);
        axi_write(REG_SEG_DP,          32'h0000_00A5, 4'hF);
        axi_write(REG_SEG_CTRL,        32'h0000_FF01, 4'hF);
        verify_scan_sequence(32'hCAFE_BABE, 8'hA5, 8'hFF, 1'b0, 1'b0, 3, 2, "DP pattern 0xA5");

        axi_write(REG_SEG_DP,          32'h0000_00FF, 4'hF);
        verify_scan_sequence(32'hCAFE_BABE, 8'hFF, 8'hFF, 1'b0, 1'b0, 3, 1, "DP pattern 0xFF (all on)");

        // ------------------------------------------------------------------
        // TEST 5: Digit Masking & Enable/Blanking Control
        // ------------------------------------------------------------------
        $display("\n[TEST 5] Digit Masking & Display Enable Blanking");
        axi_write(REG_SEG_DATA,        32'hF7E6_D5C4, 4'hF);
        axi_write(REG_SEG_DP,          32'h0000_005A, 4'hF);
        axi_write(REG_SEG_REFRESH_DIV, 32'h0000_0004, 4'hF);

        // Partial mask: 0x5A (digits 1, 3, 4, 6 enabled; 0, 2, 5, 7 masked)
        // Start from EN=0 first so digit_idx_q resets cleanly to 0, then enable with mask[0]=0
        axi_write(REG_SEG_CTRL, 32'h0000_5A00, 4'hF);
        axi_write(REG_SEG_CTRL, 32'h0000_5A01, 4'hF);
        @(posedge clk); #1; // Allow 1 cycle to skip masked digit 0 -> digit 1
        verify_scan_sequence(32'hF7E6_D5C4, 8'h5A, 8'h5A, 1'b0, 1'b0, 4, 3, "Partial digit mask 0x5A");

        // Single-digit mask: 0x08 (only digit 3)
        axi_write(REG_SEG_CTRL, 32'h0000_0801, 4'hF);
        @(posedge clk); #1;
        verify_scan_sequence(32'hF7E6_D5C4, 8'h5A, 8'h08, 1'b0, 1'b0, 4, 2, "Single digit mask 0x08");

        // All digits masked (DIGIT_MASK=0x00, EN=1) -> blanked
        axi_write(REG_SEG_CTRL, 32'h0000_0001, 4'hF);
        verify_scan_sequence(32'hF7E6_D5C4, 8'h5A, 8'h00, 1'b0, 1'b0, 4, 1, "All digits masked (mask=0x00, EN=1)");

        // Display disabled (EN=0, DIGIT_MASK=0xFF) -> blanked
        axi_write(REG_SEG_CTRL, 32'h0000_FF00, 4'hF);
        verify_scan_sequence(32'hF7E6_D5C4, 8'h5A, 8'h00, 1'b0, 1'b0, 4, 1, "Display disabled (EN=0, mask=0xFF)");

        // ------------------------------------------------------------------
        // TEST 6: Active-High and Active-Low Polarity Configurations
        // ------------------------------------------------------------------
        $display("\n[TEST 6] Active-High & Active-Low Polarity Configurations");
        axi_write(REG_SEG_DATA,        32'h7654_3210, 4'hF);
        axi_write(REG_SEG_DP,          32'h0000_0055, 4'hF);
        axi_write(REG_SEG_REFRESH_DIV, 32'h0000_0003, 4'hF);

        // 1) seg=active-high, an=active-high
        axi_write(REG_SEG_CTRL, 32'h0000_FF01, 4'hF);
        verify_scan_sequence(32'h7654_3210, 8'h55, 8'hFF, 1'b0, 1'b0, 3, 1, "Polarity seg=AH, an=AH");

        // 2) seg=active-low, an=active-high
        axi_write(REG_SEG_CTRL, 32'h0000_FF03, 4'hF);
        verify_scan_sequence(32'h7654_3210, 8'h55, 8'hFF, 1'b1, 1'b0, 3, 1, "Polarity seg=AL, an=AH");

        // 3) seg=active-high, an=active-low
        axi_write(REG_SEG_CTRL, 32'h0000_FF05, 4'hF);
        verify_scan_sequence(32'h7654_3210, 8'h55, 8'hFF, 1'b0, 1'b1, 3, 1, "Polarity seg=AH, an=AL");

        // 4) seg=active-low, an=active-low
        axi_write(REG_SEG_CTRL, 32'h0000_FF07, 4'hF);
        verify_scan_sequence(32'h7654_3210, 8'h55, 8'hFF, 1'b1, 1'b1, 3, 1, "Polarity seg=AL, an=AL");

        // Verify blanked polarity (EN=0) for mixed polarities
        axi_write(REG_SEG_CTRL, 32'h0000_FF02, 4'hF); // seg=AL, an=AH
        @(posedge clk); #1;
        check_eq8(seg_o, 8'hFF, "Blanked seg_o when seg_active_low=1");
        check_eq8(an_o,  8'h00, "Blanked an_o  when an_active_low=0");

        axi_write(REG_SEG_CTRL, 32'h0000_FF04, 4'hF); // seg=AH, an=AL
        @(posedge clk); #1;
        check_eq8(seg_o, 8'h00, "Blanked seg_o when seg_active_low=0");
        check_eq8(an_o,  8'hFF, "Blanked an_o  when an_active_low=1");

        // ------------------------------------------------------------------
        // TEST 7: Mid-Operation Reset Recovery
        // ------------------------------------------------------------------
        $display("\n[TEST 7] Mid-Operation Reset Recovery");
        axi_write(REG_SEG_CTRL, 32'h0000_FF01, 4'hF);
        repeat (5) @(posedge clk);
        apply_reset(5);
        check_eq8(seg_o, 8'hFF, "Post-reset seg_o");
        check_eq8(an_o,  8'hFF, "Post-reset an_o");
        axi_read(REG_SEG_DATA,        rdata); check_eq32(rdata, RST_SEG_DATA,        "Post-reset SEG_DATA");
        axi_read(REG_SEG_CTRL,        rdata); check_eq32(rdata, RST_SEG_CTRL,        "Post-reset SEG_CTRL");
        axi_read(REG_SEG_DP,          rdata); check_eq32(rdata, RST_SEG_DP,          "Post-reset SEG_DP");
        axi_read(REG_SEG_REFRESH_DIV, rdata); check_eq32(rdata, RST_SEG_REFRESH_DIV, "Post-reset SEG_REFRESH_DIV");

        // ------------------------------------------------------------------
        // Summary
        // ------------------------------------------------------------------
        $display("\n==================================================================");
        $display("  tb_axi_seg7 Summary: PASS=%0d, FAIL=%0d", pass_count, fail_count);
        if (fail_count == 0) begin
            $display("  OVERALL RESULT: PASS");
            $display("==================================================================");
            $finish;
        end else begin
            $display("  OVERALL RESULT: FAIL");
            $display("==================================================================");
            $fatal(1, "tb_axi_seg7 failed with %0d error(s)", fail_count);
        end
    end

endmodule
