// =============================================================================
// SEG7 Segment and Anode Polarity Sequence: seg7_polarity_seq
// Verifies:
//   1. All four segment and anode polarity combinations in SEG_CTRL:
//      - Case 1: SEG_ACTIVE_LOW=0, AN_ACTIVE_LOW=0 (Active-High Segments, Active-High Anodes)
//      - Case 2: SEG_ACTIVE_LOW=0, AN_ACTIVE_LOW=1 (Active-High Segments, Active-Low Anodes)
//      - Case 3: SEG_ACTIVE_LOW=1, AN_ACTIVE_LOW=0 (Active-Low Segments, Active-High Anodes)
//      - Case 4: SEG_ACTIVE_LOW=1, AN_ACTIVE_LOW=1 (Active-Low Segments, Active-Low Anodes)
//   2. Polarity inversion verification against physical outputs:
//      - Physical segment inversion on seg_o pins based on seg_active_low_i.
//      - Physical anode inversion (one-hot vs. one-cold) on an_o pins based on an_active_low_i.
//   3. Verification via seg7_vip_scoreboard::check_display().
// =============================================================================

`ifndef SEG7_POLARITY_SEQ_SV
`define SEG7_POLARITY_SEQ_SV

class seg7_polarity_seq extends seg7_base_seq;

    // Handle to VIP scoreboard for observation window control and display checks
    seg7_vip_scoreboard sb;

    // Compact refresh divider (20 clock cycles) to accelerate simulation while providing clean dwell intervals
    int refresh_div = 20;

    `uvm_object_utils(seg7_polarity_seq)

    function new(string name = "seg7_polarity_seq");
        super.new(name);
    endfunction

    // -------------------------------------------------------------------------
    // Reusable Task: Test a Single Polarity Configuration
    // -------------------------------------------------------------------------
    virtual task test_polarity_case(
        input bit    seg_al,
        input bit    an_al,
        input string desc
    );
        int wait_clocks;
        bit [31:0] ctrl_dis;
        bit [31:0] ctrl_en;
        bit [31:0] test_data = 32'h7654_3210;
        bit [7:0]  test_dp   = 8'h96;

        // With all 8 digits enabled, 2 complete scan rounds = 2 * 8 * refresh_div = 320 clocks.
        // Allow 2 complete rounds plus 2 dwell periods margin (18 * refresh_div = 360 clocks = 3600 ns).
        wait_clocks = (2 * 8 + 2) * refresh_div;

        `uvm_info(get_type_name(),
            $sformatf("=== Testing Polarity: SEG_ACT_LO=%0b, AN_ACT_LO=%0b (%s) ===",
                      seg_al, an_al, desc),
            UVM_LOW)

        // 1. Disable display before changing polarity
        ctrl_dis = (32'(8'hFF) << SEG_CTRL_MASK_SHIFT) |
                   (an_al  ? SEG_CTRL_AN_ACT_LO  : 32'h0) |
                   (seg_al ? SEG_CTRL_SEG_ACT_LO : 32'h0);
        write_reg(REG_SEG_CTRL, ctrl_dis);

        // 2. Clear scoreboard using start_observation_window()
        sb.start_observation_window();

        // 3. Program SEG_DATA, SEG_DP, SEG_REFRESH_DIV
        write_reg(REG_SEG_DATA, test_data);
        write_reg(REG_SEG_DP, 32'(test_dp));
        write_reg(REG_SEG_REFRESH_DIV, 32'(refresh_div));

        // 4. Enable display with selected polarity configuration
        ctrl_en = ctrl_dis | SEG_CTRL_EN;
        write_reg(REG_SEG_CTRL, ctrl_en);

        // 5. Allow at least two complete scan rounds
        #(wait_clocks * 10ns);

        // 6. Disable display to close the final active dwell
        // This causes an anode transition that prompts the monitor
        // to complete and publish the final dwell record to the scoreboard
        write_reg(REG_SEG_CTRL, ctrl_dis);

        // 7. Allow monitor clock edge and delta delay to record and publish transaction
        #20ns;

        // 8. Call existing scoreboard display check
        sb.check_display(
            .en     (1'b1),
            .data   (test_data),
            .dp     (test_dp),
            .mask   (8'hFF),
            .seg_al (seg_al),
            .an_al  (an_al)
        );

        `uvm_info(get_type_name(),
            $sformatf("=== PASS: Polarity SEG_ACT_LO=%0b, AN_ACT_LO=%0b verified successfully ===",
                      seg_al, an_al),
            UVM_LOW)
    endtask

    virtual task body();
        `uvm_info(get_type_name(), "=== Starting SEG7 Segment and Anode Polarity Verification Sequence ===", UVM_LOW)

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
        // Case 1: SEG_ACTIVE_LOW=0, AN_ACTIVE_LOW=0
        // (Active-High Segments, Active-High Anodes)
        // ---------------------------------------------------------------------
        test_polarity_case(1'b0, 1'b0, "Active-High Segments, Active-High Anodes");

        // ---------------------------------------------------------------------
        // Case 2: SEG_ACTIVE_LOW=0, AN_ACTIVE_LOW=1
        // (Active-High Segments, Active-Low Anodes)
        // ---------------------------------------------------------------------
        test_polarity_case(1'b0, 1'b1, "Active-High Segments, Active-Low Anodes");

        // ---------------------------------------------------------------------
        // Case 3: SEG_ACTIVE_LOW=1, AN_ACTIVE_LOW=0
        // (Active-Low Segments, Active-High Anodes)
        // ---------------------------------------------------------------------
        test_polarity_case(1'b1, 1'b0, "Active-Low Segments, Active-High Anodes");

        // ---------------------------------------------------------------------
        // Case 4: SEG_ACTIVE_LOW=1, AN_ACTIVE_LOW=1
        // (Active-Low Segments, Active-Low Anodes / Default)
        // ---------------------------------------------------------------------
        test_polarity_case(1'b1, 1'b1, "Active-Low Segments, Active-Low Anodes");

        // ---------------------------------------------------------------------
        // Step 8: Cleanup / Restore Defaults
        // ---------------------------------------------------------------------
        `uvm_info(get_type_name(), "Restoring default register configurations...", UVM_LOW)
        write_reg(REG_SEG_CTRL, 32'h0000_FF06);
        write_reg(REG_SEG_REFRESH_DIV, 32'h0000_03E8);
        write_reg(REG_SEG_DATA, 32'h0000_0000);
        write_reg(REG_SEG_DP, 32'h0000_0000);

        `uvm_info(get_type_name(), "=== Completed SEG7 Segment and Anode Polarity Verification Sequence ===", UVM_LOW)
    endtask

endclass : seg7_polarity_seq

`endif // SEG7_POLARITY_SEQ_SV

