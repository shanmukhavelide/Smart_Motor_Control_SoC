// =============================================================================
// SEG7 Full Hexadecimal Sweep Sequence: seg7_full_hex_sweep_seq
// Verifies:
//   1. Hexadecimal segment decoding for all 16 values (0x0 through 0xF)
//      across all eight display digit positions (0 through 7).
//   2. Full 8-digit scanning with DIGIT_MASK = 8'hFF and SEG_REFRESH_DIV = 20.
//   3. Active-low segment and anode polarity.
//   4. Decimal points disabled (SEG_DP = 8'h00).
//   5. Coverage closure for cross_hex_x_digit (16 values x 8 digits = 128 bins).
//   6. VIP scoreboard integration with fresh observation window per value.
// =============================================================================

`ifndef SEG7_FULL_HEX_SWEEP_SEQ_SV
`define SEG7_FULL_HEX_SWEEP_SEQ_SV

class seg7_full_hex_sweep_seq extends seg7_base_seq;

    // Handle to VIP scoreboard for observation window control and display checks
    seg7_vip_scoreboard sb;

    // Compact refresh divider (20 clock cycles) to accelerate simulation while providing clean dwell intervals
    int refresh_div = 20;

    `uvm_object_utils(seg7_full_hex_sweep_seq)

    function new(string name = "seg7_full_hex_sweep_seq");
        super.new(name);
    endfunction

    virtual task body();
        int wait_clocks;
        bit [31:0] ctrl_dis;
        bit [31:0] ctrl_en;

        `uvm_info(get_type_name(), "=== Starting SEG7 Full Hexadecimal Sweep Verification Sequence ===", UVM_LOW)

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
        // Step 1: Initial Hardware Configuration
        // ---------------------------------------------------------------------
        // Precalculate control words for DIGIT_MASK=8'hFF, active-low seg & an:
        // SEG_CTRL:
        //   [0]    = EN (0 for disabled, 1 for enabled)
        //   [1]    = SEG_ACTIVE_LOW (1)
        //   [2]    = AN_ACTIVE_LOW  (1)
        //   [15:8] = DIGIT_MASK     (8'hFF)
        ctrl_dis = (32'(8'hFF) << SEG_CTRL_MASK_SHIFT) | SEG_CTRL_AN_ACT_LO | SEG_CTRL_SEG_ACT_LO; // 32'h0000_FF06
        ctrl_en  = ctrl_dis | SEG_CTRL_EN;                                                           // 32'h0000_FF07

        // Allow at least 2 complete scan rounds plus 2 dwell periods margin:
        // (2 * 8 + 2) * refresh_div = 18 * 20 = 360 clock cycles = 3600 ns at 100 MHz
        wait_clocks = (2 * 8 + 2) * refresh_div;

        `uvm_info(get_type_name(),
            $sformatf("Configuring refresh_div=%0d, wait_clocks=%0d (3600 ns dwell per hex value)",
                      refresh_div, wait_clocks),
            UVM_LOW)

        // Disable decimal points across all digits
        write_reg(REG_SEG_DP, 32'h0000_0000);

        // Configure compact refresh divider
        write_reg(REG_SEG_REFRESH_DIV, 32'(refresh_div));

        // Start with display scanning disabled
        write_reg(REG_SEG_CTRL, ctrl_dis);

        // ---------------------------------------------------------------------
        // Step 2: Sweep Hexadecimal Values 0x0 through 0xF Across All 8 Digits
        // ---------------------------------------------------------------------
        for (int val = 0; val < 16; val++) begin
            bit [31:0] test_data;
            // Replicate 4-bit nibble across all 8 digits (SEG_DATA = {8{val[3:0]}})
            test_data = {8{val[3:0]}};

            `uvm_info(get_type_name(),
                $sformatf("--- Sweep Value 0x%01h/0xF Across All 8 Digits (SEG_DATA=0x%08h) ---",
                          val[3:0], test_data),
                UVM_LOW)

            // 1. Ensure display is disabled before reconfiguration
            write_reg(REG_SEG_CTRL, ctrl_dis);

            // 2. Start a fresh scoreboard observation window
            sb.start_observation_window();

            // 3. Program SEG_DATA with replicated nibble value
            write_reg(REG_SEG_DATA, test_data);

            // 4. Enable display scanning with all eight digits active
            write_reg(REG_SEG_CTRL, ctrl_en);

            // 5. Wait for at least two complete 8-digit scan rounds
            #(wait_clocks * 10ns);

            // 6. Complete digit dwell by deasserting EN to trigger anode transition (one-cold -> 8'hFF)
            // This prompts passive monitor to complete and publish the final active digit record
            // to both seg7_vip_scoreboard and seg7_coverage
            write_reg(REG_SEG_CTRL, ctrl_dis);

            // 7. Allow monitor clock edge and delta delay to record and publish transaction
            #20ns;

            // 8. Verify observed display against expected hexadecimal patterns
            sb.check_display(
                .en     (1'b1),
                .data   (test_data),
                .dp     (8'h00),
                .mask   (8'hFF),
                .seg_al (1'b1),
                .an_al  (1'b1)
            );

            `uvm_info(get_type_name(),
                $sformatf("--- PASS: Hex Value 0x%01h verified successfully across all 8 digits ---", val[3:0]),
                UVM_LOW)
        end

        // ---------------------------------------------------------------------
        // Step 3: Cleanup / Restore Power-On Reset Defaults
        // ---------------------------------------------------------------------
        `uvm_info(get_type_name(), "Restoring default register configurations...", UVM_LOW)
        write_reg(REG_SEG_CTRL, 32'h0000_FF06);
        write_reg(REG_SEG_REFRESH_DIV, 32'h0000_03E8);
        write_reg(REG_SEG_DATA, 32'h0000_0000);
        write_reg(REG_SEG_DP, 32'h0000_0000);

        `uvm_info(get_type_name(), "=== Completed SEG7 Full Hexadecimal Sweep Verification Sequence ===", UVM_LOW)
    endtask

endclass : seg7_full_hex_sweep_seq

`endif // SEG7_FULL_HEX_SWEEP_SEQ_SV

