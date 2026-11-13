// =============================================================================
// SEG7 Refresh Divider Boundary Sequence: seg7_refresh_boundary_seq
// Verifies:
//   1. Boundary and edge refresh divider values: 0, 1, 2, 20, and 65535.
//   2. Exact RTL counter advancement formula:
//      expected_dwell = (divider <= 1) ? 1 : divider
//   3. Fast divider cases (0, 1, 2, 20) with DIGIT_MASK = 8'hFF and 18 dwell intervals.
//   4. Maximum divider case (65535) with DIGIT_MASK = 8'h03 and 3 dwell intervals.
//   5. Dwell time verification via scoreboard check_dwell().
//   6. Segment display and polarity verification via scoreboard check_display().
//   7. Functional coverage sampling for dwell duration bins:
//      - edge_1clk  (divider 0, 1)
//      - fast_dwell (divider 2, 20)
//      - slow_dwell (divider 65535)
// =============================================================================

`ifndef SEG7_REFRESH_BOUNDARY_SEQ_SV
`define SEG7_REFRESH_BOUNDARY_SEQ_SV

class seg7_refresh_boundary_seq extends seg7_base_seq;

    // Handle to VIP scoreboard for observation window control and checks
    seg7_vip_scoreboard sb;

    `uvm_object_utils(seg7_refresh_boundary_seq)

    function new(string name = "seg7_refresh_boundary_seq");
        super.new(name);
    endfunction

    // -------------------------------------------------------------------------
    // Helper Task: Test Fast Divider Configurations (0, 1, 2, 20)
    // -------------------------------------------------------------------------
    virtual task test_fast_divider(
        input int        divider,
        input bit [31:0] test_data
    );
        int expected_dwell;
        int wait_clocks;
        bit [31:0] ctrl_dis;
        bit [31:0] ctrl_en;

        // Exact RTL counter advancement: divider <= 1 yields 1 clock cycle dwell
        expected_dwell = (divider <= 1) ? 1 : divider;
        wait_clocks    = 18 * expected_dwell;

        `uvm_info(get_type_name(),
            $sformatf("=== Testing Fast Refresh Divider %0d (expected_dwell=%0d, wait_clocks=%0d) ===",
                      divider, expected_dwell, wait_clocks),
            UVM_LOW)

        // Precompute control words for DIGIT_MASK = 8'hFF, active-low seg & an
        ctrl_dis = (32'(8'hFF) << SEG_CTRL_MASK_SHIFT) | SEG_CTRL_AN_ACT_LO | SEG_CTRL_SEG_ACT_LO; // 32'h0000_FF06
        ctrl_en  = ctrl_dis | SEG_CTRL_EN;                                                           // 32'h0000_FF07

        // 1. Disable display before reconfiguration
        write_reg(REG_SEG_CTRL, ctrl_dis);

        // 2. Set DIGIT_MASK = 8'hFF (embedded in ctrl_dis/ctrl_en), SEG_DATA, and SEG_DP = 8'h00
        write_reg(REG_SEG_DATA, test_data);
        write_reg(REG_SEG_DP, 32'h0000_0000);

        // 3. Write selected refresh divider
        write_reg(REG_SEG_REFRESH_DIV, 32'(divider));

        // 4. Clear scoreboard observation window
        sb.start_observation_window();

        // 5. Enable display scanning
        write_reg(REG_SEG_CTRL, ctrl_en);

        // 6. Allow at least 18 dwell intervals (18 * expected_dwell clock cycles)
        #(wait_clocks * 10ns);

        // 7. Disable scanning to publish the final active digit observation
        write_reg(REG_SEG_CTRL, ctrl_dis);

        // 8. Allow monitor clock edge and delta delay to record and publish transaction
        #20ns;

        // 9. Verify dwell times against expected dwell cycles
        sb.check_dwell(expected_dwell);

        // 10. Verify segment display patterns and active-low polarities across all 8 digits
        sb.check_display(
            .en     (1'b1),
            .data   (test_data),
            .dp     (8'h00),
            .mask   (8'hFF),
            .seg_al (1'b1),
            .an_al  (1'b1)
        );

        `uvm_info(get_type_name(),
            $sformatf("=== PASS: Fast Refresh Divider %0d verified successfully (dwell=%0d clocks) ===",
                      divider, expected_dwell),
            UVM_LOW)
    endtask

    // -------------------------------------------------------------------------
    // Helper Task: Test Maximum Refresh Divider (65535)
    // -------------------------------------------------------------------------
    virtual task test_max_divider(
        input bit [31:0] test_data
    );
        int divider        = 65535;
        int expected_dwell = 65535;
        int wait_clocks    = 196605; // 3 * 65535 complete clock cycles
        bit [31:0] ctrl_dis;
        bit [31:0] ctrl_en;

        `uvm_info(get_type_name(),
            $sformatf("=== Testing Maximum Refresh Divider %0d (expected_dwell=%0d, wait_clocks=%0d) ===",
                      divider, expected_dwell, wait_clocks),
            UVM_LOW)

        // Precompute control words for DIGIT_MASK = 8'h03 (digits 0 and 1 active), active-low seg & an
        ctrl_dis = (32'(8'h03) << SEG_CTRL_MASK_SHIFT) | SEG_CTRL_AN_ACT_LO | SEG_CTRL_SEG_ACT_LO; // 32'h0000_0306
        ctrl_en  = ctrl_dis | SEG_CTRL_EN;                                                           // 32'h0000_0307

        // 1. Disable display before reconfiguration
        write_reg(REG_SEG_CTRL, ctrl_dis);

        // 2. Set DIGIT_MASK = 8'h03, SEG_DATA (distinct nibbles for digits 0 and 1), and SEG_DP = 8'h00
        write_reg(REG_SEG_DATA, test_data);
        write_reg(REG_SEG_DP, 32'h0000_0000);

        // 3. Program SEG_REFRESH_DIV = 65535
        write_reg(REG_SEG_REFRESH_DIV, 32'd65535);

        // 4. Clear scoreboard observation window
        sb.start_observation_window();

        // 5. Enable scanning
        write_reg(REG_SEG_CTRL, ctrl_en);

        // 6. Allow three complete dwell intervals (3 * 65535 = 196605 clock cycles = 1,966,050 ns)
        #(wait_clocks * 10ns);

        // 7. Disable scanning to publish the final active digit observation
        write_reg(REG_SEG_CTRL, ctrl_dis);

        // 8. Allow monitor clock edge and delta delay to record and publish transaction
        #20ns;

        // 9. Verify dwell times against expected 65535 dwell cycles
        sb.check_dwell(expected_dwell);

        // 10. Verify segment display patterns and active-low polarities for digits 0 and 1 (masked 2..7)
        sb.check_display(
            .en     (1'b1),
            .data   (test_data),
            .dp     (8'h00),
            .mask   (8'h03),
            .seg_al (1'b1),
            .an_al  (1'b1)
        );

        `uvm_info(get_type_name(),
            $sformatf("=== PASS: Maximum Refresh Divider %0d verified successfully (dwell=%0d clocks) ===",
                      divider, expected_dwell),
            UVM_LOW)
    endtask

    virtual task body();
        bit [31:0] test_data = 32'h7654_3210;

        `uvm_info(get_type_name(), "=== Starting SEG7 Refresh Divider Boundary Verification Sequence ===", UVM_LOW)

        // Validate scoreboard handle
        if (sb == null) begin
            if (!uvm_config_db#(seg7_vip_scoreboard)::get(null, get_full_name(), "sb", sb)) begin
                uvm_root root = uvm_root::get();
                uvm_component c = root.find("uvm_test_top.env.sb");
                if (c != null) begin
                    void'($cast(sb, c));
                end
            end
        end

        if (sb == null) begin
            `uvm_fatal(get_type_name(), "Scoreboard handle 'sb' is null! Test must assign seq.sb = env.sb")
        end

        // ---------------------------------------------------------------------
        // Fast Divider Cases: 0, 1, 2, 20
        // ---------------------------------------------------------------------
        // Case 1: Divider = 0 (RTL clamps to 1 clock cycle dwell)
        test_fast_divider(0, test_data);

        // Case 2: Divider = 1 (1 clock cycle dwell)
        test_fast_divider(1, test_data);

        // Case 3: Divider = 2 (2 clock cycles dwell)
        test_fast_divider(2, test_data);

        // Case 4: Divider = 20 (20 clock cycles dwell)
        test_fast_divider(20, test_data);

        // ---------------------------------------------------------------------
        // Normal Dwell Range Case: 50 (exercises coverage bin norm_dwell [31:1000])
        // ---------------------------------------------------------------------
        // Case 5: Divider = 50 (50 clock cycles dwell)
        test_fast_divider(50, test_data);

        // ---------------------------------------------------------------------
        // Maximum Divider Case: 65535
        // ---------------------------------------------------------------------
        // Case 6: Divider = 65535 (65535 clock cycles dwell, 2 digits active)
        test_max_divider(test_data);

        // ---------------------------------------------------------------------
        // Cleanup / Restore Power-On Reset Defaults
        // ---------------------------------------------------------------------
        `uvm_info(get_type_name(), "Restoring default register configurations...", UVM_LOW)
        write_reg(REG_SEG_CTRL, 32'h0000_FF06);
        write_reg(REG_SEG_REFRESH_DIV, 32'h0000_03E8);
        write_reg(REG_SEG_DATA, 32'h0000_0000);
        write_reg(REG_SEG_DP, 32'h0000_0000);

        `uvm_info(get_type_name(), "=== Completed SEG7 Refresh Divider Boundary Verification Sequence ===", UVM_LOW)
    endtask

endclass : seg7_refresh_boundary_seq

`endif // SEG7_REFRESH_BOUNDARY_SEQ_SV

