// =============================================================================
// Seven-Segment VIP Scoreboard
// Usage from a test:  sb.clear_image();  <program regs>;  wait >= 8*dwell clocks;
//                     sb.check_display(...);  sb.check_dwell(div);
// =============================================================================
`ifndef SEG7_VIP_SCOREBOARD_SV
`define SEG7_VIP_SCOREBOARD_SV

class seg7_vip_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(seg7_vip_scoreboard)

  uvm_analysis_imp #(seg7_vip_item, seg7_vip_scoreboard) mon_imp;

  seg7_vip_monitor mon;          // set by env.connect_phase
  seg7_vip_item    hist[$];      // completed scan states since last clear
  int match_count    = 0;
  int mismatch_count = 0;

  function new(string n, uvm_component p);
    super.new(n, p);
    mon_imp = new("mon_imp", this);
  endfunction

  virtual function void write(seg7_vip_item item);
    hist.push_back(item);
    // Never more than one anode active; blank is all-0 (active-high) or all-1 (active-low)
    if (item.digit < 0 && item.an_raw != 8'h00 && item.an_raw != 8'hFF) begin
      `uvm_error(get_type_name(), $sformatf("[SCOREBOARD FAIL] an_o=0x%02h is not one-hot/one-cold/blank", item.an_raw))
      mismatch_count++;
    end
  endfunction

  function void clear_image();
    hist.delete();
    if (mon != null) mon.clear_image();
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
  function void check_display(bit en, bit [31:0] data, bit [7:0] dp, bit [7:0] mask,
                              bit seg_al, bit an_al);
    bit [7:0] exp_seg, exp_raw;
    bit       any_seen = 0;

    if (mon == null) begin
      `uvm_error(get_type_name(), "[SCOREBOARD FAIL] monitor handle not set")
      mismatch_count++;
      return;
    end

    for (int d = 0; d < 8; d++) begin
      if (mon.img_seen[d]) any_seen = 1;
      if (en && mask[d]) begin
        exp_seg = {dp[d], hex_to_seg(data[4*d +: 4])};
        exp_raw = seg_al ? ~exp_seg : exp_seg;
        if (!mon.img_seen[d]) begin
          `uvm_error(get_type_name(), $sformatf("[SCOREBOARD FAIL] digit %0d never lit (expected seg=0x%02h)", d, exp_raw))
          mismatch_count++;
        end else if (mon.img_seg[d] !== exp_raw) begin
          `uvm_error(get_type_name(), $sformatf("[SCOREBOARD FAIL] digit %0d seg_o=0x%02h expected 0x%02h", d, mon.img_seg[d], exp_raw))
          mismatch_count++;
        end else begin
          `uvm_info(get_type_name(), $sformatf("[SCOREBOARD PASS] digit %0d seg_o=0x%02h", d, exp_raw), UVM_MEDIUM)
          match_count++;
        end
      end else if (mon.img_seen[d]) begin
        `uvm_error(get_type_name(), $sformatf("[SCOREBOARD FAIL] digit %0d lit but expected off (en=%0b mask=%0b)", d, en, mask[d]))
        mismatch_count++;
      end
    end

    if (any_seen && mon.img_an_active_low !== an_al) begin
      `uvm_error(get_type_name(), $sformatf("[SCOREBOARD FAIL] anode polarity: observed active_low=%0b expected %0b",
                 mon.img_an_active_low, an_al))
      mismatch_count++;
    end
  endfunction

  // Refresh timing: needs >= 2 enabled digits so the scan actually advances.
  // The first completed state after a clear may be partial, so it is skipped.
  function void check_dwell(int div);
    int exp_dwell = (div <= 1) ? 1 : div;
    int checked = 0;
    int bad     = 0;

    for (int i = 1; i < hist.size(); i++) begin
      if (hist[i].digit < 0) continue;
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
      `uvm_error(get_type_name(), "7-Seg Verification Failed!")
    end else if (match_count > 0) begin
      `uvm_info(get_type_name(), "7-Seg Verification Completed Successfully!", UVM_LOW)
    end
  endfunction
endclass : seg7_vip_scoreboard

`endif // SEG7_VIP_SCOREBOARD_SV
