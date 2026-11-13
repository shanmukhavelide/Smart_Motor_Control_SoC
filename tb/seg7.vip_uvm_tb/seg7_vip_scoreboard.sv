// =============================================================================
// Seven-Segment VIP Scoreboard
//
// Usage model from a test:
//   1. Configure or reconfigure SEG7 registers via AXI (DIGIT_MASK, EN,
//      segment/anode polarity, display data, or refresh divider).
//   2. Explicitly start a fresh observation window:
//        sb.start_observation_window(); // or sb.clear_image();
//   3. Allow sufficient scan time before checking display:
//        wait >= num_active_digits * dwell clocks (or >= 8 * dwell clocks).
//      Optional query: wait (sb.all_masked_seen(expected_mask));
//   4. Validate display and timing:
//        sb.check_display(...);
//        sb.check_dwell(div);
//
// Reset awareness:
//   When interface reset (rst_n) asserts, the monitor broadcasts an is_reset
//   item. The scoreboard independently flushes its history and display image.
//   The monitor's is_partial flag on the first post-reset dwell is preserved,
//   and scoreboard-local tracking skips the first dwell after an explicit clear
//   without mutating the broadcast transaction.
// =============================================================================
`ifndef SEG7_VIP_SCOREBOARD_SV
`define SEG7_VIP_SCOREBOARD_SV

class seg7_vip_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(seg7_vip_scoreboard)

  uvm_analysis_imp #(seg7_vip_item, seg7_vip_scoreboard) mon_imp;

  seg7_vip_item hist[$];         // completed valid digit scan states since last clear / reset

  // Internal scoreboard state updated via write(item) (completely decoupled from monitor internals)
  bit [7:0] img_seg  [8];
  bit       img_seen [8];
  bit       img_an_active_low;
  bit       valid_scan_seen            = 0;
  bit       blank_anode_seen           = 0;

  // Scoreboard-local state to track observation clear intervals (leaves transactions immutable)
  bit       first_item_after_clear     = 0;
  int       first_item_after_clear_idx = -1;

  int match_count    = 0;
  int mismatch_count = 0;

  function new(string n, uvm_component p);
    super.new(n, p);
    mon_imp = new("mon_imp", this);
  endfunction

  virtual function void write(seg7_vip_item item);
    // Interface reset notification from monitor: cleanly flush state independently
    if (item.is_reset) begin
      reset_state();
      return;
    end

    // Track observation of valid blank anode state (active-high 8'h00 or active-low 8'hFF)
    if (item.an_raw == 8'h00 || item.an_raw == 8'hFF) begin
      blank_anode_seen = 1'b1;
    end

    // Only completed valid digit dwell transactions should accumulate in the dwell history
    if (item.digit >= 0 && item.digit < 8) begin
      // Identify first valid digit record arriving after an explicit clear using scoreboard-local state.
      // Do NOT mutate item.is_partial or any other field of the incoming transaction.
      if (first_item_after_clear) begin
        first_item_after_clear_idx = hist.size();
        first_item_after_clear     = 1'b0;
      end

      hist.push_back(item);

      // Update scoreboard's own per-digit image from transaction stream (accumulates across window)
      img_seg[item.digit]  = item.seg_raw;
      img_seen[item.digit] = 1'b1;
      img_an_active_low    = item.an_active_low;
      valid_scan_seen      = 1'b1;
    end

    // Never more than one anode active; blank is all-0 (active-high) or all-1 (active-low)
    if (item.digit < 0 && item.an_raw != 8'h00 && item.an_raw != 8'hFF) begin
      `uvm_error(get_type_name(), $sformatf("[SCOREBOARD FAIL] an_o=0x%02h is not one-hot/one-cold/blank", item.an_raw))
      mismatch_count++;
    end
  endfunction

  // Reset-triggered clear: flushes scoreboard state on interface reset
  function void reset_state();
    hist.delete();
    for (int i = 0; i < 8; i++) begin
      img_seg[i]  = 8'h00;
      img_seen[i] = 1'b0;
    end
    img_an_active_low          = 1'b0;
    valid_scan_seen            = 1'b0;
    first_item_after_clear     = 1'b0;
    first_item_after_clear_idx = -1;
    blank_anode_seen           = 1'b0;
  endfunction

  // Explicit observation window start / clear:
  // Tests call this to begin a fresh display observation window after reconfiguring
  // SEG7 registers (DIGIT_MASK, EN, polarity, data, or refresh div).
  // Note: Tests must allow sufficient scan time (>= active_digits * dwell clocks)
  // before calling check_display().
  function void clear_image();
    hist.delete();
    for (int i = 0; i < 8; i++) begin
      img_seg[i]  = 8'h00;
      img_seen[i] = 1'b0;
    end
    img_an_active_low          = 1'b0;
    valid_scan_seen            = 1'b0;
    first_item_after_clear     = 1'b1;
    first_item_after_clear_idx = -1;
    blank_anode_seen           = 1'b0;
  endfunction

  // Alias for clear_image() with explicit semantic naming for test writers
  function void start_observation_window();
    clear_image();
  endfunction

  // Returns 1 if all active digits in mask have been observed at least once in the current window
  function bit all_masked_seen(bit [7:0] mask);
    for (int d = 0; d < 8; d++) begin
      if (mask[d] && !img_seen[d]) return 1'b0;
    end
    return 1'b1;
  endfunction

  // Independent reference decode, active-high {g,f,e,d,c,b,a}
  static function bit [6:0] hex_to_seg(bit [3:0] n);
    case (n)
      4'h0: return 7'h3F;  4'h1: return 7'h06;  4'h2: return 7'h5B;  4'h3: return 7'h4F;
      4'h4: return 7'h66;  4'h5: return 7'h6D;  4'h6: return 7'h7D;  4'h7: return 7'h07;
      4'h8: return 7'h7F;  4'h9: return 7'h6F;  4'hA: return 7'h77;  4'hB: return 7'h7C;
      4'hC: return 7'h39;  4'hD: return 7'h5E;  4'hE: return 7'h79;  default: return 7'h71;
    endcase
  endfunction

  // Compare observed per-digit image against what the test programmed.
  // Note: Test must have waited sufficient clocks for the round-robin scan to complete.
  function void check_display(bit en, bit [31:0] data, bit [7:0] dp, bit [7:0] mask,
                              bit seg_al, bit an_al);
    bit [7:0] exp_seg, exp_raw;
    bit       any_seen = 0;

    for (int d = 0; d < 8; d++) begin
      if (img_seen[d]) any_seen = 1;
    end

    // Disabled display check (en = 0): no digit must be lit, and a valid blank anode state must be observed
    if (!en) begin
      if (any_seen) begin
        for (int d = 0; d < 8; d++) begin
          if (img_seen[d]) begin
            `uvm_error(get_type_name(), $sformatf("[SCOREBOARD FAIL] digit %0d lit but display is disabled (en=0)", d))
            mismatch_count++;
          end
        end
      end else if (blank_anode_seen) begin
        `uvm_info(get_type_name(), "[SCOREBOARD PASS] display correctly blanked when disabled (en=0)", UVM_MEDIUM)
        match_count++;
      end else begin
        `uvm_error(get_type_name(), "[SCOREBOARD FAIL] display disabled (en=0) check failed: no output observation received (neither blank nor digit)")
        mismatch_count++;
      end
      return;
    end

    // Enabled display (en = 1): verify each digit 0..7 against mask and data/dp
    for (int d = 0; d < 8; d++) begin
      if (mask[d]) begin
        // Decimal point is bit 7; 7-seg hex pattern is bits [6:0]
        exp_seg = {dp[d], hex_to_seg(data[4*d +: 4])};
        exp_raw = seg_al ? ~exp_seg : exp_seg;

        if (!img_seen[d]) begin
          `uvm_error(get_type_name(), $sformatf("[SCOREBOARD FAIL] digit %0d never lit (expected seg=0x%02h, mask=0x%02h; check if test waited sufficient scan intervals)",
                     d, exp_raw, mask))
          mismatch_count++;
        end else if (img_seg[d] !== exp_raw) begin
          `uvm_error(get_type_name(), $sformatf("[SCOREBOARD FAIL] digit %0d seg_o=0x%02h expected 0x%02h (dp=%0b seg_al=%0b)",
                     d, img_seg[d], exp_raw, dp[d], seg_al))
          mismatch_count++;
        end else begin
          `uvm_info(get_type_name(), $sformatf("[SCOREBOARD PASS] digit %0d seg_o=0x%02h", d, exp_raw), UVM_MEDIUM)
          match_count++;
        end
      end else begin
        // Masked digit: must NOT be lit
        if (img_seen[d]) begin
          `uvm_error(get_type_name(), $sformatf("[SCOREBOARD FAIL] digit %0d lit but expected masked off (mask[%0d]=0)", d, d))
          mismatch_count++;
        end else begin
          `uvm_info(get_type_name(), $sformatf("[SCOREBOARD PASS] digit %0d correctly masked off", d), UVM_HIGH)
          match_count++;
        end
      end
    end

    // Anode polarity check for enabled scan
    if (any_seen && (img_an_active_low !== an_al)) begin
      `uvm_error(get_type_name(), $sformatf("[SCOREBOARD FAIL] anode polarity: observed active_low=%0b expected %0b",
                 img_an_active_low, an_al))
      mismatch_count++;
    end
  endfunction

  // Refresh timing: needs >= 2 enabled digits so the scan actually advances.
  // The first completed interval in hist (hist[0] or first_item_after_clear_idx)
  // or any interval flagged as partial by the monitor is skipped.
  function void check_dwell(int div);
    int exp_dwell = (div <= 1) ? 1 : div;
    int checked   = 0;
    int bad       = 0;

    for (int i = 0; i < hist.size(); i++) begin
      // Exclude potentially partial intervals:
      // 1) First interval after explicit observation clear (scoreboard-local tracking)
      if (i == 0 || i == first_item_after_clear_idx) continue;
      // 2) Monitor-flagged partial intervals (startup / reset, preserved without mutation)
      if (hist[i].is_partial) continue;
      // Exclude blank or invalid intervals; only check actual digit dwells (0..7)
      if (hist[i].digit < 0 || hist[i].digit > 7) continue;
      checked++;
      if (hist[i].dwell_cycles != exp_dwell) begin
        bad++;
        `uvm_error(get_type_name(), $sformatf("[SCOREBOARD FAIL] digit %0d held %0d clocks, expected %0d",
                   hist[i].digit, hist[i].dwell_cycles, exp_dwell))
      end
    end

    if (checked == 0) begin
      `uvm_error(get_type_name(), "[SCOREBOARD FAIL] no complete digit dwell observed (need >= 2 enabled digits and enough wait time)")
      mismatch_count++;
    end else if (bad == 0) begin
      `uvm_info(get_type_name(), $sformatf("[SCOREBOARD PASS] %0d digit dwells all = %0d clocks", checked, exp_dwell), UVM_LOW)
      match_count++;
    end else begin
      mismatch_count += bad;
    end
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info(get_type_name(), "==================================================================", UVM_LOW)
    `uvm_info(get_type_name(), "                7-SEG SCOREBOARD SUMMARY                          ", UVM_LOW)
    `uvm_info(get_type_name(), "==================================================================", UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("  Total Scoreboard Matches    : %0d", match_count), UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("  Total Scoreboard Mismatches : %0d", mismatch_count), UVM_LOW)
    `uvm_info(get_type_name(), "==================================================================", UVM_LOW)

    if (mismatch_count > 0) begin
      `uvm_error(get_type_name(), "7-Seg Verification Failed with mismatches!")
    end else if (!valid_scan_seen && !blank_anode_seen && match_count == 0) begin
      `uvm_error(get_type_name(), "7-Seg Verification Failed: No valid digit scan or blank state was observed!")
    end else if (match_count > 0) begin
      `uvm_info(get_type_name(), "7-Seg Verification Completed Successfully!", UVM_LOW)
    end else begin
      `uvm_error(get_type_name(), "7-Seg Verification Failed: No checks or scans were verified!")
    end
  endfunction
endclass : seg7_vip_scoreboard

`endif // SEG7_VIP_SCOREBOARD_SV
