// =============================================================================
// SEG7 Eight-Digit Scanning and Digit-Mask Sequence: seg7_scan_mask_seq
// Verifies:
//   1. Full eight-digit round-robin scanning (DIGIT_MASK = 8'hFF).
//   2. Digit ordering and nibble-to-digit mapping:
//      - Digit 0 is rightmost (SEG_DATA[3:0]), Digit 7 is leftmost (SEG_DATA[31:28]).
//      - Unique hexadecimal patterns across all eight digits (0x76543210).
//   3. Digit-mask verification across selective configurations:
//      - 8'hFF: all eight digits enabled.
//      - 8'h55: alternating even digits (0, 2, 4, 6) enabled.
//      - 8'hAA: alternating odd digits (1, 3, 5, 7) enabled.
//      - 8'h0F: lower four digits (0, 1, 2, 3) enabled.
//      - 8'hF0: upper four digits (4, 5, 6, 7) enabled.
//      - 8'h01: single digit 0 only.
//      - 8'h80: single digit 7 only.
//   4. Per-mask observation windows via start_observation_window() and check_display().
// =============================================================================

`ifndef SEG7_SCAN_MASK_SEQ_SV
`define SEG7_SCAN_MASK_SEQ_SV

class seg7_scan_mask_seq extends seg7_base_seq;

    // Handle to VIP scoreboard for observation window control and display checks
    seg7_vip_scoreboard sb;

    // Compact refresh divider (20 clock cycles) to accelerate simulation while providing clean dwell intervals
    int refresh_div = 20;

    `uvm_object_utils(seg7_scan_mask_seq)

    function new(string name = "seg7_scan_mask_seq");
        super.new(name);
    endfunction

    // Helper function to count the number of active digits in a mask
    function automatic int count_active_digits(bit [7:0] m);
        int count = 0;
        for (int i = 0; i < 8; i++) begin
            if (m[i]) count++;
        end
        return count;
    endfunction

    // -------------------------------------------------------------------------
    // Reusable Task: Test a Single Digit-Mask Configuration
    // -------------------------------------------------------------------------
    virtual task test_digit_mask(
        input bit [7:0]  mask,
        input bit [31:0] data,
        input string     desc
    );
        int k;
        int wait_clocks;
        bit [31:0] ctrl_dis;
        bit [31:0] ctrl_en;

        k = count_active_digits(mask);
        // Allow at least 2 complete scan rounds plus 2 dwell periods margin:
        // For k enabled digits, each round takes k * refresh_div clock cycles.
        wait_clocks = (2 * k + 2) * refresh_div;

        `uvm_info(get_type_name(),
            $sformatf("=== Testing Digit Mask 0x%02h (%0d digits active, %0d wait clocks): %s ===",
                      mask, k, wait_clocks, desc),
            UVM_LOW)

        // 1. Disable display before reconfiguration
        ctrl_dis = (32'(mask) << SEG_CTRL_MASK_SHIFT) | SEG_CTRL_AN_ACT_LO | SEG_CTRL_SEG_ACT_LO;
        write_reg(REG_SEG_CTRL, ctrl_dis);

        // 2. Clear scoreboard using start_observation_window()
        sb.start_observation_window();

        // 3. Program SEG_DATA
        write_reg(REG_SEG_DATA, data);

        // 4. Re-enable display with target mask and active-low polarities
        ctrl_en = ctrl_dis | SEG_CTRL_EN;
        write_reg(REG_SEG_CTRL, ctrl_en);

        // 5. Wait long enough for every enabled digit to be scanned at least twice
        #(wait_clocks * 10ns);

        // 6. Disable display to close the final dwell observation
        // This causes an anode transition (one-cold -> 8'hFF) that prompts the monitor
        // to complete and publish the final dwell record to the scoreboard
        write_reg(REG_SEG_CTRL, ctrl_dis);

        // 7. Allow monitor clock edge and delta delay to record and publish transaction
        #20ns;

        // 8. Verify observed display against expected mask and data
        sb.check_display(
            .en     (1'b1),
            .data   (data),
            .dp     (8'h00),
            .mask   (mask),
            .seg_al (1'b1),
            .an_al  (1'b1)
        );

        `uvm_info(get_type_name(),
            $sformatf("=== PASS: Digit Mask 0x%02h verified successfully ===", mask),
            UVM_LOW)
    endtask

    virtual task body();
        // Eight distinct hexadecimal values assigned to digits 0..7 (unique pattern per digit)
        // Digit 0: 0x0, Digit 1: 0x1, Digit 2: 0x2, Digit 3: 0x3,
        // Digit 4: 0x4, Digit 5: 0x5, Digit 6: 0x6, Digit 7: 0x7
        bit [31:0] test_data = 32'h7654_3210;

        `uvm_info(get_type_name(), "=== Starting SEG7 Eight-Digit Scanning and Digit-Mask Verification Sequence ===", UVM_LOW)

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
        // Step 0: Hardware Initialization
        // ---------------------------------------------------------------------
        write_reg(REG_SEG_DP, 32'h0000_0000);
        write_reg(REG_SEG_REFRESH_DIV, 32'(refresh_div));

        // ---------------------------------------------------------------------
        // Section 2 & 3.1: Full Eight-Digit Scanning Test (DIGIT_MASK = 8'hFF)
        // Verifies all 8 digits scan round-robin with correct ordering (0x0..0x7)
        // ---------------------------------------------------------------------
        test_digit_mask(8'hFF, test_data, "All eight digits enabled (0..7 scanning)");

        // ---------------------------------------------------------------------
        // Section 3.2: Alternating Even Digits (DIGIT_MASK = 8'h55)
        // Enabled: 0, 2, 4, 6 | Masked: 1, 3, 5, 7
        // ---------------------------------------------------------------------
        test_digit_mask(8'h55, test_data, "Alternating even digits (0, 2, 4, 6 enabled)");

        // ---------------------------------------------------------------------
        // Section 3.3: Alternating Odd Digits (DIGIT_MASK = 8'hAA)
        // Enabled: 1, 3, 5, 7 | Masked: 0, 2, 4, 6
        // ---------------------------------------------------------------------
        test_digit_mask(8'hAA, test_data, "Alternating odd digits (1, 3, 5, 7 enabled)");

        // ---------------------------------------------------------------------
        // Section 3.4: Lower Four Digits (DIGIT_MASK = 8'h0F)
        // Enabled: 0, 1, 2, 3 | Masked: 4, 5, 6, 7
        // ---------------------------------------------------------------------
        test_digit_mask(8'h0F, test_data, "Lower four digits (0, 1, 2, 3 enabled)");

        // ---------------------------------------------------------------------
        // Section 3.5: Upper Four Digits (DIGIT_MASK = 8'hF0)
        // Enabled: 4, 5, 6, 7 | Masked: 0, 1, 2, 3
        // ---------------------------------------------------------------------
        test_digit_mask(8'hF0, test_data, "Upper four digits (4, 5, 6, 7 enabled)");

        // ---------------------------------------------------------------------
        // Section 3.6: Single Digit 0 Only (DIGIT_MASK = 8'h01)
        // Enabled: 0 (rightmost) | Masked: 1..7
        // ---------------------------------------------------------------------
        test_digit_mask(8'h01, test_data, "Single digit 0 only (rightmost)");

        // ---------------------------------------------------------------------
        // Section 3.7: Single Digit 7 Only (DIGIT_MASK = 8'h80)
        // Enabled: 7 (leftmost) | Masked: 0..6
        // ---------------------------------------------------------------------
        test_digit_mask(8'h80, test_data, "Single digit 7 only (leftmost)");

        // ---------------------------------------------------------------------
        // Section 3.8: All Digits Disabled (DIGIT_MASK = 8'h00, EN = 1)
        // Enabled: none | All digits 0..7 masked off (remains blank)
        // ---------------------------------------------------------------------
        test_digit_mask(8'h00, test_data, "All digits disabled (mask=8'h00, display blank)");

        // ---------------------------------------------------------------------
        // Step 8: Cleanup / Restore Defaults
        // ---------------------------------------------------------------------
        `uvm_info(get_type_name(), "Restoring default register configurations...", UVM_LOW)
        write_reg(REG_SEG_CTRL, 32'h0000_FF06);
        write_reg(REG_SEG_REFRESH_DIV, 32'h0000_03E8);
        write_reg(REG_SEG_DATA, 32'h0000_0000);
        write_reg(REG_SEG_DP, 32'h0000_0000);

        `uvm_info(get_type_name(), "=== Completed SEG7 Eight-Digit Scanning and Digit-Mask Verification Sequence ===", UVM_LOW)
    endtask

endclass : seg7_scan_mask_seq

`endif // SEG7_SCAN_MASK_SEQ_SV

