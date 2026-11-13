`timescale 1ns/1ps

`include "axi_spi_defines.vh"
`include "axi_spi.vh"

module tb_axi_spi;

    localparam integer DATA_WIDTH = `_AXI_SPI_DATA_WIDTH_;
    localparam integer ADDR_WIDTH = `_AXI_SPI_ADDR_WIDTH_;
    localparam integer STRB_WIDTH = DATA_WIDTH / 8;
    localparam integer ID_WIDTH   = `_AXI_SPI_ID_WIDTH_;
    localparam integer CLK_PERIOD = 10; // 100 MHz
    localparam integer AXI_TIMEOUT_CYCLES = 200;
    localparam integer SPI_TIMEOUT_CYCLES = 20000;
    localparam integer SIM_TIMEOUT_CYCLES = 100000;

    // Register Offsets
    localparam [ADDR_WIDTH-1:0] REG_GIER = `_SPI_GIER_;
    localparam [ADDR_WIDTH-1:0] REG_ISR  = `_SPI_ISR_;
    localparam [ADDR_WIDTH-1:0] REG_IER  = `_SPI_IER_;
    localparam [ADDR_WIDTH-1:0] REG_RCLK = `_SPI_RCLK_;
    localparam [ADDR_WIDTH-1:0] REG_SRR  = `_SPI_SRR_;
    localparam [ADDR_WIDTH-1:0] REG_CR   = `_SPI_CR_;
    localparam [ADDR_WIDTH-1:0] REG_SR   = `_SPI_SR_;
    localparam [ADDR_WIDTH-1:0] REG_DTR  = `_SPI_DTR_;
    localparam [ADDR_WIDTH-1:0] REG_DRR  = `_SPI_DRR_;
    localparam [ADDR_WIDTH-1:0] REG_SSR  = `_SPI_SSR_;
    localparam [ADDR_WIDTH-1:0] REG_TFOR = `_SPI_TFOR_;
    localparam [ADDR_WIDTH-1:0] REG_RFOR = `_SPI_RFOR_;

    // Reset Defaults
    localparam [31:0] RST_CR   = `_SPI_CR_INIT_;
    localparam [31:0] RST_SSR  = `_SPI_SSR_INIT_;
    localparam [31:0] RST_GIER = `_SPI_GIER_INIT_;
    localparam [31:0] RST_ISR  = `_SPI_ISR_INIT_;
    localparam [31:0] RST_IER  = `_SPI_IER_INIT_;
    localparam [31:0] RST_SR   = 32'h0000_0005; // RX_EMPTY=1, TX_EMPTY=1 from axi_spi_ctrl

    // Clock & Reset
    logic clk;
    logic axi_aresetn_i;

    // AXI4-Lite Interface Signals
    logic [ID_WIDTH-1:0]   axi_arid_i;
    logic [ADDR_WIDTH-1:0] axi_araddr_i;
    logic                  axi_arvalid_i;
    logic                  axi_arready_o;
    logic [ID_WIDTH-1:0]   axi_rid_o;
    logic [DATA_WIDTH-1:0] axi_rdata_o;
    logic [1:0]            axi_rresp_o;
    logic                  axi_rvalid_o;
    logic                  axi_rready_i;

    logic [ID_WIDTH-1:0]   axi_awid_i;
    logic [ADDR_WIDTH-1:0] axi_awaddr_i;
    logic                  axi_awvalid_i;
    logic                  axi_awready_o;
    logic [DATA_WIDTH-1:0] axi_wdata_i;
    logic [STRB_WIDTH-1:0] axi_wstrb_i;
    logic                  axi_wvalid_i;
    logic                  axi_wready_o;
    logic [ID_WIDTH-1:0]   axi_bid_o;
    logic [1:0]            axi_bresp_o;
    logic                  axi_bvalid_o;
    logic                  axi_bready_i;

    // SPI Interface Signals
    logic spi_clk_o;
    logic spi_cs_n_o;
    logic spi_mosi_o;
    logic spi_miso_i;

    // Counters
    int pass_count  = 0;
    int fail_count  = 0;
    int cycle_count = 0;

    // DUT Instantiation
    axi_spi_top dut (
        .fixed_clk_i   (clk),
        .axi_aclk_i    (clk),
        .axi_aresetn_i (axi_aresetn_i),
        .axi_arid_i    (axi_arid_i),
        .axi_araddr_i  (axi_araddr_i),
        .axi_arvalid_i (axi_arvalid_i),
        .axi_arready_o (axi_arready_o),
        .axi_rid_o     (axi_rid_o),
        .axi_rdata_o   (axi_rdata_o),
        .axi_rresp_o   (axi_rresp_o),
        .axi_rvalid_o  (axi_rvalid_o),
        .axi_rready_i  (axi_rready_i),
        .axi_awid_i    (axi_awid_i),
        .axi_awaddr_i  (axi_awaddr_i),
        .axi_awvalid_i (axi_awvalid_i),
        .axi_awready_o (axi_awready_o),
        .axi_wdata_i   (axi_wdata_i),
        .axi_wstrb_i   (axi_wstrb_i),
        .axi_wvalid_i  (axi_wvalid_i),
        .axi_wready_o  (axi_wready_o),
        .axi_bid_o     (axi_bid_o),
        .axi_bresp_o   (axi_bresp_o),
        .axi_bvalid_o  (axi_bvalid_o),
        .axi_bready_i  (axi_bready_i),
        .spi_clk_o     (spi_clk_o),
        .spi_cs_n_o    (spi_cs_n_o),
        .spi_mosi_o    (spi_mosi_o),
        .spi_miso_i    (spi_miso_i)
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
            $fatal(1, "Simulation timeout reached in tb_axi_spi");
        end
    end

    // Check Helpers
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

    task automatic check_eq1(
        input logic  actual,
        input logic  expected,
        input string label
    );
        if (actual === expected) begin
            $display("  [PASS] %s: actual=%b == expected=%b", label, actual, expected);
            pass_count++;
        end else begin
            $display("  [FAIL] %s: actual=%b != expected=%b", label, actual, expected);
            fail_count++;
        end
    endtask

    // AXI4-Lite Write Task
    // Note: axi_spi_top asserts awready/wready/bvalid simultaneously while awvalid&wvalid are high.
    // Sampling all three in the same posedge loop cleanly captures BRESP/BID and leaves >=1 idle cycle.
    task automatic axi_write(
        input logic [ADDR_WIDTH-1:0] addr,
        input logic [31:0]           data,
        input logic [3:0]            strb = 4'hF,
        input logic [ID_WIDTH-1:0]   wid  = 12'h101
    );
        bit aw_done;
        bit w_done;
        bit b_done;
        int wait_cycles;
        logic [1:0]          resp;
        logic [ID_WIDTH-1:0] bid;
        begin
            @(posedge clk);
            axi_awid_i    <= wid;
            axi_awaddr_i  <= addr;
            axi_awvalid_i <= 1'b1;
            axi_wdata_i   <= data;
            axi_wstrb_i   <= strb;
            axi_wvalid_i  <= 1'b1;
            axi_bready_i  <= 1'b1;

            aw_done = 1'b0;
            w_done  = 1'b0;
            b_done  = 1'b0;
            wait_cycles = 0;

            while (!(aw_done && w_done && b_done)) begin
                @(posedge clk);
                wait_cycles++;
                if (wait_cycles > AXI_TIMEOUT_CYCLES) begin
                    $display("  [FAIL] AXI Write timeout at addr=0x%02h", addr);
                    fail_count++;
                    axi_awvalid_i <= 1'b0;
                    axi_wvalid_i  <= 1'b0;
                    axi_bready_i  <= 1'b0;
                    resp = 2'b00;
                    bid  = wid;
                    aw_done = 1'b1;
                    w_done  = 1'b1;
                    b_done  = 1'b1;
                end else begin
                    if (axi_awvalid_i && axi_awready_o) begin
                        axi_awvalid_i <= 1'b0;
                        aw_done = 1'b1;
                    end
                    if (axi_wvalid_i && axi_wready_o) begin
                        axi_wvalid_i <= 1'b0;
                        w_done = 1'b1;
                    end
                    if (axi_bvalid_o && axi_bready_i) begin
                        resp = axi_bresp_o;
                        bid  = axi_bid_o;
                        b_done = 1'b1;
                        axi_bready_i <= 1'b0;
                    end
                end
            end

            if (resp !== 2'b00) begin
                $display("  [FAIL] AXI Write BRESP != OKAY (0x%0h) at addr=0x%02h", resp, addr);
                fail_count++;
            end
            if (bid !== wid) begin
                $display("  [FAIL] AXI Write BID mismatch (got 0x%03h, exp 0x%03h) at addr=0x%02h", bid, wid, addr);
                fail_count++;
            end
        end
    endtask

    // AXI4-Lite Read Task
    task automatic axi_read(
        input  logic [ADDR_WIDTH-1:0] addr,
        output logic [31:0]           data,
        input  logic [ID_WIDTH-1:0]   rid_in = 12'h202
    );
        bit ar_done;
        bit r_done;
        int wait_cycles;
        logic [1:0]          resp;
        logic [ID_WIDTH-1:0] rid_out;
        begin
            @(posedge clk);
            axi_arid_i    <= rid_in;
            axi_araddr_i  <= addr;
            axi_arvalid_i <= 1'b1;
            axi_rready_i  <= 1'b1;

            ar_done = 1'b0;
            r_done  = 1'b0;
            wait_cycles = 0;

            while (!(ar_done && r_done)) begin
                @(posedge clk);
                wait_cycles++;
                if (wait_cycles > AXI_TIMEOUT_CYCLES) begin
                    $display("  [FAIL] AXI Read timeout at addr=0x%02h", addr);
                    fail_count++;
                    data    = 32'hXXXX_XXXX;
                    resp    = 2'b00;
                    rid_out = rid_in;
                    axi_arvalid_i <= 1'b0;
                    axi_rready_i  <= 1'b0;
                    ar_done = 1'b1;
                    r_done  = 1'b1;
                end else begin
                    if (axi_arvalid_i && axi_arready_o) begin
                        axi_arvalid_i <= 1'b0;
                        ar_done = 1'b1;
                    end
                    if (axi_rvalid_o && axi_rready_i) begin
                        data    = axi_rdata_o;
                        resp    = axi_rresp_o;
                        rid_out = axi_rid_o;
                        r_done  = 1'b1;
                        axi_rready_i <= 1'b0;
                    end
                end
            end

            if (resp !== 2'b00) begin
                $display("  [FAIL] AXI Read RRESP != OKAY (0x%0h) at addr=0x%02h", resp, addr);
                fail_count++;
            end
            if (rid_out !== rid_in) begin
                $display("  [FAIL] AXI Read RID mismatch (got 0x%03h, exp 0x%03h) at addr=0x%02h", rid_out, rid_in, addr);
                fail_count++;
            end
        end
    endtask

    // Reset Helper
    task automatic apply_reset(input int cycles);
        begin
            axi_aresetn_i = 1'b0;
            axi_arid_i    = '0;
            axi_araddr_i  = '0;
            axi_arvalid_i = 1'b0;
            axi_rready_i  = 1'b0;
            axi_awid_i    = '0;
            axi_awaddr_i  = '0;
            axi_awvalid_i = 1'b0;
            axi_wdata_i   = '0;
            axi_wstrb_i   = 4'h0;
            axi_wvalid_i  = 1'b0;
            axi_bready_i  = 1'b0;
            spi_miso_i    = 1'b0;
            repeat (cycles) @(posedge clk);
            #1;
            axi_aresetn_i = 1'b1;
            repeat (3) @(posedge clk);
            #1;
        end
    endtask

    // Execute and Verify Single Full-Duplex SPI Mode 0 (CPOL=0, CPHA=0) Byte Transfer
    task automatic run_and_verify_spi_byte(
        input logic [7:0] tx_byte,
        input logic [7:0] miso_byte,
        input bit         lsb_first,
        input int         rclk_ratio,
        input string      label
    );
        logic [7:0] captured_mosi;
        logic [31:0] sr_val;
        logic [31:0] drr_val;
        logic [31:0] tfor_val;
        logic [31:0] rfor_val;
        int exp_half_period;
        int posedge_cnt;
        int negedge_cnt;
        int high_cnt;
        int low_cnt;
        int bit_idx;
        int wait_cyc;
        bit prev_sclk;
        bit timing_err;
        bit cs_err;
        bit mon_done;
        bit axi_done;
        bit poll_done;
        int quiet_cnt;
        int quiet_target;
        begin
            exp_half_period = (1 << rclk_ratio);
            quiet_target    = 2 * exp_half_period + 6;
            captured_mosi   = 8'h00;
            posedge_cnt     = 0;
            negedge_cnt     = 0;
            high_cnt        = 0;
            low_cnt         = 0;
            timing_err      = 1'b0;
            cs_err          = 1'b0;
            mon_done        = 1'b0;
            axi_done        = 1'b0;

            // Pre-transfer idle check: SCLK must idle LOW (CPOL=0) and CS_N must be LOW
            if (spi_clk_o !== 1'b0) begin
                $display("  [FAIL] %s: spi_clk_o not idle LOW before transfer (%b)", label, spi_clk_o);
                fail_count++;
            end
            if (spi_cs_n_o !== 1'b0) begin
                $display("  [FAIL] %s: spi_cs_n_o not asserted LOW before transfer (%b)", label, spi_cs_n_o);
                fail_count++;
            end

            // Present first MISO bit before first rising SCLK edge (Mode 0, CPHA=0)
            spi_miso_i = lsb_first ? miso_byte[0] : miso_byte[7];

            fork
                // Thread 1: AXI writes DTR, waits for TX_EMPTY & RX_NOT_EMPTY, checks TFOR/RFOR & reads DRR
                begin
                    axi_write(REG_DTR, {24'h000000, tx_byte}, 4'hF, 12'h301);

                    poll_done = 1'b0;
                    wait_cyc  = 0;
                    while (!poll_done) begin
                        axi_read(REG_SR, sr_val, 12'h302);
                        if ((sr_val[`_SR_TX_EMPTY_BIT_] == 1'b1) && (sr_val[`_SR_RX_EMPTY_BIT_] == 1'b0)) begin
                            poll_done = 1'b1;
                        end else begin
                            wait_cyc++;
                            if (wait_cyc > SPI_TIMEOUT_CYCLES / 2) begin
                                $display("  [FAIL] %s: timeout polling SPI_SR (SR=0x%08h)", label, sr_val);
                                fail_count++;
                                poll_done = 1'b1;
                            end
                        end
                    end

                    axi_read(REG_TFOR, tfor_val, 12'h303);
                    axi_read(REG_RFOR, rfor_val, 12'h304);
                    check_eq32(tfor_val, 32'd0, {label, " TFOR after transfer"});
                    check_eq32(rfor_val, 32'd1, {label, " RFOR before DRR read"});

                    axi_read(REG_DRR, drr_val, 12'h305);
                    check_eq8(drr_val[7:0], miso_byte, {label, " DRR MISO readback"});

                    axi_read(REG_SR, sr_val, 12'h306);
                    axi_read(REG_RFOR, rfor_val, 12'h307);
                    check_eq1(sr_val[`_SR_RX_EMPTY_BIT_], 1'b1, {label, " SR.RX_EMPTY after DRR read"});
                    check_eq32(rfor_val, 32'd0, {label, " RFOR after DRR read"});
                    axi_done = 1'b1;
                end

                // Thread 2: Cycle-accurate SPI physical bus monitor & slave MISO shifter
                begin
                    prev_sclk = spi_clk_o;
                    wait_cyc  = 0;
                    quiet_cnt = 0;

                    while (!mon_done) begin
                        @(posedge clk);
                        #1;
                        wait_cyc++;

                        if (wait_cyc > SPI_TIMEOUT_CYCLES) begin
                            $display("  [FAIL] %s: SPI bus monitor timeout (pos=%0d, neg=%0d)", label, posedge_cnt, negedge_cnt);
                            fail_count++;
                            mon_done = 1'b1;
                        end else begin
                            if (posedge_cnt > 0 && negedge_cnt < 8 && spi_cs_n_o !== 1'b0) begin
                                cs_err = 1'b1;
                            end

                            // Detect SCLK rising edge
                            if (prev_sclk === 1'b0 && spi_clk_o === 1'b1) begin
                                posedge_cnt++;
                                if (posedge_cnt <= 8) begin
                                    bit_idx = lsb_first ? (posedge_cnt - 1) : (8 - posedge_cnt);
                                    captured_mosi[bit_idx] = spi_mosi_o;
                                    if (posedge_cnt > 1 && low_cnt != exp_half_period) begin
                                        $display("  [FAIL] %s: SCLK low width=%0d clocks (exp %0d) before edge %0d",
                                                 label, low_cnt, exp_half_period, posedge_cnt);
                                        timing_err = 1'b1;
                                    end
                                end else begin
                                    $display("  [FAIL] %s: Spurious SCLK rising edge #%0d observed!", label, posedge_cnt);
                                    timing_err = 1'b1;
                                end
                                high_cnt = 1;
                                low_cnt  = 0;
                                quiet_cnt = 0;
                            end
                            // Detect SCLK falling edge
                            else if (prev_sclk === 1'b1 && spi_clk_o === 1'b0) begin
                                negedge_cnt++;
                                if (high_cnt != exp_half_period) begin
                                    $display("  [FAIL] %s: SCLK high width=%0d clocks (exp %0d) at pulse %0d",
                                             label, high_cnt, exp_half_period, negedge_cnt);
                                    timing_err = 1'b1;
                                end
                                // Drive next MISO bit on falling edge (CPHA=0)
                                if (negedge_cnt < 8) begin
                                    bit_idx = lsb_first ? negedge_cnt : (7 - negedge_cnt);
                                    spi_miso_i = miso_byte[bit_idx];
                                end else begin
                                    spi_miso_i = 1'b0;
                                end
                                low_cnt  = 1;
                                high_cnt = 0;
                                quiet_cnt = 0;
                            end
                            // Between edges
                            else begin
                                if (spi_clk_o === 1'b1) high_cnt++;
                                else                    low_cnt++;

                                if (negedge_cnt == 8 && posedge_cnt == 8) begin
                                    quiet_cnt++;
                                    if (quiet_cnt >= quiet_target && axi_done) begin
                                        mon_done = 1'b1;
                                    end
                                end
                            end
                            prev_sclk = spi_clk_o;
                        end
                    end
                end
            join

            check_eq8(captured_mosi, tx_byte, {label, " MOSI physical waveform"});
            if (posedge_cnt == 8 && negedge_cnt == 8 && !timing_err && !cs_err) begin
                $display("  [PASS] %s: SCLK=8 pulses (half_period=%0d clks, CPOL=0/CPHA=0, lsb=%0b), CS_N stayed LOW",
                         label, exp_half_period, lsb_first);
                pass_count++;
            end else begin
                $display("  [FAIL] %s: SCLK/CS check failed (pos=%0d, neg=%0d, timing_err=%0b, cs_err=%0b)",
                         label, posedge_cnt, negedge_cnt, timing_err, cs_err);
                fail_count++;
            end
            check_eq1(spi_mosi_o, 1'b1, {label, " MOSI idle HIGH after transfer"});
        end
    endtask

    // Main Test Sequence
    logic [31:0] rdata;
    initial begin
        $display("==================================================================");
        $display("  Starting AXI SPI Master Testbench (tb_axi_spi)");
        $display("==================================================================");

        // ------------------------------------------------------------------
        // TEST 1: Hardware Reset State & Default Register Values
        // ------------------------------------------------------------------
        $display("\n[TEST 1] Hardware Reset State & Default Register Values");
        apply_reset(6);

        check_eq1(spi_cs_n_o, 1'b1, "Reset spi_cs_n_o (deselected HIGH)");
        check_eq1(spi_clk_o,  1'b0, "Reset spi_clk_o  (idle LOW)");
        check_eq1(spi_mosi_o, 1'b1, "Reset spi_mosi_o (idle HIGH)");

        axi_read(REG_CR,   rdata); check_eq32(rdata, RST_CR,   "Reset SPI_CR");
        axi_read(REG_SR,   rdata); check_eq32(rdata, RST_SR,   "Reset SPI_SR (RX_EMPTY=1, TX_EMPTY=1)");
        axi_read(REG_SSR,  rdata); check_eq32(rdata, RST_SSR,  "Reset SPI_SSR");
        axi_read(REG_TFOR, rdata); check_eq32(rdata, 32'd0,    "Reset SPI_TFOR");
        axi_read(REG_RFOR, rdata); check_eq32(rdata, 32'd0,    "Reset SPI_RFOR");
        axi_read(REG_GIER, rdata); check_eq32(rdata, RST_GIER, "Reset SPI_GIER");
        axi_read(REG_ISR,  rdata); check_eq32(rdata, RST_ISR,  "Reset SPI_ISR");
        axi_read(REG_IER,  rdata); check_eq32(rdata, RST_IER,  "Reset SPI_IER");

        // Unmapped / write-only read check (returns 32'h61626364 per axi_spi_top)
        axi_read(7'h00,    rdata); check_eq32(rdata, 32'h61626364, "Unmapped addr 0x00 default read");
        axi_read(REG_RCLK, rdata); check_eq32(rdata, 32'h61626364, "WO SPI_RCLK read returns default");

        // ------------------------------------------------------------------
        // TEST 2: Register Access & Chip-Select (SPI_SSR -> spi_cs_n_o)
        // ------------------------------------------------------------------
        $display("\n[TEST 2] Register R/W & Chip-Select (SPI_SSR) Control");
        axi_write(REG_GIER, 32'h8000_0000);
        axi_read (REG_GIER, rdata); check_eq32(rdata, 32'h8000_0000, "SPI_GIER R/W");

        axi_write(REG_IER,  32'h0000_00AA);
        axi_read (REG_IER,  rdata); check_eq32(rdata, 32'h0000_00AA, "SPI_IER R/W");

        // SPI_ISR toggles on write (ISR_next = ISR ^ write_data)
        axi_write(REG_ISR,  32'h0000_0055);
        axi_read (REG_ISR,  rdata); check_eq32(rdata, 32'h0000_0055, "SPI_ISR toggle 0 -> 0x55");
        axi_write(REG_ISR,  32'h0000_0055);
        axi_read (REG_ISR,  rdata); check_eq32(rdata, 32'h0000_0000, "SPI_ISR toggle 0x55 -> 0x00");

        // Chip-select pin behavior via SPI_SSR[0]
        axi_write(REG_SSR, 32'hFFFF_FFFE);
        @(posedge clk); #1;
        check_eq1(spi_cs_n_o, 1'b0, "CS_N asserted LOW when SSR=0xFFFFFFFE");
        axi_read (REG_SSR, rdata); check_eq32(rdata, 32'hFFFF_FFFE, "SPI_SSR readback 0xFFFFFFFE");

        axi_write(REG_SSR, 32'hFFFF_FFFD); // bit 0 = 1, bit 1 = 0 -> spi_cs_n_o must stay 1
        @(posedge clk); #1;
        check_eq1(spi_cs_n_o, 1'b1, "CS_N deasserted HIGH when SSR[0]=1 (0xFFFFFFFD)");

        axi_write(REG_SSR, 32'hFFFF_FFFF);
        @(posedge clk); #1;
        check_eq1(spi_cs_n_o, 1'b1, "CS_N deasserted HIGH when SSR=0xFFFFFFFF");

        // ------------------------------------------------------------------
        // TEST 3: Supported SPI Mode 0 (CPOL=0, CPHA=0) - MSB-First & RCLK Ratios
        // ------------------------------------------------------------------
        $display("\n[TEST 3] SPI Mode 0 (CPOL=0, CPHA=0) MSB-First & Clock Ratios");
        $display("  [INFO] axi_spi_ctrl ignores control_cpol_i/control_cpha_i/control_spi_enable_i;");
        $display("         hardware supports Mode 0 (CPOL=0, CPHA=0) with MSB-first & LSB-first.");

        // Configure Master=1, SPE=1, Manual SS=1, LSB_FIRST=0 -> 0x0000_0086
        axi_write(REG_CR, 32'h0000_0086);
        axi_read (REG_CR, rdata); check_eq32(rdata, 32'h0000_0086, "SPI_CR configured 0x00000086");
        axi_read (REG_SR, rdata);
        check_eq1(rdata[`_SR_SMOD_SEL_BIT_], 1'b1, "SPI_SR.SMOD_SEL reflects Master=1");

        // Assert CS_N LOW
        axi_write(REG_SSR, 32'hFFFF_FFFE);
        @(posedge clk); #1;

        // Ratio 1 (1/4 clock)
        axi_write(REG_RCLK, 32'd1);
        run_and_verify_spi_byte(8'hA5, 8'h5A, 1'b0, 1, "Mode0 MSB RCLK=1 (0xA5/0x5A)");

        // Ratio 2 (1/8 clock)
        axi_write(REG_RCLK, 32'd2);
        run_and_verify_spi_byte(8'h3C, 8'hC3, 1'b0, 2, "Mode0 MSB RCLK=2 (0x3C/0xC3)");
        run_and_verify_spi_byte(8'hF0, 8'h0F, 1'b0, 2, "Mode0 MSB RCLK=2 (0xF0/0x0F)");
        run_and_verify_spi_byte(8'h00, 8'hFF, 1'b0, 2, "Mode0 MSB RCLK=2 (0x00/0xFF)");

        // Ratio 3 (1/16 clock)
        axi_write(REG_RCLK, 32'd3);
        run_and_verify_spi_byte(8'h81, 8'h42, 1'b0, 3, "Mode0 MSB RCLK=3 (0x81/0x42)");

        // ------------------------------------------------------------------
        // TEST 4: Supported SPI Mode 0 (CPOL=0, CPHA=0) - LSB-First (CR[9]=1)
        // ------------------------------------------------------------------
        $display("\n[TEST 4] SPI Mode 0 (CPOL=0, CPHA=0) LSB-First Mode (CR[9]=1)");
        axi_write(REG_RCLK, 32'd2);
        axi_write(REG_CR, 32'h0000_0286); // bit 9 (LSB_FIRST) = 1
        axi_read (REG_CR, rdata); check_eq32(rdata, 32'h0000_0286, "SPI_CR LSB-first 0x00000286");

        run_and_verify_spi_byte(8'hA5, 8'h3C, 1'b1, 2, "Mode0 LSB RCLK=2 (0xA5/0x3C)");
        run_and_verify_spi_byte(8'h81, 8'h12, 1'b1, 2, "Mode0 LSB RCLK=2 (0x81/0x12)");

        // Restore MSB-first
        axi_write(REG_CR, 32'h0000_0086);

        // ------------------------------------------------------------------
        // TEST 5: Multi-Byte Queued FIFO Transaction & Completion Status
        // ------------------------------------------------------------------
        $display("\n[TEST 5] Multi-Byte Queued FIFO Transfer & Completion");
        begin : multi_byte_blk
            logic [7:0] tx_seq   [0:3];
            logic [7:0] miso_seq [0:3];
            logic [7:0] rx_cap   [0:3];
            int byte_idx;
            int bit_idx;
            int pulse_cnt;
            int neg_cnt;
            int wait_cyc;
            bit prev_sclk;
            bit mon_done;
            bit axi_done;
            bit poll_done;
            logic [31:0] sr_val;
            logic [31:0] tfor_val;
            logic [31:0] rfor_val;

            tx_seq[0]   = 8'h11; tx_seq[1]   = 8'h22; tx_seq[2]   = 8'h33; tx_seq[3]   = 8'h44;
            miso_seq[0] = 8'hA1; miso_seq[1] = 8'hB2; miso_seq[2] = 8'hC3; miso_seq[3] = 8'hD4;
            rx_cap[0]   = 8'h00; rx_cap[1]   = 8'h00; rx_cap[2]   = 8'h00; rx_cap[3]   = 8'h00;

            axi_write(REG_RCLK, 32'd2);
            spi_miso_i = miso_seq[0][7];

            pulse_cnt = 0;
            neg_cnt   = 0;
            mon_done  = 1'b0;
            axi_done  = 1'b0;

            fork
                // AXI writes 4 bytes into TX FIFO, then waits for completion
                begin
                    axi_write(REG_DTR, {24'h0, tx_seq[0]}, 4'hF, 12'h401);
                    axi_write(REG_DTR, {24'h0, tx_seq[1]}, 4'hF, 12'h402);
                    axi_write(REG_DTR, {24'h0, tx_seq[2]}, 4'hF, 12'h403);
                    axi_write(REG_DTR, {24'h0, tx_seq[3]}, 4'hF, 12'h404);

                    poll_done = 1'b0;
                    wait_cyc  = 0;
                    while (!poll_done) begin
                        axi_read(REG_SR,   sr_val,   12'h405);
                        axi_read(REG_RFOR, rfor_val, 12'h406);
                        if ((sr_val[`_SR_TX_EMPTY_BIT_] == 1'b1) && (rfor_val == 32'd4)) begin
                            poll_done = 1'b1;
                        end else begin
                            wait_cyc++;
                            if (wait_cyc > SPI_TIMEOUT_CYCLES / 2) begin
                                $display("  [FAIL] Multi-byte timeout polling SR=0x%08h RFOR=%0d", sr_val, rfor_val);
                                fail_count++;
                                poll_done = 1'b1;
                            end
                        end
                    end

                    axi_read(REG_TFOR, tfor_val, 12'h407);
                    check_eq32(tfor_val, 32'd0, "Multi-byte TFOR after all 4 bytes");
                    check_eq32(rfor_val, 32'd4, "Multi-byte RFOR before reading DRR");

                    axi_read(REG_DRR, rdata, 12'h410); check_eq8(rdata[7:0], miso_seq[0], "Multi-byte DRR[0]");
                    axi_read(REG_DRR, rdata, 12'h411); check_eq8(rdata[7:0], miso_seq[1], "Multi-byte DRR[1]");
                    axi_read(REG_DRR, rdata, 12'h412); check_eq8(rdata[7:0], miso_seq[2], "Multi-byte DRR[2]");
                    axi_read(REG_DRR, rdata, 12'h413); check_eq8(rdata[7:0], miso_seq[3], "Multi-byte DRR[3]");

                    axi_read(REG_SR,   sr_val,   12'h414);
                    axi_read(REG_RFOR, rfor_val, 12'h415);
                    check_eq1(sr_val[`_SR_RX_EMPTY_BIT_], 1'b1, "Multi-byte SR.RX_EMPTY after 4 reads");
                    check_eq32(rfor_val, 32'd0, "Multi-byte RFOR after 4 reads");
                    axi_done = 1'b1;
                end

                // SPI Bus captures 32 bits (4 bytes) and drives MISO
                begin
                    prev_sclk = spi_clk_o;
                    wait_cyc  = 0;
                    while (!mon_done) begin
                        @(posedge clk);
                        #1;
                        wait_cyc++;
                        if (wait_cyc > SPI_TIMEOUT_CYCLES) begin
                            $display("  [FAIL] Multi-byte SPI bus timeout (pulses=%0d)", pulse_cnt);
                            fail_count++;
                            mon_done = 1'b1;
                        end else begin
                            if (prev_sclk === 1'b0 && spi_clk_o === 1'b1) begin
                                if (pulse_cnt < 32) begin
                                    byte_idx = pulse_cnt / 8;
                                    bit_idx  = 7 - (pulse_cnt % 8);
                                    rx_cap[byte_idx][bit_idx] = spi_mosi_o;
                                end
                                pulse_cnt++;
                            end else if (prev_sclk === 1'b1 && spi_clk_o === 1'b0) begin
                                neg_cnt++;
                                if (neg_cnt < 32) begin
                                    byte_idx = neg_cnt / 8;
                                    bit_idx  = 7 - (neg_cnt % 8);
                                    spi_miso_i = miso_seq[byte_idx][bit_idx];
                                end else begin
                                    spi_miso_i = 1'b0;
                                end
                            end else if (neg_cnt == 32 && axi_done) begin
                                mon_done = 1'b1;
                            end
                            prev_sclk = spi_clk_o;
                        end
                    end
                end
            join

            check_eq8(rx_cap[0], tx_seq[0], "Multi-byte MOSI[0]");
            check_eq8(rx_cap[1], tx_seq[1], "Multi-byte MOSI[1]");
            check_eq8(rx_cap[2], tx_seq[2], "Multi-byte MOSI[2]");
            check_eq8(rx_cap[3], tx_seq[3], "Multi-byte MOSI[3]");
            if (pulse_cnt == 32 && neg_cnt == 32) begin
                $display("  [PASS] Multi-byte SCLK count = 32 pulses across 4 queued bytes");
                pass_count++;
            end else begin
                $display("  [FAIL] Multi-byte SCLK count mismatch (pos=%0d, neg=%0d, exp 32)", pulse_cnt, neg_cnt);
                fail_count++;
            end
        end

        // Deassert CS_N
        axi_write(REG_SSR, 32'hFFFF_FFFF);
        @(posedge clk); #1;
        check_eq1(spi_cs_n_o, 1'b1, "CS_N deasserted HIGH after multi-byte transfer");

        // ------------------------------------------------------------------
        // TEST 6: FIFO Reset Bits, Soft Reset (SPI_SRR) & Mid-Transfer HW Reset
        // ------------------------------------------------------------------
        $display("\n[TEST 6] FIFO Reset, Soft Reset (SPI_SRR) & Hardware Reset");
        // Send one byte without reading DRR so RX FIFO holds 1 entry
        axi_write(REG_SSR,  32'hFFFF_FFFE);
        axi_write(REG_RCLK, 32'd1);
        axi_write(REG_DTR,  32'h0000_005C);
        // Wait for RX_EMPTY == 0
        begin : wait_rx1_blk
            int w;
            bit got_rx;
            w = 0;
            got_rx = 1'b0;
            while (!got_rx && w < 200) begin
                axi_read(REG_SR, rdata);
                if (rdata[`_SR_RX_EMPTY_BIT_] == 1'b0) got_rx = 1'b1;
                w++;
            end
        end
        axi_read(REG_RFOR, rdata); check_eq32(rdata, 32'd1, "RFOR==1 before CR.RX_FIFO_RESET");

        // Trigger CR.RX_FIFO_RESET (bit 6) and CR.TX_FIFO_RESET (bit 5) -> 0x0000_00E6
        axi_write(REG_CR, 32'h0000_00E6);
        axi_read (REG_CR, rdata);
        check_eq32(rdata, 32'h0000_0086, "CR[6:5] FIFO reset bits auto-cleared");
        axi_read (REG_RFOR, rdata); check_eq32(rdata, 32'd0,    "RFOR==0 after CR.RX_FIFO_RESET");
        axi_read (REG_SR,   rdata); check_eq1(rdata[`_SR_RX_EMPTY_BIT_], 1'b1, "SR.RX_EMPTY==1 after RX FIFO reset");

        // Leave another byte in RX FIFO + non-default regs, then test SPI_SRR
        axi_write(REG_DTR, 32'h0000_007E);
        begin : wait_rx2_blk
            int w;
            bit got_rx;
            w = 0;
            got_rx = 1'b0;
            while (!got_rx && w < 200) begin
                axi_read(REG_SR, rdata);
                if (rdata[`_SR_RX_EMPTY_BIT_] == 1'b0) got_rx = 1'b1;
                w++;
            end
        end

        // Writing wrong key to SPI_SRR (0x05 != 0x0A) must NOT reset registers
        axi_write(REG_SRR, 32'h0000_0005);
        repeat (3) @(posedge clk); #1;
        axi_read(REG_SSR, rdata); check_eq32(rdata, 32'hFFFF_FFFE, "SPI_SSR unchanged after wrong SRR key 0x05");

        // Writing 0x0A to SPI_SRR triggers full soft reset
        axi_write(REG_SRR, `_SPI_SRR_VALUE_);
        repeat (4) @(posedge clk); #1;
        check_eq1(spi_cs_n_o, 1'b1, "Soft reset deasserted spi_cs_n_o");
        axi_read(REG_CR,   rdata); check_eq32(rdata, RST_CR,   "Soft reset SPI_CR");
        axi_read(REG_SR,   rdata); check_eq32(rdata, RST_SR,   "Soft reset SPI_SR");
        axi_read(REG_SSR,  rdata); check_eq32(rdata, RST_SSR,  "Soft reset SPI_SSR");
        axi_read(REG_RFOR, rdata); check_eq32(rdata, 32'd0,    "Soft reset SPI_RFOR");
        axi_read(REG_GIER, rdata); check_eq32(rdata, RST_GIER, "Soft reset SPI_GIER");
        axi_read(REG_IER,  rdata); check_eq32(rdata, RST_IER,  "Soft reset SPI_IER");

        // Hardware reset mid-transfer
        axi_write(REG_CR,   32'h0000_0086);
        axi_write(REG_RCLK, 32'd4); // slow SCLK (period = 32 clks)
        axi_write(REG_SSR,  32'hFFFF_FFFE);
        axi_write(REG_DTR,  32'h0000_00A5);
        // Wait until SCLK starts toggling (at least 2 rising edges)
        repeat (2) @(posedge spi_clk_o);
        @(posedge clk); #1;
        apply_reset(6);
        check_eq1(spi_cs_n_o, 1'b1, "HW mid-transfer reset spi_cs_n_o == 1");
        check_eq1(spi_clk_o,  1'b0, "HW mid-transfer reset spi_clk_o  == 0");
        check_eq1(spi_mosi_o, 1'b1, "HW mid-transfer reset spi_mosi_o == 1");
        axi_read(REG_CR, rdata); check_eq32(rdata, RST_CR, "HW mid-transfer reset SPI_CR");
        axi_read(REG_SR, rdata); check_eq32(rdata, RST_SR, "HW mid-transfer reset SPI_SR");

        // Confirm normal operation recovers after hardware reset
        axi_write(REG_CR,   32'h0000_0086);
        axi_write(REG_RCLK, 32'd1);
        axi_write(REG_SSR,  32'hFFFF_FFFE);
        @(posedge clk); #1;
        run_and_verify_spi_byte(8'h5A, 8'hA5, 1'b0, 1, "Post-HW-reset recovery transfer");
        axi_write(REG_SSR,  32'hFFFF_FFFF);

        // ------------------------------------------------------------------
        // Summary
        // ------------------------------------------------------------------
        $display("\n==================================================================");
        $display("  tb_axi_spi Summary: PASS=%0d, FAIL=%0d", pass_count, fail_count);
        if (fail_count == 0) begin
            $display("  OVERALL RESULT: PASS");
            $display("==================================================================");
            $finish;
        end else begin
            $display("  OVERALL RESULT: FAIL");
            $display("==================================================================");
            $fatal(1, "tb_axi_spi failed with %0d error(s)", fail_count);
        end
    end

endmodule
