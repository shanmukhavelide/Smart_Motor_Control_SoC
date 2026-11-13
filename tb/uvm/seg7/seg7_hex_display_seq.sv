// =============================================================================
// SEG7 Hexadecimal Display Sequence: seg7_hex_display_seq
// Verifies:
//   1. Hexadecimal segment decoding for all 16 values (0x0 through 0xF).
//   2. Single-digit operation (digit mask enabling exactly one active digit).
//   3. Integration with seg7_vip_scoreboard:
//      - Fresh observation window per hex value via start_observation_window().
//      - Adequate dwell time for hardware output settling.
//      - Verification via scoreboard check_display() against hex reference table.
// =============================================================================

`ifndef SEG7_HEX_DISPLAY_SEQ_SV
`define SEG7_HEX_DISPLAY_SEQ_SV

class seg7_hex_display_seq extends seg7_base_seq;

    // Handle to VIP scoreboard for observation window control and display checks
    seg7_vip_scoreboard sb;

    // Configurable target digit position (0..7, defaults to digit 0)
    int target_digit = 0;

    // Compact refresh divider (20 clock cycles) to accelerate test execution
    int refresh_div = 20;

    `uvm_object_utils(seg7_hex_display_seq)

    function new(string name = "seg7_hex_display_seq");
        super.new(name);
    endfunction

    virtual task body();
        bit [7:0]  digit_mask;
        bit [31:0] ctrl_disabled;
        bit [31:0] ctrl_enabled;

        `uvm_info(get_type_name(), "=== Starting SEG7 Hexadecimal Display Verification Sequence ===", UVM_LOW)

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

        // Ensure target_digit is within valid 0..7 range
        if (target_digit < 0 || target_digit > 7) begin
            `uvm_warning(get_type_name(), $sformatf("target_digit %0d out of range [0:7], clamping to 0", target_digit))
            target_digit = 0;
        end

        // Calculate single-digit mask and control words:
        // SEG_CTRL:
        //   [0]   = EN
        //   [1]   = SEG_ACTIVE_LOW (1)
        //   [2]   = AN_ACTIVE_LOW  (1)
        //   [15:8]= DIGIT_MASK     (1 << target_digit)
        digit_mask    = (8'h01 << target_digit);
        ctrl_disabled = (32'(digit_mask) << SEG_CTRL_MASK_SHIFT) | SEG_CTRL_AN_ACT_LO | SEG_CTRL_SEG_ACT_LO;
        ctrl_enabled  = ctrl_disabled | SEG_CTRL_EN;

        // ---------------------------------------------------------------------
        // Step 1: Initialize Display Configuration
        // ---------------------------------------------------------------------
        `uvm_info(get_type_name(), $sformatf("Configuring refresh_div=%0d, target_digit=%0d (mask=0x%02h)",
                  refresh_div, target_digit, digit_mask), UVM_LOW)

        // Clear decimal point register
        write_reg(REG_SEG_DP, 32'h0000_0000);

        // Configure compact refresh divider
        write_reg(REG_SEG_REFRESH_DIV, 32'(refresh_div));

        // Start with display disabled
        write_reg(REG_SEG_CTRL, ctrl_disabled);

        // ---------------------------------------------------------------------
        // Step 2: Iterate Through All 16 Hexadecimal Values (0x0 to 0xF)
        // ---------------------------------------------------------------------
        for (int val = 0; val < 16; val++) begin
            bit [31:0] seg_data;
            seg_data = 32'(val) << (target_digit * 4);

            `uvm_info(get_type_name(),
                $sformatf("--- Testing Hex Pattern 0x%01h on Digit %0d (SEG_DATA=0x%08h) ---",
                          val, target_digit, seg_data),
                UVM_LOW)

            // 1. Start a fresh scoreboard observation window using scoreboard API
            sb.start_observation_window();

            // 2. Write hexadecimal value into target digit's nibble in SEG_DATA
            write_reg(REG_SEG_DATA, seg_data);

            // 3. Enable display with single digit enabled (active-low segments & anodes)
            write_reg(REG_SEG_CTRL, ctrl_enabled);

            // 4. Allow sufficient clock cycles for the display output to settle and dwell
            // 30 clock cycles = 300 ns at 100 MHz, exceeding refresh_div (20 cycles)
            #300ns;

            // 5. Complete digit dwell by deasserting EN to trigger anode transition (8'hFE -> 8'hFF)
            // This ensures passive monitor publishes the completed dwell record to scoreboard
            write_reg(REG_SEG_CTRL, ctrl_disabled);
            #20ns; // allow clock edge and monitor sampling to record and write transaction

            // 6. Verify observed segment pattern against scoreboard's hex reference table
            sb.check_display(
                .en     (1'b1),
                .data   (seg_data),
                .dp     (8'h00),
                .mask   (digit_mask),
                .seg_al (1'b1),
                .an_al  (1'b1)
            );
        end

        // ---------------------------------------------------------------------
        // Step 3: Cleanup / Restore Defaults
        // ---------------------------------------------------------------------
        `uvm_info(get_type_name(), "Restoring default register configurations...", UVM_LOW)
        write_reg(REG_SEG_CTRL, 32'h0000_FF06);
        write_reg(REG_SEG_REFRESH_DIV, 32'h0000_03E8);
        write_reg(REG_SEG_DATA, 32'h0000_0000);

        `uvm_info(get_type_name(), "=== Completed SEG7 Hexadecimal Display Verification Sequence ===", UVM_LOW)
    endtask

endclass : seg7_hex_display_seq

`endif // SEG7_HEX_DISPLAY_SEQ_SV

