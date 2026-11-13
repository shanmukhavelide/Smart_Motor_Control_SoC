// =============================================================================
// SEG7 Decimal Point Control Sequence: seg7_dp_control_seq
// Verifies:
//   1. Decimal-point (DP) enable and disable across all eight digits (SEG_DP).
//   2. Physical segment output bit mapping:
//      - seg_o[7] drives active-low DP (~dp_i[digit]).
//      - seg_o[6:0] drives active-low 7-segment hex pattern.
//   3. Simultaneous verification of DP illumination and 7-segment hex pattern.
//   4. Test patterns:
//      - 0x00: all decimal points disabled.
//      - 0x01: DP enabled only on digit 0 (rightmost).
//      - 0x80: DP enabled only on digit 7 (leftmost).
//      - 0x55: DP enabled on alternating even digits (0, 2, 4, 6).
//      - 0xAA: DP enabled on alternating odd digits (1, 3, 5, 7).
//      - 0xFF: all decimal points enabled.
//      - 0x96: mixed DP pattern (digits 1, 2, 4, 7 enabled).
// =============================================================================

`ifndef SEG7_DP_CONTROL_SEQ_SV
`define SEG7_DP_CONTROL_SEQ_SV

class seg7_dp_control_seq extends seg7_base_seq;

    // Handle to VIP scoreboard for observation window control and display checks
    seg7_vip_scoreboard sb;

    // Compact refresh divider (20 clock cycles) to accelerate simulation while providing clean dwell intervals
    int refresh_div = 20;

    `uvm_object_utils(seg7_dp_control_seq)

    function new(string name = "seg7_dp_control_seq");
        super.new(name);
    endfunction

    // -------------------------------------------------------------------------
    // Reusable Task: Test a Single Decimal-Point Pattern Configuration
    // -------------------------------------------------------------------------
    virtual task test_dp_pattern(
        input bit [7:0]  dp_val,
        input bit [31:0] data,
        input string     desc
    );
        int wait_clocks;
        bit [31:0] ctrl_dis;
        bit [31:0] ctrl_en;

        // With all 8 digits enabled, 2 complete scan rounds = 2 * 8 * refresh_div = 320 clocks.
        // Allow 2 complete rounds plus 2 dwell periods margin (18 * refresh_div = 360 clocks = 3600 ns).
        wait_clocks = (2 * 8 + 2) * refresh_div;

        `uvm_info(get_type_name(),
            $sformatf("=== Testing DP Pattern 0x%02h (%0d wait clocks): %s ===",
                      dp_val, wait_clocks, desc),
            UVM_LOW)

        // 1. Disable display before reconfiguration
        ctrl_dis = (32'(8'hFF) << SEG_CTRL_MASK_SHIFT) | SEG_CTRL_AN_ACT_LO | SEG_CTRL_SEG_ACT_LO;
        write_reg(REG_SEG_CTRL, ctrl_dis);

        // 2. Clear scoreboard using start_observation_window()
        sb.start_observation_window();

        // 3. Program SEG_DATA (distinct nibbles) and SEG_DP (target pattern)
        write_reg(REG_SEG_DATA, data);
        write_reg(REG_SEG_DP, 32'(dp_val));

        // 4. Re-enable display with all eight digits enabled (active-low seg & an)
        ctrl_en = ctrl_dis | SEG_CTRL_EN;
        write_reg(REG_SEG_CTRL, ctrl_en);

        // 5. Wait long enough for every enabled digit to complete at least two full scan cycles
        #(wait_clocks * 10ns);

        // 6. Disable display to close the final dwell observation
        // This causes an anode transition (one-cold -> 8'hFF) that prompts the monitor
        // to complete and publish the final dwell record to the scoreboard
        write_reg(REG_SEG_CTRL, ctrl_dis);

        // 7. Allow monitor clock edge and delta delay to record and publish transaction
        #20ns;

        // 8. Verify observed display against expected data and DP pattern
        sb.check_display(
            .en     (1'b1),
            .data   (data),
            .dp     (dp_val),
            .mask   (8'hFF),
            .seg_al (1'b1),
            .an_al  (1'b1)
        );

        `uvm_info(get_type_name(),
            $sformatf("=== PASS: DP Pattern 0x%02h verified successfully ===", dp_val),
            UVM_LOW)
    endtask

    virtual task body();
        // Eight distinct hexadecimal values assigned to digits 0..7 (unique pattern per digit)
        // Digit 0: 0x0, Digit 1: 0x1, Digit 2: 0x2, Digit 3: 0x3,
        // Digit 4: 0x4, Digit 5: 0x5, Digit 6: 0x6, Digit 7: 0x7
        bit [31:0] test_data = 32'h7654_3210;

        `uvm_info(get_type_name(), "=== Starting SEG7 Decimal Point Control Verification Sequence ===", UVM_LOW)

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
        write_reg(REG_SEG_REFRESH_DIV, 32'(refresh_div));

        // ---------------------------------------------------------------------
        // Case 1: DP disabled on all digits (SEG_DP = 0x00)
        // ---------------------------------------------------------------------
        test_dp_pattern(8'h00, test_data, "DP disabled on all digits (0x00)");

        // ---------------------------------------------------------------------
        // Case 2: DP enabled only on digit 0 (SEG_DP = 0x01, rightmost)
        // ---------------------------------------------------------------------
        test_dp_pattern(8'h01, test_data, "DP enabled only on digit 0 (0x01)");

        // ---------------------------------------------------------------------
        // Case 3: DP enabled only on digit 7 (SEG_DP = 0x80, leftmost)
        // ---------------------------------------------------------------------
        test_dp_pattern(8'h80, test_data, "DP enabled only on digit 7 (0x80)");

        // ---------------------------------------------------------------------
        // Case 4: DP enabled on alternating even digits (SEG_DP = 0x55)
        // Digits 0, 2, 4, 6 active DP; digits 1, 3, 5, 7 inactive DP
        // ---------------------------------------------------------------------
        test_dp_pattern(8'h55, test_data, "DP enabled on alternating even digits (0x55)");

        // ---------------------------------------------------------------------
        // Case 5: DP enabled on alternating odd digits (SEG_DP = 0xAA)
        // Digits 1, 3, 5, 7 active DP; digits 0, 2, 4, 6 inactive DP
        // ---------------------------------------------------------------------
        test_dp_pattern(8'hAA, test_data, "DP enabled on alternating odd digits (0xAA)");

        // ---------------------------------------------------------------------
        // Case 6: DP enabled on all digits (SEG_DP = 0xFF)
        // ---------------------------------------------------------------------
        test_dp_pattern(8'hFF, test_data, "DP enabled on all digits (0xFF)");

        // ---------------------------------------------------------------------
        // Case 7: Mixed DP pattern (SEG_DP = 0x96)
        // Digits 1, 2, 4, 7 active DP; digits 0, 3, 5, 6 inactive DP
        // ---------------------------------------------------------------------
        test_dp_pattern(8'h96, test_data, "Mixed DP pattern (0x96)");

        // ---------------------------------------------------------------------
        // Step 8: Cleanup / Restore Defaults
        // ---------------------------------------------------------------------
        `uvm_info(get_type_name(), "Restoring default register configurations...", UVM_LOW)
        write_reg(REG_SEG_CTRL, 32'h0000_FF06);
        write_reg(REG_SEG_REFRESH_DIV, 32'h0000_03E8);
        write_reg(REG_SEG_DATA, 32'h0000_0000);
        write_reg(REG_SEG_DP, 32'h0000_0000);

        `uvm_info(get_type_name(), "=== Completed SEG7 Decimal Point Control Verification Sequence ===", UVM_LOW)
    endtask

endclass : seg7_dp_control_seq

`endif // SEG7_DP_CONTROL_SEQ_SV

