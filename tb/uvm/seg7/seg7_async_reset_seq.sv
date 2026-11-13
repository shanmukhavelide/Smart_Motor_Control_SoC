// =============================================================================
// SEG7 Asynchronous Reset Sequence: seg7_async_reset_seq
//
// TIMING & RESET ARCHITECTURE:
//   - Reset Assertion: Asynchronous. rst_n is driven active-low at an arbitrary
//     fractional time (sub-cycle delay) relative to posedge clk.
//   - DUT State Response: Synchronous. Inside seg7_core.sv and axi_seg7_slave.v,
//     all sequential blocks are clocked:
//       always_ff @(posedge clk_i) if (!rst_ni) ...
//       always @(posedge S_AXI_ACLK) if (S_AXI_ARESETN == 0) ...
//     Therefore, internal state registers (digit_idx_q, refresh_cnt_q, slv_reg0..3)
//     and outputs update to their reset/blank values on the NEXT rising clock edge.
//   - Monitor/Scoreboard Response: seg7_vip_monitor detects negedge vif.rst_n
//     asynchronously, flushes in-flight dwell tracking without publishing partial
//     dwell records, and emits item.is_reset=1. seg7_vip_scoreboard resets its
//     internal state and discards partial intervals.
//
// BACKDOOR ACCESS & ERROR HANDLING:
//   - Verifies hierarchical reset path using uvm_hdl_check_path() and probes.
//   - Checks return values of uvm_hdl_force() and uvm_hdl_release(), issuing
//     uvm_fatal on any failure to guarantee deterministic test execution.
// =============================================================================

`ifndef SEG7_ASYNC_RESET_SEQ_SV
`define SEG7_ASYNC_RESET_SEQ_SV

class seg7_async_reset_seq extends seg7_base_seq;

    // Handle to VIP scoreboard for observation window control and checks
    seg7_vip_scoreboard sb;

    // Virtual interface handle for direct pin-level observation during reset
    virtual seg7_vip_if vif;

    // Verified hierarchical reset path for UVM backdoor access
    string target_reset_path = "tb_seg7_top.rst_n";
    bit    path_verified     = 1'b0;

    `uvm_object_utils(seg7_async_reset_seq)

    function new(string name = "seg7_async_reset_seq");
        super.new(name);
    endfunction

    // -------------------------------------------------------------------------
    // Helper Task: Resolve and Validate Hierarchical Reset Backdoor Path
    // -------------------------------------------------------------------------
    virtual task resolve_reset_path();
        if (path_verified) return;

        `uvm_info(get_type_name(), "Resolving hierarchical reset backdoor path...", UVM_LOW)

        // 1. Check primary top-level reset net
        if (uvm_hdl_check_path("tb_seg7_top.rst_n")) begin
            target_reset_path = "tb_seg7_top.rst_n";
            path_verified     = 1'b1;
            `uvm_info(get_type_name(), "Verified primary hierarchical path: 'tb_seg7_top.rst_n'", UVM_LOW)
        // 2. Check fallback DUT port net
        end else if (uvm_hdl_check_path("tb_seg7_top.dut.rst_n")) begin
            target_reset_path = "tb_seg7_top.dut.rst_n";
            path_verified     = 1'b1;
            `uvm_info(get_type_name(), "Verified fallback hierarchical path: 'tb_seg7_top.dut.rst_n'", UVM_LOW)
        // 3. If check_path returned 0, probe accessibility via test force/release
        end else begin
            `uvm_warning(get_type_name(),
                "uvm_hdl_check_path did not identify reset paths; attempting active backdoor probe...")
            if (uvm_hdl_force("tb_seg7_top.rst_n", 1'b1)) begin
                void'(uvm_hdl_release("tb_seg7_top.rst_n"));
                target_reset_path = "tb_seg7_top.rst_n";
                path_verified     = 1'b1;
                `uvm_info(get_type_name(), "Backdoor probe succeeded on 'tb_seg7_top.rst_n'", UVM_LOW)
            end else if (uvm_hdl_force("tb_seg7_top.dut.rst_n", 1'b1)) begin
                void'(uvm_hdl_release("tb_seg7_top.dut.rst_n"));
                target_reset_path = "tb_seg7_top.dut.rst_n";
                path_verified     = 1'b1;
                `uvm_info(get_type_name(), "Backdoor probe succeeded on 'tb_seg7_top.dut.rst_n'", UVM_LOW)
            end else begin
                `uvm_fatal(get_type_name(),
                    "Hierarchical reset path resolution FAILED! Neither 'tb_seg7_top.rst_n' nor 'tb_seg7_top.dut.rst_n' can be accessed via UVM HDL backdoor. Check simulator access options (+acc, -debug_access).")
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Helper Task: Asynchronous Reset Assertion & Pin Verification
    // -------------------------------------------------------------------------
    virtual task assert_reset_async(int hold_clocks = 5, int subcycle_offset_ns = 3);
        int force_ok;
        int release_ok;

        resolve_reset_path();

        // Subcycle delay ensures reset arrives at an arbitrary mid-cycle instant (asynchronous)
        #(subcycle_offset_ns * 1ns);
        `uvm_info(get_type_name(),
            $sformatf("Asserting asynchronous reset on '%s' (mid-cycle offset +%0dns, hold %0d clocks)...",
                      target_reset_path, subcycle_offset_ns, hold_clocks),
            UVM_LOW)

        // Force reset active-low via verified UVM backdoor path
        force_ok = uvm_hdl_force(target_reset_path, 1'b0);
        if (!force_ok) begin
            `uvm_fatal(get_type_name(),
                $sformatf("uvm_hdl_force('%s', 1'b0) FAILED! Backdoor access rejected by simulator.", target_reset_path))
        end

        // Also force VIP interfaces if secondary path was selected
        if (target_reset_path != "tb_seg7_top.rst_n") begin
            void'(uvm_hdl_force("tb_seg7_top.seg7_vif.rst_n", 1'b0));
            void'(uvm_hdl_force("tb_seg7_top.axi_vif.rst_n", 1'b0));
        end

        // Wait for next rising clock edge for synchronous DUT state registers and outputs to reset
        if (vif != null) @(posedge vif.clk);
        else #10ns;
        #1ps;

        // Verify physical outputs return to expected power-on blank/reset state
        // Under reset: EN=0, SEG_ACT_LO=1, AN_ACT_LO=1 -> seg_o = 8'hFF, an_o = 8'hFF
        if (vif != null) begin
            if (vif.an_o !== 8'hFF) begin
                `uvm_error(get_type_name(),
                    $sformatf("Reset assertion failed: an_o=0x%02h, expected 8'hFF (all anodes blank)", vif.an_o))
            end else begin
                `uvm_info(get_type_name(), "Reset assertion verified: an_o correctly blank (8'hFF)", UVM_HIGH)
            end

            if (vif.seg_o !== 8'hFF) begin
                `uvm_error(get_type_name(),
                    $sformatf("Reset assertion failed: seg_o=0x%02h, expected 8'hFF (all segments unasserted)", vif.seg_o))
            end else begin
                `uvm_info(get_type_name(), "Reset assertion verified: seg_o correctly blank (8'hFF)", UVM_HIGH)
            end
        end

        // Hold reset active for requested number of clock cycles
        if (vif != null) repeat (hold_clocks) @(posedge vif.clk);
        else #(hold_clocks * 10ns);

        // Deassert reset via UVM backdoor
        `uvm_info(get_type_name(), $sformatf("Deasserting reset on '%s'...", target_reset_path), UVM_LOW)
        release_ok = uvm_hdl_release(target_reset_path);
        if (!release_ok) begin
            `uvm_fatal(get_type_name(),
                $sformatf("uvm_hdl_release('%s') FAILED! Could not release forced reset.", target_reset_path))
        end

        if (target_reset_path != "tb_seg7_top.rst_n") begin
            void'(uvm_hdl_release("tb_seg7_top.seg7_vif.rst_n"));
            void'(uvm_hdl_release("tb_seg7_top.axi_vif.rst_n"));
        end

        // Allow reset deassertion propagation and AXI driver recovery
        if (vif != null) repeat (2) @(posedge vif.clk);
        else #20ns;
    endtask

    // -------------------------------------------------------------------------
    // Helper Task: Verify All Four Register Power-On Reset Defaults
    // -------------------------------------------------------------------------
    virtual task verify_reset_defaults();
        `uvm_info(get_type_name(), "Verifying all four AXI register power-on reset defaults...", UVM_LOW)
        read_check(REG_SEG_DATA,        32'h0000_0000, 32'hFFFF_FFFF);
        read_check(REG_SEG_CTRL,        32'h0000_FF06, 32'hFFFF_FFFF);
        read_check(REG_SEG_DP,          32'h0000_0000, 32'h0000_00FF);
        read_check(REG_SEG_REFRESH_DIV, 32'h0000_03E8, 32'h0000_FFFF);
        `uvm_info(get_type_name(), "All four AXI registers verified at reset defaults.", UVM_LOW)
    endtask

    // -------------------------------------------------------------------------
    // Helper Task: Directly Verify Scanner Restarts Strictly From Digit 0
    // -------------------------------------------------------------------------
    virtual task verify_restart_from_digit_0();
        bit first_digit_seen = 1'b0;
        bit [7:0] first_an;

        if (vif == null) begin
            `uvm_warning(get_type_name(), "vif is null; cannot verify first active anode directly.")
            return;
        end

        // Monitor the exact clock cycle when display transitions out of blank state (8'hFF)
        fork
            begin
                while (vif.an_o === 8'hFF) @(posedge vif.clk);
                #1ps; // sample after clock edge update
                first_an = vif.an_o;
                first_digit_seen = 1'b1;
            end
            begin
                // Guard timeout of 200 clock cycles (2000 ns)
                repeat (200) @(posedge vif.clk);
            end
        join_any
        disable fork;

        if (!first_digit_seen) begin
            `uvm_error(get_type_name(), "Timeout waiting for scanner restart: an_o never left blank state!")
        end else if (first_an !== 8'hFE) begin
            `uvm_error(get_type_name(),
                $sformatf("Scanner restarted at WRONG digit! First observed an_o=0x%02h, expected 0xFE (Digit 0)",
                          first_an))
        end else begin
            `uvm_info(get_type_name(),
                "CONFIRMED: Scanner restarted strictly from Digit 0 (first active an_o=0xFE).",
                UVM_LOW)
        end
    endtask

    virtual task body();
        bit [31:0] normal_data = 32'h7654_3210;

        `uvm_info(get_type_name(), "=== Starting SEG7 Asynchronous Reset Verification Sequence ===", UVM_LOW)

        // Validate scoreboard handle
        if (sb == null) begin
            if (!uvm_config_db#(seg7_vip_scoreboard)::get(null, get_full_name(), "sb", sb)) begin
                uvm_root root = uvm_root::get();
                uvm_component c = root.find("uvm_test_top.env.sb");
                if (c != null) void'($cast(sb, c));
            end
        end
        if (sb == null) begin
            `uvm_fatal(get_type_name(), "Scoreboard handle 'sb' is null! Test must assign seq.sb = env.sb")
        end

        // Retrieve virtual interface if not explicitly assigned
        if (vif == null) begin
            if (!uvm_config_db#(virtual seg7_vip_if)::get(null, get_full_name(), "seg7_vif", vif)) begin
                uvm_root root = uvm_root::get();
                void'(uvm_config_db#(virtual seg7_vip_if)::get(root, "*", "vif", vif));
            end
        end

        // =====================================================================
        // Scenario 1 to 5: Reset During Active Dwell on Digit 0 & Clean Restart
        // =====================================================================
        `uvm_info(get_type_name(), "--- Scenario 1 to 5: Active Scan Reset on Digit 0 and Clean Restart ---", UVM_LOW)

        // 1. Configure and start normal 8-digit scanning
        write_reg(REG_SEG_DATA, normal_data);
        write_reg(REG_SEG_DP, 32'h0000_0000);
        write_reg(REG_SEG_REFRESH_DIV, 32'd20);
        sb.start_observation_window();
        write_reg(REG_SEG_CTRL, 32'h0000_FF07); // EN=1, DIGIT_MASK=8'hFF, active-low seg/an

        // Precise synchronization: wait until scanner actively dwells on Digit 0 (an_o = 8'hFE)
        if (vif != null) begin
            while (vif.an_o !== 8'hFE) @(posedge vif.clk);
            repeat (5) @(posedge vif.clk); // Dwell 5 cycles into Digit 0
            if (vif.an_o !== 8'hFE) begin
                `uvm_error(get_type_name(),
                    $sformatf("Timing error: Expected Digit 0 dwell (an_o=0xFE), got 0x%02h", vif.an_o))
            end
        end else begin
            #50ns;
        end

        // 2 & 3 & 4. Assert asynchronous reset mid-dwell (+3ns offset), verify blank outputs, hold 5 clocks
        assert_reset_async(.hold_clocks(5), .subcycle_offset_ns(3));

        // 5. Verify all four register reset defaults via AXI reads
        verify_reset_defaults();

        // 5b. Reconfigure display and verify clean restart strictly from Digit 0
        `uvm_info(get_type_name(), "Re-enabling scanning to verify clean restart from Digit 0...", UVM_LOW)
        write_reg(REG_SEG_DATA, normal_data);
        write_reg(REG_SEG_REFRESH_DIV, 32'd20);
        sb.start_observation_window();

        // Launch concurrent Digit 0 restart check alongside AXI enable write
        fork
            verify_restart_from_digit_0();
            write_reg(REG_SEG_CTRL, 32'h0000_FF07);
        join

        // Allow two complete 8-digit scan rounds (360 clocks = 3600 ns)
        #3600ns;

        // Disable display to close final dwell
        write_reg(REG_SEG_CTRL, 32'h0000_FF06);
        #20ns;

        // Verify dwell times and 8-digit segment patterns
        sb.check_dwell(20);
        sb.check_display(
            .en     (1'b1),
            .data   (normal_data),
            .dp     (8'h00),
            .mask   (8'hFF),
            .seg_al (1'b1),
            .an_al  (1'b1)
        );
        `uvm_info(get_type_name(), "--- PASS: Scenario 1 to 5 verified successfully ---", UVM_LOW)

        // =====================================================================
        // Scenario 6: Reset Mid-Dwell on a Later Digit Position (Digit 3)
        // =====================================================================
        `uvm_info(get_type_name(), "--- Scenario 6: Reset Mid-Dwell at Intermediate Digit (Digit 3) ---", UVM_LOW)

        // Configure scanning with REFRESH_DIV = 20
        write_reg(REG_SEG_DATA, normal_data);
        write_reg(REG_SEG_REFRESH_DIV, 32'd20);
        write_reg(REG_SEG_CTRL, 32'h0000_FF07);

        // Precise synchronization: wait until scanner reaches Digit 3 (an_o = 8'hF7)
        if (vif != null) begin
            while (vif.an_o !== 8'hF7) @(posedge vif.clk);
            repeat (5) @(posedge vif.clk); // Dwell 5 cycles into Digit 3
            if (vif.an_o !== 8'hF7) begin
                `uvm_error(get_type_name(),
                    $sformatf("Timing error: Expected Digit 3 dwell (an_o=0xF7), got 0x%02h", vif.an_o))
            end
        end else begin
            #650ns;
        end

        // Assert asynchronous reset mid-dwell on Digit 3 (+7ns offset)
        assert_reset_async(.hold_clocks(6), .subcycle_offset_ns(7));

        // Verify all four register reset defaults
        verify_reset_defaults();

        // Verify clean restart strictly from Digit 0 again
        write_reg(REG_SEG_DATA, normal_data);
        write_reg(REG_SEG_REFRESH_DIV, 32'd20);
        sb.start_observation_window();

        fork
            verify_restart_from_digit_0();
            write_reg(REG_SEG_CTRL, 32'h0000_FF07);
        join

        #3600ns;
        write_reg(REG_SEG_CTRL, 32'h0000_FF06);
        #20ns;
        sb.check_dwell(20);
        sb.check_display(
            .en     (1'b1),
            .data   (normal_data),
            .dp     (8'h00),
            .mask   (8'hFF),
            .seg_al (1'b1),
            .an_al  (1'b1)
        );
        `uvm_info(get_type_name(), "--- PASS: Scenario 6 verified successfully ---", UVM_LOW)

        // =====================================================================
        // Scenario 7: Reset While Display Scanning Is Disabled
        // =====================================================================
        `uvm_info(get_type_name(), "--- Scenario 7: Reset While Display Is Disabled ---", UVM_LOW)

        // Program non-default register values with EN = 0
        write_reg(REG_SEG_DATA, 32'hA5A5_5A5A);
        write_reg(REG_SEG_DP, 32'h0000_00A5);
        write_reg(REG_SEG_REFRESH_DIV, 32'd50);
        write_reg(REG_SEG_CTRL, 32'h0000_AA06); // EN=0, MASK=0xAA

        // Confirm non-default values before reset
        read_check(REG_SEG_DATA, 32'hA5A5_5A5A);
        read_check(REG_SEG_DP, 32'h0000_00A5);
        read_check(REG_SEG_REFRESH_DIV, 32'd50);
        read_check(REG_SEG_CTRL, 32'h0000_AA06);

        // Assert asynchronous reset while disabled (+2ns offset)
        assert_reset_async(.hold_clocks(4), .subcycle_offset_ns(2));

        // Verify registers returned to default values
        verify_reset_defaults();
        `uvm_info(get_type_name(), "--- PASS: Scenario 7 verified successfully ---", UVM_LOW)

        // =====================================================================
        // Scenario 8: Reset With Non-Default Mask, Divider & Polarity
        // =====================================================================
        `uvm_info(get_type_name(), "--- Scenario 8: Reset With Non-Default Mask, Divider, and Polarity ---", UVM_LOW)

        // Program active-high polarity, DIGIT_MASK=8'h55, REFRESH_DIV=30
        write_reg(REG_SEG_DATA, 32'hFEDC_BA98);
        write_reg(REG_SEG_DP, 32'h0000_0033);
        write_reg(REG_SEG_REFRESH_DIV, 32'd30);
        // Active-high polarity: SEG_ACT_LO=0, AN_ACT_LO=0, EN=1, MASK=0x55 -> 0x0000_5501
        write_reg(REG_SEG_CTRL, 32'h0000_5501);

        // Synchronize: wait until active-high Digit 2 (an_o = 8'h04) is actively dwelling
        if (vif != null) begin
            while (vif.an_o !== 8'h04) @(posedge vif.clk);
            repeat (5) @(posedge vif.clk);
            if (vif.an_o !== 8'h04) begin
                `uvm_error(get_type_name(),
                    $sformatf("Timing error: Expected active-high Digit 2 (an_o=0x04), got 0x%02h", vif.an_o))
            end
        end else begin
            #1000ns;
        end

        // Assert asynchronous reset (+4ns offset)
        assert_reset_async(.hold_clocks(5), .subcycle_offset_ns(4));

        // Verify registers returned to active-low, EN=0 defaults
        verify_reset_defaults();

        // Final verification: re-enable normal 8-digit scan to confirm complete recovery
        write_reg(REG_SEG_DATA, normal_data);
        write_reg(REG_SEG_REFRESH_DIV, 32'd20);
        sb.start_observation_window();

        fork
            verify_restart_from_digit_0();
            write_reg(REG_SEG_CTRL, 32'h0000_FF07);
        join

        #3600ns;
        write_reg(REG_SEG_CTRL, 32'h0000_FF06);
        #20ns;
        sb.check_dwell(20);
        sb.check_display(
            .en     (1'b1),
            .data   (normal_data),
            .dp     (8'h00),
            .mask   (8'hFF),
            .seg_al (1'b1),
            .an_al  (1'b1)
        );
        `uvm_info(get_type_name(), "--- PASS: Scenario 8 verified successfully ---", UVM_LOW)

        // =====================================================================
        // Cleanup / Restore Power-On Reset Defaults
        // =====================================================================
        `uvm_info(get_type_name(), "Restoring default register configurations...", UVM_LOW)
        write_reg(REG_SEG_CTRL, 32'h0000_FF06);
        write_reg(REG_SEG_REFRESH_DIV, 32'h0000_03E8);
        write_reg(REG_SEG_DATA, 32'h0000_0000);
        write_reg(REG_SEG_DP, 32'h0000_0000);

        `uvm_info(get_type_name(), "=== Completed SEG7 Asynchronous Reset Verification Sequence ===", UVM_LOW)
    endtask

endclass : seg7_async_reset_seq

`endif // SEG7_ASYNC_RESET_SEQ_SV
